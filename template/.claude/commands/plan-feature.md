---
description: "Create comprehensive feature plan with deep codebase analysis and research"
---

# Plan a new task

## Feature: $ARGUMENTS

## Mission

Transform a feature request into a **comprehensive implementation plan** through systematic codebase analysis, external research, and strategic planning.

**Core Principle**: We do NOT write code in this phase. Our goal is to create a context-rich implementation plan that enables one-pass implementation success for ai agents.

**Key Philosophy**: Context is King. The plan must contain ALL information needed for implementation - patterns, mandatory reading, documentation, validation commands - so the execution agent succeeds on the first attempt.

## Planning Process

### Phase 0: Project Board & PRD Context

- Fetch open issues and project board state:
  - `gh issue list --repo {{REPO_OWNER}}/{{REPO_NAME}} --state open --json number,title,labels,state --limit 50`
  - `gh project item-list {{PROJECT_NUMBER}} --owner @me --format json`
- Check if a GitHub issue already exists for this feature
- Read the PRD at `.claude/PRD.md` (the standard location). If it doesn't exist, search for PRDs in common locations (`docs/`, project root) and tell the user: "No PRD found at `.claude/PRD.md`. I found `{path}` — run `/create-prd` to create the standard PRD from it."
- Identify where the requested feature sits in the project roadmap (which phase, which item)
- Check if there are dependencies on other features that aren't done yet
- Note any related completed work that provides context

### Phase 1: Feature Understanding

**Deep Feature Analysis:**

- Extract the core problem being solved
- Identify user value and business impact
- Determine feature type: New Capability/Enhancement/Refactor/Bug Fix
- Assess complexity: Low/Medium/High
- Map affected systems and components

**Create User Story Format Or Refine If Story Was Provided By The User:**

```
As a <type of user>
I want to <action/goal>
So that <benefit/value>
```

### Phase 2: Clarify Ambiguities

Scouts are about to be spawned in parallel — an ambiguity discovered after the fan-out invalidates their work. Resolve open questions now, before spending scout effort:

- If requirements are unclear at this point, ask the user to clarify before you continue
- Get specific implementation preferences (libraries, approaches, patterns)
- Resolve architectural decisions before proceeding

### Phase 3: Parallel Intelligence Gathering (scout fan-out)

Research runs as three concurrent scout subagents. **Spawn all three as `Agent` tool calls in a single message so they run concurrently** — listing them as sequential steps serializes them.

**Subagents see none of this conversation.** Each prompt must be self-contained: include the feature name, a one-paragraph description, the user story, and any constraints established in Phases 0–1. End every prompt with: *"Your final message is your report — return the structured findings, not a narrative of your process."*

**Scout 1 — Codebase patterns** (`subagent_type: Explore`)

Ask it to investigate and report:

- Project structure: primary language(s), frameworks, runtime versions, directory/architectural patterns, config files, build processes
- Similar implementations of comparable features, with file:line references
- Coding conventions — naming, file organization, error handling, logging — as verbatim snippets from the codebase
- Integration points: existing files the feature must update, where new files belong, registration patterns (routers, models, auth) if applicable
- Anti-patterns to avoid
- Project rules: instruct it to read CLAUDE.md and any path-scoped rules in `.claude/rules/` (Explore skips these by default)

Required report format: files with line ranges + why each matters; verbatim pattern snippets; integration-point list.

**Scout 2 — External research** (`subagent_type: general-purpose`)

Ask it to research and report:

- Current versions and best practices for libraries relevant to the feature
- Official documentation links with specific section anchors
- Implementation examples and tutorials
- Common gotchas, known issues, breaking changes, migration guides

Required report format: links with section anchors + "Why" per link; a "verified facts" list (claims confirmed against docs, not assumed).

**Scout 3 — Testing patterns** (`subagent_type: Explore`)

Ask it to investigate and report:

- Test framework and organization (unit vs integration), coverage standards
- Exemplar test files to mirror, with file:line references
- Runnable validation commands discovered from project config (lint, typecheck, test invocations) — exact and non-interactive
- `.claude/docs/` reference docs: read the header of each file (Purpose, When to use, Size) and report which are relevant to this feature

Required report format: exemplar files with line refs; exact validation commands; relevant reference-doc list.

### Phase 4: Synthesis & Deep Strategic Thinking

**Wait for all three scout reports before proceeding.** Then synthesize:

- Cross-check the reports against each other; note and resolve conflicts
- **Spot-check load-bearing claims**: before a scout's file:line reference becomes a cornerstone of the plan, read those lines yourself
- If a scout returned thin or no findings, note the gap instead of inventing citations — do targeted follow-up reads yourself
- If the scouts uncovered new ambiguities, ask the user now — before writing the plan

**Think Harder About:**

- How does this feature fit into the existing architecture?
- What are the critical dependencies and order of operations?
- What could go wrong? (Edge cases, race conditions, errors)
- How will this be tested comprehensively?
- What performance implications exist?
- Are there security considerations?
- How maintainable is this approach?

**Design Decisions:**

- Choose between alternative approaches with clear rationale
- Design for extensibility and future modifications
- Plan for backward compatibility if needed
- Consider scalability implications

### Phase 5: Plan Structure Generation

**Create comprehensive plan with the following structure:**

What's below here is a template for you to fill for the implementation agent:

````markdown
# Feature: <feature-name>

The following plan should be complete, but its important that you validate documentation and codebase patterns and task sanity before you start implementing.

Pay special attention to naming of existing utils types and models. Import from the right files etc.

## Feature Description

<Detailed description of the feature, its purpose, and value to users>

## User Story

As a <type of user>
I want to <action/goal>
So that <benefit/value>

## Problem Statement

<Clearly define the specific problem or opportunity this feature addresses>

## Solution Statement

<Describe the proposed solution approach and how it solves the problem>

## Feature Metadata

**Feature Type**: [New Capability/Enhancement/Refactor/Bug Fix]
**Estimated Complexity**: [Low/Medium/High]
**Primary Systems Affected**: [List of main components/services]
**Dependencies**: [External libraries or services required]

---

## CONTEXT REFERENCES

### Relevant Codebase Files IMPORTANT: YOU MUST READ THESE FILES BEFORE IMPLEMENTING!

<List files with line numbers and relevance>

- `path/to/file.py` (lines 15-45) - Why: Contains pattern for X that we'll mirror
- `path/to/model.py` (lines 100-120) - Why: Database model structure to follow
- `path/to/test.py` - Why: Test pattern example

### New Files to Create

- `path/to/new_service.py` - Service implementation for X functionality
- `path/to/new_model.py` - Data model for Y resource
- `tests/path/to/test_new_service.py` - Unit tests for new service

### Relevant Documentation YOU SHOULD READ THESE BEFORE IMPLEMENTING!

- [Documentation Link 1](https://example.com/doc1#section)
  - Specific section: Authentication setup
  - Why: Required for implementing secure endpoints
- [Documentation Link 2](https://example.com/doc2#integration)
  - Specific section: Database integration
  - Why: Shows proper async database patterns

### Patterns to Follow

<Specific patterns extracted from codebase - include actual code examples from the project>

**Naming Conventions:** (for example)

**Error Handling:** (for example)

**Logging Pattern:** (for example)

**Other Relevant Patterns:** (for example)

---

## INTEGRATION CONTRACTS

<If the feature spans multiple components (backend + frontend, service + client, ...), this section is the AUTHORITATIVE interface definition: all components MUST conform to it exactly, and the executor verifies alignment before integration. If the feature is single-component, state: "Single-component feature — no cross-component contracts." and delete the subsections below.>

### Component Boundaries

<Partition the files so every path has exactly one owner.>

| Component | Owns (files/dirs) | Must Not Touch |
| --------- | ----------------- | -------------- |
| backend   | `api/`, `models/` | `web/`         |
| frontend  | `web/`            | `api/`, `models/` |

### Interface Contract

<Exact endpoints or public function signatures. URLs exact, INCLUDING trailing slashes — `POST /api/things/` and `POST /api/things` are different contracts.>

| Method | Endpoint (exact) | Request Body | Response |
| ------ | ---------------- | ------------ | -------- |
| POST | `/api/things/` | `{"name": "..."}` | `ThingResponse` (200) |
| GET | `/api/things/{id}` | — | `{"thing": ThingResponse}` (200) or 404 |

### Data Shapes

<Named shapes as explicit JSON, not prose. Call out flat vs nested envelopes — consumers must know exactly what to destructure.>

**ThingResponse:**

```json
{ "id": "uuid", "name": "string", "created_at": "ISO8601" }
```

### Events / Streaming

<Every event/message type with exact JSON, or "None.">

### Error Shapes

<Status codes + error body format per failure mode (404 body, 422 body, ...).>

### State & Storage Semantics

<Explicit semantics wherever components could diverge (e.g., streamed chunks accumulated into one row vs stored per-chunk).>

### Cross-Cutting Concerns

<Behaviors spanning components. Each concern is assigned to exactly ONE owner.>

| Concern | Owner | Coordinates With | Detail |
| ------- | ----- | ---------------- | ------ |
| URL conventions | backend | frontend | Trailing slashes on collection endpoints; frontend fetch URLs must match exactly |

---

## OBSERVABLE TRUTHS

<Define what "done" looks like before diving into tasks. These are the measurable outcomes that prove the feature works.>

- When a user does X, they see Y
- The database contains Z after the action completes
- The API returns status 200 with shape {...}

## REQUIRED ARTIFACTS

<List every file, migration, config change, or resource that must exist when this feature is complete.>

- [ ] `path/to/new_file.ts` - Description of purpose
- [ ] `supabase/migrations/YYYYMMDD_name.sql` - Migration for X
- [ ] Updated `path/to/existing_file.ts` - Added Y functionality

## KEY LINKS

<External references the implementation agent needs during execution.>

- PRD section: `.claude/PRD.md` section 7.X
- GitHub issue: #NN
- Relevant docs: [Link](url) - Why it matters
- Design reference: Screenshot or mockup location

---

## IMPLEMENTATION PLAN

### Phase 1: Foundation

<Describe foundational work needed before main implementation>

**Tasks:**

- Set up base structures (schemas, types, interfaces)
- Configure necessary dependencies
- Create foundational utilities or helpers

### Phase 2: Core Implementation

<Describe the main implementation work>

**Tasks:**

- Implement core business logic
- Create service layer components
- Add API endpoints or interfaces
- Implement data models

### Phase 3: Integration

<Describe how feature integrates with existing functionality>

**Tasks:**

- Connect to existing routers/handlers
- Register new components
- Update configuration files
- Add middleware or interceptors if needed

### Phase 4: Testing & Validation

<Describe testing approach>

**Tasks:**

- Implement unit tests for each component
- Create integration tests for feature workflow
- Add edge case tests
- Validate against acceptance criteria

---

## STEP-BY-STEP TASKS

IMPORTANT: Execute every task in order, top to bottom. Each task is atomic and independently testable.

### Task Format Guidelines

Use information-dense keywords for clarity:

- **CREATE**: New files or components
- **UPDATE**: Modify existing files
- **ADD**: Insert new functionality into existing code
- **REMOVE**: Delete deprecated code
- **REFACTOR**: Restructure without changing behavior
- **MIRROR**: Copy pattern from elsewhere in codebase

### {ACTION} {target_file}

- **IMPLEMENT**: {Specific implementation detail}
- **PATTERN**: {Reference to existing pattern - file:line}
- **IMPORTS**: {Required imports and dependencies}
- **GOTCHA**: {Known issues or constraints to avoid}
- **VALIDATE**: `{executable validation command}`
- **VERIFY**: {Observable proof this task is correct}
- **DONE**: {Concrete artifact or state that marks completion}

<Continue with all tasks in dependency order...>

---

## TESTING STRATEGY

<Define testing approach based on project's test framework and patterns discovered during research>

### Unit Tests

<Scope and requirements based on project standards>

### Integration Tests

<Scope and requirements based on project standards>

### Edge Cases

<List specific edge cases that must be tested for this feature>

---

## VALIDATION COMMANDS

<Define validation commands based on project's tools discovered in Phase 2>

Execute every command to ensure zero regressions and 100% feature correctness.

### Level 1: Syntax & Style

<Project-specific linting and formatting commands>

### Level 2: Unit Tests

<Project-specific unit test commands>

### Level 3: Integration Tests

<Project-specific integration test commands>

### Level 4: Manual Validation

<Feature-specific manual testing steps - API calls, UI testing, etc.>

---

## ACCEPTANCE CRITERIA

<List specific, measurable criteria that must be met for completion>

- [ ] Feature implements all specified functionality
- [ ] All validation commands pass with zero errors
- [ ] Code follows project conventions and patterns
- [ ] No regressions in existing functionality
- [ ] Documentation is updated (if applicable)
- [ ] Performance meets requirements (if applicable)
- [ ] Security considerations addressed (if applicable)

---

## COMPLETION CHECKLIST

- [ ] All tasks completed in order
- [ ] Each task validation passed immediately
- [ ] All validation commands executed successfully
- [ ] Full test suite passes
- [ ] No linting or type checking errors
- [ ] Manual testing confirms feature works
- [ ] Acceptance criteria all met
- [ ] Code reviewed for quality and maintainability

---

## NOTES

<Additional context, design decisions, trade-offs>
````

## Output Format

**Filename**: `.agents/plans/{kebab-case-descriptive-name}.md`

- Replace `{kebab-case-descriptive-name}` with short, descriptive feature name
- Examples: `add-user-authentication.md`, `implement-search-api.md`, `refactor-database-layer.md`

**Directory**: Create `.agents/plans/` if it doesn't exist

## Quality Criteria

### Context Completeness

- [ ] All necessary patterns identified and documented
- [ ] External library usage documented with links
- [ ] Integration points clearly mapped
- [ ] Gotchas and anti-patterns captured
- [ ] Every task has executable validation command
- [ ] Scout reports synthesized; load-bearing file:line claims spot-checked

### Contract Completeness

- [ ] Interface URLs exact, including trailing slashes
- [ ] Data shapes as explicit JSON with flat-vs-nested envelopes called out
- [ ] Events and error shapes specified
- [ ] Every cross-cutting concern has exactly one owner
- [ ] Single-component plans state "no cross-component contracts" explicitly

### Implementation Ready

- [ ] Another developer could execute without additional context
- [ ] Tasks ordered by dependency (can execute top-to-bottom)
- [ ] Each task is atomic and independently testable
- [ ] Pattern references include specific file:line numbers

### Pattern Consistency

- [ ] Tasks follow existing codebase conventions
- [ ] New patterns justified with clear rationale
- [ ] No reinvention of existing patterns or utils
- [ ] Testing approach matches project standards

### Information Density

- [ ] No generic references (all specific and actionable)
- [ ] URLs include section anchors when applicable
- [ ] Task descriptions use codebase keywords
- [ ] Validation commands are non interactive executable

## Success Metrics

**One-Pass Implementation**: Execution agent can complete feature without additional research or clarification

**Validation Complete**: Every task has at least one working validation command

**Context Rich**: The Plan passes "No Prior Knowledge Test" - someone unfamiliar with codebase can implement using only Plan content

**Confidence Score**: #/10 that execution will succeed on first attempt

## Report

After creating the Plan:

1. **Create or update a GitHub feature issue:**

   - If an issue already exists: comment on it with a link to the plan file
   - If no issue exists, write the body (acceptance criteria as checkboxes) to a temp file, then one call does everything — create, labels, board add, field set, epic link:
     ```bash
     ./.claude/scripts/create-issue.sh \
       --title "<feature title>" \
       --body-file <path-to-body> \
       --labels "phase:N,type:feature,priority:X" \
       --phase "Phase N" --priority High --status Ready \
       --parent <phase-epic-number>   # omit if no epic applies
     ```
   - If the feature belongs to a phase but no Phase Epic exists yet, ask the user if they want to create one

2. **Create task sub-issues (for larger features):**

   If the plan has 5+ implementation steps, create task sub-issues under the feature issue for granular progress tracking. Do this automatically without asking. Each task sub-issue maps to a major step in the plan:

   ```bash
   ./.claude/scripts/create-issue.sh --title "Task: <step>" --body-file <path> \
     --labels "phase:N,type:infra,priority:X" --phase "Phase N" --status Ready \
     --parent <feature-issue-number>
   ```

   This gives automatic progress tracking (the feature issue shows "3/7 complete"). For smaller features (under 5 steps), skip this and just use the AC checkboxes on the feature issue.

3. Provide:
   - Summary of feature and approach
   - Full path to created Plan file
   - GitHub issue reference (e.g., "This implements GH #61")
   - Complexity assessment
   - Key implementation risks or considerations
   - Estimated confidence score for one-pass success
