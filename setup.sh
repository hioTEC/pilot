#!/usr/bin/env bash
set -euo pipefail

# Dotfiles bootstrap — identity, secrets, cloud tools, SSH config
# Usage: git clone <your-dotfiles> ~/.dotfiles && ~/.dotfiles/setup.sh

DOTFILES="$(cd "$(dirname "$0")" && pwd)"

# --- Platform detection ---
detect_platform() {
    case "$(uname -s)" in
        Darwin) PLATFORM="macos" ;;
        Linux)
            if grep -qi microsoft /proc/version 2>/dev/null; then
                PLATFORM="wsl"
            else
                PLATFORM="linux"
            fi ;;
        *) PLATFORM="unknown" ;;
    esac
}

# --- Machine detection ---
detect_machine() {
    if [[ -f "$HOME/.machine-id" ]]; then
        MACHINE="$(cat "$HOME/.machine-id")"
        return
    fi

    # Try hostname match against machines.yaml servers
    local hostname
    hostname="$(hostname)"
    local match
    match=$(python3 -c "
import yaml
with open('${DOTFILES}/infra/machines.yaml') as f:
    data = yaml.safe_load(f)
for s in data.get('servers', []):
    if '$hostname'.startswith(s['name']) or '$hostname' in s.get('alias', []):
        print(s['name']); break
" 2>/dev/null || true)

    if [[ -n "$match" ]]; then
        MACHINE="$match"
        return
    fi

    # Interactive selection — customize for your machines
    echo "Which machine is this?"
    read -rp "> " MACHINE
}

detect_platform
detect_machine
echo "=== dotfiles setup ==="
echo "  Platform: $PLATFORM"
echo "  Machine:  $MACHINE"
echo ""

# --- 1. bin/ → PATH ---
echo "=== CLI tools ==="
chmod +x "${DOTFILES}/bin/"* 2>/dev/null || true

SHELL_RC="$HOME/.bashrc"
[[ "$PLATFORM" == "macos" ]] && SHELL_RC="$HOME/.zshrc"

MARKER="# dotfiles"
if ! grep -q "$MARKER" "$SHELL_RC" 2>/dev/null; then
    cat >> "$SHELL_RC" <<EOF

$MARKER
export DOTFILES_DIR="${DOTFILES}"
export PATH="\${DOTFILES_DIR}/bin:\${PATH}"
[ -f "\${DOTFILES_DIR}/identity/aliases.sh" ] && source "\${DOTFILES_DIR}/identity/aliases.sh"
EOF
    echo "  Added to $SHELL_RC"
else
    echo "  Already in $SHELL_RC"
fi

# --- 2. Secrets ---
echo ""
echo "=== Secrets ==="
if command -v age &>/dev/null; then
    # Find age key
    AGE_KEY=""
    if [[ "$PLATFORM" == "macos" ]] && command -v security &>/dev/null; then
        AGE_KEY=$(security find-generic-password -a "$USER" -s "age-secret-key" -w 2>/dev/null || true)
    fi
    if [[ -z "$AGE_KEY" && -f "$HOME/.config/age/key.txt" ]]; then
        AGE_KEY="file"
    fi

    if [[ -n "$AGE_KEY" ]]; then
        "${DOTFILES}/bin/secrets" env "${DOTFILES}"

        if ! grep -q 'DOTFILES_DIR.*\.env' "$SHELL_RC" 2>/dev/null; then
            echo "[ -f \"\${DOTFILES_DIR}/.env\" ] && source \"\${DOTFILES_DIR}/.env\"" >> "$SHELL_RC"
            echo "  Added .env sourcing to $SHELL_RC"
        fi
    else
        echo "  Warning: age key not found"
        echo "  macOS: security add-generic-password -a \"\$USER\" -s \"age-secret-key\" -w \"KEY\""
        echo "  Linux: mkdir -p ~/.config/age && echo 'KEY' > ~/.config/age/key.txt"
    fi
else
    echo "  Warning: age not installed (apt install age / brew install age)"
fi

# --- 3. Git config ---
echo ""
echo "=== Git identity ==="
if [[ -f "${DOTFILES}/identity/profile.yaml" ]]; then
    GIT_NAME=$(python3 -c "import yaml; print(yaml.safe_load(open('${DOTFILES}/identity/profile.yaml'))['git']['name'])" 2>/dev/null || true)
    GIT_EMAIL=$(python3 -c "import yaml; print(yaml.safe_load(open('${DOTFILES}/identity/profile.yaml'))['git']['email'])" 2>/dev/null || true)
    if [[ -n "$GIT_NAME" ]]; then
        CURRENT_NAME=$(git config --global user.name 2>/dev/null || true)
        if [[ "$CURRENT_NAME" != "$GIT_NAME" ]]; then
            git config --global user.name "$GIT_NAME"
            git config --global user.email "$GIT_EMAIL"
            echo "  Set: $GIT_NAME <$GIT_EMAIL>"
        else
            echo "  Already set: $GIT_NAME <$GIT_EMAIL>"
        fi
    fi
fi

# --- 4. Claude Code config ---
echo ""
echo "=== Claude Code ==="
CLAUDE_DIR="$HOME/.claude"
mkdir -p "$CLAUDE_DIR/commands"

link() {
    local src="$1" dst="$2"
    if [[ -L "$dst" ]]; then rm "$dst"
    elif [[ -e "$dst" ]]; then mv "$dst" "${dst}.bak"; fi
    ln -s "$src" "$dst"
}

# Top-level config files
for cfg in CLAUDE.md methodology.md tools.md settings.json; do
    [[ -f "${DOTFILES}/.claude/$cfg" ]] || continue
    link "${DOTFILES}/.claude/$cfg" "$CLAUDE_DIR/$cfg"
    echo "  [+] $cfg"
done

# Commands
for cmd in "${DOTFILES}"/.claude/commands/*.md; do
    [[ -f "$cmd" ]] || continue
    name="$(basename "$cmd")"
    link "$cmd" "$CLAUDE_DIR/commands/$name"
    echo "  [+] /${name%.md}"
done

# Hooks
if [[ -d "${DOTFILES}/.claude/hooks" ]]; then
    mkdir -p "$CLAUDE_DIR/hooks"
    for hook in "${DOTFILES}"/.claude/hooks/*.sh; do
        [[ -f "$hook" ]] || continue
        name="$(basename "$hook")"
        link "$hook" "$CLAUDE_DIR/hooks/$name"
        chmod +x "$CLAUDE_DIR/hooks/$name"
        echo "  [+] hook: $name"
    done
fi

# Memory — symlink entire directory
if [[ -d "${DOTFILES}/.claude/memory" ]]; then
    PROJ_MEMORY="$CLAUDE_DIR/projects/-home-${USER}/memory"
    [[ "$PLATFORM" == "macos" ]] && PROJ_MEMORY="$CLAUDE_DIR/projects/-Users-${USER}/memory"
    mkdir -p "$(dirname "$PROJ_MEMORY")"
    link "${DOTFILES}/.claude/memory" "$PROJ_MEMORY"
    echo "  [+] memory → $PROJ_MEMORY"
fi

# --- 5. SSH config ---
echo ""
echo "=== SSH config ==="
if [[ -f "${DOTFILES}/bin/ssh-gen-config" ]]; then
    python3 "${DOTFILES}/bin/ssh-gen-config"
fi

# --- 6. Tailscale (optional) ---
echo ""
echo "=== Tailscale ==="
if command -v tailscale &>/dev/null; then
    TS_STATUS=$(tailscale status --json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('BackendState',''))" 2>/dev/null || true)
    if [[ "$TS_STATUS" == "Running" ]]; then
        TS_IP=$(tailscale ip -4 2>/dev/null || true)
        echo "  Already connected: $TS_IP"
    else
        if [[ -n "${TAILSCALE_AUTH_KEY:-}" ]]; then
            echo "  Joining tailnet..."
            sudo tailscale up --auth-key="$TAILSCALE_AUTH_KEY" --hostname="$MACHINE"
            echo "  Connected: $(tailscale ip -4)"
        else
            echo "  Warning: TAILSCALE_AUTH_KEY not found, cannot auto-join"
        fi
    fi
else
    echo "  Not installed (optional)"
fi

# --- 7. Machine ID ---
echo ""
echo "=== Machine ID ==="
echo "$MACHINE" > "$HOME/.machine-id"
echo "  Saved: $MACHINE"

echo ""
echo "=== Done ==="
echo "Run: source $SHELL_RC"
