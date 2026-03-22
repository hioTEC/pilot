Pre-landing code review. Run before /ship.

## Step 0: Detect base branch

```bash
git remote show origin | grep 'HEAD branch' | awk '{print $NF}'
```

If not on a feature branch (i.e. on main/master), warn and ask whether to continue.

## Step 1: Gather context

```bash
BASE=$(git merge-base origin/{base} HEAD)
git diff $BASE..HEAD --stat
git diff $BASE..HEAD
git log $BASE..HEAD --oneline
```

If diff is empty, stop — nothing to review.

## Step 2: Scope check

Count files changed. If > 20 files, flag as large PR — suggest splitting unless it's a refactor or migration.

## Step 3: Two-pass review

### Pass 1 — CRITICAL (must fix before merge)

Check the diff for:

| Category | Look for |
|----------|----------|
| **SQL & Data** | Raw SQL without parameterization, DROP/TRUNCATE without migration guard, missing WHERE on UPDATE/DELETE |
| **Race conditions** | Shared mutable state, check-then-act without lock, concurrent writes to same resource |
| **Security** | Hardcoded secrets, user input in shell commands, XSS (dangerouslySetInnerHTML, v-html), open redirects |
| **Auth boundaries** | Missing permission checks, token leakage in logs, privilege escalation paths |
| **Error handling** | Swallowed errors that hide failures, catch-all that masks bugs |

For each finding: quote the exact line, explain the risk, suggest a fix.

### Pass 2 — INFORMATIONAL (improve but don't block)

| Category | Look for |
|----------|----------|
| **Dead code** | Unreachable branches, unused imports/variables, commented-out code |
| **Magic numbers** | Unexplained literals that should be constants |
| **Naming** | Misleading names, inconsistent conventions |
| **Test gaps** | New code paths without tests, edge cases not covered |
| **Simplification** | Overly complex logic that could be clearer |

## Step 4: Fix-first pipeline

For each finding, classify:

- **AUTO-FIX**: Dead imports, trivial typos, missing semicolons, unused variables — fix directly, don't ask
- **ASK**: Anything that changes behavior, architecture questions, ambiguous intent

Apply auto-fixes, then present remaining items to user.

## Step 5: Summary

```
## Review Summary

**Scope:** {N} files, {M} insertions, {K} deletions
**CRITICAL:** {count} ({list or "none"})
**INFORMATIONAL:** {count}
**Auto-fixed:** {count}

**Verdict:** SHIP IT / NEEDS FIXES / NEEDS DISCUSSION
```

If verdict is SHIP IT, suggest running `/ship`.

## Notes

- Review the actual diff, not the whole file — focus on what changed
- Don't nitpick style if the project has a linter
- $ARGUMENTS: if provided, focus review on that area (e.g. "security", "performance")
