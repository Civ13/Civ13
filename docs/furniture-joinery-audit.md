# Early furniture recipe audit - 2026-10-28

This first batch depends on primitive woodworking #3382 at
`16e6c9ca8f0ca561fe39256ea185e92419115901`, itself based on master
`39c6861ccf3952fec2b8793bcbc70b0847d0f73c`. Its sawmill, piece, wedge,
mallet, crude-plank and flattening contracts are retained. No spawn kit or
respawn resource grant is introduced.

## Inventory and findings

`scripts/audit-crafting-recipes.py --output <file.json>` inventories all active
13-field material rows, category counts and furniture/storage candidates. The
first audit found 9,640 existing rows in 11 catalogs and 63 author categories;
545 existing rows select furniture, beds/chairs, tables/racks, bookcases,
closets/crates or filing cabinets. Counts include repeated map/faction rows,
not distinct inventions. Four new global joinery rows bring the total to 9,644.
`tests/furniture_joinery/legacy-furniture.json` freezes those 545 original rows
as checked-in regression inputs. Tests never depend on historical Git objects.
The same PR's subsequent reviewed batches add a paid wooden stool and a wooden
shelf material route. The current index records 9,646 active rows (six additions
over the initial inventory), including five explicit joinery rows. These limited
expansions do not establish historical review of every inventoried row.

The furniture subset and shared `stack.produce_recipe` path were reviewed for
material/secondary-input costs, title-driven tools and constructor behavior.
Most recipes abstract the whole construction into one material. **There is no
general nail or power-tool requirement to remove.** The actionable restriction
is processing: most wooden furniture needs finished planks, whereas the plain
table already accepts logs. The separate woodworking chain makes planks possible
without a metal axe; this batch adds an explicit hewn-frame option for furniture.

| Global family | Existing inputs and base wait | Current research node | Decision |
|---|---|---|---|
| Wooden table | 4 logs, 50 ds | Basic Furniture, era 0 | Preserve; add explicit pegged frame |
| Wooden chair | 4 planks, 50 ds | Basic Furniture, era 0 | Preserve; add hewn-log pegged frame |
| Wooden bed | 4 planks, 60 ds | Basic Furniture, era 0 | Preserve; add hewn-log pegged frame |
| Bookcase | 6 planks, 80 ds | Fine Furniture, era 2 | Retain; panel/shelf joinery needs its own design |
| Wood chest | 7 planks, 75 ds | Cooperage & Containers, era 1 | Retain; lid, hinges/locking and dismantling need joint audit |
| Wardrobe | 5 planks, 80 ds | Fine Furniture, era 2 | Retain; same hardware concern |
| Padded/wing chairs | 6 planks, 50 ds | Fine Furniture, era 2 | Retain; upholstery/frame bill of materials is a follow-on |
| Comfy chair/divan/sofa | Leather or cloth only | Basic/Fine Furniture | Retain; these conceal frames and padding, not just joinery |
| Iron/steel furniture | Metal only | Basic/Manufactured/Fine Furniture by output | Retain; wooden pegging does not replace a metal-frame recipe |
| Fancy/modern/poker tables, coatrack | Planks only | Fine Furniture/Fine Arts | Retain; do not backdate a style merely because its joints are old |

Era ordinals above come from actual research constructors, not the old numeric
thresholds or column 12. Column 12 is a **maximum** era. Existing factions must
complete their actual node; advancing the world era does not grant that node.
Map/faction overrides keep their current menus. The new rows are global only.

## Implemented routes

| Route | Paid inputs | Equipped tools | Base wait |
|---|---|---|---|
| Whittled wooden dowel set | 1 finished plank | Sharpened flint, or sharp supported knife harder than the plank | 120 ds |
| Hewn table with pegs | 4 logs + 1 dowel set | Chisel + hammer/mallet | 120 ds |
| Hewn chair with pegs | 4 logs + 1 dowel set | Chisel + hammer/mallet | 120 ds |
| Hewn bed with pegs | 4 logs + 2 dowel sets | Chisel + hammer/mallet | 180 ds |

Dowel sets use Basic Tools; furniture uses its existing Basic Furniture output
gate. All remain available through maximum era 8. Waits use existing crafting
and strength modifiers. A set is an abstract collection of pins for a small
frame, not a historically measured peg count. No free furniture or fasteners
appear. The ordinary routes remain cheaper/faster abstractions; this first batch
does not force every existing craft through a new component economy.

Tools can be in actual hands/equipment slots or loose on the ground at the
player's feet. Tool discovery inspects at most 32 movable atoms on that tile;
clear clutter or equip the tool if it is not found. The second ingredient stays in
the other hand. Storage is not searched. Retain the selected tools and component
across the wait; changed ownership, broken/deleted tools, lost sharpness or
hardness, exhausted stock, research loss, occupied output tiles and a crossed
save admission all reject before debit. A successful material-knife shaping
action costs 0.25 durability, using the reviewed woodworking tool predicate;
flint follows its existing convention. Assembly tools are reused without wear.
Source and peg costs are exact, with no Production-religion discount. The menu
and Atlas show the secondary ingredient and required tools; Help inherits the
same source-derived records. Batch multipliers are refused for these recipes.
Ordinary preset-size log/plank subtypes qualify only with the same actual wood
material. Joinery crafting XP is awarded after successful post-wait validation
and both debits; rejected work awards none. Other recipes retain their XP behavior.

The existing stone chisel represents cutting mortises and shaping sockets,
and the mallet drives the wooden pins. Dedicated augers, boring, glue and
geometry are abstracted. Existing bed/chair/table sprites and their ordinary
behavior are reused. This is not a reproduction of one archaeological object.

## Historical basis and limits

[Tegel et al., PLOS ONE (2012)](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0051374)
documents Early Neolithic timber well frames with mortise-and-tenon joints,
including perforated tenons keyed with wooden wedges. This supports sophisticated
pre-metal joining in the broad Stone Age tier, not evidence for these exact
furniture designs or identical tools in every early culture.

[Hatnefer's chair, ca. 1491-1473 BCE (Metropolitan Museum)](https://www.metmuseum.org/art/collection/search/543868)
attests mortise-and-tenon joints secured by pegs, resinous glue reinforcement
and a linen-cord seat. [British Museum chair EA2480](https://www.britishmuseum.org/collection/object/Y_EA2480)
also records mortises and tenons secured by dowels. These support pegged frame
joinery well before medieval times; they do not establish universal wooden
chairs, exact in-game quantities, or this game's plank/hewing tools in every
Stone Age culture. Their Bronze Age dates are not evidence for the first
invention date of all pegged furniture.

[British Museum stool EA46705](https://www.britishmuseum.org/collection/object/Y_EA46705)
records tenons/dowels and rush webbing, while [box EA5897](https://www.britishmuseum.org/collection/object/Y_EA5897)
records six wooden pieces secured by dowels. These suggest future woven-seat
and simple box routes, rather than permission to give every chest metal-free
hinges and locks. The table/bed recipes are engineering extrapolations of a
pegged wooden frame. Their precise design, all-wood surfaces, shared sprites,
tool list, availability and timing are explicit gameplay abstractions.

## Broader crafting audit index and next priorities

The generated JSON indexes every author category and catalog, including rows
outside furniture. This is an index for focused review, not a claim that all
bespoke crafting systems or outputs have been historically verified.

| Priority | Scope | What to establish before adding variants |
|---|---|---|
| 1 | Storage, furniture, bedsheets and textiles | Frame/padding/weaving inputs; simple lid versus hinges/locks; no refund exploit |
| 2 | Tools, weapon shafts and handles | Stone/bone/metal head routes, bindings, held-tool condition and exact handle consumption |
| 3 | Construction, roofs, floors and fortifications | Pegged/lapped/lashed joints where appropriate; structural and fire behavior |
| 4 | Pottery, healthcare and kitchen utensils | Forming/firing/container prerequisites and existing non-recipe acquisition |
| 5 | Economy/production stations and vehicle parts | Period-specific tools, power, fastening, research and processor yields |
| 6 | Clothing/armor, weapons, ammunition, electronics and chemistry | Separate source-backed bills of materials; avoid universal wood substitutions |

Map/faction duplicates should be reviewed as policy variants, not copied blindly.
The anvil, cooking, chemistry, workbench and attackby/processor systems need
their own inventories. No unrelated categories are changed in this batch.

## Verification scope

`tests/furniture_joinery/test_contract.py` checks original-row preservation,
shared data, source-derived admission controls and regenerated Atlas/Help.
`tests/crafting/furniture_joinery.dm` extends the existing isolated recipe fixture
with paid production, tool/stock changes during waits, missing inputs, cancellation,
research, occupied tiles, save crossing, final-slot cleanup and competing waits.
The fixture uses real crafting procedures with existing character/HUD adapters.
`scripts/check-recipes.py --compile-only` validates that fixture without starting
DreamDaemon. Compilation and offline checks do not establish full-game/client
interaction, initialized map reachability or real saved-world round trips.
