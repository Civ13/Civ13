// Areas.dm

/*

### This file contains a list of all the areas in the map. Format is as follows:

/area/CATEGORY/OR/DESCRIPTOR/NAME 	(you can make as many subdivisions as you want)
	name = "NICE NAME" 				(not required but makes things really nice)
	icon = "ICON FILENAME" 			(defaults to areas.dmi)
	icon_state = "NAME OF ICON" 	(defaults to "unknown" (blank))

*/

#define AREA_INSIDE 0
#define AREA_OUTSIDE 1

/area
	var/fire = null
	level = null
	name = "Unknown"
	icon = 'icons/turf/areas.dmi'
	icon_state = "unknown"
	layer = 10
	mouse_opacity = FALSE
	plane = LIGHTING_PLANE

	var/debug = FALSE

	var/has_gravity = TRUE
//	var/obj/machinery/power/apc/apc = null
	var/no_air = null
	var/list/ambience = list()
	var/list/forced_ambience = list()
	var/turf/base_turf //The base turf type of the area, which can be used to override the z-level's base turf
	var/sound_env = FOREST

	var/location = AREA_OUTSIDE

	var/weather = WEATHER_NONE
	var/weather_intensity = 1.0

	var/is_void_area = FALSE

	var/capturable = TRUE

	var/parent_area_type = null
	var/area/parent_area = null

	var/climate = "temperate" //temperate, desert, jungle, tundra

// ===
/area
	var/global/global_uid = FALSE
	var/uid
	var/artillery_integrity = 100

/area/New()
	icon = 'icons/effects/weather.dmi'
	icon_state = ""
	layer = 10
	uid = ++global_uid

	..()

	spawn (100)
		if (parent_area_type)
			parent_area = locate(parent_area_type)

	area_list |= src

/area/proc/get_contents()
	return contents

/area/proc/get_turfs()
	. = get_contents():Copy()
	. -= typesof(/obj)
	. -= typesof(/mob)
	return .

/area/proc/get_mobs()
	. = get_contents():Copy()
	. -= typesof(/turf)
	. -= typesof(/obj)
	return .

/area/proc/get_objs()
	. = get_contents():Copy()
	. -= typesof(/turf)
	. -= typesof(/mob)
	return .

/area/Entered(A)
	if (!istype(A,/mob/living))	return

	var/mob/living/L = A
	if (!L.ckey)	return

	if (!L.lastarea)
		L.lastarea = get_area(L.loc)

	var/area/newarea = get_area(L.loc)
	var/area/oldarea = L.lastarea
	if ((oldarea.has_gravity == FALSE) && (newarea.has_gravity == TRUE) && (L.m_intent == "run")) // Being ready when you change areas gives you a chance to avoid falling all together.
		thunk(L)
		L.update_floating( L.Check_Dense_Object() )
	if ((oldarea.has_gravity == TRUE) && (newarea.has_gravity == FALSE))
		L.update_floating( L.Check_Dense_Object() )
	if ((oldarea.no_air == FALSE) && (newarea.no_air == TRUE))
		no_air(L)
	var/override_ambience = FALSE

	for (var/typecheck in list(/area/caribbean/british, /area/caribbean/pirates, /area/caribbean/no_mans_land, /area/caribbean/forest, /area/caribbean/void))
		if (istype(oldarea, typecheck))
			if (!istype(newarea, typecheck))
				override_ambience = TRUE

	if (oldarea.is_void_area != newarea.is_void_area)
		override_ambience = TRUE

	if (oldarea.location != newarea.location)
		override_ambience = TRUE

	L.lastarea = newarea
	play_ambience(L, override_ambience)

/area/proc/play_ambience(var/mob/living/L, var/override = FALSE)

	// Ambience goes down here -- make sure to list each area seperately for ease of adding things in later, thanks! Note: areas adjacent to each other should have the same sounds to prevent cutoff when possible.- LastyScratch
//	if (!(L && L.is_preference_enabled(/datum/client_preference/play_ambiance)))	return
	if (!L || !istype(L) || !L.loc)
		return

	var/client/CL = L.client

	if (!CL)
		return

	var/lastsound = CL.ambience_playing
	var/sound = (map && map.ambience.len) ? pick(map.ambience) : null
	var/override_volume = 0

	if (sound && (!CL.ambience_playing || override || sound != lastsound))
		CL.ambience_playing = sound

		var/ideal_x = round(world.maxx/2)
		var/ideal_y = round(world.maxy/2)
		var/area/L_area = get_area(L)

		// war volume will vary from 2% to 22%, depending on where you are (on a 150x150 map)
		// the max() check makes this code forestmap compatible too
		var/warvolume = 21

		warvolume -= ceil(abs(L.x - ideal_x)/15)
		warvolume -= ceil(abs(L.y - ideal_y)/15)

		if (L_area)
			if (L_area.location == AREA_INSIDE)
				warvolume -= 4
			if (L_area.is_void_area)
				warvolume -= 5

		warvolume = max(warvolume, 2)

		L << sound(null, channel = SOUND_CHANNEL_AMBIENCE)
		var/sound/S = sound(sound, repeat = TRUE, wait = FALSE, volume = override_volume ? override_volume : warvolume, channel = SOUND_CHANNEL_AMBIENCE)
		S.environment = 22
		L << S

/proc/stop_ambience(var/mob_or_client)
	var/client/C = isclient(mob_or_client) ? mob_or_client : mob_or_client:client
	if (C)
		C.ambience_playing = null
	mob_or_client << sound(null, channel = SOUND_CHANNEL_AMBIENCE)

/area/proc/gravitychange(var/gravitystate = FALSE, var/area/A)
	A.has_gravity = gravitystate

	for (var/mob/M in A)
		if (has_gravity)
			thunk(M)
		M.update_floating( M.Check_Dense_Object() )

/area/proc/thunk(mob)
	if (istype(mob,/mob/living/human/))
		var/mob/living/human/H = mob
		if (istype(H.shoes, /obj/item/clothing/shoes/magboots) && (H.shoes.item_flags & NOSLIP))
			return

		if (H.m_intent == "run")
			H.AdjustStunned(2)
			H.AdjustWeakened(2)
		else
			H.AdjustStunned(1)
			H.AdjustWeakened(1)
		mob << "<span class='notice'>The sudden appearance of gravity makes you fall to the floor!</span>"

/area/proc/has_gravity()
	return has_gravity

/area/proc/no_air(mob)
	if (istype(mob,/mob/living/human/))
		var/mob/living/human/H = mob

		if (istype(H.shoes, /obj/item/clothing/head/astronaut) && istype(H.shoes, /obj/item/clothing/suit/astronaut))
			return
		else
			H.AdjustStunned(10)
			H.AdjustWeakened(10)
			H.burn_skin(25)
			H.adjustFireLoss(25)
			H.drop_item()
			H.adjustOxyLoss(80)
			H.adjustBodyTemp(-100)
			H.emote("gasp")
			H.emote("cry")
			H.emote("choke")
			mob << "<span class='notice'>You gasp and shudder as the void boils you alive!!</span>"
			spawn(100)
				H.burn_skin(25)
				H.adjustFireLoss(30)
				H.emote("gasp")
				H.emote("choke")
				H.adjustBodyTemp(-200)
				mob << "<span class='notice'>You gasp and shudder as the void boils you alive!!</span>"
				spawn(100)
					H.burn_skin(25)
					H.adjustFireLoss(20)
					H.emote("gasp")
					H.emote("choke")
					mob << "<span class='notice'>You gasp and shudder as the void boils you alive!!</span>"

/area/proc/arty_act(loss)
	if (prob(25))
		artillery_integrity -= loss * 1.33
	else if (prob(50))
		artillery_integrity -= loss
	else
		artillery_integrity -= loss * 0.75
	if (artillery_integrity > 0)
		return FALSE
	return TRUE

/proc/has_gravity(atom/AT, turf/T)
	return TRUE

// Changes the area of T to A. Do not do this manually.
// Area is expected to be a non-null instance.
/proc/ChangeArea(var/turf/T, var/area/A)
	if(!istype(A))
		CRASH("Area change attempt failed: invalid area supplied.")
	var/area/old_area = get_area(T)
	if(old_area == A)
		return
	A.contents.Add(T)
	if(old_area)
		old_area.Exited(T, A)
		for(var/atom/movable/AM in T)
			old_area.Exited(AM, A)  // Note: this _will_ raise exited events.
	A.Entered(T, old_area)
	for(var/atom/movable/AM in T)
		A.Entered(AM, old_area) // Note: this will _not_ raise moved or entered events. If you change this, you must also change everything which uses them.
