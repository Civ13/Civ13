---
name: civ13-global-init-limit
description: Keep Civ13 inside BYOND's size cap on the world's global initialiser proc. Use when adding a global or static variable or table, or when a build or probe fails with "Procedure is too large".
---

# Global initialiser size limit

Every initialised global and static variable shares one engine-generated
proc, and BYOND caps its size. When it overflows the compiler reports
"Procedure is too large" at an unrelated line (often only in probe builds,
which add their own globals).

## Rules

- Never write a large eagerly initialised global such as
  `var/global/list/x = list(...)`.
- Build a big table in a proc: `var/global/list/x = x_table()` with
  `/proc/x_table()` returning the `list(...)`. Examples:
  `code/modules/diet/diet.dm`, `code/modules/admin/admin_verbs.dm`.
- Or initialise lazily at first use with `LAZYINITLIST(x)` (`code/_macros.dm`)
  or a getter proc.
- Remove globals nothing reads.
- Tables pinned by source tests or line-indexed by `UI/crafting-atlas.json`
  stay where they are unless you update the pin or regenerate the atlas.

## Check

`python3 scripts/agent_preflight.py compile` (also run by `all` when a
compiler is installed) compiles `civ13.dme` with 1,000 extra initialised
entries (`HEADROOM_ENTRIES`), so a branch that leaves less than that spare
fails preflight before it breaks every probe build in CI.
