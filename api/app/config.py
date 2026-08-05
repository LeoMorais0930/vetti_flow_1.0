"""Configuração do serviço, toda por variável de ambiente."""
import os

# Banco onde as mutações são aplicadas.
#
# Hoje é a cópia do Protheus migrada para PostgreSQL local (`vettip12`), não o
# ERP de verdade. É de propósito: o objetivo desta API é ver como as mutações
# do VettiFlow se comportam contra as tabelas reais antes de encostar em
# produção.
DSN = os.getenv("VF_DSN", "postgresql://localhost:5432/vettip12")

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
