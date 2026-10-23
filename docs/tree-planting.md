# Growing timber trees

Tree seeds, fruit crops and decorative potted trees already existed. Before this
change, the timber-tree crop reached a harvest sprite and cutting it returned
three logs (with the usual nutrition multiplier) and two seeds. It did not become
a world tree. Fruit crops and decorative pots keep their existing behavior.

## Player steps

1. With Help intent, use a kitchen knife on a small bush to forage seeds. Tree
   seeds are one possible result in the existing biome-filtered catalog. Bush
   seed stock recovers after ten minutes. Some maps also place tree-seed crates;
   their presence is map dependent. No new crafting recipe or research unlock is
   required for planting.
2. Use a plough to prepare an outdoor dirt plot. Keep it under open sky and free
   of dense objects, living occupants and other crops. Stand beside the plot and
   use tree seeds on it. One portion is spent on a successful planting; rejected
   planting spends none.
3. Tend the seedling using existing crop watering and fertilizer interactions.
   Nearby fresh water or flooded irrigation within two tiles supplies water;
   salt water does not. Rain also helps. Drought, snowstorms and sandstorms can
   kill it. Uproot a dead seedling with a knife, bayonet, scythe or hatchet.
4. Allow six successful one-minute growth stages. Poor soil can delay stages.
   All inherited tree biomes are supported; winter is excluded by the existing
   tree season list. Development pauses outside that list while watering and
   soil consumption continue. Occupied, roofed or unploughed plots pause the
   entire stage clock until cleared. Server downtime adds no growth.
5. The seedling becomes an ordinary seasonal broadleaf tree. It uses existing
   branches, leaves, chopping, collision and art. Chop it with a suitable tool
   for the normal seven logs. Cutting a seedling only uproots it and returns no
   logs or seeds. Forage bushes again for replacement seeds.

## Implementation and compatibility

Only `/obj/structure/farming/plant/tree` uses the existing `processing_objects`
scheduler instead of inherited recursive crop waits. It reuses `stageGrowth`,
`soil_nutrition_proc` and `water_proc`, and converts at the existing stage-7
threshold to `/obj/structure/wild/tree/live_tree`. No new world scan, plant loop,
sprite or resource recipe is introduced. Trees enforce their declared climate
and season together, including maps where ordinary crops bypass those gates.

The save contains stage, water, nutrition and `growth_time_left`. The process
clock `last_growth_tick` is excluded on export and legacy import. Construction
only registers; `after_load` anchors the clock without resetting progress or
charging soil/water. Set membership prevents duplicate registrations. Services
during an active save/load operation do no growth work. Credit is capped by both
the scheduler interval and elapsed game ticks, so a lag or duplicate callback
cannot cause catch-up growth. Up to one unserviced object interval is lost on a
save, rather than credited twice after a restart.

Legacy saved timber crops keep their stage/water/nutrition. Their absent remaining
duration defaults to one minute; a living stage 7-10 crop becomes a world tree
after its next eligible minute. Stage 11 corpses and static props stay terminal.
Mature trees use the unchanged world-tree serializer and seasonal behavior.

## Verification and remaining acceptance

`tests/tree_planting` executes the production scheduler body through explicit
synthetic engine adapters and checks admission, art, seed supply and save hooks
offline. It includes generated source controls for stopped clocks, import work
and seasonal growth. The native fixture uses the real planting dispatch,
watering, saver/loader, repeated `after_load`, mature tree construction and wood
drop. A separate writer and fresh reader additionally exercise production object
dispatch and saved partial-duration resume. Fixture-owned durations are shortened;
the natural scheduler cadence and connected-client presentation remain separate.

The follow-up integrates master including #3286's processing-only hide guards.
Native fixture compilation succeeded under BYOND 516.1681, with zero errors and
warnings. Runtime acceptance is blocked by an initial localhost listener caught
by the unchanged Windows supervisor, including after an earlier-global port close.
Native assertions, real disk round-trip execution, fresh-process recovery and
client captures remain unverified. See [the attempted-run evidence and remaining
acceptance](tree-planting-native-validation.md). No OpenDream or live Gaia changes
were made, and no guard was bypassed after its rejection.

This branch has no dependency on the Atlas variant, animal retaliation or saved
year changes. It changes one curated Atlas acquisition record and its generated
catalog; concurrent Atlas work must regenerate the catalog after combining work.
It does not modify persistence core code, year state or animal interactions.
