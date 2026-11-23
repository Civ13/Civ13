// Full-source probe: riding on top of a vehicle (vehicle_decks.dm). Getting up
// from outside and through a hatch, walking across the roof, riding along when
// it drives and turns, sight over walls, melee only between people on top,
// shots aimed at someone on top, jumping off and falling when the roof goes.
// do_after is skipped by calling board_vehicle_deck after the same refusal.
/world
	hub = ""
	visibility = 0
	maxx = 30
	maxy = 30
	maxz = 1
	fps = 20
	turf = /turf/floor/plating/vehicle_decks_probe
	area = /area

/world/OpenPort(port)
	if (port == "none")
		return ..("none")
	return FALSE

/world/Topic()
	return null

/client/New()
	del(src)

/obj/map_metadata/vehicle_decks_probe/New()
	map = src

/turf/floor/plating/vehicle_decks_probe

/mob/living/human/vehicle_decks_probe/human_subtile_authority(client/owner)
	return TRUE

var/vehicle_decks_probe_checks = 0

/proc/vehicle_decks_probe_assert(ok, label)
	vehicle_decks_probe_checks++
	if (!ok)
		throw EXCEPTION(label)

/proc/vehicle_decks_probe_actor(tx, ty, char_name = "Rider")
	var/mob/living/human/vehicle_decks_probe/H = new(locate(tx, ty, 1))
	H.canmove = TRUE
	H.stat = CONSCIOUS
	H.lastarea = get_area(H)
	H.real_name = char_name
	H.name = char_name
	return H

// A 2 by 3 car facing north with its south-west corner at x,y.
/proc/vehicle_decks_probe_car(x, y, axis_type = /obj/structure/vehicleparts/axis/car)
	for (var/dx = 0, dx < 2, dx++)
		for (var/dy = 0, dy < 3, dy++)
			new /obj/structure/vehicleparts/frame(locate(x + dx, y + dy, 1))
	var/obj/structure/engine/internal/E = new /obj/structure/engine/internal/gasoline/premade/v6(locate(x, y + 1, 1))
	E.anchored = FALSE
	new /obj/item/weapon/reagent_containers/glass/barrel/fueltank/smalltank/fueledgasoline(locate(x + 1, y + 1, 1))
	var/obj/structure/bed/chair/drivers/D = new(locate(x + 1, y, 1))
	D.anchored = FALSE
	for (var/turf/T in list(locate(x, y, 1), locate(x + 1, y, 1), locate(x, y + 2, 1), locate(x + 1, y + 2, 1)))
		new /obj/structure/vehicleparts/movement(T)
	var/obj/structure/vehicleparts/axis/A = new axis_type(locate(x, y, 1))
	var/why = A.assemble(NORTH)
	vehicle_decks_probe_assert(isnull(why), "car_assembled ([why])")
	return A

/proc/vehicle_decks_probe_frame(obj/structure/vehicleparts/axis/A, turf/T)
	for (var/obj/structure/vehicleparts/frame/F in T)
		if (F.axis == A)
			return F
	return null

/proc/vehicle_decks_probe_run()
	config = new
	config.webhook_can_fire = FALSE
	makeDatumRefLists()
	GLOB.all_observable_events = list()
	GLOB.moved_event = new
	GLOB.dir_set_event = new
	GLOB.destroyed_event = new
	GLOB.stat_set_event = new
	GLOB.name_set_event = new
	movementMachine = new
	map = new /obj/map_metadata/vehicle_decks_probe
	vehicle_decks_probe_assert(world.byond_version == 516 && world.byond_build == 1688, "pinned_native_engine")

	var/obj/structure/vehicleparts/axis/A = vehicle_decks_probe_car(10, 10)
	var/obj/structure/vehicleparts/frame/side = vehicle_decks_probe_frame(A, locate(10, 11, 1))
	vehicle_decks_probe_assert(side && vehicle_deck_walkable(side), "roofed_frame_walkable")

	// Up from outside: next to the car, not inside it.
	var/mob/living/human/vehicle_decks_probe/ann = vehicle_decks_probe_actor(9, 11, "Ann")
	var/mob/living/human/vehicle_decks_probe/bob = vehicle_decks_probe_actor(10, 12, "Bob")
	var/mob/living/human/vehicle_decks_probe/far = vehicle_decks_probe_actor(5, 20, "Far")
	vehicle_decks_probe_assert(isnull(ann.vehicle_deck_refusal(side)), "adjacent_climb_allowed")
	vehicle_decks_probe_assert(findtext(bob.vehicle_deck_refusal(side), "inside it"), "inside_needs_a_hatch")
	vehicle_decks_probe_assert(findtext(far.vehicle_deck_refusal(side), "next to"), "must_be_adjacent")
	vehicle_decks_probe_assert(los_eye_level(ann) == LOS_EYE_STANDING, "ground_eye")
	vehicle_decks_probe_assert(ann.board_vehicle_deck(side), "boarded")
	vehicle_decks_probe_assert(ann.loc == side.loc && ann.vehicle_deck == side && los_on_vehicle_deck(ann) && vehicle_deck_axis(ann) == A, "on_top")
	vehicle_decks_probe_assert(ann.layer > 11 && ann.rest_pixel_y() > 0, "drawn_above_roof")
	vehicle_decks_probe_assert(los_eye_level(ann) == LOS_EYE_DECK && los_target_top(ann) > 3, "eye_over_walls")
	var/list/field = los_terrain_for(ann, 7)
	vehicle_decks_probe_assert(islist(field) && field.len == 3, "deck_field")
	var/datum/los_terrain_field/LF = field[1]
	vehicle_decks_probe_assert(LF.eye == LOS_EYE_DECK, "deck_field_eye")
	vehicle_decks_probe_assert(findtext(ann.vehicle_deck_refusal(side), "already"), "one_deck_at_a_time")

	// Walk across the roof: the next frame north is still the car.
	vehicle_decks_probe_assert(ann.vehicle_deck_step(NORTH) && ann.loc == locate(10, 12, 1) && vehicle_deck_axis(ann) == A, "walk_across_roof")
	vehicle_decks_probe_assert(ann.vehicle_deck_step(EAST) && ann.loc == locate(11, 12, 1) && vehicle_deck_axis(ann) == A, "walk_over_inner_walls")

	// Melee: nobody inside or on the ground reaches the roof; riders on the
	// same roof reach each other.
	vehicle_decks_probe_assert(tree_melee_blocked(bob, ann) && tree_melee_blocked(ann, bob), "no_melee_roof_to_inside")
	var/mob/living/human/vehicle_decks_probe/cat = vehicle_decks_probe_actor(12, 12, "Cat")
	vehicle_decks_probe_assert(tree_melee_blocked(cat, ann), "no_melee_ground_to_roof")
	vehicle_decks_probe_assert(cat.board_vehicle_deck(vehicle_decks_probe_frame(A, locate(11, 11, 1))), "second_rider")
	vehicle_decks_probe_assert(!tree_melee_blocked(cat, ann) && !tree_melee_blocked(ann, cat), "same_roof_melee")
	cat.leave_vehicle_deck(locate(12, 11, 1), "climb")
	vehicle_decks_probe_assert(!cat.vehicle_deck && cat.loc == locate(12, 11, 1) && cat.pixel_y == 0, "climbed_down_beside")

	// Shots: one aimed at the rider meets her before the car's walls.
	var/obj/item/projectile/P = new(locate(13, 12, 1))
	P.original = ann
	var/list/order = P.projectile_tile_order(ann.loc)
	vehicle_decks_probe_assert(order.len && order[1] == ann, "aimed_shot_reaches_rider_first")
	P.original = bob
	order = P.projectile_tile_order(ann.loc)
	vehicle_decks_probe_assert(order[1] != ann, "stray_shots_keep_tile_order")
	qdel(P)

	// The roof rides with the car when it drives and turns.
	var/turf/before = get_turf(ann)
	vehicle_decks_probe_assert(A.do_move() && get_turf(ann) == get_step(before, NORTH), "rides_along")
	ann.vehicle_deck_check()
	vehicle_decks_probe_assert(los_on_vehicle_deck(ann) && vehicle_deck_axis(ann) == A, "still_on_top_after_driving")
	turn_swing_last = null
	vehicle_decks_probe_assert(A.do_matrix(A.dir, TURN_LEFT(A.dir), "left"), "turns")
	// The turn is drawn as the car swinging round its pivot on an arc, its
	// frames turning as they go and the rider carried round upright.
	var/list/swing = turn_swing_last
	vehicle_decks_probe_assert(swing && swing[3] == 90 && swing[4] > swing[5] && swing[5] > 0, "turn_drawn_as_one_swing ([swing ? "[swing[3]] degrees, [swing[4]] swung, [swing[5]] turning" : "none"])")
	var/matrix/upright = ann.transform
	vehicle_decks_probe_assert(upright.a == 1 && upright.e == 1 && !upright.b && !upright.d, "rider_swings_round_upright")
	sleep(20)
	ann.vehicle_deck_check()
	vehicle_decks_probe_assert(A.dir == WEST && los_on_vehicle_deck(ann) && vehicle_deck_axis(ann) == A, "still_on_top_after_turning")

	// Jumping off the edge lands at once on the ground beside the car.
	var/obj/structure/vehicleparts/frame/now = ann.vehicle_deck
	var/turf/edge = null
	for (var/d in list(NORTH, SOUTH, EAST, WEST))
		var/turf/T = get_step(now.loc, d)
		if (T && !vehicle_deck_at(T))
			edge = T
			ann.dir = d
			break
	vehicle_decks_probe_assert(edge, "found_an_edge")
	var/brute = ann.getBruteLoss()
	vehicle_decks_probe_assert(ann.vehicle_deck_step(ann.dir) && ann.loc == edge && !ann.vehicle_deck && ann.pixel_y == 0 && ann.layer < 11, "jumped_off_edge")
	vehicle_decks_probe_assert(ann.getBruteLoss() > brute, "jump_hurts")
	vehicle_decks_probe_assert(los_eye_level(ann) != LOS_EYE_DECK, "eye_back_down")

	// Through a hatch: a seat under a sunroof lets the rider up from inside.
	var/obj/structure/vehicleparts/axis/B = vehicle_decks_probe_car(20, 10)
	var/obj/structure/vehicleparts/frame/seat_frame = vehicle_decks_probe_frame(B, locate(21, 10, 1))
	var/mob/living/human/vehicle_decks_probe/dan = vehicle_decks_probe_actor(21, 10, "Dan")
	vehicle_decks_probe_assert(findtext(dan.vehicle_deck_refusal(seat_frame, TRUE), "no hatch"), "no_hatch_in_a_plain_car")
	seat_frame.sunroof = TRUE
	vehicle_decks_probe_assert(vehicle_deck_hatch(seat_frame) && isnull(dan.vehicle_deck_refusal(seat_frame, TRUE)), "sunroof_is_a_hatch")
	vehicle_decks_probe_assert(dan.board_vehicle_deck(seat_frame) && dan.loc == seat_frame.loc && los_on_vehicle_deck(dan), "up_through_sunroof")
	dan.leave_vehicle_deck(null)
	vehicle_decks_probe_assert(!dan.vehicle_deck && dan.loc == seat_frame.loc, "back_down_through_sunroof")

	// The roof going away drops the rider; so does a stun.
	vehicle_decks_probe_assert(dan.board_vehicle_deck(seat_frame), "up_again")
	brute = dan.getBruteLoss()
	qdel(seat_frame)
	dan.vehicle_deck_check()
	vehicle_decks_probe_assert(!dan.vehicle_deck && dan.getBruteLoss() > brute && dan.pixel_y == 0, "fell_when_roof_gone")
	var/obj/structure/vehicleparts/frame/back = vehicle_decks_probe_frame(B, locate(20, 12, 1))
	var/mob/living/human/vehicle_decks_probe/eve = vehicle_decks_probe_actor(19, 12, "Eve")
	vehicle_decks_probe_assert(eve.board_vehicle_deck(back), "eve_up")
	eve.weakened = 3
	eve.vehicle_deck_check()
	vehicle_decks_probe_assert(!eve.vehicle_deck && !vehicle_deck_at(get_turf(eve)), "stun_falls_beside")

	// The double-decker bus: built from the works layout, every frame an
	// upper deck, stairs inside lead up and back down without leaving it.
	var/obj/structure/car_workshop/W = new(locate(2, 20, 1))
	vehicle_decks_probe_assert(W.model_size("Double-decker bus") == 5 && W.largest_model_size() == 4, "bus_oversize_bay")
	var/obj/effects/premadevehicles/bus/doubledecker/plan = new(null, TRUE)
	var/obj/structure/vehicleparts/axis/bus = W.assemble_layout(plan, 5)
	qdel(plan)
	vehicle_decks_probe_assert(istype(bus, /obj/structure/vehicleparts/axis/car/bus), "bus_assembled")
	var/decks = 0
	var/obj/structure/vehicle_stairs/stairs = null
	for (var/obj/structure/vehicleparts/frame/F in bus.components)
		if (F.upper_deck && vehicle_deck_walkable(F))
			decks++
		if (!stairs)
			stairs = locate(/obj/structure/vehicle_stairs) in F.loc
	vehicle_decks_probe_assert(decks == 10 && stairs, "bus_upper_deck_and_stairs")
	var/obj/structure/vehicleparts/frame/stair_frame = vehicle_decks_probe_frame(bus, stairs.loc)
	vehicle_decks_probe_assert(vehicle_deck_hatch(stair_frame), "stairs_lead_up")
	var/mob/living/human/vehicle_decks_probe/fay = vehicle_decks_probe_actor(stairs.x, stairs.y, "Fay")
	vehicle_decks_probe_assert(isnull(fay.vehicle_deck_refusal(stair_frame, TRUE)), "upstairs_allowed")
	vehicle_decks_probe_assert(fay.board_vehicle_deck(stair_frame) && los_on_vehicle_deck(fay) && vehicle_deck_axis(fay) == bus, "upstairs")
	fay.leave_vehicle_deck(null)
	vehicle_decks_probe_assert(!fay.vehicle_deck && fay.loc == stairs.loc, "downstairs_inside")
	var/mob/living/human/vehicle_decks_probe/gus = vehicle_decks_probe_actor(stairs.x, stairs.y - 1, "Gus")
	vehicle_decks_probe_assert(findtext(gus.vehicle_deck_refusal(vehicle_decks_probe_frame(bus, gus.loc), TRUE), "no hatch"), "only_the_stairs_lead_up")

	// Crashes, hard turns and low roofs throw riders off the top.
	var/obj/structure/vehicleparts/axis/C = vehicle_decks_probe_car(24, 20)
	var/mob/living/human/vehicle_decks_probe/hal = vehicle_decks_probe_actor(23, 21, "Hal")
	vehicle_decks_probe_assert(hal.board_vehicle_deck(vehicle_decks_probe_frame(C, locate(24, 21, 1))) && C.deck_riders().len == 1, "hal_up")
	C.deck_jolt(100, NORTH, "Crash!")
	vehicle_decks_probe_assert(!hal.vehicle_deck && hal.loc == locate(24, 23, 1), "crash_throws_ahead_past_the_edge")
	vehicle_decks_probe_assert(hal.board_vehicle_deck(vehicle_decks_probe_frame(C, locate(24, 22, 1))), "hal_up_again")
	C.currentspeed = 2
	vehicle_decks_probe_assert(C.do_matrix(C.dir, TURN_LEFT(C.dir), "left") && hal.vehicle_deck, "slow_turn_keeps_rider")
	sleep(20)
	C.currentspeed = 5
	vehicle_decks_probe_assert(C.do_matrix(C.dir, TURN_LEFT(C.dir), "left") && !hal.vehicle_deck && !vehicle_deck_at(get_turf(hal)), "hard_turn_flings_rider")
	sleep(20)
	C.currentspeed = 0
	var/obj/structure/vehicleparts/frame/lead = null
	for (var/obj/structure/vehicleparts/frame/F in C.components)
		var/turf/ahead = get_step(F.loc, C.dir)
		if (ahead && !vehicle_deck_at(ahead))
			lead = F
			break
	var/mob/living/human/vehicle_decks_probe/ivy = vehicle_decks_probe_actor(hal.x, hal.y, "Ivy")
	vehicle_decks_probe_assert(lead && ivy.board_vehicle_deck(lead), "ivy_up_front")
	new /obj/roof(get_step(lead.loc, C.dir))
	vehicle_decks_probe_assert(C.do_move() && !ivy.vehicle_deck && !(locate(/obj/roof) in get_turf(ivy)), "low_roof_sweeps_rider_off")

	// Train roofs: two coaches facing east, coupled; ride on top, walk from
	// car to car, ride along, jump off. Flatbeds have no roof.
	var/obj/structure/train_car_kit/coach/K1 = new(locate(14, 4, 1))
	var/obj/structure/trains/platform/car1 = K1.assemble(EAST)
	var/obj/structure/train_car_kit/coach/K2 = new(locate(10, 4, 1))
	var/obj/structure/trains/platform/car2 = K2.assemble(EAST)
	var/obj/structure/trains/platform/tail1 = car1
	while (tail1.connected)
		tail1 = tail1.connected
	tail1.connected = car2
	vehicle_decks_probe_assert(car1.roofed() && car2.roofed() && car1.car_id != car2.car_id, "coaches_have_roofs")
	var/obj/structure/train_car_kit/flat_kit = new(locate(25, 4, 1))
	var/obj/structure/trains/platform/flat = flat_kit.assemble(EAST)
	vehicle_decks_probe_assert(!flat.roofed() && !vehicle_deck_at(flat.loc), "flatbed_has_no_roof")
	var/atom/side_deck = vehicle_deck_at(locate(12, 5, 1))
	vehicle_decks_probe_assert(istype(side_deck, /obj/structure/train_part/deck) && istype(vehicle_deck_at(locate(12, 4, 1)), /obj/structure/trains/platform), "car_tiles_are_deck_surfaces")
	vehicle_decks_probe_assert(car1.roof_images && car1.roof_images.len == 3, "coach_has_roof_pictures")
	var/image/roof_left = car1.roof_images[1]
	var/image/roof_mid = car1.roof_images[2]
	vehicle_decks_probe_assert(roof_mid.loc == car1 && istype(roof_left.loc, /obj/structure/train_part/deck) && roof_mid.icon_state == "roof_coach_fc" && roof_mid.dir == EAST, "roof_pictures_ride_the_car")
	vehicle_decks_probe_assert(isnull(flat.roof_images), "flatbed_has_no_roof_picture")
	var/mob/living/human/vehicle_decks_probe/jo = vehicle_decks_probe_actor(12, 6, "Jo")
	var/mob/living/human/vehicle_decks_probe/kim = vehicle_decks_probe_actor(13, 4, "Kim")
	vehicle_decks_probe_assert(isnull(jo.vehicle_deck_refusal(side_deck)), "climb_onto_coach_from_beside")
	vehicle_decks_probe_assert(findtext(kim.vehicle_deck_refusal(vehicle_deck_at(locate(13, 5, 1))), "inside it"), "inside_the_coach_cannot_climb")
	vehicle_decks_probe_assert(jo.board_vehicle_deck(side_deck) && los_eye_level(jo) == LOS_EYE_DECK, "on_the_coach_roof")
	vehicle_decks_probe_assert(jo.vehicle_deck_step(SOUTH) && istype(jo.vehicle_deck, /obj/structure/trains/platform) && jo.loc == locate(12, 4, 1), "walk_onto_the_centre")
	vehicle_decks_probe_assert(jo.vehicle_deck_step(WEST) && jo.vehicle_deck_step(WEST) && vehicle_deck_group(jo) == car2.car_id, "walk_car_to_car")
	vehicle_decks_probe_assert(tree_melee_blocked(kim, jo), "no_melee_inside_to_roof")
	var/mob/living/human/vehicle_decks_probe/lee = vehicle_decks_probe_actor(11, 6, "Lee")
	vehicle_decks_probe_assert(lee.board_vehicle_deck(vehicle_deck_at(locate(11, 5, 1))) && !tree_melee_blocked(lee, jo), "melee_across_the_coupling")
	lee.leave_vehicle_deck(locate(11, 6, 1))
	var/turf/jo_was = get_turf(jo)
	vehicle_decks_probe_assert(car1.Move(get_step(car1.loc, EAST), EAST) && get_turf(jo) == get_step(jo_was, EAST), "rides_along_the_track")
	jo.vehicle_deck_check()
	vehicle_decks_probe_assert(los_on_vehicle_deck(jo) && vehicle_deck_group(jo) == car2.car_id, "still_on_the_roof_after_moving")
	new /obj/roof(get_turf(jo))
	train_deck_clearance(list(jo), WEST)
	vehicle_decks_probe_assert(!jo.vehicle_deck && !vehicle_deck_at(get_turf(jo)), "low_roof_sweeps_train_rider")
	var/mob/living/human/vehicle_decks_probe/max = vehicle_decks_probe_actor(14, 6, "Max")
	vehicle_decks_probe_assert(max.board_vehicle_deck(vehicle_deck_at(locate(14, 5, 1))) && max.vehicle_deck_step(NORTH) && !max.vehicle_deck && max.loc == locate(14, 6, 1), "jump_off_the_coach")

/world/New()
	OpenPort("none")
	var/error = null
	try
		vehicle_decks_probe_run()
	catch (var/exception/probe_error)
		error = "[probe_error.name] ([probe_error.file]:[probe_error.line])"
	text2file(error ? "FAIL [error]" : "PASS", "result.txt")
	text2file(json_encode(list("checks" = vehicle_decks_probe_checks, "error" = error, "byond_build" = byond_build)), "receipt.json")
	del(world)
