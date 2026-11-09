# Agent observation visibility regression

Offline CI runs `python3 tests/agent_control/test_visibility.py`. These are
source contracts, projector checks, and tests of the real Python `SensesClient`
cache. They do not claim to execute BYOND's line-of-sight engine.

Prepare a native fixture, without starting any server:

```sh
python3 tests/agent_control/visibility/prepare.py --output /fresh/visibility-fixture
```

Compile on the pinned BYOND toolchain (still no daemon):

```sh
python3 tests/agent_control/visibility/prepare.py --output /fresh/visibility-compile --compile --byond-bin /path/to/byond/bin
```

Use a fresh output directory; an existing directory is never overwritten. Inputs,
SHA-256 provenance, compiler identity and compiler output are retained there.
Windows uses `dm.exe`; Linux uses `DreamMaker` and the shared installed-member
identity verifier. The shared compiler validator requires the current exact pin
and zero errors/warnings. Compilation does not establish runtime success.

The complete current `act_character_observe` proc is extracted unchanged from
`agent_characters.dm`. `adapters.dm` supplies only the minimal type schema and
inert unrelated helpers for self state, authentication, auditing, wound/vehicle
information, verbs and queues. Native `view()`, opacity, location, range,
`invisibility`/`see_invisible`, row generation and change-list bookkeeping are
not replaced. Constants for death and indoor area state are source-extracted.
No Git history, production DME, maps, startup, saved state or credentials enter
the fixture. It tests synthetic human mobs as player bodies, not real clients.

The native assertions cover visible players/objects, the see-invisible equality
boundary, higher invisibility, an opaque wall, range, another z-level, container
contents, self and nameless exclusion. Each visibility-loss cause checks a
matching revision's removed refs, cleared signatures, a second hidden poll,
a stale full baseline, and visible-again rows. This is nearby observation
coverage, not graphical rendering, action authorization, or full-game behavior.

Native execution is a separate opt-in operation requiring maintainer approval:

```sh
python3 tests/agent_control/visibility/run.py --run-native --output /fresh/visibility-native --byond-bin /path/to/byond/bin
```

The separate launcher recompiles the prepared inputs. On Windows it reuses the
current-pin `human_subtile` facade and `native_fixture` supervisor unchanged:
exact executable allowlist, hidden suspended launch, one-process Job, memory/
time limits, socket sampling and retained owned-process cleanup. Linux reuses
the repository's bounded subprocess and pinned-toolchain helpers; that path
does not claim Windows-equivalent OS socket isolation. The `--run-native` flag
is an explicit opt-in, not a substitute for authorization.

The fixture closes its port, refuses reopening, rejects clients and outbound
Export, and terminates explicitly. Do not infer socket isolation from `-close`
or the in-world port assertions. A Windows startup login connection is still
rejected by the existing zero-socket policy, even if gameplay assertions finish.
The launcher preserves that rejection and never retries with weaker controls.

Native acceptance requires matching source hash and engine version/build,
clean compiler and runtime logs, accepted containment where supported, zero
failures and all 185 expected assertion labels present and passing. A complete
assertion receipt alone cannot override a failed supervisor. Failed logs and
cleanup receipts stay in the output directory. Compile-only preparation leaves
runtime unverified. CI registration belongs in the existing `agent_control`
offline suite; do not silently add native job admission.
