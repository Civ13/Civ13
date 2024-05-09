// None of those definitions are used in-game as of May 9th 2024.

#define DEBUG 0

#define SEE_INVISIBLE_MINIMUM 5

#define INVISIBILITY_LIGHTING 20

#define SEE_INVISIBLE_LIVING 25

#define INVISIBILITY_OBSERVER 60
#define SEE_INVISIBLE_OBSERVER 60

#define INVISIBILITY_MAXIMUM 100

#define INVISIBILITY_ABSTRACT 101 //only used for abstract objects (e.g. spacevine_controller), things that are not really there.


//Object specific defines
#define CANDLE_LUM 3 //For how bright candles are


//some arbitrary defines to be used by self-pruning global lists. (see master_controller)
#define PROCESS_KILL 26	//Used to trigger removal from a processing list

//=================================================
#define HOSTILE_STANCE_IDLE 1
#define HOSTILE_STANCE_ALERT 2
#define HOSTILE_STANCE_ATTACK 3
#define HOSTILE_STANCE_ATTACKING 4
#define HOSTILE_STANCE_TIRED 5
//=================================================


//=================================================
//Game mode related defines.

#define TRANSITIONEDGE 3 //Distance from edge to move to another z-level

//Flags for zone sleeping
#define ZONE_ACTIVE 1
#define ZONE_SLEEPING 0
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

#define GAME_YEAR (text2num(time2text(world.realtime, "YYYY"))) // To be adapted according to each map's year. Here it gives a date set in the current real world year.


#define MAX_MESSAGE_LEN 1024
#define MAX_PAPER_MESSAGE_LEN 3072
#define MAX_BOOK_MESSAGE_LEN 9216
#define MAX_NAME_LEN 45
#define MAX_BROADCAST_LEN 512


/// Is something in the IC chat filter? This is config dependent.
#define CHAT_FILTER_CHECK(text) (config.ic_filter_regex && findtext_char(text, config.ic_filter_regex))

//for whether AI eyes see static, and whether it is mouse-opaque or not
#define USE_STATIC_NONE 0
#define USE_STATIC_TRANSPARENT 1
#define USE_STATIC_OPAQUE 2

#define WORLD_VIEW "15x15"
// 7 to X and 7 to Y = 15х15
// 9 to X and 7 to Y = 19х15
#define WORLD_VIEW_NUM_X 5
#define WORLD_VIEW_NUM_Y 5
#define VIEW_NUM_TO_STRING(v) "[1 + 2 * v]x[1 + 2 * v]"

#define TEXT_NORTH "[NORTH]"
#define TEXT_SOUTH "[SOUTH]"
#define TEXT_EAST "[EAST]"
#define TEXT_WEST "[WEST]"
