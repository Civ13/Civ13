// These are not flags, binary operations not intended
// Defines moved to __DEFINES/topic.dm


/datum/category_group/player_setup_category/general_preferences
	name = "Character"
	sort_order = 1
	category_item_type = /datum/category_item/player_setup_item/general

/datum/category_group/player_setup_category/global_preferences
	name = "Global"
	sort_order = 2
	category_item_type = /datum/category_item/player_setup_item/player_global

/****************************
* Category Collection Setup *
****************************/
/datum/category_collection/player_setup_collection
	category_group_type = /datum/category_group/player_setup_category
	var/datum/preferences/preferences

/datum/category_collection/player_setup_collection/New(var/datum/preferences/_preferences)
	preferences = _preferences
	..()

/datum/category_collection/player_setup_collection/Destroy()
	preferences = null
	return ..()

/datum/category_collection/player_setup_collection/proc/sanitize_setup()
	for (var/datum/category_group/player_setup_category/PS in categories)
		PS.sanitize_setup()

/datum/category_collection/player_setup_collection/proc/load_character()
	for (var/datum/category_group/player_setup_category/PS in categories)
		PS.load_character()

/datum/category_collection/player_setup_collection/proc/save_character()
	for (var/datum/category_group/player_setup_category/PS in categories)
		PS.save_character()

/datum/category_collection/player_setup_collection/proc/load_preferences()
	for (var/datum/category_group/player_setup_category/PS in categories)
		PS.load_preferences()

/datum/category_collection/player_setup_collection/proc/save_preferences()
	for (var/datum/category_group/player_setup_category/PS in categories)
		PS.save_preferences()

/datum/category_collection/player_setup_collection/proc/update_setup()
	for (var/datum/category_group/player_setup_category/PS in categories)
		. = . && PS.update_setup()

/**************************
* Category Category Setup *
**************************/
/datum/category_group/player_setup_category
	var/sort_order = FALSE

/datum/category_group/player_setup_category/dd_SortValue()
	return sort_order

/datum/category_group/player_setup_category/proc/sanitize_setup()
	for (var/datum/category_item/player_setup_item/PI in items)
		PI.sanitize_preferences()
	for (var/datum/category_item/player_setup_item/PI in items)
		PI.sanitize_character()

/datum/category_group/player_setup_category/proc/load_character()
	// Load all data, then sanitize it.
	// Need due to, for example, the 11_basic module relying on species having been loaded to sanitize correctly but that isn't loaded until module FALSE3_body.
	for (var/datum/category_item/player_setup_item/PI in items)
		PI.load_character()
	for (var/datum/category_item/player_setup_item/PI in items)
		PI.sanitize_character()

/datum/category_group/player_setup_category/proc/save_character()
	// Sanitize all data, then save it
	for (var/datum/category_item/player_setup_item/PI in items)
		PI.sanitize_character()
	for (var/datum/category_item/player_setup_item/PI in items)
		PI.save_character()

/datum/category_group/player_setup_category/proc/load_preferences()
	for (var/datum/category_item/player_setup_item/PI in items)
		PI.load_preferences()
	for (var/datum/category_item/player_setup_item/PI in items)
		PI.sanitize_preferences()

/datum/category_group/player_setup_category/proc/save_preferences()
	for (var/datum/category_item/player_setup_item/PI in items)
		PI.sanitize_preferences()
	for (var/datum/category_item/player_setup_item/PI in items)
		PI.save_preferences()

/datum/category_group/player_setup_category/proc/update_setup()
	for (var/datum/category_item/player_setup_item/PI in items)
		. = . && PI.update_setup()

/**********************
* Category Item Setup *
**********************/
/datum/category_item/player_setup_item
	var/sort_order = FALSE
	var/datum/preferences/pref

/datum/category_item/player_setup_item/New()
	..()
	var/datum/category_collection/player_setup_collection/psc = category.collection
	pref = psc.preferences

/datum/category_item/player_setup_item/Destroy()
	pref = null
	return ..()

/datum/category_item/player_setup_item/dd_SortValue()
	return sort_order

/*
* Called when the item is asked to load per character settings
*/
/datum/category_item/player_setup_item/proc/load_character()
	return

/*
* Called when the item is asked to save per character settings
*/
/datum/category_item/player_setup_item/proc/save_character()
	return

/*
* Called when the item is asked to load user/global settings
*/
/datum/category_item/player_setup_item/proc/load_preferences()
	return

/*
* Called when the item is asked to save user/global settings
*/
/datum/category_item/player_setup_item/proc/save_preferences()
	return

/*
* Called when the item is asked to update user/global settings
*/
/datum/category_item/player_setup_item/proc/update_setup()
	return FALSE

/datum/category_item/player_setup_item/proc/sanitize_character()
	return

/datum/category_item/player_setup_item/proc/sanitize_preferences()
	return

/datum/category_item/player_setup_item/proc/preference_mob()
	if (!pref.client)
		for (var/client/C)
			if (C.ckey == pref.client_ckey)
				pref.client = C
				break

	if (pref.client)
		return pref.client.mob
