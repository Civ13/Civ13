// Defines shared across files. They live here so civ13.dme compiles in any
// include order, including the alphabetical order the Dream Maker IDE saves.

// Scholar reading light (_research_tree_defines.dm)
#define SCHOLAR_MIN_LIGHT 0.3

// Book writing (book_pages.dm)
#define BOOK_WRITE_TIME(tier) (1200 + 600 * max(0, tier))
#define BOOK_WRITE_STAMINA(tier) (15 + 5 * max(0, tier))

// Book research (book_research.dm)
#define BOOK_RESEARCH_REACH 1
// Work while the bench runs (chat feedback, 2026-11-17): the scholar leading
// the work counts while within this many tiles and in sight of the bench, at
// full pace beside it and BOOK_RESEARCH_AWAY_RATE further off, so they can
// craft, cook or build nearby. Their writing tool may rest on the bench.
#define BOOK_RESEARCH_NEAR 3
#define BOOK_RESEARCH_AWAY_RATE 0.75
#define BOOK_STUDY_TIME(tier) (600 + 300 * max(0, tier))

// A land's era follows the capstones written down in it (era_loss.dm). Real
// time, in deciseconds, so it also passes while a land sleeps.
// How often a land checks its written records.
#define ERA_RECORD_CHECK_INTERVAL (5 MINUTES)
// How long a land keeps its era after the last copy of the capstone has left
// or been destroyed: a book brought back within this costs nothing.
#define ERA_RECORD_RETURN_WINDOW (2 HOURS)
// How long a later capstone must stay in a land before the land starts to rise.
#define ERA_RECORD_SETTLE_TIME (2 HOURS)
// At most one era gained or lost per this long.
#define ERA_RECORD_STEP (1 HOURS)
