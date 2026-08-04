BEGIN;

DROP VIEW IF EXISTS protheus_raw.vw_sb2_stock_balances;

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
