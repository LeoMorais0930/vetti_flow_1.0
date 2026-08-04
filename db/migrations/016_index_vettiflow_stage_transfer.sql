CREATE INDEX IF NOT EXISTS idx_sd3_vettiflow_stage_transfer
  ON protheus_raw.sd3_movements ((payload ->> 'vettiflow_stage_transfer_id'))
  WHERE payload ? 'vettiflow_stage_transfer_id';
