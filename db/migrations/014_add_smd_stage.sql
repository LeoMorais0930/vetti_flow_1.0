ALTER TYPE vettiflow.production_stage ADD VALUE IF NOT EXISTS 'smd' AFTER 'warehouse';
ALTER TYPE vettiflow.work_stage ADD VALUE IF NOT EXISTS 'smd' AFTER 'dashboard';
