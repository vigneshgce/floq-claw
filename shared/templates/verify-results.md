# Verification Results: <LINEAR-ID>

## Verification run
- **Timestamp**: <ISO timestamp>
- **Agent**: <builder | reviewer | infra>
- **Phase**: <build-time | review-time | post-deploy>
- **Attempt**: <N> of 3

## Lint / Typecheck
- **Command**: `<lint command>`
- **Result**: <PASS | FAIL>
- **Output**:
```
<stdout/stderr if relevant>
```

## Test Suite
- **Command**: `<test command>`
- **Result**: <PASS | FAIL> (<N passed, N failed>)
- **Output**:
```
<test summary output>
```

## API Tests
| Endpoint | Method | Expected Status | Actual Status | Response Check | Result |
|----------|--------|-----------------|---------------|----------------|--------|
| <path> | <GET/POST/...> | <200> | <200> | <body assertion> | <PASS/FAIL> |

## DB Verification
- **Migration**: <applied successfully | N/A | failed — detail>
- **Schema check**: <verified | N/A | mismatch — detail>
- **Data round-trip**: <PASS | N/A | FAIL — detail>
- **Rollback test**: <PASS | N/A | FAIL — detail>

## UI Verification
- **Method**: <DOM snapshot | screenshot + vision | N/A>
- **Pages checked**: <list of URLs>
- **Result**: <PASS | FAIL | N/A>
- **Findings**:
```
<DOM snapshot or vision model assessment>
```

## Log Analysis
- **Source**: <local dev server | Railway logs | N/A>
- **Command**: `<log command>`
- **Errors found**: <none | list>
- **Warnings found**: <none | list>

## Failures & Fixes
| Attempt | Failure | Root Cause | Fix Applied | Re-run Result |
|---------|---------|------------|-------------|---------------|
| <1> | <what failed> | <why> | <what was changed> | <PASS/FAIL> |

## Post-Deploy Verification (Infra only)
- **Service**: <service name>
- **Health endpoint**: <URL> — <PASS | FAIL>
- **Smoke tests**: <N/N passed>
- **Log errors (last 5 min)**: <none | list>
- **Deployment ID**: <railway deployment id>

## Overall Verdict
- **Result**: <PASS | FAIL>
- **Blockers**: <none | list of what couldn't be verified and why>
- **Notes**: <any additional context>
