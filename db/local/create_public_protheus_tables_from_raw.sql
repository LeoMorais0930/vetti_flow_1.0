-- Compatibilidade local para a API do Protheus.
--
-- O export JSON/CSV do Leonardo popula `protheus_raw.*`. A API de mutacoes,
-- alinhada com o banco do Vitor/VM, escreve nas tabelas fisicas do Protheus no
-- schema `public`: sb1010, sc2010, sg1010, sb2010, sd3010 e sd4010.
--
-- Este script cria as tabelas fisicas somente quando elas ainda nao existem.
-- Em banco que ja veio do dump completo do Protheus, nada e sobrescrito.

CREATE TABLE IF NOT EXISTS public.sb1010 AS
SELECT
  COALESCE(payload ->> 'b1_filial', '') AS b1_filial,
  COALESCE(payload ->> 'b1_cod', '') AS b1_cod,
  COALESCE(payload ->> 'b1_desc', '') AS b1_desc,
  COALESCE(payload ->> 'b1_tipo', '') AS b1_tipo,
  COALESCE(payload ->> 'b1_um', '') AS b1_um,
  COALESCE(payload ->> 'b1_grupo', '') AS b1_grupo,
  COALESCE(payload ->> 'b1_msblql', '') AS b1_msblql,
  COALESCE(payload ->> 'd_e_l_e_t_', '') AS d_e_l_e_t_,
  COALESCE(NULLIF(payload ->> 'r_e_c_n_o_', '')::numeric, 0) AS r_e_c_n_o_,
  COALESCE(NULLIF(payload ->> 'r_e_c_d_e_l_', '')::numeric, 0) AS r_e_c_d_e_l_
FROM protheus_raw.sb1_products
WHERE false;

CREATE TABLE IF NOT EXISTS public.sg1010 AS
SELECT
  COALESCE(payload ->> 'g1_filial', '') AS g1_filial,
  COALESCE(payload ->> 'g1_cod', '') AS g1_cod,
  COALESCE(payload ->> 'g1_comp', '') AS g1_comp,
  COALESCE(NULLIF(payload ->> 'g1_quant', '')::numeric, 0) AS g1_quant,
  COALESCE(payload ->> 'g1_ini', '') AS g1_ini,
  COALESCE(payload ->> 'g1_fim', '') AS g1_fim,
  COALESCE(payload ->> 'g1_trt', '') AS g1_trt,
  COALESCE(payload ->> 'd_e_l_e_t_', '') AS d_e_l_e_t_,
  COALESCE(NULLIF(payload ->> 'r_e_c_n_o_', '')::numeric, 0) AS r_e_c_n_o_,
  COALESCE(NULLIF(payload ->> 'r_e_c_d_e_l_', '')::numeric, 0) AS r_e_c_d_e_l_
FROM protheus_raw.sg1_structures
WHERE false;

INSERT INTO public.sb1010 (
  b1_filial, b1_cod, b1_desc, b1_tipo, b1_um, b1_grupo, b1_msblql,
  d_e_l_e_t_, r_e_c_n_o_, r_e_c_d_e_l_
)
SELECT
  COALESCE(payload ->> 'b1_filial', '') AS b1_filial,
  COALESCE(payload ->> 'b1_cod', '') AS b1_cod,
  COALESCE(payload ->> 'b1_desc', '') AS b1_desc,
  COALESCE(payload ->> 'b1_tipo', '') AS b1_tipo,
  COALESCE(payload ->> 'b1_um', '') AS b1_um,
  COALESCE(payload ->> 'b1_grupo', '') AS b1_grupo,
  COALESCE(payload ->> 'b1_msblql', '') AS b1_msblql,
  COALESCE(payload ->> 'd_e_l_e_t_', '') AS d_e_l_e_t_,
  COALESCE(NULLIF(payload ->> 'r_e_c_n_o_', '')::numeric, 0) AS r_e_c_n_o_,
  COALESCE(NULLIF(payload ->> 'r_e_c_d_e_l_', '')::numeric, 0) AS r_e_c_d_e_l_
FROM protheus_raw.sb1_products
WHERE NOT EXISTS (SELECT 1 FROM public.sb1010);

INSERT INTO public.sg1010 (
  g1_filial, g1_cod, g1_comp, g1_quant, g1_ini, g1_fim, g1_trt,
  d_e_l_e_t_, r_e_c_n_o_, r_e_c_d_e_l_
)
SELECT
  COALESCE(payload ->> 'g1_filial', '') AS g1_filial,
  COALESCE(payload ->> 'g1_cod', '') AS g1_cod,
  COALESCE(payload ->> 'g1_comp', '') AS g1_comp,
  COALESCE(NULLIF(payload ->> 'g1_quant', '')::numeric, 0) AS g1_quant,
  COALESCE(payload ->> 'g1_ini', '') AS g1_ini,
  COALESCE(payload ->> 'g1_fim', '') AS g1_fim,
  COALESCE(payload ->> 'g1_trt', '') AS g1_trt,
  COALESCE(payload ->> 'd_e_l_e_t_', '') AS d_e_l_e_t_,
  COALESCE(NULLIF(payload ->> 'r_e_c_n_o_', '')::numeric, 0) AS r_e_c_n_o_,
  COALESCE(NULLIF(payload ->> 'r_e_c_d_e_l_', '')::numeric, 0) AS r_e_c_d_e_l_
FROM protheus_raw.sg1_structures
WHERE NOT EXISTS (SELECT 1 FROM public.sg1010);

CREATE TABLE IF NOT EXISTS public.sb2010 AS
SELECT
  COALESCE(payload ->> 'b2_filial', '') AS b2_filial,
  COALESCE(payload ->> 'b2_cod', '') AS b2_cod,
  COALESCE(payload ->> 'b2_local', '') AS b2_local,
  COALESCE(NULLIF(payload ->> 'b2_qatu', '')::numeric, 0) AS b2_qatu,
  COALESCE(NULLIF(payload ->> 'b2_qemp', '')::numeric, 0) AS b2_qemp,
  COALESCE(NULLIF(payload ->> 'b2_reserva', '')::numeric, 0) AS b2_reserva,
  COALESCE(payload ->> 'd_e_l_e_t_', '') AS d_e_l_e_t_,
  COALESCE(NULLIF(payload ->> 'r_e_c_n_o_', '')::numeric, 0) AS r_e_c_n_o_,
  COALESCE(NULLIF(payload ->> 'r_e_c_d_e_l_', '')::numeric, 0) AS r_e_c_d_e_l_
FROM protheus_raw.sb2_balances
WHERE false;

INSERT INTO public.sb2010 (
  b2_filial, b2_cod, b2_local, b2_qatu, b2_qemp, b2_reserva,
  d_e_l_e_t_, r_e_c_n_o_, r_e_c_d_e_l_
)
SELECT
  COALESCE(payload ->> 'b2_filial', '') AS b2_filial,
  COALESCE(payload ->> 'b2_cod', '') AS b2_cod,
  COALESCE(payload ->> 'b2_local', '') AS b2_local,
  COALESCE(NULLIF(payload ->> 'b2_qatu', '')::numeric, 0) AS b2_qatu,
  COALESCE(NULLIF(payload ->> 'b2_qemp', '')::numeric, 0) AS b2_qemp,
  COALESCE(NULLIF(payload ->> 'b2_reserva', '')::numeric, 0) AS b2_reserva,
  COALESCE(payload ->> 'd_e_l_e_t_', '') AS d_e_l_e_t_,
  COALESCE(NULLIF(payload ->> 'r_e_c_n_o_', '')::numeric, 0) AS r_e_c_n_o_,
  COALESCE(NULLIF(payload ->> 'r_e_c_d_e_l_', '')::numeric, 0) AS r_e_c_d_e_l_
FROM protheus_raw.sb2_balances
WHERE NOT EXISTS (SELECT 1 FROM public.sb2010);

CREATE TABLE IF NOT EXISTS public.sc2010 AS
SELECT
  COALESCE(payload ->> 'c2_filial', '') AS c2_filial,
  COALESCE(payload ->> 'c2_num', '') AS c2_num,
  COALESCE(payload ->> 'c2_item', '') AS c2_item,
  COALESCE(payload ->> 'c2_sequen', '') AS c2_sequen,
  COALESCE(payload ->> 'c2_itemgrd', '') AS c2_itemgrd,
  COALESCE(payload ->> 'c2_produto', '') AS c2_produto,
  COALESCE(payload ->> 'c2_local', '') AS c2_local,
  COALESCE(NULLIF(payload ->> 'c2_quant', '')::numeric, 0) AS c2_quant,
  COALESCE(NULLIF(payload ->> 'c2_qtsegum', '')::numeric, 0) AS c2_qtsegum,
  COALESCE(NULLIF(payload ->> 'c2_quje', '')::numeric, 0) AS c2_quje,
  COALESCE(payload ->> 'c2_um', '') AS c2_um,
  COALESCE(payload ->> 'c2_emissao', '') AS c2_emissao,
  COALESCE(payload ->> 'c2_datpri', '') AS c2_datpri,
  COALESCE(payload ->> 'c2_datprf', '') AS c2_datprf,
  COALESCE(payload ->> 'c2_datrf', '') AS c2_datrf,
  COALESCE(payload ->> 'c2_status', '') AS c2_status,
  COALESCE(payload ->> 'c2_tpop', '') AS c2_tpop,
  COALESCE(payload ->> 'c2_tppr', '') AS c2_tppr,
  COALESCE(payload ->> 'c2_obs', '') AS c2_obs,
  COALESCE(payload ->> 'c2_roteiro', '') AS c2_roteiro,
  COALESCE(payload ->> 'c2_grupo', '') AS c2_grupo,
  COALESCE(payload ->> 'd_e_l_e_t_', '') AS d_e_l_e_t_,
  COALESCE(NULLIF(payload ->> 'r_e_c_n_o_', '')::numeric, 0) AS r_e_c_n_o_,
  COALESCE(NULLIF(payload ->> 'r_e_c_d_e_l_', '')::numeric, 0) AS r_e_c_d_e_l_
FROM protheus_raw.sc2_orders
WHERE false;

INSERT INTO public.sc2010 (
  c2_filial, c2_num, c2_item, c2_sequen, c2_itemgrd, c2_produto, c2_local,
  c2_quant, c2_qtsegum, c2_quje, c2_um, c2_emissao, c2_datpri, c2_datprf,
  c2_datrf, c2_status, c2_tpop, c2_tppr, c2_obs, c2_roteiro, c2_grupo,
  d_e_l_e_t_, r_e_c_n_o_, r_e_c_d_e_l_
)
SELECT
  COALESCE(payload ->> 'c2_filial', '') AS c2_filial,
  COALESCE(payload ->> 'c2_num', '') AS c2_num,
  COALESCE(payload ->> 'c2_item', '') AS c2_item,
  COALESCE(payload ->> 'c2_sequen', '') AS c2_sequen,
  COALESCE(payload ->> 'c2_itemgrd', '') AS c2_itemgrd,
  COALESCE(payload ->> 'c2_produto', '') AS c2_produto,
  COALESCE(payload ->> 'c2_local', '') AS c2_local,
  COALESCE(NULLIF(payload ->> 'c2_quant', '')::numeric, 0) AS c2_quant,
  COALESCE(NULLIF(payload ->> 'c2_qtsegum', '')::numeric, 0) AS c2_qtsegum,
  COALESCE(NULLIF(payload ->> 'c2_quje', '')::numeric, 0) AS c2_quje,
  COALESCE(payload ->> 'c2_um', '') AS c2_um,
  COALESCE(payload ->> 'c2_emissao', '') AS c2_emissao,
  COALESCE(payload ->> 'c2_datpri', '') AS c2_datpri,
  COALESCE(payload ->> 'c2_datprf', '') AS c2_datprf,
  COALESCE(payload ->> 'c2_datrf', '') AS c2_datrf,
  COALESCE(payload ->> 'c2_status', '') AS c2_status,
  COALESCE(payload ->> 'c2_tpop', '') AS c2_tpop,
  COALESCE(payload ->> 'c2_tppr', '') AS c2_tppr,
  COALESCE(payload ->> 'c2_obs', '') AS c2_obs,
  COALESCE(payload ->> 'c2_roteiro', '') AS c2_roteiro,
  COALESCE(payload ->> 'c2_grupo', '') AS c2_grupo,
  COALESCE(payload ->> 'd_e_l_e_t_', '') AS d_e_l_e_t_,
  COALESCE(NULLIF(payload ->> 'r_e_c_n_o_', '')::numeric, 0) AS r_e_c_n_o_,
  COALESCE(NULLIF(payload ->> 'r_e_c_d_e_l_', '')::numeric, 0) AS r_e_c_d_e_l_
FROM protheus_raw.sc2_orders
WHERE NOT EXISTS (SELECT 1 FROM public.sc2010);

CREATE TABLE IF NOT EXISTS public.sd3010 AS
SELECT
  COALESCE(payload ->> 'd3_filial', '') AS d3_filial,
  COALESCE(payload ->> 'd3_cf', '') AS d3_cf,
  COALESCE(payload ->> 'd3_tm', '') AS d3_tm,
  COALESCE(payload ->> 'd3_cod', '') AS d3_cod,
  COALESCE(payload ->> 'd3_local', '') AS d3_local,
  COALESCE(NULLIF(payload ->> 'd3_quant', '')::numeric, 0) AS d3_quant,
  COALESCE(payload ->> 'd3_doc', '') AS d3_doc,
  COALESCE(payload ->> 'd3_emissao', '') AS d3_emissao,
  COALESCE(payload ->> 'd3_op', '') AS d3_op,
  COALESCE(payload ->> 'd3_estorno', '') AS d3_estorno,
  COALESCE(payload ->> 'd_e_l_e_t_', '') AS d_e_l_e_t_,
  COALESCE(NULLIF(payload ->> 'r_e_c_n_o_', '')::numeric, 0) AS r_e_c_n_o_,
  COALESCE(NULLIF(payload ->> 'r_e_c_d_e_l_', '')::numeric, 0) AS r_e_c_d_e_l_
FROM protheus_raw.sd3_movements
WHERE false;

CREATE TABLE IF NOT EXISTS public.sd4010 AS
SELECT
  COALESCE(payload ->> 'd4_filial', '') AS d4_filial,
  COALESCE(payload ->> 'd4_op', '') AS d4_op,
  COALESCE(payload ->> 'd4_cod', '') AS d4_cod,
  COALESCE(payload ->> 'd4_produto', '') AS d4_produto,
  COALESCE(payload ->> 'd4_local', '') AS d4_local,
  COALESCE(NULLIF(payload ->> 'd4_quant', '')::numeric, 0) AS d4_quant,
  COALESCE(NULLIF(payload ->> 'd4_qtdeori', '')::numeric, 0) AS d4_qtdeori,
  COALESCE(NULLIF(payload ->> 'd4_sldemp', '')::numeric, 0) AS d4_sldemp,
  COALESCE(NULLIF(payload ->> 'd4_sldemp2', '')::numeric, 0) AS d4_sldemp2,
  COALESCE(NULLIF(payload ->> 'd4_qtneces', '')::numeric, 0) AS d4_qtneces,
  COALESCE(NULLIF(payload ->> 'd4_qsusp', '')::numeric, 0) AS d4_qsusp,
  COALESCE(NULLIF(payload ->> 'd4_qtsegum', '')::numeric, 0) AS d4_qtsegum,
  COALESCE(payload ->> 'd4_data', '') AS d4_data,
  COALESCE(payload ->> 'd4_roteiro', '') AS d4_roteiro,
  COALESCE(payload ->> 'd4_trt', '') AS d4_trt,
  COALESCE(payload ->> 'd4_situaca', '') AS d4_situaca,
  COALESCE(payload ->> 'd_e_l_e_t_', '') AS d_e_l_e_t_,
  COALESCE(NULLIF(payload ->> 'r_e_c_n_o_', '')::numeric, 0) AS r_e_c_n_o_,
  COALESCE(NULLIF(payload ->> 'r_e_c_d_e_l_', '')::numeric, 0) AS r_e_c_d_e_l_
FROM protheus_raw.sd4_commitments
WHERE false;

INSERT INTO public.sd3010 (
  d3_filial, d3_cf, d3_tm, d3_cod, d3_local, d3_quant, d3_doc, d3_emissao,
  d3_op, d3_estorno, d_e_l_e_t_, r_e_c_n_o_, r_e_c_d_e_l_
)
SELECT
  COALESCE(payload ->> 'd3_filial', '') AS d3_filial,
  COALESCE(payload ->> 'd3_cf', '') AS d3_cf,
  COALESCE(payload ->> 'd3_tm', '') AS d3_tm,
  COALESCE(payload ->> 'd3_cod', '') AS d3_cod,
  COALESCE(payload ->> 'd3_local', '') AS d3_local,
  COALESCE(NULLIF(payload ->> 'd3_quant', '')::numeric, 0) AS d3_quant,
  COALESCE(payload ->> 'd3_doc', '') AS d3_doc,
  COALESCE(payload ->> 'd3_emissao', '') AS d3_emissao,
  COALESCE(payload ->> 'd3_op', '') AS d3_op,
  COALESCE(payload ->> 'd3_estorno', '') AS d3_estorno,
  COALESCE(payload ->> 'd_e_l_e_t_', '') AS d_e_l_e_t_,
  COALESCE(NULLIF(payload ->> 'r_e_c_n_o_', '')::numeric, 0) AS r_e_c_n_o_,
  COALESCE(NULLIF(payload ->> 'r_e_c_d_e_l_', '')::numeric, 0) AS r_e_c_d_e_l_
FROM protheus_raw.sd3_movements
WHERE NOT EXISTS (SELECT 1 FROM public.sd3010);

INSERT INTO public.sd4010 (
  d4_filial, d4_op, d4_cod, d4_produto, d4_local, d4_quant, d4_qtdeori,
  d4_sldemp, d4_sldemp2, d4_qtneces, d4_qsusp, d4_qtsegum, d4_data,
  d4_roteiro, d4_trt, d4_situaca, d_e_l_e_t_, r_e_c_n_o_, r_e_c_d_e_l_
)
SELECT
  COALESCE(payload ->> 'd4_filial', '') AS d4_filial,
  COALESCE(payload ->> 'd4_op', '') AS d4_op,
  COALESCE(payload ->> 'd4_cod', '') AS d4_cod,
  COALESCE(payload ->> 'd4_produto', '') AS d4_produto,
  COALESCE(payload ->> 'd4_local', '') AS d4_local,
  COALESCE(NULLIF(payload ->> 'd4_quant', '')::numeric, 0) AS d4_quant,
  COALESCE(NULLIF(payload ->> 'd4_qtdeori', '')::numeric, 0) AS d4_qtdeori,
  COALESCE(NULLIF(payload ->> 'd4_sldemp', '')::numeric, 0) AS d4_sldemp,
  COALESCE(NULLIF(payload ->> 'd4_sldemp2', '')::numeric, 0) AS d4_sldemp2,
  COALESCE(NULLIF(payload ->> 'd4_qtneces', '')::numeric, 0) AS d4_qtneces,
  COALESCE(NULLIF(payload ->> 'd4_qsusp', '')::numeric, 0) AS d4_qsusp,
  COALESCE(NULLIF(payload ->> 'd4_qtsegum', '')::numeric, 0) AS d4_qtsegum,
  COALESCE(payload ->> 'd4_data', '') AS d4_data,
  COALESCE(payload ->> 'd4_roteiro', '') AS d4_roteiro,
  COALESCE(payload ->> 'd4_trt', '') AS d4_trt,
  COALESCE(payload ->> 'd4_situaca', '') AS d4_situaca,
  COALESCE(payload ->> 'd_e_l_e_t_', '') AS d_e_l_e_t_,
  COALESCE(NULLIF(payload ->> 'r_e_c_n_o_', '')::numeric, 0) AS r_e_c_n_o_,
  COALESCE(NULLIF(payload ->> 'r_e_c_d_e_l_', '')::numeric, 0) AS r_e_c_d_e_l_
FROM protheus_raw.sd4_commitments
WHERE NOT EXISTS (SELECT 1 FROM public.sd4010);

ANALYZE public.sb1010;
ANALYZE public.sg1010;
ANALYZE public.sb2010;
ANALYZE public.sc2010;
ANALYZE public.sd3010;
ANALYZE public.sd4010;
