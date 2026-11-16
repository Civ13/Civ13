// Click cooldown
#define DEFAULT_ATTACK_COOLDOWN 8 //Default timeout for aggressive actions
#define DEFAULT_QUICK_COOLDOWN  4


//default item on-mob icons
#define INV_HEAD_DEF_ICON 'icons/mob/head.dmi'
#define INV_BACK_DEF_ICON 'icons/mob/back.dmi'
#define INV_L_HAND_DEF_ICON 'icons/mob/items/lefthand.dmi'
#define INV_R_HAND_DEF_ICON 'icons/mob/items/righthand.dmi'
#define INV_W_UNIFORM_DEF_ICON 'icons/mob/uniform.dmi'
#define INV_ACCESSORIES_DEF_ICON 'icons/mob/ties.dmi'
#define INV_SUIT_DEF_ICON 'icons/mob/suit.dmi'


// Defines mob sizes, used by lockers and to determine what is considered a small sized mob, etc.
#define MOB_HUGE  		70
#define MOB_LARGE  		40
#define MOB_MEDIUM 		20
#define MOB_SMALL 		10
#define MOB_TINY 		5
#define MOB_MINISCULE	1

// Gluttony levels.
#define GLUT_TINY 1	   // Eat anything tiny and smaller
#define GLUT_SMALLER 2	// Eat anything smaller than we are
#define GLUT_ANYTHING 3   // Eat anything, ever

#define TINT_NONE 0
#define TINT_HEAVY 2
#define TINT_BLIND 3

#define FLASH_PROTECTION_REDUCED -1
#define FLASH_PROTECTION_NONE 0
#define FLASH_PROTECTION_MODERATE 1
#define FLASH_PROTECTION_MAJOR 2

// Incapacitation flags, used by the mob/proc/incapacitated() proc
#define INCAPACITATION_RESTRAINED 1
#define INCAPACITATION_BUCKLED_PARTIALLY 2
#define INCAPACITATION_BUCKLED_FULLY 4
#define INCAPACITATION_DISABLED 8
#define INCAPACITATION_STUNNED 8
#define INCAPACITATION_FORCELYING 16 //needs a better name - represents being knocked down BUT still conscious.
#define INCAPACITATION_KNOCKOUT 32
// Sleep opts into checking disabled states except resting; DEFAULT is unchanged.
#define INCAPACITATION_DISABLED_NO_REST 64

#define INCAPACITATION_DEFAULT (INCAPACITATION_RESTRAINED|INCAPACITATION_BUCKLED_FULLY|INCAPACITATION_DISABLED)

#define MOB_PULL_NONE 0
#define MOB_PULL_SMALLER 1
#define MOB_PULL_LARGER 3

#define MOVED_DROP 1

//carbon taste sensitivity defines, used in mob/living/human/proc/ingest
#define TASTE_NORMAL 1 //anything below 15%

//Ambience
#define SOUND_CHANNEL_AMBIENCE 2
#define SOUND_CHANNEL_RAIN 778

//Hygiene levels for humans
#define HYGIENE_LEVEL_CLEAN 250
#define HYGIENE_LEVEL_NORMAL 200
#define HYGIENE_LEVEL_DIRTY 75
#define HYGIENE_FACTOR 0.015
// How dirty the hands are (hygiene_work.dm).
#define DIRTY_HANDS_GRIME 1
#define DIRTY_HANDS_WASTE 2
// Percent a second that a worn garment over 90 dirt picks up fleas (about an hour on average).
#define FLEA_INFEST_CHANCE 0.03
// Percent of flea infestations that carry typhus.
#define FLEA_TYPHUS_SHARE 10
// Percent a second that typhus-carrying fleas pass it on (about one in three over an hour).
#define FLEA_TYPHUS_RATE 0.01
// Mood tiers. Every reader (stats, movement, HUD icon, messages, examine, Help)
// goes through mood_tier(), and each boundary belongs to the higher tier.
#define MOOD_TIER_HORRIBLE 1 // below 20
#define MOOD_TIER_BAD 2      // 20 up to 40
#define MOOD_TIER_NEUTRAL 3  // 40 up to 60: no bonus and no penalty
#define MOOD_TIER_GOOD 4     // 60 up to 80
#define MOOD_TIER_EXCELLENT 5 // 80 and above
#define MOOD_REST 50      // where mood settles with nothing acting on it
#define MOOD_REST_MIN 30  // lasting conditions move the resting level within these
#define MOOD_REST_MAX 75
#define MOOD_REST_CHECK 100 // deciseconds between looks at the lasting conditions
#define MOOD_BOOST_BAND 10 // a lift this far above the resting level fades slowly
#define MOOD_FADE 0.015   // lost per life tick inside that band
#define MOOD_BURN 0.07    // lost per life tick above it: highs do not last
#define MOOD_RECOVER 0.03 // regained per life tick below the resting level
// Free movement (client/Move fine_step values). Plain direction keys slide at
// the ordinary walking/running pace and stop where they are released.
// Alt+direction nudges 2 pixels, then slides if held past the glide delay.
#define FINE_STEP_NUDGE 1
#define FINE_STEP_HELD 2
// Plain held keys: a held slide when the body can slide, else a tile step.
#define FINE_STEP_FREE 3
#define FINE_OFFSET_GLIDE_DELAY 1
// Fresh free movement glides its first step this many pixels short (one tick
// of travel, within these bounds), so the client keeps a small glide buffer.
// It hides uneven per-tick pulses and small network jitter (see
// human_subtile_glide_distance). Later chained steps glide at the exact pace.
#define HUMAN_SUBTILE_GLIDE_BUFFER_MIN 6
#define HUMAN_SUBTILE_GLIDE_BUFFER_MAX 8
// Largest drawn lag free movement smooths out; anything bigger is drawn as a jump.
#define HUMAN_SUBTILE_SMOOTH_MAX 12
// Off: on live Gaia (2026-11-11) the body's offset was drawn but the camera's
// was not, so the body swung up to 12px around the screen centre while walking.
// Turn back on only after a Dream Seeker check in the real game.
#define HUMAN_SUBTILE_SMOOTH_DRAW 0
