#!/usr/bin/env bash
# install-project.sh — Install pilot project-level harness.
#
# Memory lives inside the project repo (.claude/memory/) so it travels
# with git. This script creates a symlink from Claude Code's expected
# path to the project's in-repo memory directory.
#
# What it does:
#   1. Detects machine and Claude Code project path hash
#   2. Creates {project}/.claude/memory/ with MEMORY.md template (if not exists)
#   3. Symlinks ~/.claude/projects/{hash}/memory/ → {project}/.claude/memory/
#   4. Creates project CLAUDE.md (if not exists)
#   5. Optionally configures hooks
#
# Special: --home flag also creates a home-directory symlink so this
# project's memory is used when Claude Code runs from ~/ (global memory).
#
# Usage:
#   ./install-project.sh /path/to/project [--home] [--hooks=lint,gate]

set -euo pipefail

PILOT_DIR="$(dirname "$(realpath "$0")")"
TARGET="${1:?Usage: ./install-project.sh /path/to/project [--home] [--hooks=lint,gate]}"
CLAUDE_DIR="$HOME/.claude"
MACHINE_ID_FILE="$CLAUDE_DIR/machine-id"

# Parse flags
HOME_FLAG=false
HOOKS_ARG=""
shift
for arg in "$@"; do
    case "$arg" in
        --home)       HOME_FLAG=true ;;
        --hooks=*)    HOOKS_ARG="$arg" ;;
    esac
done

if [ ! -d "$TARGET" ]; then
    echo "Error: $TARGET is not a directory"
    exit 1
fi

# Resolve to absolute path
TARGET="$(cd "$TARGET" && pwd)"

# ── Machine identity ──────────────────────────────────────────────

if [ -f "$MACHINE_ID_FILE" ]; then
    MACHINE_NAME="$(cat "$MACHINE_ID_FILE")"
else
    echo "Error: Run install-global.sh first (no machine-id found)"
    exit 1
fi

# ── Claude Code path hash ─────────────────────────────────────────

PROJECT_HASH=$(echo -n "$TARGET" | tr '/' '-')
CLAUDE_MEMORY_DIR="$CLAUDE_DIR/projects/$PROJECT_HASH/memory"
PROJECT_MEMORY_DIR="$TARGET/.claude/memory"

HOME_HASH=$(echo -n "$HOME" | tr '/' '-')
HOME_MEMORY_DIR="$CLAUDE_DIR/projects/$HOME_HASH/memory"

echo "┌─ Pilot Project Install ────────────────────"
echo "│ Machine:      $MACHINE_NAME"
echo "│ Project:      $TARGET"
echo "│ Project hash: $PROJECT_HASH"
echo "│ In-repo mem:  $PROJECT_MEMORY_DIR"
echo "│ Claude mem:   $CLAUDE_MEMORY_DIR"
if [ "$HOME_FLAG" = true ]; then
echo "│ Home mem:     $HOME_MEMORY_DIR (--home)"
fi
echo "└─────────────────────────────────────────────"
echo ""

# Helper
link() {
    local src="$1" dst="$2"
    if [[ -L "$dst" ]]; then
        rm "$dst"
    elif [[ -e "$dst" ]]; then
        mv "$dst" "${dst}.bak"
        echo "    (backed up ${dst} → ${dst}.bak)"
    fi
    ln -s "$src" "$dst"
}

# 1. In-repo memory directory
if [ ! -f "$PROJECT_MEMORY_DIR/MEMORY.md" ]; then
    mkdir -p "$PROJECT_MEMORY_DIR"
    cp "$PILOT_DIR/project/MEMORY.md" "$PROJECT_MEMORY_DIR/MEMORY.md"
    echo "[+] Created $PROJECT_MEMORY_DIR/MEMORY.md"
else
    echo "[=] $PROJECT_MEMORY_DIR/MEMORY.md exists, skipping"
fi

# 2. Symlink Claude Code memory → in-repo memory
mkdir -p "$(dirname "$CLAUDE_MEMORY_DIR")"
link "$PROJECT_MEMORY_DIR" "$CLAUDE_MEMORY_DIR"
echo "[+] Symlink: $CLAUDE_MEMORY_DIR"

# 3. Home directory symlink (--home): also link ~/ project to this memory
if [ "$HOME_FLAG" = true ]; then
    mkdir -p "$(dirname "$HOME_MEMORY_DIR")"
    link "$PROJECT_MEMORY_DIR" "$HOME_MEMORY_DIR"
    echo "[+] Home symlink: $HOME_MEMORY_DIR"
fi

# 4. Project CLAUDE.md
if [ ! -f "$TARGET/CLAUDE.md" ]; then
    cp "$PILOT_DIR/project/CLAUDE.md" "$TARGET/CLAUDE.md"
    echo "[+] Created CLAUDE.md (fill in project details)"
else
    echo "[=] CLAUDE.md exists, skipping"
fi

# 5. Ensure .claude/memory is not gitignored (it should be tracked)
GITIGNORE="$TARGET/.gitignore"
if [ -f "$GITIGNORE" ]; then
    if grep -q '^\.claude/$' "$GITIGNORE" 2>/dev/null; then
        echo ""
        echo "⚠  .gitignore has '.claude/' — memory won't be tracked."
        echo "   Add '!.claude/memory/' to .gitignore to fix:"
        echo "   .claude/"
        echo "   !.claude/memory/"
    fi
fi

# 6. Hooks (optional)
if [ -n "$HOOKS_ARG" ]; then
    HOOKS_VALUE="${HOOKS_ARG#--hooks=}"

    if [ "$HOOKS_VALUE" = "none" ]; then
        echo "[=] Hooks: skipped"
    else
        SETTINGS_DIR="$TARGET/.claude"
        SETTINGS_FILE="$SETTINGS_DIR/settings.json"
        mkdir -p "$SETTINGS_DIR"

        HOOKS_JSON='{"hooks":{'
        FIRST=true

        if echo "$HOOKS_VALUE" | grep -q "gate"; then
            HOOKS_JSON+="\"Stop\":[{\"hooks\":[{\"type\":\"command\",\"command\":\"$PILOT_DIR/hooks/stop-gate.sh\",\"timeout\":120000}]}]"
            FIRST=false
        fi

        if echo "$HOOKS_VALUE" | grep -q "lint"; then
            if [ "$FIRST" = false ]; then HOOKS_JSON+=","; fi
            HOOKS_JSON+="\"PostToolUse\":[{\"matcher\":\"Edit|Write\",\"hooks\":[{\"type\":\"command\",\"command\":\"$PILOT_DIR/hooks/post-edit-lint.sh\",\"timeout\":30000}]}]"
        fi

        HOOKS_JSON+='}}'

        if [ -f "$SETTINGS_FILE" ]; then
            echo "[=] $SETTINGS_FILE exists — add hooks manually"
        else
            echo "$HOOKS_JSON" | jq '.' > "$SETTINGS_FILE"
            echo "[+] Hooks: $HOOKS_VALUE"
        fi
    fi
fi

echo ""
echo "Done. Memory is in-repo at $PROJECT_MEMORY_DIR"
echo "  - Syncs with git push/pull"
echo "  - Claude Code reads via symlink"
echo "  - On other machines, run: ./install-project.sh $TARGET"
