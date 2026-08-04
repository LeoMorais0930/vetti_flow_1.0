BEGIN;

CREATE TABLE IF NOT EXISTS protheus_raw.sc2_orders (
  id bigserial PRIMARY KEY,
  source_table text NOT NULL DEFAULT 'SC2',
  payload jsonb NOT NULL,
  c2_filial text GENERATED ALWAYS AS (payload ->> 'c2_filial') STORED,
  c2_num text GENERATED ALWAYS AS (payload ->> 'c2_num') STORED,
  c2_item text GENERATED ALWAYS AS (payload ->> 'c2_item') STORED,
  c2_sequen text GENERATED ALWAYS AS (payload ->> 'c2_sequen') STORED,
  c2_produto text GENERATED ALWAYS AS (payload ->> 'c2_produto') STORED,
  c2_quant numeric GENERATED ALWAYS AS (NULLIF(payload ->> 'c2_quant', '')::numeric) STORED,
  c2_quje numeric GENERATED ALWAYS AS (NULLIF(payload ->> 'c2_quje', '')::numeric) STORED,
  c2_emissao text GENERATED ALWAYS AS (payload ->> 'c2_emissao') STORED,
  c2_datpri text GENERATED ALWAYS AS (payload ->> 'c2_datpri') STORED,
  c2_datprf text GENERATED ALWAYS AS (payload ->> 'c2_datprf') STORED,
  c2_datrf text GENERATED ALWAYS AS (payload ->> 'c2_datrf') STORED,
  c2_status text GENERATED ALWAYS AS (payload ->> 'c2_status') STORED,
  imported_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS protheus_raw.sg1_structures (
  id bigserial PRIMARY KEY,
  source_table text NOT NULL DEFAULT 'SG1',
  payload jsonb NOT NULL,
  g1_filial text GENERATED ALWAYS AS (payload ->> 'g1_filial') STORED,
  g1_cod text GENERATED ALWAYS AS (payload ->> 'g1_cod') STORED,
  g1_comp text GENERATED ALWAYS AS (payload ->> 'g1_comp') STORED,
  g1_quant numeric GENERATED ALWAYS AS (NULLIF(payload ->> 'g1_quant', '')::numeric) STORED,
  g1_ini text GENERATED ALWAYS AS (payload ->> 'g1_ini') STORED,
  g1_fim text GENERATED ALWAYS AS (payload ->> 'g1_fim') STORED,
  imported_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS protheus_raw.sb2_balances (
  id bigserial PRIMARY KEY,
  source_table text NOT NULL DEFAULT 'SB2',
  payload jsonb NOT NULL,
  b2_filial text GENERATED ALWAYS AS (payload ->> 'b2_filial') STORED,
  b2_cod text GENERATED ALWAYS AS (payload ->> 'b2_cod') STORED,
  b2_local text GENERATED ALWAYS AS (payload ->> 'b2_local') STORED,
  b2_qatu numeric GENERATED ALWAYS AS (NULLIF(payload ->> 'b2_qatu', '')::numeric) STORED,
  b2_qemp numeric GENERATED ALWAYS AS (NULLIF(payload ->> 'b2_qemp', '')::numeric) STORED,
  b2_reserva numeric GENERATED ALWAYS AS (NULLIF(payload ->> 'b2_reserva', '')::numeric) STORED,
  imported_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sc2_orders_num
  ON protheus_raw.sc2_orders (c2_num, c2_item, c2_sequen);

CREATE INDEX IF NOT EXISTS idx_sc2_orders_produto
  ON protheus_raw.sc2_orders (c2_produto);

CREATE INDEX IF NOT EXISTS idx_sc2_orders_payload
  ON protheus_raw.sc2_orders USING gin (payload);

CREATE INDEX IF NOT EXISTS idx_sg1_structures_cod
  ON protheus_raw.sg1_structures (g1_cod);

CREATE INDEX IF NOT EXISTS idx_sg1_structures_comp
  ON protheus_raw.sg1_structures (g1_comp);

CREATE INDEX IF NOT EXISTS idx_sg1_structures_payload
  ON protheus_raw.sg1_structures USING gin (payload);

CREATE INDEX IF NOT EXISTS idx_sb2_balances_cod_local
  ON protheus_raw.sb2_balances (b2_cod, b2_local);

CREATE INDEX IF NOT EXISTS idx_sb2_balances_payload
  ON protheus_raw.sb2_balances USING gin (payload);

COMMIT;
