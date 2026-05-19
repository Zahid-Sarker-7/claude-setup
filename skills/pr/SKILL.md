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
   - What approach was decided on and why (especially if alternatives were considered and rejected)
   - Any specific implementation decisions, trade-offs, or constraints discussed
   - Errors or edge cases that came up and how they were handled
   - Anything the user explicitly said they want in the PR or noted as important
   - Test results or validation steps already performed in the session

   This session context takes priority over generic inference — if the user explained something here, use that explanation in the PR rather than re-inferring it from the diff.

4. **Get commit log and diff stats** (already fetched above).

5. **Fetch the Jira issue** (if ticket ID found). Extract:
   - Summary, full description, acceptance criteria
   - Issue type → infer feat / fix / chore / refactor / docs

6. **Read key changed files.** From diff stats, identify the most important source files changed (focus on source, not lock files). Read up to 3 of the most impactful changed files.

7. **Before/after validation.** For each significant change in the diff:
   - First, build intent context from all available sources:
     - Session conversation: what the user described as the problem and expected fix
     - Jira ticket: bug description, steps to reproduce, expected vs actual behaviour in the description
     - Commit messages: look for "fix", "was", "now", "before", "after", "broken", "incorrect" patterns
     - PR description (if `$ARGUMENTS` contains one, or if the branch already has a PR): extract described behaviour changes
   - Use `git show origin/main:<file>` to read the **before** state of the relevant functions/blocks
   - Read the current working copy for the **after** state
   - Cross-reference: does the code change match the intent described in session/Jira/commits? Does it actually fix what it claims?
   - If tests exist, run them: `make test` or `poetry run pytest` or equivalent — note pass/fail
   - Only include a Before/After section in the PR description if meaningful behavioural differences can be stated. Skip it for trivial changes (formatting, renaming, config).

8. **Generate the PR description** in this format. The Jira link **must be the very first line**. Do NOT include any Claude attribution:

```markdown
[DHK-NNNN](https://optimizely-ext.atlassian.net/browse/DHK-NNNN) — <Summary>

## [DHK-NNNN] <feat/fix/chore/refactor/docs>: <concise description>

## Summary

<2-3 sentences: what this PR does and why. Focus on user/product impact.>

## Changes

- <Bullet per logical change group, derived from commits and diff stats>

## Before / After

<!-- Only include if meaningful behavioural differences exist. Omit for trivial changes. -->

| Scenario | Before | After |
|----------|--------|-------|
| <scenario 1> | <what happened> | <what happens now> |
| <scenario 2> | <what happened> | <what happens now> |

## Testing

- [ ] Unit tests added/updated
- Tests run: <✅ N passed / ❌ N failed / ⚠️ not run — reason>
- [ ] Manual testing: <describe what you tested>
- [ ] <Any specific test instructions for reviewer>

## Acceptance Criteria

<Copy from Jira or infer. Prefix each with - [ ] >

## Notes for Reviewer

<Non-obvious implementation decisions, trade-offs, or areas needing extra attention. Omit if nothing to note.>
```

9. **No Claude attribution** anywhere in the output.

10. **Push the branch and create the PR.** Do not ask for confirmation.

   First push the branch:
   ```bash
   git push -u origin <branch-name>
   ```

   Then create the PR — write the generated description to a temp file and pass it via `--body-file` to avoid shell quoting issues:
   ```bash
   # Write body to temp file
   cat > /tmp/pr-body.md << 'PRBODY'
   <full generated PR description>
   PRBODY

   gh pr create \
     --title "[DHK-NNNN] <feat/fix/chore/refactor/docs>: <concise description>" \
     --body-file /tmp/pr-body.md \
     --base main
   # if --draft was in $ARGUMENTS, add: --draft
   ```

   Capture the PR URL from the output of `gh pr create`.

11. **Print the share message:**

```
---
📣 Share this with the team:

🔀 PR #<N> — <feat/fix/chore>: <concise title>
<PR URL>

<1–2 plain-English sentences explaining what this changes and why it matters.
Write for someone who hasn't seen the ticket or the code — focus on what breaks/works differently, not how it was implemented.>

Jira: <DHK-NNNN URL> | Reviews welcome 🙏
```

Rules for the share message:
- No jargon, no file names, no technical internals unless essential
- Start with the user-facing or system-level impact ("Users will now see...", "Fixes a bug where...", "Adds the ability to...")
- Keep it to 2–3 lines max — short enough to paste into Slack or Teams without scrolling
