---
description: Initialize project workflow with GitHub Project board and all configuration
---

# Initialize Project Workflow

## Overview

This command sets up the full Claude Code workflow for a new project. It checks prerequisites, creates a GitHub Project board, configures labels, captures all generated IDs, and writes them into the workflow files so all slash commands work correctly.

**Run this once when starting a new project.**

---

## Step 1: Prerequisites Check

Before anything else, verify the tools this workflow depends on are installed and configured. Run all checks, collect results, then present a single summary.

### Required Tools

These must be installed for the workflow to function:

| Tool | Check Command | Purpose | Install (macOS) | Install (Windows) | Install (Linux) |
|------|---------------|---------|-----------------|-------------------|-----------------|
| **git** | `git --version` | Version control, all commands | `brew install git` | `winget install Git.Git` | `sudo apt install git` |
| **GitHub CLI** | `gh --version` | Issue tracking, project board, labels | `brew install gh` | `winget install GitHub.cli` | See https://github.com/cli/cli/blob/trunk/docs/install_linux.md |

### Required Configuration

These must be set up after the tools are installed:

| Check | Command | Fix |
|-------|---------|-----|
| **gh authenticated** | `gh auth status` | `gh auth login` |
| **Inside a git repo** | `git rev-parse --is-inside-work-tree` | `git init` |
| **Git remote set** | `git remote get-url origin` | `git remote add origin <url>` |

### Optional Tools

These are not required by the workflow itself but are commonly needed during development. Check them so the user knows their environment state:

| Tool | Check Command | Purpose | Install (macOS) | Install (Windows) | Install (Linux) |
|------|---------------|---------|-----------------|-------------------|-----------------|
| **Node.js** | `node --version` | JS/TS projects | `brew install node` | `winget install OpenJS.NodeJS.LTS` | `nvm install --lts` |
| **npm** | `npm --version` | Package management | (comes with Node) | (comes with Node) | (comes with Node) |
| **Supabase CLI** | `supabase --version` | Supabase migrations & types | `brew install supabase/tap/supabase` | `npm install -g supabase` | `npm install -g supabase` |
| **Docker** | `docker --version` | Local database, containers | `brew install --cask docker` | `winget install Docker.DockerDesktop` | See https://docs.docker.com/engine/install/ |

### Run the Check

```bash
# Detect OS and package manager
OS=$(uname -s)
case "$OS" in
  Darwin*)  PLATFORM="macOS" ; PKG_MGR="brew" ;;
  Linux*)   PLATFORM="Linux" ; PKG_MGR="apt" ;;
  MINGW*|MSYS*|CYGWIN*) PLATFORM="Windows" ; PKG_MGR="winget" ;;
  *)        PLATFORM="Unknown ($OS)" ; PKG_MGR="unknown" ;;
esac
echo "Platform: $PLATFORM (package manager: $PKG_MGR)"

# Required tools
echo "=== Required Tools ==="
git --version 2>/dev/null && echo "  git: OK" || echo "  git: MISSING"
gh --version 2>/dev/null | head -1 && echo "  gh: OK" || echo "  gh: MISSING"

# Required configuration
echo "=== Required Configuration ==="
gh auth status 2>&1 | head -3
git rev-parse --is-inside-work-tree 2>/dev/null && echo "  Git repo: OK" || echo "  Git repo: NOT A REPO"
git remote get-url origin 2>/dev/null && echo "  Git remote: OK" || echo "  Git remote: NOT SET"

# Optional tools
echo "=== Optional Tools ==="
node --version 2>/dev/null && echo "  node: OK" || echo "  node: not installed"
npm --version 2>/dev/null && echo "  npm: OK" || echo "  npm: not installed"
supabase --version 2>/dev/null && echo "  supabase: OK" || echo "  supabase: not installed"
docker --version 2>/dev/null && echo "  docker: OK" || echo "  docker: not installed"
```

**Windows note:** Claude Code on Windows typically runs in Git Bash, WSL, or PowerShell. The check commands above work in all three. When offering install commands, use `winget` if running natively on Windows, or the Linux commands if running inside WSL.

### Present Results

Show the user a checklist:

```
## Prerequisites

### Required (must fix before continuing)
- [x] git 2.x.x
- [x] GitHub CLI 2.x.x
- [x] gh authenticated
- [x] Inside git repo
- [x] Git remote configured

### Optional (for reference)
- [x] Node.js 20.x.x
- [x] npm 10.x.x
- [ ] Supabase CLI - not installed
- [x] Docker 24.x.x
```

### Handle Missing Required Tools

If any **required** tool or configuration is missing:

1. List exactly what's missing
2. Provide the install command for the detected platform:
   - **macOS:** use `brew install`
   - **Windows (native/Git Bash):** use `winget install`
   - **Windows (WSL):** use `sudo apt install` (it's Linux inside WSL)
   - **Linux:** use `sudo apt install` (or the distro-appropriate command)
3. Ask: "Should I run these install commands for you, or would you prefer to install manually?"
4. If the user says yes, run the install commands
5. After installation, re-run the check to confirm
6. **Do not proceed to Step 2 until all required checks pass**

If only **optional** tools are missing, note them but continue.

---

## Step 2: Gather Project Details

Ask the user for the following (suggest defaults based on the repo if possible):

1. **Project name** (human-readable, e.g., "PeerPull", "TaskFlow")
2. **Repo owner** (GitHub username or org): detect from `gh repo view --json owner` and parse the login field
3. **Repo name**: detect from `gh repo view --json name` and parse the name field
4. **Project description** (one sentence for CLAUDE.md)

Confirm all values with the user before proceeding.

## Step 3: Check for Existing Setup

Scan for files that already exist and could be overwritten. This is important when adding the workflow to an existing project that already has some `.claude/` configuration.

```bash
echo "=== Existing Files Check ==="

# Critical - these contain project-specific content that would be lost
test -f CLAUDE.md && echo "  CLAUDE.md: EXISTS (will be regenerated)" || echo "  CLAUDE.md: not found"
test -f .claude/workflow.md && echo "  .claude/workflow.md: EXISTS" || echo "  .claude/workflow.md: not found"

# Commands - check if any custom commands exist that would be overwritten
for cmd in commit continue execute plan-feature status create-prd create-rules prime; do
  test -f ".claude/commands/$cmd.md" && echo "  .claude/commands/$cmd.md: EXISTS"
done

# Rules - check for existing path-scoped rules
ls .claude/rules/*.md 2>/dev/null && echo "  .claude/rules/: has existing rules" || echo "  .claude/rules/: empty or not found"

# GitHub Project
gh project list --owner @me --format json
```

### Handle conflicts

Present the user with a summary of what exists:

```
## Existing Files Detected

The following files already exist and would be affected:

| File | Action | Risk |
|------|--------|------|
| CLAUDE.md | Will be regenerated from codebase analysis | **Your existing rules will be lost** |
| .claude/commands/commit.md | Will be overwritten with template version | Custom commit logic will be lost |
| .claude/rules/components.md | Will be overwritten with template starter | Custom component rules will be lost |
| ... | ... | ... |

Options:
1. **Back up and proceed** - I'll copy existing files to `.claude/backup/` before overwriting
2. **Merge mode** - I'll keep your existing files and only add what's missing
3. **Abort** - Stop and let you review manually
```

**If the user chooses "Back up and proceed":**

```bash
# Create backup directory with timestamp
BACKUP_DIR=".claude/backup/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Back up CLAUDE.md
test -f CLAUDE.md && cp CLAUDE.md "$BACKUP_DIR/"

# Back up existing .claude files
test -f .claude/workflow.md && cp .claude/workflow.md "$BACKUP_DIR/"
for f in .claude/commands/*.md .claude/rules/*.md; do
  test -f "$f" && cp "$f" "$BACKUP_DIR/"
done

echo "Backed up existing files to $BACKUP_DIR"
```

Then proceed with the full setup.

**If the user chooses "Merge mode":**

- Skip overwriting any existing command files, only create missing ones
- Skip overwriting existing rule files, only create missing ones
- Skip CLAUDE.md regeneration (or offer to append new sections to the existing one)
- Still create the GitHub Project board and fill in workflow.md placeholders

**If a GitHub Project board already exists** that looks related, ask if they want to use it instead of creating a new one. If yes, skip board creation and just capture the existing field IDs.

## Step 4: Create GitHub Project Board

```bash
# Create the project
# Create the project and capture the output
gh project create --owner @me --title "{{PROJECT_NAME}} Roadmap" --format json

# From the JSON output, extract the project number and node ID
# Then get the full project details including the node ID
gh project list --owner @me --format json

# Parse the output to find the newly created project's number and ID (PVT_...)
# Store as PROJECT_NUMBER and PROJECT_ID for use in subsequent steps

# Link the project to the repo so it appears on the repo's Projects tab
# (without this, the project only shows under the user profile)
gh project link $PROJECT_NUMBER --owner {{REPO_OWNER}} --repo {{REPO_OWNER}}/{{REPO_NAME}}
```

### Create custom fields

The Status field exists by default. Create Phase and Priority:

```bash
# Create Phase field
gh project field-create $PROJECT_NUMBER --owner @me --name "Phase" --data-type "SINGLE_SELECT" --single-select-options "Phase 1,Phase 2,Phase 3"

# Create Priority field
gh project field-create $PROJECT_NUMBER --owner @me --name "Priority" --data-type "SINGLE_SELECT" --single-select-options "Low,Medium,High,Critical"
```

### Capture all field IDs

```bash
# Get all fields with their option IDs
gh project field-list $PROJECT_NUMBER --owner @me --format json
```

Parse the output to extract:
- **Status field ID** and option IDs for: Backlog, Ready, In Progress, Done
  - Note: "Todo" may need to be renamed to "Backlog" in the GitHub UI, or use "Todo" as the Backlog equivalent
- **Phase field ID** and option IDs for each phase
- **Priority field ID** and option IDs for: Low, Medium, High, Critical

Store all IDs in shell variables for the next step.

## Step 5: Create Labels

Create the standard label taxonomy on the repo:

```bash
REPO="{{REPO_OWNER}}/{{REPO_NAME}}"

# Phase labels
gh label create "phase:1" --repo $REPO --color "0E8A16" --description "Phase 1" --force
gh label create "phase:2" --repo $REPO --color "0E8A16" --description "Phase 2" --force
gh label create "phase:3" --repo $REPO --color "0E8A16" --description "Phase 3" --force

# Type labels
gh label create "type:feature" --repo $REPO --color "1D76DB" --description "New feature" --force
gh label create "type:bug" --repo $REPO --color "D73A4A" --description "Bug fix" --force
gh label create "type:infra" --repo $REPO --color "5319E7" --description "Infrastructure" --force
gh label create "type:polish" --repo $REPO --color "FBCA04" --description "Polish and UX" --force
gh label create "type:dx" --repo $REPO --color "C5DEF5" --description "Developer experience" --force
gh label create "type:tech-debt" --repo $REPO --color "D4C5F9" --description "Technical debt" --force
gh label create "type:docs" --repo $REPO --color "0075CA" --description "Documentation" --force

# Priority labels
gh label create "priority:critical" --repo $REPO --color "B60205" --description "Critical priority" --force
gh label create "priority:high" --repo $REPO --color "D93F0B" --description "High priority" --force
gh label create "priority:medium" --repo $REPO --color "FBCA04" --description "Medium priority" --force
gh label create "priority:low" --repo $REPO --color "0E8A16" --description "Low priority" --force

# Source labels
gh label create "source:research" --repo $REPO --color "C2E0C6" --description "From research" --force
gh label create "source:user-report" --repo $REPO --color "C2E0C6" --description "User reported" --force
gh label create "source:internal" --repo $REPO --color "C2E0C6" --description "Internal discovery" --force
```

## Step 6: Write Configuration Files

Now replace all `{{PLACEHOLDER}}` values in the workflow files with the real IDs captured above.

### Files to update with real values:

1. **`.claude/workflow.md`** - Replace all `{{...}}` placeholders:
   - `{{PROJECT_NAME}}` with the project name
   - `{{REPO_OWNER}}` with the repo owner
   - `{{REPO_NAME}}` with the repo name
   - `{{PROJECT_NUMBER}}` with the project number
   - `{{PROJECT_ID}}` with the project node ID
   - `{{STATUS_FIELD_ID}}` with the Status field ID
   - `{{STATUS_BACKLOG_ID}}` (or Todo equivalent)
   - `{{STATUS_READY_ID}}`
   - `{{STATUS_IN_PROGRESS_ID}}`
   - `{{STATUS_DONE_ID}}`
   - `{{PHASE_FIELD_ID}}` with the Phase field ID
   - `{{PRIORITY_FIELD_ID}}` with the Priority field ID
   - `{{PRIORITY_LOW_ID}}`, `{{PRIORITY_MEDIUM_ID}}`, `{{PRIORITY_HIGH_ID}}`, `{{PRIORITY_CRITICAL_ID}}`

2. **All `.claude/commands/*.md`** files - Replace:
   - `{{REPO_OWNER}}/{{REPO_NAME}}` with actual repo path
   - `{{PROJECT_NUMBER}}` with actual number
   - `{{PROJECT_ID}}` with actual ID

3. **`.claude/skills/workflow/SKILL.md`** - Replace same placeholders

### Generate CLAUDE.md

Before generating, scan for existing documentation that could provide project context:

```bash
# Search for PRDs, design docs, architecture docs, READMEs in subdirs
find . -maxdepth 3 -type f \( \
  -name "PRD*" -o -name "prd*" -o \
  -name "README*" -o \
  -name "ARCHITECTURE*" -o \
  -name "DESIGN*" -o \
  -name "SPEC*" -o \
  -name "*.prd.md" \
  \) -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null
```

Also check `docs/`, `doc/`, `.github/`, `.claude/` directories for documentation files.

If documentation is found, list it and read the relevant files to extract project purpose, architecture, and domain context. Use this to write a more accurate Project Overview section in CLAUDE.md.

If no documentation is found, ask the user:

> "I didn't find any existing documentation (PRDs, design docs, etc.). Do you have any files you'd like me to read before generating CLAUDE.md? You can share file paths or just describe the project and I'll work from that."

Then run the `/create-rules` command logic to analyze the codebase and generate a CLAUDE.md file. If the project is brand new with minimal code, create a starter CLAUDE.md from the template at `.claude/CLAUDE-template.md` with the project name and description filled in.

Add these standard sections to the generated CLAUDE.md (adapt based on what `/create-rules` produces):

**Issue Tracking section:**
```markdown
## Issue Tracking

When starting work on any GitHub issue, move it to "In Progress" on the project board before making changes.

**Never close issues or move them to "Done" during implementation.** Only `/commit` closes issues.

**After creating a GitHub issue**, always:
1. Add the item to the project board via GraphQL (`addProjectV2ItemById`)
2. Set relevant custom fields (Priority, Status, Phase) via `updateProjectV2ItemFieldValue`
3. GitHub issue labels and project board custom fields are separate systems. Always set both.
```

**Decision Protocol section:**
```markdown
## Decision Protocol

### Low Stakes (proceed autonomously)
- Fixing typos, formatting, lint errors
- Adding imports or removing unused ones
- Adjusting styling classes or spacing

### Medium Stakes (proceed, but note what you did)
- Adding a new component file or utility function
- Changing validation logic
- Modifying database queries

### High Stakes (stop and ask before proceeding)
- Changing core business logic or economic rules
- Modifying database migrations that have been pushed
- Altering auth flow, middleware, or session handling
- Deleting or renaming database tables/columns
- Architectural decisions (new dependencies, new patterns)
```

**Scope Enforcement section:**
```markdown
## Scope Enforcement

**Never silently drop tasks from a plan.** Every item in an agreed plan must be completed, explicitly deferred, or flagged.

- **If blocked:** say "I'm blocked on [step] because [reason]. Should I skip it or try a different approach?"
- **If a step turns out unnecessary:** say "Step X appears unnecessary because [reason]. OK to skip?"
- **If running long:** say "I've completed steps 1-4. Steps 5-7 remain. Should I continue?"
```

## Step 7: Auto-Format on Commit (JS/TS Projects)

Check if the project already has auto-formatting configured:

```bash
# Check for existing setup
test -f .husky/pre-commit && echo "Husky pre-commit: EXISTS" || echo "Husky pre-commit: not found"
test -f .prettierrc.json -o -f .prettierrc -o -f prettier.config.js && echo "Prettier config: EXISTS" || echo "Prettier config: not found"
grep -q "lint-staged" package.json 2>/dev/null && echo "lint-staged: configured" || echo "lint-staged: not configured"
```

**If package.json exists but auto-formatting is not set up**, offer to configure it:

> "I noticed this is a JS/TS project without auto-formatting on commit. I'd recommend setting up Husky + lint-staged + Prettier so every commit gets automatically formatted. This pairs well with `/commit` since the formatting runs as a pre-commit hook. Want me to set it up?"

**If the user says yes:**

```bash
# Install dev dependencies
npm install -D prettier husky lint-staged

# Initialize husky
npx husky init
```

Create `.husky/pre-commit`:
```bash
npx lint-staged
```

Create `.prettierrc.json` with sensible defaults (adapt based on existing code style):
```json
{
  "semi": true,
  "singleQuote": false,
  "tabWidth": 2,
  "trailingComma": "es5",
  "printWidth": 120
}
```

Add lint-staged config to `package.json`:
```json
{
  "lint-staged": {
    "*.{ts,tsx,js,jsx}": [
      "prettier --write"
    ],
    "*.{json,css,md}": [
      "prettier --write"
    ]
  }
}
```

If ESLint is already installed, add it to the lint-staged pipeline before Prettier:
```json
{
  "lint-staged": {
    "*.{ts,tsx,js,jsx}": [
      "eslint --fix",
      "prettier --write"
    ],
    "*.{json,css,md}": [
      "prettier --write"
    ]
  }
}
```

**If the project already has auto-formatting**, or is not a JS/TS project, skip this step.

## Step 8: Configure GitHub Project Automations

Tell the user to manually configure these in the GitHub UI (Project Settings > Workflows):

1. **Auto-add**: When an issue is created in the repo, add it to this project
2. **Item closed**: When an issue is closed, set Status to Done
3. **Auto-archive**: Archive items in Done after 14 days

These cannot be set via the API.

## Step 9: Create Starter Views

Tell the user to create these views in the GitHub Project UI:

1. **Active Work** - Board layout, filter: `status:Ready,"In Progress"`
2. **Backlog** - Board layout, filter: `status:Backlog` (or `status:Todo`)
3. **Bugs** - Board layout, filter: `label:type:bug`
4. **Epics** - Table layout with hierarchy enabled

## Step 10: Verify Setup

Run verification checks:

```bash
# Verify project exists
gh project view $PROJECT_NUMBER --owner @me --format json

# Verify fields exist
gh project field-list $PROJECT_NUMBER --owner @me --format json

# Verify labels exist
gh label list --repo $REPO --json name

# Verify workflow.md has no remaining placeholders
grep -c '{{' .claude/workflow.md && echo "ERROR: Unresolved placeholders" || echo "OK: All placeholders resolved"

# Verify commands have no remaining placeholders
grep -rc '{{' .claude/commands/ && echo "ERROR: Unresolved placeholders in commands" || echo "OK: All command placeholders resolved"
```

## Step 11: Output Summary

Report to the user:

```
## Project Workflow Initialized

**Project:** {{PROJECT_NAME}} Roadmap (#N)
**Repo:** owner/name
**Board URL:** [link]

### Environment
- OS: [detected]
- git: [version]
- gh: [version]
- node: [version or "not installed"]
- supabase: [version or "not installed"]

### Created
- GitHub Project board with Status, Phase, Priority fields
- 17 labels (phase, type, priority, source)
- Workflow configuration in .claude/workflow.md
- 8 slash commands configured
- CLAUDE.md (generated or starter)
- Auto-format on commit (if configured): Husky + lint-staged + Prettier

### Manual Steps Required
1. Configure project automations (auto-add, item-closed, auto-archive) in GitHub UI
2. Create project views (Active Work, Backlog, Bugs, Epics) in GitHub UI
3. Review and customize CLAUDE.md
4. Write your first PRD with /create-prd
5. Add path-scoped rules in .claude/rules/ as your codebase grows
6. Add reference docs in .claude/docs/ for complex subsystems

### Ready to Use
- /prime         - Load project context
- /create-prd    - Write your PRD
- /plan-feature  - Plan a feature
- /execute       - Implement a plan
- /commit        - Commit with issue tracking
- /continue      - Resume next session
- /status        - Review progress
```

## Notes

- If `gh project create` fails, the user may need to enable Projects in their GitHub settings
- The Status field is created by default with options: Todo, In Progress, Done. "Backlog" and "Ready" may need to be added manually in the GitHub UI, or use "Todo" as the backlog equivalent
- Phase options can be added later as the project grows via `gh project field-edit`
- Area labels are intentionally NOT created here since they are project-specific. Add them as needed (e.g., `area:auth`, `area:dashboard`)
- On Windows, `winget` is the default package manager. If the user prefers Chocolatey (`choco`), adapt commands accordingly (e.g., `choco install gh git`)
- On WSL, use Linux install commands since WSL is a Linux environment
- On Windows, `uname -s` returns `MINGW64_NT-*` in Git Bash or `Linux` in WSL. Use this to pick the right install commands
