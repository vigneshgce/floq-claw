---
name: linear
description: Linear project management — ticket CRUD, comments, search, status updates
requires:
  bins:
    - curl
    - jq
---

# Linear Skill

Provides Linear API integration for all agents via `linear.sh`.

## Commands

```bash
linear.sh get <ID-or-URL>                  # Fetch ticket details + comments
linear.sh comment <ID-or-URL> "<text>"     # Add markdown comment
linear.sh search <query>                   # Full-text search (top 15)
linear.sh update <ID-or-URL> <field> <val> # Update state or priority
linear.sh create "<title>" [options]       # Create a new ticket
linear.sh list-states                      # List all workflow states
linear.sh assign <ID-or-URL> "<name>"      # Assign ticket to team member
```

## Create options
```
--desc "<markdown>"    Description body
--priority <0-4>       0=none, 1=urgent, 2=high, 3=medium, 4=low
--label "<name>"       Apply existing label
--parent <ID>          Set parent ticket
--state "<name>"       Set initial state
--team <UUID>          Override default team
```

## Setup
Place your Linear API key in `./skills/linear/.linear-api-key`:
```bash
echo "lin_api_XXXXX" > ./skills/linear/.linear-api-key
chmod 600 ./skills/linear/.linear-api-key
```
