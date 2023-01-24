var/list/exterior_turfs = list(/turf/floor/grass,
							/turf/floor/dirt,
							/turf/floor/beach/sand,
							/turf/floor/plating/concrete,
							)

var/list/interior_areas = list(/area/caribbean/houses,
							)

// atmos stuff
///turf/var/zone/zone
/turf/var/open_directions

///turf/var/needs_air_update = FALSE
///turf/var/datum/gas_mixture/air


/turf
	name = "turf"
	icon = 'icons/turf/floors.dmi'
	level = TRUE

	//Properties for airtight tiles (/wall)
	var/heat_capacity = TRUE

	//Properties for both
	var/temperature = T20C	  // Initial turf temperature.

	// General properties.
	var/icon_old = null
	var/pathweight = TRUE		  // How much does it cost to pathfind over this turf?

	var/list/decals
	var/move_delay = 0

	var/calcborders = FALSE //if borders were calculated already. To prevent both sides creating borders over each other.

	var/wet = FALSE
	var/image/wet_overlay = null
	var/water_level = 0 // For flooding
	var/is_diggable = FALSE //can be digged with a shovel?
	var/is_plowed = FALSE // ready to be farmed?
	var/is_mineable = FALSE //can be mined with a pickaxe?
	//Mining resources (for the large drills).
//	var/has_resources
//	var/list/resources

	var/to_be_destroyed = FALSE //Used for fire, if a melting temperature was reached, it will be destroyed
	var/max_fire_temperature_sustained = FALSE //The max temperature of the fire which it was subjected to
	var/dirt = FALSE

//	var/datum/scheduled_task/flooding_task
	var/interior = TRUE
	var/stepsound = null
	var/floor_type= null
	var/intact = TRUE

	// for digging out dirt
	var/available_dirt = 0
	var/available_sand = 0
	var/available_snow = 0
	var/bullethole_count = 0
	var/overlay_priority = 0

	map_storage_saved_vars = "icon_state;name"

/turf/New()
	..()
	for (var/atom/movable/AM as mob|obj in src)
		spawn( FALSE )
			Entered(AM)
			return
	if (ticker && ticker.current_state == GAME_STATE_PLAYING)
		new_turfs |= src
	turfs |= src


/turf/CanPass(atom/movable/mover, turf/target, height=1.5,air_group=0)
	if (!target) return FALSE

	if (istype(mover)) // turf/Enter(...) will perform more advanced checks
		return !density

	else // Now, doing more detailed checks for air movement and air group formation
	/*	if (target.blocks_air||blocks_air)
			return FALSE*/

		for (var/obj/obstacle in src)
			if (!obstacle.CanPass(mover, target, height, air_group))
				return FALSE
		if (target != src)
			for (var/obj/obstacle in target)
				if (!obstacle.CanPass(mover, src, height, air_group))
					return FALSE

		return TRUE

/turf/proc/update_icon()
	return

/turf/proc/neighbors()
	var/list/l = list()
	for (var/turf/t in range(1, src))
		l += t
	return l

/turf/Destroy()
	turfs -= src
	for (var/obj/o in contents)
		if (o.special_id == "seasons")
			if (overlays.Find(o))
				overlays -= o
			qdel(o)
	..()

/turf/ex_act(severity)
	return FALSE

/turf/proc/is_space()
	return FALSE

/turf/proc/is_intact()
	return FALSE

/mob/var/next_push = -1

/turf/attack_hand(mob/user)
	if (!(user.canmove) || user.restrained() || !(user.pulling))
		return FALSE
	if (user.pulling.anchored || !isturf(user.pulling.loc))
		return FALSE
	if (user.pulling.loc != user.loc && get_dist(user, user.pulling) > 1)
		return FALSE
	if (istype(src, /turf/floor/dirt/underground) && ishuman(user))
		var/turf/floor/dirt/underground/U = src
		var/mob/living/human/H = user
		if (H.ant)
			visible_message("<span class = 'notice'>[user] starts to break the rock with their hands...</span>", "<span class = 'notice'>You start to break the rock with the your hands...</span>")
			playsound(src,'sound/effects/pickaxe.ogg',100,1)
			if (do_after(user, (160/(H.getStatCoeff("strength"))/1.5)))
				U.collapse_check()
				if (istype(src, /turf/floor/dirt/underground/empty))
					var/turf/floor/dirt/underground/empty/T = src
					T.mining_clear_debris()
					return
				else if (!istype(src, /turf/floor/dirt/underground/empty))
					mining_proc(H)
				return TRUE
	if (world.time >= user.next_push)
		if (ismob(user.pulling))
			var/mob/M = user.pulling
			var/atom/movable/t = M.pulling
			M.stop_pulling()
			step(user.pulling, get_dir(user.pulling.loc, src))
			M.start_pulling(t)
		else
			step(user.pulling, get_dir(user.pulling.loc, src))
		user.next_push = world.time + 20
	return TRUE

/turf/Enter(atom/movable/mover as mob|obj, atom/forget as mob|obj|turf|area)
	if (movement_disabled && usr.ckey != movement_disabled_exception)
		usr << "<span class='warning'>Movement is admin-disabled.</span>" //This is to identify lag problems
		return

	..()

	if (!mover || !isturf(mover.loc) || isobserver(mover))
		return TRUE

	//First, check objects to block exit that are not on the border
	for (var/obj/obstacle in mover.loc)
		if (!(obstacle.flags & ON_BORDER) && (mover != obstacle) && (forget != obstacle))
			if (!obstacle.CheckExit(mover, src))
				mover.Bump(obstacle, TRUE)
				return FALSE

	//Now, check objects to block exit that are on the border
	for (var/obj/border_obstacle in mover.loc)
		if ((border_obstacle.flags & ON_BORDER) && (mover != border_obstacle) && (forget != border_obstacle))
			if (!border_obstacle.CheckExit(mover, src))
				mover.Bump(border_obstacle, TRUE)
				return FALSE

	//Next, check objects to block entry that are on the border
	for (var/obj/border_obstacle in src)
		if (border_obstacle.flags & ON_BORDER)
			if (!border_obstacle.CanPass(mover, mover.loc, TRUE, FALSE) && (forget != border_obstacle))
				mover.Bump(border_obstacle, TRUE)
				return FALSE

	//Then, check the turf itself
	if (!CanPass(mover, src))
		mover.Bump(src, TRUE)
		return FALSE

	//Finally, check objects/mobs to block entry that are not on the border
	for (var/atom/movable/obstacle in src)
		if (!(obstacle.flags & ON_BORDER))
			if (!obstacle.CanPass(mover, mover.loc, TRUE, FALSE) && (forget != obstacle))
				mover.Bump(obstacle, TRUE)
				return FALSE
	return TRUE //Nothing found to block so return success!

var/const/enterloopsanity = 100
/turf/Entered(atom/atom as mob|obj)

	if (movement_disabled)
		usr << "<span class='warning'>Movement is admin-disabled.</span>" //This is to identify lag problems
		return
	..()

	if (!istype(atom, /atom/movable))
		return

	var/atom/movable/A = atom

	if (ismob(A))
		var/mob/M = A
		if (!M.lastarea)
			M.lastarea = get_area(M.loc)

	var/objects = FALSE
	if (A && (A.flags & PROXMOVE))
		for (var/atom/movable/thing in range(1))
			if (objects > enterloopsanity) break
			objects++
			spawn(0)
				if (A)
					A.HasProximity(thing, TRUE)
					if ((thing && A) && (thing.flags & PROXMOVE))
						thing.HasProximity(A, TRUE)
	return

/turf/proc/adjacent_fire_act(turf/floor/source, temperature, volume)
	return

/turf/proc/is_plating()
	return FALSE

/turf/proc/levelupdate()
	for (var/obj/O in src)
		O.hide(O.hides_under_flooring() && !is_plating())

/turf/proc/AdjacentTurfs()
	var/L[] = new()
	for (var/turf/t in oview(src,1))
		if (!t.density)
			if (!LinkBlocked(src, t) && !TurfBlockedNonWindow(t))
				L.Add(t)
	return L

/turf/proc/CardinalTurfs()
	var/L[] = new()
	for (var/turf/T in AdjacentTurfs())
		if (T.x == x || T.y == y)
			L.Add(T)
	return L

/turf/proc/Distance(turf/t)
	if (get_dist(src,t) == TRUE)
		var/cost = (x - t.x) * (x - t.x) + (y - t.y) * (y - t.y)
		cost *= (pathweight+t.pathweight)/2
		return cost
	else
		return get_dist(src,t)

/turf/proc/AdjacentTurfsSpace()
	var/L[] = new()
	for (var/turf/t in oview(src,1))
		if (!t.density)
			if (!LinkBlocked(src, t) && !TurfBlockedNonWindow(t))
				L.Add(t)
	return L

/turf/proc/process()
	return PROCESS_KILL

/turf/proc/contains_dense_objects()
	if (density)
		return TRUE
	for (var/atom/A in src)
		if (A.density && !(A.flags & ON_BORDER))
			return TRUE
	return FALSE

//expects an atom containing the reagents used to clean the turf
/turf/proc/clean(atom/source, mob/user)
	if (source.reagents.has_reagent("water", TRUE) || source.reagents.has_reagent("cleaner", TRUE))
		clean_blood()
		if (istype(src, /turf))
			var/turf/T = src
			T.dirt = FALSE
		for (var/obj/effect/O in src)
			if (istype(O,/obj/effect/decal/cleanable) || istype(O,/obj/effect/overlay))
				qdel(O)
	else
		user << "<span class='warning'>\The [source] is too dry to wash that.</span>"
	source.reagents.trans_to_turf(src, TRUE, 10)	//10 is the multiplier for the reaction effect. probably needed to wet the floor properly.

/turf/proc/update_blood_overlays()
	return

/turf/clean_blood()
	for (var/obj/effect/decal/cleanable/blood/B in contents)
		B.clean_blood()
	..()

/turf/New()
	..()
	levelupdate()


/turf/proc/initialize()
	return

/turf/proc/AddTracks(var/typepath,var/bloodDNA,var/comingdir,var/goingdir,var/bloodcolor="#A10808")
	var/obj/effect/decal/cleanable/blood/tracks/tracks = locate(typepath) in src
	if (!tracks)
		tracks = new typepath(src)
	tracks.AddTracks(bloodDNA,comingdir,goingdir,bloodcolor)

/turf/Entered(atom/A, atom/OL)
	if (movement_disabled && usr.ckey != movement_disabled_exception)
		usr << "<span class='danger'>Movement is admin-disabled.</span>" //This is to identify lag problems
		return

	if (istype(A,/mob/living))
		var/mob/living/M = A
		if (M.lying)
			return ..()


		if (istype(M, /mob/living/human))
			var/mob/living/human/H = M
			if (!istype(src, /turf/floor/beach/water) && !istype(src, /turf/floor/trench/flooded) && !H.on_fire)
				if (H.overlays_standing[25])
					H.overlays_standing[25] = null
					H.update_fire(1)
			var/footstepsound
			// Tracking blood
			var/list/bloodDNA = null
			var/bloodcolor=""

			if (H.shoes)
				var/obj/item/clothing/shoes/S = H.shoes
				if (istype(S))
					S.handle_movement(src,(H.m_intent == "run" ? TRUE : FALSE))
					if (S.track_blood && S.blood_DNA)
						bloodDNA = S.blood_DNA
						bloodcolor=S.blood_color
						S.track_blood--
			else
				if (H.track_blood && H.feet_blood_DNA)
					bloodDNA = H.feet_blood_DNA
					bloodcolor = H.feet_blood_color
					H.track_blood--

			if (bloodDNA)
				AddTracks(/obj/effect/decal/cleanable/blood/tracks/footprints,bloodDNA,H.dir,0,bloodcolor) // Coming
				var/turf/from = get_step(H,reverse_direction(H.dir))
				if (istype(from) && from)
					from.AddTracks(/obj/effect/decal/cleanable/blood/tracks/footprints,bloodDNA,0,H.dir,bloodcolor) // Going

				bloodDNA = null

			//Shoe sounds
			if (type == /turf/floor/plating)
				footstepsound = "platingfootsteps"
			else if (istype(src, /turf/floor/grass))
				footstepsound = "grassfootsteps"
			else if (istype(src, /turf/floor/winter))
				footstepsound = "snowfootsteps"
			else 	if (istype(src, /turf/floor/beach/water) && src.water_level > 0)
				if (!istype(src, /turf/floor/beach/water/ice))
					footstepsound = "waterfootsteps"
				else
					footstepsound = "icefootsteps"
			else	if (istype(src, /turf/floor/beach/sand))
				footstepsound = "sandfootsteps"
			else 	if (istype(src, /turf/floor/wood))
				footstepsound = "woodfootsteps"
			else 	if (istype(src, /turf/floor/carpet))
				footstepsound = "carpetfootsteps"
			else 	if (istype(src, /turf/floor/dirt))
				footstepsound = "dirtfootsteps"
			else 	if (istype(src, /turf/floor/trench))
				if (istype(src, /turf/floor/trench/flooded))
					footstepsound = "waterfootsteps"
				else
					footstepsound = "dirtfootsteps"
			else
				footstepsound = "erikafootsteps"

			for(var/obj/structure/multiz/ladder/ww2/LADDER in src)
				footstepsound = "woodfootsteps"
				break
			for(var/obj/covers/CV in src)
				if (istype(CV, /obj/covers/carpet))
					footstepsound = "carpetfootsteps"
					break
				else if (istype(CV, /obj/covers/wood))
					footstepsound = "woodfootsteps"
					for(var/obj/effect/flooding/FLD in src)
						footstepsound = "waterfootsteps"
						break
					break
				else
					footstepsound = "platingfootsteps"
					break

			if (H.m_intent != "stealth" && H.m_intent != "proning")
				var/fsvol = 60
				if (istype(H.shoes, /obj/item/clothing/shoes))
					fsvol = 100 //shoes make more noise than bare feet
				if (movementMachine.ticks >= H.next_footstep_sound_at_movement_tick)
					playsound(src, footstepsound, fsvol, TRUE)
					switch (H.m_intent)
						if ("run")
							H.next_footstep_sound_at_movement_tick = movementMachine.ticks + (movementMachine.interval*40*(0.3/movementMachine.interval))
						if ("walk")
							H.next_footstep_sound_at_movement_tick = movementMachine.ticks + (movementMachine.interval*53*(0.3/movementMachine.interval))
		if (wet)

			if (M.buckled || (wet == TRUE && M.m_intent == "walk"))
				return

			var/slip_dist = TRUE
			var/slip_stun = 6
			var/floor_type = "wet"

			switch(wet)
				if (2) // Lube
					floor_type = "slippery"
					slip_dist = 4
					slip_stun = 10
				if (3) // Ice
					floor_type = "icy"
					slip_stun = 4

			if (M.slip("the [floor_type] floor",slip_stun))
				for (var/i = FALSE;i<slip_dist;i++)
					step(M, M.dir)
					sleep(1)
			else
				M.inertia_dir = FALSE
		else
			M.inertia_dir = FALSE

	..()

//returns TRUE if made bloody, returns FALSE otherwise
/turf/add_blood(mob/living/human/M as mob)
	if (!..())
		return FALSE

	if (istype(M))
		for (var/obj/effect/decal/cleanable/blood/B in contents)
	/*		if (!B.blood_DNA)
				B.blood_DNA = list()
			if (!B.blood_DNA[M.dna.unique_enzymes])
				B.blood_DNA[M.dna.unique_enzymes] = M.dna.b_type
				B.virus2 = virus_copylist(M.virus2)*/
			return TRUE //we bloodied the floor
		blood_splatter(src,M.get_blood(M.vessel),1)
		return TRUE //we bloodied the floor
	return FALSE


/turf/proc/can_build_cable(var/mob/user)
	return FALSE