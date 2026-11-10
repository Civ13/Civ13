# Television native regression

Offline source contracts: `python tests/television/test_contract.py`.

Compile only (never launches DreamDaemon):
`python tests/television/run.py --byond-bin <pinned-bin> --compile-only`.

With explicit maintainer authorization only:
`python tests/television/run.py --byond-bin <pinned-bin> --trusted`.
The runner checks the canonical BYOND pin, suppresses normal world/global startup,
removes maps, uses unique temporary storage, closes and refuses listening ports,
and preserves logs and results in ignored `.ci/television/` evidence directories.
It never changes production saves or map activation.

The headless fixture exercises production power, physical camera pairing,
receiver view ownership, camera/desk/receiver movement, helmet battery/range,
TV live/course/node teaching, saved camera settings and transient session fields,
and world save/reload. Only actor online/physiology and authoritative broadcast
clocks are adapted. Native `reset_view` is invoked but has no client in this
fixture: rendered camera views and connected-client interruption are unverified.
Compile-only success does not establish any native assertions passed.

CI registers only the offline contract suite. Native execution is opt-in and is
not implied by a green aggregate or by adding this directory.
