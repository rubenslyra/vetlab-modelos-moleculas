#!/bin/sh
# Entrypoint do PgBouncer do VET-Lab.
#
# A imagem oficial do PgBouncer não gera userlist.txt. Este wrapper materializa
# as credenciais vindas do ambiente em /etc/pgbouncer/userlist.txt (modo 600,
# dentro do filesystem do contêiner — nunca no host nem no repositório) e então
# entrega o controle ao binário do PgBouncer com o pgbouncer.ini versionado.
set -eu

AUTH_FILE="${PGBOUNCER_AUTH_FILE:-/etc/pgbouncer/userlist.txt}"
CONFIG_FILE="${PGBOUNCER_CONFIG:-/etc/pgbouncer/pgbouncer.ini}"

log() { printf '[pgbouncer-entrypoint] %s\n' "$*" >&2; }

: "${SVC_DB_USER:?SVC_DB_USER não definido}"
: "${SVC_DB_PASSWORD:?SVC_DB_PASSWORD não definido}"

umask 077
tmp_file="${AUTH_FILE}.tmp"
: >"$tmp_file"

# Escapa aspas duplas para manter o formato `"usuario" "senha"` do PgBouncer.
append_user() {
    user="$1"
    password="$2"
    [ -n "$user" ] || return 0
    [ -n "$password" ] || return 0
    escaped_user=$(printf '%s' "$user" | sed 's/"/\\"/g')
    escaped_password=$(printf '%s' "$password" | sed 's/"/\\"/g')
    printf '"%s" "%s"\n' "$escaped_user" "$escaped_password" >>"$tmp_file"
}

append_user "$SVC_DB_USER" "$SVC_DB_PASSWORD"
append_user "${SVC_DB_READONLY_USER:-}" "${SVC_DB_READONLY_PASSWORD:-}"
# O superusuário entra na userlist para poder usar o console de administração
# do PgBouncer (`psql -p 6432 -U postgres pgbouncer`).
append_user "${POSTGRES_USER:-}" "${POSTGRES_PASSWORD:-}"

mv "$tmp_file" "$AUTH_FILE"
chmod 600 "$AUTH_FILE"
log "userlist gerada com $(wc -l <"$AUTH_FILE") usuário(s) em ${AUTH_FILE}"

exec /opt/pgbouncer/pgbouncer "$CONFIG_FILE"
