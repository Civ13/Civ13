#define COMMAND_LEVEL_1 4
#define COMMAND_LEVEL_2 3
#define COMMAND_LEVEL_3 2
#define COMMAND_LEVEL_4 1

/mob/living/simple_animal/complex_animal/dog
	icon_state = null
	resting_state = null
	wander = FALSE

	// COMMANDS
	// format is "word;jobtitle&jobtitle;proc"
	// special values that are permitted for jobtitle are:
		//'master' - the dog's owner
		//'team' - anyone on the dog's faction
		//'everyone' - anyone at all
		//'default' - alias for "master"

	var/list/commands = list(
	"attack;default;attack", // attack armed enemies
	"kill;default;kill", // attack enemies, armed or unarmed
	"guard;default;guard", // attack people who come into our area
	"patrol;default;patrol", // wander around the base, overlaps with other cmds
	"stop patrolling;default;stop_patrol",
	"be passive;default;passive", // only attack in self-defense
	"stop everything;default;stop", // stop doing everything
	"follow;default;follow", // makes the dog follow you
	"stop following;default;stop_following", // makes the stop following who its following
	"prioritize following;default;prioritize_following",
	"prioritize attacking;default;prioritize_attacking"
	)

	faction = null

	var/attack_mode = "guard"
	var/patrolling = FALSE
	var/following = null

	var/prioritizes = "attacking"

	var/last_patrol_area = null

	var/command_levels = list() // "command" = COMMAND_LEVEL

	var/next_bork = -1

	var/atom/walking_to = null

	var/race = "samoyed"

	maxHealth = 55
	health = 55
	mob_size = MOB_MEDIUM

/mob/living/simple_animal/complex_animal/dog/New()
	..()
	icon_state = "[race]"
	resting_state = "[race]_rest"
	dead_state = "[race]_dead"
	icon_living = icon_state
	icon_dead = dead_state
	dog_mob_list += src
	update_icons()


/mob/living/simple_animal/complex_animal/dog/Del()
	dog_mob_list -= src
	..()

/mob/living/simple_animal/verb/name_pet()
	set category = null
	set name = "Name"
	set desc = "Name this animal."

	set src in view(1)

	var/mob_factions = "none"
	if (istype(usr, /mob/living/carbon/human))
		var/mob/living/carbon/human/H = usr
		if (map.civilizations)
			mob_factions = H.civilization
		else
			mob_factions = H.faction_text
	if (istype(src, /mob/living/simple_animal/complex_animal))
		var/mob/living/simple_animal/complex_animal/CA = src
		if (CA.owner || (mob_factions == faction))
			var/yn = input(usr, "Name this [src]?") in list("Yes", "No")
			if (yn == "Yes")
				var/_name = input(usr, "What name?") as text
				name = sanitize(_name, 50)
				return
		else
			usr << "You can't name this [src], as it does not belong to you or your faction."
			return
	else
		if (name == initial(name) && !istype(src, /mob/living/simple_animal/hostile) && !istype(src, /mob/living/simple_animal/mosquito))
			var/yn = input(usr, "Name this [src]?") in list("Yes", "No")
			if (yn == "Yes")
				var/_name = input(usr, "What name?") as text
				name = sanitize(_name, 50)
				return
	return
/mob/living/simple_animal/complex_animal/dog/proc/check_can_command(var/list/ranks, var/mob/living/carbon/human/H)
	if (!islist(ranks))
		. = list()
		. += ranks
		ranks = .
	var/mob_faction = "none"
	if (map.civilizations)
		mob_faction = H.civilization
	else
		mob_faction = H.faction_text
	// no 'else's here, because we accept multiple ranks

	if (ranks.Find("master"))
		if (H == owner || (!owner && mob_faction == faction))
			return TRUE

	if (ranks.Find("team"))
		if (mob_faction == faction)
			return TRUE

	if (ranks.Find("everyone"))
		return TRUE
	return FALSE

// types of dogs

/mob/living/simple_animal/complex_animal/dog/german_shepherd
	name = "Wild German Shepherd"
	faction = null
	allow_moving_outside_home = TRUE
	attack_mode = -1
	race = "german_shepherd"
	tameminimum = 100

/mob/living/simple_animal/complex_animal/dog/samoyed
	name = "Wild Samoyed"
	faction = null
	allow_moving_outside_home = TRUE
	attack_mode = -1
	race = "samoyed"
	tameminimum = 125

/mob/living/simple_animal/complex_animal/dog/wolf
	name = "Wild Wolf"
	faction = null
	allow_moving_outside_home = TRUE
	attack_mode = -1
	race = "wolf"
	tameminimum = 200
	maxHealth = 65
	health = 65

/mob/living/simple_animal/complex_animal/dog/beagle
	name = "Wild Beagle"
	faction = null
	allow_moving_outside_home = TRUE
	attack_mode = -1
	race = "beagle"
	tameminimum = 75
	mob_size = MOB_SMALL
	maxHealth = 50
	health = 0

/mob/living/simple_animal/complex_animal/dog/pug
	name = "Wild Pug"
	faction = null
	allow_moving_outside_home = TRUE
	attack_mode = -1
	race = "pug"
	tameminimum = 70
	maxHealth = 45
	health = 45
	mob_size = MOB_SMALL
// "backend" procs

// parse messages that people say (WIP)
	// needs faction, friendly, etc support
	// commands list needs to be filled
/mob/living/simple_animal/complex_animal/dog/proc/hear_command(var/message, var/mob/living/carbon/human/H)
	if (!faction)
		return
	if (!dd_hassuffix(message, "!"))
		return
	message = copytext(message, TRUE, lentext(message))
//	world << "1. [message]"
	// parse message into a command
	if (stat == CONSCIOUS)
	//	world << "2. [src]"
		for (var/command in commands)
			var/list/parts = splittext(command, ";")
			var/req_word = lowertext(parts[1])
			var/list/req_ranks = splittext(parts[2], "&")
			if (!islist(req_ranks))
				. = list()
				. += req_ranks
				req_ranks = .

			for (var/RR in req_ranks)
			//	world << "2.5: [RR]"
				req_ranks += lowertext(RR)
				req_ranks -= RR

			// DEBUG BLOCK
			var/d1 = ""
			for (var/RR in req_ranks)
				d1 += RR
				d1 += ";"
		//	world << "2.6: [d1]"
			// END DEBUG BLOCK

			for (var/RR in req_ranks)
				if (RR == "default")
					req_ranks += "master"
					req_ranks -= RR

			// DEBUG BLOCK
			d1 = ""
			for (var/RR in req_ranks)
				d1 += RR
				d1 += ";"
		//	world << "2.7: [d1]"
			// END DEBUG BLOCK

			var/_call = parts[3]
		//	world << "3. [req_word];[req_ranks[1]];[_call]"

			var/list/command_types = list(
				"attack_mode" = list("attack", "kill", "guard"),
				"patrol" = list("patrol", "stop patrolling"),
				"anything" = list("be passive", "stop everything",
					"follow", "stop following"))

			if (dd_hasprefix(lowertext(message), req_word) || lowertext(message) == req_word)
			//	world << "4. [message] v. [req_word]"

				var/command_type_sublist = null
				for (var/key in command_types)
					if (locate(req_word) in command_types[key])
						command_type_sublist = key

				var/command_level_to_dog = COMMAND_LEVEL_4

				if (H == owner)
					command_level_to_dog = COMMAND_LEVEL_1
				else if (H.civilization == faction && map.civilizations)
					command_level_to_dog = COMMAND_LEVEL_3
				else if (H.faction_text == faction && !map.civilizations)
					command_level_to_dog = COMMAND_LEVEL_3
				else if (!owner && !faction)
					command_level_to_dog = COMMAND_LEVEL_4

				// daga kotowaru
				if (command_level_to_dog == COMMAND_LEVEL_4)
					visible_message("<span class = 'warning'>\The [name] refuses to listen.</span>")
					continue

				if (command_levels[command_type_sublist] > command_level_to_dog)
					visible_message("<span class = 'warning'>\The [name] refuses to listen, because it already has a contradicting order from its owner.</span>")
					continue
				else if (hascall(src, _call))
					call(src, _call)(H)

					switch (req_word)
						if ("attack", "kill", "guard")
							command_levels["attack_mode"] = command_level_to_dog
							command_levels["anything"] = command_level_to_dog
						if ("patrol", "stop patrolling", "follow")
							command_levels["patrol"] = command_level_to_dog
							command_levels["anything"] = command_level_to_dog
s
/mob/living/simple_animal/complex_animal/dog/can_wander_specialcheck()
	if (faction && pulledby && check_can_command(list("master", "team"), pulledby))
		return FALSE
	return TRUE

/mob/living/simple_animal/complex_animal/dog/can_rest_specialcheck()
	if (!can_wander_specialcheck())
		return FALSE
	if (attack_mode != -1 || patrolling)
		return FALSE

// "frontend" procs
/mob/living/simple_animal/complex_animal/dog/proc/attack(var/mob/living/carbon/human/H)
	if (!(attack_mode == "attack"))
		visible_message("<span class = 'warning'>\The [src] looks around aggressively.</span>")
	attack_mode = "attack"
	onModeChange()

/mob/living/simple_animal/complex_animal/dog/proc/kill(var/mob/living/carbon/human/H)
	if (!(attack_mode == "kill"))
		visible_message("<span class = 'warning'>\The [src] looks around murderously.</span>")
	attack_mode = "kill"
	onModeChange()

/mob/living/simple_animal/complex_animal/dog/proc/guard(var/mob/living/carbon/human/H)
	if (!(attack_mode == "guard"))
		visible_message("<span class = 'warning'>\The [src] starts guarding their domain.</span>")
	attack_mode = "guard"
	onModeChange()

/mob/living/simple_animal/complex_animal/dog/proc/patrol(var/mob/living/carbon/human/H)
	if (!patrolling)
		visible_message("<span class = 'warning'>\The [src] starts patrolling.</span>")
	patrolling = TRUE
	allow_moving_outside_home = TRUE
	wander_probability = 80
	onModeChange()

/mob/living/simple_animal/complex_animal/dog/proc/stop_patrol(var/mob/living/carbon/human/H)
	if (patrolling)
		visible_message("<span class = 'warning'>\The [src] stops patrolling.</span>")
	patrolling = FALSE
	allow_moving_outside_home = FALSE
	wander_probability = 20
	onModeChange()

/mob/living/simple_animal/complex_animal/dog/proc/passive(var/mob/living/carbon/human/H)
	if (attack_mode != -1)
		visible_message("<span class = 'notice'>\The [src] looks calm.</span>")
	attack_mode = -1
	onModeChange()

/mob/living/simple_animal/complex_animal/dog/proc/stop(var/mob/living/carbon/human/H)
	passive()
	stop_patrol()
	visible_message("<span class = 'notice'>\The [src] stops doing everything they were doing.</span>")
	onModeChange()

/mob/living/simple_animal/complex_animal/dog/proc/follow(var/mob/living/carbon/human/H)
	visible_message("<span class = 'notice'>\The [src] starts following [H].</span>")
	if (following)
		stop_following(H, FALSE)
	else
		walking_to = null
	walking_to = H
	following = H

/mob/living/simple_animal/complex_animal/dog/proc/stop_following(var/mob/living/carbon/human/H, var/message = TRUE)
	if (following)
		if (message)
			visible_message("<span class = 'notice'>\The [src] stops following [following].</span>")
		walking_to = null
		following = null

/mob/living/simple_animal/complex_animal/dog/proc/prioritize_following(var/mob/living/carbon/human/H)
	var/o_prioritizes = prioritizes
	prioritizes = "following"
	if (o_prioritizes != prioritizes)
		visible_message("<span class = 'notice'>\The [src] will no longer attack enemies when it is following somebody.</span>")

/mob/living/simple_animal/complex_animal/dog/proc/prioritize_attacking(var/mob/living/carbon/human/H)
	var/o_prioritizes = prioritizes
	prioritizes = "attacking"
	if (o_prioritizes != prioritizes)
		visible_message("<span class = 'notice'>\The [src] will no longer follow you when it is attacking somebody.</span>")

/mob/living/simple_animal/complex_animal/dog/proc/onModeChange()
	for (var/mob/living/carbon/human/H in view(10, src))
		onHumanMovement(H)

// dog life
/mob/living/simple_animal/complex_animal/dog/onEveryLifeTick()
	. = ..()
	if (. == TRUE && faction)
		for (var/mob/living/carbon/human/H in player_list)

			var/area/H_area = get_area(H)
			var/area/src_area = get_area(src)

			var/H_area_check = H_area
			if (H_area_check)
				H_area_check = istype(H_area_check, /area/caribbean)
			var/mob_faction = "none"
			if (map.civilizations)
				mob_faction = H.civilization
			else
				mob_faction = H.faction_text

			if (H.loc && H.z == z && H_area_check && H.client && H.stat == CONSCIOUS && mob_faction != faction)

				if (H_area.is_void_area && H_area != src_area)
					continue

				var/dist = abs_dist(H, src)
				var/maxdist = 13
				if (!locate(H) in view(7, src) && dist <= maxdist)
					if (prob(5) && world.time >= next_bork)
						visible_message("<span class = 'danger'>\The [src] starts barking! It smells an enemy!</span>")
						if (prob(50))
							playsound(src.loc, 'sound/animals/dogbark1.ogg', 100, TRUE, 3)
						else
							playsound(src.loc, 'sound/animals/dogbark2.ogg', 100, TRUE, 3)
						next_bork = world.time + 500 // shut the fuck up dogs - kachnov
						return

// dog combat

/mob/living/simple_animal/complex_animal/dog/var/next_shred = -1
/mob/living/simple_animal/complex_animal/dog/proc/shred(var/mob/living/carbon/human/H)
	if (stat == CONSCIOUS && !resting && H.stat != DEAD && H.getBruteLoss() <= 500)
		if (world.time >= next_shred)
			if (H in range(1, src))
				dir = get_dir(src, H)
				visible_message("<span class = 'warning'>\The [src] shreds [H] with their teeth!</span>")
				H.adjustBruteLoss(rand(8,12)/H.getStatCoeff("strength"))
				playsound(get_turf(src), 'sound/weapons/bite.ogg', rand(70,80))
				next_shred = world.time + 20
				spawn (20)
					if (!client)
						shred(H)
		else if (H in range(1, src))
			spawn (20)
				if (!client)
					shred(H)

// things we do when someone touches us
/mob/living/simple_animal/complex_animal/dog/onTouchedBy(var/mob/living/carbon/human/H, var/intent = I_HELP)
	if (..(H, intent) && stat == CONSCIOUS && !resting)
		switch (intent)
			if (I_HURT)

				enemies |= H

				spawn (rand(2,3))
					shred(H)

				// make other dogs go after them too
				for (var/mob/living/simple_animal/complex_animal/dog/D in view(7, H))
					if (D.faction == faction)
						D.enemies |= H
						D.onHumanMovement(H)

/* things we do when someone attacks us */
/mob/living/simple_animal/complex_animal/dog/onAttackedBy(var/mob/living/carbon/human/H, var/obj/item/weapon/W)
	if (..(H, W) && stat == CONSCIOUS && !resting)
		if (W.force > resistance)

			enemies |= H
			processes.callproc.queue(src, /mob/living/simple_animal/complex_animal/dog/proc/shred, list(H), 2)

			// make other dogs go after them too
			for (var/mob/living/simple_animal/complex_animal/dog/D in view(7, H))
				if (D.faction == faction)
					D.enemies |= H
					D.onHumanMovement(H)

/mob/living/simple_animal/complex_animal/dog/proc/hostileCheck(var/mob/living/carbon/human/H)
	if (!H.original_job)
		return TRUE
	if (map.civilizations)
		if (faction != H.civilization)
			. = ((istype(H.l_hand, /obj/item/weapon/gun) || istype(H.r_hand, /obj/item/weapon/gun)) || (istype(H.l_hand, /obj/item/weapon/material) || istype(H.r_hand, /obj/item/weapon/material)))
	else
		if (H.original_job.base_type_flag() == CIVILIAN)
			. = (istype(H.l_hand, /obj/item/weapon/gun) || istype(H.r_hand, /obj/item/weapon/gun))
		if (H.original_job.base_type_flag() == CIVILIAN)
			. = (istype(H.l_hand, /obj/item/weapon/material) || istype(H.r_hand, /obj/item/weapon/material))
		else
			. = faction != H.original_job.base_type_flag()

/* check if we should go after an enemy */
/mob/living/simple_animal/complex_animal/dog/proc/shouldGoAfter(var/mob/living/carbon/human/H)
	. = FALSE // when can we attack random enemies who enter our area
	if (attack_mode == "kill")
		. = TRUE
	else if (attack_mode == "attack")
		if (hostileCheck(H))
			. = TRUE
	else if (attack_mode == "guard")
		if (get_area(H) == get_area(src) && hostileCheck(H))
			. = TRUE

/* called after H added to knows_about_mobs() */
/mob/living/simple_animal/complex_animal/dog/onHumanMovement(var/mob/living/carbon/human/H)
	if (..(H) && stat == CONSCIOUS && !resting && (!following || prioritizes == "attacking"))
		if (shouldGoAfter(H) || enemies.Find(H))
			if (assess_hostility(H) || ((!H.original_job || H.original_job.base_type_flag() != faction)))
				enemies |= H
				if (get_dist(src, H) > 1 && H.stat != DEAD)
					if (prioritizes == "attacking" && following)
						stop_following()
					walking_to = H
				else
					shred(H)
	else if (following)
		walking_to = following
	else if (stat != CONSCIOUS || resting)
		walking_to = null

/mob/living/simple_animal/complex_animal/dog/Move()
	. = ..()
	if (stat == CONSCIOUS && !resting)
		for (var/mob/living/carbon/human/H in get_step(src, dir))
			if (assess_hostility(H) && shouldGoAfter(H) && !client)
				shred(H)
			else if (client)
				walking_to = null

/mob/living/simple_animal/complex_animal/dog/onEveryBaseTypeMovement(var/mob/living/simple_animal/complex_animal/C)
	return

/mob/living/simple_animal/complex_animal/dog/onEveryXMovement(var/mob/X)
	return