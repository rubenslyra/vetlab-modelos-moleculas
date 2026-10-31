# ADR-0001: Volumes nomeados para dados do PostgreSQL, certificados e pgAdmin

**Status:** Aceito (2026-10-30)

**Contexto:** o projeto precisa rodar em Windows (Docker Desktop/WSL2), macOS e
Linux. `initdb` exige que `PGDATA` tenha permissão `0700`, e o PostgreSQL recusa
chave privada legível por grupo/outros. Bind mounts a partir de NTFS/APFS não
preservam permissões POSIX: `chmod` não tem efeito e o primeiro start falha com
`could not change permissions`. Além disso, o pgAdmin roda como uid 5050 e
precisa escrever em `/var/lib/pgadmin`.

**Decisão:** estado do PostgreSQL, certificados TLS e dados do pgAdmin vivem em
volumes nomeados (`pgdata`, `pglab_certs`, `pgadmin_data`). Bind mounts ficam
restritos a conteúdo versionado e somente leitura (`config/`, `init-scripts/`) e
à saída de backups (`./data/backups`).

**Consequências:**

- (+) Funciona igual nos três sistemas operacionais, sem passo manual de `chmod`.
- (+) `pg_upgrade --link` funciona porque o volume cobre `/var/lib/postgresql`.
- (−) Inspecionar dados exige `docker compose exec` / `docker compose cp`.
- (−) `docker compose down -v` apaga o cluster (comportamento esperado).

**Alternativas:**

- Bind mount `./database:/var/lib/postgresql`: rejeitada — permissões POSIX
  inconsistentes em Windows/macOS e risco de commit acidental de dados.
- Volume anônimo: rejeitada — sem nome estável para backup/inspeção.

**Revisit trigger:** adotar um orquestrador que gerencie permissões (Kubernetes
com `fsGroup`) ou distribuir em Linux puro com bind mount controlado.
