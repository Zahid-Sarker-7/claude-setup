---
name: startwork
description: Start work on a Jira ticket — fetch details, create branch, transition to In Progress. Add --wt flag to open in a new worktree window instead of switching this one. Add --project to target a specific repo.
argument-hint: "DHK-NNNN [slug] [--wt] [--project opal-tools|opal-app|optimizely|frontdoor]"
disable-model-invocation: true
allowed-tools: Bash(git checkout *) Bash(git branch *) Bash(git status *) Bash(git rev-parse *) Bash(git worktree *) Bash(git fetch *) Bash(poetry *) Bash(code *) Bash(pwd) Bash(cp *)
---

# Start Work on a Jira Ticket

Onboard to a Jira ticket: fetch details, create a branch, and transition to In Progress.

Two modes:
- **Normal mode** (default): switch this window to the new branch
- **Worktree mode** (`--wt`): create an isolated worktree and continue working in the same session

## Usage

```
/startwork DHK-4628                              # branch in current dir
/startwork DHK-4628 --project opal-tools         # branch in opal-tools
/startwork DHK-4628 --wt                         # worktree in current dir's project
/startwork DHK-4628 my-slug --project opal-app   # custom slug, specific project
```

## Steps

1. Parse arguments (ticket ID, --wt flag, --project, custom slug)
2. Resolve the target repo path
3. Fetch the Jira issue via Atlassian MCP
4. Determine branch name: `zahid-<TICKET-ID>-<slug>`
5. Check git state (existing branch, worktree, uncommitted changes)
6. Create branch (normal) or worktree (--wt mode) from origin/main
7. Transition ticket to In Progress
8. Print work context with ticket details and next steps
