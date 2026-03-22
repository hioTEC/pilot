#!/usr/bin/env bash
# post-edit-lint.sh — Claude Code "PostToolUse" hook for Edit/Write tools.
#
# After editing a file, runs typecheck on just that file to catch errors early
# instead of waiting until the end.
#
# Claude Code hook config:
# {
#   "hooks": {
#     "PostToolUse": [{
#       "matcher": "Edit|Write",
#       "command": "/home/ubuntu/pilot/harness/hooks/post-edit-lint.sh",
#       "timeout": 30000
#     }]
#   }
# }

set -euo pipefail

INPUT=$(cat)

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // empty' 2>/dev/null)

if [ -z "$FILE_PATH" ] || [[ ! "$FILE_PATH" =~ \.(ts|tsx)$ ]]; then
  exit 0
fi

# Find the project root (look for tsconfig.json)
DIR=$(dirname "$FILE_PATH")
while [ "$DIR" != "/" ]; do
  if [ -f "$DIR/tsconfig.json" ]; then
    # Quick single-file type check
    cd "$DIR"
    ERRORS=$(npx tsc --noEmit 2>&1 | grep -c "error TS" || true)
    if [ "$ERRORS" -gt 0 ]; then
      echo "TypeCheck: $ERRORS error(s) detected after editing $FILE_PATH"
      echo "Run 'npx tsc --noEmit' in $DIR to see details."
    fi
    break
  fi
  DIR=$(dirname "$DIR")
done

exit 0
