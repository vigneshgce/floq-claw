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

### Full System Map

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              EXTERNAL SYSTEMS                                  │
│                                                                                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────────┐  │
│  │  LINEAR  │  │  GITHUB  │  │ RAILWAY  │  │ DATABASE │  │  APPLICATION     │  │
│  │  tickets │  │  repos   │  │ services │  │ Postgres │  │  dev server      │  │
│  │  states  │  │  PRs     │  │ deploys  │  │ Redis    │  │  localhost:3000   │  │
│  │  comments│  │  reviews │  │  logs    │  │ schema   │  │  API endpoints   │  │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────────┬─────────┘  │
│       │              │             │              │                 │            │
└───────┼──────────────┼─────────────┼──────────────┼─────────────────┼────────────┘
        │              │             │              │                 │
        │              │             │              │                 │
┌───────┼──────────────┼─────────────┼──────────────┼─────────────────┼────────────┐
│       │              │             │              │                 │            │
│  ┌────▼──────────────▼─────┐  ┌────▼──────────────▼─────────────────▼─────┐      │
│  │        ROUTER 🚦        │  │                                           │      │
│  │                         │  │            BUILDER 🛠️                      │      │
│  │  reads: Linear tickets  │  │                                           │      │
│  │  writes: Linear state   │  │  reads: spec.md, tasks.md, tests.md       │      │
│  │  writes: Linear comments│  │  writes: code → git → GitHub PR           │      │
│  │  reads: GitHub PR status│  │                                           │      │
│  │                         │  │  ┌─ VERIFICATION LOOP ──────────────────┐ │      │
│  │  classifies tasks       │  │  │                                      │ │      │
│  │  orchestrates pipeline  │  │  │  lint/typecheck ◄── project files    │ │      │
│  │  relays responses       │  │  │       │                              │ │      │
│  └────────┬────────────────┘  │  │  test suite ◄────── npm test / pytest│ │      │
│           │                   │  │       │                              │ │      │
│  ┌────────▼────────────────┐  │  │  API tests ◄──────── curl against   │ │      │
│  │     ARCHITECT 🧠        │  │  │       │              dev server     │ │      │
│  │                         │  │  │  DB verify ◄──────── psql queries   │ │      │
│  │  reads: Linear tickets  │  │  │       │              schema check   │ │      │
│  │  reads: codebase files  │  │  │       │              data round-trip│ │      │
│  │  reads: CLAUDE.md       │  │  │  UI check ◄──────── a11y snapshot  │ │      │
│  │  reads: repo structure  │  │  │  (blocking)          Happy DOM     │ │      │
│  │                         │  │  │       │                              │ │      │
│  │  writes: spec.md        │  │  │  UI visual ◄──────── Playwright    │ │      │
│  │  writes: tasks.md       │  │  │  (background)        screenshots   │ │      │
│  │  writes: tests.md       │  │  │       │                              │ │      │
│  │  writes: ANALYSIS.md    │  │  │  log analysis ◄───── grep stderr   │ │      │
│  │  writes: QUESTIONS.md   │  │  │       │              parse traces   │ │      │
│  │                         │  │  │       ▼                              │ │      │
│  │  posts: Linear comments │  │  │  FAIL? → fix code → re-run (max 3) │ │      │
│  └─────────────────────────┘  │  │  PASS? → verify-results.md → PR    │ │      │
│                               │  └──────────────────────────────────────┘ │      │
│  ┌─────────────────────────┐  └───────────────────────────────────────────┘      │
│  │     REVIEWER 🔬         │                                                     │
│  │                         │  ┌───────────────────────────────────────────┐      │
│  │  reads: spec.md         │  │          INFRA 🚂                         │      │
│  │  reads: PR diff (gh)    │  │                                           │      │
│  │  reads: verify-results  │  │  POST-DEPLOY VERIFICATION:                │      │
│  │  reads: tasks.md        │  │                                           │      │
│  │                         │  │  health ◄─────── curl <service>/health    │      │
│  │  validates: coverage    │  │       │                                   │      │
│  │  validates: self-fixes  │  │  smoke tests ◄── curl from tests.md      │      │
│  │  flags: gaps            │  │       │           against live service    │      │
│  │                         │  │  log check ◄──── railway logs --since 5m  │      │
│  │  writes: review.md      │  │       │          grep error/exception     │      │
│  │  writes: GitHub review  │  │       ▼                                   │      │
│  │  posts: Linear comment  │  │  FAIL? → alert user via Router            │      │
│  └─────────────────────────┘  │  PASS? → verify-results.md → Linear Done  │      │
│                               └───────────────────────────────────────────┘      │
│                                                                                  │
│  ┌───────────────────────────────────────────────────────────────────────────┐   │
│  │                        SHARED WORK PACKETS                                │   │
│  │                     ./shared/work/<LINEAR-ID>/                             │   │
│  │                                                                           │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────────────┐  │   │
│  │  │ spec.md  │ │ tasks.md │ │ tests.md │ │status.md │ │verify-results  │  │   │
│  │  │(Archit.) │ │(Archit.) │ │(Archit.) │ │(all)     │ │.md (Bldr/Rev/  │  │   │
│  │  │          │ │          │ │          │ │          │ │     Infra)     │  │   │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘ └────────────────┘  │   │
│  │                                                       ┌──────────┐       │   │
│  │                                                       │review.md │       │   │
│  │                                                       │(Reviewer)│       │   │
│  │                                                       └──────────┘       │   │
│  └───────────────────────────────────────────────────────────────────────────┘   │
│                                                                                  │
│  ┌───────────────────────────────────────────────────────────────────────────┐   │
│  │                     ARCHITECT NOTES (persistent)                           │   │
│  │                  ./architect/notes/<TICKET_ID>/                            │   │
│  │                                                                           │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                    │   │
│  │  │ ANALYSIS.md  │  │ QUESTIONS.md │  │ TECH_SPEC.md │                    │   │
│  │  │ code traces  │  │ open/answered│  │ working draft│                    │   │
│  │  │ dependencies │  │ with context │  │ before final │                    │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘                    │   │
│  └───────────────────────────────────────────────────────────────────────────┘   │
│                                                                                  │
│  ┌───────────────────────────────────────────────────────────────────────────┐   │
│  │                      ACTIVE WORK QUEUE                                    │   │
│  │                      ./shared/active.md                                   │   │
│  │                                                                           │   │
│  │  Work ID  │ Owner     │ State          │ Branch / PR Links                │   │
│  │  FLOQ-42  │ architect │ grooming       │ pending                          │   │
│  │  FLOQ-38  │ builder   │ in_progress    │ builder/FLOQ-38-... / PR #12     │   │
│  │  FLOQ-35  │ reviewer  │ review_pending │ PR #10                           │   │
│  └───────────────────────────────────────────────────────────────────────────┘   │
│                                                                                  │
└──────────────────────────────────────────────────────────────────────────────────┘
                                    FLOQ-CLAW
```

### End-to-End Flow (BIG Pipeline)

```
USER ──► "Implement rate limiting for the API"
           │
           ▼
┌─────── ROUTER 🚦 ──────────────────────────────────────────────────────────────┐
│  1. Fetch Linear ticket                                                         │
│  2. Classify: Bounded scope + Uncertain ambiguity + High risk = BIG             │
│  3. Create work folder: ./shared/work/FLOQ-42/                                  │
│  4. Post Linear comment: "🧠 Technical grooming initiated"                       │
└────────────┬────────────────────────────────────────────────────────────────────┘
             │ sessions_send (thinking: xhigh, timeout: 3600)
             ▼
┌─────── ARCHITECT 🧠 ───────────────────────────────────────────────────────────┐
│  1. Read Linear ticket details (linear.sh get FLOQ-42)                          │
│  2. Read codebase: CLAUDE.md, route files, service layers, DB schemas           │
│  3. Trace code paths: controllers → services → repositories → models            │
│  4. Map dependencies: which services call this? shared DB tables?               │
│  5. Identify risks: rate limit storage, concurrent access, cache invalidation   │
│  6. Write ANALYSIS.md to architect/notes/FLOQ-42/                               │
│  7. Run 7-point readiness checklist — all pass                                  │
│  8. Write spec.md + tasks.md + tests.md to shared/work/FLOQ-42/                │
│  9. Post Linear comment: "Tech spec ready"                                      │
│  10. Return: GROOM_RESULT: READY                                                │
└────────────┬────────────────────────────────────────────────────────────────────┘
             │
             ▼
┌─────── ROUTER 🚦 ──────────────────────────────────────────────────────────────┐
│  Post Linear: "Spec ready. Starting implementation."                             │
│  Update Linear state → "In Progress"                                             │
└────────────┬────────────────────────────────────────────────────────────────────┘
             │ sessions_send (thinking: xhigh, timeout: 3600)
             ▼
┌─────── BUILDER 🛠️ ─────────────────────────────────────────────────────────────┐
│                                                                                  │
│  IMPLEMENT                                                                       │
│  1. Read spec.md → understand scope, approach, acceptance criteria                │
│  2. Read tasks.md → follow task order                                            │
│  3. git checkout -b builder/FLOQ-42-rate-limiting                                │
│  4. Write code: middleware, Redis store, config, tests                            │
│  5. Mark tasks complete in tasks.md as I go                                      │
│                                                                                  │
│  VERIFY (self-correction loop, max 3 attempts)                                   │
│  ┌────────────────────────────────────────────────────────────────────────────┐   │
│  │                                                                            │   │
│  │  ┌─ LINT ──────────────────────────────────────────────────────────────┐   │   │
│  │  │ $ npm run lint                                                      │   │   │
│  │  │ $ npx tsc --noEmit                                                  │   │   │
│  │  │ Result: PASS ✓                                                      │   │   │
│  │  └─────────────────────────────────────────────────────────────────────┘   │   │
│  │                                                                            │   │
│  │  ┌─ TEST SUITE ────────────────────────────────────────────────────────┐   │   │
│  │  │ $ npm test                                                          │   │   │
│  │  │ 14 passed, 0 failed ✓                                              │   │   │
│  │  │                                                                     │   │   │
│  │  │ If FAIL: read error → trace to source → fix → re-run               │   │   │
│  │  └─────────────────────────────────────────────────────────────────────┘   │   │
│  │                                                                            │   │
│  │  ┌─ API TESTS (curl against localhost) ────────────────────────────────┐   │   │
│  │  │ $ npm run dev &   ← start dev server                               │   │   │
│  │  │ $ curl -s POST localhost:3000/api/users -d '...'                    │   │   │
│  │  │   Expected: 200  Actual: 200 ✓                                     │   │   │
│  │  │ $ curl -s POST localhost:3000/api/users -d '...'  (rapid fire)     │   │   │
│  │  │   Expected: 429  Actual: 429 ✓  (rate limit works)                 │   │   │
│  │  │ $ kill %1         ← stop dev server                                │   │   │
│  │  └─────────────────────────────────────────────────────────────────────┘   │   │
│  │                                                                            │   │
│  │  ┌─ DB VERIFICATION ──────────────────────────────────────────────────┐   │   │
│  │  │ $ npx prisma migrate deploy                                        │   │   │
│  │  │   Migration applied ✓                                              │   │   │
│  │  │ $ psql -c "SELECT column_name, data_type                           │   │   │
│  │  │            FROM information_schema.columns                         │   │   │
│  │  │            WHERE table_name = 'rate_limits'"                       │   │   │
│  │  │   ip_address | varchar, window_start | timestamp,                  │   │   │
│  │  │   request_count | integer ✓                                        │   │   │
│  │  │ $ psql -c "INSERT INTO rate_limits (...) VALUES (...)"             │   │   │
│  │  │ $ psql -c "SELECT * FROM rate_limits WHERE ..."                    │   │   │
│  │  │ $ psql -c "DELETE FROM rate_limits WHERE ..."                      │   │   │
│  │  │   Round-trip: PASS ✓                                               │   │   │
│  │  └─────────────────────────────────────────────────────────────────────┘   │   │
│  │                                                                            │   │
│  │  ┌─ UI CHECK (blocking — fast) ───────────────────────────────────────┐   │   │
│  │  │ Tier 1: $ npx vitest run --environment happy-dom                   │   │   │
│  │  │         Component tests: 3 passed ✓  (~42ms)                       │   │   │
│  │  │ Tier 2: Playwright a11y snapshot of /dashboard                     │   │   │
│  │  │         Rate limit indicator present ✓  (<1s)                      │   │   │
│  │  └─────────────────────────────────────────────────────────────────────┘   │   │
│  │                                                                            │   │
│  │  ┌─ UI VISUAL (background — slow, don't wait) ────────────────────────┐   │   │
│  │  │ $ npx playwright test --reporter=json &                             │   │   │
│  │  │   Running in background... Builder continues to PR                  │   │   │
│  │  │   Results → verify-results.md (PASS or ASYNC_FAIL)                 │   │   │
│  │  └─────────────────────────────────────────────────────────────────────┘   │   │
│  │                                                                            │   │
│  │  ┌─ LOG ANALYSIS ─────────────────────────────────────────────────────┐   │   │
│  │  │ $ npm run dev 2>&1 | tee /tmp/app.log &                            │   │   │
│  │  │   ... run API tests ...                                             │   │   │
│  │  │ $ grep -i "error\|exception\|fatal" /tmp/app.log                   │   │   │
│  │  │   No errors found ✓                                                │   │   │
│  │  │                                                                     │   │   │
│  │  │ If errors found:                                                    │   │   │
│  │  │   read stack trace → identify root cause → fix → re-run            │   │   │
│  │  └─────────────────────────────────────────────────────────────────────┘   │   │
│  │                                                                            │   │
│  └────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                  │
│  6. Write all results to verify-results.md                                       │
│  7. git push → gh pr create                                                      │
│  8. Post Linear: "🔗 PR created: github.com/.../pull/42"                          │
│  9. Return: PR URL + verification summary                                        │
└────────────┬────────────────────────────────────────────────────────────────────┘
             │
             ▼
┌─────── ROUTER 🚦 ──────────────────────────────────────────────────────────────┐
│  Post Linear: "Implementation complete. Sending to review."                      │
└────────────┬────────────────────────────────────────────────────────────────────┘
             │ sessions_send (thinking: xhigh, timeout: 1800)
             ▼
┌─────── REVIEWER 🔬 ────────────────────────────────────────────────────────────┐
│                                                                                  │
│  STATIC CODE REVIEW                                                              │
│  1. Read spec.md → acceptance criteria                                           │
│  2. Fetch PR diff: gh pr diff <url>                                              │
│  3. Read surrounding source files for context                                    │
│  4. Run review checklist:                                                        │
│     ├── Correctness: Does code match spec? Edge cases? DB transactions?          │
│     ├── Security: SQL injection? XSS? Auth? Credentials?                         │
│     ├── Performance: N+1? Indexes? Unbounded loops? Pagination?                  │
│     ├── Maintainability: Follows patterns? No dead code? Clear naming?           │
│     └── Testing: Tests exist? Cover edge cases? Not fragile?                     │
│                                                                                  │
│  VERIFICATION ASSESSMENT                                                         │
│  5. Read verify-results.md                                                       │
│     ├── Did Builder run lint? ✓                                                  │
│     ├── Did Builder run tests? ✓ (14 passed)                                     │
│     ├── API change → API tests present? ✓ (rate limit 429 verified)              │
│     ├── DB migration → schema verified? ✓                                        │
│     ├── UI change → UI check done? ✓ (a11y + component)                          │
│     └── Self-correction needed? No — first attempt passed                        │
│                                                                                  │
│  6. Write review.md (Verdict: PASS / WARN / FAIL)                                │
│  7. Post GitHub review: gh pr review --approve                                   │
│  8. Post Linear: "✅ Code review: PASS"                                           │
│                                                                                  │
│  If FAIL → Router sends findings to Builder → Builder fixes → re-review (max 3)  │
└────────────┬────────────────────────────────────────────────────────────────────┘
             │
             ▼
┌─────── ROUTER 🚦 ──────────────────────────────────────────────────────────────┐
│  Review PASS → Merge PR                                                          │
│  Post Linear: "PR merged. Triggering deploy verification."                       │
└────────────┬────────────────────────────────────────────────────────────────────┘
             │ sessions_send (thinking: high, timeout: 1800)
             ▼
┌─────── INFRA 🚂 ───────────────────────────────────────────────────────────────┐
│                                                                                  │
│  POST-DEPLOY VERIFICATION                                                        │
│  ┌────────────────────────────────────────────────────────────────────────────┐   │
│  │                                                                            │   │
│  │  ┌─ DEPLOYMENT STATUS ────────────────────────────────────────────────┐   │   │
│  │  │ $ railway deployments list                                          │   │   │
│  │  │   Latest: deploy-abc123  Status: SUCCESS ✓                         │   │   │
│  │  │ $ railway service info api-service                                  │   │   │
│  │  │   Status: RUNNING  Replicas: 2/2 ✓                                 │   │   │
│  │  └─────────────────────────────────────────────────────────────────────┘   │   │
│  │                                                                            │   │
│  │  ┌─ HEALTH ENDPOINT ─────────────────────────────────────────────────┐   │   │
│  │  │ $ curl -sf https://api.floq.app/health                             │   │   │
│  │  │   200 OK ✓                                                         │   │   │
│  │  └─────────────────────────────────────────────────────────────────────┘   │   │
│  │                                                                            │   │
│  │  ┌─ SMOKE TESTS (from tests.md, against live service) ────────────────┐   │   │
│  │  │ $ curl -s POST https://api.floq.app/api/users -d '...'             │   │   │
│  │  │   Expected: 200  Actual: 200 ✓                                     │   │   │
│  │  │ $ curl -s POST https://api.floq.app/api/users -d '...' (x20)      │   │   │
│  │  │   Expected: 429  Actual: 429 ✓  (rate limit works in prod)         │   │   │
│  │  └─────────────────────────────────────────────────────────────────────┘   │   │
│  │                                                                            │   │
│  │  ┌─ PRODUCTION LOG CHECK ─────────────────────────────────────────────┐   │   │
│  │  │ $ railway logs api-service --since 5m                               │   │   │
│  │  │ $ grep -i "error\|exception\|fatal"                                │   │   │
│  │  │   No errors in last 5 minutes ✓                                    │   │   │
│  │  └─────────────────────────────────────────────────────────────────────┘   │   │
│  │                                                                            │   │
│  └────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                  │
│  Append post-deploy results to verify-results.md                                 │
│  Return: DEPLOY_VERIFY: PASS                                                     │
└────────────┬────────────────────────────────────────────────────────────────────┘
             │
             ▼
┌─────── ROUTER 🚦 ──────────────────────────────────────────────────────────────┐
│  Update Linear state → "Done"                                                    │
│  Post Linear: "🏁 Deployment verified. All smoke tests passed."                  │
│  Relay full results to User                                                      │
└─────────────────────────────────────────────────────────────────────────────────┘
             │
             ▼
USER ◄── "Rate limiting implemented, verified, reviewed, deployed, and confirmed."
```

### What Each Agent Can See and Access

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      AGENT ACCESS MAP                                       │
├──────────────┬──────────┬──────────┬──────────┬──────────┬──────────────────┤
│   Resource   │ Router 🚦│Archit. 🧠│Builder 🛠️│Review 🔬│   Infra 🚂       │
├──────────────┼──────────┼──────────┼──────────┼──────────┼──────────────────┤
│ Linear API   │  read    │  read    │  comment │  comment │   comment        │
│              │  write   │  write   │          │          │                  │
│              │  create  │  search  │          │          │                  │
├──────────────┼──────────┼──────────┼──────────┼──────────┼──────────────────┤
│ GitHub       │  PR view │    —     │  PR      │  PR view │     —            │
│              │          │          │  create  │  review  │                  │
│              │          │          │  push    │  approve │                  │
├──────────────┼──────────┼──────────┼──────────┼──────────┼──────────────────┤
│ Codebase     │    —     │  read    │  read    │  read    │     —            │
│              │          │  grep    │  write   │  (diff)  │                  │
│              │          │  trace   │  edit    │          │                  │
├──────────────┼──────────┼──────────┼──────────┼──────────┼──────────────────┤
│ Dev Server   │    —     │    —     │  start   │    —     │     —            │
│ (localhost)  │          │          │  stop    │          │                  │
│              │          │          │  curl    │          │                  │
├──────────────┼──────────┼──────────┼──────────┼──────────┼──────────────────┤
│ Database     │    —     │  read    │  migrate │    —     │   connect        │
│ (Postgres,   │          │  schema  │  query   │          │   status         │
│  Redis)      │          │  inspect │  verify  │          │                  │
├──────────────┼──────────┼──────────┼──────────┼──────────┼──────────────────┤
│ Test Suite   │    —     │    —     │  run     │  read    │     —            │
│              │          │          │  parse   │  results │                  │
│              │          │          │  fix     │          │                  │
├──────────────┼──────────┼──────────┼──────────┼──────────┼──────────────────┤
│ App Logs     │    —     │    —     │  capture │    —     │   railway logs   │
│              │          │          │  grep    │          │   query          │
│              │          │          │  parse   │          │   grep           │
├──────────────┼──────────┼──────────┼──────────┼──────────┼──────────────────┤
│ Browser      │    —     │    —     │  a11y    │    —     │     —            │
│ (Playwright) │          │          │  snapshot│          │                  │
│              │          │          │  screensht│         │                  │
├──────────────┼──────────┼──────────┼──────────┼──────────┼──────────────────┤
│ Railway      │    —     │    —     │    —     │    —     │   deploy         │
│              │          │          │          │          │   logs           │
│              │          │          │          │          │   rollback       │
│              │          │          │          │          │   env vars       │
│              │          │          │          │          │   health check   │
├──────────────┼──────────┼──────────┼──────────┼──────────┼──────────────────┤
│ Work Packets │  create  │  write   │  write   │  write   │   write          │
│              │  read    │  read    │  read    │  read    │   read           │
├──────────────┼──────────┼──────────┼──────────┼──────────┼──────────────────┤
│ Architect    │    —     │  write   │    —     │    —     │     —            │
│ Notes        │          │  read    │          │          │                  │
└──────────────┴──────────┴──────────┴──────────┴──────────┴──────────────────┘
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
