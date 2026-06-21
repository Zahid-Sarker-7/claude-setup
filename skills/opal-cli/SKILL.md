---
name: opal-cli
description: Start/stop/manage opal-app Docker stack and opal-tools services for local development
argument-hint: "up [exp|agents|chat|full|ce] | down | status | pull | sync | logs <svc> | clean | restart <svc>"
disable-model-invocation: false
allowed-tools: Bash, Read, AskUserQuestion
---

# Opal CLI — Local Development Manager

Manages the opal-app Docker stack and standalone opal-tools services together.

## Prerequisites

- Docker Desktop running (check: `docker info`)
- `opal-cli` installed at `/usr/local/bin/opal-cli`
- `~/opal-localdev-config.yaml` exists with `workspace: /Users/zahid.sarker/Official/Project`

## Key Facts

- **Standalone `opal-tools/`** (port 8000 locally, 8111 in Docker) = Experimentation tools (your repo). Runs via Poetry locally.
- **`opal-app/tools/opal-tools/`** (port 8012) = VAU/IM tools (different codebase). Runs inside opal-app docker-compose.
- These are completely separate — don't confuse them.
- `opal-cli pull` downloads pre-built CI images. Use this for initial setup, not `opal-cli build`.
- `opal-cli build <service>` only when deps (`pyproject.toml`, `requirements.txt`) or Dockerfile changes.
- Volume mounts = live hot reload for source code changes — no rebuild needed.
- opal-tools registers with TMS automatically via `/discovery` endpoint.

## Commands

### `/opal-cli up [group]`

Starts opal-app services and optionally opal-tools. If no group is specified, **infer from conversation context** using these rules:

| Signal in conversation | Inferred group |
|---|---|
| Working in opal-tools repo, mentions experiments/flags/audiences/entity lifecycle | `exp` |
| Mentions agents, hypatia, workflows, specialized agents | `agents` |
| Mentions chat, primary-agent, no tools needed | `chat` |
| Says "full", "everything", "all services" | `full` |
| Mentions code execution, sandbox, workspace-manager | `ce` |
| Unclear or ambiguous | **Ask the user** |

**Always confirm with the user before starting.** Show the service list and ask if it looks right via AskUserQuestion.

#### Service Groups

**`exp`** — Experimentation tools development (DEFAULT for opal-tools work)

opal-app services (via `opal-cli up`):
```
primary-agent, tools-mgmt-service, opal-api-gateway, opal-nginx,
opal-app-backend, opal-app-frontend, chat-frontend, token-service,
mysql, redis, fake-gcs-server
```

opal-tools (standalone):
```bash
# Terminal 1: Python FastAPI (:8000)
cd /Users/zahid.sarker/Official/Project/opal-tools
make run

# Terminal 2: TypeScript backend (:3000) — runs in Docker
cd /Users/zahid.sarker/Official/Project/opal-tools
make start-opensearch-query
```

**`agents`** — Agent testing

Same as `exp` plus:
```
hypatia, instructions-service, notification-service
```

opal-tools: same as `exp`.

**`chat`** — Chat flow only (no external tools)

opal-app services only:
```
primary-agent, tools-mgmt-service, opal-api-gateway, opal-nginx,
opal-app-backend, opal-app-frontend, chat-frontend, token-service,
mysql, redis, fake-gcs-server
```

No opal-tools started.

**`full`** — All default services

```bash
opal-cli up
```

Plus opal-tools Python + TS backend.

**`ce`** — Code execution

```bash
opal-cli up --profile ce
```

No opal-tools.

#### Startup Sequence

1. Check Docker Desktop is running: `docker info > /dev/null 2>&1`
2. Start opal-app services: `opal-cli up <service-list>` (runs in background)
3. Wait for key services to be healthy: check `opal-cli ps` for mysql, redis, TMS
4. If opal-tools needed:
   - Ensure `.env` exists — if missing, auto-create from `.env.example`:
     ```bash
     if [ ! -f /Users/zahid.sarker/Official/Project/opal-tools/.env ]; then
       cp /Users/zahid.sarker/Official/Project/opal-tools/.env.example \
          /Users/zahid.sarker/Official/Project/opal-tools/.env
     fi
     ```
     If created from example, apply known devel-rc defaults (non-secret placeholders only):
     ```bash
     cd /Users/zahid.sarker/Official/Project/opal-tools
     sed -i '' \
       -e 's|GCP_PROJECT_ID="your-gcp-project-id"|GCP_PROJECT_ID="cmp-development-423512"|' \
       -e 's|EXP_HOST="your-exp-host.optimizely.com"|EXP_HOST="develrc-app.optimizely.com"|' \
       .env
     ```
     Then warn: ".env created with devel-rc defaults. These secrets still need real values for full functionality:
     `HMAC_CLIENT_KEY`, `HMAC_SECRET_KEY`, `EXP_API_HASH_KEY`.
     opal-tools will start fine without them — only Exp API calls that require HMAC auth won't work."
   - Ensure TS backend `.env` exists:
     ```bash
     TS_ENV="/Users/zahid.sarker/Official/Project/opal-tools/src/services/typescript_backend/nodejs/.env"
     if [ ! -f "$TS_ENV" ]; then
       cp "${TS_ENV}.example" "$TS_ENV"
     fi
     ```
     If created from example, warn: "TS backend .env created from .env.example. These need real values:
     `AWS_OPENSEARCH_ENDPOINT`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`.
     The TS backend won't connect to OpenSearch until these are filled in."
   - Start Python in Docker: `cd /Users/zahid.sarker/Official/Project/opal-tools && make start`
     (runs on port 8111 in Docker with hot reload; alternatively `make run` for local Poetry on port 8000)
   - Start TS backend — find a free port and start:
     ```bash
     # Find first free port starting from 3000
     TS_PORT=3000
     while lsof -ti :$TS_PORT > /dev/null 2>&1; do TS_PORT=$((TS_PORT + 1)); done

     cd /Users/zahid.sarker/Official/Project/opal-tools
     if [ "$TS_PORT" -eq 3000 ]; then
       make start-opensearch-query
     else
       echo "Port 3000 occupied, using port $TS_PORT"
       docker run -d --name opal-opensearch-query \
         -p $TS_PORT:3000 \
         --env-file src/services/typescript_backend/nodejs/.env \
         -e SERVER_HOST=0.0.0.0 -e SERVER_PORT=3000 \
         -v $(pwd)/src/services/typescript_backend/nodejs:/app/nodejs \
         opal-tools-opensearch-query:latest \
         node dist/server/index.js
       # Update Python service to point to the new port
       sed -i '' "s|TYPESCRIPT_BACKEND_BASE_URL=.*|TYPESCRIPT_BACKEND_BASE_URL=http://localhost:$TS_PORT|" .env
     fi
     ```
   - Register opal-tools with TMS (so tools are discoverable by primary-agent):
     ```bash
     docker exec opal-mysql mysql -uroot -pzxc90zxc -e "
       INSERT IGNORE INTO \`tools-mgmt-service\`.tools_services
         (id, discovery_url, owner_email, name, date_created, managed_provider)
       VALUES
         ('exp-opal-tools-local', 'http://host.docker.internal:8111/discovery', 'admin@optimizely.com', 'Opal Experimentation Tools', NOW(), 0);
     "
     ```
     Then trigger a sync so TMS fetches the tool definitions (auto-sync — no auth needed):
     ```bash
     curl -s -X POST http://localhost:8010/api/tools-service/exp-opal-tools-local/auto-sync
     ```
5. Verify:
   - `curl -s http://localhost:8111/api/status` (Python health — port 8111 via Docker, 8000 via `make run`)
   - `curl -s http://localhost:3000/health` (TS health)
   - `curl -s http://localhost:8111/discovery | python3 -m json.tool | head -5` (tool discovery)

#### Notes on opal-tools

- `make run` starts ONLY the Python FastAPI service with hot reload
- `make start-opensearch-query` starts the TypeScript backend in a Docker container
- `make start-all` starts Python + TS + Spanner emulator (all in Docker) — use when you also need Spanner
- TS backend requires AWS OpenSearch credentials in `src/services/typescript_backend/nodejs/.env`
- Python service env: `TYPESCRIPT_BACKEND_BASE_URL=http://localhost:3000` (auto-detected on Mac)

### `/opal-cli down`

Stop everything:

```bash
# Stop opal-app containers
opal-cli down

# Stop opal-tools containers
cd /Users/zahid.sarker/Official/Project/opal-tools
docker stop opal-tools 2>/dev/null
docker stop opal-opensearch-query 2>/dev/null

# If running locally via make run instead of Docker
pkill -f "python main.py" 2>/dev/null
```

### `/opal-cli status`

Show current state:

```bash
echo "=== Docker Desktop ==="
docker info --format '{{.ServerVersion}}' 2>/dev/null && echo "running" || echo "NOT RUNNING"

echo "=== opal-app containers ==="
opal-cli ps 2>/dev/null || docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -v "^$"

echo "=== opal-tools Python ==="
docker ps --filter name=opal-tools --format "{{.Status}}" 2>/dev/null | grep -q "Up" && echo "Python (:8111 Docker) running" || \
  (pgrep -f "python main.py" > /dev/null && echo "Python (:8000 local) running" || echo "Python stopped")
curl -s http://localhost:8111/api/status 2>/dev/null || curl -s http://localhost:8000/api/status 2>/dev/null || echo "(not responding)"

echo "=== opal-tools TypeScript ==="
docker ps --filter name=opal-opensearch-query --format "{{.Status}}" 2>/dev/null || echo "stopped"
curl -s http://localhost:3000/health 2>/dev/null && echo "" || echo "(not responding)"

echo "=== Docker disk usage ==="
docker system df 2>/dev/null
```

### `/opal-cli pull`

Download latest CI-built images:

```bash
opal-cli pull
```

Use this instead of `opal-cli build` for initial setup or syncing with the team. Only build when you've changed deps or Dockerfiles.

### `/opal-cli sync`

Re-sync opal-tools with TMS so tool schema changes (new tool, renamed, changed params/description) are picked up by primary-agent.

**When to use:**
- Added or removed a tool
- Changed a tool's name, description, or parameters
- Changed TypeScript backend code (no hot reload in Docker — needs restart)
- NOT needed for Python code-only changes (hot reload handles those)

```bash
# Re-sync tool definitions with TMS
curl -s -X POST http://localhost:8010/api/tools-service/exp-opal-tools-local/auto-sync | python3 -m json.tool

# If TypeScript backend code changed, restart it too
cd /Users/zahid.sarker/Official/Project/opal-tools
make stop-opensearch-query && make start-opensearch-query
```

If opal-tools isn't registered yet, register first then sync:
```bash
docker exec opal-mysql mysql -uroot -pzxc90zxc -e "
  INSERT IGNORE INTO \`tools-mgmt-service\`.tools_services
    (id, discovery_url, owner_email, name, date_created, managed_provider)
  VALUES
    ('exp-opal-tools-local', 'http://host.docker.internal:8000/discovery', 'admin@optimizely.com', 'Opal Experimentation Tools', NOW(), 0);
"
curl -s -X POST http://localhost:8010/api/tools-service/exp-opal-tools-local/auto-sync | python3 -m json.tool
```

### `/opal-cli logs <service>`

```bash
opal-cli logs --tail 100 <service>
# or follow:
opal-cli logs -f <service>
```

For opal-tools Python logs: check the terminal where `make run` is running.
For opal-tools TS logs: `docker logs --tail 100 opal-opensearch-query`

### `/opal-cli clean`

Reclaim disk space:

```bash
echo "=== Build cache ==="
docker builder prune -f

echo "=== Dangling images ==="
docker image prune -f

echo "=== Disk usage after cleanup ==="
docker system df
```

For aggressive cleanup (removes ALL unused images — will require re-pull):
```bash
docker system prune -a
```

### `/opal-cli restart <service>`

For opal-app services:
```bash
opal-cli rebuild <service>
```

For opal-tools Python: kill and restart `make run`.
For opal-tools TS: `make stop-opensearch-query && make start-opensearch-query`.

## Troubleshooting

- **grpcio hash mismatch during build**: Corrupted Docker build cache (0-byte wheel from interrupted download). Fix: `docker builder prune -f` then rebuild.
- **webhook-broker crash loop** (`Data too long for column 'seedData'`): The seed config outgrew the TEXT column. Fix: `docker exec opal-mysql mysql -uroot -pzxc90zxc -e "ALTER TABLE \`webhook-broker\`.app MODIFY COLUMN seedData MEDIUMTEXT;"`then restart: `docker restart opal-webhook-broker`.
- **401 from gateway**: Token expired. User needs to log in via browser, then re-fetch OBO token.
- **opal-tools not discovered by TMS**: Check TMS is running (`opal-cli ps | grep tools-mgmt`), then verify discovery endpoint: `curl http://localhost:8111/discovery` (Docker) or `curl http://localhost:8000/discovery` (local).
- **TS backend won't start**: Check `src/services/typescript_backend/nodejs/.env` has valid AWS OpenSearch credentials.

## Port Reference

| Service | Port | Notes |
|---|---|---|
| opal-tools Python | 8000 (local) / 8111 (Docker) | Standalone, Exp tools |
| opal-tools TS backend | 3000 | OpenSearch query engine |
| primary-agent | 8088 | Main chat LLM |
| TMS | 8000 | Tool registry |
| hypatia | 8026 | Agent engine |
| api-gateway | 3058 | Auth + routing |
| nginx | 443 | SSL termination |
| backend | 8114 | Users, instances |
| opal-app opal-tools | 8012 | VAU/IM tools (different from standalone) |
| MySQL | 3306 | Database |
| Redis | 6379 | Cache |

## URLs

| URL | What |
|---|---|
| https://opal-localdev.optimizely.com | Main Opal app |
| https://dashboards-localdev.opal.optimizely.com:8444 | Admin dashboard |
| http://localhost:8000/docs | opal-tools Swagger UI |
| http://localhost:3000/health | TS backend health |
