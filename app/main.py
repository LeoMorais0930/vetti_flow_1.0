"""API que leva a fila de mutações do VettiFlow até o Protheus.

O VettiFlow opera com o ERP fora do alcance: o chão de fábrica pede abertura de
OP, mexe em empenho e transfere entre armazéns, tudo em cache local. Esta API é
o transporte — recebe a fila e **armazena**. Só aplica nas tabelas do Protheus
quando a OP for finalizada pela Responsável.

Hoje aplica na cópia migrada em PostgreSQL (`vettip12`), para se ver o efeito
real nas tabelas antes de encostar em produção.
"""
import json
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from . import config, db, protheus
from .schemas import (
    BatchResult,
    FinalizarRequest,
    Health,
    MutationBatch,
    MutationResult,
    MutationStatus,
)

log = logging.getLogger("vetti_flow_api")

@asynccontextmanager
async def lifespan(_: FastAPI):
    db.preparar_banco()
    if not config.APPLY:
        log.warning("VF_APPLY=0 — validando sem gravar em SC2/SD4/SB2")
    yield


app = FastAPI(
    title="VettiFlow · Protheus",
    version="0.2.0",
    description=__doc__,
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/api/v1/health", response_model=Health)
def health() -> Health:
    with db.conexao() as conn:
        conn.execute("SELECT 1")
    return Health(
        ok=True,
        banco=config.DSN.rsplit("/", 1)[-1],
        aplicando=config.APPLY,
        empresa=config.EMPRESA,
    )


def _ja_existe(conn, id_: str) -> dict | None:
    return conn.execute(
        "SELECT protheus_ref, status FROM vf_mutations WHERE id = %s",
        (id_,),
    ).fetchone()


@app.post("/api/v1/mutations", response_model=BatchResult)
def armazenar(lote: MutationBatch) -> BatchResult:
    """Recebe um lote e **armazena** — não aplica no Protheus.

    As mutações ficam com status `armazenado` até que a OP seja finalizada
    pela Responsável via `POST /api/v1/finalizar`.
    """
    resultados: list[MutationResult] = []

    for mutacao in lote.mutations:
        with db.conexao() as conn:
            anterior = _ja_existe(conn, mutacao.id)
            if anterior:
                resultados.append(
                    MutationResult(
                        id=mutacao.id,
                        status=MutationStatus(anterior["status"]),
                        protheusRef=anterior["protheus_ref"],
                    )
                )
                continue

            _auditar(
                conn, mutacao, MutationStatus.armazenado, None, None, None
            )
            conn.commit()
            resultados.append(
                MutationResult(
                    id=mutacao.id,
                    status=MutationStatus.armazenado,
                )
            )

    return BatchResult(results=resultados)


@app.post("/api/v1/finalizar", response_model=BatchResult)
def finalizar(req: FinalizarRequest) -> BatchResult:
    """Aplica mutações armazenadas no Protheus.

    Chamado quando a Responsável finaliza a OP. Cada mutação é sua própria
    transação: uma recusa não derruba as outras.
    """
    resultados: list[MutationResult] = []

    for id_ in req.ids:
        with db.conexao() as conn:
            linha = conn.execute(
                "SELECT * FROM vf_mutations WHERE id = %s", (id_,)
            ).fetchone()

            if linha is None:
                resultados.append(
                    MutationResult(
                        id=id_,
                        status=MutationStatus.erro,
                        erro="Mutação não encontrada",
                    )
                )
                continue

            if linha["status"] == MutationStatus.enviado.value:
                resultados.append(
                    MutationResult(
                        id=id_,
                        status=MutationStatus.enviado,
                        protheusRef=linha["protheus_ref"],
                    )
                )
                continue

            if linha["status"] != MutationStatus.armazenado.value:
                resultados.append(
                    MutationResult(
                        id=id_,
                        status=MutationStatus(linha["status"]),
                        erro=f"Status atual é {linha['status']}, esperado armazenado",
                    )
                )
                continue

            payload = linha["payload"]
            kind = linha["kind"]
            mutacao = _reconstruir_mutacao(linha, payload)
            if mutacao is None:
                resultados.append(
                    MutationResult(
                        id=id_,
                        status=MutationStatus.erro,
                        erro=f"Kind desconhecido: {kind}",
                    )
                )
                continue

            aplicador = protheus.APLICADORES.get(kind)
            if aplicador is None:
                resultados.append(
                    MutationResult(
                        id=id_,
                        status=MutationStatus.erro,
                        erro=f"Aplicador não existe para kind={kind}",
                    )
                )
                continue

            try:
                if config.APPLY:
                    ref, antes = aplicador(conn, mutacao)
                else:
                    ref, antes = f"DRY:{kind}", {"dry_run": True}

                conn.execute(
                    """
                    UPDATE vf_mutations
                    SET status = %s, protheus_ref = %s, antes = %s,
                        aplicado_em = now()
                    WHERE id = %s
                    """,
                    (
                        MutationStatus.enviado.value,
                        ref,
                        json.dumps(antes, default=str) if antes else None,
                        id_,
                    ),
                )
                conn.commit()
                resultados.append(
                    MutationResult(
                        id=id_,
                        status=MutationStatus.enviado,
                        protheusRef=ref,
                    )
                )
            except protheus.RecusaProtheus as e:
                conn.rollback()
                with db.conexao() as auditoria:
                    auditoria.execute(
                        """
                        UPDATE vf_mutations
                        SET status = %s, erro = %s, aplicado_em = now()
                        WHERE id = %s
                        """,
                        (MutationStatus.erro.value, str(e), id_),
                    )
                    auditoria.commit()
                resultados.append(
                    MutationResult(
                        id=id_, status=MutationStatus.erro, erro=str(e)
                    )
                )
            except Exception as e:  # noqa: BLE001
                conn.rollback()
                log.exception("falha ao aplicar %s", id_)
                resultados.append(
                    MutationResult(
                        id=id_,
                        status=MutationStatus.erro,
                        erro=f"{type(e).__name__}: {e}",
                    )
                )

    return BatchResult(results=resultados)


def _reconstruir_mutacao(linha: dict, payload: dict):
    """Reconstrói o objeto de mutação a partir do que está no banco."""
    from datetime import datetime

    from .schemas import (
        AberturaOpMutation,
        AberturaOpPayload,
        BaixaProducaoMutation,
        BaixaProducaoPayload,
        EmpenhoMutation,
        EmpenhoPayload,
        TransferenciaMutation,
        TransferenciaPayload,
    )

    kind = linha["kind"]
    envelope = {
        "id": linha["id"],
        "filial": linha["filial"],
        "criadoEm": linha["criado_em"],
        "autor": linha["autor"],
    }

    if kind == "aberturaOp":
        return AberturaOpMutation(
            kind="aberturaOp",
            payload=AberturaOpPayload(**payload),
            **envelope,
        )
    if kind == "empenho":
        return EmpenhoMutation(
            kind="empenho",
            payload=EmpenhoPayload(**payload),
            **envelope,
        )
    if kind == "transferencia":
        return TransferenciaMutation(
            kind="transferencia",
            payload=TransferenciaPayload(**payload),
            **envelope,
        )
    if kind == "baixaProducao":
        return BaixaProducaoMutation(
            kind="baixaProducao",
            payload=BaixaProducaoPayload(**payload),
            **envelope,
        )
    return None


def _auditar(conn, mutacao, status, ref, erro, antes) -> None:
    conn.execute(
        """
        INSERT INTO vf_mutations
            (id, kind, filial, autor, criado_em, status, protheus_ref, erro,
             payload, antes)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT (id) DO UPDATE SET
            status = EXCLUDED.status,
            protheus_ref = EXCLUDED.protheus_ref,
            erro = EXCLUDED.erro,
            aplicado_em = now()
        """,
        (
            mutacao.id,
            mutacao.kind,
            mutacao.filial,
            mutacao.autor,
            mutacao.criadoEm,
            status.value,
            ref,
            erro,
            json.dumps(mutacao.payload.model_dump(mode="json")),
            json.dumps(antes, default=str) if antes is not None else None,
        ),
    )


@app.get("/api/v1/mutations/{id_}")
def consultar(id_: str) -> dict:
    with db.conexao() as conn:
        linha = conn.execute(
            "SELECT * FROM vf_mutations WHERE id = %s", (id_,)
        ).fetchone()
    return linha or {"erro": "não encontrada"}


@app.get("/api/v1/ops/{op}/empenhos")
def empenhos(op: str, filial: str = config.FILIAL_PADRAO) -> list[dict]:
    """O empenho real (SD4) de uma OP, ao vivo.

    `quantidade` é o D4_QUANT — o que **resta** do empenho, não o pedido
    original (achado em 03/08/2026 batendo contra a documentação do Protheus
    e a base real). `quantidadeOriginal` é o D4_QTDEORI, fixo desde a
    abertura da OP — serve só de contexto na tela ("418 de 500, 82 já
    produzidos"), não entra em conta de saldo nenhuma.
    """
    with db.conexao() as conn:
        return conn.execute(
            f"""
            SELECT btrim(d4_op) AS op, btrim(d4_cod) AS produto,
                   btrim(d4_local) AS local, d4_quant AS quantidade,
                   d4_qtdeori AS "quantidadeOriginal"
            FROM {config.tabela('SD4')}
            WHERE d_e_l_e_t_ <> '*' AND d4_filial = %s AND btrim(d4_op) = %s
            ORDER BY produto
            """,
            (filial, op),
        ).fetchall()


def _data_br(yyyymmdd: str | None) -> str | None:
    """`20260729` -> `29/07/2026`. Vazio ou fora do formato vira `None`."""
    valor = (yyyymmdd or "").strip()
    if len(valor) != 8:
        return None
    return f"{valor[6:8]}/{valor[4:6]}/{valor[0:4]}"


@app.get("/api/v1/ops/abertas")
def ops_abertas(filial: str = config.FILIAL_PADRAO) -> list[dict]:
    """OPs em aberto (C2_DATRF vazio) de uma filial, ao vivo.

    Mesmo formato de campos usado na extração de `ordens.json` no app —
    quem lê esta resposta no Flutter monta o mesmo `ProtheusOrder.fromJson`.
    """
    with db.conexao() as conn:
        linhas = conn.execute(
            f"""
            SELECT c2_filial AS filial, btrim(c2_num) AS numero,
                   btrim(c2_item) AS item, btrim(c2_sequen) AS sequencia,
                   btrim(c2_itemgrd) AS "itemGrade", btrim(c2_produto) AS produto,
                   c2_quant AS quantidade, btrim(c2_local) AS local,
                   c2_emissao AS emissao, c2_datprf AS previsao
            FROM {config.tabela('SC2')}
            WHERE d_e_l_e_t_ <> '*' AND c2_filial = %s AND btrim(c2_datrf) = ''
            ORDER BY numero, item, sequencia
            """,
            (filial,),
        ).fetchall()
    for linha in linhas:
        linha["emissao"] = _data_br(linha["emissao"])
        linha["previsao"] = _data_br(linha["previsao"])
        linha["encerrada"] = False
    return linhas


@app.get("/api/v1/produtos/{codigo}/saldos")
def saldos(codigo: str, filial: str = config.FILIAL_PADRAO) -> list[dict]:
    with db.conexao() as conn:
        return conn.execute(
            f"""
            SELECT btrim(b2_local) AS local, b2_qatu AS saldo,
                   b2_qemp AS empenhado
            FROM {config.tabela('SB2')}
            WHERE d_e_l_e_t_ <> '*' AND b2_filial = %s AND btrim(b2_cod) = %s
            ORDER BY local
            """,
            (filial, codigo),
        ).fetchall()


@app.get("/api/v1/ops/{op}/armazenadas")
def armazenadas_da_op(op: str) -> list[dict]:
    """Mutações armazenadas para uma OP, ainda não aplicadas."""
    with db.conexao() as conn:
        return conn.execute(
            """
            SELECT id, kind, filial, autor, criado_em, status, payload
            FROM vf_mutations
            WHERE status = %s
              AND (
                payload->>'op' = %s
                OR (kind = 'aberturaOp' AND id IN (
                    SELECT id FROM vf_mutations
                    WHERE status = %s AND kind = 'aberturaOp'
                ))
              )
            ORDER BY criado_em
            """,
            (MutationStatus.armazenado.value, op, MutationStatus.armazenado.value),
        ).fetchall()
