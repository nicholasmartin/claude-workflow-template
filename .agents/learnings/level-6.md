# Level 6: The Ship Layer (`/merge` + `/pr`) — What Changed and Why

**Status:** implemented; walkthrough + sign-off pending (HARD GATE for Level 7)
**Commits:** (added at /commit)
**Diagram:** `level-6-diagram.mmd` (paste into mermaid.live)

## The gap this closes

Through Level 5, the system decided when work landed. `/execute-isolated`
auto-merged the worktree branch into master and deleted it in the same breath,
and `/commit` closed issues while the work existed only on the branch — an
ordering flaw found live in the Level 5 dogfood run (issue closed ≈2 minutes
before its code reached master; harmless only because nothing ever aborted in
that window). Worse: there was no PR path at all, so on client repos where the
owner cannot push to master, the workflow dead-ended at the finish line.

Level 6 splits the flow at the seam **"work committed on a branch" → "work
lands on the default branch"** and hands the crossing to the engineer, per
branch, at ship time. An earlier design (`SHIP_FLOW=merge|pr` in workflow.env)
was rejected: an install-time mode can't know what the *next* task needs.

**The governing invariant, now enforced everywhere: an issue closes only when
its work reaches the default branch.**

## What changed, file by file

### New: `template/.claude/commands/merge.md` — the local ending
Absorbs `/execute-isolated`'s old Step 7 choreography, plus: a
**branch-protection guard** before anything mutates (`gh api
repos/{o}/{r}/branches/<default> --jq .protected` — read-access-safe, covers
rulesets; fail-safe: API failure = assume protected → redirect to `/pr`),
close/Done/claim-release bookkeeping (this command IS the closing moment),
push, and **consent-gated cleanup with keep as the default** — branch deletion
stopped being a side effect.

### New: `template/.claude/commands/pr.md` — the remote ending
Ported from digi-tal's `/pr`: never merges, consent-only rebase, `--reviewer`/
`--draft`, `Closes #N` in the body. Adapted: default branch detected (no
hardcoded `main`), board → **In Review** via `move-issue.sh`, duplicate-PR
handled gracefully. Branch, worktree, and claim deliberately survive — review
feedback lands in place; stack follow-up work on top in the same worktree.

### New: `template/.claude/scripts/add-field-option.sh` — safe option minting
Single-select options are one atomic list; the API's only write is
whole-list-replace (omitted options are DELETED and their item values
cleared). This helper makes growth safe by construction: live read →
idempotent name check → append-only rebuild (existing ids re-sent verbatim) →
mutate → print id. First live run minted "Phase 7" (`07b5f671`); the
idempotency re-run returned the same id. Convention: raw options mutations
only on fresh empty boards (`/init-project`); populated boards use the UI or
this helper.

### Updated: `execute-isolated.md` — ends at the seam
Step 7 no longer merges/deletes; it reports state (branch committed, worktree
kept, issue open, claim held) and names the two endings. `/commit` inside the
worktree no longer closes (see below).

### Updated: `commit.md` — the closing gate
Post-commit issue section now checks `git branch --show-current` against the
default branch. On it: identical behavior to Level 5. Off it (incl. detached
HEAD): progress comment + AC checkoff only, then a pointer to `/merge`/`/pr`.
Escape hatch: `/commit --close`.

### Updated: `continue.md` — merged-PR reconcile (new Step 2)
Auto-gather gains a merged-PR probe (`gh pr list --head <br> --state merged`
per local branch — `[]`/exit 0 when none). For each merged branch: pull
default, board → Done + claim release (ALWAYS — GitHub's `Closes #N`
auto-close never touches the board), then **stack-aware GC**: a branch with
local descendants is never deleted — the exact `git rebase --onto
origin/<default> A B` command is offered instead; otherwise consent-gated
`git branch -D` (squash-merges defeat `-d`; the PR's MERGED state is the
authority), worktree removal first.

### Updated: plumbing + docs
- `move-issue.sh`: `"in review")` case + `{{STATUS_IN_REVIEW_ID}}`
- `workflow.env` + `sync-template.sh`: `STATUS_IN_REVIEW_ID=1faa23f0`
  (In Review was added manually in the UI — populated board), Phase 7 id
- `workflow.md`: §2 Status/Views, §5 lifecycle fork + invariant, §7 entries
  (2 new, 3 rewritten), §10 claim-release timing (claims now legitimately
  outlive `/execute-isolated`)
- `SKILL.md` lists, `init-project.md` (GraphQL Status options incl. In Review
  — fixing the false "UI-only" claims; automations remain genuinely UI-only),
  `hotfix.md` invariant wording, root `CLAUDE.md`, `README.md`,
  `AGENTIC-EVOLUTION.md` (protection-endpoint correction)

## How information flows now

BEFORE (Levels 4–5):
```
/execute-isolated: execute → /commit (CLOSES issue, on the branch!)
                 → ExitWorktree → merge --no-ff → delete worktree + branch
                 → release claim            [system decides landing; no PR path]
```

AFTER (Level 6):
```
/execute-isolated: execute → /commit (comments + AC only) → STOP at the seam
                                                             |
              ┌──────────────────────────────────────────────┴───────┐
              v                                                      v
   /merge (local ending)                                  /pr (remote ending)
   guard: default branch protected? ──yes──> use /pr      push branch, open PR
   merge --no-ff, push                                    Closes #N, board → In Review
   close issue, board → Done, release claim               branch/worktree/claim live on
   cleanup consent-gated (default: keep)                       |
                                                          reviewer merges (GitHub)
                                                               |
                                                          /continue reconcile:
                                                          pull, board → Done, release,
                                                          stack-aware branch GC
```

## See it yourself (the walkthrough script)

1. **Static proof:** `grep -c 'git merge --no-ff' .claude/commands/execute-isolated.md`
   → 0; `grep -ci 'never merge' .claude/commands/pr.md` → 2; `grep -c '\-\-close'
   .claude/commands/commit.md` → 2; `grep -c 'rebase --onto' .claude/commands/continue.md`
   → 1; `ls .claude/commands/*.md | wc -l` → 18.
2. **The seam:** run `/execute-isolated` on a small real plan → confirm it ends
   with the branch committed, worktree in `git worktree list`, issue open,
   claim label present.
3. **`/merge` ending:** `/merge` that branch → issue closed, board Done, claim
   gone, master pushed, branch still exists (decline deletion at the prompt).
4. **`/pr` ending + reconcile:** second small branch → `/pr` → board shows In
   Review (`gh project item-list`), PR has `Closes #N`. Squash-merge the PR in
   the GitHub UI (simulating the teammate). `/continue` → watch the probe print
   `MERGED:`, master pulled, board Done, claim released, `-D` offered.
5. **Stack protection:** before merging a PR for branch A, create branch B from
   A (`git checkout -b`), then squash-merge A's PR → `/continue` must NOT offer
   to delete A; it must print the filled-in `git rebase --onto origin/master A B`.
   Run it; re-run reconcile; now A is deletable.
6. **Protection guard:** add a temporary ruleset on master (Settings →
   Rules → restrict pushes), run `/merge` on any branch → it must stop with the
   `/pr` redirect BEFORE merging; remove the ruleset.
7. **Helper idempotency (already proven live in the build):**
   `./.claude/scripts/add-field-option.sh Phase "Phase 7"` → `07b5f671`, exit 0,
   no board change.

## What to watch out for

- **The options mutation is destructive-replace.** Never hand-write
  `updateProjectV2Field` with `singleSelectOptions` against a populated board.
  UI or `add-field-option.sh`, always. (The helper appends only — reordering
  stays in the UI.)
- **Squash-merge vs git:** after a squash, `git branch -d` refuses forever —
  that's git being honest, not broken. Reconcile deletes with `-D` because the
  PR's merged state is the real authority.
- **Claims now outlive `/execute-isolated` by design.** A PR-parked branch
  keeps its worktree and its `worktree:*` claim — `/continue`'s stale-claim
  heuristic (worktree missing = stale) still works precisely because the
  worktree stays alive.
- **`/merge`'s fail-safe direction:** offline/API failure = assume protected =
  redirect to `/pr`. The annoying failure mode is a false redirect; the
  dangerous one (landing unreviewed on a protected repo) is impossible.
- **`/commit --close`** exists for work that will never cross a ship step —
  use it consciously; it bypasses the invariant.
- **Escape hatch for a wrong `/merge`:** before pushing, `git reset --hard
  origin/<default>` unwinds the landing; the branch (kept by default!) still
  has everything.

## Interesting findings from the build

- **The documented protection endpoint was wrong.** The roadmap originally
  cited `.../branches/<default>/protection` — research showed it's admin-gated
  and returns 404 for non-admins, indistinguishable from "not protected", i.e.
  useless for exactly the users the guard protects. The branch object's
  `protected` boolean (Contents:read) covers classic protection AND rulesets
  (verified empirically against vercel/next.js).
- **`gh pr list --head <br> --state merged` returns `[]` with exit 0** when
  nothing matches — script-friendly; `gh pr view <br>` exits 1 instead. The
  probe uses the former.
- **No standalone `jq` needed:** `add-field-option.sh` builds its GraphQL
  options fragment inside a `gh --jq` expression on the live read — which also
  structurally guarantees the array can only come from the immediately
  preceding query.
- **In Review sits after Done in the option order** (manual UI add appends).
  Display-order only; drag it in the UI if it bothers you — never reorder via
  API on a populated board.

## Walkthrough log — appended live during the session

*(pending — steps recorded here with ✓ as demonstrated; owner sign-off
recorded as a comment on epic #34)*
