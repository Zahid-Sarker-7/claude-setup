---
name: testexpcrud
description: Comprehensive functional testing of opal-tools experimentation CRUD features. Analyzes chat conversation and plan context to generate test scenarios. Use --before to baseline, --after to verify fixes.
argument-hint: "--before|--after <token> [project_id]"
disable-model-invocation: true
---

# Test Experimentation CRUD Tools

Functional testing of opal-tools experimentation CRUD features with hot reload. Analyzes conversation and plan context to generate comprehensive test scenarios for the specific feature/bug being worked on.

**Two modes:**
- `--before` — Baseline before development. Tests may fail — that's expected.
- `--after` — Verify after development. All tests should pass.

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
/testexpcrud --before eyJhbGci... 5129532268085248   # FX project
```

## Steps

### Step 0 — Detect repo path

Run via Bash tool:
```bash
git rev-parse --show-toplevel 2>/dev/null
git branch --show-current 2>/dev/null
git rev-parse --short HEAD 2>/dev/null
```

If not in a git repo, infer the project from conversation context (recent `/startwork`, `/develop`, Jira ticket, or file paths discussed). If still unclear, default to `/Users/zahid.sarker/Official/Project/opal-tools`.

Use the detected repo path (`<repo>`) for all subsequent steps.

### Step 1 — Parse arguments

From `$ARGUMENTS`:
- Extract the **mode**: `--before` or `--after` (required)
- Extract the **token** (required — raw JWT token for authenticated testing)
- Extract optional **project_id** (see auto-selection logic below)
- If no mode flag provided, ask the user: "Are you running before or after development?"
- If no token provided, stop and ask the user for one

**Project ID auto-selection** (when not explicitly provided):

| Entity types | Project | ID |
|---|---|---|
| `flag`, `rule`, `ruleset`, `environment`, `variable_definition` | FX | `5129532268085248` |
| `experiment`, `page`, `campaign`, `experience`, `extension` | Web | `6078529820426240` |
| `audience`, `event`, `attribute` (shared entities) | FX (default) | `5129532268085248` |

Flags/rules → **always** FX `5129532268085248`. Using Web project for flags returns 401.

### Step 2 — Analyze conversation context

Review the current chat conversation and any active plan to identify:
- **What feature or bug** is being worked on (e.g., "add variation to flag rule", "fix audience condition validation")
- **What entity types** are involved (flag, rule, audience, experiment, etc.)
- **What operations** are being modified (create, update, delete, read)
- **What test scenarios** were discussed in the plan or conversation
- **What edge cases** should be covered

Use this context to generate **comprehensive, feature-specific test scenarios** — not generic endpoint tests.

**For `--before` mode:** Frame expectations around current behavior. Some tests are expected to fail — that's the point. Document what works and what doesn't.

**For `--after` mode:** All tests should pass. If any fail, that indicates the fix is incomplete or introduced a regression.

### Step 3 — Rename tools for conflict-free testing

Temporarily rename Python tool decorators to avoid conflicts with deployed services. Use the Edit tool to find and replace the exact `@tool(name="..."` strings in each file:

In `<repo>/src/tools/opensearch_query.py`:
- `@tool(name="exp_get_schemas"` → `@tool(name="exp_get_schemasx"`
- `@tool(name="exp_execute_query"` → `@tool(name="exp_execute_queryx"`

In `<repo>/src/tools/exp_get_entity_templates.py`:
- `@tool(name="exp_get_entity_templates"` → `@tool(name="exp_get_entity_templatesx"`

In `<repo>/src/tools/exp_manage_entity_lifecycle.py`:
- `@tool(name="exp_manage_entity_lifecycle"` → `@tool(name="exp_manage_entity_lifecyclex"`

### Step 4 — Start development environment (with worktree safety)

**CRITICAL: Docker volume mount worktree mismatch detection.**
The `opal-opensearch-query` Docker container volume-mounts the TS backend source from whatever directory was active when `make opal-tools-with-opensearch` was **last run**. If you're on a different branch/worktree now, the container serves STALE code from the old branch. This silently makes all tests run against the wrong code.

**Always follow this sequence:**

```bash
cd <repo>

# 1. Stop any existing TS backend container to avoid stale code
docker stop opal-opensearch-query 2>/dev/null || true

# 2. Check if port 3000 is still in use (zombie process)
lsof -ti :3000 | xargs kill -9 2>/dev/null || true

# 3. Verify we're on the correct branch
echo "Current branch: $(git branch --show-current)"
echo "Current commit: $(git rev-parse --short HEAD)"

# 4. Install dependencies if missing (node_modules may be empty after branch switch)
cd src/services/typescript_backend/nodejs
if [ ! -f node_modules/.bin/tsc ]; then
  echo "node_modules missing or incomplete — running npm install..."
  npm install --prefer-offline
fi

# 5. Build the TypeScript backend from the CURRENT branch
npm run build

# 6. Ensure .env exists (TS backend crashes without OpenSearch credentials)
#    Check both nodejs/ and parent typescript_backend/ — user may have it at either level
if [ ! -f .env ]; then
  if [ -f ../.env ]; then
    cp ../.env .env
    echo "Copied .env from typescript_backend/ to nodejs/"
  else
    echo "ERROR: .env missing. Required vars: AWS_OPENSEARCH_ENDPOINT, AWS_REGION,"
    echo "  AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, TOKEN_SERVICE_BASE_URL, MONOLITH_BASE_URL"
    echo "Ask the user for values, then create .env before continuing."
    exit 1
  fi
fi

# 7. Start the TS backend directly (NOT via Docker) to guarantee correct code
npm run server &
TS_PID=$!
echo "TS backend started with PID: $TS_PID"

# 8. Wait for health check
sleep 5
curl -s http://localhost:3000/health
```

If health check fails, check with `lsof -i :3000` and retry.

After testing is complete, kill the TS backend:
```bash
kill $TS_PID 2>/dev/null || true
```

### Step 5 — Execute comprehensive test scenarios

Based on the feature/bug identified in Step 2, generate and execute **thorough functional tests** using curl.

**First, set up shell variables** (used in all subsequent curl commands):
```bash
TOKEN="<raw JWT from Step 1 — NO Bearer prefix>"
PROJECT_ID="<project_id from Step 1 auto-selection>"
```

**Test categories to cover:**

1. **Positive cases** — the feature works as expected with valid inputs
2. **Negative cases** — proper error handling for invalid inputs
3. **Edge cases** — boundary conditions, empty values, very long values, special characters
4. **Regression tests** — existing functionality that could break still works

**CRITICAL — test isolation rules:**
- **Create a fresh flag for EACH independent test** that adds rules. Reusing the same flag causes
  "Path '/rules/...' already exists" errors when a previous test already added a rule.
- **Use unique keys** with timestamps: `"key": "test_feature_$(date +%s)"` to avoid collisions.
- **Chain tests intentionally** — only reuse entity IDs from prior tests when the tests are
  explicitly sequential (e.g., create flag → add rule to THAT flag → verify rule on THAT flag).

**CRITICAL — JSON quoting in curl commands:**
Always use **double-quoted** `-d` strings with escaped inner quotes (`\"`), NOT single-quoted
strings with `'$(...)' ` shell subshells. Single-quote nesting breaks JSON parsing.

```bash
# WRONG — shell quoting mangles the JSON:
curl -s -X POST ... -d '{
  "key": "test_'$(date +%s)'"
}' | jq

# RIGHT — double-quoted with escaped inner quotes:
curl -s -X POST ... -d "{
  \"key\": \"test_$(date +%s)\"
}" | jq
```

Use `"$TOKEN"` and `"$PROJECT_ID"` directly inside double-quoted `-d` strings.
Do NOT use the `'"$VAR"'` single-quote-escape pattern — it is fragile and breaks
when `$VAR` contains special characters (like JWT tokens with `+` or `/`).

**CRITICAL — run independent tests in parallel:**
Tests that don't depend on each other's results (e.g., regression tests, independent create
operations, health checks, template endpoint checks) MUST be run in parallel using multiple
Bash tool calls in a single message. This significantly reduces total test time.

Only run tests sequentially when there is a data dependency (e.g., Test 2 needs the entity_id
from Test 1). Group your tests into dependency chains and run independent chains in parallel.

**CRITICAL — audience condition tests require real audience IDs:**
When testing audience_conditions, you MUST first discover valid audience IDs in the target project.
Do NOT hardcode or guess audience IDs — they are project-scoped and cross-project IDs cause 400 errors.

**Discover audiences before testing:**
```bash
# NOTE: The query endpoint uses auth_data (NOT user_token). Format differs from lifecycle endpoint.
curl -s -X POST http://localhost:3000/api/v1/query \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "template": {
      "steps": [{
        "entity": "audience",
        "filters": [
          {"field": "project_id", "operator": "equals", "value": "'"$PROJECT_ID"'"},
          {"field": "archived", "operator": "equals", "value": false}
        ],
        "return_fields": ["id", "name", "conditions"],
        "limit": 5
      }]
    },
    "auth_data": {"provider": "OptiID", "credentials": {"access_token": "'"$TOKEN"'"}},
    "project_id": "'"$PROJECT_ID"'"
  }' | jq '.results[] | {id, name}'
```
Use the returned audience IDs in your `audience_conditions` payloads.

**Curl format for all tests:**
```bash
TOKEN="<raw JWT token without Bearer prefix>"
PROJECT_ID="<project_id from Step 1>"

curl -s -X POST http://localhost:3000/api/v1/entity/lifecycle \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "operation": "<create|update|delete>",
    "entity_type": "<flag|rule|audience|experiment|...>",
    "project_id": "'"$PROJECT_ID"'",
    "mode": "template",
    "template_id": "<template_id>",
    "template_data": { ... },
    "user_token": "'"$TOKEN"'"
  }' | jq
```

**CRITICAL — auth formats differ by endpoint:**
- **Lifecycle endpoint** (`/api/v1/entity/lifecycle`): uses `"user_token": "$TOKEN"` (raw JWT, NO "Bearer " prefix)
- **Query endpoint** (`/api/v1/query`): uses `"auth_data": {"provider": "OptiID", "credentials": {"access_token": "$TOKEN"}}` (NO `user_token`)
- Both also need `Authorization: Bearer $TOKEN` header
- Do NOT mix these formats — lifecycle rejects `auth_data`, query rejects `user_token`

**Example — if working on "add variation to flag rule":**

Test 1: Create flag with multiple variations
```bash
curl -s -X POST http://localhost:3000/api/v1/entity/lifecycle \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{
    \"operation\": \"create\",
    \"entity_type\": \"flag\",
    \"project_id\": \"$PROJECT_ID\",
    \"mode\": \"template\",
    \"template_id\": \"flag_basic_v1\",
    \"template_data\": {
      \"key\": \"test_variations_$(date +%s)\",
      \"name\": \"Multi Variation Test Flag\",
      \"variations\": [
        {\"key\": \"control\", \"name\": \"Control\", \"variables\": []},
        {\"key\": \"treatment\", \"name\": \"Treatment\", \"variables\": []}
      ]
    },
    \"user_token\": \"$TOKEN\"
  }" | jq
```

Test 2: Add 3rd variation to existing flag (use entity_id from Test 1)
```bash
curl -s -X POST http://localhost:3000/api/v1/entity/lifecycle \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{
    \"operation\": \"update\",
    \"entity_type\": \"flag\",
    \"entity_id\": \"<FLAG_ID_FROM_TEST_1>\",
    \"project_id\": \"$PROJECT_ID\",
    \"mode\": \"template\",
    \"template_id\": \"flag_add_variation\",
    \"template_data\": {
      \"variation\": {
        \"key\": \"new_treatment\",
        \"name\": \"New Treatment\",
        \"variables\": []
      }
    },
    \"user_token\": \"$TOKEN\"
  }" | jq
```

Test 3: Duplicate variation key should fail
```bash
curl -s -X POST http://localhost:3000/api/v1/entity/lifecycle \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{
    \"operation\": \"update\",
    \"entity_type\": \"flag\",
    \"entity_id\": \"<FLAG_ID_FROM_TEST_1>\",
    \"project_id\": \"$PROJECT_ID\",
    \"mode\": \"template\",
    \"template_id\": \"flag_add_variation\",
    \"template_data\": {
      \"variation\": {
        \"key\": \"control\",
        \"name\": \"Duplicate Control\"
      }
    },
    \"user_token\": \"$TOKEN\"
  }" | jq
# Expected: error about duplicate variation key
```

Test 4: Edge cases — empty key, very long name
```bash
# Empty variation key
curl -s -X POST http://localhost:3000/api/v1/entity/lifecycle \
  -H "Content-Type: application/json" \
  -d "{
    \"operation\": \"update\",
    \"entity_type\": \"flag\",
    \"template_data\": {
      \"variation\": {\"key\": \"\", \"name\": \"Empty Key\"}
    }
  }" | jq
# Expected: validation error
```

Tests 5-7 are independent — run them in **parallel** (multiple Bash tool calls in one message):

Test 5: Regression — basic flag creation still works
```bash
curl -s -X POST http://localhost:3000/api/v1/entity/lifecycle \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{
    \"operation\": \"create\",
    \"entity_type\": \"flag\",
    \"project_id\": \"$PROJECT_ID\",
    \"mode\": \"template\",
    \"template_id\": \"flag_basic_v1\",
    \"template_data\": {
      \"key\": \"regression_test_$(date +%s)\",
      \"name\": \"Regression Test Flag\"
    },
    \"user_token\": \"$TOKEN\"
  }" | jq
```

Test 6: Regression — templates endpoint works
```bash
# NOTE: Templates endpoint is GET with query params (not POST with JSON body)
curl -s "http://localhost:3000/api/v1/entity/template?operation=update&entity_type=flag&project_id=$PROJECT_ID" | jq
```

Test 7: Regression — health check
```bash
curl -s http://localhost:3000/health
```

**IMPORTANT:** The examples above are illustrative. Generate tests **specific to the feature/bug from Step 2**. Use the same pattern but with payloads and scenarios relevant to the actual work being done. Chain test results — use entity IDs from create operations in subsequent update/delete tests.

### Step 6 — Document test results

Print a summary using this format (adapt header for `--before` / `--after`):

```
## Test Results — [Feature Name] — BEFORE (Baseline) | AFTER (Verification)

**Environment:** <branch> @ <commit> — <timestamp>

**Test Scenarios**
- [PASS/FAIL] Test N: <description> — <result>
  (For --before failures, add: EXPECTED — this is what we're fixing)
  (For --after on previously-failing tests, add: WAS FAILING — now fixed)

**Regression Tests**
- [PASS/FAIL] Basic entity creation
- [PASS/FAIL] Templates endpoint
- [PASS/FAIL] Health check

**Summary**
- --before: what works, what's broken, what we expect to fix
- --after: what was fixed, any regressions, overall status
```

### Step 7 — Revert tool names

**Always revert** the tool renames from Step 3, regardless of test results. Use the Edit tool to reverse each rename:

In `<repo>/src/tools/opensearch_query.py`:
- `@tool(name="exp_get_schemasx"` → `@tool(name="exp_get_schemas"`
- `@tool(name="exp_execute_queryx"` → `@tool(name="exp_execute_query"`

In `<repo>/src/tools/exp_get_entity_templates.py`:
- `@tool(name="exp_get_entity_templatesx"` → `@tool(name="exp_get_entity_templates"`

In `<repo>/src/tools/exp_manage_entity_lifecycle.py`:
- `@tool(name="exp_manage_entity_lifecyclex"` → `@tool(name="exp_manage_entity_lifecycle"`

Verify the revert worked by grepping for any remaining `x` suffixed tool names:
```bash
grep -n 'name="exp_get_schemasx"\|name="exp_execute_queryx"\|name="exp_get_entity_templatesx"\|name="exp_manage_entity_lifecyclex"' \
  <repo>/src/tools/opensearch_query.py \
  <repo>/src/tools/exp_get_entity_templates.py \
  <repo>/src/tools/exp_manage_entity_lifecycle.py
```
If any matches found, the revert failed — fix manually with Edit tool.

## Known Pitfalls (avoid these)

| Pitfall | Symptom | Fix |
|---------|---------|-----|
| Docker worktree mismatch | Tests pass/fail unexpectedly — container runs stale code from wrong branch | Always `docker stop opal-opensearch-query` and run `npm run server` from current branch |
| Wrong auth format | 401/403 on API calls | Lifecycle uses `user_token` (raw JWT). Query uses `auth_data: {provider: "OptiID", credentials: {access_token: "<token>"}}`. Do NOT mix them |
| Wrong project ID for flags | 401 on flag create/update | Flags are FX entities → use `5129532268085248`, NOT Web `6078529820426240` |
| Token expired mid-test | 401 after some tests pass | Tokens last ~1 hour. Get a fresh one if testing takes long |
| Port 3000 still occupied | TS backend fails to start | `lsof -ti :3000 | xargs kill -9` before starting |
| Missing node_modules | `tsc: command not found` during `npm run build` | Run `npm install --prefer-offline` before `npm run build` if `node_modules/.bin/tsc` doesn't exist |
| Missing .env file | TS backend crashes on startup: "Missing required environment variables: AWS_OPENSEARCH_ENDPOINT..." | Check both `nodejs/` and parent `typescript_backend/` for `.env`. Copy from parent if needed. Ask user if neither exists |
| Wrong templates endpoint | 404 on template fetch | Use `GET /api/v1/entity/template?operation=...&entity_type=...&project_id=...` (GET, singular, query params) — NOT `POST /api/v1/entity/templates` |
| Cross-project audience IDs | 400: "Audience conditions must not contain audience_id values from other projects" | Query OpenSearch for real audience IDs in the target project before using them in tests |
| Missing template wrapper on query | 400: "Missing \"template\" in request body" | Query endpoint body needs `{"template": {"steps": [...]}, ...}` — steps must be inside a `template` object |
| Reused flag across tests | 400: "Path '/rules/...' already exists" | Create a fresh flag for each independent test that adds rules. Don't reuse flags from prior tests |
| Single-quote JSON with subshells | `jq: parse error: Invalid numeric literal` or mangled JSON | Never use `'...'$(cmd)'...'` in curl `-d`. Use double-quoted strings with `\"` escapes: `-d "{ \"key\": \"val_$(date +%s)\" }"` |

## Self-Improvement on Failure

When a test fails due to a **skill gap** (wrong endpoint, missing setup step, bad test data) rather than a code bug:

1. **Diagnose the root cause** — was it a missing prerequisite, wrong API format, bad test data, or stale state?
2. **Fix it in the skill immediately** — update the relevant step or pitfall entry. Do NOT add a new section if an existing one covers the same concern. Instead:
   - If the fix belongs in a step's bash script or instructions, update that step inline
   - If it's a new pitfall pattern, add ONE row to the Known Pitfalls table
   - If an existing pitfall row covers a similar issue, update that row instead of adding another
3. **Never duplicate information** — before adding, grep the skill file for the symptom/keyword. If it's already documented, strengthen the existing guidance rather than repeating it.
4. **Keep the fix proportional** — a one-line pitfall entry is better than a new paragraph. The goal is preventing the same failure, not documenting the debugging journey.

## Debug

```bash
curl -s http://localhost:3000/health       # TS backend health
make logs-opensearch-query                 # TS backend logs
docker logs -f opal-tools                  # FastAPI logs
lsof -i :3000                             # Check port 3000
lsof -i :8111                             # Check port 8111
```
