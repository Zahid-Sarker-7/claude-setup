---
name: worktree
description: List or remove git worktrees for any project. To CREATE a worktree for a ticket, use /startwork DHK-NNNN --wt instead.
argument-hint: "list | remove DHK-NNNN [--project name]"
disable-model-invocation: true
allowed-tools: Bash(git worktree *) Bash(git -C *) Bash(git rev-parse *) Bash(ls *) Bash(rm -rf *)
---

# Manage Git Worktrees

> **To create a worktree** for a new ticket, use `/startwork DHK-NNNN --wt`. It handles branch creation, dep install, and Jira transition in one go.

This skill handles **listing and removing** existing worktrees for any project.

**Known projects:**
| Name | Repo path | Worktrees dir |
|------|-----------|---------------|
| opal-tools | `/Users/zahid.sarker/Official/Project/opal-tools` | `opal-tools-wt/` |
| opal-app | `/Users/zahid.sarker/Official/Project/opal-app` | `opal-app-wt/` |
| optimizely | `/Users/zahid.sarker/Official/Project/optimizely` | `optimizely-wt/` |
| frontdoor | `/Users/zahid.sarker/Official/Project/frontdoor` | `frontdoor-wt/` |
| authz-sdk | `/Users/zahid.sarker/Official/Project/authz-sdk` | `authz-sdk-wt/` |

**Base dir:** `/Users/zahid.sarker/Official/Project/`

## Usage

```
/worktree list                              # list worktrees for current repo
/worktree list --project opal-app           # list worktrees for opal-app
/worktree list all                          # list worktrees across ALL projects
/worktree remove DHK-4800                   # remove worktree in current repo
/worktree remove DHK-4800 --project frontdoor
```

---

## Step 0 — Resolve the target project

### Current repo
```
!`git rev-parse --show-toplevel 2>/dev/null || echo "(not in a git repo)"`
```

- If `--project <name>` is provided → look up from the table above
- Otherwise → match the repo root above against known paths
- If not in a git repo and no `--project` → ask the user

Set `<repo-path>` and `<wt-dir>` from the table.

---

## Mode: `list` (or no arguments)

**Single project (default):**
1. Run: `git -C <repo-path> worktree list`
2. Also: `ls <base-dir>/<wt-dir>/ 2>/dev/null`
3. Print a concise table: path | branch | status

**All projects (`list all`):**
1. For each known project, run: `git -C <repo-path> worktree list 2>/dev/null`
2. Skip projects with only the main worktree (1 entry)
3. Print grouped by project name

---

## Mode: `remove <DHK-NNNN>`

1. Extract the ticket ID (e.g. `DHK-4800`).
2. Find the matching path: `ls <base-dir>/<wt-dir>/ 2>/dev/null | grep -i <ticket-id>`
3. Run: `git -C <repo-path> worktree remove --force <full-path>`
4. If that fails (not registered), also: `rm -rf <full-path>`
5. Print: "Removed worktree for <ticket-id> in <project-name>."
