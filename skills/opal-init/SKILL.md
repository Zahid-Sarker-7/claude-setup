---
name: opal-init
description: Initialize opal-app localdev from scratch — Docker, certs, hosts, opal-cli, pull, and first run
argument-hint: "[step-name] — resume from a specific step, or run without args for full guided setup"
disable-model-invocation: false
allowed-tools: Bash, Read, AskUserQuestion, WebSearch
---

# opal-init — Opal App Local Environment Setup

Guided setup for running opal-app locally from a fresh Mac. Detects what's already installed, skips completed steps, and walks through the rest.

## Prerequisites Check

Run this first to detect current state. Report results as a table to the user.

```bash
echo "=== System ==="
uname -m                                          # Should be arm64
sw_vers --productVersion                          # macOS version

echo "=== Required Tools ==="
which brew     2>/dev/null && echo "brew: installed"         || echo "brew: MISSING"
which docker   2>/dev/null && docker --version 2>/dev/null   || echo "docker: MISSING"
which go       2>/dev/null && go version 2>/dev/null         || echo "go: MISSING"
which gcloud   2>/dev/null && echo "gcloud: installed"       || echo "gcloud: MISSING"
which jq       2>/dev/null && echo "jq: installed"           || echo "jq: MISSING"
which yq       2>/dev/null && echo "yq: installed"           || echo "yq: MISSING"
which mkcert   2>/dev/null && echo "mkcert: installed"       || echo "mkcert: MISSING"
which jf       2>/dev/null && echo "jfrog-cli: installed"    || echo "jfrog-cli: MISSING"
which opal-cli 2>/dev/null && opal-cli version 2>/dev/null   || echo "opal-cli: MISSING"

echo "=== Configuration ==="
cat ~/opal-localdev-config.yaml 2>/dev/null       || echo "workspace config: MISSING"
ls ~/.config/gcloud/application_default_credentials.json 2>/dev/null || echo "GCP ADC: MISSING"
ls ~/.opal_jfrog_token 2>/dev/null                || echo "JFrog token: MISSING"
cat ~/.opal-jfrog-config 2>/dev/null | head -1    || echo "JFrog env config: MISSING"
cat ~/.docker/config.json 2>/dev/null | grep -q "us-central1-docker.pkg.dev" && echo "GCP Docker registry: configured" || echo "GCP Docker registry: MISSING"
ls /Users/zahid.sarker/Official/Project/opal-app/localdev/certs/opal-localdev.crt 2>/dev/null || echo "SSL certs: MISSING"
grep -q opal /etc/hosts 2>/dev/null && echo "/etc/hosts: configured" || echo "/etc/hosts: MISSING"

echo "=== Docker Desktop Settings (manual check) ==="
echo "Verify in Docker Desktop → Settings:"
echo "  General: VirtioFS ON, Rosetta ON, Docker VMM OFF"
echo "  Resources: RAM 16GB, Swap 4GB, CPU/Disk keep defaults"
```

Show the user a status table, then proceed with only the missing steps.

## Steps

### Step 1: Install Docker Desktop

**Skip if:** `docker --version` succeeds.

```bash
brew install --cask docker
```

Then tell the user to open Docker Desktop from Applications and wait for the whale icon in the menu bar.

**Optional: Docker Desktop optimization.** Ask the user if they want to configure Docker for optimal opal-app performance. If yes:

**Settings → General:**
- Use Virtualization framework → ON
- Use Rosetta for x86_64/amd64 → ON
- Choose file sharing: **VirtioFS**
- Do NOT enable Docker VMM

**Settings → Resources → Advanced:**
- Memory: **16 GB**
- Swap: **4 GB**
- CPUs and Disk: **keep defaults**

**Settings → Docker Engine** (replace JSON):
```json
{
  "builder": {
    "gc": {
      "defaultKeepStorage": "20GB",
      "enabled": true
    }
  },
  "features": {
    "buildkit": true
  },
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "max-concurrent-downloads": 10,
  "max-concurrent-uploads": 5
}
```

If user skips, Docker defaults work fine — optimization just improves volume mount speed and prevents log bloat.

Wait for user confirmation before proceeding.

### Step 2: Install CLI Tools

**Skip if:** all of `yq`, `mkcert`, `jf` are installed.

```bash
brew install yq mkcert jfrog-cli
```

### Step 3: Configure JFrog

**Skip if:** `~/.opal_jfrog_token` and `~/.opal-jfrog-config` exist.

Tell the user:
1. Go to https://optimizely.jfrog.io/
2. Log in with Optimizely SSO
3. Profile (top right) → Edit Profile → Generate an Identity Token
4. Copy the token

Then run:
```bash
cd /Users/zahid.sarker/Official/Project/opal-app
make configure-jfrog
# When prompted, paste the token

make extract-jfrog-credentials
```

Verify:
```bash
cat ~/.opal-jfrog-config | head -3
```

### Step 4: Configure GCP Docker Registry

**Skip if:** `~/.docker/config.json` contains `us-central1-docker.pkg.dev`.

```bash
gcloud auth configure-docker us-central1-docker.pkg.dev --quiet
gcloud config set project opal-app-integration
gcloud auth application-default set-quota-project opal-app-integration
```

If GCP ADC is also missing:
```bash
gcloud auth application-default login --no-launch-browser
```

### Step 5: Create Workspace Config

**Skip if:** `~/opal-localdev-config.yaml` exists.

```bash
cd /Users/zahid.sarker/Official/Project/opal-app
make setup-workspace
```

When prompted, enter: `/Users/zahid.sarker/Official/Project`

**IMPORTANT:** This must be done BEFORE Steps 6 and 7. The Makefile reads this file to find the workspace path. Without it, `make configure-ssl` and `make update-hosts` will fail with "Read-only file system" errors.

### Step 6: Generate SSL Certificates

**Skip if:** `localdev/certs/opal-localdev.crt` exists.

```bash
mkcert -install    # Installs local CA (prompts for password)

cd /Users/zahid.sarker/Official/Project/opal-app
make configure-ssl
```

### Step 7: Configure /etc/hosts

**Skip if:** `grep -q opal /etc/hosts` succeeds.

```bash
cd /Users/zahid.sarker/Official/Project/opal-app
make update-hosts    # Prompts for password
```

### Step 8: Build & Install opal-cli

**Skip if:** `opal-cli version` succeeds.

```bash
cd /Users/zahid.sarker/Official/Project/opal-app/localdev/cli-wrapper
go build -ldflags "-X main.Version=$(cat VERSION)" -o opal-cli .
sudo mv opal-cli /usr/local/bin/

cd /Users/zahid.sarker/Official/Project/opal-app
make install-autocomplete
```

### Step 9: Pull Images

```bash
opal-cli pull
```

Expected: 30+ images pull successfully. A few may fail (ce-executor, spanner-init, evals-dev) — these are non-essential and can be built locally if needed later.

### Step 10: First Run

```bash
opal-cli up primary-agent tools-mgmt-service opal-api-gateway opal-app-backend opal-app-frontend chat-frontend token-service
```

Wait for all services to show healthy, then:

**Fix webhook-broker if it crash-loops** (common on first run):
```bash
docker exec opal-mysql mysql -uroot -pzxc90zxc -e "ALTER TABLE \`webhook-broker\`.app MODIFY COLUMN seedData MEDIUMTEXT;"
docker restart opal-webhook-broker
```

**Run MySQL migrations:**
```bash
docker exec opal-mysql sh -c 'mysql -uroot -pzxc90zxc < /docker-entrypoint-initdb.d/04-oauth-gateway.sql'
docker exec opal-mysql sh -c 'mysql -uroot -pzxc90zxc < /docker-entrypoint-initdb.d/05-remote-mcp-server.sql'
docker exec opal-mysql sh -c 'mysql -uroot -pzxc90zxc < /docker-entrypoint-initdb.d/authz-indexer.sql'
docker exec opal-mysql sh -c 'mysql -uroot -pzxc90zxc < /docker-entrypoint-initdb.d/notification-service.sql'
docker exec opal-mysql sh -c 'mysql -uroot -pzxc90zxc < /docker-entrypoint-initdb.d/workspace-manager.sql'
```

**Clear changelog:**
```bash
opal-cli changelog --mark-read
```

**Start any remaining "Created" containers:**
```bash
docker start primary-agent system-tools opal-app-frontend 2>/dev/null
```

### Step 11: Verify

```bash
echo "=== Service Health ==="
docker ps --format "table {{.Names}}\t{{.Status}}" | grep -v Exited | sort

echo "=== Gateway ==="
curl -s -k -o /dev/null -w "%{http_code}" https://opal-localdev.optimizely.com
```

Then tell the user to open: **https://opal-localdev.optimizely.com/instances/4ba0da0ede704f81ab4cd075c87e177e/chat**

Localdev instance ID: `4ba0da0ede704f81ab4cd075c87e177e`

## Troubleshooting

### "Read-only file system" during `make configure-ssl`
Workspace config missing. Run Step 5 first.

### grpcio hash mismatch during build
Corrupted Docker build cache. Fix: `docker builder prune -f` then rebuild.

### webhook-broker crash loop (`Data too long for column 'seedData'`)
```bash
docker exec opal-mysql mysql -uroot -pzxc90zxc -e "ALTER TABLE \`webhook-broker\`.app MODIFY COLUMN seedData MEDIUMTEXT;"
docker restart opal-webhook-broker
```

### 403 on `/api/v1/user/current-user`
Wrong instance ID in URL. Use `4ba0da0ede704f81ab4cd075c87e177e`.

### ce-executor / ce-host-agent / evals-dev fail to pull
These don't exist in the registry. Build locally only if needed: `opal-cli build ce-executor`.

### ce-executor build timeout
Network timeout downloading packages. Not needed for core dev — skip it.

### MySQL/Redis "dependency failed to start"
Usually a healthcheck timing issue. Check `docker ps` — they're probably actually running. If not, `docker restart opal-mysql opal-redis`.

### Docker Desktop slow / high RAM
Check Settings → Resources: RAM should be 16GB (not higher). Enable VirtioFS in General settings. Do NOT enable Docker VMM.

## Reference

- Setup guide doc: `/Users/zahid.sarker/Official/Project/opal-app-local-setup.md`
- Architecture overview: `/Users/zahid.sarker/Official/Project/opal-app-overview.md`
- Docker compose: `/Users/zahid.sarker/Official/Project/opal-app/localdev/docker-compose.yml`
- API gateway routes: `api-gateway/src/config/api-gateway/development.yaml`
- opal-app CLAUDE.md: `/Users/zahid.sarker/Official/Project/opal-app/CLAUDE.md`
