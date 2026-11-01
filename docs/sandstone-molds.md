# Carved sandstone casting molds

Hold or place an accessible sandstone stack, with a chisel and hammer or mallet
equipped or loose at your feet, then choose a sandstone mold from its molds menu.
The tools are reused. Each mold takes 120 base deciseconds to carve, adjusted by
the existing strength/crafting calculation. Costs in sandstone blocks are:

| Shape | Blocks | Research |
| --- | ---: | --- |
| Ingot | 3 | Bronze Working |
| Axehead | 3 | Stone Arms |
| Sword | 10 | Stone Arms |
| Knife | 2 | Stone Arms |
| Spearhead | 3 | Stone Arms |
| Pickaxe | 6 | Stone Arms |
| Shovel | 6 | Basic Toolmaking |
| Arrowhead | 2 | Stone Arms |

The result is ready for pouring without oven firing. Smelt/alloy in the existing
fired clay blacksmith pot or jug, pour into the mold, then use the filled mold on
an appropriate anvil. Mold capacities, metal acceptance, output recipes and
research prototypes follow the corresponding existing clay type. Molds remain
reusable after casting. This adds casting molds, not stone crucibles, pots, jugs
or key molds. All existing clay recipes, vessels, capacities and gates remain.

Sandstone is already produced by mining sandy underground tiles or underground
beneath desert areas. Availability and access are map dependent; no resources,
tools or research are granted. The existing eight-stone chisel and five-log hammer
are Basic Toolmaking recipes. Existing pickaxe/handle progression supplies mining.
The axehead variant is also a valid Bronze Working prototype through inheritance,
so the new route does not require Bronze Working to craft its own prototype.

Carving retains the exact source stack, site, selected tools and persistence
admission identity through the existing crafting wait. Cancellation, missing or
broken tools, changed material, insufficient stock, moved stock, revoked research
or a crossed save/load admission reject before payment/output. Only actual
sandstone is admitted; a preset sandstone stack with a replaced material cannot
pass. No nested storage search or automatic replacement tool is used. XP follows
successful payment. The action datum is local to the call and is never stored
on an atom. The historical clay type ancestry is retained for existing consumers;
a narrow oven guard prevents stone molds from being replaced or emptied by firing.

Existing metallurgy DMI states are reused with a source color matrix that converts
them to a sandstone palette. No DMI file or paid asset is added. The full-state
metal is tinted with the mold; this is a visual abstraction. Static sprite export
checks do not establish the appearance of engine color matrices.

## Historical scope

[Amgueddfa Cymru object 79.26H](https://museum.wales/collections/online/object/eb1f8bda-073d-35b2-ad0e-aa264a8b736d/Early-Bronze-Age-stone-mould/)
is an Early Bronze Age sandstone mold with several carved matrices. Its intended
products are uncertain, with one possibly intended for a flat triangular dagger.
[Dumfries Museum's Canonbie mold](https://www.futuremuseum.co.uk/collections/people/lives-in-key-periods/archaeology/the-bronze-age/domestic/stone-mirror-mould--canonbie)
is a sandstone slab with carved matrices for a chisel and possibly a mirror.
These support a carved sandstone casting path. They do not establish every
game shape/capacity or a universal date at which clay succeeded stone.
[National Museums Scotland's Blyth Hoard](https://www.nms.ac.uk/discover-catalogue/the-blyth-hoard)
includes surviving clay mold/core fragments, illustrating clay's metallurgy role.
The game retains its existing compatible metal list; this feature does not model
thermal shock, moisture, preheating, cooling, stone selection or mold wear.

## Verification boundary

`tests/stone_molds/test_source.py` checks current recipe/material/research
contracts, inherited casting classes/capacities/prototypes, carving admission and
commit ordering, oven preservation, Atlas/Help instructions, and causal omission
controls. These are offline source/model checks, not native gameplay.
`tests/crafting/stone_molds.dm` adds actual production crafting/payment and
late-rejection assertions to the existing isolated recipe fixture. Compilation
alone does not execute those assertions. The fixture assigns metal and empty
states directly; it does not exercise actual pouring or anvil casting. Oven
preservation retains the same mold and metal while ejecting it onto the oven turf.
Native/client, save/load and graphical
acceptance must be reported separately for the exact tested commit.

Player-facing changelog: Added reusable sandstone casting molds carved with a
chisel and hammer or mallet, alongside the existing fired clay molds.
