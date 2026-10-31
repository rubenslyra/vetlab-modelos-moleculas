-- ---------------------------------------------------------------------------
-- 30-grants.sql — permissões dentro de vetlab_db.
--
-- Modelo:
--   svc_app      -> USAGE + CREATE nos schemas de domínio (dono dos objetos)
--   svc_readonly -> USAGE nos schemas + SELECT em tabelas existentes e futuras
--   PUBLIC       -> nada além de CONNECT (revogado) e USAGE em public
-- ---------------------------------------------------------------------------
\set ON_ERROR_STOP on

-- --- Banco ----------------------------------------------------------------
REVOKE ALL ON DATABASE :"db_name" FROM PUBLIC;
GRANT CONNECT ON DATABASE :"db_name" TO :"app_user", :"readonly_user";

-- --- Schema public (extensões) -------------------------------------------
REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO :"app_user", :"readonly_user";

-- --- Schemas de domínio ---------------------------------------------------
GRANT USAGE, CREATE ON SCHEMA clinica, genoma, auditoria TO :"app_user";
GRANT USAGE ON SCHEMA clinica, genoma, auditoria TO :"readonly_user";

-- --- Objetos já existentes (reexecução segura) ----------------------------
GRANT SELECT ON ALL TABLES IN SCHEMA clinica, genoma, auditoria TO :"readonly_user";
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA clinica, genoma, auditoria TO :"readonly_user";

-- --- Objetos futuros criados pela aplicação -------------------------------
ALTER DEFAULT PRIVILEGES FOR ROLE :"app_user" IN SCHEMA clinica, genoma, auditoria
    GRANT SELECT ON TABLES TO :"readonly_user";
ALTER DEFAULT PRIVILEGES FOR ROLE :"app_user" IN SCHEMA clinica, genoma, auditoria
    GRANT USAGE, SELECT ON SEQUENCES TO :"readonly_user";

-- --- Cron: leitura da agenda de jobs para a aplicação ---------------------
GRANT USAGE ON SCHEMA cron TO :"app_user", :"readonly_user";
GRANT SELECT ON ALL TABLES IN SCHEMA cron TO :"app_user", :"readonly_user";
