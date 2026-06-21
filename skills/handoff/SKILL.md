---
name: handoff
description: Generate a handoff report from the current session for continuity in a new session. Use at the end of a long session or when context should be preserved.
argument-hint: '[save] ["focus topic"]'
---

# Handoff — Session Context Report

Distill the current session into a portable report that a fresh session can pick up. Works for ticket work, exploration, debugging, setup — anything worth carrying forward.

## Current context
```
!`git rev-parse --show-toplevel 2>/dev/null; echo "---"; git branch --show-current 2>/dev/null; echo "---"; date +%Y-%m-%d`
```

## Usage

```
/handoff                                # scan conversation, print report
/handoff "auth token exploration"       # focus on specific topic
/handoff save                           # print + save to ~/.claude/handoffs/
/handoff save "localdev docker issues"  # save with custom slug
```

## Steps

### Step 1 — Parse arguments

From `$ARGUMENTS`:
- **`save`** flag → will write to file after generating
- **Quoted or remaining text** → focus topic (filter extraction to this topic)
- **Neither** → full conversation scan, print only

### Step 2 — Scan the conversation

Read the full conversation and extract the following. If a focus topic was provided, filter to content relevant to that topic. **Include only what actually happened** — never fabricate or infer actions that weren't taken.

**Extract:**

| Category | What to look for |
|----------|-----------------|
| **Subject** | What was explored, worked on, or discussed. Ticket IDs, feature names, questions asked |
| **Findings** | Things discovered — how something works, why something breaks, what a code path does |
| **Decisions** | Approaches chosen + reasoning. Alternatives considered and why they were rejected |
| **Actions taken** | Files edited, commits made, PRs created, services configured, tests run. Include file paths |
| **Unfinished work** | Things started but not completed, blocked items, deferred tasks |
| **Open questions** | Unanswered questions, things that need more investigation |
| **Gotchas** | Non-obvious things that would trip up the next session — surprising behavior, workarounds, edge cases |

**Skip:**
- Tool call mechanics (which tools were called, in what order)
- Conversation pleasantries or meta-discussion about how to proceed
- Information already in CLAUDE.md or memory (don't repeat what's already persisted)

### Step 3 — Generate the report

```markdown
# Handoff: <title>

| Field | Value |
|-------|-------|
| Date | <YYYY-MM-DD> |
| Branch | <branch or "n/a"> |
| Ticket | <DHK-NNNN or "none"> |
| Project | <project name or "general"> |

## Context

<1-3 sentences: what was being explored/worked on, what prompted it, where things stand now>

## Key Findings

| Finding | Detail | Impact |
|---------|--------|--------|
| <what was discovered> | <specifics, file paths, code references> | <why this matters going forward> |

## Decisions Made

- **<decision>** — because <reasoning>
  - Rejected: <alternative> — <why not>

<Omit this section if no decisions were made (e.g., pure exploration)>

## What Was Done

- <action with file paths>
- <action with file paths>
- Commits: `<sha> <message>`, `<sha> <message>`
- PR: <URL> (if created)

<Omit this section if nothing was changed (e.g., pure research)>

## What's Left

- [ ] <unfinished item — be specific enough to act on>
- [ ] <open question — include what was already tried>
- [ ] <next step — what the next session should do first>

<Omit this section if everything is complete>

## Gotchas

- <non-obvious thing that would bite the next session>
- <workaround that was used and why>

<Omit this section if nothing surprising was encountered>
```

**Rules:**
- Title: derive from the focus topic if provided, else from the ticket summary, else from the primary topic discussed
- Omit empty sections entirely — a pure exploration has no "What Was Done", a completed task has no "What's Left"
- Keep each entry actionable — "auth is broken" is useless; "auth fails because OptiID returns 401 when token has `aud: api://default` instead of `aud: https://opal.optimizely.com`" is useful
- File paths should be relative to the repo root when possible
- Keep the whole report under ~80 lines — this gets pasted into a new session's first message

### Step 4 — Present the report

Print the full report to the screen.

### Step 5 — Save (if `save` flag)

**Determine the slug:**
1. If focus topic text was provided → slugify it (lowercase, hyphens, max 5 words)
2. Else if on a branch → use the branch name
3. Else → use `handoff-<YYYY-MM-DD>`

**Write the file:**
```bash
mkdir -p ~/.claude/handoffs
```
Then write the report to `~/.claude/handoffs/<slug>.md` using the Write tool.

**After saving, print:**
```
Saved to: ~/.claude/handoffs/<slug>.md

To load in a new session, start with:
  "Continue from handoff: ~/.claude/handoffs/<slug>.md"
```

### Step 6 — Suggest memory (if applicable)

After generating the report, check if any findings are **reusable across multiple future sessions** (not just the next one). If so, suggest:

```
Some findings might be worth saving to memory (persistent across all sessions):
- "<finding>" → would you like me to save this as a feedback/project memory?

(Handoff files are for one-time context transfer. Memory is for things you'll need again and again.)
```

Only suggest this if there are genuinely reusable findings. Don't suggest it for task-specific state.
