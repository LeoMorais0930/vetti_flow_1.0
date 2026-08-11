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
from datetime import date

from fastapi import FastAPI, HTTPException, Query
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


def _relation_exists(conn, name: str) -> bool:
    row = conn.execute("SELECT to_regclass(%s) AS rel", (name,)).fetchone()
    return row is not None and row["rel"] is not None


def _layout(conn) -> str:
    """Detecta se estamos lendo export bruto ou tabelas fisicas Protheus."""
    if all(
        _relation_exists(conn, name)
        for name in (
            "protheus_raw.vw_sb1_products",
            "protheus_raw.vw_sg1_product_structures",
            "protheus_raw.vw_sb2_stock_balances",
            "protheus_raw.vw_sc2_orders",
        )
    ):
        return "raw"
    if all(
        _relation_exists(conn, config.tabela(name))
        for name in ("SB1", "SG1", "SB2", "SC2")
    ):
        return "physical"
    raise HTTPException(
        status_code=503,
        detail=(
            "Base Protheus incompleta: esperado protheus_raw.vw_* "
            "ou tabelas fisicas SB1/SG1/SB2/SC2."
        ),
    )


def _scalar(value, default=0):
    if value in (None, ""):
        return default
    return value


def _json_list(value) -> list:
    if value is None:
        return []
    if isinstance(value, list):
        return value
    if isinstance(value, str):
        try:
            decoded = json.loads(value)
            return decoded if isinstance(decoded, list) else []
        except json.JSONDecodeError:
            return []
    return []


def _produtos_raw(conn, query: str, filial: str, limit: int) -> list[dict]:
    normalized = query.strip().upper()
    return conn.execute(
        """
        SELECT
          filial,
          codigo AS code,
          descricao AS description,
          tipo AS type,
          unidade AS unit,
          grupo AS "group",
          COALESCE(payload ->> 'b1_msblql', payload ->> 'B1_MSBLQL', '') AS "screenBlock"
        FROM protheus_raw.vw_sb1_products
        WHERE codigo IS NOT NULL
          AND descricao IS NOT NULL
          AND (filial = %s OR filial = '')
          AND COALESCE(NULLIF(payload ->> 'b1_msblql', ''), NULLIF(payload ->> 'B1_MSBLQL', ''), '2') <> '1'
          AND (
            %s = ''
            OR codigo ILIKE %s
            OR descricao ILIKE %s
          )
        ORDER BY
          CASE WHEN codigo = %s THEN 0 ELSE 1 END,
          CASE WHEN codigo ILIKE %s THEN 0 ELSE 1 END,
          CASE WHEN codigo LIKE '7%%' THEN 0 ELSE 1 END,
          CASE
            WHEN tipo IN ('PA', 'PI') THEN 0
            WHEN tipo IN ('SB', 'SV') THEN 1
            ELSE 2
          END,
          codigo
        LIMIT %s
        """,
        (
            filial,
            normalized,
            f"%{normalized}%",
            f"%{normalized}%",
            normalized,
            f"{normalized}%",
            limit,
        ),
    ).fetchall()


def _produto_raw(conn, codigo: str, filial: str) -> dict | None:
    rows = conn.execute(
        """
        SELECT
          filial,
          codigo AS code,
          descricao AS description,
          tipo AS type,
          unidade AS unit,
          grupo AS "group",
          COALESCE(payload ->> 'b1_msblql', payload ->> 'B1_MSBLQL', '') AS "screenBlock"
        FROM protheus_raw.vw_sb1_products
        WHERE codigo = %s
          AND (filial = %s OR filial = '')
          AND COALESCE(NULLIF(payload ->> 'b1_msblql', ''), NULLIF(payload ->> 'B1_MSBLQL', ''), '2') <> '1'
        LIMIT 1
        """,
        (codigo, filial),
    ).fetchone()
    return rows


def _componentes_raw(conn, codigo: str, filial: str) -> list[dict]:
    rows = conn.execute(
        """
        WITH component_orders AS (
          SELECT
            produto_codigo,
            jsonb_agg(
              jsonb_build_object(
                'number', op,
                'productCode', produto_codigo,
                'productDescription', produto_descricao,
                'plannedQuantity', quantidade_planejada,
                'producedQuantity', quantidade_produzida,
                'status', status_protheus
              )
              ORDER BY emissao_aaaammdd DESC NULLS LAST, op DESC
            ) FILTER (WHERE op IS NOT NULL) AS child_orders
          FROM protheus_raw.vw_sc2_orders
          WHERE filial = %s
          GROUP BY produto_codigo
        ),
        stock_summary AS (
          SELECT
            produto_codigo,
            sum(saldo_disponivel_estimado) AS stock_available
          FROM protheus_raw.vw_sb2_stock_balances
          WHERE filial = %s
          GROUP BY produto_codigo
        ),
        stock_balances AS (
          SELECT
            produto_codigo,
            jsonb_agg(
              jsonb_build_object(
                'filial', filial,
                'armazem', armazem,
                'currentStock', saldo_atual,
                'committedQuantity', quantidade_empenhada,
                'reservedQuantity', quantidade_reservada,
                'availableQuantity', saldo_disponivel_estimado
              )
              ORDER BY armazem
            ) AS warehouse_balances
          FROM protheus_raw.vw_sb2_stock_balances
          WHERE filial = %s
          GROUP BY produto_codigo
        )
        SELECT
          s.filial,
          s.componente_codigo AS code,
          s.componente_descricao AS description,
          s.quantidade_por_unidade AS "quantityPerUnit",
          p.unidade AS unit,
          COALESCE(stock_summary.stock_available, 0) AS "stockAvailable",
          COALESCE(stock_balances.warehouse_balances, '[]'::jsonb) AS "warehouseBalances",
          COALESCE(component_orders.child_orders, '[]'::jsonb) AS "childOrders",
          'SG1' AS "requirementSource",
          '' AS "sourceOrder",
          '' AS "commitmentDate",
          0 AS "originalQuantity",
          0 AS "commitmentQuantity",
          COALESCE(s.payload ->> 'g1_trt', s.payload ->> 'G1_TRT', '') AS "structureSequence"
        FROM protheus_raw.vw_sg1_product_structures AS s
        LEFT JOIN protheus_raw.vw_sb1_products AS p
          ON p.codigo = s.componente_codigo
         AND (p.filial = %s OR p.filial = '')
        LEFT JOIN stock_summary ON stock_summary.produto_codigo = s.componente_codigo
        LEFT JOIN stock_balances ON stock_balances.produto_codigo = s.componente_codigo
        LEFT JOIN component_orders ON component_orders.produto_codigo = s.componente_codigo
        WHERE s.produto_codigo = %s
          AND (s.filial = %s OR s.filial = '')
          AND COALESCE(NULLIF(p.payload ->> 'b1_msblql', ''), NULLIF(p.payload ->> 'B1_MSBLQL', ''), '2') <> '1'
        ORDER BY
          COALESCE(NULLIF(s.payload ->> 'g1_trt', ''), NULLIF(s.payload ->> 'G1_TRT', ''), s.componente_codigo),
          s.componente_codigo
        """,
        (filial, filial, filial, filial, codigo, filial),
    ).fetchall()
    return [_normalizar_componente(row) for row in rows]


def _produtos_fisicos(conn, query: str, filial: str, limit: int) -> list[dict]:
    normalized = query.strip().upper()
    sb1 = config.tabela("SB1")
    return conn.execute(
        f"""
        SELECT
          btrim(b1_filial) AS filial,
          btrim(b1_cod) AS code,
          btrim(b1_desc) AS description,
          btrim(b1_tipo) AS type,
          btrim(b1_um) AS unit,
          btrim(b1_grupo) AS "group",
          btrim(COALESCE(b1_msblql, '')) AS "screenBlock"
        FROM {sb1}
        WHERE btrim(b1_cod) <> ''
          AND btrim(COALESCE(b1_desc, '')) <> ''
          AND (btrim(b1_filial) = %s OR btrim(b1_filial) = '')
          AND COALESCE(NULLIF(btrim(COALESCE(b1_msblql, '')), ''), '2') <> '1'
          AND (
            %s = ''
            OR btrim(b1_cod) ILIKE %s
            OR btrim(b1_desc) ILIKE %s
          )
        ORDER BY
          CASE WHEN btrim(b1_cod) = %s THEN 0 ELSE 1 END,
          CASE WHEN btrim(b1_cod) ILIKE %s THEN 0 ELSE 1 END,
          CASE WHEN btrim(b1_cod) LIKE '7%%' THEN 0 ELSE 1 END,
          btrim(b1_cod)
        LIMIT %s
        """,
        (
            filial,
            normalized,
            f"%{normalized}%",
            f"%{normalized}%",
            normalized,
            f"{normalized}%",
            limit,
        ),
    ).fetchall()


def _produto_fisico(conn, codigo: str, filial: str) -> dict | None:
    sb1 = config.tabela("SB1")
    return conn.execute(
        f"""
        SELECT
          btrim(b1_filial) AS filial,
          btrim(b1_cod) AS code,
          btrim(b1_desc) AS description,
          btrim(b1_tipo) AS type,
          btrim(b1_um) AS unit,
          btrim(b1_grupo) AS "group",
          btrim(COALESCE(b1_msblql, '')) AS "screenBlock"
        FROM {sb1}
        WHERE btrim(b1_cod) = %s
          AND (btrim(b1_filial) = %s OR btrim(b1_filial) = '')
          AND COALESCE(NULLIF(btrim(COALESCE(b1_msblql, '')), ''), '2') <> '1'
        LIMIT 1
        """,
        (codigo, filial),
    ).fetchone()


def _saldos_fisicos(conn, codigo: str, filial: str) -> list[dict]:
    sb2 = config.tabela("SB2")
    return conn.execute(
        f"""
        SELECT
          btrim(b2_filial) AS filial,
          btrim(b2_local) AS armazem,
          b2_qatu AS "currentStock",
          b2_qemp AS "committedQuantity",
          COALESCE(b2_reserva, 0) AS "reservedQuantity",
          b2_qatu AS "availableQuantity"
        FROM {sb2}
        WHERE d_e_l_e_t_ <> '*'
          AND b2_filial = %s
          AND btrim(b2_cod) = %s
        ORDER BY armazem
        """,
        (filial, codigo),
    ).fetchall()


def _componentes_fisicos(conn, codigo: str, filial: str) -> list[dict]:
    sg1 = config.tabela("SG1")
    sb1 = config.tabela("SB1")
    hoje = date.today().strftime("%Y%m%d")
    rows = conn.execute(
        f"""
        SELECT
          btrim(s.g1_filial) AS filial,
          btrim(s.g1_comp) AS code,
          btrim(COALESCE(p.b1_desc, '')) AS description,
          s.g1_quant AS "quantityPerUnit",
          btrim(COALESCE(p.b1_um, '')) AS unit,
          btrim(COALESCE(s.g1_trt, '')) AS "structureSequence"
        FROM {sg1} s
        LEFT JOIN {sb1} p
          ON btrim(p.b1_cod) = btrim(s.g1_comp)
         AND (btrim(p.b1_filial) = %s OR btrim(p.b1_filial) = '')
        WHERE s.d_e_l_e_t_ <> '*'
          AND btrim(s.g1_cod) = %s
          AND (btrim(s.g1_filial) = %s OR btrim(s.g1_filial) = '')
          AND btrim(COALESCE(s.g1_ini, '')) <= %s
          AND (btrim(COALESCE(s.g1_fim, '')) = '' OR btrim(s.g1_fim) >= %s)
          AND COALESCE(NULLIF(btrim(COALESCE(p.b1_msblql, '')), ''), '2') <> '1'
        ORDER BY btrim(COALESCE(s.g1_trt, '')), btrim(s.g1_comp)
        """,
        (filial, codigo, filial, hoje, hoje),
    ).fetchall()
    components = []
    for row in rows:
        data = dict(row)
        balances = _saldos_fisicos(conn, data["code"], filial)
        best = _melhor_saldo(balances)
        data["warehouseBalances"] = balances
        data["childOrders"] = []
        data["requirementSource"] = "SG1"
        data["sourceOrder"] = ""
        data["commitmentDate"] = ""
        data["originalQuantity"] = 0
        data["commitmentQuantity"] = 0
        data["armazem"] = best.get("armazem", "") if best else ""
        data["stockAvailable"] = best.get("availableQuantity", 0) if best else 0
        data["currentStock"] = best.get("currentStock", 0) if best else 0
        data["committedQuantity"] = best.get("committedQuantity", 0) if best else 0
        data["reservedQuantity"] = best.get("reservedQuantity", 0) if best else 0
        components.append(data)
    return components


def _melhor_saldo(balances: list[dict]) -> dict | None:
    positives = [
        item
        for item in balances
        if _scalar(item.get("availableQuantity")) > 0
        or _scalar(item.get("currentStock")) > 0
    ]
    values = positives or balances
    if not values:
        return None
    return sorted(
        values,
        key=lambda item: (
            _scalar(item.get("availableQuantity")),
            _scalar(item.get("currentStock")),
        ),
        reverse=True,
    )[0]


def _normalizar_componente(row: dict) -> dict:
    data = dict(row)
    balances = _json_list(data.pop("warehouseBalances", []))
    children = _json_list(data.pop("childOrders", []))
    best = _melhor_saldo(balances)
    data["warehouseBalances"] = balances
    data["childOrders"] = children
    data["armazem"] = best.get("armazem", "") if best else ""
    data["stockAvailable"] = best.get("availableQuantity", 0) if best else 0
    data["currentStock"] = best.get("currentStock", 0) if best else 0
    data["committedQuantity"] = best.get("committedQuantity", 0) if best else 0
    data["reservedQuantity"] = best.get("reservedQuantity", 0) if best else 0
    return data


@app.get("/api/v1/produtos")
def produtos(
    query: str = "",
    limit: int = Query(default=12, ge=1, le=250),
    filial: str = config.FILIAL_PADRAO,
) -> list[dict]:
    with db.conexao() as conn:
        if _layout(conn) == "raw":
            return _produtos_raw(conn, query, filial, limit)
        return _produtos_fisicos(conn, query, filial, limit)


@app.get("/api/v1/produtos/{codigo}")
def produto(codigo: str, filial: str = config.FILIAL_PADRAO) -> dict:
    code = codigo.strip().upper()
    with db.conexao() as conn:
        layout = _layout(conn)
        if layout == "raw":
            product = _produto_raw(conn, code, filial)
            components = _componentes_raw(conn, code, filial) if product else []
        else:
            product = _produto_fisico(conn, code, filial)
            components = _componentes_fisicos(conn, code, filial) if product else []

    if product is None:
        raise HTTPException(status_code=404, detail="Produto nao encontrado")
    return {
        "filial": filial,
        "armazem": "",
        "product": product,
        "components": components,
        "smdReleaseOrders": [],
    }


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
        if _layout(conn) == "raw":
            rows = conn.execute(
                """
                SELECT
                  armazem AS local,
                  saldo_atual AS saldo,
                  quantidade_empenhada AS empenhado
                FROM protheus_raw.vw_sb2_stock_balances
                WHERE filial = %s AND produto_codigo = %s
                ORDER BY local
                """,
                (filial, codigo.strip().upper()),
            ).fetchall()
            return rows
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
