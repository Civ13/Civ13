// ============================================================
// Research Tree - shared defines
// ------------------------------------------------------------
// Phase 0: data model + bench skeleton. See the research-tree
// rework project notes for the full phased plan.
// ============================================================

// How a node is completed.
#define RESEARCH_MODE_ANALYSIS   1 // fills passively from bench ticks
#define RESEARCH_MODE_BOOK       2 // completed/boosted by a subject research book
#define RESEARCH_MODE_PROTOTYPE  3 // requires building/consuming a prototype item

// Per-faction status of a single node. Computed from stored progress.
#define RNODE_LOCKED       1 // prereqs not yet met
#define RNODE_AVAILABLE    2 // researchable, no ticks yet
#define RNODE_IN_PROGRESS  3 // has ticks but not finished
#define RNODE_DONE         4 // completed, unlocks granted faction-wide

// Index into a stored per-node progress entry: list(status_hint, ticks, prototype_submitted)
#define RNODE_ENTRY_STATUS    1
#define RNODE_ENTRY_TICKS     2
// PROTOTYPE nodes need BOTH full study AND a submitted prototype; this flags
// whether the matching prototype item has been fed to a bench yet. Older saved
// entries only have two elements, so reads must guard on entry.len.
#define RNODE_ENTRY_PROTOTYPE 3

// Phase 3: bench tiers, faction bench cap, resource forge.
#define MAX_BENCH_TIER 7 // matches the highest min_bench_tier used in the tree

// Silver-equivalent coin value (copper 0.1 / silver 1 / gold 4, summed across
// coins fed in) needed to push a bench from tier T to tier T+1. Escalates so
// late tiers are a real investment.
#define BENCH_TIER_UPGRADE_COST(T) (120 * (T + 1))

// Base number of benches a faction may own, before any forge upgrades, at
// a given ordinal_age. +1 per era reached.
#define BASE_BENCH_CAP(era) (1 + era)

// Silver-equivalent coin value needed at the resource forge to grant a faction
// its Nth bonus bench slot (N = current bonus count, 0-indexed). Coins are
// valued at copper 0.1 / silver 1 / gold 4, and accumulate across feedings (a
// coin stack maxes at 500), so late slots costing more than one full stack are
// paid off cumulatively.
#define FORGE_CAP_UPGRADE_COST(N) (300 * (N + 1))

// Research trade goods (notes + books). Produced by a faction that has a node
// DONE, consumed by another faction's bench working that same node:
//   NOTES  - weaker; grant a chunk of analysis ticks toward the node.
//   BOOK   - stronger; complete the node outright.
// One set of notes grants this fraction of the node's total tick cost.
#define RESEARCH_NOTE_BOOST_FRACTION 0.3
// Studying one sample (an existing example of something the node will unlock)
// grants this fraction of the node's cost. Each distinct item TYPE can only be
// studied once per assignment, so the ceiling is (distinct unlockables) x this.
#define RESEARCH_SAMPLE_BOOST_FRACTION 0.12
// Transcription time (deciseconds) at the bench. Books are far more work than
// quick notes -- that effort gap is what keeps notes worth trading.
#define RESEARCH_NOTES_WRITE_TIME 60   // 6s
#define RESEARCH_BOOK_WRITE_TIME  350  // 35s
