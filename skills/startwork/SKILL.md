---
name: startwork
description: Start work on a Jira ticket — fetch details, create branch, transition to In Progress. Add --wt flag to open in a new worktree window instead of switching this one. Add --project to target a specific repo.
argument-hint: "DHK-NNNN [slug] [--wt] [--project opal-tools|opal-app|optimizely|frontdoor]"
disable-model-invocation: true
allowed-tools: Bash(git checkout *) Bash(git branch *) Bash(git status *) Bash(git rev-parse *) Bash(git worktree *) Bash(git fetch *) Bash(poetry *) Bash(code *) Bash(pwd) Bash(cp *)
---

# Start Work on a Jira Ticket

Onboard to a Jira ticket: fetch details, create a branch, and transition to In Progress.

Two modes depending on whether `--wt` flag is present:
- **Normal mode** (default): switch this window to the new branch
- **Worktree mode** (`--wt`): create an isolated worktree and continue working in the same session

**Known projects:**
| Name | Path |
|------|------|
| opal-tools | `/Users/zahid.sarker/Official/Project/opal-tools` |
| opal-app | `/Users/zahid.sarker/Official/Project/opal-app` |
| optimizely | `/Users/zahid.sarker/Official/Project/optimizely` |
| frontdoor | `/Users/zahid.sarker/Official/Project/frontdoor` |

**Worktrees dir:** `/Users/zahid.sarker/Official/Project/opal-tools-wt/` (only for opal-tools worktrees)

## Usage

```
/startwork DHK-4628                              # branch in current dir
/startwork DHK-4628 --project opal-tools         # branch in opal-tools
/startwork DHK-4628 --wt                         # worktree in current dir's project
/startwork DHK-4628 my-slug --project opal-app   # custom slug, specific project
```

---

## Steps

### Step 1 — Parse arguments
From `$ARGUMENTS`:
- Extract the ticket ID (e.g. `DHK-4628`)
- Check if `--wt` flag is present → set `worktree_mode = true`, remove it from args
- Check if `--project <name>` is present → set `target_project = <name>`, remove both tokens from args
- Any remaining words after the ticket ID → custom slug

### Step 2 — Resolve the target repo path

**If `--project` was provided:**
- Look up the path from the known projects table above.
- If the name doesn't match any known project, print the list and ask the user to choose.

**If `--project` was NOT provided:**
- Run via Bash tool: `git rev-parse --show-toplevel 2>/dev/null`
- If this succeeds → use that path as the target repo. Print: "Using current repo: `<path>`"
- If this fails (not a git repo) → ask the user:
  ```
  Current directory is not a git repository. Create branch in opal-tools? (yes / choose: opal-app | optimizely | frontdoor)
  ```
  Wait for the response before continuing.

### Step 3 — Fetch the Jira issue
Use the Atlassian MCP tool with the issue key from step 1. Extract:
- Summary
- Description (full text)
- Acceptance criteria (look for "Acceptance Criteria" section in description)
- Issue type (Bug / Story / Task / Sub-task)
- Priority
- Story points (if present)
- Labels / Components
- Reporter and Assignee

### Step 4 — Determine names
- **Slug:** use custom slug if provided; otherwise derive from summary (lowercase, hyphens, max 5 words, skip filler words: a/an/the/for/to)
- **Branch name:** `zahid-<TICKET-ID>-<slug>` (e.g. `zahid-DHK-4628-experiment-query-tool`). No type prefix.
- **Worktree path** (only if `--wt` and target is opal-tools): `/Users/zahid.sarker/Official/Project/opal-tools-wt/<branch-name>`

### Step 5 — Check git state
Run via Bash tool (using the resolved repo path):
```bash
git -C <repo-path> branch -a | grep <branch-name>
git -C <repo-path> worktree list
```
- If the branch already has an active worktree, print its path and stop — it's already set up.
- In normal mode: also run `git -C <repo-path> status --short`; warn if there are uncommitted changes.

### Step 6a — Normal mode (no `--wt`)

1. Fetch and create/switch branch:
   ```bash
   git -C <repo-path> fetch origin
   # branch is new:
   git -C <repo-path> checkout -b <branch-name> origin/main
   # branch already exists:
   git -C <repo-path> checkout <branch-name>
   ```
   If `<repo-path>` is the current directory, omit `-C <repo-path>`.
2. Transition ticket to In Progress (Atlassian MCP transition tool — find "In Progress" or "In Development").
3. Print work context (Step 7).

### Step 6b — Worktree mode (`--wt`)

1. Fetch and create the worktree:
   ```bash
   git -C <repo-path> fetch origin
   # branch is new:
   git -C <repo-path> worktree add -b <branch-name> <worktree-path> origin/main
   # branch already exists on origin:
   git -C <repo-path> worktree add <worktree-path> <branch-name>
   ```
2. Copy `.env` from the main repo to the worktree (it's gitignored and won't exist in the new worktree):
   ```bash
   cp <repo-path>/.env <worktree-path>/.env 2>/dev/null || echo "⚠️  No .env found in <repo-path> — you may need to create one manually"
   ```
3. Install dependencies (if opal-tools — Python/poetry; if opal-app — check for package.json):
   ```bash
   cd <worktree-path> && poetry install --quiet 2>&1 | tail -3
   ```
3. Transition ticket to In Progress (Atlassian MCP transition tool).
4. Print work context (Step 7).

### Step 7 — Print work context

```
## Ticket: <TICKET-ID> — <Summary>

Type: <type>  Priority: <priority>  Points: <sp>
Project: <project name>  Repo: <repo-path>

### Goal
<One paragraph summary of what needs to be done>

### Acceptance Criteria
<Bulleted list from ticket or inferred from description>

### Branch
<branch-name>

[if --wt mode:]
### Worktree
<worktree-path>
Continue working in this session.
When done: /worktree remove <TICKET-ID>

### Notes
<Any warnings, dependencies, or callouts from the description>

Next: run `/develop` to explore the code and plan implementation.
```
