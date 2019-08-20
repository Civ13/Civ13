/datum/job/var/allow_spies = FALSE
/datum/job/var/is_officer = FALSE
/datum/job/var/is_squad_leader = FALSE
/datum/job/var/is_commander = FALSE
/datum/job/var/is_petty_commander = FALSE
/datum/job/var/is_nonmilitary = FALSE
/datum/job/var/spawn_delay = FALSE
/datum/job/var/delayed_spawn_message = ""
/datum/job/var/is_primary = TRUE
/datum/job/var/is_secondary = FALSE
/datum/job/var/is_deathmatch = FALSE
/datum/job/var/blacklisted = FALSE
/datum/job/var/whitelisted = FALSE
/datum/job/var/is_target = FALSE //for VIP modes
/datum/job/var/rank_abbreviation = null
/datum/job/var/is_governor = FALSE
/datum/job/var/is_merchant = FALSE
/datum/job/var/is_religious = FALSE
/datum/job/var/is_RP = FALSE //to enable civilian jobs per faction
/datum/job/var/is_army = FALSE //land troops
/datum/job/var/is_marooned = FALSE //marooned pirate
/datum/job/var/is_medieval = FALSE //self explanatory
/datum/job/var/is_crusader = FALSE //self explanatory
/datum/job/var/is_nomad = FALSE //self explanatory
/datum/job/var/is_gladiator = FALSE
/datum/job/var/is_civilizations = FALSE //if the job is for civilization maps
/datum/job/var/is_cowboy = FALSE
/datum/job/var/is_ww1 = FALSE
/datum/job/var/is_ww2 = FALSE
/datum/job/var/is_reichstag = FALSE
/datum/job/var/is_coldwar = FALSE
/datum/job/var/is_radioman = FALSE
/datum/job/var/is_specops = FALSE
/datum/job/var/is_modernday = FALSE
/datum/job/var/is_rcw = FALSE
/datum/job/var/can_get_coordinates = FALSE
// new autobalance stuff - Kachnov
/datum/job/var/min_positions = 1 // absolute minimum positions if we reach player threshold
/datum/job/var/max_positions = 1 // absolute maximum positions if we reach player threshold
/datum/job/var/player_threshold = 0 // number of players who have to be on for this job to be open
/datum/job/var/scale_to_players = 50 // as we approach this, our open positions approach max_positions. Does nothing if min_positions == max_positions, so just don't touch it

/* type_flag() replaces flag, and base_type_flag() replaces department_flag
 * this is a better solution than bit constants, in my opinion */

/datum/job
	var/_base_type_flag = -1

/datum/job/proc/specialcheck()
	return TRUE

/datum/job/proc/type_flag()
	return "[type]"

/datum/job/proc/base_type_flag(var/most_specific = FALSE)

	if (_base_type_flag != -1)
		return _base_type_flag

	else if (istype(src, /datum/job/pirates))
		. = PIRATES
	else if (istype(src, /datum/job/civilian))
		. = CIVILIAN
	else if (istype(src, /datum/job/british))
		. = BRITISH
	else if (istype(src, /datum/job/french))
		. = FRENCH
	else if (istype(src, /datum/job/portuguese))
		. = PORTUGUESE
	else if (istype(src, /datum/job/spanish))
		. = SPANISH
	else if (istype(src, /datum/job/indians))
		. = INDIANS
	else if (istype(src, /datum/job/dutch))
		. = DUTCH
	else if (istype(src, /datum/job/japanese))
		. = JAPANESE
	else if (istype(src, /datum/job/russian))
		. = RUSSIAN
	else if (istype(src, /datum/job/roman))
		. = ROMAN
	else if (istype(src, /datum/job/german))
		. = GERMAN
	else if (istype(src, /datum/job/greek))
		. = GREEK
	else if (istype(src, /datum/job/arab))
		. = ARAB
	else if (istype(src, /datum/job/american))
		. = AMERICAN
	else if (istype(src, /datum/job/vietnamese))
		. = VIETNAMESE
	_base_type_flag = .
	return _base_type_flag

/datum/job/proc/get_side_name()
	return capitalize(lowertext(base_type_flag()))

/datum/job/proc/assign_faction(var/mob/living/carbon/human/user)

	if (istype(src, /datum/job/pirates))
		user.faction_text = "PIRATES"
		user.base_faction = new/datum/faction/pirates(user, src)
	else if (istype(src, /datum/job/british))
		user.faction_text = "BRITISH"
		user.base_faction = new/datum/faction/british(user, src)
	else if (istype(src, /datum/job/portuguese))
		user.faction_text = "PORTUGUESE"
		user.base_faction = new/datum/faction/portuguese(user, src)
	else if (istype(src, /datum/job/french))
		user.faction_text = "FRENCH"
		user.base_faction = new/datum/faction/french(user, src)
	else if (istype(src, /datum/job/spanish))
		user.faction_text = "SPANISH"
		user.base_faction = new/datum/faction/spanish(user, src)
	else if (istype(src, /datum/job/indians))
		user.faction_text = "INDIANS"
		user.base_faction = new/datum/faction/indians(user, src)
	else if (istype(src, /datum/job/dutch))
		user.faction_text = "DUTCH"
		user.base_faction = new/datum/faction/dutch(user, src)
	else if (istype(src, /datum/job/japanese))
		user.faction_text = "JAPANESE"
		user.base_faction = new/datum/faction/japanese(user, src)
	else if (istype(src, /datum/job/russian))
		user.faction_text = "RUSSIAN"
		user.base_faction = new/datum/faction/russian(user, src)
	else if (istype(src, /datum/job/civilian))
		user.faction_text = "CIVILIAN"
		user.base_faction = new/datum/faction/civilian(user, src)
	else if (istype(src, /datum/job/roman))
		user.faction_text = "ROMAN"
		user.base_faction = new/datum/faction/roman(user, src)
	else if (istype(src, /datum/job/greek))
		user.faction_text = "GREEK"
		user.base_faction = new/datum/faction/greek(user, src)
	else if (istype(src, /datum/job/arab))
		user.faction_text = "ARAB"
		user.base_faction = new/datum/faction/arab(user, src)
	else if (istype(src, /datum/job/german))
		user.faction_text = "GERMAN"
		user.base_faction = new/datum/faction/german(user, src)
	else if (istype(src, /datum/job/american))
		user.faction_text = "AMERICAN"
		user.base_faction = new/datum/faction/american(user, src)
	else if (istype(src, /datum/job/vietnamese))
		user.faction_text = "VIETNAMESE"
		user.base_faction = new/datum/faction/vietnamese(user, src)
/datum/job/proc/opposite_faction_name()
	if (istype(src, /datum/job/pirates))
		return "British Empire"
	else
		return "Pirate crew"
		/*

*/
/proc/get_side_name(var/side, var/datum/job/j)
	if (side == BRITISH)
		return "British Empire"
	if (side == PIRATES)
		return "Pirate crew"
	return null

/datum/job/update_character(var/mob/living/carbon/human/H)
	..()
	if (is_officer || can_get_coordinates)
		H.make_artillery_officer()
		H.add_note("Officer", "As an officer, you can check coordinates.</span>")
	if (is_commander && map.ordinal_age < 5)
		H.make_commander()
	if (is_radioman)
		H.make_artillery_radioman()
		H.add_note("Radio Operator", "As a radio operator, you can order air strikes on your commander's provided coordinates.</span>")

	// hack to make scope icons immediately appear - Kachnov
	spawn (20)
		for (var/obj/item/weapon/gun/G in H.contents)
			if (list(H.l_hand, H.r_hand).Find(G))
				for (var/obj/item/weapon/attachment/scope/S in G.contents)
					if (S.azoom)
						S.azoom.Grant(H)
		for (var/obj/item/weapon/attachment/scope/S in H.contents)
			if (list(H.l_hand, H.r_hand).Find(S))
				if (S.azoom)
					S.azoom.Grant(H)