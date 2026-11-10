# Personal recipe manuals (issue #4239, phase 1)

This feature is inactive by default. A Persistence map may opt in with the
`recipe_books` configuration flag; no shipped map is enabled by this change.
Round maps retain their faction/era rules. The flag is not saved as mutable map
metadata. To enable it in an already running world, the operator integration
must call `activate_recipe_books()` instead of assigning the flag directly.
Activation itself is outside this PR's authorization.

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
