BEGIN;

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

CREATE OR REPLACE VIEW protheus_raw.vw_sd4_commitments AS
SELECT
  d.d4_filial AS filial,
  d.d4_op AS op_chave,
  d.d4_cod AS componente_codigo,
  p.b1_desc AS componente_descricao,
  d.d4_local AS armazem,
  d.d4_data AS data_empenho_aaaammdd,
  d.d4_qtdeori AS quantidade_original,
  d.d4_quant AS quantidade_empenhada,
  d.d4_sldemp AS saldo_empenhado,
  d.d4_qtneces AS quantidade_necessaria,
  d.d4_produto AS produto_codigo,
  d.d4_trt AS sequencia_estrutura,
  d.payload
FROM protheus_raw.sd4_commitments AS d
LEFT JOIN protheus_raw.sb1_products AS p
  ON p.b1_cod = d.d4_cod
WHERE COALESCE(d.payload ->> 'd_e_l_e_t_', '') <> '*';

DROP VIEW IF EXISTS protheus_raw.vw_sd3_internal_movements;

CREATE OR REPLACE VIEW protheus_raw.vw_sd3_internal_movements AS
SELECT
  m.d3_filial AS filial,
  m.d3_op AS op_chave,
  m.d3_cod AS produto_codigo,
  p.b1_desc AS produto_descricao,
  m.d3_local AS armazem,
  m.payload ->> 'd3_localdest' AS armazem_destino,
  m.d3_quant AS quantidade_movimentada,
  m.d3_cf AS tipo_re_de,
  m.d3_doc AS documento,
  m.d3_emissao AS emissao_aaaammdd,
  m.d3_estorno AS estorno,
  m.payload ->> 'vettiflow_origin' AS origem_vettiflow,
  m.payload ->> 'vettiflow_from_stage' AS etapa_origem,
  m.payload ->> 'vettiflow_to_stage' AS etapa_destino,
  m.payload ->> 'vettiflow_from_warehouse' AS armazem_origem_vettiflow,
  m.payload ->> 'vettiflow_to_warehouse' AS armazem_destino_vettiflow,
  m.payload
FROM protheus_raw.sd3_movements AS m
LEFT JOIN protheus_raw.sb1_products AS p
  ON p.b1_cod = m.d3_cod
WHERE COALESCE(m.payload ->> 'd_e_l_e_t_', '') <> '*';

COMMIT;
