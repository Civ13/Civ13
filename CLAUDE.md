# Civ13 - Claude Code entry point

Claude Code reads this file, not AGENTS.md, so it imports the shared guides.
Keep project rules in AGENTS.md and CODEX.md; keep this file short.

@AGENTS.md
@CODEX.md

Repository skills live in `.agents/skills/` (shared with Codex). The matching
`.claude/skills/` entries are pointers so Claude Code can discover them.
Before pushing any source or config change, follow the `civ13-pr-preflight`
skill: cloud sessions can install the pinned compiler with
`bash scripts/cloud_byond_setup.sh`.

Use CODEX.md's ownership and handoff rules for blocked work and CI monitoring.
Before authorized server work, use the read-only preflight in
[Operations and integrations](docs/agent-guides/operations-integrations/README.md#read-only-server-preflight).
These instructions preserve existing action-time confirmation and security rules.
