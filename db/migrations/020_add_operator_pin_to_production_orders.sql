BEGIN;

ALTER TABLE IF EXISTS vettiflow.production_orders
  ADD COLUMN IF NOT EXISTS operator_pin_hash text;

COMMIT;
