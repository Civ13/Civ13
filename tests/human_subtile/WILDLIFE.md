# Wildlife movement coverage and remaining work

This is a source inventory for the staged wildlife branch. No wildlife type
enables the new pursuit, follow, flee, pet, species or recovery gates. The only
existing default pulse opt-in remains the NPC vendor family. A staged producer
is not evidence of native collision, gameplay or visual correctness.

| Wildlife or behavior | Current source path | Coverage and remaining work |
| --- | --- | --- |
| Common passive wander and food seeking, including many farm animals, deer, rabbits and birds | `simple_ai.dm`, `simple_animal.dm` | Existing `ai_step` call sites can pulse only when explicitly enabled. Inherited follow, scared, pursuit and species overrides must also be safe before enabling any type. |
| Predators and defensive wildlife, including wolf, bear, alligator and snakes | `hostile/tactical_ai.dm`, `code/pathfinding.dm` | Pursuit, idle combat wander and attack gate are staged and default-off. AI-tick side choice is serialized with pulses; exact legacy overlapping movement, timing, stuck count and RNG ordering are not established. Review per-type attack and Life overrides. |
| Leashed animals and animal-to-animal following | `simple_animal.dm`, `subtile_movement.dm`, `code/modules/1713/structures.dm` | Follow owner is staged and default-off. `following_mob` remains a durable level link; compare native `walk_to`, leash break, retarget and combat precedence. |
| Cats and dogs, including cat friend-follow | `friendly/cat.dm`, `friendly/dogs.dm`, `simple_animal.dm` | Pet walk owner is staged and default-off. Verify scan stops, target changes, prey-on-turf attacks, flee, friend distances and handoffs to follow or pursuit. |
| Crabs | `friendly/crab.dm` | The independent lateral decision has a staged default-off pulse branch. Inherited food, fear, follow and possession states still need coverage. |
| Flies and mosquitoes | `friendly/flies.dm`, `hostile/mosquitoes.dm` | Random/towards movement, swat-flee and curtain redirects route through one default-off staged species owner. Legacy commands remain the default; native callback, collision and bite/disease timing still need verification. |
| Vampire bats | `hostile/vampirebat.dm` | Random/towards commands route through the same staged owner. Contact decisions retain their Life/RNG location with a settled-attacker guard. Verify native choice, disease and interval timing. |
| Frogs and small insect eaters | `friendly/lizard.dm` | Consumption now requires both staged animals to be settled. The frog egg `walk_towards` sits in an `else if (isturf(loc) ...)` after an `if (isturf(loc) || ...)` and is unreachable; breeding logic remains unchanged. |
| Mammoths and T. rex | `hostile/mammoth.dm`, `hostile/dino.dm` | Their 96x96 bounds and direction-dependent `bound_x` are rejected by the current 32x32 admission. See `MULTITILE_WILDLIFE.md` for the required footprint contract. |
| Constrictor snakes and special contact attacks | `hostile/snake.dm`, `hostile/monsters.dm` | Constrictor `forceMove` is an explicit attack interaction, not a walking step. Beetle contact and `AttackTarget` behavior need separate callback/attack timing checks. |
| Boreas and Echofiend | `hostile/monsters.dm` | Oven, victim and investigation `walk_to` commands and stops use the staged path owner with a legacy fallback; relevant source target writers invalidate obsolete pending commands. Review native pathing, engine callbacks and interactions before enabling. |
| Commanded bear and dog | `hostile/commanded/` | Inherited follow and command stops use the staged path owner and targeted invalidation. Their AI and command interactions still require native verification. |
| Other animal and map-specific descendants | `friendly/`, `hostile/`, and simple-animal descendants outside that directory | This matrix is not a complete type taxonomy. Enumerate inherited and overridden producers at the exact integration commit before claiming all wildlife. |

Player-controlled, ridden, pulled, restrained, buckled, incapacitated and
non-32x32 bodies are states or shapes of actors, not a separate wildlife class.
The current pulse admission excludes those states; it does not establish smooth
movement or a safe transition for them. A human monkey and a simple-animal monkey
also have different movement ownership. Do not assume one implementation covers
both or turn these exclusions into a claim that all wildlife is complete.

## Pending intent invalidation

The pending slot is bounded to one runtime-only intent. The following mutation
hooks now invalidate at the write, including a change and restoration between
polls:

- Direct `following_mob` assignments in the current source route through
  `npc_set_following`; unchanged values do not cancel a request. The durable
  field and level-link codec are retained.
- Direct pet `movement_target` and `flee_target` assignments route through
  mode-specific setters; only a pending pet command using that field is cleared.
- Common wildlife combat-target writes in `simple_animal.dm`, `simple_ai.dm`,
  `hostile/tactical_ai.dm`, `friendly/mouse.dm` and `hostile/mammoth.dm` route
  through `npc_set_combat_target`. A real target change clears the pending slot;
  reassigning the same target does not.
- Completed mount and dismount transitions clear pending work; client login,
  death and deletion have staged invalidation in source. Their native dispatch
  and timing are not yet verified. None enables movement while ridden or controlled.

The lexical assignment check covers direct DM writes to those three target fields,
not dynamic `vars[]` writes, engine reference nulling, save import or unknown
future code. The save loader restores durable links through its codec while the
pending worker is excluded. Other combat `target_mob` writers and `target_obj`,
`stance`, and `behaviour` still have many direct mutations across animal,
extraction and magic code. The pending validator samples those values on Life, selected pulses
and dispatch; it cannot prove invalidation if a value changes and returns between
checks. Other authority, location, restraint and engine callback transitions also
need a precise mutation/ownership audit. Do not claim a universal no-replay epoch.

## Next steps

1. Review the narrow mutation setters and cover the remaining relevant state
   writers with bounded, field-specific invalidation. Add omission controls for
   actual writes and review dynamic or engine-owned transitions separately; avoid
   a global event bus or per-pulse searches.
2. Review the staged insect/bat continuous walker, selective food-stop and contact
   guards. Review Boreas/Echofiend and commanded path adapters; cover remaining overridden
   producers while preserving selection, intervals and stop semantics. Serialization
   changes when an overlapping pursuit side-step can execute.
3. Design multi-tile collision and interrupted interaction handoffs, including
   controlled/ridden states, without snapping or an unsafe legacy fallback.
4. Integrate the current master movement hook and run the authorized exact-commit
   compiler, native collision/AI/save fixtures and real-client motion checks when
   separately allowed. No native, live-server, merge or publication action is
   authorized by this inventory.

The species adapter converts native lag from world ticks to deciseconds using
`world.tick_lag`; each reissued command resets its first deadline and reuses one
owner. A replacement during a physical pulse invalidates that receipt and may
wait for its paid interval and collision-safe alignment. This serialized handoff
can differ in timing from overlapping native walkers. Offline source contracts
cannot establish equivalent scheduling, engine pathing or gameplay costs.

For mosquitoes and vampire bats, a bounded one-bit contact window holds the
walker after an arrived or settled pulse until the next Life contact observation.
The original Life roll and target loop remain in place, with no queued attack or
extra roll. This may extend a movement interval by up to a Life scheduling gap;
repeated interrupted pulses, callback ordering and actual bite frequency require
native verification. The gate remains off. BYOND walking lag is converted at the
producer boundary from ticks using `world.tick_lag`; pursuit's existing decisecond
movement delay is unchanged. OpenDream is not the timing reference for this stage.
