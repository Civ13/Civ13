/*
This is an attempt to make some easily reusable "particle" type effect, to stop the code
constantly having to be rewritten. An item like the jetpack that uses the ion_trail_follow system, just has one
defined, then set up when it is created with New(). Then this same system can just be reused each time
it needs to create more trails.A beaker could have a steam_trail_follow system set up, then the steam
would spawn and follow the beaker, even if it is carried or thrown.
*/


/obj/effect/effect
	name = "effect"
	icon = 'icons/effects/effects.dmi'
	mouse_opacity = FALSE
	pass_flags = PASSTABLE | PASSGRILLE

/obj/effect/Destroy()
	if (reagents)
		reagents.delete()
	return ..()

/datum/effect/effect/system
	var/number = 3
	var/cardinals = FALSE
	var/turf/location
	var/atom/holder
	var/setup = FALSE

	proc/set_up(n = 3, c = FALSE, turf/loc)
		if (n > 10)
			n = 10
		number = n
		cardinals = c
		location = loc
		setup = TRUE

	proc/attach(atom/atom)
		holder = atom

	proc/start()


/////////////////////////////////////////////
// GENERIC STEAM SPREAD SYSTEM

// Usage: set_up(number of bits of steam, use North/South/East/West only, spawn location)
// The attach(atom/atom) proc is optional, and can be called to attach the effect
// to something, like a smoking beaker, so then you can just call start() and the steam
// will always spawn at the items location, even if it's moved.

/* Example:
var/datum/effect/system/steam_spread/steam = new /datum/effect/system/steam_spread() -- creates new system
steam.set_up(5, FALSE, mob.loc) -- sets up variables
OPTIONAL: steam.attach(mob)
steam.start() -- spawns the effect
*/
/////////////////////////////////////////////
/obj/effect/effect/steam
	name = "steam"
	icon = 'icons/effects/effects.dmi'
	icon_state = "extinguish"
	density = FALSE

/datum/effect/effect/system/steam_spread

	set_up(n = 3, c = FALSE, turf/loc)
		if (n > 10)
			n = 10
		number = n
		cardinals = c
		location = loc

	start()
		var/i = FALSE
		for (i=0, i<number, i++)
			spawn(0)
				if (holder)
					location = get_turf(holder)
				var/obj/effect/effect/steam/steam = PoolOrNew(/obj/effect/effect/steam, location)
				var/direction
				if (cardinals)
					direction = pick(cardinal)
				else
					direction = pick(alldirs)
				for (i=0, i<pick(1,2,3), i++)
					sleep(5)
					step(steam,direction)
				spawn(20)
					qdel(steam)

/////////////////////////////////////////////
//SPARK SYSTEM (like steam system)
// The attach(atom/atom) proc is optional, and can be called to attach the effect
// to something, like the RCD, so then you can just call start() and the sparks
// will always spawn at the items location.
/////////////////////////////////////////////

/obj/effect/sparks
	name = "sparks"
	icon_state = "sparks"
	var/amount = 6.0
	anchored = 1.0
	mouse_opacity = FALSE

/obj/effect/sparks/New()
	..()
	playsound(loc, "sparks", 100, TRUE)

/obj/effect/sparks/initialize()
	..()
	schedule_task_in(10 SECONDS, /proc/qdel, list(src))

/obj/effect/sparks/Destroy()
	return ..()

/obj/effect/sparks/Move()
	..()
/datum/effect/effect/system/spark_spread
	var/total_sparks = FALSE // To stop it being spammed and lagging!

	set_up(n = 3, c = FALSE, loca)
		if (n > 10)
			n = 10
		number = n
		cardinals = c
		if (istype(loca, /turf/))
			location = loca
		else
			location = get_turf(loca)

	start()
		var/i = FALSE
		for (i=0, i<number, i++)
			if (total_sparks > 20)
				return
			spawn(0)
				if (holder)
					location = get_turf(holder)
				var/obj/effect/sparks/sparks = PoolOrNew(/obj/effect/sparks, location)
				total_sparks++
				var/direction
				if (cardinals)
					direction = pick(cardinal)
				else
					direction = pick(alldirs)
				for (i=0, i<pick(1,2,3), i++)
					sleep(5)
					step(sparks,direction)
				spawn(20)
					if (sparks)
						qdel(sparks)
					total_sparks--



/////////////////////////////////////////////
//// SMOKE SYSTEMS
// direct can be optinally added when set_up, to make the smoke always travel in one direction
// in case you wanted a vent to always smoke north for example
/////////////////////////////////////////////


/obj/effect/effect/smoke
	name = "smoke"
	icon_state = "smoke"
	opacity = TRUE
	anchored = 0.0
	mouse_opacity = FALSE
	var/amount = 6.0
	var/time_to_live = 100

	//Remove this bit to use the old smoke
	icon = 'icons/effects/96x96.dmi'
	pixel_x = -32
	pixel_y = -32

	layer = 6

/obj/effect/effect/smoke/New()
	..()
	processes.callproc.queue(src, /datum/proc/qdeleted, null, time_to_live)

/obj/effect/effect/smoke/Crossed(mob/living/human/M as mob )
	..()
	if (istype(M))
		affect(M)

/obj/effect/effect/smoke/proc/affect(var/mob/living/human/M)
	if (istype(M))
		return FALSE
	return TRUE

/obj/effect/effect/smoke/fast
	time_to_live = 30

/obj/effect/effect/smoke/small

	icon = 'icons/effects/effects.dmi'
	pixel_x = 0
	pixel_y = 0
/obj/effect/effect/smoke/small/fast
	time_to_live = 30

/obj/effect/effect/smoke/purple
	color = "#800080"
	time_to_live = 600
/obj/effect/effect/smoke/red
	color = "#a83232"
	time_to_live = 600
/obj/effect/effect/smoke/green
	color = "#366b36"
	time_to_live = 600
/obj/effect/effect/smoke/yellow
	color = "#ffff00"
	time_to_live = 600
/obj/effect/effect/smoke/orange
	color = "#c47f18"
	time_to_live = 600
/obj/effect/effect/smoke/blue
	color = "#3a5087"
	time_to_live = 600

/////////////////////////////////////////////
// Illumination
/////////////////////////////////////////////

/obj/effect/effect/smoke/illumination
	name = "illumination"
	opacity = FALSE
	icon = 'icons/effects/effects.dmi'
	icon_state = "sparks"

/obj/effect/effect/smoke/illumination/New(var/newloc, var/brightness=15, var/lifetime=10)
	time_to_live=lifetime
	..()
	set_light(brightness)

/////////////////////////////////////////////
// Bad smoke
/////////////////////////////////////////////

/obj/effect/effect/smoke/bad
	time_to_live = 200

/obj/effect/effect/smoke/bad/New(_loc, move = FALSE)
	..(_loc)
	if (move)
		for (var/v in 1 to time_to_live/10)
			spawn (v * 5)
				step_rand(src)
	processes.callproc.queue(src, /datum/proc/qdeleted, null, time_to_live)

/obj/effect/effect/smoke/bad/Move()
	..()
	for (var/mob/living/human/M in get_turf(src))
		affect(M)

/obj/effect/effect/smoke/bad/affect(var/mob/living/human/M)
	if (!..())
		return FALSE
	M.drop_item()
	M.adjustOxyLoss(1)
	if (M.coughedtime != TRUE)
		M.coughedtime = TRUE
		M.emote("cough")
		spawn ( 20 )
			M.coughedtime = FALSE

/obj/effect/effect/smoke/bad/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)
	if (air_group || (height==0)) return TRUE
/*	if (istype(mover, /obj/item/projectile/beam))
		var/obj/item/projectile/beam/B = mover
		B.damage = (B.damage/2)*/
	return TRUE
/////////////////////////////////////////////
// Sleep smoke
/////////////////////////////////////////////

/obj/effect/effect/smoke/sleepy

/obj/effect/effect/smoke/sleepy/Move()
	..()
	for (var/mob/living/human/M in get_turf(src))
		affect(M)

/obj/effect/effect/smoke/sleepy/affect(mob/living/human/M as mob )
	if (!..())
		return FALSE

	M.drop_item()
	M:sleeping += 1
	if (M.coughedtime != TRUE)
		M.coughedtime = TRUE
		M.emote("cough")
		spawn ( 20 )
			M.coughedtime = FALSE
/////////////////////////////////////////////
// Mustard Gas
/////////////////////////////////////////////


/obj/effect/effect/smoke/mustard
	name = "mustard gas"
	icon_state = "mustard"

/obj/effect/effect/smoke/mustard/Move()
	..()
	for (var/mob/living/human/R in get_turf(src))
		affect(R)

/obj/effect/effect/smoke/mustard/affect(var/mob/living/human/R)
	if (!..())
		return FALSE
	if (R.wear_suit != null)
		return FALSE

	R.burn_skin(0.75)
	if (R.coughedtime != TRUE)
		R.coughedtime = TRUE
		R.emote("gasp")
		spawn (20)
			R.coughedtime = FALSE
	R.updatehealth()
	return

/////////////////////////////////////////////
// Smoke spread
/////////////////////////////////////////////

/datum/effect/effect/system/smoke_spread
	var/total_smoke = FALSE // To stop it being spammed and lagging!
	var/direction
	var/smoke_type = /obj/effect/effect/smoke

/datum/effect/effect/system/smoke_spread/set_up(n = 5, c = FALSE, loca, direct)
	if (n > 10)
		n = 10
	number = n
	cardinals = c
	if (istype(loca, /turf/))
		location = loca
	else
		location = get_turf(loca)
	if (direct)
		direction = direct

/datum/effect/effect/system/smoke_spread/start()
	var/i = FALSE
	for (i=0, i<number, i++)
		if (total_smoke > 20)
			return
		spawn(0)
			if (holder)
				location = get_turf(holder)
			var/obj/effect/effect/smoke/smoke = PoolOrNew(smoke_type, location)
			total_smoke++
			var/src_direction = direction
			if (!src_direction)
				if (cardinals)
					src_direction = pick(cardinal)
				else
					src_direction = pick(alldirs)
			for (i=0, i<pick(0,1,1,1,2,2,2,3), i++)
				sleep(10)
				step(smoke,src_direction)
			spawn(smoke.time_to_live*0.75+rand(10,30))
				if (smoke) qdel(smoke)
				total_smoke--


/datum/effect/effect/system/smoke_spread/bad
	smoke_type = /obj/effect/effect/smoke/bad

/datum/effect/effect/system/smoke_spread/bad/chem/payload/chlorine_gas
	smoke_type = /obj/effect/effect/smoke/chem/payload/chlorine_gas

/datum/effect/effect/system/smoke_spread/bad/chem/payload/mustard_gas
	smoke_type = /obj/effect/effect/smoke/chem/payload/mustard_gas

/datum/effect/effect/system/smoke_spread/bad/chem/payload/phosgene
	smoke_type = /obj/effect/effect/smoke/chem/payload/phosgene

/datum/effect/effect/system/smoke_spread/bad/chem/payload/white_phosphorus_gas
	smoke_type = /obj/effect/effect/smoke/chem/payload/white_phosphorus_gas

/datum/effect/effect/system/smoke_spread/bad/chem/payload/xylyl_bromide
	smoke_type = /obj/effect/effect/smoke/chem/payload/xylyl_bromide

/datum/effect/effect/system/smoke_spread/bad/chem/payload/csgas
	smoke_type = /obj/effect/effect/smoke/chem/payload/csgas

/datum/effect/effect/system/smoke_spread/bad/chem/payload/zyklon_b
	smoke_type = /obj/effect/effect/smoke/chem/payload/zyklon_b

/datum/effect/effect/system/smoke_spread/sleepy
	smoke_type = /obj/effect/effect/smoke/sleepy

/datum/effect/effect/system/smoke_spread/mustard
	smoke_type = /obj/effect/effect/smoke/mustard

/datum/effect/effect/system/smoke_spread/purple
	smoke_type = /obj/effect/effect/smoke/purple

/datum/effect/effect/system/smoke_spread/green
	smoke_type = /obj/effect/effect/smoke/green

/datum/effect/effect/system/smoke_spread/blue
	smoke_type = /obj/effect/effect/smoke/blue

/datum/effect/effect/system/smoke_spread/red
	smoke_type = /obj/effect/effect/smoke/red

/datum/effect/effect/system/smoke_spread/yellow
	smoke_type = /obj/effect/effect/smoke/yellow

/datum/effect/effect/system/smoke_spread/orange
	smoke_type = /obj/effect/effect/smoke/orange

/////////////////////////////////////////////
//////// Attach a steam trail to an object (eg. a reacting beaker) that will follow it
// even if it's carried of thrown.
/////////////////////////////////////////////

/datum/effect/effect/system/steam_trail_follow
	var/turf/oldposition
	var/processing = TRUE
	var/on = TRUE

	set_up(atom/atom)
		attach(atom)
		oldposition = get_turf(atom)

	start()
		if (!on)
			on = TRUE
			processing = TRUE
		if (processing)
			processing = FALSE
			spawn(0)
				if (number < 3)
					var/obj/effect/effect/steam/I = PoolOrNew(/obj/effect/effect/steam, oldposition)
					number++
					oldposition = get_turf(holder)
					I.set_dir(holder.dir)
					spawn(10)
						qdel(I)
						number--
					spawn(2)
						if (on)
							processing = TRUE
							start()
				else
					spawn(2)
						if (on)
							processing = TRUE
							start()

	proc/stop()
		processing = FALSE
		on = FALSE

/datum/effect/effect/system/reagents_explosion
	var/amount 						// TNT equivalent
	var/flashing = FALSE			// does explosion creates flash effect?
	var/flashing_factor = FALSE		// factor of how powerful the flash effect relatively to the explosion

	set_up (amt, loc, flash = FALSE, flash_fact = FALSE)
		amount = amt
		if (istype(loc, /turf/))
			location = loc
		else
			location = get_turf(loc)

		flashing = flash
		flashing_factor = flash_fact

		return

	start()
		if (amount <= 2)
			var/datum/effect/effect/system/spark_spread/s = PoolOrNew(/datum/effect/effect/system/spark_spread)
			s.set_up(2, TRUE, location)
			s.start()

			for (var/mob/M in viewers(5, location))
				M << "<span class='warning'>The solution violently explodes.</span>"
			for (var/mob/M in viewers(1, location))
				if (prob (50 * amount))
					M << "<span class='warning'>The explosion knocks you down.</span>"
					M.Weaken(rand(1,5))
			return
		else
			var/devst = -1
			var/heavy = -1
			var/light = -1
			var/flash = -1

			// Clamp all values to fractions of max_explosion_range, following the same pattern as for tank transfer bombs
			if (round(amount/12) > 0)
				devst = devst + amount/12

			if (round(amount/6) > 0)
				heavy = heavy + amount/6

			if (round(amount/3) > 0)
				light = light + amount/3

			if (flashing && flashing_factor)
				flash = (amount/4) * flashing_factor

			for (var/mob/M in viewers(8, location))
				M << "<span class='warning'>The solution violently explodes.</span>"

			explosion(
				location,
				round(min(devst, BOMBCAP_DVSTN_RADIUS)),
				round(min(heavy, BOMBCAP_HEAVY_RADIUS)),
				round(min(light, BOMBCAP_LIGHT_RADIUS)),
				round(min(flash, BOMBCAP_FLASH_RADIUS))
				)

/obj/effect/helicopter_flyby
	name = "helicopter flyby"
	icon_state = ""
	mouse_opacity = FALSE

/obj/effect/helicopter_flyby/uh1/New()
	..()
	spawn(10)
		playsound(get_turf(src), 'sound/effects/aircraft/uh1.ogg', 100, TRUE, extrarange = 100)
		world << "The sound of a helicopter rotor can be heard from the sky. Sounds like a UH-1."
/obj/effect/helicopter_flyby/uh60/New()
	..()
	spawn(10)
		playsound(get_turf(src), 'sound/effects/aircraft/uh60.ogg', 100, TRUE, extrarange = 100)
		world << "The sound of a helicopter rotor can be heard from the sky. Sounds like a UH-60 Black Hawk."
/obj/effect/helicopter_flyby/ch47/New()
	..()
	spawn(10)
		playsound(get_turf(src), 'sound/effects/aircraft/ch47.ogg', 100, TRUE, extrarange = 100)
		world << "The sound of a helicopter rotor can be heard from the sky. Sounds like a Boeing CH-47 Chinook."
/obj/effect/helicopter_flyby/mi8/New()
	..()
	spawn(10)
		playsound(get_turf(src), 'sound/effects/aircraft/mi8.ogg', 100, TRUE, extrarange = 100)
		world << "The sound of a helicopter rotor can be heard from the sky. Sounds like a Mi-8."
/obj/effect/helicopter_flyby/mi24/New()
	..()
	spawn(10)
		playsound(get_turf(src), 'sound/effects/aircraft/mi24.ogg', 100, TRUE, extrarange = 100)
		world << "The sound of a helicopter rotor can be heard from the sky. Sounds like a Mi-24 Hind."


/obj/effect/plane_flyby
	name = "jet flyby"
	icon_state = ""
	mouse_opacity = FALSE

// Modern
/obj/effect/plane_flyby/f16/New()
	..()
	spawn(10)
		var/sound/uploaded_sound = sound('sound/effects/aircraft/f16_center.ogg', repeat = FALSE, wait = TRUE, channel = 777)
		uploaded_sound.priority = 250
		for (var/mob/M in player_list)
			if (!new_player_mob_list.Find(M))
				M << SPAN_NOTICE("<font size=3>The air vibrates as a F-16 Fighting Falcon flies overhead.</font>")
				M.client << uploaded_sound

/obj/effect/plane_flyby/f16_no_message/New()
	..()
	spawn(10)
		var/sound/uploaded_sound = sound('sound/effects/aircraft/f16_center.ogg', repeat = FALSE, wait = TRUE, channel = 777)
		uploaded_sound.priority = 250
		for (var/mob/M in player_list)
			if (!new_player_mob_list.Find(M))
				M.client << uploaded_sound

/obj/effect/plane_flyby/su25/New()
	..()
	spawn(10)
		var/sound/uploaded_sound = sound('sound/effects/aircraft/su25_center.ogg', repeat = FALSE, wait = TRUE, channel = 777)
		uploaded_sound.priority = 250
		for (var/mob/M in player_list)
			if (!new_player_mob_list.Find(M))
				M << SPAN_NOTICE("<font size=3>The air vibrates as a Su-25 Rook flies overhead.</font>")
				M.client << uploaded_sound

/obj/effect/plane_flyby/su25_no_message/New()
	..()
	spawn(10)
		var/sound/uploaded_sound = sound('sound/effects/aircraft/su25_center.ogg', repeat = FALSE, wait = TRUE, channel = 777)
		uploaded_sound.priority = 250
		for (var/mob/M in player_list)
			if (!new_player_mob_list.Find(M))
				M.client << uploaded_sound

// WW2
/obj/effect/plane_flyby/bf109/New()
	..()
	spawn(10)
		var/sound/uploaded_sound = sound('sound/effects/aircraft/bf109.ogg', repeat = FALSE, wait = TRUE, channel = 777)
		uploaded_sound.priority = 250
		for (var/mob/M in player_list)
			if (!new_player_mob_list.Find(M))
				M << SPAN_NOTICE("<font size=3>The air vibrates as a Bf-109 flies overhead.</font>")
				M.client << uploaded_sound

/obj/effect/plane_flyby/ju87/New()
	..()
	spawn(10)
		var/sound/uploaded_sound = sound('sound/effects/aircraft/ju87.ogg', repeat = FALSE, wait = TRUE, channel = 777)
		uploaded_sound.priority = 250
		for (var/mob/M in player_list)
			if (!new_player_mob_list.Find(M))
				M << SPAN_NOTICE("<font size=3>The air vibrates as a Junkers Ju 87 'Stuka' flies overhead.</font>")
				M.client << uploaded_sound

/obj/effect/plane_flyby/p47/New()
	..()
	spawn(10)
		var/sound/uploaded_sound = sound('sound/effects/aircraft/p47.ogg', repeat = FALSE, wait = TRUE, channel = 777)
		uploaded_sound.priority = 250
		for (var/mob/M in player_list)
			if (!new_player_mob_list.Find(M))
				M << SPAN_NOTICE("<font size=3>The air vibrates as a P-47 'Thunderbolt' flies overhead.</font>")
				M.client << uploaded_sound

/obj/effect/plane_flyby/p47_no_message/New()
	..()
	spawn(10)
		var/sound/uploaded_sound = sound('sound/effects/aircraft/p47.ogg', repeat = FALSE, wait = TRUE, channel = 777)
		uploaded_sound.priority = 250
		for (var/mob/M in player_list)
			if (!new_player_mob_list.Find(M))
				M.client << uploaded_sound

/obj/effect/flare
	name = "flare"
	icon_state = ""
	mouse_opacity = FALSE
	var/flare_range = 8

/obj/effect/flare/red/New()
	..()
	set_light(flare_range, 0.75, "#ff0000")
	spawn(rand(600,750))
		for (var/v in 1 to flare_range)
			spawn (v*5)
				flare_range--
				update_light()
		qdel(src)