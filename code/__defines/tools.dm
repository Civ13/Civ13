// Tool qualities. An item declares what it can do as a tool in `tool_flags`,
// and code asks is_tool(I, TOOL_X) instead of checking one item path, so a
// new tool (a bone chisel, an obsidian knife) works everywhere by declaring
// the quality. A quality is inherited by every subtype of the item that
// declares it.
#define TOOL_WRENCH      (1<<0)
#define TOOL_HAMMER      (1<<1)
#define TOOL_CROWBAR     (1<<2)
#define TOOL_WIRECUTTER  (1<<3)
#define TOOL_SCREWDRIVER (1<<4)
#define TOOL_WELDER      (1<<5)
#define TOOL_KNIFE       (1<<6)
#define TOOL_HATCHET     (1<<7)
#define TOOL_SHOVEL      (1<<8)
#define TOOL_PICKAXE     (1<<9)
#define TOOL_CHISEL      (1<<10)

// Kinds of labour whose wait comes from work_delay() (materials/work_speed.dm).
#define WORK_DIG  "dig"
#define WORK_MINE "mine"
#define WORK_CHOP "chop"
#define WORK_TILL "till"
#define WORK_SHIFT "shift" // moving loose earth: piles, backfill, filling roads
// Bounds on a worker's total wait multiplier against the base wait.
#define WORK_MIN_MULT 0.25
#define WORK_MAX_MULT 3
// Wait to fell a tree for an average worker with an iron hatchet (30 x 1.7).
#define CHOP_TREE_TIME 51
