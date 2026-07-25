# Feature: Level 7 — Automated Triage (`/dispatch` + scheduled morning session)

The following plan should be complete, but its important that you validate documentation and codebase patterns and task sanity before you start implementing.

Pay special attention to naming of existing utils types and models. Import from the right files etc.

## Feature Description

Add Dan's "factory router agent" on subscription primitives: a `/dispatch` command that reads board #18, picks the top-priority **Ready, unclaimed, not-already-dispatched** issue, classifies it by `type:` label, runs the matching planner (`/plan-feature`, `/plan-bug`, `/plan-hotfix`) in **proceed-and-document mode** (never asks — records assumptions), commits the plan to a `dispatch/<N>-<slug>` branch, and opens a PR via `/pr` **without `Closes #N`** — then stops. It never executes plans. A local cron entry runs it headless each morning (`claude -p "/dispatch" --permission-mode dontAsk`), so the owner's day starts at the review constraint, not the research phase.

## User Story

As the owner
I want a scheduled session to triage the board and prep the next plan overnight
So that my morning starts at the review constraint (a plan-PR waiting for approval), not the research phase — with both human gates (plan approval, code review) intact.

## Problem Statement

Every planning cycle starts with a human at the keyboard doing mechanical triage: read the board, pick the top Ready issue, decide which planner fits, run it, wait. That's ~30–60 minutes of latency before the first genuine judgment call (approving the plan). The board already encodes everything needed to route (Status, `type:` labels, the board Priority field, claims) — the routing is deterministic; only the plan content needs an agent.

## Solution Statement

`/dispatch` = the routing rules from `/continue` Step 4 + planner invocation with the interactive gates neutralized + the Level 6 ship layer for delivery. Design decisions (owner, 2026-07-17): **local cron + documented recipe** (not cloud routines — research preview, fresh-clone constraints); **proceed-and-document** ambiguity policy (harness-enforced: `dontAsk` auto-denies AskUserQuestion); **plan lands via branch + `/pr`** (dogfoods Level 6; the plan is reviewed as a PR diff). Guardrails: never executes, never claims (planning commands don't — workflow.md §10), never closes, never clears claims, plan PR carries no `Closes #N`, issue board Status stays **Ready** (a plan-in-review ≠ feature-in-review).

## Feature Metadata

**Feature Type**: New Capability (1 command, 1 reference doc, 1 cron recipe)
**Estimated Complexity**: Medium
**Primary Systems Affected**: `template/.claude/commands/` (new dispatch.md), `template/.claude/docs/` (new cron recipe doc), workflow.md §7/§9/§10, SKILL.md, counts (18→19), root docs
**Dependencies**: Claude Code ≥2.1.x headless mode (`-p`, `--permission-mode dontAsk`, `--max-turns`); cron + flock (verified present on this machine); Levels 1–6 (all shipped)

---

## CONTEXT REFERENCES

### Relevant Codebase Files IMPORTANT: YOU MUST READ THESE FILES BEFORE IMPLEMENTING!

- `template/.claude/commands/continue.md` (Step 1 auto-gather lines 5–14; Step 4 work-order rules lines 66–80) — Why: `/dispatch` reuses the `board-state.sh` gather and the exact prioritization rules; rule 7 ("ask the user" about stale claims) becomes "skip" unattended.
- `template/.claude/scripts/board-state.sh` — Why: the one board-reading path; JSON shape `{issues, closed, board}`.
- `template/.claude/commands/plan-feature.md` (Phase 0 line 25 PRD-missing tell-the-user; Phase 2 lines 48–54 clarify-ambiguities; Phase 4 line 106 ask-now; Report line 511 epic-creation ask; Report sub-issues section) — Why: the four interactive points + sub-issue creation that dispatch mode overrides.
- `template/.claude/commands/plan-bug.md` + `plan-hotfix.md` — Why: already unattended-safe (no ask points, no board writes); dispatch routes to them by label.
- `template/.claude/commands/pr.md` (Step 1 preconditions lines 40–48; Step 3 `Closes` derivation lines 67–92; Step 6 board → In Review lines 122–127) — Why: dispatch must satisfy the preconditions (branch first, commit first) and override TWO steps: omit `Closes #N`, and skip the In Review board move (issue stays Ready; PR URL comment only).
- `template/.claude/commands/commit.md` (closing gate lines 64–84) — Why: confirms `/commit` on `dispatch/<slug>` cannot close the feature issue; dispatch must never use `--close`.
- `template/.claude/commands/execute-isolated.md` (Step 5 executor-choice pattern) — Why: the established "read `<command>.md` and follow its steps with listed overrides" composition pattern dispatch uses for planners.
- `template/.claude/commands/merge.md` (frontmatter) — Why: `disable-model-invocation: true` precedent for mutating commands; dispatch gets it too (blocks model auto-fire; explicit `claude -p "/dispatch"` invocation still works — user-invoked).
- `template/.claude/workflow.md` (§5 invariant lines 164–166; §7 entry format; §10 planning-commands-don't-claim lines 456–459; stale claims 480–485) — Why: every rule dispatch must respect; §7 needs the new entry.
- `.claude/docs/EXAMPLE.md` — Why: scout-friendly header format (Purpose/When to use/Size) for the new cron reference doc.
- `.agents/learnings/level-6.md` (deferred validations lines 201–205; watch-out-fors 141–156) — Why: this level's walkthrough discharges deferred #2; the destructive-mutation and claim conventions carry over.
- `.agents/plans/level-6-ship-layer.md` — Why: task format, VALIDATE style, closer + learning-gate task exemplars.

### New Files to Create

- `template/.claude/commands/dispatch.md` — the `/dispatch` command
- `template/.claude/docs/dispatch-cron.md` — the unattended-run reference doc (cron recipe, permission posture, WSL2 notes)
- `.agents/learnings/level-7.md` + `level-7-diagram.mmd` — learning doc + diagram (repo-only)

### Relevant Documentation YOU SHOULD READ THESE BEFORE IMPLEMENTING!

- [Headless mode](https://code.claude.com/docs/en/headless)
  - Why: `claude -p "/dispatch"` is documented-supported ("include /skill-name in the prompt string"); `--output-format json` for cron logs; subagents work in `-p` (background cap 10 min); do NOT use `--bare` (skips OAuth + skills — breaks subscription auth and command discovery).
- [Permission modes](https://code.claude.com/docs/en/permission-modes#allow-only-pre-approved-tools-with-dontask-mode)
  - Why: `dontAsk` auto-denies un-allowlisted calls AND `AskUserQuestion` without aborting — the documented "locked-down CI" posture; `bypassPermissions` is containers-only per docs and needs a one-time interactive acceptance — do not use.
- [CLI reference](https://code.claude.com/docs/en/cli-reference)
  - Why: `--max-turns` (print-mode turn bound; wall-clock needs `timeout(1)`), no `--cwd` flag exists (cron must `cd`), `settings.json` permission rules apply in non-bare headless runs.
- [Scheduled tasks comparison](https://code.claude.com/docs/en/scheduled-tasks#compare-scheduling-options) + [Routines](https://code.claude.com/docs/en/routines)
  - Why: CronCreate is session-scoped (fires only while a session is open — unsuitable); Routines are cloud research-preview (fresh clone, no local files) — the documented future path, named in the doc but not built on.
- `man 5 crontab`
  - Why: cron's minimal PATH (claude lives in `~/.local/bin` — must extend PATH in crontab), `%` must be escaped as `\%`, HOME is set (gh/git auth work).

### Patterns to Follow

**Composition (execute-isolated Step 5 style):** "Read `.claude/commands/plan-feature.md` and follow it from Phase 0, with the following overrides: …" — never duplicate a planner's flow inline.

**Inline gather (continue.md Step 1):** `!`-prefixed `./.claude/scripts/board-state.sh` so board state lands in context before reasoning.

**STOP conditions:** merge.md/pr.md style — numbered preconditions, each a hard STOP with a one-line reason. Unattended STOPs must also `echo` a machine-greppable line (e.g. `dispatch: nothing to do — no Ready unclaimed issues`) so cron logs are auditable.

**Placeholders:** `{{REPO_OWNER}}/{{REPO_NAME}}`, `{{PROJECT_NUMBER}}` in all gh calls; new command is picked up by sync automatically (no sync-script edit needed — no new tokens introduced).

**Reference-doc header (EXAMPLE.md):** `**Purpose:** / **When to use:** / **Size:**` then `---`.

---

## INTEGRATION CONTRACTS

Single-component feature — no cross-component contracts. (One repo, markdown + bash; the "contract" is dispatch's guardrail list, stated once in dispatch.md and mirrored in workflow.md §7.)

---

## OBSERVABLE TRUTHS

- Running `/dispatch` (attended or headless) against a board with a seeded Ready `type:feature` issue produces: a plan file in `.agents/plans/`, a `dispatch/<N>-<slug>` branch whose only commit adds that plan file, an open PR titled `plan: …` whose body contains **no `Closes` line** but references the issue (`Plan for #N`), and a comment on the issue with the PR URL.
- After a dispatch run: the issue is **open**, **unclaimed** (no `worktree:*` label), board Status still **Ready**, and no other board item changed.
- A second `/dispatch` run against the same board **skips** the already-dispatched issue (open `dispatch/<N>-*` PR detected) and picks the next eligible issue or reports "nothing to do".
- `/dispatch` with no eligible issues (none Ready, or all claimed/dispatched/chore) exits cleanly with a greppable "nothing to do" line — no branch, no PR, no mutations.
- Issues with `type:chore` are never dispatched (logged as skipped); `type:bug` routes to `/plan-bug`; `type:feature` (and unlabeled-type default) routes to `/plan-feature`; explicit hotfix labeling routes to `/plan-hotfix`.
- The plan produced unattended contains an `## ASSUMPTIONS (unattended)` section listing every decision the planner would have asked about.
- A headless run (`claude -p "/dispatch" --permission-mode dontAsk --max-turns 100 --output-format json`) completes without human input; its JSON log shows the run's result; the session was never blocked waiting for a prompt.
- The main tree ends on `master`, clean — dispatch switches back after pushing the branch.
- `ls .claude/commands/*.md | wc -l` → 19; battery green.

## REQUIRED ARTIFACTS

- [ ] `template/.claude/commands/dispatch.md` — the command (frontmatter: `description`, `disable-model-invocation: true`)
- [ ] `template/.claude/docs/dispatch-cron.md` — cron recipe doc (scout header; crontab snippet with PATH/flock/timeout/`\%`; `dontAsk` + settings.local.json allowlist shape; WSL2 VM-lifetime note + Task Scheduler keepalive; log location convention)
- [ ] Updated `template/.claude/workflow.md` — §7 `/dispatch` entry; §9 note (dispatch drives planner scouts unattended); §10 note (dispatch reads claims, never writes them)
- [ ] Updated `template/.claude/skills/workflow/SKILL.md` — dispatch.md in both lists
- [ ] Updated `template/.claude/commands/init-project.md` — count 19 + Ready-to-Use row
- [ ] Updated root `CLAUDE.md` (count 19), `README.md` (table row + section), `AGENTIC-EVOLUTION.md` (Level 7 routing fix: bug → `/plan-bug`, chore → skipped; mark shipped at completion)
- [ ] Synced root `.claude/` (battery green, 19 commands)
- [ ] Live crontab entry on this machine (installed during walkthrough, owner-approved)
- [ ] `.agents/learnings/level-7.md` + `level-7-diagram.mmd` + walkthrough + sign-off (HARD GATE)

## KEY LINKS

- PRD: `.claude/PRD.md` §7 Level 7, §12 Phase 7 row, success criterion "Overnight run produces a correct, reviewable plan for a seeded issue"
- Roadmap: `AGENTIC-EVOLUTION.md` Level 7 (lines 233–246)
- GitHub issue: (created by /plan-feature — see epic)
- Level 6 deferred validation #2 (discharged by this walkthrough): `.agents/learnings/level-6.md` lines 201–205

---

## IMPLEMENTATION PLAN

### Phase A: The command and its doc
`dispatch.md` (the router), then `dispatch-cron.md` (the unattended recipe).

### Phase B: Docs ripple + sync
workflow.md, SKILL.md, init-project.md, root docs, sync + battery.

### Phase C: Live validation
Attended smoke test on a seeded issue, then a real headless run.

### Phase D: Learning gate (HARD GATE)
Learning doc + diagram + walkthrough (cron install + overnight run + Level 6 deferred #2 discharge) + sign-off.

---

## STEP-BY-STEP TASKS

IMPORTANT: Execute every task in order, top to bottom. Each task is atomic and independently testable.

### Task 1: CREATE template/.claude/commands/dispatch.md

- **IMPLEMENT**: Frontmatter: `description: Triage the board unattended — route the top Ready issue to a planner and open a plan PR`, `disable-model-invocation: true` (blocks model auto-fire; explicit invocation incl. `claude -p "/dispatch"` still works — the prompt string is user invocation). Structure:
  **Step 1 — Preconditions (all STOP with a greppable `dispatch: <reason>` echo):** on the default branch; working tree clean (unattended must never stash); `gh auth status` succeeds.
  **Step 2 — Gather:** `!` inline `./.claude/scripts/board-state.sh` + `git worktree list` + open dispatch-PR probe: `gh pr list --repo {{REPO_OWNER}}/{{REPO_NAME}} --state open --json headRefName --jq '[.[].headRefName | select(startswith("dispatch/"))]'`.
  **Step 3 — Select:** apply `/continue` Step 4's work-order rules with three unattended amendments (state them, don't re-derive): (a) only Status **Ready** issues are eligible (In Progress belongs to a human session); (b) **skip** — never clear — claimed issues and stale claims (rule 7's "ask the user" is impossible here); (c) skip issues with an existing open `dispatch/<N>-*` PR or an existing plan file referencing them. If nothing is eligible: echo `dispatch: nothing to do — no eligible Ready issues` and STOP cleanly.
  **Step 4 — Classify by `type:` label:** `type:bug` → `plan-bug.md`; `type:feature` → `plan-feature.md`; no type label → `plan-feature.md` (default, note the assumption); `type:chore` → skip the issue (echo `dispatch: #N is a chore — handle via /chore`, return to Step 3 for the next candidate); explicit hotfix indication (board Priority field **Critical** + `type:bug` — priority labels no longer exist; board-state.sh carries each item's `priority` value) → `plan-hotfix.md`.
  **Step 5 — Plan in proceed-and-document mode:** read the selected planner file and follow it (execute-isolated Step 5 composition pattern) with these overrides, listed verbatim in the command: (1) never ask the user anything — `AskUserQuestion` is denied in headless `dontAsk` mode anyway; where the planner says "ask", make the reasonable assumption instead; (2) every such assumption goes in a `## ASSUMPTIONS (unattended)` section of the plan AND in the issue comment (Step 7); (3) the issue already exists — comment on it, never create a duplicate; skip the epic-creation question (attach to an existing phase epic if the label makes it obvious, else no parent); (4) **skip task sub-issue creation** (unattended board writes stay minimal — the reviewer can create them at approval); (5) plan-feature's scout fan-out runs as normal (subagents work headless; background cap ~10 min).
  **Step 6 — Ship the plan:** `git checkout -b dispatch/<N>-<slug>`; `git add .agents/plans/<file>` (the plan file ONLY — nothing else); commit `plan(#<N>): <title> (dispatched)`; then follow `pr.md` with TWO overrides: (a) **no `Closes #N`** — the body says `Plan for #<N> — merging this PR does NOT close the issue` (merging a plan must not trip the close invariant); (b) **skip pr.md Step 6's board → In Review move** — the feature isn't in review, the plan is; the issue's Status stays Ready. Title: `plan: <issue title> (#<N>)`.
  **Step 7 — Report and stop:** comment on the issue: plan PR URL + the assumptions list + "review and `/execute` after merging". `git checkout <default-branch>` (leave the tree as found). Echo `dispatch: #<N> planned — <PR URL>`. **This command never executes plans, never claims, never closes, never touches other issues.**
  A final **"What this command does NOT do"** section (pr.md style): no execute, no claim (workflow.md §10 — planning is read-mostly), no close/`--close`, no claim-clearing, no In Review, no board mutations beyond one issue comment.
- **PATTERN**: composition — `execute-isolated.md` Step 5; gather — `continue.md` Step 1; STOP style — `merge.md` Step 1; guardrail section — `pr.md` "What this command does NOT do"
- **GOTCHA**: dispatch must NOT re-derive `/continue`'s priority rules inline (drift risk) — reference them and state only the three unattended amendments. The branch add must be surgical (`git add <plan-file>` — a stray `git add -A` would commit scout droppings). The `dispatch/` branch prefix is load-bearing (idempotency probe keys on it).
- **VALIDATE**: `test -f template/.claude/commands/dispatch.md && grep -c 'disable-model-invocation: true' template/.claude/commands/dispatch.md` → 1; `grep -c 'board-state.sh' template/.claude/commands/dispatch.md` → ≥1; `grep -c 'dispatch/' template/.claude/commands/dispatch.md` → ≥3; `grep -ci 'never ask' template/.claude/commands/dispatch.md` → ≥1; `grep -c 'ASSUMPTIONS' template/.claude/commands/dispatch.md` → ≥2; `grep -c 'Closes' template/.claude/commands/dispatch.md` → ≥2 (the override is stated); `grep -ci 'does NOT close' template/.claude/commands/dispatch.md` → ≥1; `grep -c 'In Review' template/.claude/commands/dispatch.md` → ≥1 (the skip is stated); `grep -c 'claim' template/.claude/commands/dispatch.md` → ≥3 (never-claim + skip-claimed both stated); `grep -c '{{REPO_OWNER}}' template/.claude/commands/dispatch.md` → ≥1; `awk '/^````/{n++} END{print n+0}' template/.claude/commands/dispatch.md` → 0
- **VERIFY**: reading top-to-bottom — every mutation is one of: plan file write, branch/commit/push of that file, one PR, one issue comment; the chore-skip loops back to selection; every STOP has a greppable echo; no path claims, closes, or moves board Status
- **DONE**: `/dispatch` exists — router + guardrails + unattended overrides

### Task 2: CREATE template/.claude/docs/dispatch-cron.md

- **IMPLEMENT**: Scout-friendly header (`**Purpose:** run /dispatch unattended on a schedule; **When to use:** wiring or debugging the morning triage cron; **Size:** ~60 lines`). Sections: (1) **The invocation** — `claude -p "/dispatch" --permission-mode dontAsk --max-turns 100 --output-format json` with why: `dontAsk` auto-denies (never hangs, never aborts; AskUserQuestion denied = proceed-and-document enforced), NOT `--bare` (kills OAuth + command discovery), NOT `--dangerously-skip-permissions` (docs: containers only + needs interactive acceptance). (2) **The allowlist** — settings.local.json (per-machine, never synced/committed) `permissions.allow` shape: Read/Glob/Grep/Agent, `Edit/Write(.agents/plans/**)`, `Bash(git status/diff/log/add/commit/push/checkout -b/branch *)`, `Bash(gh issue *)`, `Bash(gh pr create *)`, `Bash(gh project *)`, `Bash(gh api graphql *)`; deny `Bash(git push --force *)`, `Bash(gh pr merge *)`. (3) **The crontab** — verbatim, generic paths:
  ```
  SHELL=/bin/bash
  PATH=$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin
  MAILTO=""
  15 7 * * 1-5  flock -n $HOME/.cache/dispatch.lock -c 'cd <repo> && timeout 3600 claude -p "/dispatch" --permission-mode dontAsk --max-turns 100 --output-format json >> $HOME/.local/state/dispatch-$(date +\%F).log 2>&1'
  ```
  with the three non-obvious notes: cron's PATH is minimal (claude lives in `~/.local/bin`); `%` must be escaped in crontabs; there is no `--cwd` flag — the `cd` is mandatory. (4) **WSL2** — cron fires only while the WSL VM is up; check `systemctl is-system-running` + `service cron status`; keepalive via Windows Task Scheduler running `wsl.exe` at logon. (5) **Reading the log** — `jq -r '.result'` on the JSON blob; grep for `dispatch:` lines (nothing-to-do / planned / skip reasons). (6) **Alternatives** — CronCreate (session-scoped, fires only while a session is open) and cloud Routines (research preview, fresh clone) — named, not used.
- **PATTERN**: header — `.claude/docs/EXAMPLE.md`; snippets verbatim from the research report (verified against docs + this machine)
- **GOTCHA**: this doc ships in the template — keep paths generic (`<repo>`, `$HOME`); the repo-specific crontab (real paths) is installed at the walkthrough, not written into the template.
- **VALIDATE**: `test -f template/.claude/docs/dispatch-cron.md && head -5 template/.claude/docs/dispatch-cron.md | grep -c 'Purpose'` → 1; `grep -c 'dontAsk' template/.claude/docs/dispatch-cron.md` → ≥2; `grep -c 'flock' template/.claude/docs/dispatch-cron.md` → ≥1; `grep -c 'bare' template/.claude/docs/dispatch-cron.md` → ≥1; `grep -c 'settings.local.json' template/.claude/docs/dispatch-cron.md` → ≥1; `grep -c 'wsl\|WSL' template/.claude/docs/dispatch-cron.md` → ≥1
- **VERIFY**: the crontab block survives a copy-paste (no smart quotes, `\%` present); the allowlist contains no rule broader than dispatch needs
- **DONE**: unattended recipe ships with the template

### Task 3: UPDATE template/.claude/workflow.md

- **IMPLEMENT**: (1) §7: `/dispatch` entry in house format — **Reads:** board state, issue bodies, planner command files; **Spawns:** whatever the routed planner spawns (plan-feature's three scouts); **Creates:** plan file on a `dispatch/<N>-<slug>` branch + plan PR (no `Closes`); **Updates:** ONE issue comment — never claims, closes, or moves Status; **Post-execution:** stops for review; `/execute` after the human merges the plan PR. Place after `/continue`. (2) §9 roster: one row — dispatch (via routed planner) reuses the planner's subagent roster unattended. (3) §10: one sentence in the claims section: "`/dispatch` reads claims to skip owned work but never writes or clears them (planning commands do not claim; stale-claim clearing stays consent-gated in `/continue`)."
- **PATTERN**: §7 entry format — the `/merge` + `/pr` entries added at Level 6
- **VALIDATE**: `grep -c '/dispatch' template/.claude/workflow.md` → ≥3; `grep -c 'dispatch/' template/.claude/workflow.md` → ≥1
- **DONE**: workflow.md documents the router

### Task 4: UPDATE SKILL.md + init-project.md + root docs

- **IMPLEMENT**: (1) `template/.claude/skills/workflow/SKILL.md`: add `dispatch.md` to the Step 1 read-list and Step 3 impact checklist. (2) `template/.claude/commands/init-project.md`: "18 slash commands configured" → 19; add `/dispatch` to Ready-to-Use. (3) Root `CLAUDE.md`: "18 slash commands" → 19 (add dispatch to the parenthetical). (4) `README.md`: table row (`/dispatch` — unattended morning triage: routes the top Ready issue to a planner, opens a plan PR) + a short `### /dispatch` prose section pointing at the cron doc. (5) `AGENTIC-EVOLUTION.md` Level 7 section: fix the routing line (`type:bug → /plan-bug` — `/plan-bug` postdates that text; chore → skipped by design, never executed unattended) and note the shipped invocation (`claude -p` + cron, not CronCreate — CronCreate is session-scoped).
- **GOTCHA**: CLAUDE.md/README/AGENTIC are root-only (edit directly, never synced); the other two live in template/.
- **VALIDATE**: `grep -c 'dispatch.md' template/.claude/skills/workflow/SKILL.md` → 2; `grep -c '19 slash commands' template/.claude/commands/init-project.md` → 1; `grep -c '19 slash commands' CLAUDE.md` → 1; `grep -c '/dispatch' README.md` → ≥2; `grep -c 'plan-bug' AGENTIC-EVOLUTION.md` → ≥1
- **DONE**: counts and lists consistent at 19

### Task 5: RUN sync + battery

- **IMPLEMENT**: `./scripts/sync-template.sh`; battery; confirm expected file list in git status.
- **VALIDATE**: `./scripts/sync-template.sh` → "OK: template synced, all placeholders resolved."; `./.claude/hooks/validate-local.sh && echo battery-green` → battery-green; `ls .claude/commands/*.md | wc -l` → 19; `grep -rn '{{' .claude/commands/dispatch.md .claude/docs/dispatch-cron.md` → no output
- **DONE**: root installation carries `/dispatch`

### Task 6: RUN attended smoke test (seeded issue)

- **IMPLEMENT**: (1) Seed: `./.claude/scripts/create-issue.sh --title "Seed: dispatch smoke test — add a --version flag to sync-template.sh" --body-file <small real body with 2 AC> --labels "type:feature" --priority Medium --status Ready` (a small but REAL feature — the planner must have something genuine to plan). (2) Run `/dispatch` **in this session** (attended first — same instructions, human watching). (3) Assert the Observable Truths: plan file exists with `## ASSUMPTIONS (unattended)`; branch `dispatch/<N>-*` has exactly one commit touching only the plan file; PR open, body has `Plan for #N` and NO `Closes`; issue commented, still open, unclaimed, Status Ready; tree back on master, clean. (4) Re-run `/dispatch` → must skip the dispatched issue → `dispatch: nothing to do` (idempotency). (5) Leave the seed + PR in place — Task 7 and the walkthrough reuse them.
- **GOTCHA**: this is a live test against board #18 — the seed issue is real and gets cleaned up in the walkthrough (close PR unmerged OR merge it as the deferred-#2 demo; then close seed via ship-step convention). Do not let the smoke test's plan PR linger past the walkthrough.
- **VALIDATE**: `test -f .agents/plans/<produced-plan>.md && grep -c 'ASSUMPTIONS' .agents/plans/<produced-plan>.md` → ≥1; `gh pr list --repo {{REPO_OWNER}}/{{REPO_NAME}} --state open --json headRefName,body --jq '.[] | select(.headRefName | startswith("dispatch/")) | .body' | grep -c 'Closes'` → 0; `gh issue view <seed-N> --json labels --jq '[.labels[].name | select(startswith("worktree:"))] | length'` → 0; `git branch --show-current` → master
- **VERIFY**: second run skipped correctly; board item still Ready (`gh project item-list` check); no other issue was touched
- **DONE**: dispatch works attended, idempotently

### Task 7: RUN headless validation (the "no human at the keyboard" criterion)

- **IMPLEMENT**: (1) Add the dispatch allowlist to `.claude/settings.local.json` (root-only, uncommitted — the doc's shape). (2) Seed a second small real issue (same pattern). (3) From a plain shell (not inside a Claude session): `cd <repo> && timeout 3600 claude -p "/dispatch" --permission-mode dontAsk --max-turns 100 --output-format json > /tmp/dispatch-headless-test.json 2>&1; echo "exit:$?"`. (4) Assert: exit 0; `jq -r '.result'` (or gh's --jq equivalent) shows the `dispatch: #N planned` line; all Task 6 truths hold for the second issue; the run never waited for input (wall-clock sanity: minutes, not the timeout).
- **GOTCHA**: this consumes subscription usage from the same 5-hour window as interactive work — run it once, not in a loop. If `dontAsk` denies a needed tool, the log shows the denial — extend the allowlist and re-run once; record the final allowlist in the doc (Task 2 amendment) if it differs.
- **VALIDATE**: `test -s /tmp/dispatch-headless-test.json && echo log-exists` → log-exists; the produced plan/branch/PR assertions from Task 6 applied to seed #2
- **VERIFY**: the JSON log contains no permission-prompt hang and no abort; the `## ASSUMPTIONS (unattended)` section is non-empty (proves proceed-and-document fired where an attended run would have asked)
- **DONE**: PRD criterion met — an unattended run produced a reviewable plan for a seeded issue

### Task 8: CREATE .agents/learnings/level-7.md + level-7-diagram.mmd + walkthrough (HARD GATE)

- **IMPLEMENT**: Learning doc per convention (gap / files / flow BEFORE-AFTER / see-it-yourself / watch-out-fors / findings / log). Diagram: `flowchart TD` — board → eligibility filter (Ready ∧ unclaimed ∧ undispatched ∧ ¬chore) → type router → planner (proceed-and-document) → dispatch branch → plan PR (no Closes) → human gates. **Walkthrough script:** (1) static greps; (2) review the Task 6/7 artifacts live (plan PRs, assumptions sections, untouched board); (3) **install the real crontab** (owner runs `crontab -e` with the doc's block, real paths — owner-approved system change); (4) **discharge Level 6 deferred validation #2**: owner merges one dispatch plan PR in the GitHub UI → `/continue` → watch the reconcile probe flag the merged `dispatch/` branch → pull, consent-gated `-D` — with the noted caveat that a plan PR has no `Closes #N`/board move, so only the branch-GC half of deferred #2 demonstrates here (log it as partially discharged, honestly); (5) cleanup: second dispatch PR closed unmerged + branch deleted; seed issues closed via ship-step convention (their plans were the product, delivered); (6) next morning (or a cron line set 5 minutes ahead): verify the cron-fired log exists and shows a clean nothing-to-do run. Log appended live, dated ✓ steps; owner sign-off as a comment on the Level 7 epic. Also: log the Level 6 deferred-#2 outcome in `.agents/learnings/level-6.md`'s deferred list.
- **PATTERN**: `.agents/learnings/level-6.md` structure; level-5 walkthrough-log style
- **VALIDATE**: `test -f .agents/learnings/level-7.md && grep -c '^## ' .agents/learnings/level-7.md` → ≥6; `test -f .agents/learnings/level-7-diagram.mmd && echo ok` → ok
- **DONE**: doc + diagram exist; walkthrough performed (incl. live cron install + cron-fired run); owner sign-off recorded on the epic (HARD GATE — the roadmap's final level)

---

## TESTING STRATEGY

### Unit Tests
Structural greps per task (no test framework). The command's logic is exercised by live runs, not static analysis.

### Integration Tests
Sync + battery (Task 5); attended smoke test with idempotency re-run (Task 6); headless run (Task 7) — the real integration test of command × permissions × cron environment.

### Edge Cases
- Empty board / nothing Ready → clean "nothing to do" exit, zero mutations
- All Ready issues claimed or already dispatched → same
- `type:chore` at top priority → skipped, next candidate taken
- Issue with no `type:` label → defaults to `/plan-feature`, assumption logged
- Dirty tree at start → STOP (unattended never stashes)
- `dontAsk` denies an un-allowlisted tool → agent adapts/reports in log, run completes degraded rather than hanging
- Two overlapping runs → flock makes the second a no-op
- WSL VM asleep at cron time → no run; keepalive documented (accepted residual risk)

---

## VALIDATION COMMANDS

### Level 1: Syntax & Style
```bash
awk '/^````/{n++} END{print n+0}' template/.claude/commands/dispatch.md template/.claude/docs/dispatch-cron.md
for f in scripts/*.sh template/.claude/scripts/*.sh; do bash -n "$f" || echo "FAIL: $f"; done
```

### Level 2: Unit (structural greps)
The per-task VALIDATE blocks above, in order.

### Level 3: Integration
```bash
./scripts/sync-template.sh          # → OK: template synced, all placeholders resolved.
./.claude/hooks/validate-local.sh && echo battery-green
ls .claude/commands/*.md | wc -l    # → 19
```

### Level 4: Manual Validation
Task 6 (attended + idempotency), Task 7 (headless), Task 8 walkthrough (cron-fired).

---

## ACCEPTANCE CRITERIA

- [ ] `/dispatch` routes by `type:` label (bug→plan-bug, feature/unlabeled→plan-feature, critical-bug→plan-hotfix, chore→skipped) and never executes, claims, closes, or moves board Status
- [ ] Plan PRs open without `Closes #N`; the dispatched issue stays open, unclaimed, Ready
- [ ] Re-dispatch is idempotent (open `dispatch/<N>-*` PR ⇒ skip)
- [ ] Unattended plans carry a non-empty `## ASSUMPTIONS (unattended)` section
- [ ] A headless `claude -p "/dispatch"` run under `dontAsk` completes with exit 0, producing a reviewable plan PR for a seeded issue (PRD success criterion)
- [ ] A cron-fired run leaves an auditable JSON log with greppable `dispatch:` lines
- [ ] `dispatch-cron.md` ships in the template with the verified recipe (dontAsk, allowlist, flock/timeout/PATH/`\%`, WSL2 keepalive)
- [ ] Counts/lists at 19 everywhere; workflow.md §7/§9/§10 updated; battery green
- [ ] Level 6 deferred validation #2 discharged (partially — branch-GC half) and logged in level-6.md
- [ ] Learning doc + diagram + walkthrough (incl. live cron install) + owner sign-off (HARD GATE)

## COMPLETION CHECKLIST

- [ ] All tasks completed in order
- [ ] Each task validation passed immediately
- [ ] Attended + headless + idempotency runs all green
- [ ] Battery green; 19 commands
- [ ] Walkthrough performed; sign-off recorded (closes the roadmap's final level)

---

## NOTES

- **Executor: `/execute` in the MAIN TREE.** Tasks 6–7 run live dispatches that create branches from master and mutate board/issues — worktree isolation would isolate nothing and complicate the branch topology. Single-component, no contracts → not `/execute-team`. (Deferred Level 6 validation #1 — first real `/merge` — is NOT forced here; it discharges naturally on a future feature.)
- **Design provenance (owner, 2026-07-17):** local cron over cloud Routines (research preview, fresh-clone, no local state) and over CronCreate (session-scoped — fires only while a session sits open; also scheduled fires skip `disable-model-invocation` skills). Proceed-and-document over stop-and-ask (mornings should start at review, not questions) — and `dontAsk` mode *enforces* it. Branch+PR delivery over uncommitted files (durable, reviewable as a diff, dogfoods Level 6).
- **Permission posture:** `dontAsk` + settings.local.json allowlist. Never `--bare` (breaks OAuth + command discovery), never `--dangerously-skip-permissions` (docs: isolated containers only; requires an interactive first-acceptance). The allowlist lives in settings.local.json — per-machine, uncommitted — NOT in the template's settings.json, so interactive users don't inherit broad git/gh auto-allows.
- **Board-signal decision:** a dispatched issue stays **Ready** (In Review would misreport the feature's state; the plan PR itself is the review surface). The "already dispatched" marker is the open `dispatch/<N>-*` PR — no new labels, no new statuses.
- **Invariant compliance:** the plan PR omits `Closes #N` precisely so the Level 6 invariant (close ⟺ work on default branch) survives — merging a plan is not landing the work. `/commit` on the dispatch branch can't close (gate), and dispatch never uses `--close`.
- **Usage note:** each headless run draws from the same subscription windows as interactive use (verified: OAuth works in `-p`; no API key involved). One run/morning is negligible; the cron doc says so explicitly. UNVERIFIED in docs: any cron-specific policy — flagged in the doc as a watch-item.
- **Confidence: 7.5/10.** Risks: headless behavior differences only discoverable at Task 7 (mitigated: attended run first, allowlist iteration loop documented); planner-in-dispatch-mode producing thin plans unattended (mitigated: assumptions section makes gaps visible at review — and a bad plan costs one rejected PR, not bad code); WSL VM lifetime for the real cron fire (accepted residual, keepalive documented).
