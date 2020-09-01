/proc/get_job_datums()
	var/list/occupations = list()
	var/list/all_jobs = typesof(/datum/job)

	for (var/A in all_jobs)
		var/datum/job/job = new A()
		if (!job)	continue
		occupations += job

	return occupations

/datum/job

	//The name of the job
	var/title = "generic job"
	//English meaning of this job's title, if applicable
	var/en_meaning = ""
	var/faction = "None"				  // Players will be allowed to spawn in as jobs that are set to "Human"

	var/total_positions = FALSE			   // How many players can be this job
	var/current_positions = FALSE			 // How many players have this job
	var/selection_color = "#404040"	   // Selection screen color

	var/spawn_location = null

	var/enabled = TRUE

/datum/job/proc/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_english_name(H.gender)
	H.real_name = H.name
	return FALSE

/datum/job/proc/get_keys()
	return list()

/datum/job/proc/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	update_character(H)
	return TRUE

/datum/job/proc/update_character(var/mob/living/human/H)
	return TRUE

/datum/job/proc/apply_fingerprints(var/mob/living/human/target)
	if (!istype(target))
		return FALSE
	for (var/obj/item/item in target.contents)
		apply_fingerprints_to_item(target, item)
	return TRUE

/datum/job/proc/apply_fingerprints_to_item(var/mob/living/human/holder, var/obj/item/item)
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