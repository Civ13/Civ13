# Trench world-save regression

Run with the pinned BYOND 516.1681 compiler/runtime and a verified Python interpreter:

```
<python> tests/trench_save/run.py --byond-bin <BYOND-bin>
<python> tests/trench_save/run.py --byond-bin <BYOND-bin> --negative-control filling
<python> tests/trench_save/run.py --byond-bin <BYOND-bin> --negative-control digging
```

The runner compiles the production game types, turf constructors, flooring icon
builder and persistence code. Normal startup and global-controller initialization
are disabled in generated temporary sources. No production config, saves or SQL
are used; optional outbound hooks and remote Topic operations are disabled.
Disk saves, compiler/runtime logs, metadata and the tested checkout patch are
retained in the printed temporary directory. Unique generated checkout files are
removed on success, error and timeout. Compiler/runtime subprocesses are bounded.

A synthetic 12x8x2 world exercises Save_World, preflight, ClearMap and Load_World.
It deliberately replaces trench turfs and resets construction progress before
import. Assertions cover connected dry trench bends, fresh/salty channels, a
second-level boundary trench, reconstructed flooring/plane/edge overlays, bridge
contents, a crate with nested knife, map identity, dirt/sand partial digging and
trench fill progress. Production check_filling must complete after the next dirt
deposit. Depth is defined by the trench type/flooring/plane; there is no separate
mutable depth field. previous_turf is unused by current filling behavior and is
not added to persistence. Runtime cooldowns and registries remain excluded.

Each negative control changes only the relevant allowlist in a generated copy
and requires its specific assertion to fail. Baseline master e1447594b restored
types, layout and contents but reset all three progress values from 1 to 0.
The test checks appearance metadata using actual game icons; it does not prove a
rendered client view, player shovel interaction, movement or production saves.
No graphics change. CI's existing game build applies; this probe is currently a
local regression unless admitted by its explicit workflow guard.

## Explicit current-target profile

Existing invocations above retain the strict **516.1681** expectation. A different
compiler still fails them. The irrigation CI slice explicitly adds
`--expected-byond-version 516.1688` for the normal fixture and both existing
filling/digging controls. This is a new selected-target receipt, not a relabeling
of historical 1681 evidence or broad engine/save compatibility acceptance.

`--compile-only` compiles this actual prepared fixture, copies its compile
evidence, and returns before any daemon or config/name copying. Metadata records
the expected and observed compiler, compile-only request and runtime boundary.
Compiler/runtime deadlines remain 120/60 seconds, startup isolation and old
controls are unchanged, and temporary generated checkout files still retire in
`finally`. The outer hosted step has a ten-minute limit and retains only its
synthetic metadata/logs/results, not binaries or savefiles.
