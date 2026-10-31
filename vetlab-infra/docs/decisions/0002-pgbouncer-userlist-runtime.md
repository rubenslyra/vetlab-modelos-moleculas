# ADR-0002: PgBouncer em pool transacional com userlist gerada no start

**Status:** Aceito (2026-10-30)

**Contexto:** a aplicação abre muitas conexões curtas; `max_connections = 100`
no PostgreSQL não deve ser consumido por sessões ociosas. A imagem oficial
`pgbouncer/pgbouncer` não gera `userlist.txt`, e o modo `transaction` exige que
cada conexão de servidor seja autenticada de forma independente. Guardar a
userlist no repositório significaria versionar segredos.

**Decisão:** `pool_mode = transaction`, `auth_type = scram-sha-256`, e um
entrypoint próprio (`docker/pgbouncer/entrypoint.sh`) que materializa a userlist
em `/etc/pgbouncer/userlist.txt` (modo 600, dentro do filesystem do contêiner) a
partir de `SVC_DB_*` e `POSTGRES_*`. O `pgbouncer.ini` permanece versionado.

**Consequências:**

- (+) Nenhum segredo em texto claro no repositório ou no host.
- (+) `svc_app`/`svc_readonly` autenticam por SCRAM, e o pooler fala TLS com o
  servidor (`server_tls_sslmode` padrão `prefer`).
- (+) Console de administração funciona (`admin_users = postgres`).
- (−) Trocar senha exige `ALTER ROLE` + restart do PgBouncer.
- (−) `transaction` não suporta `PREPARE`, `LISTEN`/`NOTIFY` nem cursores
  nomeados entre transações — quem precisar disso deve ir direto na 5432.

**Alternativas:**

- `auth_query` + `SECURITY DEFINER` (sem userlist): rejeitada por adicionar um
  objeto privilegiado no banco e depender do suporte a SCRAM pass-through.
- `pool_mode = session`: rejeitada — neutraliza o ganho de multiplexação.
- Userlist versionada com hash: rejeitada — PgBouncer precisa da senha em claro
  para autenticar no servidor via SCRAM.

**Revisit trigger:** necessidade de `LISTEN/NOTIFY` ou de rotação de senha sem
restart.
