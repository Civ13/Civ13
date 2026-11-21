// ============================================================
// Vehicle roof decks: riding on top of a vehicle
// ------------------------------------------------------------
// The top of a vehicle is a raised deck on the street's own level, not a
// second z-level (multi-deck vehicles plan, Phase 1). Someone up there stands
// on the same tile as whoever rides inside, carries a deck (the frame under
// their feet) the way a tree climber carries a tree, and is drawn raised over
// the roof. So nothing falls through open air, nothing has to exist above the
// street, and a save only ever holds one level.
//
//   - Up: grab a roofed frame from outside with a free hand (or Climb Onto
//     Roof), or climb out through the hatch over your seat in a tank
//     (Climb Through Hatch).
//   - On top: walk across the roofed frames of that vehicle (or one parked
//     against it). The deck rides with the vehicle when it drives or turns.
//   - Off: walking off the edge is a jump that lands at once on the tile
//     beside the vehicle and hurts a little; Climb Down is the careful way,
//     back through a hatch when you stand on one.
//   - Up there you see over walls (los_terrain.dm), cannot reach anyone below
//     in melee, and can be shot at directly (projectile.dm).
//   - A crash or a hard turn at speed throws riders off, and driving under a
//     roof sweeps them off backwards (deck_jolt, deck_clearance).
// ============================================================

#define VEHICLE_DECK_CLIMB_TIME 30
#define VEHICLE_DECK_DOWN_TIME 20
#define VEHICLE_DECK_PIXEL_Y 14
#define VEHICLE_DECK_LAYER 11.5
#define VEHICLE_DECK_THROW_RANGE 6

// A frame whose top people may stand on even without a roof (an open-top
// upper deck).
/obj/structure/vehicleparts/frame/var/upper_deck = FALSE
// A roof opening over a seat that is not a tank hatch (a car's sunroof).
/obj/structure/vehicleparts/frame/var/sunroof = FALSE

/mob/living/human/var/tmp/vehicle_deck_busy = FALSE
/mob/living/human/var/tmp/vehicle_deck_old_layer = null

// A climb in progress is never saved: a restored character can climb again.
/mob/living/human/persistence_runtime_var(key)
	return key == "vehicle_deck_busy" || ..()

// Deck surfaces: what a rider can stand on top of. Either a vehicle frame
// (modular vehicles) or a tile of a roofed train car (train_platforms.dm),
// which is the segment on the rail tile or the deck part either side of it.
// A rider's vehicle_deck is the surface on their own tile; nothing else about
// the vehicle is kept, so a deck needs no saved references.

// The train segment a deck surface belongs to, or null.
/proc/train_deck_segment(atom/D)
	if (istype(D, /obj/structure/trains/platform))
		return D
	if (istype(D, /obj/structure/train_part/deck))
		var/obj/structure/train_part/deck/P = D
		return P.segment
	return null

// TRUE when someone may stand on top of D.
/proc/vehicle_deck_walkable(atom/D)
	if (!D || QDELETED(D) || !isturf(D.loc))
		return FALSE
	if (istype(D, /obj/structure/vehicleparts/frame))
		var/obj/structure/vehicleparts/frame/F = D
		return F.axis && (F.upper_deck || !F.noroof)
	var/obj/structure/trains/platform/S = train_deck_segment(D)
	return S && S.roofed()

// The deck surface on T, or null.
/proc/vehicle_deck_at(turf/T)
	if (!T)
		return null
	for (var/obj/O in T)
		if (O.loc == T && vehicle_deck_walkable(O))
			return O
	return null

// What D belongs to, so riders on the same vehicle can be told apart from
// riders on another: a frame's axis, or a train car's id.
/proc/vehicle_deck_vehicle(atom/D)
	if (istype(D, /obj/structure/vehicleparts/frame))
		var/obj/structure/vehicleparts/frame/F = D
		return F.axis
	var/obj/structure/trains/platform/S = train_deck_segment(D)
	return S ? S.car_id : null

// The vehicle M is riding on top of (frame axis or train car id), or null.
/proc/vehicle_deck_group(mob/M)
	if (!los_on_vehicle_deck(M))
		return null
	return vehicle_deck_vehicle(M.vehicle_deck)

// TRUE when riders A and B can reach each other on top: the same vehicle, or
// two coupled train cars with the riders next to each other.
/proc/vehicle_deck_same_roof(mob/A, mob/B)
	var/a = vehicle_deck_group(A)
	var/b = vehicle_deck_group(B)
	if (!a || !b)
		return FALSE
	if (a == b)
		return TRUE
	return istext(a) && istext(b) && get_dist(A, B) <= 1

// TRUE when M stands inside the vehicle D is part of (under its roof).
/proc/vehicle_deck_inside(mob/M, atom/D)
	var/owner = vehicle_deck_vehicle(D)
	if (!owner || !isturf(M.loc))
		return FALSE
	for (var/obj/O in M.loc)
		if ((istype(O, /obj/structure/vehicleparts/frame) || train_deck_segment(O)) && vehicle_deck_vehicle(O) == owner)
			return TRUE
	return FALSE

// The vehicle M is riding on top of, or null.
/proc/vehicle_deck_axis(mob/M)
	if (!los_on_vehicle_deck(M))
		return null
	var/obj/structure/vehicleparts/frame/F = M.vehicle_deck
	return istype(F) ? F.axis : null

// TRUE when F opens through its roof over a seat (a tank hatch or a sunroof),
// or has a bus's stairs up to its upper deck.
/proc/vehicle_deck_hatch(obj/structure/vehicleparts/frame/F)
	if (!istype(F) || !F.axis)
		return FALSE
	if (locate(/obj/structure/vehicle_stairs) in F.loc)
		return TRUE
	if (!(locate(/obj/structure/bed/chair) in F.loc))
		return FALSE
	return F.sunroof || istype(F.axis, /obj/structure/vehicleparts/axis/heavy)

/mob/living/human/proc/vehicle_deck_pose_y()
	return initial(pixel_y) + VEHICLE_DECK_PIXEL_Y

/mob/living/human/rest_pixel_y()
	return los_on_vehicle_deck(src) ? vehicle_deck_pose_y() : ..()

// Null when the human can get up onto F now, otherwise why not.
// from_inside: through a hatch over their seat.
/mob/living/human/proc/vehicle_deck_refusal(obj/structure/vehicleparts/frame/F, from_inside = FALSE)
	if (!vehicle_deck_walkable(F))
		return "There is no roof there to stand on."
	if (vehicle_deck)
		return "You are already on top of a vehicle."
	if (climbed_tree)
		return "Climb down from the tree first."
	if (!isturf(loc) || F.z != z)
		return "You can't reach the roof from here."
	if (from_inside)
		if (F.loc != loc || !vehicle_deck_hatch(F))
			return "There is no hatch over you."
	else
		if (get_dist(src, F) != 1)
			return "You need to stand next to \the [F]."
		if (vehicle_deck_inside(src, F))
			return "You are inside it. Climb out through a hatch, or get out first."
	if (stat || lying || resting || prone || weakened || stunned || paralysis || restrained())
		return "You can't climb right now."
	if (!from_inside && buckled)
		return "You can't climb right now."
	if (l_hand && r_hand)
		return "You need a free hand to climb."
	if (grabbed_by && grabbed_by.len)
		return "You can't climb while someone holds you."
	return null

/mob/living/human/proc/climb_onto_vehicle(obj/structure/vehicleparts/frame/F, from_inside = FALSE)
	if (!F || vehicle_deck_busy)
		return FALSE
	var/why = vehicle_deck_refusal(F, from_inside)
	if (why)
		to_chat(src, SPAN_WARNING(why))
		return FALSE
	vehicle_deck_busy = TRUE
	visible_message(SPAN_NOTICE("[src] starts climbing onto \the [F]."), SPAN_NOTICE("You start climbing [from_inside ? ((locate(/obj/structure/vehicle_stairs) in F.loc) ? "the stairs" : "out through the hatch") : "onto the roof"]..."))
	var/climb_time = from_inside ? VEHICLE_DECK_DOWN_TIME : VEHICLE_DECK_CLIMB_TIME
	var/climb_motion = body_motion_climb(TRUE, climb_time)
	var/done = do_after(src, climb_time, F)
	body_motion_stop(climb_motion)
	vehicle_deck_busy = FALSE
	if (!done)
		return FALSE
	why = vehicle_deck_refusal(F, from_inside)
	if (why)
		to_chat(src, SPAN_WARNING(why))
		return FALSE
	return board_vehicle_deck(F)

// Puts the human on top of F at once.
/mob/living/human/proc/board_vehicle_deck(obj/structure/vehicleparts/frame/F)
	if (!vehicle_deck_walkable(F))
		return FALSE
	if (buckled)
		buckled.unbuckle_mob()
	stop_pulling()
	if (pulledby)
		pulledby.stop_pulling()
	if (loc != F.loc)
		forceMove(F.loc)
	step_x = 0
	step_y = 0
	if (loc != F.loc)
		return FALSE
	vehicle_deck = F
	if (isnull(vehicle_deck_old_layer))
		vehicle_deck_old_layer = layer
	layer = VEHICLE_DECK_LAYER
	animate(src, pixel_y = vehicle_deck_pose_y(), time = 3)
	var/obj/structure/vehicleparts/frame/upper = F
	if (istype(upper) && upper.upper_deck)
		visible_message(SPAN_NOTICE("[src] goes up to the upper deck."), SPAN_NOTICE("You are on the upper deck. You can see over walls from up here. Walk off the edge to jump down, or use Climb Down."))
	else
		visible_message(SPAN_NOTICE("[src] climbs up onto \the [F]."), SPAN_NOTICE("You are on top of \the [F]. You can see over walls from up here. Walk off the edge to jump down, or use Climb Down."))
	vehicle_deck_refresh_sight()
	return TRUE

// Leaves the deck for dest (or stays on this tile when dest is null).
// how: "climb" (careful), "jump" (walked off the edge) or "fall".
/mob/living/human/proc/leave_vehicle_deck(turf/dest, how = "climb")
	if (!vehicle_deck)
		return
	vehicle_deck = null
	animate(src)
	pixel_y = initial(pixel_y)
	layer = isnull(vehicle_deck_old_layer) ? initial(layer) : vehicle_deck_old_layer
	vehicle_deck_old_layer = null
	if (dest && dest != loc)
		forceMove(dest)
		step_x = 0
		step_y = 0
	switch (how)
		if ("jump")
			visible_message(SPAN_WARNING("[src] jumps down from the vehicle."), SPAN_WARNING("You jump down and hit the ground hard."))
			adjustBruteLoss(rand(1, 4))
			Weaken(1)
		if ("fall")
			visible_message(SPAN_DANGER("[src] falls off the vehicle!"), SPAN_DANGER("You fall off the vehicle!"))
			adjustBruteLoss(rand(3, 8))
			Weaken(2)
		else
			visible_message(SPAN_NOTICE("[src] climbs down."), SPAN_NOTICE("You climb down."))
	vehicle_deck_refresh_sight()

/mob/living/human/proc/vehicle_deck_refresh_sight()
	if (looking)
		look_into_distance(src, FALSE)
	if (client && CIV13_GEOMETRIC_LOS_CORE)
		client.los_dirty = TRUE
		client.reconcile_geometric_los()

// TRUE when a person can land on T from a vehicle's top.
/proc/vehicle_deck_landing_clear(turf/T)
	if (!T || T.density)
		return FALSE
	for (var/atom/movable/AM in T)
		if (AM.density && !ismob(AM))
			return FALSE
	return TRUE

// A movement key while on top: walk across the deck, or jump off the edge.
/mob/living/human/proc/vehicle_deck_step(direct)
	var/turf/here = get_turf(src)
	var/turf/dest = get_step(here, direct)
	dir = direct
	if (!dest)
		return FALSE
	var/obj/structure/vehicleparts/frame/next = vehicle_deck_at(dest)
	if (next)
		forceMove(dest)
		step_x = 0
		step_y = 0
		vehicle_deck = next
		pixel_y = vehicle_deck_pose_y()
		vehicle_deck_refresh_sight()
		return TRUE
	if (!vehicle_deck_landing_clear(dest))
		to_chat(src, SPAN_WARNING("You can't jump down there."))
		return FALSE
	leave_vehicle_deck(dest, "jump")
	return TRUE

// Climb Down from the top: back through the hatch under you, otherwise over
// the side onto the nearest clear ground.
/mob/living/human/proc/start_vehicle_deck_down()
	if (!vehicle_deck || vehicle_deck_busy)
		return FALSE
	var/obj/structure/vehicleparts/frame/F = vehicle_deck
	var/turf/dest = null
	if (vehicle_deck_hatch(F))
		dest = get_turf(F)
	else
		for (var/d in list(dir, NORTH, SOUTH, EAST, WEST))
			var/turf/T = get_step(F.loc, d)
			if (T && !vehicle_deck_at(T) && vehicle_deck_landing_clear(T))
				dest = T
				break
	if (!dest)
		to_chat(src, SPAN_WARNING("There is no clear ground beside the vehicle to climb down to."))
		return FALSE
	vehicle_deck_busy = TRUE
	to_chat(src, SPAN_NOTICE("You start climbing down..."))
	var/climb_motion = body_motion_climb(FALSE, VEHICLE_DECK_DOWN_TIME)
	var/done = do_after(src, VEHICLE_DECK_DOWN_TIME, F)
	body_motion_stop(climb_motion)
	vehicle_deck_busy = FALSE
	if (!done || vehicle_deck != F)
		return FALSE
	if (dest != get_turf(F) && !vehicle_deck_landing_clear(dest))
		to_chat(src, SPAN_WARNING("Something is in the way now."))
		return FALSE
	leave_vehicle_deck(dest == get_turf(F) ? null : dest)
	return TRUE

// Once per Life tick while on top.
/mob/living/human/proc/vehicle_deck_check()
	var/obj/structure/vehicleparts/frame/F = vehicle_deck
	if (!vehicle_deck_walkable(F) || F.loc != loc || !isturf(loc))
		// The roof went away under them, or they were moved off it.
		leave_vehicle_deck(null, (F && QDELETED(F)) || (F && F.loc == loc) ? "fall" : "climb")
		return
	if (stat || paralysis || weakened || stunned || sleeping > 0 || buckled)
		var/turf/beside = null
		for (var/d in shuffle(list(NORTH, SOUTH, EAST, WEST)))
			var/turf/T = get_step(loc, d)
			if (T && !vehicle_deck_at(T) && vehicle_deck_landing_clear(T))
				beside = T
				break
		leave_vehicle_deck(beside, "fall")
		return
	if (pixel_y != vehicle_deck_pose_y())
		pixel_y = vehicle_deck_pose_y()
	if (layer != VEHICLE_DECK_LAYER)
		layer = VEHICLE_DECK_LAYER

/mob/living/human/Life()
	. = ..()
	if (vehicle_deck)
		vehicle_deck_check()
	else if (layer == VEHICLE_DECK_LAYER)
		// Off the roof (a save loaded without the deck): back to the ground.
		layer = isnull(vehicle_deck_old_layer) ? initial(layer) : vehicle_deck_old_layer
		vehicle_deck_old_layer = null
		pixel_y = initial(pixel_y)

// Thrown off the top towards throw_dir: past the vehicle's edge onto clear
// ground, else onto any clear tile beside it, else down onto the frame's own
// tile. why: what the rider is told.
/mob/living/human/proc/vehicle_deck_thrown(throw_dir, why)
	if (!vehicle_deck)
		return
	var/turf/dest = null
	if (throw_dir)
		var/turf/T = loc
		for (var/i = 1 to VEHICLE_DECK_THROW_RANGE)
			T = get_step(T, throw_dir)
			if (!T)
				break
			if (vehicle_deck_at(T))
				continue
			if (vehicle_deck_landing_clear(T))
				dest = T
			break
	if (!dest)
		for (var/d in shuffle(list(NORTH, SOUTH, EAST, WEST)))
			var/turf/T = get_step(loc, d)
			if (T && !vehicle_deck_at(T) && vehicle_deck_landing_clear(T))
				dest = T
				break
	if (why)
		to_chat(src, SPAN_DANGER(why))
	leave_vehicle_deck(dest, "fall")

// Everyone riding on top of this vehicle.
/obj/structure/vehicleparts/axis/proc/deck_riders()
	. = list()
	for (var/obj/structure/vehicleparts/frame/F in components)
		if (!isturf(F.loc))
			continue
		for (var/mob/living/human/H in F.loc)
			if (H.vehicle_deck == F)
				. += H

// A crash, a stall or a hard turn at speed: each rider on top is thrown off
// with chance percent.
/obj/structure/vehicleparts/axis/proc/deck_jolt(chance, throw_dir, why)
	if (chance <= 0)
		return
	for (var/mob/living/human/H in deck_riders())
		if (prob(chance))
			H.vehicle_deck_thrown(throw_dir, why)

// After a step or a turn: a roof overhead sweeps riders off the top,
// backwards (back_dir) when driving under it.
/obj/structure/vehicleparts/axis/proc/deck_clearance(back_dir)
	for (var/mob/living/human/H in deck_riders())
		var/obj/roof/R = locate(/obj/roof) in H.loc
		if (R)
			H.vehicle_deck_thrown(back_dir, "You hit \the [R] overhead and are knocked off!")

// ---- Train car roofs (train_platforms.dm) ----

// TRUE when this car has a roof to ride on: coaches, sleepers, dining,
// storage and armored cars. Flatbeds and gun cars are open decks.
/obj/structure/trains/platform/proc/roofed()
	if (wrecked || !isturf(loc))
		return FALSE
	var/list/L = layout()
	// A locomotive has a roof over its cab only (train_locomotives.dm); a
	// tram over every section people ride in (train_electric.dm).
	if (L && L["body"] && seg_index != L["cab"] && seg_index != L["cab2"] && segment_layout()["solid"])
		return FALSE
	return L && L["roof"]

// The roof pictures of this segment's three tiles, drawn over the car for
// everyone but those riding inside it (process_train_roofs). Made only when
// the art for this car and position exists.
/obj/structure/trains/platform/proc/make_roof_images()
	roof_images = null
	if (!roofed())
		return
	var/list/L = layout()
	var/list/segs = L["segments"]
	var/row = seg_index <= 1 ? "f" : (seg_index >= segs.len ? "b" : "m")
	if (L["body"])
		// The rear cab's roof faces the other way; a section between the cabs has its own.
		row = (L["cab2"] && seg_index == L["cab2"]) ? "b" : (seg_index == L["cab"] ? "" : "m")
	var/list/states = train_roof_states()
	var/list/made = list()
	for (var/i in 1 to 3)
		var/state = "roof_[L["roof"]]_[row][copytext("lcr", i, i + 1)]"
		if (!(state in states))
			return
		made += state
	roof_images = list()
	for (var/i in 1 to 3)
		var/image/R = image(icon, null, made[i], 8, dir)
		roof_images += R
	// Centre on the segment; the sides on their deck parts once placed.
	var/image/C = roof_images[2]
	C.loc = src
	train_roof_segments |= src

// Segments with roof pictures, for process_train_roofs.
var/global/list/train_roof_segments = list()

/proc/train_roof_states()
	var/static/list/states = null
	if (!states)
		states = icon_states('icons/obj/vehicles/train_platforms.dmi')
	return states

// Hangs the side roof pictures on the deck parts made for them.
/obj/structure/trains/platform/proc/hang_roof_images()
	if (!roof_images)
		return
	for (var/obj/structure/train_part/deck/D in deck_parts)
		var/image/R = roof_images[D.side + 2]
		R.loc = D

// After a car moves: anyone riding on top under a roof is knocked off,
// backwards along the track.
/proc/train_deck_clearance(list/cargo, back_dir)
	for (var/mob/living/human/H in cargo)
		if (!H.vehicle_deck || !train_deck_segment(H.vehicle_deck))
			continue
		var/obj/roof/R = locate(/obj/roof) in H.loc
		if (R)
			H.vehicle_deck_thrown(back_dir, "You hit \the [R] overhead and are knocked off!")
		else
			// A live overhead line (train_electric.dm).
			train_catenary_strike(H, back_dir)

/mob/living/human/var/tmp/list/train_roofs_shown = null

// Shows train car roofs to this person, except the car they ride inside.
/mob/living/human/proc/process_train_roofs()
	if (!client)
		train_roofs_shown = null
		return
	var/list/want = list()
	var/inside = null
	if (!vehicle_deck && isturf(loc))
		for (var/obj/O in loc)
			inside = train_roof_car_id(O)
			if (inside)
				break
	var/reach = 12
	for (var/obj/structure/trains/S in train_roof_segments)
		if (QDELETED(S) || !S.roof_images)
			train_roof_segments -= S
			continue
		if (S.z != z || S.car_id == inside || get_dist(S, src) > reach)
			continue
		want += S.roof_images
	var/list/had = train_roofs_shown || list()
	if (had.len)
		client.images -= (had - want)
	if (want.len)
		client.images |= want
	train_roofs_shown = want.len ? want : null

// Grab intent and a free hand on a vehicle from outside: climb onto its roof.
/mob/living/human/proc/grab_climb_vehicle(atom/A)
	if (a_intent != I_GRAB || get_active_hand() || vehicle_deck)
		return FALSE
	var/atom/F = null
	if (vehicle_deck_walkable(A))
		F = A
	else if (isturf(A) || istype(A, /obj/structure/vehicleparts/frame) || istype(A, /obj/structure/train_part/deck) || istype(A, /obj/structure/trains/platform))
		// A roofless frame or a car's floor: the roof on that tile, if any.
		F = vehicle_deck_at(get_turf(A))
	if (!F || get_dist(src, F) != 1 || vehicle_deck_inside(src, F))
		return FALSE
	climb_onto_vehicle(F)
	return TRUE

/obj/structure/vehicleparts/frame/verb/climb_onto_roof_verb()
	set name = "Climb Onto Roof"
	set category = null
	set src in view(1)
	if (!ishuman(usr))
		return
	var/mob/living/human/H = usr
	H.climb_onto_vehicle(src)

/obj/structure/train_part/deck/verb/climb_onto_car_roof_verb()
	set name = "Climb Onto Roof"
	set category = null
	set src in view(1)
	if (ishuman(usr))
		var/mob/living/human/H = usr
		H.climb_onto_vehicle(src)

/obj/structure/trains/platform/verb/climb_onto_car_roof_verb()
	set name = "Climb Onto Roof"
	set category = null
	set src in view(1)
	if (ishuman(usr))
		var/mob/living/human/H = usr
		H.climb_onto_vehicle(src)

/mob/living/human/verb/climb_through_hatch_verb()
	set name = "Climb Through Hatch"
	set category = "IC"
	set desc = "Climb out through the hatch or sunroof over your seat onto the vehicle's roof."
	var/obj/structure/vehicleparts/frame/F = null
	for (var/obj/structure/vehicleparts/frame/candidate in loc)
		if (vehicle_deck_hatch(candidate))
			F = candidate
			break
	if (!F)
		to_chat(src, SPAN_WARNING("There is no hatch over you."))
		return
	climb_onto_vehicle(F, TRUE)

/obj/structure/vehicleparts/frame/examine(mob/user, distance = -1)
	. = ..()
	if (!user || get_dist(user, src) > 3)
		return
	for (var/mob/living/human/H in loc)
		if (H.vehicle_deck == src)
			to_chat(user, SPAN_NOTICE("[H] is standing on top of it."))

#undef VEHICLE_DECK_CLIMB_TIME
#undef VEHICLE_DECK_DOWN_TIME
#undef VEHICLE_DECK_PIXEL_Y
#undef VEHICLE_DECK_LAYER
#undef VEHICLE_DECK_THROW_RANGE
