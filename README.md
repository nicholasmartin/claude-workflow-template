# Claude Workflow Template

A lightweight, reusable project management workflow for [Claude Code](https://claude.ai/code). Gives you structured slash commands, GitHub Issues/Projects integration, and progressive context loading without the bloat.

## The Story

I started out using Claude Code to generate loose markdown files: PRDs, plans, trackers. No structure, no conventions, just asking Claude to create or update files as I went. It got messy fast, especially when trying to pick up where I left off between sessions.

Then I found [Cole Medin's video](https://www.youtube.com/watch?v=goOZSXmrYQ4) showing his `.claude/` folder structure with slash commands. Simple, but powerful. That became my foundation. I built on it by integrating everything with GitHub Issues and Projects so `/commit` could auto-close issues, `/plan-feature` could create issues from plans, and `/continue` could scan the board to suggest what to work on next.

Finally, I looked at the heavier frameworks out there: [BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD), [GSD](https://github.com/gsd-build/gsd-2), [everything-claude-code](https://github.com/affaan-m/everything-claude-code). Way too complex for a solo developer. So I just cherry-picked the best ideas (decision protocols, deviation rules, scope enforcement, placeholder scanning) and folded them into this lightweight template. The result is fast, focused, and does one thing well: structured commands with GitHub tracking.

## Credits & Inspiration

### [Cole Medin's WISC Framework](https://github.com/coleam00/context-engineering-intro/tree/main/use-cases/ai-coding-wisc-framework) ([video](https://www.youtube.com/watch?v=goOZSXmrYQ4))

The foundation for everything. Cole's `.claude/` folder structure and WISC (Write, Isolate, Select, Compress) context engineering framework is what got me started. I took:

- `.claude/commands/` folder structure for slash commands
- `.claude/rules/` with `paths:` frontmatter for auto-loaded, path-scoped context (the "Select" strategy)
- `.claude/docs/` with scout-friendly headers for on-demand reference loading (Tier 3 context)
- AI context tracking in commits (`Context:` section) so the AI layer's evolution is visible in `git log` (the "Write" strategy)
- The 3-tier progressive context loading model (always loaded > auto-loaded > on-demand)

### [BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD) (Breakthrough Method for Agile AI-Driven Development)

Structured agile workflows with specialized agent roles. I took:

- Decision protocol tiers (low/medium/high stakes) for when Claude should proceed vs ask
- Implementation readiness gates in `/execute` (pre-flight checks before coding)
- PRD-to-issue sync concept (inspired `/plan-feature`'s GitHub issue creation from plans)

### [GSD](https://github.com/gsd-build/gsd-2) (Get Shit Done)

A meta-prompting and spec-driven development system for autonomous agent work. I took:

- Scope enforcement rules (never silently drop tasks from a plan)
- Deviation rules in `/execute` (4-tier system: fix inline, add validation, fix blockers, stop for architecture)
- Verify/done criteria in plan templates (Observable Truths, Required Artifacts sections)

### [everything-claude-code](https://github.com/affaan-m/everything-claude-code)

A comprehensive Claude Code plugin collection from an Anthropic hackathon winner. I took:

- Placeholder scanning in `/commit` (TODO/FIXME/HACK/XXX pre-commit check)
- Anti-slop word list for writing style enforcement
- Post-edit auto-format hook pattern

### What I Built Myself

- Full GitHub Projects integration (board creation, field IDs, GraphQL mutations, automatic issue updates)
- Label taxonomy and issue hierarchy (Phase Epics > Feature Issues > Task Sub-issues)
- `/workflow` skill for safely modifying the workflow system itself
- Prerequisites checker with OS detection and install commands
- The `/init-project` bootstrapper that ties everything together

### Community

- **[Bjorn](https://glossboss.ink/)** shared the `/continue` session resumption concept with me on a live stream, which became one of the most-used commands in this workflow
- **[Charles Coppinger](https://www.twitch.tv/thecoppinger)** created [stream-leak-guard](https://github.com/coppinger/stream-leak-guard) for preventing secret leaks during live coding. Not included by default, but I highly recommend it if you stream or share your screen.
- **[Anthropic](https://www.anthropic.com/)** for Claude Code and the slash command, rules, and skills system that makes all of this possible

---

## What's Included

### Commands at a Glance

| Command | What It Does |
|---------|-------------|
| `/init-project` | Bootstrap a new project with prerequisites, GitHub board, labels, and CLAUDE.md |
| `/plan-feature` | Create a detailed implementation plan and GitHub issue from a feature request |
| `/execute` | Implement a plan step by step with pre-flight checks and deviation rules |
| `/commit` | Smart commit with placeholder scanning, AI context tracking, and issue updates |
| `/merge` | Land a feature branch on the default branch locally (ship step; protection-guarded) |
| `/pr` | Push the branch and open a pull request — never merges (ship step; board → In Review) |
| `/continue` | Resume a session by scanning board state and suggesting next tasks |
| `/status` | Progress review across all phases |
| `/create-prd` | Generate a Product Requirements Document |
| `/create-rules` | Analyze codebase and generate CLAUDE.md |
| `/prime` | Load project context into the conversation |
| `/workflow` | Safely modify the workflow system itself (skill) |

### `/init-project` - Project Bootstrapper

The entry point for new projects. Checks that required tools are installed (git, gh) across macOS, Windows, and Linux, and offers to install what's missing. Creates a GitHub Project board with Status/Phase/Priority fields, sets up 13 standard labels, captures all generated field IDs, and writes them into every command and config file. For JS/TS projects, offers to set up auto-formatting on commit (Husky + lint-staged + Prettier) so every commit gets cleaned up automatically. If you're adding this to an existing project, it detects existing files and offers to back up, merge, or abort so nothing gets overwritten.

### `/plan-feature` - Feature Planner

Takes a feature request and turns it into a detailed implementation plan through 5 phases: board context, feature analysis, codebase intelligence gathering, external research, and strategic planning. Outputs a plan file to `.agents/plans/` with step-by-step tasks, validation commands, and acceptance criteria. Also creates a GitHub issue with AC checkboxes and adds it to the project board. Searches for duplicate issues before creating new ones.

### `/execute` - Plan Executor

Reads a plan file and implements it step by step. Starts with pre-flight checks (clean git, dependencies installed, env file present). Moves the GitHub issue to "In Progress" on the board. Follows 4-tier deviation rules: fix bugs inline, add boundary validation, fix blockers pragmatically, but stop and ask before architecture changes. Updates the issue with progress as it goes.

### `/commit` - Smart Commit

Scans staged files for TODO/FIXME/HACK/XXX placeholders and empty function bodies before committing (currently JS/TS only: `.js`, `.jsx`, `.ts`, `.tsx`). If AI context files (`.claude/rules/`, `.claude/commands/`, `CLAUDE.md`) are in the diff, appends a `Context:` section to the commit body describing what changed in the AI layer. After committing, checks open GitHub issues, comments with the commit hash, checks off completed acceptance criteria, and closes issues when all AC are met.

### `/continue` - Session Resumption

Fetches open issues and project board state, checks git status and recent history, then presents a table grouped by status: In Progress first, then Ready, then Backlog. Suggests what to work on next based on priority and dependencies. Designed so you can start every session with `/continue` and immediately know where things stand.

### `/status` - Progress Review

Pulls data from the GitHub project board and recent git activity. Shows issues per phase, board status breakdown, recently completed issues, and suggests top priority items to pick up next.

### `/create-prd` - PRD Generator

Generates a Product Requirements Document with 15 sections from executive summary through risks and mitigations. Extracts requirements from the conversation, synthesizes them, and writes a structured markdown file.

### `/create-rules` - CLAUDE.md Generator

Analyzes the codebase to detect project type, tech stack, patterns, and conventions, then generates a `CLAUDE.md` file. Also adds decision protocol tiers (low/medium/high stakes), scope enforcement rules, and issue tracking conventions.

### `/prime` - Context Loader

Reads project structure, documentation, key files, config files, and recent git history. Outputs a scannable summary of the project: overview, architecture, tech stack, conventions, and current state.

### `/workflow` - Workflow Modifier (Skill)

Used when changing the workflow system itself. Reads all components (workflow.md, all commands, CLAUDE.md, GitHub Project state), performs impact analysis, presents a change plan, and updates everything in the correct order. Prevents accidentally updating one piece without updating the others.

### Configuration

| File | Purpose |
|------|---------|
| `workflow.md` | Source of truth for project management: board structure, issue hierarchy, label taxonomy, context loading tiers |
| `CLAUDE-template.md` | Starter template for `CLAUDE.md` generation |
| `.claude/rules/components.md` | Starter React/Next.js component conventions (auto-loaded when editing `components/**`) |
| `.claude/rules/api-routes.md` | Starter API route conventions (auto-loaded when editing `app/api/**`) |
| `.claude/docs/EXAMPLE.md` | Shows the scout-friendly header format for reference docs |

---

## Quick Start

### 1. Copy template into your project

```bash
cp -r template/.claude your-project/.claude
cp -r template/.agents your-project/.agents
```

### 2. Run the setup command

Open Claude Code in your project directory and run:

```
/init-project
```

This will:
- Check prerequisites and offer to install missing tools
- Ask for your project name, repo, and description
- **Detect existing files** (CLAUDE.md, commands, rules) and offer to back up, merge, or abort so nothing gets lost
- Create a GitHub Project board with Status, Phase, Priority fields
- Create 13 standard labels on your repo (phase, type, source — priority lives only in the board's Priority field)
- Capture all generated field IDs and write them into workflow.md and commands
- Analyze your codebase and generate CLAUDE.md

### 3. Start working

```
/prime              # Load project context
/create-prd         # Write your PRD
/plan-feature       # Plan a feature
/execute            # Implement a plan
/commit             # Commit with issue tracking
/continue           # Resume work next session
```

## The Workflow Lifecycle

```
/create-prd                     Write the spec
     |
     v
/plan-feature                   Create implementation plan + GitHub issue
     |                          (plan file in .agents/plans/, issue on board)
     v
/execute .agents/plans/X.md     Implement step by step
     |                          (moves issue to In Progress, checks off AC)
     v
/commit                         Commit with issue tracking
     |                          (comments on issue, closes if all AC met)
     v
/continue                       Resume next session
                                (shows board state, suggests next task)
```

For quick fixes: just implement and `/commit`. Not everything needs a plan.

## Customization

After setup, you should:

1. **Review CLAUDE.md** and add project-specific conventions, writing style, and important notes
2. **Add path-scoped rules** in `.claude/rules/` for areas of your codebase (e.g., `components.md`, `api-routes.md`, `migrations.md`). Use `paths:` frontmatter to auto-load them when relevant files are touched
3. **Add reference docs** in `.claude/docs/` for complex subsystems. Include a header with Purpose, When to use, and Size so agents can scout relevance before loading the full doc
4. **Create Phase Epics** as parent issues for development phases
5. **Add area labels** specific to your project (e.g., `area:auth`, `area:dashboard`, `area:api`)
6. **Write your first PRD** with `/create-prd`

## Auto-Format on Commit (JS/TS Projects)

For JavaScript and TypeScript projects, `/init-project` offers to set up automatic code formatting on every commit using Husky + lint-staged + Prettier. This is optional but recommended. When configured, every `git commit` (including `/commit`) automatically runs Prettier and ESLint on your staged files before the commit goes through. No more style inconsistencies in your codebase.

If you skip it during setup, you can always add it later:

```bash
npm install -D prettier husky lint-staged
npx husky init
echo "npx lint-staged" > .husky/pre-commit
```

Then add to your `package.json`:

```json
{
  "lint-staged": {
    "*.{ts,tsx,js,jsx}": ["eslint --fix", "prettier --write"],
    "*.{json,css,md}": ["prettier --write"]
  }
}
```

## File Structure

```
.claude/
├── commands/
│   ├── commit.md          # Smart commit + issue tracking + AI context tracking
│   ├── continue.md        # Resume work sessions
│   ├── create-prd.md      # PRD generator (15-section template)
│   ├── create-rules.md    # CLAUDE.md generator from codebase analysis
│   ├── execute.md         # Plan executor with deviation rules
│   ├── init-project.md    # Project bootstrapper with prerequisites
│   ├── plan-feature.md    # 5-phase feature planner
│   ├── prime.md           # Context loader
│   └── status.md          # Progress reviewer
├── skills/
│   └── workflow/
│       └── SKILL.md       # Workflow modification with impact analysis
├── docs/                  # On-demand reference docs (you create these)
├── rules/                 # Path-scoped rules (you create these)
├── CLAUDE-template.md     # Template for CLAUDE.md generation
└── workflow.md            # Project management source of truth
.agents/
└── plans/                 # Implementation plans (created by /plan-feature)
```

## Prerequisites

> **Shell requirement:** The slash commands use bash syntax (`jq`, `grep`, `xargs`, `$(...)`, `test -f`). Run Claude Code with **Git Bash** or **WSL** as your shell — they do **not** run in native PowerShell. On Windows, Git Bash is the recommended default.

`/init-project` checks all of these automatically and offers to install what's missing.

| Tool | Purpose | macOS | Windows | Linux |
|------|---------|-------|---------|-------|
| [Claude Code](https://claude.ai/code) | CLI for Claude | `npm i -g @anthropic-ai/claude-code` | same | same |
| [git](https://git-scm.com/) | Version control | `brew install git` | `winget install Git.Git` | `sudo apt install git` |
| [GitHub CLI](https://cli.github.com/) (`gh`) | Issues, project board, labels | `brew install gh` | `winget install GitHub.cli` | [install guide](https://github.com/cli/cli/blob/trunk/docs/install_linux.md) |

After installing, run `gh auth login` to authenticate.
