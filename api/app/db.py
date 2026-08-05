"""Acesso ao PostgreSQL e as manhas das tabelas do Protheus."""
from contextlib import contextmanager
from functools import lru_cache

import psycopg
from psycopg.rows import dict_row

from . import config

# Auditoria de tudo que esta API aplicou.
#
# Serve para duas coisas: idempotência (reenviar o mesmo `id` não duplica) e
# reversão — `antes` guarda o estado anterior de cada linha tocada.
DDL_AUDITORIA = """
CREATE TABLE IF NOT EXISTS vf_mutations (
    id            text PRIMARY KEY,
    kind          text        NOT NULL,
    filial        text        NOT NULL,
    autor         text        NOT NULL,
    criado_em     timestamptz NOT NULL,
    aplicado_em   timestamptz NOT NULL DEFAULT now(),
    status        text        NOT NULL,
    protheus_ref  text,
    erro          text,
    payload       jsonb       NOT NULL,
    antes         jsonb
);
"""


@contextmanager
def conexao():
    with psycopg.connect(config.DSN, row_factory=dict_row) as conn:
        yield conn


def preparar_banco() -> None:
    with conexao() as conn:
        conn.execute(DDL_AUDITORIA)
        conn.commit()


@lru_cache(maxsize=None)
def colunas(tabela: str) -> tuple[tuple[str, str], ...]:
    """Colunas de uma tabela e seus tipos, em ordem.

    As tabelas do Protheus têm todas as colunas `NOT NULL` e sem default — a
    SC2 tem 151. Inserir exige preencher todas, então o INSERT é montado a
    partir daqui em vez de escrito à mão.
    """
    with conexao() as conn:
        linhas = conn.execute(
            """
            SELECT column_name, data_type
            FROM information_schema.columns
            WHERE table_name = %s
            ORDER BY ordinal_position
            """,
            (tabela,),
        ).fetchall()
    return tuple((r["column_name"], r["data_type"]) for r in linhas)


def _vazio(tipo: str):
    """O 'nada' de cada tipo, no jeito do Protheus.

    O ERP não usa NULL: campo texto vazio é `''` e número vazio é `0`. Gravar
    NULL aqui quebraria as consultas do próprio Protheus — com exceções:
    colunas `uuid` e `timestamp` (ex.: `D3_MSUID`/`D3_MSUIDT`/`S_T_A_M_P_` da
    SD3, achadas só quando a baixa de produção passou a escrever nessa
    tabela) não são do Protheus clássico, são acréscimo da migração para
    rastreio multi-origem, aceitam NULL (conferido no `information_schema`) e
    não têm `''` como valor válido — tipado, `''` não converte para nenhum
    dos dois.
    """
    if tipo in ("double precision", "numeric", "integer", "bigint", "real"):
        return 0
    if tipo == "uuid" or "timestamp" in tipo:
        return None
    return ""


def linha_em_branco(tabela: str) -> dict:
    """Uma linha com todas as colunas preenchidas com o vazio do tipo."""
    return {nome: _vazio(tipo) for nome, tipo in colunas(tabela)}


def proximo_recno(conn, tabela: str) -> int:
    """O próximo `R_E_C_N_O_` da tabela.

    É o número de registro do Protheus e a chave primária de toda tabela do
    ERP. Não é uma sequence do banco — o Protheus o gerencia por fora —, então
    inserir sem calcular deixaria tudo em zero e a segunda linha colidiria.
    """
    linha = conn.execute(
        f"SELECT coalesce(max(r_e_c_n_o_), 0) + 1 AS proximo FROM {tabela}"
    ).fetchone()
    return int(linha["proximo"])


def inserir(conn, tabela: str, valores: dict) -> None:
    """Insere preenchendo tudo que não veio em `valores`."""
    linha = linha_em_branco(tabela)
    desconhecidas = set(valores) - set(linha)
    if desconhecidas:
        raise ValueError(
            f"{tabela} não tem as colunas: {sorted(desconhecidas)}"
        )
    linha.update(valores)
    if "r_e_c_n_o_" in linha and not valores.get("r_e_c_n_o_"):
        linha["r_e_c_n_o_"] = proximo_recno(conn, tabela)
    campos = list(linha)
    marcadores = ", ".join(["%s"] * len(campos))
    conn.execute(
        f'INSERT INTO {tabela} ({", ".join(campos)}) VALUES ({marcadores})',
        [linha[c] for c in campos],
    )


def proximo_numero_op(conn, tabela_sc2: str, filial: str) -> str:
    """O próximo C2_NUM da filial, no formato de 6 dígitos do Protheus.

    Quem numera a OP é o ERP — o VettiFlow só pede. Aqui esta API faz o papel
    dele. No Protheus de verdade a numeração vem do SXE/SXF com trava de
    concorrência; a trava equivalente aqui é o `FOR UPDATE` no lote.
    """
    linha = conn.execute(
        f"SELECT max(c2_num) AS ultimo FROM {tabela_sc2} WHERE c2_filial = %s",
        (filial,),
    ).fetchone()
    ultimo = (linha or {}).get("ultimo") or "000000"
    try:
        proximo = int(ultimo) + 1
    except ValueError:
        proximo = 1
    return str(proximo).zfill(6)
