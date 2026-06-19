---
name: ticket
description: Create one or multiple DHK Jira tickets from conversation context or an explicit description. Use when you want to log a task, bug, or feature as a ticket.
argument-hint: '["description"] [bulk] [start]'
disable-model-invocation: true
---

# Create Jira Ticket(s)

Create one or multiple DHK Jira tickets, optionally starting work immediately.

## Usage

```
/ticket                              # infer ticket(s) from conversation context
/ticket "add rate limiting to the query endpoint"
/ticket bulk                         # create multiple from brainstorming context
/ticket start                        # create AND start working immediately
/ticket "description" start
```

## Steps

### 1. Determine mode

Parse `$ARGUMENTS`:
- Contains `start` → set `START_WORK=true`
- Contains `bulk` → set `BULK=true`
- Remaining text after flags → explicit description for a single ticket
- No remaining text → infer from conversation context

### 2. Extract ticket content

**If explicit description in arguments:**
- Summary = description text
- Infer type: Bug if contains "fix/broken/error/crash", Story if feature/add/build, Task otherwise
- Acceptance criteria = empty (user fills in Jira)

**If context mode:**
- Scan conversation for: feature ideas, tasks, bugs, action items, "we should...", "TODO:", "next steps"
- **Single mode** (no `bulk`): pick the most recent prominent single item. If multiple candidates and unclear, list them and ask which one.
- **Bulk mode**: extract ALL distinct actionable items. Group related ones. Show list before creating, confirm first.

For each ticket, determine:
- **Summary**: concise, action-oriented verb ("Add", "Fix", "Implement", "Refactor")
- **Issue type**: Story / Bug / Task
- **Priority**: infer from urgency language (blocker → Highest, critical → High, default → Medium)
- **Description**: expand with what, why, technical notes
- **Acceptance criteria**: extract from "should / must / expects" language

### 3. Confirm before bulk creation

For 2+ tickets, print a preview table and wait for confirmation:
```
About to create N tickets in DHK:

1. [Story] Add experiment query tool  (Medium)
2. [Task]  Add env var to config      (Medium)
3. [Bug]   Fix auth token in context  (High)

Proceed? (yes or "skip 2")
```

For single ticket: create immediately, no confirmation.

### 4. Create ticket(s) via Atlassian MCP

Use `create_issue` with: `project: DHK`, `summary`, `issuetype`, `priority`, `description`.

### 5. Report results

```
Created:
- DHK-4630: Add experiment query tool
  https://optimizely-ext.atlassian.net/browse/DHK-4630
```

### 6. If `START_WORK=true`

- Single ticket: run the `/startwork` flow immediately (fetch, create branch, transition In Progress, print context).
- Multiple tickets: ask "Which ticket do you want to start on?"
