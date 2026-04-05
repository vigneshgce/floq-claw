# TESTS: <LINEAR-ID>

## Metadata
- **Linear ticket**: <LINEAR-ID>
- **Spec**: ./spec.md
- **Tester**: reviewer / builder

## Unit tests
<Tests that verify individual functions/modules>

### Test 1: <name>
- **What**: <what it tests>
- **Expected**: <expected result>
- **Command**: `npm test -- --grep "<test name>"`

## Integration tests
<Tests that verify API endpoints / service interactions>

### Test 1: <endpoint name>
- **What**: <what it tests>
- **Method**: <HTTP method>
- **Endpoint**: <path>
- **Request**:
```bash
curl -X POST http://localhost:3000/api/<path> \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{
    "field": "value"
  }'
```
- **Expected response**: `200 OK`
```json
{
  "success": true,
  "data": {}
}
```

## Edge case tests

### Test 1: <edge case name>
- **What**: <what edge case>
- **Input**: <input that triggers edge case>
- **Expected**: <expected behavior>
- **Command**:
```bash
curl -X POST http://localhost:3000/api/<path> \
  -H "Content-Type: application/json" \
  -d '{}'
```
- **Expected**: `400 Bad Request` with validation error

## Acceptance test checklist
<Map to acceptance criteria from spec.md>

- [ ] Criterion 1: <how to verify>
- [ ] Criterion 2: <how to verify>
- [ ] Criterion 3: <how to verify>

## Test results
<Filled in by builder/reviewer after running tests>

| Test | Result | Notes |
|------|--------|-------|
| | | |
