#!/usr/bin/env bash
# install-global.sh — Deploy pilot harness to ~/.claude/
#
# Detects machine identity and Claude Code paths automatically.
# Supports macOS, Linux, and Windows (WSL).
#
# Deploys:
#   1. Machine identity    → ~/.claude/machine-id
#   2. CLAUDE.md           → ~/.claude/CLAUDE.md (symlink)
#   3. methodology.md      → ~/.claude/methodology.md (symlink)
#   4. commands/            → ~/.claude/commands/*.md (symlinks)
#
# Note: Memory is NOT managed by pilot. Memory lives in each project's
# git repo (e.g., dotfiles/.claude/memory/) and is linked via install-project.sh.
#
# Usage: ./install-global.sh [machine-name]
#   If machine-name is omitted, auto-detects from hostname.

set -euo pipefail

PILOT_DIR="$(dirname "$(realpath "$0")")"
CLAUDE_DIR="$HOME/.claude"
COMMANDS_DIR="$CLAUDE_DIR/commands"
MACHINE_ID_FILE="$CLAUDE_DIR/machine-id"

# ── Machine detection ──────────────────────────────────────────────

detect_os() {
    case "$(uname -s)" in
        Darwin)  echo "macos" ;;
        Linux)
            if grep -qi microsoft /proc/version 2>/dev/null; then
                echo "wsl"
            else
                echo "linux"
            fi ;;
        MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
        *)       echo "unknown" ;;
    esac
}

detect_machine() {
    local os hostname_short
    os="$(detect_os)"
    hostname_short="$(hostname -s 2>/dev/null || hostname)"

    # Try to match against known machines
    case "$hostname_short" in
        *macbook*|*MacBook*) echo "macbook" ;;
        *mac-mini*|*mini*)   echo "mac-mini" ;;
        *) echo "$hostname_short" ;;
    esac
}

OS="$(detect_os)"
MACHINE_NAME="${1:-$(detect_machine)}"

# ── Setup ──────────────────────────────────────────────────────────

mkdir -p "$COMMANDS_DIR"

echo "┌─ Pilot Global Install ─────────────────────"
echo "│ Machine:    $MACHINE_NAME"
echo "│ OS:         $OS"
echo "│ Home:       $HOME"
echo "│ Claude dir: $CLAUDE_DIR"
echo "└─────────────────────────────────────────────"
echo ""

# Helper: create symlink (replace existing file or symlink)
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

# 1. Machine identity
echo "$MACHINE_NAME" > "$MACHINE_ID_FILE"
echo "[+] machine-id: $MACHINE_NAME"

# 2. CLAUDE.md
link "$PILOT_DIR/global/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
echo "[+] CLAUDE.md"

# 3. methodology.md
link "$PILOT_DIR/global/methodology.md" "$CLAUDE_DIR/methodology.md"
echo "[+] methodology.md"

# 4. Commands — symlink all .md files in commands/
for cmd in "$PILOT_DIR"/global/commands/*.md; do
    name="$(basename "$cmd")"
    link "$cmd" "$COMMANDS_DIR/$name"
    echo "[+] /${name%.md} command"
done

echo ""
echo "Done. Machine '$MACHINE_NAME' registered."
echo ""
echo "Next: run install-project.sh for each project:"
echo "  ./install-project.sh /path/to/project"
echo ""
echo "For home-directory memory (global memory), link dotfiles:"
echo "  ./install-project.sh /path/to/dotfiles --home"
