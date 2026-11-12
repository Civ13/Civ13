// Human-powered ground transport. Keep fuel, engine and crash damage out of it.
/proc/bicycle_load_ratio(carried_weight, strength)
	var/capacity = max(1, (((strength - 1) / 2) + 1) * 59)
	return max(0, carried_weight) / capacity

/proc/bicycle_step_delay(load_ratio, fastest = 1.5, slowest = 6)
	return Clamp(fastest * (1 + max(0, load_ratio)), fastest, slowest)

/proc/bicycle_step_cost(load_ratio)
	return Clamp(0.5 + max(0, load_ratio) * 0.5, 0.5, 2)

// Natural ground (grass, dirt, sand, snowfields) is slower than built floors
// and roads, and lying snow drags further.
/proc/bicycle_ground_delay(step_delay, rough, snowy)
	if (rough)
		step_delay *= 1.25
	if (snowy)
		step_delay += 1
	return step_delay

// Coasting downhill is free. Rough ground and each level climbed cost more.
/proc/bicycle_ground_cost(step_cost, rough, levels)
	if (levels < 0)
		return 0
	if (rough)
		step_cost *= 1.25
	return step_cost + levels * 0.5

// Include worn items, pockets, holsters and nested bags. Guns and magazines
// already include their ammunition in get_weight(), so do not count it twice.
/proc/bicycle_carried_weight(atom/container)
	var/total = 0
	for (var/obj/item/I in container.contents)
		total += max(0, I.get_weight())
		if (istype(I, /obj/item/weapon/gun/projectile) || istype(I, /obj/item/ammo_magazine))
			continue
		total += bicycle_carried_weight(I)
	return total

/obj/item/vehicleparts/wheel/handle/bicycle
	name = "bicycle handlebars"
	icon = 'icons/obj/vehicles/bicycle.dmi'
	icon_state = "bicycle_handlebars"
	desc = "Use to start or stop pedaling. The secondary action brakes. Direction keys steer."
	weight = 0

/obj/item/vehicleparts/wheel/handle/bicycle/attack_self(mob/living/human/H)
	if (istype(origin, /obj/structure/vehicle/bicycle))
		var/obj/structure/vehicle/bicycle/B = origin
		if (H != B.driver || loc != H)
			return
		if (B.moving)
			B.stopmovementloop()
			to_chat(H, SPAN_NOTICE("You stop pedaling."))
		else if (B.rider_ready())
			B.startmovementloop()
			if (B.moving)
				to_chat(H, SPAN_NOTICE("You start pedaling. Use direction keys to steer and the secondary action to brake."))

/obj/item/vehicleparts/wheel/handle/bicycle/secondary_attack_self(mob/living/human/H)
	if (istype(origin, /obj/structure/vehicle/bicycle))
		var/obj/structure/vehicle/bicycle/B = origin
		if (H == B.driver && loc == H)
			B.secondary_control(H)

/obj/structure/vehicle/bicycle
	name = "pedal bicycle"
	desc = "A pedal-powered bicycle. It is quickest on roads and built floors, and a heavy load slows it down and tires you sooner. Drag yourself onto it, use the handlebars to pedal, and use their secondary action to brake."
	icon = 'icons/obj/vehicles/bicycle.dmi'
	icon_state = "bicycle"
	density = TRUE
	wheeled = TRUE
	not_movable = TRUE
	not_disassemblable = TRUE
	vehicle_m_delay = 1.5
	mobcapacity = 1
	storagecapacity = 0
	var/tmp/pedal_timer = null
	var/tmp/pedal_safety_timer = null
	var/tmp/pedal_next_move = 0
	var/tmp/pedal_busy = FALSE
	// Handlebars, crank and nearest wheel, drawn in front of the rider.
	var/tmp/image/rider_overlay = null
	var/overlay_state = "bicycle_overlay"
	var/control_type = /obj/item/vehicleparts/wheel/handle/bicycle
	// Deciseconds per tile with no load, and the slowest a load can make it.
	var/pedal_fastest = 1.5
	var/pedal_slowest = 6

// The handlebars' secondary action.
/obj/structure/vehicle/bicycle/proc/secondary_control(mob/living/human/H)
	stopmovementloop()
	to_chat(H, SPAN_NOTICE("You brake."))

/obj/structure/vehicle/bicycle/update_overlay()
	if (!rider_overlay)
		rider_overlay = image(icon, overlay_state)
		rider_overlay.layer = MOB_LAYER + 2.1
	overlays -= rider_overlay
	if (driver)
		overlays += rider_overlay

// What the next tile does to a step: list(rough, snowy, levels climbed).
/obj/structure/vehicle/bicycle/proc/ground_ahead(turf/start, turf/target)
	var/rough = !target.terrain_smoothed()
	var/snowy = target.has_snow_cover() && !target.terrain_floor_covered()
	return list(rough, snowy, terrain_step_levels(start, target))

// Hills: the walking slope rule.
/obj/structure/vehicle/bicycle/proc/slope_delay(turf/start, turf/target, interval)
	return terrain_slope_delay(start, target, interval)

/obj/structure/vehicle/bicycle/New()
	..()
	// Saved controls are restored with their holder and cyclic origin link.
	// Creating a second set here would leave duplicate handlebars after load.
	if (!persistence_saved_atom_construction)
		dwheel = new control_type(src)
		dwheel.origin = src

/obj/structure/vehicle/bicycle/persistence_restore_finished()
	..()
	stopmovementloop()
	update_overlay()
	if (!istype(dwheel, control_type))
		dwheel = new control_type(src)
	dwheel.origin = src
	if (!pedal_safety_timer)
		safety_check()

/obj/structure/vehicle/bicycle/safety_check()
	pedal_safety_timer = null
	if (gcDestroyed || persistence_saved_atom_construction)
		return
	if (driver && (driver.loc != loc || driver.buckled != src || driver.driver_vehicle != src))
		unbuckle_mob()
	else if (moving && !rider_ready())
		stopmovementloop()
	release_stale_ride_glides()
	pedal_safety_timer = addtimer(CALLBACK(src, PROC_REF(safety_check)), 20, TIMER_STOPPABLE)

/obj/structure/vehicle/bicycle/controls_released(mob/living/human/H)
	stopmovementloop()

/obj/structure/vehicle/bicycle/proc/rider_ready()
	// ssd_check() lets agent-run bodies ride; a disconnected player stops.
	if (!driver || driver.ssd_check() || driver.stat != CONSCIOUS || health <= 0 || !isturf(loc) || anchored)
		return FALSE
	if (driver.driver_vehicle != src || !driver.driver || driver.buckled != src || driver.loc != loc || !(driver in ontop))
		return FALSE
	if (persistence_input_frozen(driver.client) || driver.incapacitated(INCAPACITATION_DISABLED|INCAPACITATION_RESTRAINED) || driver.legcuffed)
		return FALSE
	if (!dwheel || dwheel.loc != driver || (driver.l_hand != dwheel && driver.r_hand != dwheel))
		return FALSE
	for (var/part in list("l_leg", "r_leg", "l_foot", "r_foot"))
		var/obj/item/organ/external/E = driver.get_organ(part)
		if (!E || E.is_stump())
			return FALSE
	return TRUE

/obj/structure/vehicle/bicycle/MouseDrop_T(atom/A, mob/living/human/user)
	if (A != user || !istype(user) || driver || ontop.len || user.driver || user.buckled || user.anchored || !user.Adjacent(src) || user.incapacitated())
		return
	if (!do_after(user, 20, src))
		return
	// Another rider, restraint or movement may have changed during the wait.
	if (driver || ontop.len || user.driver || user.buckled || user.anchored || !user.Adjacent(src) || user.incapacitated())
		return
	if (!user.put_in_active_hand(dwheel))
		to_chat(user, SPAN_WARNING("You need a free hand for the handlebars."))
		return
	user.stop_pulling()
	user.forceMove(get_turf(src))
	if (!buckle_mob(user))
		user.remove_from_mob(dwheel)
		dwheel.forceMove(src)
		return
	driver = user
	user.driver = TRUE
	user.driver_vehicle = src
	ontop += user
	update_overlay()
	update_icon()
	user.visible_message(SPAN_NOTICE("[user] gets on \the [src]."), SPAN_NOTICE("You get on \the [src]. [mount_hint()]"))

/obj/structure/vehicle/bicycle/proc/mount_hint()
	return "Use the handlebars to pedal; click the bicycle to get off."

/obj/structure/vehicle/bicycle/startmovementloop()
	if (moving || pedal_busy || !rider_ready())
		return
	moving = TRUE
	movement_processes = 1
	// Retain the paid interval across rapid brake/start clicks, but never
	// bank time spent stopped.
	pedal_next_move = max(pedal_next_move, world.time)
	pedal_timer = addtimer(CALLBACK(src, PROC_REF(movementloop)), max(world.tick_lag, pedal_next_move - world.time), TIMER_STOPPABLE)

/obj/structure/vehicle/bicycle/movementloop()
	pedal_timer = null
	if (!moving || pedal_busy || !rider_ready())
		stopmovementloop()
		return
	pedal_busy = TRUE
	var/success = FALSE
	try
		success = do_move(driver.dir)
	catch (var/exception/E)
		pedal_busy = FALSE
		stopmovementloop()
		throw E
	pedal_busy = FALSE
	if (!success || !moving)
		stopmovementloop()
		return
	pedal_timer = addtimer(CALLBACK(src, PROC_REF(movementloop)), max(world.tick_lag, pedal_next_move - world.time), TIMER_STOPPABLE)

/obj/structure/vehicle/bicycle/stopmovementloop()
	moving = FALSE
	movement_processes = 0
	if (pedal_timer)
		deltimer(pedal_timer)
		pedal_timer = null
	release_carriage_glides()

/obj/structure/vehicle/bicycle/do_vehicle_check()
	if (!rider_ready())
		return FALSE
	var/turf/T = get_step(src, driver.dir)
	if (!istype(T, /turf/floor) || T.density || istype(T, /turf/floor/broken_floor))
		return FALSE
	// No buoyancy: water needs a real, non-dense bridge/cover.
	if (istype(T, /turf/floor/beach/water) || istype(T, /turf/floor/trench/flooded))
		var/bridged = FALSE
		for (var/obj/covers/C in T)
			if (!C.density)
				bridged = TRUE
		if (!bridged)
			return FALSE
	var/area/A = get_area(T)
	if (map && A && map.caribbean_blocking_area_types.Find(A.type))
		if (!map.faction1_can_cross_blocks() && !map.faction2_can_cross_blocks())
			return FALSE
	if (map && map.check_caribbean_block(driver, T))
		return FALSE
	return TRUE

/obj/structure/vehicle/bicycle/do_move(m_dir = null, interval = null)
	if (!moving || world.time < pedal_next_move || !do_vehicle_check() || !(m_dir in cardinal) || m_dir != driver.dir)
		return FALSE
	var/mob/living/human/H = driver
	var/turf/start = get_turf(src)
	var/turf/target = get_step(src, m_dir)
	var/list/ground = ground_ahead(start, target)
	var/load_ratio = bicycle_load_ratio(bicycle_carried_weight(H), H.getStatCoeff("strength"))
	var/cost = bicycle_ground_cost(bicycle_step_cost(load_ratio), ground[1], ground[3])
	if (H.getStat("stamina") < cost)
		to_chat(H, SPAN_WARNING("You are too tired to keep pedaling."))
		return FALSE
	interval = bicycle_ground_delay(bicycle_step_delay(load_ratio, pedal_fastest, pedal_slowest), ground[1], ground[2])
	// Hills: slower uphill, a little quicker coasting down.
	interval = Clamp(interval + slope_delay(start, target, interval), 1, max(10, pedal_slowest))
	vehicle_m_delay = interval
	// Timers land on whole server ticks. Keep to the schedule while it is less
	// than one step behind, so late ticks do not stretch the average pace.
	var/due = pedal_next_move
	if (due < world.time - interval)
		due = world.time
	pedal_next_move = due + interval
	var/datum/carriage_glide_lease/lease = claim_ride_glides(m_dir, interval)
	// Native Move honors borders, doors, covers, mobs and turf collision.
	// Do not use legacy forceMove to drive through them or inflict engine damage.
	if (!Move(target, m_dir) || loc != target)
		lease.release()
		to_chat(H, SPAN_WARNING("Something is in the way. You stop pedaling."))
		return FALSE
	if (gcDestroyed || !H || driver != H || H.loc != start || H.buckled != src)
		lease.release()
		return FALSE
	H.stats["stamina"][1] = max(0, H.stats["stamina"][1] - cost)
	H.forceMove(target)
	for (var/atom/movable/member in lease.members)
		member.carriage_glide_step = null
	update_icon()
	return H && driver == H && H.loc == loc && H.buckled == src

/obj/structure/vehicle/bicycle/unbuckle_mob()
	stopmovementloop()
	if (driver)
		var/mob/living/human/H = driver
		if (dwheel && dwheel.loc == H)
			H.remove_from_mob(dwheel)
			dwheel.forceMove(src)
		H.driver = FALSE
		H.driver_vehicle = null
		ontop -= H
		driver = null
		update_overlay()
	return ..()

/obj/structure/vehicle/bicycle/Destroy()
	unbuckle_mob()
	if (pedal_safety_timer)
		deltimer(pedal_safety_timer)
		pedal_safety_timer = null
	return ..()

/obj/structure/vehicle/bicycle/persistence_runtime_var(key)
	return key == "pedal_safety_timer" || key == "pedal_timer" || key == "pedal_next_move" || key == "pedal_busy" || key == "rider_overlay" || key == "moving" || key == "movement_processes" || ..()
