# Each land's era follows its books

Val, 2026-11-23: "the epoch of the world should be tied to the books that exist
on their lands". Code: `code/modules/research_tree/era_loss.dm`; timings in
`code/__defines/research.dm`; tests in `tests/recipe_knowledge/game.dm`
(`check_era_loss`).

Applies only to persistent worlds with book research. Each land (one region
world, or a world on its own) keeps the era whose capstone, or a later one, is
written down in that land: an ordinary book's chapter, a torn chapter, a recipe
manual or a compendium, carried, stored, on a bench or on an offline character.
A capstone written in one land does nothing for another until a copy is taken
there. With book research regions no longer follow the mainland's epoch
(`follow_mainland_epoch` returns early).

| What happens | Timing |
| --- | --- |
| Records checked | every 5 minutes |
| Last copy of the current era's capstone leaves the land or is destroyed | the land keeps its era for **2 hours**; a copy back in that time costs nothing |
| Still missing after 2 hours | the land falls back one era, then one more **each hour** while records are missing (never below the Stone Age) |
| A later capstone is carried into the land | nothing for **2 hours**; if it leaves first the wait starts again |
| It stays 2 hours | the land rises one era, then one more **each hour** until it reaches the book's era |
| Someone writes the capstone (or a lost one again from memory) | the land moves into that era at once, as before |

So a book carried away for good moves its era with it over a few hours, and one
brought home within two hours moves nothing. Destruction now gets the same
2-hour window (it was 10 minutes), since a land cannot tell a book that left
from one that burned.

The clocks are real time (`world.realtime`) kept in the map field
`era_records_state` (durable map field version 7, as text so JSON keeps the
digits), so restarts, handovers and a sleeping land do not reset them. Knowledge
spread bands (`knowledge_spread.dm`) read each land's own era.

On first deployment a region running above the era its own books hold starts
its 2-hour window then and falls back one era an hour after it.
