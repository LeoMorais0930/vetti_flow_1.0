BEGIN;

CREATE TABLE IF NOT EXISTS vettiflow.warehouse_requests (
  id text PRIMARY KEY,
  order_number text NOT NULL,
  product_code text NOT NULL DEFAULT '',
  product_name text NOT NULL DEFAULT '',
  component_code text NOT NULL DEFAULT '',
  component_description text NOT NULL DEFAULT '',
  quantity integer NOT NULL CHECK (quantity >= 0),
  filial text NOT NULL DEFAULT '04',
  order_warehouse text NOT NULL DEFAULT '',
  requested_warehouse text NOT NULL DEFAULT '',
  requested_by text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'pending',
  response_by text,
  response_pin_hash text,
  response_note text,
  manual boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_warehouse_requests_area
  ON vettiflow.warehouse_requests (requested_warehouse, status);

CREATE INDEX IF NOT EXISTS idx_warehouse_requests_order
  ON vettiflow.warehouse_requests (order_number);

COMMIT;
