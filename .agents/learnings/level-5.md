# Level 5: Cross-Session Coordination — What Changed and Why

**Status:** built and verified; walkthrough + owner sign-off pending (HARD GATE — blocks Level 6)
**Commits:** this level's single commit (see epic #29); built inside worktree `level-5-cross-session-coordination` — itself the first traced `/execute-isolated` run
**Diagram:** `.agents/learnings/level-5-diagram.mmd` (paste into mermaid.live)

---

## The gap this closes

Level 4 gave sessions isolated *trees*; nothing coordinated their *work*. Two
terminals could `/continue`, see the same Ready issue, and both start it. Board
Status "In Progress" says someone is on an issue, never *which session* — and a
dead session's In Progress looks identical to a live one. AGENTIC-EVOLUTION.md
Level 5: make GitHub the shared blackboard and add a worktree-ownership
convention so "you become the router in Dan's factory diagram."

## What changed, file by file

### New: `template/.claude/scripts/claim-issue.sh` (~80 lines)

The claim/release plumbing. A claim is a **dynamic `worktree:<name>` label**:

- `claim-issue.sh <N> claim [<name>]` — creates the label idempotently
  (`gh label create --force` — labels must exist before `--add-label`, a
  verified gh gotcha), adds it, then **re-reads the issue**: if two `worktree:*`
  labels coexist, the later writer removes its own and exits 3
  (`CLAIM COLLISION`). GitHub has no compare-and-swap; check-after-write is the
  race guard. `<name>` auto-detects: worktree slug under `.claude/worktrees/`,
  else `main`.
- `claim-issue.sh <N> release` — removes every `worktree:*` label from the
  issue and deletes each label object no open issue still carries. The label
  list self-cleans; the taxonomy documents a *pattern*, not a fixed set.

### Updated: the ripple (workflow-skill lockstep)

- **Five executors** (`execute`, `execute-team`, `execute-isolated`, `hotfix`,
  `bug`): claim right after `move-issue.sh … "In Progress"`. `/execute-isolated`
  claims with its plan slug *before* entering the worktree, and releases in
  Step 7 (post-merge) and in Rollback. `/chore` untouched — no issue linkage.
- **`/commit`**: after every close (+ board→Done), releases the claim.
  Progress-comment-only issues keep their claims.
- **`/continue`**: gathers `git worktree list`; report table gains a **Claim**
  column; work-order rules 6–7 added — skip issues claimed by another session;
  surface stale claims and ask before clearing. Rules 1–5 unchanged.
- **`/status`**: gathers `git worktree list`; new **Session Claims** report
  block. Report-only — never clears.
- **`workflow.md`**: §4 gains the Worktree label row; §7 entries updated for all
  8 touched commands; new **§10 Coordination Layer (Cross-Session)** — the
  authoritative spec (blackboard model, claim lifecycle, collision rule, stale
  rule); old §10–12 renumbered §11–13, cross-refs swept.
- **`SKILL.md`**: plumbing checklist gains `claim-issue`; new guardrail — never
  change the claim convention without updating workflow.md §10.
- **Bug fix (found during build):** `board-state.sh` and `move-issue.sh` called
  `gh project item-list` with no `--limit` — the default is **30** and the board
  was at 28 items, one issue away from silent truncation (move-issue would have
  reported "not on board" for item #31+). Both now pass `--limit 200`.

## How information flows now

BEFORE (Level 4): isolation without coordination —

```
terminal A: /continue → board → picks #42 → works
terminal B: /continue → board → picks #42 → works   ← same issue, nobody knows
```

AFTER (Level 5): the board arbitrates —

```
terminal A: /execute-isolated plan-A → In Progress + claim worktree:plan-a on #42
terminal B: /continue → board-state.sh (labels included, zero extra calls)
            → sees #42 claimed by worktree:plan-a, not mine → skips → picks #57
terminal B: /hotfix 57 → claim worktree:hotfix-57 … collision? exit 3, back off
…
terminal A: /commit closes #42 → board Done + claim released + label GC'd
```

The blackboard works because `gh` hits the **remote** — worktrees isolate files,
never coordination state.

## See it yourself (the walkthrough script)

1. **Static proof:** `grep -c 'claim-issue.sh' .claude/commands/{execute,execute-team,execute-isolated,hotfix,bug,commit,continue}.md`
   → 1,1,≥3,1,1,1,1; `grep -c 'claim-issue.sh' .claude/commands/chore.md` → 0.
2. **The main event (PRD Phase 5 validation, 2–3 terminals on real issues):**
   terminal 1 runs `/execute-isolated` on a small real plan — watch the issue
   gain `worktree:<slug>` on GitHub; terminal 2 runs `/continue` — the report
   shows the claim, and the issue is not offered as next work; terminal 3
   (optional) `/hotfix` a different issue in a second worktree.
3. **Deliberate collision:** from the main tree, on the issue terminal 1 owns:
   `./.claude/scripts/claim-issue.sh <N> claim` → `CLAIM COLLISION … already
   claimed by worktree:<slug>`, exit 3; `gh issue view <N> --json labels` still
   shows exactly one `worktree:*` label.
4. **Stale-claim demo:** `git worktree remove` a claimed worktree (or simulate
   with a label for a nonexistent name), run `/continue` — the claim is flagged
   stale and you are asked before it's cleared.
5. **Release proof:** `/commit` closes the issue → `gh issue view <N> --json
   labels` shows no `worktree:*`; `gh label list | grep worktree:` shows the
   orphaned label object is gone.

## What to watch out for

- **Claims are advisory, not locks.** Nothing on GitHub *prevents* work on a
  claimed issue — the convention only works because every executor claims and
  `/continue` respects claims. A human bypassing both bypasses the system.
- **The collision window is real but small.** Two sessions claiming within the
  same seconds both get the label; the re-read makes the later one back off.
  Don't remove the verify step from claim-issue.sh.
- **Stale ≠ abandoned.** A claim whose worktree exists but whose session died is
  NOT flagged (the worktree is still listed). `git worktree list` + your memory
  of open terminals is the tiebreak; when unsure, ask before releasing.
- **`main` claims are honor-system.** Two main-checkout sessions can't be told
  apart — the convention assumes at most one executes at a time.
- **Label GC needs the issue closed.** Closed issues keep their labels
  harmlessly; GC only deletes the label *object* when no open issue carries it.
- **Template copies of scripts stay non-runnable** ({{PLACEHOLDER}} tokens);
  only the synced `.claude/scripts/` copies work. Sync before testing.

## Interesting findings from the build

1. **The worktree base was one commit behind reality.** Worktrees branch from
   `origin/HEAD`; Level 4's commit was unpushed, so this worktree materialized
   *without* `execute-isolated.md` — the very file the plan edits. Fix: local
   fast-forward (`git merge master`) inside the worktree before executing. The
   generalized lesson joined the watch-outs above: worktree base = the *remote*
   default branch; unpushed commits are as absent as uncommitted files.
2. **A one-item margin from silent truncation.** The missing `--limit` on
   `gh project item-list` (default 30, board at 28) was in the plan for
   `board-state.sh`; the same bug was found and fixed inline in `move-issue.sh`
   (deviation rule 1). Two more issues on the board and `move-issue.sh` would
   have started failing with "not on project board" for new items.
3. **The claim marker chose itself.** Labels ride along in `board-state.sh`'s
   existing output for both issues and board items — comments would have cost
   one extra `gh` call per issue. The one thing comments do better (server
   timestamps for ordering) is covered by the collision re-read.
4. **Live validation caught an eventual-consistency bug the plan missed.** The
   release-time label GC checked "any open issue still carrying this label?"
   *immediately* after removing it — and GitHub's list index still counted the
   just-released issue, so the orphaned label survived. Re-querying seconds
   later returned 0. Fix: a shared `gc_label` helper — settle delay with one
   retry (2s, then 3s), best-effort delete — used by both the release path and
   the collision backoff (which also leaked its freshly created label). GC is
   deliberately best-effort: under longer lag an orphaned label can survive
   (harmless; `gh label delete` cleans it, and it prints a note when it
   punts). The scouts' "board data is eventually consistent" warning was in
   the plan's research — it just bit on a different query than predicted.
   Postscript: the default-limit gotcha struck a *third* time during
   verification — `gh label list` also truncates at 30, and this repo's label
   list had just crossed it, hiding a surviving orphan. Every paginated `gh`
   list command needs an explicit `--limit`.

### Level 4's deferred observations — settled on this run

This build was itself the first traced `/execute-isolated` run (level-4.md
deferred these three findings to it):

1. **`EnterWorktree` branch-name format:** `worktree-<name>` — observed
   `worktree-level-5-cross-session-coordination`, tree at
   `.claude/worktrees/level-5-cross-session-coordination/`.
2. **`$CLAUDE_PROJECT_DIR` in-worktree:** *unset* in regular Bash tool calls;
   set for **hook invocations** — the settings.json hook commands'
   `"$CLAUDE_PROJECT_DIR"/…` prefix resolved and executed correctly from inside
   the worktree.
3. **Hooks fire in-worktree:** deliberately wrote a broken `.sh` in the
   worktree → PostToolUse `post-edit-lint.sh` fired with blocking syntax
   feedback within the same tool call; the Stop battery (`validate-local.sh`)
   also ran green in-worktree.

## Walkthrough log (2026-07-15, live, two terminals)

Performed live on real issue #33 (this level's own gate task), owner at
terminal 2, orchestrating session at terminal 1 in the main checkout:

1. **Static greps** — all seven issue-linked/lifecycle commands carry
   `claim-issue.sh` (execute 1, execute-team 1, execute-isolated 4, hotfix 1,
   bug 1, commit 1, continue 1); chore 0. ✓
2. **Multi-terminal claim awareness (PRD Phase 5 validation)** — terminal 1
   created worktree `walkthrough-demo` and claimed #33 for it; terminal 2's
   `/continue` showed the Claim column (`walkthrough-demo` on #33, `—` on
   #29), correctly judged the claim **not stale** (worktree present in
   `git worktree list`), and refused to take #33 without the owner's say-so —
   even adding its own judgment that the branch had no commits. ✓
3. **Deliberate collision** — terminal 1 (identity `main`) tried to claim the
   owned issue: `CLAIM COLLISION: issue #33 already claimed by
   worktree:walkthrough-demo`, exit 3, exactly one claim label retained. ✓
4. **Stale detection** — the worktree was removed out from under the claim;
   terminal 2's next `/continue` flagged the claim stale, cited the rule, and
   asked before clearing (rule 7 honored — no silent takeover). ✓
5. **Release + GC** — owner consented; terminal 2 released; verified from
   terminal 1: label off the issue, **zero** `worktree:*` label objects
   remaining (untruncated `--limit 200` check). ✓

Observed bonus: two sessions coordinating on the *same* gate task ended the
walkthrough with terminal 2 offering to claim #33 as `main` — the exact
scenario the convention arbitrates. Terminal 1 finished the gate; terminal 2
stood down.

Owner sign-off recorded as a comment on epic #29 — the gate's explicit logged
act. Level 6 planning may begin. (Next up per owner decision: Level 6 becomes
the PR-handoff ship layer; automated triage moves to Level 7.)
