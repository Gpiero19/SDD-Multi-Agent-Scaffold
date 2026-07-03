# Agent scaffolding

Reusable multi-agent project template for Spec-Driven Development with Claude Code + VSCode.
Designed for production-grade company websites and web applications.

---

## Prerequisites

Before starting any project with this scaffold:

1. **Git initialized** — the branching workflow requires git. Run `git init` in the project root if it doesn't exist yet.
2. **Claude Code installed** — run `claude` from the terminal or open via VSCode extension.
3. **Global MCP servers installed** — see below. Do this once, applies to all projects.
4. **Project-specific MCPs configured** — see MCP Setup section further below. Done per project.

### Global MCP servers (install once, apply to all projects)

These MCP servers are installed globally into Claude Code and are available in every project automatically. Run each command once from any directory.

| Server | Purpose |
|---|---|
| `context7` | Fetches up-to-date documentation for any library or framework in real time — agents always use current docs, never outdated training data |
| `sequential-thinking` | Improves how the orchestrator breaks down complex problems step by step before delegating |
| `filesystem` | Controlled read/write access to `~/Documents/github` — agents can navigate the local file system safely |
| `git` | Allows the orchestrator to commit after each approved task directly via the git MCP |

**Installation — run these once:**

```bash
claude mcp add context7 -- npx -y @upstash/context7-mcp
claude mcp add sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking
claude mcp add filesystem -- npx -y @modelcontextprotocol/server-filesystem ~/Documents/github
claude mcp add git -- npx -y @cyanheads/git-mcp-server
```

> **Global vs project-specific MCPs:**
> - `claude mcp add` (no flag) installs globally — available in every Claude Code session on this machine
> - `claude mcp add --project` installs for the current project only — generates a `.mcp.json` file in the project folder and applies only when Claude Code is opened in that directory
> - Use global for universal tools (context7, sequential-thinking, filesystem, git)
> - Use `--project` for project-specific tools (Supabase, Postgres, custom APIs)

---

## How to use

1. Copy this folder into your new project directory
2. Follow `CHECKLIST.md` — every step, in order, before triggering the orchestrator
3. Open the project in VSCode
4. Run `claude` in the terminal
5. Tell the orchestrator what you want to build — brainstorm-agent will guide you through the spec

Brainstorm-agent asks questions, proposes design alternatives, and produces `docs/specs/SPEC-0X-<feature-name>.md`. Once you confirm it, the orchestrator runs architect-agent to produce `ARCHITECTURE.md`, then pauses for your approval before any code is written.

> **CHECKLIST.md is not optional.** It exists to prevent you from skipping a step that costs days to fix later.

---

## Folder structure

```
.claude/
  CLAUDE.md                    ← orchestrator instructions
  agents/
    brainstorm-agent.md        ← designs specs through conversation
    architect-agent.md         ← generates ARCHITECTURE.md for new projects
    task-agent.md              ← implements features
    test-agent.md              ← runs tests, reports pass/fail
    security-agent.md          ← security gate before review
    review-agent.md            ← code quality gate (read-only)
AGENT_LOG.md                   ← cumulative decision log (never delete)
docs/
  specs/
    SPEC-01-<feature>.md       ← first implementation spec
    SPEC-02-<feature>.md       ← second implementation spec
    SPEC-03-<feature>.md       ← and so on...
SPEC.md                        ← template only, do not use directly
README.md                      ← this file
```

## Two types of projects

**New project (greenfield)**
The orchestrator detects no existing SPEC or AGENT_LOG entries.
Activates brainstorm-agent automatically to produce the first SPEC.

**Existing project**
Copy the scaffold into the project root.
Tell the orchestrator what you want to add.
Brainstorm-agent reads the existing codebase and AGENT_LOG before asking questions.
Produces a new SPEC-0X file that explicitly protects existing functionality.

## The workflow

```
You describe what you want to build
        ↓
Brainstorm-agent asks questions → produces docs/specs/SPEC-0X-name.md
        ↓
You review and confirm the SPEC
        ↓
Orchestrator reads the SPEC → checks ARCHITECTURE.md → begins tasks
        ↓
For each task:
  feature branch created
  task-agent implements → test-agent validates → security-agent audits → review-agent approves
  merge to main → branch deleted → AGENT_LOG.md updated
        ↓
All tasks done → implementation complete → AGENT_LOG permanent record
```

## Key rules

- `AGENT_LOG.md` is cumulative — it grows across every implementation, never reset
- Each SPEC file is permanent — never delete or overwrite a completed SPEC
- Brainstorm-agent always runs before a new SPEC is created
- The orchestrator never starts executing without a confirmed SPEC
- task-agent only touches files explicitly listed in the active SPEC

---

## MCP Setup

MCP (Model Context Protocol) connects agents to external tools — databases, GitHub, browsers. Without MCP, agents work from file contents only. With MCP, they can inspect real schemas, create PRs, and control a live browser.

**The orchestrator generates `.mcp.json` for you** once the stack is agreed (after ARCHITECTURE.md is approved), picking servers from the decided technology. You then restart the session and approve them. The configs below are the reference it draws from — and what you'd edit to add or remove a server by hand.

### The `.mcp.json` format

Project MCP servers live in `.mcp.json` (project root), **not** `.claude/settings.json` — current Claude Code rejects an `mcpServers` field in `settings.json`.

```json
{
  "mcpServers": {
    "server-name": {
      "command": "npx",
      "args": ["-y", "package-name"],
      "env": {
        "ENV_VAR": "${ENV_VAR}"
      }
    }
  }
}
```

The `${ENV_VAR}` syntax reads from your shell environment. Set tokens in your shell profile (`.zshrc`, `.bashrc`) or in a `.env` file — never hardcode them in `.mcp.json`.

---

### GitHub MCP — recommended for all projects

Enables agents to read repository state: CI status, issues, and existing branches.

**Setup:**
1. Create a GitHub Personal Access Token at [github.com/settings/tokens](https://github.com/settings/tokens) with scopes: `repo`, `workflow`
2. Add to your shell: `export GITHUB_TOKEN=your_token_here`
3. Add to `.mcp.json` (project root):

```json
"mcpServers": {
  "github": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-github"],
    "env": {
      "GITHUB_TOKEN": "${GITHUB_TOKEN}"
    }
  }
}
```

**What it unlocks:**
- Agents can read repository state: issues, CI status, existing branches
- Orchestrator can check CI status before marking a task complete
- Full audit trail of changes visible in GitHub alongside `AGENT_LOG.md`

> All git operations (branch creation, commits, merges, pushes) are the orchestrator's responsibility — task-agent never runs git commands or creates branches, with or without GitHub MCP.

---

### Playwright MCP — recommended for all website projects

Enables `test-agent` to control a real browser: navigate pages, click elements, fill forms, take screenshots. Far more powerful than running Playwright via bash alone.

**Setup:**
1. Install Playwright: `npx playwright install`
2. Add to `.mcp.json` (project root):

```json
"mcpServers": {
  "playwright": {
    "command": "npx",
    "args": ["-y", "@playwright/mcp@latest"]
  }
}
```

**What it unlocks:**
- `test-agent` runs E2E tests with real browser control and attaches screenshots to its output
- Visual regression testing becomes native to the workflow
- Failures include a screenshot showing exactly what broke

---

### Supabase MCP — for Supabase projects

Enables agents to inspect the live database schema, run queries, and verify migrations.

**Setup:**
1. Find your project ref in Supabase dashboard → Settings → General
2. Create a service role key in Supabase dashboard → Settings → API
3. Add to your shell: `export SUPABASE_ACCESS_TOKEN=your_token`
4. Add to `.mcp.json` (project root):

```json
"mcpServers": {
  "supabase": {
    "command": "npx",
    "args": [
      "-y",
      "@supabase/mcp-server-supabase@latest",
      "--project-ref",
      "YOUR_PROJECT_REF"
    ],
    "env": {
      "SUPABASE_ACCESS_TOKEN": "${SUPABASE_ACCESS_TOKEN}"
    }
  }
}
```

**What it unlocks:**
- `architect-agent` reads the real schema before designing the data architecture
- `task-agent` verifies migrations applied correctly after schema-change tasks
- `test-agent` queries the DB directly to verify data integrity after integration tests

---

### PostgreSQL MCP — for raw Postgres projects

Enables direct database access for projects not using Supabase.

**Setup:**
1. Add to your shell: `export DATABASE_URL=postgresql://user:password@host:5432/dbname`
2. Add to `.mcp.json` (project root):

```json
"mcpServers": {
  "postgres": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-postgres"],
    "env": {
      "DATABASE_URL": "${DATABASE_URL}"
    }
  }
}
```

**What it unlocks:** Same as Supabase MCP — schema inspection, migration verification, data integrity checks.

---

### Combining multiple MCPs

You can run all MCPs simultaneously. Example `.mcp.json` (project root) with GitHub + Playwright + Supabase:

```json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": { "GITHUB_TOKEN": "${GITHUB_TOKEN}" }
    },
    "playwright": {
      "command": "npx",
      "args": ["-y", "@playwright/mcp@latest"]
    },
    "supabase": {
      "command": "npx",
      "args": ["-y", "@supabase/mcp-server-supabase@latest", "--project-ref", "YOUR_PROJECT_REF"],
      "env": { "SUPABASE_ACCESS_TOKEN": "${SUPABASE_ACCESS_TOKEN}" }
    }
  }
}
```

---

## Human approval checkpoints

The orchestrator pauses and waits for your input at these moments:

| Moment | What to do |
|---|---|
| brainstorm-agent produces `docs/specs/SPEC-0X` file | Human reviews and confirms before execution begins |
| After `ARCHITECTURE.md` is generated | Review it, then reply "approved" or give feedback |
| When a task is **BLOCKED** (3 retries at one gate) | Provide guidance or confirm to skip |
| When security-agent finds a **critical** vulnerability | Review the finding and decide how to proceed |

---

## Agent responsibilities

| Agent | Does | MCP used |
|---|---|---|
| `brainstorm-agent` | Designs implementation through conversation, produces `docs/specs/SPEC-0X` file, hands off to orchestrator after user confirmation | None |
| `architect-agent` | Designs architecture, writes ARCHITECTURE.md, documents ADRs | DB MCP (schema), GitHub MCP (repo state) |
| `task-agent` | Implements the task spec, TDD, runs linter | GitHub MCP (read-only — fetch repo info only) |
| `test-agent` | Runs tests, reports coverage, diagnoses failures | Playwright MCP (E2E), DB MCP (data checks) |
| `review-agent` | Reviews quality, architecture conformance, a11y, performance | None |
| `security-agent` | Reviews OWASP, privacy, CVEs, runs dependency audit | None |

> **Git ownership:** all git operations (branch creation, commits, merges, pushes) are the orchestrator's responsibility. No subagent ever runs a git command.

---

## Ground rules enforced automatically

These apply to every task — no per-task configuration needed:

- TypeScript strict mode, no `any` types
- All dependencies pinned to exact versions
- Input validation at entry points only
- Structured JSON logging, no `console.log`
- All env vars through a central config module
- DB schema changes require migration with `up` + `down`
- Every external call has error handling and a fallback
- All list endpoints paginated (no unbounded queries)
- Rate limiting on mutation endpoints
- No PII in logs or error responses
- GDPR checks on every data collection point
- API versioning enforced from the first route

---

## Key files

| File | Written by | Edit manually? |
|---|---|---|
| `docs/specs/SPEC-0X-*.md` | brainstorm-agent + human approval | Yes — one per implementation |
| `SPEC.md` | Template | No — reference template only, never filled in directly. brainstorm-agent uses this schema to produce `docs/specs/SPEC-0X` files. Do not edit or read this file in any agent workflow. |
| `CHECKLIST.md` | Template | Yes — check boxes per project |
| `.mcp.json` | Orchestrator (after stack agreed) | Restart + approve servers; edit to add/remove |
| `.claude/settings.json` | You | Yes — permissions per project |
| `ARCHITECTURE.md` | architect-agent | Only to give feedback for revision |
| `AGENT_LOG.md` | Orchestrator | Never |
| `.claude/CLAUDE.md` | Template | No |
| `.claude/agents/*.md` | Template | No |
| `.gitignore` | Template | Yes — extend with project-specific entries |
