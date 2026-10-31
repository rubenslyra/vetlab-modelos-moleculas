#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Verificação de saúde do stack VET-Lab (executar após `docker compose up -d`).
#
# Uso (do host, com Docker rodando):
#   ./scripts/smoke-test.sh
#
# Cada verificação imprime PASS/FAIL; o script termina com código != 0 se
# qualquer uma falhar.
# ---------------------------------------------------------------------------
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$COMPOSE_DIR"

if [[ ! -f .env ]]; then
    echo "ERRO: .env não encontrado em ${COMPOSE_DIR} (copie de .env.example)" >&2
    exit 2
fi

set -a
# shellcheck disable=SC1091
. ./.env
set +a

PASS=0
FAIL=0

ok() { printf '  [PASS] %s\n' "$1"; PASS=$((PASS + 1)); }
no() {
    printf '  [FAIL] %s\n' "$1"
    if [[ -n "${2:-}" ]]; then
        printf '         %s\n' "$(printf '%s' "$2" | head -3)"
    fi
    FAIL=$((FAIL + 1))
}

# expect <esperado> <descrição> <comando...>
expect() {
    local expected="$1" description="$2"
    shift 2
    local output
    if output="$("$@" 2>&1)" && [[ "$output" == "$expected" ]]; then
        ok "$description"
    else
        no "$description" "esperado='${expected}' obtido='${output}'"
    fi
}

# expect_failure <descrição> <padrão de erro> <comando...>
expect_failure() {
    local description="$1" pattern="$2"
    shift 2
    local output
    if output="$("$@" 2>&1)"; then
        no "$description" "o comando deveria falhar, mas retornou: ${output}"
    elif printf '%s' "$output" | grep -qi -- "$pattern"; then
        ok "$description"
    else
        no "$description" "falhou pelo motivo errado: ${output}"
    fi
}

direct_sql() {
    docker compose exec -T postgres \
        psql -q -X -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$SVC_DB_NAME" -tAc "$1"
}

pooler_sql() {
    docker compose exec -T -e PGPASSWORD="$1" postgres \
        psql -q -X -v ON_ERROR_STOP=1 -h pgbouncer -p 6432 -U "$2" -d "$SVC_DB_NAME" -tAc "$3"
}

echo "VET-Lab — smoke test (${COMPOSE_DIR})"
echo

echo "[containers]"
for service in postgres pgbouncer pgadmin; do
    if docker compose ps --status running --services | grep -qx "$service"; then
        ok "serviço '${service}' em execução"
    else
        no "serviço '${service}' em execução"
    fi
done

echo
echo "[postgres]"
if docker compose exec -T postgres pg_isready -q -U "$POSTGRES_USER" -d "$POSTGRES_DB"; then
    ok "PostgreSQL aceita conexão (pg_isready)"
else
    no "PostgreSQL aceita conexão (pg_isready)"
fi
expect "on" "TLS habilitado (ssl=on)" direct_sql "show ssl"

for schema in clinica genoma auditoria; do
    expect "1" "schema '${schema}' existe" \
        direct_sql "select 1 from pg_namespace where nspname = '${schema}'"
done

for extension in vector pgaudit pg_cron pg_partman hypopg pg_stat_statements pg_trgm unaccent pgcrypto; do
    expect "1" "extensão '${extension}' instalada" \
        direct_sql "select 1 from pg_extension where extname = '${extension}'"
done

expect "1" "role '${SVC_DB_USER}' existe" \
    direct_sql "select 1 from pg_roles where rolname = '${SVC_DB_USER}'"
expect "1" "role '${SVC_DB_READONLY_USER}' existe" \
    direct_sql "select 1 from pg_roles where rolname = '${SVC_DB_READONLY_USER}'"
expect "clinica, genoma, auditoria, public" "search_path do banco aponta para os schemas de domínio" \
    direct_sql "select setting from pg_settings where name = 'search_path'"

echo
echo "[pgbouncer]"
expect "1" "${SVC_DB_USER} conecta via pooler (6432)" \
    pooler_sql "$SVC_DB_PASSWORD" "$SVC_DB_USER" "select 1"
expect "1" "${SVC_DB_READONLY_USER} conecta via pooler (6432)" \
    pooler_sql "$SVC_DB_READONLY_PASSWORD" "$SVC_DB_READONLY_USER" "select 1"
expect_failure "${SVC_DB_READONLY_USER} não pode criar objetos" "permission denied" \
    pooler_sql "$SVC_DB_READONLY_PASSWORD" "$SVC_DB_READONLY_USER" \
    "create table clinica._smoke_readonly (id int)"

echo
echo "[pgadmin]"
# O pgAdmin pode levar alguns minutos no primeiro start (import de servers.json).
# Qualquer resposta HTTP < 500 conta como "servindo" (sem sessão, /login
# devolve 401 por falta de CSRF — isso é esperado).
pgadmin_url="http://localhost:${PGADMIN_PORT:-5050}"
pgadmin_code="000"
for _ in $(seq 1 60); do
    pgadmin_code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "${pgadmin_url}/" || true)"
    if [[ "$pgadmin_code" =~ ^[1-4][0-9][0-9]$ ]]; then
        break
    fi
    pgadmin_code="000"
    sleep 3
done
if [[ "$pgadmin_code" != "000" ]]; then
    ok "pgAdmin responde em ${pgadmin_url} (HTTP ${pgadmin_code})"
else
    no "pgAdmin responde em ${pgadmin_url}" "sem resposta após 180s — veja 'docker compose logs pgadmin'"
fi

echo
echo "[backup]"
if docker compose exec -T -u postgres postgres pg-backup "$SVC_DB_NAME"; then
    ok "pg-backup gerou e validou um dump"
else
    no "pg-backup gerou e validou um dump"
fi

echo
echo "Resultado: ${PASS} PASS / ${FAIL} FAIL"
[[ "$FAIL" -eq 0 ]]
