# Built-hull sinking and salvage test

`python3 -B -m unittest discover -s tests/hull_depth -v` runs the
offline source contracts. It does not execute DreamDaemon or open a socket.

## Compile evidence only

Use the pinned compiler from `tools/byond/version.json`. The prepare script
uses the existing minimal-world projection technique: omit compiled maps,
disable normal world/global startup, and add a synthetic fixture. The full
game save, load, geometry and repair procs are otherwise unchanged by default.

    python3 tests/hull_depth/compile_roundtrip.py --compiler /path/to/pinned/DreamMaker --output /new/evidence/compiler

This writes the compile log, binaries, hashes and fixture provenance; it does
not run the game. Do not claim save/reload behavior from this step alone.
`--probe pressure` selects the separately audited pressure fixture at compile
time; the round-trip runner does not accept pressure receipts.

## Explicitly approved, confined native run

Use a disposable Linux x86-64 runner with unprivileged user/network/PID
namespaces, a C compiler, GNU binutils, an i386 sysroot/QEMU and the pinned
BYOND installation. Maintainer authorization is required for DreamDaemon.
The native runner requires `--run-native`, refuses an existing evidence path,
and is not automatically invoked by CI. Never substitute the generic
`tests/ecology_spawning/run_linux.py` for this specific fixture.

    python3 -B tests/hull_depth/run_roundtrip_offline.py --run-native \
      --compiled /new/evidence/compiler --output /new/evidence/runtime \
      --qemu /path/to/qemu-i386 --loader /path/to/ld-linux.so.2 \
      --daemon /path/to/pinned/byond/bin/DreamDaemon --library-path /path/to/i386-linux-gnu

It launches the payload in CGI mode (no initial listener) with a fresh home,
an allowlisted environment, and only the tracked public character-name tables
from repository configuration. Before
every daemon exec, a fresh private network/PID namespace and a host seccomp
filter must pass: no routable interface, no listeners or inherited non-stdio
FDs, and IPv4, IPv6 and Unix socket creation denied in both the verifier and a
fresh child exec. A separate inert i386 syscall negative control proves that
the chosen QEMU driver also receives the denial before the first game start.
The filter is already applied when QEMU starts; the DM `OpenPort` and hub
settings are defense in depth, not the startup guarantee. A failed check
refuses to start. This is an authorized test for the audited repository
fixture, not a sandbox intended to run arbitrary DMBs.

CGI exits at the first production tick yield rather than keeping a world
scheduler alive. The default projection can therefore observe synchronous
ship behavior, but may end at the first save pause without a completion receipt.
Pass `--physical-only` to the native runner to exercise the same real descent,
breach, repair and refloat code without saving or reloading. This mode checks
whether the same crew, hull, hold and cargo make it back to the surface; it
does not establish persistence.

The writer builds and sinks a small commissioned ship with main/upper crew
and nested hold cargo. It checks that an obstruction leaves every deck in
place and that descent preserves the ship and its deck relationships. It
uses the normal game ticker to write a save. Only that synthetic generation
is copied into the reader's fresh directory and process. The reader verifies
identity, footprint, depth, water and cargo/crew persistence, then opens a
breach, shows the breach prevents refloat, patches and refloats the same hull,
and writes another generation. No graphical or live server evidence is
implied. Keep both process logs and the guard proof with any reported result.
