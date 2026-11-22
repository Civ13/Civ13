# Research Tree

Civ13's research system is a **tech tree**, not a point pool. Instead of feeding items into a desk to raise three abstract Industrial/Military/Health numbers, your faction builds **research benches**, assigns each one a specific invention to study, and watches it complete — either by passive study over time, by building a working prototype, or by learning it from another faction's research book.

This page describes the tech-tree mode. On persistent worlds, research works through books instead; see [Books and Scholars](Guide_to_Books_and_Scholars.md). Check the round's selected research mode first; [legacy modes](../gamemodes/Civilizations_and_Nomads.md#research) work differently. Unlocking a node still requires the recipe to exist in the active map's crafting catalog and your character to meet its skill requirements. In this mode, colored cable recipes and electronics are gated by **Electricity**; possessing a battery does not grant cable access. Laboratory benches and burners use **Apothecary**, while laboratory feedstock dispensers and centrifuges use **Pharmacology**. See [Chemistry](Guide_to_Chemistry.md) and [Power & Batteries](Guide_to_Power.md) for setup.

Completing a node unlocks every recipe gated behind it, faction-wide, permanently.

## Contents

- [The tree: layers and lines](#the-tree-layers-and-lines)
- [Eras and baseline research](#eras-and-baseline-research)
- [Research benches](#research-benches)
- [Faction roles: who can direct research](#faction-roles-who-can-direct-research)
- [How a node gets completed](#how-a-node-gets-completed)
- [Research trade goods: notes and books](#research-trade-goods-notes-and-books)
- [Bench tiers](#bench-tiers)
- [The resource forge: raising your bench cap](#the-resource-forge-raising-your-bench-cap)
- [Full node reference](#full-node-reference)

---

## The tree: layers and lines

The tree has three intersecting **layers** — Industrial, Military, and Health — each broken into several **functional lines**. Nodes ladder up within a line, but many also cross-reference nodes in *other* layers (e.g. Steel Blades needs Iron Smithing from the Metallurgy line, not just its own Melee line). That's deliberate: it's what makes this a tree instead of three independent ladders.

| Layer | Lines |
|---|---|
| **Industrial** | Toolmaking, Metallurgy, Construction, Production, Textiles, Furniture, Power, Vehicles, Infrastructure, Agriculture |
| **Military** | Melee, Archery, Firearms, Artillery, Armor |
| **Health** | Medicine, Surgery, Sanitation |

See the [full reference table](#full-node-reference) for node eras, study costs and prerequisites.

### What needs what

A subject only requires what you really need to build it: the same craft one step earlier, the material it is made of, or the power that drives it.

- **Tools, metals and power are the trunk.** Bronze Working, Iron Smithing, Steelmaking and Alloys, and Watermills, Steam Power, Electricity and the Combustion Engine are what most late subjects lean on.
- **Every other branch can be left alone.** Farming, health, clothing, building, culture, arms and vehicles each start from a subject with no prerequisites.
- **Some subjects are side steps.** Irrigation, Imperial Architecture, Classical Dress, Siege Engines and Mail & Plate unlock their own things, and nothing later needs them. Armour is taught by the armour subjects (Primitive Armor, Mail & Plate, Trench Warfare, Modern Armor), not by the blade and firearm subjects. A farmer can go from Basic Agriculture straight to Advanced Agriculture, then to Soil Science or Crop Breeding. Irrigation leads only to Hydroponics.
- **Civil subjects never need military ones.** Rocketry and Drones follow from flight. Military subjects need a civil one only where they are built from it, such as Steelmaking for Rifling or the Combustion Engine for tanks.

---

## Eras and baseline research

Every node has an **era tier** (0–9, from the Stone Age to the Digital Age, matching the map's ages). This is the key rule that makes the tree playable instead of a grind wall:

**Main-tree baseline research is granted up to a faction's founding era.** That baseline is frozen: another faction advancing the world does not automatically unlock later nodes for an established faction. Research beyond your baseline must be earned.

Factionless players receive Main-tree baseline nodes up to the current era. A new faction starts with the era baseline at its founding; loaded faction state and map setup still matter.

**Specialist trees**, including Agriculture and Tailoring, do not receive era-based automatic completion. For example, Modern does not grant Irrigation. Unlock its gateway, meet the bench tier and complete the node.

**Persistent worlds** don't use faction research. Knowledge lives in books there, the world starts in 5000 B.C. and moves on only when someone finishes a capstone. See [Books and Scholars](Guide_to_Books_and_Scholars.md).

Raised baselines and research tables are saved with the world, so they survive a restart.

---

## Research benches

A **research bench** is a craftable structure. Assign it one invention from the tree, and it will make progress on that invention — nothing else — until it's done, at which point you reassign it to the next thing.

- **Building one:** costs 8 planks in the default global recipe. Anyone can build one, in a faction or not.
- **Ownership:** a bench built by a faction member belongs to that faction. It is *not* shared infrastructure between factions. A bench built by someone without a faction belongs to nobody until a faction claims it, and it doesn't count toward any faction's cap.
- **Viewing vs. acting:** anyone can open a bench's interface to see the state of their faction's tree and what's currently being researched. Only the Leader, Research Director, or an appointed Researcher can *change* what a bench is working on, or produce trade goods from it.
- **Claiming a bench:** a faction under its own bench cap can claim a bench that belongs to nobody, or one whose faction has died out completely (no living members left). The claimed bench's old research assignment is cleared.

### How many benches can a faction have?

```
bench cap = (1 + current era) + forge bonus slots
```

The cap rises by **+1 automatically every time the map advances an era**, starting at 1 bench in the Stone Age. Beyond that, a faction can buy more slots at a [resource forge](#the-resource-forge-raising-your-bench-cap).

Trying to build (or claim) a bench while at your faction's cap will fail with a warning — build a forge and melt down some coin first.

---

## Faction roles: who can direct research

Three roles can change what a bench researches and produce research trade goods:

| Role | Appointed by | Notes |
|---|---|---|
| **Leader** | (elected/self-appointed via the existing faction system) | Always has full research authority. Can appoint and dismiss the Research Director and Researchers. |
| **Research Director** | The Leader, at a bench | One per faction. The Leader picks the title (defaults to "Research Director" but can be renamed to whatever fits your faction's flavor). Can appoint/dismiss Researchers. |
| **Researcher** | The Leader or the Research Director, at a bench | Any number of them. Rank-and-file staff trusted to redirect research and produce trade goods. |

All of these appointments happen through a bench's interface — approach any bench your faction owns and use it to appoint, dismiss, or rename these roles. Ordinary faction members can still *view* the tree and bench progress; they just can't redirect research or write trade goods.

---

## How a node gets completed

Every node completes one of three ways, depending on its **mode**:

### 1. Passive study (Analysis mode — most nodes)

The assigned bench ticks forward automatically, once every **10 seconds**, contributing 1 tick per bench per tick. Multiple benches assigned to the *same* node stack additively — two benches on Steelmaking means 2 ticks every 10 seconds toward it, not 1.

A bench must be at least the node's **minimum bench tier** (the era) before it can work on it at all — see [Bench tiers](#bench-tiers).

### 2. Build a prototype (Prototype mode — 11 key nodes)

Some inventions (Bronze Working, Iron Smithing, Gunpowder, Printing Press, Steam Power, Electricity, Nuclear Power, Mechanized Warfare, Powered Flight, Digital Computing, Digital Networks) need more than theory — they need a **working prototype**. These require **both** the full passive study **and** the matching prototype item fed to the bench (see the [reference table](#full-node-reference)) — it's an extra requirement, not a shortcut. Whichever you finish second is what completes the node: submit the prototype after study is done and it finishes at once; submit it early and the node completes the moment the ticks catch up.

[Research notes](#research-trade-goods-notes-and-books) still help on these techs, since they grant ticks toward the study half.

**These are the era-changing capstones.** The first time *any* faction completes one ahead of the current era, the **whole world advances into that era**, with a server-wide announcement. Two eras can be opened from either side: the **Imperial** era opens with Gunpowder *or* the Printing Press, and the **World War II** era opens with Mechanized Warfare *or* Powered Flight, so a peaceful people never has to study weapons to move the world on. Existing factions retain their founding Main-tree baseline; they must earn later nodes. New factions receive the Main-tree baseline of their founding era, while factionless players follow the current Main-tree baseline. Specialist trees do not gain automatic completion. Capstones have a **passive tick cost of 5× the listed base cost** (the tick numbers in the reference table below are the pre-multiplier base values).

### Studying samples (any Analysis/Prototype node)

While a bench is researching a node, you can feed it a **sample**: an existing example of something that node will unlock (reverse-engineering). Since you can't craft the locked item yet, samples have to be looted, traded, or found. Each distinct item type teaches something only once per assignment, and each grants a chunk of ticks. Only works on the bench's currently-selected subject.

### Research queue

A bench can hold a **queue** of nodes (add any not-current tech from its detail popup). As each subject completes, the bench automatically advances to the next still-valid node in the queue, so research staff don't have to re-assign after every finish. Queued nodes whose prerequisites aren't met yet are held until they become researchable. Note: benches only make passive progress while a Leader, Research Director, or Researcher of the faction is actually connected — you can't queue everything and log off to drag the server forward.

### 3. Learn from a book (Book mode — reserved, currently unused)

A mode exists for nodes that can *only* be learned by importing a research book from a faction that already has it — no passive ticking, no prototype shortcut. No current node uses this mode, but it's there for future content that should represent knowledge that can't be independently rediscovered.

---

## Research trade goods: notes and books

Once your faction has completed a node, your Research staff can **write it up** at the bench that researched it, producing an item another faction can use to shortcut the same research. This is a deliberate trade good — sell it, gift it, or use it as leverage in diplomacy.

| | **Research Notes** | **Research Book** |
|---|---|---|
| Write time | 6 seconds | 35 seconds |
| Effect on the buyer's matching node | Grants a tick boost worth **30% of the node's total cost** | **Completes the node outright**, instantly |
| Reusable? | Consumed on use | Consumed on use |

**Writing:** at a bench assigned to a node your faction has already completed, choose to write notes or a full book. Only Leader/Director/Researcher can do this.

**Using someone else's notes/book:** bring it to a bench assigned to the *matching* node (the subject must line up), and feed it to the bench like any other item. Prerequisites still apply — a book can't skip nodes your faction hasn't unlocked the prerequisites for.

Notes work on any tick-accumulating node — which today means every node except the (currently unused) Book-mode. A full book completes any node outright, including Prototype-mode ones, bypassing the need to ever find or build the prototype item.

---

## Bench tiers

A bench's tier is the **current global era**: Stone Age (era 0) benches are tier 0, Bronze Age (era 1) benches tier 1, and so on, up to tier 8. Higher-tier nodes need a bench of at least their tier before they can be worked at all.

You don't pay anything to raise it. When the world advances an era, every bench rises to the new tier on its own. So you can only ever be as advanced as the age you're in, and the node's prerequisites and other requirements still apply.

---

## The resource forge: raising your bench cap

A **resource forge** is a separate structure (one serves your whole faction, not tied to any single bench) that raises your faction's bench cap beyond the automatic per-era increase.

**Feed it copper, silver, or gold coins** — nothing else is accepted. Coins are valued in silver-equivalents:

| Coin | Silver-equivalent value |
|---|---|
| Copper | 0.1 |
| Silver | 1 |
| Gold | 4 |

Those values are for full-weight coins. A debased coin counts only for the metal in it (see [Money & Coins](Guide_to_Money.md#debased-coins)).

When you interact with the forge, you're prompted for how many coins to melt (so a full purse isn't accidentally vaporized in one click).

**Cost to grant the Nth bonus bench slot:**

```
silver needed = 300 x (N + 1)
```

The first bonus slot costs 300 silver-equivalent, the second costs 600, the third 900, and so on. Since a coin stack caps at 500, later slots are paid off cumulatively across multiple feedings — progress carries over between visits to the forge.

---

## Full node reference

**Legend:** *Era* = the node's era tier, used for Main-tree baseline eligibility under the rules above; specialist nodes must be earned. *Ticks* = base passive study cost; Prototype nodes require **5× this cost plus their prototype item**. *Min Tier* = lowest bench tier that can work this node. Era tier alone does not complete research or guarantee a recipe is available in the active catalog.

### Industrial layer

#### Toolmaking
| Node | Era | Ticks | Min Tier | Mode | Prerequisites |
|---|---|---|---|---|---|
| Basic Toolmaking | 0 | 60 | 0 | Analysis | - |
| Iron Tools | 2 | 130 | 1 | Analysis | Basic Toolmaking, Iron Smithing |
| Machined Tools | 4 | 200 | 3 | Analysis | Iron Tools, Steelmaking |
| Power Tools | 6 | 270 | 5 | Analysis | Machined Tools, Electricity |

#### Metallurgy
| Node | Era | Ticks | Min Tier | Mode | Prerequisites |
|---|---|---|---|---|---|
| Bronze Working | 1 | 142 | 0 | **Prototype** (cast axehead mold) | Basic Toolmaking |
| Iron Smithing | 2 | 195 | 1 | **Prototype** (ingot mold) | Bronze Working |
| Steelmaking | 4 | 200 | 3 | Analysis | Iron Smithing |
| Alloys | 6 | 270 | 5 | Analysis | Steelmaking |

#### Construction
| Node | Era | Ticks | Min Tier | Mode | Prerequisites |
|---|---|---|---|---|---|
| Primitive Construction | 0 | 60 | 0 | Analysis | - |
| Stone Masonry | 1 | 95 | 0 | Analysis | Primitive Construction |
| Brickmaking | 2 | 130 | 1 | Analysis | Stone Masonry |
| Imperial Architecture | 3 | 165 | 2 | Analysis | Brickmaking |
| Reinforced Concrete | 4 | 200 | 3 | Analysis | Brickmaking, Steelmaking |
| Modern Construction | 6 | 270 | 5 | Analysis | Reinforced Concrete |

#### Culture & Faith
| Node | Era | Ticks | Min Tier | Mode | Prerequisites |
|---|---|---|---|---|---|
| Ritual & Worship | 0 | 60 | 0 | Analysis | - |
| Regalia & Heraldry | 0 | 60 | 0 | Analysis | Weaving |
| Monuments & Statuary | 2 | 130 | 1 | Analysis | Stone Masonry, Ritual & Worship |
| Fine Arts & Leisure | 3 | 165 | 2 | Analysis | Ritual & Worship |

#### Production
| Node | Era | Ticks | Min Tier | Mode | Prerequisites |
|---|---|---|---|---|---|
| Pottery & Cookware | 0 | 60 | 0 | Analysis | - |
| Cooperage & Containers | 1 | 95 | 0 | Analysis | Basic Toolmaking |
| Resource Processing | 1 | 95 | 0 | Analysis | Basic Toolmaking |
| Trade & Coinage | 1 | 95 | 0 | Analysis | - |
| Workshops | 2 | 130 | 1 | Analysis | Bronze Working |
| Glassworking | 2 | 130 | 1 | Analysis | Pottery & Cookware |
| Papermaking | 2 | 130 | 1 | Analysis | - |
| Printing Press | 3 | 165 | 2 | **Prototype** (envelope or wax seal stamp) | Papermaking |
| Optics & Instruments | 3 | 165 | 2 | Analysis | Glassworking |
| Factories | 4 | 200 | 3 | Analysis | Workshops, Steam Power |
| Assembly Line | 5 | 235 | 4 | Analysis | Factories |
| Automation | 7 | 305 | 6 | Analysis | Assembly Line, Electricity |
| Digital Computing | 8 | 510 | 7 | **Prototype** (Cold War-era camera) | Automation, Electricity |
| Digital Networks | 9 | 560 | 8 | **Prototype** (mobile phone) | Digital Computing |
| Consumer Electronics | 9 | 420 | 8 | Analysis | Digital Networks |
| 3D Printing | 9 | 420 | 8 | Analysis | Digital Computing |

#### Textiles (gateway)
| Node | Era | Ticks | Min Tier | Mode | Prerequisites |
|---|---|---|---|---|---|
| Weaving | 0 | 60 | 0 | Analysis | - |
| Furriery | 1 | 95 | 0 | Analysis | Weaving |

**Weaving** (basic) stays on the Main tree as the textiles gateway — it covers basic weaving and the basic tailoring tools (e.g. the loom). **Furriery** (fur coats from any pelt, white pelts included, plus fur hats and fur caps) is also on the Main tree, so it comes with the era like other Main-tree nodes and players without a faction can make warm clothes. The advanced tailoring nodes are in the standalone **Tailoring** tree (see below).

#### Furniture
| Node | Era | Ticks | Min Tier | Mode | Prerequisites |
|---|---|---|---|---|---|
| Basic Furniture | 0 | 60 | 0 | Analysis | - |
| Fine Furniture | 2 | 130 | 1 | Analysis | Basic Furniture |
| Manufactured Furniture | 4 | 200 | 3 | Analysis | Fine Furniture |

#### Power
| Node | Era | Ticks | Min Tier | Mode | Prerequisites |
|---|---|---|---|---|---|
| Watermills | 3 | 165 | 2 | Analysis | Resource Processing |
| Steam Power | 4 | 300 | 3 | **Prototype** (machined handle) | Watermills, Iron Smithing |
| Electricity | 5 | 352 | 4 | **Prototype** (cable coil) | Steam Power, Galvanic Cells |
| Combustion Engine | 5 | 235 | 4 | Analysis | Steam Power, Steelmaking |
| Nuclear Power | 7 | 458 | 6 | **Prototype** (geiger counter) | Electricity, Alloys |
| Hydraulic Fracturing | 8 | 400 | 7 | Analysis | Combustion Engine, Electricity |

Electricity unlocks the powered soil sifter and river concentrator. Hydraulic Fracturing unlocks the finite petroleum rig; see [Resource Extraction](Guide_to_Resource_Extraction.md) for input and power requirements. Automobiles and Electricity are both needed to use the [automobile workshop](Guide_to_Crafting.md#automobile-workshop). Lighter-than-Air Flight unlocks the basic [wooden airship kit](Guide_to_Aircraft.md#crewed-airships) before Powered Flight, which unlocks the aircraft hangar and runway. Submarines unlocks the submarine pen and the parts to build a submarine by hand; see [Submarines](Guide_to_Boats.md#submarines). Naval Aviation unlocks the shipyard office that lays down a carrier; see [Aircraft Carriers](Guide_to_Aircraft_Carriers.md).

#### Vehicles
| Node | Era | Ticks | Min Tier | Mode | Prerequisites |
|---|---|---|---|---|---|
| Carts | 1 | 95 | 0 | Analysis | - |
| Oared Ships | 1 | 95 | 0 | Analysis | Carts |
| Wagons & Ships | 3 | 165 | 2 | Analysis | Carts |
| Rail & Steam | 4 | 200 | 3 | Analysis | Wagons & Ships, Steam Power |
| Automobiles | 5 | 235 | 4 | Analysis | Wagons & Ships, Combustion Engine |
| Lighter-than-Air Flight | 5 | 235 | 4 | Analysis | Wagons & Ships, Utilities |
| Powered Flight | 6 | 270 | 5 | **Prototype** (small fuel tank) | Combustion Engine |
| Submarines | 6 | 270 | 5 | Analysis | Wagons & Ships, Combustion Engine, Electricity |
| Aviation & Rocketry | 7 | 305 | 6 | Analysis | Powered Flight, Alloys |
| Naval Aviation | 7 | 305 | 6 | Analysis | Powered Flight, Wagons & Ships |

#### Infrastructure
| Node | Era | Ticks | Min Tier | Mode | Prerequisites |
|---|---|---|---|---|---|
| Paved Infrastructure | 3 | 165 | 2 | Analysis | Stone Masonry |
| Utilities | 5 | 235 | 4 | Analysis | Electricity |

#### Agriculture (gateway)
| Node | Era | Ticks | Min Tier | Mode | Prerequisites |
|---|---|---|---|---|---|
| Basic Agriculture | 1 | 95 | 0 | Analysis | - |

**Basic Agriculture** is the Bronze Age gateway for farming, and lives in the **Main** tree: completing it unlocks the basic farming tools (plough, iron plough, planting trowel, pitchfork, shears, berries gatherer, produce basket, seed collector) *and* opens the standalone **Agriculture** tree (see below).

The bench interface presents research as switchable **tabs** — the Main tree first, then any specialized trees, each its own standalone tab reachable once its Main-tree gateway is researched.

### Specialized tree: Tailoring

The Tailoring tree contains advanced clothing and armour research, split into two layers: **Textiles** and **Armour**. Its Main-tree gateways are Weaving and Primitive Armor.

**Textiles** (gateway: Weaving)

| Node | Era | Ticks | Min Tier | Mode | Prerequisites |
|---|---|---|---|---|---|
| Classical Dress | 1 | 95 | 0 | Analysis | Weaving |
| Tailoring | 2 | 130 | 1 | Analysis | Weaving |
| Fine Garments | 3 | 165 | 2 | Analysis | Tailoring |
| Haberdashery | 3 | 165 | 2 | Analysis | Tailoring |
| Textile Mills | 4 | 200 | 3 | Analysis | Tailoring, Steam Power |
| Ready-Made Clothing | 5 | 235 | 4 | Analysis | Textile Mills |
| Synthetic Fabrics | 7 | 305 | 6 | Analysis | Textile Mills, Combustion Engine |

**Armour** (gateway: Primitive Armor)

| Node | Era | Ticks | Min Tier | Mode | Prerequisites |
|---|---|---|---|---|---|
| Mail & Plate | 2 | 130 | 1 | Analysis | Primitive Armor, Iron Smithing |
| Trench Warfare | 5 | 235 | 4 | Analysis | Primitive Armor, Field Defenses, Steelmaking |
| Modern Armor | 7 | 305 | 6 | Analysis | Trench Warfare, Alloys |

### Specialized tree: Agriculture

Its own standalone tab, reachable once Basic Agriculture (in the Main tree) is researched.

| Node | Era | Ticks | Min Tier | Mode | Prerequisites |
|---|---|---|---|---|---|
| Irrigation | 2 | 165 | 1 | Analysis | Basic Agriculture |
| Advanced Agriculture | 4 | 235 | 3 | Analysis | Basic Agriculture |

**Irrigation** unlocks the shovel's "dig an irrigation channel" action.

### Military layer

#### Melee
| Node | Era | Ticks | Min Tier | Mode | Prerequisites |
|---|---|---|---|---|---|
| Stone Arms | 0 | 60 | 0 | Analysis | - |
| Bronze Arms & Armor | 1 | 95 | 0 | Analysis | Stone Arms, Bronze Working |
| Steel Blades | 2 | 130 | 1 | Analysis | Bronze Arms & Armor, Iron Smithing |

#### Archery
| Node | Era | Ticks | Min Tier | Mode | Prerequisites |
|---|---|---|---|---|---|
| Archery | 0 | 60 | 0 | Analysis | - |
| Crossbows | 2 | 130 | 1 | Analysis | Archery |

#### Order & Defense
| Node | Era | Ticks | Min Tier | Mode | Prerequisites |
|---|---|---|---|---|---|
| Law & Order | 1 | 95 | 0 | Analysis | - |
| Field Defenses | 0 | 60 | 0 | Analysis | - |
| Fortifications | 3 | 165 | 2 | Analysis | Field Defenses, Stone Masonry |

#### Firearms
| Node | Era | Ticks | Min Tier | Mode | Prerequisites |
|---|---|---|---|---|---|
| Gunpowder | 3 | 248 | 2 | **Prototype** (pouch of gunpowder) | Iron Smithing |
| Gunsmithing | 3 | 200 | 2 | Analysis | Gunpowder |
| Rifling | 4 | 200 | 3 | Analysis | Gunpowder, Steelmaking |
| Cartridge Firearms | 5 | 235 | 4 | Analysis | Rifling |
| Self-Loading Firearms | 6 | 270 | 5 | Analysis | Cartridge Firearms |
| Automatic Weapons | 7 | 305 | 6 | Analysis | Self-Loading Firearms |

*Field Defenses gates the shovel's "dig a trench" action in tech-tree mode. Gunsmithing is a separate firearm research node.*

#### Artillery
| Node | Era | Ticks | Min Tier | Mode | Prerequisites |
|---|---|---|---|---|---|
| Siege Engines | 2 | 130 | 1 | Analysis | Primitive Construction |
| Cannon | 3 | 165 | 2 | Analysis | Gunpowder |
| Field Artillery | 4 | 200 | 3 | Analysis | Cannon, Steelmaking |
| Mechanized Warfare | 6 | 405 | 5 | **Prototype** (tank shell casing) | Field Artillery, Combustion Engine, Steelmaking |
| Missiles | 7 | 305 | 6 | Analysis | Aviation & Rocketry, Gunpowder |
| Drones | 9 | 450 | 8 | Analysis | Consumer Electronics, Powered Flight |

#### Armor (gateway)
| Node | Era | Ticks | Min Tier | Mode | Prerequisites |
|---|---|---|---|---|---|
| Primitive Armor | 0 | 60 | 0 | Analysis | - |

**Primitive Armor** stays on the Main tree as the armour gateway. Advanced armour nodes are in the standalone **Tailoring** tree above.

### Health layer

#### Medicine
| Node | Era | Ticks | Min Tier | Mode | Prerequisites |
|---|---|---|---|---|---|
| Herbalism | 0 | 60 | 0 | Analysis | - |
| Apothecary | 2 | 130 | 1 | Analysis | Herbalism |
| Pharmacology | 5 | 235 | 4 | Analysis | Apothecary |
| Modern Medicine | 7 | 305 | 6 | Analysis | Pharmacology |

#### Surgery
| Node | Era | Ticks | Min Tier | Mode | Prerequisites |
|---|---|---|---|---|---|
| Field Surgery | 1 | 95 | 0 | Analysis | Herbalism |
| Surgical Theory | 3 | 165 | 2 | Analysis | Field Surgery, Papermaking |
| Anesthetic Surgery | 5 | 235 | 4 | Analysis | Surgical Theory, Apothecary |

#### Sanitation
| Node | Era | Ticks | Min Tier | Mode | Prerequisites |
|---|---|---|---|---|---|
| Hygiene | 1 | 95 | 0 | Analysis | - |
| Sanitation | 3 | 165 | 2 | Analysis | Hygiene |
| Germ Theory | 5 | 235 | 4 | Analysis | Sanitation |
| Public Health | 7 | 305 | 6 | Analysis | Germ Theory |

---

*This system replaces the old flat Industrial/Military/Health point-pool research. Recipes not yet migrated into the tree still use the legacy threshold gate as a fallback — over time, more of the crafting catalogue will be tied to specific nodes above.*
