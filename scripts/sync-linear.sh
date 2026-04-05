#!/usr/bin/env bash
# sync-linear.sh — Sync work packet status to/from Linear
#
# Usage:
#   ./scripts/sync-linear.sh status <LINEAR-ID>   # Show status of work packet + Linear ticket
#   ./scripts/sync-linear.sh sync <LINEAR-ID>      # Sync local status to Linear comment
#   ./scripts/sync-linear.sh list                   # List all active work packets

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LINEAR_SH="$PROJECT_ROOT/skills/linear/linear.sh"
WORK_DIR="$PROJECT_ROOT/shared/work"

cmd_status() {
  local linear_id="$1"
  local packet_dir="$WORK_DIR/$linear_id"

  echo "=== Work Packet: $linear_id ==="
  echo ""

  if [[ -d "$packet_dir" ]]; then
    echo "--- Local Status ---"
    if [[ -f "$packet_dir/status.md" ]]; then
      cat "$packet_dir/status.md"
    else
      echo "(no status.md)"
    fi
    echo ""
  else
    echo "No local work packet found."
    echo ""
  fi

  echo "--- Linear Ticket ---"
  if [[ -x "$LINEAR_SH" ]]; then
    "$LINEAR_SH" get "$linear_id" 2>/dev/null || echo "Ticket not found in Linear"
  else
    echo "Linear CLI not available"
  fi
}

cmd_sync() {
  local linear_id="$1"
  local packet_dir="$WORK_DIR/$linear_id"

  if [[ ! -d "$packet_dir" ]]; then
    echo "ERROR: No work packet found for $linear_id" >&2
    exit 1
  fi

  if [[ ! -f "$packet_dir/status.md" ]]; then
    echo "ERROR: No status.md in work packet" >&2
    exit 1
  fi

  # Extract state from status.md
  local state
  state=$(grep -oP '(?<=\*\*State\*\*: )\S+' "$packet_dir/status.md" || echo "unknown")

  # Build sync comment
  local comment="**Agent Status Sync**\n"
  comment+="- State: $state\n"
  comment+="- Pipeline: $(grep -oP '(?<=\*\*Pipeline\*\*: )\S+' "$packet_dir/status.md" || echo "unknown")\n"

  if [[ -f "$packet_dir/tasks.md" ]]; then
    local total
    total=$(grep -c '^\- \[' "$packet_dir/tasks.md" || echo 0)
    local done
    done=$(grep -c '^\- \[x\]' "$packet_dir/tasks.md" || echo 0)
    comment+="- Tasks: $done/$total complete\n"
  fi

  # Get branch/PR links
  local branch
  branch=$(grep -oP '(?<=\*\*Branch\*\*: ).*' "$packet_dir/status.md" || echo "")
  local pr
  pr=$(grep -oP '(?<=\*\*PR\*\*: ).*' "$packet_dir/status.md" || echo "")

  [[ -n "$branch" ]] && comment+="- Branch: $branch\n"
  [[ -n "$pr" ]] && comment+="- PR: $pr\n"

  echo -e "$comment"
  echo ""

  if [[ -x "$LINEAR_SH" ]]; then
    "$LINEAR_SH" comment "$linear_id" "$(echo -e "$comment")"
    echo "Synced status to Linear."
  else
    echo "Linear CLI not available — could not sync."
  fi
}

cmd_list() {
  echo "=== Active Work Packets ==="
  echo ""

  if [[ ! -d "$WORK_DIR" ]]; then
    echo "No work directory found."
    exit 0
  fi

  local found=0
  for dir in "$WORK_DIR"/*/; do
    [[ -d "$dir" ]] || continue
    local name
    name=$(basename "$dir")
    [[ "$name" == "_TEMPLATE" ]] && continue

    local state="unknown"
    local pipeline="unknown"
    if [[ -f "$dir/status.md" ]]; then
      state=$(grep -oP '(?<=\*\*State\*\*: )\S+' "$dir/status.md" 2>/dev/null || echo "unknown")
      pipeline=$(grep -oP '(?<=\*\*Pipeline\*\*: )\S+' "$dir/status.md" 2>/dev/null || echo "unknown")
    fi

    echo "  $name | $state | $pipeline"
    found=$((found + 1))
  done

  if [[ "$found" -eq 0 ]]; then
    echo "  (no active work packets)"
  fi

  echo ""
  echo "Total: $found packets"
}

# --- Main ---

if [[ $# -lt 1 ]]; then
  echo "Usage: sync-linear.sh <command> [args...]" >&2
  echo "" >&2
  echo "Commands:" >&2
  echo "  status <LINEAR-ID>   Show work packet + Linear ticket status" >&2
  echo "  sync <LINEAR-ID>     Sync local status to Linear comment" >&2
  echo "  list                 List all active work packets" >&2
  exit 1
fi

COMMAND="$1"
shift

case "$COMMAND" in
  status)
    [[ $# -lt 1 ]] && { echo "Usage: sync-linear.sh status <LINEAR-ID>" >&2; exit 1; }
    cmd_status "$1"
    ;;
  sync)
    [[ $# -lt 1 ]] && { echo "Usage: sync-linear.sh sync <LINEAR-ID>" >&2; exit 1; }
    cmd_sync "$1"
    ;;
  list)
    cmd_list
    ;;
  *)
    echo "ERROR: Unknown command: $COMMAND" >&2
    exit 1
    ;;
esac
