#!/usr/bin/env bash
# check-freeze.sh — PreToolUse hook for Edit/Write
# Blocks file edits outside the frozen directory boundary.
#
# Hook config (settings.json):
# {
#   "hooks": {
#     "PreToolUse": [{
#       "matcher": "Edit|Write",
#       "command": "~/.claude/hooks/check-freeze.sh",
#       "timeout": 5000
#     }]
#   }
# }
#
# Set freeze boundary: echo "/path/to/dir/" > ~/.claude/freeze-dir.txt
# Remove freeze: rm ~/.claude/freeze-dir.txt

set -euo pipefail

FREEZE_FILE="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/freeze-dir.txt"

# No freeze active — allow everything
[ -f "$FREEZE_FILE" ] || exit 0

FREEZE_DIR=$(cat "$FREEZE_FILE")
[ -z "$FREEZE_DIR" ] && exit 0

# Ensure trailing slash to prevent partial matches (/src vs /src-old)
FREEZE_DIR="${FREEZE_DIR%/}/"

INPUT=$(cat)

# Extract file_path from JSON
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // empty' 2>/dev/null)
[ -z "$FILE_PATH" ] && exit 0

# Normalize path
if [[ "$FILE_PATH" != /* ]]; then
    FILE_PATH="$(pwd)/$FILE_PATH"
fi

# Check if file is within freeze boundary
case "$FILE_PATH" in
    "${FREEZE_DIR}"*)
        exit 0  # Inside boundary — allow
        ;;
    *)
        echo "{\"permissionDecision\":\"deny\",\"message\":\"Edit blocked: $FILE_PATH is outside freeze boundary ($FREEZE_DIR). Remove ~/.claude/freeze-dir.txt to unfreeze.\"}"
        exit 0
        ;;
esac
