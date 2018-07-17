/datum/job

	//The name of the job
	var/title = "generic job"
	//English meaning of this job's title, if applicable
	var/en_meaning = ""
	var/faction = "None"	              // Players will be allowed to spawn in as jobs that are set to "Station"

	var/total_positions = FALSE               // How many players can be this job
	//var/spawn_positions = FALSE               // How many players can spawn in as this job
	var/current_positions = FALSE             // How many players have this job
	var/selection_color = "#ffffff"       // Selection screen color
	var/list/alt_titles                   // List of alternate titles, if any
	var/req_admin_notify                  // If this is set to TRUE, a text is printed to the player when jobs are assigned, telling him that he should let admins know that he has to disconnect.
	var/minimal_player_age = FALSE            // If you have use_age_restriction_for_jobs config option enabled and the database set up, this option will add a requirement for players to be at least minimal_player_age days old. (meaning they first signed in at least that many days before.)
	var/department = null                 // Does this position have a department tag?
	var/head_position = FALSE                 // Is this position Command?
	var/minimum_character_age = FALSE
	var/ideal_character_age = 30
	var/account_allowed = TRUE				  // Does this job type come with a station account?
	var/economic_modifier = 2			  // With how much does this job modify the initial account amount?
	var/survival_gear = /obj/item/weapon/storage/box/survival// Custom box for spawn in backpack

	//job equipment
	var/uniform = /obj/item/clothing/under/color/grey
	var/shoes = /obj/item/clothing/shoes/black
	var/hat = null
	var/suit = null
	var/gloves = null
	var/mask = null
	var/belt = null
	var/ear = null
	var/hand = null
	var/glasses = null
	var/suit_store = null

	var/list/backpacks = list(
		/obj/item/weapon/storage/backpack,
		/obj/item/weapon/storage/backpack/satchel_norm,
		/obj/item/weapon/storage/backpack/satchel
		)

	//This will be put in backpack. List ordered by priority!
	var/list/put_in_backpack = list()
	var/spawn_location = null

	var/uses_keys = TRUE

	var/enabled = TRUE

	/*For copy-pasting:
	implanted =
	uniform =
	pda =
	ear =
	shoes =
	suit =
	suit_store =
	gloves =
	mask =
	belt =
	hand =
	glasses =
	hat =

	put_in_backpack = list(

		)

	backpacks = list(
		/obj/item/weapon/storage/backpack,
		/obj/item/weapon/storage/backpack/satchel_norm,
		/obj/item/weapon/storage/backpack/satchel
		)
	*/

/datum/job/proc/give_random_name(var/mob/living/carbon/human/H)
	return FALSE

/datum/job/proc/train_check()
	return TRUE

/datum/job/proc/get_keys()
	return list()

/datum/job/proc/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

	//Put items in hands
	if (hand) H.equip_to_slot_or_del(new hand (H), slot_l_hand)

	//Put items in backpack
	if ( H.backbag != TRUE )
		var/backpack = backpacks[H.backbag-1]
		var/obj/item/weapon/storage/backpack/BPK = new backpack(H)
		if (H.equip_to_slot_or_del(BPK, slot_back,1))
			new survival_gear(BPK)
			for ( var/path in put_in_backpack )
				new path(BPK)

	//Survival equipment


	//No-check items (suits, gloves, etc)
	if (ear)			H.equip_to_slot_or_del(new ear (H), slot_l_ear)
	if (shoes)		H.equip_to_slot_or_del(new shoes (H), slot_shoes)
	if (uniform)		H.equip_to_slot_or_del(new uniform (H), slot_w_uniform)
	if (suit)		H.equip_to_slot_or_del(new suit (H), slot_wear_suit)
	if (suit_store)	H.equip_to_slot_or_del(new suit_store (H), slot_s_store)
	if (mask)		H.equip_to_slot_or_del(new mask (H), slot_wear_mask)
	if (hat)			H.equip_to_slot_or_del(new hat (H), slot_head)
	if (gloves)		H.equip_to_slot_or_del(new gloves (H), slot_gloves)
	if (glasses)		H.equip_to_slot_or_del(new glasses (H), slot_glasses)
	if (belt)		H.equip_to_slot_or_del(new belt (H), slot_belt)

	if (!H.back || !istype(H.back, /obj/item/weapon/storage/backpack))
		var/list/slots = list( slot_belt, slot_r_store, slot_l_store, slot_r_hand, slot_l_hand, slot_s_store )
		for ( var/path in put_in_backpack )
			if ( !slots.len ) break
			var/obj/item/I = new path(H)
			for ( var/slot in slots )
				if ( H.equip_to_slot_if_possible(I, slot, FALSE, TRUE, FALSE) )
					slots -= slot
					break
			if (istype(H.r_hand,/obj/item/weapon/storage))
				new path(H.r_hand)
			else if (istype(H.l_hand, /obj/item/weapon/storage))
				new path(H.l_hand)

	update_character(H)

	return TRUE

/datum/job/proc/update_character(var/mob/living/carbon/human/H)
	return TRUE

/datum/job/proc/get_access()
	return list()

//If the configuration option is set to require players to be logged as old enough to play certain jobs, then this proc checks that they are, otherwise it just returns TRUE
/datum/job/proc/player_old_enough(client/C)
	return (available_in_days(C) == FALSE) //Available in FALSE days = available right now = player is old enough to play.

/datum/job/proc/available_in_days(client/C)
/*	if (C && config.use_age_restriction_for_jobs && isnum(C.player_age) && isnum(minimal_player_age))
		return max(0, minimal_player_age - C.player_age)*/
	return FALSE

/datum/job/proc/apply_fingerprints(var/mob/living/carbon/human/target)
	if (!istype(target))
		return FALSE
	for (var/obj/item/item in target.contents)
		apply_fingerprints_to_item(target, item)
	return TRUE

/datum/job/proc/apply_fingerprints_to_item(var/mob/living/carbon/human/holder, var/obj/item/item)
	item.add_fingerprint(holder,1)
	if (item.contents.len)
		for (var/obj/item/sub_item in item.contents)
			apply_fingerprints_to_item(holder, sub_item)

/datum/job/proc/is_position_available(var/list/restricted_choices, var/list/people_in_join_queue)
	if ((!restricted_choices || restricted_choices.len == 0) && (!people_in_join_queue || people_in_join_queue.len == FALSE))
		return (current_positions < total_positions) || (total_positions == -1)
	else
		var/subtract_positions = 0
		for (var/_title in restricted_choices)
			if (_title == title)
				subtract_positions++
		for (var/mob/new_player/player in people_in_join_queue)
			if (player.desired_job == title)
				subtract_positions++

		if (total_positions == -1)
			return TRUE
		else
			return (current_positions-subtract_positions < total_positions)