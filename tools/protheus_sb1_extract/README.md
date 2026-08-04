# Extrair SB1 do backup Protheus via Docker

Objetivo: restaurar temporariamente o `.bak` em SQL Server Developer dentro de
Docker, exportar somente a SB1 inteira como JSONL e importar esse arquivo leve
para o Postgres local do VettiFlow.

## Realidade importante

Docker nao "abre uma tabela dentro do .bak" sem restaurar o SQL Server. Ele so
facilita criar uma instancia SQL Server descartavel.

Este backup declara:

- Dados: cerca de 25.7 GB.
- Log: cerca de 259.8 GB.

Entao existem tres caminhos:

1. **Melhor localmente:** usar um SSD/disco externo com mais de 350 GB livres
   como `-WorkDir`.
2. **Melhor sem gastar disco local:** rodar este processo em uma VM temporaria
   com disco grande, exportar a SB1 e baixar so o JSONL.
3. **Melhor se o servidor original ainda existe:** exportar a SB1 direto do SQL
   Server original, sem restaurar backup.

Depois do JSONL pronto, o Postgres local so recebe a SB1, nao o banco Protheus
inteiro.

## Pre-requisitos

- Docker Desktop instalado e rodando.
- SQL Server command-line tools locais (`sqlcmd` e `bcp`).
- Postgres local do VettiFlow rodando em `localhost:5432`.

## Uso local

Escolha um `WorkDir` em um disco com bastante espaco livre. Exemplo com disco
externo `D:`.

```powershell
.\tools\protheus_sb1_extract\extract_sb1_via_docker.ps1 `
  -BakPath 'C:\Users\Leonardo Morais\Desktop\vetti\VettiFlow\Backups\VettiP12_VettiFlow_Backup_29-07-2026.bak' `
  -WorkDir 'D:\vettiflow-sql-extract' `
  -SaPassword 'UseUmaSenhaForte!2026'
```

Se a extracao terminar bem, o arquivo vai ficar em:

```text
<WorkDir>\export\sb1_products.jsonl
```

## Importar para o Postgres

O script ja tenta importar automaticamente. Para importar manualmente:

```powershell
& 'C:\Program Files\PostgreSQL\18\bin\psql.exe' `
  -h localhost `
  -p 5432 `
  -U postgres `
  -d vettiflow `
  -c "\copy protheus_raw.sb1_products(payload) FROM '<WorkDir>\export\sb1_products.jsonl' WITH (FORMAT text, ENCODING 'UTF8')"
```

Depois consulte:

```sql
SELECT b1_cod, b1_desc, b1_tipo, b1_um, b1_grupo
FROM protheus_raw.sb1_products
ORDER BY b1_cod;
```
