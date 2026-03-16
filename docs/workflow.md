# Autonomous Development Workflow

## Roles

| Role | Who | Responsibility |
|------|-----|----------------|
| **Pilot** | You (human) | Direction, priorities, approve/reject |
| **Engine** | Claude Code | Implement in isolated worktrees |
| **Harness** | Scripts + hooks | Verify quality automatically |
| **Reviewer** | Codex / claude -p | Structured code review |

## The loop

```
1. Pilot writes a TODO (GitHub Issue / direct instruction / memory)
      ↓
2. Engine picks up task
      ↓
3. Engine creates worktree branch
      ↓
4. Engine implements (code + tests)
      ↓
5. Harness auto-runs: typecheck → lint → unit test → build
      ├── fail → Engine reads agent-friendly error → fixes → goto 5
      └── pass ↓
6. Engine runs E2E tests + captures screenshots
      ↓
7. Engine opens PR with:
      - Summary of changes
      - Test results
      - Screenshots/evidence
      ↓
8. Reviewer (Codex) inspects:
      - Logic correctness
      - Consistency with project conventions
      - Security
      - Posts structured comments
      ↓
9. Pilot reviews:
      - Glance at screenshots ("does this look right?")
      - Read Codex review summary
      - Approve → merge
      - Reject → comment why → goto 4
```

## Key principles

### Agent-readable errors
Every failure message should include:
- **WHAT** failed (specific file, line, test name)
- **WHERE** in the codebase
- **HOW TO FIX** (actionable next step, not just the error code)

### Evidence-based PRs
Every PR should include proof that the change works:
- Screenshot for UI changes
- Test output for logic changes
- Before/after comparison for bug fixes

### Entropy management
Periodically run a background agent to:
- Detect pattern drift (code that diverges from conventions)
- Find stale TODOs
- Update documentation that fell out of sync
- Submit cleanup PRs

## Commands

```bash
# Verify a project manually
./harness/scripts/verify.sh /path/to/project

# Install harness to a new project
./harness/install.sh /path/to/project

# Run Claude in headless mode for a task
claude -p "implement feature X" \
  --allowedTools "Read,Edit,Write,Bash,Glob,Grep" \
  --append-system-prompt "Run verify.sh before finishing"
```
