---
name: worktree
description: List or remove opal-tools git worktrees. To CREATE a worktree for a ticket, use /startwork DHK-NNNN --wt instead.
argument-hint: "list | remove DHK-NNNN"
disable-model-invocation: true
allowed-tools: Bash(git worktree *) Bash(ls *) Bash(rm -rf *)
---

# Manage opal-tools Git Worktrees

> **To create a worktree** for a new ticket, use `/startwork DHK-NNNN --wt`. It handles branch creation, `poetry install`, opening VS Code, and Jira transition in one go.

This skill handles **listing and removing** existing worktrees.

## Usage

```
/worktree list                  # show all active worktrees
/worktree remove DHK-4800       # tear down worktree for a ticket
```

## Steps

1. `list`: Show all active worktrees with path, branch, and type
2. `remove <DHK-NNNN>`: Find matching worktree, remove it, clean up
