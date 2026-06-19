---
name: testexpcrud
description: Comprehensive functional testing of opal-tools experimentation CRUD features. Analyzes chat conversation and plan context to generate test scenarios. Use --before to baseline, --after to verify fixes.
argument-hint: "--before|--after <token> [project_id]"
disable-model-invocation: true
---

# Test Experimentation CRUD Tools

Functional testing of opal-tools experimentation CRUD features. This skill is invoked mid-conversation when task context (Jira ticket, plan, code changes) is already in the context window. It reads that context, explores relevant code, generates comprehensive test scenarios, and runs them against a local TS backend.

**Two modes:**
- `--before` — Baseline before development. Tests may fail — that's expected. Establishes what works and what doesn't.
- `--after` — Verify after development. Stops any running server from `--before`, rebuilds to capture code changes, restarts, and reruns tests. All tests should pass.

**TypeScript Backend Endpoints:**
| Endpoint | Purpose |
|----------|---------|
| `POST /api/v1/entity/lifecycle` | Entity CRUD operations |
| `GET /api/v1/entity/template?operation=...&entity_type=...&project_id=...` | Get entity templates (**GET**, singular, query params — NOT POST) |
| `POST /api/v1/schemas` | Get entity schemas |
| `POST /api/v1/query` | Execute OpenSearch queries |
| `GET /health` | Health check |

## Usage

```
/testexpcrud --before eyJhbGci...          # baseline before development
/testexpcrud --after eyJhbGci...           # verify after development
/testexpcrud --before eyJhbGci... 5129532268085248   # explicit FX project
```

## Steps

### Step 1 — Parse arguments & detect repo

### Current context
```
!`git rev-parse --show-toplevel 2>/dev/null; echo "---"; git branch --show-current 2>/dev/null; echo "---"; git rev-parse --short HEAD 2>/dev/null`
```

From `$ARGUMENTS`:
- Extract **mode**: `--before` or `--after` (required — ask if missing)
- Extract **token** (required — raw JWT, ask if missing)
- Extract optional **project_id** (auto-selected from entity types if not provided)

If not in a git repo, infer from conversation context. Default: `/Users/zahid.sarker/Official/Project/opal-tools`. Use the detected path (`<repo>`) for all subsequent steps.

**Project ID auto-selection** (when not explicitly provided):

| Entity types | Project | ID |
|---|---|---|
| `flag`, `rule`, `ruleset`, `environment`, `variable_definition` | FX | `5129532268085248` |
| `experiment`, `page`, `campaign`, `experience`, `extension` | Web | `6078529820426240` |
| `audience`, `event`, `attribute` (shared entities) | FX (default) | `5129532268085248` |

### Step 2 — Analyze context & explore code

This is the core of the skill. The task context is already in the conversation — read it thoroughly.

**From conversation context, identify:**
- What feature or bug is being worked on
- What entity types are involved
- What operations are being modified (create, update, delete, read)
- What test scenarios were discussed in the plan or conversation
- What the expected behavior should be

**Explore the relevant source code** to understand:
- What code paths are affected by the changes
- What templates and orchestration steps are involved (check `StaticTemplates.ts`, `EntityOrchestrator.ts`, `EntityLifecycleManager.ts`)
- What validation or error handling exists
- What related functionality could regress

**Payload structure:** If you already understand the payload structure from exploring the code (e.g., you read `StaticTemplates.ts` or `UpdateEntityTemplates.ts`), use that knowledge directly. Only call the templates endpoint when you're unsure about the correct structure for an entity type or operation:
```bash
curl -s "http://localhost:$PORT/api/v1/entity/template?operation=create&entity_type=flag&project_id=$PROJECT_ID" | jq
```
Use the returned `example_filled` as the payload base and `critical_rules` as constraints.

**If anything is unclear, ask the user** before proceeding. Better to clarify now than waste a test run.

**Generate a comprehensive test plan covering:**

1. **Task-specific tests** — directly exercise the feature/fix being developed
2. **Edge cases** — boundary conditions, empty values, invalid inputs, special characters, missing fields
3. **Negative cases** — verify proper error handling for invalid operations
4. **Regression tests** — existing functionality that touches the same code paths must still work (basic CRUD for affected entity types, templates endpoint, related operations)

**For `--before`:** Some tests are expected to fail — that's the baseline. Document what works and what doesn't.

**For `--after`:** Every test should pass. Failures indicate the fix is incomplete or introduced a regression.

### Step 3 — Build & start server

**For `--after` mode:** If a server from `--before` is still running, stop it first — the code has changed and must be rebuilt.

```bash
cd <repo>

# 1. If --after, stop the previous server (code has changed, needs rebuild)
cd src/services/typescript_backend/nodejs
if [ -f .testserver ]; then
  OLD_PID=$(awk '{print $1}' .testserver)
  OLD_PORT=$(awk '{print $2}' .testserver)
  kill $OLD_PID 2>/dev/null || true
  rm .testserver
  echo "Stopped previous server (PID=$OLD_PID, port=$OLD_PORT)"
fi
cd <repo>

# 2. Stop any Docker container to avoid stale code
docker stop opal-opensearch-query 2>/dev/null || true

# 3. Verify correct branch
echo "Current branch: $(git branch --show-current)"
echo "Current commit: $(git rev-parse --short HEAD)"

# 4. Install dependencies if missing
cd src/services/typescript_backend/nodejs
if [ ! -f node_modules/.bin/tsc ]; then
  echo "node_modules missing — running npm install..."
  npm install --prefer-offline
fi

# 5. Build the TypeScript backend from current branch
npm run build

# 6. Ensure .env exists
if [ ! -f .env ]; then
  if [ -f ../.env ]; then
    cp ../.env .env
    echo "Copied .env from typescript_backend/ to nodejs/"
  else
    echo "ERROR: .env missing. Required vars: AWS_OPENSEARCH_ENDPOINT, AWS_REGION,"
    echo "  AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, TOKEN_SERVICE_BASE_URL, MONOLITH_BASE_URL"
    exit 1
  fi
fi

# 7. Start server on a free port (race-condition safe — try-then-retry, not check-then-start)
PORT=3000
MAX_PORT=3010
TS_PID=""
while [ $PORT -le $MAX_PORT ]; do
  echo "Attempting to start server on port $PORT..."
  SERVER_PORT=$PORT npm run server &
  TS_PID=$!
  sleep 3
  if kill -0 $TS_PID 2>/dev/null; then
    if curl -sf http://localhost:$PORT/health >/dev/null 2>&1; then
      echo "TS backend running with PID: $TS_PID on port $PORT"
      break
    fi
    sleep 3
    if curl -sf http://localhost:$PORT/health >/dev/null 2>&1; then
      echo "TS backend running with PID: $TS_PID on port $PORT"
      break
    fi
  fi
  kill $TS_PID 2>/dev/null || true
  wait $TS_PID 2>/dev/null || true
  echo "Port $PORT failed, trying next..."
  PORT=$((PORT + 1))
  TS_PID=""
done

if [ -z "$TS_PID" ] || ! kill -0 $TS_PID 2>/dev/null; then
  echo "ERROR: Could not start server on any port 3000-$MAX_PORT"
  exit 1
fi

# 8. Save PID+port for cleanup (survives across shell invocations)
echo "$TS_PID $PORT" > .testserver
echo "Health check: $(curl -s http://localhost:$PORT/health)"
echo "Server info saved to .testserver (PID=$TS_PID, PORT=$PORT)"
```

**Read the port in every subsequent Bash call:**
```bash
PORT=$(awk '{print $2}' <repo>/src/services/typescript_backend/nodejs/.testserver)
```

### Step 4 — Execute tests

Run the test plan from Step 2 using curl against `http://localhost:$PORT`.

**Rules:**
- Read `$PORT` from `.testserver` at the start of each Bash call
- Use double-quoted `-d` strings with `\"` escapes — never single-quote JSON with `'$(...)' ` subshells
- Use unique keys with timestamps: `"key": "test_$(date +%s)"` to avoid collisions
- Create a fresh entity for each independent test — don't reuse entities across unrelated tests
- Chain tests intentionally — only reuse entity IDs when tests are explicitly sequential
- Run independent tests in **parallel** (multiple Bash tool calls in one message)
- When testing audience_conditions, first query for real audience IDs in the target project — never hardcode them

**Auth formats differ by endpoint:**
- **Lifecycle** (`/api/v1/entity/lifecycle`): `"user_token": "<raw JWT>"` in body (NO "Bearer " prefix)
- **Query** (`/api/v1/query`): `"auth_data": {"provider": "OptiID", "credentials": {"access_token": "<token>"}}` in body
- Both also need `Authorization: Bearer $TOKEN` header

**Payload patterns:**
- If unsure about payload structure, call the templates endpoint (`GET /api/v1/entity/template?operation=...&entity_type=...&project_id=...`) and use its `example_filled` as your payload base
- **Template mode** is mandatory for complex entities (flags with rules/variations/metrics, experiments with pages): set `template_id` in the payload
- **Refs** for related entities: `{"ref": {"key": "my_key"}}` or `{"ref": {"id": "12345"}}` — never bare strings
- **Traffic allocation**: basis points summing to exactly `10000` (e.g., two variations at `5000` each)
- **A/B tests**: at least 1 metric required in `metrics` array
- **Flag sub-entities** (`variable_definition`, `variation`, `variable`): omit `project_id` from body
- **Audience "Everyone"**: omit the audience field entirely — no special value
- **Query endpoint**: steps must be inside `{"template": {"steps": [...]}}`
- **Valid operations**: `create`, `update`, `archive`, `unarchive` — `delete` is **disabled** (returns 400)

**Common LLM mistakes — never do these:**
- String booleans (`"true"` instead of `true`)
- Numeric-indexed objects (`{0: {}, 1: {}}` instead of arrays)
- Direct mode for complex flag/experiment creation (must use template mode)
- Hardcoded audience IDs (query real ones via `/api/v1/query` first)
- Bare string refs instead of `{"ref": {...}}` objects
- Variations as numeric IDs instead of objects with `{key, name, variable_values}`
- Do NOT mix these formats

### Step 5 — Document test results

```
## Test Results — [Feature Name] — BEFORE (Baseline) | AFTER (Verification)

**Environment:** <branch> @ <commit> — <timestamp> — port <PORT>

**Task-Specific Tests**
- [PASS/FAIL] Test N: <description> — <result>
  (--before failures: EXPECTED — this is what we're fixing)
  (--after on previously-failing: WAS FAILING — now fixed)

**Edge Case Tests**
- [PASS/FAIL] ...

**Regression Tests**
- [PASS/FAIL] ...

**Summary**
- --before: what works, what's broken, what we expect to fix
- --after: what was fixed, any regressions, overall status
```

### Step 6 — Stop the server

**Always run after Step 5.** Reads PID and port from `.testserver` — only kills this session's server.

```bash
cd <repo>/src/services/typescript_backend/nodejs
if [ -f .testserver ]; then
  TS_PID=$(awk '{print $1}' .testserver)
  PORT=$(awk '{print $2}' .testserver)
  kill $TS_PID 2>/dev/null || true
  rm .testserver
  echo "Stopped TS backend (PID: $TS_PID, port: $PORT)"
else
  echo "No .testserver file found — server may have already been stopped."
  echo "Check for orphans: lsof -i :3000-3010"
fi
```

**Do NOT** kill servers on other ports — they may belong to other active worktree sessions.

## Known Pitfalls

| Pitfall | Symptom | Fix |
|---------|---------|-----|
| Docker worktree mismatch | Tests run against wrong code | Always `docker stop opal-opensearch-query` and run `npm run server` from current branch |
| Wrong auth format | 401/403 | Lifecycle: `user_token` (raw JWT). Query: `auth_data`. Don't mix them |
| Wrong project ID for flags | 401 on flag operations | Flags → FX `5129532268085248`, NOT Web `6078529820426240` |
| Token expired mid-test | 401 after some tests pass | Tokens last ~1 hour. Get a fresh one if testing takes long |
| Port conflict with parallel worktree | Server fails to start | Step 3 uses try-then-retry. Writes PID+port to `.testserver` for reliable cleanup |
| Missing node_modules | `tsc: command not found` | `npm install --prefer-offline` before build |
| Missing .env | Crash on startup | Copy from parent `typescript_backend/` dir, or ask user |
| Wrong templates endpoint | 404 | `GET /api/v1/entity/template?...` (GET, singular, query params) — NOT `POST /templates` |
| Cross-project audience IDs | 400 | Query for real audience IDs in the target project first |
| Reused entity across tests | 400: path already exists | Create a fresh entity for each independent test |
| Payload structure wrong | 400 with validation errors | Call `GET /api/v1/entity/template?operation=create&entity_type=X&project_id=Y` first — use its `example_filled` as payload base |

## Self-Improvement on Failure

When a test fails due to a **skill gap** (wrong endpoint, bad test data) rather than a code bug:
1. Diagnose — was it a missing prerequisite, wrong API format, bad test data, or stale state?
2. Fix inline — update the relevant step or add ONE pitfall row. Don't duplicate existing guidance.
3. Keep fixes proportional — one line beats one paragraph.

## Debug

```bash
PORT=$(awk '{print $2}' <repo>/src/services/typescript_backend/nodejs/.testserver)
curl -s http://localhost:$PORT/health       # TS backend health
lsof -i :3000 -i :3001 -i :3002           # Check ports (parallel worktrees)
lsof -i :8111                             # Python service port
```

To clean up orphaned servers when **no worktree sessions are active**, the user can manually run:
```bash
for p in $(seq 3000 3010); do lsof -ti :$p | xargs kill 2>/dev/null; done
```
**Never run this automatically** — it will kill servers belonging to other active sessions.
