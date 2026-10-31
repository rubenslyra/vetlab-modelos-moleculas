-- ---------------------------------------------------------------------------
-- 20-extensions.sql — extensões habilitadas no banco da aplicação.
--
-- As extensões que exigem shared_preload_libraries
-- (pg_stat_statements, pgaudit, pg_cron, pg_partman_bgw) já estão pré-carregadas
-- em config/postgresql.conf; aqui apenas materializamos os objetos no banco.
-- ---------------------------------------------------------------------------
\set ON_ERROR_STOP on

-- Observabilidade e auditoria
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS pgaudit;

-- Utilidades de dados
CREATE EXTENSION IF NOT EXISTS pgcrypto;   -- gen_random_uuid(), digest()
CREATE EXTENSION IF NOT EXISTS pg_trgm;    -- busca textual por similaridade
CREATE EXTENSION IF NOT EXISTS unaccent;   -- normalização para busca

-- Domínio genômico / busca vetorial
CREATE EXTENSION IF NOT EXISTS vector;     -- pgvector: colunas e índices vetoriais

-- Manutenção e experimentação de plano
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_partman;
CREATE EXTENSION IF NOT EXISTS hypopg;     -- índices hipotéticos (análise de plano)
