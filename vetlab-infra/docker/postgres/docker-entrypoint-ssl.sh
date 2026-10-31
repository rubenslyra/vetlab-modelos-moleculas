#!/usr/bin/env bash
# Entrypoint do contêiner PostgreSQL do VET-Lab.
#
# Responsabilidade única: garantir que exista um par certificado/chave TLS
# autoassinado em POSTGRES_SSL_CERT_DIR antes de o servidor subir e, em seguida,
# delegar tudo para o entrypoint oficial da imagem postgres.
#
# Só executa a geração quando o primeiro argumento é "postgres"; qualquer outro
# comando (pg_dump, psql, bash...) passa direto, sem efeito colateral.
set -Eeuo pipefail

CERT_DIR="${POSTGRES_SSL_CERT_DIR:-/etc/postgresql/certs}"
CERT_FILE="${CERT_DIR}/server.crt"
KEY_FILE="${CERT_DIR}/server.key"
SSL_SUBJECT="${POSTGRES_SSL_SUBJECT:-/CN=localhost}"
SSL_SAN="${POSTGRES_SSL_SAN:-DNS:localhost,DNS:postgres,DNS:pgbouncer,IP:127.0.0.1}"
SSL_DAYS="${POSTGRES_SSL_DAYS:-3650}"

log() { printf '[entrypoint-ssl] %s\n' "$*" >&2; }

generate_certificates() {
    if [[ -s "$CERT_FILE" && -s "$KEY_FILE" ]]; then
        log "certificado existente em ${CERT_DIR} (reaproveitado)"
        return 0
    fi

    log "gerando certificado autoassinado (subject=${SSL_SUBJECT} san=${SSL_SAN} validade=${SSL_DAYS}d)"
    mkdir -p "$CERT_DIR"
    openssl req -x509 -nodes -newkey rsa:4096 -days "$SSL_DAYS" \
        -keyout "$KEY_FILE" -out "$CERT_FILE" \
        -subj "$SSL_SUBJECT" -addext "subjectAltName=${SSL_SAN}" >/dev/null 2>&1

    # O PostgreSQL recusa chaves legíveis por grupo/outros usuários.
    chmod 600 "$KEY_FILE"
    chmod 644 "$CERT_FILE"
}

if [[ "${1:-}" == "postgres" ]]; then
    generate_certificates
    if [[ "$(id -u)" == "0" ]]; then
        chown -R postgres:postgres "$CERT_DIR"
    fi
fi

exec /usr/local/bin/docker-entrypoint.sh "$@"
