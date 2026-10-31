# ADR-0004: Infraestrutura isolada em `vetlab-infra/`

**Status:** Aceito (2026-10-30)

**Contexto:** o repositório misturava, na raiz, arquivos de infraestrutura
(`docker-compose.yml`, `Dockerfile`, `config/`, `init-scripts/`, `data/`) com
arquivos de controle de versão. Ao mesmo tempo, `docker-compose.yml` referenciava
arquivos inexistentes (`docker/postgres/*`, `config/postgresql.conf`,
`config/pg_bouncer/pgbouncer.ini`, `data/pgadmin-conf/servers.json`), e o README
citava serviços (Grafana, exportador de métricas) que não existiam no compose.

**Decisão:** todo o artefato de runtime fica em `vetlab-infra/`, que é também o
diretório de contexto do build e o diretório de projeto do Compose. A raiz
guarda apenas `README.md` e arquivos de controle de versão/edição
(`.gitignore`, `.gitattributes`, `.editorconfig`). Serviços citados mas
inexistentes foram removidos da documentação e do `.env` em vez de
"implementados pela metade".

**Consequências:**

- (+) Um único ponto de entrada (`cd vetlab-infra`) para subir, inspecionar e
  versionar a infraestrutura.
- (+) `.dockerignore` restrito ao diretório da infra — segredos da raiz ficam
  fora do contexto de build.
- (+) Documentação e compose descrevem exatamente o mesmo conjunto de serviços.
- (−) Os comandos exigem `cd vetlab-infra` (ou `--project-directory`).
- (−) Caminhos relativos dentro do compose são relativos a `vetlab-infra/`.

**Alternativas:**

- Manter tudo na raiz: rejeitada — não escala quando a aplicação entrar no
  mesmo repositório.
- Um repositório só para a infra: rejeitada — o ensaio de caso é didático e se
  beneficia de um clone único.

**Revisit trigger:** a aplicação passar a viver no mesmo repositório e precisar
de `docker compose` conjunto.
