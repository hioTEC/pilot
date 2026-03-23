归档一个工具。$ARGUMENTS 是工具名。

## 步骤

1. **找到工具** — 在 `infra/repos.yaml` 中定位
2. **更新状态** — `status: trial` 或 `status: active` → `status: archived`
3. **清理集成** — 如果工具在 ~/.claude/ 下注册了 commands/hooks/mcp，列出但不自动删除
4. **报告** — 说明归档了什么，有哪些残留配置需要手动清理

## 注意

- 不删除文件和目录 — 归档只改状态
- 如果用户想彻底删除，需要明确说
