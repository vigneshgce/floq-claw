# TESTS: <LINEAR-ID>

## Metadata
- **Linear ticket**: <LINEAR-ID>
- **Spec**: ./spec.md
- **Tester**: builder (build-time), reviewer (review-time), infra (post-deploy)

## Test environment
- **Dev server command**: `<npm run dev | python manage.py runserver | go run .>`
- **Dev server port**: `<3000>`
- **Dev server health**: `http://localhost:<port>/health`
- **Production URL**: `<https://api.floq.app>` (for post-deploy smoke tests)
- **DB connection**: `<connection string or "N/A">`

## Lint / Typecheck commands
```bash
<npm run lint>
<npx tsc --noEmit>
```

## Test suite command
```bash
<npm test>
```

## Unit tests
<Tests that verify individual functions/modules>

### Test 1: <name>
- **What**: <what it tests>
- **Expected**: <expected result>
- **Command**: `npm test -- --grep "<test name>"`

## Integration tests (API)
<Tests that verify API endpoints. Builder runs against localhost, Infra runs against production URL.>

### Test 1: <endpoint name>
- **What**: <what it tests>
- **Method**: <HTTP method>
- **Endpoint**: <path>
- **Expected status**: `<200>`
- **Request**:
```bash
curl -s -w "\n%{http_code}" -X POST http://localhost:3000/api/<path> \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{
    "field": "value"
  }'
```
- **Expected response**:
```json
{
  "success": true,
  "data": {}
}
```
- **Response assertions**:
  - Status code is `200`
  - `.success` is `true`
  - `.data` is present

### Test 2: <error case>
- **What**: <what error it tests>
- **Method**: <HTTP method>
- **Endpoint**: <path>
- **Expected status**: `<400>`
- **Request**:
```bash
curl -s -w "\n%{http_code}" -X POST http://localhost:3000/api/<path> \
  -H "Content-Type: application/json" \
  -d '{}'
```
- **Expected**: `400 Bad Request` with validation error
- **Response assertions**:
  - Status code is `400`
  - Error message is present

## Edge case tests

### Test 1: <edge case name>
- **What**: <what edge case>
- **Input**: <input that triggers edge case>
- **Expected**: <expected behavior>
- **Command**:
```bash
curl -s -w "\n%{http_code}" -X POST http://localhost:3000/api/<path> \
  -H "Content-Type: application/json" \
  -d '<edge case payload>'
```

## DB verification (if applicable)

### Migration test
```bash
<npx prisma migrate deploy | knex migrate:latest>
```

### Schema verification
```bash
<psql -c "SELECT column_name, data_type FROM information_schema.columns WHERE table_name = '<table>'">
```

### Data round-trip
```bash
# Insert
<psql -c "INSERT INTO <table> (...) VALUES (...) RETURNING id">

# Query
<psql -c "SELECT * FROM <table> WHERE id = <id>">

# Cleanup
<psql -c "DELETE FROM <table> WHERE id = <id>">
```

## UI verification (if applicable)

### Component tests — Tier 1 (FAST, blocking, ~14ms/test)
<Component-level tests using Vitest + Happy DOM or Jest + jsdom. No browser needed.>

```bash
# Command to run component tests
<npx vitest run --environment happy-dom src/components/<component>.test.ts>
```

### Pages to check — Tier 2 (FAST, blocking, <1s/page)
<Pages to verify with Playwright accessibility snapshot. Builder runs these and reads the a11y tree.>

- `http://localhost:<port>/<path>` — <what to look for in a11y tree>

### Expected UI state (for a11y snapshot verification)
- <element role>: <expected text/name>
- <element role>: <expected text/name>

### Visual tests — Tier 3 (SLOW, background, 4-10s/page)
<Playwright screenshot or visual regression tests. Builder runs these in background — does NOT wait.>

```bash
# Background visual test command
<npx playwright test --reporter=json --output=./shared/work/<LINEAR-ID>/playwright-report.json>
```

### Pages for visual verification
- `http://localhost:<port>/<path>` — <what visual aspects to check>

## Acceptance test checklist
<Map to acceptance criteria from spec.md. Each criterion has a specific verification method.>

- [ ] Criterion 1: <how to verify — specific command or check>
- [ ] Criterion 2: <how to verify>
- [ ] Criterion 3: <how to verify>

## Smoke tests (for post-deploy verification by Infra)
<Subset of integration tests safe to run against production. No destructive operations.>

### Smoke 1: Health check
```bash
curl -sf <production-url>/health
```
- **Expected**: `200 OK`

### Smoke 2: <read-only endpoint>
```bash
curl -s <production-url>/api/<read-only-endpoint>
```
- **Expected**: `200 OK` with valid response shape

## Test results
<Filled in by builder/reviewer/infra after running tests>

| Test | Agent | Phase | Result | Notes |
|------|-------|-------|--------|-------|
| | | | | |
