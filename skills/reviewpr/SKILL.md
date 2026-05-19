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

## Steps

1. Load the PR (diff, commits, metadata)
2. Detect and fetch Jira ticket for acceptance criteria
3. Load project rules and memory for context
4. Understand the intent by comparing against main
5. Project-specific checks (opal-tools: ID types, decorators, async patterns, etc.)
6. General engineering best practices (TODOs, debug statements, secrets, N+1, error handling)
7. Validate against Jira acceptance criteria
8. Output structured review with verdict
9. Prepare inline review comments with severity assessment
10. Post approved comments to the PR
