#!/bin/sh
# ---------------------------------------------------------------------------
# VET-Lab — bootstrap do cluster (executado uma única vez, na criação do volume
# de dados, pelo entrypoint oficial da imagem postgres).
#
# Ordem das operações:
#   1. roles de cluster (svc_app, svc_readonly)          -> sql/00-roles.sql
#   2. banco de aplicação (vetlab_db)                    -> sql/01-database.sql
#   3. objetos internos do banco (schemas, extensões, grants)
#
# O corpo roda em subshell de propósito: o entrypoint oficial "source" este
# arquivo quando ele não tem bit de execução (comum ao copiar o projeto entre
# Windows/Linux sem git), e o subshell impede que `set -eu` vaze para ele.
# ---------------------------------------------------------------------------
(
    set -eu

    # Contrato de variáveis — falha cedo e com mensagem clara.
    : "${POSTGRES_DB:?POSTGRES_DB não definido}"
    : "${SVC_DB_NAME:?SVC_DB_NAME não definido}"
    : "${SVC_DB_USER:?SVC_DB_USER não definido}"
    : "${SVC_DB_PASSWORD:?SVC_DB_PASSWORD não definido}"
    : "${SVC_DB_READONLY_USER:?SVC_DB_READONLY_USER não definido}"
    : "${SVC_DB_READONLY_PASSWORD:?SVC_DB_READONLY_PASSWORD não definido}"

    SQL_DIR="/docker-entrypoint-initdb.d/sql"

    log() { printf '[bootstrap] %s\n' "$*" >&2; }

    psql_cluster() {
        psql -v ON_ERROR_STOP=1 -q \
            --dbname="$POSTGRES_DB" \
            --set=db_name="$SVC_DB_NAME" \
            --set=app_user="$SVC_DB_USER" \
            --set=app_password="$SVC_DB_PASSWORD" \
            --set=readonly_user="$SVC_DB_READONLY_USER" \
            --set=readonly_password="$SVC_DB_READONLY_PASSWORD" \
            --file="$1"
    }

    psql_database() {
        psql -v ON_ERROR_STOP=1 -q \
            --dbname="$SVC_DB_NAME" \
            --set=db_name="$SVC_DB_NAME" \
            --set=app_user="$SVC_DB_USER" \
            --set=readonly_user="$SVC_DB_READONLY_USER" \
            --file="$1"
    }

    log "1/3 roles de cluster"
    psql_cluster "$SQL_DIR/00-roles.sql"

    log "2/3 banco de aplicação '${SVC_DB_NAME}'"
    psql_cluster "$SQL_DIR/01-database.sql"

    log "3/3 schemas, extensões e permissões em '${SVC_DB_NAME}'"
    for file in "$SQL_DIR"/10-schemas.sql "$SQL_DIR"/20-extensions.sql "$SQL_DIR"/30-grants.sql; do
        psql_database "$file"
    done

    log "concluído: banco=${SVC_DB_NAME} app=${SVC_DB_USER} readonly=${SVC_DB_READONLY_USER}"
)
