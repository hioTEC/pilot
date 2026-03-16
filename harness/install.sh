#!/usr/bin/env bash
# install.sh — Apply pilot harness to a target project.
#
# What it does:
#   1. Copies AGENTS.md template to the project (if not exists)
#   2. Configures Claude Code hooks in project settings
#   3. Sets up basic test infrastructure if missing
#
# Usage: ./install.sh /path/to/project

set -euo pipefail

PILOT_DIR="$(dirname "$(dirname "$(realpath "$0")")")"
TARGET="${1:?Usage: ./install.sh /path/to/project}"

if [ ! -d "$TARGET" ]; then
  echo "Error: $TARGET is not a directory"
  exit 1
fi

echo "Installing pilot harness to: $TARGET"
echo ""

# 1. AGENTS.md
if [ ! -f "$TARGET/AGENTS.md" ]; then
  cp "$PILOT_DIR/templates/AGENTS.md" "$TARGET/AGENTS.md"
  echo "[+] Created AGENTS.md"
else
  echo "[=] AGENTS.md already exists, skipping"
fi

# 2. Claude Code hooks
SETTINGS_DIR="$TARGET/.claude"
SETTINGS_FILE="$SETTINGS_DIR/settings.json"
mkdir -p "$SETTINGS_DIR"

if [ ! -f "$SETTINGS_FILE" ]; then
  cat > "$SETTINGS_FILE" << SETTINGS
{
  "hooks": {
    "Stop": [
      {
        "command": "$PILOT_DIR/harness/hooks/stop-gate.sh",
        "timeout": 120000
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "command": "$PILOT_DIR/harness/hooks/post-edit-lint.sh",
        "timeout": 30000
      }
    ]
  }
}
SETTINGS
  echo "[+] Created .claude/settings.json with hooks"
else
  echo "[=] .claude/settings.json already exists"
  echo "    To add hooks manually, see: $PILOT_DIR/harness/hooks/"
fi

# 3. Register in pilot.json
PROJECT_NAME=$(basename "$TARGET")
ALREADY_REGISTERED=$(jq -r ".projects[] | select(.path == \"$TARGET\") | .name" "$PILOT_DIR/pilot.json" 2>/dev/null)

if [ -z "$ALREADY_REGISTERED" ]; then
  TEMP=$(mktemp)
  jq ".projects += [{
    \"name\": \"$PROJECT_NAME\",
    \"path\": \"$TARGET\",
    \"harness\": {\"typecheck\": true, \"lint\": true, \"test\": \"vitest\", \"e2e\": \"playwright\", \"build\": true},
    \"status\": \"installed\"
  }]" "$PILOT_DIR/pilot.json" > "$TEMP" && mv "$TEMP" "$PILOT_DIR/pilot.json"
  echo "[+] Registered in pilot.json"
else
  echo "[=] Already registered in pilot.json"
fi

echo ""
echo "Done. Harness installed."
echo "  - verify:  $PILOT_DIR/harness/scripts/verify.sh $TARGET"
echo "  - hooks:   active on next Claude Code session in $TARGET"
