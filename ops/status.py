"""Unified infrastructure status.

Called by `dot status`. Aggregates:
  - Server connectivity + expiry warnings
  - Service health checks
  - Domain DNS status
  - Fleet status (e.g. sing-box nodes)

Customize for your infrastructure.
"""

from ops import load_yaml


def print_status():
    """Print unified infrastructure status."""
    machines = load_yaml("machines")
    services = load_yaml("services")

    print("=== Servers ===")
    for server in machines.get("servers", []):
        name = server["name"]
        role = server.get("role", "")
        expires = server.get("expires", "")
        print(f"  {name:20s} {role:20s} expires: {expires}")

    print("")
    print("=== Services ===")
    for svc in services.get("services", []):
        name = svc["name"]
        machine = svc.get("machine", "")
        port = svc.get("port", "")
        print(f"  {name:20s} {machine}:{port}")
