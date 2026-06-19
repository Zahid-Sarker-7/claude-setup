# Claude Code Skills

A collection of custom [Claude Code](https://docs.anthropic.com/en/docs/claude-code) skills for an end-to-end automated dev workflow.

## Workflow

```
/startwork DHK-NNNN [--wt] [--project]     Pick up ticket, create branch
        │
        ▼
/develop [DHK-NNNN]                         Explore, plan, implement, verify
        │
        ▼
/test [--unit|--pipeline|--all]             Run tests (functional by default)
        │
        ▼
/commit [staged]                            Plan + execute atomic commits
        │
        ▼
/pr [DHK-NNNN|draft]                        Push + create PR with Jira link
        │
        ▼
/fixpr [pr N]                               Fix CI failures + review feedback
```

## Skills (14)

| Skill | Command | Description | Claude Code Features |
|-------|---------|-------------|---------------------|
| **startwork** | `/startwork` | Start a Jira ticket — branch, worktree, transition to In Progress | `!`cmd`` context injection |
| **develop** | `/develop` | Full dev flow — understand ticket, plan with diagrams, implement, verify | `!`cmd``, plan mode |
| **test** | `/test` | Unified test runner — functional, unit, pipeline, or all. Any project | `!`cmd`` context injection |
| **testexpcrud** | `/testexpcrud` | opal-tools CRUD functional testing with before/after verification | `!`cmd`` context injection |
| **commit** | `/commit` | Plan and execute atomic commits with good messages | `!`cmd`` context injection |
| **pr** | `/pr` | Generate PR description from Jira + git changes, push and create PR | `!`cmd`` context injection |
| **fixpr** | `/fixpr` | Fix CI failures + review feedback — one batch commit+push | `!`cmd`` context injection |
| **reviewpr** | `/reviewpr` | Deep PR review — validates ACs, posts inline comments | |
| **jira** | `/jira` | Look up a Jira ticket (auto-invocable) | `!`cmd``, auto-invoke |
| **ticket** | `/ticket` | Create Jira ticket(s) from conversation or description | |
| **confluence** | `/confluence` | Search Confluence docs (auto-invocable) | auto-invoke |
| **debugdd** | `/debugdd` | Debug via Datadog logs + codebase cross-reference | `context: fork`, `agent: Explore`, `!`cmd`` |
| **incident** | `/incident` | Triage PagerDuty alerts using Datadog logs | `context: fork`, `agent: Explore` |
| **worktree** | `/worktree` | List or remove git worktrees across any project | `!`cmd`` context injection |

### Claude Code features used

- **`!`command``** — Dynamic context injection. Runs shell commands at skill load time and injects output into the prompt, saving a tool call round-trip per invocation.
- **`context: fork`** — Runs skill in an isolated subagent context, keeping heavy output (Datadog logs) out of the main conversation.
- **`agent: Explore`** — Uses the read-only Explore subagent for fast, cheap analysis without loading full project context.
- **`disable-model-invocation: true`** — Skill only runs when explicitly invoked with `/command`. Used for skills with side effects (commits, PRs, Jira transitions).
- **Auto-invoke** (`disable-model-invocation` omitted) — Claude can trigger the skill automatically when relevant. Used for read-only lookups (`/jira`, `/confluence`).

## Installation

### Quick install

```bash
./install.sh
```

Copies all skills into `~/.claude/skills/`. Existing skills are backed up to `.bak`.

### Manual install

```bash
cp -r skills/<skill-name> ~/.claude/skills/
```

## Customization

Skills contain team-specific values — update these for your setup:

| Value | Where to update |
|-------|----------------|
| Jira project key (`DHK`) | `jira/`, `ticket/`, `startwork/` |
| Confluence space (`EXPENG`) | `confluence/` |
| Atlassian cloud ID | Skills referencing Jira/Confluence |
| Project paths | `startwork/`, `develop/`, `worktree/`, `test/` |
| Datadog service names | `debugdd/`, `incident/` |

## Prerequisites

MCP servers required:

- **Atlassian MCP** — Jira + Confluence
- **Datadog MCP** — Log search + incident triage
- **GitHub MCP** — PR operations
