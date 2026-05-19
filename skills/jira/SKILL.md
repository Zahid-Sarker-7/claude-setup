---
name: jira
description: Look up a DHK Jira ticket. Use when user mentions a ticket ID or asks about the current ticket, sprint task, or issue details.
argument-hint: "[DHK-NNNN] [comments] [subtasks]"
allowed-tools: Bash(git branch *)
---

# Look Up a Jira Ticket

Fetch and display a Jira ticket in a readable format.

## Step 0 — Get current branch
Run via Bash tool: `git branch --show-current 2>/dev/null || echo "(not in a git repo)"`

## Usage

```
/jira DHK-4628
/jira DHK-4628 comments       (include recent comments)
/jira DHK-4628 subtasks       (include sub-tasks)
/jira                         (auto-detect from current branch)
```

## Steps

1. **Parse arguments.** Extract ticket ID from `$ARGUMENTS`. Detect flags: `comments`, `subtasks`.

2. **If no ticket ID**, extract from the current branch name shown above (pattern: `[A-Z]+-\d+`). If still no ticket ID, ask user.

3. **Fetch the Jira issue** via Atlassian MCP.

4. **If `comments` flag**, fetch issue comments and include the 3 most recent.

5. **If `subtasks` flag**, fetch and list all sub-tasks with status.

6. **Display:**

```
## [TICKET-ID] Summary text here
Status: In Progress | Priority: High | Type: Story | Points: 3
Assignee: Zahid Sarker | Reporter: John Doe

### Description
<Full description -- strip Jira markup artifacts>

### Acceptance Criteria
<Bulleted list>

### Sub-tasks (if requested)
- [ ] DHK-4629 Sub-task description (To Do)
- [x] DHK-4630 Another sub-task (Done)

### Recent Comments (if requested)
**Author** (2 days ago):
> Comment text

---
Link: https://optimizely-ext.atlassian.net/browse/<TICKET-ID>
```

Keep output tight -- this is for quick reference, not a wall of text.

---

## Atlassian MCP Reference (DHK Project)

Tested and verified field formats, gotchas, and patterns for the Jira MCP server.

### Connection

- **Cloud ID**: `optimizely-ext.atlassian.net` (works directly, no UUID needed)
- **Project key**: `DHK` (project name: "DEX", project ID: `10069`)
- **Board ID**: `367`

### Issue Types (DHK)

| Name            | ID      | Subtask? | Required Custom Fields              |
|-----------------|---------|----------|--------------------------------------|
| Epic            | `10000` | No       | None                                 |
| Bug             | `10034` | No       | **Severity + Regression (REQUIRED)** |
| Story           | `10043` | No       | None                                 |
| Tech Story      | `10044` | No       | None                                 |
| Spike           | `10045` | No       | None                                 |
| Sub-task        | `10037` | Yes      | None                                 |
| Bug Sub-task    | `10038` | Yes      | None                                 |
| Support Case    | `10036` | No       | None                                 |
| Request         | `10046` | No       | None                                 |
| Incident        | `10047` | No       | None                                 |
| Security Finding| `10048` | No       | None                                 |
| Testing Sub-task| `10073` | Yes      | None                                 |

### Bug-Only Required Fields

Bugs WILL FAIL without these. Story/Tech Story do NOT require them.

**Severity** (`customfield_10105`, select):
```json
{"customfield_10105": {"id": "10020"}}  // S0 - Critical
{"customfield_10105": {"id": "10021"}}  // S1 - High
{"customfield_10105": {"id": "10022"}}  // S2 - Medium
{"customfield_10105": {"id": "10023"}}  // S3 - Low
{"customfield_10105": {"id": "10024"}}  // S4 - Minor
```

**Regression** (`customfield_10146`, radio):
```json
{"customfield_10146": {"id": "10041"}}  // Yes
{"customfield_10146": {"id": "10042"}}  // No
```

### Priority Values

Pass via `additional_fields`: `{"priority": {"name": "Critical"}}`

| Name              | ID      |
|-------------------|---------|
| Critical          | `10000` |
| High (migrated)   | `10003` |
| Normal (default)  | `10005` |
| Low (migrated)    | `10002` |
| Trivial           | `10001` |
| Unprioritized     | `10004` |

### Sprint Field (GOTCHA)

The sprint field (`customfield_10020`) is typed as `array<json>` but the MCP `editJiraIssue` tool requires a **bare integer**.

```
WORKS:    {"customfield_10020": 27165}
FAILS:    {"customfield_10020": {"id": 27165}}
FAILS:    {"customfield_10020": [{"id": 27165}]}
```

### Workflow Transitions (from any status)

All transitions are global (available from any status):

| Name         | Transition ID | Target Status ID | Category    |
|--------------|---------------|------------------|-------------|
| To Do        | `131`         | `10006`          | To Do       |
| In Progress  | `141`         | `3`              | In Progress |
| In Review    | `151`         | `10002`          | In Progress |
| Blocked      | `181`         | `10004`          | In Progress |
| Merged       | `191`         | `10183`          | In Progress |
| In Testing   | `201`         | `10203`          | In Progress |
| In Support   | `221`         | `10009`          | In Progress |
| Closed       | `171`         | `6`              | Done        |
| Accept       | `211`         | `10006`          | To Do       |

### Issue Link Types (common)

| Name         | ID      | Inward               | Outward        |
|--------------|---------|----------------------|----------------|
| 1-Relates    | `10039` | relates to           | relates to     |
| 2-Blocks     | `10040` | is blocked by        | blocks         |
| 3-Duplicate  | `10037` | is duplicated by     | duplicates     |
| Blocks       | `10000` | is blocked by        | blocks         |
| Dependency   | `10045` | Is Required For      | Depends On     |

### Creating Issues — Minimal Examples

**Bug** (has extra required fields):
```
createJiraIssue(
  cloudId: "optimizely-ext.atlassian.net",
  projectKey: "DHK",
  issueTypeName: "Bug",
  summary: "[MCP] Bug title here",
  description: "...",
  contentFormat: "markdown",
  additional_fields: {
    "customfield_10105": {"id": "10022"},   // Severity: S2 - Medium
    "customfield_10146": {"id": "10042"},   // Regression: No
    "priority": {"name": "High (migrated)"},
    "labels": ["mcp", "opal-tools"]
  }
)
```

**Story / Tech Story** (no extra required fields):
```
createJiraIssue(
  cloudId: "optimizely-ext.atlassian.net",
  projectKey: "DHK",
  issueTypeName: "Story",
  summary: "[MCP] Story title here",
  description: "...",
  contentFormat: "markdown",
  additional_fields: {
    "priority": {"name": "Normal"},
    "labels": ["mcp"]
  }
)
```

### JQL Cheat Sheet

```
project = DHK AND sprint in openSprints()           // current sprint
project = DHK AND sprint in futureSprints()          // upcoming sprint
project = DHK AND assignee = currentUser()           // my tickets
project = DHK AND status = "In Progress"             // in-flight work
project = DHK AND labels = "mcp"                     // by label
project = DHK AND issuetype = Bug AND status != Closed
project = DHK ORDER BY created DESC                  // recent tickets
```

### Common Pitfalls

1. **Bug creation fails silently** if Severity/Regression are missing
2. **Sprint field format** is a bare integer, NOT `{"id": N}` or `[{"id": N}]`
3. **Priority uses `name`** not `id` when passed via `additional_fields`
4. **Link type names are prefixed** with numbers: use `"2-Blocks"` not `"Blocks"`
5. **No active sprint may exist** — always check `openSprints()` before assuming
6. **Closed transition has a screen** (`hasScreen: true`) — may require resolution or other fields
7. **`responseContentFormat: "markdown"`** is key for readable output
