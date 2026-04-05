#!/usr/bin/env bash
# create-work-packet.sh — Create a work packet folder from a Linear ticket
#
# Usage: ./scripts/create-work-packet.sh <LINEAR-ID> [--pipeline SMALL|MEDIUM|BIG]
#
# Creates:
#   ./shared/work/<LINEAR-ID>/
#     ├── spec.md      (BIG only)
#     ├── tasks.md     (MEDIUM + BIG)
#     ├── tests.md     (BIG only)
#     └── status.md    (always)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEMPLATE_DIR="$PROJECT_ROOT/shared/work/_TEMPLATE"
LINEAR_SH="$PROJECT_ROOT/skills/linear/linear.sh"

if [[ $# -lt 1 ]]; then
  echo "Usage: create-work-packet.sh <LINEAR-ID> [--pipeline SMALL|MEDIUM|BIG]" >&2
  exit 1
fi

LINEAR_ID="$1"
shift

PIPELINE="MEDIUM"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pipeline) PIPELINE="${2^^}"; shift 2 ;;
    *) echo "ERROR: Unknown flag: $1" >&2; exit 1 ;;
  esac
done

WORK_DIR="$PROJECT_ROOT/shared/work/$LINEAR_ID"

# Check if already exists
if [[ -d "$WORK_DIR" ]]; then
  echo "Work packet already exists: $WORK_DIR"
  echo "Continuing with existing packet."
  exit 0
fi

# Fetch ticket info from Linear
echo "Fetching ticket $LINEAR_ID from Linear..."
TICKET_INFO=""
if [[ -x "$LINEAR_SH" ]]; then
  TICKET_INFO=$("$LINEAR_SH" get "$LINEAR_ID" 2>/dev/null || echo "")
fi

# Extract title from ticket info
TICKET_TITLE=""
if [[ -n "$TICKET_INFO" ]]; then
  TICKET_TITLE=$(echo "$TICKET_INFO" | head -1 | sed 's/^=== [A-Z]*-[0-9]*: //;s/ ===$//')
fi

# Create work directory
mkdir -p "$WORK_DIR"

# Always create status.md
TIMESTAMP=$(date -u '+%Y-%m-%d %H:%M')
sed \
  -e "s|<LINEAR-ID>|$LINEAR_ID|g" \
  -e "s|<title>|${TICKET_TITLE:-TBD}|g" \
  -e "s|<agent>|router|g" \
  -e "s|<SMALL | MEDIUM | BIG>|$PIPELINE|g" \
  -e "s|<timestamp>|$TIMESTAMP UTC|g" \
  "$TEMPLATE_DIR/status.md" > "$WORK_DIR/status.md"

# Create files based on pipeline
case "$PIPELINE" in
  SMALL)
    echo "Created SMALL work packet: $WORK_DIR"
    echo "  - status.md"
    ;;
  MEDIUM)
    cp "$TEMPLATE_DIR/tasks.md" "$WORK_DIR/tasks.md"
    sed -i "s|<LINEAR-ID>|$LINEAR_ID|g" "$WORK_DIR/tasks.md"
    echo "Created MEDIUM work packet: $WORK_DIR"
    echo "  - status.md"
    echo "  - tasks.md"
    ;;
  BIG)
    cp "$TEMPLATE_DIR/spec.md" "$WORK_DIR/spec.md"
    cp "$TEMPLATE_DIR/tasks.md" "$WORK_DIR/tasks.md"
    cp "$TEMPLATE_DIR/tests.md" "$WORK_DIR/tests.md"
    sed -i "s|<LINEAR-ID>|$LINEAR_ID|g" "$WORK_DIR/spec.md"
    sed -i "s|<LINEAR-ID>|$LINEAR_ID|g" "$WORK_DIR/tasks.md"
    sed -i "s|<LINEAR-ID>|$LINEAR_ID|g" "$WORK_DIR/tests.md"
    echo "Created BIG work packet: $WORK_DIR"
    echo "  - spec.md"
    echo "  - tasks.md"
    echo "  - tests.md"
    echo "  - status.md"
    ;;
  *)
    echo "ERROR: Invalid pipeline: $PIPELINE (expected SMALL, MEDIUM, or BIG)" >&2
    exit 1
    ;;
esac

# Add Linear ticket info if available
if [[ -n "$TICKET_INFO" ]]; then
  echo ""
  echo "Ticket info:"
  echo "$TICKET_INFO" | head -10
fi
