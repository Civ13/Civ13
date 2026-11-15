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
