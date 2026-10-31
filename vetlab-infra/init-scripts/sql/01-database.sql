-- ---------------------------------------------------------------------------
-- 01-database.sql — banco principal do VET-Lab.
-- Idempotente: só cria se ainda não existir.
-- ---------------------------------------------------------------------------
\set ON_ERROR_STOP on

SELECT format('CREATE DATABASE %I OWNER %I', :'db_name', :'app_user')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'db_name')
\gexec
