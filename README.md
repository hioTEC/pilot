# pilot

A harness engineering project that makes autonomous AI agent development reliable.

**The idea**: You steer direction (TODOs + memories). Agents develop in isolation. The harness proves quality. You approve results.

## What's inside

```
pilot/
├── harness/
│   ├── hooks/        # Claude Code hook configs (quality gates)
│   ├── scripts/      # Verification scripts (typecheck, lint, test, build)
│   └── install.sh    # Apply harness to a target project
├── templates/
│   ├── AGENTS.md     # Agent instructions template
│   └── CLAUDE.md     # Project-level Claude config template
├── docs/
│   └── workflow.md   # How the autonomous dev loop works
└── pilot.json        # Managed projects registry
```

## Quick start

```bash
# Apply harness to an existing project
./harness/install.sh /path/to/your/project
```

## Workflow

```
You: write a TODO
        ↓
Claude: pick up task → worktree → implement
        ↓
Harness: typecheck → lint → test → build → screenshot
        ├── pass → open PR with evidence
        └── fail → auto-diagnose → retry
        ↓
Reviewer (Codex / claude -p): structured code review
        ↓
You: look at screenshots + review comments → approve/reject
```

## Principles (from harness engineering)

1. **What agents can't see doesn't exist** — all decisions live in the repo
2. **Mechanical enforcement over documentation** — linters and tests, not rules to remember
3. **Give agents eyes** — E2E screenshots, DevTools, observability
4. **Ask what capability is missing, not why the agent failed** — fix the environment
5. **Provide maps, not manuals** — ARCHITECTURE.md shows boundaries and invariants
