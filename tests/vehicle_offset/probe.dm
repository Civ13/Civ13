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

/obj/structure/vehicle_offset_probe_wall
	name = "probe wall"
	density = TRUE
	anchored = TRUE

var/vehicle_offset_probe_checks = 0
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
