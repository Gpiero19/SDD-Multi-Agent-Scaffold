# SDD Scaffold — source repository

This repo is distributed as the Claude Code plugin **sdd-scaffold**.

Canonical sources (edit these, nothing else):
- Orchestrator protocol → `skills/sdd-orchestrator/SKILL.md`
- Agent definitions → `agents/*.md`

Consumer projects get these via `/plugin install sdd-scaffold@sdd-scaffold`
(after `/plugin marketplace add Gpiero19/SDD-Multi-Agent-Scaffold`), or via
`./sync-scaffold.sh <project>` for legacy copy-mode.

After ANY change to agent frontmatter or permissions, rerun the agent canary
(nonce read + sha256 + expected-failure command) before trusting delegation.
