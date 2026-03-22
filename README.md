# Pilot — Harness Engineering

A methodology framework for autonomous AI agent development with Claude Code.

## Three Pillars

1. **Decision Trail** — Every non-obvious decision recorded as an immutable event
2. **Progressive Maturity** — Validate before expanding
3. **Agent Autonomy** — Default to action, pause only when genuinely uncertain

## Architecture

Pilot is a **stateless framework**. It provides methodology and tooling — no memory or personal state.

Memory lives in your project repos (e.g., your dotfiles or any project), synced via git.

```
pilot (framework — clone once per machine)
├── global/           CLAUDE.md, methodology.md, commands/
├── project/          Templates for new projects
├── hooks/            Optional quality hooks
├── scripts/          Standalone tools
├── install-global.sh One-time machine setup
└── install-project.sh Per-project memory setup

your-project (state — synced via git)
└── .claude/memory/   Memory files tracked in this repo's git
    ├── MEMORY.md     L0 index (always loaded by agent)
    ├── events/       Decisions & milestones (immutable)
    ├── cases/        Problem-solution pairs (immutable)
    ├── patterns/     Reusable workflows (mergeable)
    └── ...
```

### Layered Harness

Three layers aligned with Claude Code's scoping:

| Layer | Scope | Contents |
|-------|-------|----------|
| **Identity** | `~/.claude/CLAUDE.md` | Who the agent is, who the user is, trust boundaries |
| **Methodology** | `~/.claude/methodology.md` | Session lifecycle, memory protocol, decision trails |
| **Project** | `{project}/CLAUDE.md` | Project-specific principles + `.claude/memory/` |

### Memory System

**Progressive loading:** L0 = index (always), L1 = first 25 lines (when relevant), L2 = full file (when needed).

| Type | Location | Mutability | Purpose |
|------|----------|------------|---------|
| event | `events/` | Immutable | Decisions, milestones |
| case | `cases/` | Immutable | Problem → solution pairs |
| pattern | `patterns/` | Mergeable | Reusable workflows |
| toolbox | `toolbox/` | Updatable | Cross-project tools |
| project | `project_*.md` | Updatable | Project state |
| reference | `reference_*.md` | Updatable | External pointers |

### Memory Ownership

Memory belongs to the **project**, not to pilot:

- Each project stores memory in `.claude/memory/` within its own git repo
- `install-project.sh` creates symlinks so Claude Code finds it at `~/.claude/projects/{hash}/memory/`
- Use `--home` flag to designate one project's memory as global (used when Claude runs from `~/`)
- Different machines have different path hashes — the install script handles this automatically

## Getting Started

```bash
# 1. Clone pilot
git clone https://github.com/YOUR_USER/pilot.git

# 2. Install methodology globally (one-time per machine)
./install-global.sh              # auto-detects machine name
./install-global.sh my-macbook   # or specify explicitly

# 3. Install project harness (per-project)
./install-project.sh /path/to/project
./install-project.sh /path/to/project --hooks=lint,gate

# 4. Designate one project as global memory carrier
./install-project.sh /path/to/dotfiles --home
```

### Multi-machine Setup

```bash
# On machine A (macOS):
./install-global.sh macbook
./install-project.sh /Users/me/code/dotfiles --home
./install-project.sh /Users/me/code/myapp

# On machine B (Linux server):
./install-global.sh dev-server
./install-project.sh /home/me/dotfiles --home
./install-project.sh /home/me/myapp

# On machine C (Windows WSL):
./install-global.sh windows-pc
./install-project.sh /home/me/dotfiles --home
```

Memory syncs across machines via `git push/pull` in each project repo. The install scripts create local symlinks — run them once per machine.

### Customization

1. Edit `global/CLAUDE.md` — fill in the `{{PLACEHOLDERS}}` in the PROFILE section
2. Edit `global/methodology.md` — adjust session lifecycle and memory rules
3. Add commands to `global/commands/` — any `.md` file becomes a `/slash-command`

## Slash Commands

| Command | Purpose |
|---------|---------|
| `/wrap` | Session closure: extract memories, audit decisions, generate summary |
| `/newclaw` | Launch a new Claude Code instance in a screen session |

## Lineage

Draws from:
- **ADR** (Architecture Decision Records) → `events/`
- **C4 Model** → L0/L1/L2 progressive detail
- **Evolutionary Architecture** → progressive maturity
