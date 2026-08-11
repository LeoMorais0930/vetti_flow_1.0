-- Carrega protheus_raw.* a partir das tabelas cruas do dump VettiP12
-- que vivem no schema public do mesmo banco (maquina do macOS).
--
-- Na maquina do Leonardo o protheus_raw e populado pelo
-- tools/import_protheus_export_to_postgres.ps1, a partir do export em CSV/JSON.
-- Aqui a origem ja esta no proprio Postgres, entao basta converter cada linha
-- em jsonb: os nomes de coluna do vettip12 ja estao em minusculas, batendo com
-- as chaves que as views protheus_raw.vw_* esperam.
--
-- Idempotente: pode rodar de novo a qualquer momento.
--
-- psql -h localhost -U postgres -d vettip12 -v ON_ERROR_STOP=1 \
--   -f db/local/load_protheus_raw_from_vettip12.sql

BEGIN;

TRUNCATE protheus_raw.sb1_products;
INSERT INTO protheus_raw.sb1_products (source_table, payload)
SELECT 'SB1', to_jsonb(t) FROM public.sb1010 AS t;

TRUNCATE protheus_raw.sc2_orders;
INSERT INTO protheus_raw.sc2_orders (source_table, payload)
SELECT 'SC2', to_jsonb(t) FROM public.sc2010 AS t;

TRUNCATE protheus_raw.sg1_structures;
INSERT INTO protheus_raw.sg1_structures (source_table, payload)
SELECT 'SG1', to_jsonb(t) FROM public.sg1010 AS t;

TRUNCATE protheus_raw.sb2_balances;
INSERT INTO protheus_raw.sb2_balances (source_table, payload)
SELECT 'SB2', to_jsonb(t) FROM public.sb2010 AS t;

TRUNCATE protheus_raw.sd3_movements;
INSERT INTO protheus_raw.sd3_movements (source_table, payload)
SELECT 'SD3', to_jsonb(t) FROM public.sd3010 AS t;

TRUNCATE protheus_raw.sd4_commitments;
INSERT INTO protheus_raw.sd4_commitments (source_table, payload)
SELECT 'SD4', to_jsonb(t) FROM public.sd4010 AS t;

COMMIT;

ANALYZE protheus_raw.sb1_products;
ANALYZE protheus_raw.sc2_orders;
ANALYZE protheus_raw.sg1_structures;
ANALYZE protheus_raw.sb2_balances;
ANALYZE protheus_raw.sd3_movements;
ANALYZE protheus_raw.sd4_commitments;
