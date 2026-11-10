# Personal recipe manuals (issue #4239, phase 1)

On Persistence, `recipe_books` and `book_research` are on by default since the
research relaunch (Val, 2026-11-10). Both only apply when the round is
Persistence (`recipe_knowledge_enabled()` needs `persistence`), so round maps
keep their faction/era rules. Turning them on needs a fresh world: a restored
save keeps its characters, who would then know nothing. Launch is
**Fresh world (all regions)** in the launcher on the same update. Neither flag
is saved as mutable map metadata. `activate_recipe_books()` remains the
integration point for switching recipe books on in an already running world.

With the flag enabled, crafting needs both faction/era research and personal
knowledge of the node. Only research essentials (the research bench, legacy
research desk and node prototypes) skip the personal check. Read a
node manual for one minute to learn it. Reading leaves the book intact and
repeated reading does not duplicate knowledge. Books cannot bypass research.
The book's subject is a text ID, not a reference to a research datum.

Existing saved bodies receive one grant of the nodes unlocked by their restored
faction and era, after world restoration. The marker and list are saved on each
body. New bodies created with this feature enabled start empty, including after
save/reload. Death clears personal knowledge; a fresh body does not inherit it.
Already-known manuals return immediately. Faster relearning after death is not
implemented: the plan does not define book ownership or whether memory may
survive death, and this phase adds no account-level or seen-node history.
That balance rule remains unresolved.

AI-controlled Nomads are exempt from the personal gate, not the research ceiling.
NPC trader shops are not player crafting actions.

Research completion makes one reusable manual at a faction bench, falling back
to a living faction member if there is no bench. One-copy versus per-member
balance remains a design decision; this draft proposes one copy. Starter stock,
copying, printing, teaching and compendiums follow in phase 2, menu hints in phase 3.

Region travel uses version 2 for knowledge or manuals. Known IDs survive travel
regardless of the destination research ceiling, which still controls crafting.
Old version-1 arrivals remain accepted; unsupported versions and unknown node
IDs are refused rather than silently lost. Knowledge-carrying travel requires
upgraded peers. The existing payload size and item count limits still apply.

## Book research (Persistence redesign, phase 1)

`code/modules/research_tree/book_research.dm` adds a second opt-in map flag,
`book_research`, on top of `recipe_books` (`book_research_enabled()` needs both
and `persistence`). It is off on every map; turning it on is a maintainer
decision. With it on:

- Research benches belong to nobody. Faction claiming, staff roles, the queue
  and the bench cap are skipped; anyone can set a bench's subject.
- Research is written into the book placed on the bench (one ordinary,
  non-`unique` book; Alt-click or the UI takes it back). The book keeps
  `research_progress` (`node=ticks=prototype;...`) and `research_chapters`
  (`node;...`) as text, so progress travels with the book and survives saves.
- A bench only progresses while someone within one tile knows every
  prerequisite of the subject (a connected player or an agent character).
  Prototypes and samples go into the book's progress the same way.
- Finishing a node writes a chapter and teaches no one. A capstone still moves
  the world era the first time anyone finishes it. Anyone who knows the
  groundwork studies the chapter from the book (`BOOK_STUDY_TIME(era_tier)`).
- Crafting needs the character's own knowledge only: no faction or era grants.
  Research essentials need the node's groundwork instead of a manual.
- No first-node manual is produced and enabling the flag grants nothing to
  existing bodies.
- Older research checks outside crafting (trenches, irrigation, kilns,
  gunsmithing, slipways, workshops, the tablet press, safehouse upgrades,
  specialist traders, factory fabricators) go through `research_node_known(H,
  node)`, which is the character's knowledge in book mode and faction research
  otherwise.

### Scholarship skills (phase 2)

`scholarship.dm` adds per-character discipline levels (0-100), saved on the
body as `scholarship` and cleared on death: Basic Mathematics, Engineering,
Natural Science, Medicine, Agriculture and Military Science. Each node has a
discipline (`node_discipline()`: category default plus
`scholar_node_disciplines` overrides) and needs `era_tier * 12` in it plus
half that in Basic Mathematics before anyone can progress it at a bench.
Skill above the requirement speeds research up to double. Each bench tick
gives the researcher `SCHOLAR_RESEARCH_GAIN` and each studied chapter
`SCHOLAR_STUDY_GAIN`, reduced for work far below their level; half also goes
to Basic Mathematics. Studying needs no skill. The `Check scholarship` verb
lists the levels and the bench shows each node's requirement.

### Books from memory (phase 3)

`book_pages.dm` keeps a book's writing as pages (`written_pages`; `dat` mirrors
them and older one-block books become page one). Pen or pencil "Contents" adds
a page. With book research on:

- The same pen menu offers "Research chapter": pick a node you know that the
  book lacks, hold a blank sheet of paper or parchment, and spend
  `BOOK_WRITE_STAMINA(tier)` stamina over `BOOK_WRITE_TIME(tier)` (two minutes
  for the Stone Age). Writing gives a little scholarship.
- "Rip out a page" (any non-unique book) takes a page or chapter out in two
  seconds. A page becomes a written sheet; a chapter becomes a
  `research_page` that can be studied on its own. Using either on a book binds
  it back in over 30 seconds.
- Parchment (`/obj/item/weapon/paper/parchment`) is cut from a dried hide with a
  sharp tool, four sheets per hide, and works like paper.
- The pencil, paper and blank book are craftable by anyone from 5000 B.C.
  (`book_research_writing_supplies`); the pen stays on Papermaking. Material
  menus show rows up to the world era and the craft checks knowledge.

### Two books on a bench (phase 4)

A bench holds up to two books (`BENCH_MAX_BOOKS`). Research is written into
the first; "Write research into the other book" swaps them. With two books,
"Copy a chapter" copies any chapter one has and the other lacks, with a blank
sheet, the same stamina and time as writing, and no knowledge of the node.
"Study a chapter" studies from a shelved book without picking it up, and each
book has its own Take button (Alt-click takes the last one).

### No clock (phase 5)

With book research on, a Persistence world has no 1943 date floor and no
auto-research: `apply_persistence_age_floor()` turns `autoresearch` off and
returns, so a world can start at 5000 B.C. and stay there. The legacy era
steps in the map tick (faction research point totals) are skipped as well.
The era only moves when someone finishes a capstone chapter, which needs the
capstone's prototype (`book_research_node_finished`). The mode shows as
"Persistent (Book Research)". Research time already grows with tier through
each node's `cost_ticks`; writing and study time and writing stamina grow
with `era_tier` (`BOOK_WRITE_TIME`, `BOOK_STUDY_TIME`, `BOOK_WRITE_STAMINA`).

### Starting a book research world (phase 6)

At startup in `PERSISTENCE` mode with book research on,
`start_book_research_world()` sets the world to 5000 B.C. with no ages done
and auto-research off. A restored save then replaces this with its own era,
so only a fresh world starts in the Stone Age. A faction founder receives the
Stone Age master book (every era-0 chapter, `stone_age_node_ids()`) and a
pencil; the chapters still have to be studied.

The launch wipe is an operator step, not code: turn on `recipe_books` and
`book_research` for the Persistence maps, then use **Fresh world** for each
region (see `docs/launcher-fresh-world.md`). That archives the world saves,
which hold every saved body, so all characters start over. Fresh world refuses
regions with transfer links; a connected region group such as Gaia's uses
`shard_group.py group-fresh-world --confirm-group GROUP` instead, which also
archives the transfer stores and account homes.

### Scholar tools (profession 1)

`scholar_tools.dm` makes writing tools part of the scholar's trade. A bench
only progresses while the researcher holds a writing tool, and the tool's rate
multiplies the scholar's own research rate: writing slate and chalk or pencil
1.0, crayon 0.5, quill or pen 1.25, expensive pen 1.5 (`scholar_tool_rate`).
Writing a chapter from memory and copying between two books need a pencil or
pen in hand (the slate can't write into books), and the time is
`BOOK_WRITE_TIME(tier)` divided by the pen's rate (`scholar_write_time`). The
writing slate is a Stone Age item made from 2 stone; like the pencil it is a
book-research writing supply, free from 5000 B.C. Before the Industrial Age
the plain ink pen is named a quill, matching its feather sprite.

### Writing desk and library (profession 2)

The writing desk (6 soft wood, Basic Furniture, unused `good_desk` art) speeds
studying, writing and copying by 1.25x for anyone beside a fastened one
(`scholar_desk_rate`, `scholar_study_time`, the `writer` argument of
`scholar_write_time`). A research bench counts distinct chapters on the
node's groundwork or in its discipline, in books on bookcases within 3 tiles
(`library_chapters`), and researches 10% faster per chapter, up to 50%
(`library_rate`). The bench status line shows the library bonus.

### Research supplies and light (profession 3)

A bench makes no progress in the dark (turf light below 0.3,
`research_lit`). Each research tick uses one supply point for the subject's
discipline; with none, research runs at half speed (`use_research_supply`).
Using a supply on the bench stores points, up to 200 per discipline, saved on
the bench as `research_supplies` text (`discipline=points;...`, validated on
read). Supplies by discipline (`scholar_supply_value`): blank paper or
parchment for Basic Mathematics, material stacks for Engineering, ore or glass
for Natural Science, medical stacks or grown herbs for Medicine, seeds or
produce for Agriculture, and ammunition or ammunition parts for Military
Science. Samples and prototypes are checked first, so an item that is both
still counts as a sample.

### Instruments (profession 4)

From the Imperial Age (`SCHOLAR_INSTRUMENT_TIER` 3), a node needs its
discipline's instrument on or next to the bench, or in a researcher's hands
(`has_research_instrument`), or the bench makes no progress. Instruments:
abacus (new, 3 soft wood, Trade & Coinage) for Basic Mathematics, drafting set
(new, 2 iron, Iron Tools) for Engineering, a beaker or glass jar for Natural
Science, a scalpel for Medicine, a plough for Agriculture and a map for
Military Science. Every instrument is made from a node below tier 3, so none
is locked behind the research it enables. The abacus and drafting set sprites
are in `icons/obj/scholar_tools.dmi`.

### Tutoring (profession 5)

When someone studies a chapter, a player or agent character beside them who
already knows that node tutors them (`find_tutor`): the study takes
`1 / SCHOLAR_TUTOR_RATE` (two thirds) of the time and, if the tutor is still
beside the student at the end (`still_tutoring`), the student gains three
times the usual study skill and the tutor gains the usual amount. Selling
books and taking commissions need no new code: books are ordinary items that
change hands through normal trade, and a commission is a chapter written from
memory or copied at a bench.

### Apprentices (profession 6)

The IC verb **Take an apprentice** offers an apprenticeship to a player next
to the master; the apprentice must accept, and a master has at most three.
The link is `scholar_master` on the apprentice's body (the master's
`ckey:real_name`), saved with the body, validated on load and cleared on death
or with **Leave apprenticeship**. At a research bench, a researcher whose
master stands within 2 tiles gains twice the usual skill, and the
researcher's own apprentices within 2 tiles gain half the usual research skill
by watching (`apprentice_research_gain`). The link does not travel between
regions.

### Titles (profession 7)

Examining a living character in book research shows their highest discipline
as a title (`scholar_title`): Apprentice from level 12, Scholar from 40 and
Master from 75, for example "Scholar of Medicine", so players can find and hire
scholars. Characters below 12 in every discipline show no title.

## Verification

`tests/recipe_knowledge/test_contract.py` checks source wiring offline and is
registered in the baseline. `tests/recipe_knowledge/run.py --byond-bin <bin>`
compiles the production game with isolated startup and an 8x8 offline fixture.
Its native cases cover real world-save/reload, new/dead bodies, legacy migration,
repeat learning/reading, invalid IDs and the research ceiling. The fixture
adapts human construction/physiology and does not establish connected-client
reading cancellation or live-server migration acceptance. It defaults to untrusted mode. On Windows the save fixture requires explicit
maintainer authorization for `--trusted`; it still opens no port and uses only
disposable fixture files. Logs are retained under ignored `.ci/` evidence.
