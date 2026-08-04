SELECT
  priority AS prioridade,
  protheus_table_prefix AS tabela,
  physical_table_pattern AS padrao_fisico,
  protheus_name AS nome_protheus,
  vettiflow_use AS uso_no_vettiflow,
  important_fields AS campos_importantes,
  extraction_scope AS escopo,
  notes AS observacao
FROM protheus_metadata.vw_vettiflow_required_tables;
