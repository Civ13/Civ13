# Dentistry

Source: `code/modules/1713/dentistry.dm` (hooks in `organ_external.dm`
knock-out, `cooked_meals.dm` bites, `living/say.dm`, `examine.dm`,
`human_attackhand.dm`, `human.dm` spawn/revive and `human_life.dm`).
Tests: `tests/dentistry/`. Art: `tests/sprites/create_dentistry.py` ->
`icons/obj/dentistry.dmi` (drawn by Fable).

Grounded and low-maintenance: nothing here needs regular attention from a
player who eats plainly and owns a chewing stick. Dental decay only runs on
civilization (persistent) maps, like hair growth.

## Teeth state (head organ, saved as plain values)

Natural teeth are the existing `teeth_list` stacks (32 for humans). On top:
decayed, prepared (scraped and waiting for a filling) and filled counts,
plaque, minutes a cavity has gone untreated, an abscess flag, bridged teeth,
and a fitted denture typepath and gap count. Knock-outs remove a random mix
of rotten, filled and sound teeth. Spawn and revival reset everything.

## Decay, toothache and abscess

- Each bite of food adds 0.2 plaque, plus the sugar, honey and syrup in the
  bite (at most 5). Saliva removes 0.5 a minute.
- From 100 plaque a sound tooth has an 8% chance a minute to start a cavity
  (plaque drops by 50). A sweet-toothed character who never cleans gets about
  one cavity per 15 to 20 sweet bites; plain bread alone takes hours.
- A cavity gives an occasional dull toothache (pain 15, -1 mood) and pain on
  biting. After two hours untreated it can abscess (3% a minute): stronger
  pain, -2 mood, a swollen jaw on examine and a little toxin, capped at 20 so
  it never kills on its own. Painkillers mask the pain as usual.
- An abscess clears when a rotten tooth is drawn, or with penicillin (the
  cavity itself still needs treating).

## Hygiene

| Item | Research | Recipe | Effect |
| --- | --- | --- | --- |
| Chewing stick (miswak) | Hygiene | 0.5 wood + knife | removes 60 plaque, 6 uses |
| Toothbrush (bone and bristle) | Sanitation | 1 bone + knife | removes all plaque, lasts |

Use in hand on yourself.

## Treatment (help intent, aim at the mouth, face not cut open)

- **Drawing a tooth**: dental forceps (iron, or bronze; Field Surgery) work
  best; a hemostat or wirecutters will do at a pinch. Takes a rotten tooth
  first, hands it over, and clears an abscess. Any era.
- **Replanting**: a tooth knocked out of someone's mouth stays fresh for ten
  minutes (not across a save). Pressing it back (Surgical Theory) takes about
  half the time at once, falling to one in five by the end; a failed try
  leaves a dead tooth. Merged piles are only as fresh as their stalest tooth.
- **Fillings** (Surgical Theory): scrape the cavity with a dental pick or the
  surgical drill, then pack it with lead, tin or gold (1 sheet), or silver
  amalgam lumps (Anesthetic Surgery). Abscessed teeth must be drawn or the
  infection cleared first. Filled teeth no longer decay.

## Replacing teeth

| Replacement | Era (research) | Recipe | Chews |
| --- | --- | --- | --- |
| Gold band bridge (Etruscan) | Field Surgery | 1 gold + 3 teeth | 3 teeth, fully |
| Carved bone dentures | Surgical Theory | 3 bone + knife | 30% |
| Human-tooth dentures | Surgical Theory | 2 bone + 16 teeth + knife | 60% |
| Porcelain dentures | Anesthetic Surgery | 2 clay, fired in a kiln | 80%, may shatter on a blow |
| Vulcanite dentures | Anesthetic Surgery | 2 rubber + a porcelain set | 90% |
| Acrylic dentures | Modern Medicine | 2 plastic | 100% |

A bridge is bound in by a practitioner (a surgery step) and needs at least two
natural teeth to hold; it falls out if fewer remain. Dentures fill every gap:
use them on your own or a patient's mouth; click your own mouth with an empty
hand on help intent to take them out. A hard blow to the mouth can knock
dentures out.

## Effects of missing teeth

- Chewing: under 16 chewing teeth each bite shrinks, to half with none.
- Speech: from 8 gaps, "s" starts to whistle into "th", more often as gaps
  grow. Any full set of false teeth fixes it.
- Examine shows the gaps (false teeth hide them) and names the dentures.

## Later ideas (not built)

Local anaesthetic injections, root canals, crowns, orthodontic braces and
fluoride toothpaste for the modern eras.
