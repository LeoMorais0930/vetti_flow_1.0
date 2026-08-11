BEGIN;

CREATE SCHEMA IF NOT EXISTS vettiflow;
CREATE SCHEMA IF NOT EXISTS protheus_metadata;
CREATE SCHEMA IF NOT EXISTS protheus_raw;

DO $$
BEGIN
  CREATE TYPE vettiflow.production_stage AS ENUM (
    'warehouse',
    'smd',
    'firmware',
    'soldering',
    'testing',
    'closing',
    'expedition',
    'storage',
    'completed'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE TYPE vettiflow.production_run_status AS ENUM (
    'waiting',
    'active',
    'paused',
    'completed'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE TYPE vettiflow.status_op AS ENUM (
    'a_abrir',
    'nao_iniciada',
    'em_andamento',
    'finalizada'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE TYPE vettiflow.work_area AS ENUM (
    'production',
    'smd',
    'warehouse',
    'support',
    'system'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE TYPE vettiflow.work_stage AS ENUM (
    'dashboard',
    'smd',
    'firmware',
    'soldering',
    'testing',
    'closing',
    'expedition',
    'warehouse',
    'support',
    'tv'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS protheus_metadata.backup_imports (
  id bigserial PRIMARY KEY,
  backup_path text NOT NULL,
  source_database text NOT NULL,
  backup_started_at timestamptz,
  backup_finished_at timestamptz,
  sql_server_version text,
  collation_name text,
  compressed_backup_size_bytes bigint,
  original_data_size_bytes bigint,
  original_log_size_bytes bigint,
  status text NOT NULL DEFAULT 'discovered',
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS protheus_metadata.source_tables (
  id bigserial PRIMARY KEY,
  backup_import_id bigint REFERENCES protheus_metadata.backup_imports(id) ON DELETE SET NULL,
  source_schema text NOT NULL DEFAULT 'dbo',
  source_table text NOT NULL,
  source_description text,
  row_count_estimate bigint,
  primary_key_columns text[] NOT NULL DEFAULT '{}',
  used_by_vettiflow boolean NOT NULL DEFAULT false,
  mapped_to text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (backup_import_id, source_schema, source_table)
);

CREATE TABLE IF NOT EXISTS protheus_metadata.source_columns (
  id bigserial PRIMARY KEY,
  source_table_id bigint NOT NULL REFERENCES protheus_metadata.source_tables(id) ON DELETE CASCADE,
  source_column text NOT NULL,
  ordinal_position integer NOT NULL,
  sql_server_type text NOT NULL,
  max_length integer,
  numeric_precision integer,
  numeric_scale integer,
  is_nullable boolean NOT NULL,
  column_description text,
  mapped_to text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (source_table_id, source_column)
);

CREATE TABLE IF NOT EXISTS protheus_raw.records (
  id bigserial PRIMARY KEY,
  source_table text NOT NULL,
  source_key text,
  payload jsonb NOT NULL,
  imported_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS vettiflow.operators (
  id bigserial PRIMARY KEY,
  name text NOT NULL,
  username text NOT NULL,
  password_hash text,
  pin_hash text,
  role text NOT NULL DEFAULT 'Operador',
  area vettiflow.work_area NOT NULL DEFAULT 'production',
  default_stage vettiflow.work_stage NOT NULL,
  uses_assigned_stage boolean NOT NULL DEFAULT false,
  can_manage_assignments boolean NOT NULL DEFAULT false,
  manages_area vettiflow.work_area,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (username, default_stage, role)
);

CREATE TABLE IF NOT EXISTS vettiflow.production_orders (
  number text PRIMARY KEY,
  product_code text NOT NULL DEFAULT '',
  product_name text NOT NULL,
  quantity integer NOT NULL CHECK (quantity >= 0),
  current_stage vettiflow.production_stage NOT NULL DEFAULT 'warehouse',
  run_status vettiflow.production_run_status NOT NULL DEFAULT 'waiting',
  op_status vettiflow.status_op NOT NULL DEFAULT 'a_abrir',
  priority text NOT NULL DEFAULT 'Media',
  progress_percent integer NOT NULL DEFAULT 0 CHECK (progress_percent BETWEEN 0 AND 100),
  responsavel text,
  operator_name text,
  opened_at date,
  due_date date,
  month_label text,
  is_late boolean NOT NULL DEFAULT false,
  closed_quantity integer NOT NULL DEFAULT 0 CHECK (closed_quantity >= 0),
  stored_quantity integer NOT NULL DEFAULT 0 CHECK (stored_quantity >= 0),
  dispatched_quantity integer NOT NULL DEFAULT 0 CHECK (dispatched_quantity >= 0),
  last_observation text,
  planned_stages jsonb NOT NULL DEFAULT '[]'::jsonb,
  source_table text,
  source_key text,
  source_payload jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  synchronized_at timestamptz
);

CREATE TABLE IF NOT EXISTS vettiflow.production_components (
  id bigserial PRIMARY KEY,
  order_number text NOT NULL REFERENCES vettiflow.production_orders(number) ON DELETE CASCADE,
  component_code text NOT NULL DEFAULT '',
  description text NOT NULL,
  quantity numeric(14,4) NOT NULL DEFAULT 0,
  stock numeric(14,4) NOT NULL DEFAULT 0,
  structure_sequence text NOT NULL DEFAULT '',
  source_payload jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS vettiflow.production_stage_timings (
  id bigserial PRIMARY KEY,
  order_number text NOT NULL REFERENCES vettiflow.production_orders(number) ON DELETE CASCADE,
  stage vettiflow.production_stage NOT NULL,
  started_at timestamptz,
  completed_at timestamptz,
  paused_at timestamptz,
  paused_duration_ms bigint NOT NULL DEFAULT 0 CHECK (paused_duration_ms >= 0),
  UNIQUE (order_number, stage)
);

CREATE TABLE IF NOT EXISTS vettiflow.production_operator_sessions (
  id bigserial PRIMARY KEY,
  order_number text NOT NULL REFERENCES vettiflow.production_orders(number) ON DELETE CASCADE,
  stage vettiflow.production_stage NOT NULL,
  operator_name text NOT NULL,
  operator_pin_hash text,
  started_at timestamptz NOT NULL,
  completed_at timestamptz,
  paused_at timestamptz,
  paused_duration_ms bigint NOT NULL DEFAULT 0 CHECK (paused_duration_ms >= 0),
  produced_quantity integer NOT NULL DEFAULT 0 CHECK (produced_quantity >= 0)
);

CREATE TABLE IF NOT EXISTS vettiflow.production_pause_events (
  id bigserial PRIMARY KEY,
  order_number text NOT NULL REFERENCES vettiflow.production_orders(number) ON DELETE CASCADE,
  stage vettiflow.production_stage NOT NULL,
  operator_name text NOT NULL,
  operator_pin_hash text,
  reason text NOT NULL,
  custom_reason text,
  produced_quantity integer NOT NULL DEFAULT 0 CHECK (produced_quantity >= 0),
  created_at timestamptz NOT NULL,
  resumed_at timestamptz
);

CREATE TABLE IF NOT EXISTS vettiflow.production_defects (
  id bigserial PRIMARY KEY,
  order_number text NOT NULL REFERENCES vettiflow.production_orders(number) ON DELETE CASCADE,
  code text NOT NULL,
  title text NOT NULL,
  quantity integer NOT NULL CHECK (quantity >= 0),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_source_tables_used
  ON protheus_metadata.source_tables (used_by_vettiflow, source_table);

CREATE INDEX IF NOT EXISTS idx_source_columns_name
  ON protheus_metadata.source_columns (source_column);

CREATE INDEX IF NOT EXISTS idx_raw_records_source
  ON protheus_raw.records (source_table, source_key);

CREATE INDEX IF NOT EXISTS idx_raw_records_payload
  ON protheus_raw.records USING gin (payload);

CREATE INDEX IF NOT EXISTS idx_orders_stage_status
  ON vettiflow.production_orders (current_stage, run_status);

CREATE INDEX IF NOT EXISTS idx_orders_due_date
  ON vettiflow.production_orders (due_date);

CREATE INDEX IF NOT EXISTS idx_orders_source
  ON vettiflow.production_orders (source_table, source_key);

CREATE INDEX IF NOT EXISTS idx_components_order
  ON vettiflow.production_components (order_number);

CREATE INDEX IF NOT EXISTS idx_sessions_order_stage
  ON vettiflow.production_operator_sessions (order_number, stage);

COMMIT;
