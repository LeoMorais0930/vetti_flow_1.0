"""Exercita a API contra o banco `vettip12`.

Os testes que **gravam** rodam dentro de uma transação que é desfeita no fim:
a cópia migrada não pode sair diferente de como entrou.
"""
import os
from datetime import datetime, timezone

import pytest
from fastapi.testclient import TestClient

os.environ.setdefault("VF_APPLY", "1")

from app import config, db, protheus  # noqa: E402
from app.main import app  # noqa: E402
from app.schemas import (  # noqa: E402
    AberturaOpMutation,
    BaixaProducaoMutation,
    EmpenhoMutation,
    TransferenciaMutation,
)

FILIAL = "04"
AGORA = datetime.now(timezone.utc)


@pytest.fixture(scope="session")
def cliente():
    db.preparar_banco()
    with TestClient(app) as c:
        yield c


@pytest.fixture
def conn():
    """Conexão que sempre desfaz o que fez."""
    with db.conexao() as c:
        yield c
        c.rollback()


def _produto_com_estrutura(conn) -> str:
    linha = conn.execute(
        f"""
        SELECT btrim(c2_produto) AS produto
        FROM {config.tabela('SC2')}
        WHERE d_e_l_e_t_ <> '*' AND c2_datrf = '' AND c2_filial = %s
        LIMIT 1
        """,
        (FILIAL,),
    ).fetchone()
    return linha["produto"]


def _op_em_aberto(conn) -> tuple[str, str]:
    linha = conn.execute(
        f"""
        SELECT btrim(d.d4_op) AS op, btrim(d.d4_cod) AS produto,
               btrim(d.d4_local) AS local
        FROM {config.tabela('SD4')} d
        WHERE d.d_e_l_e_t_ <> '*' AND d.d4_filial = %s
        LIMIT 1
        """,
        (FILIAL,),
    ).fetchone()
    return linha["op"], linha["produto"], linha["local"]


def _op_para_baixa(conn, folga_minima: float = 2) -> dict:
    """Uma OP aberta com pelo menos um componente empenhado e folga suficiente
    entre `C2_QUANT` e `C2_QUJE` para testar baixa parcial sem fechar a OP."""
    linha = conn.execute(
        f"""
        SELECT btrim(c.c2_num) AS numero, btrim(c.c2_item) AS item,
               btrim(c.c2_sequen) AS sequencia, btrim(c.c2_produto) AS produto,
               c.c2_quant AS quant, coalesce(c.c2_quje, 0) AS quje,
               btrim(c.c2_local) AS local
        FROM {config.tabela('SC2')} c
        WHERE c.d_e_l_e_t_ <> '*' AND c.c2_filial = %s AND btrim(c.c2_datrf) = ''
          AND c.c2_quant - coalesce(c.c2_quje, 0) >= %s
          AND EXISTS (
              SELECT 1 FROM {config.tabela('SD4')} d
              WHERE d.d_e_l_e_t_ <> '*' AND d.d4_filial = c.c2_filial
                AND btrim(d.d4_op) = btrim(c.c2_num) || btrim(c.c2_item)
                                      || btrim(c.c2_sequen)
          )
        ORDER BY (c.c2_quant - coalesce(c.c2_quje, 0)) DESC
        LIMIT 1
        """,
        (FILIAL, folga_minima),
    ).fetchone()
    op = linha["numero"] + linha["item"] + linha["sequencia"]
    componente = conn.execute(
        f"""
        SELECT btrim(d4_cod) AS produto, btrim(d4_local) AS local, d4_quant
        FROM {config.tabela('SD4')}
        WHERE d_e_l_e_t_ <> '*' AND d4_filial = %s AND btrim(d4_op) = %s
        LIMIT 1
        """,
        (FILIAL, op),
    ).fetchone()
    return {
        "op": op,
        "produto": linha["produto"],
        "local": linha["local"],
        "quant": linha["quant"],
        "quje": linha["quje"],
        "componente_produto": componente["produto"],
        "componente_local": componente["local"],
        "componente_quant": componente["d4_quant"],
    }


class TestSaude:
    def test_health_responde_e_diz_onde_grava(self, cliente):
        r = cliente.get("/api/v1/health")

        assert r.status_code == 200
        corpo = r.json()
        assert corpo["ok"] is True
        assert corpo["banco"] == "vettip12"
        assert corpo["empresa"] == "010"


class TestLeituraAoVivo:
    """Endpoints que o app passou a consultar direto no banco (03/08/2026),
    em vez de só ler o retrato estático embarcado."""

    def test_ops_abertas_bate_com_a_contagem_real(self, cliente, conn):
        esperado = conn.execute(
            f"SELECT count(*) AS n FROM {config.tabela('SC2')} "
            "WHERE d_e_l_e_t_ <> '*' AND c2_filial = %s AND btrim(c2_datrf) = ''",
            (FILIAL,),
        ).fetchone()["n"]

        r = cliente.get(f"/api/v1/ops/abertas?filial={FILIAL}")

        assert r.status_code == 200
        corpo = r.json()
        assert len(corpo) == esperado
        # Toda linha vem marcada como aberta, no formato dd/mm/aaaa esperado
        # pelo `ProtheusOrder.fromJson` do app.
        assert all(not linha["encerrada"] for linha in corpo)
        com_data = [linha for linha in corpo if linha["emissao"]]
        assert com_data, "esperava pelo menos uma OP com emissão preenchida"
        assert all(len(linha["emissao"]) == 10 for linha in com_data)

    def test_empenhos_da_op_traz_quantidade_original(self, cliente, conn):
        op, produto, local = _op_em_aberto(conn)
        esperado = conn.execute(
            f"SELECT d4_qtdeori AS qtdeori FROM {config.tabela('SD4')} "
            "WHERE d4_filial = %s AND btrim(d4_op) = %s AND btrim(d4_cod) = %s "
            "AND d4_local = %s",
            (FILIAL, op, produto, local),
        ).fetchone()["qtdeori"]

        r = cliente.get(f"/api/v1/ops/{op}/empenhos?filial={FILIAL}")

        assert r.status_code == 200
        linha = next(l for l in r.json() if l["produto"] == produto)
        assert linha["quantidadeOriginal"] == pytest.approx(esperado)
        # A resposta não deve mais trazer o campo antigo `saldo`, que estava
        # errado (D4_SLDEMP, quase sempre zero, de outro fluxo).
        assert "saldo" not in linha


class TestAberturaOp:
    def test_a_op_nasce_com_numero_do_protheus(self, conn):
        produto = _produto_com_estrutura(conn)
        antes = db.proximo_numero_op(conn, config.tabela("SC2"), FILIAL)

        mutacao = AberturaOpMutation(
            id="teste-abertura-1",
            kind="aberturaOp",
            filial=FILIAL,
            criadoEm=AGORA,
            autor="teste",
            payload={
                "produto": produto,
                "quantidade": 10,
                "localProducao": "01",
                "previsao": "15/08/2026",
            },
        )

        ref, _ = protheus.abrir_op(conn, mutacao)

        # O numero e do ERP, nao do app: proximo da sequencia da filial.
        assert ref == f"{antes}01001"
        assert len(ref) == 11

        linha = conn.execute(
            f"SELECT c2_produto, c2_quant, c2_datprf FROM {config.tabela('SC2')} "
            "WHERE c2_filial = %s AND c2_num = %s",
            (FILIAL, antes),
        ).fetchone()
        assert linha["c2_quant"] == 10
        assert linha["c2_datprf"] == "20260815"

    def test_sem_empenhos_no_pedido_vale_a_estrutura_do_produto(self, conn):
        produto = _produto_com_estrutura(conn)
        esperado = len(protheus._estrutura(conn, produto))

        mutacao = AberturaOpMutation(
            id="teste-abertura-2",
            kind="aberturaOp",
            filial=FILIAL,
            criadoEm=AGORA,
            autor="teste",
            payload={
                "produto": produto,
                "quantidade": 5,
                "localProducao": "01",
            },
        )

        ref, _ = protheus.abrir_op(conn, mutacao)

        linhas = conn.execute(
            f"SELECT count(*) AS n FROM {config.tabela('SD4')} "
            "WHERE d4_filial = %s AND btrim(d4_op) = %s",
            (FILIAL, ref),
        ).fetchone()
        assert linhas["n"] == esperado

    def test_empenhos_do_pedido_substituem_a_estrutura(self, conn):
        produto = _produto_com_estrutura(conn)

        mutacao = AberturaOpMutation(
            id="teste-abertura-3",
            kind="aberturaOp",
            filial=FILIAL,
            criadoEm=AGORA,
            autor="teste",
            payload={
                "produto": produto,
                "quantidade": 5,
                "localProducao": "01",
                "empenhos": [
                    {"produto": "100-003", "quantidade": 20, "local": "01"},
                ],
            },
        )

        ref, _ = protheus.abrir_op(conn, mutacao)

        linhas = conn.execute(
            f"SELECT btrim(d4_cod) AS cod, d4_quant FROM {config.tabela('SD4')} "
            "WHERE d4_filial = %s AND btrim(d4_op) = %s",
            (FILIAL, ref),
        ).fetchall()
        assert len(linhas) == 1
        assert linhas[0]["cod"] == "100-003"
        assert linhas[0]["d4_quant"] == 20

    def test_produto_inexistente_e_recusado(self, conn):
        mutacao = AberturaOpMutation(
            id="teste-abertura-4",
            kind="aberturaOp",
            filial=FILIAL,
            criadoEm=AGORA,
            autor="teste",
            payload={
                "produto": "NAO-EXISTE",
                "quantidade": 5,
                "localProducao": "01",
            },
        )

        with pytest.raises(protheus.RecusaProtheus, match="não existe"):
            protheus.abrir_op(conn, mutacao)

    def test_data_fora_do_formato_e_recusada(self, conn):
        mutacao = AberturaOpMutation(
            id="teste-abertura-5",
            kind="aberturaOp",
            filial=FILIAL,
            criadoEm=AGORA,
            autor="teste",
            payload={
                "produto": _produto_com_estrutura(conn),
                "quantidade": 5,
                "localProducao": "01",
                "previsao": "2026-08-15",
            },
        )

        with pytest.raises(protheus.RecusaProtheus, match="dd/mm/aaaa"):
            protheus.abrir_op(conn, mutacao)


class TestEmpenho:
    def test_alterar_quantidade_ajusta_o_empenhado_na_sb2(self, conn):
        op, produto, local = _op_em_aberto(conn)
        original = conn.execute(
            f"SELECT d4_quant FROM {config.tabela('SD4')} "
            "WHERE d4_filial = %s AND btrim(d4_op) = %s AND btrim(d4_cod) = %s "
            "AND d4_local = %s",
            (FILIAL, op, produto, local),
        ).fetchone()["d4_quant"]
        antes = protheus._saldo(conn, FILIAL, produto, local)
        emp_antes = antes["b2_qemp"] if antes else 0

        nova = original + 100
        mutacao = EmpenhoMutation(
            id="teste-empenho-1",
            kind="empenho",
            filial=FILIAL,
            criadoEm=AGORA,
            autor="teste",
            payload={
                "op": op,
                "operacao": "alterar",
                "produto": produto,
                "local": local,
                "quantidade": nova,
                "quantidadeAnterior": original,
            },
        )

        protheus.alterar_empenho(conn, mutacao)

        depois = protheus._saldo(conn, FILIAL, produto, local)
        # A reserva sobe exatamente o que o empenho subiu.
        assert depois["b2_qemp"] == pytest.approx(emp_antes + 100)

    def test_excluir_devolve_a_reserva_ao_saldo(self, conn):
        op, produto, local = _op_em_aberto(conn)
        original = conn.execute(
            f"SELECT d4_quant FROM {config.tabela('SD4')} "
            "WHERE d4_filial = %s AND btrim(d4_op) = %s AND btrim(d4_cod) = %s "
            "AND d4_local = %s",
            (FILIAL, op, produto, local),
        ).fetchone()["d4_quant"]
        antes = protheus._saldo(conn, FILIAL, produto, local)
        emp_antes = antes["b2_qemp"] if antes else 0

        mutacao = EmpenhoMutation(
            id="teste-empenho-2",
            kind="empenho",
            filial=FILIAL,
            criadoEm=AGORA,
            autor="teste",
            payload={
                "op": op,
                "operacao": "excluir",
                "produto": produto,
                "local": local,
            },
        )

        protheus.alterar_empenho(conn, mutacao)

        restante = conn.execute(
            f"SELECT count(*) AS n FROM {config.tabela('SD4')} "
            "WHERE d4_filial = %s AND btrim(d4_op) = %s AND btrim(d4_cod) = %s "
            "AND d4_local = %s",
            (FILIAL, op, produto, local),
        ).fetchone()["n"]
        assert restante == 0

        depois = protheus._saldo(conn, FILIAL, produto, local)
        assert depois["b2_qemp"] == pytest.approx(emp_antes - original)

    def test_excluir_empenho_inexistente_e_recusado(self, conn):
        op, _, local = _op_em_aberto(conn)

        mutacao = EmpenhoMutation(
            id="teste-empenho-3",
            kind="empenho",
            filial=FILIAL,
            criadoEm=AGORA,
            autor="teste",
            payload={
                "op": op,
                "operacao": "excluir",
                "produto": "100-003",
                "local": "99",
            },
        )

        with pytest.raises(protheus.RecusaProtheus, match="não existe"):
            protheus.alterar_empenho(conn, mutacao)


class TestTransferencia:
    def test_move_saldo_entre_armazens(self, conn):
        produto = "100-003"
        origem, destino = "01", "05"
        antes_o = protheus._saldo(conn, FILIAL, produto, origem)
        antes_d = protheus._saldo(conn, FILIAL, produto, destino)
        saldo_o = antes_o["b2_qatu"] if antes_o else 0
        saldo_d = antes_d["b2_qatu"] if antes_d else 0

        mutacao = TransferenciaMutation(
            id="teste-transf-1",
            kind="transferencia",
            filial=FILIAL,
            criadoEm=AGORA,
            autor="teste",
            payload={
                "produto": produto,
                "quantidade": 30,
                "localOrigem": origem,
                "localDestino": destino,
            },
        )

        protheus.transferir(conn, mutacao)

        depois_o = protheus._saldo(conn, FILIAL, produto, origem)
        depois_d = protheus._saldo(conn, FILIAL, produto, destino)
        assert depois_o["b2_qatu"] == pytest.approx(saldo_o - 30)
        assert depois_d["b2_qatu"] == pytest.approx(saldo_d + 30)

    def test_o_empenhado_nao_se_move_junto(self, conn):
        produto = "100-003"
        antes = protheus._saldo(conn, FILIAL, produto, "01")
        emp_antes = antes["b2_qemp"] if antes else 0

        protheus.transferir(
            conn,
            TransferenciaMutation(
                id="teste-transf-2",
                kind="transferencia",
                filial=FILIAL,
                criadoEm=AGORA,
                autor="teste",
                payload={
                    "produto": produto,
                    "quantidade": 10,
                    "localOrigem": "01",
                    "localDestino": "05",
                },
            ),
        )

        depois = protheus._saldo(conn, FILIAL, produto, "01")
        assert depois["b2_qemp"] == pytest.approx(emp_antes)

    def test_destino_sem_posicao_de_estoque_e_criado(self, conn):
        produto = "100-003"
        # Almoxarifado onde este produto nunca esteve.
        destino = "08"
        conn.execute(
            f"DELETE FROM {config.tabela('SB2')} "
            "WHERE b2_filial = %s AND btrim(b2_cod) = %s AND b2_local = %s",
            (FILIAL, produto, destino),
        )

        protheus.transferir(
            conn,
            TransferenciaMutation(
                id="teste-transf-3",
                kind="transferencia",
                filial=FILIAL,
                criadoEm=AGORA,
                autor="teste",
                payload={
                    "produto": produto,
                    "quantidade": 7,
                    "localOrigem": "01",
                    "localDestino": destino,
                },
            ),
        )

        criado = protheus._saldo(conn, FILIAL, produto, destino)
        assert criado is not None
        assert criado["b2_qatu"] == pytest.approx(7)

    def test_mesma_origem_e_destino_e_recusada(self, conn):
        with pytest.raises(protheus.RecusaProtheus, match="mesmo almoxarifado"):
            protheus.transferir(
                conn,
                TransferenciaMutation(
                    id="teste-transf-4",
                    kind="transferencia",
                    filial=FILIAL,
                    criadoEm=AGORA,
                    autor="teste",
                    payload={
                        "produto": "100-003",
                        "quantidade": 5,
                        "localOrigem": "01",
                        "localDestino": "01",
                    },
                ),
            )

    def test_saldo_negativo_e_permitido(self, conn):
        # O Protheus aceita, e a produção precisa disso quando o material está
        # a caminho. A API não pode ser mais rígida que o ERP.
        produto = "100-003"
        saldo = protheus._saldo(conn, FILIAL, produto, "01")["b2_qatu"]

        protheus.transferir(
            conn,
            TransferenciaMutation(
                id="teste-transf-5",
                kind="transferencia",
                filial=FILIAL,
                criadoEm=AGORA,
                autor="teste",
                payload={
                    "produto": produto,
                    "quantidade": saldo + 1000,
                    "localOrigem": "01",
                    "localDestino": "05",
                },
            ),
        )

        depois = protheus._saldo(conn, FILIAL, produto, "01")
        assert depois["b2_qatu"] < 0


class TestBaixaProducao:
    """SD3 (PR0+RE1) + C2_QUJE + D4_QUANT + SB2 dos dois lados."""

    def _mutacao(self, op_dados: dict, produzido: float, consumido: float):
        return BaixaProducaoMutation(
            id=f"teste-baixa-{op_dados['op']}-{produzido}",
            kind="baixaProducao",
            filial=FILIAL,
            criadoEm=AGORA,
            autor="teste",
            payload={
                "op": op_dados["op"],
                "produto": op_dados["produto"],
                "quantidadeProduzida": produzido,
                "localProducao": op_dados["local"],
                "componentes": [
                    {
                        "produto": op_dados["componente_produto"],
                        "local": op_dados["componente_local"],
                        "quantidade": consumido,
                    }
                ],
            },
        )

    def test_baixa_parcial_grava_sd3_desconta_sd4_e_soma_quje_sem_fechar(
        self, conn
    ):
        dados = _op_para_baixa(conn)
        antes_saldo_pa = protheus._saldo(conn, FILIAL, dados["produto"], dados["local"])
        antes_saldo_comp = protheus._saldo(
            conn, FILIAL, dados["componente_produto"], dados["componente_local"]
        )
        qatu_pa_antes = antes_saldo_pa["b2_qatu"] if antes_saldo_pa else 0
        qatu_comp_antes = antes_saldo_comp["b2_qatu"] if antes_saldo_comp else 0
        qemp_comp_antes = antes_saldo_comp["b2_qemp"] if antes_saldo_comp else 0

        mutacao = self._mutacao(dados, produzido=1, consumido=2)
        ref, info = protheus.dar_baixa_producao(conn, mutacao)

        assert ref.startswith("SD3:")
        assert info["fechouOp"] is False
        doc = ref.split(":", 1)[1]

        linhas_sd3 = conn.execute(
            f"""
            SELECT btrim(d3_cf) AS cf, btrim(d3_cod) AS cod, d3_quant,
                   btrim(d3_local) AS local
            FROM {config.tabela('SD3')}
            WHERE d3_filial = %s AND btrim(d3_doc) = %s
            ORDER BY cf
            """,
            (FILIAL, doc),
        ).fetchall()
        assert len(linhas_sd3) == 2
        pr0 = next(l for l in linhas_sd3 if l["cf"] == "PR0")
        re1 = next(l for l in linhas_sd3 if l["cf"] == "RE1")
        assert pr0["cod"] == dados["produto"]
        assert pr0["d3_quant"] == pytest.approx(1)
        assert pr0["local"] == dados["local"]
        assert re1["cod"] == dados["componente_produto"]
        assert re1["d3_quant"] == pytest.approx(2)
        assert re1["local"] == dados["componente_local"]

        sd4_depois = conn.execute(
            f"SELECT d4_quant FROM {config.tabela('SD4')} "
            "WHERE d4_filial = %s AND btrim(d4_op) = %s AND btrim(d4_cod) = %s "
            "AND d4_local = %s",
            (
                FILIAL,
                dados["op"],
                dados["componente_produto"],
                dados["componente_local"],
            ),
        ).fetchone()
        assert sd4_depois["d4_quant"] == pytest.approx(
            dados["componente_quant"] - 2
        )

        depois_pa = protheus._saldo(conn, FILIAL, dados["produto"], dados["local"])
        assert depois_pa["b2_qatu"] == pytest.approx(qatu_pa_antes + 1)

        depois_comp = protheus._saldo(
            conn, FILIAL, dados["componente_produto"], dados["componente_local"]
        )
        assert depois_comp["b2_qatu"] == pytest.approx(qatu_comp_antes - 2)
        assert depois_comp["b2_qemp"] == pytest.approx(qemp_comp_antes - 2)

        sc2_depois = conn.execute(
            f"SELECT c2_quje, c2_datrf FROM {config.tabela('SC2')} "
            "WHERE c2_filial = %s AND c2_num = %s AND c2_item = %s "
            "AND c2_sequen = %s",
            (FILIAL, dados["op"][:6], dados["op"][6:8], dados["op"][8:11]),
        ).fetchone()
        assert sc2_depois["c2_quje"] == pytest.approx(dados["quje"] + 1)
        assert sc2_depois["c2_datrf"].strip() == ""

    def test_baixa_que_completa_o_total_fecha_a_op(self, conn):
        dados = _op_para_baixa(conn)
        restante = dados["quant"] - dados["quje"]

        mutacao = self._mutacao(dados, produzido=restante, consumido=1)
        ref, info = protheus.dar_baixa_producao(conn, mutacao)

        assert info["fechouOp"] is True
        sc2_depois = conn.execute(
            f"SELECT c2_quje, c2_datrf FROM {config.tabela('SC2')} "
            "WHERE c2_filial = %s AND c2_num = %s AND c2_item = %s "
            "AND c2_sequen = %s",
            (FILIAL, dados["op"][:6], dados["op"][6:8], dados["op"][8:11]),
        ).fetchone()
        assert sc2_depois["c2_quje"] == pytest.approx(dados["quant"])
        assert sc2_depois["c2_datrf"].strip() != ""

    def test_op_encerrada_e_recusada(self, conn):
        linha = conn.execute(
            f"""
            SELECT btrim(c2_num) AS numero, btrim(c2_item) AS item,
                   btrim(c2_sequen) AS sequencia, btrim(c2_produto) AS produto,
                   btrim(c2_local) AS local
            FROM {config.tabela('SC2')}
            WHERE d_e_l_e_t_ <> '*' AND c2_filial = %s AND btrim(c2_datrf) <> ''
            LIMIT 1
            """,
            (FILIAL,),
        ).fetchone()
        op = linha["numero"] + linha["item"] + linha["sequencia"]

        mutacao = BaixaProducaoMutation(
            id="teste-baixa-encerrada",
            kind="baixaProducao",
            filial=FILIAL,
            criadoEm=AGORA,
            autor="teste",
            payload={
                "op": op,
                "produto": linha["produto"],
                "quantidadeProduzida": 1,
                "localProducao": linha["local"],
                "componentes": [],
            },
        )

        with pytest.raises(protheus.RecusaProtheus, match="encerrada"):
            protheus.dar_baixa_producao(conn, mutacao)

    def test_componente_sem_empenho_na_op_e_recusado(self, conn):
        dados = _op_para_baixa(conn)
        mutacao = BaixaProducaoMutation(
            id="teste-baixa-sem-empenho",
            kind="baixaProducao",
            filial=FILIAL,
            criadoEm=AGORA,
            autor="teste",
            payload={
                "op": dados["op"],
                "produto": dados["produto"],
                "quantidadeProduzida": 1,
                "localProducao": dados["local"],
                "componentes": [
                    {"produto": "NAO-EMPENHADO", "local": "01", "quantidade": 1}
                ],
            },
        )

        with pytest.raises(protheus.RecusaProtheus, match="não existe"):
            protheus.dar_baixa_producao(conn, mutacao)


class TestFluxoDuasFases:
    """POST /mutations armazena; POST /finalizar aplica."""

    def test_mutations_armazena_sem_aplicar(self, cliente, conn):
        produto = _produto_com_estrutura(conn)

        r = cliente.post(
            "/api/v1/mutations",
            json={
                "mutations": [
                    {
                        "id": "teste-2fases-1",
                        "kind": "aberturaOp",
                        "filial": FILIAL,
                        "criadoEm": AGORA.isoformat(),
                        "autor": "teste",
                        "payload": {
                            "produto": produto,
                            "quantidade": 5,
                            "localProducao": "01",
                        },
                    }
                ]
            },
        )

        assert r.status_code == 200
        resultado = r.json()["results"][0]
        assert resultado["status"] == "armazenado"
        assert resultado["protheusRef"] is None

        linha = conn.execute(
            "SELECT status FROM vf_mutations WHERE id = 'teste-2fases-1'"
        ).fetchone()
        assert linha["status"] == "armazenado"

        conn.execute("DELETE FROM vf_mutations WHERE id = 'teste-2fases-1'")
        conn.commit()

    def test_finalizar_aplica_no_protheus(self, cliente, conn):
        produto = _produto_com_estrutura(conn)

        # 1. Armazena
        cliente.post(
            "/api/v1/mutations",
            json={
                "mutations": [
                    {
                        "id": "teste-2fases-2",
                        "kind": "aberturaOp",
                        "filial": FILIAL,
                        "criadoEm": AGORA.isoformat(),
                        "autor": "teste",
                        "payload": {
                            "produto": produto,
                            "quantidade": 3,
                            "localProducao": "01",
                        },
                    }
                ]
            },
        )

        # 2. Finaliza
        r = cliente.post(
            "/api/v1/finalizar",
            json={"ids": ["teste-2fases-2"]},
        )

        assert r.status_code == 200
        resultado = r.json()["results"][0]
        assert resultado["status"] == "enviado"
        assert resultado["protheusRef"] is not None

        # Limpa a OP, empenhos e auditoria criados pelo teste.
        ref = resultado["protheusRef"]
        sc2 = config.tabela("SC2")
        sd4 = config.tabela("SD4")
        num = ref[:6]
        conn.execute(f"DELETE FROM {sd4} WHERE d4_filial = %s AND btrim(d4_op) = %s", (FILIAL, ref))
        conn.execute(f"DELETE FROM {sc2} WHERE c2_filial = %s AND c2_num = %s", (FILIAL, num))
        conn.execute("DELETE FROM vf_mutations WHERE id = 'teste-2fases-2'")
        conn.commit()

    def test_reenviar_armazenada_retorna_mesmo_status(self, cliente, conn):
        produto = _produto_com_estrutura(conn)

        payload = {
            "mutations": [
                {
                    "id": "teste-2fases-3",
                    "kind": "aberturaOp",
                    "filial": FILIAL,
                    "criadoEm": AGORA.isoformat(),
                    "autor": "teste",
                    "payload": {
                        "produto": produto,
                        "quantidade": 1,
                        "localProducao": "01",
                    },
                }
            ]
        }

        r1 = cliente.post("/api/v1/mutations", json=payload)
        r2 = cliente.post("/api/v1/mutations", json=payload)

        assert r1.json()["results"][0]["status"] == "armazenado"
        assert r2.json()["results"][0]["status"] == "armazenado"

        conn.execute("DELETE FROM vf_mutations WHERE id = 'teste-2fases-3'")
        conn.commit()

    def test_finalizar_mutacao_inexistente_retorna_erro(self, cliente):
        r = cliente.post(
            "/api/v1/finalizar",
            json={"ids": ["nao-existe"]},
        )

        resultado = r.json()["results"][0]
        assert resultado["status"] == "erro"
        assert "não encontrada" in resultado["erro"]
