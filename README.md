# Claude Workflow Template

A lightweight, reusable project management workflow for [Claude Code](https://claude.ai/code). Gives you structured slash commands, GitHub Issues/Projects integration, and progressive context loading without the bloat.

## The Story

I started out creating markdown files with Claude Code but without any real structure. PRDs, plan files, progress trackers, all just loose files I'd ask Claude to generate or update. I was trying to figure out how to structure plans that Claude could actually execute, how to track what was done, and how to pick up where I left off between sessions. It got messy fast.

Then I stumbled on [Cole Medin's video](https://www.youtube.com/watch?v=goOZSXmrYQ4) showing his `.claude/` folder structure with slash commands. Simple, but powerful. It immediately gave me a structure I could build on: commands for planning, executing, committing, and priming context. That was the real starting point.

After using Cole's approach for a while, I wanted to move beyond my simple markdown tracker file. I wanted everything synced with GitHub Issues and Projects so I could see board status, track phases, and have `/commit` automatically close issues when acceptance criteria were met. That's where most of the original work in this template came from: wiring up `gh` CLI commands, GraphQL mutations for project board fields, label taxonomies, and issue hierarchies.

As a final step, I looked at what other frameworks were out there: [BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD), [GSD](https://github.com/gsd-build/gsd-2), [everything-claude-code](https://github.com/affaan-m/everything-claude-code). They're impressive, but they're also really heavy and complex. Way overkill for a solo developer like me. So instead of adopting any of them wholesale, I just analyzed them, compared the best parts, and pulled in specific ideas that made my workflow better without bloating it.

The result is this template. It's lightweight, fast, and focused on one thing: working with Claude Code's structured commands and GitHub Issues/Projects for tracking progress. Nothing more.

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
- **[Charles Coppinger](https://www.twitch.tv/thecoppinger)** created [stream-leak-guard](https://github.com/coppinger/stream-leak-guard) for preventing secret leaks during live coding. It's not included in this template by default, but I highly recommend it as an add-on if you stream or share your screen.

### Comparison Matrix

| Feature | Source |
|---------|--------|
| `.claude/` folder structure | Cole Medin |
| Path-scoped rules (`.claude/rules/`) | Cole Medin (WISC "Select") |
| Scout-pattern reference docs (`.claude/docs/`) | Cole Medin (WISC "Select") |
| AI context tracking in commits | Cole Medin (WISC "Write") |
| 3-tier context loading | Cole Medin (WISC framework) |
| Decision protocol tiers | BMAD-METHOD |
| Implementation readiness gate | BMAD-METHOD |
| PRD sync to GitHub issues | BMAD-METHOD |
| Scope enforcement | GSD |
| Deviation rules in `/execute` | GSD |
| Verify/done criteria in plans | GSD |
| Placeholder scan in `/commit` | everything-claude-code |
| Anti-slop word list | everything-claude-code |
| Auto-format hook | everything-claude-code |
| `/continue` for session resumption | Bjorn (glossboss.ink) |
| GitHub Projects integration | Original |
| Label taxonomy & issue hierarchy | Original |
| `/workflow` modification skill | Original |
| Prerequisites checker | Original |

### Also Thanks To

- **[Anthropic](https://www.anthropic.com/)** for Claude Code and the slash command, rules, and skills system that makes all of this possible

## What's Included

### Slash Commands (9)

| Command | Purpose |
|---------|---------|
| `/init-project` | **Project bootstrapper** with prerequisites check, GitHub Project board creation, label setup, field ID capture, and CLAUDE.md generation |
| `/commit` | Smart commits with placeholder scanning, AI context tracking (`Context:` section in commit body), and automatic GitHub issue updates (comment, check off AC, close) |
| `/continue` | Resume work sessions by scanning board state, showing In Progress/Ready/Backlog issues, and suggesting next tasks by priority |
| `/execute` | Execute implementation plans with pre-flight checks (clean git, deps, env), board status updates, and 4-tier deviation rules (fix inline, add validation, fix blockers, stop for architecture) |
| `/plan-feature` | Create implementation plans through 5-phase process: board context, feature analysis, codebase intelligence, external research, strategic planning. Outputs to `.agents/plans/` with GitHub issue creation |
| `/status` | Progress review across all phases with board status breakdown, recently completed issues, and suggested next priorities |
| `/create-prd` | Generate Product Requirements Documents with 15-section template (executive summary through risks & mitigations) |
| `/create-rules` | Analyze codebase and generate `CLAUDE.md` with detected project type, tech stack, patterns, and conventions |
| `/prime` | Load project context by reading structure, docs, key files, and recent git activity |

### Skills (1)

| Skill | Purpose |
|-------|---------|
| `/workflow` | Safely modify the workflow system itself. Reads all components, performs impact analysis across all files, presents a change plan, and updates everything in the correct order |

### Configuration Files

| File | Purpose |
|------|---------|
| `workflow.md` | Source of truth for the entire project management process: board structure, issue hierarchy, label taxonomy, slash command integration, context loading tiers |
| `CLAUDE-template.md` | Starter template for `CLAUDE.md` generation with sections for overview, stack, commands, structure, patterns, testing, and key files |

### Optional Add-ons

| Add-on | Purpose | Link |
|--------|---------|------|
| **stream-leak-guard** | Prevents secret leaks during live coding and screen sharing. Created by [Charles Coppinger](https://www.twitch.tv/thecoppinger). | [github.com/coppinger/stream-leak-guard](https://github.com/coppinger/stream-leak-guard) |

### Systems & Patterns

These are built into the commands and workflow, not separate files:

| System | Where | What It Does |
|--------|-------|--------------|
| **3-tier context loading** | `workflow.md` section 9 | Tier 1: CLAUDE.md (always loaded), Tier 2: path-scoped rules (auto-loaded), Tier 3: on-demand reference docs (scout headers) |
| **Issue hierarchy** | `workflow.md` section 3 | Phase Epics > Feature Issues > Task Sub-issues with auto-rolling progress bars |
| **Decision protocol** | Generated in CLAUDE.md | Low/Medium/High stakes tiers for when to proceed vs ask |
| **Scope enforcement** | Generated in CLAUDE.md | Rules against silently dropping plan steps |
| **AI context tracking** | `/commit` | `Context:` section in commit messages when `.claude/` files change, making AI layer evolution visible in `git log` |
| **Placeholder scanning** | `/commit` | Pre-commit scan for TODO/FIXME/HACK/XXX and empty function bodies in staged files |
| **Deviation rules** | `/execute` | 4-tier system: fix bugs inline, add boundary validation, fix blockers pragmatically, stop for architecture changes |
| **Deduplication checks** | `/plan-feature` | Searches existing issues before creating new ones to prevent duplicates |
| **Prerequisites checker** | `/init-project` | OS detection, required/optional tool checks, install command generation for macOS/Windows/Linux |

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
- Create 17 standard labels on your repo (phase, type, priority, source)
- Capture all generated field IDs and write them into workflow.md and commands
- Analyze your codebase and generate CLAUDE.md with decision protocol, scope enforcement, and issue tracking rules

**Adding to an existing project?** `/init-project` scans for existing `.claude/` files before touching anything. If you already have a CLAUDE.md or custom commands, it'll show you what would be affected and let you choose: back up and overwrite, merge (only add what's missing), or abort.

### 3. Start working

```
/prime              # Load project context
/create-prd         # Write your PRD
/plan-feature       # Plan a feature
/execute            # Implement a plan
/commit             # Commit with issue tracking
/continue           # Resume work next session
/status             # Review progress
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

`/init-project` checks all of these automatically and offers to install what's missing.

### Required

| Tool | Purpose | macOS | Windows | Linux |
|------|---------|-------|---------|-------|
| [Claude Code](https://claude.ai/code) | CLI for Claude | `npm i -g @anthropic-ai/claude-code` | same | same |
| [git](https://git-scm.com/) | Version control | `brew install git` | `winget install Git.Git` | `sudo apt install git` |
| [GitHub CLI](https://cli.github.com/) (`gh`) | Issues, project board, labels | `brew install gh` | `winget install GitHub.cli` | [install guide](https://github.com/cli/cli/blob/trunk/docs/install_linux.md) |
| [jq](https://jqlang.github.io/jq/) | JSON parsing for API responses | `brew install jq` | `winget install jqlang.jq` | `sudo apt install jq` |

After installing, run `gh auth login` to authenticate.

### Optional (checked but not blocking)

| Tool | Purpose | macOS | Windows | Linux |
|------|---------|-------|---------|-------|
| [Node.js](https://nodejs.org/) | JS/TS projects | `brew install node` | `winget install OpenJS.NodeJS.LTS` | `nvm install --lts` |
| [Supabase CLI](https://supabase.com/docs/guides/cli) | DB migrations & type gen | `brew install supabase/tap/supabase` | `npm i -g supabase` | `npm i -g supabase` |
| [Docker](https://www.docker.com/) | Local databases, containers | `brew install --cask docker` | `winget install Docker.DockerDesktop` | [install guide](https://docs.docker.com/engine/install/) |

**Windows note:** Commands work in Git Bash, PowerShell, and WSL. If running inside WSL, use the Linux column instead.

### What `/init-project` does with this

1. Detects your OS (macOS, Windows, Linux/WSL)
2. Checks every required tool and config
3. Shows a pass/fail checklist
4. For anything missing: shows the install command and asks if you want it run automatically
5. Re-checks after install to confirm
6. Only proceeds to GitHub setup once all required checks pass
7. Reports optional tool versions in the final summary
