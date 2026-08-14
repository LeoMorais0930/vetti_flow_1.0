"""Configuração do serviço, toda por variável de ambiente."""
import os
from pathlib import Path


def _load_local_env() -> None:
    """Carrega `api/.env` sem sobrescrever variáveis já exportadas no sistema."""
    env_path = Path(__file__).resolve().parents[1] / ".env"
    if not env_path.exists():
        return

    for raw_line in env_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key and key not in os.environ:
            os.environ[key] = value


_load_local_env()


def _csv_env(nome: str, padrao: list[str]) -> list[str]:
    valor = os.getenv(nome, "").strip()
    if not valor:
        return padrao
    return [parte.strip() for parte in valor.split(",") if parte.strip()]


# Banco onde as mutações são aplicadas.
#
# Hoje é a cópia do Protheus migrada para PostgreSQL local (`vettip12`), não o
# ERP de verdade. É de propósito: o objetivo desta API é ver como as mutações
# do VettiFlow se comportam contra as tabelas reais antes de encostar em
# produção.
DSN = os.getenv("VF_DSN", "postgresql://localhost:5432/vettip12")

# Token simples para proteger a API em rede interna. Vazio mantém o modo dev
# aberto; em servidor, defina VF_API_TOKEN e envie o mesmo valor pelo app.
API_TOKEN = os.getenv("VF_API_TOKEN", "").strip()

# Em dev pode ficar aberto. No servidor, use os hosts reais do Flutter/Web.
CORS_ORIGINS = _csv_env("VF_CORS_ORIGINS", ["*"])

# Liga a trava de SF5 para gravações em SD3. Em export local incompleto pode
# ficar desligado; na VM/dev do Protheus deve ficar ligado.
REQUIRE_SF5_MOVEMENTS = os.getenv(
    "VF_REQUIRE_SF5_MOVEMENTS", "0"
).lower() in ("1", "true", "sim", "yes")

# Mapeamento entre o código RE/DE/PR/ER gravado em D3_CF e o tipo numérico
# cadastrado na SF5, que vai para D3_TM. Não inventar valor: confirmar na SF5
# real da Vetti e informar por ambiente.
SF5_TM_BY_CF = {
    "PR0": os.getenv("VF_TM_PR0", "").strip(),
    "PR1": os.getenv("VF_TM_PR1", "").strip(),
    "RE1": os.getenv("VF_TM_RE1", "").strip(),
    "RE4": os.getenv("VF_TM_RE4", "").strip(),
    "DE4": os.getenv("VF_TM_DE4", "").strip(),
    "ER0": os.getenv("VF_TM_ER0", "").strip(),
    "ER1": os.getenv("VF_TM_ER1", "").strip(),
}

# Empresa/filial padrão. As tabelas do Protheus são sufixadas pela empresa:
# SC2 da empresa 010 é `sc2010`.
EMPRESA = os.getenv("VF_EMPRESA", "010")

# Aplicar de verdade nas tabelas do Protheus?
#
# `0` valida tudo, grava a auditoria e devolve o mesmo resultado, mas não toca
# em SC2/SD4/SB2. Serve para testar o caminho inteiro sem alterar a base.
APPLY = os.getenv("VF_APPLY", "1") not in ("0", "false", "False")

# Filial em que o VettiFlow opera. Confere com `filialOperacao` no app.
FILIAL_PADRAO = os.getenv("VF_FILIAL", "04")

def tabela(nome: str) -> str:
    """`SC2` -> `sc2010`. Os nomes vieram minúsculos da migração."""
    return f"{nome.lower()}{EMPRESA}"
