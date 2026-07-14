# Evolving This Framework Toward Agentic Engineering

A comparison of this `claude-workflow-template` against IndyDevDan's "AI Developer Workflows" (ADW) model, and a level-by-level roadmap for scaling from single-session Claude Code work toward multi-agent workflows — all while staying on the Claude Code subscription (no API bill).

Source: transcript of ["Forget Loop Engineering"](https://www.youtube.com/@indydevdan) by Dan Eisler (IndyDevDan).

---

## Dan's core thesis

Forget "loop engineering." Build **AI Developer Workflows** by composing 3 actors:

- **Engineers** — show up at the ends (planning + review)
- **Agents** — fill the middle
- **Code** — fastest, most reliable, zero-cost, zero-hallucination

The endgame is a **software factory** that routes any kanban ticket through a specialized workflow (feature / bug / hotfix / chore) via parallel agent sandboxes.

Key rules Dan repeats:
1. **KISS.** Start with the simplest workflow that works.
2. **Do it by hand first.** Walk end-to-end yourself (mermaid diagram), then automate.
3. **Use agents AND code.** Don't overload agents with work code can do deterministically.
4. **Separate concerns.** Agent SDK runs the build agent, then external code runs the linter, then results feed back into the same agent session — not "one big skill."
5. **Scale compute to scale impact.** Multiple specialized agents beat one generalist.
6. **Build the system that builds the system.** Meta-engineering compounds.

---

## What this framework already gets right

| Dan's concept | Existing equivalent |
|---|---|
| Kanban ingestion | GitHub Projects + `/continue`, `/status` |
| Plan agent | `/plan-feature` |
| Build agent | `/execute` |
| Ship node | `/commit` |
| Code guardrails | Husky + lint-staged, placeholder scan, deviation rules |
| Engineer at both ends | Explicit human review at PRD → plan → execution → commit |
| Specialization via context | Path-scoped rules (`.claude/rules/`), scout-friendly docs (`.claude/docs/`) |
| Templated engineering | `CLAUDE.md`, `workflow.md`, deviation rules baked into commands |

## Gaps vs Dan's model

1. **Agent-to-agent handoff.** `/plan-feature` is one agent doing Phase 0-5 sequentially. Dan splits scout ≠ plan ≠ build ≠ test.
2. **Parallelism.** Everything is a blocking single session.
3. **Deterministic code between agents.** Hooks exist *inside* the session (pre-commit) but not *between* agent invocations.
4. **Ticket-type specialization.** `/execute` is one-size-fits-all. No `/hotfix`, `/chore` variants.
5. **Sandboxing.** No worktree/isolation story.
6. **Validation loop back into build.** `/execute` runs validations at the end. Dan pipes lint/test failures back into the build agent as a loop until pass.

---

## The Level Ladder

Each level builds on the previous. All fit within Claude Code's native primitives — subagents (`Agent` tool), hooks, worktrees, background bash, multiple sessions, scheduled agents — no API costs.

### Level 0 — Current state

Single Claude Code session, human-in-loop at every step, slash commands run sequentially:

```
/create-prd → /plan-feature → /execute → /commit → /continue
```

Works fine. Bottleneck: everything blocks on the human and on a single agent's context.

---

### Level 1 — Add code between the human and the agent

**Dan:** *"Code costs zero tokens and always runs the same way."*

The cheapest win. Move deterministic checks out of the agent's turn and into hooks that trigger automatically.

**Concrete moves:**

- **Post-edit validation hook** in `.claude/settings.json`: after any Write/Edit, run `tsc --noEmit`, `eslint`, or the project's typecheck. Failures show up as a system reminder — Claude fixes them without you having to say anything. Zero tokens for the trigger.
- **Stop hook** that runs the full validation battery before the turn ends. Currently `/execute` does this manually in Step 5 — moving it to a hook makes it unskippable.
- **Extend the pre-commit placeholder scan** — currently catches `TODO|FIXME|HACK|XXX` and empty function bodies. Add empty `catch` blocks and `.only`/`.skip` in test files.

**Effort:** ~1 hour of hook config.
**Impact:** Closes the tightest "loop" in Dan's diagram (build → lint → build) with deterministic code, not a prompt.

---

### Level 2 — Parallel subagents inside one session

**Dan:** *"Scale compute to scale impact."*

Claude Code's `Agent` tool spawns subagents; multiple in one message run concurrently. Use this to split `/plan-feature`'s serial phases into parallel scouts.

**Concrete moves — refactor `/plan-feature` Phase 2/3:**

Spawn three subagents in one message:
- **Explore agent** — codebase intelligence (patterns, imports, similar features, naming conventions)
- **general-purpose agent** — external research (docs, gotchas, versions, breaking changes)
- **Explore agent** — testing patterns + existing test scaffolds

Main session synthesizes the three reports into the plan file. This is Dan's scout/researcher split, done inside one session.

**Concrete moves — refactor `/execute`:**

After each task completes, spawn a **verification subagent** to independently check the observable truths from the plan. Two eyes catch things one doesn't. The verifier reports pass/fail without polluting the builder's context.

**Effort:** Rewrite two commands.
**Impact:** Planning phase becomes ~3× faster wall-clock and more thorough because context is isolated per subagent.

---

### Level 3 — Specialized command variants

**Dan:** *"You're not going to deploy your heavy AI developer workflows for a chore."*

Split `/execute` by ticket weight. Match workflow depth to ticket depth.

**New commands:**

- **`/execute`** — current heavy workflow (full plan, verification subagent, all validations). For features.
- **`/hotfix`** — skips PRD, skips plan file, single agent, minimum ceremony, prioritizes speed, doesn't touch board Phase field
- **`/chore`** — no issue linkage, single validation pass, `/commit` with `chore:` prefix
- **`/bug`** — pulls issue body as context, forces a failing-test-first step, then fix

**New planners:**

- **`/plan-bug`** — reads bug repro + logs, generates minimal fix plan
- **`/plan-hotfix`** — minimal: "what's broken, what's the fix, ship it"

**Effort:** 4 new commands, each ~half the size of `/execute`.
**Impact:** No more over-engineering a typo fix. Serious features still get the full treatment.

---

### Level 4 — Isolation via worktrees

**Dan:** *"Worktrees are a great place to start, not a great place to end"* — but for a solo dev on subscription, they're perfect and you never hit "the end."

Use Claude Code's `EnterWorktree` tool inside a new command.

**Concrete moves:**

- New `/execute-isolated` command that wraps `EnterWorktree`
- `/execute-isolated plan-A.md` runs in worktree A
- Second Claude Code terminal runs `/execute-isolated plan-B.md` in worktree B
- No file conflicts, no partial-state confusion, easy rollback via `ExitWorktree`

**Effort:** One new command wrapping `EnterWorktree`.
**Impact:** Real parallelism without leaving the subscription.

---

### Level 5 — Cross-session coordination via GitHub as shared state

This is where you actually approach Dan's "software factory" without paying for it.

**Setup:**
- Terminal 1: `/execute` on issue #42 (feature) in worktree A
- Terminal 2: `/hotfix` on issue #67 (prod bug) in worktree B
- Terminal 3: `/plan-feature` on issue #71 in the main tree

GitHub Issues + Projects = the shared blackboard (already have this). `/continue` in any session reads the current board state, so nothing steps on anything. `/commit` already comments/checks-off/closes correctly, so sessions coordinate without talking to each other.

**One new convention:** add a **worktree label or comment** to issues so each session knows which worktree it owns. Example: `worktree:hotfix-67`.

**Effort:** Convention only, no code.
**Impact:** You become the router in Dan's factory diagram.

---

### Level 6 — Automated triage (aspirational)

Dan's **factory router agent**. With **scheduled agents** (`CronCreate` / the `schedule` skill) you can:

- Every morning, a scheduled Claude session runs `/continue`
- Picks the top priority `Ready` issue
- Classifies it: `type:bug` → `/plan-hotfix`, `type:feature` → `/plan-feature`, `type:chore` → prepare a chore commit
- Drops the plan file
- Stops for your review before `/execute`

Effectively an automated version of "read the board, decide the workflow, prep the context" — leaving you the two constraint slots Dan identified: **prompt** (approve the plan) and **review** (approve the diff).

**Effort:** One cron + a small `/dispatch` command that reads the board and routes to the right planner.
**Impact:** Closes the loop from "ticket lands" to "plan is waiting for review" without you being at the keyboard.

---

## Recommended first move

If you do one thing, do **Level 1 + the parallel scout half of Level 2**. Between them you:

- Kill the tightest wasteful loop (manual "did lint pass?" checks) with deterministic hooks
- Get your first taste of Dan's scale-compute-to-scale-impact by parallelizing the research phase of `/plan-feature`

Both fit inside the existing framework — no restructuring, no new mental model. Then Levels 3-6 become natural extensions instead of a rewrite.

---

## Caveat for subscription-only setups

Dan talks about the Anthropic Agent SDK + separate code files calling agents. On the Claude Code subscription you don't have that — the "orchestrator" is **you plus slash commands**. So your "code between agents" lives in:

- **Hooks** (`.claude/settings.json` — pre-commit, post-edit, stop)
- **Bash blocks inside command markdown files**
- **Deterministic sections of skills**
- **Cron-scheduled Claude sessions** (`CronCreate`)

Same idea, different substrate. You still get the 3-actor composition (engineer + agents + code), just orchestrated through slash commands instead of an SDK.

---

## Mapping — Dan's diagram to your primitives

| Dan's factory node | Your Claude Code primitive |
|---|---|
| Kanban queue | GitHub Projects board |
| Factory router agent | `/dispatch` (Level 6) or you reading `/continue` |
| Scout agent | `Agent` tool with `subagent_type: Explore` |
| Plan agent | `/plan-feature` (single-agent today, subagent-orchestrated at Level 2) |
| Build agent | `/execute` (or `/hotfix`, `/bug`, `/chore` at Level 3) |
| Test agent | Verification subagent inside `/execute` (Level 2) |
| Agent sandbox | Worktree via `EnterWorktree` (Level 4) |
| Multiple sandboxes running in parallel | Multiple Claude Code terminals, one per worktree (Level 5) |
| Code between agents | Hooks + bash inside command files (Level 1) |
| Ship node | `/commit` |
| Engineer review | You, always, at plan approval and commit |

---

## Success metric

You're doing this right when: **a new ticket lands, you review the auto-generated plan, hit `/execute`, and the workflow ships a passing PR with your name on it — while you're already reviewing the plan for the next ticket in another terminal.**

That's the solo-dev version of the software factory. All achievable on the Claude Code subscription.
