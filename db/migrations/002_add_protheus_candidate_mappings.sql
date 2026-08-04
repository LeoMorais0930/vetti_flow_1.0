BEGIN;

CREATE TABLE IF NOT EXISTS protheus_metadata.vettiflow_candidate_mappings (
  id bigserial PRIMARY KEY,
  area text NOT NULL,
  protheus_table_prefix text NOT NULL,
  likely_physical_table_pattern text NOT NULL,
  purpose text NOT NULL,
  key_fields text[] NOT NULL DEFAULT '{}',
  useful_fields text[] NOT NULL DEFAULT '{}',
  vettiflow_target text,
  confidence text NOT NULL DEFAULT 'candidate',
  notes text,
  reference_url text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (area, protheus_table_prefix)
);

INSERT INTO protheus_metadata.vettiflow_candidate_mappings (
  area,
  protheus_table_prefix,
  likely_physical_table_pattern,
  purpose,
  key_fields,
  useful_fields,
  vettiflow_target,
  confidence,
  notes,
  reference_url
)
VALUES
  (
    'criacao_controle_op',
    'SC2',
    'SC2%, normalmente SC2010/SC2020 conforme empresa/ambiente',
    'Cabecalho da Ordem de Producao. E o primeiro lugar para localizar OP criada no Protheus.',
    ARRAY['C2_FILIAL', 'C2_NUM', 'C2_ITEM', 'C2_SEQUEN'],
    ARRAY['C2_PRODUTO', 'C2_QUANT', 'C2_QUJE', 'C2_EMISSAO', 'C2_DATPRI', 'C2_DATPRF', 'C2_DATRF', 'C2_TPOP', 'D_E_L_E_T_'],
    'vettiflow.production_orders',
    'alta_padrao_protheus',
    'No VettiFlow, C2_NUM/C2_ITEM/C2_SEQUEN devem virar o numero unico da OP. C2_PRODUTO aponta para SB1.B1_COD. Filtrar D_E_L_E_T_ = espaco/vazio.',
    'https://centraldeatendimento.totvs.com/hc/pt-br/articles/360044950994-Manufatura-Linha-Protheus-SIGAPCP-Alterar-o-n%C3%BAmero-da-ordem-de-produ%C3%A7%C3%A3o-sugerida-pelo-Sistema'
  ),
  (
    'produtos_por_codigo',
    'SB1',
    'SB1%, normalmente SB1010/SB1020 conforme empresa/ambiente',
    'Cadastro de Produtos. Usar para puxar produto pelo codigo e mostrar nomes como Central, Controle etc.',
    ARRAY['B1_FILIAL', 'B1_COD'],
    ARRAY['B1_DESC', 'B1_TIPO', 'B1_UM', 'B1_GRUPO', 'B1_CODITE', 'D_E_L_E_T_'],
    'catalogo de produtos do VettiFlow / product_code e product_name',
    'alta_padrao_protheus',
    'Busca principal: B1_COD = codigo digitado/lido. Para telas, exibir B1_COD + B1_DESC. Categorias como Central/Controle podem estar no texto B1_DESC ou agrupadas por B1_GRUPO/B1_TIPO, precisa confirmar na base da Vetti.',
    'https://centraldeatendimento.totvs.com/hc/pt-br/articles/16660636353047-Cross-Segmento-Backoffice-Linha-Protheus-SIGAEST-Numera%C3%A7%C3%A3o-autom%C3%A1tica-no-c%C3%B3digo-do-produto-B1-COD'
  ),
  (
    'estrutura_componentes_bom',
    'SG1',
    'SG1%, normalmente SG1010/SG1020 conforme empresa/ambiente',
    'Estrutura do Produto/BOM. Mostra os componentes que compoem uma Central, Controle ou outro produto acabado.',
    ARRAY['G1_FILIAL', 'G1_COD', 'G1_COMP'],
    ARRAY['G1_DESC', 'G1_QUANT', 'G1_INI', 'G1_FIM', 'D_E_L_E_T_'],
    'vettiflow.production_components',
    'alta_padrao_protheus',
    'G1_COD e o produto pai, normalmente o B1_COD da Central/Controle. G1_COMP e o componente. Juntar G1_COMP com SB1.B1_COD para descricao completa do componente.',
    'https://sempreju.com.br/tabelas_protheus/tabelas/tabela_sg1.html'
  ),
  (
    'estoque_saldo',
    'SB2',
    'SB2%, normalmente SB2010/SB2020 conforme empresa/ambiente',
    'Saldos fisico-financeiros por produto/armazem. Usar para checar disponibilidade de componentes/produtos.',
    ARRAY['B2_FILIAL', 'B2_COD', 'B2_LOCAL'],
    ARRAY['B2_QATU', 'B2_QEMP', 'B2_RESERVA', 'B2_CM1', 'D_E_L_E_T_'],
    'estoque para tela de almoxarifado / disponibilidade',
    'media_alta_padrao_protheus',
    'B2_QATU e saldo atual; B2_QEMP costuma estar ligado a quantidade empenhada para OP. Disponibilidade final pode depender da regra da Vetti.',
    'https://centraldeatendimento.totvs.com/hc/pt-br/articles/4414424489879-Cross-Segmentos-Backoffice-Protheus-SIGAFAT-Preenchimento-dos-campos-de-faturamento-da-tabela-SB2'
  ),
  (
    'movimentos_apontamentos',
    'SD3',
    'SD3%, normalmente SD3010/SD3020 conforme empresa/ambiente',
    'Movimentacoes internas de estoque/producao. Ajuda a auditar consumo, requisicao e entrada de producao vinculada a OP.',
    ARRAY['D3_FILIAL', 'D3_OP', 'D3_COD', 'D3_LOCAL'],
    ARRAY['D3_QUANT', 'D3_EMISSAO', 'D3_TM', 'D3_CF', 'D3_DOC', 'D3_NUMSEQ', 'D_E_L_E_T_'],
    'historico/apontamentos futuros do VettiFlow',
    'media_padrao_protheus',
    'Para VettiFlow inicial, SC2/SB1/SG1 devem vir primeiro. SD3 entra quando quisermos conferir movimentos reais e apontamentos.',
    'https://centraldeatendimento.totvs.com/hc/pt-br/articles/4414744933911-Manufatura-Linha-Protheus-SIGAPCP-Diferen%C3%A7as-entre-as-tabelas-SD3-e-a-SH6'
  ),
  (
    'movimentos_producao_pcp',
    'SH6',
    'SH6%, normalmente SH6010/SH6020 conforme empresa/ambiente',
    'Movimentacoes da producao em rotinas PCP Mod1/Mod2.',
    ARRAY['H6_FILIAL', 'H6_OP'],
    ARRAY['H6_PRODUTO', 'H6_QTDPROD', 'H6_DTAPONT', 'D_E_L_E_T_'],
    'historico/apontamentos futuros do VettiFlow',
    'media_padrao_protheus',
    'A propria TOTVS diferencia SD3 e SH6: SH6 guarda movimentos com operacoes em rotinas PCP; SD3 guarda movimentos de producao/requisicao em certas rotinas.',
    'https://centraldeatendimento.totvs.com/hc/pt-br/articles/4414744933911-Manufatura-Linha-Protheus-SIGAPCP-Diferen%C3%A7as-entre-as-tabelas-SD3-e-a-SH6'
  ),
  (
    'dicionario_tabelas',
    'SX2/SX3',
    'SX2%, SX3%',
    'Dicionario de dados do Protheus. Usar para confirmar nomes, descricoes, tipos e tamanhos dos campos da base da Vetti.',
    ARRAY['X2_CHAVE', 'X3_CAMPO'],
    ARRAY['X2_NOME', 'X3_TITULO', 'X3_DESCRIC', 'X3_TIPO', 'X3_TAMANHO', 'X3_DECIMAL'],
    'protheus_metadata.source_tables/source_columns',
    'alta_para_confirmacao_local',
    'Quando restaurarmos o backup, SX2/SX3 sao o caminho mais confiavel para montar o catalogo real em vez de depender so de conhecimento padrao.',
    NULL
  )
ON CONFLICT (area, protheus_table_prefix)
DO UPDATE SET
  likely_physical_table_pattern = EXCLUDED.likely_physical_table_pattern,
  purpose = EXCLUDED.purpose,
  key_fields = EXCLUDED.key_fields,
  useful_fields = EXCLUDED.useful_fields,
  vettiflow_target = EXCLUDED.vettiflow_target,
  confidence = EXCLUDED.confidence,
  notes = EXCLUDED.notes,
  reference_url = EXCLUDED.reference_url;

CREATE OR REPLACE VIEW protheus_metadata.vw_vettiflow_protheus_map AS
SELECT
  area,
  protheus_table_prefix,
  likely_physical_table_pattern,
  purpose,
  array_to_string(key_fields, ', ') AS key_fields,
  array_to_string(useful_fields, ', ') AS useful_fields,
  vettiflow_target,
  confidence,
  notes,
  reference_url
FROM protheus_metadata.vettiflow_candidate_mappings
ORDER BY
  CASE area
    WHEN 'criacao_controle_op' THEN 1
    WHEN 'produtos_por_codigo' THEN 2
    WHEN 'estrutura_componentes_bom' THEN 3
    WHEN 'estoque_saldo' THEN 4
    WHEN 'movimentos_apontamentos' THEN 5
    WHEN 'movimentos_producao_pcp' THEN 6
    ELSE 7
  END;

COMMIT;
