/atom/movable/proc/get_mob()
	return
/mob/get_mob()
	return src

//helper for inverting armor blocked values into a multiplier
#define blocked_mult(blocked) max(1 - (blocked/100), 0)

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

proc/random_skin_tone()
	switch(pick(60;"caucasian", 15;"afroamerican", 10;"african", 10;"latino", 5;"albino"))
		if("caucasian")		. = -10
		if("afroamerican")	. = -115
		if("african")		. = -165
		if("latino")		. = -55
		if("albino")		. = 34
	return clamp(. + rand(-25, 25), -185, 34) // Clamp() keeps the rand(-25, 25) variation of skin tone between -185 to 34.

proc/skintone2racedescription(tone)
	if(!isnum(tone))
		CRASH("skintone2racedescription; proc called without correct tone (integer) argument.")

	switch(tone)
		if (30 to INFINITY)		return "albino"
		if (20 to 29)			return "pale"
		if (5 to 19)			return "light skinned"
		if (-10 to 4)			return "white"
		if (-25 to -9)			return "tan"
		if (-45 to -24)			return "darker skinned"
		if (-65 to -44)			return "brown"
		if (-INFINITY to -64)		return "black"
		else				return "unknown"

proc/age2agedescription(age)
	if(!isnum(age))
		CRASH("age2agedescription; proc called without correct age (integer) argument.")

	switch(age)
		if (0 to 1)			return "infant"
		if (2 to 3)			return "toddler"
		if (4 to 12)			return "child"
		if (13 to 17)			return "teenager"
		if (18 to 29)			return "young adult"
		if (30 to 44)			return "adult"
		if (45 to 59)			return "middle-aged"
		if (60 to 69)			return "aging"
		if (70 to INFINITY)		return "elderly"
		else				return "unknown"

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

/mob/var/may_do_mob = TRUE
/proc/do_mob(mob/user , mob/target, time = 30, uninterruptible = FALSE, progress = TRUE)
	if (!user || !target || !user.may_do_mob)
		return FALSE

	user.may_do_mob = FALSE

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

		if (!user || user.incapacitated())
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
			if (user.loc != original_loc)
				. = FALSE
				break

		if (needhand)
			if (user.get_active_hand() != holding)
				. = FALSE
				break
	if (user)
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

/proc/getbritishmobs(var/alive = FALSE)
	var/list/british = list()
	for (var/mob/living/human/H in mob_list)
		if (!istype(H))
			continue
		if (alive && H.stat == DEAD)
			continue
		if (!H.loc)
			continue
		if (!istype(H.original_job, /datum/job/british))
			continue
		if (istype(H, /mob/living/human/corpse))
			continue
		british += H

	return british

/proc/getportuguesemobs(var/alive = FALSE)
	var/list/portuguese = list()
	for (var/mob/living/human/H in mob_list)
		if (!istype(H))
			continue
		if (alive && H.stat == DEAD)
			continue
		if (!H.loc)
			continue
		if (!istype(H.original_job, /datum/job/portuguese))
			continue
		if (istype(H, /mob/living/human/corpse))
			continue
		portuguese += H

	return portuguese

/proc/getspanishmobs(var/alive = FALSE)
	var/list/spanish = list()
	for (var/mob/living/human/H in mob_list)
		if (!istype(H))
			continue
		if (alive && H.stat == DEAD)
			continue
		if (!H.loc)
			continue
		if (!istype(H.original_job, /datum/job/spanish))
			continue
		if (istype(H, /mob/living/human/corpse))
			continue
		spanish += H

	return spanish

/proc/getdutchmobs(var/alive = FALSE)
	var/list/dutch = list()
	for (var/mob/living/human/H in mob_list)
		if (!istype(H))
			continue
		if (alive && H.stat == DEAD)
			continue
		if (!H.loc)
			continue
		if (!istype(H.original_job, /datum/job/dutch))
			continue
		if (istype(H, /mob/living/human/corpse))
			continue
		dutch += H

	return dutch

/proc/getitalianmobs(var/alive = FALSE)
	var/list/italian = list()
	for (var/mob/living/human/H in mob_list)
		if (!istype(H))
			continue
		if (alive && H.stat == DEAD)
			continue
		if (!H.loc)
			continue
		if (!istype(H.original_job, /datum/job/italian))
			continue
		if (istype(H, /mob/living/human/corpse))
			continue
		italian += H

	return italian

/proc/getjapanesemobs(var/alive = FALSE)
	var/list/japanese = list()
	for (var/mob/living/human/H in mob_list)
		if (!istype(H))
			continue
		if (alive && H.stat == DEAD)
			continue
		if (!H.loc)
			continue
		if (!istype(H.original_job, /datum/job/japanese))
			continue
		if (istype(H, /mob/living/human/corpse))
			continue
		japanese += H

	return japanese

/proc/getgreekmobs(var/alive = FALSE)
	var/list/greek = list()
	for (var/mob/living/human/H in mob_list)
		if (!istype(H))
			continue
		if (alive && H.stat == DEAD)
			continue
		if (!H.loc)
			continue
		if (!istype(H.original_job, /datum/job/greek))
			continue
		if (istype(H, /mob/living/human/corpse))
			continue
		greek += H

	return greek

/proc/getrussianmobs(var/alive = FALSE)
	var/list/russian = list()
	for (var/mob/living/human/H in mob_list)
		if (!istype(H))
			continue
		if (alive && H.stat == DEAD)
			continue
		if (!H.loc)
			continue
		if (!istype(H.original_job, /datum/job/russian))
			continue
		if (istype(H, /mob/living/human/corpse))
			continue
		russian += H

	return russian

/proc/getchechenmobs(var/alive = FALSE)
	var/list/chechen = list()
	for (var/mob/living/human/H in mob_list)
		if (!istype(H))
			continue
		if (alive && H.stat == DEAD)
			continue
		if (!H.loc)
			continue
		if (!istype(H.original_job, /datum/job/arab/civilian/chechen))
			continue
		if (istype(H, /mob/living/human/corpse))
			continue
		chechen += H

	return chechen

/proc/getfinnishmobs(var/alive = FALSE)
	var/list/finnish = list()
	for (var/mob/living/human/H in mob_list)
		if (!istype(H))
			continue
		if (alive && H.stat == DEAD)
			continue
		if (!H.loc)
			continue
		if (!istype(H.original_job, /datum/job/finnish))
			continue
		if (istype(H, /mob/living/human/corpse))
			continue
		finnish += H

	return finnish


/proc/getgermanmobs(var/alive = FALSE)
	var/list/german = list()
	for (var/mob/living/human/H in mob_list)
		if (!istype(H))
			continue
		if (alive && H.stat == DEAD)
			continue
		if (!H.loc)
			continue
		if (!istype(H.original_job, /datum/job/german))
			continue
		if (istype(H, /mob/living/human/corpse))
			continue
		german += H

	return german

/proc/getfrenchmobs(var/alive = FALSE)
	var/list/french = list()
	for (var/mob/living/human/H in mob_list)
		if (!istype(H))
			continue
		if (alive && H.stat == DEAD)
			continue
		if (!H.loc)
			continue
		if (!istype(H.original_job, /datum/job/french))
			continue
		if (istype(H, /mob/living/human/corpse))
			continue
		french += H

	return french

/proc/getindiansmobs(var/alive = FALSE)
	var/list/indians = list()
	for (var/mob/living/human/H in mob_list)
		if (!istype(H))
			continue
		if (alive && H.stat == DEAD)
			continue
		if (!H.loc)
			continue
		if (!istype(H.original_job, /datum/job/indians))
			continue
		if (istype(H, /mob/living/human/corpse))
			continue
		indians += H

	return indians

/proc/getpiratesmobs(var/alive = FALSE)
	var/list/pirates = list()
	for (var/mob/living/human/H in mob_list)
		if (!istype(H))
			continue
		if (!H.loc) // supply train announcer
			continue
		if (alive && H.stat == DEAD)
			continue
		if (!istype(H.original_job, /datum/job/pirates))
			continue
		if (istype(H, /mob/living/human/corpse))
			continue
		pirates += H

	return pirates


/proc/getcivilians(var/alive = FALSE)
	var/list/civilians = list()
	for (var/mob/living/human/H in mob_list)
		if (istype(H.original_job, /datum/job/civilian))
			civilians += H
	return civilians

/proc/getamericanmobs(var/alive = FALSE)
	var/list/americans = list()
	for (var/mob/living/human/H in mob_list)
		if (istype(H.original_job, /datum/job/american))
			americans += H
	return americans

/proc/getvietnamesemobs(var/alive = FALSE)
	var/list/vietnamese = list()
	for (var/mob/living/human/H in mob_list)
		if (istype(H.original_job, /datum/job/vietnamese))
			vietnamese += H
	return vietnamese

/proc/getchinesemobs(var/alive = FALSE)
	var/list/chinese = list()
	for (var/mob/living/human/H in mob_list)
		if (istype(H.original_job, /datum/job/chinese))
			chinese += H
	return chinese

/proc/getfilipinomobs(var/alive = FALSE)
	var/list/filipino = list()
	for (var/mob/living/human/H in mob_list)
		if (istype(H.original_job, /datum/job/filipino))
			filipino += H
	return filipino

/proc/getpolishmobs(var/alive = FALSE)
	var/list/polish = list()
	for (var/mob/living/human/H in mob_list)
		if (istype(H.original_job, /datum/job/polish))
			polish += H
	return polish

/proc/getbluefactionmobs(var/alive = FALSE)
	var/list/bluefaction = list()
	for (var/mob/living/human/H in mob_list)
		if (!istype(H))
			continue
		if (alive && H.stat == DEAD)
			continue
		if (!H.loc)
			continue
		if (!istype(H.original_job, /datum/job/bluefaction))
			continue
		if (istype(H, /mob/living/human/corpse))
			continue
		bluefaction += H
	return bluefaction

/proc/getredfactionmobs(var/alive = FALSE)
	var/list/redfaction = list()
	for (var/mob/living/human/H in mob_list)
		if (!istype(H))
			continue
		if (alive && H.stat == DEAD)
			continue
		if (!H.loc)
			continue
		if (!istype(H.original_job, /datum/job/redfaction))
			continue
		if (istype(H, /mob/living/human/corpse))
			continue
		redfaction += H
	return redfaction

/proc/getcafrmobs(var/alive = FALSE)
	var/list/cafr = list()
	for (var/mob/living/human/H in mob_list)
		if (!istype(H))
			continue
		if (alive && H.stat == DEAD)
			continue
		if (!H.loc)
			continue
		if (!istype(H.original_job, /datum/job/cafr))
			continue
		if (istype(H, /mob/living/human/corpse))
			continue
		cafr += H
	return cafr

/proc/gettsfsrmobs(var/alive = FALSE)
	var/list/tsfsr = list()
	for (var/mob/living/human/H in mob_list)
		if (!istype(H))
			continue
		if (alive && H.stat == DEAD)
			continue
		if (!H.loc)
			continue
		if (!istype(H.original_job, /datum/job/tsfsr))
			continue
		if (istype(H, /mob/living/human/corpse))
			continue
		tsfsr += H
	return tsfsr

/proc/getfitmobs(var/faction)

	var/list/mobs = null
	var/list/newmobs = list()

	switch (faction)
		if (null)
			mobs = mob_list // we want actual mobs, not name = mob
		if (BRITISH)
			mobs = getbritishmobs(0)
		if (PIRATES)
			mobs = getpiratesmobs(0)
		if (CIVILIAN)
			mobs = getcivilians(0)
		if (INDIANS)
			mobs = getindiansmobs(0)
		if (FRENCH)
			mobs = getfrenchmobs(0)
		if (SPANISH)
			mobs = getspanishmobs(0)
		if (PORTUGUESE)
			mobs = getportuguesemobs(0)
		if (DUTCH)
			mobs = getdutchmobs(0)
		if (ITALIAN)
			mobs = getitalianmobs(0)
		if (JAPANESE)
			mobs = getjapanesemobs(0)
		if (GREEK)
			mobs = getgreekmobs(0)
		if (RUSSIAN)
			mobs = getrussianmobs(0)
		if (CHECHEN)
			mobs = getchechenmobs(0)
		if (FINNISH)
			mobs = getfinnishmobs(0)
		if (GERMAN)
			mobs = getgermanmobs(0)
		if (AMERICAN)
			mobs = getamericanmobs(0)
		if (VIETNAMESE)
			mobs = getvietnamesemobs(0)
		if (CHINESE)
			mobs = getchinesemobs(0)
		if (FILIPINO)
			mobs = getfilipinomobs(0)
		if (POLISH)
			mobs = getpolishmobs(0)
		if (BLUEFACTION)
			mobs = getbluefactionmobs(0)
		if (REDFACTION)
			mobs = getredfactionmobs(0)
		if (CAFR)
			mobs = getcafrmobs(0)
		if (TSFSR)
			mobs = gettsfsrmobs(0)
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
	for (var/mob/living/human/M in sortmob)
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

// Returns true if M was not already in the dead mob list
/mob/proc/switch_from_living_to_dead_mob_list()
	remove_from_living_mob_list()
	. = add_to_dead_mob_list()

// Returns true if M was not already in the living mob list
/mob/proc/switch_from_dead_to_living_mob_list()
	remove_from_dead_mob_list()
	. = add_to_living_mob_list()

// Returns true if the mob was in neither the dead or living list
/mob/proc/add_to_living_mob_list()
	return FALSE
/mob/living/add_to_living_mob_list()
	if((src in global.living_mob_list) || (src in global.dead_mob_list))
		return FALSE
	global.living_mob_list += src
	return TRUE

// Returns true if the mob was removed from the living list
/mob/proc/remove_from_living_mob_list()
	return global.living_mob_list.Remove(src)

// Returns true if the mob was in neither the dead or living list
/mob/proc/add_to_dead_mob_list()
	return FALSE
/mob/living/add_to_dead_mob_list()
	if((src in global.living_mob_list) || (src in global.dead_mob_list))
		return FALSE
	global.dead_mob_list += src
	return TRUE

// Returns true if the mob was removed form the dead list
/mob/proc/remove_from_dead_mob_list()
	return global.dead_mob_list.Remove(src)
