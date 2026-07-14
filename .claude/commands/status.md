---
description: "Review project progress from GitHub project board and milestones"
---

# Status: Project Progress Review

## Objective

Review current project state from the GitHub project board and open issues.

## Process

### 1. State (auto-gathered)

Board, open issues, and recently closed issues:
!`./.claude/scripts/board-state.sh`

Recent git activity:
!`git log --oneline -15; git status --porcelain`

### 2. Analyze Progress

From the gathered data, calculate:
- Issues per phase and how many are closed vs open
- Issues in each board status column (Backlog, Ready, In Progress, Done)
- High priority items that haven't been started

### 3. Report

Provide a concise summary:

**Phase Progress:**
- Phase N: X/Y complete (list phases with open issues)

**Board Status:**
| Status | Count | Issues |
|--------|-------|--------|
| In Progress | N | #X, #Y |
| Ready | N | #X, #Y |
| Backlog | N | ... |

**Recently Completed:**
- List issues closed in the last week

**Up Next (suggested):**
- Top 3 priority items from Backlog/Ready

**Blockers or Decisions Needed:**
- Any issues flagged as blocked or needing input

Keep the report scannable with bullet points, no prose.
