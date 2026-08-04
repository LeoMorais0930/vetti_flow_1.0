BEGIN;

DROP INDEX IF EXISTS idx_sb1_products_cod;
DROP INDEX IF EXISTS idx_sb1_products_desc;

ALTER TABLE protheus_raw.sb1_products
  DROP COLUMN IF EXISTS b1_filial,
  DROP COLUMN IF EXISTS b1_cod,
  DROP COLUMN IF EXISTS b1_desc,
  DROP COLUMN IF EXISTS b1_tipo,
  DROP COLUMN IF EXISTS b1_um,
  DROP COLUMN IF EXISTS b1_grupo,
  DROP COLUMN IF EXISTS b1_codite;

ALTER TABLE protheus_raw.sb1_products
  ADD COLUMN b1_filial text GENERATED ALWAYS AS (payload ->> 'b1_filial') STORED,
  ADD COLUMN b1_cod text GENERATED ALWAYS AS (payload ->> 'b1_cod') STORED,
  ADD COLUMN b1_desc text GENERATED ALWAYS AS (payload ->> 'b1_desc') STORED,
  ADD COLUMN b1_tipo text GENERATED ALWAYS AS (payload ->> 'b1_tipo') STORED,
  ADD COLUMN b1_um text GENERATED ALWAYS AS (payload ->> 'b1_um') STORED,
  ADD COLUMN b1_grupo text GENERATED ALWAYS AS (payload ->> 'b1_grupo') STORED,
  ADD COLUMN b1_codite text GENERATED ALWAYS AS (payload ->> 'b1_codite') STORED;

CREATE INDEX IF NOT EXISTS idx_sb1_products_cod
  ON protheus_raw.sb1_products (b1_cod);

CREATE INDEX IF NOT EXISTS idx_sb1_products_desc
  ON protheus_raw.sb1_products (b1_desc);

COMMIT;
