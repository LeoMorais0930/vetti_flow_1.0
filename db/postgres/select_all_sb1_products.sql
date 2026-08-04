/*
  PostgreSQL local do VettiFlow.

  Lista todos os produtos SB1 que ja tiverem sido importados para
  protheus_raw.records.

  Se voltar 0 linhas, nao e erro no SELECT: significa que a SB1 real do
  Protheus ainda nao foi importada para este Postgres.
*/

SELECT
  source_table AS tabela_origem,
  payload ->> 'b1_filial' AS filial,
  payload ->> 'b1_cod' AS codigo,
  payload ->> 'b1_desc' AS descricao,
  payload ->> 'b1_tipo' AS tipo,
  payload ->> 'b1_um' AS unidade,
  payload ->> 'b1_grupo' AS grupo,
  payload ->> 'b1_codite' AS codigo_alternativo,
  imported_at
FROM protheus_raw.records
WHERE source_table ILIKE 'SB1%'
UNION ALL
SELECT
  source_table AS tabela_origem,
  b1_filial AS filial,
  b1_cod AS codigo,
  b1_desc AS descricao,
  b1_tipo AS tipo,
  b1_um AS unidade,
  b1_grupo AS grupo,
  b1_codite AS codigo_alternativo,
  imported_at
FROM protheus_raw.sb1_products
ORDER BY
  codigo,
  descricao;
