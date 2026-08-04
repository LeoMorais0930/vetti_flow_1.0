BEGIN;

CREATE TABLE IF NOT EXISTS protheus_metadata.vettiflow_required_tables (
  id bigserial PRIMARY KEY,
  priority text NOT NULL,
  protheus_table_prefix text NOT NULL,
  physical_table_pattern text NOT NULL,
  protheus_name text NOT NULL,
  vettiflow_use text NOT NULL,
  important_fields text[] NOT NULL DEFAULT '{}',
  extraction_scope text NOT NULL DEFAULT 'tabela_inteira',
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (priority, protheus_table_prefix)
);

INSERT INTO protheus_metadata.vettiflow_required_tables (
  priority,
  protheus_table_prefix,
  physical_table_pattern,
  protheus_name,
  vettiflow_use,
  important_fields,
  extraction_scope,
  notes
)
VALUES
  (
    'obrigatoria',
    'SB1',
    'SB1%',
    'Cadastro de Produtos',
    'Catalogo de produtos por codigo, descricao, unidade, grupo/tipo e dados completos do produto.',
    ARRAY['B1_FILIAL', 'B1_COD', 'B1_DESC', 'B1_TIPO', 'B1_UM', 'B1_GRUPO', 'B1_CODITE', 'D_E_L_E_T_'],
    'tabela_inteira',
    'Essa e a primeira tabela a extrair. O VettiFlow precisa dela para buscar Central, Controle e qualquer produto por codigo.'
  ),
  (
    'obrigatoria',
    'SC2',
    'SC2%',
    'Ordens de Producao',
    'Lista de OPs abertas/finalizadas, produto da OP, quantidade, datas e status base do Protheus.',
    ARRAY['C2_FILIAL', 'C2_NUM', 'C2_ITEM', 'C2_SEQUEN', 'C2_PRODUTO', 'C2_QUANT', 'C2_QUJE', 'C2_EMISSAO', 'C2_DATPRI', 'C2_DATPRF', 'C2_DATRF', 'C2_TPOP', 'D_E_L_E_T_'],
    'tabela_inteira',
    'Base para alimentar dashboard, kanban, TV e telas de etapas com as OPs reais.'
  ),
  (
    'obrigatoria',
    'SG1',
    'SG1%',
    'Estruturas dos Produtos',
    'Componentes/BOM do produto fabricado para almoxarifado e previsao de materiais por OP.',
    ARRAY['G1_FILIAL', 'G1_COD', 'G1_COMP', 'G1_QUANT', 'G1_INI', 'G1_FIM', 'D_E_L_E_T_'],
    'tabela_inteira',
    'G1_COD e o produto pai; G1_COMP e o componente. Juntar com SB1 para descricao dos componentes.'
  ),
  (
    'obrigatoria',
    'SB2',
    'SB2%',
    'Saldos Fisico e Financeiro',
    'Saldo de estoque por produto/armazem para almoxarifado e disponibilidade de componentes.',
    ARRAY['B2_FILIAL', 'B2_COD', 'B2_LOCAL', 'B2_QATU', 'B2_QEMP', 'B2_RESERVA', 'D_E_L_E_T_'],
    'tabela_inteira',
    'Permite mostrar estoque atual e possivel disponibilidade dos componentes.'
  ),
  (
    'recomendada',
    'SD4',
    'SD4%',
    'Empenhos/Requisicoes ligadas a OP',
    'Materiais efetivamente empenhados/requisitados para OP, se a Vetti quiser refletir o que o Protheus gerou e nao apenas calcular pela SG1.',
    ARRAY['D4_FILIAL', 'D4_OP', 'D4_COD', 'D4_QUANT', 'D4_LOCAL', 'D_E_L_E_T_'],
    'tabela_inteira',
    'Usar se o almoxarifado precisar comparar estrutura prevista x empenho real da OP.'
  ),
  (
    'recomendada',
    'SD3',
    'SD3%',
    'Movimentos Internos',
    'Historico de movimentos de estoque/producao para auditoria, consumo e entrada vinculada a OP.',
    ARRAY['D3_FILIAL', 'D3_OP', 'D3_COD', 'D3_QUANT', 'D3_EMISSAO', 'D3_TM', 'D3_LOCAL', 'D_E_L_E_T_'],
    'tabela_inteira',
    'Nao e obrigatoria para a primeira carga, mas ajuda quando o VettiFlow precisar conferir movimentos reais.'
  ),
  (
    'recomendada',
    'SH6',
    'SH6%',
    'Apontamentos/Movimentos PCP',
    'Apontamentos de producao conforme rotina PCP usada no Protheus.',
    ARRAY['H6_FILIAL', 'H6_OP', 'H6_PRODUTO', 'H6_QTDPROD', 'H6_DTAPONT', 'D_E_L_E_T_'],
    'tabela_inteira',
    'Confirmar se a Vetti usa SH6, SD3 ou ambos para apontamento.'
  ),
  (
    'apoio',
    'SX2',
    'SX2%',
    'Dicionario de Tabelas',
    'Nomes/descricoes das tabelas reais do ambiente.',
    ARRAY['X2_CHAVE', 'X2_NOME'],
    'tabela_inteira',
    'Ajuda a confirmar sufixos fisicos como SB1010, SC2010 etc.'
  ),
  (
    'apoio',
    'SX3',
    'SX3%',
    'Dicionario de Campos',
    'Titulos, descricoes, tipos e tamanhos dos campos.',
    ARRAY['X3_CAMPO', 'X3_TITULO', 'X3_DESCRIC', 'X3_TIPO', 'X3_TAMANHO', 'X3_DECIMAL'],
    'tabela_inteira',
    'Muito util para montar a integracao sem depender de memoria de campo.'
  ),
  (
    'opcional_futuro',
    'NNR',
    'NNR%',
    'Armazens',
    'Descricao dos armazens/locais de estoque.',
    ARRAY['NNR_CODIGO', 'NNR_DESCRI', 'D_E_L_E_T_'],
    'tabela_inteira',
    'Usar se o VettiFlow precisar mostrar nome do armazem em vez de apenas o codigo B2_LOCAL.'
  ),
  (
    'opcional_futuro',
    'SBM',
    'SBM%',
    'Grupos de Produtos',
    'Descricao dos grupos de produto.',
    ARRAY['BM_GRUPO', 'BM_DESC', 'D_E_L_E_T_'],
    'tabela_inteira',
    'Usar se Central/Controle estiverem organizados por grupo e nao apenas por B1_DESC.'
  ),
  (
    'opcional_futuro',
    'SB8',
    'SB8%',
    'Saldos por Lote/Sublote',
    'Rastreabilidade por lote/sublote, se aplicavel aos produtos da Vetti.',
    ARRAY['B8_FILIAL', 'B8_PRODUTO', 'B8_LOCAL', 'B8_LOTECTL', 'B8_SALDO', 'D_E_L_E_T_'],
    'tabela_inteira',
    'So pedir se a Vetti controlar lote/sublote no Protheus.'
  )
ON CONFLICT (priority, protheus_table_prefix)
DO UPDATE SET
  physical_table_pattern = EXCLUDED.physical_table_pattern,
  protheus_name = EXCLUDED.protheus_name,
  vettiflow_use = EXCLUDED.vettiflow_use,
  important_fields = EXCLUDED.important_fields,
  extraction_scope = EXCLUDED.extraction_scope,
  notes = EXCLUDED.notes;

CREATE OR REPLACE VIEW protheus_metadata.vw_vettiflow_required_tables AS
SELECT
  priority,
  protheus_table_prefix,
  physical_table_pattern,
  protheus_name,
  vettiflow_use,
  array_to_string(important_fields, ', ') AS important_fields,
  extraction_scope,
  notes
FROM protheus_metadata.vettiflow_required_tables
ORDER BY
  CASE priority
    WHEN 'obrigatoria' THEN 1
    WHEN 'recomendada' THEN 2
    WHEN 'apoio' THEN 3
    ELSE 4
  END,
  protheus_table_prefix;

COMMIT;
