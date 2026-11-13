// ============================================================
// The Ides of March
// ------------------------------------------------------------
// Caesar and his friends against the senators who mean to kill him.
// Everyone wears the toga; the conspirators carry a pugio out of sight.
// The map and win condition are in map_metadata/ides_of_march.dm.
// ============================================================

/obj/item/weapon/material/kitchen/utensil/knife/dagger/iron/pugio
	name = "pugio"
	desc = "A short Roman dagger, small enough to carry hidden under a toga."

// Toga, sandals and Latin, shared by every role on both sides.
/proc/ides_dress(mob/living/human/H, toga_type = /obj/item/clothing/under/toga)
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/roman(H), slot_shoes)
	H.equip_to_slot_or_del(new toga_type(H), slot_w_uniform)
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_NORMAL)

/proc/ides_add_caesar(mob/living/human/H)
	if (map && map.ID == MAP_IDES_OF_MARCH)
		var/obj/map_metadata/ides_of_march/IM = map
		IM.caesars |= H

// ------------------------------------------------------------
// Caesar's party
// ------------------------------------------------------------

/datum/job/roman/ides
	title = "Ides of March (DO NOT USE)"
	allowed_maps = list()
	spawn_location = "JoinLateIdesCaesar"

/datum/job/roman/ides/caesar
	title = "Dictator"
	en_meaning = "Gaius Julius Caesar"
	rank_abbreviation = ""
	allowed_maps = list(MAP_IDES_OF_MARCH)
	is_officer = TRUE
	is_commander = TRUE
	min_positions = 1
	max_positions = 1

/datum/job/roman/ides/caesar/give_random_name(var/mob/living/human/H)
	H.name = "Gaius Julius Caesar"
	H.real_name = H.name

/datum/job/roman/ides/caesar/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	ides_dress(H, /obj/item/clothing/under/custom/toga/purple)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/laurelcrown/gold(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/dagger/iron/pugio(H), slot_r_store)
	H.add_note("Role", "You are <b>Gaius Julius Caesar</b>, Dictator of Rome. There are whispers of a plot among the senators. Stay alive until the day is out, and trust your lictors and friends.")
	give_random_name(H)
	ides_add_caesar(H)
	return TRUE

/datum/job/roman/ides/lictor
	title = "Lictor"
	en_meaning = "Caesar's Bodyguard"
	rank_abbreviation = ""
	allowed_maps = list(MAP_IDES_OF_MARCH)
	is_squad_leader = FALSE
	min_positions = 4
	max_positions = 24

/datum/job/roman/ides/lictor/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	ides_dress(H)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/quarterstaff(H), slot_r_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/dagger/iron/pugio(H), slot_r_store)
	H.add_note("Role", "You are a <b>Lictor</b>, one of Caesar's attendants. Your rods clear his way. Keep the knives away from him.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	give_random_name(H)
	return TRUE

/datum/job/roman/ides/friend
	title = "Amicus Caesaris"
	en_meaning = "Caesar's Friend"
	rank_abbreviation = ""
	allowed_maps = list(MAP_IDES_OF_MARCH)
	min_positions = 4
	max_positions = 100

/datum/job/roman/ides/friend/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	ides_dress(H)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/dagger/iron/pugio(H), slot_r_store)
	H.add_note("Role", "You are a friend of Caesar. Stay at his side, and give your life for his if it comes to that.")
	give_random_name(H)
	return TRUE

// ------------------------------------------------------------
// The conspirators
// ------------------------------------------------------------

/datum/job/civilian/ides
	title = "Conspirator (DO NOT USE)"
	allowed_maps = list()
	spawn_location = "JoinLateIdesSenate"
	default_language = "Latin"
	additional_languages = list()

/datum/job/civilian/ides/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_roman_name()
	H.real_name = H.name

/datum/job/civilian/ides/brutus
	title = "Praetor"
	en_meaning = "Marcus Junius Brutus"
	rank_abbreviation = ""
	allowed_maps = list(MAP_IDES_OF_MARCH)
	is_officer = TRUE
	is_commander = TRUE
	min_positions = 1
	max_positions = 1

/datum/job/civilian/ides/brutus/give_random_name(var/mob/living/human/H)
	H.name = "Marcus Junius Brutus"
	H.real_name = H.name

/datum/job/civilian/ides/brutus/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	ides_dress(H, /obj/item/clothing/under/toga2)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/dagger/iron/pugio(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/dagger/iron/pugio(H), slot_l_store)
	H.add_note("Role", "You are <b>Marcus Junius Brutus</b>. Caesar will make himself king unless he is stopped today. Lead the senators: your daggers are hidden in your toga until you draw them.")
	H.setStat("swords", STAT_HIGH)
	give_random_name(H)
	return TRUE

/datum/job/civilian/ides/senator
	title = "Senator"
	en_meaning = "Conspirator"
	rank_abbreviation = ""
	allowed_maps = list(MAP_IDES_OF_MARCH)
	min_positions = 6
	max_positions = 100

/datum/job/civilian/ides/senator/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	ides_dress(H, /obj/item/clothing/under/toga2)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/dagger/iron/pugio(H), slot_r_store)
	H.add_note("Role", "You are a <b>Senator</b> sworn to the plot against Caesar. Your pugio is hidden in your toga. Strike when he is within reach.")
	give_random_name(H)
	return TRUE
