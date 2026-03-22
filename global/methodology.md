# Methodology

Managed by pilot. Do not edit manually — updates via `install-global.sh`.

---

## Session Lifecycle

1. **Bootstrap:** Read this file → read MEMORY.md → read active plan (if any)
2. **Work:** Follow decision trail and memory protocols below
3. **Close:** Run `/wrap` for audit and memory extraction

### Session Discipline

- Read existing code before modifying it
- Track progress in docs, keep status updated
- Sub-agents: only for heavy tools (context7, playwright) or explorations > 15K tokens; otherwise read directly

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
