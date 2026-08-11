# SDD Scaffold — source repository

This repo is distributed as the Claude Code plugin **sdd-scaffold**.

Canonical sources (edit these, nothing else):
- Orchestrator protocol → `skills/sdd-orchestrator/SKILL.md`
- Agent definitions → `agents/*.md`

**The SPEC template lives in two files and they are a matched pair.** `SPEC.md`
(root) and the embedded copy inside `agents/brainstorm-agent.md` must always be
changed together in the same commit. The embedded copy is the one that actually
produces SPEC files; `SPEC.md` is the human-readable reference. Change only one
and new SPECs silently lose the field you added.

Bump `.claude-plugin/plugin.json` on every change: MINOR when agent or protocol
behaviour changes, PATCH for wording only. **The `**Scaffold-version:**` stamp at
the top of `skills/sdd-orchestrator/SKILL.md` must be bumped in the same commit** —
it is what the orchestrator actually reports in the audit log, because it cannot
resolve `plugin.json`'s path at runtime. Projects consume this plugin from a
cached install — a change is not live anywhere until
`claude plugin marketplace update sdd-scaffold` and
`claude plugin update sdd-scaffold@sdd-scaffold` have both run, and the session
has restarted.

Consumer projects get these via `/plugin install sdd-scaffold@sdd-scaffold`
(after `/plugin marketplace add Gpiero19/SDD-Multi-Agent-Scaffold`), or via
`./sync-scaffold.sh <project>` for legacy copy-mode.

After ANY change to agent frontmatter or permissions, rerun the agent canary
(nonce read + sha256 + expected-failure command) before trusting delegation.
