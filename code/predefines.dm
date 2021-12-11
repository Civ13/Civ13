#define DEBUG

#define GAME_STATE_PREGAME		1
#define GAME_STATE_SETTING_UP	2
#define GAME_STATE_PLAYING		3
#define GAME_STATE_FINISHED		4

#define MAX_CHARS_PER_LINE 200
#define MAX_CHARS_TOTAL 20000

// These are for when a mob breathes poisonous air.
#define MIN_TOXIN_DAMAGE TRUE
#define MAX_TOXIN_DAMAGE 10

#define SOUND_MINIMUM_PRESSURE 10

// Pressure limits.
#define  HAZARD_HIGH_PRESSURE 550 // This determines at what pressure the ultra-high pressure red icon is displayed. (This one is set as a constant)
#define WARNING_HIGH_PRESSURE 325 // This determines when the orange pressure icon is displayed (it is 0.7 * HAZARD_HIGH_PRESSURE)
#define NORMAL_PRESSURE  100
#define WARNING_LOW_PRESSURE  50  // This is when the gray low pressure icon is displayed. (it is 2.5 * HAZARD_LOW_PRESSURE)
#define  HAZARD_LOW_PRESSURE  20  // This is when the black ultra-low pressure icon is displayed. (This one is set as a constant)

#define TEMPERATURE_DAMAGE_COEFFICIENT  1.5 // This is used in handle_temperature_damage() for humans, and in reagents that affect body temperature. Temperature damage is multiplied by this amount.
#define BODYTEMP_AUTORECOVERY_DIVISOR   45  // This is the divisor which handles how much of the temperature difference between the current body temperature and 310.15K (optimal temperature) humans auto-regenerate each tick. The higher the number, the slower the recovery. This is applied each tick, so long as the mob is alive.
#define BODYTEMP_AUTORECOVERY_MINIMUM   0.2   // Minimum amount of kelvin moved toward 310.15K per tick. So long as abs(310.15 - bodytemp) is more than 50.
#define BODYTEMP_COLD_DIVISOR		   3   // Similar to the BODYTEMP_AUTORECOVERY_DIVISOR, but this is the divisor which is applied at the stage that follows autorecovery. This is the divisor which comes into play when the human's loc temperature is lower than their body temperature. Make it lower to lose bodytemp faster.
#define BODYTEMP_HEAT_DIVISOR		   3   // Similar to the BODYTEMP_AUTORECOVERY_DIVISOR, but this is the divisor which is applied at the stage that follows autorecovery. This is the divisor which comes into play when the human's loc temperature is higher than their body temperature. Make it lower to gain bodytemp faster.
#define BODYTEMP_COOLING_MAX		   -18  // The maximum number of degrees that your body can cool down in 1 tick, when in a cold area.
#define BODYTEMP_HEATING_MAX			18  // The maximum number of degrees that your body can heat up in 1 tick,   when in a hot area.

#define BODYTEMP_HEAT_DAMAGE_LIMIT 360.15 // The limit the human body can take before it starts taking damage from heat.
#define BODYTEMP_COLD_DAMAGE_LIMIT 260.15 // The limit the human body can take before it starts taking damage from coldness.

#define SPACE_HELMET_MIN_COLD_PROTECTION_TEMPERATURE 2.0 // What min_cold_protection_temperature is set to for space-helmet quality headwear. MUST NOT BE 0.
#define   SPACE_SUIT_MIN_COLD_PROTECTION_TEMPERATURE 2.0 // What min_cold_protection_temperature is set to for space-suit quality jumpsuits or suits. MUST NOT BE 0.
#define	   HELMET_MIN_COLD_PROTECTION_TEMPERATURE 160 // For normal helmets.
#define		ARMOR_MIN_COLD_PROTECTION_TEMPERATURE 160 // For armor.
#define	   GLOVES_MIN_COLD_PROTECTION_TEMPERATURE 2.0 // For some gloves.
#define		 SHOE_MIN_COLD_PROTECTION_TEMPERATURE 2.0 // For shoes.

#define  SPACE_SUIT_MAX_HEAT_PROTECTION_TEMPERATURE 5000  // These need better heat protect, but not as good heat protect as firesuits.
#define	FIRESUIT_MAX_HEAT_PROTECTION_TEMPERATURE 30000 // What max_heat_protection_temperature is set to for firesuit quality headwear. MUST NOT BE 0.
#define FIRE_HELMET_MAX_HEAT_PROTECTION_TEMPERATURE 30000 // For fire-helmet quality items. (Red and white hardhats)
#define	  HELMET_MAX_HEAT_PROTECTION_TEMPERATURE 600   // For normal helmets.
#define	   ARMOR_MAX_HEAT_PROTECTION_TEMPERATURE 600   // For armor.
#define	  GLOVES_MAX_HEAT_PROTECTION_TEMPERATURE 1500  // For some gloves.
#define		SHOE_MAX_HEAT_PROTECTION_TEMPERATURE 1500  // For shoes.

// Fire.
#define FIRE_MIN_STACKS		  -20
#define FIRE_MAX_STACKS		   25
#define FIRE_MAX_FIRESUIT_STACKS  20 // If the number of stacks goes above this firesuits won't protect you anymore. If not, you can walk around while on fire like a badass.

#define THROWFORCE_SPEED_DIVISOR	5  // The throwing speed value at which the throwforce multiplier is exactly 1.
#define THROWNOBJ_KNOCKBACK_SPEED   15 // The minumum speed of a w_class 2 thrown object that will cause living mobs it hits to be knocked back. Heavier objects can cause knockback at lower speeds.
#define THROWNOBJ_KNOCKBACK_DIVISOR 2  // Affects how much speed the mob is knocked back with.

#define PRESSURE_DAMAGE_COEFFICIENT 4 // The amount of pressure damage someone takes is equal to (pressure / HAZARD_HIGH_PRESSURE)*PRESSURE_DAMAGE_COEFFICIENT, with the maximum of MAX_PRESSURE_DAMAGE.
#define	MAX_HIGH_PRESSURE_DAMAGE 4 // This used to be 20... I got this much random rage for some retarded decision by polymorph?! Polymorph now lies in a pool of blood with a katana jammed in his spleen. ~Errorage --PS: The katana did less than 20 damage to him :(
#define		 LOW_PRESSURE_DAMAGE 2 // The amount of damage someone takes when in a low pressure area. (The pressure threshold is so low that it doesn't make sense to do any calculations, so it just applies this flat value).

#define HUNGER_FACTOR			  0.05 // Factor of how fast mob nutrition decreases

#define MINIMUM_TEMPERATURE_RATIO_TO_SUSPEND	  0.012		// Minimum temperature difference before group processing is suspended.
#define MINIMUM_TEMPERATURE_DELTA_TO_SUSPEND	  4
#define MINIMUM_TEMPERATURE_DELTA_TO_CONSIDER	 0.5		  // Minimum temperature difference before the gas temperatures are just set to be equal.
#define MINIMUM_TEMPERATURE_FOR_SUPERCONDUCTION   (T20C + 10)
#define MINIMUM_TEMPERATURE_START_SUPERCONDUCTION (T20C + 200)

// Must be between FALSE and 1. Values closer to TRUE equalize temperature faster. Should not exceed 0.4, else strange heat flow occurs.
#define  FLOOR_HEAT_TRANSFER_COEFFICIENT 0.4
#define   WALL_HEAT_TRANSFER_COEFFICIENT 0.0
#define   DOOR_HEAT_TRANSFER_COEFFICIENT 0.0
#define  SPACE_HEAT_TRANSFER_COEFFICIENT 0.2 // A hack to partly simulate radiative heat.
#define   OPEN_HEAT_TRANSFER_COEFFICIENT 0.4
#define WINDOW_HEAT_TRANSFER_COEFFICIENT 0.1 // A hack for now.

// Fire damage.
#define CARBON_LIFEFORM_FIRE_RESISTANCE (T0C + 200)
#define CARBON_LIFEFORM_FIRE_DAMAGE	 4

//How many moles of fuel are contained within one solid/liquid fuel volume unit
#define LIQUIDFUEL_AMOUNT_TO_MOL		1  //mol/volume unit

#define T0C  273.15 //	0.0 degrees celcius
#define T20C 293.15 //   20.0 degrees celcius
#define TCMB 2.7	// -270.3 degrees celcius

#define HUMAN_STRIP_DELAY		40   // Takes 40ds = 4s to strip someone.
#define NORMPIPERATE			 30   // Pipe-insulation rate divisor.
#define HEATPIPERATE			 8	// Heat-exchange pipe insulation.
#define FLOWFRAC				 0.99 // Fraction of gas transfered per process.
#define SHOES_SLOWDOWN		  -0.2  // How much shoes slow you down by default. Negative values speed you up.

// Flags bitmasks.
#define STOPPRESSUREDAMAGE TRUE // This flag is used on the flags variable for SUIT and HEAD items which stop pressure damage. Note that the flag TRUE was previous used as ONBACK, so it is possible for some code to use (flags & TRUE) when checking if something can be put on your back. Replace this code with (inv_flags & SLOT_BACK) if you see it anywhere
							 // To successfully stop you taking all pressure damage you must have both a suit and head item with this flag.
#define NOBLUDGEON		 2	// When an item has this it produces no "X has been hit by Y with Z" message with the default handler.
#define AIRTIGHT		   4	// Functions with internals.
#define USEDELAY		   8	// TRUE second extra delay on use. (Can be used once every 2s)
#define NOSHIELD		   16   // Weapon not affected by shield.
#define CONDUCT			32   // Conducts electricity. (metal etc.)
#define ON_BORDER		  64   // Item has priority to check when entering or leaving.
#define NOBLOODY		   512  // Used for items if they don't want to get a blood overlay.
#define NODELAY			8192 // TRUE second attack-by delay skipped (Can be used once every 0.2s). Most objects have a TRUEs attack-by delay, which doesn't require a flag.

//Use these flags to indicate if an item obscures the specified slots from view, whereas body_parts_covered seems to be used to indicate what body parts the item protects.
#define GLASSESCOVERSEYES 256
#define	MASKCOVERSEYES 256 // Get rid of some of the other retardation in these flags.
#define	HEADCOVERSEYES 256 // Feel free to reallocate these numbers for other purposes.
#define   MASKCOVERSMOUTH 512 // On other items, these are just for mask/head.
#define   HEADCOVERSMOUTH 512

#define THICKMATERIAL		  256  // From /tg/station: prevents syringes, parapens and hyposprays if the external suit or helmet (if targeting head) has this flag. Example: space suits, biosuit, bombsuits, thick suits that cover your body. (NOTE: flag shared with NOSLIP for shoes)
#define NOSLIP				 256  // Prevents from slipping on wet floors, in space, etc.
#define OPENCONTAINER		  1024 // Is an open container for chemistry purposes.
#define BLOCK_GAS_SMOKE_EFFECT 2048 // Blocks the effect that chemical clouds would have on a mob -- glasses, mask and helmets ONLY! (NOTE: flag shared with ONESIZEFITSALL)
#define ONESIZEFITSALL		 2048
#define PHORONGUARD			4096 // Does not get contaminated by phoron.
#define	NOREACT				4096 // Reagents don't react inside this container.
#define BLOCKHEADHAIR		  4	// Temporarily removes the user's hair overlay. Leaves facial hair.
#define BLOCKHAIR			  8192 // Temporarily removes the user's hair, facial and otherwise.

// Flags for pass_flags.
#define PASSTABLE  TRUE
#define PASSGLASS  2
#define PASSGRILLE 4
#define PASSBLOB   8

// Turf-only flags.
#define NOJAUNT TRUE // This is used in literally one place, turf.dm, to block ethereal jaunt.

// Bitmasks for the flags_inv variable. These determine when a piece of clothing hides another, i.e. a helmet hiding glasses.
// WARNING: The following flags apply only to the external suit!
#define HIDEGLOVES	  TRUE
#define HIDESUITSTORAGE 2
#define HIDEJUMPSUIT	4
#define HIDESHOES	   8
#define HIDETAIL		16

// WARNING: The following flags apply only to the helmets and masks!
#define HIDEMASK 1
#define HIDEEARS 2 // Headsets and such.
#define HIDEEYES 4 // Glasses.
#define HIDEFACE 8 // Dictates whether we appear as "Unknown".

// Slots.
#define slot_back		TRUE
#define slot_wear_mask   2
#define slot_handcuffed  3
#define slot_l_hand	  4
#define slot_r_hand	  5
#define slot_belt		6
#define slot_wear_id	 7
#define slot_l_ear	   8
#define slot_eyes		9
#define slot_gloves	  10
#define slot_head		11
#define slot_shoes	   12
#define slot_wear_suit   13
#define slot_w_uniform   14
#define slot_l_store	 15
#define slot_r_store	 16
#define slot_s_store	 17
#define slot_in_backpack 18
#define slot_legcuffed   19
#define slot_r_ear	   20
#define slot_legs		21
#define slot_shoulder	22
#define slot_l_arm	   23
#define slot_r_arm	   24
#define slot_accessory   25

#define	R_HAND	0
#define L_HAND	1
#define R_ARM	2
#define L_ARM	3

// Inventory slot strings.
// since numbers cannot be used as associative list keys.
#define slot_back_str		"back"
#define slot_l_hand_str		"slot_l_hand"
#define slot_r_hand_str		"slot_r_hand"
#define slot_w_uniform_str	"w_uniform"
#define slot_shoulder_str		"slot_shoulder"
#define icon_head		"slot_head"
#define slot_head_str		"slot_head"
#define slot_wear_suit_str	"slot_suit"

// Bitflags for clothing parts.
#define HEAD		TRUE
#define FACE		2
#define EYES		4
#define UPPER_TORSO 8
#define LOWER_TORSO 16
#define LEG_LEFT	32
#define LEG_RIGHT   64
#define LEGS		96   //  LEG_LEFT | LEG_RIGHT
#define FOOT_LEFT   128
#define FOOT_RIGHT  256
#define FEET		384  // FOOT_LEFT | FOOT_RIGHT
#define ARM_LEFT	512
#define ARM_RIGHT   1024
#define ARMS		1536 //  ARM_LEFT | ARM_RIGHT
#define HAND_LEFT   2048
#define HAND_RIGHT  4096
#define HANDS	   6144 // HAND_LEFT | HAND_RIGHT
#define FULL_BODY   8191

// Bitflags for the percentual amount of protection a piece of clothing which covers the body part offers.
// Used with human/proc/get_heat_protection() and human/proc/get_cold_protection().
// The values here should add up to TRUE, e.g., the head has 30% protection.
#define THERMAL_PROTECTION_HEAD		0.3
#define THERMAL_PROTECTION_UPPER_TORSO 0.15
#define THERMAL_PROTECTION_LOWER_TORSO 0.15
#define THERMAL_PROTECTION_LEG_LEFT	0.075
#define THERMAL_PROTECTION_LEG_RIGHT   0.075
#define THERMAL_PROTECTION_FOOT_LEFT   0.025
#define THERMAL_PROTECTION_FOOT_RIGHT  0.025
#define THERMAL_PROTECTION_ARM_LEFT	0.075
#define THERMAL_PROTECTION_ARM_RIGHT   0.075
#define THERMAL_PROTECTION_HAND_LEFT   0.025
#define THERMAL_PROTECTION_HAND_RIGHT  0.025

// sdisabilities
#define BLIND TRUE
#define NEARSIGHTED TRUE
#define MUTE  2
#define DEAF  4

// /mob/var/stat things.
#define CONSCIOUS   0
#define UNCONSCIOUS 1
#define DEAD		2

// TDM gamemodes
#define NORMAL		 0
#define COMPETITIVE	 1
#define HARDCORE	 2

#define GAS_O2  (1 << 0)
#define GAS_N2  (1 << 1)
#define GAS_PL  (1 << 2)
#define GAS_CO2 (1 << 3)
#define GAS_N2O (1 << 4)

// Damage things. TODO: Merge these down to reduce on defines.
// Way to waste perfectly good damage-type names (BRUTE) on this... If you were really worried about case sensitivity, you could have just used lowertext(damagetype) in the proc.
#define BRUTE	 "brute"
#define BURN	  "fire"
#define TOX	   "tox"
#define OXY	   "oxy"
#define CLONE	 "clone"
#define HALLOSS   "halloss"

#define CUT	   "cut"
#define BRUISE	"bruise"
#define PIERCE	"pierce"
#define LASER	 "laser"

#define STUN	  "stun"
#define WEAKEN	"weaken"
#define PARALYZE  "paralize"
#define IRRADIATE "irradiate"
#define AGONY	 "agony"	 // Added in PAIN!
#define SLUR	  "slur"
#define STUTTER   "stutter"
#define EYE_BLUR  "eye_blur"
#define DROWSY	"drowsy"
#define POISONOUS	"poisonous"

// I hate adding defines like this but I'd much rather deal with bitflags than lists and string searches.
#define BRUTELOSS TRUE
#define FIRELOSS  2
#define TOXLOSS   4
#define OXYLOSS   8

// Bitflags defining which status effects could be or are inflicted on a mob.
#define CANSTUN	 TRUE
#define CANWEAKEN   2
#define CANPARALYSE 4
#define CANPUSH	 8
#define LEAPING	 16
#define PASSEMOTES  32	// Mob has a cortical borer or holders inside of it that need to see emotes.
#define GODMODE	 4096
#define FAKEDEATH   8192  // Replaces stuff like changeling.changeling_fakedeath.
#define DISFIGURED  16384 // I'll probably move this elsewhere if I ever get wround to writing a bitflag mob-damage system.

// Grab levels.
#define GRAB_PASSIVE	TRUE
#define GRAB_AGGRESSIVE 2
#define GRAB_NECK	   3
#define GRAB_UPGRADING  4
#define GRAB_KILL	   5

// Security levels.
#define SEC_LEVEL_GREEN FALSE
#define SEC_LEVEL_BLUE  TRUE
#define SEC_LEVEL_RED   2
#define SEC_LEVEL_DELTA 3

#define TRANSITIONEDGE 7 // Distance from edge to move to another z-level.

// Invisibility constants.
#define INVISIBILITY_LIGHTING			 20
#define INVISIBILITY_LEVEL_ONE			35
#define INVISIBILITY_LEVEL_TWO			45
#define INVISIBILITY_OBSERVER			 60
#define INVISIBILITY_EYE				  61

#define SEE_INVISIBLE_LIVING			  25
#define SEE_INVISIBLE_OBSERVER_NOLIGHTING 45
#define SEE_INVISIBLE_LEVEL_ONE		   35
#define SEE_INVISIBLE_LEVEL_TWO		   45
#define SEE_INVISIBLE_OBSERVER			25

#define SEE_INVISIBLE_MINIMUM 5
#define INVISIBILITY_MAXIMUM 100

// Object specific defines.
#define CANDLE_LUM 3 // For how bright candles are.

//Some mob defines below
#define AI_CAMERA_LUMINOSITY 6

// Some arbitrary defines to be used by self-pruning global lists. (see master_controller)
#define PROCESS_KILL 26 // Used to trigger removal from a processing list.

#define HOSTILE_STANCE_IDLE	  TRUE
#define HOSTILE_STANCE_ALERT	 2
#define HOSTILE_STANCE_ATTACK	3
#define HOSTILE_STANCE_TIRED	 4

#define ROUNDSTART_LOGOUT_REPORT_TIME 6000 // Amount of time (in deciseconds) after the rounds starts, that the player disconnect report is issued.

// Organ defines.
#define ORGAN_CUT_AWAY   TRUE
#define ORGAN_GAUZED	 2
#define ORGAN_ATTACHABLE 4
#define ORGAN_BLEEDING   8
#define ORGAN_BROKEN	 32
#define ORGAN_DESTROYED  64
#define ORGAN_SPLINTED   256
#define SALVED		   512
#define ORGAN_DEAD	   1024
#define ORGAN_MUTATED	2048
#define ORGAN_ASSISTED   4096
#define ORGAN_ARTERY_CUT 8192

// Preference toggles: these are no longer bitflags, but list items
#define SOUND_ADMINHELP TRUE
#define SOUND_MIDI	  2
#define SOUND_AMBIENCE  4
#define SOUND_LOBBY	 8
#define CHAT_OOC		16
#define CHAT_DEAD	   32
#define CHAT_GHOSTEARS  64
#define CHAT_GHOSTSIGHT 128
#define CHAT_PRAYER	 256
#define CHAT_RADIO	  512
#define CHAT_ATTACKLOGS 1024
#define CHAT_DEBUGLOGS  2048
#define CHAT_LOOC	   4096
#define CHAT_GHOSTRADIO 8192
#define SHOW_TYPING	 16384
#define CHAT_NOICONS	32768

#define TOGGLES_DEFAULT (SOUND_ADMINHELP|SOUND_MIDI|SOUND_AMBIENCE|SOUND_LOBBY|CHAT_OOC|CHAT_DEAD|CHAT_GHOSTEARS|CHAT_GHOSTSIGHT|CHAT_PRAYER|CHAT_RADIO|CHAT_LOOC)


// Age limits on a character.
#define AGE_MIN 12
#define AGE_MAX 75

// Languages.
#define LANGUAGE_HUMAN  TRUE
#define LANGUAGE_DOG	2
#define LANGUAGE_CAT	4
#define LANGUAGE_BINARY 8
#define LANGUAGE_OTHER  32768

#define LANGUAGE_UNIVERSAL 65535

#define LEFT  TRUE
#define RIGHT 2

// Pulse levels, very simplified.
#define PULSE_NONE	FALSE // So !M.pulse checks would be possible.
#define PULSE_SLOW	TRUE // <60	 bpm
#define PULSE_NORM	2 //  60-90  bpm
#define PULSE_FAST	3 //  90-120 bpm
#define PULSE_2FAST   4 // >120	bpm
#define PULSE_THREADY 5 // Occurs during hypovolemic shock
#define GETPULSE_HAND FALSE // Less accurate. (hand)
#define GETPULSE_TOOL TRUE // More accurate. (med scanner, sleeper, etc.)

// Species flags.
#define NO_BLOOD		  TRUE	 // Vessel var is not filled with blood, cannot bleed out.
#define NO_BREATHE		2	 // Cannot suffocate or take oxygen loss.
#define NO_SCAN		   4	 // Cannot be scanned in a DNA machine/genome-stolen.
#define NO_PAIN		   8	 // Cannot suffer halloss/recieves deceptive health indicator.
#define NO_SLIP		   16	// Cannot fall over.
#define NO_POISON		 32	// Cannot not suffer toxloss.
#define HAS_SKIN_TONE	 64	// Skin tone selectable in chargen. (0-255)
#define HAS_SKIN_COLOR	128   // Skin colour selectable in chargen. (RGB)
#define HAS_LIPS		  256   // Lips are drawn onto the mob icon. (lipstick)
#define HAS_UNDERWEAR	 512   // Underwear is drawn onto the mob icon.
#define HAS_HAIR_COLOR	1024   // Hair colour selectable in chargen. (RGB)
#define IS_WHITELISTED	2048  // Must be whitelisted to play.
#define IS_SYNTHETIC	  4096  // Is a machine race.
#define HAS_EYE_COLOR	 8192  // Eye colour selectable in chargen. (RGB)
#define CAN_JOIN		  16384 // Species is selectable in chargen.
#define IS_RESTRICTED	 32768 // Is not a core/normally playable species. (castes, mutantraces)
#define REGENERATES_LIMBS 65536 // Attempts to regenerate unamputated limbs.

//Flags for zone sleeping
#define ZONE_ACTIVE   TRUE
#define ZONE_SLEEPING FALSE


/*
 *	Germs and infections.
*/

#define GERM_LEVEL_AMBIENT  110 // Maximum germ level you can reach by standing still.
#define GERM_LEVEL_MOVE_CAP 200 // Maximum germ level you can reach by running around.

#define INFECTION_LEVEL_ONE   100
#define INFECTION_LEVEL_TWO   500
#define INFECTION_LEVEL_THREE 1000

// Special return values from bullet_act(). Positive return values are already used to indicate the blocked level of the projectile.
#define PROJECTILE_CONTINUE   -1 //if the projectile should continue flying after calling bullet_act()
#define PROJECTILE_FORCE_MISS -2 //if the projectile should treat the attack as a miss (suppresses attack and admin logs) - only applies to mobs.

#define MAX_GEAR_COST 5 // Used in chargen for accessory loadout limit.


// Chemistry.
#define SPEED_OF_LIGHT	   3e8	// Approximate.
#define SPEED_OF_LIGHT_SQ	9e16
#define FIRE_DAMAGE_MODIFIER 0.0215 // Higher values result in more external fire damage to the skin. (default 0.0215)
#define  AIR_DAMAGE_MODIFIER 2.025  // More means less damage from hot air scalding lungs, less = more damage. (default 2.025)
#define INFINITY			 1.#INF

// Setting this much higher than 1024 could allow spammers to DOS the server easily.
#define MAX_MESSAGE_LEN	   1024
#define MAX_PAPER_MESSAGE_LEN 3072
#define MAX_BOOK_MESSAGE_LEN  9216
#define MAX_LNAME_LEN		 64
#define MAX_NAME_LEN		  45 // long german names and stuff

// Event defines.
#define EVENT_LEVEL_MUNDANE  TRUE
#define EVENT_LEVEL_MODERATE 2
#define EVENT_LEVEL_MAJOR	3

// NanoUI flags
#define STATUS_INTERACTIVE 2 // GREEN Visability
#define STATUS_UPDATE TRUE // ORANGE Visability
#define STATUS_DISABLED FALSE // RED Visability
#define STATUS_CLOSE -1 // Close the interface

//General-purpose life speed define for plants.
#define HYDRO_SPEED_MULTIPLIER TRUE

// Appearance change flags
#define APPEARANCE_UPDATE_DNA TRUE
#define APPEARANCE_RACE	(2|APPEARANCE_UPDATE_DNA)
#define APPEARANCE_GENDER (4|APPEARANCE_UPDATE_DNA)
#define APPEARANCE_SKIN 8
#define APPEARANCE_HAIR 16
#define APPEARANCE_HAIR_COLOR 32
#define APPEARANCE_FACIAL_HAIR 64
#define APPEARANCE_FACIAL_HAIR_COLOR 128
#define APPEARANCE_EYE_COLOR 256
#define APPEARANCE_ALL_HAIR (APPEARANCE_HAIR|APPEARANCE_HAIR_COLOR|APPEARANCE_FACIAL_HAIR|APPEARANCE_FACIAL_HAIR_COLOR)
#define APPEARANCE_ALL 511


#define MIN_SUPPLIED_LAW_NUMBER 15
#define MAX_SUPPLIED_LAW_NUMBER 50

//Area flags, possibly more to come
#define RAD_SHIELDED TRUE //shielded from radiation, clearly

//intent flags, why wasn't this done the first time?
#define I_HELP		"help"
#define I_DISARM	"disarm"
#define I_GRAB		"grab"
#define I_HARM		"harm"
#define I_DODGE		"dodge"
#define I_PARRY		"parry"

/*
	These are used Bump() code for living mobs, in the mob_bump_flag, mob_swap_flags, and mob_push_flags vars to determine whom can bump/swap with whom.
*/

#define HUMAN TRUE
#define MONKEY 2
#define SIMPLE_ANIMAL 4
#define HEAVY 8
#define ALLMOBS (HUMAN|MONKEY|SIMPLE_ANIMAL|HEAVY)

#define NEXT_MOVE_DELAY 8

#define DROPLIMB_EDGE 0
#define DROPLIMB_BLUNT 1
#define DROPLIMB_BURN 2


#define WALL_CAN_OPEN TRUE
#define WALL_OPENING 2

//#define Clamp(x, y, z) 	(x <= y ? y : (x >= z ? z : x))

//#define CLAMP01(x) 		(Clamp(x, 0, 1))

#define DEFAULT_WALL_MATERIAL "wood"
#define DEFAULT_TABLE_MATERIAL "wood"

// Convoluted setup so defines can be supplied by Bay12 main server compile script.
// Should still work fine for people jamming the icons into their repo.
#ifndef CUSTOM_ITEM_OBJ
#define CUSTOM_ITEM_OBJ 'icons/obj/custom_items_obj.dmi'
#endif
#ifndef CUSTOM_ITEM_MOB
#define CUSTOM_ITEM_MOB 'icons/mob/custom_items_mob.dmi'
#endif

#define SHARD_SHARD "shard"
#define SHARD_SHRAPNEL "shrapnel"
#define SHARD_STONE_PIECE "piece"
#define SHARD_SPLINTER "splinters"
#define SHARD_NONE ""

#define MATERIAL_UNMELTABLE TRUE
#define MATERIAL_BRITTLE 2
#define MATERIAL_PADDING 4

#define TABLE_BRITTLE_MATERIAL_MULTIPLIER 4 // Amount table damage is multiplied by if it is made of a brittle material (e.g. glass)

#define FOR_DVIEW(type, range, center, invis_flags) \
	dview_mob.loc = center; \
	dview_mob.see_invisible = invis_flags; \
	for (type in view(range, dview_mob))
#define END_FOR_DVIEW dview_mob.loc = null

//Gun loading types
#define SINGLE_CASING 	1	//The gun only accepts ammo_casings. ammo_magazines should never have this as their mag_type.
#define SPEEDLOADER 	2	//Transfers casings from the mag to the gun when used.
#define MAGAZINE 		4	//The magazine item itself goes inside the gun

#define HOLD_CASINGS	0 //do not do anything after firing. Manual action, like pump shotguns, or guns that want to define custom behaviour
#define EJECT_CASINGS	1 //drop spent casings on the ground after firing
#define CYCLE_CASINGS 	2 //experimental: cycle casings, like a revolver. Also works for multibarrelled guns
#define REMOVE_CASINGS	3 //deletes casings

#define list_cmp(l1, l2) (length(l1 & l2) > 0)

#define ZOOM_CONSTANT 7

// Admin permissions.
#define R_BUILDMODE	 0x1
#define R_ADMIN		 0x2
#define R_TRIALADMIN   0x4
#define R_FUN		   0x8
#define R_SERVER		0x10
#define R_DEBUG		 0x20
#define R_POSSESS	   0x40
#define R_PERMISSIONS   0x80
#define R_STEALTH	   0x100
#define R_REJUVINATE	0x200
#define R_VAREDIT	   0x400
#define R_SOUNDS		0x800
#define R_SPAWN		 0x1000
#define R_MOD		   0x2000
#define R_MENTOR		0x4000
#define R_HOST		  0x8000 //higher than this will overflow

#define R_MAXPERMISSION 0x8000 // This holds the maximum value for a permission. It is used in iteration, so keep it updated.

#define SHORT_RANGE_STILL "short_range_still"
#define SHORT_RANGE_MOVING "short_range_moving"

#define MEDIUM_RANGE_STILL "medium_range_still"
#define MEDIUM_RANGE_MOVING "medium_range_moving"

#define LONG_RANGE_STILL "long_range_still"
#define LONG_RANGE_MOVING "long_range_moving"

#define VERY_LONG_RANGE_STILL "very_long_range_still"
#define VERY_LONG_RANGE_MOVING "very_long_range_moving"

#define KD_CHANCE_VERY_LOW 20
#define KD_CHANCE_LOW 40
#define KD_CHANCE_MEDIUM 60
#define KD_CHANCE_HIGH 80