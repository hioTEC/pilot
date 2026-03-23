"""Reconciliation engine — compare desired vs actual infrastructure state.

Called by `dot check`. Reads desired-state.yaml and probes actual state,
then emits actions classified by safety level:

  - safe:    Auto-fixable, no confirmation needed
  - confirm: Needs user approval before applying
  - manual:  Report only, human must act

Customize probes and actions for your infrastructure.
"""

from ops import load_yaml


def print_actions():
    """Compare desired vs actual state and print recommended actions."""
    desired = load_yaml("desired-state")

    if not desired:
        print("No desired state defined. Edit infra/desired-state.yaml to get started.")
        return

    print("=== Reconciliation ===")
    print("  (customize ops/reconcile.py for your infrastructure)")
