
/mob
	density = TRUE
	layer = 4.0
	animate_movement = 2
	flags = PROXMOVE

	var/last_movement = -1
	var/movement_speed_multiplier = 1.0
	var/atom/movable/attached_to_object = null

	var/datum/mind/mind

	var/lastKnownIP = null
	var/lastKnownCID = null
	var/lastKnownCkey = null

	var/computer_id = null

	var/stat = FALSE //Whether a mob is alive or dead. TODO: Move this to living - Nodrak

//	var/obj/screen/flash = null
//	var/obj/screen/blind = null
	var/obj/screen/hands = null
	var/obj/screen/pullin = null
	var/obj/screen/purged = null
//	var/obj/screen/internals = null
//	var/obj/screen/oxygen = null
	var/obj/screen/i_select = null
	var/obj/screen/m_select = null
//	var/obj/screen/toxin = null
//	var/obj/screen/fire = null
/*	var/obj/screen/bodytemp = null
	var/obj/screen/healths = null
	var/obj/screen/throw_icon = null
	var/obj/screen/nutrition_icon = null
	var/obj/screen/pressure = null
	//var/obj/screen/damageoverlay = null
	var/obj/screen/pain = null
	var/obj/screen/gun/item/item_use_icon = null
	var/obj/screen/gun/radio/radio_use_icon = null
	var/obj/screen/gun/move/gun_move_icon = null
	var/obj/screen/gun/run/gun_run_icon = null
	var/obj/screen/gun/mode/gun_setting_icon = null*/

	//spells hud icons - this interacts with add_spell and remove_spell
	var/list/obj/screen/movable/spell_master/spell_masters = null

	/*A bunch of this stuff really needs to go under their own defines instead of being globally attached to mob.
	A variable should only be globally attached to turfs/objects/whatever, when it is in fact needed as such.
	The current method unnecessarily clusters up the variable list, especially for humans (although rearranging won't really clean it up a lot but the difference will be noticable for other mobs).
	I'll make some notes on where certain variable defines should probably go.
	Changing this around would probably require a good look-over the pre-existing code.
	*/
	var/obj/screen/zone_sel/zone_sel = null

	var/use_me = TRUE //Allows all mobs to use the me verb by default, will have to manually specify they cannot
	var/damageoverlaytemp = FALSE
	var/atom/movable/using_object = null
//	var/obj/machinery/machine = null
	var/poll_answer = 0.0
	var/sdisabilities = FALSE	//Carbon
	var/disabilities = FALSE	//Carbon

	var/atom/movable/pulling = null
	var/other_mobs = null
	var/next_move = null
	var/transforming = null	//Carbon
	var/hand = null
	var/real_name = null

	var/bhunger = FALSE			//Carbon
	var/ajourn = FALSE
	var/seer = FALSE //for cult//Carbon, probably Human

	var/druggy = FALSE			//Carbon
	var/confused = FALSE		//Carbon
	var/sleeping = FALSE		//Carbon
	var/resting = FALSE			//Carbon

	var/nvg = FALSE
	var/thermal = FALSE

	var/lying = FALSE
	var/prone = FALSE
	var/lying_prev = FALSE
	var/canmove = TRUE
	//Allows mobs to move through dense areas without restriction. For instance, in space or out of holder objects.
	var/incorporeal_move = FALSE //0 is off, TRUE is normal, 2 is for ninjas.
	var/
	var/list/pinned = list()            // List of things pinning this creature to walls (see living_defense.dm)
	var/list/embedded = list()          // Embedded items, since simple mobs don't have organs.
	var/list/languages = list()         // For speaking/listening.
	var/list/speak_emote = list("says") // Verbs used when speaking. Defaults to 'say' if speak_emote is null.
	var/emote_type = TRUE		// Define emote default type, TRUE for seen emotes, 2 for heard emotes
	var/facing_dir = null   // Used for the ancient art of moonwalking.

	var/name_archive //For admin things like possession

	var/timeofdeath = 0.0

	var/bodytemperature = 310.055	//98.7 F
	var/old_x = FALSE
	var/old_y = FALSE

	var/shakecamera = FALSE
	var/a_intent = I_HELP//Living
	var/defense_intent = I_DODGE//Living. For dodging and parrying.
	var/m_intent = "walk"//Living
	var/obj/buckled = null//Living
	var/middle_click_intent = "kick" //For doing different things with middle click.
	var/obj/item/shoulder = null//Living
	var/obj/item/eyes = null//Living
	var/obj/item/l_hand = null//Living
	var/obj/item/r_hand = null//Living
	var/obj/item/weapon/back = null//Human/Monkey
	var/obj/item/weapon/storage/s_active = null//Carbon
	var/obj/item/clothing/mask/wear_mask = null//Carbon

	var/datum/hud/hud_used = null

	var/list/grab_list = list()
	var/list/grabbed_by = list()
	var/list/requests = list()

	var/in_throw_mode = FALSE

	var/inertia_dir = FALSE

	var/targeted_organ = "chest"

//	var/job = null//Living

	// Job information: this goes here because it copies the mind.assigned_job
	// from a new_player mob
	var/datum/job/original_job
	var/original_job_title = "Sailor"
	var/special_job_title = -1

	var/can_pull_size = 10              // Maximum w_class the mob can pull.
	var/can_pull_mobs = MOB_PULL_LARGER // Whether or not the mob can pull other mobs.

	var/datum/dna/dna = null//Carbon
	var/list/active_genes=list()
	var/list/mutations = list() //Carbon -- Doohl
	//see: setup.dm for list of mutations

	var/radiation = 0.0//Carbon

	var/voice_name = "unidentifiable voice"

	var/faction = "neutral" //Used for checking whether hostile simple animals will attack you, possibly more stuff later
	var/captured = FALSE //Functionally, should give the same effect as being buckled into a chair when true.

	var/blinded = null
	var/ear_deaf = null		//Carbon

//The last mob/living/carbon to push/drag/grab this mob (mostly used by slimes friend recognition)
	var/mob/living/carbon/LAssailant = null

//Wizard mode, but can be used in other modes thanks to the brand new "Give Spell" badmin button
	var/spell/list/spell_list = list()

	mouse_drag_pointer = MOUSE_ACTIVE_POINTER
	mouse_drop_pointer = MOUSE_ACTIVE_POINTER
	mouse_drop_zone = TRUE

	var/update_icon = TRUE //Set to TRUE to trigger update_icons() at the next life() call

	var/status_flags = CANSTUN|CANWEAKEN|CANPARALYSE|CANPUSH	//bitflags defining which status effects can be inflicted (replaces canweaken, canstun, etc)

	var/area/lastarea = null

	var/obj/control_object //Used by admins to possess objects. All mobs should have this var

	//Whether or not mobs can understand other mobtypes. These stay in /mob so that ghosts can hear everything.
	var/universal_speak = FALSE // Set to TRUE to enable the mob to speak to everyone -- TLE
	var/universal_understand = FALSE // Set to TRUE to enable the mob to understand everyone, not necessarily speak

	//If set, indicates that the client "belonging" to this (clientless) mob is currently controlling some other mob
	//so don't treat them as being SSD even though their client var is null.
	var/mob/teleop = null

	var/turf/listed_turf = null  	//the current turf being examined in the stat panel
	var/list/shouldnt_see = list()	//list of objects that this mob shouldn't see in the stat panel. this silliness is needed because of AI alt+click and cult blood runes

	var/mob_size = MOB_MEDIUM

	var/paralysis = FALSE
	var/stunned = FALSE
	var/weakened = FALSE
	var/drowsyness = 0.0//Carbon

	var/memory = ""
	var/flavor_text = ""


	var/list/HUDneed = list() // What HUD object need see
	var/list/HUDinventory = list()
	var/list/HUDfrippery = list()//свестелки и перделки
	var/list/HUDprocess = list() //What HUD object need process
	var/list/HUDtech = list()
	var/defaultHUD = "" //Default mob hud

	var/scrambling = FALSE //For crawling.
	var/has_limbs = TRUE //Whether this mob have any limbs he can move with

	var/roundUID = 0

/mob/proc/getRoundUID(var/text = FALSE)
	if (!roundUID)
		roundUID = rand(1, 10000000)
	if (text)
		return num2text(roundUID, 20)
	else
		return roundUID