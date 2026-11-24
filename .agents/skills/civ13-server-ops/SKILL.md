---
name: civ13-server-ops
description: Rules for Civ13 server, bot, launcher and deployment work - authorization, the read-only preflight, starting and stopping through the launcher, and keeping the launcher in step with server-management features. Use before any live-server action, deployment, restart, or launcher change.
---

# Server operations and the launcher

## Authorization

- Source PR work grants no merge, deployment, restart, save/import, feature
  activation, credential or security-setting authority. Each live action needs
  the user's own go-ahead for that action and target; keep action-time
  confirmations and runtime guards.
- Live actions that cannot be undone (production changes, bulk deletes,
  messages outside the project) wait for the user even after a source PR merges.
- Keep server credentials, private configuration, hostnames, raw process
  arguments and save metadata out of the repository, PRs and public text.

## Before server work

Run the [read-only server preflight](../../../docs/agent-guides/operations-integrations/README.md#read-only-server-preflight)
and keep its record private. It performs no pull, build, launch, restart,
save/import or cleanup.

## Starting and stopping

- Servers and bots the launcher manages start, stop, update and restart only
  through the launcher, never ad-hoc scripts or killed processes.
- One busy region never blocks work on the others.
- DreamDaemon always runs `-trusted`, never `-safe`.

## Keeping the launcher current

The standalone launcher (`tools/opendream-client/`) must support every new
server-management feature. When a PR adds or changes one, update the launcher
in the same or a follow-up PR, bump its version in both
`tools/opendream-client/native/version.json` and `native/Civ13.Launcher.csproj`,
and give the maintainer numbered release steps; the maintainer publishes
releases. Launcher internals: [Launcher guide](../../../docs/agent-guides/launcher/README.md).

Deployment, agent control, MCP and bots:
[Operations and integrations guide](../../../docs/agent-guides/operations-integrations/README.md).
