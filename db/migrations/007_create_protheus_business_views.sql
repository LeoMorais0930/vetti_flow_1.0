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
  AND COALESCE(NULLIF(payload ->> 'b1_msblql', ''), NULLIF(payload ->> 'B1_MSBLQL', ''), '2') <> '1';

DROP VIEW IF EXISTS protheus_raw.vw_sc2_orders CASCADE;

CREATE OR REPLACE VIEW protheus_raw.vw_sc2_orders AS
SELECT
  o.c2_filial AS filial,
  concat_ws('-', o.c2_num, o.c2_item, o.c2_sequen) AS op,
  concat(o.c2_num, o.c2_item, o.c2_sequen) AS op_chave,
  o.c2_num AS numero,
  o.c2_item AS item,
  o.c2_sequen AS sequencia,
  o.c2_produto AS produto_codigo,
  p.b1_desc AS produto_descricao,
  o.c2_quant AS quantidade_planejada,
  o.c2_quje AS quantidade_produzida,
  o.c2_emissao AS emissao_aaaammdd,
  o.c2_datpri AS inicio_previsto_aaaammdd,
  o.c2_datprf AS fim_previsto_aaaammdd,
  o.c2_datrf AS fim_real_aaaammdd,
  o.c2_status AS status_protheus,
  o.payload
FROM protheus_raw.sc2_orders AS o
LEFT JOIN protheus_raw.sb1_products AS p
  ON p.b1_cod = o.c2_produto
WHERE COALESCE(o.payload ->> 'd_e_l_e_t_', '') <> '*';

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
  AND COALESCE(NULLIF(parent.payload ->> 'b1_msblql', ''), NULLIF(parent.payload ->> 'B1_MSBLQL', ''), '2') <> '1'
  AND COALESCE(NULLIF(component.payload ->> 'b1_msblql', ''), NULLIF(component.payload ->> 'B1_MSBLQL', ''), '2') <> '1';

CREATE OR REPLACE VIEW protheus_raw.vw_sb2_stock_balances AS
SELECT
  b.b2_filial AS filial,
  b.b2_cod AS produto_codigo,
  p.b1_desc AS produto_descricao,
  b.b2_local AS armazem,
  b.b2_qatu AS saldo_atual,
  b.b2_qemp AS quantidade_empenhada,
  b.b2_reserva AS quantidade_reservada,
  COALESCE(b.b2_qatu, 0) AS saldo_disponivel_estimado,
  b.payload
FROM protheus_raw.sb2_balances AS b
LEFT JOIN protheus_raw.sb1_products AS p
  ON p.b1_cod = b.b2_cod
WHERE COALESCE(b.payload ->> 'd_e_l_e_t_', '') <> '*';

COMMIT;
