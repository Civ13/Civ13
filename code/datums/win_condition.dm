/datum/win_condition
	var/hash = 0

/datum/win_condition/proc/check(var/list/areas, var/list/attackers, var/list/defenders, threshold = 1.0, sethash = FALSE)

	if (sethash)
		set_hash(areas, attackers, defenders, threshold)

	var/attacker_count = 0
	var/defender_count = 0

	for (var/human in human_mob_list)
		var/mob/living/carbon/human/H = human
		if (H.original_job && H.client && H.stat == CONSCIOUS && !H.lying && !H.restrained() && !iscloset(H.loc))
			var/area/H_area = get_area(H)
			if (H_area && area_check(H_area, areas))
				if (attackers.Find(H.original_job.base_type_flag()))
					++attacker_count
				else if (defenders.Find(H.original_job.base_type_flag()))
					++defender_count

	var/coeff = 1.0
	if (!defender_count)
		if (!attacker_count)
			coeff = 1.0
		else if (attacker_count)
			coeff = INFINITY
	else
		coeff = attacker_count/defender_count

	if (coeff >= threshold)
		return TRUE

	return FALSE

/datum/win_condition/proc/area_check(var/area/A, areas)
	for (var/area_path in areas)
		if (istype(A, area_path))
			if (A.capturable)
				return TRUE
	return FALSE

/datum/win_condition/proc/set_hash(var/list/areas, var/list/attackers, var/list/defenders, threshold = 1.0)
	hash = ""
	for (var/area_path in areas) // this is not necessarily a path but path2text() works anyway
		hash = "[.][path2text(area_path)]|"
	for (var/attacker in attackers)
		hash = "[.][attacker]|"
	for (var/defender in defenders)
		hash = "[.][defenders]|"
	hash = "[.][threshold]"
	return hash