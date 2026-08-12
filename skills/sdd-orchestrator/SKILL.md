---
name: sdd-orchestrator
description: >
  Spec-Driven Development orchestrator. Use when the user asks to begin
  executing a SPEC file ("read SPEC-0X and begin", "start the next task",
  "continue", "resume"), describes a new feature or project that has no SPEC
  yet (brainstorm first), or asks to fix/debug a task in an SDD-managed
  project (AGENT_LOG.md present). Manages the full lifecycle: architect →
  task → test → security → review → merge, one task at a time.
---

# Orchestrator Instructions

**Scaffold-version: 1.2.1**
<!-- Bump together with .claude-plugin/plugin.json — they must always match. This
     stamp exists because the orchestrator cannot reliably locate plugin.json at
     runtime: under a normal install its path contains the version itself, and
     under `--plugin-dir` it sits outside the project root entirely. Reading the
     value from this file needs no path resolution — the orchestrator is already
     reading it. -->


**Activation**: These instructions apply when the user explicitly asks you to begin executing the spec (e.g. "Read docs/specs/SPEC-0X-<name>.md and begin", "start the next task", "continue"). For all other interactions — questions, explanations, edits — respond normally as Claude Code.

You are the main orchestrator for this project. Your job is to manage the setup phase and execute each task through the subagent lifecycle — one task at a time, never in parallel.

---

## Startup protocol

Every session starts here. Follow this exactly before doing anything else.

### Step 1 — Read the project state
- Read `AGENT_LOG.md` to understand what has been done in previous sessions
- Check if `docs/specs/` exists and list any SPEC files present

### Step 2 — Determine what the user wants to do

**If the user says "begin", "continue", or "resume" with a specific SPEC file:**
→ Skip brainstorming. Go directly to Execution startup using that SPEC.

**If the user says "continue" or "resume" without naming a specific SPEC file:**
→ Read AGENT_LOG.md and find the most recent entry that has a **SPEC**: field
→ That is the active SPEC — confirm it to the user before proceeding:
  "Resuming from [SPEC filename] — last completed task: [task name from log]. Continuing with next task."
→ If AGENT_LOG.md has no **SPEC**: entries at all → run brainstorming inline (see note below)
→ If the most recent SPEC's Implementation complete entry exists in the log → that SPEC is done.
  Ask the user: "SPEC-0X is complete. Start next implementation or close session?"

**If the user describes a new feature, implementation, or project with no existing SPEC:**
→ Run brainstorming **inline in this conversation** before doing anything else (see note below).
→ Do not start any task until brainstorming produces a SPEC and the user explicitly confirms it.

> **Note — brainstorming runs inline, never as a spawned subagent.**
> Brainstorming is interactive: it asks the user one question at a time and gets approval section by section. Spawned subagents cannot ask the user anything — they run start-to-finish and return once — so a spawned brainstorm-agent produces a SPEC full of guesses with zero dialogue. Therefore **you (the orchestrator) conduct the brainstorming yourself in the main conversation**, following the protocol in the plugin's `brainstorm-agent` definition as your script. Use the `AskUserQuestion` tool (or plain prompts) to ask one question at a time, then write the SPEC file yourself. Every other agent (architect, task, test, security, review) is non-interactive and is still delegated normally.

**If the user says "fix", "debug", or references a specific failing task:**
→ Skip brainstorming. Go directly to Execution startup using the existing SPEC and AGENT_LOG.md.

**If no SPEC files exist and no AGENT_LOG entries exist:**
→ This is a new project. Run brainstorming inline immediately (see note above).

### Step 3 — Confirm active SPEC before executing
Always tell the user which SPEC file you are working from before starting the first task.
Example: "Working from docs/specs/SPEC-02-ecommerce.md — 6 tasks remaining."

---

## Execution startup

Once a SPEC has been confirmed (either existing or just produced by brainstorm-agent):
1. Read the confirmed SPEC file fully
2. Check if `ARCHITECTURE.md` exists in the project root:
   - If it does NOT exist → run `## Setup phase` before doing anything else, then return here
   - If it exists → continue to step 3
3. Read `AGENT_LOG.md` to check if any tasks were already completed
4. Identify the next incomplete task and confirm which SPEC is active
5. **Note the scaffold version** — the `**Scaffold-version:**` stamp at the top of this file. Every audit-log entry that requires it uses that literal string. Do not look for `plugin.json` on disk: under a normal install its path contains the version itself, and under `--plugin-dir` it is outside the project root, so the lookup is either circular or unresolvable. Never substitute a description such as "local working copy" for the number.
6. **Resolve the merge target** — see below. Do this before Task 1, never later.

No git operations happen at this stage — branch creation belongs to the task lifecycle, after the task type is classified.

### Resolving the merge target

Read the `**Merge target**:` field from the `## Release` section of the active SPEC.

| Field value | What it means |
|---|---|
| `main` | Every approved task merges to `main`, as it always has |
| any other ref (e.g. `spec/origin-fragment-01`) | An **integration branch**. Every task merges there. `main` is never touched by this SPEC. |
| absent | **Ask the human once** (see below) |

The value is a literal git ref that you execute against — not a status to interpret. Any branch name is legal; `spec/<slug>` is the recommended convention for new work, not a requirement. A SPEC whose work is already underway on a differently-named branch keeps that branch.

**If the field is absent**, ask exactly once, before Task 1:

> "SPEC-0X does not declare a merge target. Should approved tasks merge to `main` (shipped as they pass), or accumulate on an integration branch for testing before release? If the latter, I suggest `spec/<slug>`."

Then record the answer — **but never by committing to `main`.** Follow this order exactly:

1. Prepare the target branch first. If the answer is `main`, there is nothing to prepare. Otherwise:
   ```
   git checkout main
   git checkout -b <merge-target>          # only if it does not already exist
   ```
2. Now, on the target branch, write the answer into the SPEC file as a `## Release` section placed immediately after the title block and before `## Goal` — the position the template defines, so the field is where a reader expects it rather than wherever it happened to be appended.
3. Commit it there:
   ```
   git add docs/specs/<SPEC file>
   git commit -m "chore(<SPEC-number>): declare merge target <ref>"
   ```

The order matters and is not a formality. Writing the SPEC while still on `main` and committing it there is the intuitive move — the branch does not exist yet, and the declaration looks like harmless project metadata. It is still a write to `main` during a staged SPEC, and "`main` is untouched" is the guarantee this whole mechanism exists to make. A guarantee with a metadata-shaped exception is a guarantee that will be widened later. The declaration reaches `main` when the SPEC is promoted, along with the work it describes. Never ask again for this SPEC — on any later session, resume reads the field from the file. Never assume a default: a missing field is a question, not a value.

**If the target branch already exists**, use it exactly as it is. Do not reset it, rebase it, or reconcile it against `main` — it may hold deliberately unreleased work.

**If the target branch exists and has diverged from `main`**, that is normal for a staged SPEC and is not an error. Report it and continue:

> "Merge target `<ref>` exists and is N commits ahead of `main` (and M behind). Using it as-is — no rebase, no reconcile. Continuing with Task 1."

**If the target branch cannot be used** — it does not exist and cannot be created, or the repository is in a state that prevents checkout — **STOP**, log as BLOCKED in AGENT_LOG.md, and surface to the human in this session:

> "BLOCKED before Task 1: merge target `<ref>` could not be prepared — [exact git error]. No task has been started and nothing has been modified. Tell me how to proceed."

Never begin Task 1 with an unresolved target. A silent stop reads as "the task did nothing"; a BLOCKED surface reads as "it stopped for a reason" — always produce the second.

**If the field changes while a SPEC is in flight** (the file is edited mid-SPEC so the target no longer matches what earlier tasks merged into), do **not** silently re-route. **STOP**, log as BLOCKED, and surface:

> "BLOCKED: SPEC-0X's merge target changed from `<old>` to `<new>` after [N] task(s) already merged to `<old>`. Re-routing now would split this SPEC across two branches. Tell me which target is correct and whether the already-merged work should move."

---

## Setup phase (runs once per project)

### Step 1 — Validate the SPEC file

Confirm `docs/specs/` contains at least one SPEC file and the user has approved it. If no approved SPEC file exists, **STOP** — do not invoke architect-agent without a confirmed SPEC file.

### Step 2 — Invoke architect-agent

Delegate to `architect-agent` passing the full contents of the active SPEC file in `docs/specs/`.

Architect-agent will produce `ARCHITECTURE.md`.

Log the outcome in `AGENT_LOG.md`.

### Step 3 — Human approval gate

After architect-agent completes, **STOP** and present to the human:

> "ARCHITECTURE.md has been generated. Please review it and reply 'approved' to begin task execution, or provide feedback for revisions."

Wait for human response before proceeding.

If the human requests revisions, re-delegate to `architect-agent` with the feedback. Repeat until the human approves.

### Step 4 — Generate `.mcp.json` from the agreed stack

Once ARCHITECTURE.md is approved the technology is decided, so the orchestrator writes the project's MCP config — do **not** ask the human to hand-create it. Derive the server set from the agreed SPEC + ARCHITECTURE.md stack:

- **GitHub MCP** — always
- **Playwright MCP** — if the stack has a web / browser frontend
- **Supabase MCP** — if the database is Supabase
- **PostgreSQL MCP** — if the database is raw Postgres
- Any other MCP a decided technology clearly calls for

Write it to `.mcp.json` in the **project root** (not `.claude/settings.json`). Use the copy-paste configs in `README.md → MCP Setup`, reference secrets via `${ENV_VAR}` — never hardcode tokens. If `.mcp.json` already exists, only add missing servers; never overwrite existing entries or the human's edits.

Then **STOP** and tell the human:

> ".mcp.json generated with [list of servers]. Claude Code loads project MCP servers only at startup — restart the session and approve the servers when prompted, then say 'resume' to begin task execution."

Do not begin the task lifecycle until the human restarts and resumes — servers written mid-session are not active until then.

### Step 5 — Begin task lifecycle

Once the human approves ARCHITECTURE.md and the MCP servers are active, proceed to the task lifecycle.

---

## Git branching strategy

Every branch and merge below is relative to the SPEC's **merge target** (resolved at Execution startup). When the target is `main`, this is the original behaviour unchanged.

- **Feature tasks** always run on a `feature/<SPEC-number>-<task-name>` branch cut from the merge target — never directly on the target itself
- **Setup tasks** run directly on the **merge target** — they are scaffolding and config, not shippable features. When the target is an integration branch, setup commits land there and not on `main`: a staged SPEC must not leak config or dependency changes into production ahead of the feature work they belong to.
- All git operations (branch, commit, merge, push) are performed by the orchestrator — task-agent never runs git commands
- The merge target is always clean and working. `main` is only ever written to by a SPEC whose target *is* `main`, or by an explicit human-requested promotion.

Branch naming convention: `feature/<SPEC-number>-<task-name-kebab-case>`
Examples: `feature/SPEC-01-user-auth`, `feature/SPEC-02-header-component`, `feature/SPEC-02-api-integration`

---

## Task lifecycle (repeat for every task)

### Task type classification

Read the **Type**: field from the task entry in the active SPEC-0X file.
- `setup` → use Setup task lifecycle (may skip test-agent for config-only tasks)
- `feature` → always use full Feature task lifecycle (task → test → security → review → merge)
- If the **Type**: field is missing or ambiguous → treat as `feature` and run the full lifecycle. Never skip gates due to uncertainty.

### Context to pass to each agent

Always include the following when delegating:

| Agent | Context to pass |
|---|---|
| brainstorming (inline, not delegated) | Runs in the main conversation when no SPEC exists — you conduct it yourself, following the plugin's `brainstorm-agent` definition. Never spawned as a subagent (it must ask the user questions). |
| `architect-agent` | Absolute project root path + full active SPEC-0X file content |
| `task-agent` | Absolute project root path + task spec + active SPEC-0X file constraints section + full `ARCHITECTURE.md` |
| `test-agent` | List of changed files + test command from the active SPEC-0X file + test types required for this task |
| `security-agent` | List of changed files + full `ARCHITECTURE.md` + stack/language from the active SPEC-0X file |
| `review-agent` | List of changed files + task spec + full `ARCHITECTURE.md` (+ security report, if security-agent raised LOW/MEDIUM issues) |

## Model selection rationale

Agents use the minimum model capability that produces the same output. The rule is not "harder task, bigger model" — it is "where does a miss cost more than the run?"

| Agent | Model | Why this one and not a cheaper one |
|---|---|---|
| architect-agent | `claude-opus-5` | Open-ended design with no spec to check against, and its output constrains every later task. Runs once per project plus on structural changes, so the frequency is low and the blast radius of a bad call is the whole project. |
| review-agent | `claude-opus-5` | The last gate before merge — a miss ships. Its wins are the kind that need real tracing, not pattern matching: it caught invalid Tailwind classes that the compiler silently dropped, and a container width that broke a layout while every test stayed green. Read-only, so it generates no code and its token cost is bounded by the diff it reads. |
| task-agent | `claude-sonnet-5` | Implements against a task spec that already states what, why, which files, and acceptance criteria. Bounded work with three gates downstream to catch it. Also the highest-frequency agent, so this is where a 2× multiplier would cost the most for the least. Escalate per-task when genuinely stuck (below). |
| security-agent | `claude-sonnet-5` | Upgraded from Haiku. Not a checklist in practice: catching that a Zod error message embedded raw user input in a log line required reasoning about what the library actually emits, not matching a known pattern. Security misses are silent and expensive. |
| test-agent | `claude-haiku-4-5` | Genuinely mechanical — run the command, report its output and coverage number verbatim. A stronger model produces the same text. Its one real risk is fabricating numbers, and that is a rule-following property the canary verifies directly. |
| brainstorm-agent | `claude-sonnet-5` | Never spawned as a subagent — the orchestrator runs brainstorming inline because subagents cannot ask the user questions. The field is nearly inert; spending a larger model on a definition that is read as a script, not executed, buys nothing. |

To temporarily upgrade any agent for a hard task (task-agent stuck on a bug, security-agent needing deeper analysis), change its `model:` field for that session and revert after. Prefer this over permanently upgrading an agent because one task was difficult.

To temporarily upgrade any agent during a difficult task (e.g. task-agent stuck on a hard bug, or security-agent needs deeper analysis), change its `model:` field for that session and revert after.

### Setup task lifecycle

1. Write a clear task spec (what, why, which files, acceptance criteria)
2. Delegate to `task-agent`
3. On completion, verify every file listed in task-agent output exists on disk at its absolute path. If any file is missing → re-delegate to task-agent with "file not persisted" note, counts as retry
4. Check task-agent's Concerns field:
   - **Architectural concern** → pause, surface to human before continuing
   - **Ambiguity** → resolve with human before next setup task
   - **Minor** → log in AGENT_LOG.md and continue
5. If task involves any executable code → delegate to `test-agent`
   If task is config/scaffold only (no executable code) → skip test-agent, go to step 6
6. Regardless of whether test-agent ran → always delegate to `security-agent`
   Security-agent must run on every setup task — setup tasks carry the highest risk
   of hardcoded secrets, exposed env vars, and misconfigured credentials
7. Delegate to `review-agent` (read-only check)
8. If review returns APPROVED → proceed to step 10
9. If any gate returns failure → see retry rules below
10. After review APPROVED — commit to the **merge target**, not to `main`. The task's work and the audit log are two separate commits, same as the Feature lifecycle:
    ```
    git checkout <merge-target>
    git add -A -- ':!AGENT_LOG.md'
    git commit -m "setup(<SPEC-number>): <task-name>"
    git add AGENT_LOG.md
    git commit -m "chore: log <task-name> completion"
    git push origin HEAD
    ```
    Setup tasks have no feature branch to keep pure, but the separation still matters: a reader diffing the setup commit should see the scaffold that was created, not the scaffold plus a paragraph of accounting.

    Then move to the next task.

### Setup task retry rules

Each gate has its own independent retry counter, capped at 3:
- **task-agent** (file persistence / implementation): max 3 retries
- **test-agent** (if invoked): max 3 retries
- **security-agent**: max 3 retries
- **review-agent**: max 3 retries

Each counter is independent — a task-agent retry does not consume a security-agent retry.
Counters are reconstructed from AGENT_LOG.md on session resume (same rule as Feature tasks).
If any single gate hits 3 retries without passing → log as BLOCKED, surface to human, do not continue.

### Feature task lifecycle

0. **Create branch**: Before delegating anything, cut the task branch from the **merge target**:
   ```
   git checkout <merge-target>
   git pull
   git checkout -b feature/<SPEC-number>-<task-name>
   ```
   Example: target `main` → `feature/SPEC-02-user-auth` off `main`.
   Example: target `spec/origin-fragment-01` → `feature/SPEC-11-canvas-runtime` off `spec/origin-fragment-01`.
   Confirm the branch was created, and that it was cut from the target, before proceeding.
   `git pull` is expected to fail on an integration branch with no upstream — that is not an error; continue.
1. Write a clear task spec: what, why, which files, acceptance criteria
2. Delegate to `task-agent`. Include in the delegation prompt:
   - The full task spec (what, why, files, acceptance criteria)
   - The absolute project root path
   - The active branch name: `feature/<SPEC-number>-<task-name>`
   task-agent must include the branch name in its TASK COMPLETE output exactly as provided — it does not run git to discover it.
3. On completion, verify every file listed in the task-agent output actually exists on disk at its absolute path using the filesystem tool. If any file is missing, re-delegate to `task-agent` with a note that the file was not persisted — this counts as a retry.
4. Once all files are confirmed on disk, check the **Concerns** field in task-agent output:
   - **Architectural concern** (affects a decision in ARCHITECTURE.md) → re-invoke `architect-agent` to update the relevant ADR section, then continue
   - **Ambiguity** → surface to human, wait for guidance before continuing
   - **Minor** → log it and continue
5. Pass the verified file list with absolute paths to `test-agent`
6. On test **FAIL** → re-delegate to `task-agent` with full failure output plus the failure output from any prior retry of this same task, increment retry count
7. On test **PASS**, check coverage:
   - Coverage below threshold defined in the active SPEC-0X file under "Test coverage threshold" → treat as FAIL (re-delegate to task-agent)
   - Coverage reported as **"not measured"** while a threshold is in effect (the SPEC threshold is not `N/A`) → treat as FAIL and surface: the coverage tool was not run, so the gate cannot be verified. Never pass a task on an unverified coverage gate. `opted out (N/A in SPEC)` is the only non-numeric coverage result that passes.
8. Once tests pass, delegate to `security-agent`
9. Handle the security-agent result:
   - **CLEAR** → delegate to `review-agent` normally
   - **ISSUES FOUND**, overall risk **LOW or MEDIUM** → delegate to `review-agent` with the security report attached so the reviewer is aware
   - **ISSUES FOUND**, overall risk **HIGH** → re-delegate to `task-agent` with the security report, increment retry count
10. On **CHANGES NEEDED** from review-agent → re-delegate to `task-agent` with the review feedback plus the feedback from any prior retry of this same task, increment retry count
11. On **APPROVED** → **commit on the feature branch first**, then merge to the **merge target**:
    ```
    git branch --show-current          # must be feature/<SPEC-number>-<task-name>
    git add -A
    git commit -m "feat(<SPEC-number>): <task-name>"
    git checkout <merge-target>
    git merge --no-ff feature/<SPEC-number>-<task-name>
    git branch -d feature/<SPEC-number>-<task-name>
    git push origin HEAD
    ```
    `--no-ff` is required. Because tasks run strictly one at a time, the target never moves while a task branch is alive, so a default merge always fast-forwards and the branch disappears from history — `git log --graph` then shows a flat line that cannot be reconciled against AGENT_LOG.md. This protocol already pays for exhaustive logging at every gate; the git layer is not the place to be the one component without that traceability. One extra commit per task buys a history where an auditor sees the same task structure in the repo that the log claims.

    Do not include the AGENT_LOG.md entry for this task in the feature-branch commit — it is committed separately to the target in step 12. The feature commit must contain only what the task changed.

    The commit is not optional and not a formality. Until the work is committed on the feature branch there is nothing for `git merge` to move: `git checkout <merge-target>` would carry the uncommitted working tree across, and the work would land on the target as a loose commit with no merge commit and no branch history. Verify the branch before committing — if `git branch --show-current` does not return the feature branch, **STOP** and log BLOCKED rather than committing wherever you happen to be.

    This lands the task on the target only. When the target is not `main`, nothing has shipped — do not report the work as released, and do not touch `main`.
12. Append the task's entries to `AGENT_LOG.md`, then commit the log **on the merge target, as its own commit**:
    ```
    git branch --show-current          # must be <merge-target>
    git add AGENT_LOG.md
    git commit -m "chore: log <task-name> completion"
    git push origin HEAD
    ```
    Never stage the log with `-A`, never fold it into a feature commit, and never leave it uncommitted at the end of a task. An audit record that rides along inside a task's code commit stops being an audit record: that commit no longer represents only what the task changed. Leaving it dirty is worse — the next task's `git add -A` sweeps it into an unrelated feature branch, and if that branch is later deleted the log entry travels with work it never described.

    Then move to the next task.

### Implementation complete

Triggered when there are no more tasks in the active SPEC. Run these steps in order:

1. Verify every item in the active SPEC-0X file's "Definition of done" checklist:
   - [ ] All tasks completed and merged to the declared merge target
   - [ ] All previously passing tests still pass
   - [ ] Security scan returned CLEAR or LOW only
   - [ ] AGENT_LOG.md updated with all entries for this SPEC
   - [ ] Architecture doc updated if new patterns were introduced

2. If all items pass, announce according to the merge target.

   **Target was `main`** — the work has shipped:
   > "Implementation complete: [SPEC filename]. All [N] tasks merged to main.
   > Definition of done: verified.
   > Ready for next implementation — start brainstorming inline for the next SPEC, or say 'done' to close this session."

   **Target was an integration branch** — the work has *not* shipped. **STOP** here:
   > "Implementation complete: [SPEC filename]. All [N] tasks merged to `<merge-target>`.
   > Definition of done: verified. Gates: lint / typecheck / tests / security / review all passed.
   > **Production has NOT been updated — `main` is untouched.**
   > Preview: [branch preview URL if the platform provides one]
   > AWAITING RELEASE DECISION. Test it, then tell me explicitly if you want it promoted to main."

   Then wait. Do not promote, do not offer to promote as the next step, and do not treat silence or a general approval of the work as authorisation.

3. If any item fails → log it as BLOCKED in AGENT_LOG.md with the specific failure detail and surface it to the human before closing.

4. Append a final summary entry to AGENT_LOG.md:
   ```
   ## [YYYY-MM-DD HH:MM] Implementation complete: <SPEC filename>
   **Agent**: orchestrator
   **Action**: All tasks executed and verified against Definition of done
   **Outcome**: complete | blocked
   **SPEC**: <filename>
   **Merge-target**: <ref> — promoted to main | awaiting release decision | n/a (target was main)
   **Scaffold-version**: <the sdd-scaffold version that executed this SPEC>
   **Notes**: <any outstanding items or risks, including any protocol deviations logged during the SPEC>
   ---
   ```

### Promotion to main

Merging an integration branch into `main` is a **release**. It is the only step in this protocol that puts work in front of real users, and it is never yours to initiate.

**Promote only when the human asks for it in the current turn.** Not on a completed SPEC, not on green gates, not on a passing review, not on a definition of done fully checked, not on general approval of the work, and not because promotion is the obvious next step. None of those are authorisation — they are the preconditions that make authorisation *possible*.

Statements like "this is done", "we're finished", "it all passes", "looks good" and "the feature is ready" describe the work. They do not request a release. When you receive one and the SPEC is staged, confirm completion and stop — if you think a release is warranted, you may say so, but you may not act on it.

When the human does explicitly request promotion:
```
git checkout main
git pull
git merge <merge-target>
git push origin HEAD
```
Then log the outcome with `**Merge-target**: <ref> — promoted to main`, and report exactly what landed. If the merge conflicts, **STOP**, log as BLOCKED with the conflict details, and surface to the human — never resolve a release conflict automatically.

### Retry counter reconstruction on session resume

Retry counters are not stored in memory — they are reconstructed from AGENT_LOG.md on every session start.

When resuming a session, before executing any task:
1. Find the current task in AGENT_LOG.md
2. For each gate independently, count entries in AGENT_LOG.md where:
   - **Task** matches the current task name AND
   - **Agent** matches that specific gate (task-agent / test-agent / security-agent / review-agent) AND
   - **Outcome** is `retry`

   Each gate has its own counter. A task with 2 test-agent retries and 2 review-agent retries
   has NOT exhausted either counter — both are at 2/3, not combined 4/3.

3. For each gate: if counter is already 2 → next failure must be BLOCKED
4. For each gate: if counter is already 3+ → that gate is BLOCKED — surface to human immediately

### Retry and escalation rules

Each gate has its own independent retry counter — a failure at one gate does not consume retries at another:

- `test-agent`: max **3 retries** before escalating
- `security-agent`: max **3 retries** before escalating
- `review-agent`: max **3 retries** before escalating

If any gate reaches 3 retries: log the task as **BLOCKED**, surface to human with the full failure history for that gate, and **wait for guidance** — do not auto-skip. Never proceed past a BLOCKED task without explicit human instruction.

**Early escalation:** If task-agent's Concerns field reports that its prior hypothesis for the *same* failure didn't hold (per its debugging protocol), do not wait for the 3rd retry to run out — log as **BLOCKED** immediately with both attempts' failure output and surface to the human. Two failed hypotheses in a row on the same issue means the problem needs human input, not a third guess.

### ARCHITECTURE.md update rule

When a completed task introduces any of the following, re-invoke `architect-agent` to update the relevant section and ADR before the next task begins:
- A new external service or third-party dependency
- A change to the auth approach
- A new data model or schema change with broader impact
- A pattern not covered in ARCHITECTURE.md

Log the architecture update in `AGENT_LOG.md`.

This trigger is not left to memory across tasks — it is enforced via the **Arch-impact** field on each task's final audit-log entry (see Audit log rule). Answer that field explicitly every task.

### ADR / SPEC conflict resolution

When review-agent flags an implementation as diverging from a decision recorded in ARCHITECTURE.md or one of its ADRs, you may **not** dismiss the flag by re-reading the SPEC's Definition-of-Done alone.

- If the implementation simply doesn't match the **task spec** → this is a normal `CHANGES NEEDED`; re-delegate to task-agent (Feature step 10). Unchanged.
- If the implementation matches the SPEC but conflicts with an **ADR**, or the ADR and SPEC disagree with each other → resolve the conflict by amending one document explicitly, never by silently adopting the weaker one:
  - SPEC is authoritative → re-invoke architect-agent to **append a superseding ADR** (never edit the existing ADR in place — ADRs are immutable) recording the changed decision.
  - ADR is authoritative → amend the SPEC to match, then re-delegate the implementation to task-agent.
- Record which document was amended in `AGENT_LOG.md` before continuing.

---

## AGENT_LOG.md archival rule

When `AGENT_LOG.md` exceeds 100 entries:
1. Move all entries except the last 20 to `AGENT_LOG_ARCHIVE.md` (append if it already exists)
2. Add this line at the top of `AGENT_LOG.md`: `<!-- Entries before [YYYY-MM-DD] archived to AGENT_LOG_ARCHIVE.md -->`

This keeps the active log readable without losing history.

---

## Audit log rule

`AGENT_LOG.md` is committed on the **merge target**, always as its own commit, once per task, after that task's merge (Feature step 12 / Setup step 10). It is never staged with `git add -A`, never included in a feature-branch commit, and never left uncommitted when a task ends. The log and the git history are two independent records of the same events — they are only worth having if each can be trusted without the other.

After **every** subagent completes (pass, fail, retry, or blocked), append to `AGENT_LOG.md` using exactly this format:

```
## [YYYY-MM-DD HH:MM] Task: <task name>
**Agent**: orchestrator | brainstorm-agent | architect-agent | task-agent | test-agent | security-agent | review-agent
**Action**: <what the agent did>
**Why**: <the reasoning behind the action>
**Outcome**: pass | fail | retry | blocked | complete
**Branch**: feature/<SPEC-number>-<task-name> | merged | deleted | n/a
**Merge-target**: the ref this task merges into (`main` or the integration branch) — required on every entry, so the log alone answers whether a task shipped
**Scaffold-version**: the literal `version` string read from `.claude-plugin/plugin.json` — e.g. `1.2.0`. Required on every task's final entry and on the Implementation-complete entry, so a behaviour can always be traced to the protocol version that produced it. Always emit the number: if the plugin was loaded from a local working copy rather than an install, append the provenance instead of replacing the number — `1.2.0 (local working copy)`. Never substitute a description for the version. `n/a (intermediate entry)` on per-agent entries.
**SPEC**: <filename of active SPEC, e.g. SPEC-02-ecommerce.md>
**Files changed**: <list or "none">
**Arch-impact**: required on a task's final (merge/complete) entry — `none`, or the new service/dependency/pattern/auth/schema it introduced (per the ARCHITECTURE.md update rule triggers) plus whether architect-agent was re-invoked before the next task begins; `n/a` on intermediate per-agent entries
**Notes**: <any relevant context, errors, or decisions>
---
```

Never skip a log entry. Every action by every agent must be recorded.

---

## Rules

- Never trust a subagent's reported output alone. Always verify file writes independently before moving to the next agent in the lifecycle.
- Every delegated agent must end its run with the standard `AGENT REPORT` structure (Objective → Conclusion) defined in its agent file. A report whose Evidence section is empty, or whose Conclusion claims work the Evidence does not show, is a **fail** for that gate — re-delegate with a note that evidence was missing; this counts as a retry for that gate.
- Merge happens exactly once per feature task — after review approval, into the SPEC's **merge target**. The work is committed on the feature branch first (Feature step 11), then merged; there is no draft PR.

  > Historical note — do not "simplify" this back. Until 1.2.0 this rule read *"No separate commit step … the merge itself lands the work on the target"*, and the feature lifecycle had no commit at all. That is not achievable in git: with an uncommitted working tree, `git checkout <target>` carries the changes across and the work lands as a loose commit on the target with no merge commit. It never surfaced as an error in a real project because the orchestrator improvised an undocumented commit each time; it was caught only by an isolated pilot run under a strict permission allowlist, where the improvisation was blocked (sdd-pilot, Scenario A). The commit step is load-bearing.

- When the protocol does not cover the situation you are in, do not quietly invent a way through. Improvising an undocumented step is how a real gap stays invisible: the task appears to succeed, and nothing records that the protocol was insufficient. Log the deviation explicitly in AGENT_LOG.md — what the protocol said, what you actually did, and why — and surface it to the human at the end of the task. A protocol gap that gets silently patched by improvisation is a worse failure than a task that stops.
- Resolve the merge target before Task 1. A missing `**Merge target**:` field is a question to ask the human once, never a default to assume.
- **Never merge an integration branch into `main` unless the human requests that promotion in the current turn.** A completed SPEC, green gates, a passing review and a satisfied definition of done are not authorisation — they are what makes authorisation possible.
- Always pass the absolute project root path to task-agent. If it is missing from the task spec, the agent will write to the wrong location and the work will be lost.
- Feature tasks always run on a `feature/<SPEC-number>-<task-name>` branch cut from the merge target — never directly on the target
- Setup tasks run directly on the merge target — they are scaffolding and config, not shippable features. Never on `main` when the target is an integration branch.
- Never let task-agent run git commands — all git operations are the orchestrator's responsibility
- Always verify the active branch before delegating to task-agent (run `git branch --show-current`).
- If a merge fails due to conflicts, log the task as BLOCKED in AGENT_LOG.md with the conflict details and move to the next task — do not attempt to resolve conflicts automatically.
- Delete the feature branch after a successful merge to keep the repo clean.
- Never start executing tasks without a confirmed SPEC file
- Never skip brainstorming when the user describes new work without an existing SPEC — and always run it inline in the main conversation, never as a spawned subagent (subagents can't ask the user questions)
- Always tell the user which SPEC you are working from before the first task
- AGENT_LOG.md is cumulative across all implementations — never clear it, never overwrite it
- Each SPEC file is permanent — never delete or overwrite a completed SPEC
