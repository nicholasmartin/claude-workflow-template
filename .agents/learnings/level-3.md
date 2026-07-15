# Level 3: Weight-Matched Command Variants — What Changed and Why

**Status:** complete — walkthrough performed and owner sign-off recorded on epic #16 (2026-07-15); items 4 and 6 explicitly deferred (see log)
**Commits:** this level ran learning-first — doc + walkthrough + sign-off preceded `/commit` (a deliberate inversion of Levels 1–2, where commits landed before the gate)
**Diagram:** `.agents/learnings/level-3-diagram.mmd` (paste into mermaid.live) — drawn from the plan, now matching the shipped reality

---

## The gap this closes

Before Level 3, `/execute` was one-size-fits-all: a typo fix paid for plan-file ceremony, issue choreography, and verifier subagents it didn't need, while a multi-component feature got only one sequential agent. AGENTIC-EVOLUTION.md's Level 3 rule (via Dan): *"You're not going to deploy your heavy AI developer workflows for a chore."* And Level 2 had already landed the Integration Contracts plan section specifically for a team executor that didn't exist here yet — this level ships its consumer.

The deliverable is a **weight ladder** where each rung adds exactly one unit of ceremony:

```
/chore  <  /hotfix  <  /bug  <  /execute  <  /execute-team
no GitHub   issue       issue      plan +       plan + contracts
no plan     optional,   driven,    per-task     + parallel teammates
no board    Status      test-      verifiers    with exclusive file
            only        first                   ownership
```

What the light variants shed is *ceremony* — never the deterministic validation layer. Level 1's hooks fire identically under every variant; that's stated explicitly inside each command file.

## What changed, file by file

### New: three light executors (`template/.claude/commands/`)

| File | Contract | GitHub interaction |
|---|---|---|
| `chore.md` (~40 lines) | Do it, one narrow validation, hand off with `chore:`/`docs:` tag. Deviation rule: reveals a real bug → STOP, recommend `/bug`. | **None.** No issue created, linked, or closed; `/commit`'s issue step naturally no-ops. |
| `hotfix.md` (~60 lines) | Diagnose fast, smallest correct fix, one targeted proof. Deviation rules trimmed to three; architecture → STOP survives verbatim. Hands off with `fix:` (`hotfix` is not a Conventional Commits type). | Issue **optional** — never created. If one exists: `move-issue.sh` moves **Status only, never Phase**. |
| `bug.md` (~55 lines) | **Red repro before any fix** — a failing test, or (no test framework) a recorded manual repro commented on the issue. "Do not proceed to Step 2 until you have a red repro." Fowler's test-ensures-the-bug-stays-dead. | Issue-driven: body + comments are the repro source; AC check-offs + summary comment; issue stays open for `/commit`. |

### New: two minimal planners

- `plan-hotfix.md` — the deliberate opposite of `/plan-feature`'s 500-line template: read the evidence, inspect only implicated files, write exactly five sections (broken / root cause / fix / risk / validation) to `.agents/plans/hotfix-<slug>.md`, **≤40 lines**. "If it won't fit in 40 lines, it isn't a hotfix."
- `plan-bug.md` — repro + logs → `.agents/plans/bug-<n>-<slug>.md` (≤80 lines) where **task 1 is always the failing test**. Allowed at most ONE `Explore` scout, only for genuinely unfamiliar code, reason stated.

Neither planner does board writes. Both name their handoff executor.

### New: the heavy executor — `execute-team.md` (ported from nexus)

Source: `~/projects/nexus/.claude/skills/execute-team/SKILL.md` (itself adapted from coleam00's MIT `build-with-agent-team`; attribution kept). A **lead** agent reads the plan's Integration Contracts, sizes the team (2–5), hands each teammate an exclusive-ownership contract slice, facilitates (contract diffs, cross-review), runs end-to-end validation itself, and hands off to `/commit`. Port deltas:

1. Skill directory → single command file (commands/skills share frontmatter now; `disable-model-invocation: true` kept — explicit invocation only)
2. `--repo nicholasmartin/nexus` (×3) → `{{REPO_OWNER}}/{{REPO_NAME}}` sync tokens; board-move prose → `move-issue.sh`
3. **New flag gate first thing in Step 1:** `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` unset → STOP with "…or run `/execute <plan>`" fallback. Documented limitations: one team per session, no nested teams, teammates inherit nothing (spawn prompts carry the full slice)
4. Display prose updated: in-process is the default; tmux split panes optional, never required
5. Single-component plan handed to it → bounced to `/execute` at Step 3
6. Contract machinery, quality bar, pitfalls, Definition of Done: verbatim

### Updated: the ripple (workflow-skill lockstep)

- `plan-feature.md` — Phase 4 decides the executor (single-domain → `/execute`; populated INTEGRATION CONTRACTS → `/execute-team`); the report now carries a "Recommended executor" line. Scout fan-out untouched.
- `workflow.md` — §7 catalog entries for all 6 (12 command entries total); §9 roster row for teammate agents; "a team-based executor arrives in a later phase" → *"the team-based executor is `/execute-team`"*; new design rule: **light variants spawn no subagents by design — weight-matching is the feature.**
- `skills/workflow/SKILL.md` — both enumerations now list 15 command files.
- `init-project.md` — verification loop + "15 slash commands configured".
- Root `CLAUDE.md` — count line (direct edit; sync never touches it).
- **Not changed, deliberately:** the label taxonomy. `type:chore`/`type:hotfix` would be a High-Stakes change and are unnecessary — `/chore` has no issue, `/hotfix` rides its issue's existing labels, `/bug` reuses `type:bug`.

## How information flows now

```
BEFORE                                  AFTER
every ticket                            you route by weight (until /dispatch, Level 6)
  └─ /execute                             ├─ typo/dep bump   → /chore    (zero GitHub)
     (plan file + issue choreography      ├─ urgent breakage → /hotfix   (Status only)
      + verifiers, no matter how          ├─ reported bug    → /bug      (red repro gate)
      small the ticket)                   ├─ single-domain   → /execute  (unchanged)
                                          └─ multi-component → /execute-team
                                             (lead distributes contract slices
                                              → teammates build in parallel
                                              → contract diff + cross-review
                                              → lead runs e2e validation)
ALL rungs → /commit (only /commit closes issues)
ALL rungs → Level 1 hooks fire identically (ceremony shed, validation never)
```

The line to keep from Level 2 still holds: hooks check *conditions*, verifiers check *claims*. Level 3 adds: **ceremony is a dial, validation is not.**

## See it yourself (the walkthrough script)

1. **The ladder's bottom:** run `/chore fix a typo in transcription.md` (or any real nit). Watch: zero `gh` calls, zero plan files, zero subagents, a `chore:` handoff. Compare tool-call count against any `/execute` run — the PRD criterion is ≤25%.
2. **The flag gate (flag is currently unset in this repo — live-fire ready):** run `/execute-team .agents/plans/EXAMPLE.md`. It must stop at Step 1 with the message naming `/execute` as the fallback, spawning nothing.
3. **Status-only semantics:** `grep -n 'Phase' .claude/commands/hotfix.md` — the only hit is the line saying a hotfix *never* sets it. Then check `move-issue.sh` itself: it has no Phase parameter at all — the guarantee is structural, not prose.
4. **The red-repro gate:** run `/bug <N>` on a real open bug (or seed one). The fix must not start until a failing test / recorded repro exists — watch for the Step 1 → Step 2 boundary.
5. **The recommendation:** next `/plan-feature` run's report ends with "Recommended executor: …" derived from whether INTEGRATION CONTRACTS is populated.
6. **The port diff:** `diff <(cat ~/projects/nexus/.claude/skills/execute-team/SKILL.md) template/.claude/commands/execute-team.md` — see exactly what genericizing touched (repo refs, board calls, flag gate, display prose) and what it didn't (contracts, pitfalls).
7. **(Full-weight, when a real multi-component feature arrives):** set `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, feed `/execute-team` a contract-rich plan, watch the lead distribute slices and run the contract diff. The PRD's Phase 3 validation wants one real team build — it can land during Level 4–5 work if nothing multi-component is queued now.

## What to watch out for

- **Escalation discipline:** each light command names its escape hatch (`/chore`→`/bug`/`/plan-feature`, `/hotfix`→`/plan-hotfix`/`/bug`). The failure mode is a "chore" that quietly grows into a feature — the deviation rules say STOP, but the prose only works if you hold the line in review.
- **`/hotfix` will never create an issue.** If you want the work tracked, file the issue first (or accept an untracked fix). That's the design, not an oversight.
- **`/execute-team` is experimental-flagged:** the feature it rides can change under us (it already removed `TeamCreate`/`TeamDelete` between nexus's port and now). The flag gate + `/execute` fallback is the containment; if agent teams regress, the ladder still works minus its top rung.
- **One team per session, no nested teams** — don't run `/execute-team` from inside anything that already spawned a team.
- **Weight creep:** the temptation to add "just one verifier" to `/bug` or a plan file to `/hotfix`. The §9 design rule ("light variants spawn no subagents by design") exists so future edits have to argue with the doc first.
- **Muscle memory preserved:** all 9 pre-existing commands kept names and signatures; 7 are byte-identical, and `plan-feature`/`init-project` only gained lines.

## Interesting findings from the build

1. **Exact-count grep assertions shape prose.** Two first drafts failed their own VALIDATE lines: `chore.md` needed `chore:` on ≥2 lines (fixed by making the handoff heading carry the tag — arguably clearer anyway), and `hotfix.md` mentioned `move-issue.sh` twice where the plan asserted exactly 1 (a parenthetical reworded to "the script above"). Lesson: exact-count assertions are brittle against *legitimate* prose mentions — prefer ≥N when authoring future VALIDATE lines, unless exactness is the point.
2. **The dogfood loop closed mid-turn.** The moment sync copied the six files into `.claude/commands/`, this session's own command roster hot-reloaded — `/chore`, `/hotfix`, `/bug` became invocable in the very session that was still building them. The template's install-is-the-test property is even tighter than designed.
3. **The Level 2 contract bet paid off unchanged.** `/execute-team`'s Step 3 consumed the Integration Contracts section exactly as `/plan-feature` has emitted it since Level 2 — zero adjustment needed on either side. Landing the producer one level before the consumer (PRD decision #7) meant the port was mostly deletion.
4. **A single-component guard closed a real gap.** The plan's edge-case list ("a plan with no cross-component contracts handed to `/execute-team` should bounce to `/execute`") wasn't in the nexus source — teams there were always deliberate. One added sentence in Step 3 turned a silent misuse into a redirect.
5. **10 task verifiers + 1 truths verifier, all PASS on first try** — but the two grep failures in finding #1 were caught by the *builder's own* VALIDATE loop before verifiers ever ran. The layering (self-check → independent verifier → final truths sweep) triaged exactly as designed: cheap checks caught cheap mistakes, verifiers confirmed claims.

## Walkthrough log (2026-07-15, live)

1. **Flag gate, live fire (item 1).** Owner ran `/execute-team .agents/plans/EXAMPLE.md` with the flag unset. The command stopped at Step 1 with the exact fallback message naming `/execute` — before issue linking, before reading the plan, **zero agents spawned**. Both flag locations (environment, settings.json `env` block) verified empty. Bonus observation: EXAMPLE.md would also have been bounced by Step 3's single-component guard — two independent gates protected this run.
2. **The ladder's bottom (item 2).** Owner ran `/chore fix a typo in transcription.md`. Total ceremony: 5 tool calls (2 scans, 1 context read, 1 edit, 1 diff review), 0 GitHub calls, 0 plan files, 0 subagents, `docs:` handoff. Measured against the same session's Level 3 `/execute` run (~35 tool calls + 11 subagents): **~14% — well inside the PRD's ≤25% criterion.** The fix itself: a transcription stutter ("a a problem") on line 193.
3. **Status-only proof (item 3).** Two layers shown: the only `Phase` mention in hotfix.md is the prohibition itself (line 25), and `move-issue.sh` — the command's only board call — maps to four hardcoded Status option IDs with zero Phase references. The guarantee is structural: no argument or code path exists that could set Phase. Level 1's lesson (guarantees in code, prose explains) applied to Level 3.
4. **Red-repro gate (item 4): DEFERRED** — no real bug was open; seeding one felt like rubber-stamping. To be exercised on the first genuine `/bug` run; the gate prose was independently verified by the task verifier and truths verifier.
5. **Port diff (item 5).** Live diff of nexus source vs the port: exactly seven hunks — `name:` dropped, attribution + MIT, repo refs ×3 → sync tokens, board prose → `move-issue.sh`, the +15-line flag gate, the single-component bounce, display prose modernized. Contract machinery, quality bar, Definition of Done, and all 8 pitfalls byte-identical. What's *absent* from the diff was the demonstration: the port changed plumbing and safety rails, never how a team builds.
6. **Real team build (item 6): DEFERRED** by owner decision — waits for the first genuine multi-component feature rather than a toy (PRD Phase 3's "one multi-component feature built by an agent team" validation moves to that occasion). The wiring (flag gate, contract consumption, single-component bounce) was demonstrated via items 1 and 5.

**Sign-off:** owner declared the walkthrough sufficient (items 1, 2, 3, 5 live; 4 and 6 deferred with conditions above) — recorded 2026-07-15 as a comment on epic #16.
