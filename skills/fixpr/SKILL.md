---
name: fixpr
description: Fix PR issues — CI pipeline failures AND review feedback (Copilot, Claude, reviewers). Checks CI status first, waits for pending pipelines, then addresses all issues in one batch. Auto-detects PR from current branch or takes explicit PR number.
argument-hint: "[pr <number>]"
disable-model-invocation: true
allowed-tools: Bash(git *) Bash(gh *) Bash(cat *) Bash(NODE_OPTIONS=* npx jest*) Bash(npx tsc*) Bash(poetry run pytest*) Bash(make test*)
---

# Fix PR Issues — CI Failures & Review Feedback

Fix both CI pipeline failures and review feedback on a GitHub PR. Checks pipelines first, waits for pending ones, then addresses all issues in one commit+push.

## Current branch context
```
!`git branch --show-current && git rev-parse --show-toplevel`
```

## Usage

```
/fixpr                # address feedback on PR for current branch
/fixpr pr 380         # address feedback on PR #380
```

## Steps

### Step 1 — Determine the PR number

**If `pr <number>` is provided in arguments:** use that number.

**Otherwise:** detect from the current branch:
```bash
gh pr list --head "$(git branch --show-current)" --json number,url --jq '.[0].number'
```

If no PR is found, tell the user and stop.

### Step 2 — Check CI pipeline status

Check all pipeline checks on the PR:

```bash
gh pr checks <PR_NUMBER>
```

**Categorise each check:**

| Status | Action |
|--------|--------|
| `pass` | No action needed |
| `fail` | Fetch logs and diagnose — this must be fixed |
| `pending` / `skipping` / no status | Pipeline still running or waiting |

**If any pipelines are still pending** (especially `claude-review`, `claude-deep-review`, or `run_tests`):
- Tell the user which pipelines are still running
- Ask if they want to wait or proceed with what's available
- If waiting, tell the user to re-run `/fixpr` when the pipelines complete

**For each failed check**, fetch the failure logs:

```bash
# Get the run ID from the checks output URL, then:
gh run view <RUN_ID> --log-failed 2>&1 | tail -60
```

**Common CI failure patterns:**

| Pattern | Fix |
|---------|-----|
| `editorconfig-checker` — wrong indentation | Fix spacing to match `.editorconfig` (typically 4-space indent for Python, 2-space for TS) |
| `editorconfig-checker` — trailing whitespace | Remove trailing whitespace |
| `black` / `flake8` / `pylint` — formatting | Run `make format` or fix manually |
| `tsc` — TypeScript compilation error | Fix the type error |
| `jest` — test failure | Read the failing test, fix code or test |
| `pytest` — test failure | Read the failing test, fix code or test |

**Track all CI fixes needed** — they will be combined with review feedback fixes into one commit in Step 5.

### Step 3 — Fetch all review comments (unresolved only)

Use the GraphQL API with **pagination** to get ALL unresolved review threads. PRs with many review rounds can have 50+ threads — `first: 50` without pagination will silently miss threads.

**IMPORTANT:** Always use `--paginate` with `first: 100` and a cursor variable. Never assume all threads fit in one page.

```bash
gh api graphql --paginate -f query='
query($endCursor: String) {
  repository(owner: "<OWNER>", name: "<REPO>") {
    pullRequest(number: <PR_NUMBER>) {
      reviewThreads(first: 100, after: $endCursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id
          isResolved
          path
          line
          comments(first: 10) {
            nodes {
              id
              databaseId
              body
              author { login }
              createdAt
            }
          }
        }
      }
    }
  }
}'
```

Get `<OWNER>` and `<REPO>` from:
```bash
gh repo view --json nameWithOwner --jq '.nameWithOwner'
```

**Filter:** Only process threads where `isResolved == false`. Skip already-resolved threads.

**Save the thread IDs** — you will need them in Step 6 to resolve conversations.

### Step 4 — Categorise and plan

For each unresolved comment, categorise it and assess severity:

**Categories:**

| Category | Action |
|----------|--------|
| Code change requested (bug, logic, naming, comment text) | Make the change, reply with what was fixed + commit SHA |
| Test coverage requested | Write the test, reply with what was added + commit SHA |
| Question / clarification | Reply with explanation only (no code change) |
| Suggestion you disagree with | Reply with reasoning for current approach |
| Nitpick / style preference | Make the change if trivial, explain if not |

**Severity levels — assess each comment based on actual impact:**

| Severity | Meaning | Action guidance |
|----------|---------|-----------------|
| **CRITICAL** | Bug that breaks production, data loss, security vulnerability, silent wrong behaviour | Must fix before merge |
| **HIGH** | Incorrect logic that affects edge cases, missing error handling that causes bad UX, contract violations | Should fix |
| **MEDIUM** | Defensive coding improvements, missing tests for new code paths, misleading comments | Fix if straightforward, explain if deferring |
| **LOW** | Hypothetical edge cases (corrupt data, prototype pollution), style preferences, redundant guards, defense-in-depth tests for already-tested logic | Safe to ignore — reply with explanation |

**How to assess severity:**
- Read the actual code path the comment describes. Can it happen in practice?
- "Could theoretically fail if X" where X requires corrupt data / misconfigured infra → LOW
- "Will fail when user does Y" where Y is a normal operation → CRITICAL or HIGH
- "Missing test for code that's already tested via another path" → LOW
- "Type safety gap on `any` from external source" → MEDIUM if the field is user-facing, LOW if internal
- Automated reviewer comments (copilot, claude) tend to flag defensive patterns — assess whether the scenario is realistic before assigning HIGH

Present a numbered summary to the user before doing anything. Include both CI failures and review comments:

```
## PR #380 — 1 CI failure + 3 unresolved review comments

### CI Failures
[CI-1] run_tests — editorconfig-checker
       src/tools/exp_manage_entity_lifecycle.py: lines 468-470 wrong indentation (want multiple of 4)
       Plan: Fix indentation to 4-space multiples

### Review Comments
[1] CRITICAL — EntityLifecycleManager.ts:694 (copilot-pull-request-reviewer)
    Unguarded JSON.parse throws on malformed input — regression from old code
    Plan: Wrap in try/catch with fallback
    Category: Code change

[2] MEDIUM — EntityRouter.ts:339 (copilot-pull-request-reviewer)
    Missing unit tests for new case 'page' branch
    Plan: Add 2 unit tests matching existing experiment pattern
    Category: Test coverage

[3] LOW — UpdateHandlerHelpers.ts:120 (claude)
    Type safety gap on OpenSearch result field — requires corrupt index document
    Plan: Reply with explanation — field is guaranteed by return_fields query
    Category: Can safely ignore

### Pending Pipelines
⏳ claude-deep-review — still running (wait or proceed?)

Proceed? (yes / edit / skip)
```

Wait for user confirmation before making changes. If the user says "yes" or similar affirmative, proceed. If they say "skip N", skip that item. If they provide edits, adjust the plan.

### Step 5 — Make code changes

**CRITICAL — Do not make narrow, isolated fixes. Every fix must account for the surrounding control flow.**

For each item that requires a code change:

1. **Read the ENTIRE function** (not just the flagged line). Understand every code path, every early return, every catch block, and how they interact. If the function calls helpers, read those too.
2. **Before writing any code, trace the control flow** of your proposed change:
   - What happens on the happy path?
   - What happens on every error/edge-case path?
   - Does your new code land inside a try block whose catch will re-wrap or swallow it?
   - Does your change affect fall-through behavior (e.g., removing a `return` that previously prevented subsequent code from running)?
   - If you add a `throw`, where does it get caught? Follow it up the call stack.
   - If you add a `return`, what code no longer executes that previously did?
3. **Make the change** using the Edit tool
4. **Self-review the diff** — re-read the function with your change applied. Specifically check:
   - No double-wrapping: errors thrown inside a `try` are not caught and re-wrapped by the same function's `catch`
   - No silent fall-through: when an early branch fails, execution doesn't silently continue to a different branch (e.g., ID lookup fails → name lookup runs without the caller knowing)
   - No truthiness bugs: `if (x)` vs `if (x !== undefined && x !== null)` for values where `0`, `""`, or `false` are valid
   - No scope issues: variables declared inside `try` that are referenced after `catch`
5. **Run tests** to verify nothing broke:
   - TypeScript: `cd <repo>/src/services/typescript_backend/nodejs && NODE_OPTIONS=--experimental-vm-modules npx jest --silent`
   - Python: `make test` or `poetry run pytest`
6. Track which files were changed for the commit

**If you are fixing multiple comments in the same file, read the file ONCE, understand the full picture, then make ALL changes together. Do not fix-commit-push one at a time — that triggers a new review cycle per push.**

### Step 6 — Commit and push (ONE push per /fixpr invocation)

**CRITICAL — Make ALL changes before committing. Do NOT commit-push-fix-commit-push in a loop.** Each push triggers a new automated review cycle, which creates more comments, which triggers more fixes — an infinite feedback loop. Batch everything into ONE commit and ONE push.

Stage only the files changed in Step 4. Create a single commit:

```bash
git add <file1> <file2> ...
git commit -m "address review feedback: <brief summary>"
git push
```

**Commit message rules:**
- One line, lowercase verb start
- Describe what was done, not who asked
- No ticket ID (it's in the branch name)
- No Claude attribution

### Step 7 — Reply to each comment and resolve

For each unresolved thread:

1. **Post a reply** using the REST API — reply to the *first comment ID* in the thread:

```bash
gh api repos/<OWNER>/<REPO>/pulls/<PR_NUMBER>/comments/<COMMENT_ID>/replies \
  -f body="<reply text>"
```

Reply format:
- For code changes: "Fixed — <what changed>. Commit <short SHA>."
- For tests added: "Added — <what tests>. All N tests pass. Commit <short SHA>."
- For explanations: Direct answer to the question/concern.
- Keep replies concise. No fluff.

2. **Resolve the thread** using the GraphQL API with the thread ID saved from Step 2:

```bash
gh api graphql -f query='
mutation {
  resolveReviewThread(input: {threadId: "<THREAD_ID>"}) {
    thread { isResolved }
  }
}'
```

**IMPORTANT — GraphQL resolve reliability:**
- Always use the `PRRT_*` thread ID from Step 2, never construct it yourself
- The `resolveReviewThread` mutation requires the thread ID (`PRRT_kwDO...`), NOT the comment ID
- Always verify the response contains `"isResolved": true`
- If the mutation returns an error, log it and continue — do not retry the exact same call
- Post the reply FIRST, then resolve. If resolve fails, the reply is still visible.

### Step 8 — Summary

Print a final summary:

```
## Done — PR #380

CI fixes:
  [CI-1] Fixed indentation in exp_manage_entity_lifecycle.py (editorconfig)

Review feedback addressed (2):
  [1] EntityLifecycleManager.ts:694 — updated comment text
  [2] EntityRouter.ts:339 — added 2 unit tests (page update payload stripping, missing entity ID)

Commit: abc1234
Tests: 496 passed
All conversations resolved.
```

## Error handling

- **No unresolved comments:** "No unresolved review comments on PR #380. Nothing to do."
- **PR not found:** "No PR found for branch `<branch>`. Use `/fixpr pr <number>` to specify."
- **GraphQL resolve fails:** Log the error, note which threads couldn't be resolved, continue with the rest. Tell the user at the end which threads need manual resolution.
- **Tests fail after changes:** Stop, show the failure, ask the user how to proceed. Do NOT commit failing code.
