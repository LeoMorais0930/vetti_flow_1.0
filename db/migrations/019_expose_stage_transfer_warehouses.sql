BEGIN;

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
