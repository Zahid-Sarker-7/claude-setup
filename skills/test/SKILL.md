---
name: test
description: Run tests across any Optimizely project. Default is functional tests (context-aware). Flags: --unit, --pipeline, --all, --before, --after.
argument-hint: "[--unit|--pipeline|--all] [--before|--after] [token] [project_id]"
disable-model-invocation: true
---

# Test — Unified Test Runner

Run unit, pipeline, or functional tests for any project. Auto-detects the project from cwd.

## Usage

```
/test                                # functional tests (default) — needs token
/test --unit                         # unit tests only (no services needed)
/test --pipeline                     # simulate CI pipeline locally
/test --all                          # pipeline first, then functional
/test --before <token>               # functional baseline before development
/test --after <token>                # rebuild + verify after development
/test --unit --pipeline              # both unit and pipeline (no functional)
/test <token>                        # functional with token (shorthand)
/test <token> 5129532268085248       # functional with explicit project_id
```

## Known Projects

| Name | Path | Unit command | Pipeline order |
|------|------|-------------|----------------|
| opal-tools | `/Users/zahid.sarker/Official/Project/opal-tools` | `make test` + jest | editorconfig → isort → black → flake8 → mypy → pytest → jest |
| opal-app | `/Users/zahid.sarker/Official/Project/opal-app` | per-service | per-service format → lint → type check → test |
| frontdoor | `/Users/zahid.sarker/Official/Project/frontdoor` | `cd frontdoor-go && make test` | go fmt → go vet → golangci-lint → go test |
| optimizely | `/Users/zahid.sarker/Official/Project/optimizely` | `cd src/www && ./runtest <path>` | black → ./runtest |
| authz-sdk | `/Users/zahid.sarker/Official/Project/authz-sdk` | `poetry run pytest` | mypy → pytest |

## Step 0 — Parse arguments and detect project

### Current context
```
!`git rev-parse --show-toplevel 2>/dev/null; echo "---"; git branch --show-current 2>/dev/null; echo "---"; git rev-parse --short HEAD 2>/dev/null`
```

From `$ARGUMENTS`, extract:
- **Mode flags**: `--unit`, `--pipeline`, `--all` (default: functional if none)
- **Timing flags**: `--before`, `--after` (only meaningful for functional mode)
- **Token**: any `eyJ...` string (raw JWT, no "Bearer " prefix)
- **Project ID**: any standalone numeric string

Match `$REPO_ROOT` against the known projects table. Also match worktree paths (containing `-wt/` in the path) to their parent project. If not in a git repo, ask the user which project.

For **opal-app**: detect the active service from changed files:
```bash
git diff --name-only HEAD~5 2>/dev/null | cut -d/ -f1 | sort -u | head -10
git status --short | awk '{print $2}' | cut -d/ -f1 | sort -u
```
Use the top-level directory that contains changes (e.g., `tools-mgmt-service/`, `hypatia/`). If multiple or unclear, ask the user.

---

## Mode: `--unit`

No services needed. Run the project's test suite directly.

### opal-tools
```bash
cd <repo>
make test                            # pytest + mypy
cd src/services/typescript_backend/nodejs
NODE_OPTIONS=--experimental-vm-modules npx jest --silent
```

### opal-app (per detected service)

| Service type | How to detect | Command |
|---|---|---|
| Python with Makefile | `Makefile` exists in service dir | `cd <repo>/<service> && make test` |
| Python without Makefile | `pyproject.toml` exists | `cd <repo>/<service> && poetry run pytest tests/` |
| Go | `go.mod` exists | `cd <repo>/<service> && go test -v ./...` |
| Node | `package.json` exists | `cd <repo>/<service> && npm test` |

If no specific service detected from changed files, ask:
```
Multiple services in opal-app. Which one to test?
1. tools-mgmt-service
2. hypatia
3. primary-agent
4. <others from changed files>
```

### frontdoor
```bash
cd <repo>/frontdoor-go && make test
```

### optimizely
```bash
cd <repo>/src/www
```
Determine the test file from changed files:
```bash
git diff --name-only HEAD~5 2>/dev/null | grep '_test\.py$' | head -5
```
If found, run those test files. If not, check which source files changed and find corresponding test files. If still unclear, ask the user for the test path.
```bash
./runtest <test-file>
```

### authz-sdk
```bash
cd <repo>
poetry run pytest
poetry run mypy .
```

### Output format
```
## Unit Test Results — <project> (<service if opal-app>)
Branch: <branch> @ <commit>

<pass/fail summary>
<failure details if any>
```

---

## Mode: `--pipeline`

Simulate the CI pipeline locally. Run checks in the same order as the project's GitHub Actions workflow. **Stop on first failure** and report which step failed.

### opal-tools (mirrors `ci_tests.yml`)
```bash
cd <repo>

# 1. Formatting checks
echo "--- isort ---"
poetry run isort --check-only --diff .

echo "--- black ---"
poetry run black --check .

# 2. Linting
echo "--- flake8 ---"
poetry run flake8

# 3. Type checking
echo "--- mypy ---"
poetry run mypy .

# 4. Python tests
echo "--- pytest ---"
poetry run pytest -v

# 5. TypeScript tests
echo "--- jest ---"
cd src/services/typescript_backend/nodejs
NODE_OPTIONS=--experimental-vm-modules npx jest --silent
```

### opal-app (per detected service)

**Python services:**
```bash
cd <repo>/<service>
echo "--- format check ---"
make check-format 2>/dev/null || poetry run black --check .

echo "--- lint ---"
make lint 2>/dev/null || make check-lint 2>/dev/null || poetry run flake8

echo "--- type check ---"
poetry run mypy . 2>/dev/null || echo "mypy not configured, skipping"

echo "--- tests ---"
make test 2>/dev/null || poetry run pytest tests/
```

**Go services:**
```bash
cd <repo>/<service>
echo "--- vet ---"
go vet ./...

echo "--- lint ---"
golangci-lint run 2>/dev/null || echo "golangci-lint not installed, skipping"

echo "--- tests ---"
go test -v ./...
```

**Node services:**
```bash
cd <repo>/<service>
echo "--- lint ---"
npm run lint 2>/dev/null || echo "no lint script, skipping"

echo "--- tests ---"
npm test
```

### frontdoor (mirrors `pr-pipeline.yaml`)
```bash
cd <repo>/frontdoor-go

echo "--- go fmt ---"
CHANGED=$(gofmt -l .)
if [ -n "$CHANGED" ]; then echo "FAIL: unformatted files: $CHANGED"; exit 1; fi

echo "--- go vet ---"
go vet ./...

echo "--- golangci-lint ---"
golangci-lint run --tests=false

echo "--- go test ---"
go test -shuffle=on -v -cover ./...
```

### optimizely
```bash
cd <repo>/src/www

echo "--- black ---"
python3 -m black --check . 2>/dev/null || echo "black not available, skipping"

echo "--- tests ---"
./runtest <relevant-test-files>
```

### authz-sdk
```bash
cd <repo>

echo "--- mypy ---"
poetry run mypy .

echo "--- pytest ---"
poetry run pytest
```

### Output format
```
## Pipeline Results — <project>
Branch: <branch> @ <commit>

| Step | Status |
|------|--------|
| isort | PASS |
| black | PASS |
| flake8 | FAIL |

First failure: flake8
<error output snippet>
```

---

## Mode: Functional (default)

Context-aware functional testing against running services. This is the most complex mode — it generates test scenarios from conversation context and runs them against live endpoints.

### Step F1 — Check prerequisites

If no token in `$ARGUMENTS`:
```
Functional tests need authentication. Please provide:
1. Your OptiID JWT token (from browser devtools > Network > Authorization header)
2. (Optional) Project ID — I'll auto-detect from entity types if not provided
```

**Project-specific notes:**
- **authz-sdk**: no functional endpoints (library). Print: "authz-sdk is a library — running unit tests instead." Then run `--unit` mode.
- **optimizely**: heavyweight (emulators needed). Ask: "Functional testing for optimizely requires Spanner, PubSub, Datastore, and Cloud Tasks emulators. Start them? (yes / switch to --unit)"

### Step F2 — Analyze conversation context and explore code

Read the full conversation to identify:
- What feature or bug is being worked on
- What files were changed and what code paths are affected
- What entity types / API endpoints / services are involved
- What operations are being modified (create, update, delete, read)
- What the expected behavior should be

Then explore the relevant source code:
- Entry points and handlers for the affected code paths
- Validation and error handling logic
- Templates and orchestration steps (for opal-tools entity lifecycle)
- Related functionality that could regress

Use Grep, Read, and the Agent tool with `subagent_type: Explore` as needed.

### Step F3 — Generate test plan

Generate comprehensive test scenarios in 4 categories:

1. **Task-specific tests** — directly exercise the feature/fix being developed
2. **Edge cases** — boundary conditions, empty values, invalid inputs, special characters, missing fields
3. **Negative cases** — verify proper error handling for invalid operations
4. **Regression tests** — existing functionality touching the same code paths must still work

Present the plan before executing. Open with a diagram of the flow being tested, then a table of all scenarios:

```
## Test Plan — <feature name>
Environment: <branch> @ <commit>
Mode: functional | --before (baseline) | --after (verification)

### Flow Under Test
<ASCII diagram showing the request/data flow being exercised>

Request → Handler → Orchestrator
                       ├─► Step 1: Create entity
                       ├─► Step 2: Configure rules  ← TESTING THIS
                       └─► Step 3: Activate

### Scenarios

| # | Category | Scenario | Expected | Priority |
|---|----------|----------|----------|----------|
| 1 | Task | <description> | <outcome> | Must pass |
| 2 | Task | <description> | <outcome> | Must pass |
| 3 | Edge | <boundary condition> | <outcome> | Should pass |
| 4 | Negative | <invalid input> | 400 + error msg | Should pass |
| 5 | Regression | <existing feature> | Unchanged | Must pass |

Proceed? (yes / adjust / skip N)
```

Wait for user confirmation.

### Step F4 — Start services

#### opal-tools — Start TS backend

```bash
cd <repo>/src/services/typescript_backend/nodejs

# For --after: stop previous server (code changed, needs rebuild)
if [ -f .testserver ]; then
  OLD_PID=$(awk '{print $1}' .testserver)
  kill $OLD_PID 2>/dev/null || true
  rm .testserver
fi

# Stop Docker to avoid stale code
docker stop opal-opensearch-query 2>/dev/null || true

# Install deps if missing
if [ ! -f node_modules/.bin/tsc ]; then
  npm install --prefer-offline
fi

# Build from current branch
npm run build

# Ensure .env
if [ ! -f .env ]; then
  cp ../.env .env 2>/dev/null || echo "ERROR: .env missing"
fi

# Start on free port (try-then-retry, no hardcoded port)
PORT=3000
MAX_PORT=3010
TS_PID=""
while [ $PORT -le $MAX_PORT ]; do
  SERVER_PORT=$PORT npm run server &
  TS_PID=$!
  sleep 3
  if kill -0 $TS_PID 2>/dev/null; then
    if curl -sf http://localhost:$PORT/health >/dev/null 2>&1; then break; fi
    sleep 3
    if curl -sf http://localhost:$PORT/health >/dev/null 2>&1; then break; fi
  fi
  kill $TS_PID 2>/dev/null || true
  wait $TS_PID 2>/dev/null || true
  PORT=$((PORT + 1))
  TS_PID=""
done

if [ -z "$TS_PID" ] || ! kill -0 $TS_PID 2>/dev/null; then
  echo "ERROR: Could not start server on any port 3000-$MAX_PORT"
  exit 1
fi

echo "$TS_PID $PORT" > .testserver
echo "Health: $(curl -s http://localhost:$PORT/health)"
```

#### frontdoor — Start Go service

```bash
cd <repo>/frontdoor-go
PORT=3000
while lsof -i :$PORT >/dev/null 2>&1; do PORT=$((PORT + 1)); done
source .env 2>/dev/null || true
PORT=$PORT make develop &
FD_PID=$!
echo "$FD_PID $PORT" > .testserver
for i in $(seq 1 10); do
  curl -sf http://localhost:$PORT/health >/dev/null 2>&1 && break
  sleep 2
done
```

#### opal-app — Start individual service

```bash
cd <repo>/<service>
# Service-specific startup — check Makefile for dev/run target
make dev 2>/dev/null || make run 2>/dev/null || poetry run uvicorn app.main:app --port 8000 &
SVC_PID=$!
echo "$SVC_PID $PORT" > .testserver
```

#### optimizely — Start emulators + app

```bash
cd <repo>/src/www
make spanner-start
make pubsub-start
make datastore-start
make cloud-tasks-start
make app-start
```

### Step F5 — Execute tests

Read `$PORT` from `.testserver` at the start of each Bash call:
```bash
PORT=$(awk '{print $2}' <service-dir>/.testserver)
```

**Rules:**
- Use timestamp-based unique keys: `"key": "test_$(date +%s)_$$"`
- Create a fresh entity for each independent test — don't reuse across unrelated tests
- Run independent tests in **parallel** (multiple Bash tool calls in one message)
- When testing audience_conditions, first query for real audience IDs — never hardcode

#### opal-tools endpoint reference

Follow testexpcrud patterns exactly for payload construction, auth formats, and known pitfalls.

| Endpoint | Method | Auth in body | Auth header |
|----------|--------|-------------|-------------|
| `/api/v1/entity/lifecycle` | POST | `"user_token": "<raw JWT>"` | `Authorization: Bearer <token>` |
| `/api/v1/entity/template` | GET | query params only | `Authorization: Bearer <token>` |
| `/api/v1/query` | POST | `"auth_data": {"provider": "OptiID", "credentials": {"access_token": "<token>"}}` | `Authorization: Bearer <token>` |
| `/health` | GET | none | none |

**Project ID auto-selection** (when not explicitly provided):

| Entity types | Project | ID |
|---|---|---|
| `flag`, `rule`, `ruleset`, `environment`, `variable_definition` | FX | `5129532268085248` |
| `experiment`, `page`, `campaign`, `experience`, `extension` | Web | `6078529820426240` |
| `audience`, `event`, `attribute` | FX (default) | `5129532268085248` |

**Payload rules:**
- Template mode mandatory for complex entities (flags with rules/variations, experiments with pages): set `template_id`
- Refs for related entities: `{"ref": {"key": "my_key"}}` or `{"ref": {"id": "12345"}}` — never bare strings
- Traffic allocation: basis points summing to exactly `10000`
- A/B tests: at least 1 metric in `metrics` array
- Flag sub-entities (variable_definition, variation, variable): omit `project_id` from body
- Audience "Everyone": omit the audience field entirely
- Valid operations: `create`, `update`, `archive`, `unarchive` — `delete` is **disabled** (returns 400)
- Use `"operation"` field (not `"action"`)

#### frontdoor endpoint testing

Test modified routes via curl:
```bash
curl -s -w "\n%{http_code}" http://localhost:$PORT/<route> \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json"
```

#### opal-app service testing

Test the specific service endpoints being modified. Auth depends on the service — check the service's auth middleware.

### Step F6 — Document results

```
## Test Results — <Feature Name>
Environment: <branch> @ <commit> — <timestamp> — port <PORT>
Mode: functional | baseline (--before) | verification (--after)

| # | Category | Scenario | Status | Detail |
|---|----------|----------|--------|--------|
| 1 | Task | <description> | PASS | 200, entity created |
| 2 | Task | <description> | FAIL | expected 200, got 400: "missing field" |
| 3 | Edge | <boundary> | PASS | handled gracefully |
| 4 | Negative | <invalid input> | PASS | 400 with correct error |
| 5 | Regression | <existing feature> | PASS | unchanged behavior |

**Summary:** 5 tests — 4 passed, 1 failed
```

For `--before`: "Some failures are expected — this is the baseline."
For `--after`: "All tests should pass. Failures indicate the fix is incomplete or introduced a regression." Cross-reference against `--before` results if they exist in the conversation.

### Step F7 — Stop services (ALWAYS — even on failure)

```bash
cd <service-dir>
if [ -f .testserver ]; then
  SVC_PID=$(awk '{print $1}' .testserver)
  PORT=$(awk '{print $2}' .testserver)
  kill $SVC_PID 2>/dev/null || true
  rm .testserver
  echo "Stopped server (PID: $SVC_PID, port: $PORT)"
fi
```

Do NOT kill servers on other ports — they may belong to other worktree sessions.

For optimizely emulators:
```bash
cd <repo>/src/www
make spanner-stop; make pubsub-stop; make datastore-stop; make cloud-tasks-stop
```

---

## Mode: `--all`

1. Run `--pipeline` mode (Step pipeline above)
2. If any pipeline step fails → stop, report, do NOT proceed to functional
3. If pipeline passes → run functional mode (Steps F1–F7 above). Token required — ask if not provided.
4. Report combined results

---

## `--before` / `--after` semantics

Only apply to functional tests.

- **`--before`**: Labels results as "Baseline". Some tests may fail — that's expected. Documents current state.
- **`--after`**: Stops any running server from `--before` (code changed, needs rebuild). Rebuilds, restarts, and reruns. Labels results as "Verification". Cross-references against baseline.
- **Neither flag**: Just runs functional tests against current code. No baseline/verification labeling. This is the default — use when the task is obvious and there's no need to compare before/after.

---

## Known Pitfalls

| Pitfall | Symptom | Fix |
|---------|---------|-----|
| Wrong project detected | Tests for wrong repo | Verify `git rev-parse --show-toplevel` against known paths |
| opal-app service ambiguity | Don't know which service | Check `git diff --name-only` for changed service dirs |
| Docker stale code (opal-tools) | Tests against old code | `docker stop opal-opensearch-query` before local server |
| Port conflict with worktree | Server fails to start | Try-then-retry loop 3000-3010, track in `.testserver` |
| Token expired | 401 after some tests pass | Tokens last ~1 hour. Ask for fresh one |
| Missing deps | Build fails | `npm install`, `poetry install`, or `go mod download` first |
| optimizely emulators | Can't connect to Spanner/PubSub | Start via Makefile targets before tests |
| Wrong auth format (opal-tools) | 401/403 | Lifecycle: `user_token`. Query: `auth_data`. Don't mix |
| Wrong project ID for flags | 401 on flag operations | Flags → FX `5129532268085248`, NOT Web |
| Reused entity key | 400 path already exists | Timestamp-based keys: `test_$(date +%s)_$$` |

## Debug

```bash
# opal-tools TS backend
PORT=$(awk '{print $2}' <repo>/src/services/typescript_backend/nodejs/.testserver)
curl -s http://localhost:$PORT/health
lsof -i :3000 -i :3001 -i :3002

# frontdoor
PORT=$(awk '{print $2}' <repo>/frontdoor-go/.testserver)
curl -s http://localhost:$PORT/health

# opal-app services
lsof -i :8000 -i :8026 -i :8088 -i :8111

# Clean up orphaned servers (ONLY when no worktree sessions active)
for p in $(seq 3000 3010); do lsof -ti :$p | xargs kill 2>/dev/null; done
```
