---
name: incident
description: Triage a production incident or PagerDuty alert using Datadog logs to find root cause and recommended action.
argument-hint: "[alert-description | service:x] [time:y] [env:z]"
disable-model-invocation: true
context: fork
agent: Explore
---

# Incident Triage

Investigate a PagerDuty alert using Datadog logs to find root cause and recommend action.

## Input: $ARGUMENTS

Parse all tokens:

**Required (one of):**
- Alert title or description: e.g. `exp_manage_entity_lifecycle 5xx spike`
- Error message snippet: e.g. `timeout connecting to typescript backend`
- Service name: e.g. `service:opal-tools`

**Optional overrides:**
- `service:<name>` → Datadog service filter
- `time:<value>` or `last:<value>` → how far back (default: `30m`)
- `env:<value>` → environment tag (default: `production`)

**Examples:**
```
/incident exp_manage_entity_lifecycle high error rate
/incident service:opal-tools last:1h env:production
/incident timeout on entity lifecycle create time:45m
```

## Steps

1. **Parse ALL tokens** from `$ARGUMENTS`. Extract `service:`, `time:`/`last:`, `env:`. Treat remainder as alert keywords.

2. **Find project root.** Run `git rev-parse --show-toplevel`. Read `CLAUDE.md` for default service name. Explicit `service:` arg always overrides.

3. **Make a SINGLE Datadog search:**
   - Query: `service:<name> [env:<env>] status:error <keywords>`
   - `extra_fields: ["*", "http.status_code", "error.message", "error.stack", "http.url"]`
   - Sort: descending (`-timestamp`)
   - Time: parsed window (default `now-30m`)

   **Evaluate immediately:**
   - No errors → widen to `now-2h` and retry once. If still none → report "no matching errors found".
   - Errors present → note top error patterns. Do ONE follow-up ascending search only if chronological trace is needed. **Max 2 searches total.**

4. **Triage:**
   - What is the error? (message, stack trace, status code)
   - How many occurrences? (frequency from logs)
   - Is it ongoing or stopped?
   - Which component is failing?

5. **Cross-reference the codebase.** Use `.claude/rules/` files to locate the failing component. Read the specific source file.

6. **Report:**

```
## Incident Report

**Project:** <project>
**Query used:** `<exact Datadog query>`
**Time window:** <window>
**Environment:** <env>

## Affected Flow

<ASCII diagram showing which component is failing in the system>

User → App UI → Gateway → Hypatia → TMS → opal-tools
                                              └─► TS Backend ← FAILING

## Alert Summary

| Field | Value |
|-------|-------|
| Error | <error message> |
| Service/Tool | <name> |
| First seen | <timestamp> |
| Last seen | <timestamp> |
| Frequency | <count / rate> |
| Status | Ongoing / Resolved |

## Root Cause
<what is failing and why, file + line if traceable>

## Impact
<what is broken for users — which tools/features are affected>

## Recommended Action
**Immediate:** <rollback / restart / config fix / escalate>
**Code fix:** <file path + specific change if applicable>

## Next Steps
<follow-up commands, who to notify, related logs to monitor>
```
