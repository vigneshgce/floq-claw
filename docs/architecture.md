# Floq-Claw Agent Architecture

## Overview

Floq-Claw is a 5-agent OpenClaw profile designed to automate product development for the Floq project. All work flows through Linear as the single source of truth, with GitHub as the code collaboration layer.

## Agents

| Agent | Emoji | Role | Thinking |
|-------|-------|------|----------|
| **Router** | 🚦 | Front-door orchestrator, task classifier, Linear coordinator | low |
| **Architect** | 🧠 | CTO-level technical grooming and specification | xhigh |
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
     │              └──┬──────┬───┘              │
     │                 │      │                  │
┌────▼─────┐  ┌───────▼──┐ ┌─▼────────┐  ┌──────▼─────┐
│Architect │  │ Builder  │ │ Reviewer │  │   Infra    │
│   🧠     │  │   🛠️     │ │    🔬    │  │    🚂      │
└────┬─────┘  └───────┬──┘ └─┬────────┘  └──────┬─────┘
     │                │      │                   │
     │                └──────┴───────────────────┘
     │                       │
     │                ┌──────▼─────┐
     │                │   GitHub   │
     │                │   (PRs)    │
     │                └────────────┘
     │
     └──→ Shared Work Packets
          (spec.md, tasks.md, tests.md)
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

Files created: `status.md` only. No design needed.

#### MEDIUM (architect → builder → reviewer)
**When**: Standard feature or bug fix, clear requirements

```
User → Router → Architect → Router → Builder → Router → Reviewer → Router → User
                  │                    │                    │
                  └──→ tasks.md        ├──→ GitHub PR       ├──→ GitHub PR review
                                       └──→ Linear          └──→ Linear
```

Architect does **light grooming**: reads ticket + relevant code, produces `tasks.md` with ordered implementation steps.

Builder runs **build-time verification** (lint + test + API checks) before creating PR. Self-corrects from failures (max 3 attempts).

Reviewer validates builder's verification evidence (reads verify-results.md, flags coverage gaps).

If reviewer returns FAIL: `Router → Builder (fix) → Router → Reviewer (re-review)` (max 3 iterations)

After review PASS, Router can optionally trigger **post-deploy verification** via Infra (health + smoke tests + log check).

Files created: `status.md`, `tasks.md` (by architect), `verify-results.md` (by builder/reviewer/infra), `review.md` (by reviewer)

#### BIG (architect → builder → reviewer)
**When**: Complex work, uncertain approach, wide scope, high risk

```
User → Router → Architect ──→ [spec.md, tasks.md, tests.md]
                  │                │
                  │    (if NEEDS_INPUT: questions → user → resume)
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
                  ├──→ [Review loop: max 3 iterations]
                  │
                  └──→ Infra (post-deploy verification: health + smoke + logs)
```

Architect does **full grooming**: 6-step codebase analysis, 7-point readiness checklist, produces all three artifacts. May ask structured questions before reaching READY state.

Builder runs **full verification** (lint + test + API + DB + UI if applicable) before PR. Self-corrects (max 3 attempts).

Reviewer validates builder's verification coverage (does NOT re-run tests — builder already did).

After merge + deploy, Infra runs **post-deploy verification** (health + smoke tests from tests.md + log check).

Files created: `spec.md`, `tasks.md`, `tests.md` (by architect), `status.md`, `verify-results.md` (by builder/reviewer/infra), `review.md` (by reviewer)

## Architect: Design-First Development

The Architect agent ensures design work happens before implementation — never during it. This separation means:

- **Builder never guesses** — it implements from clear specs and task lists
- **Reviewer has acceptance criteria** — it reviews against the spec, not just code quality
- **Questions surface early** — before code is written, not during review

### Architect Operating Modes

| Mode | Trigger | Output |
|------|---------|--------|
| **Light Groom** | MEDIUM tasks | `tasks.md` + lightweight ANALYSIS.md |
| **Full Groom** | BIG tasks | `spec.md` + `tasks.md` + `tests.md` + full ANALYSIS.md |
| **Resume** | User answers architect's questions | Completes spec from where it left off |
| **Refine** | "Change the approach for X" | Targeted spec updates |

### Architect Notes (Per-Ticket)

Architect stores working analysis at `./architect/notes/<TICKET_ID>/`:

```
architect/notes/<TICKET_ID>/
  ANALYSIS.md    — Raw codebase findings (files traced, dependencies, patterns)
  QUESTIONS.md   — Open/answered questions with timestamps
  TECH_SPEC.md   — Working draft spec (before promoting to shared work packet)
```

These notes persist across sessions — architect picks up where it left off when resuming.

### Readiness Checklist (BIG tasks)

All 7 criteria must pass before architect marks READY:
1. Clear problem statement
2. Testable acceptance criteria
3. Identified repos and services
4. Feasible approach
5. No blocking questions
6. Documented risks with mitigations
7. Specified contracts (API/schema/events)

## Verification Architecture: Build → Run → See → Fix

Agents don't just build features — they verify them at runtime, see the output, and self-correct. This creates a feedback loop at every stage.

### 3-Layer Verification

| Layer | Owner | When | What | Feedback Loop |
|-------|-------|------|------|---------------|
| **Build-time** | Builder | After implementation, before PR | Lint, tests, API checks, DB verification, UI checks, log analysis | Parse failures → fix code → re-run (max 3 attempts) |
| **Review-time** | Reviewer | During PR review | Validate builder's verify-results.md, flag coverage gaps | Gaps or suspicious fixes flagged in review.md |
| **Post-deploy** | Infra | After merge + deployment | Health check, smoke tests, production log check | Failures trigger alert to user via Router |

### Verification Flow (BIG pipeline)

```
Builder implements
  │
  ├─→ Lint/Typecheck ─→ Failures? ─→ Fix → Re-lint
  ├─→ Test suite ────→ Failures? ─→ Fix → Re-test
  ├─→ API tests (curl against dev server) ─→ Wrong response? ─→ Fix → Re-test
  ├─→ DB verification (migrations, schema, data round-trip) ─→ Mismatch? ─→ Fix
  ├─→ UI verification (DOM snapshot or screenshot) ─→ Wrong state? ─→ Fix
  └─→ Log analysis (parse errors from dev server) ─→ Errors? ─→ Fix
  │
  ▼
Write verify-results.md → Create PR
  │
  ▼
Reviewer reads verify-results.md
  ├─→ Validate verification coverage (did builder test what matters?)
  ├─→ Flag gaps (change touches X but no X verification)
  └─→ Record verification assessment in review.md
  │
  ▼
Merge → Deploy
  │
  ▼
Infra post-deploy verification
  ├─→ Health endpoint check
  ├─→ Smoke tests (read-only subset of tests.md against production)
  └─→ Log check (errors in last 5 minutes)
  │
  ▼
Results → verify-results.md → Linear "Done"
```

### Verification Artifact: verify-results.md

Every work packet gets a `verify-results.md` that records:
- What was verified (lint, tests, API, DB, UI, logs)
- Exact commands run and their output
- Self-correction attempts (failure → fix → re-run)
- Blockers (tools unavailable, server won't start)
- Overall verdict (PASS/FAIL)

This file is cumulative — Builder writes build-time results, Reviewer appends review-time results, Infra appends post-deploy results.

### UI Verification Approaches

| Approach | How | When to Use |
|----------|-----|-------------|
| **DOM/Accessibility snapshot** | Playwright captures accessibility tree as JSON text | Default for any UI change — lightweight, deterministic |
| **Screenshot + Vision** | Playwright takes screenshot, vision model analyzes | Critical UI features where visual correctness matters |

### Self-Correction Loop

```
Attempt 1: Run verification
  → If PASS: proceed to PR
  → If FAIL: parse error, identify root cause, fix code

Attempt 2: Re-run verification
  → If PASS: proceed to PR
  → If FAIL: parse error, fix code

Attempt 3: Final attempt
  → If PASS: proceed to PR
  → If FAIL: create PR anyway, document all failures in verify-results.md
```

Max 3 attempts prevents infinite loops. If builder can't self-correct after 3 tries, the failures are visible in verify-results.md for reviewer and user to see.

## Context Preservation (Zero Loss Between Agents)

All context passes through **shared work packet files** — never through message summaries alone.

| Handoff | Context Medium | What's Preserved |
|---------|---------------|-----------------|
| Router → Architect | Linear ticket + work folder path | Problem statement, requirements, discussion |
| Architect → Builder | `spec.md` + `tasks.md` + `tests.md` | Full design, acceptance criteria, task order |
| Builder → Reviewer | `spec.md` + `verify-results.md` + PR URL in `status.md` | Spec for criteria, verification evidence to validate, PR for diff |
| Reviewer → Builder (fix) | `review.md` in shared folder | Blocking issues, verification gaps, specific file/line refs |
| Router → Infra (post-deploy) | `tests.md` (smoke tests section) + `status.md` | What to verify against live service |
| Any agent → Any agent | `status.md` | Current state, owner, timeline, links |
| All verification agents | `verify-results.md` | Cumulative verification evidence across all phases |
| Architect resume | `architect/notes/<TICKET_ID>/` | ANALYSIS.md, QUESTIONS.md — full continuity |

### Active Work Queue

`./shared/active.md` tracks all work in progress:

```
| Work ID | Owner | State | Last Updated (UTC) | Branch/PR Links |
```

States flow: `grooming` → `designed`/`groomed` → `in_progress` → `review_pending` → `done`

## Work Packet System

Every task gets a folder: `./shared/work/<LINEAR-ID>/`

```
./shared/work/FLOQ-42/
├── spec.md              # Technical specification (BIG tasks — by Architect)
│                          - Problem statement, scope, acceptance criteria
│                          - Technical approach, decisions with rationale
│                          - Contract changes, files to modify, test plan
│
├── tasks.md             # Ordered task list (MEDIUM + BIG — by Architect)
│                          - Checkboxes for progress tracking
│                          - Builder marks as complete during implementation
│
├── tests.md             # Test plan (BIG tasks — by Architect)
│                          - Unit tests, integration tests, curl commands
│                          - Smoke tests for post-deploy verification
│                          - Acceptance test checklist mapped to spec
│
├── status.md            # Current state (ALL tasks — updated by all agents)
│                          - Owner, state, pipeline type
│                          - Timeline of state transitions
│                          - Links to branch, PR, Linear ticket
│
├── verify-results.md    # Verification evidence (by Builder, Reviewer, Infra)
│                          - Lint/typecheck, test suite, API tests
│                          - DB verification, UI verification, log analysis
│                          - Self-correction attempts and outcomes
│                          - Post-deploy smoke test results
│
└── review.md            # Review findings (by Reviewer)
                           - Verdict: PASS / WARN / FAIL
                           - Verification evidence (independent re-execution)
                           - Blocking issues, warnings, notes
```

## Linear Integration

Linear is the source of truth for all work. Every state transition is reflected in Linear.

### State mapping

| Agent Action | Linear State | Linear Comment |
|---|---|---|
| Router receives task | Backlog → In Progress | "Starting work on <ID>" |
| Architect grooming | In Progress | "🧠 Technical grooming initiated" |
| Architect spec ready | In Progress | "Tech spec ready — starting implementation" |
| Builder starts coding | In Progress | "Builder working on branch: <name>" |
| Builder creates PR | In Progress | "🔗 PR created: <url>" |
| Reviewer starts review | In Review | "Reviewer analyzing PR" |
| Reviewer: FAIL | In Progress | "Review FAIL — N blocking issues" |
| Reviewer: PASS | Done | "✅ Review PASS — approved and ready to merge" |

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

1. **Hub-and-spoke over peer-to-peer**: Router coordinates all communication. Prevents deadlocks, keeps routing deterministic, makes debugging simple.

2. **Design before implementation**: Architect grooms every non-trivial task. Builder never guesses — it follows specs and task lists produced by someone who read the codebase first.

3. **Linear as source of truth**: All state lives in Linear. Work packets are local caches for agent context. If Linear and local state diverge, Linear wins.

4. **Context through files, not messages**: Every agent handoff goes through shared work packet files. No context lives only in message history. This is how zero context loss is achieved.

5. **Deterministic pipeline selection**: Router classifies tasks based on scope/ambiguity/risk — not agent-decided. Phase transitions are rule-based.

6. **Bounded iteration**: Review loops cap at 3 attempts. Prevents infinite loops and escalates stuck work to humans.

7. **One feature per session**: Builder handles one task per session to prevent context exhaustion. Fresh context for each delegation.

8. **Everything visible**: All state changes appear in Linear comments, GitHub PRs, and local work packets. Nothing happens "in the dark."
