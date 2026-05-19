---
name: pr
description: Generate a pull request description from Jira ticket and git changes. Use when creating a PR.
argument-hint: "[DHK-NNNN | draft]"
disable-model-invocation: true
allowed-tools: Bash(git branch *) Bash(git log *) Bash(git diff *) Bash(git show *) Bash(git push *) Bash(make test*) Bash(poetry run pytest*) Bash(gh pr create *) Bash(gh pr view *)
---

# Generate Pull Request Description

Generate a detailed PR description combining Jira ticket context with actual code changes.

## Step 0 — Get current branch context
Run via Bash tool:
```
git branch --show-current
git log origin/main..HEAD --oneline 2>/dev/null | head -20 || git log main..HEAD --oneline | head -20
git diff origin/main --stat 2>/dev/null | tail -8 || git diff main --stat | tail -8
```

## Usage

```
/pr
/pr DHK-4628        (override ticket — if branch name doesn't contain ticket ID)
/pr draft           (mark PR as draft)
```

## Steps

1. **Get current branch name** (already fetched above).

2. **Extract ticket ID.** Look for `DHK-\d+` in the branch name. If `$ARGUMENTS` contains a ticket ID, use that instead. If no ticket ID found, skip Jira lookup.

3. **Mine the current session for context.** Before reading git or Jira, look at what has been discussed in this conversation. Extract:
   - What problem or bug was being investigated or fixed
   - What approach was decided on and why
   - Any specific implementation decisions, trade-offs, or constraints discussed
   - Errors or edge cases that came up and how they were handled
   - Anything the user explicitly said they want in the PR or noted as important
   - Test results or validation steps already performed in the session

4. **Get commit log and diff stats** (already fetched above).

5. **Fetch the Jira issue** (if ticket ID found). Extract:
   - Summary, full description, acceptance criteria
   - Issue type → infer feat / fix / chore / refactor / docs

6. **Read key changed files.** From diff stats, identify the most important source files changed. Read up to 3 of the most impactful changed files.

7. **Before/after validation.** For each significant change in the diff:
   - Build intent context from all available sources
   - Use `git show origin/main:<file>` to read the **before** state
   - Read the current working copy for the **after** state
   - Cross-reference: does the code change match the intent?
   - Only include a Before/After section if meaningful behavioural differences can be stated

8. **Generate the PR description** with Jira link as the very first line. No Claude attribution.

9. **Push the branch and create the PR.** Do not ask for confirmation.

10. **Print a share message** for Slack/Teams — concise, non-technical, focused on impact.
