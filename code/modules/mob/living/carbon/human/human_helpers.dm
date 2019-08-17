#define HUMAN_EATING_NO_ISSUE		0
#define HUMAN_EATING_NO_MOUTH		1
#define HUMAN_EATING_BLOCKED_MOUTH	2

#define add_clothing_protection(A)	\
	var/obj/item/clothing/C = A; \
	flash_protection += C.flash_protection; \
	equipment_tint_total += C.tint;

/mob/living/carbon/human/can_eat(var/food, var/feedback = TRUE)
	var/list/status = can_eat_status()
	if (status[1] == HUMAN_EATING_NO_ISSUE)
		return TRUE
	if (feedback)
		if (status[1] == HUMAN_EATING_NO_MOUTH)
			src << "Where do you intend to put \the [food]? You don't have a mouth!"
		else if (status[1] == HUMAN_EATING_BLOCKED_MOUTH)
			src << "<span class='warning'>\The [status[2]] is in the way!</span>"
	return FALSE

/mob/living/carbon/human/can_force_feed(var/feeder, var/food, var/feedback = TRUE)
	var/list/status = can_eat_status()
	if (status[1] == HUMAN_EATING_NO_ISSUE)
		return TRUE
	if (feedback)
		if (status[1] == HUMAN_EATING_NO_MOUTH)
			feeder << "Where do you intend to put \the [food]? \The [src] doesn't have a mouth!"
		else if (status[1] == HUMAN_EATING_BLOCKED_MOUTH)
			feeder << "<span class='warning'>\The [status[2]] is in the way!</span>"
	return FALSE

/mob/living/carbon/human/proc/can_eat_status()
	if (!check_has_mouth())
		return list(HUMAN_EATING_NO_MOUTH)
	var/obj/item/blocked = check_mouth_coverage()
	if (blocked)
		return list(HUMAN_EATING_BLOCKED_MOUTH, blocked)
	return list(HUMAN_EATING_NO_ISSUE)

#undef HUMAN_EATING_NO_ISSUE
#undef HUMAN_EATING_NO_MOUTH
#undef HUMAN_EATING_BLOCKED_MOUTH

/mob/living/carbon/human/proc/update_equipment_vision()
	flash_protection = FALSE
	equipment_tint_total = FALSE
	equipment_see_invis	= FALSE
	equipment_vision_flags = FALSE
	equipment_prescription = FALSE
	equipment_darkness_modifier = FALSE
//	equipment_overlays.Cut()

	if (istype(head, /obj/item/clothing/head))
		add_clothing_protection(head)
	if (istype(wear_mask, /obj/item/clothing/glasses))
		var/obj/item/clothing/glasses/GL = wear_mask
		process_glasses(GL)
	if (istype(wear_mask, /obj/item/clothing/mask))
		add_clothing_protection(wear_mask)

/mob/living/carbon/human/proc/process_glasses(var/obj/item/clothing/glasses/G)
	if (G && G.active)
		equipment_darkness_modifier += G.darkness_view
		equipment_vision_flags |= G.vision_flags

		if (G.see_invisible >= 0)
			if (equipment_see_invis)
				equipment_see_invis = min(equipment_see_invis, G.see_invisible)
			else
				equipment_see_invis = G.see_invisible


/mob/living/carbon/human/verb/mob_sleep()
	set name = "Sleep"
	set category = "IC"

	if (usr.sleeping)
		usr << "<span class = 'red'>You are already sleeping.</span>"
		return
	var/found = FALSE
	for (var/obj/structure/bed/B in get_turf(src))
		if (B)
			found = TRUE
	if (!found)
		usr << "<span class = 'red'>You need to be over a bed.</span>"
		return
	if (WWinput(src, "Are you sure you want to sleep for a while? This will protect you when disconnected, but takes 2 minutes to take effect.", "Sleep", "Yes", list("Yes","No")) == "Yes")
		usr << "You will start sleeping in two minutes."
		spawn(1200)
			if (usr.sleeping)
				return
			else
				found = FALSE
				for (var/obj/structure/bed/B in get_turf(src))
					if (B)
						found = TRUE
				if (!found)
					usr << "<span class = 'red'>You need to be over a bed.</span>"
					return
				else
					lastx = usr.x
					lasty = usr.y
					lastz = usr.z
					usr.sleeping = 20 //Short nap
					inducedSSD = TRUE
					sleep_update()
					usr.forceMove(locate(1,1,1))
					return
/mob/living/carbon/human/verb/mob_wakeup()
	set name = "Wake Up"
	set category = "IC"

	if (!usr.sleeping)
		usr << "<span class = 'red'>You are already awake.</span>"
		return
	if (WWinput(src, "Are you sure you want to wake up? This will take 30 seconds.", "Wake Up", "Yes", list("Yes","No")) == "Yes")
		usr << "You will wake up in 30 seconds."
		spawn(300)
			usr.sleeping = 0 //Short nap
			inducedSSD = FALSE
			usr.forceMove(locate(lastx,lasty,lastz))
			return
//to keep the character sleeping
/mob/living/carbon/human/proc/sleep_update()
	if (!inducedSSD)
		return
	else
		sleeping = 20
		spawn(600)
			sleep_update()
			return

/mob/living/carbon/human/handle_mutations_and_radiation()
	if (world_radiation > 125)
		var/area/A = get_area(src)
		if (A.location == 1)
			var/multiplier = 1
			if (world_radiation >= 300)
				switch(A.weather)
					if (WEATHER_NONE)
						multiplier = 1
					if (WEATHER_RAIN)
						multiplier = 1.5
					if (WEATHER_SNOW)
						multiplier = 1.5
					if (WEATHER_BLIZZARD)
						multiplier = 3
					if (WEATHER_SANDSTORM)
						multiplier = 1.3
					if (WEATHER_STORM)
						multiplier = 2
					if (WEATHER_SMOG)
						multiplier = 1
			radiation += (world_radiation/1000)*multiplier
	if(radiation)
		radiation -= 0.05
		if (stat != DEAD)
			return
			switch(radiation)
				if(RAD_LEVEL_NORMAL to RAD_LEVEL_MODERATE) //0.15 Gy, equal to 1 year smoking 1 1/2 packs of cigarettes a day. Avg dose for Chernobyl recovery workers
					if (prob(0.5))
						src << "You feel slighly nauseous."
				if(RAD_LEVEL_MODERATE to RAD_LEVEL_HIGH)//Gives radiation poisoning (passing out, twitches, severe erytrema)
					if (prob(1))
						src << "You feel nauseous."
					if (prob(0.5))
						emote("twitch")
					if (prob(0.5))
						src << "<span class='warning'>You suddently pass out!</span>"
						paralysis = 6
						sleeping  = 6
				if(RAD_LEVEL_HIGH to RAD_LEVEL_VERY_HIGH) //Gives mild radiation poisoning symptoms (vomiting, erytrema)
					if (prob(2))
						src << "You feel very nauseous."
					if (prob(1.5))
						emote("twitch")
					if (prob(0.5))
						src << "<span class='warning'>You suddently pass out!</span>"
						paralysis = 6
						sleeping  = 6
					if (prob(1.5))
						vomit()
				if(RAD_LEVEL_VERY_HIGH to RAD_LEVEL_CRITICAL) //Severe radiation poisoning, sometimes fatal
					adjustBrainLoss(0.05)
					if (prob(2.5))
						src << "<span class='warning'>You suddently pass out!</span>"
						paralysis = 8
						sleeping  = 8
					if (prob(2))
						vomit_blood()
				if(RAD_LEVEL_CRITICAL to RAD_LEVEL_DEADLY) //LD50
					adjustBrainLoss(0.07)
					if (prob(3))
						death()
					if (prob(4))
						src << "<span class='warning'>You suddently pass out!</span>"
						paralysis = 8
						sleeping  = 8
					if (prob(2))
						vomit_blood()
				if(RAD_LEVEL_DEADLY to INFINITY) //Always kills
					death()

		if(radiation >= 100)
			adjustFireLoss(radiation*0.002)
		updatehealth()

		radiation = Clamp(radiation, 0, 750)