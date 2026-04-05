#!/usr/bin/env bash
# setup.sh — Set up the floq-claw OpenClaw profile
#
# Usage: ./scripts/setup.sh [--api-key <linear-api-key>]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=== Floq-Claw Setup ==="
echo ""

# Check dependencies
echo "Checking dependencies..."
for cmd in curl jq git gh; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: $cmd is not installed" >&2
    exit 1
  fi
  echo "  $cmd: OK"
done

# Check if OpenClaw is installed
if command -v openclaw &>/dev/null; then
  echo "  openclaw: OK ($(openclaw --version 2>/dev/null || echo 'unknown'))"
else
  echo "  openclaw: NOT FOUND"
  echo "  Install: npm install -g openclaw@latest"
fi

# Check if Railway CLI is installed
if command -v railway &>/dev/null; then
  echo "  railway: OK"
else
  echo "  railway: NOT FOUND (optional — needed for infra agent)"
  echo "  Install: npm install -g @railway/cli"
fi

echo ""

# Set up Linear API key
LINEAR_KEY_FILE="$PROJECT_ROOT/skills/linear/.linear-api-key"

if [[ "${1:-}" == "--api-key" && -n "${2:-}" ]]; then
  echo "$2" > "$LINEAR_KEY_FILE"
  chmod 600 "$LINEAR_KEY_FILE"
  echo "Linear API key saved to $LINEAR_KEY_FILE"
elif [[ ! -f "$LINEAR_KEY_FILE" ]]; then
  echo "No Linear API key found."
  echo "Please provide your Linear API key:"
  echo ""
  echo "  ./scripts/setup.sh --api-key lin_api_XXXXX"
  echo ""
  echo "Or manually:"
  echo "  echo 'lin_api_XXXXX' > $LINEAR_KEY_FILE"
  echo "  chmod 600 $LINEAR_KEY_FILE"
  echo ""
else
  echo "Linear API key: already configured"
fi

# Test Linear API if key exists
if [[ -f "$LINEAR_KEY_FILE" ]]; then
  echo ""
  echo "Testing Linear API connection..."
  if "$PROJECT_ROOT/skills/linear/linear.sh" list-states &>/dev/null; then
    echo "  Linear API: connected successfully"
  else
    echo "  Linear API: connection failed — check your API key"
  fi
fi

# Create work directory
mkdir -p "$PROJECT_ROOT/shared/work"
mkdir -p "$PROJECT_ROOT/shared/reviews"

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "  1. Ensure your Linear API key is configured"
echo "  2. Copy openclaw.json to ~/.openclaw/ or use 'openclaw config load ./openclaw.json'"
echo "  3. Start the gateway: openclaw gateway start"
echo "  4. Send a message to the router agent to begin"
