# Methodology

## Session Lifecycle

1. **Bootstrap:** Read this file → MEMORY.md → `tracks.md` → active plan
2. **Work:** Follow tracks/stages, update memory in-place
3. **Checkpoint:** At natural milestones — update `tracks.md`, update feedback if behavior guidance changed
4. **Close:** Run `/wrap`

- Read existing code before modifying. Sub-agents only for explorations > 15K tokens.

---

## Tracks & Stages

Track = parallel line of work: **name** | **stage** | **scope** | **intent**

No priority, no deadlines. Agent suggests next stage, never forces.

Tracks live in three sections:
- **Active** — currently being worked on
- **Shelved** — direction confirmed, not actively pursued. Don't proactively suggest unless user brings up
- **Done** — completed

```
ideate → plan → implement → review → ship → qa → ops → done
```

| Stage | What | Signal |
|-------|------|--------|
| ideate | Challenge assumptions | User commits to direction |
| plan | Architecture, scope | Plan agreed |
| implement | Write code | Works locally |
| review | Find bugs CI won't | Review passes |
| ship | PR, merge, deploy | Merged |
| qa | Test in real env | No blockers |
| ops | Monitor, fix prod | Stable |
| done | Record learnings | /wrap done |

### Stage Gate

Track 切换 stage 时，agent 必须检查：

1. 相关文档是否反映当前状态
2. 是否有过时 memory 需要更新/归档
3. `plans/` 里的计划是否完成或需要更新

不是自动化 hook，是 agent 人工检查的规则。

### Plans

实施计划存放在项目 `plans/` 目录。一个 track 一个 plan。

格式：`YYYYMMDD-{name}.md`，包含 goal、architecture、tasks with checkboxes。

---

## Decision Trail

Non-obvious decisions → comment next to the code/config they describe. Not a separate file.

If you chose A over B, the rationale belongs where someone would look when changing that code.

---

## Memory Protocol

Memory = small set of living documents. Update over create. Delete when stale.

**What goes in memory:**
- **feedback** — behavior guidance from user (corrections + confirmations)
- **patterns** — reusable workflows
- **tracks** — current work state

**What does NOT go in memory:**
- Anything derivable from code, git log, or current file state
- Decision rationale (→ comment in the relevant code/config)
- Session logs or activity summaries (→ git log)
- File paths or project structure (→ read the filesystem)

**Rules:**
- Update existing files, don't create new ones for the same topic
- /wrap updates feedback + tracks, doesn't create immutable artifacts
- If MEMORY.md exceeds ~30 lines, something is wrong — simplify
