# VettiFlow local Postgres

Este diretório guarda somente scripts PostgreSQL do VettiFlow.

Organizacao:

- `migrations/`: criacao e alteracoes do banco local.
- `postgres/`: selects e consultas auxiliares para rodar no Postgres.

## Postgres local

O cluster local foi criado em `.local_pg/data` e fica fora do git.

Conexao local:

```text
postgresql://postgres@localhost:5432/vettiflow
```

Subir o servidor:

```powershell
& 'C:\Program Files\PostgreSQL\18\bin\pg_ctl.exe' -D '.local_pg\data' -o "-p 5432" -l '.local_pg\postgres.log' start
```

Parar o servidor:

```powershell
& 'C:\Program Files\PostgreSQL\18\bin\pg_ctl.exe' -D '.local_pg\data' stop
```

Aplicar migrations:

```powershell
& 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -h localhost -p 5432 -U postgres -d vettiflow -v ON_ERROR_STOP=1 -f 'db\migrations\001_create_vettiflow_local.sql'
& 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -h localhost -p 5432 -U postgres -d vettiflow -v ON_ERROR_STOP=1 -f 'db\migrations\002_add_protheus_candidate_mappings.sql'
& 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -h localhost -p 5432 -U postgres -d vettiflow -v ON_ERROR_STOP=1 -f 'db\migrations\003_create_sb1_raw_products.sql'
& 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -h localhost -p 5432 -U postgres -d vettiflow -v ON_ERROR_STOP=1 -f 'db\migrations\004_define_vettiflow_protheus_scope.sql'
& 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -h localhost -p 5432 -U postgres -d vettiflow -v ON_ERROR_STOP=1 -f 'db\migrations\005_create_protheus_raw_tables.sql'
& 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -h localhost -p 5432 -U postgres -d vettiflow -v ON_ERROR_STOP=1 -f 'db\migrations\006_fix_sb1_generated_columns_lowercase.sql'
& 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -h localhost -p 5432 -U postgres -d vettiflow -v ON_ERROR_STOP=1 -f 'db\migrations\007_create_protheus_business_views.sql'
```

## Consultas prontas

Resumo da importacao Protheus:

```powershell
& 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -h localhost -p 5432 -U postgres -d vettiflow -f 'db\postgres\view_imported_protheus_summary.sql'
```

Listar produtos SB1 ja importados:

```powershell
& 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -h localhost -p 5432 -U postgres -d vettiflow -f 'db\postgres\select_all_sb1_products.sql'
```

Ver o mapa da SB1 no VettiFlow:

```powershell
& 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -h localhost -p 5432 -U postgres -d vettiflow -f 'db\postgres\view_sb1_if_imported.sql'
```

Exemplos de consultas para VettiFlow:

```powershell
& 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -h localhost -p 5432 -U postgres -d vettiflow -f 'db\postgres\view_protheus_vettiflow_examples.sql'
```

## Importar export Protheus

Export atual recebido:

```text
C:\Users\Leonardo Morais\Desktop\vetti\VettiFlow\export-protheus-2026-07-30
```

Importar JSONs para o Postgres:

```powershell
.\tools\import_protheus_export_to_postgres.ps1 -ExportDir 'C:\Users\Leonardo Morais\Desktop\vetti\VettiFlow\export-protheus-2026-07-30'
```

Tabelas raw carregadas:

- `protheus_raw.sb1_products`
- `protheus_raw.sc2_orders`
- `protheus_raw.sg1_structures`
- `protheus_raw.sb2_balances`

Views para uso do VettiFlow:

- `protheus_raw.vw_sb1_products`
- `protheus_raw.vw_sc2_orders`
- `protheus_raw.vw_sg1_product_structures`
- `protheus_raw.vw_sb2_stock_balances`

## Schemas criados

- `vettiflow`: tabelas operacionais do app, alinhadas aos modelos Dart atuais.
- `protheus_metadata`: catalogo das tabelas/campos extraidos do Protheus.
- `protheus_raw`: area generica para guardar registros brutos em `jsonb` antes do mapeamento final.

## Backup analisado

Arquivo:

```text
C:\Users\Leonardo Morais\Desktop\vetti\VettiFlow\Backups\VettiP12_VettiFlow_Backup_29-07-2026.bak
```

Leituras feitas via SQL Server LocalDB:

- Assinatura do arquivo: `MSSQLBAK`.
- Banco original: `VettiP12`.
- Backup full, comprimido com `MS_XPRESS`.
- Inicio: `2026-07-29 15:28:10`.
- Fim: `2026-07-29 15:29:45`.
- Tamanho comprimido: `3100644453` bytes.
- MDF original declarado: `25676087296` bytes.
- LDF original declarado: `259798990848` bytes.
- Collation: `Latin1_General_CI_AS`.
- `RESTORE VERIFYONLY` concluiu que o backup e valido.

## Bloqueio atual

A maquina tem apenas SQL Server LocalDB/Express disponivel. Esse motor nao e
adequado para restaurar este backup porque o backup declara aproximadamente
25.7 GB de dados e 259.8 GB de log, enquanto o LocalDB/Express tem limite de
tamanho e a unidade local tinha cerca de 251.3 GB livres.

Para ver produtos reais da Vetti dentro do Postgres, primeiro precisamos que os
dados da SB1 sejam importados para `protheus_raw.records` ou para uma tabela
Postgres dedicada. Ate isso acontecer, os selects de SB1 rodam, mas retornam
zero linhas.
