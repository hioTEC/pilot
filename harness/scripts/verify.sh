#!/usr/bin/env bash
# verify.sh — Run all quality gates for a project.
# Usage: ./verify.sh [project-path] [--fix]
#
# Exit codes:
#   0  all gates passed
#   1  a gate failed (details in output)
#
# Output is designed to be agent-readable:
# each failure includes WHAT failed, WHERE, and HOW TO FIX.

set -euo pipefail

PROJECT_PATH="${1:-.}"
FIX_MODE="${2:-}"

cd "$PROJECT_PATH"

# Colors (skip if not a terminal)
if [ -t 1 ]; then
  GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'; NC='\033[0m'
else
  GREEN=''; RED=''; YELLOW=''; NC=''
fi

PASSED=0
FAILED=0
RESULTS=()

run_gate() {
  local name="$1"
  local cmd="$2"
  local fix_hint="$3"

  echo -e "${YELLOW}[$name]${NC} Running..."
  if eval "$cmd" 2>&1; then
    echo -e "${GREEN}[$name] PASSED${NC}"
    RESULTS+=("PASS: $name")
    ((PASSED++))
  else
    echo -e "${RED}[$name] FAILED${NC}"
    echo -e "${RED}  HOW TO FIX: $fix_hint${NC}"
    RESULTS+=("FAIL: $name — FIX: $fix_hint")
    ((FAILED++))
  fi
  echo ""
}

# Detect project type
if [ -f "package.json" ]; then
  # Node.js / Next.js project
  HAS_TSC=$(jq -r '.devDependencies.typescript // .dependencies.typescript // empty' package.json 2>/dev/null)
  HAS_ESLINT=$(jq -r '.devDependencies.eslint // .dependencies.eslint // empty' package.json 2>/dev/null)
  HAS_VITEST=$(jq -r '.devDependencies.vitest // empty' package.json 2>/dev/null)
  HAS_PLAYWRIGHT=$(jq -r '.devDependencies["@playwright/test"] // empty' package.json 2>/dev/null)
  HAS_BUILD=$(jq -r '.scripts.build // empty' package.json 2>/dev/null)

  if [ -n "$HAS_TSC" ]; then
    run_gate "TypeCheck" \
      "npx tsc --noEmit" \
      "Fix type errors shown above. Run 'npx tsc --noEmit' to see all errors."
  fi

  if [ -n "$HAS_ESLINT" ]; then
    if [ "$FIX_MODE" = "--fix" ]; then
      run_gate "Lint" \
        "npx eslint . --fix" \
        "ESLint auto-fix applied. Review changes."
    else
      run_gate "Lint" \
        "npx eslint ." \
        "Run 'npx eslint . --fix' to auto-fix, then manually fix remaining issues."
    fi
  fi

  if [ -n "$HAS_VITEST" ]; then
    run_gate "UnitTest" \
      "npx vitest run --reporter=verbose" \
      "Fix failing tests. Run 'npx vitest run' to see details."
  fi

  if [ -n "$HAS_PLAYWRIGHT" ]; then
    run_gate "E2E" \
      "npx playwright test" \
      "E2E tests failed. Run 'npx playwright test --ui' for visual debugging."
  fi

  if [ -n "$HAS_BUILD" ]; then
    run_gate "Build" \
      "npm run build" \
      "Build failed. Check the error output above for the specific file and line."
  fi
fi

# Summary
echo "========================================="
echo " VERIFICATION SUMMARY"
echo "========================================="
for r in "${RESULTS[@]}"; do
  echo "  $r"
done
echo ""
echo "  Passed: $PASSED / $((PASSED + FAILED))"

if [ "$FAILED" -gt 0 ]; then
  echo -e "  ${RED}Status: FAILED${NC}"
  exit 1
else
  echo -e "  ${GREEN}Status: ALL PASSED${NC}"
  exit 0
fi
