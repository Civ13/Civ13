# Permits and licences

Code: `code/game/mob/groups/faction_permits.dm` (papers in `faction_papers.dm`). Tests:
`python3 tests/faction_permits/test_source.py`; native probe
`python3 tests/ecology_spawning/run_linux.py . tests/faction_permits/probe.dm`.

Second round, step 3 of the bureaucracy and currency plan. A faction may require permits on its
registered land (`docs/land-registry.md`). Both requirements are **off** unless the faction turns
them on.

## Requiring permits

Under **Faction Papers**, the papers power picks **Require permits on our land** and turns each
requirement on or off. Members hear the change, and the census shows what is required.

- **Building permit**: needed to build a structure, cover or floor on any of the faction's registered
  plots.
- **Trading licence**: needed to build a market stall or sales machine there. It takes the place of
  a building permit for a stall.

Members of the faction never need a permit, and neither does anyone carrying the plot's valid deed.
Off the faction's registered plots nothing is needed.

## Issuing

The papers power issues permits like other papers: to a person standing beside them, on a blank
sheet, good for 1 to 30 days or until revoked (0 days). A permit counts only for its holder, only
while carried in the hands or worn directly, and is revoked like any papers. Permits never open
border doors.

The check runs when the build starts and again when it finishes; the crafting menu never hides a
recipe for it.

## Saved state

The faction's papers record keeps `"require" = list("build", "trade")`; permits are rows of kind
`"build"` or `"trade"` in the same register.

## Substance rules

The faction leader can set each class of drug (opiates, stimulants, tobacco, cannabis, alcohol) to
allowed, licensed or banned on the faction's registered land, from Faction Papers. Everything is
allowed until a rule is set. The game only shows the rule:

- examining an item on that land says whether it is banned there or needs a **substance licence**;
- "Read the laws" in Faction Justice lists the rules after the written laws;
- police dogs on that land bark at what it bans. Off faction land they keep the old contraband list.

Arrest, trial, fines and confiscation use the faction's justice as usual. A substance licence is a
faction paper issued like a trading licence. The record keeps
`"substances" = list(class = "licensed" or "banned")`; `code/game/mob/groups/faction_substances.dm`
has the code.
