# Tree → timber → next craft: source-only scene proposal

**Not a new run.** Current merged source pinned to `9683866a89d2bdc12f8dc7d25444e350583c5483` (master observed 2026-10-25); 13 production source/art/test files independently matched its Git tree. Prior bakery proof stays unchanged.

## Proposed 20-second / 80-frame / 4fps take

| Approximate time | Visible process | Provenance/assertion |
|---|---|---|
| 0–1.5s | Tight outdoor plot, grower, seed packet, water bucket and hatchet; woodworker waits at bottom | Prepared soil and starting supplies explicitly staged; not claimed bought, foraged or crafted |
| 1.5–3s | Seed packet picked up; empty tilled plot becomes an original seedling; hold | Production turf.attackby spends exactly one of two seeds; no spawned seedling |
| 3–4s | First growth service, same seedling appearance | One fixture stage duration reduced60s→1s; normal process_interval pays3 soil/15 water |
| 4–5s | Grower picks up and empties bucket facing seedling; remaining seed/bucket on ground | Real secondary_attack_self→reagents.splash;15 units actually consumed; crop65→80. Water amount is receipt evidence, not readable pixels; no invented pouring animation |
| 5–10s | Distinct original growth sprites3–6, about four captured frames each; seedling becomes full leafy tree | Six real production transitions total, same planted object; no stage assignment or final-tree spawn |
| 10–12s | Mature tree held clearly in frame | Normal summer art, collision and random tree variant; original64² tree art appears approximately128² at native2×zoom |
| 12–16.65s | Grower picks up stock steel hatchet, normal chop animation/action, tree falls to timber | Unshortened46.5-tick do_after; tool wear0.25; seven logs created by production handler |
| 16.65–17.65s | Log stack on ground where tree stood; clear finished-state hold | Same newly created wood stack, not preplaced output |
| 17.65–18.65s | Grower moves logs to foreground, drops them; woodworker picks up same stack and steps toward worktable | Visible ground transfer and movement; inventory equality asserted, not a claim the tiny stack number is readable |
| Remaining frames | Final worker/work-area state | Next process is timber construction/crafting, not demonstrated in this clip |

Native frame timestamps and beat timestamps must align; fail if take is not complete by19.5s. These are nominal source timings, **not measured hosted timings**. No extending work/cadence/artifact budgets if it misses. Full capture acceptance still requires every frame's existing safety/pixel/cadence checks and owned cleanup.

## Tight framing, no postcapture crop

Proposed camera eye(7,7,1), `client.view=3` (7×7 tiles), native MAP `zoom=2`, `zoom-mode=normal`, letterbox=true; MAIN/MAP remain480×480 and statusbar=false. Approximately64px/tile vs32px in bakery. All action remains x5–9/y5–8, mature canopy inside view. No child-window capture, scaling filter or asset repaint.

Primary documentation: https://www.byond.com/docs/ref/skinparams.html, zoom parameter: “2 at double size”. `zoom-mode=normal` preserves pixel appearance at integer zoom. The entire admitted parent window still must pass exact480×480. Native UI/render framing remains to be verified; do not claim this has already improved footage.

## Honest time compression

Natural production growth requires six successful60-second stages: at least six minutes, outside unchanged165s work/20s capture budget. Only the fixture-owned seedling's `growth_time_left` becomes10 ticks before each1s hold; `process_interval(1)` uses actual elapsed game ticks. No rewriting last_growth_tick, stage, icons, tree health or production timing defaults. Its original production growth handler handles admission, seasons, resource payment and mature-tree construction. Deterministic rich soil150 and summer setting are staged; no fertilizer/soil-preparation process is claimed. No general production scheduler is started.

Suggested accompanying caption (not burned in): **“Plant, tend, grow, harvest, pass it on. Genuine Civ13 gameplay rendering with scripted actors and supplied starting materials. Six one-minute growth stages are compressed to one second each for this demonstration; planting, watering, chopping and timber hand-off use the native game handlers.”**

Original art inspection: tree-grow1 and tree-grow2 are pixel-identical, so the first paid growth transition has no visible shape change. Stages3–6 have distinct pixels; visible seedling alpha bounds grow from11×9 to23×22 original pixels (22×18 to46×44 at2×zoom), then the mature tree uses a64×64 canvas. Six paid transitions do not imply six distinct intermediate appearances. `sprite-source-check.json` records hashes/bounds.

At4fps: state changes and holds are visible; smooth gesture fidelity is not. Seed debit, water quantity, soil payment and exact stack amount are machine-verified, not necessarily legible onscreen. If first native review fails to make these stages clearly visible, it is not marketing-ready even if technical checks pass.

## Source proposal and remaining integration gates

The complete controller integrates the scene in `changed-source/filming/scene.dm`, the authored `tree.dmm` and native `cloud.dmf`. The current3677-blob materialization closure is pinned to9683866; all13 isolation overlays are rebased against exact old/current Git blobs. Initial actors/supplies are prepared before listener/client admission, then take alone waits for first accepted frame. All three map-admission phases use six fixed orchard witnesses. Initial plot rejects pre-existing plants, mature tree or timber, and checks supplied resources. No production tree/farming/watering/chopping body is overridden. This is a complete **inactive source proposal**, not native compilation or accepted footage.

The stock steel hatchet is an explicitly pre-provisioned tool. Production chopping_speed1.55 means46.5 ticks (4.65s, subject to engine tick rounding), not a changed timer. The iron option required51ticks. All visual holds remain unchanged. Nominal sequence18.65s plus prior V29 measured worst first-frame0.172s and marker poll≤0.1s leaves approximately0.83s before frame79 starts19.75s; tree-hosted scheduling overhead remains unmeasured. Existing take≤19.5s and completion-before-recording-return gates still fail closed; no truncation or speedup on failure.
Offline gates: current source bindings, fixture coordinates, all six one-second growth calls via unchanged process_interval, no direct result spawning/stage edits, original resource and timed-chop assertions, nominal18.65s timeline and untouched guard files. Native compilation, first-frame/readiness, actual sprite visibility and scene duration remain test gaps. The prior source showed a reliable native recording; this proposal must meet a stronger human process-clarity review.

## Offline result
Current full controller offline results are recorded in the root review/seal; no BYOND compiler, server, client or FFmpeg invocation was made for this proposal. Tests prove source bindings/structural constraints, not runtime or visual acceptance.
