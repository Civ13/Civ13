# Flintlock assembly

In ages 3 and 4, with Gunsmithing unlocked, craft a pistol butt (1 softwood,
120 ticks) or musket stock (3 softwood, 240 ticks) from the plank Tools menu.
Use iron on an anvil and choose **flintlock parts** for a pistol barrel
(20 iron) or musket barrel (30 iron). Use steel on a steel anvil for a
flintlock mechanism (2 steel). Existing blacksmith skill/job restrictions apply.

Gather flint from rocks with grab intent, then strike a rock with it until it
becomes sharpened. Use that sharpened flint on a mechanism (20 ticks).
Use the matching barrel on its stock, then the loaded mechanism on the
barreled stock (20 ticks per pistol step, 30 per musket step). Hold the input
in your active hand; the target must be held or on adjacent ground.
Movement, losing an input, incapacitation, or losing the era/research gate
cancels consumption. Shared parts cannot be assembled twice concurrently.

This produces the existing flintlock pistol or `/flintlock/musket`, preserving
their stats, ammunition, firing and sprites. Existing crude musket, musket,
musketoon, blunderbuss and pistol crafting routes remain available. Assembly
adds steel, wood and flint to the existing pistol/musket iron costs; it is
an optional craft route, not an economy discount. Traded parts still require
Gunsmithing and age 3 or 4 to assemble. Partial assemblies persist; transient
operation reservations do not.

## Source and attribution

Adapted from [New-Civ13/Civ13 PR26](https://github.com/New-Civ13/Civ13/pull/26),
head `7750eaebd09be721a9d9816acd9ed8be856e8f89`, base
`907783f141c588f4fe8f740b60732eabba38458e`. Original coder: Isaku4904.
Parts sprites: mohamed/mm2hn (`@not_an_egyptian_spy`, the PR's spriter credit).
The human requester reports permission from Isaku to reuse the feature.
Separate permission from the credited spriter was not independently verified.
Both repositories carry GNU AGPL v3; retain that license and these credits.

Only `flintlocks.dmi` is imported (upstream Git blob
`d8b2c1775a028ad4e196a24fa19d1cb80cdae5f5`). The existing `ancient.dmi`
is retained. The upstream rock patch, forging schema, weapon recipe removals,
base-musket output and assembly implementation defects are not imported.

## Verification

`tests/blackpowder/run.ps1 -ByondBin <516.1681-bin>` runs production sources
with normal world/global startup disabled, temporary files and bounded processes.
It checks assembly, rejection, cancellation, shared reservations, material/era/
research menus and the production save/load routines. Actor startup and selected
wait/inventory effects are explicit adapters; genuine do_after cancellation is
also exercised. It does not prove production behavior or graphical acceptance.
Run `scripts/check-recipes.py` for the compiled catalog and full game compilation.

The probe also accepts `-NegativeControl`: an isolated temporary mutation removes
the completion-time compatibility check, and the test must catch the missing flint.
The actual imported sprite cells are shown in [this preview](images/flintlock-parts.png).
