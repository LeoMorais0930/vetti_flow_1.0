BEGIN;

CREATE TABLE IF NOT EXISTS vettiflow.production_flow_events (
  id bigserial PRIMARY KEY,
  order_number text REFERENCES vettiflow.production_orders(number) ON DELETE CASCADE,
  event_type text NOT NULL,
  stage vettiflow.production_stage,
  run_status vettiflow.production_run_status,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_flow_events_order_created
  ON vettiflow.production_flow_events (order_number, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_flow_events_type_created
  ON vettiflow.production_flow_events (event_type, created_at DESC);

COMMIT;
