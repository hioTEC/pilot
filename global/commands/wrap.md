整理当前会话的记忆，准备收尾。

## 记忆系统说明

Claude Code 有两套记忆机制，/wrap 需要同时处理：

1. **Auto-memory**（系统内置）— 类型：user, feedback, project, reference
   - 位置：`~/.claude/projects/{project-hash}/memory/`
   - 通过 Write 工具写入，格式有 frontmatter（name, description, type）
   - 索引文件：同目录下的 `MEMORY.md`

2. **Project memory**（dotfiles 扩展）— 类型：event, case, pattern, toolbox
   - 位置：同上目录，通过子目录区分（`events/`, `cases/`, `patterns/`, `toolbox/`）
   - events/ 和 cases/ 不可变（只建不改不删）
   - patterns/ 和 toolbox/ 可合并更新

两套共存于同一个 memory 目录，通过类型区分。

## 步骤

### 1. 定位记忆目录

读取当前项目的 `MEMORY.md`。如果不存在，说明当前项目没有启用 memory，跳过写入步骤，只做审计。

### 2. 回顾会话，提取候选记忆

逐类检查，对照 MEMORY.md 索引去重：

**Auto-memory 类型（写入 memory 根目录）：**
- **feedback**: 用户纠正了哪些做法？确认了哪些非显而易见的方式？
- **project**: 项目状态有变化吗？（阶段推进、服务上下线、依赖变更）
- **reference**: 发现了新的外部资源指针吗？
- **user**: 了解到关于用户的新信息吗？（角色、偏好、知识）

**Project 扩展类型（写入子目录）：**
- **event**: 本次做了哪些非显而易见的决策？→ `events/YYYYMMDD-{描述}.md`（不可变）
- **case**: 解决了哪些棘手问题？→ `cases/case-{描述}-YYYYMMDD.md`（不可变）
- **pattern**: 发现了哪些可复用流程？→ `patterns/pattern-{名称}.md`（新建或合并）

### 3. 写入

每个文件遵循格式：
```markdown
---
name: {名称}
description: {一行描述，用于未来判断相关性}
type: {类型}
---

{内容 — feedback/project 类型用 rule/fact + **Why:** + **How to apply:** 结构}
```

写完后更新 MEMORY.md 索引，为每个新建/修改的文件添加一行描述。

### 4. 更新 tracks

读取 `tracks.md`，更新：
- 推进了哪个 track？stage 是否变化？
- 有没有新 track 或完成的 track？
- 下次 session 建议从哪里继续？

### 5. 审计摘要

```
## /wrap 审计

### 记忆
- 新建: {列出文件名}
- 更新: {列出文件名}
- 跳过: {去重跳过的}

### Tracks
- 推进: {track} {old_stage} → {new_stage}
- 新增/完成: ...

### 下次建议
- 从 {track} 的 {stage} 继续
- 待办: {CLAUDE.md 修改建议等}
```

## 注意事项
- 不确定是否值得记录时，宁可记录
- events/ 和 cases/ 不可变 — 只建不改不删
- 审计是 harness 迭代的数据源，不是惩罚机制
- $ARGUMENTS 如果非空，作为额外上下文
