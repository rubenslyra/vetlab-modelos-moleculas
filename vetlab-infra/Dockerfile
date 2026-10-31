# syntax=docker/dockerfile:1
# ---------------------------------------------------------------------------
# Imagem PostgreSQL do VET-Lab.
#
# Base oficial postgres:18 (Debian trixie) + pacotes do repositório PGDG que já
# vem configurado na imagem. Instalamos apenas extensões efetivamente
# habilitadas por init-scripts/sql/20-extensions.sql — nada de pacote órfão.
# ---------------------------------------------------------------------------
ARG POSTGRES_MAJOR=18
FROM postgres:${POSTGRES_MAJOR}

ARG POSTGRES_MAJOR

LABEL org.opencontainers.image.title="vetlab-postgres" \
      org.opencontainers.image.description="PostgreSQL ${POSTGRES_MAJOR} com pgvector, pgaudit, pg_cron, pg_partman e hypopg para o VET-Lab" \
      org.opencontainers.image.vendor="VET-Lab"

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        openssl \
        "postgresql-${POSTGRES_MAJOR}-pgvector" \
        "postgresql-${POSTGRES_MAJOR}-pgaudit" \
        "postgresql-${POSTGRES_MAJOR}-cron" \
        "postgresql-${POSTGRES_MAJOR}-partman" \
        "postgresql-${POSTGRES_MAJOR}-hypopg" \
    ; \
    rm -rf /var/lib/apt/lists/*; \
    # Falha o build se algum módulo esperado não tiver sido instalado.
    for so in pg_stat_statements auto_explain vector pgaudit pg_cron \
              pg_partman_bgw hypopg pgcrypto pg_trgm unaccent; do \
        test -e "/usr/lib/postgresql/${POSTGRES_MAJOR}/lib/${so}.so"; \
    done

# Diretórios de configuração, certificados e backups (os volumes são montados
# em runtime: pglab_certs e ./data/backups).
RUN set -eux; \
    mkdir -p /etc/postgresql/certs /backups; \
    chown -R postgres:postgres /etc/postgresql /backups

COPY docker/postgres/docker-entrypoint-ssl.sh /usr/local/bin/docker-entrypoint-ssl.sh
COPY docker/postgres/pg-backup               /usr/local/bin/pg-backup
COPY docker/postgres/pg-restore              /usr/local/bin/pg-restore

RUN set -eux; \
    chmod 0755 /usr/local/bin/docker-entrypoint-ssl.sh \
               /usr/local/bin/pg-backup \
               /usr/local/bin/pg-restore; \
    for f in /usr/local/bin/docker-entrypoint-ssl.sh /usr/local/bin/pg-backup /usr/local/bin/pg-restore; do \
        bash -n "$f"; \
        printf 'syntax OK: %s\n' "$f"; \
    done

ENTRYPOINT ["/usr/local/bin/docker-entrypoint-ssl.sh"]
CMD ["postgres"]
