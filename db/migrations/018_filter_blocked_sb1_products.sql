BEGIN;

CREATE OR REPLACE VIEW protheus_raw.vw_sb1_products AS
SELECT
  b1_filial AS filial,
  b1_cod AS codigo,
  b1_desc AS descricao,
  b1_tipo AS tipo,
  b1_um AS unidade,
  b1_grupo AS grupo,
  b1_codite AS codigo_alternativo,
  payload,
  COALESCE(payload ->> 'b1_msblql', payload ->> 'B1_MSBLQL', '') AS b1_msblql
FROM protheus_raw.sb1_products
WHERE COALESCE(payload ->> 'd_e_l_e_t_', '') <> '*'
  AND COALESCE(
    NULLIF(payload ->> 'b1_msblql', ''),
    NULLIF(payload ->> 'B1_MSBLQL', ''),
    '2'
  ) <> '1';

CREATE OR REPLACE VIEW protheus_raw.vw_sg1_product_structures AS
SELECT
  s.g1_filial AS filial,
  s.g1_cod AS produto_codigo,
  parent.b1_desc AS produto_descricao,
  s.g1_comp AS componente_codigo,
  component.b1_desc AS componente_descricao,
  s.g1_quant AS quantidade_por_unidade,
  s.g1_ini AS inicio_aaaammdd,
  s.g1_fim AS fim_aaaammdd,
  s.payload
FROM protheus_raw.sg1_structures AS s
LEFT JOIN protheus_raw.sb1_products AS parent
  ON parent.b1_cod = s.g1_cod
LEFT JOIN protheus_raw.sb1_products AS component
  ON component.b1_cod = s.g1_comp
WHERE COALESCE(s.payload ->> 'd_e_l_e_t_', '') <> '*'
  AND COALESCE(
    NULLIF(parent.payload ->> 'b1_msblql', ''),
    NULLIF(parent.payload ->> 'B1_MSBLQL', ''),
    '2'
  ) <> '1'
  AND COALESCE(
    NULLIF(component.payload ->> 'b1_msblql', ''),
    NULLIF(component.payload ->> 'B1_MSBLQL', ''),
    '2'
  ) <> '1';

COMMIT;
