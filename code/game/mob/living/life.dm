/mob/living/var/next_weather_sound = -1
/mob/living/var/last_life_tick = 0
/mob/living/Life()

	..()

	last_life_tick = world.realtime

	if (!loc)
		return

	if (client)

		var/near_rainy_area = FALSE
		var/rdist = 100
		var/area/A = get_area(src)
		if (A && A.weather == WEATHER_WET && findtext(A.icon_state,"rain"))
			near_rainy_area = TRUE
			rdist = 0
		else
			for (var/turf/T in view(7, src))
				var/area/T_area = get_area(T)
				if (T_area.weather == WEATHER_WET && findtext(T_area.icon_state,"rain"))
					near_rainy_area = TRUE
					rdist = min(rdist, get_dist(src, T))

		if (world.time >= next_weather_sound && near_rainy_area)
			src << sound('sound/ambience/rain.ogg', channel = 778, volume = (100 - (rdist*2)))
			next_weather_sound = world.time + 1450 // the rain sound is 1510 deciseconds long, but even when this was set to 1500, there was delay between successive rain sounds - Kachnov
		else if (world.time < next_weather_sound && !near_rainy_area)
			src << sound(null, channel = 778)
			next_weather_sound = world.time

	if (transforming)
		return

	if (stat != DEAD)

		//Breathing, if applicable
		handle_breathing()

		//Mutations and radiation
		handle_mutations_and_radiation()

		//Chemicals in the body
		handle_chemicals_in_body()

		//Blood
		handle_blood()

		//Random events (vomiting etc)
		handle_random_events()

		//Cool colour filters
		update_client_colour()

		. = TRUE

		handle_environment()

	// put us out before we check fire stuff
	if (istype(loc, /turf/floor/beach/water))
		var/turf/floor/beach/water/W = loc
		W.Extinguish(src)

	//Check if we're on fire
	handle_fire()

	//stuff in the stomach
	handle_stomach()

	update_pulling()

	for (var/obj/item/weapon/grab/G in src)
		G.process()

	blinded = FALSE // Placing this here just show how out of place it is.
	// human/handle_regular_status_updates() needs a cleanup, as blindness should be handled in handle_disabilities()
	if (handle_regular_status_updates()) // Status & health update, are we dead or alive etc.
		handle_disabilities() // eye, ear, brain damages
		handle_status_effects() //all special effects, stunned, weakened, jitteryness, hallucination, sleeping, etc

	handle_actions()

	update_canmove()

	handle_regular_hud_updates()

/mob/living/proc/handle_breathing()
	return

/mob/living/proc/handle_mutations_and_radiation()
	return

/mob/living/proc/handle_chemicals_in_body()
	return

/mob/living/proc/handle_blood()
	return

/mob/living/proc/handle_random_events()
	return

/mob/living/proc/handle_environment()
	return

/mob/living/proc/handle_stomach()
	return

/mob/living/proc/update_pulling()
	if (pulling)
		if (incapacitated() || prone)
			stop_pulling()

//This updates the health and status of the mob (conscious, unconscious, dead)
/mob/living/proc/handle_regular_status_updates()
	updatehealth()
	if (stat != DEAD)
		if (paralysis)
			stat = UNCONSCIOUS
		else if (status_flags & FAKEDEATH)
			stat = UNCONSCIOUS
		else
			stat = CONSCIOUS
		return TRUE

//this updates all special effects: stunned, sleeping, weakened, druggy, stuttering, etc..
/mob/living/proc/handle_status_effects()
	if (paralysis)
		paralysis = max(paralysis-1,0)
	if (stunned)
		stunned = max(stunned-1,0)
		if (!stunned)
			update_icons()

	if (weakened)
		weakened = max(weakened-1,0)
		if (!weakened)
			update_icons()

/mob/living/proc/handle_disabilities()
	//Eyes
	if ((sdisabilities & BLIND) || stat || find_trait("Blind"))	//blindness from disability or unconsciousness doesn't get better on its own
		eye_blind = max(eye_blind, TRUE)
	else if (eye_blind)			//blindness, heals slowly over time
		eye_blind = max(eye_blind-1,0)
	else if (eye_blurry)			//blurry eyes heal slowly
		eye_blurry = max(eye_blurry-1, FALSE)

	//Ears
	if ((sdisabilities & DEAF) || find_trait("Deaf"))		//disabled-deaf, doesn't get better on its own
		setEarDamage(-1, max(ear_deaf, TRUE))
	else
		// deafness heals slowly over time, unless ear_damage is over 100
		if (ear_damage < 100)
			adjustEarDamage(-0.05,-1)

//this handles hud updates. Calls update_vision() and handle_hud_icons()
/mob/living/proc/handle_regular_hud_updates()
	if (!client)	return FALSE

	handle_hud_icons()
	handle_vision()

	return TRUE

/mob/living/proc/handle_vision()
//	client.screen.Remove(global_hud.blurry, global_hud.druggy, global_hud.vimpaired, global_hud.darkMask, global_hud.nvg, global_hud.thermal, global_hud.meson, global_hud.science)
	update_sight()

	if (stat == DEAD)
		return

	if (using_object)
		var/viewflags = using_object.check_eye(src)
		if (viewflags < 0)
			reset_view(null, FALSE)
		else if (viewflags)
			sight |= viewflags
/*	else if (eyeobj)
		if (eyeobj.owner != src)
			reset_view(null)*/
	else if (!client.adminobs)
		reset_view(null)
	if (sdisabilities & NEARSIGHTED)
		client.screen += global_hud.vimpaired

/mob/living/proc/update_sight()
	if (stat == DEAD/* || eyeobj*/)
		update_dead_sight()
	else
		sight &= ~(SEE_TURFS|SEE_MOBS|SEE_OBJS)
		see_in_dark = initial(see_in_dark)
		see_invisible = initial(see_invisible)

/mob/living/proc/update_dead_sight()
	sight |= SEE_TURFS
	sight |= SEE_MOBS
	sight |= SEE_OBJS
	see_in_dark = 8
	see_invisible = SEE_INVISIBLE_LEVEL_TWO

/mob/living/proc/handle_hud_icons()
	handle_hud_icons_health()

/mob/living/proc/handle_hud_icons_health()
	return