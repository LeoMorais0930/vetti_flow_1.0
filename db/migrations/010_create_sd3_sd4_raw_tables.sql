BEGIN;

CREATE TABLE IF NOT EXISTS protheus_raw.sd4_commitments (
  id bigserial PRIMARY KEY,
  source_table text NOT NULL DEFAULT 'SD4',
  payload jsonb NOT NULL,
  d4_filial text GENERATED ALWAYS AS (payload ->> 'd4_filial') STORED,
  d4_cod text GENERATED ALWAYS AS (payload ->> 'd4_cod') STORED,
  d4_local text GENERATED ALWAYS AS (payload ->> 'd4_local') STORED,
  d4_op text GENERATED ALWAYS AS (payload ->> 'd4_op') STORED,
  d4_data text GENERATED ALWAYS AS (payload ->> 'd4_data') STORED,
  d4_qtdeori numeric GENERATED ALWAYS AS (NULLIF(trim(payload ->> 'd4_qtdeori'), '')::numeric) STORED,
  d4_quant numeric GENERATED ALWAYS AS (NULLIF(trim(payload ->> 'd4_quant'), '')::numeric) STORED,
  d4_sldemp numeric GENERATED ALWAYS AS (NULLIF(trim(payload ->> 'd4_sldemp'), '')::numeric) STORED,
  d4_produto text GENERATED ALWAYS AS (payload ->> 'd4_produto') STORED,
  d4_qtneces numeric GENERATED ALWAYS AS (NULLIF(trim(payload ->> 'd4_qtneces'), '')::numeric) STORED,
  d4_trt text GENERATED ALWAYS AS (payload ->> 'd4_trt') STORED,
  imported_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS protheus_raw.sd3_movements (
  id bigserial PRIMARY KEY,
  source_table text NOT NULL DEFAULT 'SD3',
  payload jsonb NOT NULL,
  d3_filial text GENERATED ALWAYS AS (payload ->> 'd3_filial') STORED,
  d3_cod text GENERATED ALWAYS AS (payload ->> 'd3_cod') STORED,
  d3_quant numeric GENERATED ALWAYS AS (NULLIF(trim(payload ->> 'd3_quant'), '')::numeric) STORED,
  d3_cf text GENERATED ALWAYS AS (payload ->> 'd3_cf') STORED,
  d3_op text GENERATED ALWAYS AS (payload ->> 'd3_op') STORED,
  d3_local text GENERATED ALWAYS AS (payload ->> 'd3_local') STORED,
  d3_doc text GENERATED ALWAYS AS (payload ->> 'd3_doc') STORED,
  d3_emissao text GENERATED ALWAYS AS (payload ->> 'd3_emissao') STORED,
  d3_estorno text GENERATED ALWAYS AS (payload ->> 'd3_estorno') STORED,
  imported_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sd4_commitments_op
  ON protheus_raw.sd4_commitments (d4_filial, d4_op);

CREATE INDEX IF NOT EXISTS idx_sd4_commitments_cod_local
  ON protheus_raw.sd4_commitments (d4_cod, d4_local);

CREATE INDEX IF NOT EXISTS idx_sd4_commitments_payload
  ON protheus_raw.sd4_commitments USING gin (payload);

CREATE INDEX IF NOT EXISTS idx_sd3_movements_op
  ON protheus_raw.sd3_movements (d3_filial, d3_op);

CREATE INDEX IF NOT EXISTS idx_sd3_movements_cod_local
  ON protheus_raw.sd3_movements (d3_cod, d3_local);

CREATE INDEX IF NOT EXISTS idx_sd3_movements_payload
  ON protheus_raw.sd3_movements USING gin (payload);

COMMIT;
