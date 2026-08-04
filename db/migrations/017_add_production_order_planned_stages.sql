ALTER TABLE IF EXISTS vettiflow.production_orders
ADD COLUMN IF NOT EXISTS planned_stages jsonb NOT NULL DEFAULT '[]'::jsonb;
