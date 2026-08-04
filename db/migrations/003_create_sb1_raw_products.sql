BEGIN;

CREATE TABLE IF NOT EXISTS protheus_raw.sb1_products (
  id bigserial PRIMARY KEY,
  source_table text NOT NULL DEFAULT 'SB1',
  payload jsonb NOT NULL,
  b1_filial text GENERATED ALWAYS AS (payload ->> 'b1_filial') STORED,
  b1_cod text GENERATED ALWAYS AS (payload ->> 'b1_cod') STORED,
  b1_desc text GENERATED ALWAYS AS (payload ->> 'b1_desc') STORED,
  b1_tipo text GENERATED ALWAYS AS (payload ->> 'b1_tipo') STORED,
  b1_um text GENERATED ALWAYS AS (payload ->> 'b1_um') STORED,
  b1_grupo text GENERATED ALWAYS AS (payload ->> 'b1_grupo') STORED,
  b1_codite text GENERATED ALWAYS AS (payload ->> 'b1_codite') STORED,
  imported_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sb1_products_cod
  ON protheus_raw.sb1_products (b1_cod);

CREATE INDEX IF NOT EXISTS idx_sb1_products_desc
  ON protheus_raw.sb1_products (b1_desc);

CREATE INDEX IF NOT EXISTS idx_sb1_products_payload
  ON protheus_raw.sb1_products USING gin (payload);

COMMIT;
