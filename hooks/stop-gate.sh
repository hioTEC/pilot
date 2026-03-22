#!/usr/bin/env bash
# stop-gate.sh — Claude Code "Stop" hook handler.
#
# Runs verification before allowing Claude to finish a task.
# If verification fails, returns a message telling Claude what to fix.
#
# Claude Code hook config (add to .claude/settings.json):
# {
#   "hooks": {
#     "Stop": [{
#       "command": "/home/ubuntu/pilot/harness/hooks/stop-gate.sh",
#       "timeout": 120000
#     }]
#   }
# }

set -euo pipefail

# Read hook input from stdin
INPUT=$(cat)

# Determine project path from the stop event
# The hook receives the current working directory context
PROJECT_PATH=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
if [ -z "$PROJECT_PATH" ]; then
  PROJECT_PATH="$(pwd)"
fi

# Only run for managed projects
PILOT_DIR="$(dirname "$(dirname "$(dirname "$(realpath "$0")")")")"
MANAGED=$(jq -r ".projects[] | select(.path == \"$PROJECT_PATH\") | .name" "$PILOT_DIR/pilot.json" 2>/dev/null)

if [ -z "$MANAGED" ]; then
  # Not a managed project, allow stop
  exit 0
fi

# Run verification
VERIFY_OUTPUT=$("$PILOT_DIR/harness/scripts/verify.sh" "$PROJECT_PATH" 2>&1) || {
  # Verification failed — block stop and tell Claude what to fix
  echo "VERIFICATION FAILED. Fix the following issues before completing:"
  echo ""
  echo "$VERIFY_OUTPUT" | grep -E "(FAIL:|HOW TO FIX:)" || echo "$VERIFY_OUTPUT"
  exit 2  # exit 2 = block the action
}

# All passed
exit 0
