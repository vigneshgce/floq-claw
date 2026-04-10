# Active Work Queue

Use this file as the top-level index for Work IDs and ownership.

## Rules
- Keep exactly one active owner per Work ID.
- Keep execution serial per Work ID.
- Allow global concurrency across unrelated Work IDs.
- Update this file whenever owner or state changes.

## Agents
- `architect`: grooming owner (state: grooming → designed/groomed)
- `builder`: implementation owner (state: in_progress → review_pending)
- `reviewer`: review gate (state: reviewing → done)

## Queue
| Work ID | Owner | State | Last Updated (UTC) | Branch/PR Links |
| --- | --- | --- | --- | --- |
