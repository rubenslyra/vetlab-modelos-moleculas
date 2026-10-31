-- ---------------------------------------------------------------------------
-- 10-schemas.sql — schemas de domínio do VET-Lab.
--
--   clinica    -> tutores, pacientes, atendimentos, exames
--   genoma     -> sequências, variantes, vetores de embedding (pgvector)
--   auditoria  -> trilha de auditoria (pgaudit + tabelas de histórico)
--
-- O search_path do banco coloca os schemas de domínio à frente de public, de
-- modo que nomes não qualificados resolvem para o domínio.
-- ---------------------------------------------------------------------------
\set ON_ERROR_STOP on

CREATE SCHEMA IF NOT EXISTS clinica;
CREATE SCHEMA IF NOT EXISTS genoma;
CREATE SCHEMA IF NOT EXISTS auditoria;

-- A aplicação é dona dos schemas de domínio; ela cria e evolui suas tabelas.
ALTER SCHEMA clinica OWNER TO :"app_user";
ALTER SCHEMA genoma OWNER TO :"app_user";
ALTER SCHEMA auditoria OWNER TO :"app_user";

COMMENT ON SCHEMA clinica IS 'Dados clínicos: tutores, pacientes, atendimentos e exames';
COMMENT ON SCHEMA genoma IS 'Dados genômicos: sequências, variantes e embeddings (pgvector)';
COMMENT ON SCHEMA auditoria IS 'Trilha de auditoria e histórico de alterações';

-- Princípio do menor privilégio: nada para PUBLIC, tudo via grants explícitos.
REVOKE ALL ON SCHEMA clinica, genoma, auditoria FROM PUBLIC;

ALTER DATABASE :"db_name" SET search_path TO clinica, genoma, auditoria, public;
