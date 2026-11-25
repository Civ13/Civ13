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
			to_chat(src, "Where do you intend to put \the [food]? You don't have a mouth!")
		else if (status[1] == HUMAN_EATING_BLOCKED_MOUTH)
			to_chat(src, SPAN_WARNING("\The [status[2]] is in the way!"))
	return FALSE

// Voluntary solid-food eating must respect the same diet through either bite path.
/mob/living/human/proc/can_eat_solid_food_diet(non_vegetarian)
	if (gorillaman || find_trait("Vegan"))
		if (non_vegetarian)
			to_chat(src, SPAN_WARNING("You are a vegan/herbivore! You can't eat this!"))
			return FALSE
	else if (wolfman || crab || find_trait("Carnivore"))
		if (!non_vegetarian)
			to_chat(src, SPAN_WARNING("You are a carnivore! You can't eat this!"))
			return FALSE
	return TRUE

/mob/living/human/can_force_feed(var/feeder, var/food, var/feedback = TRUE)
	var/list/status = can_eat_status()
	if (status[1] == HUMAN_EATING_NO_ISSUE)
		return TRUE
	if (feedback)
		if (status[1] == HUMAN_EATING_NO_MOUTH)
			to_chat(feeder, "Where do you intend to put \the [food]? \The [src] doesn't have a mouth!")
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
	equipment_darkness_modifier = FALSE

	if (istype(head, /obj/item/clothing/head))
		add_clothing_protection(head)
	if (istype(eyes, /obj/item/clothing/glasses))
		var/obj/item/clothing/glasses/GL = eyes
		add_clothing_protection(GL) // toggled-off optics zero their own protection and tint
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


// The old protected-sleep zone was (1,1,1), and existing maps also mark it as
// the admin zone. Nothing sends bodies there any more; this only lets saved
// bodies still parked there be moved back into the world when they return.
/proc/is_protected_sleep_location(atom/location)
	var/turf/T = get_turf(location)
	return T && (T == locate(1,1,1) || istype(T.loc, /area/caribbean/admin))

// Releases only this body's reciprocal seat (used to move old zone residents).
/mob/living/human/proc/release_protected_sleep_buckle()
	if (!buckled)
		return TRUE
	var/obj/seat = buckled
	if (seat.buckled_mob != src)
		return FALSE
	seat.unbuckle_mob()
	return !buckled && (!seat || seat.buckled_mob != src)

// Sleeping keeps the body where it lies: hunger slows and it can still be hurt.
/mob/living/human/proc/enter_bed_sleep()
	if (persistence_sleep_transfer_blocked() || inducedSSD || stat == DEAD)
		return FALSE
	sleeping = 66
	inducedSSD = TRUE
	offline_sleep_protection_lifted = FALSE
	if (s_active)
		s_active.close(src)
	sleep_update()
	return TRUE

/mob/living/human/verb/mob_sleep()
	set name = "Sleep"
	set category = "IC"

	if (usr != src || !client || client.mob != src)
		return
	var/client/sleeping_client = client
	if (persistence_sleep_transfer_blocked())
		to_chat(src, SPAN_RED("Wait for the world save or load to finish before sleeping."))
		return

	if(map && map.ID == MAP_VOYAGE)
		WWalert("You cannot use this function on this map.","Disabled",src)
		return

	// The sick may sleep: rest is what an illness needs (resting_in_bed()), and
	// refusing left a sick character unable to assign a bed or log off safely.

	for (var/obj/item/clothing/C in list(wear_suit,w_uniform,shoes))
		if (C.fleas == TRUE)
			to_chat(src, SPAN_RED("You toss and turn but your skin is crawling and you can not sleep."))
			return

	if (hygiene < HYGIENE_LEVEL_DIRTY) // the same "filthy" line as mood and self-examine
		to_chat(src, SPAN_RED("You toss and turn but you are too filthy to sleep."))
		return

	if (sleeping)
		to_chat(src, SPAN_RED("You are already sleeping."))
		return
	// A sleep flag whose refresh loop has stopped leaves an awake body that Sleep
	// would refuse forever; the player is evidently awake, so clear it.
	if (inducedSSD)
		inducedSSD = FALSE
	var/turf/sleep_turf = get_turf(src)
	var/found = FALSE
	for (var/obj/structure/bed/B in sleep_turf)
		if (B)
			found = TRUE
	if (!found)
		to_chat(src, SPAN_RED("You need to be over a bed."))
		return
	var/registered_bed_sleep = persistence_bed_return_enabled()
	if (registered_bed_sleep && saved_bed_taken_here())
		to_chat(src, SPAN_RED("This bed is assigned to someone else. Sleep in an unassigned bed or your own."))
		return
	if (registered_bed_sleep)
		var/refusal = saved_bed_sleep_refusal()
		if (refusal)
			to_chat(src, SPAN_RED(refusal))
			log_game("Sleep refused for [key_name(src)] at [x],[y],[z]: [refusal]")
			return
	var/sleep_delay = 2 MINUTES
	var/sleep_delay_text = "two minutes"
	var/sleep_message = "Are you sure you want to sleep for a while? This takes two minutes. Your body stays here and can be harmed, but you get hungry much more slowly."
	if (registered_bed_sleep)
		// Admission above already requires an eligible stationary bed. Choose
		// the wait now; the existing live logout protection remains separate.
		var/protection_eligible = offline_sleep_protection_map_allowed() && offline_sleep_province_owned()
		if (!protection_eligible)
			sleep_delay = 10 SECONDS
			sleep_delay_text = "10 seconds"
		sleep_message = "Sleep here and assign this bed for saved-character returns? You can have only one bed, so any bed assigned to you before is released. This takes " + sleep_delay_text + ". Your body stays here. Only a completed world save preserves it on disk."
		if (protection_eligible)
			sleep_message += " Your body can be harmed while connected. If this location still qualifies when you log off after falling asleep, nobody can harm, rob or move you while you are protected."
		else
			sleep_message += " This location does not currently grant offline protection. Your body can still be harmed here after you log off."
	else if (offline_sleep_protection_map_allowed())
		sleep_message += " If you belong to a faction and this bed is in a province your faction holds, logging off once you are asleep keeps your body safe here: nobody can harm, rob or move it until you come back."
	if (WWinput(src, sleep_message, "Sleep", "Yes", list("Yes","No")) == "Yes")
		if (registered_bed_sleep)
			if (!sleeping_client || client != sleeping_client || sleeping_client.mob != src)
				return
			if (get_turf(src) != sleep_turf)
				to_chat(src, SPAN_NOTICE("You are no longer at the bed where you started. Use Sleep again."))
				return
		to_chat(src, SPAN_NOTICE("You will start sleeping in " + sleep_delay_text + "."))
		if (do_after(src, sleep_delay, src, FALSE, incapacitation_flags = (INCAPACITATION_DEFAULT & ~INCAPACITATION_DISABLED) | INCAPACITATION_DISABLED_NO_REST))
			if (!sleeping_client || client != sleeping_client || sleeping_client.mob != src)
				return
			if (sleeping)
				return
			else
				found = FALSE
				for (var/obj/structure/bed/B in get_turf(src))
					if (B)
						found = TRUE
				if (!found)
					to_chat(src, SPAN_RED("You need to be over a bed."))
					return
				else
					if (persistence_bed_return_enabled())
						if (saved_bed_taken_here())
							to_chat(src, SPAN_RED("This bed is assigned to someone else. Sleep in an unassigned bed or your own."))
							return
						var/previous_bed = saved_bed_assignment()
						if (!enter_saved_bed_sleep())
							var/refusal = saved_bed_sleep_refusal()
							if (!refusal)
								refusal = "You could not fall asleep here. Try Sleep again."
							to_chat(src, SPAN_WARNING(refusal))
							log_game("Sleep refused for [key_name(src)] at [x],[y],[z]: [refusal]")
						else
							if (previous_bed == "elsewhere")
								to_chat(src, SPAN_NOTICE("This is now your bed. Your previous bed is no longer assigned to you."))
							else if (!previous_bed)
								to_chat(src, SPAN_NOTICE("This is now your bed."))
							sleeping_client.open_character_sleep_picker()
						return
					if (!enter_bed_sleep())
						to_chat(src, SPAN_RED("You could not fall asleep. Wait for any world save or load to finish, then try again."))
					return
		else
			to_chat(src, SPAN_NOTICE("You stop trying to sleep"))

/mob/living/human/verb/mob_wakeup()
	set name = "Wake Up"
	set category = "IC"

	if (usr != src || !client || client.mob != src)
		return
	if (!sleeping && !inducedSSD)
		to_chat(src, SPAN_RED("You are already awake."))
		return
	if (!inducedSSD)
		to_chat(src, SPAN_RED("You aren't asleep that deeply, just wait."))
		return
	if (persistence_sleep_transfer_blocked())
		to_chat(src, SPAN_RED("Wait for the world save or load to finish before waking up."))
		return
	var/client/waking_client = client
	if (WWinput(src, "Are you sure you want to wake up? This will take 30 seconds.", "Wake Up", "Yes", list("Yes","No")) == "Yes")
		to_chat(src, "You will wake up in 30 seconds.")
		spawn(300)
			if (!src || !waking_client || client != waking_client || waking_client.mob != src || !inducedSSD)
				return
			if (persistence_sleep_transfer_blocked())
				to_chat(src, SPAN_WARNING("Wait for the world save or load to finish, then retry Wake Up."))
				return
			// A body left in the old sleep zone goes back to where it slept.
			if (is_protected_sleep_location(src))
				var/turf/return_turf = locate(lastx,lasty,lastz)
				if (isturf(loc) && persistence_character_turf_safe(return_turf, src) && release_protected_sleep_buckle())
					forceMove(return_turf)
				if (is_protected_sleep_location(src))
					to_chat(src, SPAN_WARNING("You wake up somewhere strange. Ask an administrator to move you back."))
			sleeping = 0
			inducedSSD = FALSE
			divine_rested()

// The end of Wake Up after its 30 seconds, for agent characters, which have no
// client to use the verb (agent_characters.dm "wake"). Mirrors mob_wakeup above.
/mob/living/human/proc/finish_wake_up()
	if (!inducedSSD || stat == DEAD)
		return FALSE
	if (persistence_sleep_transfer_blocked())
		to_chat(src, SPAN_WARNING("Wait for the world save or load to finish, then retry Wake Up."))
		return FALSE
	// A body left in the old sleep zone goes back to where it slept.
	if (is_protected_sleep_location(src))
		var/turf/return_turf = locate(lastx,lasty,lastz)
		if (isturf(loc) && persistence_character_turf_safe(return_turf, src) && release_protected_sleep_buckle())
			forceMove(return_turf)
		if (is_protected_sleep_location(src))
			to_chat(src, SPAN_WARNING("You wake up somewhere strange. Ask an administrator to move you back."))
	sleeping = 0
	inducedSSD = FALSE
	divine_rested()
	return TRUE

// The picker button is already explicit confirmation. Keep the regular
// wake delay and finish path; an obsolete window or timer cannot wake a body.
/mob/living/human/var/tmp/character_picker_waking = FALSE

/mob/living/human/proc/request_character_picker_wake(client/C)
	if(character_picker_waking || character_lobby_sleep_body(C) != src)
		return FALSE
	if(persistence_sleep_transfer_blocked() || map_storage.character_recovery_unready())
		to_chat(C, SPAN_WARNING("Wait for the world save or recovery to finish, then try again."))
		return FALSE
	character_picker_waking = TRUE
	to_chat(C, SPAN_NOTICE("You will wake up in 30 seconds."))
	addtimer(CALLBACK(src, PROC_REF(complete_character_picker_wake), C), 30 SECONDS)
	return TRUE

/mob/living/human/proc/complete_character_picker_wake(client/C)
	character_picker_waking = FALSE
	if(!C || character_lobby_sleep_body(C) != src || map_storage.character_recovery_unready())
		return
	finish_wake_up()

//to keep the character sleeping
// One refresh loop per body: a restored body restarts it on reconnect, and a
// second caller only tops up sleeping instead of starting another loop.
/mob/living/human/var/tmp/sleep_update_queued = FALSE

/mob/living/human/proc/sleep_update()
	if (!inducedSSD)
		return
	sleeping = 66
	if (sleep_update_queued)
		return
	sleep_update_queued = TRUE
	spawn(600) // 1 minute
		sleep_update_queued = FALSE
		sleep_update()

/mob/living/human/handle_mutations_and_radiation()
	get_rads_from_equipment()

	if (global_radiation > 125)
		var/area/A = get_area(src)
		var/multiplier = 0.7
		if (A.location == 1)
			if (global_radiation >= 300)
				switch(weather_at(src))
					if (WEATHER_NONE)
						multiplier = 1
					if (WEATHER_WET)
						multiplier = 1.5
					if (WEATHER_EXTREME)
						multiplier = 2
					if (WEATHER_SMOG)
						multiplier = 1
		if (z == multiz_top_z())
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
	// The client whose image list roofs_removed describes. Never saved.
	var/tmp/roofs_client

// Roof images live in the client's image list, which a reconnect or a world
// load starts empty. The flag alone would be restored from the save.
/mob/living/human/persistence_runtime_var(key)
	return key == "roofs_removed" || key == "roofs_client" || key == "character_picker_waking" || ..()

/mob/living/human/proc/process_turret_roofs()
	if (!client)
		return

	var/list/view_size = getviewsize(client.view)
	var/half_w = round(view_size[1] / 2)
	var/half_h = round(view_size[2] / 2)
	var/view_dist = max(half_w, half_h) + 5 // + reserve so that when moving the load is not visible [translated]

	var/view_x_offset = 0
	var/view_y_offset = 0

	if(client.pixel_x > 0)
		view_x_offset = half_w
	else if(client.pixel_x < 0)
		view_x_offset = -half_w

	if(client.pixel_y > 0)
		view_y_offset = half_h
	else if(client.pixel_y < 0)
		view_y_offset = -half_h

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

	var/list/view_size = getviewsize(client.view)
	var/half_w = round(view_size[1] / 2)
	var/half_h = round(view_size[2] / 2)
	var/view_dist = max(half_w, half_h) + 5 // + reserve so that when moving the load is not visible [translated]

	var/view_x_offset = 0
	var/view_y_offset = 0

	if(client.pixel_x > 0)
		view_x_offset = half_w
	else if(client.pixel_x < 0)
		view_x_offset = -half_w

	if(client.pixel_y > 0)
		view_y_offset = half_h
	else if(client.pixel_y < 0)
		view_y_offset = -half_h

	var/view_loc = locate(x + view_x_offset, y + view_y_offset, z)

	var/obj/structure/vehicleparts/frame/found = null

	for (var/image/tmpimg in client.images)
		var/image_icon = tmpimg.icon
		if (image_icon == 'icons/obj/vehicles/vehicleparts.dmi' || image_icon == 'icons/obj/vehicles/lightplane.dmi' || image_icon == 'icons/obj/vehicles/vehicles96x96.dmi' || image_icon == 'icons/obj/vehicles/vehicles128x128.dmi' || image_icon == 'icons/obj/vehicles/apcparts.dmi' || image_icon == 'icons/obj/vehicles/tankparts.dmi' || image_icon == 'icons/obj/vehicles/tankparts96x96.dmi' || image_icon == 'icons/obj/vehicles/apcparts96x96.dmi'  || image_icon == 'icons/obj/vehicles/tankparts96x96_damaged.dmi' || image_icon == 'icons/obj/vehicles/apcparts96x96_damaged.dmi')
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
	sync_static_roofs(client, client.images, A && A.location == AREA_INSIDE)

// viewer owns the images list. A new or reconnected client has no roof images
// yet, even when a world load restored roofs_removed from an older client.
/mob/living/human/proc/sync_static_roofs(viewer, list/images, inside)
	if (roofs_client != viewer)
		roofs_client = viewer
		roofs_removed = TRUE
	if (inside)
		if (!roofs_removed)
			images -= roofs_list
			roofs_removed = TRUE
	else if (roofs_removed)
		images |= roofs_list
		roofs_removed = FALSE

/mob/living/human
	var/drowning = FALSE
	var/water_overlay = FALSE
/mob/living/human/proc/handle_drowning()
	if (bends)
		bends_tick() // decompression sickness (scuba.dm)
	var/turf/T = get_turf(src)
	if (!T) return // nowhere to drown or redraw: a body between places (persistence_load_holds_life)
	// A flooded built deck is open sea, not a pressure hull. Crew carried
	// down with it can swim clear on their remaining breath, including after
	// loading a saved hull. Never refill an active breath budget here.
	var/on_sunken_deck = submerged_built_hull_deck(T)
	if (on_sunken_deck && stat != DEAD && !seabed_diving_rating() && sunken_hull_pressure_breath(T, TRUE))
		free_diving = FALSE
		drowning = FALSE
		water_overlay = FALSE
		if (plane == FLOOR_PLANE)
			plane = GAME_PLANE
		if (!on_fire)
			overlays_standing[25] = null
		swim_rest()
		life_water_refresh()
		return
	var/exposed_seabed = on_sunken_deck || (sea_layer_cell(T) && !T.iscovered())
	if (on_sunken_deck && !free_diving && !seabed_diving_rating() && stat != DEAD)
		free_diving = TRUE
		if (swim_breath < 0)
			swim_breath = max(1, round(swim_breath_max() / 2))
	// A sealed diver walks the seabed (seabed.dm) and breathes from the bottle.
	if (exposed_seabed && seabed_diving_rating())
		drowning = FALSE
		if (water_overlay)
			water_overlay = FALSE
			if (plane == FLOOR_PLANE)
				plane = GAME_PLANE
			if (!on_fire)
				overlays_standing[25] = null
		life_water_refresh()
		return
	// A free diver on the seabed, on a held breath (free_diving.dm).
	if (free_diving)
		if (exposed_seabed && !seabed_diving_rating())
			free_dive_tick(T)
			life_water_refresh()
			return
		free_diving = FALSE
	// A lifejacket or covered tile cannot provide air in a roof-high tunnel.
	if (flood_airless(T) && !seabed_diving_rating())
		drowning = TRUE
		water_overlay = TRUE
		if (!tunnel_hold_breath())
			to_chat(src, SPAN_DANGER("<font size='2'>You are drowning in the flooded tunnel!</font>"))
			adjustOxyLoss(10)
		life_water_refresh()
		return
	// Floating: a lifejacket, or a sealed diving suit with its weights dropped.
	if ((istype(wear_suit, /obj/item/clothing/suit/lifejacket) || seabed_diving_rating()) && istype(T, /turf/floor/beach/water/deep) && !T.iscovered())
		drowning = FALSE
		water_overlay = TRUE
		swim_rest()
		life_water_refresh()
		return
	if (!istype(T, /turf/floor/beach/water/deep) || T.iscovered())
		// River floodwater over land (flood_effects.dm): over the head, swim.
		var/flood_band = T.iscovered() ? FLOOD_BAND_NONE : flood_band_at(T)
		if (flood_band == FLOOD_BAND_DEEP && !istype(buckled, /obj/structure/vehicle/boat) && !istype(wear_suit, /obj/item/clothing/suit/lifejacket) && !seabed_diving_rating())
			if (swim_step(T))
				drowning = FALSE
				water_overlay = TRUE
				life_water_refresh()
				return
			drowning = TRUE
			// Spent: a held breath first (swimming.dm).
			if (swim_hold_breath())
				life_water_refresh()
				return
			to_chat(src, SPAN_WARNING("<font size='2'>You are drowning in the floodwater!</font>"))
			body_motion_struggle()
			life_water_refresh()
			adjustOxyLoss(10)
			return
		drowning = FALSE
		swim_rest()
		if ((is_open_water(T) && !T.iscovered()) || flood_band >= FLOOD_BAND_KNEE)
			water_overlay = TRUE
			life_water_refresh()
			return
		else
			if (istype(T, /turf/floor/sub_deck) && T:water_depth > 0)
				drowning = FALSE
				water_overlay = TRUE
				life_water_refresh()
				return
			water_overlay = FALSE
			if (plane == FLOOR_PLANE)
				plane = GAME_PLANE
			if (!on_fire)
				overlays_standing[25] = null
			life_water_refresh()
			return
	else
		var/turf/floor/beach/water/deep/D = T
		if (D.iscovered())
			drowning = FALSE
			water_overlay = FALSE
			swim_rest()
			life_water_refresh()
			return
		else if (buckled && istype(buckled, /obj/structure/vehicle/boat))
			drowning = FALSE
			water_overlay = FALSE
			swim_rest()
			life_water_refresh()
			return
		else
			for(var/obj/structure/vehicle/boat/BT in range(1,src))
				if(src in BT.ontop)
					drowning = FALSE
					water_overlay = FALSE
					swim_rest()
					life_water_refresh()
					return
			// Swimming (swimming.dm): afloat until the swimmer tires.
			if (swim_step(D))
				drowning = FALSE
				water_overlay = TRUE
				life_water_refresh()
				return
			drowning = TRUE
			if (swim_hold_breath())
				life_water_refresh()
				return
			to_chat(src, SPAN_WARNING("<font size='2'>You are drowning!</font>"))
			body_motion_struggle()
			life_water_refresh()
			adjustOxyLoss(10)
			return
