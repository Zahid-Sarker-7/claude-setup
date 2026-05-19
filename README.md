# Claude Code Skills

A collection of custom [Claude Code](https://docs.anthropic.com/en/docs/claude-code) skills used by me for an end-to-end automated workflow.

## What's included

| Skill | Command | Description |
|-------|---------|-------------|
| **commit** | `/commit` | Plan and execute atomic commits with good messages |
| **pr** | `/pr` | Generate PR description from Jira + git changes, push and create PR |
| **fixpr** | `/fixpr` | Address PR review feedback — fix code, reply, resolve threads |
| **reviewpr** | `/reviewpr` | Deep PR review — validates against Jira ACs, checks engineering practices |
| **startwork** | `/startwork` | Start a Jira ticket — fetch details, create branch, transition to In Progress |
| **develop** | `/develop` | Full dev flow — understand ticket, explore code, plan, implement, verify |
| **jira** | `/jira` | Look up a DHK Jira ticket |
| **ticket** | `/ticket` | Create Jira ticket(s) from conversation context or description |
| **confluence** | `/confluence` | Search and display Confluence docs from the EXPENG space |
| **debugdd** | `/debugdd` | Debug production issues via Datadog logs + codebase cross-reference |
| **incident** | `/incident` | Triage PagerDuty alerts using Datadog logs |
| **testexpcrud** | `/testexpcrud` | Functional testing of opal-tools experimentation CRUD features |
| **worktree** | `/worktree` | List or remove opal-tools git worktrees |

## Installation

### Quick install (recommended)

```bash
./install.sh
```

This copies all skills into `~/.claude/skills/`. Existing skills with the same name will be backed up to `~/.claude/skills/<name>/SKILL.md.bak`.

### Manual install

Copy any skill folder into your Claude Code skills directory:

```bash
cp -r skills/<skill-name> ~/.claude/skills/
```

## Customization

Some skills contain team-specific values you may want to update:

- **Jira project key**: `DHK` — update in `jira/SKILL.md`, `ticket/SKILL.md`, `startwork/SKILL.md`
- **Confluence space**: `EXPENG` — update in `confluence/SKILL.md`
- **Atlassian cloud ID**: `optimizely-ext.atlassian.net` — update in skills that reference Jira/Confluence
- **Project paths**: `/Users/zahid.sarker/Official/Project/...` — update in `startwork/SKILL.md`, `develop/SKILL.md`, `worktree/SKILL.md`
- **Datadog service names**: update in `debugdd/SKILL.md`, `incident/SKILL.md`

## Prerequisites

These skills assume you have the following MCP servers configured in Claude Code:

- **Atlassian MCP** — for Jira and Confluence integration
- **Datadog MCP** — for log search and incident triage
- **GitHub MCP** — for PR operations

## Contributing

To add or update a skill:

1. Edit the `SKILL.md` file in the relevant `skills/<name>/` directory
2. Test locally by copying to `~/.claude/skills/`
3. Open a PR with your changes
