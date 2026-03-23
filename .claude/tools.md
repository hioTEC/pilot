# Tools

工具注册表。工具由 Claude Code 自身管理，不通过 dotfiles/claw。

## gstack (recommended)

26 skills covering plan → design → review → ship → ops → debug lifecycle.

Install: `git clone https://github.com/garrytan/gstack.git ~/.claude/skills/gstack && cd ~/.claude/skills/gstack && ./setup`
Upgrade: `/gstack-upgrade`

**设计文档**: `~/.gstack/projects/{slug}/` — `/office-hours` 等 skill 产出的设计文档存放于此。开始 feature 前先检查该目录是否有 APPROVED 的设计文档。

| Stage | Skills |
|-------|--------|
| Plan | /office-hours, /plan-ceo-review, /plan-eng-review, /plan-design-review |
| Design | /design-consultation, /design-review |
| Review | /review, /qa, /qa-only |
| Ship | /ship, /land-and-deploy, /document-release |
| Ops | /canary, /benchmark, /retro |
| Debug | /investigate |
| Safety | /careful, /freeze, /guard, /unfreeze |
| Browser | /browse, /setup-browser-cookies |
| Meta | /setup-deploy, /codex, /gstack-upgrade |

## Auxiliary Models (optional)

通过 Anthropic 兼容 API 接入第三方模型。密钥用 age secrets 管理。

<!-- Example entry:
| 模型 | Base URL | Key env var | 用途 |
|------|----------|-------------|------|
| model-name | `https://api.example.com/v1` | `MODEL_API_KEY` | context size, strengths |
-->

**调用方式（Anthropic Messages API）：**
```bash
eval "$(secrets env)"
curl -s $BASE_URL/messages \
  -H "x-api-key: $KEY" -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{"model":"MODEL","max_tokens":4096,"messages":[{"role":"user","content":"..."}]}'
```

**Claude Code 后端替换：** 设 `ANTHROPIC_BASE_URL` + `ANTHROPIC_AUTH_TOKEN` 即可让 Claude Code 使用这些模型。

## Plugins (recommended)

由 Claude Code plugin 系统管理：
- **claude-hud** — status line（jarrodwatts/claude-hud）
- **typescript-lsp** — TypeScript 类型检查（official marketplace）
- **pyright-lsp** — Python 类型检查（official marketplace）

---

## Dotfiles 部署 (`setup.sh`)

`setup.sh` 自动 symlink 以下内容到 `~/.claude/` 和 `~/`：

| 源 (dotfiles) | 目标 | 方式 |
|----------------|------|------|
| `.claude/{CLAUDE.md,methodology.md,tools.md}` | `~/.claude/` | 逐文件 symlink |
| `.claude/commands/*.md` | `~/.claude/commands/` | 逐文件 symlink |
| `.claude/hooks/*.sh` | `~/.claude/hooks/` | symlink + chmod +x |
| `.claude/memory/` | `~/.claude/projects/-{home,Users}-$USER/memory` | 整目录 symlink（按平台） |

新增配置文件只需加到 dotfiles 对应目录，`setup.sh` 会自动处理。新机器部署：`~/.dotfiles/setup.sh`。

---

## CI/CD Guidance

Quality gates are handled by gstack's /review and /qa skills, not by custom scripts.

**Agent behavior at review → ship → qa → ops stages:**

- **Proactively introduce** best practices and typical steps — don't assume user knows the flow
- **Adapt to complexity:**
  - Simple (<50 lines) → fast-track: commit, push, done
  - Complex → multi-pass: eng review, design review if frontend, adversarial review for critical paths
- **Track familiarity:** as user masters a workflow, reduce explanation and increase speed. Note growth in memory (feedback type)
