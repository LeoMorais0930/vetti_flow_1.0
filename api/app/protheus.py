"""Aplica as mutações do VettiFlow nas tabelas do Protheus.

O que cada uma toca:

- **abertura de OP**  -> SC2 (a ordem) + SD4 (os empenhos) + SB2 (`b2_qemp`)
- **empenho**         -> SD4 + SB2 (`b2_qemp`)
- **transferência**   -> SB2 (`b2_qatu` nas duas pontas) + SD3 (`RE4`/`DE4`)

Isto é o comportamento do Protheus reconstruído a partir das tabelas, não uma
chamada ao ERP. Existe para ver o efeito real das mutações — quais linhas
nascem, quais saldos se mexem — antes de encostar em produção. Quando a
integração de verdade existir, é esta camada que troca de dono: as funções
passam a chamar a rotina do Protheus (MATA650 e afins) em vez de escrever.
"""
from datetime import date

from . import config, db


class RecusaProtheus(Exception):
    """A mutação é inválida e o Protheus não a aceitaria.

    Diferente de um erro de infraestrutura: isto é uma recusa com motivo, que
    volta para a fila do app para o operador corrigir.
    """


_SF5_EXPECTED_TYPE = {
    "PR0": "P",
    "PR1": "P",
    "RE1": "R",
    "RE4": "R",
    "DE4": "D",
    # ER é estorno de produção, mas a SF5 só classifica como D/P/R. Mantemos
    # P até a SF5 real da Vetti dizer outro fluxo.
    "ER0": "P",
    "ER1": "P",
}


def _data_protheus(br: str | None) -> str:
    """`31/07/2026` -> `20260731`. Vazio vira hoje."""
    if not br:
        return date.today().strftime("%Y%m%d")
    partes = br.strip().split("/")
    if len(partes) != 3:
        raise RecusaProtheus(f"Data fora do formato dd/mm/aaaa: {br!r}")
    dia, mes, ano = partes
    if not (dia.isdigit() and mes.isdigit() and ano.isdigit()):
        raise RecusaProtheus(f"Data fora do formato dd/mm/aaaa: {br!r}")
    return f"{ano.zfill(4)}{mes.zfill(2)}{dia.zfill(2)}"


def _relacao_existe(conn, nome: str) -> bool:
    linha = conn.execute("SELECT to_regclass(%s) AS rel", (nome,)).fetchone()
    return linha is not None and linha["rel"] is not None


def _validar_tipo_movimento_sf5(conn, filial: str, cf: str) -> str:
    """Valida o tipo de movimento contra a SF5 e devolve o D3_TM.

    `D3_CF` guarda a família operacional (`PR0`, `RE1`, `RE4`, `DE4`), mas
    `D3_TM` precisa apontar para um `F5_CODIGO` real. Na VM, ligue
    `VF_REQUIRE_SF5_MOVEMENTS=1` e informe `VF_TM_RE1`/`VF_TM_PR0` etc.
    """
    cf = cf.strip().upper()
    tm = config.SF5_TM_BY_CF.get(cf, "").strip()
    esperado = _SF5_EXPECTED_TYPE.get(cf)

    if not config.REQUIRE_SF5_MOVEMENTS:
        return tm

    if esperado is None:
        raise RecusaProtheus(f"Tipo D3_CF {cf} não mapeado para validação SF5")
    if not tm:
        raise RecusaProtheus(
            f"Configure VF_TM_{cf} com o F5_CODIGO da SF5 antes de gravar {cf}"
        )

    sf5 = db.config.tabela("SF5")
    if not _relacao_existe(conn, sf5):
        raise RecusaProtheus(
            f"Tabela {sf5} não encontrada; não dá para validar D3_TM {tm}"
        )

    linha = conn.execute(
        f"""
        SELECT btrim(f5_codigo) AS codigo,
               btrim(f5_tipo) AS tipo,
               btrim(COALESCE(f5_texto, '')) AS descricao
        FROM {sf5}
        WHERE d_e_l_e_t_ <> '*'
          AND (btrim(f5_filial) = %s OR btrim(f5_filial) = '')
          AND btrim(f5_codigo) = %s
        ORDER BY CASE WHEN btrim(f5_filial) = %s THEN 0 ELSE 1 END
        LIMIT 1
        """,
        (filial, tm, filial),
    ).fetchone()
    if linha is None:
        raise RecusaProtheus(f"SF5 não tem F5_CODIGO {tm} para {cf}")
    if linha["tipo"] != esperado:
        raise RecusaProtheus(
            f"SF5 {tm} ({linha['descricao']}) é tipo {linha['tipo']}; "
            f"{cf} exige tipo {esperado}"
        )
    return tm


def _campos_movimento_sd3(conn, filial: str, cf: str) -> dict:
    tm = _validar_tipo_movimento_sf5(conn, filial, cf)
    return {
        "d3_cf": cf,
        **({"d3_tm": tm} if tm else {}),
    }


def _inserir_movimento_sd3(
    conn,
    *,
    filial: str,
    cf: str,
    produto: str,
    local: str,
    quantidade: float,
    doc: str,
    emissao: str,
    op: str = "",
) -> None:
    db.inserir(
        conn,
        db.config.tabela("SD3"),
        {
            "d3_filial": filial,
            **_campos_movimento_sd3(conn, filial, cf),
            "d3_cod": produto,
            "d3_local": local,
            "d3_quant": float(quantidade),
            "d3_doc": doc,
            "d3_emissao": emissao,
            "d3_op": op,
        },
    )


def _existe_produto(conn, codigo: str) -> bool:
    linha = conn.execute(
        f"SELECT 1 FROM {db.config.tabela('SB1')} "
        "WHERE btrim(b1_cod) = %s AND d_e_l_e_t_ <> '*' LIMIT 1",
        (codigo,),
    ).fetchone()
    return linha is not None


def _estrutura(conn, produto: str) -> list[dict]:
    """A estrutura vigente do produto (SG1).

    A vigência (`G1_INI`/`G1_FIM`) faz parte da chave: sem esse filtro vêm
    componentes de revisões antigas junto com os atuais.
    """
    hoje = date.today().strftime("%Y%m%d")
    return conn.execute(
        f"""
        SELECT btrim(g1_comp) AS componente,
               g1_quant AS quantidade,
               btrim(COALESCE(g1_trt, '')) AS estrutura
        FROM {db.config.tabela('SG1')}
        WHERE d_e_l_e_t_ <> '*'
          AND btrim(g1_cod) = %s
          AND btrim(g1_ini) <= %s
          AND (btrim(g1_fim) = '' OR btrim(g1_fim) >= %s)
        ORDER BY componente
        """,
        (produto, hoje, hoje),
    ).fetchall()


def _saldo(conn, filial: str, produto: str, local: str) -> dict | None:
    return conn.execute(
        f"SELECT b2_qatu, b2_qemp FROM {db.config.tabela('SB2')} "
        "WHERE b2_filial = %s AND btrim(b2_cod) = %s AND b2_local = %s "
        "AND d_e_l_e_t_ <> '*'",
        (filial, produto, local),
    ).fetchone()


def _mexer_saldo(
    conn, filial: str, produto: str, local: str, *, qatu=0.0, qemp=0.0
) -> None:
    """Soma nos saldos da SB2, criando a posição se ela ainda não existe.

    Criar é o que o Protheus faz quando um produto chega a um almoxarifado onde
    nunca esteve.
    """
    sb2 = db.config.tabela("SB2")
    atual = _saldo(conn, filial, produto, local)
    if atual is None:
        db.inserir(
            conn,
            sb2,
            {
                "b2_filial": filial,
                "b2_cod": produto,
                "b2_local": local,
                "b2_qatu": qatu,
                "b2_qemp": qemp,
            },
        )
        return
    conn.execute(
        f"UPDATE {sb2} SET b2_qatu = b2_qatu + %s, b2_qemp = b2_qemp + %s "
        "WHERE b2_filial = %s AND btrim(b2_cod) = %s AND b2_local = %s",
        (qatu, qemp, filial, produto, local),
    )


# --------------------------------------------------------------------------
# Abertura de OP
# --------------------------------------------------------------------------


def abrir_op(conn, mutacao) -> tuple[str, dict]:
    """Cria a OP na SC2 com seus empenhos na SD4.

    Devolve `(referência, estado_anterior)`. A referência é a OP concatenada
    (`015963` + `01` + `001`), que é o número que o app passa a conhecer.
    """
    p = mutacao.payload
    filial = mutacao.filial

    if not _existe_produto(conn, p.produto):
        raise RecusaProtheus(f"Produto {p.produto} não existe no cadastro")
    if p.quantidade <= 0:
        raise RecusaProtheus("Quantidade da OP precisa ser maior que zero")

    sc2 = db.config.tabela("SC2")
    numero = db.proximo_numero_op(conn, sc2, filial)
    item, sequencia = "01", "001"
    emissao = date.today().strftime("%Y%m%d")
    previsao = _data_protheus(p.previsao)

    db.inserir(
        conn,
        sc2,
        {
            "c2_filial": filial,
            "c2_num": numero,
            "c2_item": item,
            "c2_sequen": sequencia,
            "c2_produto": p.produto,
            "c2_quant": float(p.quantidade),
            "c2_emissao": emissao,
            "c2_datprf": previsao,
            "c2_local": p.localProducao,
            # C2_STATUS tem só três valores possíveis no Protheus: U
            # (Suspensa), S (Sacramentada/encerrada) e N (Normal — ativa, não
            # "não iniciada" como uma versão antiga deste comentário dizia).
            # `F` (firme) e `N` são o que as 12.316 linhas reais da Vetti na
            # filial 04 trazem — nenhuma delas é U ou S.
            "c2_tpop": "F",
            "c2_status": "N",
            "c2_obs": (p.observacao or "")[:60],
        },
    )

    op = f"{numero}{item}{sequencia}"

    # Sem empenho no pedido, vale a estrutura do produto — é o que o Protheus
    # faz sozinho ao abrir a OP.
    linhas = p.empenhos or [
        type(
            "L",
            (),
            {
                "produto": e["componente"],
                "quantidade": float(e["quantidade"] or 0) * p.quantidade,
                "local": p.localProducao,
                "estrutura": e.get("estrutura") or "",
            },
        )()
        for e in _estrutura(conn, p.produto)
    ]

    for linha in linhas:
        _incluir_empenho(
            conn,
            filial=filial,
            op=op,
            produto=linha.produto,
            produto_pai=p.produto,
            local=linha.local,
            quantidade=float(linha.quantidade),
            data=emissao,
            estrutura=(
                getattr(linha, "structureSequence", None)
                or getattr(linha, "estrutura", None)
                or ""
            ),
        )

    return op, {"criou_op": op, "empenhos": len(list(linhas))}


# --------------------------------------------------------------------------
# Empenhos
# --------------------------------------------------------------------------


def _produto_da_op(conn, filial: str, op: str) -> str:
    if len(op) != 11:
        return ""
    numero, item, sequencia = op[:6], op[6:8], op[8:11]
    linha = conn.execute(
        f"""
        SELECT btrim(c2_produto) AS produto
        FROM {db.config.tabela('SC2')}
        WHERE c2_filial = %s AND c2_num = %s AND c2_item = %s
          AND c2_sequen = %s AND d_e_l_e_t_ <> '*'
        LIMIT 1
        """,
        (filial, numero, item, sequencia),
    ).fetchone()
    return linha["produto"] if linha else ""


def _sd4_commitment_values(
    *,
    filial: str,
    op: str,
    produto: str,
    produto_pai: str,
    local: str,
    quantidade: float,
    data: str,
    estrutura: str = "",
) -> dict:
    return {
        "d4_filial": filial,
        "d4_op": op,
        "d4_cod": produto,
        "d4_produto": produto_pai,
        "d4_local": local,
        "d4_quant": quantidade,
        "d4_qtdeori": quantidade,
        "d4_sldemp": 0,
        "d4_sldemp2": 0,
        "d4_qtneces": 0,
        "d4_qsusp": 0,
        "d4_qtsegum": 0,
        "d4_data": data,
        "d4_roteiro": "01",
        "d4_trt": estrutura,
        "d_e_l_e_t_": "",
        "r_e_c_d_e_l_": 0,
    }


def _incluir_empenho(
    conn, *, filial: str, op: str, produto: str, local: str,
    quantidade: float, data: str, produto_pai: str = "",
    estrutura: str = "",
) -> None:
    values = _sd4_commitment_values(
        filial=filial,
        op=op,
        produto=produto,
        produto_pai=produto_pai or _produto_da_op(conn, filial, op),
        local=local,
        quantidade=quantidade,
        data=data,
        estrutura=estrutura,
    )
    db.inserir(
        conn,
        db.config.tabela("SD4"),
        values,
    )
    # Empenhar reserva saldo: sobe `b2_qemp` sem mexer no que há fisicamente.
    _mexer_saldo(conn, filial, produto, local, qemp=quantidade)


def alterar_empenho(conn, mutacao) -> tuple[str, dict]:
    p = mutacao.payload
    filial = mutacao.filial
    sd4 = db.config.tabela("SD4")
    local_anterior = p.localAnterior or p.local

    atual = conn.execute(
        f"SELECT d4_quant, d4_local FROM {sd4} "
        "WHERE d4_filial = %s AND btrim(d4_op) = %s AND btrim(d4_cod) = %s "
        "AND d4_local = %s AND d_e_l_e_t_ <> '*'",
        (filial, p.op, p.produto, local_anterior),
    ).fetchone()

    antes = (
        {"quantidade": atual["d4_quant"], "local": atual["d4_local"]}
        if atual
        else None
    )

    if p.operacao == "excluir" or getattr(p.operacao, "value", None) == "excluir":
        if atual is None:
            raise RecusaProtheus(
                f"Empenho de {p.produto} no almox. {local_anterior} "
                f"não existe na OP {p.op}"
            )
        conn.execute(
            f"DELETE FROM {sd4} WHERE d4_filial = %s AND btrim(d4_op) = %s "
            "AND btrim(d4_cod) = %s AND d4_local = %s",
            (filial, p.op, p.produto, local_anterior),
        )
        # Devolve a reserva ao saldo.
        _mexer_saldo(
            conn, filial, p.produto, local_anterior,
            qemp=-float(atual["d4_quant"]),
        )
        return f"SD4:{p.op}:{p.produto}", {"removeu": antes}

    if p.quantidade <= 0:
        raise RecusaProtheus("Quantidade do empenho precisa ser maior que zero")

    if atual is None:
        # Alterar o que não existe vira inclusão: é o efeito que o operador
        # pediu, e recusar aqui só o obrigaria a repetir o pedido de outro
        # jeito.
        _incluir_empenho(
            conn,
            filial=filial,
            op=p.op,
            produto=p.produto,
            local=p.local,
            quantidade=p.quantidade,
            data=date.today().strftime("%Y%m%d"),
        )
        return f"SD4:{p.op}:{p.produto}", {"incluiu": True}

    if p.local != local_anterior:
        # Mudar de almoxarifado é mover a linha: a reserva sai de um lugar e
        # entra no outro.
        conn.execute(
            f"UPDATE {sd4} SET d4_local = %s, d4_quant = %s, "
            "d4_sldemp = 0, d4_sldemp2 = 0, d4_qtneces = 0 "
            "WHERE d4_filial = %s AND btrim(d4_op) = %s AND btrim(d4_cod) = %s "
            "AND d4_local = %s",
            (p.local, p.quantidade, filial, p.op, p.produto,
             local_anterior),
        )
        _mexer_saldo(
            conn, filial, p.produto, local_anterior,
            qemp=-float(atual["d4_quant"]),
        )
        _mexer_saldo(conn, filial, p.produto, p.local, qemp=p.quantidade)
    else:
        conn.execute(
            f"UPDATE {sd4} SET d4_quant = %s, d4_sldemp = 0, "
            "d4_sldemp2 = 0, d4_qtneces = 0 "
            "WHERE d4_filial = %s AND btrim(d4_op) = %s AND btrim(d4_cod) = %s "
            "AND d4_local = %s",
            (p.quantidade, filial, p.op, p.produto, p.local),
        )
        _mexer_saldo(
            conn, filial, p.produto, p.local,
            qemp=p.quantidade - float(atual["d4_quant"]),
        )

    return f"SD4:{p.op}:{p.produto}", {"antes": antes}


# --------------------------------------------------------------------------
# Transferência entre armazéns
# --------------------------------------------------------------------------


def transferir(conn, mutacao) -> tuple[str, dict]:
    p = mutacao.payload
    filial = mutacao.filial

    if p.localOrigem == p.localDestino:
        raise RecusaProtheus("Origem e destino são o mesmo almoxarifado")
    if p.quantidade <= 0:
        raise RecusaProtheus("Quantidade da transferência precisa ser positiva")
    if not _existe_produto(conn, p.produto):
        raise RecusaProtheus(f"Produto {p.produto} não existe no cadastro")

    origem = _saldo(conn, filial, p.produto, p.localOrigem)
    antes = {
        "origem": dict(origem) if origem else None,
        "destino": dict(_saldo(conn, filial, p.produto, p.localDestino) or {}),
    }

    # Saldo negativo é permitido no Protheus e acontece de verdade quando o
    # material está a caminho — a API não bloqueia o que o ERP aceita.
    sd3 = db.config.tabela("SD3")
    doc = f"TR{db.proximo_recno(conn, sd3):07d}"
    emissao = date.today().strftime("%Y%m%d")

    _inserir_movimento_sd3(
        conn,
        filial=filial,
        cf="RE4",
        produto=p.produto,
        local=p.localOrigem,
        quantidade=p.quantidade,
        doc=doc,
        emissao=emissao,
        op=getattr(p, "op", "") or "",
    )
    _inserir_movimento_sd3(
        conn,
        filial=filial,
        cf="DE4",
        produto=p.produto,
        local=p.localDestino,
        quantidade=p.quantidade,
        doc=doc,
        emissao=emissao,
        op=getattr(p, "op", "") or "",
    )
    _mexer_saldo(conn, filial, p.produto, p.localOrigem, qatu=-p.quantidade)
    _mexer_saldo(conn, filial, p.produto, p.localDestino, qatu=p.quantidade)

    ref = f"SD3:{doc}"
    return ref, antes


# --------------------------------------------------------------------------
# Baixa de produção
# --------------------------------------------------------------------------


def dar_baixa_producao(conn, mutacao) -> tuple[str, dict]:
    """Aponta produção de uma OP: entrada do produto acabado + consumo dos
    componentes.

    Espelha o que a SD3 registra de verdade: uma linha `D3_CF='PR0'` (produto
    acabado) e uma `D3_CF='RE1'` por componente, todas com o mesmo `D3_DOC` —
    conferido contra a base real (OP 015961/filial 04: produziu 82, o
    componente MOD08010201006 consumiu 82 × 4.17 ÷ 500 = 0.68, exatamente
    D4_QTDEORI ÷ C2_QUANT).

    O consumo de cada componente já vem calculado do app, proporcional ao
    empenho real da OP — aqui só se aplica: `D4_QUANT` desconta, a SB2 do
    componente sai fisicamente **e** libera o empenho (`b2_qatu` e `b2_qemp`
    juntos, porque o que saiu foi consumido, não só movido), e a SB2 do
    produto acabado recebe a entrada.
    """
    p = mutacao.payload
    filial = mutacao.filial

    if p.quantidadeProduzida <= 0:
        raise RecusaProtheus("Quantidade produzida precisa ser maior que zero")
    if len(p.op) != 11:
        raise RecusaProtheus(f"OP fora do formato esperado: {p.op!r}")

    numero, item, sequencia = p.op[:6], p.op[6:8], p.op[8:11]
    sc2 = db.config.tabela("SC2")
    sd3 = db.config.tabela("SD3")
    sd4 = db.config.tabela("SD4")

    op_sc2 = conn.execute(
        f"SELECT c2_quant, c2_quje, c2_datrf FROM {sc2} "
        "WHERE c2_filial = %s AND c2_num = %s AND c2_item = %s "
        "AND c2_sequen = %s AND d_e_l_e_t_ <> '*'",
        (filial, numero, item, sequencia),
    ).fetchone()
    if op_sc2 is None:
        raise RecusaProtheus(f"OP {p.op} não existe na filial {filial}")
    if op_sc2["c2_datrf"].strip():
        raise RecusaProtheus(f"OP {p.op} já está encerrada")

    doc = f"BX{db.proximo_recno(conn, sd3):07d}"
    emissao = date.today().strftime("%Y%m%d")

    _inserir_movimento_sd3(
        conn,
        filial=filial,
        cf="PR0",
        produto=p.produto,
        local=p.localProducao,
        quantidade=p.quantidadeProduzida,
        doc=doc,
        emissao=emissao,
        op=p.op,
    )
    _mexer_saldo(
        conn, filial, p.produto, p.localProducao, qatu=float(p.quantidadeProduzida)
    )

    for c in p.componentes:
        atual = conn.execute(
            f"SELECT d4_quant FROM {sd4} WHERE d4_filial = %s "
            "AND btrim(d4_op) = %s AND btrim(d4_cod) = %s AND d4_local = %s "
            "AND d_e_l_e_t_ <> '*'",
            (filial, p.op, c.produto, c.local),
        ).fetchone()
        if atual is None:
            raise RecusaProtheus(
                f"Empenho de {c.produto} no almox. {c.local} não existe na OP {p.op}"
            )

        _inserir_movimento_sd3(
            conn,
            filial=filial,
            cf="RE1",
            produto=c.produto,
            local=c.local,
            quantidade=c.quantidade,
            doc=doc,
            emissao=emissao,
            op=p.op,
        )
        conn.execute(
            f"""
            UPDATE {sd4}
            SET d4_quant = d4_quant - %s,
                d4_sldemp = 0,
                d4_sldemp2 = 0,
                d4_qtneces = 0,
                d4_situaca = CASE
                    WHEN d4_quant - %s <= 0 THEN 'R'
                    ELSE d4_situaca
                END
            WHERE d4_filial = %s
              AND btrim(d4_op) = %s
              AND btrim(d4_cod) = %s
              AND d4_local = %s
            """,
            (c.quantidade, c.quantidade, filial, p.op, c.produto, c.local),
        )
        _mexer_saldo(
            conn, filial, c.produto, c.local, qatu=-c.quantidade, qemp=-c.quantidade
        )

    produzido_total = float(op_sc2["c2_quje"] or 0) + p.quantidadeProduzida
    fecha_op = produzido_total >= float(op_sc2["c2_quant"])
    if fecha_op:
        conn.execute(
            f"UPDATE {sc2} SET c2_quje = %s, c2_datrf = %s "
            "WHERE c2_filial = %s AND c2_num = %s AND c2_item = %s "
            "AND c2_sequen = %s",
            (produzido_total, emissao, filial, numero, item, sequencia),
        )
    else:
        conn.execute(
            f"UPDATE {sc2} SET c2_quje = %s "
            "WHERE c2_filial = %s AND c2_num = %s AND c2_item = %s "
            "AND c2_sequen = %s",
            (produzido_total, filial, numero, item, sequencia),
        )

    return f"SD3:{doc}", {
        "produzido": p.quantidadeProduzida,
        "produzidoTotal": produzido_total,
        "fechouOp": fecha_op,
    }


APLICADORES = {
    "aberturaOp": abrir_op,
    "empenho": alterar_empenho,
    "transferencia": transferir,
    "baixaProducao": dar_baixa_producao,
}
