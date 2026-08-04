SELECT 'SB1 produtos' AS origem, count(*) AS total FROM protheus_raw.sb1_products
UNION ALL
SELECT 'SC2 ordens' AS origem, count(*) AS total FROM protheus_raw.sc2_orders
UNION ALL
SELECT 'SG1 estruturas' AS origem, count(*) AS total FROM protheus_raw.sg1_structures
UNION ALL
SELECT 'SB2 saldos' AS origem, count(*) AS total FROM protheus_raw.sb2_balances
UNION ALL
SELECT 'SD4 empenhos' AS origem, count(*) AS total FROM protheus_raw.sd4_commitments
UNION ALL
SELECT 'SD3 movimentos' AS origem, count(*) AS total FROM protheus_raw.sd3_movements
ORDER BY origem;
