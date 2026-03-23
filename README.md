# Pilot

Dotfiles framework for multi-machine development with Claude Code agent integration.

## What This Is

A complete infrastructure-as-code setup that manages:

- **Agent configuration** — Claude Code identity, methodology, memory, hooks, slash commands
- **CLI tools** — `dot` (infra meta-command), `claw` (workspace agent launcher), `secrets` (age encryption)
- **Infrastructure state** — declarative YAML for machines, repos, domains, services
- **Operations** — Python modules for status, SSH batch ops, backup, reconciliation
- **Cross-machine sync** — git-based config propagation via symlinks

## Architecture

```
pilot/
├── .claude/                    # Claude Code configuration
│   ├── CLAUDE.md               # Agent identity + trust boundaries
│   ├── methodology.md          # Session lifecycle + tracks + memory protocol
│   ├── tools.md                # Tool registry (gstack, models, plugins)
│   ├── settings.json           # Permissions, hooks, plugins
│   ├── commands/               # Slash commands (/wrap, /try, /drop, /delete)
│   └── hooks/                  # Session hooks (bootstrap.sh)
│
├── bin/                        # CLI tools (added to $PATH)
│   ├── dot                     # Infrastructure meta-command
│   ├── claw                    # Workspace agent launcher
│   ├── secrets                 # age-encrypted secrets management
│   └── ssh-gen-config          # Generate SSH config from machines.yaml
│
├── infra/                      # Infrastructure state (YAML)
│   ├── machines.yaml           # Server + dev machine registry
│   ├── repos.yaml              # Workspace repos + trust levels
│   ├── domains.yaml            # Domain DNS configuration
│   ├── services.yaml           # Running services per machine
│   └── desired-state.yaml      # Desired state for reconciliation
│
├── identity/                   # User identity
│   ├── profile.yaml            # Name, email, timezone, git config
│   └── aliases.sh              # Shell functions (model wrappers, etc.)
│
├── ops/                        # Infrastructure operations (Python)
│   ├── __init__.py             # YAML loaders
│   ├── status.py               # Unified status display
│   └── reconcile.py            # Desired vs actual state diff
│
├── plans/                      # Implementation plans (per track)
├── setup.sh                    # Bootstrap script (one command per machine)
└── .gitignore
```

## Quick Start

```bash
# Clone
git clone https://github.com/your-org/pilot.git ~/.dotfiles

# Customize
# 1. Edit identity/profile.yaml with your info
# 2. Edit .claude/CLAUDE.md PROFILE section
# 3. Add your machines to infra/machines.yaml
# 4. Add your repos to infra/repos.yaml

# Bootstrap
~/.dotfiles/setup.sh

# Source shell config
source ~/.bashrc  # or ~/.zshrc
```

## CLI Tools

### `dot` — Infrastructure meta-command

```bash
dot status    # Full infrastructure status
dot sync      # git pull + decrypt secrets + regen SSH config
dot push      # Commit local changes + push
dot pull      # Pull + re-run setup.sh
dot backup    # Run cloud backup
dot check     # Reconcile desired vs actual state
```

### `claw` — Workspace agent launcher

```bash
claw myproject    # Open claude session in repo (trust level from repos.yaml)
claw home         # Open claude -dsp in ~ (infra focus)
claw serve name   # Start remote-control pm2 server
claw status       # All repos: branch, dirty state, last commit
claw setup        # Clone missing repos + bootstrap
claw sync         # Reconcile repos.yaml with GitHub
```

### `secrets` — Age-encrypted secrets

```bash
secrets show              # Decrypt + print
secrets edit              # Edit + re-encrypt
secrets env [DIR]         # Decrypt .env + extract keys
secrets push HOST         # SCP encrypted bundle to remote
secrets setup-remote HOST # Full remote bootstrap
```

## Key Design Decisions

- **Declarative YAML** over imperative scripts — machines.yaml, repos.yaml as source of truth
- **Age encryption** for secrets at rest — no plaintext credentials in git
- **Symlink everything** from dotfiles repo — changes propagate via git push/pull
- **Agent autonomy** with trust levels — repos.yaml defines per-repo trust for Claude Code
- **Quality gates via gstack** — /review and /qa skills, not custom scripts
- **Memory as living docs** — small set, update over create, delete when stale
- **Decision trail in code** — rationale belongs next to the code it describes, not in separate files

## Methodology

The agent follows a structured workflow:

```
ideate → plan → implement → review → ship → qa → ops → done
```

Parallel work tracked as **tracks** with stage gates. Memory protocol keeps cross-session context minimal and fresh. See `.claude/methodology.md` for details.

## Dependencies

**Required:** git, python3, python3-yaml, age
**Optional:** Tailscale, pm2, gh (GitHub CLI)
