---
description: Build a plan using a collaborating Claude Code agent team, with GitHub board tracking. Reads a plan path and optional team size, moves the issue to In Progress, has the lead author/distribute integration contracts, spawns agents to build in parallel, runs end-to-end validation, and hands off to /commit. Explicit invocation only.
argument-hint: [path-to-plan] [num-agents]
disable-model-invocation: true
---

# Execute Team: Build from a Plan with an Agent Team

This is the multi-agent counterpart to `/execute`. It fills the same lifecycle slot
— consume a plan, produce a built and validated feature with the GitHub board kept
in sync — but instead of one agent working sequentially, a **lead** coordinates
several agents building different layers in parallel.

Adapted from coleam00/context-engineering-intro `build-with-agent-team` (MIT), trimmed
for this workflow: board lifecycle baked in, and contracts sourced from the plan.

## When to use this vs /execute

- **/execute** — one domain, sequential work, a plan a single agent can carry top to bottom.
- **/execute-team** — multiple components that integrate across boundaries (e.g. frontend
  + backend + database), buildable in parallel, where agents must agree on interfaces.
  `/plan-feature` recommends which executor fits a given plan.

## Arguments

- **Plan path**: `$ARGUMENTS[0]` — markdown plan file (ideally produced by `/plan-feature`)
- **Team size**: `$ARGUMENTS[1]` — number of agents (optional; inferred from the plan if omitted)

---

## Step 0: Link to the GitHub issue → In Progress

Before building, wire this run into the board (same as `/execute`):

- Ask which issue this plan implements, if it isn't obvious from the plan.
- Read it: `gh issue view <NUMBER> --repo {{REPO_OWNER}}/{{REPO_NAME}}`
- Move the board item to "In Progress": `./.claude/scripts/move-issue.sh <NUMBER> "In Progress"`

**Never close issues or move them to Done here — only `/commit` closes issues.**

## Step 1: Pre-flight checks

**Feature-flag gate — check this before anything else.** Agent teams are an
experimental Claude Code feature. Verify `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is
set (in the `env` block of settings.json, or the environment). If it is not set,
STOP with:

> Agent teams are not enabled. Either set `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
> in settings and restart, or run `/execute <plan>` — the single-agent executor
> handles the same plan.

Operational limitations to respect throughout (from the agent-teams docs): **one
team per session**; **no nested teams**; **teammates do not inherit this
conversation** — every spawn prompt must carry the full contract slice (the Step 4
prompt template does).

Then run these and report a checklist before building:

```bash
git status --porcelain        # working tree clean?
git branch --show-current     # on the expected branch?
# deps + env per the project, e.g.:
# npm ls --depth=0 2>&1 | head -5
# test -f .env.local || test -f .env
```

- **Dirty tree** → stop; ask to stash, commit, or abort.
- **Missing deps** → install and continue.
- **Missing env** → stop and ask.

## Step 2: Read the plan and size the team

Read `$ARGUMENTS[0]`. Identify: what's being built, the major components/layers, the
technologies involved, and the dependencies between components.

If `$ARGUMENTS[1]` is provided, use that team size. Otherwise size by the number of
independent components and technology boundaries:

- **2** — clear frontend/backend split
- **3** — full-stack (frontend, backend, database/infra)
- **4** — adds a cross-cutting concern (testing, DevOps, docs)
- **5+** — many independent modules

For each agent, define: **name**, **owns** (exclusive files/dirs), **does NOT touch**
(prevents conflicts), and **responsibilities**.

## Step 3: Get the contracts (from the plan, or author them)

Parallel agents diverge on endpoint URLs, response shapes, trailing slashes, and
storage semantics unless they start from agreed interfaces. The lead settles these
**before** spawning — this upfront work is what lets every agent spawn at once.

- **If the plan has an Integration Contracts section** (plans from `/plan-feature`
  should): read it, confirm it's complete, and hand each agent its relevant slice.
  This is the normal path. (If it says "Single-component feature — no cross-component
  contracts", this plan belongs to `/execute`, not a team — say so and stop.)
- **If it doesn't:** author the contracts now from the plan — exact endpoint URLs
  (including trailing slashes), request/response JSON shapes, status codes,
  event/SSE formats, data models, and response envelopes (flat vs nested).

Also pin down **cross-cutting concerns** and assign each to exactly ONE agent:

- Streaming-storage semantics (per-chunk vs accumulated into one row)
- URL conventions (trailing slashes, path/query params)
- Error shapes (status codes + error body format)
- Accessibility hooks (aria-labels) so UI is testable by automation

**Contract quality bar** before handing to agents:

- URLs exact, including trailing slashes (`POST /api/sessions/` vs `POST /api/sessions`)
- Response shapes as explicit JSON, not prose (`{"session": {...}, "messages": [...]}`)
- All event/SSE types documented with exact JSON
- Error responses specified (404 body, 422 body, …)
- Storage semantics explicit (accumulated vs per-chunk)

## Step 4: Spawn agents in parallel

You are the **lead / coordinator** — do not write feature code yourself; delegate.
The default in-process display is all this needs — teammates' activity appears in
your session. Split panes (`teammateMode: "tmux"`) are optional, never required.

Spawn all agents at once, each with everything it needs to build independently:

```
You are the [ROLE] agent for this build.

## Ownership
- You own: [dirs/files]
- Do NOT touch: [other agents' files]

## What you're building
[relevant section of the plan]

## Contracts
### You produce: [the contract this agent owns]
  - Build to match exactly; message the lead before deviating.
### You consume: [the contract this agent depends on]
  - Build against it exactly; do not guess.
### Cross-cutting concerns you own: [explicit list]

## Coordination
- Message the lead about anything that affects a contract; wait for approval before changing one.
- Challenge [other agent]'s work at [integration point].

## Before reporting done
Run these validations and fix any failures: [commands from the plan]
Do NOT report done until all pass.
```

## Step 5: Facilitate while they build

- Relay contract issues between agents. If a deviation is justified, update the
  contract and notify everyone affected.
- Unblock agents and track progress on a shared task list. Because contracts are
  settled, agents build immediately — only integration testing blocks on others.
- Before any agent reports done, run a **contract diff**: "Backend, exact curl per
  endpoint?" vs "Frontend, exact fetch URLs + request bodies?" Flag mismatches
  before integration testing.
- **Cross-review:** each agent reviews an adjacent agent's integration surface
  (frontend reviews backend API usability, backend reviews DB query patterns, …).

## Step 6: Validation

**Agent-level** (each agent, before reporting done) — derive specifics from the
plan's Validation section. For example:

- **Database** — schema creates cleanly; CRUD works; foreign keys/cascades behave; indexes exist.
- **Backend** — server starts; endpoints respond; request/response shapes match; error codes correct; streaming works (if applicable).
- **Frontend** — type-checks (`tsc --noEmit`); build succeeds; dev server starts; components render without console errors.

**Lead-level (end-to-end)** — after all agents return control, you run it:

1. The system starts (all services up, no startup errors).
2. The happy path works end to end.
3. Integrations connect (frontend → backend → database; data flows through all layers).
4. Edge/empty/error/loading states behave.

If validation fails: identify which agent's domain owns the bug, re-spawn that agent
with the specific issue, and re-validate.

## Step 7: Update the issue → hand off to /commit

Same close-out as `/execute`:

- Check off satisfied acceptance criteria in the issue body
  (`gh issue edit <NUMBER> --repo {{REPO_OWNER}}/{{REPO_NAME}} --body "<updated body>"`).
- Comment a summary of what each agent built
  (`gh issue comment <NUMBER> --repo {{REPO_OWNER}}/{{REPO_NAME}} --body "..."`).
- Leave the issue **open** — run `/commit` to commit the code and close it.

## Definition of Done

1. All agents report done and have validated their own domain.
2. Contract diff is clean; cross-review feedback addressed.
3. Lead end-to-end validation passes.
4. The plan's acceptance criteria are met.
5. The issue is updated and ready for `/commit`.

## Pitfalls to Prevent

1. **Spawning without contracts** → integration mismatches. Settle contracts first.
2. **Implicit contracts** ("the API returns sessions") → require exact JSON, URLs, status codes.
3. **Orphaned cross-cutting concerns** → assign each to exactly one agent.
4. **Lead over-implementing** → stay the coordinator; delegate the building.
5. **Two agents editing one file** → assign exclusive ownership.
6. **Agents not talking** → require explicit handoffs via lead relay.
7. **Per-chunk streaming storage** → frontend renders N bubbles on reload; accumulate into single rows.
8. **Hidden interactive elements** (CSS `opacity-0`) → invisible to automation; add aria-labels and visible focus.

---

## Execute

Now run the build:

1. Step 0 — link the issue, move it to In Progress.
2. Step 1 — feature-flag gate (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`), then pre-flight checks.
3. Step 2 — read the plan, decide team size (`$ARGUMENTS[1]` if given).
4. Step 3 — get the contracts (from the plan if present, else author them) and assign cross-cutting concerns.
5. Step 4 — spawn all agents in parallel, each with its contract slice and validation checklist.
6. Step 5 — facilitate: relay messages, mediate deviations, run the contract diff.
7. Step 6 — when all agents return, run end-to-end validation yourself.
8. Step 7 — update the issue and hand off to `/commit`.
