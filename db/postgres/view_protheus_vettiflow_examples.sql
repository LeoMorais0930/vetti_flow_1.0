-- Produtos por texto.
SELECT codigo, descricao, tipo, unidade, grupo
FROM protheus_raw.vw_sb1_products
WHERE descricao ILIKE '%CENTRAL%'
ORDER BY codigo
LIMIT 30;

-- OPs recentes com descricao do produto.
SELECT
  op,
  produto_codigo,
  produto_descricao,
  quantidade_planejada,
  quantidade_produzida,
  emissao_aaaammdd,
  fim_previsto_aaaammdd,
  status_protheus
FROM protheus_raw.vw_sc2_orders
ORDER BY emissao_aaaammdd DESC NULLS LAST, op DESC
LIMIT 30;

-- Componentes de um produto especifico.
-- Troque o codigo abaixo pelo produto desejado.
SELECT
  produto_codigo,
  produto_descricao,
  componente_codigo,
  componente_descricao,
  quantidade_por_unidade
FROM protheus_raw.vw_sg1_product_structures
WHERE produto_codigo = '730-0863'
ORDER BY componente_codigo;

-- Estoque de um produto/componente.
-- Troque o codigo abaixo pelo produto desejado.
SELECT
  produto_codigo,
  produto_descricao,
  armazem,
  saldo_atual,
  quantidade_empenhada,
  quantidade_reservada,
  saldo_disponivel_estimado
FROM protheus_raw.vw_sb2_stock_balances
WHERE produto_codigo = '730-0863'
ORDER BY armazem;
