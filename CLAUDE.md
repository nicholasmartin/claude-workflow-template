# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the **claude-workflow-template** — a lightweight, reusable project-management workflow for Claude Code: structured slash commands, GitHub Issues/Projects integration, and progressive context loading. The repo is both the **product** (the template under `template/`) and its own **first customer**: the template is self-installed at the repo root and used to manage its own evolution toward AI Developer Workflows (see `AGENTIC-EVOLUTION.md`).

---

## The Golden Rule: template/ is the source of truth

The repo has two copies of the workflow files:

| Copy | Role | Edit? |
|------|------|-------|
| `template/.claude/`, `template/.agents/` | The product being developed and shipped | **Always edit here** |
| `.claude/`, `.agents/` | This repo's live installation (dogfood) | **Never edit directly** — regenerate via sync |

After editing anything under `template/`, run:

```bash
./scripts/sync-template.sh
```

This copies `template/.claude` → `.claude` and fills `{{PLACEHOLDER}}` values from `scripts/workflow.env` (project number, field IDs, etc.). Exception: `init-project.md` is copied verbatim since its braces are instructional. Root-only files (`CLAUDE.md`, `.claude/PRD.md`, `.agents/plans/*`) are never touched by sync.

**Sync before every commit that touches `template/`.** A drifted root copy means the dogfood installation no longer tests what's being shipped.

---

## Tech Stack

| Technology | Purpose |
|------------|---------|
| Markdown | Slash commands, skills, rules, docs — the entire product |
| Bash + GitHub CLI (`gh`) | Deterministic plumbing: board state, issue lifecycle, sync |
| GitHub Issues/Projects | Work tracking (this repo uses its own workflow: board #18) |

There is no build, no package.json, no test framework — validation is structural (placeholder checks, sync verification).

---

## Commands

```bash
# Sync template -> live installation (run after any template/ edit)
./scripts/sync-template.sh

# Validate this repo's invariants (placeholders, sync drift, shell syntax)
# — also runs automatically as the Stop-hook battery
./.claude/hooks/validate-local.sh
```

---

## Project Structure

```
/
├── template/            # THE PRODUCT: what gets copied into user projects
│   ├── .claude/
│   │   ├── commands/    # 16 slash commands (plan-feature, execute, execute-team, hotfix, bug, chore, ...)
│   │   ├── skills/      # workflow skill (meta: modify the system safely)
│   │   ├── rules/       # example path-scoped rules
│   │   ├── docs/        # example scout-friendly reference docs
│   │   ├── workflow.md  # source of truth for the workflow system
│   │   └── CLAUDE-template.md
│   └── .agents/plans/   # plan file convention + example
├── .claude/             # live installation of template/ (generated, do not hand-edit)
├── .agents/plans/       # real plan files for this repo's own work
├── scripts/
│   ├── sync-template.sh # template -> root sync with placeholder fill
│   └── workflow.env     # this repo's captured IDs (board #18, field IDs)
├── AGENTIC-EVOLUTION.md # the roadmap: Level 1-6 ladder toward ADWs
└── transcription.md     # source material (IndyDevDan ADW transcript)
```

---

## Issue Tracking

This repo tracks its own work on GitHub Project board #18 (`Claude Workflow Template Roadmap`). **Phase N on the board = Level N of AGENTIC-EVOLUTION.md.**

When starting work on any GitHub issue, move it to "In Progress" on the project board before making changes.

**Never close issues or move them to "Done" during implementation.** Only `/commit` closes issues.

**After creating a GitHub issue**, always:
1. Add the item to the project board via GraphQL (`addProjectV2ItemById`)
2. Set relevant custom fields (Priority, Status, Phase) via `updateProjectV2ItemFieldValue`
3. GitHub issue labels and project board custom fields are separate systems. Always set both.

Field IDs live in `.claude/workflow.md` (Field IDs Reference) and `scripts/workflow.env`.

---

## Decision Protocol

### Low Stakes (proceed autonomously)
- Fixing typos, formatting, wording in template files
- Keeping root copies in sync via `./scripts/sync-template.sh`
- Updating counts/lists when commands are added or removed

### Medium Stakes (proceed, but note what you did)
- Changing a slash command's steps or output format
- Adding a new hook, script, or command to the template
- Restructuring a section of workflow.md

### High Stakes (stop and ask before proceeding)
- Changing the template/ vs root sync model
- Renaming or removing slash commands (breaks users' muscle memory)
- Changing the label taxonomy or board field structure
- Anything that would require existing template users to migrate

---

## Scope Enforcement

**Never silently drop tasks from a plan.** Every item in an agreed plan must be completed, explicitly deferred, or flagged.

- **If blocked:** say "I'm blocked on [step] because [reason]. Should I skip it or try a different approach?"
- **If a step turns out unnecessary:** say "Step X appears unnecessary because [reason]. OK to skip?"
- **If running long:** say "I've completed steps 1-4. Steps 5-7 remain. Should I continue?"

---

## Key Files

| File | Purpose |
|------|---------|
| `AGENTIC-EVOLUTION.md` | The roadmap this repo is executing (Levels 1-6) |
| `template/.claude/workflow.md` | Source of truth for the workflow system design |
| `template/.claude/skills/workflow/SKILL.md` | Meta-skill: how to change the system consistently |
| `scripts/sync-template.sh` | The template → installation sync (run after template edits) |

---

## Notes

- When a change touches the workflow system itself (commands, board schema, labels), use the `workflow` skill — it enforces updating all related pieces together.
- The `workflow` skill's guardrail applies doubly here: never update a command without updating `workflow.md`, and never update either without re-running the sync.
- Board Status options were set via the `updateProjectV2Field` GraphQL mutation — despite `init-project.md` claiming this needs the UI. That command should be updated (candidate dogfood fix).
