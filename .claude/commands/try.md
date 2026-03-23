评估一个新工具。$ARGUMENTS 是 GitHub URL 或工具名。

**不自动安装。** 克隆 + 研究 + 给出意见，用户确认后再装。

## 步骤

1. **克隆** — 到 ~/repos/，如果已存在就跳过
2. **研究** — 读 README、核心代码结构、安装方式，搞清楚：
   - 它解决什么问题
   - 怎么安装、有什么依赖
   - 侵入性如何（改多少配置、装多少东西）
3. **分类** — 判断工具类型：
   - `tool` — 独立 skill 包（如 gstack）
   - `plugin` — Claude Code 插件（如 claude-hud）
   - `mcp` — MCP server
4. **结合现有架构给出意见** — 读 `infra/repos.yaml` 和当前工具状态，回答：
   - 跟现有工具是否重叠或冲突
   - 适合什么角色（替代某个 archived 工具？补充空缺？）
   - 推荐 trial 还是不值得试
5. **等用户决定** — 用户说装再装。装完后注册到 `infra/repos.yaml`，`status: trial`

## 注意

- trust 默认 read-only
- 不自动安装，不自动改配置
- 如果工具需要 API key，提示但不代填
