---
name: develop
description: Understand a Jira ticket, explore the codebase, plan implementation with test cases, then execute with before/after verification. Use after /startwork or when picking up a ticket.
argument-hint: "[DHK-NNNN]"
disable-model-invocation: true
---

# Develop a Ticket

Understand what a Jira ticket requires, explore the relevant code, plan the implementation (including test cases), then execute with before/after verification.

## Usage

```
/develop DHK-4628           # fetch ticket and start the flow
/develop                    # auto-detect ticket from branch or conversation context
```

## Steps

### Step 0 — Get current context

Run via Bash tool:
```bash
git rev-parse --show-toplevel 2>/dev/null; git branch --show-current 2>/dev/null
```

If not in a git repo, infer the project from conversation context (e.g., recent `/startwork`, Jira ticket, or file paths discussed). If still unclear, ask the user which project to work in.

### Step 1 — Gather ticket context

**Do not re-fetch Jira if the ticket is already in the conversation** (e.g., from `/startwork`). Use the summary, description, acceptance criteria, type, and priority that were already printed. This is the expected flow — `/startwork` fetches the ticket, `/develop` picks it up from the conversation.

**Only fetch from Jira if:**
- `$ARGUMENTS` contains a ticket ID AND the ticket has not been fetched in this conversation
- No ticket context exists in the conversation at all

**If no ticket context and no ticket ID in arguments:** extract from current branch name (`DHK-\d+` pattern). If still nothing, ask the user.

### Step 2 — Understand the work

Parse the ticket to determine:
- **What needs to change** — which components, entities, or behaviors are affected
- **What the expected outcome is** — what should be different before vs. after
- **What entity types are involved** (for opal-tools: flag, rule, audience, experiment, etc.)
- **What operations are affected** (create, update, delete, read)

If the ticket description is ambiguous or missing key information, ask the user up to 3 clarifying questions before proceeding. Do not ask obvious questions — only ask if there is genuine ambiguity about scope, approach, or acceptance criteria.

### Step 3 — Explore the codebase and plan in plan mode

Enter plan mode. Explore the codebase to build the plan — find entry points, read the implementation, check test files, identify shared utilities, and understand callers/consumers. Use Grep, Glob, Read, and the Agent tool with `subagent_type: Explore` as needed.

Present a structured implementation plan:

```
## Implementation Plan: [TICKET-ID] — [Summary]

### Understanding
<What the ticket requires, in your own words>

### Approach
<How you plan to implement it, with rationale>

### Files to Modify
1. `path/to/file.ts` — <what changes and why>
2. `path/to/other.py` — <what changes and why>

### Test Plan

**Before-state tests** (to run with /testexpcrud --before):
1. <test scenario that should show current behavior/bug>
2. <test scenario for regression baseline>
3. <edge case scenario>

**After-state tests** (to run with /testexpcrud --after):
1. <test scenario that should show fixed/new behavior>
2. <same regression test — should still pass>
3. <same edge case — should now be handled>

### Risks / Edge Cases
- <potential issues to watch for>
```

Wait for user approval before proceeding. Accept adjustments.

### Step 4 — Run "before" tests

Tell the user to run `/testexpcrud --before <token>` to establish the baseline state. The test scenarios from the plan will be used by testexpcrud.

For unit tests, run them directly:
- TypeScript: `cd <repo>/src/services/typescript_backend/nodejs && NODE_OPTIONS=--experimental-vm-modules npx jest --silent`
- Python: `make test` or `poetry run pytest`

### Step 5 — Implement changes

Make the code changes according to the approved plan:
1. Follow existing code patterns identified during exploration
2. Run relevant unit tests after each logical change to catch issues early
3. If something doesn't work as planned, adapt — but communicate the deviation

### Step 6 — Run "after" tests

Tell the user to run `/testexpcrud --after <token>` to verify the changes. Run the full test suite as well:
- `make test` (for opal-tools)
- Project-specific test commands for other repos

If tests fail, debug and fix before proceeding.

### Step 7 — Summary

```
## Development Complete: [TICKET-ID]

### Before / After
| Scenario | Before | After |
|----------|--------|-------|
| <scenario 1> | <behavior> | <behavior> |

### Files Changed
- `path/to/file.ts` — <what changed>

### Test Results
- Before: N scenarios tested, M passed
- After: N scenarios tested, N passed
- Unit tests: all passing

### Next Steps
- `/commit` to plan and execute atomic commits
- `/pr` to create a pull request
- `/testexpcrud --after <token>` for integration testing (if not already done)
```
