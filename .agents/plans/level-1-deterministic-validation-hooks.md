# Feature: Level 1 — Deterministic Validation Hooks

The following plan should be complete, but it's important that you validate documentation and codebase patterns and task sanity before you start implementing.

Pay special attention to the Golden Rule: **every edit lands in `template/`, then `./scripts/sync-template.sh` regenerates `.claude/`**. Never edit root `.claude/` files directly (root-only files like `validate-local.sh` are the documented exception).

## Feature Description

Move the workflow's three loop *conditions* out of prompt prose and into harness-enforced code: a `PostToolUse` hook lints each edited file (advisory), a `Stop` hook runs the full validation battery and refuses to let the turn end while it fails (blocking), and a pre-commit scan script detects placeholder junk at ship time (warn). Command files are trimmed so agents keep only judgment work. A second, separable stage extracts deterministic `gh` choreography into plumbing scripts. This is Phase 1 of the PRD and Level 1 of AGENTIC-EVOLUTION.md.

## User Story

As a solo developer running agentic workflows
I want every deterministic validation triggered by the harness instead of by prompt obedience
So that "done" always means verified, regardless of whether the agent had a good day.

## Problem Statement

Today every check in `/execute` and `/commit` runs only if the agent follows instructions faithfully: "verify as you go" (execute step 3c), "if any command fails: fix, re-run" (execute step 5), and the placeholder greps in `/commit`. A distracted agent can skip any of them and nothing stops it. Additionally, this repo's sync invariant ("sync before committing template/ changes") is enforced only by CLAUDE.md prose.

## Solution Statement

Ship a hook layer in the template: `.claude/settings.json` wiring + three scripts under `.claude/hooks/` that (a) parse hook stdin JSON with a jq→python3 fallback, (b) detect available project tooling and no-op silently when absent (the template is language-agnostic), and (c) use exit-code semantics correctly: `exit 2` on PostToolUse feeds stderr to Claude as advisory feedback; `exit 2` on Stop blocks the turn from ending. Trim the command prose the hooks replace. Then (separate commit) extract board plumbing into `.claude/scripts/`. Finish with the Level 1 learning doc + walkthrough (hard gate).

## Feature Metadata

**Feature Type**: New Capability
**Estimated Complexity**: Medium
**Primary Systems Affected**: template/.claude (settings, hooks, commands, workflow.md, skill), scripts/sync-template.sh, root .claude installation
**Dependencies**: None external. Uses bash + python3 (stdin parsing fallback) + optional project tools (eslint/tsc) when present.

---

## CONTEXT REFERENCES

### Relevant Codebase Files IMPORTANT: YOU MUST READ THESE FILES BEFORE IMPLEMENTING!

- `template/.claude/commands/execute.md` (steps 3c, 5 — lines ~76-103) — Why: the prose being replaced by hooks; trim exactly these
- `template/.claude/commands/commit.md` (Pre-Commit section, lines 5-27) — Why: greps moving into pre-commit-scan.sh; keep the warn-don't-block conversation
- `template/.claude/commands/init-project.md` (steps 6-7, 10) — Why: where hook installation + approval note gets added
- `template/.claude/workflow.md` — Why: must document the hook layer (new section); source of truth
- `template/.claude/skills/workflow/SKILL.md` (Step 1 + Step 3 checklists) — Why: hooks/settings/scripts become checklist components
- `scripts/sync-template.sh` — Why: verify it propagates executable bits and skips root-only files; extend only if needed
- `.claude/PRD.md` section 7 Level 1 + section 6 (extraction rule, two-tier table) — Why: the spec this implements

### New Files to Create

- `template/.claude/settings.json` — hooks wiring (PostToolUse + Stop)
- `template/.claude/hooks/lib.sh` — shared: stdin JSON field extraction (jq, else python3), tool detection
- `template/.claude/hooks/post-edit-lint.sh` — per-edit advisory lint
- `template/.claude/hooks/stop-validate.sh` — per-turn blocking battery
- `template/.claude/hooks/pre-commit-scan.sh` — ship-time placeholder scan (invoked by /commit; wired to husky by init-project on JS repos)
- `.claude/hooks/validate-local.sh` — ROOT-ONLY (not in template): this repo's battery — placeholder scan, sync-drift check, bash -n on scripts
- `template/.claude/scripts/board-state.sh` — stage B: dump issues + board items as one JSON blob
- `template/.claude/scripts/move-issue.sh` — stage B: `move-issue.sh <number> <Status>` (resolves item ID + option ID internally)
- `template/.claude/scripts/create-issue.sh` — stage B: create issue + labels + board add + Phase/Priority fields in one call
- `.agents/learnings/level-1.md` — learning doc (hard gate deliverable)

### Relevant Documentation YOU SHOULD READ THESE BEFORE IMPLEMENTING!

- [Claude Code hooks reference](https://code.claude.com/docs/en/hooks.md)
  - Sections: PostToolUse/Stop input schemas, exit codes, decision JSON
  - Why: exact contract the scripts are written against (verified 2026-07-14, summarized below)
- [Hooks guide](https://code.claude.com/docs/en/hooks-guide.md)
  - Section: Stop hook loop protection
  - Why: `stop_hook_active` pattern

### Verified API Facts (from claude-code-guide research, 2026-07-14)

- Matcher `"Write|Edit"` is valid (pipe-separated, case-sensitive tool names); `"matcher": ""` matches all for Stop
- Hook config: `{"hooks": {"PostToolUse": [{"matcher": "Write|Edit", "hooks": [{"type": "command", "command": "...", "timeout": <seconds>}]}]}}`
- stdin JSON: `tool_input.file_path` for both Write and Edit; Stop input has top-level `stop_hook_active` (boolean)
- Exit codes: `0` = OK (stdout parsed as decision JSON if present); `2` = PostToolUse: stderr fed to Claude as feedback / Stop: turn blocked, stderr becomes the instruction; other = non-blocking error to debug log. Never mix exit 2 with JSON stdout.
- Stop hooks are force-overridden after 8 consecutive blocks; always `exit 0` when `stop_hook_active` is true
- Hooks run in the **launch directory**, not project root → always prefix paths with `$CLAUDE_PROJECT_DIR`
- settings.json edits hot-reload in-session (verify with `/hooks`); project hooks need **one-time user approval** on first run
- This machine: `jq` NOT installed, `python3` at /usr/bin/python3 → lib.sh must fall back to python3

### Patterns to Follow

**Shell style** (from `scripts/sync-template.sh`): `#!/usr/bin/env bash`, `set -euo pipefail`, comment header explaining purpose + rules, `$(dirname "$0")` for self-location. EXCEPTION: hook scripts must NOT use `set -e` for the tool-runs themselves — a lint failure is data, not a crash; capture exit codes explicitly.

**Graceful degradation** (new, becomes the pattern): every tool invocation guarded:
```bash
if [ -f "$CLAUDE_PROJECT_DIR/package.json" ] && npx --no-install eslint --version >/dev/null 2>&1; then
  npx --no-install eslint --cache "$FILE" 2>&1
fi
```

**Contract-statement trim** (new, becomes the pattern for all future hook extractions): deleted prose is replaced by ONE line stating the contract, e.g. *"Per-edit lint and end-of-turn validation run automatically via hooks (see workflow.md §Hook Layer); fix anything they report."*

**Docs lockstep** (workflow skill guardrail): command edit → workflow.md edit → SKILL.md checklist edit → sync → verify.

---

## OBSERVABLE TRUTHS

- Writing a `.sh` file with a syntax error into the repo produces hook feedback in the same turn, without anyone asking (bash -n via post-edit-lint)
- Editing a `.md` file produces zero hook output and adds no perceptible latency
- With `template/` edited and sync NOT run, the agent's turn cannot end: the Stop hook blocks with "run ./scripts/sync-template.sh"
- `printf 'x' > /tmp/t.sh; echo '{"tool_input":{"file_path":"/tmp/t.sh"}}' | .claude/hooks/post-edit-lint.sh` exits 0 (valid syntax) and the same with `if x` content exits 2 with a readable stderr message
- `echo '{"stop_hook_active":true}' | .claude/hooks/stop-validate.sh` exits 0 unconditionally (loop guard)
- On a machine without jq, all hooks still parse stdin (python3 fallback)
- In a repo with no package.json, no eslint, no tsc, every hook exits 0 silently for JS-tier checks
- `.claude/hooks/pre-commit-scan.sh` run with a staged test file containing `.only(` prints a warning listing file:line and exits 0 (warn, not block)
- `/execute` and `/commit` command files no longer contain the prose the hooks replaced; each has a one-line contract statement instead
- (Stage B) `.claude/scripts/move-issue.sh <N> "In Progress"` moves the board item using only workflow.env values, no ID lookups by the agent

## REQUIRED ARTIFACTS

- [ ] `template/.claude/settings.json` — PostToolUse (Write|Edit) + Stop wiring, $CLAUDE_PROJECT_DIR-prefixed commands, timeouts (15s post-edit, 120s stop)
- [ ] `template/.claude/hooks/lib.sh` — `hook_field <jq-path>` stdin extractor (jq → python3), `has_tool` helper
- [ ] `template/.claude/hooks/post-edit-lint.sh` — advisory; .sh→bash -n, .js/.jsx/.ts/.tsx→eslint --cache (if available), else exit 0
- [ ] `template/.claude/hooks/stop-validate.sh` — loop guard; tsc --noEmit --incremental (if available); sources `.claude/hooks/validate-local.sh` if present; exit 2 with combined failures
- [ ] `template/.claude/hooks/pre-commit-scan.sh` — staged-file scan: TODO/FIXME/HACK/XXX, empty fn bodies, empty catch, `.only`/`.skip` in test files; prints findings, exits 0
- [ ] `.claude/hooks/validate-local.sh` — root-only: unresolved-placeholder scan, template↔root sync-drift check, bash -n over scripts/ and .claude/hooks/
- [ ] Updated `template/.claude/commands/execute.md` — step 3c deleted; step 5 → contract line (~179 → ~90 lines)
- [ ] Updated `template/.claude/commands/commit.md` — grep section → one script call + relay/ask flow
- [ ] Updated `template/.claude/commands/init-project.md` — hook install note (approval prompt, /hooks verification, husky wiring of pre-commit-scan.sh for JS repos)
- [ ] Updated `template/.claude/workflow.md` — new "Hook Layer" section (tiers table, contracts, extension points)
- [ ] Updated `template/.claude/skills/workflow/SKILL.md` — settings.json/hooks/scripts in Step 1 reading list + Step 3 checklist
- [ ] All template hook/script files executable in git (`update-index --chmod=+x` or committed with 755)
- [ ] Stage B: `template/.claude/scripts/{board-state,move-issue,create-issue}.sh` + trimmed gather/report sections in continue/status/execute/plan-feature
- [ ] `.agents/learnings/level-1.md` + walkthrough performed + sign-off recorded on the epic

## KEY LINKS

- PRD: `.claude/PRD.md` §6 (extraction rule, two-tier validation), §7 Level 1, §12 Phase 1
- GitHub epic: created by this plan's Report step (Phase 1 on board #18)
- Hooks docs: https://code.claude.com/docs/en/hooks.md

---

## IMPLEMENTATION PLAN

### Phase A: Hook layer (commit 1)

Foundation (lib), the three hook scripts, settings wiring, root-only battery, command trims, docs lockstep, sync.

### Phase B: Plumbing scripts (commit 2)

Board plumbing scripts + gather-step inlining in continue/status; call-site swaps in execute/plan-feature; docs lockstep; sync.

### Phase C: Learning gate

Learning doc, live walkthrough (see script in Testing Strategy), owner sign-off on the epic. **Level 2 planning is blocked until this completes.**

---

## STEP-BY-STEP TASKS

### CREATE template/.claude/hooks/lib.sh

- **IMPLEMENT**: `hook_stdin_field()` — reads stdin once into a var; extracts a dotted path via jq if present, else `python3 -c 'import json,sys; ...'`. `has_tool()` — checks a command exists AND is project-relevant (e.g., eslint requires package.json). Export `PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"`.
- **PATTERN**: header comment style from `scripts/sync-template.sh:1-11`
- **GOTCHA**: stdin can only be read once — capture to a variable first; python3 fallback must not crash on empty stdin (hooks may be invoked manually in tests)
- **VALIDATE**: `echo '{"tool_input":{"file_path":"/a b/c.ts"}}' | bash -c 'source template/.claude/hooks/lib.sh && hook_stdin_field tool_input.file_path'` → `/a b/c.ts` (spaces preserved)
- **DONE**: lib sources cleanly under `bash -n`, both parse paths with and without jq installed

### CREATE template/.claude/hooks/post-edit-lint.sh

- **IMPLEMENT**: source lib; get file_path; case on extension: `*.sh` → `bash -n`; `*.ts|*.tsx|*.js|*.jsx` → eslint --cache single file if available; everything else → exit 0. On check failure: print ≤10 lines to stderr, `exit 2`. Never exit 2 for tool-missing.
- **GOTCHA**: advisory tier — exit 2 here does NOT undo the edit (tool already ran); it feeds stderr to Claude. Do not use `set -e` around the lint invocation. `--cache` writes `.eslintcache` — respect project .gitignore (note in workflow.md).
- **VALIDATE**: `printf 'if [ x\n' > /tmp/bad.sh && echo '{"tool_input":{"file_path":"/tmp/bad.sh"}}' | template/.claude/hooks/post-edit-lint.sh; echo "exit=$?"` → stderr shows syntax error, exit=2. Repeat with valid file → exit=0, no output. Repeat with `/tmp/x.md` → exit=0 instantly.
- **DONE**: all three validations pass

### CREATE template/.claude/hooks/stop-validate.sh

- **IMPLEMENT**: source lib; `stop_hook_active == true` → exit 0 immediately. Collect failures array: (1) if tsconfig.json + tsc available → `tsc --noEmit --incremental`; (2) if `.claude/hooks/validate-local.sh` exists → run it, capture output. Any failures → print all to stderr with header "Validation failed — fix before finishing:" and exit 2. Else exit 0.
- **GOTCHA**: the 8-block force-override cap means a permanently broken battery self-resolves, but keep messages actionable; battery must complete inside the 120s timeout — no test-suite runs here by default (projects opt in via validate-local.sh)
- **VALIDATE**: `echo '{"stop_hook_active":true}' | template/.claude/hooks/stop-validate.sh; echo $?` → 0. `echo '{"stop_hook_active":false}' | ...` in this repo with a deliberately drifted template file → exit 2, stderr names sync-template.sh
- **DONE**: loop guard + pass + fail paths all verified

### CREATE template/.claude/hooks/pre-commit-scan.sh

- **IMPLEMENT**: scan `git diff --cached --name-only` files: markers `(TODO|FIXME|HACK|XXX)\b`, empty bodies `(function|=>)\s*\{\s*\}`, empty catch `catch\s*(\([^)]*\))?\s*\{\s*\}`, and in `*test*`/`*spec*` files `\.(only|skip)\(`. Print `file:line: match` list + count; ALWAYS exit 0 (warn tier — the conversation happens in /commit).
- **PATTERN**: greps from current `template/.claude/commands/commit.md:9-18`, extended
- **GOTCHA**: `xargs` on empty input runs the command once — use `xargs -r`; scope marker-scan to code extensions so this repo's markdown (which legitimately says "TODO") doesn't false-positive
- **VALIDATE**: stage a temp file `t.test.ts` containing `it.only(` → script prints 1 finding, exits 0; unstage
- **DONE**: finds seeded patterns, exits 0 both with and without findings

### CREATE template/.claude/settings.json

- **IMPLEMENT**: PostToolUse matcher `Write|Edit` → `"$CLAUDE_PROJECT_DIR"/.claude/hooks/post-edit-lint.sh`, timeout 15; Stop matcher `""` → stop-validate.sh, timeout 120.
- **GOTCHA**: `$CLAUDE_PROJECT_DIR` must be inside the command string (shell form) — hooks run from the launch dir, not project root. JSON must remain valid — validate with python3.
- **VALIDATE**: `python3 -m json.tool template/.claude/settings.json`
- **DONE**: valid JSON, paths prefixed, timeouts set

### CREATE .claude/hooks/validate-local.sh  (ROOT-ONLY — do not create in template/)

- **IMPLEMENT**: this repo's battery: (1) unresolved placeholders: `grep -rl '{{' .claude/ | grep -v init-project.md` must be empty; (2) sync-drift: run `./scripts/sync-template.sh`, then `git status --porcelain .claude .agents` must be empty (sync is idempotent — any diff means root was stale or hand-edited); (3) `bash -n` every `scripts/*.sh` and `.claude/hooks/*.sh`. Print failures, exit non-zero on any.
- **GOTCHA**: drift check mutates the working tree only when drift exists — that's intentional (the fix is already applied; agent just stages it). Say so in the error message.
- **VALIDATE**: run directly → exit 0 on clean tree; touch a template file copy in root .claude, run → exit non-zero with drift message; `git checkout .claude` to restore
- **DONE**: all three checks fire correctly

### UPDATE template/.claude/commands/execute.md

- **IMPLEMENT**: REMOVE step 3c ("Verify as you go") entirely; REPLACE step 5's fix-loop prose with: "### 5. Final Validation — Validation runs automatically when you finish (Stop hook — see workflow.md §Hook Layer). Additionally run the plan's project-specific validation commands now; fix anything either reports." Renumber; keep pre-flight, deviation rules, output report untouched (pre-flight extraction is NOT this level).
- **VALIDATE**: `grep -c 'Verify as you go' template/.claude/commands/execute.md` → 0; file still contains all four deviation rules
- **DONE**: ~90-110 lines, judgment content intact

### UPDATE template/.claude/commands/commit.md

- **IMPLEMENT**: REPLACE the two grep blocks + surrounding instructions with: run `"$CLAUDE_PROJECT_DIR"/.claude/hooks/pre-commit-scan.sh`; if it prints findings, relay them and ask "Found N placeholder(s). Proceed anyway?"; on yes continue, on no stop. Keep AI Context Tracking + post-commit issue sections verbatim.
- **VALIDATE**: `grep -c 'xargs grep' template/.claude/commands/commit.md` → 0
- **DONE**: scan is one script call + conversation

### UPDATE template/.claude/commands/init-project.md

- **IMPLEMENT**: ADD to step 6 (config files): note that `.claude/settings.json` + `.claude/hooks/` ship with the copy; on first hook fire Claude Code asks one-time approval — expected. ADD to step 7: if husky is configured, append `bash .claude/hooks/pre-commit-scan.sh` to `.husky/pre-commit`. ADD to step 10 verification: `/hooks` shows the two hooks; `python3 -m json.tool .claude/settings.json`.
- **VALIDATE**: read back — new prose references only files this plan creates
- **DONE**: a fresh install gets working hooks with no extra steps

### UPDATE template/.claude/workflow.md

- **IMPLEMENT**: ADD section "Hook Layer (deterministic validation)": the two-tier table (per-edit advisory / per-turn blocking / per-ship warn), what each script does, the `validate-local.sh` extension point, the contract statements commands rely on, `.eslintcache` gitignore note, and the rule that hook changes go through the workflow skill.
- **VALIDATE**: section exists; every script it names exists in template/.claude/hooks/
- **DONE**: workflow.md is again the complete system description

### UPDATE template/.claude/skills/workflow/SKILL.md

- **IMPLEMENT**: ADD `.claude/settings.json`, `.claude/hooks/*`, `.claude/scripts/*` to Step 1 reading list and Step 3 impact checklist; ADD guardrail: "Never change a hook script without updating workflow.md §Hook Layer".
- **VALIDATE**: checklist contains the three new component lines
- **DONE**: skill enforces hook-layer lockstep

### UPDATE scripts/sync-template.sh + run sync (closes Phase A)

- **IMPLEMENT**: ensure executable bits survive sync (`cp` preserves mode; ADD `chmod +x` on `.claude/hooks/`*.sh and `.claude/scripts/`*.sh after copy as belt-and-braces); ensure template files are staged executable (`git update-index --chmod=+x`). Run `./scripts/sync-template.sh`; verify root `.claude/settings.json` and hooks arrived.
- **VALIDATE**: `./scripts/sync-template.sh && test -x .claude/hooks/post-edit-lint.sh && python3 -m json.tool .claude/settings.json`
- **DONE**: root installation has live hooks. **Commit Phase A** (feat(hooks): ...). NOTE: after this commit, hooks are ACTIVE in this repo — the user must approve them once; verify with `/hooks`.

### CREATE template/.claude/scripts/board-state.sh  (Phase B)

- **IMPLEMENT**: one JSON blob to stdout: `{issues: [...], board: [...]}` from `gh issue list --json number,title,labels,state` + `gh project item-list --format json`. Repo/board values via `{{REPO_OWNER}}/{{REPO_NAME}}`/`{{PROJECT_NUMBER}}` placeholders (sync fills them).
- **GOTCHA**: placeholders mean the template copy is not runnable — only the synced copy is; say so in header comment
- **VALIDATE**: `./.claude/scripts/board-state.sh | python3 -m json.tool >/dev/null` (after sync)
- **DONE**: single call replaces the gather choreography

### CREATE template/.claude/scripts/move-issue.sh  (Phase B)

- **IMPLEMENT**: `move-issue.sh <issue-number> <status-name>`; resolves item ID via `gh project item-list --jq`; maps status name → option ID from filled placeholders (case-insensitive); `gh project item-edit`. Clear usage/error messages.
- **VALIDATE**: `./.claude/scripts/move-issue.sh 999 "In Progress"` → readable "issue not on board" error, exit 1 (after sync)
- **DONE**: three-step ID dance is one call

### CREATE template/.claude/scripts/create-issue.sh  (Phase B)

- **IMPLEMENT**: `create-issue.sh --title T --body-file F --labels "a,b" [--phase "Phase 1"] [--priority High] [--status Ready] [--parent <epic-number>]`; creates issue, adds labels, adds to board, sets fields via one GraphQL mutation, optional addSubIssue to parent. Prints issue number + URL.
- **GOTCHA**: this replaces the most fumble-prone choreography in the repo (plan-feature Report step, ~40 lines). Body via file to dodge quoting hell.
- **VALIDATE**: bash -n; live test creates+closes a `type:docs` scratch issue (delete after)
- **DONE**: plan-feature's Report step becomes ~5 script calls

### UPDATE commands to use scripts + sync  (closes Phase B)

- **IMPLEMENT**: `continue.md`/`status.md` Step 1 → inline `` !`./.claude/scripts/board-state.sh` `` (+ git one-liners), delete command lists; `execute.md` step 0 → `move-issue.sh <N> "In Progress"`; `plan-feature.md` Report → `create-issue.sh` calls; workflow.md documents the scripts; SKILL.md checklist already covers `.claude/scripts/*`. Run sync.
- **VALIDATE**: `grep -rn 'gh project item-edit' template/.claude/commands/` → 0 hits; `./scripts/sync-template.sh` green
- **DONE**: **Commit Phase B** (refactor(scripts): ...)

### CREATE .agents/learnings/level-1.md + walkthrough  (Phase C — hard gate)

- **IMPLEMENT**: write per the PRD §7 learning-doc structure (gap → files → information flow → see-it-yourself → watch-outs → walkthrough log). Then run the live walkthrough (Testing Strategy §Manual). Record sign-off comment on the epic. Only then may `/commit` close the epic.
- **VALIDATE**: doc exists; epic has sign-off comment
- **DONE**: Level 1 gate passed; Level 2 unblocked

---

## TESTING STRATEGY

### Unit Tests

No test framework in this repo (by design). Each hook script is exercised by piping synthetic stdin JSON and asserting exit codes + stderr — the VALIDATE lines above are the unit tests. Run them all after Phase A and again after sync (against root copies).

### Integration Tests

- Full turn simulation: with hooks live, Write a broken `.sh` into scratch → observe feedback arrives; fix → silence
- Drift simulation: edit a template file, do NOT sync, attempt to end turn → Stop hook blocks; run sync → turn ends
- Fresh-install simulation: `cp -r template/.claude /tmp/fake-proj/.claude` in a scratch git repo with no JS tooling → simulate both hooks → all exit 0 silently

### Edge Cases

- File paths with spaces (lib.sh extraction must preserve)
- Empty stdin / manual invocation (no crash)
- jq absent (this machine — python3 path is the tested path), python3 also absent (hooks exit 0 with a one-line stderr note, never block)
- `stop_hook_active: true` (must exit 0 — loop guard)
- Repo where `.claude/hooks/validate-local.sh` doesn't exist (template default — stop hook still runs tsc tier or exits clean)

### Manual Validation (= the Level 1 walkthrough script)

1. `/hooks` — show the two hooks registered and approved
2. Ask the agent to write a `.sh` with a syntax error → watch the advisory feedback arrive and get fixed unprompted
3. Edit `template/.claude/workflow.md` (add a comment), skip sync, try to end the turn → Stop hook blocks with the drift message → run sync → turn ends
4. Stage a scratch `x.test.ts` with `it.only(` → run `/commit` → watch the warn-and-ask flow
5. Diff `git show` of the command trims: before/after of execute.md step 5
6. (Phase B) `/continue` — note the gather step is now one inline script whose output precedes the agent's analysis

---

## VALIDATION COMMANDS

### Level 1: Syntax & Style

```bash
for f in template/.claude/hooks/*.sh template/.claude/scripts/*.sh scripts/*.sh; do bash -n "$f" || echo "FAIL: $f"; done
python3 -m json.tool template/.claude/settings.json >/dev/null && echo settings-ok
```

### Level 2: Hook Contract Tests

```bash
printf 'if [ x\n' > /tmp/bad.sh
echo '{"tool_input":{"file_path":"/tmp/bad.sh"}}' | template/.claude/hooks/post-edit-lint.sh; test $? -eq 2 && echo advisory-fail-ok
echo '{"tool_input":{"file_path":"/tmp/nofile.md"}}' | template/.claude/hooks/post-edit-lint.sh && echo skip-ok
echo '{"stop_hook_active":true}' | template/.claude/hooks/stop-validate.sh && echo loop-guard-ok
```

### Level 3: Integration

```bash
./scripts/sync-template.sh
grep -rl '{{' .claude/ | grep -v init-project.md | wc -l   # expect 0
test -x .claude/hooks/post-edit-lint.sh && echo exec-ok
echo '{"stop_hook_active":false}' | .claude/hooks/stop-validate.sh && echo battery-green
```

### Level 4: Manual Validation

The walkthrough script above (Testing Strategy §Manual) — performed live with the owner as the Level 1 learning gate.

---

## ACCEPTANCE CRITERIA

- [ ] An agent edit that breaks `.sh` syntax (or lint, where eslint exists) is reported to the agent in-turn, unprompted (PRD L1 req)
- [ ] An agent turn cannot end while the validation battery fails (PRD L1 req)
- [ ] A staged test file with `.only` triggers a warning at `/commit` without blocking (PRD L1 req)
- [ ] A commit touching `template/` with a drifted root copy is caught before the turn ends (sync-drift check)
- [ ] All hooks silent no-op on repos without the relevant tooling; per-edit tier adds <500ms on non-code files (~0)
- [ ] execute.md and commit.md contain contract statements instead of the extracted prose; deviation rules and warn-don't-block conversations survive verbatim
- [ ] workflow.md §Hook Layer + SKILL.md checklist updated; sync green; no unresolved placeholders
- [ ] Phase B: continue/status/execute/plan-feature use the three plumbing scripts; no raw `gh project item-edit` left in command files
- [ ] `.agents/learnings/level-1.md` exists and the walkthrough sign-off is recorded on the epic

## COMPLETION CHECKLIST

- [ ] All tasks completed in order (A → B → C)
- [ ] Every VALIDATE line executed and passing
- [ ] Both commits made (Phase A: feat(hooks), Phase B: refactor(scripts)) — epic stays open until Phase C sign-off
- [ ] Hooks approved and visible in `/hooks` in this repo
- [ ] Learning gate passed — owner sign-off on epic

---

## NOTES

- **Deviation from PRD §6 layout**: plumbing scripts live at `.claude/scripts/` (inside the synced tree), not `template/scripts/`. Rationale: sync-template.sh already covers the `.claude` tree; a second sync path adds drift surface for zero benefit. PRD layout diagram should be corrected at the learning step.
- **Scope exclusion**: `/execute` pre-flight extraction and the `updateProjectV2Field` fix to init-project.md are NOT in this level (the latter is an ideal `/chore` demo for Level 3).
- **Session note**: after Phase A lands, hooks are live in this very repo — the remainder of the level is built *under* the machinery it shipped. First hook fire triggers a one-time approval prompt; this is expected and should be shown in the walkthrough.
- **Two-tier rationale** (PRD §6): tsc is cross-file → Stop tier only; eslint is per-file → per-edit tier. Test suites stay out of hooks by default (timeout budget); projects opt in via validate-local.sh.
