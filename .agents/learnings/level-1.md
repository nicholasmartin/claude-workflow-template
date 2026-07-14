# Level 1: Deterministic Validation Hooks — What Changed and Why

**Status:** awaiting walkthrough + sign-off (this doc is deliverable 1 of 3; the live walkthrough and your sign-off comment on epic #1 complete the gate)
**Commits:** `5b4e29f` (Phase A: hook layer), `d9b5d36` (Phase B: plumbing scripts)

---

## The gap this closes

Before Level 1, every deterministic check in the workflow ran only if the agent *chose to obey prose*: `/execute` said "verify as you go" and "re-run until it passes"; `/commit` embedded two grep commands and hoped they got run. An agent having a bad day could skip any of them, and nothing in the system would notice. AGENTIC-EVOLUTION.md calls this the tightest wasteful loop (build → lint → build); Dan's rule is that **loop conditions are code's job** — agents supply judgment, not discipline.

## What changed, file by file

### New: the hook layer (`.claude/settings.json` + `.claude/hooks/`)

| File | Event | Tier | Behavior |
|---|---|---|---|
| `post-edit-lint.sh` | `PostToolUse` on Write\|Edit | **Advisory** | `.sh` → `bash -n`; `.ts/.js/...` → single-file `eslint --cache` if the project has it. On failure: exit 2 → stderr is fed to the agent as feedback. The edit is never undone — mid-flight breakage is legitimate. |
| `stop-validate.sh` | `Stop` (turn ending) | **Blocking** | `tsc --noEmit --incremental` if present, then the project-local battery. On failure: exit 2 → the turn *cannot end*; stderr becomes the agent's next instruction. |
| `pre-commit-scan.sh` | invoked by `/commit` | **Warn** | Staged-file scan: TODO/FIXME/HACK/XXX, empty function bodies, empty `catch`, `.only`/`.skip` in tests. Always exits 0 — `/commit` relays and asks you. |
| `lib.sh` | (shared) | — | stdin JSON parsing with jq → python3 fallback (this machine has no jq — python3 is the tested path). |
| `validate-local.sh` | (root-only, NOT in template) | — | This repo's battery: placeholder scan on generated files, template↔root sync-drift detection, `bash -n` across the toolchain. |

### New: plumbing scripts (`.claude/scripts/`)

- `board-state.sh` — one JSON blob (open issues + recent closed + board); `/continue` and `/status` now inject it via inline `` !`...` `` bash *before* the agent thinks
- `move-issue.sh <n> <status>` — replaces the 3-step item-ID/field-ID/option-ID dance
- `create-issue.sh` — create + labels + board + Status/Priority/Phase + epic link, one call

### Trimmed: the commands

- `execute.md`: step 3c ("verify as you go") **deleted** — the hook owns it. Step 5's fix-loop prose → one contract line. Step 0's board choreography → one script call. Deviation rules, pre-flight, report format: untouched.
- `commit.md`: two embedded greps → one `pre-commit-scan.sh` call; the warn-and-ask conversation stayed yours.
- `continue.md` / `status.md`: gather steps became auto-gathered inline bash; prioritization rules and report formats unchanged.
- `plan-feature.md`: Report choreography ~40 lines → ~15 (script calls).

### The test for every line was: does it tell the agent how to *think*, or how to *type*?

Think-lines stayed verbatim. Type-lines became a hook (harness-triggered), a script (agent calls it with judgment inputs), or inline bash (harness runs it before the agent starts).

## How information flows now

```
BEFORE                                    AFTER
agent edits file                          agent edits file
  └─(hopefully remembers to lint)           └─ harness fires post-edit-lint.sh
                                                 └─ failure? stderr → agent fixes now

agent decides it's done → turn ends       agent decides it's done
  └─(validations maybe ran, maybe not)      └─ harness fires stop-validate.sh
                                                 ├─ green → turn ends
                                                 └─ red → turn CANNOT end;
                                                     stderr = fix instructions

/commit: agent runs greps by prose        /commit: agent runs one script,
  └─(or doesn't)                            relays findings, asks you
```

The agent's *judgment* loop is unchanged. What changed is who enforces the *conditions*: the harness, every time, with zero prompt tokens.

## See it yourself (the walkthrough script)

1. Run `/hooks` — see PostToolUse + Stop registered (approve the one-time prompt if asked)
2. Ask the agent to write a `.sh` file with a syntax error — watch feedback arrive and get fixed without you saying anything
3. Add a line to any `template/.claude/` file, don't sync, let the agent try to end its turn — watch the Stop hook block with "run ./scripts/sync-template.sh"
4. Stage a file containing `it.only(` and run `/commit` — watch the warn-and-ask
5. `git show 5b4e29f -- template/.claude/commands/execute.md` — the before/after of the trim
6. Run `/continue` — the board state now precedes the agent's first token

## What to watch out for

- **One-time approval:** first hook fire asks you to approve project hooks. Expected; approve it.
- **Advisory ≠ blocking:** per-edit failures don't stop anything — by design. Only the Stop tier blocks, only at turn end. If a Stop hook seems stuck in a loop: it exits 0 after one block per chain (`stop_hook_active` guard) and Claude Code force-overrides after 8.
- **Drift check self-heals:** when it fires, sync has *already run* — you review `git status .claude` and stage, not re-run anything.
- **Escape hatch:** delete or `chmod -x .claude/hooks/stop-validate.sh` to disable the gate; remove the hook entry in `.claude/settings.json` to kill a tier entirely.
- **`.eslintcache`:** in JS projects, add it to `.gitignore` (the per-edit tier writes it).

## Interesting findings from the build (the hooks caught their own toolchain)

1. `sync-template.sh`'s verification and the placeholder check both false-positived on files that *mention* `{{TOKEN}}` syntax (PRD.md, the scanner's own grep patterns). Fix: scope placeholder checks to **generated files only** and make the scanner self-excluding. Lesson: validation layers need to be told about their own reflection.
2. The inherited empty-function regex missed named functions (`function empty() {}`); caught while seeding test data. The extended scan is genuinely stronger than the prose version was.
3. `execute.md` landed at 167 lines, not the plan's ~90 estimate — the trim was exactly as specced; the estimate under-counted what deliberately stays (pre-flight, deviation rules, report format).
4. **The dogfood/product boundary was convention-only — and the naive guard made it worse** (found during the walkthrough Q&A). "validate-local.sh is root-only" was enforced by nothing: a same-named file in `template/` would be *copied over the real root file by sync* — and because the drift check itself invokes sync, the battery script could be overwritten **while bash was executing it** (bash reads scripts lazily → silent early exit 0 → fake green). Fix, two layers: `sync-template.sh` refuses to run when a root-only file exists in `template/` (the only propagation path), and `validate-local.sh` checks the boundary FIRST, before anything can invoke sync, exiting immediately. Lesson: a "repo-only" property needs a deterministic guard at the propagation point, and a script that can trigger its own rewrite must gate that path before executing it.

## Walkthrough log (2026-07-14, live)

1. **Advisory tier, live fire:** agent wrote a `.sh` with a missing `fi` — the PostToolUse hook reported "syntax error: unexpected end of file from `if` on line 3" into the agent's context unprompted; the fix produced silence. Confirmed working in-session, not just via simulated stdin.
2. **Warn tier:** staged a file with `it.only(`, empty `catch`, and a TODO — scan reported all 3 with file:line, exit 0. Both patterns the old prose greps missed (`.only`, empty catch) were caught.
3. **The trim, as a diff:** `git show 5b4e29f` — instruction prose out, contract statements in.
4. **Plumbing:** `board-state.sh` returned the full tracking state (8 open, 1 closed, 9 board items) as one JSON blob.
5. **Blocking tier, live fire (the finale):** agent added a line to `template/.claude/workflow.md`, skipped sync, and attempted to end its turn. **The Stop hook blocked the turn** with "Template/root drift: template/ was edited without syncing" — the drift check had already self-healed via sync, the agent reviewed `git status`, removed the demo line, re-synced, and only then was the turn allowed to end. The full loop condition → feedback → fix → green cycle ran with zero human intervention.

**Question raised (owner):** "The drift check is for developing the template — it must not ship to template users. How are we making sure?" Answer: drift machinery lives entirely in root-only `validate-local.sh`; the shipped `stop-validate.sh` has only a generic optional extension point, and fresh installs contain no local battery. Verifying this live exposed that the boundary was convention-only — and led to finding #4 below (sync-clobber + mid-execution self-overwrite). Two deterministic guards added and leak-tested: sync refuses on leak, battery fails fast before sync can run.

**Sign-off:** recorded as a comment on epic #1.
