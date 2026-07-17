# Feature: Level 6 — Ship Layer (`/merge` + `/pr`)

The following plan should be complete, but its important that you validate documentation and codebase patterns and task sanity before you start implementing.

Pay special attention to naming of existing utils types and models. Import from the right files etc.

## Feature Description

Add the ship layer to the workflow template: landing work on the default branch becomes an explicit, per-branch, ship-time choice between two new endings — **`/merge`** (land locally: merge `--no-ff`, close issue, board → Done, release claim, push) and **`/pr`** (land remotely: push branch, open PR with `Closes #N`, board → **In Review**, someone else merges). `/execute-isolated` stops at the commit seam (no more auto merge/delete), `/commit` closes issues **only on the default branch**, and `/continue` gains a merged-PR reconcile step (pull, board Done, claim release, stack-aware branch GC). There is **no `SHIP_FLOW` flag** — this design was explicitly rejected (PRD §15 decision 9).

## User Story

As the owner (solo dev who also consults on multi-dev repos)
I want to choose merge-or-PR at ship time, per branch
So that the same workflow serves solo repos (merge, keep moving) and client repos where I can't merge PRs (PR, stack on top, reconcile later) — with no install-time mode deciding for me.

## Problem Statement

Today `/execute-isolated` auto-merges the worktree branch into master and deletes it in the same breath, and `/commit` closes issues while the work exists only on the branch (premature-close ordering flaw, found in the Level 5 dogfood run). There is no PR path at all: on repos where the owner cannot push to master, the workflow dead-ends. The system decides when work lands instead of the engineer.

## Solution Statement

Split the flow at the natural seam — *"work committed on a branch" → "work lands on the default branch."* Every isolated run ends at the seam; the engineer picks the ending. The governing invariant, enforced across all commands: **an issue closes only when its work reaches the default branch** (locally via `/merge`, or remotely via PR merge + `Closes #N`). Branch/worktree deletion becomes an explicit act (default: keep; `/continue` GCs merged branches with consent), never a side effect.

## Feature Metadata

**Feature Type**: New Capability (2 new commands) + Enhancement (4 command edits, 1 script edit, board schema)
**Estimated Complexity**: Medium-High
**Primary Systems Affected**: `template/.claude/commands/` (pr, merge, execute-isolated, commit, continue, init-project), `template/.claude/scripts/move-issue.sh`, board #18 schema, `workflow.md` §2/§5/§7/§10, sync plumbing
**Dependencies**: gh CLI ≥2.46 (already required); GitHub Projects v2 GraphQL (already used)

---

## CONTEXT REFERENCES

### Relevant Codebase Files IMPORTANT: YOU MUST READ THESE FILES BEFORE IMPLEMENTING!

- `AGENTIC-EVOLUTION.md` (lines 169–226) — Why: the authoritative Level 6 design; every deliverable below traces to it. NOTE: its protection-endpoint line is corrected by this plan (see Task 11 + NOTES).
- `.claude/PRD.md` (§7 Level 6, §15 decisions 8–10) — Why: scope + the rejected-flag decision; do not re-introduce a mode.
- `template/.claude/commands/execute-isolated.md` (lines 96–125 Step 6+7; line 56 close-invariant; lines 127–137 Notes) — Why: Step 7's merge/cleanup tail is what moves into `/merge`; Step 6 line 99 ("closes issues exactly as it always does") becomes false.
- `template/.claude/commands/commit.md` (lines 61–77 Post-Commit block) — Why: the close/Done/release choreography that gets gated behind a default-branch check.
- `template/.claude/commands/continue.md` (lines 5–12 auto-gather, 35–49 work order + stale-claim consent pattern) — Why: where the reconcile step slots in; lines 47–49 are the consent-gate model for branch GC.
- `~/projects/digi-tal/claude-workflow/.claude/commands/pr.md` (all 102 lines) — Why: the `/pr` port source (never-merges contract, consent-only rebase, preconditions, PR-BODY template).
- `template/.claude/scripts/move-issue.sh` (lines 10–23 usage + case block) — Why: gets the `"in review")` case + `{{STATUS_IN_REVIEW_ID}}`.
- `template/.claude/scripts/claim-issue.sh` (lines 74–94) — Why: exit-code contract (3 = collision) and `release` semantics `/merge` + reconcile call; no changes to the script itself.
- `scripts/sync-template.sh` (lines 36–56 sed list, 75–87 leak check) — Why: any new `{{TOKEN}}` must be added to the sed list or sync hard-fails.
- `scripts/workflow.env` — Why: `STATUS_IN_REVIEW_ID` lands here; `PHASE_OPTIONS` gains Phase 7.
- `template/.claude/workflow.md` (§2 lines 30–34 Status table; §5 lines 114–155 lifecycle; §7 lines 262–268 /execute-isolated, 297–301 /commit, 303–306 /continue; §10 lines 403–443 claims) — Why: every section that documents the changed behavior.
- `template/.claude/skills/workflow/SKILL.md` (lines 27–42 + 68–83 command lists; guardrails 154–163) — Why: the update-together checklist this plan satisfies; the skill file itself is on it.
- `template/.claude/commands/init-project.md` (lines 228–253 Step 4 fields; 480–488 + 573 the wrong "UI-only" claims; 548 count) — Why: In Review creation via GraphQL lands here and fixes the flagged dogfood bug (CLAUDE.md Notes).
- `template/.claude/commands/hotfix.md` (line 30) — Why: carries the "only /commit closes issues" sentence that must be reconciled.
- `.agents/plans/level-5-cross-session-coordination.md` — Why: task-format, VALIDATE-style, and learning-gate exemplar this plan mirrors.
- `.agents/learnings/level-5.md` (lines 170–201) — Why: walkthrough-log convention (dated numbered ✓ steps + sign-off comment on the epic).

### New Files to Create

- `template/.claude/commands/pr.md` — the `/pr` command (ported + adapted)
- `template/.claude/commands/merge.md` — the `/merge` command (new)
- `.agents/learnings/level-6.md` — learning doc (repo-only, HARD GATE)
- `.agents/learnings/level-6-diagram.mmd` — mermaid flow diagram (repo-only)

### Relevant Documentation YOU SHOULD READ THESE BEFORE IMPLEMENTING!

- [REST: Get a branch](https://docs.github.com/en/rest/branches/branches?apiVersion=2022-11-28#get-a-branch)
  - Specific section: response schema (`protected` boolean)
  - Why: THE protection check for `/merge` — needs only Contents:read; verified to reflect rulesets too. Do NOT use `.../protection` (admin-gated, ambiguous 404 for non-admins).
- [GraphQL: updateProjectV2Field](https://docs.github.com/en/graphql/reference/mutations#updateprojectv2field) + [ProjectV2SingleSelectFieldOptionInput](https://docs.github.com/en/graphql/reference/input-objects#projectv2singleselectfieldoptioninput)
  - Specific section: `singleSelectOptions` input
  - Why: **DESTRUCTIVE REPLACE** — the options array overwrites the whole list; every existing option must be re-sent WITH its `id` (else it is deleted and item values cleared). `color` + `description` required on every option.
- [gh pr create](https://cli.github.com/manual/gh_pr_create) / [gh pr view](https://cli.github.com/manual/gh_pr_view) / [gh pr list](https://cli.github.com/manual/gh_pr_list)
  - Why: `--reviewer` (comma-separated), `--draft`; `pr view <branch> --json state,mergedAt,mergeCommit` works after merge; `pr list --head <br> --state merged` returns `[]` exit 0 when none (script-friendly); duplicate PR → exit 1, stderr contains `already exists`.
- [git rebase --onto](https://git-scm.com/docs/git-rebase#Documentation/git-rebase.txt---ontoltnewbasegt)
  - Why: `git rebase --onto origin/<default> A B` replays exactly `A..B`; `A` must still resolve — delete A only after rebasing B.
- [git branch -d/-D](https://git-scm.com/docs/git-branch#Documentation/git-branch.txt--d) / [git worktree remove](https://git-scm.com/docs/git-worktree#Documentation/git-worktree.txt-remove)
  - Why: after squash-merge `-d` refuses ("not fully merged") — `-D` required, PR merged-state is the authority; a branch checked out in a worktree cannot be deleted — worktree removal first; dirty worktree remove → exit 128, needs `--force`.

### Patterns to Follow

**Frontmatter (new commands):** mirror `execute-isolated.md:1-5` — `description`, `argument-hint`, and `disable-model-invocation: true` for `/merge` (destructive local op; user-invoked only). `/pr` mirrors the source's frontmatter (`argument-hint: [--reviewer <handles>] [--draft]`).

**STOP conditions:** blockquote style from `execute-isolated.md:30-35`; collision phrasing from `execute-isolated.md:52-53` ("On `CLAIM COLLISION` (exit 3), STOP and tell the user…").

**Helper invocation:** always `./.claude/scripts/move-issue.sh <N> "In Review"` / `./.claude/scripts/claim-issue.sh <N> release` (never inline GraphQL choreography in commands).

**Placeholders:** `gh` calls in commands use `{{REPO_OWNER}}/{{REPO_NAME}}` (commit.md:65); new tokens must be added to BOTH `sync-template.sh` sed list AND `workflow.env`.

**Consent gates:** the stale-claim pattern (`continue.md:47-49`) — surface, never silently act, ask before destructive step. Branch deletion follows this everywhere.

**Default-branch detection (in commands):**
```bash
DEFAULT_BRANCH=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||') \
  || DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name)
# if symbolic-ref is unset and network is up: git remote set-head origin --auto (after a fetch)
```

**Protection check (non-admin safe, fail-safe to protected):**
```bash
PROTECTED=$(gh api "repos/{{REPO_OWNER}}/{{REPO_NAME}}/branches/$DEFAULT_BRANCH" --jq .protected) || PROTECTED=true
```

---

## INTEGRATION CONTRACTS

Single-component feature — no cross-component contracts. (One repo, one owner, markdown + bash; the "contract" is the close-invariant, enforced by prose in each command and documented once in workflow.md §5.)

---

## OBSERVABLE TRUTHS

- `/commit` run on a feature branch comments progress and checks off AC but leaves the issue **open** and the board **In Progress**, ending with a pointer to `/merge` / `/pr`; the identical flow on the default branch closes it (unchanged behavior).
- `/execute-isolated` ends after the commit step with the worktree and branch intact, the issue open, and the claim held — `git worktree list` still shows the worktree; the report names both endings.
- `/merge` on an unprotected repo: work appears on local master (`git log --merges -1` shows the `--no-ff` merge), issue closed, board Done, claim label gone, master pushed; the branch still exists unless the user opted to delete.
- `/merge` when the default branch is protected: stops BEFORE merging with a redirect to `/pr`; nothing merged, nothing closed.
- `/pr`: branch on origin, PR open with `Closes #N` in body, board shows **In Review**, worktree + branch alive.
- After the PR is squash-merged upstream: `/continue` reconciles — local master pulled, board Done, claim released, and the branch deleted via `-D` **only after** confirming no local branch descends from it; with a stacked descendant, it instead offers the exact `git rebase --onto origin/<default> A B` command.
- Board #18 Status field lists exactly 5 options (Backlog, Ready, In Progress, In Review, Done) with the four original option IDs unchanged, and no board item lost its Status value.
- `./.claude/scripts/add-field-option.sh Phase "Phase 7"` mints the option (Phase field → 7 options, original 6 IDs intact, no item loses its Phase); a second identical run prints the same ID and exits 0.
- `./.claude/scripts/move-issue.sh <N> "In Review"` succeeds on a board item.
- `ls .claude/commands/*.md | wc -l` → 18; `./.claude/hooks/validate-local.sh` → green.

## REQUIRED ARTIFACTS

- [ ] Board #18: "In Review" Status option (created manually in UI, ID captured read-only) + "Phase 7" Phase option (minted by `add-field-option.sh` in Task 12)
- [ ] `template/.claude/scripts/add-field-option.sh` — append-only read-modify-write helper for single-select options (idempotent)
- [ ] `scripts/workflow.env` — `STATUS_IN_REVIEW_ID`, `PHASE_OPTIONS` + Phase 7
- [ ] `scripts/sync-template.sh` — sed line for `{{STATUS_IN_REVIEW_ID}}`
- [ ] `template/.claude/scripts/move-issue.sh` — "in review" case + usage string
- [ ] `template/.claude/commands/pr.md` — ported `/pr`
- [ ] `template/.claude/commands/merge.md` — new `/merge`
- [ ] Updated `template/.claude/commands/execute-isolated.md` — ends at commit seam
- [ ] Updated `template/.claude/commands/commit.md` — default-branch-gated close (+ `--close` escape hatch)
- [ ] Updated `template/.claude/commands/continue.md` — merged-PR reconcile, stack-aware
- [ ] Updated `template/.claude/commands/init-project.md` — GraphQL Status-option creation incl. In Review; UI-only claims fixed; counts bumped
- [ ] Updated `template/.claude/commands/hotfix.md` — close-invariant sentence reconciled
- [ ] Updated `template/.claude/workflow.md` — §2, §5, §7 (2 new + 3 edited entries), §10
- [ ] Updated `template/.claude/skills/workflow/SKILL.md` — command lists include merge/pr
- [ ] Updated `CLAUDE.md` (root-only) — closing rule + command count
- [ ] Updated `README.md` — commands table + counts
- [ ] Updated `AGENTIC-EVOLUTION.md` — protection-endpoint correction
- [ ] Synced root `.claude/` (battery green)
- [ ] `.agents/learnings/level-6.md` + `level-6-diagram.mmd` + logged walkthrough + owner sign-off (HARD GATE)

## KEY LINKS

- PRD section: `.claude/PRD.md` §7 Level 6, §15 decisions 8–10
- Roadmap: `AGENTIC-EVOLUTION.md` lines 169–226
- GitHub issue: (created by /plan-feature — see epic)
- Port source: `~/projects/digi-tal/claude-workflow/.claude/commands/pr.md`

---

## IMPLEMENTATION PLAN

### Phase A: Board schema + plumbing (GitHub fields first, per SKILL.md order)

Board mutations, env, sync, move-issue.sh — everything commands depend on.

### Phase B: The two new commands

`/pr` port, then `/merge` (merge.md references pr.md's redirect target, so pr.md first).

### Phase C: Command integration

`/execute-isolated` trim, `/commit` gate, `/continue` reconcile.

### Phase D: Ripple + sync

workflow.md, SKILL.md, init-project.md, hotfix.md, CLAUDE.md, README.md, AGENTIC-EVOLUTION.md correction; sync + battery.

### Phase E: Learning gate (HARD GATE)

Learning doc + diagram + live walkthrough + owner sign-off.

---

## STEP-BY-STEP TASKS

IMPORTANT: Execute every task in order, top to bottom. Each task is atomic and independently testable.

### Task 1: RUN capture the "In Review" option ID (created manually in the UI — read-only)

- **IMPLEMENT**: The owner already added "In Review" to the Status field by hand (2026-07-17) — the safe path for a populated board. Verify and capture its ID: `gh api graphql -f query='query { node(id: "PVTSSF_lAHOAC3aXM4BdVs6zhX37pk") { ... on ProjectV2SingleSelectField { options { id name } } } }'`. Confirm 5 options with the original 4 ids (`5bc12968`, `99ecc1d7`, `0e4738bd`, `43f67a5a`) unchanged; record the In Review id for Task 2.
- **GOTCHA**: read-only — no mutation runs against the Status field in this plan. If "In Review" is missing, STOP and ask the owner to add it in the UI (do NOT fall back to `updateProjectV2Field` on this populated field).
- **VALIDATE**: the query above → 5 options, In Review present, original ids intact
- **VERIFY**: `gh project item-list 18 --owner @me --format json --limit 200 --jq '[.items[] | select(.status != null)] | length'` → unchanged from before (nothing lost a Status)
- **DONE**: In Review option ID recorded for Task 2

### Task 1b: CREATE template/.claude/scripts/add-field-option.sh (safe dynamic option creation)

- **IMPLEMENT**: New deterministic helper — the safe programmatic path for growing single-select fields on the fly (phases especially): `add-field-option.sh <field-name> <option-name> [--color COLOR] [--desc TEXT]` (color defaults GRAY, desc defaults ""). Flow, strictly read-modify-write: (1) resolve the field id + current options live via `gh project field-list {{PROJECT_NUMBER}} --owner @me --format json` + GraphQL node query for `options { id name color description }`; (2) **idempotency**: if `<option-name>` already exists, print its id and `exit 0`; (3) build the `singleSelectOptions` array from the *just-read* state — every existing option re-sent verbatim WITH its `id`, new option appended at the end (no id); (4) run `updateProjectV2Field`; (5) print the new option's id. Header comment: the destructive-replace warning + "options are ONLY ever appended; never reorder or rename here — use the UI for that." Standard conventions: `set -euo pipefail`, usage + `exit 1`, template-copy-not-runnable NOTE.
- **PATTERN**: arg/usage style `create-issue.sh:17-33`; runtime Phase-by-name resolution `create-issue.sh:73-80`; mutation shape in "Relevant Documentation"
- **GOTCHA**: `color` and `description` are REQUIRED on every re-sent option — read them back and pass verbatim (empty description is fine). The array must come from the immediate read, never from workflow.env or memory. Append-only: array order = display order, so appending is the only order-safe operation.
- **VALIDATE**: `bash -n template/.claude/scripts/add-field-option.sh && echo syntax-ok` → syntax-ok; `grep -c 'exit 0' template/.claude/scripts/add-field-option.sh` → ≥1 (idempotent path); `grep -c 'id name color description' template/.claude/scripts/add-field-option.sh` → ≥1; `grep -c '{{PROJECT_NUMBER}}' template/.claude/scripts/add-field-option.sh` → ≥1
- **VERIFY**: reading the script, no code path constructs the options array from anything but the immediately-preceding query; existing option `id`s always included
- **DONE**: script exists in template (live Phase-7 run happens in Task 12, after sync fills placeholders)

### Task 2: UPDATE scripts/workflow.env

- **IMPLEMENT**: Add `STATUS_IN_REVIEW_ID="<captured-id>"` (from Task 1) after line 13 (`STATUS_IN_PROGRESS_ID`). Phase 7 is appended to `PHASE_OPTIONS` later, in Task 12, after `add-field-option.sh` mints it.
- **PATTERN**: existing entries `scripts/workflow.env:11-14`
- **VALIDATE**: `grep -c 'STATUS_IN_REVIEW_ID' scripts/workflow.env` → 1
- **DONE**: env carries the In Review ID

### Task 3: UPDATE scripts/sync-template.sh

- **IMPLEMENT**: Add the `{{STATUS_IN_REVIEW_ID}}` sed replacement to the sed list (lines 38–56), alphabetically with the other STATUS lines.
- **GOTCHA**: skipping this makes the sync's leak check (lines 75–86) hard-fail the moment move-issue.sh gains the token.
- **VALIDATE**: `bash -n scripts/sync-template.sh && echo syntax-ok` → syntax-ok; `grep -c 'STATUS_IN_REVIEW_ID' scripts/sync-template.sh` → ≥1
- **DONE**: sync fills the new token

### Task 4: UPDATE template/.claude/scripts/move-issue.sh

- **IMPLEMENT**: Add `"in review") OPT="{{STATUS_IN_REVIEW_ID}}" ;;` to the case block (lines 17–23); extend the usage string (line 11) to `<Backlog|Ready|"In Progress"|"In Review"|Done>`.
- **PATTERN**: existing case arms `move-issue.sh:18-21`
- **VALIDATE**: `bash -n template/.claude/scripts/move-issue.sh && echo syntax-ok` → syntax-ok; `grep -c 'STATUS_IN_REVIEW_ID' template/.claude/scripts/move-issue.sh` → 1; `grep -c 'In Review' template/.claude/scripts/move-issue.sh` → ≥2
- **DONE**: script routes "In Review"

### Task 5: CREATE template/.claude/commands/pr.md

- **IMPLEMENT**: Port `~/projects/digi-tal/claude-workflow/.claude/commands/pr.md` with these adaptations: (1) frontmatter `argument-hint: [--reviewer <handles>] [--draft]`; (2) replace `.claude/harness/workflow.md` refs with `.claude/workflow.md`; (3) parameterize `main` → detected default branch (pattern above); (4) Step 6 board update: replace the `board_item_id`-frontmatter mechanism with this repo's — derive issue number from the plan file's issue reference or ask the user (mirror `execute.md:16`), then `./.claude/scripts/move-issue.sh <N> "In Review"` and comment the PR URL on the issue; (5) add `--reviewer` passthrough to `gh pr create` (comma-separated handles); (6) keep verbatim: preconditions (not on default branch / tree clean / commits ahead), consent-only rebase, PR-BODY template with `## Summary`/`## Testing`/`Closes #<issue>`, "never invoke the merge subcommand", "What this command does NOT do"; (7) add note: worktree + branch stay alive for review feedback; claim label stays held until reconcile; (8) duplicate-PR handling: `gh pr create` exit 1 with `already exists` in stderr → report the existing PR URL, offer `gh pr view --web`, do not error out.
- **PATTERN**: STOP blockquote `execute-isolated.md:30-35`; `{{REPO_OWNER}}/{{REPO_NAME}}` in gh calls `commit.md:65`
- **GOTCHA**: never `gh pr merge` — the never-merges contract is the command's identity. `gh pr list --head` does not support `owner:branch` syntax (same-repo only — fine here).
- **VALIDATE**: `test -f template/.claude/commands/pr.md && grep -ci 'never merge' template/.claude/commands/pr.md` → ≥2; `grep -c 'In Review' template/.claude/commands/pr.md` → ≥2; `grep -c 'Closes #' template/.claude/commands/pr.md` → ≥2; `grep -c 'move-issue.sh' template/.claude/commands/pr.md` → ≥1; `grep -c 'harness' template/.claude/commands/pr.md` → 0; `grep -c '\-\-reviewer' template/.claude/commands/pr.md` → ≥2; `awk '/^`````/{n++} END{print n+0}' template/.claude/commands/pr.md` → 0
- **VERIFY**: reading the file top-to-bottom, every gh call uses `{{REPO_OWNER}}/{{REPO_NAME}}` or repo-inferred context; no `main` hardcoded as a branch name
- **DONE**: `/pr` exists, adapted to this repo's conventions

### Task 6: CREATE template/.claude/commands/merge.md

- **IMPLEMENT**: New command, frontmatter `description: Land the current feature branch on the default branch locally`, `argument-hint: []`, `disable-model-invocation: true`. Steps: **(1) Preconditions** — current branch is NOT the default branch (else STOP: "nothing to land"); branch has commits ahead; working tree clean (else point at `/commit`). **(2) Protection guard** — detect default branch, then `PROTECTED=$(gh api "repos/{{REPO_OWNER}}/{{REPO_NAME}}/branches/$DEFAULT_BRANCH" --jq .protected) || PROTECTED=true` (fail-safe: API/network failure = assume protected); if `true`, STOP: "The default branch is protected — this repo lands work via pull requests. Run `/pr` instead." **(3) Exit worktree if inside one** — `ExitWorktree` with `action: "keep"` (never remove before merging); skip if not in a worktree. **(4) Safety in main checkout** — `git status --porcelain` clean; no other session mid-merge (two parallel sessions serialize their merges — ask the user if unsure; mirror old execute-isolated Step 7 wording). **(5) Land** — `git merge --no-ff <branch>`; on conflict STOP and hand to the user (never auto-resolve). **(6) Close bookkeeping** — the issue(s) this branch implements (from plan file or ask, mirror `execute.md:16`): comment landing commit hash, check off AC, `gh issue close <N> ... "Landed on <default> in <hash>."`, `./.claude/scripts/move-issue.sh <N> Done`, `./.claude/scripts/claim-issue.sh <N> release`. **(7) Push** — `git push origin $DEFAULT_BRANCH`; if rejected (non-fast-forward or policy), report and leave local state intact. **(8) Cleanup — explicit, default KEEP** — ask: "Delete the worktree and branch now? (default: keep — `/continue` offers GC of merged branches later)". Only on explicit yes: `git worktree remove .claude/worktrees/<name>` THEN `git branch -d <branch>` (worktree first — a branch checked out in a worktree cannot be deleted).
- **PATTERN**: old Step 7 choreography `execute-isolated.md:102-118` (this command absorbs it); consent gate `continue.md:47-49`
- **GOTCHA**: order in step 8 matters (worktree remove before branch delete, exit 128 if dirty → surface, don't `--force` silently). Step 6 close semantics are legitimate here — this command IS the work-reaches-default-branch moment.
- **VALIDATE**: `test -f template/.claude/commands/merge.md && grep -c 'disable-model-invocation: true' template/.claude/commands/merge.md` → 1; `grep -c '\.protected' template/.claude/commands/merge.md` → ≥1; `grep -c 'no-ff' template/.claude/commands/merge.md` → ≥1; `grep -c 'move-issue.sh' template/.claude/commands/merge.md` → ≥1; `grep -c 'claim-issue.sh' template/.claude/commands/merge.md` → ≥1; `grep -ci 'default.*keep\|keep.*default' template/.claude/commands/merge.md` → ≥1; `grep -c '/pr' template/.claude/commands/merge.md` → ≥2; `awk '/^`````/{n++} END{print n+0}' template/.claude/commands/merge.md` → 0
- **VERIFY**: the protection guard appears BEFORE the merge step; deletion is question-gated with keep as default; `gh pr merge` appears nowhere
- **DONE**: `/merge` exists with guard, landing, bookkeeping, explicit cleanup

### Task 7: UPDATE template/.claude/commands/execute-isolated.md

- **IMPLEMENT**: (1) Step 6 (lines 96–99): rewrite — `/commit` on the worktree branch now comments progress and checks AC but does NOT close (default-branch rule); state that explicitly. (2) Step 7 (lines 102–118): REPLACE the exit/merge/cleanup choreography with a short "Step 7: Report the seam" — summarize state (branch, worktree kept, issue open, claim held) and present the two endings: "`/merge` to land locally, `/pr` to open a pull request." The command ends here. (3) Line 56 invariant sentence → "Never close issues or move them to Done here — closing happens at the ship step (`/merge`, or PR merge via `Closes #N`)." (4) Rollback section: unchanged (abandon still releases the claim). (5) Notes: line 133 "`ExitWorktree` never merges anything — merge-back is always the explicit Step 7" → "…merging is always an explicit `/merge` (or `/pr` + upstream merge)"; keep the §10 coordination xref.
- **PATTERN**: current file, read in full first
- **GOTCHA**: do NOT remove the claim-release from the Rollback path — abandoning a run must still release. The claim now outlives the command in the success path (released by `/merge` or reconcile) — this is intentional; workflow.md §10 documents it (Task 10).
- **VALIDATE**: `grep -c 'git merge --no-ff' template/.claude/commands/execute-isolated.md` → 0; `grep -c 'git branch -d' template/.claude/commands/execute-isolated.md` → 0; `grep -c '/merge' template/.claude/commands/execute-isolated.md` → ≥2; `grep -c '/pr' template/.claude/commands/execute-isolated.md` → ≥2; `grep -c 'EnterWorktree' template/.claude/commands/execute-isolated.md` → ≥3 (entry flow untouched); `grep -c 'release' template/.claude/commands/execute-isolated.md` → ≥1 (rollback keeps it)
- **VERIFY**: no merge/cleanup choreography remains anywhere in the file; the two endings are named in Step 7
- **DONE**: command ends at the commit seam

### Task 8: UPDATE template/.claude/commands/commit.md

- **IMPLEMENT**: Wrap the Post-Commit close block (lines 61–77) in a default-branch gate. Before step 2's close actions: detect default branch + `CUR=$(git branch --show-current)`. If `CUR` == default: current behavior verbatim (close, Done, release, sub-issues). If not: comment progress + check off satisfied AC as today, but do NOT close / move Done / release; end the command's report with: "On branch `<CUR>` — issue #N stays open until this lands on `<default>`. Ship it with `/merge` or `/pr`." Add `--close` escape hatch: `/commit --close` skips the gate (explicit user override, documented in one line). Sub-issue closing (lines 72–76) obeys the same gate.
- **PATTERN**: default-branch detection snippet (Patterns to Follow); existing block structure `commit.md:61-77`
- **GOTCHA**: the gate must NOT change staging/scan/commit behavior — only the post-commit issue section. Detached HEAD (`CUR` empty) → treat as non-default (don't close).
- **VALIDATE**: `grep -c 'branch --show-current' template/.claude/commands/commit.md` → ≥1; `grep -c '\-\-close' template/.claude/commands/commit.md` → ≥2; `grep -c '/merge' template/.claude/commands/commit.md` → ≥1; `grep -c '/pr' template/.claude/commands/commit.md` → ≥1; `grep -c 'issue close' template/.claude/commands/commit.md` → ≥1 (close path retained for default branch)
- **VERIFY**: reading the block, the default-branch path is byte-equivalent in behavior to today's; the branch path can never reach `gh issue close` without `--close`
- **DONE**: close is default-branch-gated with escape hatch

### Task 9: UPDATE template/.claude/commands/continue.md

- **IMPLEMENT**: (1) Extend Step 1 auto-gather (line 11) with a merged-PR probe:
  ```bash
  for BR in $(git for-each-ref --format='%(refname:short)' refs/heads/); do [ "$BR" = "$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')" ] && continue; echo "== $BR"; gh pr list --head "$BR" --state merged --json number,mergedAt,mergeCommit --jq '.[0]'; done
  ```
  (`[]`/empty output = nothing merged; exit 0 — script-friendly). (2) New **Step 2: Reconcile shipped work** (renumber current 2→3, 3→4): for each local branch whose PR is MERGED — (a) `git checkout <default> && git pull`; (b) if the linked issue is open (Closes #N may have already closed it): close-with-comment, then `./.claude/scripts/move-issue.sh <N> Done` and `./.claude/scripts/claim-issue.sh <N> release` (always run these two — GitHub's auto-close never moves the board); (c) **stack check**: `git branch --contains <BR> | grep -v "^[* ] $BR$"` — if any other branch contains BR's tip, it descends from it: do NOT delete; offer `git rebase --onto origin/<default> <BR> <descendant>` (exact command, filled in); (d) otherwise offer deletion with consent (model: stale-claim pattern, lines 47–49): `git worktree remove <path>` if a worktree has it checked out, THEN `git branch -D <BR>` (`-D` required — squash-merge defeats `-d`; the PR's MERGED state is the authority). (3) Also update the Step 2 report table: add a "PR" column (open PR = In Review, merged = reconcile pending).
- **PATTERN**: consent gate `continue.md:47-49`; inline `!` auto-gather `continue.md:5-12`
- **GOTCHA**: never delete a branch another branch descends from (strands the stack). `git branch --contains` lists BR itself — exclude it. Board Done + claim release must run even when GitHub already closed the issue via `Closes #N`.
- **VALIDATE**: `grep -c 'state merged' template/.claude/commands/continue.md` → ≥1; `grep -c 'rebase --onto' template/.claude/commands/continue.md` → ≥1; `grep -c 'branch -D' template/.claude/commands/continue.md` → ≥1; `grep -c 'branch --contains' template/.claude/commands/continue.md` → ≥1; `grep -c 'move-issue.sh' template/.claude/commands/continue.md` → ≥1; `grep -c 'claim-issue.sh' template/.claude/commands/continue.md` → ≥2 (stale-claim + reconcile)
- **VERIFY**: the reconcile path cannot reach `git branch -D` without either the descendant check passing or user consent
- **DONE**: `/continue` reconciles merged PRs, stack-aware

### Task 10: UPDATE template/.claude/workflow.md

- **IMPLEMENT**: (1) §2 Status table (line 32): add In Review between In Progress and Done, with meaning "PR open, awaiting review". (2) §5 lifecycle (lines 114–155): document the seam + fork — commit-on-branch never closes; `/merge` = local landing (close/Done/release/push); `/pr` = remote landing (In Review; `Closes #N` fires on merge; `/continue` reconciles board Done + claim release + branch GC). State the invariant verbatim: "An issue closes only when its work reaches the default branch." Fix the line-143 "Board auto-updates to Done via automation" claim to match §7's explicit-move reality. (3) §7: add `/merge` and `/pr` entries (same format as neighbors); edit `/execute-isolated` (lines 262–268: ends at seam), `/commit` (297–301: default-branch gate + `--close`), `/continue` (303–306: reconcile step). (4) §10 (lines 423–427 Release paragraph): rewrite — "`/commit` releases claims on issues it closes (default branch only); `/merge` releases after landing; `/continue` reconcile releases on merged PRs; `/execute-isolated` holds the claim at its end (released by the ship step) and releases only on rollback/abandon."
- **PATTERN**: §7 entry format — mirror the `/execute-isolated` entry structure
- **GOTCHA**: SKILL.md guardrails — a board field change MUST land in §2 and a claim-timing change MUST land in §10 in the same change as the commands (this task is the lockstep).
- **VALIDATE**: `grep -c 'In Review' template/.claude/workflow.md` → ≥3; `grep -c '/merge' template/.claude/workflow.md` → ≥3; `grep -c 'reaches the default branch' template/.claude/workflow.md` → ≥1; `grep -c 'rebase --onto' template/.claude/workflow.md` → ≥1
- **DONE**: workflow.md documents the ship layer end-to-end

### Task 11: UPDATE remaining docs (SKILL.md, init-project.md, hotfix.md, CLAUDE.md, README.md, AGENTIC-EVOLUTION.md)

- **IMPLEMENT**: (1) `SKILL.md`: add `merge.md` + `pr.md` to both command lists (lines 27–42, 68–83) and `add-field-option.sh` to the scripts line (line 87). (2) `init-project.md`: in Step 4 (lines 228–253) add GraphQL creation of Status options **including In Review** via `updateProjectV2Field` — safe there because `/init-project` targets a freshly created, EMPTY board (destructive replace can't destroy values that don't exist yet); fix the false "UI-only" claims at lines 480–488/573 (CLAUDE.md-flagged dogfood bug) and add the convention: **on a board that already has items, never run the options mutation — add options in the UI or via `./.claude/scripts/add-field-option.sh` (append-only, read-modify-write)**; capture `STATUS_IN_REVIEW_ID` with the other IDs; bump "16 slash commands" (line 548) → 18 and add `/merge`+`/pr` to the Ready-to-Use list (560–567). NOTE: this file is copied verbatim by sync — its braces stay literal. (3) `hotfix.md` line 30: reconcile the close-invariant sentence (hotfix works on the default branch → `/commit` still closes there; say so). (4) Root `CLAUDE.md` (NOT synced — edit directly): rewrite "Only `/commit` closes issues" (Issue Tracking section) → "Issues close only at the ship step: `/commit` on the default branch, `/merge`, or a merged PR (`Closes #N`). Never close during implementation."; bump "16 slash commands" → 18. (5) `README.md`: add `/merge` + `/pr` rows to the commands table (lines 69–80). (6) `AGENTIC-EVOLUTION.md` line ~200: correct the protection-check reference from `gh api .../branches/<default>/protection` to `gh api repos/{o}/{r}/branches/<default> --jq .protected` (the `/protection` endpoint is admin-gated and 404s ambiguously for non-admins).
- **GOTCHA**: CLAUDE.md, README.md, AGENTIC-EVOLUTION.md are root-only (sync never touches them). Everything else in this task lives under `template/`.
- **VALIDATE**: `grep -c 'merge.md' template/.claude/skills/workflow/SKILL.md` → ≥2; `grep -c 'pr.md' template/.claude/skills/workflow/SKILL.md` → ≥2; `grep -c 'In Review' template/.claude/commands/init-project.md` → ≥1; `grep -c '18 slash commands' template/.claude/commands/init-project.md` → ≥1; `grep -c '/merge' README.md` → ≥1; `grep -c 'only /commit closes' CLAUDE.md` → 0; `grep -c '.protected' AGENTIC-EVOLUTION.md` → ≥1
- **DONE**: every doc consistent with the new close rule and 18 commands

### Task 12: RUN sync + Phase 7 mint + full battery (closer)

- **IMPLEMENT**: (1) `./scripts/sync-template.sh` (fills placeholders, makes root scripts runnable). (2) **Live first run of the new helper**: `./.claude/scripts/add-field-option.sh Phase "Phase 7" --desc "Level 7: automated triage"` → capture the printed option id; run it a second time to prove idempotency (same id, exit 0). (3) Append `Phase 7: \`<id>\`` to `PHASE_OPTIONS` in `scripts/workflow.env`, re-run `./scripts/sync-template.sh`. (4) Full battery; confirm git status lists exactly the expected new/modified files.
- **GOTCHA**: the Phase-7 run mutates live board #18 via the script's read-modify-append — this is the script earning its keep; verify Phase options read back as 7 with the original 6 ids intact before proceeding.
- **VALIDATE**: `./scripts/sync-template.sh` → "OK: template synced, all placeholders resolved."; `./.claude/hooks/validate-local.sh && echo battery-green` → battery-green; `ls .claude/commands/*.md | wc -l` → 18; `grep -rn '{{' .claude/commands/merge.md .claude/commands/pr.md .claude/scripts/move-issue.sh .claude/scripts/add-field-option.sh` → no output; `test -x .claude/scripts/add-field-option.sh && echo exec-ok` → exec-ok; Phase field read-back → 7 options, original 6 ids unchanged; `gh project item-list 18 --owner @me --format json --limit 200 --jq '[.items[] | select(.phase != null)] | length'` → unchanged; `./.claude/scripts/move-issue.sh <this-epic-number> "In Review" && ./.claude/scripts/move-issue.sh <this-epic-number> "In Progress"` → both succeed (live smoke test, restores state)
- **DONE**: root installation regenerated, Phase 7 minted by the helper (idempotency proven), battery green, In Review routable

### Task 13: CREATE .agents/learnings/level-6.md + level-6-diagram.mmd + walkthrough (HARD GATE)

- **IMPLEMENT**: Learning doc per convention (`level-5.md` skeleton): gap closed / what changed file-by-file / how information flows now (BEFORE: commit closes → auto-merge → delete; AFTER: seam → choose ending → close-at-landing) / see-it-yourself script / watch-out-fors (destructive board mutation, squash vs `-d`, stack stranding, `--close` hatch) / walkthrough log appended live. Diagram: `flowchart TD` with the seam as the central decision node, two ending subgraphs (`/merge` local, `/pr` remote + reconcile). **Walkthrough script (executed live with the owner):** (1) static greps — the Task 5–11 VALIDATE set, sampled; (2) `/execute-isolated` a small real chore plan → verify it ends at the seam (worktree alive, issue open, claim held); (3) `/merge` it → issue closed, board Done, claim gone, master pushed, branch kept (decline deletion); (4) second small branch → `/pr` against this repo → board In Review; squash-merge the PR in the GitHub UI (simulating the teammate); `/continue` → watch reconcile pull master, set Done, release claim, offer `-D`; (5) stack demo: branch B from branch A before A's PR merges; after squash-merge, `/continue` must protect B and print the `--onto` command; run it; (6) protection-guard demo: add a temporary ruleset on master (or use a known protected repo read-only), `/merge` → redirect to `/pr`; remove the ruleset. Owner sign-off recorded as a comment on the Level 6 epic.
- **PATTERN**: `.agents/learnings/level-5.md` (sections + dated ✓ log); `level-4-diagram.mmd` header style
- **VALIDATE**: `test -f .agents/learnings/level-6.md && grep -c '^## ' .agents/learnings/level-6.md` → ≥6; `test -f .agents/learnings/level-6-diagram.mmd && echo ok` → ok
- **VERIFY**: walkthrough log has dated, numbered ✓ steps including one live `/merge`, one live `/pr`+reconcile, the stack protection, and the guard redirect
- **DONE**: doc + diagram exist; walkthrough performed; owner sign-off recorded on the epic (HARD GATE — Level 7 planning blocked until then)

---

## TESTING STRATEGY

### Unit Tests

None (no test framework). Per-task structural greps with expected counts + `bash -n` on every touched script are the unit tier (see each task's VALIDATE).

### Integration Tests

`./scripts/sync-template.sh` + `./.claude/hooks/validate-local.sh` (placeholder leak, sync drift, shell syntax, root-only leak). Live smoke: `move-issue.sh <N> "In Review"` round-trip (Task 12).

### Edge Cases

- Detached HEAD at `/commit` → treated as non-default branch (no close)
- Protection API unreachable (offline) → `/merge` fail-safes to "assume protected"
- Duplicate PR for branch → `/pr` reports existing URL, exit gracefully
- Squash-merged branch: `-d` refuses → reconcile uses `-D` with PR-merged authority
- Stacked descendant branch present → reconcile never deletes, offers `--onto`
- Branch checked out in a worktree → worktree removal before branch deletion
- Issue already closed by `Closes #N` → reconcile still moves board Done + releases claim

---

## VALIDATION COMMANDS

Execute every command to ensure zero regressions and 100% feature correctness.

### Level 1: Syntax & Style

```bash
for f in scripts/*.sh template/.claude/hooks/*.sh template/.claude/scripts/*.sh; do bash -n "$f" || echo "FAIL: $f"; done
awk '/^`````/{n++} END{print n+0}' template/.claude/commands/merge.md template/.claude/commands/pr.md
```

### Level 2: Unit (structural greps)

The per-task VALIDATE blocks above, in order.

### Level 3: Integration

```bash
./scripts/sync-template.sh          # → OK: template synced, all placeholders resolved.
./.claude/hooks/validate-local.sh && echo battery-green
ls .claude/commands/*.md | wc -l    # → 18
```

### Level 4: Manual Validation

The Task 13 walkthrough script (live, with owner): seam → `/merge` ending → `/pr` ending + reconcile → stack protection → guard redirect.

---

## ACCEPTANCE CRITERIA

- [ ] Board #18 has "In Review" (Status, added manually) and "Phase 7" (Phase, minted by `add-field-option.sh`) options; all pre-existing option IDs and item values intact
- [ ] `add-field-option.sh` is append-only read-modify-write, idempotent, and never builds the options array from anything but a live read
- [ ] `/pr` opens a PR with `Closes #N`, sets board In Review, never merges; branch + worktree survive
- [ ] `/merge` lands via `--no-ff`, closes issue + Done + releases claim + pushes; deletion is consent-gated, default keep
- [ ] `/merge` stops and redirects to `/pr` when the default branch is protected (fail-safe on API error)
- [ ] `/execute-isolated` ends at the commit seam with claim held; no merge/cleanup choreography remains
- [ ] `/commit` on a non-default branch never closes issues (without `--close`); unchanged on the default branch
- [ ] `/continue` reconciles merged PRs (pull, Done, release, `-D`) and protects stacked descendants (offers `--onto`)
- [ ] workflow.md §2/§5/§7/§10, SKILL.md, init-project.md (incl. UI-only-claim fix), hotfix.md, CLAUDE.md, README.md all consistent; command count 18 everywhere it's stated
- [ ] Sync battery green; no placeholder leaks
- [ ] Learning doc + diagram + live walkthrough + owner sign-off on the epic (HARD GATE)

## COMPLETION CHECKLIST

- [ ] All tasks completed in order
- [ ] Each task validation passed immediately
- [ ] All validation commands executed successfully
- [ ] Full battery passes (validate-local.sh)
- [ ] Manual walkthrough confirms both endings + reconcile + guard
- [ ] Acceptance criteria all met
- [ ] Owner sign-off recorded (gate to Level 7)

---

## NOTES

- **Executor: `/execute` in the MAIN TREE — deliberately not `/execute-isolated`.** Rationale: (1) this plan rewrites `/execute-isolated`'s own ending — executing it inside that command means finishing under instructions the plan just changed; (2) Task 1 mutates live board state and Task 12 runs a live smoke test — worktree isolation isolates nothing here; (3) single-component plan, no INTEGRATION CONTRACTS → not an `/execute-team` candidate.
- **High-stakes acknowledgment + the options convention (owner decision, 2026-07-17):** board field structure changes are high-stakes (CLAUDE.md). Resolution: **"In Review" was added manually in the UI** (the safe path for a populated board — mid-list placement, zero mutation risk); the plan only reads its ID. **Phase options are dynamic by design** (`create-issue.sh` already resolves them by name at runtime) — the new `add-field-option.sh` makes *creating* them safe too: deterministic read-modify-append, idempotent, existing IDs always preserved. Convention going forward: raw `updateProjectV2Field` options mutations only on fresh empty boards (`/init-project`); populated boards use the UI or the helper. Agents never hand-build a `singleSelectOptions` array.
- **Design provenance:** finalized 2026-07-17 (PRD §15 decisions 8–10). Rejected alternatives: `SHIP_FLOW` env flag (can't know the next task's needs), ask-at-ship-time prompt in `/commit` (doesn't compose with Level 7 unattended flows). Branch-state inference + explicit ending commands won.
- **Protection-check correction:** the roadmap docs cite `gh api .../branches/<default>/protection` — research verified that endpoint is admin-gated (404s ambiguously for non-admins, indistinguishable from "not protected"). The implemented check is `gh api repos/{o}/{r}/branches/<b> --jq .protected` (Contents:read, covers rulesets empirically). Task 11 corrects AGENTIC-EVOLUTION.md.
- **Claim lifetime change:** the `worktree:*` claim now legitimately outlives `/execute-isolated` (released by `/merge` or reconcile). `/continue`'s stale-claim heuristic (worktree missing = stale) still holds — a PR-parked branch keeps its worktree alive by design.
- **Confidence: 8/10.** Risks: the live board mutation (no dry run — mitigated by re-send-with-ids + read-back validation); porting drift in `/pr` step 6 (mitigated by explicit adaptation list); walkthrough's protection demo needs a temporary ruleset (harmless, removed after).
