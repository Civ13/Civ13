/mob/living/carbon/human

	//Hair colour and style
	var/r_hair = FALSE
	var/g_hair = FALSE
	var/b_hair = FALSE
	var/h_style = "Bald"
	var/h_growth = 0

	//Facial hair colour and style
	var/r_facial = FALSE
	var/g_facial = FALSE
	var/b_facial = FALSE
	var/f_style = "Shaved"
	var/f_growth = 0

	//Eye colour
	var/r_eyes = FALSE
	var/g_eyes = FALSE
	var/b_eyes = FALSE

	var/s_tone = FALSE	//Skin tone

	//Skin colour
	var/r_skin = FALSE
	var/g_skin = FALSE
	var/b_skin = FALSE

	var/size_multiplier = 1.0 //multiplier for the mob's icon size
	var/damage_multiplier = 1.0 //multiplies melee combat damage
	var/icon_update = TRUE //whether icon updating shall take place

	var/datum/body_build/body_build = null

	var/lip_style = null	//no lipstick by default- arguably misleading, as it could be used for general makeup

	var/age = 30		//Player's age (pure fluff)
	var/b_type = "A+"	//Player's bloodtype

	var/list/all_underwear = list()

	//Equipment slots
	var/obj/item/wear_suit = null
	var/obj/item/w_uniform = null
	var/obj/item/shoes = null
	var/obj/item/belt = null
	var/obj/item/gloves = null
	var/obj/item/head = null
	var/obj/item/l_ear = null
	var/obj/item/r_ear = null
	var/obj/item/wear_id = null
	var/obj/item/r_store = null
	var/obj/item/l_store = null

	var/icon/stand_icon = null
	var/icon/lying_icon = null

	var/voice = ""	//Instead of new say code calling GetVoice() over and over and over, we're just going to ask this variable, which gets updated in Life()
	var/sayverb = "says"

	var/speech_problem_flag = FALSE

	var/miming = null //Toggle for the mime's abilities.
	var/special_voice = "" // For changing our voice. Used by a symptom.

	var/last_dam = -1	//Used for determining if we need to process all organs or just some or even none.
	var/list/bad_external_organs = list()// organs we check until they are good.

	var/mob/remoteview_target = null
	var/hand_blood_color

	var/gunshot_residue
	var/pulling_punches // Are you trying not to hurt your opponent?

	mob_bump_flag = HUMAN
	mob_push_flags = ~HEAVY
	mob_swap_flags = ~HEAVY

	var/flash_protection = FALSE				// Total level of flash protection
	var/equipment_tint_total = FALSE			// Total level of visualy impairing items
	var/equipment_darkness_modifier			// Darkvision modifier from equipped items
	var/equipment_vision_flags				// Extra vision flags from equipped items
	var/equipment_see_invis					// Max see invibility level granted by equipped items
	var/equipment_prescription				// Eye prescription granted by equipped items
	var/list/equipment_overlays = list()	// Extra overlays from equipped items

	var/stance_damage = FALSE //Whether this mob's ability to stand has been affected

	var/list/all_factions = list()
	var/datum/faction/base_faction = null
	var/datum/faction/squad/squad_faction = null
	var/faction_text = null

	var/list/faction_images[100] // names are keys, values are images


	var/embedded_flag	  //To check if we've need to roll for damage on movement while an item is imbedded in us.
	var/obj/item/weapon/rig/wearing_rig // This is very not good, but it's much much better than calling get_rig() every update_canmove() call.

	var/list/hud_list[200]

	var/job_spawn_location = null // used to override job.spawn_location for a single mob

	var/shoveling_snow = FALSE
	var/shoveling_dirt = FALSE
	var/shoveling_sand = FALSE
	var/buriedalive = FALSE

	var/circumcised = FALSE
	var/ptsd = 0
	var/hygiene = 200
	var/mood_modifier = 1
	var/surrendered = FALSE

	var/werewolf = FALSE
	var/gorillaman = FALSE
	var/ant = FALSE
	var/orc = FALSE
	var/lizard = FALSE
	var/wolfman = FALSE
	var/crab = FALSE

	/* These are stats. They affect how fast and how well you can do certain
	 * actions. All stats have a min (stats[stat][1]) and a max (stats[stat][2]),
	 * but currently no stats 'deteriorate' (in the future strength will),
	 * so stats will remain the same over the entire round. */

	/* All stat names (here) MUST be lowercase. */

	var/list/stats = list(
		"strength" = list(100,100),
		"crafting" = list(100,100),
		"rifle" = list(100,100),
		"dexterity" = list(100,100),
		"swords" = list(100,100),
		"pistol" = list(100,100),
		"bows" = list(100,100),
		"medical" = list(100,100),
		"philosophy" = list(100,100),
		"mg" = list(100,100),
		"stamina" = list(100,100))

	var/has_hunger_and_thirst = TRUE

	var/has_pain = TRUE

	var/stopDumbDamage = FALSE

	var/partial_languages[0]

	var/debugmob = FALSE

	var/next_footstep_sound_at_movement_tick = -1

	var/never_set_faction_huds = TRUE

	var/life_hud_check = list(
		"stat" = -1,
		"health" = -1)

	var/disease = FALSE
	var/disease_type = "none"
	var/disease_progression = 0
	var/disease_treatment = 0

	var/list/disease_immunity = list()

//	drug addiction works on a scale of 0 to 100.
//	Every dose increases the meter. It will slowly go down, but high values will give you withdrawal symptoms,
//	if you dont have that reagent in your blood.

	var/civilization = "none" //what civilization this person belongs to
	var/leader = FALSE
	//leadership (total control!), announcement, give titles, recruitment
	var/list/faction_perms = list(0,0,0,0)
	var/title = ""
	var/announcement_cooldown = 0

	var/religion = "none" //what religion this person belongs to
	var/religion_type = "none"
	var/religion_style = "none"
	var/religious_leader = FALSE
	var/religious_clergy = FALSE

	var/inducedSSD = FALSE
	var/lastx = 0
	var/lasty = 0
	var/lastz = 0

	var/driver = FALSE
	var/obj/structure/vehicle/driver_vehicle = null
	var/riding = FALSE // if riding a horse
	var/mob/living/simple_animal/riding_mob = null