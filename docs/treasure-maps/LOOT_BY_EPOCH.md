# Buried Ruins loot by epoch

Each era should reward the kind of expedition it depicts, without making ruins
the only source of technology or the best way to gather ordinary materials.
This proposal covers the ten source-defined Persistence epochs, using the
[origin epoch ordinal](../../code/modules/persistence/functions.dm#L46-L58)
rather than parsing the displayed date. The first profile is civilian:
everyday materials, spare gear and one useful find. Nothing here is a live
drop table, enabled rule, game tuning result or reward guarantee.

## Starting tables

Each cell shows two **alternatives**, not rewards that are awarded together.
Weights are relative within a slot; e.g., 70/30 means 70 and 30 out of 100
before any ordinary item eligibility constraint. Weights, quantity and
tuning are proposed starting points.

| Origin epoch | Theme | Supply 70/30 | Optional cache 65/35 | Vault 60/40 |
| --- | --- | --- | --- | --- |
| 0. 5000 B.C. | Early camp | 3 stone / 2 logs | 2 rope / 2 logs | 1 stone fat lamp / 1 empty cloth drawstring pouch |
| 1. 313 B.C. | Masonry store | 3 sandstone / 3 stone | 2 rope / 2 logs | 1 empty small copper pot / 1 empty cloth drawstring pouch |
| 2. 1013 | Scribe workshop | 3 finished planks / 3 stone bricks | 2 blank paper / 2 rope | 1 lantern / 1 empty red folder |
| 3. 1713 | Surveyor’s station | 3 glass sheets / 3 finished planks | 2 blank paper / 2 rope | 1 compass / 1 empty thermometer body |
| 4. 1873 | Rail stores | 3 finished planks / 3 stone bricks | 2 cloth / 2 rope | 1 railway hand lamp / 1 pair of work boots |
| 5. 1903 | Utility workshop | 3 glass sheets / 3 finished planks | 2 m blue cable / 2 blank paper | 1 cable connector / 1 empty duffel |
| 6. 1943 | Field engineering | 3 stone bricks / 3 finished planks | 2 cloth / 2 rope | 1 pair of mountaineering boots / 1 railway hand lamp |
| 7. 1969 | Civilian field kit | 3 cloth / 3 finished planks | 2 blue glowsticks / 2 rope | 1 folding umbrella / 1 empty retention lanyard |
| 8. 2013 | Diagnostics workshop | 3 glass sheets / 3 cloth | 2 m blue cable / 2 blank paper | 1 handheld reagent analyser / 1 standard power cell |
| 9. 2026 | Terrain survey | 3 finished planks / 3 glass sheets | 2 blank paper / 2 blue glowsticks | 1 unconfigured smartphone / 1 GPS receiver without waypoints |

The [review data](loot-tables.json) lists the exact existing DM path and source
line for each candidate, plus relevant Crafting Atlas provenance where a
direct recipe describes it. Rope and stone brick Atlas outputs may be
resource aliases; the table records the actual portable stack type. The
table never grants recipes, unlocks, notes or licenses. Blank paper is
ordinary blank paper, not an official form or an authoritative treasure map.
The reagent analyser is the existing handheld laboratory tool. A GPS
receiver has no waypoints and requires normal satellite service; a phone has
no accounts, address book, numbers or new network privileges preloaded.

## Pinned profile and award rules

1. **Snapshot at issue.** The authoritative original blueprint pins origin
   region/world lineage, source epoch **ordinal**, loot profile version and
   canonical content hash, policy version, per-run limits and a hidden
   seed. A map issued in 1713 does not become a 2026 prize by waiting,
   shipping the map, or changing realms or date. The table is never provided
   by player paper, item names, DMM contents or the client. Disable or retire
   a pinned profile without substituting a different table on an old map.
2. **Single deterministic allocation.** Use a server versioned, domain-separated
   deterministic draw per logical slot, keyed by the original blueprint and
   immutable slot ID. Record one chosen lot ID and amount before revealing
   the contents. Openings, retries, copies, respawns and regenerated world
   chunks consult that receipt instead of rolling again. Normalize quantity
   through the exact item definition (for example, two meters of blue cable,
   not two full coils).
3. **Ordinary eligibility.** Exclude items prohibited by origin map policy,
   the pinned era ceiling, current ordinary research/participation eligibility
   or the transfer allowlist. Recheck when revealed and before extraction,
   including if participant or faction membership changed. Check both the
   source admissibility and current destination policy; an epoch advancing
   cannot upgrade the pinned reward and a compatible re-entry cannot reroll
   it. If the pinned lot is no longer eligible, use its one configured
   conservative fallback (small stone, log or empty cloth pouch according to
   slot) **only if** normally permitted; otherwise award nothing for that
   slot. No repeated retries, compensating rolls, modern substitute, or
   research/availability bypass. Expose a bland sealed-cache/no-grant reason,
   not hidden profile settings.
4. **Party-wide caps.** At most one reward-bearing supply socket, one optional
   cache and one vault roll for the entire party, regardless of the number
   of lookalike containers, exits, regions or ready players. Supply is
   capped at three stack units, cache at two stack units or ordinary small
   consumables, vault at one durable item, a combined maximum of six
   counted units and one durable item. Cable meters count as units. This is
   a budget ceiling, not a target reward or six objects. Physical chest
   placement, rarity and issue rate can still lower it. Gear must carry
   exact empty or approved inactive state through the existing supported
   codec. No hidden inventory, extra power or fuel, cargo containers with
   contents, keys, currency, banks, weapons, ammo, military loot, vehicles,
   technology grants, high-value bulk or complete infrastructure kits.
5. **One successful extraction.** Entering/opening a container is not a
   durable grant. Only supported loot in actual personal custody and the
   designated origin-mouth extract chest can be committed by the existing
   planned journal on a successful exit. The same lot cannot be awarded
   from both channels or to two players; the exact lot/quantity is consumed
   once from party budget at the terminal commit. Unsupported nested state
   cannot leak or multiply items. An intercepted death returns the affected
   original character and gear with no loot; timed-out/failed/abandoned
   custody receives no loot. Retrying/recovering a successful commit reuses
   the same immutable award receipt, not another draw. An early normal exit
   never awards unopened containers. Normal disposal/settlement rules still
   apply after a committed recovery; no automatic sale or paid-for recipe.
6. **Economy review before enabling.** Six units is a conservative first
   cap, not evidence of no inflation. Compare reward value and effort to an
   ordinary workshop trip using map-local supply, verify scarcity on each
   active map, and look at paid claims per epoch, prize repetition and
   loss-normalized attempts in a contained test. Use a low issue cap at
   first. If supply outpaces ordinary craft or one tech becomes default
   dungeon farming, lower issue frequency or candidate caps for **new**
   profile versions. All source profile fixtures stay off by default.

## Verification needed

Offline proposal validation checks every epoch ordinal, exact source
types and available Atlas links, normalized weight totals, minimum-era
and party caps, and fenced rejection of future items and excluded
categories. Before implementation claims: test same input across
restarts, no reroll on failed or duplicate opens, expiry and epoch changes,
per-run and concurrent-party conservation, changed faction or release
policy, fallback unavailable, and container/custody crashes at each
journal phase. Test recovery/arrival with actual legal empty items,
charge/consumable state and supported saved serialization in a staged
native fixture separate from live saves. The fixed stock room/chest art
currently does not spawn or grant loot.
