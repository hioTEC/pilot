# Methodology

Managed by pilot. Do not edit manually — updates via `install-global.sh`.

---

## Session Lifecycle

1. **Bootstrap:** Read this file → read MEMORY.md → read `tracks.md` → read active plan (if any)
2. **Work:** Follow stage/track awareness, decision trail and memory protocols below
3. **Close:** Run `/wrap` for audit, memory extraction, and track status update

### Session Discipline

- Read existing code before modifying it
- Track progress in docs, keep status updated
- Sub-agents: only for heavy tools (context7, playwright) or explorations > 15K tokens; otherwise read directly

---

## Tracks & Stages

### Tracks

A track is a parallel line of work with its own progression. Tracked in `tracks.md` in project memory.

Each track has: **name** | **stage** | **scope** (repos/modules) | **intent** (one line)

- No priority, no dependencies, no deadlines — agent judges context from project state and user's current interest
- User may work on any track at any time, including "unimportant" details
- Agent suggests next stage when current one completes, but never forces

### Stages

A track moves through stages. Not every track uses every stage. Stages can be revisited.

```
ideate → plan → implement → review → ship → qa → ops → done
```

| Stage | What happens | Completion signal |
|-------|-------------|-------------------|
| ideate | Explore the problem, challenge assumptions | User commits to a direction |
| plan | Architecture, scope, approach | Plan written or agreed verbally |
| implement | Write code | Feature works locally |
| review | Code review, find bugs CI won't catch | Review passes |
| ship | PR, merge, deploy | Merged and deployed |
| qa | Test in real environment (browser, API, etc.) | No blocking issues |
| ops | Monitor, fix production issues | Stable |
| done | Wrap up, record learnings | /wrap captures it |

### Stage transitions

When a stage completes, **suggest** the next stage and relevant skill (if available):
- "Review 通过了，要 `/ship` 吗？"
- "已经部署，要跑一轮 `/qa` 吗？"

If no skill exists for a stage yet, just describe what to do. Skills are added incrementally.

---

## Decision Trail

Every non-obvious decision leaves a trace:

- **What to record:** Technical choices, architecture direction, process changes, trade-offs
- **Format:** Immutable events in `events/YYYYMMDD-{description}.md`
- **Key rule:** If you chose A over B, say why — future agents need that context

---

## Memory Protocol

### Progressive Loading (L0/L1/L2)

| Level | Content | When to read |
|-------|---------|--------------|
| L0 | MEMORY.md index — one-line per file | Always (session start) |
| L1 | First 25 lines of a memory file (after frontmatter) | When topic is relevant |
| L2 | Full file (line 26+) | When details are needed |

### Memory Types

| Type | Location | Mutability | Purpose |
|------|----------|------------|---------|
| event | `events/` | Immutable | Decisions, milestones |
| case | `cases/` | Immutable | Problem → solution pairs |
| pattern | `patterns/` | Mergeable | Reusable workflows |
| toolbox | `toolbox/` | Updatable | Cross-project tools, accelerators |
| project | `project_*.md` | Updatable | Project overview |
| reference | `reference_*.md` | Updatable | External pointers |

### Rules

- `events/` and `cases/`: create only, never edit or delete
- All other types: read fully + deduplicate before modifying
- Before creating: check MEMORY.md index for existing entries
- After changes: notify user with filename and summary
- Multi-file types use directories; single files stay at root

### Active Learning

Before high-risk actions (data migration, bulk operations, architecture changes, component deletion):
**search `cases/` for relevant lessons first.**

---

## Quality Gates

- Test before declaring done
- Run `verify.sh` for automated quality checks (typecheck, lint, test, build)
- Each failure includes WHAT failed and HOW TO FIX

---

## /wrap Audit

Every session ends with `/wrap`, which:

1. Extracts decisions → `events/`
2. Extracts problem-solutions → `cases/`
3. Updates project state and patterns
4. Reports decision recording rate and cases consultation
