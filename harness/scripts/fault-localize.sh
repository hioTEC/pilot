#!/usr/bin/env bash
# fault-localize.sh — Extract and rank relevant files for a task spec.
# Usage: ./fault-localize.sh <task-spec-text> <project-path>
#
# Searches the project codebase for keywords extracted from the spec,
# scores each file by relevance, and returns the top 8 with snippets.
#
# Output is agent-readable plain text.

set -euo pipefail

SPEC="${1:-}"
PROJECT_PATH="${2:-.}"

if [ -z "$SPEC" ]; then
  echo "Usage: fault-localize.sh <task-spec-text> <project-path>"
  exit 1
fi

cd "$PROJECT_PATH"

# --- Keyword extraction ---
# 1. Explicit file paths (e.g., src/lib/foo.ts, lib/bar.js)
PATHS=$(echo "$SPEC" | grep -oE '[a-zA-Z0-9_/.-]+\.(ts|tsx|js|jsx|css|json|sh|py|sql)' | sort -u || true)

# 2. Quoted strings (single or double)
QUOTED=$(echo "$SPEC" | grep -oE '"[^"]{2,}"' | tr -d '"' || true)
QUOTED+=$'\n'$(echo "$SPEC" | grep -oE "'[^']{2,}'" | tr -d "'" || true)

# 3. Function/method names (camelCase, snake_case identifiers that look technical)
IDENTIFIERS=$(echo "$SPEC" | grep -oE '\b[a-z][a-zA-Z0-9]*[A-Z][a-zA-Z0-9]*\b' | sort -u || true)
IDENTIFIERS+=$'\n'$(echo "$SPEC" | grep -oE '\b[a-z_][a-z0-9_]{3,}\b' | sort -u || true)

# 4. Technical terms (PascalCase, UPPER_CASE constants)
TECH_TERMS=$(echo "$SPEC" | grep -oE '\b[A-Z][a-zA-Z0-9]{2,}\b' | sort -u || true)
TECH_TERMS+=$'\n'$(echo "$SPEC" | grep -oE '\b[A-Z_]{3,}\b' | sort -u || true)

# Combine all keywords, deduplicate, filter out noise
ALL_KEYWORDS=$(echo -e "${PATHS}\n${QUOTED}\n${IDENTIFIERS}\n${TECH_TERMS}" \
  | sed '/^$/d' \
  | grep -vE '^(the|and|that|this|with|from|for|are|was|will|not|but|can|has|have|its|you|your|all|should|would|could|must|may|also|each|when|then|into|only|just|use|used|using|make|like|need|new|run|get|set|add|fix|any|our|one|two)$' \
  | sort -u \
  || true)

if [ -z "$ALL_KEYWORDS" ]; then
  echo "No keywords extracted from spec."
  exit 0
fi

# --- File scoring ---
declare -A FILE_SCORES

# Score from explicit path matches
while IFS= read -r path; do
  [ -z "$path" ] && continue
  if [ -f "$path" ]; then
    FILE_SCORES["$path"]=$(( ${FILE_SCORES["$path"]:-0} + 45 ))
  fi
done <<< "$PATHS"

# Search for each keyword with ripgrep
while IFS= read -r keyword; do
  [ -z "$keyword" ] && continue
  # Skip very short keywords (likely noise)
  [ ${#keyword} -lt 3 ] && continue

  # Search with rg, collect matching files
  MATCHES=$(rg -l --no-messages --max-count 5 -g '!node_modules' -g '!.git' -g '!*.lock' -g '!dist/' -g '!.next/' -- "$keyword" 2>/dev/null || true)

  while IFS= read -r file; do
    [ -z "$file" ] && continue
    FILE_SCORES["$file"]=$(( ${FILE_SCORES["$file"]:-0} + 10 ))
  done <<< "$MATCHES"
done <<< "$ALL_KEYWORDS"

# Apply type bonuses/penalties
for file in "${!FILE_SCORES[@]}"; do
  score=${FILE_SCORES["$file"]}

  # +35 for code files
  if [[ "$file" =~ \.(ts|tsx|js|jsx)$ ]]; then
    score=$((score + 35))
  fi

  # +25 for error-related mentions (test files, error handlers)
  if [[ "$file" =~ (error|Error|test|spec|__test) ]]; then
    score=$((score + 25))
  fi

  # -25 for docs/config files
  if [[ "$file" =~ \.(md|txt|yml|yaml|toml|ini)$ ]] || [[ "$file" =~ (README|LICENSE|CHANGELOG|docs/) ]]; then
    score=$((score - 25))
  fi

  FILE_SCORES["$file"]=$score
done

# --- Sort and output top 8 ---
SORTED=$(for file in "${!FILE_SCORES[@]}"; do
  echo "${FILE_SCORES[$file]} $file"
done | sort -rn | head -8)

if [ -z "$SORTED" ]; then
  echo "No relevant files found for the given spec."
  exit 0
fi

echo "=== FAULT LOCALIZATION RESULTS ==="
echo "Project: $PROJECT_PATH"
echo "Keywords extracted: $(echo "$ALL_KEYWORDS" | wc -l | tr -d ' ')"
echo ""

RANK=1
while IFS= read -r line; do
  [ -z "$line" ] && continue
  SCORE=$(echo "$line" | awk '{print $1}')
  FILE=$(echo "$line" | awk '{print $2}')

  echo "[$RANK] $FILE (score: $SCORE)"

  # Show a short code snippet (first match from any keyword)
  SNIPPET=""
  while IFS= read -r keyword; do
    [ -z "$keyword" ] && continue
    [ ${#keyword} -lt 3 ] && continue
    SNIPPET=$(rg -n --max-count 3 -C 1 --no-messages -- "$keyword" "$FILE" 2>/dev/null | head -12 || true)
    if [ -n "$SNIPPET" ]; then
      break
    fi
  done <<< "$ALL_KEYWORDS"

  if [ -n "$SNIPPET" ]; then
    echo "    ---"
    echo "$SNIPPET" | sed 's/^/    /'
    echo "    ---"
  fi
  echo ""
  RANK=$((RANK + 1))
done <<< "$SORTED"

echo "=== END FAULT LOCALIZATION ==="
