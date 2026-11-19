// Full-source probe: vehicle offsets (code/modules/craft/vehicle_offset.dm).
// A crate, a bicycle with a rider, a frame car and a carriage are moved by
// pixels: the pixel position advances by the speed on every pulse, across
// tile crossings, in all four ways; walls stop the body flush with the tile;
// everything carried keeps the same offset; snap() drops the offset without
// moving anyone off their tile. It also times the pixel writes of a pulse,
// which are the only new cost between tile steps (receipt.json).
/world
	hub = ""
	visibility = 0
	maxx = 40
	maxy = 40
	maxz = 1
	fps = 25
	turf = /turf/floor/plating/vehicle_offset_probe
	area = /area

/world/OpenPort(port)
	if (port == "none")
		return ..("none")
	return FALSE

/world/Topic()
	return null

/client/New()
	del(src)

/obj/map_metadata/vehicle_offset_probe/New()
	map = src

/turf/floor/plating/vehicle_offset_probe

/obj/structure/vehicle_offset_probe_crate
	name = "probe crate"
	density = TRUE

/mob/living/human/vehicle_offset_probe_rider/ssd_check()
	return FALSE

// Seats H as V's driver with the controls in hand, as getting on does.
/proc/vehicle_offset_probe_seat(obj/structure/vehicle/V, mob/living/human/H)
	H.forceMove(V.loc)
	if (V.dwheel)
		H.put_in_active_hand(V.dwheel)
	V.buckle_mob(H)
	V.driver = H
	H.driver = TRUE
	H.driver_vehicle = V
	V.ontop |= H

/obj/structure/vehicle_offset_probe_deck
	name = "probe deck"
	density = FALSE

/obj/structure/vehicle_offset_probe_wall
	name = "probe wall"
	density = TRUE
	anchored = TRUE

var/vehicle_offset_probe_checks = 0
// Nobody has a client here; the probe says when a player is near.
var/vehicle_offset_probe_watched = FALSE

/datum/vehicle_offset/watched()
	return vehicle_offset_probe_watched

/datum/vehicle_offset/axis/watched()
	return vehicle_offset_probe_watched
var/list/vehicle_offset_probe_receipt = list()

/proc/vehicle_offset_probe_assert(ok, label)
	vehicle_offset_probe_checks++
	if (!ok)
		throw EXCEPTION(label)

// Absolute pixel position of A's lower-left corner.
/proc/vehicle_offset_probe_px(atom/movable/A)
	return list(A.x * 32 + A.step_x, A.y * 32 + A.step_y)

// TRUE when A is filed under the tile beneath its centre (offsets -16 to 15).
/proc/vehicle_offset_probe_centred(atom/movable/A)
	return A.step_x >= -16 && A.step_x < 16 && A.step_y >= -16 && A.step_y < 16

// A 2 by 3 car facing north with its south-west corner at x,y (as tests/vehicle_decks).
/proc/vehicle_offset_probe_car(x, y)
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
	var/obj/structure/vehicleparts/axis/A = new /obj/structure/vehicleparts/axis/car(locate(x, y, 1))
	var/why = A.assemble(NORTH)
	vehicle_offset_probe_assert(isnull(why), "car_assembled ([why])")
	return A

// A 2 by 3 ship of frames facing north with a wheel and one rigged mast, its south-west corner at x,y.
/proc/vehicle_offset_probe_ship(x, y)
	for (var/dx = 0, dx < 2, dx++)
		for (var/dy = 0, dy < 3, dy++)
			new /obj/structure/vehicleparts/frame/ship(locate(x + dx, y + dy, 1))
	var/obj/structure/vehicleparts/shipwheel/W = new(locate(x + 1, y, 1))
	W.anchored = TRUE
	new /obj/structure/vehicleparts/movement/sail/premade(locate(x, y + 1, 1))
	var/obj/structure/vehicleparts/axis/ship/A = new(locate(x, y, 1))
	var/why = A.assemble(NORTH)
	vehicle_offset_probe_assert(isnull(why), "ship_assembled ([why])")
	return A

// Pulses O n times and checks that every pulse moves the body by exactly the speed.
/proc/vehicle_offset_probe_drive(datum/vehicle_offset/O, atom/movable/body, n, label)
	for (var/i = 1 to n)
		var/list/before = vehicle_offset_probe_px(body)
		O.pulse()
		var/list/after = vehicle_offset_probe_px(body)
		vehicle_offset_probe_assert(after[1] - before[1] == O.speed_x && after[2] - before[2] == O.speed_y, "[label]_pulse_[i]_moves_by_speed")
		vehicle_offset_probe_assert(vehicle_offset_probe_centred(body), "[label]_pulse_[i]_centre_filed")

// Pixel writes per second the pulse costs for n carried things, in ms per pulse.
/proc/vehicle_offset_probe_time(datum/vehicle_offset/O, pulses)
	var/started = world.timeofday
	for (var/i = 1 to pulses)
		O.ox = (i % 2) ? 3 : -3
		O.draw()
	var/elapsed = max(world.timeofday - started, 0)
	O.snap()
	return elapsed * 100 / pulses

/proc/vehicle_offset_probe_run()
	config = new
	config.webhook_can_fire = FALSE
	makeDatumRefLists()
	GLOB.all_observable_events = list()
	GLOB.moved_event = new
	GLOB.dir_set_event = new
	GLOB.destroyed_event = new
	GLOB.stat_set_event = new
	GLOB.name_set_event = new
	GLOB.global_listen_count = list()
	GLOB.event_sources_count = list()
	GLOB.event_listen_count = list()
	movementMachine = new
	map = new /obj/map_metadata/vehicle_offset_probe
	vehicle_offset_probe_assert(world.byond_version == 516 && world.byond_build == 1688, "pinned_native_engine")

	// Speed: pixels per tick from deciseconds per tile.
	vehicle_offset_probe_assert(vehicle_offset_speed(1.6) == 32 * world.tick_lag / 1.6, "speed_from_ladder")
	vehicle_offset_probe_assert(vehicle_offset_speed(0) == 0, "no_speed_without_interval")

	// A crate rolls east by 4 px a pulse across two tiles.
	var/obj/structure/vehicle_offset_probe_crate/crate = new(locate(5, 5, 1))
	var/datum/vehicle_offset/O = new(crate)
	vehicle_offset_probe_assert(O in vehicle_offsets, "registered")
	O.carry(crate, TRUE)
	O.speed_x = 4
	vehicle_offset_probe_drive(O, crate, 16, "east")
	vehicle_offset_probe_assert(crate.loc == locate(7, 5, 1) && crate.step_x == 0 && O.crossings == 2, "east_two_tiles")
	O.speed_x = 5
	vehicle_offset_probe_drive(O, crate, 3, "east_odd")
	vehicle_offset_probe_assert(crate.loc == locate(7, 5, 1) && crate.step_x == 15, "east_odd_offset_stays_on_tile")
	O.pulse()
	vehicle_offset_probe_assert(crate.loc == locate(8, 5, 1) && crate.step_x == -12, "east_crossing_wraps")

	// Direct writes keep a negative offset on the same tile.
	O.speed_x = 0
	O.ox = -5
	O.draw()
	vehicle_offset_probe_assert(crate.loc == locate(8, 5, 1) && crate.step_x == -5, "negative_offset_kept")

	// West, then north and south, back across crossings.
	O.speed_x = -7
	vehicle_offset_probe_drive(O, crate, 9, "west")
	O.speed_x = 0
	O.speed_y = 6
	vehicle_offset_probe_drive(O, crate, 11, "north")
	O.speed_y = -3
	vehicle_offset_probe_drive(O, crate, 9, "south")

	// Fractions of a pixel are carried, not lost.
	O.snap()
	var/list/start = vehicle_offset_probe_px(crate)
	O.speed_x = 2.5
	for (var/i = 1 to 4)
		O.pulse()
	vehicle_offset_probe_assert(vehicle_offset_probe_px(crate)[1] - start[1] == 10, "fractions_carried")

	// A wall stops the body flush with its tile; the speed on that axis drops.
	O.snap()
	new /obj/structure/vehicle_offset_probe_wall(get_step(get_step(crate.loc, EAST), EAST))
	O.speed_x = 6
	for (var/i = 1 to 12)
		O.pulse()
	vehicle_offset_probe_assert(crate.step_x == 0 && O.speed_x == 0 && O.blocked_dir == EAST, "wall_stops_flush")
	vehicle_offset_probe_assert((locate(/obj/structure/vehicle_offset_probe_wall) in get_step(crate.loc, EAST)), "stopped_beside_wall")
	O.speed_x = 3
	O.pulse()
	vehicle_offset_probe_assert(crate.step_x == 0 && O.speed_x == 0, "wall_still_blocks")
	O.speed_x = -3
	O.pulse()
	vehicle_offset_probe_assert(crate.step_x == -3, "backs_away_from_wall")

	// Snapping drops the offset, never the tile.
	var/turf/at = crate.loc
	O.snap()
	vehicle_offset_probe_assert(crate.loc == at && !crate.step_x && !crate.step_y && !O.speed_x, "snap_keeps_tile")
	O.ox = 9
	O.oy = -9
	O.draw()
	vehicle_offset_snap_all()
	vehicle_offset_probe_assert(crate.loc == at && !crate.step_x && !crate.step_y, "snap_all_before_save")
	qdel(O)
	vehicle_offset_probe_assert(!(O in vehicle_offsets), "unregistered")

	// A motorcycle with its rider: both keep the same offset; the bike's own step crosses tiles.
	var/obj/structure/vehicle/motorcycle/bike = new(locate(20, 5, 1))
	var/mob/living/human/rider = new(locate(20, 5, 1))
	bike.ontop += rider
	var/datum/vehicle_offset/single/BO = new(bike)
	BO.carry(bike, TRUE)
	BO.carry(rider)
	BO.speed_y = 8
	vehicle_offset_probe_drive(BO, bike, 8, "bike_north")
	vehicle_offset_probe_assert(bike.loc == locate(20, 7, 1) && rider.loc == bike.loc && rider.step_y == bike.step_y && rider.step_x == bike.step_x, "rider_stays_seated")
	BO.speed_y = 0
	BO.speed_x = -8
	vehicle_offset_probe_drive(BO, bike, 4, "bike_west")
	vehicle_offset_probe_assert(bike.loc == locate(19, 7, 1) && rider.loc == bike.loc && rider.step_x == bike.step_x, "rider_follows_west")
	BO.drop(rider)
	vehicle_offset_probe_assert(!(rider in BO.carried), "rider_dropped")
	BO.snap()

	// A frame car: every frame, part and passenger keeps one offset across tile steps.
	var/obj/structure/vehicleparts/axis/A = vehicle_offset_probe_car(10, 15)
	var/mob/living/human/passenger = new(locate(10, 15, 1))
	A.add_transporting(FALSE)
	var/datum/vehicle_offset/axis/CO = new(A)
	for (var/atom/movable/M in (A.transporting | A.components))
		CO.carry(M, istype(M, /obj/structure/vehicleparts/frame))
	vehicle_offset_probe_assert((passenger in CO.carried) && CO.footprint.len == 6, "car_carries_everything")
	vehicle_offset_probe_assert(!passenger.carried_by_vehicle(), "parked_car_passenger_walks")
	A.moving = TRUE
	vehicle_offset_probe_assert(passenger.carried_by_vehicle(), "moving_car_passenger_carried")
	A.moving = FALSE
	vehicle_offset_probe_assert(CO.tiles_ahead(NORTH).len == 2 && CO.tiles_ahead(EAST).len == 3, "car_leading_edge")
	var/list/car_start = list()
	for (var/atom/movable/M in CO.carried)
		car_start[M] = vehicle_offset_probe_px(M)
	CO.speed_y = 8
	vehicle_offset_probe_drive(CO, A, 12, "car_north")
	vehicle_offset_probe_assert(CO.crossings == 3, "car_three_tile_steps")
	var/together = TRUE
	for (var/atom/movable/M in CO.carried)
		var/list/was = car_start[M]
		var/list/now = vehicle_offset_probe_px(M)
		if (now[1] != was[1] || now[2] - was[2] != 96)
			together = FALSE
	vehicle_offset_probe_assert(together, "car_moves_as_one")
	CO.speed_y = 0
	CO.speed_x = 8
	CO.pulse()
	vehicle_offset_probe_assert(A.step_x == 8 && CO.crossings == 3, "car_sideways_within_tile")
	CO.pulse()
	vehicle_offset_probe_assert(A.step_x == 15 && CO.blocked_dir == EAST && !CO.speed_x, "car_cannot_step_sideways")
	CO.snap()
	vehicle_offset_probe_receipt["car_carried"] = CO.carried.len
	vehicle_offset_probe_receipt["car_ms_per_pulse"] = vehicle_offset_probe_time(CO, 20000)

	// Pixel driving (vehicle_offset_ride.dm): a motorcycle and its rider roll by pixels.
	var/obj/structure/vehicle/motorcycle/m125/full/moto = new(locate(5, 30, 1))
	var/mob/living/human/biker = new(locate(5, 30, 1))
	moto.engine.on = TRUE
	moto.driver = biker
	moto.ontop += biker
	biker.driver = TRUE
	biker.driver_vehicle = moto
	biker.dir = EAST
	moto.axis.currentspeed = 1
	moto.vehicle_m_delay = 3
	moto.moving = TRUE
	vehicle_offset_probe_assert(biker.carried_by_vehicle(), "driver_makes_no_footsteps")
	var/mob/living/human/walker = new(locate(6, 31, 1))
	vehicle_offset_probe_assert(!walker.carried_by_vehicle(), "walker_keeps_footsteps")
	qdel(walker)
	vehicle_offset_probe_assert(!moto.vehicle_offset_drives(), "nobody_near_tile_steps")
	vehicle_offset_probe_watched = TRUE
	vehicle_offset_probe_assert(moto.vehicle_offset_drives(), "player_near_rolls_by_pixels")
	var/list/moto_start = vehicle_offset_probe_px(moto)
	for (var/i = 1 to 20)
		vehicle_offset_probe_assert(moto.vehicle_offset_tick() == world.tick_lag, "moto_tick_[i]_every_tick")
		vehicle_offset_probe_assert(biker.loc == moto.loc && biker.step_x == moto.step_x && biker.step_y == moto.step_y, "moto_tick_[i]_rider_seated")
	var/rolled = vehicle_offset_probe_px(moto)[1] - moto_start[1]
	vehicle_offset_probe_assert(abs(rolled - 20 * vehicle_offset_speed(4)) <= 1 && moto.x >= 6, "moto_rolls_its_speed ([rolled])")
	vehicle_offset_probe_receipt["moto_px_in_20_ticks"] = rolled
	// Turning keeps the sideways offset: it stands where it is, like a player.
	var/side = moto.step_x
	biker.dir = NORTH
	for (var/i = 1 to 3)
		moto.vehicle_offset_tick()
	vehicle_offset_probe_assert(moto.step_x == side && moto.step_y > 0, "turn_keeps_sideways_offset")
	// Out of gear it rolls on, slowing, and stops within about half a tile.
	moto.moving = FALSE
	moto.axis.currentspeed = 0
	var/coast_from = vehicle_offset_probe_px(moto)[2]
	var/coast_ticks = 0
	while (moto.offset_coast > 0 && coast_ticks < 100)
		moto.vehicle_offset_tick()
		coast_ticks++
	var/coasted = vehicle_offset_probe_px(moto)[2] - coast_from
	vehicle_offset_probe_assert(coasted > 0 && coasted <= 20 && coast_ticks < 100, "coasts_to_a_stop ([coasted])")
	vehicle_offset_probe_assert(moto.vehicle_offset_tick() == moto.vehicle_m_delay + 1, "stopped_waits_like_the_tile_loop")
	vehicle_offset_probe_receipt["moto_coast_px"] = coasted
	// Driving into a wall: the motorcycle's own crash check, then it stops flush.
	var/wall_y = moto.y + 2
	new /obj/structure/vehicle_offset_probe_wall(locate(moto.x, wall_y, 1))
	moto.moving = TRUE
	moto.axis.currentspeed = 1
	for (var/i = 1 to 60)
		moto.vehicle_offset_tick()
	vehicle_offset_probe_assert(moto.y == wall_y - 1 && moto.step_y == 0 && moto.axis.currentspeed == 0 && !moto.offset_coast, "moto_stops_flush_at_wall ([moto.x],[moto.y],[moto.step_x],[moto.step_y],[moto.axis.currentspeed],[moto.offset_coast],[moto.driver])")
	// Nobody near: square on the tile again and back to tile steps.
	vehicle_offset_probe_watched = FALSE
	vehicle_offset_probe_assert(!moto.vehicle_offset_drives(), "unwatched_back_to_tiles")
	moto.vehicle_offset_release()
	vehicle_offset_probe_assert(!moto.step_x && !moto.step_y && moto.offset_mover.carried.len == 1, "release_squares_and_drops_riders")
	vehicle_offset_probe_watched = TRUE
	moto.offset_mover.ox = 7
	moto.offset_mover.draw()
	vehicle_offset_snap_all()
	vehicle_offset_probe_assert(!moto.step_x && !moto.offset_mover.speed_x, "save_snaps_ridden_vehicles")

	// A bicycle pedals by pixels on its own loop; each tile still pays stamina.
	var/obj/structure/vehicle/bicycle/cycle = new(locate(5, 36, 1))
	var/mob/living/human/vehicle_offset_probe_rider/cyclist = new(locate(5, 36, 1))
	vehicle_offset_probe_seat(cycle, cyclist)
	cyclist.dir = EAST
	vehicle_offset_probe_assert(cycle.rider_ready() && cycle.vehicle_offset_drives(), "bike_rolls_by_pixels_when_near")
	var/stamina_before = cyclist.getStat("stamina")
	cycle.moving = TRUE
	cycle.movement_processes = 1
	var/list/cycle_start = vehicle_offset_probe_px(cycle)
	var/cycle_offset_seen = FALSE
	for (var/i = 1 to 20)
		cycle.movementloop()
		if (cycle.pedal_timer)
			deltimer(cycle.pedal_timer)
			cycle.pedal_timer = null
		if (cycle.step_x)
			cycle_offset_seen = TRUE
		vehicle_offset_probe_assert(cyclist.loc == cycle.loc && cyclist.step_x == cycle.step_x, "bike_tick_[i]_rider_seated")
	var/pedalled = vehicle_offset_probe_px(cycle)[1] - cycle_start[1]
	vehicle_offset_probe_assert(cycle.moving && cycle_offset_seen && cycle.x > 5 && pedalled > 32, "bike_pedals_by_pixels ([pedalled],[cycle.x],[cycle.step_x],[cycle.moving])")
	vehicle_offset_probe_assert(cyclist.getStat("stamina") < stamina_before, "bike_pays_stamina_per_tile")
	vehicle_offset_probe_receipt["bike_px_in_20_ticks"] = pedalled
	cycle.stopmovementloop()
	vehicle_offset_probe_assert(!cycle.moving && cycle.offset_mover, "bike_brakes")

	// A raft paddles by pixels while the key is held, then drifts to a stop.
	for (var/rx = 2 to 20)
		for (var/ry = 37 to 39)
			new /turf/floor/beach/water(locate(rx, ry, 1))
	var/obj/structure/vehicle/raft/R = new(locate(3, 38, 1))
	var/mob/living/human/vehicle_offset_probe_rider/rafter = new(locate(3, 38, 1))
	vehicle_offset_probe_seat(R, rafter)
	rafter.dir = EAST
	rafter.movement_eastwest = EAST
	var/list/raft_start = vehicle_offset_probe_px(R)
	R.processmove(EAST)
	vehicle_offset_probe_assert(R.offset_paddling, "raft_starts_paddling")
	for (var/i = 1 to 30)
		R.vehicle_offset_paddle()
	var/paddled = vehicle_offset_probe_px(R)[1] - raft_start[1]
	vehicle_offset_probe_assert(abs(paddled - 31 * vehicle_offset_speed(R.vehicle_m_delay)) <= 1 && rafter.loc == R.loc && rafter.step_x == R.step_x, "raft_paddles_its_speed ([paddled])")
	rafter.movement_eastwest = null
	var/drift_from = vehicle_offset_probe_px(R)[1]
	var/drift_ticks = 0
	while (R.offset_paddling && drift_ticks < 100)
		R.vehicle_offset_paddle()
		drift_ticks++
	var/drifted = vehicle_offset_probe_px(R)[1] - drift_from
	vehicle_offset_probe_assert(drifted > 0 && drifted <= 16 && !R.offset_coast, "raft_drifts_to_a_stop ([drifted])")
	// Off the water's edge: the raft's own check stops it flush.
	rafter.movement_eastwest = EAST
	R.processmove(EAST)
	for (var/i = 1 to 1500)
		if (!R.offset_paddling)
			break
		R.vehicle_offset_paddle()
	vehicle_offset_probe_assert(R.x == 20 && R.step_x == 0 && !R.offset_paddling, "raft_stops_at_the_shore ([R.x],[R.step_x])")
	vehicle_offset_probe_watched = FALSE
	rafter.dir = WEST
	R.dir = WEST
	var/raft_x = R.x
	R.lastmove = -100
	R.processmove(WEST)
	vehicle_offset_probe_assert(!R.offset_paddling && R.x == raft_x - 1 && !R.step_x, "unwatched_raft_paddles_by_tiles ([R.x],[R.step_x])")
	vehicle_offset_probe_watched = TRUE

	// A carriage with a horse in harness rolls by pixels the way it faces.
	var/obj/structure/vehicle/carriage/coach = new(locate(33, 3, 1))
	coach.facing = NORTH
	coach.apply_shape()
	var/mob/living/simple_animal/horse/nag = new(locate(33, 3, 1))
	coach.hitch(nag)
	var/mob/living/human/vehicle_offset_probe_rider/coachman = new(locate(33, 3, 1))
	vehicle_offset_probe_assert(coach.take_reins(coachman) && coach.driver_ready() && coach.team_pull() > 0, "coach_ready")
	vehicle_offset_probe_assert(coach.vehicle_offset_drives() && coach.vehicle_offset_heading() == NORTH, "coach_rolls_the_way_it_faces")
	var/obj/structure/closet/crate/cart/trailer = new(coach.hitch_turf(coach.facing))
	vehicle_offset_probe_assert(trailer.hitch_to(coach), "coach_cart_hitched")
	coach.gear = 1
	coach.moving = TRUE
	coach.movement_processes = 1
	var/coach_from = vehicle_offset_probe_px(coach)[2]
	for (var/i = 1 to 40)
		coach.movementloop()
		if (coach.step_timer)
			deltimer(coach.step_timer)
			coach.step_timer = null
		vehicle_offset_probe_assert(coachman.loc == coach.loc && nag.loc == coach.loc && coachman.step_y == coach.step_y && nag.step_y == coach.step_y && trailer.step_y == coach.step_y && trailer.loc == coach.hitch_turf(coach.facing), "coach_tick_[i]_rig_together")
	var/coach_rolled = vehicle_offset_probe_px(coach)[2] - coach_from
	vehicle_offset_probe_assert(coach.moving && coach.y > 3 && coach_rolled > 32 && !coach.step_x, "coach_rolls_by_pixels ([coach_rolled],[coach.y],[coach.step_y])")
	vehicle_offset_probe_receipt["coach_px_in_40_ticks"] = coach_rolled
	// A wall across the team's lane stops it before the horse overlaps it.
	var/coach_wall = coach.y + 6
	new /obj/structure/vehicle_offset_probe_wall(locate(33, coach_wall, 1))
	new /obj/structure/vehicle_offset_probe_wall(locate(34, coach_wall, 1))
	for (var/i = 1 to 200)
		if (!coach.moving)
			break
		coach.movementloop()
		if (coach.step_timer)
			deltimer(coach.step_timer)
			coach.step_timer = null
	var/list/coach_cells = coach.cells_at(coach.loc, coach.facing)
	var/turf/wall_cell = locate(33, coach_wall, 1)
	var/turf/last_cell = locate(33, coach_wall - 1, 1)
	vehicle_offset_probe_assert(!coach.moving && coach.step_y == 0 && !(wall_cell in coach_cells) && (last_cell in coach_cells), "coach_stops_flush_before_a_wall ([coach.y],[coach.step_y],[coach.moving])")
	// Turning squares it on its tile first.
	coach.offset_mover.oy = 9
	coach.offset_mover.draw()
	coach.dir = EAST
	coach.updatepassdir()
	vehicle_offset_probe_assert(!coach.step_y && !coachman.step_y, "coach_turn_squares_first")

	// A carriage: one object with 64x96 bounds covers six tiles.
	var/obj/structure/vehicle/carriage/C = new(locate(25, 20, 1))
	var/datum/vehicle_offset/CA = new(C)
	CA.carry(C, TRUE)
	var/list/covered = vehicle_offset_tiles(C)
	vehicle_offset_probe_assert(covered.len == (C.bound_width / 32) * (C.bound_height / 32), "carriage_covers_its_bounds")
	vehicle_offset_probe_assert(CA.tiles_ahead(EAST).len == C.bound_height / 32, "carriage_leading_edge")
	CA.speed_x = 6
	vehicle_offset_probe_drive(CA, C, 8, "carriage_east")
	vehicle_offset_probe_assert(C.loc == locate(27, 20, 1) && C.step_x == -16, "carriage_crossed")
	CA.snap()
	vehicle_offset_probe_receipt["crate_ms_per_pulse"] = vehicle_offset_probe_time(CA, 20000)

	// Walking on a moving deck (settle()): a three-tile deck carries a person,
	// who keeps where they walk, stays filed on the deck and steps off its end.
	var/datum/vehicle_offset/W = new(null)
	for (var/dx = 0 to 2)
		W.carry(new /obj/structure/vehicle_offset_probe_deck(locate(30 + dx, 10, 1)), TRUE)
	var/mob/living/human/vehicle_offset_probe_rider/deckhand = new(locate(31, 10, 1))
	deckhand.human_subtile_enabled = TRUE
	W.carry(deckhand)
	vehicle_offset_probe_assert(vehicle_offset_riders[deckhand] == W, "deckhand_registered")
	W.speed_x = 4
	W.pulse()
	W.pulse()
	vehicle_offset_probe_assert(deckhand.step_x == 8 && deckhand.human_subtile_offset_owned, "deckhand_carried_owns_offset")
	// They walk 5 px east by themselves: the next pulse keeps that walk.
	var/list/walk_from = vehicle_offset_probe_px(deckhand)
	deckhand.step_x += 5
	W.pulse()
	vehicle_offset_probe_assert(vehicle_offset_probe_px(deckhand)[1] - walk_from[1] == 9 && (deckhand in W.carried), "walk_kept_on_moving_deck")
	var/list/own = W.carried[deckhand]
	vehicle_offset_probe_assert(own[1] == 5 && deckhand.loc == locate(31, 10, 1), "walk_is_own_offset")
	// Seated cargo that did not move is not touched by settle().
	vehicle_offset_probe_assert(W.carried.len == 4, "deck_carried")
	// At the bow, past the deck's own front edge as drawn but over its last
	// tile: filed on that deck tile, never on the open tile ahead.
	W.speed_x = 0
	W.ox = 12
	W.draw()
	deckhand.loc = locate(32, 10, 1)
	deckhand.step_x = 12 + 10
	W.pulse()
	vehicle_offset_probe_assert(deckhand.loc == locate(32, 10, 1) && (deckhand in W.carried), "bow_filed_on_deck")
	vehicle_offset_probe_assert(deckhand.step_x == 22 && deckhand.human_subtile_shape(), "bow_offset_kept_and_walkable")
	// A rider at the deck's largest negative offset still has a walkable shape.
	W.ox = -16
	W.carried[deckhand] = list(-16, 0, 0, 0)
	W.draw()
	vehicle_offset_probe_assert(deckhand.step_x == -32 && deckhand.human_subtile_shape(), "deck_rider_negative_shape")
	W.ox = 12
	W.carried[deckhand] = list(10, 0, 0, 0)
	W.draw()
	// Walking off the bow: their centre leaves every deck tile, so they step off.
	deckhand.step_x += 20
	W.pulse()
	vehicle_offset_probe_assert(!(deckhand in W.carried) && !vehicle_offset_riders[deckhand], "walked_off_dropped")
	vehicle_offset_probe_assert(deckhand.loc == locate(33, 10, 1) && deckhand.step_x == 10 && deckhand.step_x >= -16 && deckhand.step_x < 16, "walked_off_refiled_by_centre ([deckhand.x],[deckhand.step_x])")
	vehicle_offset_probe_assert(!deckhand.human_subtile_shape() || deckhand.step_x >= -16, "off_deck_shape_as_land")
	qdel(W)
	vehicle_offset_probe_assert(!vehicle_offset_riders.len || !(locate(/obj/structure/vehicle_offset_probe_deck) in vehicle_offset_riders), "riders_cleared_on_destroy")

	// Phase 2 (vehicle_offset_frame.dm): a frame car in gear rolls by pixels,
	// everything aboard on one offset, coasts square out of gear, squares
	// before a turn and stops flush and square before a wall.
	vehicle_offset_probe_watched = TRUE
	var/obj/structure/vehicleparts/axis/A2 = vehicle_offset_probe_car(36, 4)
	var/mob/living/human/vehicle_offset_probe_rider/rider2 = new(locate(36, 5, 1))
	A2.engine.on = TRUE
	vehicle_offset_probe_assert(A2.check_engine(), "frame_car_engine_runs ([A2.get_weight()] of [A2.maxpower])")
	var/list/car2_frames = list()
	for (var/obj/structure/vehicleparts/frame/F in A2.components)
		car2_frames += F
	var/obj/structure/vehicleparts/frame/front2 = car2_frames[1]
	for (var/obj/structure/vehicleparts/frame/F in car2_frames)
		if (F.y > front2.y)
			front2 = F
	A2.currentspeed = 1
	A2.vehicle_m_delay = 3
	A2.moving = TRUE
	vehicle_offset_probe_assert(A2.vehicle_offset_drives() && A2.vehicle_offset_heading() == NORTH, "frame_car_rolls_the_way_it_faces")
	vehicle_offset_probe_watched = FALSE
	A2.offset_mover.watch_checked = -1000
	vehicle_offset_probe_assert(!A2.vehicle_offset_drives(), "frame_car_unwatched_tile_steps")
	vehicle_offset_probe_watched = TRUE
	var/car2_from = vehicle_offset_probe_px(front2)[2]
	var/rider2_from = vehicle_offset_probe_px(rider2)[2]
	// The pace is the tile loop's: one tile per vehicle_m_delay + 1, which the load sets after each tile.
	var/car2_expected = 0
	for (var/i = 1 to 40)
		car2_expected += vehicle_offset_speed(A2.vehicle_m_delay + 1)
		vehicle_offset_probe_assert(A2.vehicle_offset_tick() == world.tick_lag, "frame_car_tick_[i]_every_tick")
		var/same = TRUE
		for (var/obj/structure/vehicleparts/frame/F in car2_frames)
			if (F.step_y != front2.step_y || F.step_x)
				same = FALSE
		vehicle_offset_probe_assert(same && rider2.step_y == front2.step_y && (rider2 in A2.offset_mover.carried) && A2.step_y == front2.step_y, "frame_car_tick_[i]_together")
		vehicle_offset_probe_assert(vehicle_offset_probe_centred(front2), "frame_car_tick_[i]_filed")
	var/car2_rolled = vehicle_offset_probe_px(front2)[2] - car2_from
	vehicle_offset_probe_assert(abs(car2_rolled - car2_expected) <= 1.5 && vehicle_offset_probe_px(rider2)[2] - rider2_from == car2_rolled, "frame_car_rolls_by_pixels ([car2_rolled] of [car2_expected])")
	vehicle_offset_probe_assert(A2.offset_mover.crossings >= 2 && A2.moving, "frame_car_tile_steps_under_the_offset ([A2.offset_mover.crossings])")
	vehicle_offset_probe_assert(rider2.carried_by_vehicle(), "frame_car_rider_makes_no_footsteps")
	vehicle_offset_probe_receipt["frame_car_px_in_40_ticks"] = car2_rolled
	// Out of gear it coasts on and stops square on its tiles.
	A2.moving = FALSE
	A2.currentspeed = 0
	var/car2_coast_from = vehicle_offset_probe_px(front2)[2]
	var/car2_coast_ticks = 0
	vehicle_offset_probe_assert(A2.offset_coast > 0, "frame_car_coasts")
	for (var/i = 1 to 300)
		car2_coast_ticks++
		if (!A2.vehicle_offset_tick())
			break
		vehicle_offset_probe_assert(rider2.carried_by_vehicle(), "frame_car_coast_[i]_no_footsteps")
	var/car2_coasted = vehicle_offset_probe_px(front2)[2] - car2_coast_from
	vehicle_offset_probe_assert(!A2.offset_coast && !front2.step_y && !rider2.step_y && !A2.offset_mover.carried.len && car2_coasted > 0 && car2_coasted <= 32, "frame_car_coasts_square ([car2_coasted] px in [car2_coast_ticks] ticks)")
	vehicle_offset_probe_assert(rider2.loc == locate(36, front2.y - 1, 1) && !rider2.carried_by_vehicle(), "frame_car_parked_rider_walks")
	vehicle_offset_probe_receipt["frame_car_coast_px"] = car2_coasted
	// A turn squares it first.
	A2.currentspeed = 1
	A2.moving = TRUE
	for (var/i = 1 to 3)
		A2.vehicle_offset_tick()
	vehicle_offset_probe_assert(front2.step_y > 0, "frame_car_mid_tile")
	A2.check_corners()
	A2.check_matrix()
	A2.do_matrix(A2.dir, TURN_RIGHT(A2.dir), "right")
	var/squared = TRUE
	for (var/obj/structure/vehicleparts/frame/F in car2_frames)
		if (F.step_x || F.step_y)
			squared = FALSE
	vehicle_offset_probe_assert(squared && !rider2.step_x && !rider2.step_y && A2.offset_coast > 0, "frame_car_turn_squares_first ([A2.dir])")
	if (A2.dir != NORTH)
		A2.check_corners()
		A2.check_matrix()
		A2.do_matrix(A2.dir, TURN_LEFT(A2.dir), "left")
	vehicle_offset_probe_assert(A2.dir == NORTH, "frame_car_turns_back_north")
	// A wall ahead stops it flush and square, and out of gear.
	front2 = car2_frames[1]
	for (var/obj/structure/vehicleparts/frame/F in car2_frames)
		if (F.y > front2.y)
			front2 = F
	var/car2_wall = front2.y + 3
	for (var/obj/structure/vehicleparts/frame/F in car2_frames)
		if (F.y == front2.y)
			new /obj/structure/vehicle_offset_probe_wall(locate(F.x, car2_wall, 1))
	A2.currentspeed = 1
	A2.moving = TRUE
	for (var/i = 1 to 300)
		if (!A2.vehicle_offset_tick())
			break
	vehicle_offset_probe_assert(!A2.moving && !A2.currentspeed && !A2.offset_coast && !front2.step_y && front2.y == car2_wall - 1, "frame_car_stops_flush_before_a_wall ([front2.y],[front2.step_y],[car2_wall])")
	vehicle_offset_probe_assert(!A2.offset_mover.carried.len && !rider2.step_y, "frame_car_crash_lets_go")

	// Frame ships (vehicle_offset_ship.dm): a workshop ship under sail sails by
	// pixels through her own movement loop, a turn ordered between squares waits
	// for the next square (no jump back), and the shore stops her flush and square.
	for (var/x = 4 to 18)
		for (var/y = 12 to 26)
			var/turf/WT = locate(x, y, 1)
			for (var/atom/movable/AM in WT)
				qdel(AM)
			WT.ChangeTurf(/turf/floor/beach/water/deep)
	map.windspeedvar = 3
	var/obj/structure/vehicleparts/axis/ship/S = vehicle_offset_probe_ship(6, 13)
	var/mob/living/human/vehicle_offset_probe_rider/sailor = new(locate(7, 14, 1))
	var/list/ship_frames = list()
	for (var/obj/structure/vehicleparts/frame/F in S.components)
		ship_frames += F
	var/obj/structure/vehicleparts/frame/bow = ship_frames[1]
	for (var/obj/structure/vehicleparts/frame/F in ship_frames)
		if (F.y > bow.y)
			bow = F
	vehicle_offset_probe_assert(S.offset_drive && S.masts.len == 1, "ship_sails_by_pixels ([S.masts.len] masts)")
	S.anchor = FALSE
	for (var/obj/structure/vehicleparts/movement/sail/M in S.masts)
		M.sails_on = TRUE
	S.moving = TRUE
	S.currentspeed = 0
	var/ship_from = vehicle_offset_probe_px(bow)[2]
	var/sailor_from = vehicle_offset_probe_px(sailor)[2]
	var/ship_expected = 0
	for (var/i = 1 to 60)
		S.movement_processes = 0
		vehicle_offset_probe_assert(S.movementloop() && S.movement_processes == 1, "ship_loop_[i]_by_pixels")
		ship_expected += vehicle_offset_speed(S.vehicle_m_delay + 1)
		var/same = TRUE
		for (var/obj/structure/vehicleparts/frame/F in ship_frames)
			if (F.step_y != bow.step_y || F.step_x)
				same = FALSE
		vehicle_offset_probe_assert(same && S.moving && S.currentspeed == 1 && sailor.step_y == bow.step_y && (sailor in S.offset_mover.carried), "ship_loop_[i]_together")
	var/ship_sailed = vehicle_offset_probe_px(bow)[2] - ship_from
	vehicle_offset_probe_assert(ship_sailed > 32 && abs(ship_sailed - ship_expected) <= 1.5 && vehicle_offset_probe_px(sailor)[2] - sailor_from == ship_sailed, "ship_sails_her_pace ([ship_sailed] of [ship_expected], delay [S.vehicle_m_delay])")
	vehicle_offset_probe_assert(S.offset_mover.crossings >= 1, "ship_tile_steps_under_the_offset ([S.offset_mover.crossings])")
	vehicle_offset_probe_receipt["ship_px_in_60_ticks"] = ship_sailed
	// A turn ordered mid-tile is held: she sails on to the square, never back.
	for (var/i = 1 to 200)
		if (bow.step_y > 2)
			break
		S.movement_processes = 0
		S.movementloop()
	vehicle_offset_probe_assert(bow.step_y > 2, "ship_mid_tile ([bow.step_y])")
	S.check_corners()
	S.check_matrix()
	vehicle_offset_probe_assert(S.do_matrix(S.dir, TURN_RIGHT(S.dir), "right") && S.dir == NORTH && S.offset_turn == "right", "ship_turn_held")
	var/last_py = vehicle_offset_probe_px(bow)[2]
	var/turned_after = 0
	for (var/i = 1 to 200)
		S.movement_processes = 0
		S.movementloop()
		if (S.dir != NORTH)
			turned_after = i
			break
		var/py = vehicle_offset_probe_px(bow)[2]
		vehicle_offset_probe_assert(py >= last_py, "ship_held_turn_[i]_never_backs")
		last_py = py
	var/turned_square = TRUE
	for (var/obj/structure/vehicleparts/frame/F in ship_frames)
		if (F.step_x || F.step_y)
			turned_square = FALSE
	vehicle_offset_probe_assert(turned_after && S.dir == EAST && !S.offset_turn && S.moving, "ship_comes_about_at_the_square ([turned_after] ticks)")
	vehicle_offset_probe_assert(turned_square || S.offset_mover.ox > 0, "ship_turn_had_no_jump")
	// Sand ahead: she stops flush and square, the crew let go.
	var/obj/structure/vehicleparts/frame/east_bow = ship_frames[1]
	for (var/obj/structure/vehicleparts/frame/F in ship_frames)
		if (F.x > east_bow.x)
			east_bow = F
	var/shore = east_bow.x + 3
	for (var/y = 12 to 26)
		var/turf/ST = locate(shore, y, 1)
		ST.ChangeTurf(/turf/floor/beach/sand)
	for (var/i = 1 to 600)
		S.movement_processes = 0
		S.movementloop()
		if (!S.moving && !S.offset_coast && (!S.offset_mover || !S.offset_mover.carried.len))
			break
	vehicle_offset_probe_assert(!S.moving && !east_bow.step_x && east_bow.x == shore - 1 && !sailor.step_x, "ship_stops_flush_at_the_shore ([east_bow.x],[east_bow.step_x],[shore])")
	S.movement_processes = 0

	// A hull-sized load: 1000 things on one offset, for the ship and train budget.
	var/datum/vehicle_offset/H = new(null)
	for (var/i = 0 to 999)
		H.carry(new /obj/structure/vehicle_offset_probe_crate(locate(1 + (i % 40), 30 + round(i / 400), 1)))
	vehicle_offset_probe_assert(H.carried.len == 1000, "hull_load")
	vehicle_offset_probe_receipt["hull_1000_ms_per_pulse"] = vehicle_offset_probe_time(H, 2000)

/world/New()
	OpenPort("none")
	var/error = null
	try
		vehicle_offset_probe_run()
	catch (var/exception/probe_error)
		error = "[probe_error.name] ([probe_error.file]:[probe_error.line])"
	vehicle_offset_probe_receipt["checks"] = vehicle_offset_probe_checks
	vehicle_offset_probe_receipt["error"] = error
	vehicle_offset_probe_receipt["byond_build"] = byond_build
	text2file(error ? "FAIL [error]" : "PASS", "result.txt")
	text2file(json_encode(vehicle_offset_probe_receipt), "receipt.json")
	del(world)
