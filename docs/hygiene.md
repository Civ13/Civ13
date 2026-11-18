# Hygiene

Cleanliness runs 0-250 (clean 250, normal 200, dirty 75; `code/__defines/mobs.dm`).
Water quality is in [water-quality.md](water-quality.md).

## Dirt from work (`code/modules/1713/hygiene_work.dm`)

Idle cleanliness falls by 0.015 a second (about 2.3 hours from normal to
dirty), plus 0.01 a second in heat of 27 C or more. Finished work adds steps
through `soil(amount, hands)`:

| Work | Lost | Hands |
| --- | --- | --- |
| Farming task (anything that trains farming) | 1 | |
| Mining a rock | 1 | |
| Butchering or skinning | 3 | grimy |
| Relieving yourself | 5 | waste |
| Soiling yourself | 25 + 5 | waste |
| Picking up dung (not compost) | 0 | waste |

## Dirty hands

`dirty_hands` (saved) is 0, grimy (1) or waste (2); gloves keep it at 0. Any
hand wash clears it: every wash that calls `clean_blood()` on the washer (sink,
piped tap, public bath, showers) and a bare hand on fresh water with help
intent (2 seconds). The first bite of each piece of food with dirty hands
rolls once: waste on the hands gives cholera at 4% (worms at a share, as with
dirty water), and either kind gives food poisoning at 5%, scaled by
`infection_chance_scale()`. Examining someone within 2 tiles shows filthy
hands.

## Bathing (`code/modules/1713/bathing.dm`)

| Way to wash | Water | Time | Reaches |
| --- | --- | --- | --- |
| Hands at a sink, tap, bath or fresh water | | 2-4 s | clears dirty hands |
| One body part, help intent (`body_washing.dm`) | 5 from a container | 2 s | +10 on bare skin up to 175; soap +20 up to 250 |
| Sponge bath, bucket on yourself undressed, harm intent (30+ water) | what it holds | instant | up to 175 |
| **Bathe** (IC verb), undressed in a river with a current | | 15 s | 200 |
| **Bathe** in still fresh water | | 15 s | 175 |
| Shower, any material | a tubful on Persistence maps | | 200 |
| Tub soak, any material (`bathtubs.dm`) | a tubful on Persistence maps | 10 s | 200 |
| Soap where there is water | | 4 s | 250 |

Washing one part (`body_washing.dm`): the targeted part says what you mean.
Drinking from a container, or feeding someone, needs the mouth targeted
(`standard_feed_mob`). On help intent any other part washes: click yourself or
someone beside you with an open container holding at least 5 clean water (a
bucket, pot, mug, cup or glass), or
target the part and click a sink, tap, fountain or fresh water to wash it on
yourself (a hand there keeps the hand wash). A hand clears dirty and bloody
hands; another part cleans the blood off the clothes over it, or on bare skin
adds 10 cleanliness up to 175 (20 up to 250 with soap in your other hand).
Water halves the germs in that part's open wounds, and in the part while it is
below the first infection level; soap disinfects the wounds. An infection that
has set in still needs medicine. Water with food poisoning in it is refused.
Off help intent, the drink hint says to switch to help intent to wash instead.

After each part (and after a plain hand wash at open water, a sink or a
basin), washing moves on by itself to the next bare part that still needs it,
head to feet (`next_dirty_zone()`), until none is left, the source cannot pay
for another part (`wash_spend()`, 5 water from a container or tap), or the
washer moves.

Self-examine marks the parts that need washing. Hands show dirty or bloody
from work and blood. Below 200 cleanliness, every part not washed since shows
dirty (filthy below 75); a part washed bare stays clean until cleanliness
falls 25 below what it was after that wash (`washed_parts`, not saved).
Every bare hand wash (open water, sinks, taps, basins) marks both hands, and
Bathe or a sponge bath marks every bare part, even when it stops below 200. Skin
under clothes shows "(covered)", because washing there cleans the clothes.
Each wash says how clean you now feel, and the mood check points a dirty
player to self-examine. Below 200 that feeling follows the marked parts: with
every part washed it says "fairly clean" (water alone stops at 175; soap, a tub
or a river with a current reach clean), and with only covered skin left it
says to undress. Washing the last part that needed it counts as a sponge bath:
cleanliness rises to 175 at least, so a body washed head to foot is never
filthy. Filthy (below 75) is one line everywhere: the mood, self-examine and
being too filthy to sleep. Clothes hold no dirt of their own, only blood and fleas.

Bathing in foul water rolls the illness of drinking it at half the chance.

## Bathtubs (`code/modules/1713/bathtubs.dm`)

Click an empty tub to fill it (on Persistence maps that takes a tubful from
its tank). Click a full tub, or drag yourself onto it, to climb in: a small
tub lays one bather down, a public tub takes one on each of its four tiles.
After a 10 second soak an undressed bather is washed to 200; dressed, nothing
changes. Dragging someone else onto it puts them in and bathes them. Click the
tub again or press a direction to climb out. Alt-click (or Pull the Plug)
empties it into a floor drain or onto the floor. A full tub puts out fire and
brings bathers toward the water's temperature, warning about searing or
freezing water at most once a minute. Soap works anywhere over a full tub.
On Persistence maps a tub or shower holds a tank (`station_water.dm`): turning
it on takes 100 water (bronze and steel 80; the big tubs 200 and 160) unless
running water or a pipe feeds it, and a bucket pours in. Piped showers keep
their own pipe water. Reaching 200 from below gives "being freshly bathed"
(+3 mood), at most once every 20 minutes.

## Fleas and typhus

`handle_hygiene()` in `human_needs.dm`; see [water-quality.md](water-quality.md)
for the rates.
