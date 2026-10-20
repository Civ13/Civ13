# Farm registry retirement source contract

Narrow correction for the population-accounting slice of issue #3051. Fifteen
existing farm-animal death/Destroy hooks intersect their registry with `src`
using `&=`. That removes every other member and can retain the retiring member;
an unregistered male boar's death can empty the boar registry. Replace only those
operators with `-=` to remove the retiring member without clearing its peers.

## Scope

- Cows and bulls: death and Destroy (four hooks).
- Pig gilts and boars: death and Destroy (four hooks).
- Wild boar gilt: death and Destroy; wild male boar: death (three hooks).
- Goat and sheep base types: death and Destroy (four hooks).

Each existing hook remains unconditional and still calls its parent afterward.
No live/dead check, constructor, revival, birth, yield, food cost, save field,
registry creation, population cap or callback changes. Repeated removal is
intended to be idempotent; native execution has not been performed here.

Existing constructors register cows/bulls, pig gilts/boars, female wild boars,
and goat/sheep base types, without checking consciousness. Thus these registries
are not filtered snapshots of conscious animals. Death/Destroy retire entries.
The global conception gates inspect registry length: under 30 for cow/pig/boar,
under 35 for goat/sheep. Nearby mate and population checks require CONSCIOUS and
reject local counts above five. Already-pregnant animals continue their existing
birth countdown; this patch does not impose a hard birth-time population cap.

Known separate lifecycle gaps are deliberately not repaired:
- Male wild boars have no New registration or Destroy hook in this file.
- Goat/sheep female Life guards milk with CONSCIOUS but does not early-return
  before reproduction, unlike cow/pig/boar.
- Base simple-animal Life can revive a dead animal whose health becomes positive;
  this path updates living/dead mob lists, not these farm registries.
- Bear/bison/wolf registries elsewhere also contain intersection retirements.

## Offline check

Run from the repository root:

    python -m unittest discover -s tests/animal_registry -v

Five source-contract tests check all 15 exact hook bodies without requiring Git
history. Synthetic restoration of all intersection operators and each individual
reversion are rejected; unrelated source additions remain allowed. One-time review
against master 5bf351248de6050876fe5b53f91209a970cc5668 verified that the production
diff changes only these 15 operators (not a permanent whole-file test constraint). Missing-parent, wrong-registry and clear-all mutations are rejected for
every hook. These are textual contract checks, not a DM interpreter or evidence
of native list semantics, compile success, save/load, reproduction, graphical
acceptance or whole-game performance. No workflow change or external publication
is included.

Before native acceptance, exercise production hooks with multiple retained peer
identities: death, repeated death, Destroy without death, death then Destroy, and
unregistered owner removal; assert only that owner disappears and parent runs.
Keep native compiler/runtime and connected-client results separate.

## Duplicate review

Read-only GitHub all-state PR searches for cow_count, animal registry, livestock,
husbandry, and farm death plus the recent 200 PR bodies and this file's Git history
found no existing repair. Merged #3126 concerns animal health/attack dispatch,
#3080 harvesting, and #3133 drying preservation, not these retirement operators.
This correction does not complete the broader #3051 husbandry milestone.
