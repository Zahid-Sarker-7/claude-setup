---
name: confluence
description: Search and display Confluence documentation from the DEX Projects space. Use when user asks about architecture, setup guides, or internal docs.
argument-hint: "[keyword or page title]"
---

# Fetch Confluence Documentation

Search for and display Confluence pages, primarily from the DEX Projects space.

## Usage

```
/confluence experiment sdk setup
/confluence opal tools architecture
/confluence                          # list recent DEX Projects pages
```

## Details

- Base URL: `https://optimizely-ext.atlassian.net/wiki`
- Primary space: `EXPENG`
- Primary parent page: DEX Projects (ID `198021608`)
- Remote MCP parent page: Project: Experimentation Remote MCP (ID `588087307`)

## Steps

### 1. Parse arguments

- Empty → list children of DEX Projects parent page (ID `198021608`) as a browseable index.
- Otherwise → treat `$ARGUMENTS` as search query.

### 2. Search for pages

Use Atlassian MCP Confluence search:
- Query: `$ARGUMENTS`
- Space: `EXPENG`
- Limit: 5 results

If no results in `EXPENG`, broaden to all spaces and note that.

### 3. If multiple results

Print a numbered list and wait for selection:
```
Found N pages matching "<query>":

1. Page Title One
   https://optimizely-ext.atlassian.net/wiki/spaces/EXPENG/pages/<id>/...

2. Page Title Two
   ...

Which one? (enter number, or "all" to show all summaries)
```

If only 1 result, skip and proceed directly.

### 4. Fetch and display the selected page

```
## <Page Title>
Space: EXPENG | Last updated: <date> | Author: <name>
Link: https://...

---

<Full page content, cleaned of Confluence markup. Preserve headings, bullets, code blocks.>
```

### 5. After displaying

If content is relevant to active coding work (architecture, API spec, setup guide), ask:
"Save this as context for the current session? (yes to keep it in mind for follow-up questions)"

### 6. No-args mode — browse index

Fetch children of page `198021608` and display as a clickable index.
