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

1. Determine mode (single vs bulk, start flag)
2. Extract ticket content from arguments or conversation context
3. For bulk: confirm before creating
4. Create ticket(s) via Atlassian MCP (project: DHK)
5. Report results with links
6. If start flag: run /startwork flow immediately
