# Civ13 - Claude Code entry point

Claude Code reads this file, not AGENTS.md, so it imports the always-on rules.
Keep always-on rules in AGENTS.md and step-by-step procedures in skills; keep
this file short.

@AGENTS.md

Repository skills live in `.agents/skills/<name>/SKILL.md`. Each matching
`.claude/skills/<name>/SKILL.md` is a pointer so Claude Code can discover it;
edit the `.agents` copy. A new skill needs both files.
Cloud sessions install the pinned compiler with `bash scripts/cloud_byond_setup.sh`.
