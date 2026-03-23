整理当前会话的记忆，准备收尾。

## 步骤

### 1. 回顾会话，提取候选记忆

对照 MEMORY.md 索引，逐类检查是否有值得记录的变化：

- **feedback**: 用户纠正或确认了哪些做法？
- **user**: 了解到关于用户的新信息？
- **project**: 项目状态有非显而易见的变化？
- **reference**: 发现了新的外部资源指针？
- **pattern**: 发现了可复用流程？→ `patterns/` 目录

**写入门槛：** 如果能从代码、git log、或当前文件状态推导出来，不记。只记非显而易见的、未来 session 需要但无法自行发现的信息。

**更新优先于新建。** 先检查是否有已有文件可以更新。

### 2. 写入

每个文件遵循格式：
```markdown
---
name: {名称}
description: {一行描述}
type: {feedback | user | project | reference}
---

{内容}
```

写完后更新 MEMORY.md 索引。

### 3. 更新 tracks

读取 `tracks.md`，更新：
- 推进了哪个 track？stage 是否变化？
- 有没有新 track、完成的 track、或状态变更（active ↔ shelved）？

### 3.5. Decision Trail 检查

回顾本次 session 的代码变更，检查是否有非显而易见的决策缺少代码注释：

- 参数选择（batch size、阈值、timeout）
- A over B 的取舍（为什么用这个算法/结构而不是另一个）
- Workaround 或特殊处理的原因

用 `git diff` 或 `git log` 定位本次修改的文件，grep 检查关键修改点是否有注释。缺少的当场补上并 commit。

### 4. 审计摘要

```
## /wrap 审计

### 记忆
- 新建: {列出}
- 更新: {列出}
- 无变化: {跳过原因}

### Tracks
- {变更列表}

### 下次建议
- {从哪里继续}
```

### 5. 同步 dotfiles

```bash
cd ~/.dotfiles
git add -A
git commit -m "memory: wrap $(date +%Y-%m-%d)"
git push
```

## 注意事项
- 不记可推导的信息——git log、代码、文件系统能回答的不存 memory
- events/ 和 cases/ 已废弃，不再使用
- $ARGUMENTS 如果非空，作为额外上下文
