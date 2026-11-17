# The hull ledger

Every hull the players built and commissioned on the water keeps one record of
her condition (`code/modules/naval/hull_ledger.dm`, `/datum/hull_ledger` on
`/datum/craft`). It is plain numbers, like a submarine's air ledger: no water
lies on any tile. Airships and turf-built vessels have none.

## Size classes

| Class | Tiles of hull | Seams |
| --- | --- | --- |
| Small craft | up to 12 | never seep |
| Boat | 13 to 40 | seep when built of wood |
| Ship | 41 and up | seep when built of wood |

A plank of steel, iron or aluminium lets nothing through; a tile counts as wood
unless one of those lies on it. The class and the count are surveyed when she is
commissioned, refitted and loaded.

## Bilge water

- She holds 4 bucketfuls a tile and is awash at half of that. The water stops at
  awash until holes and foundering are built.
- A wooden boat or ship takes 0.045 bucketfuls a tile a minute under way and
  half that lying still: left alone she is awash in about 45 minutes, and half an
  hour's seepage is two minutes' bailing for one person.
- She only changes while she is awake: under way, or with a living player on
  her deck. A moored or anchored hull with nobody aboard keeps what she has.
- Past a damp bilge (a tenth full) the water weighs on her drives as more tiles
  of hull (`craft.mass()`), so a sail that made half ahead may only make slow.
- The tiller reads the depth: dry, damp, ankle deep, knee deep, awash. The crew
  is told once as each of the last three is reached.

## Bailing

Stand on her deck and use an empty bucket on one of her planks. Each bucketful
takes three seconds; the bailer carries on until the bilge is dry, they move or
they put the bucket away. A step of the hull does not stop them.

## Cost and saves

One looping timer (`hull_ledgers_tick`, every 30 seconds) steps the ledgers that
are awake. Players are matched to hulls from the client list with one keyed
lookup a hull, so empty hulls cost no deck walk. Nothing runs during a world
save. The tiller saves the ledger inside its `hull_state` record
(`"ledger": {"water": n}`); nothing stores `world.time`.

## Tests

    python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/bilge_probe.dm 300
