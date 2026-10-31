# 📐 Modelos e Moléculas 🔬 — VET-Lab

**O Banco de Dados Relacional entre a Teoria dos Conjuntos e a Biologia Computacional**

Repositório do ensaio de caso do VET-Lab (Programa 1). Provisiona um ecossistema
PostgreSQL 18 isolado e reprodutível, com extensões analíticas (pgvector,
pgaudit, pg_cron, pg_partman), pool de conexões e interface de administração.

O ambiente é 100 % declarativo: `docker compose up -d --build` cria o cluster,
as roles, o banco `vetlab_db`, os schemas de domínio, as extensões e os grants —
sem passo manual.

---

## 📁 Estrutura do repositório

```
.
├── README.md                  # este arquivo
├── .editorconfig              # convenções de edição (LF, UTF-8, indentação)
├── .gitattributes             # normalização de fim de linha (crítico p/ shell e SQL)
├── .gitignore                 # segredos e dados de runtime
├── artigos/                   # acervo de leitura (PDFs, fichamentos, figuras)
│   ├── pdf/                   # artigos originais
│   ├── notas/                 # fichamentos em Markdown
│   └── figuras/               # imagens extraídas dos PDFs
└── vetlab-infra/              # toda a infraestrutura do laboratório
    ├── docker-compose.yml     # serviços: postgres, pgbouncer, pgadmin
    ├── Dockerfile             # PostgreSQL 18 + extensões do repositório PGDG
    ├── .dockerignore          # contexto de build mínimo
    ├── .env.example           # template de variáveis (copie para .env)
    ├── CREDENTIALS.md         # segredos locais (não versionado)
    ├── config/
    │   ├── postgresql.conf    # parâmetros do servidor (overrides documentados)
    │   ├── pg_hba.conf        # autenticação: socket local + scram-sha-256 em TCP
    │   ├── pgbouncer/         # pgbouncer.ini (pool transacional)
    │   └── pgadmin/           # servers.json (servidores pré-cadastrados)
    ├── docker/
    │   ├── postgres/          # entrypoint TLS, pg-backup, pg-restore
    │   └── pgbouncer/         # entrypoint que gera a userlist em runtime
    ├── init-scripts/          # bootstrap executado uma vez, na criação do volume
    │   ├── 00-bootstrap.sh
    │   └── sql/               # roles → banco → schemas → extensões → grants
    ├── scripts/
    │   └── smoke-test.sh      # verificação de saúde ponta a ponta
    ├── docs/                  # arquitetura e decisões (ADRs)
    └── data/
        └── backups/           # saída de pg-backup (conteúdo não versionado)
```

Regra de ouro: **o que é "do Docker" mora em `vetlab-infra/`** e **o material de
leitura mora em `artigos/`**; a raiz do repositório guarda apenas o README, os
arquivos de controle de versão e o acervo.

---

## 🛠️ Pré-requisitos

### Windows (recomendado)
1. **WSL2** com uma distribuição Linux (Debian/Ubuntu).
2. **Docker Desktop** com backend WSL2 e integração habilitada
   (`Settings > Resources > WSL Integration`).
3. **Windows Terminal**. Para rodar os scripts `.sh`, use **Git Bash** ou um
   terminal WSL com integração do Docker Desktop ativa.

### macOS / Linux
- **Docker Engine** + **Docker Compose v2**.

> **Instalação bare metal não é suportada.** O bootstrap, as extensões, o TLS e
> o pool de conexões são provisionados pela imagem Docker; rodar PostgreSQL
> direto no host exigiria repetir esse provisionamento manualmente.

---

## 🚀 Subir o ambiente

```bash
cd vetlab-infra

# 1. Variáveis de ambiente (no Windows: Copy-Item .env.example .env)
cp .env.example .env

# 2. Preencha as 4 senhas — o compose não sobe com elas vazias
#    (openssl rand -base64 24, uma por role)
${EDITOR:-notepad} .env

# 3. Build + start
docker compose up -d --build

# 4. Conferir status e saúde
docker compose ps
bash ./scripts/smoke-test.sh
```

No primeiro start (volume vazio) o Postgres executa `init-scripts/` e cria
roles, banco, schemas e extensões. O certificado TLS autoassinado é gerado
automaticamente no volume `pglab_certs`.

> **Primeiro boot do pgAdmin** pode levar alguns minutos (importação de
> `servers.json`). A interface fica em <http://localhost:5050>.

---

## 🔌 Serviços e portas

| Serviço | Porta host | Uso |
|---|---|---|
| PostgreSQL 18 | `127.0.0.1:5432` | Administração direta (`postgres`) |
| PgBouncer | `127.0.0.1:6432` | Caminho da aplicação (`svc_app`, pool transacional) |
| pgAdmin 4 | `127.0.0.1:5050` | Interface web |

Todas as portas são configuráveis no `.env` (`POSTGRES_PORT`, `PGBOUNCER_PORT`,
`PGADMIN_PORT`) — útil quando algo já ocupa a porta padrão. As publicações são
amarradas a `127.0.0.1`: o stack não fica acessível a outras máquinas da rede.
Para expor de propósito, troque o prefixo no `docker-compose.yml`
(`"127.0.0.1:..."` → `"..."`).

```bash
# Admin (direto)
psql "host=localhost port=5432 dbname=postgres user=postgres"

# Aplicação (via pooler)
psql "host=localhost port=6432 dbname=vetlab_db user=svc_app"
```

Credenciais locais: veja `vetlab-infra/CREDENTIALS.md` (gerado a partir do
`.env`, **não versionado**).

---

## 🗄️ O que existe no banco

| Objeto | Conteúdo |
|---|---|
| Banco | `vetlab_db` (owner `svc_app`) |
| Schemas | `clinica`, `genoma`, `auditoria` (owner `svc_app`) |
| `search_path` do banco | `clinica, genoma, auditoria, public` |
| Roles | `svc_app` (aplicação), `svc_readonly` (BI, somente leitura) |
| Extensões | `vector`, `pgaudit`, `pg_cron`, `pg_partman`, `hypopg`, `pg_stat_statements`, `pgcrypto`, `pg_trgm`, `unaccent` |
| TLS | `ssl=on`, certificado autoassinado no volume `pglab_certs` |
| Auditoria | `pgaudit` registrando `ddl, role` nos logs do contêiner |

---

## 🔧 Operação

```bash
# Logs
docker compose logs -f postgres

# psql interativo
docker compose exec postgres psql -U postgres -d vetlab_db

# Backup lógico (valida o dump e aplica retenção de BACKUP_RETENTION_DAYS)
docker compose exec -u postgres postgres pg-backup vetlab_db

# Restauração (destrutiva; pede confirmação)
docker compose exec -u postgres postgres \
  pg-restore /backups/vetlab_db_<timestamp>.dump vetlab_db

# Reset completo (apaga dados, recria e roda o bootstrap de novo)
docker compose down -v
docker compose up -d
```

Os backups ficam em `vetlab-infra/data/backups/` no host.

> Restaurar um dump em um banco **diferente** de `vetlab_db` gera um único erro
> esperado do `pg_cron` (`can only create extension in database vetlab_db`); o
> restante da restauração é aplicado normalmente.

---

## 🔐 Segurança (leia antes de reutilizar)

- Nenhuma senha tem valor padrão: o `.env.example` publica os campos vazios e o
  compose **recusa subir** (`defina POSTGRES_PASSWORD no .env`) até você gerar as
  suas. Use uma senha distinta por role (`openssl rand -base64 24`).
- TCP exige `scram-sha-256`; `trust` vale apenas para o socket local do
  contêiner.
- O certificado TLS é autoassinado (`sslmode=require` funciona;
  `verify-full` exigirá distribuir o `.crt`).
- `pgAdmin` está em modo desktop, sem master password — adequado apenas para
  uso local.
- Segredos nunca entram na imagem: o contexto de build é limitado pelo
  `.dockerignore`.

---

## 🩺 Problemas comuns

| Sintoma | Causa / solução |
|---|---|
| `port is already allocated` | Outra instância usa a porta. Ajuste `POSTGRES_PORT`, `PGBOUNCER_PORT` ou `PGADMIN_PORT` no `.env`. |
| `database "vetlab_db" does not exist` no log | Mensagem transitória do `pg_cron` durante o bootstrap; some quando o banco é criado. |
| `init-scripts` não rodaram de novo | Eles executam **só com volume vazio**: `docker compose down -v` para recriar. |
| Erro de CRLF em scripts | `.gitattributes` força LF; se o arquivo veio de fora do git, converta para LF. |
| `docker: command not found` no smoke test | Terminal WSL sem integração com Docker Desktop; use Git Bash ou habilite a integração. |
| pgAdmin não abre | Primeiro start lento; acompanhe `docker compose logs -f pgadmin`. |

---

## 📚 Documentação

- `vetlab-infra/docs/guia-instalacao-operacao.pdf` — guia completo em PDF
  (instalação, operação, validação, observações e checklist).
- `vetlab-infra/docs/ARCHITECTURE.md` — componentes, fluxo de dados, modelo de
  segurança.
- `vetlab-infra/docs/decisions/` — ADRs (volume nomeado, PgBouncer, pg_partman,
  layout do repositório).
