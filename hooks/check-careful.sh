#!/usr/bin/env bash
# check-careful.sh — PreToolUse hook for Bash
# Warns before destructive commands. User can override.
#
# Hook config (settings.json):
# {
#   "hooks": {
#     "PreToolUse": [{
#       "matcher": "Bash",
#       "command": "~/.claude/hooks/check-careful.sh",
#       "timeout": 5000
#     }]
#   }
# }

set -euo pipefail

INPUT=$(cat)

# Extract command from JSON
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$CMD" ] && exit 0

# Safe exceptions — build artifacts, caches
for safe in node_modules .next dist __pycache__ .cache build .turbo coverage .pytest_cache; do
    if [[ "$CMD" =~ rm[[:space:]].*"$safe" ]]; then
        exit 0
    fi
done

# Destructive patterns
check_pattern() {
    local pattern="$1" msg="$2"
    if echo "$CMD" | grep -qE "$pattern"; then
        echo "{\"permissionDecision\":\"ask\",\"message\":\"$msg\"}"
        exit 0
    fi
}

# File destruction
check_pattern 'rm[[:space:]]+-r' "Recursive delete detected. Verify the target path."
check_pattern 'rm[[:space:]]+-f' "Force delete detected. Verify the target path."

# Git history rewrite
check_pattern 'git[[:space:]]+push[[:space:]]+(-f|--force)' "Force push rewrites remote history."
check_pattern 'git[[:space:]]+reset[[:space:]]+--hard' "Hard reset discards uncommitted work."
check_pattern 'git[[:space:]]+checkout[[:space:]]+\.' "Checkout . discards all unstaged changes."
check_pattern 'git[[:space:]]+restore[[:space:]]+\.' "Restore . discards all unstaged changes."
check_pattern 'git[[:space:]]+clean[[:space:]]+-f' "Git clean removes untracked files permanently."

# Database destruction (case-insensitive)
check_pattern '(?i)drop[[:space:]]+(table|database)' "DROP statement detected. Verify this is intentional."
check_pattern '(?i)truncate' "TRUNCATE detected. This deletes all rows."

# Container/infra destruction
check_pattern 'kubectl[[:space:]]+delete' "kubectl delete affects live cluster resources."
check_pattern 'docker[[:space:]]+(rm[[:space:]]+-f|system[[:space:]]+prune)' "Docker destructive operation detected."

# Nothing matched — allow
exit 0
