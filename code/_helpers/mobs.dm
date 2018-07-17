/atom/movable/proc/get_mob()
	return

/obj/vehicle/train/get_mob()
	return buckled_mob

/mob/get_mob()
	return src

/proc/mobs_in_view(var/range, var/source)
	var/list/mobs = list()
	for (var/atom/movable/AM in view(range, source))
		var/M = AM.get_mob()
		if (M)
			mobs += M

	return mobs

proc/random_hair_style(gender, species = "Human")
	var/h_style = "Bald"

	var/list/valid_hairstyles = list()
	for (var/hairstyle in hair_styles_list)
		var/datum/sprite_accessory/S = hair_styles_list[hairstyle]
		if (gender == MALE && S.gender == FEMALE)
			continue
		if (gender == FEMALE && S.gender == MALE)
			continue
		if ( !(species in S.species_allowed))
			continue
		valid_hairstyles[hairstyle] = hair_styles_list[hairstyle]

	if (valid_hairstyles.len)
		h_style = pick(valid_hairstyles)

	return h_style

proc/random_facial_hair_style(gender, species = "Human")
	var/f_style = "Shaved"

	var/list/valid_facialhairstyles = list()
	for (var/facialhairstyle in facial_hair_styles_list)
		var/datum/sprite_accessory/S = facial_hair_styles_list[facialhairstyle]
		if (gender == MALE && S.gender == FEMALE)
			continue
		if (gender == FEMALE && S.gender == MALE)
			continue
		if ( !(species in S.species_allowed))
			continue

		valid_facialhairstyles[facialhairstyle] = facial_hair_styles_list[facialhairstyle]

	if (valid_facialhairstyles.len)
		f_style = pick(valid_facialhairstyles)

		return f_style

proc/sanitize_name(name, species = "Human")
	var/datum/species/current_species
	if (species)
		current_species = all_species[species]

	return current_species ? current_species.sanitize_name(name) : sanitizeName(name)

proc/random_name(gender, species = "Human")

	var/datum/species/current_species
	if (species)
		current_species = all_species[species]

	if (!current_species || current_species.name_language == null)
		if (gender==FEMALE)
			return capitalize(pick(first_names_female)) + " " + capitalize(pick(last_names))
		else
			return capitalize(pick(first_names_male)) + " " + capitalize(pick(last_names))
	else
		return current_species.get_random_name(gender)


proc/random_german_name(gender, species = "Human")

	var/datum/species/current_species
	if (species)
		current_species = all_species[species]

	if (!current_species || current_species.name_language == null)
		if (gender==FEMALE)
			return capitalize(pick(first_names_female_german)) + " " + capitalize(pick(last_names_german))
		else
			return capitalize(pick(first_names_male_german)) + " " + capitalize(pick(last_names_german))
	else
		return current_species.get_random_german_name(gender)

proc/random_italian_name(gender, species = "Human")

	var/datum/species/current_species
	if (species)
		current_species = all_species[species]

	if (!current_species || current_species.name_language == null)
		if (gender==FEMALE)
			return capitalize(pick(first_names_female_italian)) + " " + capitalize(pick(last_names_italian))
		else
			return capitalize(pick(first_names_male_italian)) + " " + capitalize(pick(last_names_italian))
	else
		return current_species.get_random_italian_name(gender)
proc/random_english_name(gender, species = "Human")
	var/datum/species/current_species
	if (species)
		current_species = all_species[species]

	if (!current_species || current_species.name_language == null)
		if (gender==FEMALE)
			return capitalize(pick(first_names_female_english)) + " " + capitalize(pick(last_names_english))
		else
			return capitalize(pick(first_names_male_english)) + " " + capitalize(pick(last_names_english))
	else
		return current_species.get_random_english_name(gender)

proc/random_japanese_name(gender, species = "Human")
	var/datum/species/current_species
	if (species)
		current_species = all_species[species]

	if (!current_species || current_species.name_language == null)
		if (gender==FEMALE)
			return capitalize(pick(first_names_female_japanese)) + " " + capitalize(pick(last_names_japanese))
		else
			return capitalize(pick(first_names_male_japanese)) + " " + capitalize(pick(last_names_japanese))
	else
		return current_species.get_random_japanese_name(gender)

proc/russify(var/list/name_list, gender)
	var/list/l = name_list.Copy()
	for (var/v in 1 to l.len)
		var/name = l[v]
		if (gender == FEMALE)
			name = replacetext(name, "ovich", "ovna")
		l[v] = name
	return l

proc/polify(var/list/name_list, gender)
	var/list/l = name_list.Copy()
	for (var/v in 1 to l.len)
		var/name = l[v]
		if (gender == FEMALE)
			name = replacetext(name, "ski", "ska")
		l[v] = name
	return l

proc/random_russian_name(gender, species = "Human")

	var/datum/species/current_species

	if (species)
		current_species = all_species[species]

	if (!current_species || current_species.name_language == null)
		if (gender==FEMALE)
			return capitalize(pick(first_names_female_russian)) + " " + capitalize(pick(russify(last_names_russian, gender)))
		else
			return capitalize(pick(first_names_male_russian)) + " " + capitalize(pick(russify(last_names_russian, gender)))
	else
		return current_species.get_random_russian_name(gender)

proc/random_ukrainian_name(gender, species = "Human")

	var/datum/species/current_species

	if (species)
		current_species = all_species[species]

	if (!current_species || current_species.name_language == null)
		if (gender==FEMALE)
			return capitalize(pick(first_names_female_ukrainian)) + " " + capitalize(pick(russify(last_names_ukrainian, gender)))
		else
			return capitalize(pick(first_names_male_ukrainian)) + " " + capitalize(pick(russify(last_names_ukrainian, gender)))
	else
		return current_species.get_random_ukrainian_name(gender)

proc/random_polish_name(gender, species = "Human")

	var/datum/species/current_species

	if (species)
		current_species = all_species[species]

	if (!current_species || current_species.name_language == null)
		if (gender==FEMALE)
			return capitalize(pick(first_names_female_polish)) + " " + capitalize(pick(polify(last_names_polish, gender)))
		else
			return capitalize(pick(first_names_male_polish)) + " " + capitalize(pick(polify(last_names_polish, gender)))
	else
		return current_species.get_random_polish_name(gender)

proc/random_skin_tone()

	var/skin_tone = "caucasian"
	if (prob(60))
		pass()
	else if (prob(15))
		skin_tone = "afroamerican"
	else if (prob(10))
		skin_tone = "african"
	else if (prob(10))
		skin_tone = "latino"
	else
		skin_tone = "albino"

	switch(skin_tone)
		if ("caucasian")		. = -10
		if ("afroamerican")	. = -115
		if ("african")		. = -165
		if ("latino")		. = -55
		if ("albino")		. = 34
		else				. = rand(-185,34)
	return min(max( .+rand(-25, 25), -185),34)

proc/skintone2racedescription(tone)
	switch (tone)
		if (30 to INFINITY)		return "albino"
		if (20 to 30)			return "pale"
		if (5 to 15)				return "light skinned"
		if (-10 to 5)			return "white"
		if (-25 to -10)			return "tan"
		if (-45 to -25)			return "darker skinned"
		if (-65 to -45)			return "brown"
		if (-INFINITY to -65)	return "black"
		else					return "unknown"

proc/age2agedescription(age)
	switch(age)
		if (0 to 1)			return "infant"
		if (1 to 3)			return "toddler"
		if (3 to 13)			return "child"
		if (13 to 19)		return "teenager"
		if (19 to 30)		return "young adult"
		if (30 to 45)		return "adult"
		if (45 to 60)		return "middle-aged"
		if (60 to 70)		return "aging"
		if (70 to INFINITY)	return "elderly"
		else				return "unknown"

proc/ageAndGender2Desc(age, gender)//Used for the radio
	if (gender == FEMALE)
		switch(age)
			if (0 to 15)			return "Girl"
			if (15 to 25)		return "Young Woman"
			if (25 to 60)		return "Woman"
			if (60 to INFINITY)	return "Old Woman"
			else				return "Unknown"
	else
		switch(age)
			if (0 to 15)			return "Boy"
			if (15 to 25)		return "Young Man"
			if (25 to 60)		return "Man"
			if (60 to INFINITY)	return "Old Man"
			else				return "Unknown"

proc/get_body_build(gender, body_build = "Default")
	if (gender == MALE)
		if (body_build in male_body_builds)
			return male_body_builds[body_build]
		else
			return male_body_builds["Default"]
	else
		if (body_build in female_body_builds)
			return female_body_builds[body_build]
		else
			return female_body_builds["Default"]

proc/RoundHealth(health)
	switch(health)
		if (100 to INFINITY)
			return "health100"
		if (70 to 100)
			return "health80"
		if (50 to 70)
			return "health60"
		if (30 to 50)
			return "health40"
		if (18 to 30)
			return "health25"
		if (5 to 18)
			return "health10"
		if (1 to 5)
			return "health1"
		if (-99 to 0)
			return "health0"
		else
			return "health-100"
	return "0"

/*
Proc for attack log creation, because really why not
1 argument is the actor
2 argument is the target of action
3 is the description of action(like punched, throwed, or any other verb)
4 should it make adminlog note or not
5 is the tool with which the action was made(usually item)					5 and 6 are very similar(5 have "by " before it, that it) and are separated just to keep things in a bit more in order
6 is additional information, anything that needs to be added
*/

/proc/add_logs(mob/user, mob/target, what_done, var/admin=1, var/object=null, var/addition=null)
	if (user && ismob(user))
		user.attack_log += text("\[[time_stamp()]\] <font color='red'>Has [what_done] [target ? "[target.name][(ismob(target) && target.ckey) ? "([target.ckey])" : ""]" : "NON-EXISTANT SUBJECT"][object ? " with [object]" : " "][addition]</font>")
	if (target && ismob(target))
		target.attack_log += text("\[[time_stamp()]\] <font color='orange'>Has been [what_done] by [user ? "[user.name][(ismob(user) && user.ckey) ? "([user.ckey])" : ""]" : "NON-EXISTANT SUBJECT"][object ? " with [object]" : " "][addition]</font>")
	if (admin)
		log_attack("<font color='red'>[user ? "[user.name][(ismob(user) && user.ckey) ? "([user.ckey])" : ""]" : "NON-EXISTANT SUBJECT"] [what_done] [target ? "[target.name][(ismob(target) && target.ckey)? "([target.ckey])" : ""]" : "NON-EXISTANT SUBJECT"][object ? " with [object]" : " "][addition]</font>")

//checks whether this item is a module of the robot it is located in.
/proc/is_robot_module(var/obj/item/thing)
	return FALSE

/proc/get_exposed_defense_zone(var/atom/movable/target)
	var/obj/item/weapon/grab/G = locate() in target
	if (G && G.state >= GRAB_NECK) //works because mobs are currently not allowed to upgrade to NECK if they are grabbing two people.
		return pick("head", "l_hand", "r_hand", "l_foot", "r_foot", "l_arm", "r_arm", "l_leg", "r_leg")
	else
		return pick("chest", "groin")

/mob/var/may_do_mob = TRUE
/proc/do_mob(mob/user , mob/target, time = 30, uninterruptible = FALSE, progress = TRUE)
	if (!user || !target || !user.may_do_mob)
		return FALSE

	user.may_do_mob = FALSE

	var/user_loc = user.loc
	var/target_loc = target.loc
	var/last_train_move_time = null

	if (user.is_on_train())
		var/datum/train_controller/tc = user.get_train()
		if (istype(tc) && tc.moving)
			last_train_move_time = user.last_moved_on_train

	var/holding = user.get_active_hand()
	var/datum/progressbar/progbar
	if (progress)
		progbar = new(user, time, target)

	var/endtime = world.time+time
	var/starttime = world.time
	. = TRUE
	while (world.time < endtime)
		sleep(0.1)
		if (progress)
			progbar.update(world.time - starttime)

		if (!user || !target)
			. = FALSE
			break

		if (uninterruptible)
			continue

		if (!user || user.incapacitated() || (!last_train_move_time && user.loc != user_loc))
			. = FALSE
			break

		if (!last_train_move_time && target.loc != target_loc)
			. = FALSE
			break

		if (last_train_move_time)
			if (user.last_moved_on_train != last_train_move_time || !user.is_on_train())
				. = FALSE
				break

		if (user.get_active_hand() != holding)
			. = FALSE
			break

	user.may_do_mob = TRUE

	if (progbar)
		qdel(progbar)

/mob/var/may_do_after = TRUE
/proc/do_after(mob/user, delay, atom/target = null, needhand = TRUE, progress = TRUE, var/incapacitation_flags = INCAPACITATION_DEFAULT, can_move = FALSE, check_for_repeats = TRUE)
	if (!user || !user.may_do_after)
		return FALSE

	if (check_for_repeats)
		user.may_do_after = FALSE

	var/target_loc = null
	var/last_train_move_time = null

	// made this account for being moved on rollerbeds - Kachnov

	var/user_on_train = FALSE
	if (user.is_on_train())
		var/datum/train_controller/tc = user.get_train()
		if (istype(tc) && tc.moving)
			last_train_move_time = user.last_moved_on_train
			user_on_train = TRUE

	if (!user_on_train)
		if (target)
			target_loc = target.loc

	var/atom/original_loc = user.loc

	var/holding = user.get_active_hand()

	var/datum/progressbar/progbar
	if (progress)
		progbar = new(user, delay, target)

	var/endtime = world.time + delay
	var/starttime = world.time
	. = TRUE
	while (world.time < endtime)
		sleep(0.1)
		if (progress)
			progbar.update(world.time - starttime)

		if (!user || user.incapacitated(incapacitation_flags))
			. = FALSE
			break

		if (target_loc && (!target || target_loc != target.loc))
			. = FALSE
			break

		if (!can_move)
			if (user.loc != original_loc && !last_train_move_time)
				. = FALSE
				break

		// this should fix the bug where a guy can start resisting on a train,
		// get moved off the train, and keep resisting even after being moved
		// - Kachnov
		if (last_train_move_time)
			if (user.last_moved_on_train != last_train_move_time || !user.is_on_train())
				. = FALSE
				break

		if (needhand)
			if (user.get_active_hand() != holding)
				. = FALSE
				break

	user.may_do_after = TRUE

	if (progbar)
		qdel(progbar)

//Returns a list of all mobs with their name
/proc/getmobs()

	var/list/mobs = sortmobs()
	var/list/names = list()
	var/list/creatures = list()
	var/list/namecounts = list()
	for (var/mob/M in mobs)
		var/name = M.name
		if (name in names)
			namecounts[name]++
			name = "[name] ([namecounts[name]])"
		else
			names.Add(name)
			namecounts[name] = TRUE
		if (M.real_name && M.real_name != M.name)
			name += " \[[M.real_name]\]"
		if (M.stat == 2)
			if (istype(M, /mob/observer/ghost/))
				name += " \[ghost\]"
			else
				name += " \[dead\]"
		creatures[name] = M

	return creatures

/proc/getsovietmobs(var/alive = FALSE)
	var/list/soviets = list()
	for (var/mob/living/carbon/human/H in mob_list)
		if (!istype(H))
			continue
		if (alive && H.stat == DEAD)
			continue
		if (!H.loc)
			continue
		if (!istype(H.original_job, /datum/job/soviet))
			continue
		if (istype(H, /mob/living/carbon/human/corpse))
			continue
		soviets += H

	return soviets

/proc/getgermanmobs(var/alive = FALSE)
	var/list/germans = list()
	for (var/mob/living/carbon/human/H in mob_list)
		if (!istype(H))
			continue
		if (!H.loc) // supply train announcer
			continue
		if (alive && H.stat == DEAD)
			continue
		if (!istype(H.original_job, /datum/job/german))
			continue
		if (istype(H, /mob/living/carbon/human/corpse))
			continue
		germans += H

	return germans

/proc/getitalianmobs(var/alive = FALSE)
	var/list/italians = list()
	for (var/mob/living/carbon/human/H in mob_list)
		if (!istype(H))
			continue
		if (!H.loc) // supply train announcer
			continue
		if (alive && H.stat == DEAD)
			continue
		if (!istype(H.original_job, /datum/job/italian))
			continue
		if (istype(H, /mob/living/carbon/human/corpse))
			continue
		italians += H

	return italians

/proc/getukrainianmobs(var/alive = FALSE)
	var/list/ukrainians = list()
	for (var/mob/living/carbon/human/H in mob_list)
		if (!istype(H))
			continue
		if (!H.loc)
			continue
		if (alive && H.stat == DEAD)
			continue
		if (!istype(H.original_job, /datum/job/partisan))
			continue
		if (istype(H, /mob/living/carbon/human/corpse))
			continue
		ukrainians += H

	return ukrainians

/proc/getgermanparatroopers(var/alive = FALSE)
	var/list/germans = getgermanmobs(alive)
	var/list/paratroopers = list()
	for (var/mob/living/carbon/human/H in germans)
		if (istype(H.original_job, /datum/job/german/paratrooper))
			paratroopers += H
	return paratroopers

/proc/getSS(var/alive = FALSE)
	var/list/germans = getgermanmobs(alive)
	var/list/SS = list()
	for (var/mob/living/carbon/human/H in germans)
		if (istype(H.original_job, /datum/job/german/soldier_ss) || istype(H.original_job, /datum/job/german/squad_leader_ss))
			SS += H
	return SS

/proc/getcivilians(var/alive = FALSE)
	var/list/ukrainians = getukrainianmobs(alive)
	var/list/civilians = list()
	for (var/mob/living/carbon/human/H in ukrainians)
		if (istype(H.original_job, /datum/job/partisan/civilian))
			civilians += H
	return civilians

/proc/getpartisans(var/alive = FALSE)
	var/list/ukrainians = getukrainianmobs(alive)
	var/list/partisans = list()
	for (var/mob/living/carbon/human/H in ukrainians)
		if (!istype(H.original_job, /datum/job/partisan/civilian))
			partisans += H
	return partisans

/proc/getfitmobs(var/faction)

	var/list/mobs = null
	var/list/newmobs = list()

	switch (faction)
		if (null)
			mobs = mob_list // we want actual mobs, not name = mob
		if (GERMAN)
			mobs = getgermanmobs(0)
		if (ITALIAN)
			mobs = getitalianmobs(0)
		if (SOVIET, "SOVIET")
			mobs = getsovietmobs(0)
		if ("PARATROOPERS")
			mobs = getgermanparatroopers(0)
		if ("SS")
			mobs = getSS(0)
		if (PARTISAN)
			mobs = getpartisans(0)
		if (CIVILIAN)
			mobs = getcivilians(0)
		if (PILLARMEN, "UNDEAD")
			mobs = list()
			for (var/mob/living/carbon/human/H in human_mob_list)
				if (istype(H, /mob/living/carbon/human/vampire) || istype(H, /mob/living/carbon/human/pillarman))
					mobs += H

	// sort mobs by stat: alive, unconscious, then dead
	for (var/v in 0 to 2)
		for (var/mob/m in mobs)
			if (m.stat == v)
				if (!m.loc)
					continue
				if (m.stat == UNCONSCIOUS)
					var/mob/living/L = m
					if (istype(L) && L.getTotalLoss() > 100)
						newmobs["[m.real_name] (DYING)"] = m
					else
						newmobs["[m.real_name] (UNCONSCIOUS)"] = m
				else if (m.stat == DEAD)
					newmobs["[m.real_name] (DEAD)"] = m
				else
					newmobs[m.real_name] = m

	return newmobs


//Orders mobs by type then by name
/proc/sortmobs()
	var/list/moblist = list()
	var/list/sortmob = sortAtom(mob_list)
	for (var/mob/observer/eye/M in sortmob)
		moblist.Add(M)
	for (var/mob/living/carbon/human/M in sortmob)
		moblist.Add(M)
	for (var/mob/living/carbon/brain/M in sortmob)
		moblist.Add(M)
	for (var/mob/living/carbon/alien/M in sortmob)
		moblist.Add(M)
	for (var/mob/observer/ghost/M in sortmob)
		moblist.Add(M)
	for (var/mob/new_player/M in sortmob)
		moblist.Add(M)
	for (var/mob/living/simple_animal/M in sortmob)
		moblist.Add(M)
	return moblist

// returns the turf behind the mob

/proc/get_turf_behind(var/mob/m)
	switch (m.dir)
		if (NORTH)
			return locate(m.x, m.y-1, m.z)
		if (SOUTH)
			return locate(m.x, m.y+1, m.z)
		if (EAST)
			return locate(m.x-1, m.y, m.z)
		if (WEST)
			return locate(m.x+1, m.y, m.z)

/mob/proc/behind()
	return get_turf_behind(src)

/* detects if we should be able to detect someone, ICly, based on direction both mobs are facing
 * this proc currently exists for projectiles, which are twice as likely to hit people in the blindspot of the firer
 	- Kachnov
*/

/mob/proc/is_in_blindspot(var/mob/other)
	if (list(NORTH, NORTHEAST, NORTHWEST).Find(dir))
		if (list(NORTH, NORTHEAST, NORTHWEST).Find(other.dir))
			return TRUE
	if (list(SOUTH, SOUTHEAST, SOUTHWEST).Find(dir))
		if (list(SOUTH, SOUTHEAST, SOUTHWEST).Find(other.dir))
			return TRUE
	if (dir == other.dir)
		return TRUE
	return FALSE