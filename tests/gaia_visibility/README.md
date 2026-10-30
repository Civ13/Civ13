# Candidate-specific Gaia visibility packet - preparation only

This new packet retains the full production source/art dependencies at an exact
immutable commit. It does **not** reuse or upgrade the historical 21x21 root-tree
fixture results. Preparation does not compile, launch DreamDaemon, open sockets,
connect clients, access a desktop or grant privileges. It has no runner option.

## Prepare and verify provenance

First commit these preparation files along with the candidate. Use that full
40-character lowercase commit SHA, never HEAD, a branch, abbreviated SHA or a
working-tree snapshot:

```sh
python3 -B tests/gaia_visibility/prepare.py --head <full-candidate-sha> --output <new-isolated-directory>
python3 -B -m unittest discover -s tests/gaia_visibility -p 'test_*.py' -v
```

The tool refuses an existing destination, noncommit refs, a staging script that
differs from the candidate, archive links/special files, missing map boundaries
and drifting negative-control anchors. It reads tracked bytes through Git archive;
dirty/untracked files are not inputs. The archive is spooled to a temporary disk
file; assets are copied and hashed in 1 MiB chunks rather than loading the full
asset tree into RAM. Only the DME and explicit source mutations are buffered. The manifest records every original and
prepared SHA256, selected commit, toolchain, controls, dimensions and evidence
status. `gaia_visibility.dme` keeps production includes, replaces only the selected
map block and appends the committed diagnostic fixture. The original DME is also
preserved unchanged. Review the generated diff and hashes before compilation.

`scene.dmm` is 48x48x2 with 12 roots per level (ordinary, pine, snow pine, jungle
and palm), grass/snow, grass/rock clutter, a door in a wall line and a roof zone.
Initial inspection positions are around (24,24,1), (24,24,2), door (33,24,z) and
roof (38,24,z). These are prepared coordinates, not proof that map startup works.
The ordinary map types and constructors are dependencies; metadata worker startup
is explicitly suppressed by staged guards.

## Readiness boundary

**Do not launch this packet yet.** `isolation.py` now stages exact entry guards
before the early global initializer, normal world startup, configuration loader,
map metadata worker scheduling, client/admin/webhook admission and preference
saving. `bootstrap.dm` replaces those paths with an in-memory configuration and
only lighting/visibility processing. Prepared macros route native extension calls
and shell calls to counting no-ops; world Export/Import/Topic/Reboot/settings are
blocked. No OS security settings are changed. These are source adapters, not an
established confinement result; compilation and native bootstrap remain unverified.

Preparation creates `owned-runtime/{config,data,map_saves,SQL,logs}` as **empty**
directories, separate from the archived source/configuration. A future admitted
launcher must use that fresh runtime cwd and copy only reviewed compiled resources,
never production configuration, credentials or saves. No launch is provided here.
The external runtime owner must verify OS egress containment, loopback binding,
unique listener ownership, no inherited privileged credentials, a process-tree
watchdog and cleanup. BYOND can bind its initial listener before DM global startup;
the early `OpenPort("none")` is not a substitute for that external admission.

Default bootstrap is closed and terminates without explicit `fixture_admit`,
three unique `fixture_clients` ckeys and a high `fixture_port`. These parameters
are **not approval** and must not be supplied until separately admitted. Once
admitted, only loopback clients on that allowlist are accepted, at most three at
once, with in-memory preferences and no administrative grants. The packet has a
ten-minute post-initialization ceiling and closes the listener/retires owned
presentation before shutdown. An external watchdog remains necessary for startup
failures or hangs. No credentials, account creation or automatic sign-in is added.

The minimal bootstrap intentionally does not prove production scheduler/startup,
normal client-admission integrations, authentication, full-game ecology or save/load.
Those cases remain separate production-path acceptance, not results to attribute
to this packet. A save/load case must use a separately reviewed temporary-save
adapter; it is not enabled here. Source-controlled fixture compile CI may compile
`gaia_visibility.dme`, but must never launch DreamDaemon.

## Real-client acceptance protocol (not automated assertions)

Admit **three actual connected clients** after runtime admission. Use production
human bodies and HUD/login beneath the fixture client-admission adapter; do not stub
clients or call a fake presenter. `gaia_visibility_fixture_report()` returns
preconditions, mask counts and fallback diagnostics, but no PASS. It omits account
identifiers and explicitly reports pixel/input/performance as not measured.
`gaia_visibility_fixture_root_report(tree, viewer)` captures current root RGB and
visual/hover/examine decisions; these are state diagnostics, not screenshots or
actual mouse evidence. Record exact candidate/build/client versions with receipts.

| Case | Required observation and retained evidence |
| --- | --- |
| Three clients / two z | All three have independently owned contexts. Put two on z1 and one on z2; change views and walk. Retain client count, coordinates, root/mask counts, per-client screenshots and video. |
| >8 roots / families | At the central grove inspect at least nine visible roots and ordinary/pine/snow/palm/jungle appearances. Check reported admission/fallback rather than count alone. |
| Door / movement | Walk near a closed door, open/close it through normal interaction and move across tile edges. Hidden geometry/canopies must not leak; visible roots must return without flicker. Record timing video and actual hover/examine clicks. |
| Root RGB | Under reviewed lighting controls, test dark ground beside a lit root and differently colored roots; whole canopy uses the committed root RGB, with tint/alpha/offset once. Retain root diagnostics plus unscaled screenshots. Pending lighting must not become white. |
| Shadows / weather | Capture ordinary shadows and rain/weather both before and after compositor activation. Grouped shadow and weather order must be checked from pixels, not configuration flags. |
| Roof / foreground fallback | Move into roof/foreground conflict and out again. Record `fallback_reason`, count, owned screens/images and restored plane targets. Ordinary ordering remains intact and compositor can reacquire afterward. |
| HUD / input | Exercise inventory and actual mouse hover/examine on visible/hidden roots and walls. Check native interaction target identity. Diagnostics alone do not prove mouse dispatch. |
| Lifecycle | Disconnect/reconnect one client; transfer/respawn body; rebuild HUD using normal paths. Other clients remain unaffected. Check old images/screens/leases and new owners. |
| Mutation | Delete/create a fixture tree, change its seasonal appearance, and mutate an opaque door. Check restoration and bounded cached images without stale canopy. |
| Opt-out | `C.set_geometric_los(FALSE)` through an authorized fixture operator path releases both presenters/leases. Reenable and verify fresh ownership. Remove a conflicting foreground image and verify fallback exits. |
| Save/load | In a separate admitted fixture cycle save and restore temporary scene state. Reconnect three clients, compare durable positions/world objects, verify fresh contexts/leases after light settlement, and retain runtime logs. |
| Cost | In the same grove and a separately reviewed denser local scene record refresh time, server tick usage, icon allocation/cache churn, network updates and movement responsiveness. No synthetic callback timing alone proves production performance. |

Keep each case's expected result, actual observation and evidence paths separate.
A missing client, missing screenshot, untested lifecycle step or skipped run is
incomplete evidence, never a successful result. No automation here creates these
observations or restarts the live server.

## Prepared causal controls

Each control is a separate packet from the **same head**, with the exact mutation
recorded by original/prepared hashes. Never deploy control packets. Admission and
cleanup rules remain identical to the candidate.

- `--control native-los`: disables geometric LOS and root-tree feature macros in
  the generated DME. Compare the same edge/door/root scene to native behavior;
  the expected visible difference must be documented before running.
- `--control white-root`: forces root RGB to white. The colored/dark-root pixel
  oracle must reject it. Merely detecting the source mutation is not rejection.
- `--control double-offset`: reapplies the tree's pixel_x on its attached image.
  The measured canopy-position oracle must reject the offset duplication.

Controls target distinct observed symptoms. If a control fails at compilation or
startup instead of its intended visual assertion, preserve it as that failure,
not as successful causal discrimination. No pixel oracle or rejection is claimed
until actual client evidence exists.
