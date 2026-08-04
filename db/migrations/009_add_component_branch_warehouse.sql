BEGIN;

ALTER TABLE vettiflow.production_components
  ADD COLUMN IF NOT EXISTS filial text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS armazem text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS current_stock numeric(14,4) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS committed_quantity numeric(14,4) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS reserved_quantity numeric(14,4) NOT NULL DEFAULT 0;

COMMIT;
