---
name: reviewpr
description: Review a GitHub PR — understands what it's trying to achieve, validates against Jira ACs, checks engineering best practices, and explains the impact. Auto-detects Jira ticket from PR if not provided.
argument-hint: "pr <number> [DHK-NNNN] [\"context\"]"
disable-model-invocation: true
allowed-tools: Bash(git diff *) Bash(git log *) Bash(git branch *) Bash(git rev-parse *) Bash(git status *) Bash(gh pr *) Bash(gh pr view *) Bash(gh api *) Bash(gh repo *) Bash(cat *) Bash(grep *)
---

# PR Review

Deep review of a GitHub PR: understand intent, validate behaviour, check engineering quality, explain impact.

## Usage

```
/reviewpr 42                          # review PR #42 (auto-detects Jira ticket)
/reviewpr 42 DHK-4628                 # review PR #42 with explicit Jira ticket
/reviewpr 42 "should rate-limit after 3 calls"  # free-text spec override
```

## Step 1 — Load the PR

Run via Bash tool:
```bash
gh pr view <number> --json title,body,author,baseRefName,headRefName,labels,url
gh pr diff <number>
```

Also fetch recent commits on the PR:
```bash
gh pr view <number> --json commits
```

## Step 2 — Detect Jira ticket

If a `DHK-\d+` was provided in `$ARGUMENTS`, use it.

Otherwise scan the PR title, body, and branch name for a `DHK-\d+` pattern. If found, use it. If multiple found, prefer the one in the title.

If a ticket ID is found: fetch it via Atlassian MCP. Extract:
- Summary
- Description
- Acceptance criteria (look for "Acceptance Criteria" section)
- Issue type, priority

## Step 3 — Load memory and project context

Before reading the diff, load available context:

1. **Project rules:** Read the relevant `.claude/rules/` files in the repo root for architecture patterns, conventions, and known pitfalls.
2. **Memory:** Read `/memories/repo/` for any repo-scoped notes. Read `/memories/` for user-level coding preferences or recurring patterns. Use this to inform what "good" looks like in this codebase.
3. Skip memory files that are clearly unrelated (e.g. standup notes when reviewing code).

## Step 4 — Understand the intent

**Compare the PR branch against main:**
```bash
git fetch origin main
git log origin/main..origin/<headRefName> --oneline
git diff origin/main...origin/<headRefName> --stat
```

Read the diff carefully. Then **explore related code files** as needed:
- If the diff touches a function, read the full function to understand the before/after
- If it adds a new integration or dependency, find where it's wired up
- If it's a bug fix, look for other places the same bug pattern might exist

The goal: understand *why* this change exists and *what problem it solves*, beyond what the diff literally shows.

## Step 5 — opal-tools specific checks (if project is opal-tools)

Run `git rev-parse --show-toplevel` to confirm.

- [ ] IDs declared as `str` not `int` (large Optimizely IDs lose precision as floats)
- [ ] `@tool()` decorator present with `name`, `description`, `auth_requirements`
- [ ] `convert_integers_to_strings()` called before returning dicts
- [ ] No `print()` statements — use `LOGGER`
- [ ] No hardcoded tokens, API keys, or secrets
- [ ] New env vars added to `.env.example`
- [ ] `IslandResponse` used for write operations in interactive mode
- [ ] `async def` used throughout (FastAPI async pattern)
- [ ] Pydantic model used for tool input, not raw dict

## Step 6 — General engineering best practices

- [ ] No `TODO` / `FIXME` / `HACK` left in changed lines
- [ ] No debug statements (`console.log`, `print()`, `debugger`)
- [ ] No secrets: `sk-`, `Bearer `, long hex strings assigned to variables
- [ ] No committed commented-out code blocks
- [ ] Test coverage: if new logic is added, are tests present or updated?
- [ ] No obvious N+1 query patterns or unbounded loops over API calls
- [ ] Error handling: are failure paths handled, or does the code silently swallow errors?
- [ ] No breaking changes to public interfaces without versioning/deprecation
- [ ] Naming is clear and consistent with the rest of the codebase

## Step 7 — Behavioural correctness (if Jira or spec context available)

- Does the implementation actually fulfil each acceptance criterion?
- Are there ACs not addressed by the diff at all?
- Are edge cases from the spec handled?

## Step 8 — Output

```
## PR Review — #<N>: <title>
Author: <author>  Branch: <head> → <base>
Jira: <DHK-XXXX — Summary> | none detected

---

### What this PR is trying to achieve
<2–4 sentences: the problem being solved, the approach taken, and why it matters.
Based on the PR description, Jira ticket, and your reading of the code.>

### How much it achieves
<Does it fully solve the problem? Partial? Scope limited intentionally or accidentally?>

  **Acceptance criteria:**
  - [x] <AC 1> — confirmed in <file:line>
  - [x] <AC 2> — confirmed in <file:line>
  - [ ] ❌ <AC 3> — not addressed in this diff

### Effect with vs without this PR

| Scenario | Without PR | With PR |
|----------|-----------|---------|
| <scenario 1> | <behaviour> | <behaviour> |
| <scenario 2> | <behaviour> | <behaviour> |

<Explain the user-facing or system-level impact. What breaks or degrades without it? What improves with it?>

### How this PR helps
<Who benefits and how — users, developers, reliability, performance, etc.>

---

### ⚠️ Engineering issues

**❌ Must fix:**
- `project_id: int` on line 23 — precision loss for large Optimizely IDs, use `str`

**⚠️ Warnings (non-blocking):**
- 1 TODO left on line 82
- Missing test for the error path in `exp_create_tool.py:94`

**✅ Looks good:**
- ID fields declared as str throughout
- No secrets detected
- Proper use of `IslandResponse` for write ops

---

### Verdict
✅ Approve  |  ⚠️ Approve with comments  |  ❌ Request changes

<One sentence rationale for the verdict.>
```

## Step 9 — Prepare inline review comments

For every issue, warning, or suggestion from steps 5–7 that can be tied to a specific line, create an **inline comment** with:
- `file`: the file path (relative to repo root)
- `line`: the line number in the diff where the comment applies (use the **right-hand side** line number from `gh pr diff`)
- `body`: a concise, actionable comment — explain what's wrong, why it matters, and what to change. Do NOT write generic summaries; each comment must stand alone and address one specific change.

### Comment voice — write as the reviewer, not as Claude

Comments are posted under the user's GitHub account. Write in first person as the reviewer making a direct observation — NOT as Claude telling the reviewer what to say.

**Wrong** (sounds like Claude coaching Zahid):
> Suggest doing this instead. Consider adding a note here. You might want to...

**Wrong** (passive/detached):
> It is suggested that this be changed. One might argue that...

**Correct** (direct reviewer voice):
> This falls through to the wrong API — change it to use the rulesets PATCH endpoint instead.
> No handler here means this silently misbehaves. Remove it or add a handler.
> `entity_id` is required at the top level, not inside `template_data`. The LLM hit a 500 on the first attempt for exactly this reason.

Be direct and specific. State the problem, state the impact, state what to do. No hedging, no "suggest", no "consider" unless it's genuinely optional.

Show the user a numbered preview of all planned inline comments **before posting anything**:

```
## Proposed inline review comments

[1] src/tools/exp_manage_entity_lifecycle.py : line 47
    `project_id` is typed as `int`. Large Optimizely IDs exceed float64 precision and
    will silently corrupt. Change to `str`.

[2] src/tools/exp_manage_entity_lifecycle.py : line 82
    TODO left in production code. Either resolve or remove before merging.

[3] tests/test_entity_lifecycle.py : line 12
    No test covers the error path when the API returns 404. Add a test that mocks a 404
    response and asserts the error is surfaced correctly.

Post all 3 comments? (yes / edit / skip)
```

Wait for explicit user approval. Options:
- **yes** → post all approved comments as individual inline comments on the PR using `gh api`
- **edit N** → user edits comment N, then re-show and ask again
- **skip** → do not post anything

## Step 10 — Post approved comments

### Validate line numbers before posting

GitHub only allows inline comments on lines that appear in the actual diff — additions, deletions, or context lines within a `@@` hunk. Posting to an arbitrary file line number returns HTTP 422 "could not be resolved".

Before posting, verify each line number appears in a diff hunk:
```bash
gh pr diff <number> | grep -n "^@@\|^+" | head -60
# Check that your target line falls within a @@ hunk's range
```

**If the code you want to comment on is NOT in the diff** (e.g., a related stub elsewhere in the file that the PR didn't touch), do NOT guess a nearby line — post it as a regular PR issue comment instead:
```bash
gh api repos/{owner}/{repo}/issues/<number>/comments \
  --method POST \
  --field body="$(cat /tmp/comment.txt)"
```

### Write comment bodies to temp files

Never inline multi-line or backtick-containing comment bodies directly in the shell command — backticks are interpreted as command substitution and will fail.

**Wrong:**
```bash
gh api ... --field body="Use `flag_update_rule` instead of `flag_change_audience`"
# Shell tries to execute `flag_update_rule` as a command — breaks
```

**Correct:** Write to a temp file with a quoted heredoc, then pass via `$(cat ...)`:
```bash
cat > /tmp/comment1.txt << 'ENDOFCOMMENT'
Use `flag_update_rule` instead of `flag_change_audience`.
This template has no handler and falls through to the wrong API.
ENDOFCOMMENT

gh api repos/{owner}/{repo}/pulls/<number>/comments \
  --method POST \
  --field body="$(cat /tmp/comment1.txt)" \
  --field commit_id="<head SHA>" \
  --field path="<file>" \
  --field line=<line> \
  --field side="RIGHT"
```

Write all comment bodies to temp files before posting any of them, then post sequentially.

### Full posting sequence

```bash
# 1. Get repo and SHA (run in parallel)
gh repo view --json nameWithOwner
gh pr view <number> --json headRefOid

# 2. Write all comment bodies to temp files
cat > /tmp/comment1.txt << 'EOF'
...
EOF

# 3. Post each comment separately
gh api repos/{owner}/{repo}/pulls/<number>/comments \
  --method POST \
  --field body="$(cat /tmp/comment1.txt)" \
  --field commit_id="<SHA>" \
  --field path="<file>" \
  --field line=<line> \
  --field side="RIGHT"
```

Get the repo owner/name from: `gh repo view --json nameWithOwner`
Get the head commit SHA from: `gh pr view <number> --json headRefOid`

After posting, confirm: "Posted N inline comments on PR #<number>."
