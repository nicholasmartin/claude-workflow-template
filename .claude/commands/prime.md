---
description: Prime agent with codebase understanding
---

# Prime: Load Project Context

## Objective

Build comprehensive understanding of the codebase by analyzing structure, documentation, and key files.

## Process

### 1. Analyze Project Structure

List all tracked files:
!`git ls-files`

Show directory structure (use `tree` if installed, otherwise fall back to `find`):

- With `tree`: `tree -L 3 -I 'node_modules|__pycache__|.git|dist|build'`
- Fallback (no `tree`): `find . -type d -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/dist/*' -not -path '*/build/*' -not -path '*/__pycache__/*' | head -50`

### 2. Read Core Documentation

- Read PRD files in `.claude/` directory
- Read CLAUDE.md or similar global rules file
- Read README files at project root and major directories
- Note `.claude/docs/` contains reference docs with scout-friendly headers. Read headers to assess relevance, load full docs only if needed.
- Note: For active work and issue tracking, use `/continue` instead

### 3. Identify Key Files

Based on the structure, identify and read:

- Main entry points (main.py, index.ts, app.py, etc.)
- Core configuration files (pyproject.toml, package.json, tsconfig.json)
- Key model/schema definitions
- Important service or controller files

### 4. Understand Current State

Check recent activity:
!`git log -10 --oneline`

Check current branch and status:
!`git status`

## Output Report

Provide a concise summary covering:

### Project Overview

- Purpose and type of application
- Primary technologies and frameworks
- Current version/state

### Architecture

- Overall structure and organization
- Key architectural patterns identified
- Important directories and their purposes

### Tech Stack

- Languages and versions
- Frameworks and major libraries
- Build tools and package managers
- Testing frameworks

### Core Principles

- Code style and conventions observed
- Documentation standards
- Testing approach

### Current State

- Active branch
- Recent changes or development focus
- Any immediate observations or concerns

**Make this summary easy to scan - use bullet points and clear headers.**
