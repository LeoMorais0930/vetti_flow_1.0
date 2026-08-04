/*
  Script PostgreSQL.

  Use este arquivo quando estiver conectado no Postgres local do VettiFlow:

    Host: localhost
    Port: 5432
    Database: vettiflow
    User: postgres

  Importante:
  - Este script NAO le diretamente o .bak do Protheus.
  - Ele mostra o mapa da SB1 e, se registros SB1 ja tiverem sido importados
    para protheus_raw.records, lista os produtos.
*/

-- 1) Onde a SB1 entra no VettiFlow.
SELECT
  area,
  protheus_table_prefix,
  likely_physical_table_pattern,
  purpose,
  key_fields,
  useful_fields,
  notes
FROM protheus_metadata.vw_vettiflow_protheus_map
WHERE protheus_table_prefix = 'SB1';

-- 2) Tabelas SB1 descobertas/importadas no catalogo local, se ja existirem.
SELECT
  source_schema,
  source_table,
  row_count_estimate,
  primary_key_columns,
  mapped_to
FROM protheus_metadata.source_tables
WHERE source_table ILIKE 'SB1%'
ORDER BY source_schema, source_table;

-- 3) Produtos SB1 ja importados para JSON bruto, se existirem.
-- Troque NULL por 'CENTRAL', 'CONTROLE' ou um codigo especifico.
WITH params AS (
  SELECT
    NULL::text AS busca,
    100::integer AS limite
)
SELECT
  r.source_table AS tabela_origem,
  r.payload ->> 'b1_filial' AS filial,
  r.payload ->> 'b1_cod' AS codigo,
  r.payload ->> 'b1_desc' AS descricao,
  r.payload ->> 'b1_tipo' AS tipo,
  r.payload ->> 'b1_um' AS unidade,
  r.payload ->> 'b1_grupo' AS grupo,
  r.payload ->> 'b1_codite' AS codigo_alternativo,
  r.imported_at
FROM protheus_raw.records AS r
CROSS JOIN params AS p
WHERE r.source_table ILIKE 'SB1%'
  AND (
    p.busca IS NULL
    OR r.payload ->> 'b1_cod' ILIKE '%' || p.busca || '%'
    OR r.payload ->> 'b1_desc' ILIKE '%' || p.busca || '%'
    OR r.payload ->> 'b1_codite' ILIKE '%' || p.busca || '%'
  )
ORDER BY r.payload ->> 'b1_cod'
LIMIT (SELECT limite FROM params);
