Commit, push, and create PR. Runs to completion — only stops for conflicts or test failures.

## Step 0: Pre-flight

```bash
git status
git branch --show-current
```

- If on main/master: stop. Create a branch first or ask user for branch name.
- If working tree is dirty: stage and commit (atomic, descriptive message).

## Step 1: Sync with base

```bash
BASE=$(git remote show origin | grep 'HEAD branch' | awk '{print $NF}')
git fetch origin $BASE
git merge origin/$BASE
```

If merge conflict: stop, show conflicts, ask user to resolve.

## Step 2: Run tests

Detect and run the project's test suite:

| Detect | Command |
|--------|---------|
| `package.json` has `test` script | `npm test` or `bun test` |
| `Makefile` has `test` target | `make test` |
| `pytest.ini` or `pyproject.toml` | `pytest` |
| `go.mod` | `go test ./...` |
| None found | Skip, note "no tests detected" |

If tests fail: stop, show failures, ask user to fix.

## Step 3: Review diff

Quick self-review of what's about to ship:

```bash
git log origin/$BASE..HEAD --oneline
git diff origin/$BASE..HEAD --stat
```

Scan for obvious issues: debug prints, TODO/FIXME, hardcoded secrets, commented-out code. Fix trivially bad stuff (debug prints, console.logs left behind). Flag anything questionable.

## Step 4: Push

```bash
git push -u origin $(git branch --show-current)
```

## Step 5: Create PR

```bash
gh pr create --title "{title}" --body "$(cat <<'EOF'
## Summary
{bullet points from commit history}

## Changes
{file-level summary}

## Test plan
{what was tested, what to verify}
EOF
)"
```

PR title: short, imperative mood, under 70 chars.
PR body: summarize the why, list key changes, describe test plan.

## Step 6: Report

```
## Shipped

**Branch:** {branch}
**PR:** {url}
**Commits:** {count}
**Files:** {count} changed

{any warnings or notes}
```

## Notes

- Never force-push unless explicitly asked
- If $ARGUMENTS contains a branch name, use it for the new branch
- If $ARGUMENTS contains "draft", create a draft PR
- Respect project's commit conventions if visible from git log
