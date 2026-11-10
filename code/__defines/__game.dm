// None of those definitions are used in-game as of May 9th 2024.

#define DEBUG 0

#define INVISIBILITY_LIGHTING 20

#define SEE_INVISIBLE_LIVING 25

#define INVISIBILITY_OBSERVER 60
#define SEE_INVISIBLE_OBSERVER 60

#define INVISIBILITY_MAXIMUM 100


//Object specific defines
#define CANDLE_LUM 3 //For how bright candles are


//some arbitrary defines to be used by self-pruning global lists. (see master_controller)
#define PROCESS_KILL 26	//Used to trigger removal from a processing list

//=================================================
#define HOSTILE_STANCE_IDLE 1
#define HOSTILE_STANCE_ALERT 2
#define HOSTILE_STANCE_ATTACK 3
#define HOSTILE_STANCE_TIRED 5
//=================================================


//=================================================
//Game mode related defines.

#define MAX_MESSAGE_LEN 1024
#define MAX_PAPER_MESSAGE_LEN 3072
#define MAX_BOOK_MESSAGE_LEN 9216
#define MAX_NAME_LEN 45

// The game view. Widescreen is the default; the "Square game view" preference
// falls back to SQUARE_VIEW. world.view stays a numeric radius of 7, so range
// checks (hearing, NPC sight, view(world.view)) are unchanged.
#define WORLD_VIEW "21x15"
#define SQUARE_VIEW "15x15"
// The HUD's default positions are laid out on this grid and anchored from it.
#define HUD_DESIGN_VIEW "15x15"

// Client animation target, independent of the world's simulation tick rate.
#define DEFAULT_CLIENT_FPS 100
