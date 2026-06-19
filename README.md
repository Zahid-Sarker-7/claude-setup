# Claude Code Skills

My personal [Claude Code](https://docs.anthropic.com/en/docs/claude-code) skill collection that I use at Optimizely for day-to-day development on the Experimentation platform. These skills automate the full dev lifecycle — from picking up a Jira ticket to getting a PR merged — with minimal manual intervention.

They're tailored to my team's stack (Python/FastAPI, TypeScript, Go, Jira, Confluence, Datadog) but the patterns are reusable. Fork and adapt to your own workflow.

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
        │                                        │
        │                              ┌─────────▼──────────┐
        │                              │  CI monitoring loop │
        │                              │  (exponential backoff│
        │                              │   5m → 8m → 12m)   │
        │                              └─────────┬──────────┘
        │                                        │
        ▼                                        ▼
/fixpr [pr N]                    auto-triggered when CI completes
                                 (or run manually anytime)
```

## Skills (14)

| Skill | Command | Description | Claude Code Features |
|-------|---------|-------------|---------------------|
| **startwork** | `/startwork` | Start a Jira ticket — branch, worktree (any repo), transition to In Progress | `!`cmd`` context injection |
| **develop** | `/develop` | Full dev flow — understand ticket, plan with diagrams, implement, verify | `!`cmd``, plan mode |
| **test** | `/test` | Unified test runner — functional, unit, pipeline, or all. Any project | `!`cmd`` context injection |
| **testexpcrud** | `/testexpcrud` | opal-tools CRUD functional testing with before/after verification | `!`cmd`` context injection |
| **commit** | `/commit` | Plan and execute atomic commits with good messages | `!`cmd`` context injection |
| **pr** | `/pr` | Push, create PR, then monitor CI with exponential backoff + auto-fix | `!`cmd``, loop, backoff |
| **fixpr** | `/fixpr` | Fix CI failures + review feedback — one batch commit+push | `!`cmd`` context injection |
| **reviewpr** | `/reviewpr` | Deep PR review — validates ACs, posts inline comments | |
| **jira** | `/jira` | Look up a Jira ticket (auto-invocable) | `!`cmd``, auto-invoke |
| **ticket** | `/ticket` | Create Jira ticket(s) from conversation or description | |
| **confluence** | `/confluence` | Search Confluence docs (auto-invocable) | auto-invoke |
| **debugdd** | `/debugdd` | Debug via Datadog logs + codebase cross-reference | `context: fork`, `agent: Explore`, `!`cmd`` |
| **incident** | `/incident` | Triage PagerDuty alerts using Datadog logs | `context: fork`, `agent: Explore` |
| **worktree** | `/worktree` | List or remove git worktrees across any project | `!`cmd`` context injection |

### Claude Code features used

| Feature | What it does | Used by |
|---------|-------------|---------|
| `!`command`` | Runs shell commands at skill load time, injects output into prompt — saves a tool call per invocation | 10 skills |
| `context: fork` | Runs skill in an isolated subagent, keeping heavy output out of main conversation | debugdd, incident |
| `agent: Explore` | Read-only subagent for fast, cheap analysis without full project context | debugdd, incident |
| `disable-model-invocation: true` | Skill only runs when you type `/command` — prevents auto-triggering side effects | 12 skills |
| Auto-invoke (omitted) | Claude triggers the skill automatically when relevant — for read-only lookups | jira, confluence |
| CI monitoring loop | After PR creation, polls CI with exponential backoff (5m→8m→12m→15m), auto-runs /fixpr | pr |

## Installation

### Quick install

```bash
git clone https://github.com/Zahid-Sarker-7/claude-setup.git
cd claude-setup
./install.sh
```

Copies all skills into `~/.claude/skills/`. Existing skills with the same name are backed up to `.bak`.

### Install a single skill

```bash
cp -r skills/<skill-name> ~/.claude/skills/
```

### Uninstall

```bash
rm -rf ~/.claude/skills/<skill-name>
```

## Customization

These skills are built for my team's setup. To adapt them, update the team-specific values:

| Value | Example | Where to update |
|-------|---------|----------------|
| Jira project key | `DHK` | jira, ticket, startwork, pr, fixpr, develop |
| Jira base URL | `optimizely-ext.atlassian.net` | jira, ticket, startwork, pr |
| Confluence space | `EXPENG` | confluence |
| Project paths | `/Users/zahid.sarker/Official/Project/...` | startwork, develop, worktree, test |
| Datadog service names | `opal-tools` | debugdd, incident |
| Branch naming pattern | `zahid-DHK-NNNN-slug` | startwork |
| PR title format | `[DHK-NNNN] feat: ...` | pr |

## Prerequisites

These skills integrate with external services via MCP servers:

| MCP Server | Used by | Required for |
|------------|---------|-------------|
| **Atlassian** | jira, ticket, startwork, confluence, develop, reviewpr | Jira ticket lookup/creation, Confluence search |
| **Datadog** | debugdd, incident | Log search, incident triage |
| **GitHub** | reviewpr, fixpr | PR comments, thread resolution |

Skills that don't use MCP (commit, test, worktree, etc.) work standalone with just `git` and `gh` CLI.
