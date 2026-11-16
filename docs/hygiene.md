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
| Sponge bath, bucket on yourself (30+ water) | what it holds | instant | up to 175 |
| **Bathe** (IC verb), undressed in a river with a current | | 15 s | 200 |
| **Bathe** in still fresh water | | 15 s | 175 |
| Tub or shower, any material | a tubful on Persistence maps | | 200 |
| Soap where there is water | | 4 s | 250 |

Bathing in foul water rolls the illness of drinking it at half the chance.
On Persistence maps a tub or shower holds a tank (`station_water.dm`): turning
it on takes 100 water (bronze and steel 80; the big tubs 200 and 160) unless
running water or a pipe feeds it, and a bucket pours in. Piped showers keep
their own pipe water. Reaching 200 from below gives "being freshly bathed"
(+3 mood), at most once every 20 minutes.

## Fleas and typhus

`handle_hygiene()` in `human_needs.dm`; see [water-quality.md](water-quality.md)
for the rates.
