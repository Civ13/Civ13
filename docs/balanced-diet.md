# Balanced diet

Design and implementation notes for issue #3313. Eating a varied diet, and eating
foods your character happens to like, raises the amount of stamina your character
can store and spend. Hunger, thirst and digestion work exactly as before.

## Player behavior

- **Energy is stamina.** Running and physical work already spend stamina, and it
  already refills over time. A good diet raises the stamina ceiling by up to
  **25%**, so the extra energy is spent and refilled the same way. The Status
  panel shows **Diet energy: +N% capacity**; stamina can read above 100%.
- **Four nutrient groups**: carbohydrate, protein, fat and vitamins. Every unit of
  food or nutritious drink that is actually digested adds to the matching
  reserves. Each group that is at least *adequate* adds **5%** capacity.
- **Tastes.** Each character likes one flavour and dislikes another in each taste
  category (grain, vegetable, animal, fruit and sweet). The lists are hidden.
  Eating a liked flavour builds *enjoyment* (up to **+10%** capacity); a disliked
  flavour wears it down. The first time a character eats about one unit of a
  liked or disliked flavour, they learn that fact, get a chat message and find it
  in **IC > Notes** under Discoveries. Neutral flavours reveal nothing.
- **Better dishes.** A prepared meal (vegetable potage, hearty stew, seasoned
  hearty stew) whose ingredients include liked flavours earns extra enjoyment,
  scaled by the meal's quality tier.
- **Check Diet** (IC tab) lists each group as depleted, low, adequate or plenty,
  whether it is rising or falling since the last check, capacity versus available
  stamina, active effects, and which foods would help each low group.
- **Examining food** shows its nutrient make-up (for example "mostly vitamins,
  some carbohydrate") and any tastes this character has already learned about
  its main flavours.
- **Imbalance.** If two or more groups stay below adequate for about 15 minutes
  the character is warned. The diet bonus fades as reserves fall. A mild
  fatigue penalty (stamina refills 25% slower after about 45 minutes of
  imbalance) exists but is **off** (`diet_penalties_enabled = FALSE`) until
  availability is shown in every supported map and season; see below.

Ordinary meals stay viable: the base stamina ceiling never shrinks, and nothing
here causes damage, disease or death.

## Audit of existing systems

| System | Where | Decision |
|---|---|---|
| Hunger | `/mob/living/human/var/nutrition`, burned in `human_life.dm` at `0.27 * 0.32` per Life tick, raised by `nutriment_factor * removed` in `/datum/reagent/nutriment/affect_ingest` | Unchanged. Diet reads the same metabolized amount after hunger is credited. |
| Thirst, bladder, bowels | drink and nutriment `affect_ingest` | Unchanged. |
| Digestion | `/datum/reagents/metabolism` removes `metabolism` units per tick from `ingested` | Diet is credited per tick from the removed amount, so only eaten food counts. |
| Stamina | `stats["stamina"]` = (current, maximum); spent by running (`mob_movement.dm`), work (`production.dm`), combat; refilled 2% of maximum per tick | Refill now targets `diet_stamina_cap()` (maximum plus diet bonus) through `diet_recover_stamina()`. Stat growth still changes only the maximum. |
| Flavour lineage | `/datum/reagent/nutriment` `data` holds flavour descriptors (`nutriment_desc`), merged by `mix_data` when foods are combined or cooked, with flavours under 10% culled | Used as the ingredient lineage for both nutrient profile and tastes. No name matching. |
| Prepared meals | `cooked_meals.dm` mood floor with finite `meal_reward_food` credit per bowl | Dish bonus uses the same finite paid credit. |
| Discoveries | `/datum/mind/proc/learn_discovery`, rendered in Notes | Tastes are recorded as category `food_taste`, identity the flavour, context the character's taste token. |

## Nutrient profiles

`code/modules/diet/diet.dm` holds the tables:

- `diet_descriptor_profiles`: flavour to group shares, for example `carrot` 80%
  vitamins and 20% carbohydrate, `meat` 70% protein and 30% fat, `beans` half
  protein and half carbohydrate, `mushroom` half vitamins and half protein.
- `diet_reagent_profiles`: reagents whose identity fixes the profile (`protein`,
  `egg`, `cornoil`, `honey`, flours, `coconutmilk`, `apricotjuice`).
- Unknown flavours and plain nutriment count as carbohydrate.

Each digested tick adds `nutrition points * share` to each group, where nutrition
points are what hunger already received (`nutriment_factor * removed`, or a
drink's `nutrition * removed`). The sum of the four reserves therefore equals the
nutrition eaten, up to the cap.

| Constant | Value | Meaning |
|---|---|---|
| Reserve cap | 150 per group | Over-eating one group cannot bank more |
| Start value | 80 per group | New and legacy bodies begin adequate, never penalized |
| Adequate | 40 | Counts toward the bonus; below it the group is "low" |
| Decay | 0.04% of each reserve per Life tick | About an hour half-life, so one missed meal changes little and one bite fixes little |
| Group bonus | 5% each | Up to 20% for all four |
| Enjoyment | 0 to 100, gains half the nutrition points times net liked share, same decay | Up to 10% |
| Total bonus cap | 25% | |
| Taste share | 25% | A flavour must be at least a quarter of the food's lineage to count for tastes |
| Imbalance | two or more groups below adequate | Counter rises 1 per tick, falls 3 per tick when balanced |

## Character tastes

- Generated lazily the first time a character eats (or the first time the tastes
  are needed) and stored on the mind, so they belong to that character life.
  Reconnect and moving to another body keep the same mind. A fresh respawn creates
  a new mind and so a new hidden profile, with no discovery records.
- Legacy minds have no tastes; they get one profile on first use, which is then
  saved. `diet_ensure_tastes()` never rerolls an existing profile.
- `diet_validate_categories()` keeps a category only if it has at least two
  distinct flavours not already claimed by an earlier category; anything else is
  logged and skipped. One like and one dislike are drawn per kept category, so a
  flavour can never be both.
- Categories and why each flavour is reachable without admin supplies:

| Category | Flavours | Sources |
|---|---|---|
| Grain | wheat, oats, barley, rice, corn | farmed crops |
| Vegetable | potato, carrot, cabbage, tomato, turnip, beans, mushroom | farmed crops; winter turnips; underground plump helmets |
| Animal | meat, egg | butchery (protein), bird eggs |
| Fruit and sweet | fruit, honey, sweetness | grown fruit and berries, beekeeping, sweet berries |

  `tests/balanced_diet/test_balanced_diet.py` checks that every listed flavour is
  carried by one of those sources.
- Hidden lists are never shown. Check Diet and food examine read only
  `diet_tastes_known`, which holds facts the character has learned. Notes render
  only the learned record's label and observation, which `learn_discovery()`
  escapes.

## Exploit prevention

- Diet is credited from metabolized units only. Slicing, sharing, pouring and
  diluting move reagents without creating them, so totals are conserved; the
  native probe compares one 4-unit meal, forty 0.1-unit bites and a meal diluted
  in water.
- Reagent-soaked food and mixed drinks count by what is actually in them.
  Non-nutritious reagents add nothing.
- Reserves, enjoyment and the bonus are all capped. Repeated eating cannot stack.
- Liked and disliked flavours in one dish offset each other. Flavours below 25%
  of the lineage, and anything `mix_data` already culled below 10%, are ignored,
  so a pinch of a liked food does not make a favourite.
- The dish bonus draws on the bowl's finite `meal_reward_food`; refilling a bowl
  does not renew it.

## Persistence

Saved with the body: `diet_reserves`, `diet_enjoyment`, `diet_imbalance_ticks`.
Saved with the mind: `diet_tastes`, `diet_taste_token`, `diet_tastes_known`,
`diet_taste_exposure` and the discovery records. `diet_last_check` (the Check Diet
trend snapshot) is a runtime field excluded from saves.

## Availability before penalties

Penalties beyond losing the bonus stay off. Before `diet_penalties_enabled` is
turned on, each supported map and season needs a demonstrated, affordable route
to all four groups without admin supplies. Current evidence, from source:

| Group | Surface summer | Winter | Underground start |
|---|---|---|---|
| Carbohydrate | grain, potato, corn | stored grain, turnips | plump helmets are vitamins and protein, not carbohydrate; bread or grain must be carried or traded |
| Protein | meat, eggs, beans | meat, eggs | plump helmets, cave animals where the map has them |
| Fat | meat, eggs, cooking oil | meat, eggs | cave animals where the map has them |
| Vitamins | vegetables, fruit, berries | turnips | plump helmets |

Because the underground carbohydrate route and per-map coverage are not yet
proven in play, enabling penalties is tracked as separate follow-up work.

## Verification

```sh
python3 -I -B -m unittest discover -s tests/balanced_diet -p 'test_*.py' -v
python3 tests/balanced_diet/run.py --byond-bin "$BYOND_BIN" --output <empty dir>
for c in balance conservation trace penalty; do
  python3 tests/balanced_diet/run.py --byond-bin "$BYOND_BIN" --negative-control $c --output <empty dir>
done
```

The native probe compiles the full game with an isolated world and runs the real
metabolism, stamina refill, examine summary, prepared-meal bite, Notes renderer
and serializer. It covers equal-intake comparisons (balanced versus single-group
and liked versus neutral), usable stamina above the base ceiling, conservation
across splitting and dilution, bounds, taste discovery and privacy, offsetting and
trace flavours, prepared-dish credit and refill, taste generation and validation,
legacy initialization, gradual imbalance and recovery, penalty gating and a
native save and load of a detached character mind. Each negative control must
fail the matching assertion.

Not verified here: live play with a connected client, a full saved-body reclaim
round trip, and real per-map availability timing.
