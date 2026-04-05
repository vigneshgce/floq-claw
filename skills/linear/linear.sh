#!/usr/bin/env bash
# linear.sh — Linear API tool for reading/updating/creating tickets
# Auth: reads API key from .linear-api-key in script directory
#
# Usage:
#   linear.sh get <ID-or-URL>              # Get ticket details + comments
#   linear.sh comment <ID-or-URL> <text>   # Add a comment (markdown)
#   linear.sh search <query>               # Search tickets (text search)
#   linear.sh update <ID-or-URL> <field> <value>      # Update state/priority
#   linear.sh create "<title>" [options]               # Create a new ticket
#   linear.sh list-states                              # List all workflow states
#   linear.sh assign <ID-or-URL> "<name>"              # Assign ticket

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_KEY_FILE="${SCRIPT_DIR}/.linear-api-key"
LINEAR_API="https://api.linear.app/graphql"

# --- Auth ---

if [[ ! -f "$API_KEY_FILE" ]]; then
  echo "ERROR: API key file not found at $API_KEY_FILE" >&2
  echo "Create a Linear personal API key at: Linear -> Settings -> Security & Access -> API" >&2
  echo "Save the key to: $API_KEY_FILE" >&2
  exit 1
fi

API_KEY="$(cat "$API_KEY_FILE" | tr -d '[:space:]')"

if [[ -z "$API_KEY" ]]; then
  echo "ERROR: API key file is empty: $API_KEY_FILE" >&2
  exit 1
fi

# --- Helpers ---

parse_identifier() {
  local input="$1"

  if [[ "$input" =~ ^https?://linear\.app/.*/issue/([A-Za-z]+-[0-9]+) ]]; then
    echo "${BASH_REMATCH[1]}"
    return
  fi

  if [[ "$input" =~ ^[A-Za-z]+-[0-9]+$ ]]; then
    echo "$input"
    return
  fi

  echo "ERROR: Cannot parse Linear identifier from: $input" >&2
  echo "Expected format: TEAM-123 or https://linear.app/.../issue/TEAM-123/..." >&2
  return 1
}

graphql_query() {
  local query="$1"
  local response

  response=$(curl -sS --max-time 30 \
    "$LINEAR_API" \
    -H "Content-Type: application/json" \
    -H "Authorization: $API_KEY" \
    --data-raw "$query" 2>&1) || {
    echo "ERROR: curl failed: $response" >&2
    exit 1
  }

  if echo "$response" | jq -e '.errors' >/dev/null 2>&1; then
    echo "ERROR: Linear API returned errors:" >&2
    echo "$response" | jq -r '.errors[].message' >&2
    exit 1
  fi

  echo "$response"
}

get_issue_id() {
  local identifier="$1"
  local lookup_query
  lookup_query=$(jq -nc --arg id "$identifier" '{
    "query": "query($id: String!) { issue(id: $id) { id identifier } }",
    "variables": { "id": $id }
  }')

  local lookup_response
  lookup_response=$(graphql_query "$lookup_query")

  local issue_id
  issue_id=$(echo "$lookup_response" | jq -r '.data.issue.id // empty')

  if [[ -z "$issue_id" ]]; then
    echo "ERROR: Ticket $identifier not found" >&2
    return 1
  fi

  echo "$issue_id"
}

# --- Commands ---

cmd_get() {
  if [[ $# -lt 1 ]]; then
    echo "Usage: linear.sh get <ID-or-URL>" >&2
    exit 1
  fi

  local identifier
  identifier=$(parse_identifier "$1")

  local query
  query=$(jq -nc --arg id "$identifier" '{
    "query": "query($id: String!) { issue(id: $id) { id identifier title description url priority priorityLabel state { name type } assignee { name } team { name key } labels { nodes { name } } parent { identifier title } children { nodes { identifier title state { name } } } comments(first: 20) { nodes { body createdAt user { name } } } createdAt updatedAt } }",
    "variables": { "id": $id }
  }')

  local response
  response=$(graphql_query "$query")

  local issue
  issue=$(echo "$response" | jq '.data.issue // empty')

  if [[ -z "$issue" || "$issue" == "null" ]]; then
    echo "ERROR: Ticket $identifier not found" >&2
    exit 1
  fi

  echo "$issue" | jq -r '
    "=== " + .identifier + ": " + .title + " ===",
    "URL: " + .url,
    "Status: " + (.state.name // "unknown") + " (" + (.state.type // "unknown") + ")",
    "Priority: " + (.priorityLabel // "none"),
    "Assignee: " + (.assignee.name // "unassigned"),
    "Team: " + (.team.name // "unknown") + " (" + (.team.key // "") + ")",
    "Labels: " + (if (.labels.nodes | length) > 0 then ([.labels.nodes[].name] | join(", ")) else "none" end),
    "Parent: " + (if .parent then .parent.identifier + " — " + .parent.title else "none" end),
    "Created: " + (.createdAt // "unknown"),
    "Updated: " + (.updatedAt // "unknown"),
    "",
    "--- Description ---",
    (.description // "(no description)"),
    ""
  '

  # Print sub-issues if any
  local child_count
  child_count=$(echo "$issue" | jq '.children.nodes | length')

  if [[ "$child_count" -gt 0 ]]; then
    echo "--- Sub-issues ($child_count) ---"
    echo "$issue" | jq -r '.children.nodes[] |
      "  " + .identifier + " [" + (.state.name // "?") + "] " + .title
    '
    echo ""
  fi

  # Print comments
  local comment_count
  comment_count=$(echo "$issue" | jq '.comments.nodes | length')

  if [[ "$comment_count" -gt 0 ]]; then
    echo "--- Comments ($comment_count) ---"
    echo "$issue" | jq -r '.comments.nodes[] |
      "\(.user.name // "unknown") (\(.createdAt // "")):",
      .body,
      ""
    '
  else
    echo "--- Comments (0) ---"
    echo "(no comments)"
  fi
}

cmd_comment() {
  if [[ $# -lt 2 ]]; then
    echo "Usage: linear.sh comment <ID-or-URL> <text>" >&2
    exit 1
  fi

  local identifier
  identifier=$(parse_identifier "$1")
  local comment_text="$2"

  local issue_id
  issue_id=$(get_issue_id "$identifier")

  local mutation
  mutation=$(jq -nc --arg issueId "$issue_id" --arg body "$comment_text" '{
    "query": "mutation($issueId: String!, $body: String!) { commentCreate(input: { issueId: $issueId, body: $body }) { success comment { id body createdAt } } }",
    "variables": { "issueId": $issueId, "body": $body }
  }')

  local response
  response=$(graphql_query "$mutation")

  local success
  success=$(echo "$response" | jq -r '.data.commentCreate.success')

  if [[ "$success" == "true" ]]; then
    echo "Comment added to $identifier successfully."
    echo "$response" | jq -r '.data.commentCreate.comment | "  ID: " + .id + "\n  Created: " + .createdAt'
  else
    echo "ERROR: Failed to add comment to $identifier" >&2
    echo "$response" | jq '.' >&2
    exit 1
  fi
}

cmd_search() {
  if [[ $# -lt 1 ]]; then
    echo "Usage: linear.sh search <query>" >&2
    exit 1
  fi

  local search_text="$1"

  local query
  query=$(jq -nc --arg q "$search_text" '{
    "query": "query($q: String!) { searchIssues(term: $q, first: 15) { nodes { identifier title state { name } assignee { name } priorityLabel updatedAt url } } }",
    "variables": { "q": $q }
  }')

  local response
  response=$(graphql_query "$query")

  local count
  count=$(echo "$response" | jq '.data.searchIssues.nodes | length')

  if [[ "$count" -eq 0 ]]; then
    echo "No tickets found matching: $search_text"
    exit 0
  fi

  echo "=== Search Results ($count) ==="
  echo ""

  echo "$response" | jq -r '.data.searchIssues.nodes[] |
    .identifier + " | " + (.state.name // "?") + " | " + (.priorityLabel // "?") + " | " + (.assignee.name // "unassigned") + " | " + .title,
    "  " + .url,
    ""
  '
}

cmd_update() {
  if [[ $# -lt 3 ]]; then
    echo "Usage: linear.sh update <ID-or-URL> <field> <value>" >&2
    echo "" >&2
    echo "Fields:" >&2
    echo "  priority <0-4>         Set priority (0=none, 1=urgent, 2=high, 3=medium, 4=low)" >&2
    echo "  state <state-name>     Set state (e.g., 'In Progress', 'Done', 'Backlog')" >&2
    exit 1
  fi

  local identifier
  identifier=$(parse_identifier "$1")
  local field="$2"
  local value="$3"

  local issue_id
  issue_id=$(get_issue_id "$identifier")

  case "$field" in
    priority)
      local mutation
      mutation=$(jq -nc --arg issueId "$issue_id" --argjson priority "$value" '{
        "query": "mutation($issueId: String!, $priority: Int!) { issueUpdate(id: $issueId, input: { priority: $priority }) { success issue { identifier priorityLabel } } }",
        "variables": { "issueId": $issueId, "priority": $priority }
      }')
      local response
      response=$(graphql_query "$mutation")
      local success
      success=$(echo "$response" | jq -r '.data.issueUpdate.success')
      if [[ "$success" == "true" ]]; then
        echo "Priority updated on $identifier: $(echo "$response" | jq -r '.data.issueUpdate.issue.priorityLabel')"
      else
        echo "ERROR: Failed to update priority on $identifier" >&2
        exit 1
      fi
      ;;

    state)
      local state_query
      state_query=$(jq -nc --arg name "$value" '{
        "query": "query($name: String!) { workflowStates(filter: { name: { eq: $name } }, first: 1) { nodes { id name } } }",
        "variables": { "name": $name }
      }')
      local state_response
      state_response=$(graphql_query "$state_query")
      local state_id
      state_id=$(echo "$state_response" | jq -r '.data.workflowStates.nodes[0].id // empty')

      if [[ -z "$state_id" ]]; then
        echo "ERROR: State '$value' not found in Linear" >&2
        exit 1
      fi

      local mutation
      mutation=$(jq -nc --arg issueId "$issue_id" --arg stateId "$state_id" '{
        "query": "mutation($issueId: String!, $stateId: String!) { issueUpdate(id: $issueId, input: { stateId: $stateId }) { success issue { identifier state { name } } } }",
        "variables": { "issueId": $issueId, "stateId": $stateId }
      }')
      local response
      response=$(graphql_query "$mutation")
      local success
      success=$(echo "$response" | jq -r '.data.issueUpdate.success')
      if [[ "$success" == "true" ]]; then
        echo "State updated on $identifier: $(echo "$response" | jq -r '.data.issueUpdate.issue.state.name')"
      else
        echo "ERROR: Failed to update state on $identifier" >&2
        exit 1
      fi
      ;;

    *)
      echo "ERROR: Unknown field: $field" >&2
      echo "Valid fields: priority, state" >&2
      exit 1
      ;;
  esac
}

cmd_create() {
  if [[ $# -lt 1 ]]; then
    echo "Usage: linear.sh create \"<title>\" [--desc \"<markdown>\"] [--priority 0-4] [--label \"<name>\"] [--parent <ID>] [--state \"<name>\"] [--team <UUID>]" >&2
    exit 1
  fi

  local title="$1"
  shift

  # Default team — update this to your team UUID
  local team_id=""
  local description=""
  local priority=""
  local label_name=""
  local parent_id=""
  local state_name=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --desc)     description="$2"; shift 2 ;;
      --priority) priority="$2"; shift 2 ;;
      --label)    label_name="$2"; shift 2 ;;
      --parent)   parent_id="$2"; shift 2 ;;
      --state)    state_name="$2"; shift 2 ;;
      --team)     team_id="$2"; shift 2 ;;
      *)
        echo "ERROR: Unknown flag: $1" >&2
        exit 1
        ;;
    esac
  done

  # If no team specified, auto-detect from first team
  if [[ -z "$team_id" ]]; then
    local teams_query
    teams_query='{"query": "{ teams(first: 1) { nodes { id name key } } }"}'
    local teams_response
    teams_response=$(graphql_query "$teams_query")
    team_id=$(echo "$teams_response" | jq -r '.data.teams.nodes[0].id // empty')

    if [[ -z "$team_id" ]]; then
      echo "ERROR: No teams found. Specify --team <UUID>" >&2
      exit 1
    fi
  fi

  local input
  input=$(jq -nc --arg title "$title" --arg teamId "$team_id" '{
    "title": $title,
    "teamId": $teamId
  }')

  if [[ -n "$description" ]]; then
    input=$(echo "$input" | jq --arg desc "$description" '. + { "description": $desc }')
  fi

  if [[ -n "$priority" ]]; then
    input=$(echo "$input" | jq --argjson p "$priority" '. + { "priority": $p }')
  fi

  if [[ -n "$label_name" ]]; then
    local label_query
    label_query=$(jq -nc --arg name "$label_name" '{
      "query": "query($name: String!) { issueLabels(filter: { name: { eq: $name } }, first: 1) { nodes { id name } } }",
      "variables": { "name": $name }
    }')
    local label_response
    label_response=$(graphql_query "$label_query")
    local label_id
    label_id=$(echo "$label_response" | jq -r '.data.issueLabels.nodes[0].id // empty')

    if [[ -z "$label_id" ]]; then
      echo "WARNING: Label '$label_name' not found — creating ticket without label" >&2
    else
      input=$(echo "$input" | jq --arg lid "$label_id" '. + { "labelIds": [$lid] }')
    fi
  fi

  if [[ -n "$parent_id" ]]; then
    local parent_identifier
    parent_identifier=$(parse_identifier "$parent_id")
    local parent_uuid
    parent_uuid=$(get_issue_id "$parent_identifier")
    input=$(echo "$input" | jq --arg pid "$parent_uuid" '. + { "parentId": $pid }')
  fi

  if [[ -n "$state_name" ]]; then
    local state_query
    state_query=$(jq -nc --arg name "$state_name" '{
      "query": "query($name: String!) { workflowStates(filter: { name: { eq: $name } }, first: 1) { nodes { id name } } }",
      "variables": { "name": $name }
    }')
    local state_response
    state_response=$(graphql_query "$state_query")
    local state_id
    state_id=$(echo "$state_response" | jq -r '.data.workflowStates.nodes[0].id // empty')

    if [[ -z "$state_id" ]]; then
      echo "WARNING: State '$state_name' not found — using default state" >&2
    else
      input=$(echo "$input" | jq --arg sid "$state_id" '. + { "stateId": $sid }')
    fi
  fi

  local mutation
  mutation=$(jq -nc --argjson input "$input" '{
    "query": "mutation($input: IssueCreateInput!) { issueCreate(input: $input) { success issue { identifier title url state { name } priorityLabel labels { nodes { name } } } } }",
    "variables": { "input": $input }
  }')

  local response
  response=$(graphql_query "$mutation")

  local success
  success=$(echo "$response" | jq -r '.data.issueCreate.success')

  if [[ "$success" == "true" ]]; then
    echo "$response" | jq -r '.data.issueCreate.issue |
      "Created: " + .identifier + " — " + .title,
      "URL: " + .url,
      "State: " + (.state.name // "default"),
      "Priority: " + (.priorityLabel // "none"),
      "Labels: " + (if (.labels.nodes | length) > 0 then ([.labels.nodes[].name] | join(", ")) else "none" end)
    '
  else
    echo "ERROR: Failed to create ticket" >&2
    echo "$response" | jq '.' >&2
    exit 1
  fi
}

cmd_list_states() {
  local query='{"query": "{ workflowStates(first: 50) { nodes { id name type team { name key } } } }"}'

  local response
  response=$(graphql_query "$query")

  echo "=== Workflow States ==="
  echo ""
  echo "$response" | jq -r '.data.workflowStates.nodes | sort_by(.team.key, .type) | .[] |
    (.team.key // "?") + " | " + .type + " | " + .name + " | " + .id
  '
}

cmd_assign() {
  if [[ $# -lt 2 ]]; then
    echo "Usage: linear.sh assign <ID-or-URL> <user-name>" >&2
    exit 1
  fi

  local identifier
  identifier=$(parse_identifier "$1")
  local user_name="$2"

  local issue_id
  issue_id=$(get_issue_id "$identifier")

  # Find user by name
  local user_query
  user_query=$(jq -nc --arg name "$user_name" '{
    "query": "query($name: String!) { users(filter: { name: { containsIgnoreCase: $name } }, first: 1) { nodes { id name } } }",
    "variables": { "name": $name }
  }')
  local user_response
  user_response=$(graphql_query "$user_query")
  local user_id
  user_id=$(echo "$user_response" | jq -r '.data.users.nodes[0].id // empty')

  if [[ -z "$user_id" ]]; then
    echo "ERROR: User '$user_name' not found in Linear" >&2
    exit 1
  fi

  local mutation
  mutation=$(jq -nc --arg issueId "$issue_id" --arg assigneeId "$user_id" '{
    "query": "mutation($issueId: String!, $assigneeId: String!) { issueUpdate(id: $issueId, input: { assigneeId: $assigneeId }) { success issue { identifier assignee { name } } } }",
    "variables": { "issueId": $issueId, "assigneeId": $assigneeId }
  }')

  local response
  response=$(graphql_query "$mutation")

  local success
  success=$(echo "$response" | jq -r '.data.issueUpdate.success')

  if [[ "$success" == "true" ]]; then
    local assigned_name
    assigned_name=$(echo "$response" | jq -r '.data.issueUpdate.issue.assignee.name')
    echo "Assigned $identifier to $assigned_name"
  else
    echo "ERROR: Failed to assign $identifier" >&2
    exit 1
  fi
}

# --- Main ---

if [[ $# -lt 1 ]]; then
  echo "Usage: linear.sh <command> [args...]" >&2
  echo "" >&2
  echo "Commands:" >&2
  echo "  get <ID-or-URL>              Get ticket details + comments" >&2
  echo "  comment <ID-or-URL> <text>   Add a comment to a ticket" >&2
  echo "  search <query>               Search tickets" >&2
  echo "  update <ID-or-URL> <field> <value>  Update ticket field (priority, state)" >&2
  echo "  create \"<title>\" [options]       Create a new ticket" >&2
  echo "  list-states                  List all workflow states" >&2
  echo "  assign <ID-or-URL> <name>    Assign ticket to a user" >&2
  exit 1
fi

COMMAND="$1"
shift

case "$COMMAND" in
  get)         cmd_get "$@" ;;
  comment)     cmd_comment "$@" ;;
  search)      cmd_search "$@" ;;
  update)      cmd_update "$@" ;;
  create)      cmd_create "$@" ;;
  list-states) cmd_list_states ;;
  assign)      cmd_assign "$@" ;;
  *)
    echo "ERROR: Unknown command: $COMMAND" >&2
    echo "Valid commands: get, comment, search, update, create, list-states, assign" >&2
    exit 1
    ;;
esac
