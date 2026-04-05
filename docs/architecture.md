# Floq-Claw Agent Architecture

## Overview

Floq-Claw is a 4-agent OpenClaw profile designed to automate product development for the Floq project. All work flows through Linear as the single source of truth, with GitHub as the code collaboration layer.

## Agents

| Agent | Emoji | Role | Thinking |
|-------|-------|------|----------|
| **Router** | 🚦 | Front-door orchestrator, task classifier, Linear coordinator | low |
| **Builder** | 🛠️ | Implementation owner — writes code, branches, PRs | xhigh |
| **Reviewer** | 🔬 | Principal engineer review gate — quality, security, correctness | xhigh |
| **Infra** | 🚂 | Railway infrastructure — deployments, services, environments | high |

## Communication Pattern: Hub-and-Spoke

```
                    ┌─────────────┐
                    │   Linear    │
                    │  (tickets)  │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
     ┌──────────────┤   Router    ├──────────────┐
     │              │     🚦      │              │
     │              └──────┬──────┘              │
     │                     │                     │
┌────▼─────┐        ┌─────▼──────┐       ┌──────▼─────┐
│ Builder  │        │  Reviewer  │       │   Infra    │
│   🛠️     │        │    🔬      │       │    🚂      │
└────┬─────┘        └─────┬──────┘       └──────┬─────┘
     │                    │                     │
     └────────────────────┴─────────────────────┘
                          │
                    ┌─────▼──────┐
                    │   GitHub   │
                    │  (PRs)     │
                    └────────────┘
```

**CRITICAL RULE**: Router orchestrates ALL communication. Agents NEVER talk to each other directly. This prevents deadlocks and keeps routing deterministic.

Flow is always: `Router → Agent → Router → Agent → Router`

## Task Classification & Pipelines

### Classification Dimensions

| Dimension | Values | Description |
|-----------|--------|-------------|
| **Scope** | Narrow / Bounded / Wide | How much code changes |
| **Ambiguity** | Obvious / Clear / Uncertain | How clear is the path |
| **Risk** | None / Low / High | Production impact |

### Three Pipelines

#### SMALL (builder only)
**When**: Narrow scope, obvious path, no/low risk (typo, config change, simple fix)

```
User → Router → Builder → Router → User
                  │
                  └──→ Linear (comment with result)
```

Files created: `status.md` only

#### MEDIUM (builder → reviewer)
**When**: Standard feature or bug fix, clear requirements

```
User → Router → Builder → Router → Reviewer → Router → User
                  │                    │
                  ├──→ GitHub PR       ├──→ GitHub PR review
                  └──→ Linear          └──→ Linear
```

If reviewer returns FAIL: `Router → Builder (fix) → Router → Reviewer (re-review)` (max 3 iterations)

Files created: `status.md`, `tasks.md`

#### BIG (spec → builder → reviewer)
**When**: Complex work, uncertain approach, wide scope, high risk

```
User → Router ──→ [Generate spec.md, tasks.md, tests.md]
                    │
                    ├──→ Builder (implement per spec)
                    │       │
                    │       ├──→ GitHub PR
                    │       └──→ Linear (progress updates)
                    │
                    ├──→ Reviewer (review against spec)
                    │       │
                    │       ├──→ GitHub PR review
                    │       └──→ Linear (review verdict)
                    │
                    └──→ [Review loop: max 3 iterations]
```

Files created: `spec.md`, `tasks.md`, `tests.md`, `status.md`

## Work Packet System

Every task gets a folder: `./shared/work/<LINEAR-ID>/`

```
./shared/work/FLOQ-42/
├── spec.md      # Technical specification (BIG tasks)
│                  - Problem statement, scope, acceptance criteria
│                  - Technical approach, architecture, risks
│
├── tasks.md     # Ordered task list (MEDIUM + BIG)
│                  - Checkboxes for progress tracking
│                  - Builder marks as complete during implementation
│
├── tests.md     # Test plan (BIG tasks)
│                  - Unit tests, integration tests, curl commands
│                  - Acceptance test checklist mapped to spec
│
├── status.md    # Current state (ALL tasks)
│                  - Owner, state, pipeline type
│                  - Timeline of state transitions
│                  - Links to branch, PR, Linear ticket
│
└── review.md    # Review findings (after reviewer runs)
                   - Verdict: PASS / WARN / FAIL
                   - Blocking issues, warnings, notes
```

## Linear Integration

Linear is the source of truth for all work. Every state transition is reflected in Linear.

### State mapping

| Agent Action | Linear State | Linear Comment |
|---|---|---|
| Router receives task | Backlog → In Progress | "Starting work on <ID>" |
| Builder starts coding | In Progress | "Builder working on branch: <name>" |
| Builder creates PR | In Progress | "PR created: <url>" |
| Reviewer starts review | In Review | "Reviewer analyzing PR" |
| Reviewer: FAIL | In Progress | "Review FAIL — N blocking issues" |
| Reviewer: PASS | Done | "Review PASS — approved and ready to merge" |

### Comment format

All agent comments on Linear follow this format:
```
**[Agent Name 🚦]** <action>

<details if relevant>
```

## GitHub Integration

### Branch naming
```
builder/<LINEAR-ID>-<short-slug>
```
Example: `builder/FLOQ-42-add-user-auth`

### PR format
```
## Summary
<what and why>

## Changes
<key files changed>

## Linear Ticket
FLOQ-42: Add user authentication

## Test Plan
<verification steps>
```

### Review flow on GitHub
- PASS → `gh pr review --approve`
- WARN → `gh pr review --comment`
- FAIL → `gh pr review --request-changes`

## Infrastructure (Railway)

The Infra agent manages Railway deployments:

- **Deployments**: Deploy, monitor, rollback services
- **Environments**: Manage env vars across staging/production
- **Services**: Create, configure, monitor Railway services
- **Databases**: PostgreSQL, Redis provisioning and management
- **Networking**: Custom domains, internal service communication

### Railway config files
- `railway.toml` — Build and deploy configuration
- `Procfile` — Process type definitions
- `nixpacks.toml` — Build system configuration

## Security Rules

1. Never commit secrets to git (API keys, tokens, passwords)
2. Linear API key stored in `.linear-api-key` (gitignored)
3. All PR changes reviewed before merge
4. Security violations in review = automatic FAIL
5. Production infrastructure changes require explicit confirmation
6. Environment variables never logged or echoed

## Error Recovery

| Level | Action |
|-------|--------|
| 1 | Retry with error context |
| 2 | Rollback to git checkpoint (builder) |
| 3 | Escalate to router with summary of attempts |
| 4 | Router escalates to user |

Review loop caps at 3 iterations. If builder can't fix reviewer's findings after 3 tries, router escalates to user.

## Design Principles

These choices are informed by production patterns from Anthropic, CrewAI, OpenHands, and Composio:

1. **Hub-and-spoke over peer-to-peer**: Router coordinates all communication. Prevents deadlocks, keeps routing deterministic, makes debugging simple.

2. **Linear as source of truth**: All state lives in Linear. Work packets are local caches for agent context. If Linear and local state diverge, Linear wins.

3. **Spec-driven development for big tasks**: Complex work gets a spec before any code is written. This catches requirement gaps early and gives reviewer clear acceptance criteria.

4. **Deterministic pipeline selection**: Router classifies tasks based on scope/ambiguity/risk — not agent-decided. Phase transitions are rule-based.

5. **Bounded iteration**: Review loops cap at 3 attempts. Prevents infinite loops and escalates stuck work to humans.

6. **One feature per session**: Builder handles one task per session to prevent context exhaustion. Fresh context for each delegation.

7. **Everything visible**: All state changes appear in Linear comments, GitHub PRs, and local work packets. Nothing happens "in the dark."
