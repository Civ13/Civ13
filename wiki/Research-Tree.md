# Research Tree

Civ13's research system is a **tech tree**, not a point pool. Instead of feeding items into a desk to raise three abstract Industrial/Military/Health numbers, your faction builds **research benches**, assigns each one a specific invention to study, and watches it complete - either by passive study over time, by building a working prototype, or by learning it from another faction's research book.

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

The tree has three intersecting **layers** - Industrial, Military, and Health - each broken into several **functional lines**. Nodes ladder up within a line, but many also cross-reference nodes in *other* layers (e.g. Steel Blades needs Iron Smithing from the Metallurgy line, not just its own Melee line). That's deliberate: it's what makes this a tree instead of three independent ladders.

| Layer | Lines |
|---|---|
| **Industrial** | Toolmaking, Metallurgy, Construction, Production, Textiles, Furniture, Power, Vehicles, Infrastructure, Agriculture |
| **Military** | Melee, Archery, Firearms, Artillery, Armor |
| **Health** | Medicine, Surgery, Sanitation |

There are **80 nodes** in total. See the [full reference table](#full-node-reference) at the bottom of this page for every node, its era, its tick cost, and its prerequisites.

---

## Eras and baseline research

Every node has an **era tier** (0–8, matching the map's ages). This is the key rule that makes the tree playable instead of a grind wall:

> **Any node whose era tier is at or below the map's current age is automatically granted to everyone - every faction, and factionless players too.**

You never re-research the Stone Age once the world has moved into the Bronze Age. Your bench time only ever goes toward the **frontier**: nodes *ahead* of the current era. As the world advances, yesterday's frontier becomes today's freebie.

This also means a brand-new faction (or someone who just abandoned one) isn't starting from zero - they get every baseline node the rest of the world already has for free.

---

## Research benches

A **research bench** is a craftable structure. Assign it one invention from the tree, and it will make progress on that invention - nothing else - until it's done, at which point you reassign it to the next thing.

- **Building one:** costs 8 soft wood, same recipe tier as a legacy research desk. You must belong to a faction to build one.
- **Ownership:** a bench belongs to whichever faction built it. It is *not* shared infrastructure between factions.
- **Viewing vs. acting:** anyone can open a bench's interface to see the state of their faction's tree and what's currently being researched. Only the Leader, Research Director, or an appointed Researcher can *change* what a bench is working on, or produce trade goods from it.
- **Reclaiming an abandoned bench:** if a faction dies out completely (no living members left), any other faction under its own bench cap can claim one of its benches. The claimed bench's old research assignment is cleared.

### How many benches can a faction have?

```
bench cap = (1 + current era) + forge bonus slots
```

The cap rises by **+1 automatically every time the map advances an era**, starting at 1 bench in the Stone Age. Beyond that, a faction can buy more slots at a [resource forge](#the-resource-forge-raising-your-bench-cap).

Trying to build (or claim) a bench while at your faction's cap will fail with a warning - build a forge and melt down some coin first.

---

## Faction roles: who can direct research

Three roles can change what a bench researches and produce research trade goods:

| Role | Appointed by | Notes |
|---|---|---|
| **Leader** | (elected/self-appointed via the existing faction system) | Always has full research authority. Can appoint and dismiss the Research Director and Researchers. |
| **Research Director** | The Leader, at a bench | One per faction. The Leader picks the title (defaults to "Research Director" but can be renamed to whatever fits your faction's flavor). Can appoint/dismiss Researchers. |
| **Researcher** | The Leader or the Research Director, at a bench | Any number of them. Rank-and-file staff trusted to redirect research and produce trade goods. |

All of these appointments happen through a bench's interface - approach any bench your faction owns and use it to appoint, dismiss, or rename these roles. Ordinary faction members can still *view* the tree and bench progress; they just can't redirect research or write trade goods.

---

## How a node gets completed

Every node completes one of three ways, depending on its **mode**:

### 1. Passive study (Analysis mode - most nodes)

The assigned bench ticks forward automatically, once every **10 seconds**, contributing 1 tick per bench per tick. Multiple benches assigned to the *same* node stack additively - two benches on Steelmaking means 2 ticks every 10 seconds toward it, not 1.

A bench must be tier-upgraded to at least the node's **minimum bench tier** before it can work on it at all - see [Bench tiers](#bench-tiers).

### 2. Build a prototype (Prototype mode - 8 key nodes)

Some inventions (Bronze Working, Iron Smithing, Gunpowder, Steam Power, Electricity, Nuclear Power, Mechanized Warfare, Digital Computing) need more than theory - they need a **working prototype**. These require **both** the full passive study **and** the matching prototype item fed to the bench (see the [reference table](#full-node-reference)) - it's an extra requirement, not a shortcut. Whichever you finish second is what completes the node: submit the prototype after study is done and it finishes at once; submit it early and the node completes the moment the ticks catch up.

[Research notes](#research-trade-goods-notes-and-books) still help on these techs, since they grant ticks toward the study half.

**These are the era-changing capstones.** The first time *any* faction completes one, the **whole world advances into that era** - announced server-wide (*"The discovery of [node] by [faction] sends the world into the [era]"*) - and every faction gets that era's baseline techs for free. Because that's a momentous, everyone-affecting event, their **passive tick cost is 5× a normal node's** (the tick numbers in the reference table below are the pre-multiplier base values).

### Studying samples (any Analysis/Prototype node)

While a bench is researching a node, you can feed it a **sample**: an existing example of something that node will unlock (reverse-engineering). Since you can't craft the locked item yet, samples have to be looted, traded, or found. Each distinct item type teaches something only once per assignment, and each grants a chunk of ticks. Only works on the bench's currently-selected subject.

### Research queue

A bench can hold a **queue** of nodes (add any not-current tech from its detail popup). As each subject completes, the bench automatically advances to the next still-valid node in the queue, so research staff don't have to re-assign after every finish. Queued nodes whose prerequisites aren't met yet are held until they become researchable. Note: benches only make passive progress while a Leader, Research Director, or Researcher of the faction is actually connected - you can't queue everything and log off to drag the server forward.

### 3. Learn from a book (Book mode - reserved, currently unused)

A mode exists for nodes that can *only* be learned by importing a research book from a faction that already has it - no passive ticking, no prototype shortcut. No current node uses this mode, but it's there for future content that should represent knowledge that can't be independently rediscovered.

---

## Research trade goods: notes and books

Once your faction has completed a node, your Research staff can **write it up** at the bench that researched it, producing an item another faction can use to shortcut the same research. This is a deliberate trade good - sell it, gift it, or use it as leverage in diplomacy.

| | **Research Notes** | **Research Book** |
|---|---|---|
| Write time | 6 seconds | 35 seconds |
| Effect on the buyer's matching node | Grants a tick boost worth **30% of the node's total cost** | **Completes the node outright**, instantly |
| Reusable? | Consumed on use | Consumed on use |

**Writing:** at a bench assigned to a node your faction has already completed, choose to write notes or a full book. Only Leader/Director/Researcher can do this.

**Using someone else's notes/book:** bring it to a bench assigned to the *matching* node (the subject must line up), and feed it to the bench like any other item. Prerequisites still apply - a book can't skip nodes your faction hasn't unlocked the prerequisites for.

Notes work on any tick-accumulating node - which today means every node except the (currently unused) Book-mode. A full book completes any node outright, including Prototype-mode ones, bypassing the need to ever find or build the prototype item.

---

## Bench tiers

A bench starts at **tier 0** and can be upgraded up to **tier 7**. Higher-tier nodes require a correspondingly upgraded bench before they can be worked at all (an untiered bench simply can't be assigned a high-tier invention).

**Era cap:** a bench can never be upgraded above the **current global era** - Stone Age (era 0) caps benches at tier 0, Bronze Age (era 1) at tier 1, and so on, up to the absolute tier-7 ceiling. As the world advances an era, every bench's upgrade cap rises with it. So you can only ever be as advanced as the age you're in.

**Upgrading:** feed the bench copper, silver, or gold **coins** - their value contributes toward the next tier. The cost escalates:

```
value needed for tier T -> T+1 = 80 x (T + 1)
```

So tier 0→1 costs 80 value, tier 1→2 costs 160, tier 6→7 costs 560, and so on. Progress accumulates across multiple items fed in - you don't need one single expensive item.

---

## The resource forge: raising your bench cap

A **resource forge** is a separate structure (one serves your whole faction, not tied to any single bench) that raises your faction's bench cap beyond the automatic per-era increase.

**Feed it copper, silver, or gold coins** - nothing else is accepted. Coins are valued in silver-equivalents:

| Coin | Silver-equivalent value |
|---|---|
| Copper | 0.1 |
| Silver | 1 |
| Gold | 4 |

When you interact with the forge, you're prompted for how many coins to melt (so a full purse isn't accidentally vaporized in one click).

**Cost to grant the Nth bonus bench slot:**

```
silver needed = 300 x (N + 1)
```

The first bonus slot costs 300 silver-equivalent, the second costs 600, the third 900, and so on. Since a coin stack caps at 500, later slots are paid off cumulatively across multiple feedings - progress carries over between visits to the forge.

---

## Full node reference

**Legend:** *Era* = the age at which this node becomes free baseline research for everyone. *Ticks* = total cost for passive study (irrelevant for Prototype nodes, which can also complete instantly). *Min Tier* = lowest bench tier that can work this node.

### Industrial layer

#### Toolmaking
| Node | Era | Ticks | Min Tier | Mode | Prerequisites |
|---|---|---|---|---|---|
| Basic Toolmaking | 0 | 60 | 0 | Analysis | - |
| Iron Tools | 2 | 130 | 1 | Analysis | Basic Toolmaking |
| Machined Tools | 4 | 200 | 3 | Analysis | Iron Tools, Steelmaking |
| Power Tools | 6 | 270 | 5 | Analysis | Machined Tools, Electricity |

#### Metallurgy
| Node | Era | Ticks | Min Tier | Mode | Prerequisites |
|---|---|---|---|---|---|
| Bronze Working | 1 | 142 | 0 | **Prototype** (cast axehead mold) | - |
| Iron Smithing | 2 | 195 | 1 | **Prototype** (ingot mold) | Bronze Working |
| Steelmaking | 4 | 200 | 3 | Analysis | Iron Smithing |
| Alloys | 6 | 270 | 5 | Analysis | Steelmaking |

#### Construction
| Node | Era | Ticks | Min Tier | Mode | Prerequisites |
|---|---|---|---|---|---|
| Stone Masonry | 1 | 95 | 0 | Analysis | - |
| Medieval Construction | 2 | 130 | 1 | Analysis | Stone Masonry |
| Imperial Architecture | 3 | 165 | 2 | Analysis | Medieval Construction |
| Reinforced Concrete | 4 | 200 | 3 | Analysis | Imperial Architecture, Steelmaking |
| Modern Construction | 6 | 270 | 5 | Analysis | Reinforced Concrete |

#### Production
| Node | Era | Ticks | Min Tier | Mode | Prerequisites |
|---|---|---|---|---|---|
| Pottery & Storage | 0 | 60 | 0 | Analysis | - |
| Workshops | 2 | 130 | 1 | Analysis | Pottery & Storage |
| Printing & Currency | 3 | 165 | 2 | Analysis | Workshops |
| Factories | 4 | 200 | 3 | Analysis | Printing & Currency, Steam Power |
| Assembly Line | 5 | 235 | 4 | Analysis | Factories |
| Automation | 7 | 305 | 6 | Analysis | Assembly Line, Electricity |
| Digital Computing | 8 | 510 | 7 | **Prototype** (Cold War-era camera) | Automation, Electricity |

#### Textiles (gateway)
| Node | Era | Ticks | Min Tier | Mode | Prerequisites |
|---|---|---|---|---|---|
| Weaving | 0 | 60 | 0 | Analysis | - |

**Weaving** (basic) stays on the Main tree as the textiles gateway - it covers basic weaving and the basic tailoring tools (e.g. the loom). The advanced tailoring nodes moved to the standalone **Tailoring** tree (see below).

#### Furniture
| Node | Era | Ticks | Min Tier | Mode | Prerequisites |
|---|---|---|---|---|---|
| Basic Furniture | 0 | 60 | 0 | Analysis | - |
| Fine Furniture | 2 | 130 | 1 | Analysis | Basic Furniture |
| Manufactured Furniture | 4 | 200 | 3 | Analysis | Fine Furniture |
| Modern Furnishings | 6 | 270 | 5 | Analysis | Manufactured Furniture |

#### Power
| Node | Era | Ticks | Min Tier | Mode | Prerequisites |
|---|---|---|---|---|---|
| Watermills | 2 | 130 | 1 | Analysis | - |
| Steam Power | 4 | 300 | 3 | **Prototype** (machined handle) | Watermills |
| Electricity | 5 | 352 | 4 | **Prototype** (cable coil) | Steam Power |
| Combustion Engine | 5 | 235 | 4 | Analysis | Steam Power, Steelmaking |
| Nuclear Power | 7 | 458 | 6 | **Prototype** (geiger counter) | Combustion Engine |

#### Vehicles
| Node | Era | Ticks | Min Tier | Mode | Prerequisites |
|---|---|---|---|---|---|
| Carts | 1 | 95 | 0 | Analysis | - |
| Wagons & Ships | 3 | 165 | 2 | Analysis | Carts |
| Rail & Steam | 4 | 200 | 3 | Analysis | Wagons & Ships, Steam Power |
| Automobiles | 5 | 235 | 4 | Analysis | Rail & Steam, Combustion Engine |
| Aviation & Rocketry | 7 | 305 | 6 | Analysis | Automobiles, Combustion Engine, Alloys |

#### Infrastructure
| Node | Era | Ticks | Min Tier | Mode | Prerequisites |
|---|---|---|---|---|---|
| Roads | 1 | 95 | 0 | Analysis | - |
| Paved Infrastructure | 3 | 165 | 2 | Analysis | Roads |
| Utilities | 5 | 235 | 4 | Analysis | Paved Infrastructure, Electricity |

#### Agriculture (gateway)
| Node | Era | Ticks | Min Tier | Mode | Prerequisites |
|---|---|---|---|---|---|
| Basic Agriculture | 1 | 95 | 0 | Analysis | - |

**Basic Agriculture** is the Bronze Age gateway for farming, and lives in the **Main** tree: completing it unlocks the basic farming tools (plough, iron plough, planting trowel, pitchfork, shears, berries gatherer, produce basket, seed collector) *and* opens the standalone **Agriculture** tree (see below).

The bench interface presents research as switchable **tabs** - the Main tree first, then any specialized trees, each its own standalone tab reachable once its Main-tree gateway is researched.

### Specialized tree: Tailoring

*Placeholder - carried over wholesale from the old Textiles and Armor lines and due a proper rework later.* Everything past the two basic gateways (Weaving and Padded Armor, which stay on Main) lives here, split into two layers: **Textiles** and **Armour**. All the recipes formerly gated on these nodes come with them unchanged.

**Textiles** (gateway: Weaving)

| Node | Era | Ticks | Min Tier | Mode | Prerequisites |
|---|---|---|---|---|---|
| Tailoring | 1 | 95 | 0 | Analysis | Weaving |
| Fine Garments | 3 | 165 | 2 | Analysis | Tailoring |
| Textile Mills | 4 | 200 | 3 | Analysis | Fine Garments, Steam Power |
| Synthetic Fabrics | 7 | 305 | 6 | Analysis | Textile Mills |

**Armour** (gateway: Padded Armor)

| Node | Era | Ticks | Min Tier | Mode | Prerequisites |
|---|---|---|---|---|---|
| Mail & Plate | 2 | 130 | 1 | Analysis | Padded Armor |
| Fortifications | 3 | 165 | 2 | Analysis | Mail & Plate, Imperial Architecture |
| Trench Warfare | 5 | 235 | 4 | Analysis | Fortifications |
| Modern Armor | 7 | 305 | 6 | Analysis | Trench Warfare, Alloys |

### Specialized tree: Agriculture

Its own standalone tab, reachable once Basic Agriculture (in the Main tree) is researched.

| Node | Era | Ticks | Min Tier | Mode | Prerequisites |
|---|---|---|---|---|---|
| Irrigation | 2 | 165 | 1 | Analysis | Basic Agriculture |
| Advanced Agriculture | 4 | 235 | 3 | Analysis | Irrigation |

**Irrigation** unlocks the shovel's "dig an irrigation channel" action.

### Military layer

#### Melee
| Node | Era | Ticks | Min Tier | Mode | Prerequisites |
|---|---|---|---|---|---|
| Stone Arms | 0 | 60 | 0 | Analysis | - |
| Bronze Weapons | 1 | 95 | 0 | Analysis | Stone Arms |
| Steel Blades | 2 | 130 | 1 | Analysis | Bronze Weapons, Iron Smithing |
| Bayonets | 3 | 165 | 2 | Analysis | Steel Blades |

#### Archery
| Node | Era | Ticks | Min Tier | Mode | Prerequisites |
|---|---|---|---|---|---|
| Archery | 0 | 60 | 0 | Analysis | - |
| Crossbows | 2 | 130 | 1 | Analysis | Archery |

#### Firearms
| Node | Era | Ticks | Min Tier | Mode | Prerequisites |
|---|---|---|---|---|---|
| Gunpowder | 3 | 248 | 2 | **Prototype** (pouch of gunpowder) | Iron Smithing |
| Gunsmithing | 3 | 200 | 2 | Analysis | Gunpowder |
| Rifling | 4 | 200 | 3 | Analysis | Gunpowder, Steelmaking |
| Cartridge Ammunition | 5 | 235 | 4 | Analysis | Rifling |
| Self-Loading Firearms | 6 | 270 | 5 | Analysis | Cartridge Ammunition |
| Automatic Weapons | 7 | 305 | 6 | Analysis | Self-Loading Firearms |
| Modern Firearms | 8 | 340 | 7 | Analysis | Automatic Weapons |

*Gunsmithing also gates the shovel's "dig a trench" action.*

*Cartridge Ammunition, Self-Loading Firearms, and Automatic Weapons also gate the gunsmithing bench: each one researched widens the selection of gun parts the bench offers (tech bands 5/6/7); before Cartridge Ammunition the bench offers no parts at all.*

#### Artillery
| Node | Era | Ticks | Min Tier | Mode | Prerequisites |
|---|---|---|---|---|---|
| Siege Engines | 2 | 130 | 1 | Analysis | - |
| Cannon | 3 | 165 | 2 | Analysis | Siege Engines, Imperial Architecture |
| Field Artillery | 4 | 200 | 3 | Analysis | Cannon, Steelmaking |
| Mechanized Warfare | 6 | 405 | 5 | **Prototype** (tank shell casing) | Field Artillery, Combustion Engine, Steelmaking |
| Missiles | 7 | 305 | 6 | Analysis | Mechanized Warfare, Aviation & Rocketry |

#### Armor (gateway)
| Node | Era | Ticks | Min Tier | Mode | Prerequisites |
|---|---|---|---|---|---|
| Padded Armor | 0 | 60 | 0 | Analysis | - |

**Padded Armor** (basic) stays on the Main tree as the armour gateway. The advanced armour nodes moved to the standalone **Tailoring** tree (see below).

### Health layer

#### Medicine
| Node | Era | Ticks | Min Tier | Mode | Prerequisites |
|---|---|---|---|---|---|
| Herbalism | 0 | 60 | 0 | Analysis | - |
| Apothecary | 2 | 130 | 1 | Analysis | Herbalism |
| Pharmacology | 5 | 235 | 4 | Analysis | Apothecary, Printing & Currency |
| Modern Medicine | 7 | 305 | 6 | Analysis | Pharmacology |

#### Surgery
| Node | Era | Ticks | Min Tier | Mode | Prerequisites |
|---|---|---|---|---|---|
| Field Surgery | 1 | 95 | 0 | Analysis | Bronze Working |
| Surgical Theory | 3 | 165 | 2 | Analysis | Field Surgery, Printing & Currency |
| Anesthetic Surgery | 5 | 235 | 4 | Analysis | Surgical Theory |
| Modern Surgery | 7 | 305 | 6 | Analysis | Anesthetic Surgery |

#### Sanitation
| Node | Era | Ticks | Min Tier | Mode | Prerequisites |
|---|---|---|---|---|---|
| Hygiene | 1 | 95 | 0 | Analysis | - |
| Sanitation | 3 | 165 | 2 | Analysis | Hygiene |
| Germ Theory | 5 | 235 | 4 | Analysis | Sanitation |
| Public Health | 7 | 305 | 6 | Analysis | Germ Theory |

---

*This system replaces the old flat Industrial/Military/Health point-pool research. Recipes not yet migrated into the tree still use the legacy threshold gate as a fallback - over time, more of the crafting catalogue will be tied to specific nodes above.*
