# Level 4: Worktree Isolation — What Changed and Why

**Status:** complete — walkthrough performed by owner and sign-off recorded on epic #25 (2026-07-15); three live-observation findings deferred to the first traced run (see log)
**Commits:** learning-first ordering held (doc + walkthrough + sign-off preceded `/commit`), matching Level 3
**Diagram:** `.agents/learnings/level-4-diagram.mmd` (paste into mermaid.live)

---

## The gap this closes

Before Level 4, every executor — `/execute`, `/execute-team`, and the light variants — worked in the main working tree. Two sessions running at once collided on files; a failed run left the main tree dirty; throughput was bounded by one checkout. AGENTIC-EVOLUTION.md:48 named it plainly: *"Sandboxing. No worktree/isolation story."* Dan's framing (Level 4, line 135): worktrees are "a great place to start" — and for a solo dev on subscription, you never hit "the end."

The deliverable is **one new command** — `/execute-isolated <plan>` — that wraps the existing executors in a worktree envelope. Nothing else changed: no new hooks, no new scripts, no board schema, no labels (the `worktree:<name>` ownership convention is Level 5's, deliberately untouched).

## What changed, file by file

### New: `template/.claude/commands/execute-isolated.md` (~130 lines)

The envelope, in order:

| Step | What | Why it's there |
|---|---|---|
| 1 | **Worktree gate** — `EnterWorktree` unavailable → STOP, fallback `/execute <plan>` (≥2.1.208 recommended) | Same containment pattern as `/execute-team`'s flag gate; evolving primitives never strand a plan |
| 2 | **Read the plan BEFORE entering** | Worktrees branch from `origin/<default-branch>` by default — an uncommitted plan file does not exist inside. Re-created from context if missing |
| 3 | Issue → "In Progress" via `move-issue.sh`, never-close guard | Identical to `/execute` step 0 |
| 4 | `EnterWorktree` named after the plan slug; in-worktree pre-flight incl. self-healing `.gitignore` grep | Deterministic + resumable names; prefigures Level 5's ownership convention |
| 5 | **Executor choice by reference** — `/execute` steps 1–6 (default) or `/execute-team` from its Step 1, per the plan's recommendation; team flag unset → single-agent *in the same worktree* | The envelope is executor-agnostic; neither flow is duplicated — one source of truth each |
| 6 | `/commit` on the worktree branch | Board is shared state; the tree is not |
| 7 | `ExitWorktree (keep)` → merge `--no-ff` from the main checkout → `git worktree remove` + `git branch -d` | **ExitWorktree never merges; `remove` deletes the branch and the work.** Order is the safety-critical part |
| — | Rollback: `ExitWorktree (remove)`; refuses on unmerged work → user-confirmed `discard_changes` | Failed runs cost nothing; main tree untouched either way |

Frontmatter carries `disable-model-invocation: true` — relocating the session's working directory should never happen because the model auto-picked a command.

### Updated: the ripple (workflow-skill lockstep)

- `workflow.md` — §7 gains the `### /execute-isolated` entry (13 command entries); §9 gains the design rule: **worktree lifecycle is never delegated** — teammates/subagents never call `EnterWorktree`/`ExitWorktree` (subagents can't call `ExitWorktree` at all).
- `skills/workflow/SKILL.md` — both enumerations now list 16 command files.
- `init-project.md` — verification loop + "16 slash commands configured".
- Root `CLAUDE.md` — count line 15 → 16 (direct edit; sync never touches it).
- **New root `.gitignore`** — `.claude/worktrees/` (official docs tip; this repo had no .gitignore at all). Template users get the same protection from the command's self-healing pre-flight grep instead of a shipped file.
- **Not changed, deliberately:** labels/board schema (`worktree:` is Level 5); README's command table (already stale since Level 3 — separate docs chore); PRD §4 checkboxes (convention: the board tracks completion).

## How information flows now

```
BEFORE                                AFTER
one working tree                      main tree stays clean; work happens in throwaway checkouts
  └─ any executor mutates it            /execute-isolated plan-A.md   (terminal 1 → .claude/worktrees/plan-A)
     (parallel sessions collide;        /execute-isolated plan-B.md   (terminal 2 → .claude/worktrees/plan-B)
      failed runs leave dirt)                │ each: enter → executor flow → /commit on worktree branch
                                             │        → ExitWorktree(keep) → merge in main checkout (serialized)
                                             └─ failure? ExitWorktree(remove) — main tree never knew
GitHub board = the shared state across sessions (formalized in Level 5)
Level 1 hooks fire identically inside worktrees ($CLAUDE_PROJECT_DIR-relative, .claude/ is committed)
```

The Level 3 line still holds — ceremony is a dial, validation is not — and Level 4 adds: **the tree is a dial too; the merge is not.** Work only reaches master through an explicit, serialized merge step.

## See it yourself (the walkthrough script)

1. **The gate, static:** `grep -n 'not available' .claude/commands/execute-isolated.md` — the STOP text names `/execute <plan>` as fallback, same shape as `/execute-team`'s flag gate.
2. **The PRD Phase 4 validation (the main event):** two terminals, two small real plans (queue two genuine nits as micro-plans). `/execute-isolated` each. Watch: two directories under `.claude/worktrees/`, two branches, zero file conflicts, two clean `--no-ff` merges back on master, worktrees and branches gone afterward.
3. **The rollback:** start a third run, let it edit something, then abandon it — `ExitWorktree (remove)` must refuse (unmerged work) until confirmed with `discard_changes: true`; afterwards `git status` in the main tree is clean and the branch is gone.
4. **Settle the unverified facts** (record answers in Findings below):
   - actual branch name format of an `EnterWorktree` worktree (`git branch --show-current` inside)
   - `echo "$CLAUDE_PROJECT_DIR"` inside the worktree — worktree root or original repo root?
   - do the PostToolUse/Stop hooks fire inside the worktree? (make an edit; watch for lint feedback; end a turn)
5. **Base-ref gotcha, live:** write a throwaway plan file, do NOT commit it, run `/execute-isolated` on it — Step 2 must carry it in and re-create it inside the worktree.
6. **(Optional, flag-gated):** with `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` and a contract-rich plan, observe teammate file operations landing under the worktree path, not the main checkout. Best-effort observation, not a gate.

## What to watch out for

- **Never `remove` before merging.** `ExitWorktree (remove)` deletes the branch and everything on it. The command's Step 7 ordering (keep → merge → cleanup) is the guarantee; the rollback section is the only sanctioned use of `remove`.
- **Merges serialize in the main checkout.** Two sessions finishing simultaneously must take turns; the command says ask the user if unsure. This is the one shared bottleneck by design.
- **Worktrees start from `origin/HEAD`, not your dirty tree.** Uncommitted anything — plan files, half-done edits, gitignored `.env` files — is absent inside. Plan files are handled (Step 2); env files need `.worktreeinclude`; local commits need `worktree.baseRef: "head"` in settings.
- **Name reuse resumes.** Re-running a plan with the same slug re-enters the old worktree at its old tip if it had commits. Fresh run → suffixed name.
- **Session death inside a worktree:** clean → auto-removed; dirty → keep/remove prompt; headless `-p` runs → orphaned worktrees (`git worktree prune` cleans admin files).
- **`EnterWorktree`/`ExitWorktree` are evolving primitives** (behaviors verified against docs current at 2.1.210). If they change, the gate + `/execute` fallback keeps every plan executable in the main tree.

## Interesting findings from the build

1. **A verifier caught scope creep on a one-line edit.** The CLAUDE.md count-bump task said "only the count changes on that line"; the builder also slipped `execute-isolated` into the parenthetical example list. Task VALIDATE greps passed — the independent verifier FAILed it against VERIFY, and the line was reverted to plan. Smallest possible demonstration of why verifiers check *claims*, not just conditions.
2. **The external scout's "unverified facts" discipline earned its keep.** The design's safety-critical fact — ExitWorktree never merges, `remove` deletes work — came from the scout's verified-facts list (read directly from the tool schemas), while two plausible-sounding claims (branch-name format, `$CLAUDE_PROJECT_DIR`) stayed explicitly unverified and were deliberately kept off the command's load-bearing path. Nothing breaks whichever way they resolve at the walkthrough.
3. **The envelope went executor-agnostic mid-review.** The plan originally wrapped `/execute` only; an owner question ("what about `/execute-team`?") surfaced that the envelope doesn't care what fills its middle. One task edit added the choice, with the team path's flag gate *softened* in-worktree (fall back to single-agent in the same worktree, don't STOP) — isolation is preserved through the whole fallback chain: team → single-agent-in-worktree → `/execute` in the main tree.
4. **This repo had no `.gitignore` until Level 4.** Three levels of markdown+bash needed nothing ignorable; the first artifact worth ignoring was the worktree directory itself.

## Walkthrough log (2026-07-15)

Owner performed the walkthrough independently and declared it complete, then instructed `/commit` (sign-off recorded as a comment on epic #25 — the gate's explicit logged act).

**Honesty note, per this doc's own rules:** the walkthrough ran outside this session and left no traces in this repo's history at commit time (no worktree branches, no merge commits on master) — consistent with rollback-only exercising, but it means the script's item 4 observations were **not captured**:

- actual `EnterWorktree` branch-name format — *unrecorded*
- `$CLAUDE_PROJECT_DIR` resolution inside a worktree — *unrecorded*
- PostToolUse/Stop hooks firing in-worktree — *unrecorded*

Following Level 3's deferred-with-conditions precedent (its items 4 and 6): **these three findings are to be recorded here on the first traced `/execute-isolated` run** — the natural occasion is the first real Level 5 plan executed in a worktree, which will also serve as the PRD Phase 4 "two plans, clean merges" evidence if run in parallel.
