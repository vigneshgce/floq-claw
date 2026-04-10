# Floq-Claw Architecture

> **5-agent OpenClaw profile for autonomous product development**
> Design, build, verify, review, and deploy — orchestrated through Linear and GitHub.

---

## Table of Contents

- [System Overview](#system-overview)
- [The 5 Agents](#the-5-agents)
- [Hub-and-Spoke Orchestration](#hub-and-spoke-orchestration)
- [Task Classification](#task-classification)
- [Pipeline Flows](#pipeline-flows)
- [Architect: Design-First Development](#architect-design-first-development)
- [Verification: Build, Run, See, Fix](#verification-build-run-see-fix)
- [Context Preservation](#context-preservation)
- [Work Packet System](#work-packet-system)
- [Linear Integration](#linear-integration)
- [GitHub Integration](#github-integration)
- [Infrastructure (Railway)](#infrastructure-railway)
- [Security](#security)
- [Error Recovery & Escalation](#error-recovery--escalation)
- [Design Principles](#design-principles)
- [Project Structure](#project-structure)

---

## System Overview

```
                         ┌──────────────────────────────────────────────────┐
                         │                   FLOQ-CLAW                     │
                         │         5-Agent Development Automation          │
                         └──────────────────────────────────────────────────┘

    ┌─────────┐       ┌──────────┐       ┌──────────┐       ┌──────────┐       ┌─────────┐
    │ LINEAR  │◄─────►│  ROUTER  │◄─────►│  GITHUB  │       │ RAILWAY  │       │  USER   │
    │ tickets │       │   🚦     │       │   PRs    │       │  deploy  │       │         │
    └─────────┘       └────┬─────┘       └──────────┘       └──────────┘       └────┬────┘
                           │                                                        │
              ┌────────────┼────────────────────────────┐                           │
              │            │                            │                           │
         ┌────▼────┐  ┌────▼────┐  ┌─────────┐  ┌──────▼──┐                        │
         │ARCHITECT│  │ BUILDER │  │REVIEWER │  │  INFRA  │                        │
         │   🧠    │  │   🛠️    │  │   🔬    │  │   🚂    │                        │
         │ design  │  │  code   │  │ review  │  │ deploy  │                        │
         └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘                        │
              │            │            │            │                              │
              ▼            ▼            ▼            ▼                              │
    ┌──────────────────────────────────────────────────────┐                        │
    │              SHARED WORK PACKETS                     │◄───────────────────────┘
    │  spec.md | tasks.md | tests.md | verify-results.md   │   (visible to user)
    └──────────────────────────────────────────────────────┘
```

**How it works in one line:**

```
Linear ticket → Router classifies → Architect designs → Builder implements → Builder verifies
→ Reviewer reviews → Infra deploys + verifies → Linear updated to Done
```

---

## The 5 Agents

### 🚦 Router — The Traffic Controller

| Property | Value |
|----------|-------|
| **Role** | Front-door orchestrator, task classifier, Linear coordinator |
| **Thinking** | `low` — lightweight classification, no deep analysis |
| **Default** | Yes — all incoming messages hit Router first |
| **Does** | Classify tasks, route to agents, orchestrate pipelines, keep Linear updated |
| **Does NOT** | Write code, review PRs, design specs, manage infrastructure |

Router is the **single coordinator**. It receives every message, decides what kind of work it is, and orchestrates the right pipeline. It relays agent responses verbatim — never summarizes or filters.

---

### 🧠 Architect — The CTO

| Property | Value |
|----------|-------|
| **Role** | CTO-level technical grooming and specification |
| **Thinking** | `xhigh` — deep codebase analysis and spec writing |
| **Default** | No — receives work from Router |
| **Does** | Read codebase, trace code paths, produce specs, ask clarifying questions |
| **Does NOT** | Write production code, review PRs, deploy services |

Architect reads the codebase before forming opinions. It produces specs so precise that Builder implements with near-100% accuracy on the first pass. When requirements are unclear, it asks structured questions — each with context explaining why the answer matters.

**4 Operating Modes:**

| Mode | When | Output |
|------|------|--------|
| **Light Groom** | MEDIUM tasks | `tasks.md` + lightweight analysis |
| **Full Groom** | BIG tasks | `spec.md` + `tasks.md` + `tests.md` + deep analysis |
| **Resume** | User answers questions | Picks up where it left off |
| **Refine** | "Change the approach" | Targeted spec updates |

---

### 🛠️ Builder — The Engineer

| Property | Value |
|----------|-------|
| **Role** | Implementation owner — writes code, creates branches and PRs |
| **Thinking** | `xhigh` — complex implementation reasoning |
| **Default** | No — receives work from Router |
| **Does** | Write code, run tests, verify output, self-correct, create PRs |
| **Does NOT** | Design specs, review other agents' work, deploy to production |

Builder follows specs and task lists. It writes code, verifies it works (lint, tests, API checks, DB, UI), self-corrects from failures, and creates PRs. One feature per session — fresh context each time.

---

### 🔬 Reviewer — The Principal Engineer

| Property | Value |
|----------|-------|
| **Role** | Quality gate — correctness, security, performance, maintainability |
| **Thinking** | `xhigh` — thorough review analysis |
| **Default** | No — receives PRs from Router |
| **Does** | Review code against specs, validate verification evidence, post GitHub reviews |
| **Does NOT** | Write code, design specs, re-run tests (builder already did) |

Reviewer checks code like a principal engineer: correctness against spec, security (OWASP), performance (N+1, indexes), and test coverage. It reads Builder's `verify-results.md` to validate verification was thorough — flags gaps, doesn't re-run the same tests.

**Verdict rules:**
- **PASS** — No blockers. Production-ready.
- **WARN** — No blockers but significant warnings. Merge OK, follow-up recommended.
- **FAIL** — Blocking issues. Security violations = automatic FAIL.

---

### 🚂 Infra — The DevOps Engineer

| Property | Value |
|----------|-------|
| **Role** | Railway infrastructure — deployments, services, environments |
| **Thinking** | `high` — infrastructure requires care |
| **Default** | No — receives infra tasks from Router |
| **Does** | Deploy, manage env vars, check logs, run post-deploy smoke tests |
| **Does NOT** | Write application code, design specs, review PRs |

Infra manages Railway services, runs post-deploy verification (health checks, smoke tests, log analysis), and handles rollbacks when deployments fail.

---

## Hub-and-Spoke Orchestration

```
                              USER
                               │
                               ▼
                         ┌───────────┐
                    ┌────┤  ROUTER   ├────┐
                    │    │    🚦     │    │
                    │    └─┬───┬───┬─┘    │
                    │      │   │   │      │
               ┌────▼──┐ ┌─▼───▼─┐ │ ┌────▼──┐
               │ARCHIT.│ │BUILDER│ │ │ INFRA │
               │  🧠   │ │  🛠️   │ │ │  🚂   │
               └───────┘ └───────┘ │ └───────┘
                                   │
                             ┌─────▼───┐
                             │REVIEWER │
                             │   🔬    │
                             └─────────┘
```

### Rules

1. **Router is the ONLY coordinator** — agents never talk to each other directly
2. **Flow is always**: `Router → Agent → Router → Agent → Router`
3. **Router relays verbatim** — never summarizes, rewrites, or filters agent responses
4. **Prevents deadlocks** — sequential orchestration from Router's own turn
5. **Ping-pong disabled** — `maxPingPongTurns: 0` prevents invisible inter-agent loops

### Session Persistence

Each agent's session is **persistent** across `sessions_send` calls. Builder retains full context when receiving fix instructions. Architect retains context when resuming after user answers. No context is lost between Router orchestration steps.

---

## Task Classification

Router classifies every incoming task on **3 dimensions** before routing:

```
                    ┌─────────────────────────────────────────┐
                    │          CLASSIFICATION MATRIX           │
                    ├─────────────┬───────────┬───────────────┤
                    │   SCOPE     │ AMBIGUITY │     RISK      │
                    ├─────────────┼───────────┼───────────────┤
                    │ Narrow      │ Obvious   │ None          │
                    │ Bounded     │ Clear     │ Low           │
                    │ Wide        │ Uncertain │ High          │
                    └─────────────┴───────────┴───────────────┘
```

| Scope | What it means | Examples |
|-------|---------------|---------|
| **Narrow** | Single file, few lines, one service | Typo, config value, rename |
| **Bounded** | Multiple files in one service, clear boundaries | Add endpoint, fix feature |
| **Wide** | Cross-service, cross-repo, APIs + DB + infra | New capability, system redesign |

| Ambiguity | What it means | Examples |
|-----------|---------------|---------|
| **Obvious** | One correct implementation, no decisions | "Change timeout to 60" |
| **Clear** | Intent clear, minor decisions for builder | "Add pagination to users endpoint" |
| **Uncertain** | Multiple valid approaches, tradeoffs | "Implement rate limiting" |

| Risk | What it means | Examples |
|------|---------------|---------|
| **None** | Docs, tests, dev tooling | README update |
| **Low** | Single service, reversible | New internal endpoint |
| **High** | Data migration, auth, shared APIs | Schema migration, auth rewrite |

### Override Signals

| Signal | Action |
|--------|--------|
| "just do it", "quick fix", "skip review" | Force **SMALL** |
| "spec this", "plan this", "design this", "groom this" | Force **BIG** |
| `/architect` | Route directly to Architect |
| `/builder` | Route directly to Builder |
| `/reviewer` | Route directly to Reviewer |
| `/infra` | Route directly to Infra |

---

## Pipeline Flows

### SMALL Pipeline — Builder Only

> **When**: Narrow + Obvious + None/Low risk
> **Examples**: Typo fix, config change, simple bug fix

```
┌──────┐     ┌──────────┐     ┌─────────┐     ┌──────────┐     ┌──────┐
│ USER │────►│  ROUTER  │────►│ BUILDER │────►│  ROUTER  │────►│ USER │
└──────┘     │  classify │     │  code   │     │  relay   │     └──────┘
             │  as SMALL │     │  commit │     │  update  │
             └──────────┘     │  push   │     │  Linear  │
                              └─────────┘     └──────────┘
```

**Work packet**: `status.md` only
**No design, no review** — overhead isn't worth it for trivial changes.

---

### MEDIUM Pipeline — Architect + Builder + Reviewer

> **When**: Narrow/Bounded + Clear + Any risk
> **Examples**: Standard feature, bug fix with clear requirements

```
┌──────┐     ┌────────┐     ┌───────────┐     ┌─────────┐     ┌──────────┐     ┌──────────┐
│ USER │────►│ ROUTER │────►│ ARCHITECT │────►│ BUILDER │────►│ REVIEWER │────►│  ROUTER  │
└──────┘     │classify│     │  light    │     │  code   │     │  review  │     │  relay   │
             │MEDIUM  │     │  groom    │     │  verify │     │  verdict │     │  update  │
             └────────┘     │           │     │  PR     │     │          │     │  Linear  │
                            │ tasks.md  │     │         │     │ review.md│     └──────────┘
                            └───────────┘     └─────────┘     └──────────┘
                                                                  │
                                                           FAIL? (max 3x)
                                                                  │
                                                          ┌───────▼───────┐
                                                          │ Builder fixes │
                                                          │ → re-review   │
                                                          └───────────────┘
```

**Work packet**: `status.md`, `tasks.md`, `verify-results.md`, `review.md`
**Post-deploy** (optional): Router sends to Infra for smoke tests after merge.

---

### BIG Pipeline — Full Spec-Driven Development

> **When**: Bounded/Wide + Uncertain + Any risk, OR Wide + Any + High
> **Examples**: Complex feature, cross-service change, architectural decision

```
┌──────┐     ┌────────┐     ┌───────────────────────────────────────┐
│ USER │────►│ ROUTER │────►│              ARCHITECT                │
└──────┘     │classify│     │                                       │
             │  BIG   │     │  1. Fetch Linear ticket               │
             └────────┘     │  2. Deep codebase analysis (6 steps)  │
                            │  3. Readiness checklist (7 criteria)  │
                            │                                       │
                            │  ┌─ READY ──────────────────────────┐ │
                            │  │ spec.md + tasks.md + tests.md    │ │
                            │  └──────────────────────────────────┘ │
                            │                                       │
                            │  ┌─ NEEDS_INPUT ────────────────────┐ │
                            │  │ Questions → User → Resume        │ │
                            │  └──────────────────────────────────┘ │
                            └──────────────┬────────────────────────┘
                                           │
                                           ▼
                            ┌──────────────────────────────┐
                            │           BUILDER            │
                            │                              │
                            │  1. Read spec + tasks         │
                            │  2. Implement per spec        │
                            │  3. Verify (lint/test/API/DB) │
                            │  4. Self-correct (max 3x)     │
                            │  5. UI checks (async bg)      │
                            │  6. Create PR                 │
                            └──────────────┬───────────────┘
                                           │
                                           ▼
                            ┌──────────────────────────────┐
                            │          REVIEWER            │
                            │                              │
                            │  1. Review against spec       │
                            │  2. Validate verify-results   │
                            │  3. Security/perf checklist   │
                            │  4. Verdict: PASS/WARN/FAIL   │
                            └──────────────┬───────────────┘
                                           │
                              ┌────────────┼────────────┐
                              │            │            │
                           PASS         WARN         FAIL
                              │            │            │
                              ▼            ▼            ▼
                           Merge        Merge     Builder fixes
                              │            │       → re-review
                              ▼            ▼       (max 3x)
                            ┌──────────────────────────────┐
                            │      INFRA (post-deploy)     │
                            │                              │
                            │  1. Health endpoint check     │
                            │  2. Smoke tests from tests.md │
                            │  3. Railway log check (5 min) │
                            │  4. Report PASS/FAIL          │
                            └──────────────────────────────┘
                                           │
                                           ▼
                                   Linear → "Done"
```

**Work packet**: `spec.md`, `tasks.md`, `tests.md`, `status.md`, `verify-results.md`, `review.md`

---

## Architect: Design-First Development

The Architect ensures design happens **before** implementation — never during it.

```
                    WHY ARCHITECT EXISTS

    Without Architect              With Architect
    ─────────────────              ──────────────────
    Router (low thinking)          Architect (xhigh thinking)
    guesses at spec                reads actual codebase
    ↓                              ↓
    Builder discovers              Builder follows precise spec
    missing requirements           ↓
    ↓                              Reviewer checks against
    Reviewer finds                 clear acceptance criteria
    design issues                  ↓
    ↓                              First-pass success rate: HIGH
    Multiple fix loops
```

### Codebase Analysis Protocol (6 Steps)

For every full grooming session, Architect follows ALL 6 steps:

```
Step 1: Identify affected domain
        ├─→ Which services?
        ├─→ Which frontend components?
        ├─→ Which infra modules?
        └─→ Cross-service dependencies?

Step 2: Read repo context files
        └─→ CLAUDE.md / AGENTS.md for architecture context

Step 3: Trace code paths
        ├─→ Routes / Controllers (entry points)
        ├─→ Services / Business logic
        ├─→ Repositories / DAOs (database)
        ├─→ Models / Entities (schema)
        ├─→ Tests (existing coverage)
        └─→ Config (env vars, feature flags)

Step 4: Map cross-service dependencies
        ├─→ Service-to-service calls
        ├─→ Shared libraries
        ├─→ Database migrations across services
        └─→ Queue/event consumers

Step 5: Identify risks and edge cases
        ├─→ Regressions, data corruption, performance
        ├─→ Null data, concurrent access, rate limits
        ├─→ Migration: backward compat, rollback
        └─→ Security: auth, validation, data exposure

Step 6: Write findings to ANALYSIS.md
        └─→ File paths, DB tables, API contracts, risks, test gaps
```

### Readiness Checklist (7 Criteria — BIG tasks)

All 7 must pass before Architect marks `GROOM_RESULT: READY`:

| # | Criterion | What It Means |
|---|-----------|---------------|
| 1 | **Clear problem statement** | The "what" and "why" are unambiguous |
| 2 | **Testable acceptance criteria** | Each can be verified with a specific test |
| 3 | **Identified repos and services** | Every affected service listed with files |
| 4 | **Feasible approach** | At least one viable approach with current architecture |
| 5 | **No blocking questions** | All critical unknowns resolved |
| 6 | **Documented risks** | Every risk has a concrete mitigation |
| 7 | **Specified contracts** | API, schema, event changes fully defined |

If ANY criterion fails → `GROOM_RESULT: NEEDS_INPUT` with structured questions.

### Architect Notes (Per-Ticket Persistence)

```
architect/notes/<TICKET_ID>/
├── ANALYSIS.md    — Raw codebase findings (files, deps, patterns)
├── QUESTIONS.md   — Open/answered questions with timestamps
└── TECH_SPEC.md   — Working draft (before promoting to shared work packet)
```

Notes persist across sessions. When the same ticket comes back (resume/refine), Architect reads existing notes and picks up where it left off.

---

## Verification: Build, Run, See, Fix

Agents don't just build features — they **run them, see the output, and self-correct**. This creates a feedback loop at every stage.

### 3-Layer Verification Architecture

```
    LAYER 1: BUILD-TIME                LAYER 2: REVIEW-TIME           LAYER 3: POST-DEPLOY
    ────────────────────                ─────────────────────          ────────────────────
    Owner: Builder                      Owner: Reviewer                Owner: Infra
    When: Before PR                     When: During PR review         When: After merge
    ┌────────────────────┐              ┌────────────────────┐         ┌────────────────────┐
    │ Lint / Typecheck   │              │ Read verify-results│         │ Health endpoint     │
    │ Test suite         │              │ Validate coverage  │         │ Smoke tests         │
    │ API tests (curl)   │              │ Flag gaps          │         │ Log check (5 min)   │
    │ DB verification    │              │ Check self-fixes   │         │ Report verdict      │
    │ UI checks (tiered) │              │                    │         │                     │
    │ Log analysis       │              │ Only re-run tests  │         │                     │
    │                    │              │ if results missing │         │                     │
    │ Self-correct loop  │              │ or suspicious      │         │                     │
    │ (max 3 attempts)   │              │                    │         │                     │
    └────────────────────┘              └────────────────────┘         └────────────────────┘
            │                                    │                              │
            ▼                                    ▼                              ▼
    verify-results.md                    review.md                      verify-results.md
    (build-time section)                 (verification assessment)      (post-deploy section)
```

### Builder Self-Correction Loop

```
    ┌──────────────────────────────────────────────────────────────┐
    │                    VERIFICATION LOOP                         │
    │                                                              │
    │   Attempt 1                Attempt 2              Attempt 3  │
    │   ─────────                ─────────              ─────────  │
    │   Run all checks           Re-run checks          Final try  │
    │       │                        │                      │      │
    │   PASS? ──→ PR            PASS? ──→ PR           PASS? ──→ PR│
    │       │                        │                      │      │
    │   FAIL?                    FAIL?                  FAIL?      │
    │       │                        │                      │      │
    │   Parse error              Parse error            PR anyway  │
    │   Find root cause          Fix code               Document   │
    │   Fix code ────────────►   ──────────────────►    failures   │
    │                                                              │
    └──────────────────────────────────────────────────────────────┘
```

### UI Verification: Tiered (Fast Blocks, Slow Runs Async)

Builder does NOT wait for slow frontend tests. UI verification is split into tiers:

```
    ┌──────────────────────────────────────────────────────────────────────┐
    │                      UI VERIFICATION TIERS                          │
    ├───────────┬────────────────────────┬──────────┬──────────┬──────────┤
    │   TIER    │ TOOL                   │  SPEED   │ BLOCKING │  CHECKS  │
    ├───────────┼────────────────────────┼──────────┼──────────┼──────────┤
    │  Tier 1   │ Vitest + Happy DOM     │ ~14ms    │   Yes    │ DOM,     │
    │           │                        │ per test │          │ component│
    │           │                        │          │          │ render   │
    ├───────────┼────────────────────────┼──────────┼──────────┼──────────┤
    │  Tier 2   │ Playwright a11y        │ <1s      │   Yes    │ Page     │
    │           │ snapshot               │ per page │          │ structure│
    │           │                        │          │          │ elements │
    ├───────────┼────────────────────────┼──────────┼──────────┼──────────┤
    │  Tier 3   │ Playwright screenshot  │ 4-10s    │   No     │ Visual   │
    │           │ / visual tests         │ per page │ (async)  │ layout   │
    │           │                        │          │          │ styles   │
    └───────────┴────────────────────────┴──────────┴──────────┴──────────┘
```

```
Builder implements UI change
   │
   ├──→ [BLOCKING]   Tier 1: Component tests ─── sub-second
   ├──→ [BLOCKING]   Tier 2: A11y snapshot ───── <1 second
   │      └──→ Self-correct if structure wrong
   │
   ├──→ [BACKGROUND] Tier 3: Visual tests ────── runs async
   │      └──→ Results appear in verify-results.md as ASYNC_FAIL if broken
   │
   └──→ Create PR immediately (don't wait for Tier 3)
```

---

## Context Preservation

**Zero context loss between agents.** All handoffs go through shared work packet files — not message summaries.

```
    ┌───────────────────────────────────────────────────────────────────────┐
    │                    CONTEXT FLOW BETWEEN AGENTS                       │
    │                                                                       │
    │   Router                                                              │
    │     │                                                                 │
    │     ├──→ Linear ticket + work folder path                             │
    │     │                                                                 │
    │     ▼                                                                 │
    │   Architect                                                           │
    │     │                                                                 │
    │     ├──→ spec.md ──────────────────────────────► Builder reads        │
    │     ├──→ tasks.md ─────────────────────────────► Builder follows      │
    │     ├──→ tests.md ─────────────────────────────► Builder executes     │
    │     │                                            Infra runs smoke     │
    │     ▼                                                                 │
    │   Builder                                                             │
    │     │                                                                 │
    │     ├──→ verify-results.md ────────────────────► Reviewer validates   │
    │     ├──→ status.md (PR links) ─────────────────► Reviewer reads       │
    │     │                                            Infra reads          │
    │     ▼                                                                 │
    │   Reviewer                                                            │
    │     │                                                                 │
    │     ├──→ review.md ────────────────────────────► Builder reads fixes  │
    │     │                                                                 │
    │     ▼                                                                 │
    │   Infra                                                               │
    │     │                                                                 │
    │     └──→ verify-results.md (post-deploy) ──────► Router reads final  │
    │                                                                       │
    └───────────────────────────────────────────────────────────────────────┘
```

| From → To | Context Medium | What's Preserved |
|-----------|---------------|-----------------|
| Router → Architect | Linear ticket + work folder path | Problem, requirements, discussion |
| Architect → Builder | `spec.md` + `tasks.md` + `tests.md` | Full design, criteria, task order |
| Builder → Reviewer | `verify-results.md` + PR URL in `status.md` | Verification evidence, code diff |
| Reviewer → Builder | `review.md` | Blocking issues, file/line refs |
| Router → Infra | `tests.md` (smoke section) + `status.md` | What to verify against live service |
| Architect resume | `architect/notes/<TICKET_ID>/` | ANALYSIS, QUESTIONS — full continuity |

### Active Work Queue

`./shared/active.md` is the single source of truth for work ownership and state:

```
┌──────────────────────────────────────────────────────────────────────┐
│ Work ID                    │ Owner     │ State          │ Links     │
├────────────────────────────┼───────────┼────────────────┼───────────┤
│ FLOQ-42                    │ architect │ grooming       │ pending   │
│ FLOQ-38                    │ builder   │ in_progress    │ PR #12    │
│ FLOQ-35                    │ reviewer  │ review_pending │ PR #10    │
└──────────────────────────────────────────────────────────────────────┘

State flow: grooming → designed/groomed → in_progress → review_pending → done
```

---

## Work Packet System

Every task gets a folder at `./shared/work/<LINEAR-ID>/`. This is the **shared context** between all agents.

```
./shared/work/FLOQ-42/
│
├── spec.md                     Written by: Architect (BIG tasks)
│   ├── Problem statement       ────────────────────────────────────
│   ├── Scope (in/out)          The complete technical specification.
│   ├── Acceptance criteria     Builder implements from this.
│   ├── Technical approach      Reviewer reviews against this.
│   ├── Decisions + rationale
│   ├── Contract changes (API, schema, events)
│   ├── Rollout + rollback plan
│   └── Files to modify
│
├── tasks.md                    Written by: Architect (MEDIUM + BIG)
│   ├── Ordered task list       ────────────────────────────────────
│   ├── Checkboxes              Builder marks complete as it goes.
│   └── Notes section           Builder adds deviations/discoveries.
│
├── tests.md                    Written by: Architect (BIG tasks)
│   ├── Component tests (Tier 1)────────────────────────────────────
│   ├── Integration tests (curl) Test commands for Builder to execute.
│   ├── Edge case tests          Smoke tests for Infra post-deploy.
│   ├── DB verification
│   ├── UI verification (tiered)
│   ├── Acceptance checklist
│   └── Smoke tests (production-safe)
│
├── status.md                   Updated by: All agents
│   ├── Owner + State           ────────────────────────────────────
│   ├── Timeline                Tracks every state transition.
│   ├── Branch + PR links       Single source for current status.
│   └── Blockers + Next steps
│
├── verify-results.md           Written by: Builder, Reviewer, Infra
│   ├── Lint / Typecheck        ────────────────────────────────────
│   ├── Test suite results      Cumulative verification evidence.
│   ├── API test results        Builder writes build-time results.
│   ├── DB verification         Reviewer appends assessment.
│   ├── UI — quick (blocking)   Infra appends post-deploy results.
│   ├── UI — visual (async)
│   ├── Log analysis
│   ├── Self-correction log
│   └── Post-deploy results
│
└── review.md                   Written by: Reviewer
    ├── Verdict (PASS/WARN/FAIL)────────────────────────────────────
    ├── Blocking issues          What must be fixed before merge.
    ├── Warnings                 Should fix, not blocking.
    ├── Notes                    Informational observations.
    ├── Verification assessment  Did Builder's verification cover enough?
    ├── Spec compliance          Per-criterion PASS/FAIL.
    └── What's good              Acknowledge quality work.
```

---

## Linear Integration

Linear is the **source of truth** for all work. Every state transition is reflected there.

### State Lifecycle

```
    ┌──────────┐     ┌────────────┐     ┌───────────┐     ┌──────┐
    │ Backlog  │────►│In Progress │────►│ In Review │────►│ Done │
    └──────────┘     └────────────┘     └───────────┘     └──────┘
         │                │                   │                │
    Router receives  Architect grooms    Reviewer starts   Review PASS
    task             Builder implements  reviewing         or deploy
                                                          verified
```

### Breadcrumb Comments

| Event | Comment |
|-------|---------|
| Grooming starts | `🧠 Technical grooming initiated by Architect agent.` |
| Spec ready | `Tech spec ready for <ID>. Starting implementation.` |
| Implementation starts | `🛠️ Implementation started. Work ID: <ID>` |
| PR created | `🔗 PR created: <URL>` |
| Review verdict | `✅ Code review: <VERDICT>. PR: <URL>` |
| Deploy verified | `🏁 Deployment verified. All smoke tests passed.` |

### Linear CLI

```bash
./skills/linear/linear.sh get <ID>              # Fetch ticket details
./skills/linear/linear.sh comment <ID> "<text>"  # Add comment
./skills/linear/linear.sh search <query>         # Search tickets
./skills/linear/linear.sh update <ID> <field> <val>  # Update state
./skills/linear/linear.sh create "<title>"       # Create ticket
./skills/linear/linear.sh list-states            # Workflow states
./skills/linear/linear.sh assign <ID> "<name>"   # Assign ticket
```

---

## GitHub Integration

### Branch Naming

```
builder/<LINEAR-ID>-<short-slug>
```

Example: `builder/FLOQ-42-add-user-auth`

### PR Format

```markdown
## Summary
<what this PR does and why>

## Changes
<key files and what changed>

## Linear Ticket
FLOQ-42: Add user authentication

## Verification Results
<summary from verify-results.md>

## Test Plan
<how to verify these changes>
```

### Review Actions

| Verdict | GitHub Action |
|---------|--------------|
| **PASS** | `gh pr review --approve` |
| **WARN** | `gh pr review --comment --body "<findings>"` |
| **FAIL** | `gh pr review --request-changes --body "<findings>"` |

---

## Infrastructure (Railway)

### What Infra Manages

| Area | Capabilities |
|------|-------------|
| **Deployments** | Deploy, monitor, rollback services |
| **Environments** | Manage env vars across staging/production |
| **Services** | Create, configure, monitor Railway services |
| **Databases** | PostgreSQL, Redis provisioning and management |
| **Networking** | Custom domains, internal service communication |
| **Post-Deploy** | Health checks, smoke tests, log verification |

### Post-Deploy Verification Protocol

```
1. Wait for deployment to stabilize
   └─→ railway deployments list / railway service info <service>

2. Health endpoint check
   └─→ curl -sf <service-url>/health

3. Smoke tests from tests.md
   └─→ Run read-only curl tests against live service URL

4. Log check
   └─→ railway logs <service> --since 5m | grep "error|exception|fatal"

5. Report verdict
   ├─→ DEPLOY_VERIFY: PASS — all checks passed
   ├─→ DEPLOY_VERIFY: FAIL — details of what failed
   └─→ DEPLOY_VERIFY: BLOCKED — missing service URL or health endpoint
```

### Railway Config Files

| File | Purpose |
|------|---------|
| `railway.toml` | Build and deploy configuration |
| `Procfile` | Process type definitions |
| `nixpacks.toml` | Build system configuration |

---

## Security

| Rule | Description |
|------|-------------|
| **No secrets in git** | API keys, tokens, passwords never committed |
| **API key storage** | `.linear-api-key` stored in gitignored file |
| **All PRs reviewed** | No code reaches production without Reviewer verdict |
| **Security = auto FAIL** | Any security violation in review is automatic FAIL |
| **Infra confirmation** | Production infrastructure changes require explicit user confirmation |
| **No credential leaks** | Environment variables never logged, echoed, or included in responses |

### Reviewer Security Checklist

- No SQL injection (parameterized queries only)
- No XSS (user input sanitized/escaped)
- No command injection (no string-interpolated shell commands)
- Authentication/authorization on all endpoints
- No overly permissive CORS
- Input validation at system boundaries

---

## Error Recovery & Escalation

```
    Level 1: Retry with error context
        │
        ▼
    Level 2: Rollback to git checkpoint (Builder)
        │
        ▼
    Level 3: Escalate to Router with summary
        │
        ▼
    Level 4: Router escalates to User
```

### Bounded Iteration

| Loop | Max Iterations | What Happens After |
|------|---------------|-------------------|
| Builder self-correction | 3 attempts | PR created with failures documented |
| Review loop (Builder ↔ Reviewer) | 3 rounds | Router escalates to user |
| Architect Q&A | Until READY | User answers resolve all questions |

---

## Design Principles

| # | Principle | Why |
|---|-----------|-----|
| 1 | **Hub-and-spoke** | Router coordinates everything. Prevents deadlocks, keeps routing deterministic. |
| 2 | **Design before implementation** | Architect grooms every non-trivial task. Builder follows specs, never guesses. |
| 3 | **Verify before merge** | Builder runs tests, sees output, self-corrects. Catches bugs before review. |
| 4 | **Context through files** | Every handoff goes through shared work packets. No context lives only in messages. |
| 5 | **Linear as source of truth** | All state lives in Linear. Work packets are local caches. Linear wins if diverged. |
| 6 | **Deterministic classification** | Router classifies on scope/ambiguity/risk. Pipeline selection is rule-based. |
| 7 | **Bounded iteration** | All loops have max attempts. Prevents infinite cycles, escalates to humans. |
| 8 | **One feature per session** | Builder gets fresh context for each task. Prevents context exhaustion. |
| 9 | **Everything visible** | All state changes in Linear, GitHub, and work packets. Nothing in the dark. |
| 10 | **Fast checks block, slow checks don't** | UI Tier 1-2 are instant. Tier 3 visual tests run in background. |

---

## Project Structure

```
floq-claw/
│
├── openclaw.json                   # Master config — 5 agents, models, tools, sessions
│
├── agents/
│   ├── router/                     # 🚦 Router
│   │   ├── IDENTITY.md             #    Name, emoji, role, thinking level
│   │   ├── SOUL.md                 #    Personality, operating principles
│   │   ├── TOOLS.md                #    Available tools, routing rules
│   │   └── AGENTS.md               #    Classification, pipelines, orchestration
│   │
│   ├── architect/                  # 🧠 Architect
│   │   ├── IDENTITY.md
│   │   ├── SOUL.md                 #    CTO mindset, read-code-first principles
│   │   ├── TOOLS.md
│   │   └── AGENTS.md               #    4 modes, 6-step analysis, 7-point checklist
│   │
│   ├── builder/                    # 🛠️ Builder
│   │   ├── IDENTITY.md
│   │   ├── SOUL.md
│   │   ├── TOOLS.md
│   │   └── AGENTS.md               #    Git hygiene, verification loop, PR creation
│   │
│   ├── reviewer/                   # 🔬 Reviewer
│   │   ├── IDENTITY.md
│   │   ├── SOUL.md
│   │   ├── TOOLS.md
│   │   └── AGENTS.md               #    Review checklist, verdict rules, verification assessment
│   │
│   └── infra/                      # 🚂 Infra
│       ├── IDENTITY.md
│       ├── SOUL.md
│       ├── TOOLS.md
│       └── AGENTS.md               #    Railway CLI, post-deploy verification protocol
│
├── architect/
│   └── notes/                      # Per-ticket analysis (ANALYSIS.md, QUESTIONS.md, TECH_SPEC.md)
│
├── skills/
│   └── linear/                     # Linear API skill
│       ├── SKILL.md                #    Skill documentation
│       ├── linear.sh               #    GraphQL API wrapper (bash)
│       └── .linear-api-key         #    (gitignored) API key
│
├── shared/
│   ├── active.md                   # Work queue — owner, state, links per Work ID
│   ├── templates/                  # Full templates with field descriptions
│   │   ├── spec.md
│   │   ├── tasks.md
│   │   ├── tests.md
│   │   ├── status.md
│   │   └── verify-results.md
│   └── work/                       # Per-ticket work packets
│       ├── _TEMPLATE/              #    Base templates for new work packets
│       └── <LINEAR-ID>/            #    One folder per ticket
│
├── scripts/
│   ├── setup.sh                    # Initial setup (deps, API key, directories)
│   ├── create-work-packet.sh       # Create work packet from Linear ticket
│   └── sync-linear.sh             # Sync local state with Linear
│
└── docs/
    └── architecture.md             # This file
```

---

> **Floq-Claw** — Design, build, verify, review, deploy. Automated.
