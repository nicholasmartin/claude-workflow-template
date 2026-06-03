# Execute Team

The multi-agent build executor for this workflow. Give it a plan and it spawns a team
of Claude Code agents that build different layers in parallel, coordinated by a lead,
with the GitHub board kept in sync — the parallel counterpart to `/execute`.

Adapted from [Cole Medin's `build-with-agent-team` skill](https://github.com/coleam00/context-engineering-intro/tree/main/use-cases/build-with-agent-team),
trimmed for our workflow: **single view** (no tmux), board lifecycle baked in, and
contracts sourced from the plan.

## Usage

```
/execute-team [plan-path] [num-agents]
```

| Parameter    | Required | Description                                            |
| ------------ | -------- | ------------------------------------------------------ |
| `plan-path`  | Yes      | Path to the plan (ideally produced by `/plan-feature`) |
| `num-agents` | No       | Team size; inferred from the plan if omitted           |

## When to use it

- **/execute** — single domain, sequential, one agent carries the plan top to bottom.
- **/execute-team** — multiple components integrating across boundaries (frontend +
  backend + database), parallelizable, where agents must agree on interfaces.

`/plan-feature` recommends which executor fits a given plan.

## Prerequisites

Agent teams are an **experimental** Claude Code feature. Enable it in
`~/.claude/settings.json`:

```json
{ "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" } }
```

We run in **single view** — no tmux and no split panes required.

> This is a test-branch feature and platform support for agent teams is still
> evolving. If a build won't spawn a team in your environment, fall back to `/execute`.

## What it does

1. Links the plan to its GitHub issue and moves it to In Progress
2. Pre-flight checks (clean tree, deps, env)
3. Lead reads or authors the integration contracts and assigns cross-cutting concerns
4. Spawns agents in parallel (single view), each with its contract slice
5. Facilitates: relays contract changes, runs a contract diff, cross-review
6. Agent-level + lead end-to-end validation
7. Updates the issue and hands off to `/commit`

## Plan format

Works best with contract-rich plans. See
[`example-plan/session-manager-plan.md`](example-plan/session-manager-plan.md) for the
shape: explicit API contracts, response shapes, cross-cutting concerns, and per-layer
plus end-to-end validation. Once the matching `/plan-feature` changes land, the planner
produces plans in this form.
