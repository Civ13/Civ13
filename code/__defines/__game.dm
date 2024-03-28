#define DEBUG 0

//Game defining directives.
//tgmc defines port from ru civ13 - anon

#define INVISIBILITY_ABSTRACT 101 //only used for abstract objects (e.g. spacevine_controller), things that are not really there.

//=================================================
//Game mode related defines.

#define GET_RANDOM_FREQ rand(32000, 55000) //Frequency stuff only works with 45kbps oggs.

//ceiling types
#define CEILING_NONE 0
#define CEILING_GLASS 1
#define CEILING_METAL 2
#define CEILING_UNDERGROUND 3
#define CEILING_UNDERGROUND_METAL 4
#define CEILING_DEEP_UNDERGROUND 5
#define CEILING_DEEP_UNDERGROUND_METAL 5

// Default font settings
#define FONT_SIZE "5pt"
#define FONT_COLOR "#09f"
#define FONT_STYLE "Arial Black"
#define SCROLL_SPEED 2

// Default preferences
#define DEFAULT_SPECIES "Human"
#define GAME_YEAR (text2num(time2text(world.realtime, "YYYY")) + 395)
#define MAX_BROADCAST_LEN 512

/// Is something in the IC chat filter? This is config dependent.
#define CHAT_FILTER_CHECK(text) (config.ic_filter_regex && findtext_char(text, config.ic_filter_regex))

//for whether AI eyes see static, and whether it is mouse-opaque or not
#define USE_STATIC_NONE 0
#define USE_STATIC_TRANSPARENT 1
#define USE_STATIC_OPAQUE 2


#define CINEMATIC_DEFAULT 1
#define CINEMATIC_SELFDESTRUCT 2
#define CINEMATIC_SELFDESTRUCT_MISS 3
#define CINEMATIC_NUKE_WIN 4
#define CINEMATIC_NUKE_MISS 5
#define CINEMATIC_ANNIHILATION 6
#define CINEMATIC_MALF 7
#define CINEMATIC_NUKE_FAKE 8
#define CINEMATIC_NUKE_NO_CORE 9
#define CINEMATIC_NUKE_FAR 10
#define CINEMATIC_CRASH_NUKE 11

#define WORLD_VIEW "15x15"
// 7 по Х и 7 по У = 15х15
// 9 по Х и 7 по У = 19х15
#define WORLD_VIEW_NUM_X 5
#define WORLD_VIEW_NUM_Y 5
#define VIEW_NUM_TO_STRING(v) "[1 + 2 * v]x[1 + 2 * v]"

#define TEXT_NORTH "[NORTH]"
#define TEXT_SOUTH "[SOUTH]"
#define TEXT_EAST "[EAST]"
#define TEXT_WEST "[WEST]"
