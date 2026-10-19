# Native sub-tile feasibility packet

Prepared against Civ13 `cc03b199128f8afed58713912c551ad7556e6bc4`.
This is an original, opt-in experiment under the repository's AGPL-3.0
license. `civ13.dme`, production movement, CI, launchers and gameplay defaults
are unchanged. Only `prototype.dme` defines `SUBTILE_FEASIBILITY`.

Status: source and offline oracle only. No compiler or DreamDaemon was run
during preparation. Engine behavior below is an assertion to measure on pinned
BYOND **516.1681**, not an observed result. No connected-client acceptance.

## Source/library audit

The prior RuCiv13 comparison used fork
`afb145be65c2f7a5ba2d466f6c278bb8e9f8b62e` and Civ13's baseline above.
RuCiv13's movement machine still supplies adjacent tile destinations. Its
vision-cone invalidation and turret-release changes are separate ports; no
authoritative sub-tile engine was found in the compared movement core. Removed
football, drone, submarine and vehicle behavior is not imported here.

The mechanism comes from BYOND's documented native interface, summarized here:

- [Move](https://www.byond.com/docs/ref/#/atom/movable/proc/Move) takes target
  offsets in arguments three and four. A slide can stop short and report a
  pixel count. A true return therefore does not prove arrival.
- [Physical offsets](https://www.byond.com/docs/ref/#/atom/movable/var/step_x)
  and [bounds](https://www.byond.com/docs/ref/#/atom/movable/var/bound_width)
  define collision geometry. Visual `pixel_x/y` and glide do not establish
  physical movement.
- [locs](https://www.byond.com/docs/ref/#/atom/movable/var/locs) enumerates
  covered turfs; one actor can be present in multiple turf contents lists.
- The installed official reference at
  `C:/Program Files (x86)/BYOND/help/ref/info.html` was read directly for Move,
  pixel movement, offsets, bounds, movement mode and file output. Its text is
  not used as proof of the pinned engine's measured behavior.

Bounded public GitHub repository searches for BYOND/pixel movement and
Forum_account did not establish a suitable implementation with explicit
license/provenance. The similarly named
[Humboof/PixelMovement](https://github.com/Humboof/PixelMovement/tree/a0e8d2efef18436618714d9d9c5d3b576f35b627)
advertises RPG Maker MV and MIT licensing in its repository metadata; it is not
this runtime. No third-party library code is copied; no licensing inference
is made about Forum_account's work. Newer pixloc/vector interfaces are not used.

## First proof and material limits

`kernel.dm` owns a dedicated experimental object and performs cardinal requests
of one to four pixels using native `Move`. It keeps the full32x32 collision box,
uses the game's default legacy movement mode, and never assigns physical
`loc/step_x/step_y`. It records raw native return, before/after scalar position,
measured displacement and exact target arrival separately. Neither failed nor
unexpected native return values are clamped or replaced with success.

Requests require canonical offsets, integer cardinal displacement, an existing
same-z destination, and a deadline from the current world time through one
decisecond later. Rejected input consumes no work or movement. Each kernel
admits at most eight native calls per engine tick. Eight ordinary4px requests
cover32px; this arithmetic is not a client speed policy. The kernel is not an
authority boundary for an arbitrary caller that can instantiate more kernels.

The first positive assertion directly reads the actor's native position and
requires four pixels east. The `control=cosmetic` profile applies the same
request only to visual offsets, returns a success value, and must fail exactly
`physical_east_four_pixels`. The control must not be accepted for an unrelated
exception or diagnostic.

The remaining native assertions cover normalization east/west and north/south,
overlapping `locs` and turf contents, actual entry/exit/cross callbacks, fixed
tick work bound, dense turf blocking and reopening, a dense movable with a2px
gap producing an exact partial slide, bump callbacks, reverse escape, rejected
inputs/deadlines/map edge and refusal of an unreviewed smaller footbox.

A fresh disk savefile stores just five position scalars. Restoration validates
them and calls native Move. A distant same-z restore is **placement/jump**, not
swept travel: intermediate walls are not promised to block it. A blocked
destination must leave the actor in place. Malformed offsets and cross-z
restoration are rejected. This is a synthetic offset policy demonstration,
**not Civ13 save/load acceptance** or a change to its codec.

Diagonal speed, continuous per-time speed, smaller collision boxes, terrain
events per distance versus per substep, and multiplayer input cadence remain
material decisions. No diagonal or new client scheduler is implemented.

## Compatibility map before any game integration

| Existing seam at the pinned baseline | Consequence for a later integration |
| --- | --- |
| `code/movementMachine.dm` `do_movement`, client `Move` and `SelfMove` in `code/game/mob/mob_movement.dm` | Inputs pass adjacent turfs and apply whole-step cooldowns. Reusing those cooldowns for4px requests would reduce distance eightfold. Stamina is charged in client movement around lines596-600, so multiplying calls also changes gameplay. |
| `mob_movement.dm:193` movable Move | Diagonals decompose through `step`, which defaults to `step_size`. Its native argument forwarding must be designed explicitly before pixel requests can reach actual actors. |
| `code/game/mob/living/living.dm:502` living Move | Argument three is already a gameplay flag; it cannot become an offset. Pulling, restraint, buckling and drone authority gates must remain intact. |
| `code/_onclick/adjacent.dm:113`, `click.dm:143/248` | Movable adjacency already iterates `locs`; turf checks also use tile distances. Multi-turf presence can alter reach thresholds and duplication. Melee/click geometry needs an explicit policy and production-path tests. |
| `code/game/turfs/turf.dm:59/176`, `code/game/objects/structures/door.dm:116`, `wild.dm:153` | Civ13 layers CanPass and border rules over native callbacks; doors and trees have gameplay exceptions. Minimal dense fixtures do not establish those rules' equivalence. |
| `code/modules/projectiles/projectile.dm:629/665/679` | Projectiles enumerate turf obstacles and invoke CanPass/CanPassOut. A shifted actor's hit geometry needs actual projectile tests, not just a native wall proof. |
| `code/modules/1713/machinery/modular_vehicles/wheels.dm`, multiz movement and structures | Vehicles and seats use their own movement/transform logic. Z transfers are jumps, not planar slides. This packet changes neither system and rejects cross-z scalar restore. |
| `code/game/mob/vision_cone.dm:101`, living Move completion | Vision rebuild uses tile view/range queries and image state. Offset-facing/invalidation must coordinate with the separate cone port, including stationary turns. |
| `code/modules/lighting/lighting_source.dm:132` light check | Source location changes are detected through turf/container location; sub-tile lighting precision is not provided by native actor offsets alone. Roof/occlusion geometry remains unconverted. |
| `code/modules/persistence/functions.dm:19`, `loading.dm:67` | Changed mob vars can include offsets; the loader assigns decoded fields individually while excluding loc/locs. There is no reviewed atomic offset/anchor/overlap reconstruction contract here. Real roundtrip tests must use the actual serializer and item/mob constructors. |

No equivalence is claimed for those production paths. This first experiment
answers whether the native engine provides the required physical primitive.

## Offline checks and reviewed native handoff

Run the pure offline tests from the checkout:

```powershell
py -3 tests/subtile_movement/test_oracle.py
```

They cover4,096 offset/direction combinations and their reversals, malformed
inputs, distance arithmetic, partial-success/cosmetic rejection, receipt profiles
and source isolation. They do not emulate collision or execute DM. The Python
receipt contract checks engine/profile/failure identity; it is not a replacement
for native assertions and strict compiler/runtime diagnostic review.

The root owner separately reviews/adapts the existing contained execution
envelope. No launcher is supplied here. Use a fresh isolated directory for each
profile, pinned516.1681, resource-free DMB only, closed/refused ports, empty hub,
zero visibility and no clients. The fixture rejects clients and Topics and
allows only `OpenPort("none")`. No native run is authorized by these instructions.
The reviewed caller requests an initial loopback bind using `-ip 127.0.0.1`
and port `59474`; world New then closes that port before any assertions. Socket
sampling can witness closure but is not OS network isolation. Root's separate
execution envelope owns containment and any initial-bind exposure controls.

Expected output contract after a future authorized run:

- `port-closed.txt`: exact bytes `closed\n`.
- `result.txt`: positive exact `PASS\n`; cosmetic exact
  `FAIL physical_east_four_pixels\n`.
- `receipt.json`: version/build, port, check count, failed-name list, control,
  caught error string or null, and bounded scalar observations. Positive has
  **42 checks**, no failures, control `none`, null error and eight observations.
  Cosmetic has **3 checks**, one exact named failure and one observation with
  zero native displacement. Raw native slide return remains present in rows.
- `offset-roundtrip.sav`: synthetic scalar file, positive profile only.

Handled assertion failures use caught `EXCEPTION`; any actual compiler warning,
engine runtime, unexpected exception, missing output, wrong profile/failure,
open port or envelope cleanup failure rejects the run independently. Root owns
process containment, deadlines, source hashes, diagnostic collection and later
acceptance. No performance, rendering or real-player smoothness claim follows
from a passing standalone proof.
