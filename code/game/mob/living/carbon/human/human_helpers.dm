#define HUMAN_EATING_NO_ISSUE		0
#define HUMAN_EATING_NO_MOUTH		1
#define HUMAN_EATING_BLOCKED_MOUTH	2

#define RAD_LEVEL_NORMAL 15 //0.15 Gy, equal to 1 year smoking 1 1/2 packs of cigarettes a day. Avg dose for Chernobyl recovery workers.
#define RAD_LEVEL_MODERATE 40 //Gives mild radiation poisoning symptoms (vomiting, erytrema)
#define RAD_LEVEL_HIGH 100 //Gives radiation poisoning (passing out, twitches, severe erytrema)
#define RAD_LEVEL_VERY_HIGH 200 //Severe radiation poisoning, sometimes fatal
#define RAD_LEVEL_CRITICAL 300 //LD50
#define RAD_LEVEL_DEADLY 500 //Always kills

#define add_clothing_protection(A)	\
	var/obj/item/clothing/C = A; \
	flash_protection += C.flash_protection; \
	equipment_tint_total += C.tint;

/mob/living/human/can_eat(var/food, var/feedback = TRUE)
	var/list/status = can_eat_status()
	if (status[1] == HUMAN_EATING_NO_ISSUE)
		return TRUE
	if (feedback)
		if (status[1] == HUMAN_EATING_NO_MOUTH)
			src << "Where do you intend to put \the [food]? You don't have a mouth!"
		else if (status[1] == HUMAN_EATING_BLOCKED_MOUTH)
			src << SPAN_WARNING("\The [status[2]] is in the way!")
	return FALSE

/mob/living/human/can_force_feed(var/feeder, var/food, var/feedback = TRUE)
	var/list/status = can_eat_status()
	if (status[1] == HUMAN_EATING_NO_ISSUE)
		return TRUE
	if (feedback)
		if (status[1] == HUMAN_EATING_NO_MOUTH)
			feeder << "Where do you intend to put \the [food]? \The [src] doesn't have a mouth!"
		else if (status[1] == HUMAN_EATING_BLOCKED_MOUTH)
			feeder << SPAN_WARNING("\The [status[2]] is in the way!")
	return FALSE

/mob/living/human/proc/can_eat_status()
	if (!check_has_mouth())
		return list(HUMAN_EATING_NO_MOUTH)
	var/obj/item/blocked = check_mouth_coverage()
	if (blocked)
		return list(HUMAN_EATING_BLOCKED_MOUTH, blocked)
	return list(HUMAN_EATING_NO_ISSUE)

#undef HUMAN_EATING_NO_ISSUE
#undef HUMAN_EATING_NO_MOUTH
#undef HUMAN_EATING_BLOCKED_MOUTH

/mob/living/human/proc/update_equipment_vision()
	flash_protection = FALSE
	equipment_tint_total = FALSE
	equipment_see_invis	= FALSE
	equipment_vision_flags = FALSE
	equipment_prescription = FALSE
	equipment_darkness_modifier = FALSE
//	equipment_overlays.Cut()

	if (istype(head, /obj/item/clothing/head))
		add_clothing_protection(head)
	if (istype(eyes, /obj/item/clothing/glasses))
		var/obj/item/clothing/glasses/GL = eyes
		process_glasses(GL)
	if (istype(wear_mask, /obj/item/clothing/mask))
		add_clothing_protection(wear_mask)

/mob/living/human/proc/process_glasses(var/obj/item/clothing/glasses/G)
	if (G && G.active)
		equipment_darkness_modifier += G.darkness_view
		equipment_vision_flags |= G.vision_flags

		if (G.see_invisible >= 0)
			if (equipment_see_invis)
				equipment_see_invis = min(equipment_see_invis, G.see_invisible)
			else
				equipment_see_invis = G.see_invisible


/mob/living/human/verb/mob_sleep()
	set name = "Sleep"
	set category = "IC"

	if(map && map.ID == MAP_VOYAGE)
		WWalert("You cannot use this function on this map.","Disabled",usr)
		return

	if (disease)
		to_chat(usr, SPAN_RED("You toss and turn but you are too unwell to sleep."))
		return

	for (var/obj/item/clothing/C in list(wear_suit,w_uniform,shoes))
		if (C.fleas == TRUE)
			to_chat(usr, SPAN_RED("You toss and turn but your skin is crawling and you can not sleep."))
			return

	if (hygiene <= 80)
		to_chat(usr, SPAN_RED("You toss and turn but you are too filthy to sleep."))
		return

	if (usr.sleeping)
		to_chat(usr, SPAN_RED("You are already sleeping."))
		return
	var/found = FALSE
	for (var/obj/structure/bed/B in get_turf(src))
		if (B)
			found = TRUE
	if (!found)
		to_chat(usr, SPAN_RED("You need to be over a bed."))
		return
	if (WWinput(src, "Are you sure you want to sleep for a while? This will protect you when disconnected, but you must stay ingame for 2 minutes for it to take effect.", "Sleep", "Yes", list("Yes","No")) == "Yes")
		to_chat(usr, SPAN_NOTICE("You will start sleeping in two minutes."))
		if (do_after(src, 2 MINUTES, src, FALSE))
			if (usr.sleeping)
				return
			else
				found = FALSE
				for (var/obj/structure/bed/B in get_turf(src))
					if (B)
						found = TRUE
				if (!found)
					to_chat(usr, SPAN_RED("You need to be over a bed."))
					return
				else
					lastx = usr.x
					lasty = usr.y
					lastz = usr.z
					usr.sleeping = 66 //nap
					inducedSSD = TRUE
					usr.drop_item()
					sleep_update()
					usr.forceMove(locate(1,1,1))
					return
		else
			to_chat(usr, SPAN_NOTICE("You stop trying to sleep"))

/mob/living/human/verb/mob_wakeup()
	set name = "Wake Up"
	set category = "IC"

	if (!usr.sleeping && !inducedSSD)
		to_chat(usr, SPAN_RED("You are already awake."))
		return
	if (!inducedSSD)
		to_chat(usr, SPAN_RED("You aren't asleep that deeply, just wait."))
		return
	if (inducedSSD && WWinput(src, "Are you sure you want to wake up? This will take 30 seconds.", "Wake Up", "Yes", list("Yes","No")) == "Yes")
		to_chat(usr, "You will wake up in 30 seconds.")
		spawn(300)
			usr.forceMove(locate(lastx,lasty,lastz))
			usr.sleeping = 0 //Short nap
			inducedSSD = FALSE
			return

//to keep the character sleeping
/mob/living/human/proc/sleep_update()
	if (!inducedSSD)
		return
	else
		sleeping = 66
		spawn(600) // 1 minute
			sleep_update()
			return

/mob/living/human/handle_mutations_and_radiation()
	get_rads_from_equipment()

	if (global_radiation > 125)
		var/area/A = get_area(src)
		var/multiplier = 0.7
		if (A.location == 1)
			if (global_radiation >= 300)
				switch(A.weather)
					if (WEATHER_NONE)
						multiplier = 1
					if (WEATHER_WET)
						multiplier = 1.5
					if (WEATHER_EXTREME)
						multiplier = 2
					if (WEATHER_SMOG)
						multiplier = 1
		if (z == world.maxz)
			rad_act((global_radiation/1000)*multiplier)
	if(radiation > 0)
		radiation -= 0.05
		if (stat != DEAD)
			switch(radiation)
				if(RAD_LEVEL_NORMAL to RAD_LEVEL_MODERATE) //0.15 Gy, equal to 1 year smoking 1 1/2 packs of cigarettes a day. Avg dose for Chernobyl recovery workers
					if (prob(0.5))
						to_chat(src, "You feel slightly nauseous.")
				if(RAD_LEVEL_MODERATE to RAD_LEVEL_HIGH)//Gives radiation poisoning (passing out, twitches, severe erytrema)
					if (prob(1))
						to_chat(src, "You feel nauseous.")
					if (prob(0.5))
						emote("twitch")
					if (prob(0.5))
						to_chat(src, SPAN_WARNING("You suddently pass out!"))
						paralysis = 6
						sleeping  = 6
				if(RAD_LEVEL_HIGH to RAD_LEVEL_VERY_HIGH) //Gives mild radiation poisoning symptoms (vomiting, erytrema)
					if (prob(2))
						to_chat(src, "You feel very nauseous.")
					if (prob(1.5))
						emote("twitch")
					if (prob(0.5))
						to_chat(src, SPAN_WARNING("You suddently pass out!"))
						paralysis = 6
						sleeping  = 6
					if (prob(1.5))
						vomit()
				if(RAD_LEVEL_VERY_HIGH to RAD_LEVEL_CRITICAL) //Severe radiation poisoning, sometimes fatal
					adjustBrainLoss(0.05)
					if (prob(2.5))
						to_chat(src, SPAN_WARNING("You suddently pass out!"))
						paralysis = 8
						sleeping  = 8
					if (prob(2))
						vomit_blood()
				if(RAD_LEVEL_CRITICAL to RAD_LEVEL_DEADLY) //LD50
					adjustBrainLoss(0.07)
					if (prob(3))
						death()
					if (prob(4))
						to_chat(src, SPAN_WARNING("You suddently pass out!"))
						paralysis = 8
						sleeping  = 8
					if (prob(2))
						vomit_blood()
				if(RAD_LEVEL_DEADLY to INFINITY) //Always kills
					death()

		if(radiation >= 100)
			adjustBurnLoss(radiation*0.002)
		updatehealth()

		if (radiation < 0)
			radiation = 0
		else if (radiation > 750)
			radiation = 750

/mob/living/human/proc/get_rads_from_equipment()
	if (head && head.radiation>0)
		rad_act(head.radiation/6/1500)

	if (wear_suit && wear_suit.radiation>0)
		rad_act(wear_suit.radiation/4/1500)

	if (w_uniform && w_uniform.radiation>0)
		rad_act(w_uniform.radiation/4/1500)

	if (gloves && gloves.radiation>0)
		rad_act(gloves.radiation/10/1500)

	if (shoes && shoes.radiation>0)
		rad_act(shoes.radiation/10/1500)

	if (wear_mask && wear_mask.radiation>0)
		rad_act(wear_mask.radiation/10/1500)

/mob/living/human
	var/roofs_removed = TRUE

/mob/living/human/proc/process_turret_roofs()
	if (!client)
		return

	var/view_dist = client.view + 5 // + reserve so that when moving the load is not visible [translated]

	var/view_x_offset = 0
	var/view_y_offset = 0

	if(client.pixel_x > 0)
		view_x_offset = client.view
	else if(client.pixel_x < 0)
		view_x_offset = -client.view

	if(client.pixel_y > 0)
		view_y_offset = client.view
	else if(client.pixel_y < 0)
		view_y_offset = -client.view

	var/view_loc = locate(x + view_x_offset, y + view_y_offset, z)

	for (var/image/tmpimg in client.images)
		if (tmpimg.icon == 'icons/obj/vehicles/vehicles256x256.dmi')
			if(get_dist(tmpimg, view_loc) < view_dist)
				client.images.Remove(tmpimg)

	for (var/obj/structure/turret/T in range(view_dist, view_loc))
		client.images += T.turret_image
		client.images += T.turret_roof_image

	if (buckled && looking)
		return

	for (var/obj/structure/turret/T in range(1, view_loc))

		var/obj/structure/vehicleparts/frame/turret_vehicle = null
		var/obj/structure/vehicleparts/frame/client_vehicle = null

		for(var/obj/structure/vehicleparts/frame/FR in T.loc)
			turret_vehicle = FR
		for(var/obj/structure/vehicleparts/frame/FR in loc)
			client_vehicle = FR

		if(turret_vehicle && client_vehicle)
			if(turret_vehicle.axis == client_vehicle.axis)
				client.images -= T.turret_roof_image
		else if(!turret_vehicle && !client_vehicle)
			client.images -= T.turret_roof_image

/mob/living/human/proc/process_vehicle_roofs()
	if (!client)
		return

	var/view_dist = client.view + 5 // + reserve so that when moving the load is not visible [translated]

	var/view_x_offset = 0
	var/view_y_offset = 0

	if(client.pixel_x > 0)
		view_x_offset = client.view
	else if(client.pixel_x < 0)
		view_x_offset = -client.view

	if(client.pixel_y > 0)
		view_y_offset = client.view
	else if(client.pixel_y < 0)
		view_y_offset = -client.view

	var/view_loc = locate(x + view_x_offset, y + view_y_offset, z)

	var/obj/structure/vehicleparts/frame/found = null

	for (var/image/tmpimg in client.images)
		if (tmpimg.icon == 'icons/obj/vehicles/vehicleparts.dmi' || tmpimg.icon == 'icons/obj/vehicles/vehicles96x96.dmi' || tmpimg.icon == 'icons/obj/vehicles/vehicles128x128.dmi' || tmpimg.icon == 'icons/obj/vehicles/apcparts.dmi' || tmpimg.icon == 'icons/obj/vehicles/tankparts.dmi' || tmpimg.icon == 'icons/obj/vehicles/tankparts96x96.dmi' || tmpimg.icon == 'icons/obj/vehicles/apcparts96x96.dmi'  || tmpimg.icon == 'icons/obj/vehicles/tankparts96x96_damaged.dmi' || tmpimg.icon == 'icons/obj/vehicles/apcparts96x96_damaged.dmi')
			if(get_dist(tmpimg, view_loc) < view_dist)
				client.images.Remove(tmpimg)
	for (var/obj/structure/vehicleparts/frame/FRL in loc)
		found = FRL
	for (var/obj/structure/vehicleparts/frame/FR in range(view_dist, view_loc))
		if (found)
			if ((FR.axis != found.axis && FR != found) || (buckled && looking))
				client.images += FR.roof
			else
				client.images -= FR.roof
		else
			if (locate(FR) in range(view_dist, view_loc))
				client.images += FR.roof

/mob/living/human/proc/process_static_roofs()
	if (!client)
		return
	var/area/A = get_area(loc)
	if (A && A.location == AREA_INSIDE)
		if (!roofs_removed)
			client.images = (client.images ^ roofs_list)
			roofs_removed = TRUE
	else
		if (roofs_removed)
			client.images |= roofs_list
			roofs_removed = FALSE

/mob/living/human
	var/drowning = FALSE
	var/water_overlay = FALSE
/mob/living/human/proc/handle_drowning()
	var/turf/T = get_turf(src)
	if (istype(wear_suit, /obj/item/clothing/suit/lifejacket) && istype(T, /turf/floor/beach/water/deep) && !T.iscovered())
		drowning = FALSE
		water_overlay = TRUE
		update_fire(1)
		return
	if (!istype(T, /turf/floor/beach/water/deep) || T.iscovered())
		drowning = FALSE
		if (((istype(T, /turf/floor/beach/water) && !istype(T, /turf/floor/beach/water/ice)) || istype(T, /turf/floor/trench/flooded)) && !T.iscovered())
			water_overlay = TRUE
			update_fire(1)
			return
		else
			water_overlay = FALSE
			if (plane == FLOOR_PLANE)
				plane = GAME_PLANE
			if (!on_fire)
				overlays_standing[25] = null
			return
	else
		var/turf/floor/beach/water/deep/D = T
		if (D.iscovered())
			drowning = FALSE
			water_overlay = FALSE
			return
		else if (buckled && istype(buckled, /obj/structure/vehicle/boat))
			drowning = FALSE
			water_overlay = FALSE
			return
		else
			for(var/obj/structure/vehicle/boat/BT in range(1,src))
				if(src in BT.ontop)
					drowning = FALSE
					water_overlay = FALSE
					return
			drowning = TRUE
			src << SPAN_WARNING("<font size='2'>You are drowning!</font>")
			update_fire(1)
			adjustOxyLoss(10)
			return
	return
