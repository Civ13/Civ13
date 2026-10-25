"""Retired legacy provisioner. This entrypoint must have no setup side effects."""
import sys


def main():
    sys.stderr.write("""The legacy Civ13 INSTALL/INSTALL.py provisioner is retired; no changes were made.
It does not install the BYOND version pinned in tools/byond/version.json.
Use the reviewed local setup/build/start instructions in docs/local-wsl.md:
- Windows/WSL: the local-wsl.ps1 Prepare, Build and Start flow.
- Debian-compatible Linux: the direct Linux commands in that document.
These create separate local test runtimes, not a production-server migration.
Legacy scripts/launch.py and scripts/updateserver.py are NOT upgraded.
Do not use them to migrate an existing server; retain saves and coordinate its stop.
""")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
