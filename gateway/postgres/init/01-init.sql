-- PostgreSQL initialization for llm-gateway
-- This runs once on first container startup

-- Create extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create additional indexes for LiteLLM performance
-- These supplement the indexes created by LiteLLM migrations.
-- Guarded with exception handlers because on first boot this init script runs
-- before LiteLLM creates its tables.

DO $$ BEGIN
    -- Index for spend logs by key and date
    CREATE INDEX IF NOT EXISTS idx_spend_logs_key_date
    ON spend_logs (api_key, start_time DESC);
EXCEPTION WHEN undefined_table THEN NULL; END $$;

DO $$ BEGIN
    -- Index for audit logs by user and date
    CREATE INDEX IF NOT EXISTS idx_audit_logs_user_date
    ON audit_logs (user_id, created_at DESC);
EXCEPTION WHEN undefined_table THEN NULL; END $$;

DO $$ BEGIN
    -- Index for team membership lookups
    CREATE INDEX IF NOT EXISTS idx_team_membership_user
    ON team_membership (user_id);
EXCEPTION WHEN undefined_table THEN NULL; END $$;

DO $$ BEGIN
    -- Index for key lookups by hash
    CREATE INDEX IF NOT EXISTS idx_keys_hash
    ON keys (key_hash);
EXCEPTION WHEN undefined_table THEN NULL; END $$;

DO $$ BEGIN
    -- Index for budget tracking
    CREATE INDEX IF NOT EXISTS idx_budgets_key_period
    ON budgets (key_id, budget_duration);
EXCEPTION WHEN undefined_table THEN NULL; END $$;

-- Grant permissions to litellm user
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO litellm;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO litellm;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO litellm;

-- Set default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO litellm;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO litellm;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO litellm;