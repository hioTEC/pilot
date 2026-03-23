彻底删除一个工具。$ARGUMENTS 是工具名。

## 步骤

1. **定位** — 在 `infra/repos.yaml` 中找到工具条目
2. **确认** — 向用户确认要删除的内容：
   - 本地目录（如 ~/repos/{name}/）
   - repos.yaml 中的条目
   - 相关的 ~/.claude/ 配置（commands, hooks, mcp, plugins）
3. **用户确认后执行：**
   - 删除本地目录
   - 从 repos.yaml 移除条目
   - 清理 ~/.claude/ 中的相关配置
   - 如果是 plugin：`/plugin uninstall`
   - 如果是 mcp：从 settings.json 移除
4. **报告** — 列出删除了什么

## 注意

- 必须用户明确确认后才删
- 列出所有将被删除的内容，让用户逐项确认
- 如果工具有 status: active，额外警告
