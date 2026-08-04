BEGIN;

ALTER TABLE vettiflow.production_components
  ADD COLUMN IF NOT EXISTS requirement_source text NOT NULL DEFAULT 'SG1',
  ADD COLUMN IF NOT EXISTS source_order text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS commitment_date text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS original_quantity numeric(14,4) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS commitment_quantity numeric(14,4) NOT NULL DEFAULT 0;

COMMIT;
