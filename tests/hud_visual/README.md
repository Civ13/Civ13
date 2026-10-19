# Isolated native HUD investigation

This opt-in probe targets reviewed master source `75890d883190355e430f9958fd102864ee88429a`.
It uses real human constructors/organs, `create_HUDtech`, native damage-overlay
objects/appearances and the production human HUD processing loop. Three uniquely
tagged health-entry exceptions compare unchanged ordering with a test-only reordered
subtype. No production recovery command or behavior is changed.

The separate test-only visual candidate removes/adds only the known blindness
underlay. It never invokes health, Life, disability processing or character reset.
The before/after oracle includes a nonzero `damageoverlaytemp` sentinel, unrelated
underlay, shared blindness image, organs, inventory, sleep and identity state.
Medical/sleep, pre-Life blindness, unknown completion, registration, location and
ownership controls retain blindness or refuse. Its fixture-supplied completion
capability is not a deployable classifier. No registration repair is implemented.

`run.py --prepare --out <fresh-absolute-directory>` freezes the packet without
compiling or launching a daemon. Preparation requires a clean committed fixture.
Native execution requires independent acceptance of that exact packet plus a
parent-issued JSON grant naming `packet_sha256`, `head`, `exclusive_blackout_only`,
`start_utc` and `end_utc`. The runner burns `USED` before any native launch. A new
reviewed packet and grant are required after any correction; never edit a used one.

Bounds: one compiler then one daemon, shared 120 seconds including 10 seconds for
cleanup; compiler 75 wall/30 CPU seconds and 1024 MiB private memory, daemon 30
wall/10 CPU seconds and 512 MiB, watcher 128 MiB. The retained-handle Windows Job
adapter prohibits child creation and uses suspended assignment, hard memory caps
and kill-on-close. No host free-memory admission or CIM query is used. The adapter
was copied from the separately reviewed HTTP admission guard; imports, host-memory
sampling and explicit hidden-window flags are the only adaptations.

The daemon argv fixes initial binding to `127.0.0.1:59474`; the fixture closes its
port at entry. Owned socket observations reject other listeners and listeners
after entry. This does not prove the process never bound. Job objects and trusted
mode do not sandbox engine-originated outbound traffic. No external service is
required; unexpected service dependence or engine diagnostics invalidate evidence.

Normal startup and map inclusion are disabled in generated copies, with isolated
public name files and a minimal configuration. Generated sources, partial build
outputs, stdout/stderr/runtime logs, per-assertion records, timing/resource/socket
samples and terminal owned-process cleanup receipts are retained. No live server
configuration, saves, credentials, player connection or network settings are used.

Headless appearance assertions cannot establish connected-client rendering,
reconnection, original incident causality, winter lighting or production recovery.
The CI job runs `ci.py` with pinned BYOND 516.1681 when this new suite is selected,
or when extensive regressions are explicitly requested. It compiles and executes
the actual probe with temporary config/storage, retained evidence and bounded
subprocess timeouts. This Linux CI path is separate from the Windows exact-packet
grant runner above; it does not claim Windows Job resource containment.

`python3 tests/hud_visual/ci.py --prepare-only --output <fresh-directory>` checks
source pins and prepares inputs without native tools. Native execution requires
`--byond-bin <516.1681-bin>`. CI preserves logs and per-assertion records.
The native fixture now also asserts its unrelated-appearance snapshot is nonempty,
so a typed-loop regression cannot silently weaken the preservation oracle.
