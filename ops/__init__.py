"""Infrastructure operations — thin Python modules called by bin/ CLI tools.

Architecture:
  - Each module handles one domain (status, ssh, backup, reconcile, dns, etc.)
  - No external dependencies beyond stdlib + PyYAML
  - CLI tools in bin/ are bash wrappers that call these modules
  - All state comes from infra/*.yaml (declarative, version-controlled)

Modules:
  status.py    — Unified infrastructure status (servers, secrets, git, services)
  ssh.py       — SSH operations + batch execution (ThreadPoolExecutor)
  backup.py    — Cloud backup engine (reads desired-state.yaml)
  reconcile.py — Desired vs actual state diff (emit safe/confirm/manual actions)
  dns.py       — DNS record management
"""

import os
import yaml

DOTFILES_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load_yaml(name: str) -> dict:
    """Load a YAML file from infra/ directory."""
    path = os.path.join(DOTFILES_DIR, "infra", f"{name}.yaml")
    with open(path) as f:
        return yaml.safe_load(f) or {}
