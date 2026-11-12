/mob/living/var/last_life_tick = 0
/mob/living/var/next_weather_scan = 0
/mob/living/var/cached_near_rainy_area = FALSE
/mob/living/var/cached_rain_dist = 100
// A player's or agent's character is held in time while its level is saved, as its input is
// (restart_transaction.dm): Life() does not run, so hunger, thirst, the bladder and bowels,
// breathing, bleeding, sickness and healing all wait until the level's capture finishes.
/proc/persistence_life_frozen(mob/living/M)
	if (!persistence_frozen_levels.len || !M || (!M.ckey && !agent_characters[M]))
		return FALSE
	var/turf/T = get_turf(M)
	return (T && persistence_frozen_levels["[T.z]"]) ? TRUE : FALSE

/mob/living/Life()

	..()

	last_life_tick = world.realtime

	if (!loc)
		return

	if (client)

		var/near_rainy_area = FALSE
		var/rdist = 100
		// rain only falls under a weather system or pinned zone weather,
		// so we can skip all of this the rest of the time
		if (weather_anywhere())
			if (weather_at(src) == WEATHER_WET && findtext(weather_look_at(src),"rain"))
				near_rainy_area = TRUE
				rdist = 0
			else if (world.time >= next_weather_scan)
				// the view(7) scan covers ~200 turfs; doing it every Life tick for
				// every player is too expensive, so rescan at most every 5 seconds
				next_weather_scan = world.time + 50
				cached_near_rainy_area = FALSE
				cached_rain_dist = 100
				for (var/turf/T in view(7, src))
					if (weather_at(T) == WEATHER_WET && findtext(weather_look_at(T),"rain"))
						cached_near_rainy_area = TRUE
						cached_rain_dist = min(cached_rain_dist, get_dist(src, T))
				near_rainy_area = cached_near_rainy_area
				rdist = cached_rain_dist
			else
				near_rainy_area = cached_near_rainy_area
				rdist = cached_rain_dist

		update_rain_sound(near_rainy_area ? (100 - (rdist*2)) : 0)

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
		if (!W.iscovered())
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
			set_stat(CONSCIOUS)
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
	update_lighting_plane()

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
// Rain loops on the client (repeat = TRUE), so it keeps playing through a
// server stall instead of stopping when a server-timed replay is missed.
// The server only starts it, changes its volume and stops it.
/mob/living/proc/update_rain_sound(volume)
	var/client/C = client
	if (!C)
		return
	volume = clamp(round(volume), 0, 100)
	if (volume == C.rain_sound_volume)
		return
	if (!volume)
		stop_rain_sound(C)
		return
	var/sound/S = sound('sound/ambience/rain.ogg', repeat = TRUE, wait = FALSE, volume = volume, channel = SOUND_CHANNEL_RAIN)
	if (C.rain_sound_volume)
		S.status = SOUND_UPDATE
	C.rain_sound_volume = volume
	C << S

/proc/stop_rain_sound(var/mob_or_client)
	var/client/C = isclient(mob_or_client) ? mob_or_client : mob_or_client:client
	if (C)
		C.rain_sound_volume = 0
	mob_or_client << sound(null, channel = SOUND_CHANNEL_RAIN)
