BEGIN;

ALTER TABLE vettiflow.production_components
  ADD COLUMN IF NOT EXISTS structure_sequence text NOT NULL DEFAULT '';

COMMIT;
