// Pedal airship: a one-person gas bag with a pedal-driven propeller. It shares
// the bicycle's seat, load and stamina rules (bicycle.dm) and the planes' sky:
// aloft it rides on the open-air level above the ground (multiz_level_above),
// so it only flies where a map has one. It is buoyant, not winged: it rises and
// sinks on the spot, hovers when the rider stops or tires, and drifts down by
// itself if it ever loses its rider. No engine, fuel or crash damage.

// Carried load, as a share of carrying capacity, above which it cannot lift.
#define PEDAL_AIRSHIP_LIFT_LIMIT 1
// Stamina spent pedaling up to flying height.
#define PEDAL_AIRSHIP_RISE_COST 5
#define PEDAL_AIRSHIP_RISE_TIME 30
#define PEDAL_AIRSHIP_SINK_TIME 20
// How far (in tiles) a forced descent looks for clear ground.
#define PEDAL_AIRSHIP_SET_DOWN_SEARCH 6
// Ground shown through the open air around it: in full, and a fainter ring.
#define PEDAL_AIRSHIP_VIEW_RANGE 7
#define PEDAL_AIRSHIP_VIEW_FAR 10

var/global/list/aloft_pedal_airships = list()

// Open air holds an airship that is aloft and its rider (aircraft_holds).
/proc/pedal_airship_holds(turf/T, atom/movable/A)
	for (var/obj/structure/vehicle/bicycle/airship/S in T)
		if (S.aloft && (A == S || (A in S.ontop)))
			return TRUE
	return FALSE

/proc/pedal_airship_can_lift(load_ratio)
	return load_ratio <= PEDAL_AIRSHIP_LIFT_LIMIT

/obj/item/vehicleparts/wheel/handle/bicycle/airship
	name = "airship tiller"
	desc = "Use to start or stop pedaling the propeller. The secondary action brakes, and when you are stopped it rises from the ground or sinks back to it. Direction keys steer."

/obj/structure/vehicle/bicycle/airship
	name = "pedal airship"
	desc = "A gas bag over a one-seat gondola with a pedal-driven propeller. Drag yourself onto it, then use the tiller's secondary action to rise, use the tiller to pedal, and stop and use the secondary action again to sink back down. It cannot lift more than you could carry on foot, and a load makes it slow."
	icon = 'icons/obj/vehicles/pedal_airship.dmi'
	icon_state = "airship"
	pixel_x = -16
	overlay_state = "airship_overlay"
	control_type = /obj/item/vehicleparts/wheel/handle/bicycle/airship
	pedal_fastest = 3
	pedal_slowest = 12
	// The rider stands in the basket.
	rider_lift = 0
	vehicle_m_delay = 3
	var/aloft = FALSE
	var/tmp/changing_height = FALSE
	var/tmp/obj/effect/aircraft_shadow/shadow
	var/tmp/turf/shadow_turf
	var/tmp/obj/effect/aircraft_ground_view/ground_view
	var/tmp/obj/effect/aircraft_ground_view/ground_view_far
	var/tmp/turf/ground_view_anchor

/obj/structure/vehicle/bicycle/airship/persistence_runtime_var(key)
	return (key in list("aloft", "changing_height", "shadow", "shadow_turf", "ground_view", "ground_view_far", "ground_view_anchor")) || ..()

/obj/structure/vehicle/bicycle/airship/mount_hint()
	return "Use the tiller's secondary action to rise, the tiller to pedal, and click the airship to get off once it is back on the ground."

// Open air it can float in: no floor or roof, nothing solid.
/proc/pedal_airship_open_air(turf/T)
	if (!istype(T, /turf/sky/building) || (locate(/obj/covers) in T))
		return FALSE
	for (var/obj/O in T)
		if (O.density && !istype(O, /obj/structure/vehicle/bicycle/airship))
			return FALSE
	return TRUE

// Why it cannot settle on ground tile G, or null when it can: dry, solid, clear.
/obj/structure/vehicle/bicycle/airship/proc/landing_block(turf/G)
	if (!G)
		return "nothing"
	if (!istype(G, /turf/floor) || G.density || istype(G, /turf/floor/broken_floor) || !G.aircraft_rough_ground())
		return "\the [G]"
	for (var/obj/O in G)
		if (O.density && O != src)
			return "\the [O]"
	for (var/mob/living/L in G)
		if (L.density && !(L in ontop))
			return "[L]"
	return null

/obj/structure/vehicle/bicycle/airship/proc/ground_turf()
	var/below = multiz_level_below(z)
	return below ? locate(x, y, below) : null

/obj/structure/vehicle/bicycle/airship/proc/set_aloft(state)
	aloft = state
	if (state)
		aloft_pedal_airships |= src
	else
		aloft_pedal_airships -= src

// Moves the airship and whoever sits in it to T.
/obj/structure/vehicle/bicycle/airship/proc/float_to(turf/T)
	var/list/riders = ontop.Copy()
	release_carriage_glides()
	forceMove(T)
	for (var/mob/living/M in riders)
		M.forceMove(T)
	update_flight_visuals()
	update_icon()

/obj/structure/vehicle/bicycle/airship/secondary_control(mob/living/human/H)
	if (moving)
		stopmovementloop()
		to_chat(H, SPAN_NOTICE("You stop pedaling. The airship hangs where it is."))
		return
	if (aloft)
		descend(H)
	else
		ascend(H)

/obj/structure/vehicle/bicycle/airship/proc/ascend(mob/living/human/H)
	if (changing_height || aloft || !rider_ready())
		return FALSE
	var/up = multiz_level_above(z)
	var/turf/sky = up ? locate(x, y, up) : null
	if (!sky || !istype(sky, /turf/sky/building))
		to_chat(H, SPAN_WARNING("There is no open sky above this place to fly into."))
		return FALSE
	if ((locate(/obj/roof) in loc) || !pedal_airship_open_air(sky))
		to_chat(H, SPAN_WARNING("Something overhead is in the way. Rise from open ground."))
		return FALSE
	if (!pedal_airship_can_lift(bicycle_load_ratio(bicycle_carried_weight(H), H.getStatCoeff("strength"))))
		to_chat(H, SPAN_WARNING("The airship strains but cannot lift you. Carry less."))
		return FALSE
	if (H.getStat("stamina") < PEDAL_AIRSHIP_RISE_COST)
		to_chat(H, SPAN_WARNING("You are too tired to pedal it off the ground."))
		return FALSE
	changing_height = TRUE
	H.visible_message(SPAN_NOTICE("[H] pedals hard and \the [src] starts to lift."), SPAN_NOTICE("You pedal hard and \the [src] starts to lift."))
	var/done = do_after(H, PEDAL_AIRSHIP_RISE_TIME, src)
	changing_height = FALSE
	// The rider, the load and the sky may all have changed during the climb.
	if (!done || aloft || !rider_ready() || multiz_level_above(z) != up || (locate(/obj/roof) in loc) || !pedal_airship_open_air(sky))
		return FALSE
	if (!pedal_airship_can_lift(bicycle_load_ratio(bicycle_carried_weight(H), H.getStatCoeff("strength"))) || H.getStat("stamina") < PEDAL_AIRSHIP_RISE_COST)
		return FALSE
	H.stats["stamina"][1] = max(0, H.stats["stamina"][1] - PEDAL_AIRSHIP_RISE_COST)
	visible_message(SPAN_NOTICE("\The [src] floats up and away."))
	set_aloft(TRUE)
	float_to(sky)
	to_chat(H, SPAN_NOTICE("You are aloft. Use the tiller to pedal; stop and use its secondary action to sink back down."))
	return TRUE

/obj/structure/vehicle/bicycle/airship/proc/descend(mob/living/human/H)
	if (changing_height || !aloft || !rider_ready())
		return FALSE
	var/turf/G = ground_turf()
	var/hit = landing_block(G)
	if (hit)
		to_chat(H, SPAN_WARNING("You cannot settle here: [hit] is right below you. Find dry, clear ground."))
		return FALSE
	changing_height = TRUE
	to_chat(H, SPAN_NOTICE("You let \the [src] sink."))
	var/done = do_after(H, PEDAL_AIRSHIP_SINK_TIME, src)
	changing_height = FALSE
	if (!done || !aloft || !rider_ready() || ground_turf() != G || landing_block(G))
		return FALSE
	set_aloft(FALSE)
	float_to(G)
	visible_message(SPAN_NOTICE("\The [src] settles onto the ground."))
	return TRUE

// A forced descent: no rider at the tiller, a save restored in mid air, or the
// airship coming apart. Straight down where that is clear, else the nearest
// clear ground, else straight down anyway. Nobody is hurt.
/obj/structure/vehicle/bicycle/airship/proc/set_down()
	if (!aloft)
		return FALSE
	stopmovementloop()
	var/turf/G = ground_turf()
	var/turf/best = null
	if (G && !landing_block(G))
		best = G
	else if (G)
		for (var/r = 1, r <= PEDAL_AIRSHIP_SET_DOWN_SEARCH && !best, r++)
			for (var/turf/T in range(r, G))
				if (!landing_block(T))
					best = T
					break
	if (!best)
		best = G
	set_aloft(FALSE)
	if (!best)
		clear_flight_visuals()
		return FALSE
	// Anyone left on its tile comes down with it rather than hanging in the air.
	var/list/stranded = list()
	for (var/mob/living/M in loc)
		if (!(M in ontop))
			stranded += M
	float_to(best)
	for (var/mob/living/M in stranded)
		M.forceMove(best)
	visible_message(SPAN_NOTICE("\The [src] drifts down and settles on the ground."))
	return TRUE

// The propeller only pulls it through the air.
/obj/structure/vehicle/bicycle/airship/startmovementloop()
	if (changing_height)
		return
	if (!aloft)
		if (driver)
			to_chat(driver, SPAN_WARNING("The propeller only pulls it through the air. Use the tiller's secondary action to rise first."))
		return
	..()

/obj/structure/vehicle/bicycle/airship/do_vehicle_check()
	if (!rider_ready() || changing_height || !aloft)
		return FALSE
	var/turf/T = get_step(src, driver.dir)
	// It floats over open air only; upper storeys and the map edge stop it.
	return T && pedal_airship_open_air(T)

// Nothing on the ground reaches it: no rough ground, snow or slopes.
/obj/structure/vehicle/bicycle/airship/ground_ahead(turf/start, turf/target)
	return list(FALSE, FALSE, 0)

/obj/structure/vehicle/bicycle/airship/slope_delay(turf/start, turf/target, interval)
	return 0

/obj/structure/vehicle/bicycle/airship/do_move(m_dir = null, interval = null)
	. = ..()
	if (aloft)
		update_flight_visuals()

/obj/structure/vehicle/bicycle/airship/attack_hand(mob/living/human/user)
	if (aloft && (user in ontop))
		if (!retake_controls(user))
			to_chat(user, SPAN_WARNING("You cannot get off up here. Stop, then use the tiller's secondary action to sink to the ground."))
		return
	..()

/obj/structure/vehicle/bicycle/airship/attackby(obj/item/weapon/W, mob/living/human/user)
	if (aloft && (user in ontop) && istype(W, /obj/item/vehicleparts/wheel))
		to_chat(user, SPAN_WARNING("You cannot get off up here. Stop, then use the tiller's secondary action to sink to the ground."))
		return
	..()

// Losing its rider in the air, however that happens, brings it down first.
/obj/structure/vehicle/bicycle/airship/unbuckle_mob()
	set_down()
	return ..()

/obj/structure/vehicle/bicycle/airship/driver_died(mob/living/human/H)
	if (H == driver)
		set_down()
	return ..()

/obj/structure/vehicle/bicycle/airship/safety_check()
	..()
	if (aloft && !driver && !gcDestroyed)
		set_down()

/obj/structure/vehicle/bicycle/airship/persistence_restore_finished()
	..()
	if (istype(loc, /turf/sky/building))
		set_aloft(TRUE)
		addtimer(CALLBACK(src, PROC_REF(set_down)), 1)

/obj/structure/vehicle/bicycle/airship/Destroy()
	. = ..()
	set_aloft(FALSE)
	clear_flight_visuals()

// What the rider sees of the ground and what the ground sees of the airship.
// Like the planes' (aircraft_view.dm), these live in nullspace and are drawn
// through turf vis_contents, which saves never record.
/obj/structure/vehicle/bicycle/airship/proc/update_flight_visuals()
	var/turf/here = get_turf(src)
	var/turf/below = aloft ? ground_turf() : null
	if (!here || !below || !istype(here, /turf/sky/building))
		clear_flight_visuals()
		return
	if (!shadow)
		shadow = new
		shadow.loc = null
	shadow.appearance = appearance
	shadow.name = "shadow"
	shadow.mouse_opacity = 0
	shadow.appearance_flags = KEEP_TOGETHER | RESET_TRANSFORM
	shadow.color = "#000000"
	shadow.alpha = 90
	shadow.plane = FLOOR_PLANE
	shadow.layer = TURF_LAYER + 0.05
	shadow.pixel_x = pixel_x + 12
	shadow.pixel_y = -12
	if (shadow_turf != below)
		if (shadow_turf)
			shadow_turf.vis_contents -= shadow
		shadow_turf = below
		below.vis_contents += shadow
	var/list/near = list()
	var/list/far = list()
	var/min_x = world.maxx + 1
	var/min_y = world.maxy + 1
	for (var/turf/air in block(locate(max(1, here.x - PEDAL_AIRSHIP_VIEW_FAR), max(1, here.y - PEDAL_AIRSHIP_VIEW_FAR), here.z), locate(min(world.maxx, here.x + PEDAL_AIRSHIP_VIEW_FAR), min(world.maxy, here.y + PEDAL_AIRSHIP_VIEW_FAR), here.z)))
		if (!istype(air, /turf/sky/building) || (locate(/obj/covers) in air))
			continue
		var/turf/G = locate(air.x, air.y, below.z)
		if (!G)
			continue
		if (max(abs(air.x - here.x), abs(air.y - here.y)) <= PEDAL_AIRSHIP_VIEW_RANGE)
			near += G
		else
			far += G
		min_x = min(min_x, G.x)
		min_y = min(min_y, G.y)
	if (!ground_view)
		ground_view = new
		ground_view.loc = null
	if (!ground_view_far)
		ground_view_far = new /obj/effect/aircraft_ground_view/far
		ground_view_far.loc = null
	var/turf/anchor = locate(min_x, min_y, here.z)
	if (ground_view_anchor != anchor)
		if (ground_view_anchor)
			ground_view_anchor.vis_contents -= ground_view
			ground_view_anchor.vis_contents -= ground_view_far
		ground_view_anchor = anchor
		if (anchor)
			anchor.vis_contents += ground_view_far
			anchor.vis_contents += ground_view
	ground_view.vis_contents = near
	ground_view_far.vis_contents = far

/obj/structure/vehicle/bicycle/airship/proc/clear_flight_visuals()
	if (shadow_turf)
		shadow_turf.vis_contents -= shadow
	shadow_turf = null
	if (shadow)
		qdel(shadow)
	shadow = null
	if (ground_view_anchor)
		ground_view_anchor.vis_contents -= ground_view
		ground_view_anchor.vis_contents -= ground_view_far
	ground_view_anchor = null
	if (ground_view)
		ground_view.vis_contents = list()
		qdel(ground_view)
	if (ground_view_far)
		ground_view_far.vis_contents = list()
		qdel(ground_view_far)
	ground_view = null
	ground_view_far = null

#undef PEDAL_AIRSHIP_VIEW_FAR
#undef PEDAL_AIRSHIP_VIEW_RANGE
#undef PEDAL_AIRSHIP_SET_DOWN_SEARCH
#undef PEDAL_AIRSHIP_SINK_TIME
#undef PEDAL_AIRSHIP_RISE_TIME
#undef PEDAL_AIRSHIP_RISE_COST
#undef PEDAL_AIRSHIP_LIFT_LIMIT
