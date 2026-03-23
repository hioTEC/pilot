#!/usr/bin/env bash
# bootstrap.sh — SessionStart hook
# Auto-inject context on new conversation: methodology → MEMORY → tools → tracks → plan
#
# Note: set -euo pipefail + ls glob with no matches = non-zero exit.
# Use nullglob or || true for optional globs to avoid hook errors.
set -euo pipefail

INPUT=$(cat)
CLAUDE_DIR="$HOME/.claude"

# Derive project memory path: /Users/hio → -Users-hio
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
[ -z "$CWD" ] && exit 0
PROJECT_KEY=$(echo "$CWD" | sed 's|/|-|g')
MEMORY_DIR="$CLAUDE_DIR/projects/$PROJECT_KEY/memory"

section() { echo ""; echo "--- $1 ---"; }

# 0. Machine identification — match tailscale IP against machines.yaml
# Customize MACHINES_YAML path to your infra config
MACHINES_YAML="$HOME/.dotfiles/infra/machines.yaml"
if command -v tailscale &>/dev/null && [ -f "$MACHINES_YAML" ]; then
  TS_IP=$(tailscale ip -4 2>/dev/null || true)
  if [ -n "$TS_IP" ]; then
    MACHINE=$(grep -B20 "$TS_IP" "$MACHINES_YAML" 2>/dev/null | grep 'name:' | tail -1 | sed 's/.*name:\s*//' | tr -d ' ' || true)
    if [ -n "$MACHINE" ]; then
      section "machine"
      echo "Current machine: $MACHINE (tailscale: $TS_IP)"
      grep -A20 "name: $MACHINE" "$MACHINES_YAML" 2>/dev/null | head -20 || true
    fi
  fi
fi

# 1. Methodology
section "methodology"
cat "$CLAUDE_DIR/methodology.md" 2>/dev/null || true

# 2. MEMORY.md (project index)
if [ -f "$MEMORY_DIR/MEMORY.md" ]; then
  section "MEMORY"
  cat "$MEMORY_DIR/MEMORY.md"
fi

# 3. Tools
section "tools"
cat "$CLAUDE_DIR/tools.md" 2>/dev/null || true

# 4. Tracks
if [ -f "$MEMORY_DIR/tracks.md" ]; then
  section "tracks"
  cat "$MEMORY_DIR/tracks.md"
fi

# 5. Active plan (most recent plan file)
PLAN_FILE=$(ls -t "$MEMORY_DIR"/plan*.md 2>/dev/null | head -1) || true
if [ -n "${PLAN_FILE:-}" ]; then
  section "active plan"
  cat "$PLAN_FILE"
fi
