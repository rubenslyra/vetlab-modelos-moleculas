-- ---------------------------------------------------------------------------
-- 00-roles.sql — roles de cluster (não pertencem a um banco específico).
-- Executado no banco administrativo (POSTGRES_DB), uma única vez.
--
-- Uso de psql :'var' (literal) e :"var" (identificador) evita concatenar
-- segredos em texto SQL. Senhas nunca são impressas nos logs.
-- ---------------------------------------------------------------------------
\set ON_ERROR_STOP on

-- Criação idempotente: \gexec executa o CREATE apenas se a role não existir.
SELECT format('CREATE ROLE %I LOGIN', :'app_user')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'app_user')
\gexec

SELECT format('CREATE ROLE %I LOGIN', :'readonly_user')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'readonly_user')
\gexec

-- Garante atributos e senha atuais mesmo em reexecução.
ALTER ROLE :"app_user"
    WITH LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS
    PASSWORD :'app_password';

ALTER ROLE :"readonly_user"
    WITH LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS
    PASSWORD :'readonly_password';

COMMENT ON ROLE :"app_user" IS 'Aplicação VET-Lab (DML nos schemas de domínio)';
COMMENT ON ROLE :"readonly_user" IS 'BI/relatórios VET-Lab (somente leitura)';
