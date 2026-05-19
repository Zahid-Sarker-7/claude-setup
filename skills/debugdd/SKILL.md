---
name: debugdd
description: Debug a production issue by searching Datadog logs and cross-referencing the codebase. Use when investigating errors, 5xx spikes, or failures.
argument-hint: "[UUID | tool-name | keywords] [service:x] [time:y] [env:z]"
disable-model-invocation: true
context: fork
agent: Explore
allowed-tools: Bash(git rev-parse *) Bash(git branch *)
---

# Debug via Datadog

Debug a production issue by searching Datadog logs and cross-referencing the codebase.

## Step 0 — Get current context
Run via Bash tool: `git rev-parse --show-toplevel 2>/dev/null; git branch --show-current 2>/dev/null`

## Input: $ARGUMENTS

Parse all tokens:

**Identifiers:**
- UUID → treat as `@opal_thread_id` (e.g. `4f64c610-8157-43e1-8f31-e6450fc2c8cf`)
- `req-*` or `request_id=*` → request ID filter
- Known tool name (e.g. `exp_manage_entity_lifecycle`) → tool name filter
- Free-form text → keyword search

**Overrides (any order, all optional):**
- `service:<name>` → Datadog service filter
- `time:<value>` or `last:<value>` → time window (default: `1h`)
- `env:<value>` → environment tag

**Examples:**
```
/debugdd 4f64c610-8157-43e1-8f31-e6450fc2c8cf
/debugdd 4f64c610-... service:opal-tools time:1h
/debugdd exp_manage_entity_lifecycle last:2h env:production
/debugdd 500 on entity lifecycle create service:opal-tools
```

## Steps

### Step 1 — Parse tokens
Extract all tokens from `$ARGUMENTS`. Classify per the rules above. Note whether a UUID was provided (thread ID mode).

### Step 2 — Determine service
Run `git rev-parse --show-toplevel` and read `CLAUDE.md` for the default service name. Override with `service:` arg if provided.

### Step 3 — Search Datadog

**If a UUID was provided (thread ID mode):**
- Query: `service:<name> @opal_thread_id:<uuid> [env:<env>]`
- Sort: **ascending** (`+timestamp`) — you want the full lifecycle in order
- Time range: parsed window (default `now-1h`)
- fetch a large enough page to capture the full thread (at least 50–100 logs)

**Otherwise (keyword/tool/error mode):**
- Query: `service:<name> [env:<env>] [attribute filters] [keywords]`
- Sort: descending (`-timestamp`)
- Time range: parsed window (default `now-30m`)
- Do ONE follow-up ascending search for a narrow window around any errors to get chronological context. **Never more than 2 searches total.**

For all searches use:
- `extra_fields: ["*", "http.status_code", "error.message", "error.stack", "opal_thread_id", "tool_name", "tool_input", "tool_output", "duration_ms"]`

### Step 4 — Filter and reconstruct the lifecycle

From the raw logs, extract only the logs that meaningfully describe what happened. Skip noisy/verbose internals. Include:

- **Request received** — method, path, headers summary, user/org context
- **Auth/validation** — any auth checks, permission lookups
- **Tool invocations** — for each tool call:
  - Tool name
  - Input (the arguments sent to the tool)
  - Output / result (what it returned)
  - Duration if available
- **LLM calls** — model used, token counts if logged
- **Errors or warnings** — full message + stack trace if present
- **Response sent** — status code, duration

### Step 5 — Cross-reference the codebase
If there are errors or unexpected behavior, use `.claude/rules/` files to locate the relevant source. Read the specific file and function from the stack trace.

### Step 6 — Report

```
## Debug Report

**Project:** <project>
**Thread ID:** <uuid if provided>
**Query:** `<exact Datadog query used>`
**Time window:** <window>
**Service:** <name>

---

## Request Lifecycle

<timestamp> REQUEST  <METHOD> <path>
  user: <user/org> | env: <env>

<timestamp> AUTH     <result>

[if tools were called, one block per tool:]
<timestamp> TOOL     <tool_name>
  INPUT:  <key args from tool_input>
  OUTPUT: <summary of tool_output or error>
  Time:   <duration_ms>ms

[if LLM calls:]
<timestamp> LLM      <model>
  tokens_in: <n> | tokens_out: <n>

[if errors:]
<timestamp> ERROR    <error.message>
  <error.stack first 5 lines>

<timestamp> RESPONSE <status_code> in <total_duration>ms

---

## Root Cause (if applicable)
<what went wrong and why, file + line reference>

## Suggested Fix (if applicable)
<specific code change or action>
```

If no errors were found and the lifecycle looks normal, say so clearly and summarize what the request did.
