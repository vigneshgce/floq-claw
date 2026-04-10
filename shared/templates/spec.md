# SPEC: <LINEAR-ID>

## Metadata
- **Linear ticket**: <LINEAR-ID> — <title>
- **URL**: <linear-url>
- **Created**: <date>
- **Author**: Architect (groomed from Linear ticket)

## Problem statement
<What problem does this solve? Why does it matter?>

## Requested outcome
<What should the end result look like?>

## Scope

### In scope
- [ ] <item 1>
- [ ] <item 2>

### Out of scope
- <explicitly excluded items>

## Acceptance criteria
- [ ] <criterion 1 — specific, testable, with verification method>
- [ ] <criterion 2>
- [ ] <criterion 3>

## Affected repos
- <repo 1>: <which services, which directories, which files>
- <repo 2>: <which services, which directories, which files>

## Technical approach
<Step-by-step implementation plan, referencing specific files and existing patterns>

### Architecture
<How does this fit into the existing system?>

### Data model changes
<Any DB schema changes, new tables, migrations — include column types and constraints>

### API changes
<New endpoints, modified endpoints, request/response shapes>

## Decisions
- <decision 1>: <choice made> — <rationale, why not the alternatives>
- <decision 2>: <choice made> — <rationale>

## Risks
- <risk 1>: <mitigation>
- <risk 2>: <mitigation>

## Contract changes
- **API**: <endpoint, method, request/response payload changes>
- **Schema**: <DB migration — table, columns, types, constraints>
- **Events**: <queue/topic changes if any>

## Rollout and rollback
- **Deploy order**: <which services first, any sequencing>
- **Feature flags**: <if needed>
- **Rollback procedure**: <how to revert safely>

## Files to modify
- `<path/to/file1>`: <what changes are needed>
- `<path/to/file2>`: <what changes are needed>

## Test plan
- <what tests to write>
- <what existing tests to update>
- <acceptance test verification commands>

## Open questions
- [ ] <should be empty for READY status — move answered questions to Decisions>
