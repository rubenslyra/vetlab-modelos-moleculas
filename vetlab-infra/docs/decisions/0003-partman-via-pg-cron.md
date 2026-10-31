# ADR-0003: Manutenção do pg_partman via pg_cron (sem background worker)

**Status:** Aceito (2026-10-30)

**Contexto:** durante os testes de boot, `pg_partman_bgw` (pré-carregado)
abortava com `exit code 1` porque, no instante em que o servidor sobe, nem o
banco `vetlab_db` nem a role `svc_app` existem — eles são criados depois, pelos
`init-scripts`. O worker não é reiniciado até um restart do servidor.

**Decisão:** não pré-carregar `pg_partman_bgw`. A manutenção de partições é
agendada com `pg_cron`, que já está habilitado no banco `vetlab_db`
(`cron.database_name`). O pg_partman 5.x recomenda explicitamente essa
combinação em detrimento do worker embutido.

**Consequências:**

- (+) Boot limpo, sem erro de background worker nem restart manual necessário.
- (+) Uma única agenda (pg_cron) para toda a manutenção.
- (+) `shared_preload_libraries` fica menor: `pg_stat_statements`, `pgaudit`,
  `pg_cron`.
- (−) A manutenção precisa de um job explícito em `cron.job`
  (`SELECT partman.run_maintenance('schema.tabela')`).

**Alternativas:**

- Manter o worker: rejeitada — falha determinística no primeiro boot.
- `cron.database_name = 'postgres'`: rejeitada — espalha a agenda em dois bancos.

**Revisit trigger:** pg_partman passar a suportar inicialização tardia do worker
ou o projeto adotar outro agendador.
