# Defensive animal retaliation

Adult domestic sheep (rams and ewes), goats (both sexes), pigs (boars and gilts),
cattle (cows and bulls), horses (all colors), and camels can immediately shove
their nearby attacker off balance without dealing damage. This is an explicit
species opt-in, not a rule for stationary mobs or all simple animals.

## Provocation and limits

- Unarmed harm, disarm, or grab intent provokes a response, matching the existing
  `defends` interaction triggers. Help intent never does.
- An item attack provokes only when it actually reduces the animal's health.
  A fatal hit cannot trigger retaliation. Petting, feeding, healing, leashing,
  successful shearing/milking and camel packing retain their noncombat paths.
- Both animal and attacker must be conscious, present directly on turfs and
  adjacent. Incapacitated, resting, immobile or buckled animals cannot respond.
  Self, null, deleted, dead, unconscious, contained, distant, already prone,
  knocked-down, stunned, buckled or weaken-immune targets are rejected.
- The shove uses existing `Weaken(2)` and active-hand `drop_from_inventory`.
  It adds no brute, burn, stamina or organ damage and honors item `nodrop` rules.
  Two Life status updates normally mean at most about two seconds at the
  one-second mob scheduler cadence; scheduling delays can extend wall time, and
  the human strength mechanic may shorten it. No additional stun is applied.
- Both participants receive a ten-second (`100` decisecond) `world.time` deadline
  before effects. The target deadline also prevents several animals from taking
  turns to maintain knockdown. Rejected attempts neither extend knockdown nor
  refresh deadlines. Both deadlines must expire before another shove is admitted.
- No attacker reference, pursuit, repeated AI attack, destruction, or aggression
  toward bystanders is added. Cooldowns are excluded from custom save export and
  import, including legacy payloads, because the clock belongs to this process.

## Audit and boundaries

Normal humans and adult sheep/goats/pigs are all `MOB_MEDIUM`; cattle, horses and
camels are `MOB_LARGE`. These domestic adults do not meet the existing item-hit
retreat rule (`wander` and smaller than attacker). Previously that path called
`do_behaviour("defends")` without retaining a behavior or target, so its first
call could leave them standing without a meaningful response. Several also
inherit zero melee damage. They now use an immediate defensive shove instead.

Calves, lambs/kids and piglets keep their original behavior. A wandering adult
facing a larger attacker still uses its existing item-hit escape path. Explicit
`scared`, `hunt` and `hostile` states never use the new response. Deer, rabbits,
birds, pets, human NPCs and other unrelated animals remain unchanged.

Existing damaging defenders and predators (for example wild male boars, bison,
buffalo, foxes, gorillas, mammoths, snakes, wolves and pachys) retain their combat.
Wild boar gilts and giant ground sloths were observed to have defensive behavior
but no configured melee damage. Changing their wild-animal balance remains a
separate review decision; neither is opted into the domestic shove here.
Turkeys also stand their ground without configured melee damage. A bird-specific
peck or wing response needs separate balance review rather than inheriting a
livestock knockdown. Existing goose/pelican defenses and smaller birds' retreat
are unchanged.

## Verification and reproduction

`tests/animal_combat/test_retaliation.py` checks source contracts, explicit opt-in,
juvenile gates, dispatch, validity, bounds and runtime save exclusions, including
guard-removal and added-damage mutations. These are offline source checks.

`tests/animal_combat/run.py --prepare-only` stages the production fixture and
records the source commit plus working-tree diff without launching native tools.
The runner also runs the offline source tests. Its existing registered CI suite
is selected on a PR introducing `retaliation.dm`/`test_retaliation.py`.

To reproduce the native checks, use the existing runner with BYOND 516.1681:
`run.py --byond-bin <516.1681-bin>`. The 8x8x1 synthetic plating fixture checks
production hand/item provocation, actual knockdown and active-hand drop, nodrop,
single incoming damage/wear, zero retaliation damage, both cooldowns and their
expiry, herd protection, invalid targets, adult/juvenile coverage, noncombat
dispatch and unaffected animals. The existing health/duplicate-hit controls
remain available. Source preparation does not establish native acceptance.

[CI run 39993427940](https://github.com/Civ13/Civ13/actions/runs/39993427940)
passed on `88d013f63ff719d51f44f701ccd9251767000d0a`: BYOND 516.1681 game and
fixture compilation produced zero errors and zero warnings; the native fixture
passed the retaliation checks above and all four existing health, chick,
duplicate and Kenobi negative controls were detected as expected. The actor's
strength coefficient and animation are adapted in this headless fixture.

The earlier [CI run 39992944285](https://github.com/Civ13/Civ13/actions/runs/39992944285)
on `54a273d50b4ef23b27a73d8b5a1c3d50c682f068` compiled cleanly but failed the
feeding assertion because the fixture ram was already full. That failed verdict
is preserved; `88d013f` sets hunger before feeding and is the passed native
result above. Local native execution stayed deferred for the prioritized tanning
work. The runner logs an initial network port before closing it; no zero-listener
census or stronger isolation acceptance is claimed.

For a later authorized isolated client check, place an adult ram beside an awake
human with a removable item held. Pet it, then use harm/disarm/grab intent or a
low-force damaging weapon. Confirm only the provoking nearby human falls and
drops the active item, with unchanged health. Stand and provoke again within ten
seconds, then after ten seconds; only the latter may knock down again. Repeat
with a second ram during the same cooldown and with a lamb, scared deer and
existing hostile predator. Record exact build/map and actual screenshots/video;
connected-client timing and appearance remain unverified. Do not use Gaia or
production saves for these checks.

## Predators

Wild predators (`carnivore` or `predatory_carnivore` animals that fight through
the generic `AttackTarget` path) only go for a person who comes within
`predator_encroach_range` (3 tiles), who hurt them, or when their hunger is
below `predator_starving_hunger` (150). A fed predator gives up an unprovoking
person who backs off past `predator_chase_range` (6 tiles); its attacker
(`provoked_by`, not saved) is never given up. Animal prey is unaffected.

Every generic-path animal bites at most once per cooldown: `melee_attack_delay`,
or `move_to_delay` seconds clamped to 2-4 s. Adjacent fights run every Life tick,
so walking speed no longer sets the bite rate, and a hungry animal in a fight
keeps fighting instead of foraging. A hunting or defending animal that is hurt
by melee or a projectile turns on its attacker, and bites back at once when
adjacent and its cooldown allows. Damage rolls across the whole
`melee_damage_lower`-`melee_damage_upper` range, bites land torso-weighted
(`animal_bite_zone`), and a bite heavy enough to break bone does so only
`bite_fracture_chance` (20%) of the time. Native evidence:
`tests/animal_combat/run.py` (`predator.dm`).

### Distracting a starving predator with thrown meat

When a person throws meat, fish or another non-vegetarian food and it lands
on a turf, every starving natural predator within sight of it (up to its
`aggro_vision_range`) that is chasing or watching a person turns to the food
instead (`lure_starving_predators`, `distract_with_food`). It drops its target,
walks to the food, eats it (`finish_eating(400)`, which leaves it fed) and so
falls back to the fed-predator rule above. People are ignored while it goes for
the food, for at most `food_distraction_time` (20 s), or until the food is
picked up or gone. An animal anyone has hurt (`provoked_by` set) is never
distracted, and hurting a distracted animal ends the distraction. Fed
predators, plant food and animals that are not after a person are unaffected.
The errand (`distracted_by`, `distracted_until`) is not saved.
