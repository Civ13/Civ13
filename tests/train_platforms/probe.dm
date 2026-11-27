// Train platform fixture: real train_platforms.dm, trains.dm and track laying
// procs on a small map. A locomotive pulls platform cars along straight track
// and round a curve; decks, walls and cargo must stay with each segment.
/world
	hub = ""
	hub_password = ""
	maxx = 452
	maxy = 26
	maxz = 1
	turf = /turf/floor/dirt
	area = /area/caribbean
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/world/Topic(T, addr, master, key)
	return "Closed train platform fixture"

/mob/living/human/platform_rider/New()
	return
/mob/living/human/platform_rider/update_icons()
	return
// A rider made without a species cannot take burns; the fixture counts them.
/mob/living/human/platform_rider/var/probe_burn = 0
/mob/living/human/platform_rider/adjustBurnLoss(var/amount)
	probe_burn += amount
/mob/living/human/platform_rider/Weaken(amount)
	return

var/global/list/platform_probe_checks = list()
var/global/list/platform_probe_failed = list()
var/global/platform_probe_runtime_error = FALSE

/world/Error(exception/E)
	platform_probe_runtime_error = TRUE
	world.log << "Unexpected fixture runtime: [E] at [E.file]:[E.line]"
	return ..()

/proc/platform_check(label, passed)
	platform_probe_checks += list(list("label" = label, "passed" = !!passed))
	if (!passed)
		platform_probe_failed += label

/proc/platform_turf(x, y)
	return locate(x, y, 1)

/proc/platform_track(x, y, facing)
	var/obj/structure/rail_bed/B = track_place_bed(platform_turf(x, y), facing)
	B.place_rails()
	return B.spike()

/proc/platform_car(kind, x, y, heading)
	var/obj/structure/train_car_kit/K = new(platform_turf(x, y))
	K.set_kind(kind)
	var/problem = K.assembly_problem(heading)
	if (problem)
		world.log << "assembly problem: [problem]"
		return null
	return K.assemble(heading)

/proc/platform_segments(obj/structure/trains/platform/front)
	var/list/segs = list()
	var/obj/structure/trains/car = front
	while (istype(car, /obj/structure/trains/platform) && segs.len < 8)
		segs += car
		car = car.connected
	return segs

// Every deck part sits on its segment's tile for the segment's heading.
/proc/platform_parts_placed(list/segs)
	for (var/obj/structure/trains/platform/P in segs)
		if (!P.deck_parts || P.deck_parts.len < 2)
			return FALSE
		var/list/tiles = train_platform_tiles(P.loc, P.dir)
		for (var/obj/structure/train_part/part in P.deck_parts)
			if (part.loc != tiles[part.side + 2] || part.dir != part.facing(P.dir))
				return FALSE
	return TRUE

/proc/platform_car_tiles(list/segs)
	var/list/tiles = list()
	for (var/obj/structure/trains/platform/P in segs)
		tiles += train_platform_tiles(P.loc, P.dir)
	return tiles

/proc/platform_last(list/segs)
	if (segs.len < TRAIN_CAR_LENGTH)
		return null
	var/obj/structure/trains/platform/P = segs[TRAIN_CAR_LENGTH]
	return P.loc

/proc/platform_step(obj/structure/trains/locomotive/L, count)
	for (var/i in 1 to count)
		L.automovement = TRUE
		if (!L.process_rail_movement())
			return i - 1
	return count

/proc/platform_probe_run()
	// Track: north along x = 10, then east along y = 20.
	for (var/y in 2 to 20)
		platform_track(10, y, NORTH)
	for (var/x in 11 to 26)
		platform_track(x, 20, EAST)
	platform_check("track/corner", locate(/obj/structure/rails/turn) in platform_turf(10, 20))

	// Assembly needs straight track and room for the deck.
	var/obj/structure/train_car_kit/bad = new(platform_turf(10, 19))
	platform_check("assembly/needs_straight_track", bad.assembly_problem(EAST))
	qdel(bad)
	var/obj/structure/trains/platform/front = platform_car("flatbed", 10, 10, NORTH)
	var/list/segs = platform_segments(front)
	platform_check("assembly/four_segments", segs.len == TRAIN_CAR_LENGTH && !(locate(/obj/structure/train_car_kit) in platform_turf(10, 10)))
	platform_check("assembly/segments_on_track", front && front.loc == platform_turf(10, 10) && platform_last(segs) == platform_turf(10, 7))
	platform_check("assembly/decks_placed", platform_parts_placed(segs))
	platform_check("assembly/walkable", front && !front.density)
	var/obj/structure/train_part/sample = front.deck_parts[1]
	platform_check("parts/not_saved", !sample.should_save)
	var/obj/structure/train_car_kit/blocked = new(platform_turf(10, 12))
	platform_check("assembly/refuses_overlap", blocked.assembly_problem(NORTH))
	qdel(blocked)

	// Hitch: only the front of a car couples.
	var/obj/structure/trains/locomotive/coal/L = new(platform_turf(10, 11))
	L.dir = NORTH
	L.fuel = 100
	L.on = TRUE
	L.connected = front

	// Load the deck: a crate on the left of section 2, a rider on the right of section 3.
	var/obj/structure/closet/crate/crate = new(platform_turf(9, 9))
	var/mob/living/human/platform_rider/rider = new(platform_turf(11, 8))
	var/obj/structure/wild/bush/bush = new(platform_turf(11, 12))

	platform_check("move/straight_steps", platform_step(L, 2) == 2)
	platform_check("move/segments_follow", front.loc == platform_turf(10, 12) && platform_last(segs) == platform_turf(10, 9))
	platform_check("move/crate_rides", crate.loc == platform_turf(9, 11))
	platform_check("move/rider_rides", rider.loc == platform_turf(11, 10))
	platform_check("move/decks_follow", platform_parts_placed(segs))

	// Glide (train_glide.dm): a driven step is drawn at the train's pace for
	// the engine, the cars, their decks and everything aboard, and the train
	// gives every glide back once it stops.
	var/crate_glide = crate.glide_size
	var/engine_glide = L.glide_size
	var/obj/structure/train_part/deck_part = front.deck_parts[1]
	var/pace = craft_glide_size(4)
	train_glide_begin(L, 4)
	var/glided = platform_step(L, 1) == 1
	platform_check("glide/step_paced", glided && L.glide_size == pace && front.glide_size == pace && crate.glide_size == pace && deck_part.glide_size == pace && (!craft_glides_natively(rider) || rider.glide_size == pace))
	train_glide_end(L)
	platform_check("glide/held_between_steps", L.glide_size == pace && crate.glide_size == pace && !train_glide_record)
	train_glide_rest(L)
	platform_check("glide/given_back", L.glide_size == engine_glide && crate.glide_size == crate_glide && !L.train_glide_was.len)

	// Round the corner and on to the end of the line.
	var/steps = platform_step(L, 40)
	platform_check("curve/reaches_end", L.loc == platform_turf(26, 20) && steps < 40)
	platform_check("curve/segments_on_track", front.loc == platform_turf(25, 20) && platform_last(segs) == platform_turf(22, 20))
	var/all_east = TRUE
	for (var/obj/structure/trains/platform/P in segs)
		if (P.dir != EAST)
			all_east = FALSE
	platform_check("curve/segments_face_east", all_east)
	platform_check("move/flora_left_behind", bush.loc == platform_turf(11, 12))
	platform_check("curve/decks_follow", platform_parts_placed(segs))
	var/list/car_tiles = platform_car_tiles(segs)
	platform_check("curve/crate_aboard", crate.loc in car_tiles)
	platform_check("curve/rider_aboard", rider.loc in car_tiles)

	// Taking the car apart needs it uncoupled and empty.
	platform_check("dismantle/coupled", findtext(front.dismantle_problem(), "Uncouple"))
	L.connected = null
	platform_check("dismantle/cargo", findtext(front.dismantle_problem(), "Clear everything"))
	qdel(crate)
	qdel(rider)
	platform_check("dismantle/ready", !front.dismantle_problem())
	var/obj/structure/train_car_kit/K = front.pack_car()
	platform_check("dismantle/kit", istype(K) && K.car_kind == "flatbed" && !K.furnished && K.loc == platform_turf(25, 20))
	var/leftovers = 0
	for (var/obj/structure/train_part/part in world)
		if (!QDELETED(part) && part.loc)
			leftovers++
	for (var/obj/structure/trains/platform/P in world)
		if (!QDELETED(P) && P.loc)
			leftovers++
	platform_check("dismantle/no_leftovers", !leftovers)

	// A coach on a second line: seats, doors and walls.
	for (var/y in 2 to 20)
		platform_track(32, y, NORTH)
	var/obj/structure/trains/platform/coach = platform_car("coach", 32, 10, NORTH)
	var/list/coach_segs = platform_segments(coach)
	var/chairs = 0
	for (var/turf/T in platform_car_tiles(coach_segs))
		for (var/obj/structure/bed/chair/C in T)
			chairs++
	platform_check("coach/seats", chairs == 6)
	var/obj/structure/train_part/edge/door = null
	for (var/obj/structure/train_part/edge/E in coach.deck_parts)
		if (E.style == "door" && E.side == TRAIN_LEFT && E.edge_kind == "out")
			door = E
	platform_check("coach/side_door", door && door.density && door.loc == platform_turf(31, 10))
	var/obj/item/weapon/hammer/probe_item = new(platform_turf(30, 9))
	var/turf/window_deck = platform_turf(31, 9)
	platform_check("coach/window_blocks", !window_deck.Enter(probe_item))
	probe_item.loc = platform_turf(30, 10)
	var/turf/door_deck = platform_turf(31, 10)
	platform_check("coach/closed_door_blocks", !door_deck.Enter(probe_item))
	door.set_open(TRUE)
	coach.open_doors |= 1 << (door.edge_index - 1)
	platform_check("coach/open_door_passes", door_deck.Enter(probe_item))
	coach.apply_layout()
	var/reopened = FALSE
	for (var/obj/structure/train_part/edge/E in coach.deck_parts)
		if (E.edge_index == door.edge_index && E.open && !E.density)
			reopened = TRUE
	platform_check("coach/door_state_rebuilt", reopened)

	// A wall beside the line stops the train before the deck scrapes it.
	var/obj/structure/trains/locomotive/coal/L2 = new(platform_turf(32, 11))
	L2.dir = NORTH
	L2.fuel = 100
	L2.on = TRUE
	L2.connected = coach
	var/turf/wall = platform_turf(33, 11)
	wall.density = TRUE
	platform_check("clearance/stops", platform_step(L2, 1) == 0 && L2.loc == platform_turf(32, 11) && !L2.automovement)
	platform_check("clearance/car_unmoved", coach.loc == platform_turf(32, 10) && platform_parts_placed(coach_segs))
	wall.density = FALSE
	platform_check("clearance/clear_again", platform_step(L2, 1) == 1 && coach.loc == platform_turf(32, 11))

	// Interior segments refuse to be unhitched.
	var/obj/structure/trains/platform/middle = coach_segs[2]
	platform_check("hitch/middle_kept", middle.connected == coach_segs[3])

	// Every kind builds.
	var/kinds_ok = TRUE
	var/x = 2
	for (var/kind in list("sleeper", "dining", "storage", "flak"))
		for (var/y in 2 to 6)
			platform_track(x + 1, y, NORTH)
		if (!platform_car(kind, x + 1, 6, NORTH))
			kinds_ok = FALSE
		x += 3
	platform_check("kinds/all_assemble", kinds_ok)


/proc/platform_warfare_run()
	// Railway gun car on its own line at x = 20, heading north.
	for (var/y in 2 to 12)
		platform_track(20, y, NORTH)
	var/obj/structure/trains/platform/gun_front = platform_car("railgun", 20, 10, NORTH)
	var/list/gun_segs = platform_segments(gun_front)
	var/obj/structure/cannon/modern/railway/G = locate() in platform_turf(20, 9)
	var/obj/structure/railway_gun_brace/B = locate() in platform_turf(19, 10)
	platform_check("railgun/fitted", G && B && gun_segs.len == TRAIN_CAR_LENGTH)
	platform_check("railgun/needs_brace", G && findtext(G.fire_problem(), "Brace"))
	for (var/obj/structure/trains/platform/P in gun_segs)
		P.last_moved = world.time
	platform_check("railgun/no_brace_while_moving", B && B.set_braced(TRUE))
	for (var/obj/structure/trains/platform/P in gun_segs)
		P.last_moved = -1000
	platform_check("railgun/braces", B && !B.set_braced(TRUE) && gun_front.braced && G && !G.fire_problem())
	platform_check("railgun/outriggers_down", gun_front.overlays.len == 3)
	var/obj/structure/trains/locomotive/coal/L = new(platform_turf(20, 11))
	L.dir = NORTH
	L.fuel = 100
	L.on = TRUE
	L.connected = gun_front
	platform_check("railgun/braced_blocks_train", platform_step(L, 1) == 0 && L.loc == platform_turf(20, 11))
	B.set_braced(FALSE)
	platform_check("railgun/outriggers_up", gun_front.overlays.len == 1)
	platform_check("railgun/unbraced_moves", platform_step(L, 1) == 1 && gun_front.loc == platform_turf(20, 11) && (G.loc == platform_turf(20, 10)))

	// Explosions wreck a car, which stops the train until welded.
	var/obj/structure/trains/platform/P2 = gun_segs[2]
	P2.ex_act(1)
	platform_check("damage/armored_reduced", P2.health == 1500 - 180 && !P2.wrecked)
	for (var/i in 1 to 9)
		P2.ex_act(1)
	platform_check("damage/wrecked", P2.wrecked && !QDELETED(P2) && P2.deck_parts && P2.deck_parts.len)
	platform_check("damage/wreck_blocks_train", platform_step(L, 1) == 0)
	P2.repair_by(1500)
	platform_check("damage/welded", !P2.wrecked && P2.health == 1500)

	// Armor plate stops bullets from outside but lets the crew fire out.
	for (var/y in 2 to 8)
		platform_track(26, y, NORTH)
	var/obj/structure/trains/platform/arm = platform_car("armored", 26, 8, NORTH)
	var/obj/structure/train_part/edge/plate = null
	for (var/obj/structure/train_part/edge/E in arm.deck_parts)
		if (E.style == "armor_door" && E.side == TRAIN_LEFT)
			plate = E
	var/obj/item/projectile/bullet = new(platform_turf(25, 8))
	bullet.starting = platform_turf(22, 8)
	platform_check("armor/stops_incoming", plate && !plate.CanPass(bullet, platform_turf(25, 8)))
	bullet.starting = platform_turf(25, 8)
	platform_check("armor/crew_fires_out", plate && plate.CanPass(bullet, platform_turf(24, 8)) && plate.CheckExit(bullet, platform_turf(24, 8)))
	var/guns = 0
	for (var/turf/T in platform_car_tiles(platform_segments(arm)))
		for (var/obj/item/weapon/gun/projectile/automatic/stationary/S in T)
			guns++
	platform_check("armor/no_free_guns", guns == 0)
	qdel(bullet)

	// The armored locomotive survives a direct hit.
	var/obj/structure/trains/locomotive/coal/armored/AL = new(platform_turf(30, 24))
	AL.ex_act(1)
	platform_check("armored_loco/survives", !QDELETED(AL) && AL.health == 2700 && !AL.disabled)

// Drive-through rail warehouse: cars come off the back of the train in the
// bay with their cargo and are coupled back on behind it.
/proc/platform_warehouse_run()
	for (var/y in 2 to 24)
		platform_track(44, y, NORTH)
	var/obj/structure/rail_warehouse/W = new(platform_turf(42, 13))
	W.dir = EAST
	var/list/bay = W.bay()
	platform_check("warehouse/bay", bay.len == 13 && bay[1] == platform_turf(44, 7) && bay[bay.len] == platform_turf(44, 19))
	var/obj/structure/trains/transport/flatbed/first = new(platform_turf(44, 12))
	var/obj/structure/trains/transport/flatbed/second = new(platform_turf(44, 13))
	first.dir = NORTH
	second.dir = NORTH
	var/list/options = W.put_away_options(W.rear_units())
	platform_check("warehouse/same_name_choices", first.name == second.name && options.len == 2 && options[options[1]][1] == first && options[options[2]][1] == second)
	platform_check("warehouse/choice_names_track_tile", findtext(options[1], "track 44, 12") && findtext(options[2], "track 44, 13"))
	qdel(first)
	qdel(second)
	var/obj/structure/trains/locomotive/coal/L = new(platform_turf(44, 18))
	L.dir = NORTH
	var/obj/structure/trains/platform/car = platform_car("storage", 44, 17, NORTH)
	var/list/segs = platform_segments(car)
	L.connected = car
	var/obj/structure/trains/transport/flatbed/F = new(platform_turf(44, 13))
	F.dir = NORTH
	var/obj/structure/trains/platform/car_rear = segs[segs.len]
	car_rear.connected = F
	var/obj/structure/closet/crate/deck_crate = new(platform_turf(45, 15))
	var/obj/item/stack/material/iron/bar = new(deck_crate)
	var/obj/structure/closet/crate/wagon_crate = new(platform_turf(44, 13))
	var/list/rear = W.rear_units()
	platform_check("warehouse/rear_unit", rear.len == 1 && rear[1][1] == F)
	var/obj/structure/trains/transport/flatbed/newly_hitched = new(platform_turf(44, 12))
	newly_hitched.dir = NORTH
	F.connected = newly_hitched // Another player couples it after the menu was shown.
	platform_check("warehouse/stale_choice_preserves_consist", W.put_away(null, rear[1], FALSE) == 0 && car_rear.connected == F && F.connected == newly_hitched && !W.stored_units().len)
	F.connected = null
	qdel(newly_hitched)
	platform_check("warehouse/missing_rear_refused", W.put_away(null, list(F, null), FALSE) == 0 && car_rear.connected == F)
	var/mob/living/human/platform_rider/rider = new(platform_turf(44, 13))
	platform_check("warehouse/refuses_riders", W.store_problem(rear[1]))
	qdel(rider)
	platform_check("warehouse/stores_wagon", W.put_away(null, rear[1], FALSE) == 1 && !isturf(F.loc) && !car_rear.connected && !isturf(wagon_crate.loc))
	rear = W.rear_units()
	platform_check("warehouse/stores_car", rear.len == 1 && W.put_away(null, rear[1], FALSE) == 1)
	var/parts_left = 0
	for (var/x in 43 to 45)
		for (var/y in 14 to 17)
			for (var/obj/structure/train_part/P in platform_turf(x, y))
				parts_left++
	platform_check("warehouse/car_off_map", !isturf(car.loc) && !isturf(deck_crate.loc) && bar.loc == deck_crate && !parts_left && !L.connected)
	platform_check("warehouse/two_stored", W.stored_units().len == 2)

	// Couple the car back on behind the locomotive.
	var/obj/structure/rail_stored_unit/stored_car = null
	var/obj/structure/rail_stored_unit/stored_wagon = null
	for (var/obj/structure/rail_stored_unit/U in W.stored_units())
		if (U.unit_length == TRAIN_CAR_LENGTH)
			stored_car = U
		else
			stored_wagon = U
	platform_check("warehouse/retrieves_car", stored_car && !W.retrieve_problem(stored_car, W.retrieve_place(stored_car)) && W.retrieve_unit(stored_car) == car)
	platform_check("warehouse/car_coupled", L.connected == car && car.loc == platform_turf(44, 17) && car_rear.loc == platform_turf(44, 14) && platform_parts_placed(segs))
	platform_check("warehouse/cargo_back", deck_crate.loc == platform_turf(45, 15) && bar.loc == deck_crate)
	platform_check("warehouse/retrieves_wagon", stored_wagon && W.retrieve_unit(stored_wagon) == F && F.loc == platform_turf(44, 13) && car_rear.connected == F && wagon_crate.loc == platform_turf(44, 13))

	// The whole train goes away from the back, then rolls out into an empty bay.
	platform_check("warehouse/whole_train", W.put_away(null, null, TRUE) == 3 && !W.rear_units().len && W.stored_units().len == 3)
	var/obj/structure/rail_stored_unit/loco_unit = null
	for (var/obj/structure/rail_stored_unit/U in W.stored_units())
		if (U.unit_name == L.name)
			loco_unit = U
	platform_check("warehouse/empty_bay", loco_unit && W.retrieve_unit(loco_unit) == L && L.loc == platform_turf(44, 19) && L.dir == NORTH)
	var/obj/structure/rail_stored_unit/blocked = W.stored_units()[1]
	var/obj/structure/closet/crate/large/obstacle = new(platform_turf(44, 18))
	obstacle.density = TRUE
	platform_check("warehouse/blocked_bay", W.retrieve_problem(blocked, W.retrieve_place(blocked)))
	qdel(obstacle)

// Driving (trains.dm): throttle, reverser, braking distance, load, double
// heading, the tender and speed-scaled collisions.
/mob/living/simple_animal/train_probe_dummy
	health = 400
	maxHealth = 400

/proc/drive_train(x, y, wagons, wagon_type = /obj/structure/trains/transport/flatbed)
	for (var/ty in 2 to 25)
		platform_track(x, ty, NORTH)
	var/obj/structure/trains/locomotive/coal/L = new(platform_turf(x, y))
	L.dir = NORTH
	L.fuel = 100
	L.on = TRUE
	var/obj/structure/trains/ahead = L
	for (var/i in 1 to wagons)
		var/obj/structure/trains/W = new wagon_type(platform_turf(x, y - i))
		W.dir = NORTH
		ahead.connected = W
		ahead = W
	return L

/proc/drive_wait(obj/structure/trains/locomotive/L, limit = 150)
	while (L.driving && limit > 0)
		sleep(1)
		limit--
	return !L.driving

/proc/platform_driving_run()
	// Reverser: the train backs up with the wagon still behind the engine.
	var/obj/structure/trains/locomotive/coal/L = drive_train(48, 12, 2)
	var/obj/structure/trains/W1 = L.connected
	var/obj/structure/trains/W2 = W1.connected
	L.reverser = -1
	L.throttle = 1
	L.automovement = TRUE
	platform_check("drive/reverse_step", L.process_rail_reverse() && L.y == 11 && W1.y == 10 && W2.y == 9)
	platform_check("drive/reverse_keeps_facing", L.dir == NORTH && W1.dir == NORTH && W2.dir == NORTH && L.connected == W1)
	L.reverser = 1

	// Throttle: the drive loop gathers speed up to the notch's cruise speed.
	L.refresh_consist()
	var/light_cruise = L.cruise_speed()
	platform_check("load/light_full_speed", L.pull_ratio() >= 1 && abs(light_cruise - 10 / L.max_train_speed / 3) < 0.01)
	L.throttle = 3
	var/start_y = L.y
	L.locomotive()
	sleep(12)
	platform_check("drive/throttle_moves", L.driving && L.y > start_y && W1.y == L.y - 1 && W2.y == L.y - 2)
	platform_check("drive/speed_capped", L.rail_speed > 0 && L.rail_speed <= 10 / L.max_train_speed)
	// Speed changes by the second: a train creeps away and takes many tiles
	// to reach full speed, and loses way gradually.
	var/creep = train_speed_gain(0, TRAIN_ACCEL)
	var/v = 0
	var/tiles_to_full = 0
	while (v < 5 && tiles_to_full < 100)
		v = train_speed_gain(v, TRAIN_ACCEL * 2)
		tiles_to_full++
	platform_check("drive/gathers_way_gradually", creep < 0.6 && tiles_to_full >= 20 && tiles_to_full <= 30 && abs(train_speed_gain(2, 1) - 2 - 1 * train_step_seconds(train_speed_gain(2, 1))) < 0.001)
	platform_check("drive/loses_way_by_the_second", train_step_seconds(5) == 0.2 && train_step_seconds(1) == 1 && train_step_seconds(0) == 2)
	L.throttle = 0
	L.braking = TRUE
	platform_check("drive/brake_stops", drive_wait(L) && L.rail_speed == 0 && !L.automovement)

	// Load: fourteen loaded wagons are more than one engine's rated pull.
	var/obj/structure/trains/locomotive/coal/H = drive_train(56, 17, 14, /obj/structure/trains/storage/closed)
	H.throttle = 3
	H.refresh_consist()
	var/heavy_cruise = H.cruise_speed()
	platform_check("load/heavy_slower", H.pull_ratio() < 1 && heavy_cruise < 10 / H.max_train_speed && heavy_cruise > 0)

	// Braking distance grows with the train: both start at the same speed,
	// slow enough for the heavy one to stop on its stretch of track.
	for (var/obj/structure/trains/locomotive/E in list(L, H))
		E.throttle = 0
		E.braking = TRUE
		E.rail_speed = 1.8
	var/light_from = L.y
	var/heavy_from = H.y
	L.drive()
	H.drive()
	drive_wait(L)
	drive_wait(H)
	// Braking is always quicker than gathering way, light train or heavy.
	var/brakes_beat_accel = TRUE
	for (var/obj/structure/trains/locomotive/E in list(L, H))
		E.refresh_consist()
		E.braking = TRUE
		if (E.stopping_decel(0, max(1, E.consist_weight / 6)) < 2 * TRAIN_ACCEL * min(2, E.pull_ratio()) - 0.001)
			brakes_beat_accel = FALSE
		E.braking = FALSE
	platform_check("brake/stops_quicker_than_it_starts", brakes_beat_accel)
	platform_check("brake/heavy_longer", (H.y - heavy_from) > (L.y - light_from) && L.y - light_from >= 1)

	// Double heading: a second running engine in the train adds its pull.
	var/obj/structure/trains/storage/closed/rear = H
	while (rear.connected)
		rear = rear.connected
	var/obj/structure/trains/locomotive/coal/helper = new(get_step(rear, SOUTH))
	helper.dir = NORTH
	helper.fuel = 100
	helper.on = TRUE
	rear.connected = helper
	H.throttle = 3
	H.refresh_consist()
	platform_check("double_heading/power", H.consist_engines == 2 && H.cruise_speed() > heavy_cruise)
	// The engine already driving sets the pace; the other one helps.
	H.locomotive()
	sleep(2)
	helper.throttle = 3
	helper.locomotive()
	platform_check("double_heading/helper_follows", H.driving && helper.lead_car() == rear && !helper.driving)
	H.throttle = 0
	H.braking = TRUE
	helper.throttle = 0
	drive_wait(H)

	// Tender: the fireman tops up a low firebox from a hitched tender.
	var/obj/structure/trains/locomotive/coal/T = drive_train(52, 12, 0)
	var/obj/structure/trains/storage/tender/tender = new(platform_turf(52, 11))
	tender.dir = NORTH
	T.connected = tender
	var/obj/item/stack/ore/coal/coal = new(tender.storage)
	coal.amount = 5
	T.fuel = 20
	T.refresh_consist(6)
	var/unfed = T.fuel == 20
	var/stroke = T.shovel_coal(null)
	platform_check("tender/shovelled_by_hand", unfed && stroke && T.fuel == 50 && coal.amount == 3 && tender.tender_fuel_left() == 45)

	// Collisions scale with speed: a crawl shoves a person aside unhurt,
	// a fast train throws them clear and keeps going.
	var/mob/living/simple_animal/train_probe_dummy/D = new(platform_turf(52, 13))
	T.rail_speed = 0.5
	platform_check("collision/crawl_shoves", T.rail_hit(D.loc, NORTH) && D.x != 52 && D.health >= 390)
	D.persistence_set_loc(platform_turf(52, 13))
	T.rail_speed = 6
	var/hp = D.health
	platform_check("collision/speed_hurts", !T.rail_hit(D.loc, NORTH) && D.x != 52 && hp - D.health >= 100)

// Heavy locomotives (train_locomotives.dm): a 3x4 engine built from a kit,
// driven by its front section with three body sections hitched behind.
/proc/heavy_parts_placed(obj/structure/trains/locomotive/E)
	if (!E.body_parts || E.body_parts.len < 2)
		return FALSE
	var/list/tiles = train_platform_tiles(E.loc, E.dir)
	for (var/obj/structure/train_part/part in E.body_parts)
		if (part.loc != tiles[part.side + 2] || part.dir != part.facing(E.dir))
			return FALSE
	return TRUE

/proc/platform_heavy_run()
	for (var/y in 2 to 25)
		platform_track(62, y, NORTH)
	// The diesel's line turns east; the armored engine stands on a spur.
	for (var/y in 2 to 18)
		platform_track(66, y, NORTH)
	for (var/x in 67 to 80)
		platform_track(x, 18, EAST)
	for (var/y in 2 to 10)
		platform_track(72, y, NORTH)
	// Steam: boiler in front, cab third, bunker last.
	var/obj/structure/trains/locomotive/coal/heavy/E = platform_car("loco_steam", 62, 12, NORTH)
	var/list/body = istype(E) ? platform_segments(E.connected) : list()
	platform_check("heavy/engine_leads", istype(E) && E.loc == platform_turf(62, 12) && body.len == 3 && E.density && E.wide_body())
	var/obj/structure/trains/platform/boiler = body[1]
	var/obj/structure/trains/platform/cab = body[2]
	var/obj/structure/trains/platform/bunker = body[3]
	platform_check("heavy/body_sections", boiler.seg_index == 2 && bunker.seg_index == 4 && bunker.loc == platform_turf(62, 9) && boiler.car_id == E.car_id && boiler.car_engine() == E)
	platform_check("heavy/body_art", E.icon_state == "loco_steam_1c" && cab.icon_state == "loco_steam_3c" && heavy_parts_placed(E) && platform_parts_placed(body))
	platform_check("heavy/solid_and_cab", boiler.density && bunker.density && !cab.density && E.control_spot() == cab)
	platform_check("heavy/cab_roof_only", cab.roofed() && cab.roof_images && cab.roof_images.len == 3 && !boiler.roofed())
	platform_check("heavy/one_piece", boiler.dismantle_problem() == E.pack_problem() && rail_warehouse_unit(bunker).len == 4 && rail_warehouse_unit(bunker)[1] == E && rail_warehouse_whole_length(E) == 4)
	var/mob/living/human/platform_rider/driver = new(platform_turf(61, 10))
	// The fire is fed at the firebox door in the middle of the cab, not from
	// the fireman's side where the driver stands here.
	var/obj/item/stack/ore/coal/lump = new(platform_turf(61, 10))
	bunker.attackby(lump, driver)
	var/refused = E.fuel == 0 && !QDELETED(lump) && E.cab_station(driver) == "fireman"
	driver.loc = platform_turf(62, 10)
	bunker.attackby(lump, driver)
	platform_check("heavy/fired_at_the_firebox_door", refused && E.fuel == 15 && QDELETED(lump) && E.cab_station(driver) == "fire")
	driver.loc = platform_turf(61, 10)
	E.fuel = 100
	E.on = TRUE
	E.refresh_consist()
	platform_check("heavy/weight_and_pull", abs(E.consist_weight - 6.1) < 0.01 && E.pull_ratio() >= 1 && E.haul == 30)
	platform_check("heavy/steps", platform_step(E, 3) == 3 && E.loc == platform_turf(62, 15) && bunker.loc == platform_turf(62, 12))
	platform_check("heavy/body_follows", heavy_parts_placed(E) && platform_parts_placed(body) && driver.loc == platform_turf(61, 13))
	// Someone beside the rails is hit by the body, not passed through.
	var/mob/living/simple_animal/train_probe_dummy/D = new(platform_turf(61, 16))
	E.rail_speed = 6
	var/hp = D.health
	platform_check("heavy/side_hit", platform_step(E, 1) == 1 && D.x == 60 && hp - D.health >= 100)
	E.rail_speed = 0
	E.reverser = -1
	E.automovement = TRUE
	platform_check("heavy/reverses", E.process_rail_reverse() && E.loc == platform_turf(62, 15) && bunker.loc == platform_turf(62, 12) && E.dir == NORTH && heavy_parts_placed(E) && driver.loc == platform_turf(61, 13))
	E.reverser = 1
	E.ex_act(1.0)
	platform_check("heavy/damage_wears", !QDELETED(E) && E.health == 2050 && !E.broken_down)
	E.heavy_damage(5000)
	platform_check("heavy/wrecked_engine_dies", E.broken_down && !E.on && E.engine_disabled())

	// Diesel: a walk-in cab at the front, a hood with walkways behind.
	var/obj/structure/trains/locomotive/heavy_diesel/DL = platform_car("loco_diesel", 66, 12, NORTH)
	var/list/hood = istype(DL) ? platform_segments(DL.connected) : list()
	var/fronts = 0
	for (var/obj/structure/train_part/edge/cab_front/G in DL.body_parts)
		if (G.density && G.dir == NORTH)
			fronts++
	platform_check("diesel/walk_in_cab", istype(DL) && !DL.density && hood.len == 3 && fronts == 3 && DL.control_spot() == DL && DL.roof_images && DL.roof_images.len == 3)
	var/obj/structure/trains/platform/hood_seg = hood[2]
	var/obj/structure/train_part/deck/walkway = null
	for (var/obj/structure/train_part/deck/W in hood_seg.deck_parts)
		walkway = W
	platform_check("diesel/hood_walkways", hood_seg.density && walkway && !walkway.density)
	var/obj/item/weapon/reagent_containers/glass/barrel/can = new(platform_turf(65, 12))
	can.reagents.add_reagent("diesel", 50)
	var/mob/living/human/platform_rider/engineer = new(platform_turf(66, 12))
	platform_check("diesel/takes_only_fuel", DL.takes_fuel(can) && !DL.takes_fuel(new /obj/item/stack/ore/coal(platform_turf(65, 12))))
	DL.attackby(can, engineer)
	platform_check("diesel/fuelled", DL.fuel == 50 && !can.reagents.has_reagent("diesel"))
	var/obj/structure/closet/crate/cab_crate = new(platform_turf(65, 12))
	var/obj/structure/closet/crate/walk_crate = new(platform_turf(67, 10))
	DL.on = TRUE
	platform_check("diesel/steps", platform_step(DL, 2) == 2 && DL.loc == platform_turf(66, 14) && heavy_parts_placed(DL) && platform_parts_placed(hood))
	platform_check("diesel/cab_load_rides", engineer.loc == platform_turf(66, 14) && cab_crate.loc == platform_turf(65, 14) && walk_crate.loc == platform_turf(67, 12))

	var/curve_steps = platform_step(DL, 30)
	var/obj/structure/trains/platform/hood_end = hood[3]
	platform_check("diesel/rounds_curve", curve_steps == 18 && DL.loc == platform_turf(80, 18) && DL.dir == EAST && hood_end.loc == platform_turf(77, 18) && hood_end.dir == EAST && heavy_parts_placed(DL) && platform_parts_placed(hood))
	// The crate on the inside of the curve slips one section back, and stays on a walkway.
	platform_check("diesel/load_rounds_curve", engineer.loc == platform_turf(80, 18) && cab_crate.loc == platform_turf(80, 19) && walk_crate.loc == platform_turf(77, 17))

	// Armored: plate over everything, bulletproof cab doors.
	var/obj/structure/trains/locomotive/coal/armored/heavy/AL = platform_car("loco_armored", 72, 8, NORTH)
	var/list/plated = istype(AL) ? platform_segments(AL.connected) : list()
	var/doors = 0
	var/obj/structure/trains/platform/armored_cab = plated.len == 3 ? plated[2] : null
	if (armored_cab)
		for (var/obj/structure/train_part/edge/G in armored_cab.deck_parts)
			if (G.is_armor() && G.is_door())
				doors++
	AL.ex_act(1.0)
	platform_check("armored_heavy/plated", istype(AL) && AL.overlays.len == 0 && doors == 2 && AL.health == 5700 && !AL.disabled && AL.haul == 40)

	// A steam engine's solid boiler side lies on the next rail tile of a curve
	// and must not stop the engine itself.
	for (var/y in 2 to 10)
		platform_track(77, y, NORTH)
	for (var/x in 78 to 84)
		platform_track(x, 10, EAST)
	var/obj/structure/trains/locomotive/coal/heavy/CE = platform_car("loco_steam", 77, 6, NORTH)
	CE.fuel = 100
	CE.on = TRUE
	var/steam_curve = platform_step(CE, 20)
	var/solid_sides = 0
	for (var/obj/structure/train_part/deck/body/B in CE.body_parts)
		if (B.density)
			solid_sides++
	platform_check("heavy/steam_rounds_curve", steam_curve == 11 && CE.loc == platform_turf(84, 10) && CE.dir == EAST && heavy_parts_placed(CE) && solid_sides == 2)

// A stand-in viewer: the step survey reads only its owner, body and reach.
/datum/los_context/train_probe
	var/list/probe_radii = list(10, 7)
/datum/los_context/train_probe/viewport_radii()
	return probe_radii

/proc/platform_viewers_run()
	var/turf/near = platform_turf(40, 12)
	var/turf/edge = platform_turf(59, 12)
	var/turf/far = platform_turf(60, 12)
	train_platform_reset_plan()
	platform_check("viewers/nobody_plain", train_tile_unwatched(near) && train_tile_unwatched(far))
	var/mob/living/human/platform_rider/watcher = new(platform_turf(40, 5))
	var/datum/los_context/train_probe/V = new(null)
	V.vars["owner"] = V
	V.body = watcher
	los_active_contexts = list(V)
	// Reach is the viewport radius plus 9 tiles: 19 across, 16 up and down.
	platform_check("viewers/cached_for_the_step", train_tile_unwatched(near))
	train_platform_reset_plan()
	platform_check("viewers/near_is_watched", !train_tile_unwatched(near) && !train_tile_unwatched(edge) && !train_tile_unwatched(platform_turf(40, 21)))
	platform_check("viewers/far_is_plain", train_tile_unwatched(far) && train_tile_unwatched(platform_turf(40, 22)))
	// A train out of the viewer's reach still carries its parts and load.
	for (var/x in 68 to 84)
		platform_track(x, 23, EAST)
	var/obj/structure/trains/platform/car = platform_car("coach", 75, 23, EAST)
	var/list/segs = platform_segments(car)
	var/obj/structure/trains/locomotive/coal/L = new(platform_turf(76, 23))
	L.dir = EAST
	L.fuel = 100
	L.on = TRUE
	L.connected = car
	var/obj/structure/closet/crate/crate = new(platform_turf(74, 24))
	var/obj/item/weapon/branch/stick = new(platform_turf(73, 22))
	var/mob/living/human/platform_rider/rider = new(platform_turf(74, 22))
	platform_check("viewers/unwatched_step", platform_step(L, 3) == 3 && train_tile_unwatched(car.loc) && platform_parts_placed(segs))
	platform_check("viewers/unwatched_load_rides", crate.loc == platform_turf(77, 24) && stick.loc == platform_turf(76, 22) && rider.loc == platform_turf(77, 22))
	// Without a viewport there is nothing to cull by, and a save checks every move.
	V.probe_radii = null
	train_platform_reset_plan()
	platform_check("viewers/no_viewport_is_watched", !train_tile_unwatched(far))
	los_active_contexts = null
	// Both ways of moving put the object on the tile; a person always moves the full way.
	var/turf/spot = platform_turf(45, 3)
	platform_check("viewers/shift_both_ways", crate.train_shift(spot, FALSE) && crate.loc == spot && stick.train_shift(spot, TRUE) && stick.loc == spot && rider.train_shift(spot, TRUE) && rider.loc == spot)
	train_platform_reset_plan()

/proc/position_track(x)
	for (var/y in 2 to 25)
		platform_track(x, y, NORTH)

/proc/position_wagon(x, y, wagon_type = /obj/structure/trains/transport/flatbed)
	var/obj/structure/trains/W = new wagon_type(platform_turf(x, y))
	W.dir = NORTH
	return W

// Engines anywhere in the train: pushing from the rear, driving from the
// middle, and what leads the train setting how fast it may go.
/proc/platform_position_run()
	// A pusher: two wagons ahead of the engine.
	position_track(90)
	var/obj/structure/trains/W1 = position_wagon(90, 10)
	var/obj/structure/trains/W2 = position_wagon(90, 9)
	var/obj/structure/trains/locomotive/coal/P = position_wagon(90, 8, /obj/structure/trains/locomotive/coal)
	W1.connected = W2
	W2.connected = P
	P.fuel = 100
	P.on = TRUE
	platform_check("position/train_head", P.train_head() == W1 && W2.train_head() == W1 && W1.train_head() == W1 && W2.lead_car() == W1)
	P.throttle = 3
	P.refresh_consist()
	var/top = 10 / P.max_train_speed
	platform_check("position/pushing_half_speed", P.drive_head == W1 && P.lead_factor == 0.5 && abs(P.cruise_speed() - top * 0.5) < 0.01)
	P.throttle = 1
	P.locomotive()
	sleep(15)
	platform_check("position/pusher_moves_train", P.driving && W1.y > 10 && W2.y == W1.y - 1 && P.y == W1.y - 2 && P.fuel < 100 && W1.connected == W2 && W2.connected == P)
	P.throttle = 0
	P.braking = TRUE
	platform_check("position/pusher_stops", drive_wait(P) && !W1.automovement)
	// Pushed cars hit what is ahead with the engine's weight and stop the train.
	var/obj/structure/trains/buffer = position_wagon(90, W1.y + 1)
	var/buffer_health = buffer.health
	var/head_health = W1.health
	P.rail_speed = 4
	P.automovement = TRUE
	P.refresh_consist()
	platform_check("position/pushed_cars_collide", !P.process_rail_forward() && W1.y == buffer.y - 1 && W1.health < head_health && buffer.health <= buffer_health && !P.automovement)
	P.rail_speed = 0
	qdel(buffer)

	// An engine in the middle drives both ways, cars leading either way.
	position_track(94)
	var/obj/structure/trains/M1 = position_wagon(94, 14)
	var/obj/structure/trains/locomotive/coal/ME = position_wagon(94, 13, /obj/structure/trains/locomotive/coal)
	var/obj/structure/trains/M3 = position_wagon(94, 12)
	M1.connected = ME
	ME.connected = M3
	ME.fuel = 100
	ME.on = TRUE
	ME.throttle = 1
	ME.locomotive()
	sleep(15)
	platform_check("position/middle_forward", ME.driving && M1.y > 14 && ME.y == M1.y - 1 && M3.y == M1.y - 2)
	ME.throttle = 0
	ME.braking = TRUE
	drive_wait(ME)
	var/back_from = M3.y
	ME.reverser = -1
	ME.throttle = 1
	ME.locomotive()
	sleep(15)
	platform_check("position/middle_backward", ME.driving && ME.lead_factor == 0.5 && M3.y < back_from && ME.y == M3.y + 1 && M1.y == M3.y + 2)
	ME.throttle = 0
	ME.braking = TRUE
	drive_wait(ME)

	// Banking: with the front engine running but idle, the rear one drives the
	// train, and both pull.
	position_track(102)
	var/obj/structure/trains/locomotive/coal/BH = position_wagon(102, 10, /obj/structure/trains/locomotive/coal)
	var/obj/structure/trains/BW = position_wagon(102, 9)
	var/obj/structure/trains/locomotive/coal/BR = position_wagon(102, 8, /obj/structure/trains/locomotive/coal)
	BH.connected = BW
	BW.connected = BR
	for (var/obj/structure/trains/locomotive/E in list(BH, BR))
		E.fuel = 100
		E.on = TRUE
	BR.throttle = 1
	BR.locomotive()
	sleep(15)
	platform_check("banking/rear_engine_drives", BR.driving && !BH.driving && BR.drive_head == BH && BR.consist_engines == 2 && BH.y > 10 && BR.y == BH.y - 2 && BR.lead_factor == 1)
	BR.throttle = 0
	BR.braking = TRUE
	drive_wait(BR)
	BH.on = FALSE
	BR.refresh_consist()
	platform_check("banking/dead_front_engine_is_pushed", BR.lead_factor == 0.5 && BR.consist_engines == 1)

	// What leads: the engine forward, the engine backward, or cars.
	position_track(98)
	var/obj/structure/trains/locomotive/coal/LE = position_wagon(98, 20, /obj/structure/trains/locomotive/coal)
	var/obj/structure/trains/LW = position_wagon(98, 19)
	platform_check("position/alone_forward_full", LE.leading_factor(list(LE)) == 1)
	LE.reverser = -1
	platform_check("position/alone_backward", LE.leading_factor(list(LE)) == 0.75)
	LE.connected = LW
	platform_check("position/backing_cars_lead", LE.leading_factor(train_consist_list(LE)) == 0.5)
	LE.reverser = 1
	platform_check("position/pulling_full", LE.leading_factor(train_consist_list(LE)) == 1)
	LE.connected = null

	// Coupling from the rear end of a car.
	var/mob/living/human/platform_rider/shunter = new(platform_turf(97, 19))
	platform_check("hitch/rear_couples", LE.hitch_rear(shunter) && LE.connected == LW)
	platform_check("hitch/rear_uncouples", LE.hitch_rear(shunter) && !LE.connected)
	var/obj/structure/trains/platform/car = platform_car("flatbed", 98, 10, NORTH)
	var/list/segs = platform_segments(car)
	var/obj/structure/trains/platform/last = segs[TRAIN_CAR_LENGTH]
	var/obj/structure/trains/behind = position_wagon(98, 6)
	platform_check("hitch/car_sections_stay", !car.hitch_rear(shunter) && car.connected == segs[2])
	platform_check("hitch/car_rear_couples", last.hitch_rear(shunter) && last.connected == behind && behind.train_head() == car)
	// A wagon already in another train is left alone.
	var/obj/structure/trains/taken = position_wagon(98, 4)
	var/obj/structure/trains/owner = position_wagon(98, 5)
	behind.connected = null
	behind.persistence_set_loc(platform_turf(98, 3))
	owner.connected = taken
	last.connected = null
	platform_check("hitch/rear_leaves_other_trains", !owner.hitch_front(shunter) && !last.hitch_rear(shunter) && !last.connected)

/proc/facing_back(obj/structure/trains/locomotive/L, count)
	for (var/i in 1 to count)
		L.automovement = TRUE
		if (!L.process_rail_reverse())
			return i - 1
	return count

/proc/facing_forward(obj/structure/trains/locomotive/L, count)
	for (var/i in 1 to count)
		L.automovement = TRUE
		if (!L.process_rail_forward())
			return i - 1
	return count

// Cars and engines coupled in facing either way: a car keeps the way it
// faces (dir) and runs tail first (reversed) when that is not the way its
// train heads.
/proc/platform_facing_run()
	var/mob/living/human/platform_rider/shunter = new(platform_turf(104, 3))
	// A coach built facing south behind an engine that faces north.
	position_track(106)
	var/obj/structure/trains/locomotive/coal/E = position_wagon(106, 14, /obj/structure/trains/locomotive/coal)
	var/obj/structure/trains/platform/car = platform_car("coach", 106, 10, SOUTH)
	var/list/segs = platform_segments(car)
	var/obj/structure/trains/platform/far = segs[TRAIN_CAR_LENGTH]
	var/turned = 0
	var/coupled = far.couple_end(FALSE, shunter)
	for (var/obj/structure/trains/platform/S in segs)
		if (S.reversed && S.dir == SOUTH && S.train_heading() == NORTH && S.train_head() == E)
			turned++
	platform_check("facing/back_to_front_couples", coupled && E.connected == far && far.connected == segs[3] && !car.connected && turned == TRAIN_CAR_LENGTH && !E.reversed)
	platform_check("facing/coupled_car_not_dismantled", car.dismantle_problem() == "Uncouple the car from the one ahead first.")
	for (var/obj/structure/trains/platform/S in segs)
		for (var/turf/T in train_platform_tiles(S.loc, S.dir))
			for (var/obj/structure/bed/B in T)
				qdel(B)
	var/obj/structure/closet/crate/crate = new(platform_turf(107, 11))
	var/mob/living/human/platform_rider/rider = new(platform_turf(106, 12))
	E.fuel = 100
	E.on = TRUE
	turned = 0
	var/stepped = platform_step(E, 3)
	for (var/obj/structure/trains/platform/S in segs)
		if (S.reversed && S.dir == SOUTH)
			turned++
	platform_check("facing/turned_car_follows", stepped == 3 && E.loc == platform_turf(106, 17) && far.loc == platform_turf(106, 16) && car.loc == platform_turf(106, 13) && turned == TRAIN_CAR_LENGTH && platform_parts_placed(segs))
	platform_check("facing/turned_car_carries", crate.loc == platform_turf(107, 14) && rider.loc == platform_turf(106, 15))
	E.reverser = -1
	E.refresh_consist()
	stepped = facing_back(E, 2)
	platform_check("facing/turned_car_backs", stepped == 2 && E.loc == platform_turf(106, 15) && car.loc == platform_turf(106, 11) && car.dir == SOUTH && platform_parts_placed(segs) && crate.loc == platform_turf(107, 12))
	E.reverser = 1
	// Uncoupled, the car is its own train again, front first.
	turned = 0
	coupled = far.couple_end(TRUE, shunter)
	for (var/obj/structure/trains/platform/S in segs)
		if (S.reversed || S.dir != SOUTH)
			turned++
	platform_check("facing/uncoupled_car_settles", coupled && !E.connected && !turned && car.connected == segs[2] && !far.connected && far.train_head() == car)

	// Top and tail: an engine at each end, each facing out.
	position_track(110)
	var/obj/structure/trains/locomotive/coal/E1 = position_wagon(110, 12, /obj/structure/trains/locomotive/coal)
	var/obj/structure/trains/W = position_wagon(110, 11)
	var/obj/structure/trains/locomotive/coal/E2 = position_wagon(110, 10, /obj/structure/trains/locomotive/coal)
	E2.dir = SOUTH
	E1.connected = W
	platform_check("facing/engine_couples_facing_away", E2.hitch_rear(shunter) && W.connected == E2 && E2.reversed && E2.dir == SOUTH && !E1.reversed && E2.train_head() == E1 && E2.train_way() == -1)
	for (var/obj/structure/trains/locomotive/L in list(E1, E2))
		L.fuel = 100
	// The rear engine runs the train its own way at full speed.
	E2.on = TRUE
	E2.throttle = 1
	E2.locomotive()
	sleep(15)
	platform_check("facing/rear_engine_leads_forward", E2.driving && E2.lead_factor == 1 && E2.y < 10 && E2.dir == SOUTH && W.y == E2.y + 1 && E1.y == E2.y + 2 && E1.dir == NORTH)
	E2.throttle = 0
	E2.braking = TRUE
	drive_wait(E2)
	// Backing from the front engine: a dead engine at the rear is only pushed.
	E2.on = FALSE
	E1.on = TRUE
	E1.reverser = -1
	E1.refresh_consist()
	var/pushed = E1.lead_factor
	E2.on = TRUE
	E1.refresh_consist()
	platform_check("facing/running_rear_engine_sees_the_line", pushed == 0.5 && E1.lead_factor == 1)
	E1.reverser = 1
	E1.refresh_consist()
	platform_check("facing/front_engine_forward", E1.lead_factor == 1 && E1.train_way() == 1)
	E1.on = FALSE
	E2.on = FALSE
	var/alone_from = E2.y
	platform_check("facing/uncoupled_engine_settles", E2.hitch_front(shunter) && !W.connected && !E2.reversed && E2.dir == SOUTH)
	E2.on = TRUE
	platform_check("facing/uncoupled_engine_runs_its_way", platform_step(E2, 1) == 1 && E2.y == alone_from - 1 && E2.dir == SOUTH)

	// A car put away in a rail warehouse comes out facing its train's way.
	position_track(114)
	var/obj/structure/rail_warehouse/depot = new(platform_turf(112, 13))
	depot.dir = EAST
	var/obj/structure/trains/puller = position_wagon(114, 16, /obj/structure/trains/locomotive/coal)
	var/obj/structure/trains/platform/stock = platform_car("flatbed", 114, 12, SOUTH)
	var/list/stock_segs = platform_segments(stock)
	var/obj/structure/trains/platform/stock_far = stock_segs[TRAIN_CAR_LENGTH]
	stock_far.couple_end(FALSE, shunter)
	var/list/rear = depot.rear_units()
	platform_check("facing/warehouse_rear_unit", puller.connected == stock_far && stock.reversed && rear.len == 1 && rear[1][1] == stock)
	platform_check("facing/warehouse_stores_turned_car", rear.len == 1 && depot.put_away(null, rear[1], FALSE) == 1 && !isturf(stock.loc) && !puller.connected && !stock.reversed && stock.connected == stock_segs[2])
	var/obj/structure/rail_stored_unit/kept = null
	for (var/obj/structure/rail_stored_unit/U in depot.stored_units())
		kept = U
	platform_check("facing/warehouse_returns_car", kept && depot.retrieve_unit(kept) == stock && puller.connected == stock && stock.loc == platform_turf(114, 15) && stock.dir == NORTH && !stock.reversed && stock_far.loc == platform_turf(114, 12) && platform_parts_placed(stock_segs))

	// A heavy engine at the rear, facing out, leads the train round a curve
	// and comes back.
	for (var/y in 8 to 25)
		platform_track(118, y, NORTH)
	for (var/x in 119 to 126)
		platform_track(x, 8, EAST)
	var/obj/structure/trains/locomotive/coal/L1 = position_wagon(118, 20, /obj/structure/trains/locomotive/coal)
	var/obj/structure/trains/locomotive/coal/L2 = position_wagon(118, 19, /obj/structure/trains/locomotive/coal)
	L1.connected = L2
	var/obj/structure/trains/locomotive/coal/heavy/H = platform_car("loco_steam", 118, 15, SOUTH)
	var/list/body = platform_segments(H.connected)
	var/obj/structure/trains/platform/bunker = body[body.len]
	var/obj/structure/trains/platform/cab = body[2]
	coupled = bunker.couple_end(FALSE, shunter)
	platform_check("facing/heavy_engine_faces_out", coupled && L2.connected == bunker && cab.connected == body[1] && body[1].connected == H && !H.connected && H.reversed && H.dir == SOUTH && H.control_spot() == cab && cab.car_engine() == H && H.train_head() == L1)
	H.fuel = 100
	H.on = TRUE
	H.refresh_consist()
	stepped = facing_back(H, 12)
	platform_check("facing/heavy_engine_leads_round_curve", stepped == 12 && H.lead_factor == 1 && H.loc == platform_turf(123, 8) && H.dir == EAST && bunker.dir == EAST && L1.loc == platform_turf(118, 8) && heavy_parts_placed(H) && platform_parts_placed(body))
	H.reverser = -1
	H.refresh_consist()
	stepped = facing_forward(H, 12)
	platform_check("facing/heavy_engine_comes_back", stepped == 12 && H.lead_factor == 0.5 && H.loc == platform_turf(118, 15) && H.dir == SOUTH && L1.loc == platform_turf(118, 20) && heavy_parts_placed(H) && platform_parts_placed(body))

// Bogie stock: cars as long as their kind says (train_car_length()).
/proc/platform_long_run()
	for (var/y in 2 to 16)
		platform_track(130, y, NORTH)
	for (var/x in 131 to 139)
		platform_track(x, 16, EAST)
	var/obj/structure/train_car_kit/short_kit = new(platform_turf(130, 6))
	short_kit.set_kind("coach")
	var/short_fits = !short_kit.assembly_problem(NORTH)
	short_kit.set_kind("bogie_coach")
	platform_check("long/kit_needs_its_length", short_fits && short_kit.car_length() == 8 && short_kit.assembly_problem(NORTH) && short_kit.name == "bogie coach kit")
	qdel(short_kit)

	var/obj/structure/trains/platform/van = platform_car("boxcar", 130, 10, NORTH)
	var/list/segs = platform_segments(van)
	var/obj/structure/trains/platform/van_end = segs.len == 8 ? segs[8] : null
	platform_check("long/eight_segments", train_car_length("boxcar") == 8 && train_car_length("coach") == 4 && train_car_length("loco_steam") == 4 && segs.len == 8 && van.loc == platform_turf(130, 10) && van_end && van_end.loc == platform_turf(130, 3) && platform_parts_placed(segs))
	var/obj/structure/trains/platform/mid = segs[4]
	platform_check("long/headstocks_at_the_ends", van.car_end_row() == "f" && van_end.car_end_row() == "b" && !mid.car_end_row() && van_end.seg_index == 8)
	var/list/states = icon_states('icons/obj/vehicles/train_platforms.dmi')
	var/missing = 0
	for (var/state in list("edge_plank", "edge_freight_door", "edge_freight_door_open", "edge_side", "edge_drop_door", "edge_drop_door_open", "deck_center_boards", "deck_side_boards", "roof_boxcar_fl", "roof_boxcar_mc", "roof_boxcar_br"))
		if (!(state in states))
			missing++
	platform_check("long/art_states", !missing)
	var/obj/structure/train_part/edge/slider = null
	var/sides = 0
	for (var/obj/structure/train_part/edge/G in mid.deck_parts)
		if (G.style == "freight_door")
			slider = G
	for (var/obj/structure/train_part/edge/G in van.deck_parts)
		if (G.style == "plank" && G.density && !G.is_door())
			sides++
	var/was_shut = slider && slider.density && slider.is_door()
	if (slider)
		slider.set_open(TRUE)
	platform_check("long/boxcar_doors_slide", was_shut && !slider.density && slider.icon_state == "edge_freight_door_open" && sides == 5)
	platform_check("long/boxcar_roofed", van.roofed() && mid.roof_images && mid.roof_images.len == 3 && van.icon_state == "deck_center_boards")
	var/weight = 0
	for (var/obj/structure/trains/platform/S in segs)
		weight += S.car_load_weight()
	platform_check("long/weighs_double", weight == 4 && rail_warehouse_unit(mid).len == 8)

	var/obj/structure/trains/locomotive/coal/L = new(platform_turf(130, 11))
	L.dir = NORTH
	L.fuel = 100
	L.on = TRUE
	var/mob/living/human/platform_rider/shunter = new(platform_turf(128, 3))
	platform_check("long/couples_at_the_ends_only", !mid.couple_end(TRUE, shunter) && van.hitch_front(shunter) && L.connected == van && van_end.train_head() == L)
	var/obj/structure/closet/crate/crate = new(platform_turf(129, 5))
	platform_check("long/follows", platform_step(L, 3) == 3 && van.loc == platform_turf(130, 13) && van_end.loc == platform_turf(130, 6) && platform_parts_placed(segs) && crate.loc == platform_turf(129, 8))
	var/curve = platform_step(L, 10)
	platform_check("long/rounds_curve", curve == 10 && L.loc == platform_turf(138, 16) && van.loc == platform_turf(137, 16) && van.dir == EAST && van_end.loc == platform_turf(130, 16) && platform_parts_placed(segs))
	platform_check("long/coupled_car_stays_whole", van.dismantle_problem())
	L.connected = null
	qdel(crate)
	var/problem = van.dismantle_problem()
	var/obj/structure/train_car_kit/packed = problem ? null : van.pack_car()
	var/left = 0
	for (var/obj/structure/trains/platform/S in world)
		if (S.car_kind == "boxcar" && !QDELETED(S))
			left++
	platform_check("long/packs_into_its_kit", !problem && packed && packed.car_kind == "boxcar" && packed.car_length() == 8 && !left)

	// A furnished bogie coach: a vestibule each end, six bays of seats.
	for (var/y in 2 to 12)
		platform_track(134, y, NORTH)
	var/obj/structure/trains/platform/coach = platform_car("bogie_coach", 134, 10, NORTH)
	var/list/coach_segs = platform_segments(coach)
	var/seats = 0
	var/doors = 0
	for (var/obj/structure/trains/platform/S in coach_segs)
		for (var/turf/T in train_platform_tiles(S.loc, S.dir))
			for (var/obj/structure/bed/chair/C in T)
				seats++
		if (S.seg_index == 1 || S.seg_index == 8)
			for (var/obj/structure/train_part/edge/G in S.deck_parts)
				if (G.is_door())
					doors++
	platform_check("long/bogie_coach_fitted", coach_segs.len == 8 && seats == 12 && doors == 6 && coach.roofed())
	var/obj/structure/trains/platform/wagon_probe = new(platform_turf(134, 12))
	wagon_probe.car_kind = "open_wagon"
	wagon_probe.seg_index = 4
	wagon_probe.apply_layout()
	var/drops = 0
	for (var/obj/structure/train_part/edge/G in wagon_probe.deck_parts)
		if (G.style == "drop_door" && G.is_door())
			drops++
	platform_check("long/open_wagon_drop_doors", drops == 2 && !wagon_probe.roofed() && train_car_length("open_wagon") == 8 && train_car_length("long_flatbed") == 8)
	qdel(wagon_probe)

// Couplings as parts (train_couplings.dm): shown at every car end, worn,
// broken, taken off and fitted, and the train parts where one breaks.
/proc/platform_coupling_run()
	var/obj/structure/trains/locomotive/coal/L = drive_train(144, 12, 3)
	var/obj/structure/trains/W1 = L.connected
	var/obj/structure/trains/W2 = W1.connected
	var/obj/structure/trains/W3 = W2.connected
	for (var/obj/structure/trains/car in list(L, W1, W2, W3))
		car.update_couplers()
	platform_check("coupling/shown_at_each_end", W1.coupler_f && W1.coupler_r && (W1.coupler_f in W1.vis_contents) && (W1.coupler_r in W1.vis_contents) && W1.coupler_f.icon_state == "coupler_f_linked" && W1.coupler_r.icon_state == "coupler_b_linked" && W3.coupler_r.icon_state == "coupler_b_free" && L.coupler_f.icon_state == "coupler_f_free" && L.coupler_r.icon_state == "coupler_b_linked")
	platform_check("coupling/part_knows_its_end", W1.coupler_r.car == W1 && !W1.coupler_r.front && W1.coupler_f.front && W1.end_neighbour(FALSE) == W2 && W1.end_neighbour(TRUE) == L && W2.end_towards(W1) && !W2.end_towards(W3))
	var/list/states = icon_states('icons/obj/vehicles/train_platforms.dmi')
	var/missing = 0
	for (var/kind in list("free", "linked", "broken", "none"))
		for (var/end in list("f", "b"))
			if (!("coupler_[end]_[kind]" in states))
				missing++
	platform_check("coupling/art_states", !missing && ("coupling_item" in states))

	platform_check("coupling/wears", W2.damage_coupling(FALSE, 40) && W2.rear_coupling == 60 && W2.connected == W3 && W2.coupler_r.icon_state == "coupler_b_linked" && findtext(W2.coupling_text(FALSE), "60%"))
	platform_check("coupling/breaks_and_parts_the_train", W2.damage_coupling(FALSE, 60) && W2.rear_coupling == 0 && !W2.connected && W3.train_head() == W3 && W2.train_head() == L && W2.coupler_r.icon_state == "coupler_b_broken" && W3.coupler_f.icon_state == "coupler_f_free" && !W2.damage_coupling(FALSE, 10))
	var/mob/living/human/platform_rider/shunter = new(platform_turf(143, 10))
	platform_check("coupling/broken_will_not_couple", !W3.hitch_front(shunter) && !W2.hitch_rear(shunter) && !W2.connected)
	platform_check("coupling/hitched_one_stays_on", !W1.remove_coupling(FALSE) && W1.rear_coupling == 100)
	var/obj/item/train_coupling/scrap = W2.remove_coupling(FALSE)
	platform_check("coupling/taken_off", scrap && scrap.condition == 0 && scrap.name == "broken train coupling" && W2.rear_coupling == -1 && W2.coupler_r.icon_state == "coupler_b_none" && findtext(W2.coupling_text(FALSE), "missing") && !W3.hitch_front(shunter))
	var/obj/item/train_coupling/spare = new(platform_turf(143, 10))
	var/refused = !W1.fit_coupling(FALSE, spare)
	platform_check("coupling/spare_fitted", refused && W2.fit_coupling(FALSE, spare) && W2.rear_coupling == 100 && QDELETED(spare) && W2.coupler_r.icon_state == "coupler_b_free")
	platform_check("coupling/couples_again", W3.hitch_front(shunter) && W2.connected == W3 && W2.coupler_r.icon_state == "coupler_b_linked" && W3.coupler_f.icon_state == "coupler_f_linked" && W3.train_head() == L)

	// By hand: a tight coupling stays made; a blow on harm intent wears it.
	L.throttle = 1
	L.driving = TRUE
	var/tight = W1.train_under_power() && W1.coupler_use(shunter, FALSE) && W1.connected == W2
	L.driving = FALSE
	L.throttle = 0
	platform_check("coupling/not_undone_under_power", tight && !W1.train_under_power())
	var/obj/item/weapon/crowbar/bar = new(shunter)
	shunter.put_in_active_hand(bar)
	shunter.a_intent = I_HARM
	var/far = !L.coupler_use(shunter, TRUE) && L.front_coupling == 100
	W2.coupler_use(shunter, TRUE)
	platform_check("coupling/struck_with_a_weapon", far && shunter.get_active_hand() == bar && W2.front_coupling == 100 - bar.force && W1.connected == W2)
	qdel(bar)

	W3.blast_couplings(2)
	var/strained = W3.front_coupling == 40 && W3.rear_coupling == 40 && W2.connected == W3
	W3.blast_couplings(1)
	platform_check("coupling/blast_breaks", strained && W3.front_coupling == 0 && W3.rear_coupling == 0 && !W2.connected)
	platform_check("coupling/train_runs_on_without_the_rest", platform_step(L, 2) == 2 && W2.loc == platform_turf(144, 12) && W3.loc == platform_turf(144, 9))
	var/obj/effect/train_coupler/gone = W3.coupler_f
	qdel(W3)
	platform_check("coupling/cleared_with_the_car", gone && QDELETED(gone))

	// Cars facing each other's way: each end still knows its neighbour.
	for (var/y in 2 to 10)
		platform_track(146, y, NORTH)
	var/obj/structure/trains/transport/flatbed/A = new(platform_turf(146, 6))
	A.dir = NORTH
	var/obj/structure/trains/transport/flatbed/B = new(platform_turf(146, 5))
	B.dir = SOUTH
	var/mob/living/human/platform_rider/second = new(platform_turf(145, 6))
	platform_check("coupling/back_to_back", A.hitch_rear(second) && A.end_neighbour(FALSE) == B && B.end_neighbour(FALSE) == A && !B.end_neighbour(TRUE) && B.coupler_r.icon_state == "coupler_b_linked" && B.coupler_f.icon_state == "coupler_f_free" && A.coupler_r.icon_state == "coupler_b_linked")
	B.damage_coupling(FALSE, 100)
	platform_check("coupling/back_to_back_parts", !A.end_neighbour(FALSE) && !B.end_neighbour(FALSE) && A.train_head() == A && B.train_head() == B && A.rear_coupling == 100)

	// A car of several sections has a coupling at each end of the car only.
	var/obj/structure/trains/platform/flat = platform_car("flatbed", 146, 10, NORTH)
	var/list/segs = platform_segments(flat)
	var/obj/structure/trains/platform/mid = segs[2]
	var/obj/structure/trains/platform/last = segs[4]
	platform_check("coupling/car_ends_only", flat.coupler_f && !flat.coupler_r && !mid.coupler_f && !mid.coupler_r && last.coupler_r && !last.coupler_f && !mid.damage_coupling(TRUE, 100) && mid.front_coupling == 100)

/proc/boiler_near(a, b)
	return abs(a - b) < 0.01

// The boiler (trains.dm): steam made and used, water, the injector, raising
// steam by the clock and the fusible plug.
/proc/platform_boiler_run()
	var/obj/structure/trains/locomotive/coal/L = drive_train(142, 4, 2)
	platform_check("boiler/built_in_steam", L.pressure == 100 && L.steam_factor() == 1 && L.water == 240 && L.boiler_water == 60 && L.injector && !L.plug_dropped && L.start_text == "Light the fire")
	L.steam_use(3, L.haul, 10)
	platform_check("boiler/work_boils_water_and_the_injector_feeds", boiler_near(L.water, 230) && boiler_near(L.boiler_water, 60) && boiler_near(L.pressure, 98))
	L.throttle = 3
	L.refresh_consist()
	L.pressure = 100
	var/full = L.cruise_speed()
	L.pressure = 70
	L.steam_use(3, L.haul * 2, 40)
	var/winded = L.cruise_speed()
	platform_check("boiler/overload_winds_the_engine", boiler_near(L.pressure, 46) && full > 0 && boiler_near(winded, full * 46 / 60))
	L.pressure = 100
	L.fuel = 10
	L.steam_use(3, L.haul, 10)
	platform_check("boiler/thin_fire_loses_steam", boiler_near(L.pressure, 90.2))
	L.pressure = 10
	platform_check("boiler/no_steam_no_power", L.steam_factor() == 0 && L.cruise_speed() == 0)
	L.throttle = 0

	L.pressure = 0
	L.fuel = 100
	L.boiler_time = world.time - 600
	L.boiler_tick()
	platform_check("boiler/raises_steam_by_the_clock", boiler_near(L.pressure, 50) && boiler_near(L.fuel, 98.8) && L.on)
	L.on = FALSE
	L.boiler_time = world.time - 1200
	L.boiler_tick()
	platform_check("boiler/cools_with_the_fire_out", boiler_near(L.pressure, 40) && boiler_near(L.fuel, 98.8))

	var/mob/living/human/platform_rider/fireman = new(platform_turf(141, 4))
	platform_check("boiler/injector_control", ("Injector off" in L.extra_controls()) && L.handle_control("Injector off", fireman) && !L.injector && ("Injector on" in L.extra_controls()) && !L.handle_control("Whistle", fireman) && findtext(L.state_text(), "injector off"))
	L.on = TRUE
	L.pressure = 100
	L.boiler_water = 60
	L.steam_use(3, L.haul, 50)
	var/low = boiler_near(L.boiler_water, 10) && L.water_warned && !L.plug_dropped && L.on
	L.steam_use(3, L.haul, 10)
	platform_check("boiler/dry_boiler_drops_the_plug", low && L.plug_dropped && !L.on && L.pressure == 0 && L.steam_factor() == 0 && L.boiler_water == 0)
	var/plug_stops = findtext(L.start_problem(), "plug")
	L.plug_dropped = FALSE
	platform_check("boiler/no_fire_without_plug_or_water", plug_stops && findtext(L.start_problem(), "water"))

	L.water = 100
	var/cold = L.add_water(120)
	var/cold_ok = cold == 120 && L.boiler_water == 60 && L.water == 160 && !L.start_problem()
	L.water = 240
	var/full_tank = L.add_water(50) == 0
	L.pressure = 100
	L.boiler_water = 30
	L.water = 0
	platform_check("boiler/cold_boiler_fills_first", cold_ok && full_tank && L.add_water(50) == 50 && L.boiler_water == 30 && L.water == 50)
	var/obj/item/weapon/reagent_containers/glass/bucket/pail = new(platform_turf(141, 4))
	pail.reagents.clear_reagents()
	pail.reagents.add_reagent("water", 100)
	L.water = 0
	var/wants = L.takes_fuel(pail)
	L.attackby(pail, fireman)
	platform_check("boiler/filled_from_a_bucket", wants && L.water == 100 && !pail.reagents.has_reagent("water") && !L.takes_fuel(pail))
	qdel(pail)

	// A helper engine low on steam adds less pull.
	var/obj/structure/trains/W2 = L.connected.connected
	var/obj/structure/trains/locomotive/coal/H = new(platform_turf(142, 1))
	H.dir = NORTH
	H.fuel = 100
	H.on = TRUE
	W2.connected = H
	L.on = TRUE
	L.fuel = 100
	L.refresh_consist()
	var/both = L.consist_power
	H.pressure = 30
	L.refresh_consist()
	platform_check("boiler/weak_helper_pulls_less", both == L.haul + H.haul && boiler_near(L.consist_power, L.haul + H.haul * 0.5))
	var/before = H.water
	L.throttle = 3
	L.refresh_consist(6)
	L.throttle = 0
	platform_check("boiler/helper_uses_its_own_water", H.water < before && H.boiler_water == 60)
	var/obj/structure/trains/locomotive/coal/heavy/big = /obj/structure/trains/locomotive/coal/heavy
	var/obj/structure/trains/locomotive/coal/armored/heavy/plated = /obj/structure/trains/locomotive/coal/armored/heavy
	var/obj/structure/trains/locomotive/plain = /obj/structure/trains/locomotive
	platform_check("boiler/heavy_engines_carry_more", initial(big.max_water) == 600 && initial(big.water) == 600 && initial(big.max_boiler) == 100 && initial(big.steam_time) == 240 && initial(plated.max_water) == 600 && initial(plain.start_text) == "Start the engine")
	platform_check("boiler/plug_spare", ("fusible_plug" in icon_states('icons/obj/vehicles/train_platforms.dmi')) && ispath(/obj/item/fusible_plug))

// The walkable tender, shovelling, and water from a tower or a crane
// (train_water.dm).
/proc/platform_tender_run()
	for (var/y in 2 to 25)
		platform_track(150, y, NORTH)
	var/obj/structure/trains/platform/tender = platform_car("tender", 150, 12, NORTH)
	var/list/segs = platform_segments(tender)
	var/obj/structure/trains/platform/last = segs.len == 4 ? segs[4] : null
	var/list/states = icon_states('icons/obj/vehicles/train_platforms.dmi')
	platform_check("tender/built_in_one_piece", last && tender.icon_state == "loco_tender_1c" && !tender.density && last.density && tender.tender_store() == tender && last.tender_store() == tender && !tender.dismantle_problem() && tender.coupler_f && last.coupler_r && ("loco_tender_1l" in states) && ("loco_tender_4r" in states) && platform_parts_placed(segs))
	var/obj/structure/trains/locomotive/coal/L = new(platform_turf(150, 13))
	L.dir = NORTH
	L.fuel = 20
	L.on = TRUE
	L.connected = tender
	var/list/found = L.engine_tenders()
	platform_check("tender/found_next_to_the_engine", found.len == 1 && found[1] == tender && last.train_head() == L)

	var/mob/living/human/platform_rider/fireman = new(platform_turf(148, 12))
	var/obj/item/stack/ore/coal/C = new(platform_turf(148, 12))
	C.amount = 10
	last.attackby(C, fireman)
	var/obj/item/weapon/reagent_containers/glass/bucket/pail = new(platform_turf(148, 12))
	pail.reagents.clear_reagents()
	pail.reagents.add_reagent("water", 100)
	last.attackby(pail, fireman)
	platform_check("tender/loaded_by_hand", tender.tender_fuel == 150 && QDELETED(C) && tender.tender_water == 100 && !pail.reagents.has_reagent("water") && findtext(last.tender_text(), "10% full"))
	qdel(pail)

	var/first = L.shovel_coal(fireman)
	var/after_one = L.fuel == 50 && tender.tender_fuel == 120
	L.shovel_coal(fireman)
	var/third = L.shovel_coal(fireman)
	platform_check("tender/shovel_fills_the_firebox", first && after_one && third && L.fuel == 100 && tender.tender_fuel == 70 && !L.shovel_coal(fireman) && L.takes_fuel(new /obj/item/weapon/material/shovel(null)))
	L.water = 200
	L.tender_top_up()
	var/topped = L.water == 240 && tender.tender_water == 60
	L.water = 230
	L.refresh_consist()
	platform_check("tender/water_runs_to_the_engine", topped && L.water == 240 && tender.tender_water == 50)
	var/obj/structure/trains/locomotive/coal/lone = new(platform_turf(150, 20))
	lone.dir = NORTH
	lone.fuel = 10
	platform_check("tender/no_tender_no_shovelling", !lone.engine_tenders().len && !lone.shovel_coal(fireman) && lone.fuel == 10)
	var/obj/structure/trains/storage/tender/wagon = new(platform_turf(150, 24))
	platform_check("tender/wagon_carries_water", wagon.tender_store() == wagon && wagon.tender_add_water(700) == 600 && wagon.tender_water == 600 && findtext(wagon.tender_text(), "100%") && !segs[2].tender_load(null, fireman))
	qdel(wagon)

	var/obj/structure/rail_water/tower/TW = new(platform_turf(153, 12))
	var/list/reach = TW.takers()
	L.water = 0
	tender.tender_water = 0
	var/filled = TW.add_tower_water(7000) == 6000 && !TW.pump_water() && TW.source() == TW
	var/gave = TW.fill_takers()
	platform_check("water/tower_fills_what_stands_by", filled && reach.len == 2 && (L in reach) && (tender in reach) && gave == 2640 && L.water == 240 && tender.tender_water == 2400 && TW.water == 3360 && TW.fill_takers() == 0)
	var/obj/structure/rail_water/crane = new(platform_turf(152, 20))
	lone.water = 40
	var/list/near = crane.takers()
	platform_check("water/crane_draws_from_the_tower", crane.source() == TW && near.len == 1 && near[1] == lone && crane.fill_takers() == 200 && lone.water == 240 && TW.water == 3160)
	lone.water = 0
	qdel(TW)
	var/list/sheet = icon_states('icons/obj/vehicles/rail_water.dmi')
	platform_check("water/crane_needs_a_tower", !crane.source() && crane.fill_takers() == 0 && lone.water == 0 && ("water_tower" in sheet) && ("water_crane" in sheet))

// Cab stations and the main-line engine with its tender.
/proc/platform_cab_run()
	for (var/y in 2 to 25)
		platform_track(160, y, NORTH)
	var/obj/structure/train_car_kit/K = new(platform_turf(160, 4))
	K.set_kind("loco_mainline")
	var/long_kit = K.car_length() == 6 && K.assembly_problem(NORTH)
	qdel(K)
	var/obj/structure/trains/locomotive/coal/mainline/E = platform_car("loco_mainline", 160, 16, NORTH)
	var/list/body = istype(E) ? platform_segments(E.connected) : list()
	var/obj/structure/trains/platform/cab = body.len == 5 ? body[5] : null
	var/obj/structure/trains/platform/firebox = body.len == 5 ? body[4] : null
	platform_check("mainline/six_sections", long_kit && cab && E.body_length() == 6 && cab.seg_index == 6 && cab.loc == platform_turf(160, 11) && !cab.density && firebox.density && E.density && E.control_spot() == cab && cab.car_engine() == E)
	var/list/states = icon_states('icons/obj/vehicles/train_platforms.dmi')
	platform_check("mainline/art", E.icon_state == "loco_mainline_1c" && cab.icon_state == "loco_mainline_6c" && ("loco_mainline_1l" in states) && ("loco_mainline_6r" in states) && ("roof_loco_mainline_c" in states) && cab.roofed() && !firebox.roofed() && heavy_parts_placed(E) && platform_parts_placed(body))
	var/obj/structure/trains/platform/tender = platform_car("tender", 160, 10, NORTH)
	cab.connected = tender
	tender.tender_fuel = 300
	tender.tender_water = 500
	E.water = 0
	E.fuel = 100
	var/list/found = E.engine_tenders()
	E.tender_top_up()
	platform_check("mainline/runs_from_its_tender", found.len == 1 && found[1] == tender && E.max_water == 100 && E.water == 100 && tender.tender_water == 400 && E.has_coupling_end(TRUE) && cab.has_coupling_end(FALSE))

	var/mob/living/human/platform_rider/driver = new(platform_turf(161, 11))
	var/mob/living/human/platform_rider/stoker = new(platform_turf(160, 11))
	var/mob/living/human/platform_rider/fireman = new(platform_turf(159, 11))
	var/mob/living/human/platform_rider/guest = new(platform_turf(160, 10))
	platform_check("cab/stations_by_tile", E.has_stations() && E.cab_station(driver) == "driver" && E.cab_station(stoker) == "fire" && E.cab_station(fireman) == "fireman" && !E.cab_station(guest))
	guest.loc = platform_turf(164, 20)
	var/list/stand = E.station_controls("driver")
	var/list/door = E.station_controls("fire")
	var/list/side = E.station_controls("fireman")
	platform_check("cab/each_station_has_its_controls", stand.len == 8 && ("Sound the whistle" in stand) && ("Ring the bell" in stand) && ("Light the headlamp" in stand) && ("Throttle up" in stand) && ("Brake" in stand) && ("Sand the rails" in stand) && !("Light the fire" in stand) && door.len == 1 && door[1] == "Light the fire" && side.len == 1 && side[1] == "Injector off")
	E.work_control("Light the fire", driver)
	var/not_lit = !E.on
	E.work_control("Light the fire", stoker)
	var/lit = E.on
	E.work_control("Drop the fire", fireman)
	platform_check("cab/fire_worked_at_the_door", not_lit && lit && E.on)
	E.work_control("Reverser to backward", stoker)
	var/kept = E.reverser == 1
	E.work_control("Reverser to backward", driver)
	var/turned = E.reverser == -1
	E.work_control("Reverser to forward", driver)
	E.work_control("Throttle up", fireman)
	platform_check("cab/driver_has_the_regulator", kept && turned && E.reverser == 1 && E.throttle == 0)
	E.work_control("Injector off", driver)
	var/still_on = E.injector
	E.work_control("Injector off", fireman)
	var/off = !E.injector
	E.work_control("Injector on", fireman)
	platform_check("cab/injector_on_the_firemans_side", still_on && off && E.injector)

	var/obj/item/stack/ore/coal/lump = new(platform_turf(161, 11))
	cab.attackby(lump, driver)
	var/obj/item/weapon/material/shovel/spade = new(platform_turf(159, 11))
	cab.attackby(spade, fireman)
	var/refused = E.fuel == 100 && !QDELETED(lump) && tender.tender_fuel == 300
	cab.attackby(lump, stoker)
	cab.attackby(spade, stoker)
	platform_check("cab/firing_needs_the_door", refused && QDELETED(lump) && E.fuel == 145 && tender.tender_fuel == 270)

	E.refresh_consist()
	E.throttle = 3
	var/top = E.cruise_speed()
	E.throttle = 0
	platform_check("mainline/pulls_more_and_faster", E.haul == 60 && E.consist_weight >= 12 && E.consist_weight < 20 && E.pull_ratio() >= 1 && abs(top - 10 / 1.4) < 0.01)
	platform_check("mainline/steps_with_its_crew", platform_step(E, 3) == 3 && E.loc == platform_turf(160, 19) && cab.loc == platform_turf(160, 14) && tender.loc == platform_turf(160, 13) && driver.loc == platform_turf(161, 14) && stoker.loc == platform_turf(160, 14) && fireman.loc == platform_turf(159, 14) && E.cab_station(driver) == "driver" && heavy_parts_placed(E) && platform_parts_placed(body))

	// One-tile engines and the diesel are worked from one place.
	var/obj/structure/trains/locomotive/coal/small = new(platform_turf(164, 22))
	var/list/all = small.station_controls(small.cab_station(guest))
	var/list/diesel = train_car_layout("loco_diesel")
	var/list/steam = train_car_layout("loco_steam")
	var/list/armored = train_car_layout("loco_armored")
	platform_check("cab/small_engines_have_one_place", !small.has_stations() && small.cab_station(guest) == "all" && small.at_firebox(guest) && all.len == 10 && ("Sound the whistle" in all) && !diesel["stations"] && steam["stations"] && armored["stations"])

// Crashes (train_crashes.dm): a running train that hits something at speed
// derails its leading cars, breaks couplings, throws riders and spills cargo.
/obj/structure/platform_buffer
	name = "buffer stop"
	density = TRUE
	anchored = TRUE
/obj/structure/platform_buffer/ex_act(severity)
	return

/proc/platform_crash_run()
	for (var/y in 2 to 25)
		platform_track(169, y, NORTH)
		platform_track(173, y, NORTH)
	var/list/struck = platform_segments(platform_car("flatbed", 169, 22, NORTH))
	var/obj/structure/trains/locomotive/coal/E = new(platform_turf(169, 18))
	E.dir = NORTH
	E.fuel = 100
	var/list/A = platform_segments(platform_car("flatbed", 169, 17, NORTH))
	var/list/B = platform_segments(platform_car("flatbed", 169, 13, NORTH))
	var/obj/structure/trains/platform/A1 = A[1]
	var/obj/structure/trains/platform/A2 = A[2]
	var/obj/structure/trains/platform/A3 = A[3]
	var/obj/structure/trains/platform/A4 = A[4]
	var/obj/structure/trains/platform/B1 = B[1]
	var/obj/structure/trains/platform/S1 = struck[1]
	var/obj/structure/trains/platform/S3 = struck[3]
	var/obj/structure/trains/platform/S4 = struck[4]
	E.connected = A1
	A4.connected = B1
	var/mob/living/simple_animal/train_probe_dummy/rider = new(platform_turf(169, 15))
	var/mob/living/simple_animal/train_probe_dummy/bystander = new(platform_turf(169, 20))
	var/obj/structure/closet/crate/box = new(platform_turf(170, 11))
	var/turf/ahead = platform_turf(169, 19)

	// A crawl, and stock moved with no engine running, only bump.
	E.refresh_consist()
	E.rail_speed = 1
	var/hp = E.health
	var/bumped = E.rail_hit(ahead, NORTH) && hp - E.health <= 5
	E.rail_speed = 0
	bumped = bumped && E.rail_hit(ahead, NORTH, 3) && hp - E.health <= 20
	platform_check("crash/slow_is_a_bump", bumped && !A1.wrecked && !S4.wrecked && E.rear_coupling == 100 && rider.loc == platform_turf(169, 15) && rider.health == 400 && box.loc == platform_turf(170, 11))

	E.health = 1000
	S4.health = 1500
	E.on = TRUE
	E.throttle = 2
	E.rail_speed = 5
	var/crashed = E.rail_hit(ahead, NORTH, 2.4)
	platform_check("crash/stops_the_train", crashed && E.rail_speed == 0 && E.throttle == 0 && !E.on && !E.automovement && E.health == 1000 - 192)
	platform_check("crash/lead_cars_derailed", A1.wrecked && A2.wrecked && !A3.wrecked && !B1.wrecked && A1.health == 600 && A2.health == 600 && A1.name == "wrecked platform car" && train_crash_derailed(1.2) == 0 && train_crash_derailed(1.25) == 1 && train_crash_derailed(3.5) == 3)
	platform_check("crash/struck_car_takes_it", S4.wrecked && S3.wrecked && !S1.wrecked && S4.health == 600 && S1.front_coupling == 46 && S4.rear_coupling == 46)
	platform_check("crash/couplings_break", E.rear_coupling == 0 && !E.connected && A1.train_head() == A1 && A4.rear_coupling == 46 && A4.connected == B1)
	platform_check("crash/riders_thrown_and_hurt", rider.loc == platform_turf(169, 17) && rider.health == 400 - 14 && bystander.loc == platform_turf(169, 22) && bystander.health == 400 - 14)
	platform_check("crash/loose_cargo_slides", box.loc == platform_turf(170, 12) && !box.anchored)
	A1.repair_by(300)
	platform_check("crash/welded_back_on", !A1.wrecked && A1.health == 900 && A2.wrecked && train_consist_obstacle(A1, platform_turf(169, 18), NORTH) == A2)

	// Chained cargo breaks loose in a hard crash; a seated rider is held.
	var/obj/structure/trains/transport/flatbed/W = new(platform_turf(165, 5))
	W.dir = NORTH
	var/obj/structure/closet/crate/chained = new(W.loc)
	chained.anchored = TRUE
	W.transporting += chained
	W.crash_jolt(NORTH, 0.9, list())
	var/held = chained.anchored && chained.loc == W.loc
	W.crash_jolt(NORTH, 1.2, list())
	platform_check("crash/chained_cargo_breaks_loose", held && !chained.anchored && !(chained in W.transporting) && chained.loc == platform_turf(165, 7))

	// A heavy engine driven into a buffer stop at full speed comes off the
	// rails and dies; one weld gets it running again.
	var/obj/structure/trains/locomotive/coal/heavy/H = platform_car("loco_steam", 173, 8, NORTH)
	var/list/body = platform_segments(H.connected)
	var/obj/structure/trains/platform/cab = body[2]
	var/obj/structure/platform_buffer/stop = new(platform_turf(173, 24))
	var/mob/living/simple_animal/train_probe_dummy/driver = new(platform_turf(174, 6))
	var/mob/living/simple_animal/train_probe_dummy/seated = new(platform_turf(172, 6))
	var/obj/structure/bed/chair/seat = new(platform_turf(172, 6))
	seated.buckled = seat
	H.fuel = 200
	H.on = TRUE
	H.throttle = 3
	// Already running at speed: a train gathers way over many more tiles
	// than this stretch has (train_speed_gain()).
	H.rail_speed = 4.5
	H.drive()
	var/top = 0
	var/limit = 400
	while (H.driving && limit > 0)
		top = max(top, H.rail_speed)
		sleep(1)
		limit--
	platform_check("crash/driven_into_a_buffer_stop", !H.driving && top >= 4 && H.loc == platform_turf(173, 23) && !QDELETED(stop) && H.broken_down && !H.on && H.throttle == 0 && H.health == 0.4 * initial(H.health) && !cab.wrecked && H.engine_disabled())
	platform_check("crash/seat_holds_its_rider", seated.loc == seat.loc && seat.loc == platform_turf(172, cab.y) && driver.loc == platform_turf(174, cab.y) && driver.health < seated.health && seated.health < 400)
	H.health = min(initial(H.health), H.health + 600)
	platform_check("crash/engine_welds_in_one_pass", H.health >= initial(H.health) / 2)

	// Backing into something: the rear car leads and comes off first.
	var/list/C = platform_segments(platform_car("coach", 169, 8, NORTH))
	var/obj/structure/trains/locomotive/coal/P = new(platform_turf(169, 9))
	P.dir = NORTH
	P.connected = C[1]
	P.rail_speed = 4
	var/obj/structure/trains/platform/C1 = C[1]
	var/obj/structure/trains/platform/C3 = C[3]
	var/obj/structure/trains/platform/C4 = C[4]
	platform_check("crash/backing_rear_car_leads", C4.train_crash(stop, 1.5, SOUTH) && C4.wrecked && C3.wrecked && !C1.wrecked && P.rail_speed == 0 && !C4.train_crash(C1, 3, SOUTH))

// Brakes (train_brakes.dm): the driver's brake holds the engine, every car
// has a handbrake, and a guard at a brake van's wheel helps stop the train.
/proc/platform_brake_run()
	for (var/y in 2 to 25)
		platform_track(180, y, NORTH)
	var/obj/structure/trains/locomotive/coal/E = new(platform_turf(180, 10))
	E.dir = NORTH
	E.fuel = 100
	E.on = TRUE
	var/list/A = platform_segments(platform_car("flatbed", 180, 9, NORTH))
	var/obj/structure/train_car_kit/brake_van/K = new(platform_turf(180, 5))
	var/kit_named = K.name == "brake van kit" && K.car_kind == "brake_van" && K.car_length() == 4
	var/list/van = platform_segments(K.assemble(NORTH))
	var/obj/structure/trains/platform/A1 = A[1]
	var/obj/structure/trains/platform/A4 = A[4]
	var/obj/structure/trains/platform/V1 = van[1]
	var/obj/structure/trains/platform/V3 = van[3]
	var/obj/structure/trains/platform/V4 = van[4]
	E.connected = A1
	A4.connected = V1
	var/obj/structure/train_brake_wheel/wheel = locate() in platform_turf(179, 3)
	var/van_weight = 0
	for (var/obj/structure/trains/platform/P in van)
		van_weight += P.car_load_weight()
	platform_check("brake_van/built_with_a_wheel", kit_named && van.len == 4 && V1.name == "brake van" && wheel && wheel.brake_car() == V3 && (locate(/obj/structure/bed/chair) in platform_turf(181, 3)) && abs(van_weight - 4.4) < 0.01 && V3.roofed() && platform_parts_placed(van))
	platform_check("brakes/cars_have_handbrakes", !E.has_handbrake() && A1.has_handbrake() && V4.has_handbrake() && !E.set_handbrake(TRUE) && !E.handbrake)

	var/wound = wheel.wind(null)
	var/all_on = V1.handbrake && V3.handbrake && V4.handbrake && !A1.handbrake && wheel.icon_state == "brake_wheel_on" && E.train_handbrakes() == 1
	var/too_soon = !wheel.wind(null) && V1.handbrake
	wheel.next_use = 0
	platform_check("brakes/wheel_winds_the_whole_car", wound && all_on && too_soon && wheel.wind(null) && !V1.handbrake && !V4.handbrake && wheel.icon_state == "brake_wheel" && E.train_handbrakes() == 0)

	// By hand from beside a standing car only.
	var/mob/living/human/platform_rider/guard = new(platform_turf(179, 8))
	E.rail_speed = 1
	var/refused = !A1.work_handbrake(guard) && !A1.handbrake && !E.work_handbrake(guard)
	E.rail_speed = 0
	platform_check("brakes/pinned_down_by_hand", refused && A4.set_handbrake(TRUE) && A1.handbrake && A4.handbrake && !V1.handbrake && E.train_handbrakes() == 1)

	// The brakes slow the train by the share of its weight they hold.
	E.refresh_consist()
	var/total = E.consist_weight
	var/hand_only = E.brake_decel()
	E.braking = TRUE
	var/with_engine = E.brake_decel()
	wheel.next_use = 0
	wheel.wind(null)
	E.refresh_consist()
	var/whole = E.brake_decel()
	platform_check("brakes/share_of_the_weight", abs(total - 9.5) < 0.01 && E.consist_own == 3 && abs(hand_only - 1.2 * 2.1 / 9.5) < 0.01 && abs(with_engine - 1.2 * 5.1 / 9.5) < 0.01 && abs(whole - 1.2) < 0.01)
	// Handbrakes left on drag while the engine pulls.
	var/dragging = E.pull_ratio()
	A1.set_handbrake(FALSE)
	wheel.next_use = 0
	wheel.wind(null)
	E.braking = FALSE
	E.refresh_consist()
	platform_check("brakes/left_on_they_drag", E.brake_decel() == 0 && E.pull_ratio() >= 1 && dragging < 0.6 && abs(E.drag_weight() - 9.5) < 0.01)

	// The guard shortens the stop: the same train from the same speed, first
	// with the engine's brake alone, then with the van's wound on as it runs.
	E.throttle = 0
	E.braking = TRUE
	E.rail_speed = 3
	var/from = E.y
	E.drive()
	drive_wait(E)
	var/alone = E.y - from
	E.braking = TRUE
	E.rail_speed = 3
	from = E.y
	E.drive()
	sleep(1)
	wheel.next_use = 0
	var/on_the_move = E.driving && wheel.wind(null) && E.consist_braked > 4 && V1.handbrake
	drive_wait(E)
	var/helped = E.y - from
	platform_check("brakes/guard_shortens_the_stop", on_the_move && alone >= 4 && helped >= 1 && helped < alone && V4.loc == platform_turf(180, 2 + alone + helped) && wheel.loc == platform_turf(179, 3 + alone + helped))

// Rolling stock (train_rolling.dm): cars keep their momentum when a moving
// train parts or when something runs into them.
/proc/platform_roll(obj/structure/trains/head, limit = 60)
	var/steps = 0
	while (steps < limit && head.roll_step() > 0)
		steps++
	return steps

/proc/platform_rolling_run()
	var/obj/structure/trains/locomotive/coal/E = drive_train(188, 6, 3)
	var/obj/structure/trains/W1 = E.connected
	var/obj/structure/trains/W2 = W1.connected
	var/obj/structure/trains/W3 = W2.connected
	var/mob/living/human/platform_rider/guard = new(platform_turf(187, 3))
	// The train runs north at speed and the coupling behind the first wagon breaks.
	E.refresh_consist()
	E.driving = TRUE
	E.rail_speed = 4
	var/list/motion = W3.train_motion()
	var/moving = motion && motion[1] == 4 && motion[2] == 6 && motion[3] && W3.travel_way(motion) == NORTH
	W1.damage_coupling(FALSE, 100)
	platform_check("rolling/parted_cars_roll_on", moving && !W1.connected && W2.train_head() == W2 && W2.roll_speed == 4 && W2.roll_weight == 2 && !E.roll_speed && W1.train_head() == E && W3.train_rolling() && !W3.work_handbrake(guard))
	E.driving = FALSE
	E.rail_speed = 0
	platform_step(E, 14)
	var/rolled = platform_roll(W2, 3)
	platform_check("rolling/slows_by_its_weight", rolled == 3 && W2.y == 7 && W3.y == 6 && abs(W2.roll_speed - 3.4) < 0.01 && W2.roll_impact() > 0.8)
	// A handbrake wound on aboard stops the runaway.
	W3.set_handbrake(TRUE)
	rolled = platform_roll(W2)
	platform_check("rolling/handbrake_stops_a_runaway", rolled == 3 && W2.y == 10 && W2.roll_speed == 0 && !W2.automovement && !W3.train_rolling())
	W3.set_handbrake(FALSE)

	// A runaway hits what is in its way, and the cars it hits roll off.
	var/started = W3.start_rolling(5, NORTH) && W2.roll_speed == 5
	var/hp = W1.health
	rolled = platform_roll(W2)
	platform_check("rolling/runaway_crashes", started && rolled == 8 && W2.y == 18 && W2.roll_speed == 0 && W1.health < hp && E.roll_speed > 1 && E.train_head() == E)
	rolled = platform_roll(E)
	platform_check("rolling/struck_cars_roll_away", rolled >= 3 && E.y == 20 + rolled && W1.y == E.y - 1 && E.roll_speed == 0)

	// Uncoupled by hand as they roll, both parts keep going.
	W2.start_rolling(3, NORTH)
	var/slipped = W2.couple_end(FALSE, guard)
	platform_check("rolling/slipped_car_rolls_on", slipped && !W2.connected && W2.roll_speed == 3 && W3.roll_speed == 3 && W3.train_head() == W3)
	W2.stop_rolling()
	W3.stop_rolling()

	// Standing cars: a handbrake or a gentle touch leaves them where they are.
	W3.set_handbrake(TRUE)
	var/held = !W3.shoved(list(4, 5, TRUE), NORTH)
	W3.set_handbrake(FALSE)
	var/gentle = !W3.shoved(list(1, 5, TRUE), NORTH) && !W3.roll_speed
	platform_check("rolling/brakes_hold_against_a_blow", held && gentle && W3.shoved(list(4, 5, TRUE), NORTH) && W3.roll_speed == 4 && W3.train_heading() == NORTH)
	W3.stop_rolling()
	// Hit on its front end, a train rolls away tail first.
	W2.connected = W3
	platform_check("rolling/rolls_away_from_the_blow", W2.shoved(list(3, 2, TRUE), SOUTH) && W3.train_head() == W3 && W3.roll_speed > 1 && W3.train_heading() == SOUTH && W2.train_heading() == SOUTH && W3.connected == W2)
	W3.stop_rolling()

// Adhesion (train_adhesion.dm): too much throttle on a heavy start spins the
// wheels until the driver eases off or sands the rails.
/proc/platform_adhesion_run()
	var/obj/structure/trains/locomotive/coal/H = drive_train(196, 16, 14, /obj/structure/trains/storage/closed)
	var/obj/structure/trains/locomotive/coal/light = new(platform_turf(198, 22))
	light.on = TRUE
	light.fuel = 100
	light.refresh_consist()
	light.throttle = 3
	H.refresh_consist()
	var/ratio = H.pull_ratio()
	H.throttle = 3
	var/full = H.wheels_slip(1)
	H.rail_speed = 2
	var/at_speed = H.wheels_slip(1)
	H.rail_speed = 0
	H.throttle = 0
	platform_check("adhesion/full_throttle_slips_a_heavy_start", ratio < 1 && full && !at_speed && !H.wheels_slip(1) && !light.wheels_slip(1) && !light.wheels_slip(0.6) && H.rail_grip() == 1 && abs(H.throttle_share()) < 0.01)
	// A train at its rated load starts on notch 2 in the dry, not in the wet.
	var/power = H.consist_power
	H.consist_power = H.drag_weight()
	H.throttle = 2
	platform_check("adhesion/wet_rails_grip_less", H.pull_ratio() == 1 && !H.wheels_slip(1) && H.wheels_slip(0.6))
	H.consist_power = power

	// Driven: full throttle from a stand gets nowhere until the rails are sanded.
	H.throttle = 3
	var/from = H.y
	H.locomotive()
	sleep(25)
	var/spinning = H.driving && H.y == from && H.slipping >= 2 && H.rail_speed == 0 && H.fuel < 100
	var/sanded = H.sand_rails(null) && H.sand == 19 && H.sanding == 8 && !H.wheels_slip(1)
	sleep(30)
	var/away = H.y > from && H.slipping == 0 && H.sanding < 8
	H.throttle = 0
	H.braking = TRUE
	drive_wait(H, 300)
	platform_check("adhesion/sand_gets_a_heavy_train_away", spinning && sanded && away && !H.driving)

	var/mob/living/human/platform_rider/fireman = new(platform_turf(195, H.y))
	H.sand = 0
	var/empty = !H.sand_rails(null) && H.sanding < 8
	var/obj/item/stack/ore/glass/pile = new(platform_turf(195, H.y))
	pile.amount = 25
	H.attackby(pile, fireman)
	var/list/controls = H.station_controls("all")
	platform_check("adhesion/sandbox_is_filled_with_sand", empty && H.sand == 20 && pile.amount == 5 && ("Sand the rails" in controls) && findtext(H.control_summary(), "Sandbox: 20 of 20"))

// Shunting (train_shunting.dm): a slow approach buffers up, automatic
// couplers lock by themselves and let go by their lever.
/proc/platform_shunting_run()
	var/obj/structure/trains/locomotive/coal/E = drive_train(204, 6, 1)
	var/obj/structure/trains/transport/flatbed/S = new(platform_turf(204, 10))
	S.dir = NORTH
	var/mob/living/human/platform_rider/shunter = new(platform_turf(203, 9))
	// An automatic coupler is a part like any coupling.
	var/obj/item/train_coupling/plain = S.remove_coupling(FALSE)
	var/obj/item/train_coupling/automatic/knuckle = new(platform_turf(203, 10))
	var/fitted = plain && !plain.automatic && S.fit_coupling(FALSE, knuckle) && S.rear_auto && !S.front_auto && S.rear_coupling == 100 && S.coupler_r.icon_state == "knuckle_b_free" && S.coupler_f.icon_state == "coupler_f_free" && S.coupler_r.name == "automatic coupler"
	S.damage_coupling(FALSE, 30)
	var/obj/item/train_coupling/back = S.remove_coupling(FALSE)
	platform_check("shunting/automatic_coupler_fitted", fitted && findtext(S.coupling_text(FALSE), "missing") && istype(back, /obj/item/train_coupling/automatic) && back.condition == 70 && !S.rear_auto && S.coupler_r.icon_state == "coupler_b_none" && S.fit_coupling(FALSE, back) && S.rear_auto && findtext(S.coupling_text(FALSE), "automatic coupler is damaged (70%)"))
	var/list/states = icon_states('icons/obj/vehicles/train_platforms.dmi')
	var/missing = 0
	for (var/kind in list("free", "linked", "broken"))
		for (var/end in list("f", "b"))
			if (!("knuckle_[end]_[kind]" in states))
				missing++
	platform_check("shunting/art_states", !missing && ("knuckle_item" in states))

	// A slow approach stops against standing cars and marks nothing.
	E.refresh_consist()
	E.driving = TRUE
	E.rail_speed = 0.8
	var/hp = E.health
	var/shp = S.health
	var/ran = platform_step(E, 10)
	platform_check("shunting/slow_approach_buffers_up", ran == 3 && E.y == 9 && E.health == hp && S.health == shp && S.y == 10 && S.train_head() == S && !S.roll_speed)
	// A manual click on the approaching engine's free coupler must not hitch.
	var/obj/structure/trains/prior_link = E.connected
	E.throttle = 1
	var/refused_free = E.train_under_power() && E.coupler_use(shunter, TRUE) && !S.connected && E.connected == prior_link
	E.throttle = 0
	platform_check("shunting/free_coupler_not_under_power", refused_free)
	// Brisker, it is a bump again; one automatic coupler alone does not lock.
	E.rail_speed = 1.3
	ran = platform_step(E, 2)
	platform_check("shunting/brisk_bump_still_marks", ran == 0 && E.health < hp && !E.auto_couplers_meet(S) && S.train_head() == S)
	// Two automatic couplers pushed together lock.
	hp = E.health
	E.front_auto = TRUE
	E.update_couplers()
	var/meet = E.auto_couplers_meet(S) && S.auto_couplers_meet(E) && E.end_facing(S) && S.end_facing(E) == FALSE && isnull(E.end_facing(shunter))
	ran = platform_step(E, 2)
	platform_check("shunting/automatic_couplers_lock", meet && ran == 0 && E.y == 9 && E.health == hp && S.connected == E && E.train_head() == S && E.coupler_f.icon_state == "knuckle_f_linked" && S.coupler_r.icon_state == "knuckle_b_linked" && !E.auto_couplers_meet(S))

	// The lever lets go at once, but not while the engine pulls.
	E.throttle = 1
	var/tight = E.lever_uncouples(TRUE) && !E.lever_uncouples(FALSE) && E.coupler_use(shunter, TRUE) && S.connected == E
	E.throttle = 0
	platform_check("shunting/lever_not_under_power", tight)
	// Let go as the train coasts, the car in front rolls on by itself.
	E.rail_speed = 3
	var/let_go = E.coupler_use(shunter, TRUE)
	platform_check("shunting/lever_lets_go_on_the_move", let_go && !S.connected && S.train_head() == S && S.roll_speed == 3 && !E.roll_speed && E.coupler_f.icon_state == "knuckle_f_free")
	S.stop_rolling()
	E.rail_speed = 0
	E.driving = FALSE

	// A car that rolls gently onto another locks to it and comes to a stand.
	var/obj/structure/trains/transport/flatbed/T = new(platform_turf(204, 13))
	T.dir = NORTH
	T.rear_auto = TRUE
	S.front_auto = TRUE
	var/rolling = S.start_rolling(1.4, NORTH)
	var/rolled = platform_roll(S)
	platform_check("shunting/rolling_car_couples", rolling && rolled == 2 && S.y == 12 && S.roll_speed == 0 && T.connected == S && S.train_head() == T && !T.roll_speed && T.health == initial(T.health))

	// Too fast, the couplers do not catch: the cars are knocked away.
	E.refresh_consist()
	E.driving = TRUE
	E.rail_speed = 2.4
	ran = platform_step(E, 6)
	platform_check("shunting/too_fast_knocks_away", ran == 2 && E.y == 11 && !S.end_neighbour(FALSE) && E.train_head() == E && T.roll_speed > 1 && T.connected == S)
	T.stop_rolling()
	E.rail_speed = 0
	E.driving = FALSE

// Servicing (train_servicing.dm): axle boxes run on oil, and a steam engine's
// fire fills with clinker until it is cleaned over an ash pit.
/proc/platform_servicing_run()
	var/obj/structure/trains/locomotive/coal/E = drive_train(206, 6, 2)
	var/obj/structure/trains/W1 = E.connected
	var/obj/structure/trains/W2 = W1.connected
	var/mob/living/human/platform_rider/fitter = new(platform_turf(205, 5))
	E.refresh_consist()
	var/fresh = W1.axle_oil == 600 && W1.axle_state() == "oiled" && !W1.axle_text() && !E.consist_hot
	E.refresh_consist(6)
	platform_check("servicing/axles_wear_as_the_train_runs", fresh && W1.axle_oil == 594 && W2.axle_oil == 594 && E.axle_oil == 594 && !E.consist_hot)

	// Run dry, a box runs hot and drags.
	var/base = E.drag_weight()
	W1.axle_oil = 50
	var/dry = W1.axle_state() == "dry" && findtext(W1.axle_text(), "running dry")
	W1.axle_oil = 3
	E.refresh_consist(6)
	platform_check("servicing/hot_box_drags", dry && W1.axle_oil == -3 && W1.axle_state() == "hot" && E.consist_hot == W1.car_load_weight() && E.drag_weight() == base + E.consist_hot && E.consist_braked == 0 && findtext(W1.axle_text(), "running hot"))
	// Run hot for long, the axle seizes and holds the car like a brake.
	W1.axle_oil = -148
	E.refresh_consist(6)
	var/seized = W1.axle_seized && W1.axle_state() == "seized" && E.consist_braked == W1.car_load_weight() && E.consist_hot == 0 && E.brake_decel() > 0 && !W2.shoved(list(4, 5, TRUE), NORTH)
	E.refresh_consist(6)
	platform_check("servicing/dry_axle_seizes", seized && W1.axle_oil == -154)
	W2.roll_since = 6
	W2.roll_refresh()
	platform_check("servicing/rolling_cars_wear_too", W2.axle_oil == 570 && W2.roll_since == 0 && W2.roll_weight == W2.car_load_weight())
	W2.stop_rolling()

	// Oil will not free a seized axle: the bearing is changed, then it is oiled.
	var/obj/item/weapon/reagent_containers/glass/bucket/can = new(platform_turf(205, 5))
	can.reagents.clear_reagents()
	can.reagents.add_reagent("water", 20)
	var/not_oil = !train_oil_in(can) && !W1.service_use(can, fitter)
	can.reagents.clear_reagents()
	can.reagents.add_reagent("fat_oil", 12)
	var/refused = train_oil_in(can) == "fat_oil" && W1.service_use(can, fitter) && W1.axle_seized && can.reagents.get_reagent_amount("fat_oil") == 12
	W1.change_bearing()
	var/freed = !W1.axle_seized && W1.axle_oil == 0 && W1.axle_state() == "hot"
	W1.oil_axles()
	E.refresh_consist()
	platform_check("servicing/bearing_changed_then_oiled", not_oil && refused && freed && W1.axle_oil == 600 && W1.axle_state() == "oiled" && E.consist_hot == 0 && E.consist_braked == 0 && W1.service_use(can, fitter) && can.reagents.get_reagent_amount("fat_oil") == 12)
	// A long car is oiled as one.
	var/obj/structure/trains/platform/flat = platform_car("long_flatbed", 206, 22, NORTH)
	var/list/segs = flat.car_segments()
	for (var/obj/structure/trains/platform/P in segs)
		P.axle_oil = 10
	var/obj/structure/trains/platform/last = segs[segs.len]
	last.oil_axles()
	var/oiled = 0
	var/speakers = 0
	for (var/obj/structure/trains/platform/P in segs)
		if (P.axle_oil == 600)
			oiled++
		if (P.axle_speaker())
			speakers++
	platform_check("servicing/long_car_oiled_as_one", segs.len == 8 && oiled == 8 && speakers == 1 && flat.service_sections().len == 8)

	// The fire fills with clinker as it works and steams worse for it.
	E.fuel = 100
	var/clean = E.clinker == 0 && E.clinker_factor() == 1 && E.fire_factor() == 1
	E.steam_use(3, E.haul, 20)
	var/dirty = abs(E.clinker - 5) < 0.01 && E.clinker_factor() == 1
	E.clinker = 70
	var/half = abs(E.clinker_factor() - 0.75) < 0.01 && abs(E.fire_factor() - 0.75) < 0.01 && findtext(E.state_text(), "dirty with clinker")
	E.clinker = 100
	platform_check("servicing/clinker_chokes_the_fire", clean && dirty && half && abs(E.fire_factor() - 0.5) < 0.01 && findtext(E.state_text(), "choked with clinker"))
	// It is cleaned with a rake at the firebox, over an ash pit.
	var/mob/living/human/platform_rider/fireman = new(platform_turf(205, 6))
	var/obj/item/train_fire_rake/rake = new(platform_turf(205, 6))
	var/no_pit = !E.ash_pit() && !E.clean_fire(fireman) && E.clinker == 100 && E.service_use(rake, fireman)
	var/obj/structure/rail_ash_pit/pit = new(platform_turf(206, 6))
	pit.update_icon()
	E.fuel = 50
	E.clean_fire_into(E.ash_pit())
	platform_check("servicing/fire_cleaned_over_an_ash_pit", no_pit && E.ash_pit() == pit && E.clinker == 0 && E.fuel == 40 && pit.ash == 1 && pit.icon_state == "ash_pit_ash" && pit.dir == NORTH && abs(E.fire_factor() - 0.8) < 0.01)
	// A full pit takes no more until it is dug out.
	pit.ash = 10
	pit.update_icon()
	E.clinker = 60
	var/full = pit.icon_state == "ash_pit_full" && !E.clean_fire(fireman) && E.clinker == 60
	var/out = pit.dig_out(platform_turf(205, 7))
	var/heaps = 0
	for (var/obj/item/wood_ash/A in platform_turf(205, 7))
		heaps++
	var/list/states = icon_states('icons/obj/vehicles/train_platforms.dmi')
	platform_check("servicing/ash_pit_dug_out", full && out == 3 && heaps == 3 && pit.ash == 0 && pit.icon_state == "ash_pit" && !pit.dig_out() && ("ash_pit" in states) && ("ash_pit_ash" in states) && ("ash_pit_full" in states) && ("fire_rake" in states))

// Deeper servicing (train_servicing.dm): brake shoes, boiler scale and the
// overhaul; and the depot (train_depot.dm): coaling stage and sand bin.
/proc/platform_depot_run()
	var/obj/structure/trains/locomotive/coal/E = drive_train(212, 12, 2)
	var/obj/structure/trains/W1 = E.connected
	var/obj/structure/trains/W2 = W1.connected
	var/mob/living/human/platform_rider/fitter = new(platform_turf(211, 12))
	E.refresh_consist()
	var/sound = W1.brake_shoes == 300 && W1.brake_hold() == 1 && !W1.shoe_text()
	// A brake that is on wears its shoes: a handbrake, and the driver's brake.
	W1.handbrake = TRUE
	E.refresh_consist(6)
	var/pinned = W1.brake_shoes == 294 && W2.brake_shoes == 300 && E.brake_shoes == 300 && E.consist_braked == W1.car_load_weight()
	E.braking = TRUE
	E.refresh_consist(6)
	platform_check("depot/brake_on_wears_the_shoes", sound && pinned && W1.brake_shoes == 288 && E.brake_shoes == 294 && W2.brake_shoes == 300)
	// Worn out, the brake barely holds.
	W1.brake_shoes = 40
	var/thin = findtext(W1.shoe_text(), "worn thin") && W1.brake_hold() == 1
	W1.brake_shoes = 4
	E.brake_shoes = 2
	E.refresh_consist(6)
	platform_check("depot/worn_shoes_barely_hold", thin && W1.brake_shoes == 0 && E.brake_shoes == 0 && abs(W1.brake_hold() - 0.3) < 0.01 && abs(E.consist_braked - 0.3 * W1.car_load_weight()) < 0.01 && abs(E.consist_own - 0.3 * E.car_load_weight()) < 0.01 && findtext(W1.shoe_text(), "worn out"))
	E.braking = FALSE
	// A train that rolls free wears them too.
	W2.handbrake = TRUE
	W2.brake_shoes = 3
	W2.roll_since = 6
	W2.roll_refresh()
	var/rolled = W2.brake_shoes == 0 && abs(W2.roll_braked - 0.3 * W2.car_load_weight()) < 0.01
	W2.stop_rolling()
	W2.handbrake = FALSE
	W1.handbrake = FALSE
	// A new set makes the brake whole; sound shoes are left alone.
	var/obj/item/train_brake_shoes/shoes = new(platform_turf(211, 12))
	W1.fit_shoes()
	E.refresh_consist()
	platform_check("depot/new_shoes_fitted", rolled && W1.brake_shoes == 300 && W1.brake_hold() == 1 && E.consist_braked == 0 && W1.service_use(shoes, fitter) && !QDELETED(shoes) && W2.brake_shoes == 0)

	// The boiler: boiled water leaves scale, and a scaled boiler steams worse.
	E.fuel = 100
	E.boiler_water = 60
	var/clean = E.scale == 0 && E.scale_factor() == 1 && !E.washout_due() && !("Wash out the boiler" in E.extra_controls())
	E.steam_use(3, E.haul, 10)
	var/scaled = abs(E.scale - 10 * 100 / (12 * 240)) < 0.001
	E.scale = 70
	var/poor = abs(E.scale_factor() - 0.8) < 0.01 && abs(E.fire_factor() - 0.8) < 0.01 && findtext(E.state_text(), "scaling up") && E.washout_due() && ("Wash out the boiler" in E.extra_controls())
	E.scale = 100
	platform_check("depot/scale_spoils_the_boiler", clean && scaled && poor && abs(E.fire_factor() - 0.6) < 0.01 && findtext(E.state_text(), "thick with scale"))
	// It is washed out cold, with water from a tower within reach.
	var/lit = !E.washout_water() && !E.wash_out_by(fitter) && E.scale == 100
	E.on = FALSE
	E.pressure = 80
	var/obj/structure/rail_water/tower/TW = new(platform_turf(215, 12))
	TW.water = 200
	var/dry = !E.washout_water()
	TW.water = 1000
	var/hot = E.washout_water() == TW && !E.wash_out_by(fitter) && E.scale == 100 && TW.water == 1000
	E.boiler_water = 5
	E.wash_out(TW)
	platform_check("depot/boiler_washed_out_cold", lit && dry && hot && E.scale == 0 && TW.water == 700 && E.boiler_water == E.max_boiler && E.pressure == 0 && E.fire_factor() == 1)

	// The engine wears with the distance it works and pulls less for it.
	E.on = TRUE
	var/counted = E.mileage == 18
	E.mileage = 0
	E.refresh_consist()
	var/fresh = counted && E.mileage == 0 && E.wear_factor() == 1 && E.consist_power == E.haul && !E.overhaul_text()
	E.mileage = 4997
	E.refresh_consist(6)
	var/due = E.mileage == 5003 && findtext(E.overhaul_text(), "due for an overhaul")
	E.mileage = 7500
	E.refresh_consist()
	var/weak = abs(E.wear_factor() - 0.85) < 0.001 && abs(E.consist_power - 0.85 * E.haul) < 0.001
	E.mileage = 20000
	platform_check("depot/worn_engine_pulls_less", fresh && due && weak && abs(E.wear_factor() - 0.7) < 0.001)
	// The overhaul is shed work, with iron or steel for the parts.
	var/outside = !E.engine_shed() && !E.overhaul_by(fitter)
	var/obj/structure/rail_warehouse/shed = new(platform_turf(210, 12))
	shed.dir = EAST
	var/obj/item/stack/material/iron/bars = new(platform_turf(211, 12))
	bars.amount = 9
	var/few = !train_overhaul_parts(bars)
	bars.amount = 12
	var/obj/item/stack/material/wood/planks = new(platform_turf(211, 12))
	planks.amount = 20
	var/parts = train_overhaul_parts(bars) && !train_overhaul_parts(planks) && !train_overhaul_parts(null)
	var/running = !E.overhaul_by(fitter) && E.mileage == 20000
	E.overhaul()
	E.refresh_consist()
	platform_check("depot/overhauled_in_the_shed", outside && E.engine_shed() == shed && few && parts && running && E.mileage == 0 && E.wear_factor() == 1 && E.consist_power == E.haul)

	// The coaling stage fills fireboxes and bunkers from its heap.
	var/obj/structure/rail_depot/coal_stage/stage = new(platform_turf(210, 13))
	var/obj/item/stack/ore/coal/C = new(platform_turf(211, 12))
	C.amount = 10
	var/empty = stage.icon_state == "coal_stage_empty" && !stage.fill_takers()
	var/loaded = stage.load_fuel(C) == 10 && stage.fuel == 150 && stage.icon_state == "coal_stage" && !stage.load_fuel(shoes)
	var/list/near = stage.takers()
	E.fuel = 20
	platform_check("depot/coaling_stage_fills_the_firebox", empty && loaded && near.len == 1 && near[1] == E && stage.fill_takers() == 80 && E.fuel == 100 && stage.fuel == 70 && stage.fill_takers() == 0)
	var/obj/structure/trains/platform/tender = platform_car("tender", 212, 22, NORTH)
	var/obj/structure/trains/platform/store = tender.tender_store()
	var/obj/structure/rail_depot/coal_stage/second = new(platform_turf(210, 21))
	store.tender_fuel = 1400
	second.fuel = 3000
	second.update_icon()
	var/high = second.icon_state == "coal_stage_full"
	var/list/by = second.takers()
	platform_check("depot/coaling_stage_fills_the_tender", high && by.len == 1 && by[1] == store && second.fill_takers() == 100 && store.tender_fuel == 1500 && second.fuel == 2900 && second.fill_takers() == 0)

	// The sand bin fills sandboxes.
	var/obj/structure/rail_depot/sand_bin/bin = new(platform_turf(214, 13))
	var/obj/item/stack/ore/glass/pile = new(platform_turf(211, 12))
	pile.amount = 30
	var/bare = bin.icon_state == "sand_bin_empty" && !bin.fill_takers()
	var/binned = bin.load_sand(pile) == 30 && bin.sand == 30 && bin.icon_state == "sand_bin" && !bin.load_sand(C)
	E.sand = 5
	var/list/sheet = icon_states('icons/obj/vehicles/rail_water.dmi')
	platform_check("depot/sand_bin_fills_the_sandbox", bare && binned && E.sand_room() == 15 && bin.fill_takers() == 15 && E.sand == 20 && bin.sand == 15 && bin.fill_takers() == 0 && ("coal_stage" in sheet) && ("coal_stage_empty" in sheet) && ("coal_stage_full" in sheet) && ("sand_bin" in sheet) && ("sand_bin_empty" in sheet) && ("brake_shoes" in icon_states('icons/obj/vehicles/train_platforms.dmi')))

// Snow on the line (train_snow.dm): the leading car pushes into it and the
// train slows, unless a snowplough leads and clears it.
/proc/platform_snow_run()
	var/obj/structure/trains/locomotive/coal/E = drive_train(218, 12, 2)
	var/obj/structure/trains/W1 = E.connected
	var/obj/structure/trains/W2 = W1.connected
	E.refresh_consist()
	E.throttle = 3
	var/turf/T = E.loc
	var/list/end = E.leading_end()
	E.meet_snow()
	var/full = E.cruise_speed()
	var/clear = full > 0 && E.snow_factor == 1 && E.drive_tail == W2 && end[1] == E && end[2] == TRUE && !T.rail_snow() && !T.plough_snow()
	T.weather_snow = 1
	E.meet_snow()
	var/light = abs(E.snow_factor - 0.75) < 0.001 && abs(E.cruise_speed() - 0.75 * full) < 0.001 && T.rail_snow() == 1
	T.weather_snow = 2
	E.meet_snow()
	var/deep = abs(E.snow_factor - 0.5) < 0.001 && abs(E.cruise_speed() - 0.5 * full) < 0.001
	T.weather_snow = 0
	E.meet_snow()
	platform_check("snow/drifts_slow_the_train", clear && light && deep && E.snow_factor == 1 && E.cruise_speed() == full)

	// A plough at the leading end throws the snow clear.
	var/bare = !E.plough_at(TRUE) && !E.plough_text() && !E.coupler_f.overlays.len
	E.set_plough(TRUE, TRUE)
	T.weather_snow = 2
	var/generation = T.snowfall_ground_generation
	E.meet_snow()
	platform_check("snow/plough_clears_the_line", bare && E.plough_at(TRUE) && !E.plough_at(FALSE) && E.snow_factor == 1 && T.weather_snow == 0 && T.snowfall_ground_generation != generation && E.coupler_f.overlays.len == 1 && !E.coupler_r.overlays.len && findtext(E.plough_text(), "front end"))

	// Only the end that leads counts: backing up, the last car goes first.
	E.reverser = -1
	end = E.leading_end()
	var/turf/back = W2.loc
	back.weather_snow = 1
	E.meet_snow()
	var/backing = end[1] == W2 && end[2] == FALSE && abs(E.snow_factor - 0.75) < 0.001 && back.weather_snow == 1
	W2.set_plough(FALSE, TRUE)
	E.meet_snow()
	platform_check("snow/only_the_leading_end_ploughs", backing && E.snow_factor == 1 && back.weather_snow == 0)

	// It comes off again as a part.
	var/mob/living/human/platform_rider/fitter = new(platform_turf(217, 12))
	var/obj/item/train_snowplough/part = W2.remove_plough(FALSE, platform_turf(217, 11))
	platform_check("snow/plough_is_a_part", istype(part) && part.loc == platform_turf(217, 11) && !W2.plough_at(FALSE) && !W2.remove_plough(FALSE) && !W2.coupler_r.overlays.len && !E.plough_use(fitter, TRUE, null) && ("plough_f" in icon_states('icons/obj/vehicles/train_plough.dmi')) && ("plough_b" in icon_states('icons/obj/vehicles/train_plough.dmi')) && ("plough_item" in icon_states('icons/obj/vehicles/train_platforms.dmi')))

// Bulk freight (train_freight.dm): ore, coal and sand as a count on an open
// wagon or a hopper, and the hopper's drop through its floor.
/proc/platform_freight_run()
	for (var/ty in 2 to 25)
		platform_track(223, ty, NORTH)
	var/obj/structure/trains/platform/wagon = platform_car("open_wagon", 223, 12, NORTH)
	var/list/segs = wagon.car_segments()
	var/obj/structure/trains/platform/store = wagon.bulk_store()
	var/obj/structure/trains/platform/last = segs[segs.len]
	var/base = 0
	for (var/obj/structure/trains/platform/P in segs)
		base += P.car_load_weight()
	var/list/flat = train_car_layout("long_flatbed")
	var/bare = segs.len == 8 && wagon.bulk_max() == 600 && store && store.seg_index == 1 && last.bulk_store() == store && !wagon.is_hopper() && findtext(wagon.bulk_text(), "is empty") && !flat["bulk"] && !wagon.bulk_overlay()
	var/obj/item/stack/ore/coal/C = new(platform_turf(220, 12))
	C.amount = 40
	var/took = last.bulk_load(C)
	var/shown = 0
	var/weight = 0
	for (var/obj/structure/trains/platform/P in segs)
		weight += P.car_load_weight()
		if (P.bulk_fill == 1 && P.bulk_path == "/obj/item/stack/ore/coal" && P.bulk_overlay())
			shown++
	platform_check("freight/bulk_is_a_count_on_the_car", bare && took == 40 && store.bulk_amount == 40 && last.bulk_amount == 0 && shown == 8 && abs(weight - base - 0.2) < 0.001 && train_bulk_tone(store.bulk_path) == "coal" && train_bulk_name(store.bulk_path) == "mineral coal" && findtext(wagon.bulk_text(), "40 of 600"))
	// One kind at a time, and no more than the car holds.
	var/obj/item/stack/ore/iron/I = new(platform_turf(220, 12))
	I.amount = 30
	var/other = !wagon.bulk_load(I) && I.amount == 30 && train_bulk_tone("[I.type]") == "ore"
	store.bulk_amount = 590
	var/obj/item/stack/ore/coal/more = new(platform_turf(220, 12))
	more.amount = 30
	var/topped = wagon.bulk_load(more) == 10 && more.amount == 20 && store.bulk_amount == 600 && last.bulk_fill == 2 && !wagon.bulk_load(more)
	var/obj/item/stack/ore/uranium/U = new(platform_turf(220, 12))
	platform_check("freight/one_kind_and_no_more_than_it_holds", other && topped && !train_bulk_item(U) && !train_bulk_item(null) && findtext(wagon.dismantle_problem(), "Unload"))
	qdel(U)
	// A shovel digs it out again, a stack at a time.
	var/turf/heap = platform_turf(221, 10)
	var/out = wagon.bulk_take(50, heap)
	var/obj/item/stack/ore/coal/dug = locate() in heap
	store.bulk_amount = 20
	wagon.update_bulk()
	var/rest = wagon.bulk_take(50, heap)
	platform_check("freight/shovelled_out_by_the_stack", out == 50 && dug && dug.amount == 50 && rest == 20 && store.bulk_amount == 0 && isnull(store.bulk_path) && last.bulk_fill == 0 && isnull(last.bulk_path) && !wagon.bulk_take(50, heap) && !wagon.dismantle_problem())

	// The hopper drops its whole load through the floor.
	var/obj/structure/trains/platform/hopper = platform_car("hopper", 223, 22, NORTH)
	var/list/bays = hopper.car_segments()
	var/obj/structure/trains/platform/bin = hopper.bulk_store()
	var/list/front = train_platform_tiles(hopper.loc, hopper.dir)
	var/obj/structure/train_hopper_lever/lever = locate() in front[1]
	var/built = bays.len == 6 && hopper.bulk_max() == 800 && hopper.is_hopper() && lever && lever.hopper() == hopper && !wagon.drop_load() && !hopper.drop_load() && !hopper.drop_pit()
	hopper.bulk_load(I)
	bin.bulk_amount = 120
	hopper.update_bulk()
	var/dropped = hopper.drop_load()
	var/on_track = 0
	var/stacks = 0
	for (var/obj/structure/trains/platform/P in bays)
		for (var/obj/item/stack/ore/iron/S in P.loc)
			on_track += S.amount
			stacks++
	platform_check("freight/hopper_drops_on_the_track", built && QDELETED(I) && dropped == 120 && on_track == 120 && stacks == 3 && bin.bulk_amount == 0 && isnull(bin.bulk_path))
	// Over a drop pit the load goes into the pit.
	var/obj/structure/rail_drop_pit/pit = new(platform_turf(223, 19))
	pit.update_icon()
	bin.bulk_path = "/obj/item/stack/ore/coal"
	bin.bulk_amount = 100
	hopper.update_bulk()
	var/over = hopper.drop_pit() == pit && pit.icon_state == "drop_pit" && pit.dir == NORTH && pit.room_for(bin.bulk_path)
	var/binned = hopper.drop_load() == 100 && pit.bulk_amount == 100 && pit.bulk_path == "/obj/item/stack/ore/coal" && pit.icon_state == "drop_pit_coal" && bin.bulk_amount == 0
	platform_check("freight/hopper_drops_into_a_pit", over && binned)
	// The pit holds one kind, and what it has no room for stays in the car.
	bin.bulk_path = "/obj/item/stack/ore/glass"
	bin.bulk_amount = 50
	hopper.update_bulk()
	var/wrong = !pit.room_for(bin.bulk_path) && hopper.drop_load() == 0 && bin.bulk_amount == 50 && train_bulk_tone(bin.bulk_path) == "sand"
	bin.bulk_path = "/obj/item/stack/ore/coal"
	bin.bulk_amount = 30
	pit.bulk_amount = 2990
	hopper.update_bulk()
	var/part = hopper.drop_load() == 10 && bin.bulk_amount == 20 && pit.bulk_amount == 3000 && !pit.room_for(bin.bulk_path)
	var/turf/side = platform_turf(221, 19)
	var/dug_out = pit.dig_out(50, side)
	var/obj/item/stack/ore/coal/from_pit = locate() in side
	pit.bulk_amount = 5
	var/emptied = pit.dig_out(50, side) == 5 && pit.bulk_amount == 0 && isnull(pit.bulk_path) && pit.icon_state == "drop_pit" && !pit.dig_out(50, side)
	var/list/sheet = icon_states('icons/obj/vehicles/train_loads.dmi')
	var/list/states = icon_states('icons/obj/vehicles/train_platforms.dmi')
	platform_check("freight/pit_holds_one_kind", wrong && part && dug_out == 50 && from_pit && from_pit.amount == 50 && emptied && ("heap_coal_1" in sheet) && ("heap_ore_2" in sheet) && ("heap_sand_2" in sheet) && ("drop_pit" in states) && ("drop_pit_sand" in states) && ("edge_hopper" in states) && ("deck_center_hopper" in states) && ("deck_side_hopper" in states))

// The tank car (train_tank.dm).
/proc/platform_tank_run()
	for (var/ty in 2 to 25)
		platform_track(229, ty, NORTH)
	var/obj/structure/trains/platform/car = platform_car("tank_car", 229, 12, NORTH)
	var/list/segs = platform_segments(car)
	var/obj/structure/trains/platform/store = car.tank_store()
	var/obj/structure/trains/platform/last = segs[segs.len]
	var/obj/structure/trains/platform/shell = segs[2]
	var/list/front = train_platform_tiles(car.loc, car.dir)
	var/obj/structure/train_tank_valve/valve = locate() in front[1]
	var/list/flat = train_car_layout("long_flatbed")
	var/base = store.car_load_weight()
	var/built = segs.len == 6 && car.tank_max() == 3600 && store == car && last.tank_store() == store && valve && valve.tank() == car && !flat["tank"]
	var/shape = shell.density && !car.density && !last.density && shell.tank_shell() && !car.tank_shell() && shell.tank_overlay() && !car.tank_overlay() && findtext(last.tank_text(), "is empty")
	platform_check("tank/built_with_a_tank_and_a_valve", built && shape)

	// An open vessel of one liquid pours in at the tank, not at the end platform.
	var/mob/living/human/platform_rider/hand = new(platform_turf(227, 11))
	var/obj/item/weapon/reagent_containers/glass/bucket/pail = new(platform_turf(227, 11))
	pail.reagents.clear_reagents()
	pail.reagents.add_reagent("water", 60)
	var/ignored = !car.tank_use(pail, hand) && store.tank_amount == 0
	var/poured = shell.tank_use(pail, hand) && store.tank_amount == 60 && store.tank_reagent == "water" && pail.reagents.total_volume == 0
	platform_check("tank/poured_in_at_the_tank", ignored && poured && train_tank_liquid(pail) == null && abs(store.car_load_weight() - base - 0.1) < 0.001 && findtext(shell.tank_text(), "60 of 3600 units of water") && findtext(car.dismantle_problem(), "Drain"))

	// One liquid at a time, plain liquids only, and no more than it holds.
	pail.reagents.add_reagent("diesel", 40)
	var/other = train_tank_liquid(pail) == "diesel" && !car.tank_takes("diesel") && shell.tank_use(pail, hand) && store.tank_amount == 60 && pail.reagents.get_reagent_amount("diesel") == 40
	pail.reagents.add_reagent("water", 10)
	var/mixed = isnull(train_tank_liquid(pail)) && shell.tank_use(pail, hand) && store.tank_amount == 60 && pail.reagents.total_volume == 50
	var/topped = car.tank_fill("water", 5000) == 3540 && store.tank_amount == 3600 && !car.tank_takes("water") && !car.tank_fill("water", 10) && !car.tank_fill("diesel", 10)
	platform_check("tank/one_liquid_and_no_more_than_it_holds", other && mixed && topped && isnull(train_tank_liquid(null)) && isnull(train_tank_liquid(hand)))

	// An empty vessel held to the tank or the valve is filled.
	pail.reagents.clear_reagents()
	var/holds = pail.reagents.maximum_volume
	valve.attackby(pail, hand)
	var/drawn = holds > 0 && pail.reagents.get_reagent_amount("water") == holds && store.tank_amount == 3600 - holds
	store.tank_amount = 5
	pail.reagents.clear_reagents()
	var/dregs = shell.tank_use(pail, hand) && pail.reagents.get_reagent_amount("water") == 5 && store.tank_amount == 0 && isnull(store.tank_reagent) && car.tank_draw(10) == 0
	platform_check("tank/drawn_off_into_a_vessel", drawn && dregs)

	// The valve runs water into a water tower beside the track.
	var/dry = car.tank_fill("water", 1000) == 1000 && car.tank_run_out(valve) == 0 && store.tank_amount == 1000
	var/obj/structure/rail_water/tower/TW = new(platform_turf(231, 11))
	var/ran = car.tank_run_out(valve) == 1000 && TW.water == 1000 && store.tank_amount == 0 && isnull(store.tank_reagent)
	TW.water = 5900
	car.tank_fill("water", 400)
	var/part = car.tank_run_out(valve) == 100 && TW.water == 6000 && store.tank_amount == 300
	platform_check("tank/valve_fills_a_water_tower", dry && ran && part)

	// A water tower fills a tank car that is empty or carries water.
	var/list/reach = TW.takers()
	var/gave = TW.fill_takers()
	var/filled = reach.len == 1 && reach[1] == store && gave == 3300 && store.tank_amount == 3600 && TW.water == 2700 && !TW.takers().len
	car.tank_draw(3600)
	car.tank_fill("diesel", 500)
	platform_check("tank/water_tower_fills_a_tank_car", filled && !TW.takers().len && TW.fill_takers() == 0 && store.tank_reagent == "diesel" && TW.water == 2700)

	// Fuel runs into a heavy diesel locomotive standing by the valve.
	var/obj/structure/trains/locomotive/heavy_diesel/DL = platform_car("loco_diesel", 229, 17, NORTH)
	if (istype(DL))
		DL.fuel = 0
	var/fuelled = istype(DL) && car.tank_run_out(valve) == 300 && DL.fuel == 300 && store.tank_amount == 200 && car.tank_run_out(valve) == 0
	var/obj/structure/trains/locomotive/coal/steam = new(platform_turf(229, 23))
	var/list/sheet = icon_states('icons/obj/vehicles/train_loads.dmi')
	var/list/states = icon_states('icons/obj/vehicles/train_platforms.dmi')
	platform_check("tank/valve_fuels_a_diesel", fuelled && isnull(steam.tank_fuel_ids()) && ("tank_f" in sheet) && ("tank_m" in sheet) && ("tank_d" in sheet) && ("tank_b" in sheet) && ("tank_valve" in states))

// Diesel working (train_diesel.dm): the two-cab main-line diesel, units in
// multiple and the dead-man's handle.
/proc/platform_diesel_run()
	for (var/ty in 2 to 25)
		platform_track(254, ty, NORTH)
	var/list/states = icon_states('icons/obj/vehicles/train_platforms.dmi')
	var/obj/structure/trains/locomotive/heavy_diesel/mainline/A = platform_car("loco_dieselmain", 254, 22, NORTH)
	if (!istype(A))
		platform_check("dieselmain/builds", FALSE)
		return
	var/list/body = platform_segments(A.connected)
	var/obj/structure/trains/platform/rear = A.rear_cab()
	var/obj/structure/trains/platform/hood = body[1]
	var/ends = 0
	if (rear)
		for (var/obj/structure/train_part/edge/G in rear.deck_parts)
			if (G.style == "cab_end" && G.density && !G.icon_state && G.dir == SOUTH)
				ends++
	var/art = ("loco_dieselmain_1c" in states) && ("loco_dieselmain_6r" in states) && ("roof_loco_dieselmain_l" in states) && ("roof_loco_dieselmain_bc" in states)
	platform_check("dieselmain/builds", body.len == 5 && !A.density && hood.density && rear && rear.seg_index == 6 && rear.loc == platform_turf(254, 17) && !rear.density && ends == 3 && art && A.roof_images && A.roof_images.len == 3 && rear.roof_images && rear.roof_images.len == 3 && !hood.roof_images && A.car_load_weight() + 5 * hood.car_load_weight() == 9)

	// Either cab drives it; the cab that leads has to be manned for full speed.
	var/mob/living/human/platform_rider/driver = new(platform_turf(254, 22))
	var/list/alone = train_consist_list(A)
	var/front = A.control_spot(driver) == A && A.cab_manned(1) && !A.cab_manned(2) && A.cab_station(driver) == "all"
	A.reverser = 1
	var/ahead = A.leading_factor(alone)
	A.reverser = -1
	var/astern = A.leading_factor(alone)
	driver.loc = platform_turf(255, 17)
	var/back = A.control_spot(driver) == rear && A.cab_manned(2) && !A.cab_manned(1) && A.leading_factor(alone) == 1
	A.reverser = 1
	platform_check("dieselmain/drive_from_the_leading_cab", front && ahead == 1 && astern == 0.75 && back && A.leading_factor(alone) == 0.75)
	driver.loc = platform_turf(254, 22)

	// Units coupled next to each other work in multiple; a car between breaks it.
	var/obj/structure/trains/locomotive/heavy_diesel/mainline/B = platform_car("loco_dieselmain", 254, 16, NORTH)
	var/obj/structure/trains/platform/flat = platform_car("flatbed", 254, 10, NORTH)
	var/obj/structure/trains/locomotive/heavy_diesel/C = platform_car("loco_diesel", 254, 6, NORTH)
	var/mob/living/human/platform_rider/shunter = new(platform_turf(257, 3))
	var/list/single = A.linked_units()
	B.hitch_front(shunter)
	flat.hitch_front(shunter)
	C.hitch_front(shunter)
	var/list/units = A.linked_units()
	var/list/far = C.linked_units()
	var/obj/structure/trains/locomotive/coal/steam = new(platform_turf(257, 5))
	platform_check("multiple/links_coupled_units", single && single.len == 1 && C.train_head() == A && units && units.len == 2 && units[A.car_id] == A && units[B.car_id] == B && far && far.len == 1 && far[C.car_id] == C && isnull(steam.linked_units()) && !steam.works_in_multiple())

	// One cab starts and stops them all.
	A.fuel = 100
	B.fuel = 0
	C.fuel = 100
	A.work_control("Start the engine", driver)
	var/dry = A.on && !B.on && !C.on
	A.work_control("Stop the engine", driver)
	B.fuel = 100
	A.work_control("Start the engine", driver)
	var/both = A.on && B.on && !C.on && findtext(A.state_text(), "2 units work in multiple, 2 running")
	A.work_control("Stop the engine", driver)
	platform_check("multiple/one_cab_starts_them_all", dry && both && !A.on && !B.on)
	A.work_control("Start the engine", driver)

	// A cab of a linked unit works the unit that drives the train.
	var/own_cab = A.linked_driver() == A && B.linked_driver() == B
	A.driving = TRUE
	platform_check("multiple/any_cab_drives", own_cab && B.linked_driver() == A && C.linked_driver() == C)
	A.driving = FALSE

	// The driver's brake holds every linked unit.
	A.refresh_consist()
	var/held = 0
	for (var/obj/structure/trains/car in train_consist_list(A))
		if (car.car_id == A.car_id || car.car_id == B.car_id)
			held += car.car_load_weight() * car.brake_hold()
	platform_check("multiple/brake_holds_linked_units", A.consist_engines == 2 && A.consist_power == 128 && held > 17 && A.consist_own == held && A.linked && A.linked.len == 2)

	// The dead-man's handle: nobody in a cab of the working units.
	A.throttle = 2
	A.braking = FALSE
	var/manned = !A.deadman_watch() && !A.deadman_watch() && !A.deadman_watch() && A.throttle == 2
	driver.loc = platform_turf(254, 11) // B's rear cab
	var/linked_cab = A.deadman_held() && !A.deadman_watch()
	driver.loc = platform_turf(254, 9) // the flatbed
	var/first = A.deadman_watch()
	var/kept = A.throttle == 2 && !A.braking
	var/tripped = A.deadman_watch()
	platform_check("deadman/trips_with_nobody_in_a_cab", manned && linked_cab && !first && kept && tripped && A.throttle == 0 && A.braking && !A.deadman_watch() && A.has_deadman() && C.has_deadman() && !steam.has_deadman())
	driver.loc = platform_turf(254, 22)
	driver.stat = UNCONSCIOUS
	platform_check("deadman/needs_a_fit_driver", !A.cab_manned() && !A.deadman_held())
	driver.stat = CONSCIOUS
	A.braking = FALSE

	// The whole body rolls, the rear cab and its rider with it.
	var/mob/living/human/platform_rider/second = new(platform_turf(253, 17))
	var/rolled = platform_step(A, 3)
	platform_check("dieselmain/rolls", rolled == 3 && A.loc == platform_turf(254, 25) && rear.loc == platform_turf(254, 20) && heavy_parts_placed(A) && platform_parts_placed(body) && driver.loc == platform_turf(254, 25) && second.loc == platform_turf(253, 20) && C.loc == platform_turf(254, 9))

// The conductor (train_conductor.dm). A coach is coupled behind the train the
// diesel run left on column 254.
/proc/platform_conductor_run()
	var/list/states = icon_states('icons/obj/vehicles/train_platforms.dmi')
	var/obj/structure/trains/platform/coach = platform_car("coach", 254, 5, NORTH)
	if (!istype(coach))
		platform_check("conductor/door_locks", FALSE)
		return
	var/mob/living/human/platform_rider/guard = new(platform_turf(253, 5))
	var/mob/living/human/platform_rider/stranger = new(platform_turf(252, 5))
	coach.hitch_front(guard)
	var/obj/structure/train_part/edge/door = null
	for (var/obj/structure/train_part/edge/G in coach.deck_parts)
		if (G.is_door() && G.edge_kind == "out" && G.loc == guard.loc)
			door = G
	var/obj/item/train_key/key = new(guard.loc)
	var/obj/item/weapon/wrench/wrong = new(guard.loc)
	if (!door)
		platform_check("conductor/door_locks", FALSE)
		return
	door.attackby(wrong, guard)
	var/plain = !door.is_locked() && !door.open
	door.attackby(key, guard)
	var/locked = door.is_locked() && coach.locked_doors && door.locked_against(stranger) && !door.locked_against(guard)
	door.attack_hand(stranger)
	var/kept_out = !door.open && door.is_locked()
	door.attack_hand(guard)
	var/from_inside = door.open && !door.is_locked() && !coach.locked_doors
	var/not_open = !door.set_locked(TRUE)
	door.attack_hand(guard)
	door.attackby(key, guard)
	var/again = !door.open && door.is_locked()
	door.open_by_force()
	platform_check("conductor/door_locks", plain && locked && kept_out && from_inside && not_open && again && door.open && !door.is_locked() && coach.open_doors && ("carriage_key" in states))
	door.attack_hand(guard)
	door.attackby(key, guard)

	// The guard's journal lists the train from the front.
	var/obj/structure/trains/head = coach.train_head()
	var/list/cars = train_consist_list(head)
	var/obj/structure/trains/platform/flat = null
	for (var/obj/structure/trains/platform/P in cars)
		if (P.car_kind == "flatbed" && P.seg_index == 1)
			flat = P
	if (flat)
		flat.set_handbrake(TRUE)
	var/list/lines = train_list_lines(coach)
	var/heading = lines.len == 6 && findtext(lines[1], "5 vehicles, [cars.len] tiles long") && findtext(lines[1], "Its engines pull 160 at full speed") && findtext(lines[1], "1 handbrake on")
	var/rows = lines.len == 6 && findtext(lines[2], "1. main-line diesel locomotive") && findtext(lines[2], "running") && findtext(lines[4], "3. platform car") && findtext(lines[4], "handbrake on") && findtext(lines[5], "4. heavy diesel locomotive") && findtext(lines[5], "stopped") && findtext(lines[6], "5. passenger coach") && findtext(lines[6], "1 door locked")
	var/mob/living/human/platform_rider/walker = new(platform_turf(261, 12))
	platform_check("conductor/train_list", cars.len == 24 && heading && rows && train_beside(guard) == coach && train_beside(stranger) && isnull(train_beside(walker)) && !train_list_lines(null).len && ("guard_journal" in states))
	if (flat)
		flat.set_handbrake(FALSE)

	// Tickets are written out and punched once.
	var/obj/item/train_ticket_book/book = new(guard.loc)
	var/obj/item/train_ticket_punch/punch = new(guard.loc)
	var/obj/item/train_ticket/T = book.issue(guard, "Port Town", "2 silver")
	var/written = istype(T) && T.name == "ticket to Port Town" && T.fare == "2 silver" && T.issuer == guard.name && T.icon_state == "ticket" && book.tickets == 39
	if (T)
		T.attackby(punch, guard)
	var/punched = T && T.punched_by == guard.name && T.icon_state == "ticket_punched" && !T.punch(guard)
	book.tickets = 0
	platform_check("conductor/tickets", written && punched && isnull(book.issue(guard, "Port Town", null)) && ("ticket" in states) && ("ticket_punched" in states) && ("ticket_book" in states) && ("ticket_punch" in states))

	// Flags shown at the rear are seen in the cabs at the front.
	var/obj/item/train_flags/flags = new(guard.loc)
	var/obj/structure/trains/locomotive/A = head
	var/crew = 0
	if (istype(A))
		for (var/turf/tile in train_platform_tiles(A.loc, A.dir))
			for (var/mob/living/human/H in tile)
				crew++
		var/obj/structure/trains/platform/rear = A.rear_cab()
		for (var/turf/tile in train_platform_tiles(rear.loc, rear.dir))
			for (var/mob/living/human/H in tile)
				crew++
	var/list/signals = train_hand_signals()
	platform_check("conductor/hand_signals", crew == 2 && signals.len == 5 && flags.show_signal(guard, "Right away") == 2 && flags.show_signal(guard, "Danger") == 2 && !flags.show_signal(guard, "Wave") && !flags.show_signal(walker, "Stop") && ("signal_flags" in states))

// Single-line isolation and footprint regressions.
/proc/platform_token_isolation()
	var/obj/structure/train_lineside/board/orphan_board = new(platform_turf(258, 9))
	orphan_board.section = "101"
	orphan_board.update_board()
	var/obj/item/train_token/orphan_token = new(platform_turf(258, 10))
	orphan_token.section = "102"
	var/obj/structure/train_token_instrument/survivor = new(platform_turf(258, 11))
	survivor.section = "103"
	var/obj/structure/train_token_instrument/A = new(platform_turf(258, 4))
	var/obj/structure/train_token_instrument/B = new(platform_turf(258, 6))
	var/obj/structure/train_token_instrument/C = new(platform_turf(260, 4))
	var/obj/structure/train_token_instrument/D = new(platform_turf(260, 6))
	var/obj/item/train_signal_wire/W = new(platform_turf(257, 6))
	W.run_to(A)
	W.run_to(B)
	platform_check("tokens/skip_all_reserved_sources", A.section == "104" && A.partner() == B)
	W.run_from = null
	W.run_to(C)
	W.run_to(D)
	var/obj/item/train_token/first = A.draw_token(null)
	var/obj/item/train_token/second = C.draw_token(null)
	platform_check("tokens/independent_sections_issue_independently", C.section && C.section != A.section && C.partner() == D && first && second)
	var/original_board_name = orphan_board.name
	W.run_from = null
	W.run_to(survivor)
	W.run_to(orphan_board)
	platform_check("tokens/unpaired_instrument_preserves_board", orphan_board.section == "101" && orphan_board.name == original_board_name)
	var/obj/structure/train_token_instrument/replacement = new(platform_turf(258, 13))
	W.run_to(replacement)
	W.run_to(orphan_board)
	platform_check("tokens/replacement_keeps_section_and_can_mark_board", survivor.section == "103" && survivor.partner() == replacement && orphan_board.section == "103" && orphan_board.name != original_board_name)

	platform_track(257, 21, NORTH)
	var/obj/structure/trains/locomotive/coal/small = new(platform_turf(257, 21))
	small.set_dir(NORTH)
	small.refresh_consist()
	var/obj/structure/train_lineside/board/check_board = new(platform_turf(258, 21))
	check_board.section = A.section
	var/mob/living/human/platform_rider/holder = new(platform_turf(258, 21))
	first.loc = holder
	platform_check("tokens/small_ignores_trackside_holder", !small.body_kind && !small.carries_token(A.section) && findtext(check_board.sighting(small), "not on the engine"))
	check_board.passed_by(small)
	platform_check("tokens/trackside_token_counts_passage", check_board.passed == 1)
	first.loc = small.loc
	check_board.passed_by(small)
	platform_check("tokens/small_accepts_centre_token", small.carries_token(A.section) && check_board.passed == 1)
	for (var/ty in 20 to 25)
		platform_track(251, ty, NORTH)
	var/obj/structure/trains/locomotive/wide = platform_car("loco_diesel", 251, 23, NORTH)
	if (wide)
		wide.refresh_consist()
		first.loc = platform_turf(252, 23)
	platform_check("tokens/wide_accepts_side_deck_token", wide && wide.body_kind && wide.carries_token(A.section))

// Signals and single-line working (train_signals.dm), on column 266.
/proc/platform_signals_run()
	for (var/ty in 2 to 25)
		platform_track(266, ty, NORTH)
	var/list/states = icon_states('icons/obj/vehicles/train_platforms.dmi')
	var/obj/structure/trains/locomotive/A = platform_car("loco_diesel", 266, 12, NORTH)
	if (!istype(A))
		platform_check("signals/semaphore", FALSE)
		return
	var/mob/living/human/platform_rider/driver = new(platform_turf(266, 12))
	var/mob/living/human/platform_rider/signalman = new(platform_turf(268, 17))

	// A semaphore is worked by hand at the post and speaks to one direction.
	var/obj/structure/train_lineside/signal/S = new(platform_turf(268, 18))
	S.set_dir(NORTH)
	var/obj/structure/train_lineside/signal/far = new(platform_turf(263, 18))
	far.set_dir(NORTH)
	var/starts = !S.clear && S.icon_state == "signal_danger"
	S.attack_hand(signalman)
	var/cleared = S.clear && S.icon_state == "signal_clear"
	S.attack_hand(signalman)
	var/obj/item/weapon/wrench/wrench = new(signalman.loc)
	S.attackby(wrench, signalman)
	var/turned = S.dir == EAST
	S.set_dir(NORTH)
	platform_check("signals/semaphore", starts && cleared && !S.clear && turned && S.ahead_of(A, NORTH) == 6 && S.ahead_of(A, SOUTH) == -6 && isnull(far.ahead_of(A, NORTH)) && (S in train_lineside) && ("signal_danger" in states) && ("signal_clear" in states))
	qdel(far)

	// A single line: two instruments wired as a pair hold one token.
	var/obj/item/train_signal_wire/wire = new(signalman.loc)
	var/obj/structure/train_token_instrument/I1 = new(platform_turf(262, 4))
	var/obj/structure/train_token_instrument/I2 = new(platform_turf(262, 22))
	var/unwired = isnull(I1.draw_token(null)) && isnull(wire.run_to(driver))
	wire.run_to(I1)
	wire.run_to(I2)
	var/paired = I1.section && I1.section == I2.section && I1.partner() == I2 && I2.partner() == I1
	var/obj/item/train_token/token = I1.draw_token(signalman)
	var/one_only = istype(token) && token.section == I1.section && train_token_out(I1.section) == token && isnull(I2.draw_token(signalman)) && findtext(token.name, "single line")
	var/obj/item/train_token/stray = new(signalman.loc)
	stray.section = "elsewhere"
	var/wrong = !I2.restore_token(stray, null) && !QDELETED(stray)
	qdel(stray)
	platform_check("signals/token_instruments", unwired && paired && one_only && wrong && ("token_instrument" in states) && ("train_token" in states) && ("signal_wire" in states))

	// The cab reads what it comes up to; a signal passed at danger and a
	// section entered without its token are marked.
	var/obj/structure/train_lineside/board/B = new(platform_turf(264, 16))
	B.set_dir(NORTH)
	wire.run_to(B)
	var/obj/structure/train_lineside/signal/back = new(platform_turf(268, 22))
	back.set_dir(SOUTH)
	A.reverser = 1
	A.refresh_consist()
	A.lineside_seen = null
	var/crew = A.cab_crew()
	var/first = A.lineside_watch()
	var/list/read = A.lineside_seen
	var/sighted = !first && read && read.len == 2 && (S in read) && (B in read) && !(back in read) && findtext(S.sighting(A), "danger") && findtext(B.sighting(A), "not on the engine")
	var/rolled = platform_step(A, 7)
	var/second = A.lineside_watch()
	platform_check("signals/passed_at_danger", (driver in crew) && sighted && rolled == 7 && second == 2 && S.passed == 1 && B.passed == 1 && !back.passed && isnull(A.lineside_seen) && B.section == I1.section && ("section_board" in states))

	// With a clear signal and the token on the engine nothing is marked.
	var/obj/structure/train_lineside/signal/S2 = new(platform_turf(264, 24))
	S2.set_dir(NORTH)
	S2.set_clear(TRUE)
	var/obj/structure/train_lineside/board/B2 = new(platform_turf(268, 23))
	B2.set_dir(NORTH)
	wire.run_to(B2)
	var/without = !A.carries_token(I1.section)
	token.loc = driver
	var/third = A.lineside_watch()
	read = A.lineside_seen
	var/sighted_clear = !third && read && read.len == 2 && findtext(S2.sighting(A), "clear") && findtext(B2.sighting(A), "is on the engine")
	rolled = platform_step(A, 6)
	var/fourth = A.lineside_watch()
	platform_check("signals/clear_road", without && A.carries_token(I1.section) && sighted_clear && rolled == 6 && fourth == 2 && !S2.passed && !B2.passed && S.passed == 1)
	var/restored = I2.restore_token(token, null) && isnull(train_token_out(I1.section))
	var/obj/item/train_token/again = I2.draw_token(null)
	platform_check("signals/token_returns", restored && istype(again) && again.section == I2.section && isnull(I1.draw_token(null)))

	// The lever frame works signals and switches by wire, interlocked.
	var/obj/structure/train_lever_frame/frame = new(platform_turf(262, 12))
	var/obj/structure/train_lever/lever = new(platform_turf(262, 14))
	var/obj/structure/rails/split/switcher/points = new(platform_turf(262, 15))
	var/needs_frame = findtext(wire.run_to(lever), "lever frame") && !lever.worked_by
	wire.run_from = null
	needs_frame = needs_frame && findtext(wire.run_to(S), "lever frame") && !S.worked_by
	wire.run_to(frame)
	wire.run_to(S)
	wire.run_to(back)
	wire.run_to(lever)
	var/obj/structure/train_lineside/signal/remote = new(platform_turf(200, 2))
	var/too_far = findtext(wire.run_to(remote), "too far") && !remote.worked_by
	qdel(remote)
	var/list/worked = frame.worked()
	var/wired = frame.frame_id && S.worked_by == frame.frame_id && lever.worked_by == frame.frame_id && worked.len == 3 && train_frame_by_id(frame.frame_id, S) == frame
	S.attack_hand(signalman)
	lever.attack_hand(signalman)
	var/not_by_hand = !S.clear && lever.switched == "forward"
	var/pulled = frame.pull(S, signalman) && S.clear
	// A clear signal locks the switch near it and the signal that faces it.
	var/locked = !frame.pull(lever, signalman) && lever.switched == "forward" && !frame.pull(back, signalman) && !back.clear && train_signals_oppose(S, back) && train_signals_oppose(back, S) && !train_signals_oppose(S, S2)
	var/restored_lever = frame.pull(S, signalman) && !S.clear
	var/thrown = frame.pull(lever, signalman) && lever.switched == "split" && points.switched == "split" && findtext(frame.lever_label(lever), "branch")
	var/opposing = frame.pull(back, signalman) && back.clear && !frame.pull(S, signalman) && !S.clear
	wire.run_to(S)
	worked = frame.worked()
	var/unwired_again = !S.worked_by && worked.len == 2 && !frame.pull(S, signalman)
	S.attack_hand(signalman)
	platform_check("signals/lever_frame", needs_frame && too_far && wired && not_by_hand && pulled && locked && restored_lever && thrown && opposing && unwired_again && S.clear && ("lever_frame" in states))

// Leaving the rails (train_derail.dm): north up column 274, then east along
// y = 20.
/proc/platform_derail_run()
	for (var/ty in 2 to 20)
		platform_track(274, ty, NORTH)
	for (var/tx in 275 to 282)
		platform_track(tx, 20, EAST)
	var/list/states = icon_states('icons/obj/vehicles/train_platforms.dmi')
	var/obj/structure/trains/locomotive/A = platform_car("loco_steam", 274, 8, NORTH)
	if (!istype(A))
		platform_check("derail/speed_is_what_matters", FALSE)
		return
	var/list/body = platform_segments(A.connected)
	var/mob/living/simple_animal/train_probe_dummy/driver = new(A.loc)
	var/driver_health = driver.health

	// Slow round a curve is safe, and so is fast along the straight.
	A.rail_speed = 2.9
	var/slow = !A.curve_check(A, EAST, get_step(A, SOUTH))
	A.rail_speed = 5
	var/straight = !A.curve_check(A, NORTH, get_step(A, SOUTH))
	A.rail_speed = 0
	platform_check("derail/speed_is_what_matters", slow && straight && !A.derailed && !A.overrun_check() && !A.engine_disabled())

	// Driven flat out into the curve, the engine leaves the rails there.
	A.fuel = 200
	A.on = TRUE
	A.throttle = 3
	A.drive()
	var/top = 0
	var/limit = 400
	while (A.driving && limit > 0)
		top = max(top, A.rail_speed)
		sleep(1)
		limit--
	var/off = 0
	for (var/obj/structure/trains/platform/P in body)
		if (P.derailed)
			off++
	platform_check("derail/too_fast_round_the_curve", !A.driving && top > 3 && A.derailed && A.loc == platform_turf(275, 20) && A.dir == EAST && off == body.len && body.len >= 2 && !A.on && A.throttle == 0 && !A.broken_down && A.health == initial(A.health) && driver.health < driver_health && ("derailed" in states))

	// It stands there: the engine is dead and the train does not step.
	A.on = TRUE
	A.throttle = 3
	A.refresh_consist()
	platform_check("derail/derailed_train_stands", A.engine_disabled() && A.cruise_speed() == 0 && train_consist_obstacle(A, get_step(A, EAST), EAST) && platform_step(A, 1) == 0 && A.loc == platform_turf(275, 20))
	A.on = FALSE
	A.throttle = 0

	// A heavy engine is too much for a jack: it takes a braced, fired crane.
	var/mob/living/human/platform_rider/hand = new(platform_turf(276, 19))
	var/obj/item/train_jack/jack = new(hand.loc)
	var/obj/structure/trains/platform/hood = body[1]
	var/too_heavy = findtext(A.rerail_problem(), "crane car") && findtext(hood.rerail_problem(), "crane car") && !A.rerail() && A.service_use(jack, hand) && A.derailed
	var/obj/structure/trains/platform/crane_car = platform_car("crane_car", 274, 16, NORTH)
	var/list/crane_segs = platform_segments(crane_car)
	var/obj/structure/workshop_machine/shear_legs/crane/steam/rail/crane = locate() in platform_turf(274, 15)
	var/list/front = crane_car ? train_platform_tiles(crane_car.loc, crane_car.dir) : list(null)
	var/obj/structure/railway_gun_brace/lever = locate() in front[1]
	var/unbraced = crane && lever && findtext(A.rerail_problem(), "crane car")
	for (var/obj/structure/trains/platform/P in crane_segs)
		P.last_moved = -1000
	if (lever)
		lever.set_braced(TRUE)
	var/unfired = crane && isnull(crane.rail_problem()) && isnull(train_breakdown_crane(A))
	if (crane)
		crane.fuel = 5
	var/ready = crane && train_breakdown_crane(A) == crane && isnull(A.rerail_problem())
	var/lifted = hood.rerail()
	off = 0
	for (var/obj/structure/trains/platform/P in body)
		if (P.derailed)
			off++
	platform_check("derail/heavy_engine_needs_a_crane", too_heavy && unbraced && unfired && ready && lifted && !A.derailed && !off && !A.engine_disabled() && crane.fuel == 4 && findtext(A.rerail_problem(), "stands on the rails"))

	// A car comes off by its leading half and is jacked back a section at a time.
	var/obj/structure/trains/platform/flat = platform_car("flatbed", 274, 10, NORTH)
	var/list/segs = platform_segments(flat)
	var/obj/structure/trains/platform/second = segs.len >= 2 ? segs[2] : null
	var/obj/structure/trains/platform/third = segs.len >= 3 ? segs[3] : null
	var/came_off = train_unit_come_off(segs) && flat.derailed && second && second.derailed && third && !third.derailed && !flat.come_off() && !flat.wrecked && flat.health == initial(flat.health)
	var/blocked = train_consist_obstacle(flat, get_step(flat, NORTH), NORTH) ? TRUE : FALSE
	var/obj/structure/rails/under = second ? (locate(/obj/structure/rails) in second.loc) : null
	var/turf/rail_tile = under ? under.loc : null
	if (under)
		under.loc = null
	var/no_rail = second && findtext(second.rerail_problem(), "no rail") && !second.rerail()
	if (under)
		under.loc = rail_tile
	var/jacked = third.service_use(jack, hand) && isnull(flat.rerail_problem()) && flat.rerail() && second.rerail() && !flat.derailed && !second.derailed && !flat.rerail()
	platform_check("derail/car_jacked_back_on", segs.len == 4 && came_off && blocked && no_rail && jacked && !train_consist_obstacle(flat, get_step(flat, NORTH), NORTH) && ("rerail_jack" in states))

	// Off the end of the rails at speed; a buffer stop or a crawl is no derailment.
	A.reverser = 1
	A.refresh_consist()
	var/obj/structure/rails/ahead = locate(/obj/structure/rails) in get_step(A, EAST)
	var/turf/ahead_tile = ahead ? ahead.loc : null
	A.rail_speed = 2.5
	var/rails_ahead = ahead && !A.overrun_check()
	if (ahead)
		ahead.loc = null
	A.rail_speed = 1.5
	var/crawl = !A.overrun_check()
	A.rail_speed = 2.5
	var/obj/structure/rails/end/stop = new(A.loc)
	var/buffered = !A.overrun_check() && !A.derailed
	stop.loc = null
	var/ran_off = A.overrun_check() && A.derailed && A.rail_speed == 0
	if (ahead)
		ahead.loc = ahead_tile
	platform_check("derail/off_the_end", rails_ahead && crawl && buffered && ran_off && A.engine_disabled())

// Stations and warnings (train_stations.dm), on column 290.
// A heavy locomotive goes into the rail warehouse whole and comes out as it
// went in (docs/trains.md#heavy-locomotives).
/proc/platform_big_warehouse_run()
	for (var/y in 2 to 25)
		platform_track(298, y, NORTH)
	var/obj/structure/rail_warehouse/W = new(platform_turf(296, 13))
	W.dir = EAST
	var/obj/structure/trains/locomotive/heavy_diesel/mainline/E = platform_car("loco_dieselmain", 298, 19, NORTH)
	var/list/body = istype(E) ? platform_segments(E.connected) : list()
	var/obj/structure/trains/platform/last = body.len ? body[body.len] : null
	var/obj/structure/trains/transport/flatbed/F = new(platform_turf(298, 13))
	F.dir = NORTH
	last.connected = F
	E.fuel = 321
	E.sand = 7
	E.mileage = 1234
	E.front_coupling = 40
	last.rear_auto = TRUE
	var/obj/item/stack/material/iron/cab_load = new(platform_turf(297, 19))
	var/list/unit = rail_warehouse_unit(last)
	platform_check("bigstore/engine_is_one_unit", body.len == 5 && unit.len == 6 && unit[1] == E && unit[6] == last && W.rear_units().len == 1)
	F.derailed = TRUE
	platform_check("bigstore/refuses_derailed", findtext(W.store_problem(list(F)), "rails"))
	F.derailed = FALSE
	platform_check("bigstore/whole_train_stored", W.put_away(null, null, TRUE) == 2 && W.stored_units().len == 2 && !isturf(E.loc) && !isturf(last.loc) && !isturf(cab_load.loc))
	var/parts_left = 0
	for (var/x in 297 to 299)
		for (var/y in 13 to 19)
			for (var/obj/structure/train_part/P in platform_turf(x, y))
				parts_left++
	platform_check("bigstore/nothing_left_on_the_map", !parts_left && !E.body_parts && !E.coupler_f)
	var/obj/structure/rail_stored_unit/engine_unit = null
	var/obj/structure/rail_stored_unit/wagon_unit = null
	for (var/obj/structure/rail_stored_unit/U in W.stored_units())
		if (U.unit_length == 6)
			engine_unit = U
		else
			wagon_unit = U
	platform_check("bigstore/engine_rolls_out", engine_unit && !W.retrieve_problem(engine_unit, W.retrieve_place(engine_unit)) && W.retrieve_unit(engine_unit) == E && E.loc == platform_turf(298, 19) && last.loc == platform_turf(298, 14) && E.dir == NORTH)
	platform_check("bigstore/engine_whole_again", heavy_parts_placed(E) && platform_parts_placed(body) && E.rear_cab() == last && last.car_engine() == E && E.coupler_f && last.coupler_r)
	platform_check("bigstore/state_kept", E.fuel == 321 && E.sand == 7 && E.mileage == 1234 && E.front_coupling == 40 && last.rear_auto && cab_load.loc == platform_turf(297, 19))
	platform_check("bigstore/wagon_couples_behind", wagon_unit && W.retrieve_unit(wagon_unit) == F && last.connected == F && F.loc == platform_turf(298, 13))
	// A car with no coupling on its drawbar rolls out but is not hitched.
	platform_check("bigstore/wagon_stored_again", W.put_away(null, list(F), FALSE) == 1 && !last.connected)
	F.front_coupling = -1
	var/obj/structure/rail_stored_unit/loose = W.stored_units()[1]
	platform_check("bigstore/no_coupling_no_hitch", W.retrieve_unit(loose) == F && F.loc == platform_turf(298, 13) && !last.connected)

// Track works (docs/trains.md#track-works): a buffer stop at the end of a
// line, and a level crossing with gates worked by hand and from a frame.
/proc/platform_trackworks_run()
	for (var/ty in 2 to 21)
		platform_track(304, ty, NORTH)
	var/list/states = icon_states('icons/obj/vehicles/train_platforms.dmi')
	platform_check("trackworks/art", ("buffer_stop" in states) && ("crossing_boards" in states) && ("crossing_gate_shut" in states) && ("crossing_gate_open" in states))

	// The crossing: boards on the rails, a gate on the road either side.
	var/obj/structure/train_crossing_boards/boards = new(platform_turf(304, 6))
	var/obj/structure/train_lineside/gate/G1 = new(platform_turf(302, 6))
	G1.set_dir(EAST)
	var/obj/structure/train_lineside/gate/G2 = new(platform_turf(306, 6))
	G2.set_dir(WEST)
	var/obj/structure/train_lineside/gate/elsewhere = new(platform_turf(302, 16))
	elsewhere.set_dir(EAST)
	var/mob/living/human/platform_rider/keeper = new(platform_turf(302, 5))
	var/obj/item/weapon/wrench/wrench = new(keeper.loc)
	boards.attackby(wrench, keeper)
	platform_check("trackworks/crossing_built", !boards.density && boards.dir != initial(boards.dir) && !G1.density && !G1.shut && G1.crossing_gates().len == 2 && (G2 in G1.crossing_gates()) && elsewhere.crossing_gates().len == 1 && (G1 in train_lineside))
	platform_check("trackworks/gates_speak_both_ways", G1.speaks_to(NORTH) && G1.speaks_to(SOUTH) && !G1.speaks_to(EAST) && G2.speaks_to(NORTH) && G1.ahead_of(platform_turf(304, 2), NORTH) == 4)
	var/shut_moved = G1.set_shut(TRUE)
	platform_check("trackworks/gates_swing_together", shut_moved && G1.shut && G2.shut && G1.density && G2.density && G2.icon_state == "crossing_gate_shut" && !elsewhere.shut && !G1.set_shut(TRUE))
	G2.set_shut(FALSE)
	var/obj/structure/closet/crate/large/cart = new(platform_turf(306, 6))
	cart.density = TRUE
	var/blocked = G1.shut_problem()
	qdel(cart)
	platform_check("trackworks/gates_do_not_shut_on_a_cart", !G1.shut && !G1.density && findtext(blocked, "in the way") && !G1.shut_problem())
	// One line to the cab for the crossing, and one mark when it is run
	// over with the gates open.
	var/list/lines = list()
	for (var/obj/structure/train_lineside/gate/G in list(G1, G2))
		var/line = G.sighting(null)
		if (line)
			lines += line
		G.passed_by(null)
	G1.set_shut(TRUE)
	var/list/shut_lines = list()
	for (var/obj/structure/train_lineside/gate/G in list(G1, G2))
		var/line = G.sighting(null)
		if (line)
			shut_lines += line
		G.passed_by(null)
	platform_check("trackworks/cab_is_told", lines.len == 1 && findtext(lines[1], "open to the road") && shut_lines.len == 1 && findtext(shut_lines[1], "shut to the road") && G1.passed + G2.passed == 1)
	G1.set_shut(FALSE)

	// From a lever frame: one lever for the crossing, locked with the signal
	// that reads over it.
	var/obj/structure/train_lever_frame/F = new(platform_turf(302, 8))
	var/obj/structure/train_lineside/signal/S = new(platform_turf(306, 3))
	S.set_dir(NORTH)
	var/obj/item/train_signal_wire/wire = new(keeper.loc)
	wire.run_to(F)
	var/joined = wire.run_to(G1)
	wire.run_to(S)
	var/list/now = F.worked()
	// The signal reads over the gates ahead of it, not over those behind.
	S.set_dir(SOUTH)
	var/behind = !train_signal_over_gate(S, G1)
	S.set_dir(NORTH)
	platform_check("trackworks/frame_takes_the_gates", findtext(joined, "One lever") && now.len == 2 && (G1 in now) && !(G2 in now) && G2.crossing_frame() == F && findtext(F.lever_label(G1), "crossing gates") && train_signal_over_gate(S, G1) && train_signal_over_gate(S, G2) && behind)
	G2.attack_hand(keeper)
	var/held = findtext(F.locked_by(S), "open to the road") && !F.pull(S, null) && !S.clear && !G2.shut
	platform_check("trackworks/signal_waits_for_the_gates", held)
	var/shut_by_lever = F.pull(G1, null) && G1.shut && G2.shut
	var/cleared = F.pull(S, null) && S.clear
	var/locked = findtext(F.locked_by(G1), "clear over the crossing") && !F.pull(G1, null) && G1.shut
	var/restored = F.pull(S, null) && !S.clear && F.pull(G1, null) && !G1.shut && !G2.shut
	platform_check("trackworks/gates_locked_under_a_clear_signal", shut_by_lever && cleared && locked && restored)
	var/off = wire.run_to(G2)
	platform_check("trackworks/gates_come_off_the_frame", findtext(off, "by hand again") && !G1.crossing_frame() && F.worked().len == 1)

	// The buffer stop: a train brought up to it stops against it.
	var/obj/structure/train_buffer_stop/stop = new(platform_turf(304, 21))
	stop.set_dir(NORTH)
	var/obj/structure/trains/locomotive/A = platform_car("loco_steam", 304, 5, NORTH)
	if (!istype(A))
		platform_check("trackworks/buffer_stop_holds", FALSE)
		return
	// What is built into the line stays there under the train on its way,
	// and shut gates two tiles out are clear of its sides.
	var/obj/structure/rail_ash_pit/pit = new(platform_turf(304, 8))
	var/obj/structure/train_lineside/signal/near = new(platform_turf(305, 9))
	near.set_dir(SOUTH)
	var/obj/structure/trains/platform/behind_cab = A.connected
	var/turf/freight_from = istype(behind_cab) ? get_step(behind_cab, EAST) : null
	var/obj/item/weapon/wrench/freight = new(freight_from)
	G1.set_shut(TRUE)
	var/soft = stop.hold(0.4) && !stop.hits
	var/hard = stop.hold(1) && stop.hits == 1 && !stop.hold(1.3)
	stop.hits = 0
	platform_check("trackworks/buffer_stop_limits", soft && hard && stop.density)
	var/mob/living/simple_animal/train_probe_dummy/driver = new(A.loc)
	A.fuel = 200
	A.on = TRUE
	A.throttle = 1
	A.drive()
	var/limit = 1500
	while (A.driving && A.automovement && limit > 0)
		sleep(1)
		limit--
	A.throttle = 0
	platform_check("trackworks/fixtures_stay_under_a_train", istype(behind_cab) && A.loc == platform_turf(304, 20) && boards.loc == platform_turf(304, 6) && pit.loc == platform_turf(304, 8) && near.loc == platform_turf(305, 9) && G1.loc == platform_turf(302, 6) && G2.loc == platform_turf(306, 6) && G1.shut && G2.density && freight.loc == get_step(behind_cab, EAST) && freight.loc != freight_from && train_track_fixture(boards) && train_track_fixture(G1) && !train_platform_carries(pit) && train_platform_carries(freight))
	G1.set_shut(FALSE)
	platform_check("trackworks/buffer_stop_holds", A.loc == platform_turf(304, 20) && !QDELETED(stop) && !A.derailed && A.health == initial(A.health) && !QDELETED(driver))
	limit = 100
	while (A.driving && limit > 0)
		sleep(1)
		limit--
	// At speed it is smashed, and the train with it; the rails stay.
	A.rail_speed = 6
	var/struck = A.rail_hit(platform_turf(304, 21), NORTH, 1.6)
	var/scrap = 0
	for (var/obj/item/stack/material/M in platform_turf(304, 21))
		scrap++
	platform_check("trackworks/buffer_stop_smashed", struck && QDELETED(stop) && scrap == 1 && (locate(/obj/structure/rails) in platform_turf(304, 21)) && A.loc == platform_turf(304, 20))
	A.rail_speed = 0

// Step 15: the turntable. A bridge of rails over a pit turns an engine to
// face the other way, or onto a road that leaves the pit at a right angle.
/proc/platform_turntable_run()
	var/list/states = icon_states('icons/obj/vehicles/train_platforms.dmi')
	platform_check("turntable/art", ("turntable_deck" in states) && ("turntable_girders" in states) && ("turntable_pivot" in states) && ("pit" in icon_states('icons/obj/vehicles/train_turntable.dmi')) && ("pit" in icon_states('icons/obj/vehicles/train_turntable_large.dmi')))
	for (var/ty in 2 to 7)
		platform_track(312, ty, NORTH)
	for (var/tx in 315 to 320)
		platform_track(tx, 10, EAST)
	var/obj/structure/train_turntable/T = new(platform_turf(312, 10))

	// The pit holds no track of its own: the lines stop at its edge.
	var/obj/structure/rails/stray = platform_track(313, 9, NORTH)
	var/in_pit = T.lay_problem()
	qdel(stray)
	var/unlaid = !T.laid && findtext(T.turn_problem(), "not laid")
	var/laid = T.lay()
	var/obj/structure/rails/turntable/end = locate(/obj/structure/rails/turntable) in platform_turf(312, 8)
	platform_check("turntable/bridge_laid", findtext(in_pit, "Take up the track") && unlaid && laid && T.laid && T.bridge_rails().len == 5 && T.bridge_whole() && end && (end.dir == NORTH) && !(locate(/obj/structure/rails) in platform_turf(310, 10)) && T.overlays.len == 1)
	platform_check("turntable/bridge_is_fixed_track", end && !track_plain_rail(end) && !track_piece_bendable(end) && !end.pry_apart() && !QDELETED(end) && end.table() == T && train_track_fixture(T) && !train_platform_carries(T))

	// An engine runs on from the south and stands whole on the bridge.
	var/obj/structure/trains/locomotive/E = platform_car("loco_steam", 312, 7, NORTH)
	if (!istype(E))
		platform_check("turntable/engine_on", FALSE)
		return
	E.fuel = 100
	E.on = TRUE
	E.refresh_consist()
	var/stepped = platform_step(E, 5)
	E.automovement = FALSE
	var/list/body = platform_segments(E.connected)
	var/obj/structure/trains/platform/last = body[body.len]
	var/mob/living/human/platform_rider/driver = new(platform_turf(311, 10))
	var/obj/item/weapon/wrench/spanner = new(platform_turf(313, 10))
	platform_check("turntable/engine_on", stepped == 5 && E.loc == platform_turf(312, 12) && last.loc == platform_turf(312, 9) && T.units().len == 4 && !T.turn_problem() && T.turn_time() > 40)

	// Nobody stands in the pit, and a train turns whole or not at all.
	var/mob/living/human/platform_rider/idler = new(platform_turf(310, 8))
	var/stood = T.turn_problem()
	idler.loc = platform_turf(309, 11)
	var/obj/structure/trains/locomotive/coal/wagon = new(platform_turf(312, 7))
	wagon.dir = NORTH
	last.connected = wagon
	var/coupled = T.turn_problem()
	last.connected = null
	qdel(wagon)
	E.automovement = TRUE
	var/moving = T.turn_problem()
	E.automovement = FALSE
	platform_check("turntable/pit_clear_and_train_whole", findtext(stood, "standing in the pit") && findtext(coupled, "not on the table") && findtext(moving, "Stop") && !T.swing(45) && !T.turn_problem())

	// A quarter to the right: the engine faces east, its load with it.
	var/quarter = T.swing(-90)
	end = locate(/obj/structure/rails/turntable) in platform_turf(314, 10)
	platform_check("turntable/quarter_turn", quarter && E.loc == platform_turf(314, 10) && E.dir == EAST && last.loc == platform_turf(311, 10) && last.dir == EAST && !T.upright() && T.bridge_rails().len == 5 && end && end.dir == EAST && !(locate(/obj/structure/rails) in platform_turf(312, 8)))
	platform_check("turntable/load_turns_with_it", heavy_parts_placed(E) && platform_parts_placed(body) && driver.loc == platform_turf(312, 11) && spanner.loc == platform_turf(312, 9))

	// It runs off onto the road that leaves the pit to the east.
	var/off = platform_step(E, 4)
	E.automovement = FALSE
	platform_check("turntable/runs_off_onto_the_road", off == 4 && E.loc == platform_turf(318, 10) && last.loc == platform_turf(315, 10) && !T.units().len && driver.loc == platform_turf(316, 11))

	// Empty, it comes round by hand: slower alone than with a second pusher.
	var/alone = T.hands().len
	var/mob/living/human/platform_rider/mate = new(platform_turf(309, 9))
	var/light = T.turn_time()
	var/list/pair = T.hands()
	var/far = T.work(driver, 90)
	var/pushed = T.work(idler, 90)
	platform_check("turntable/pushed_by_hand", alone == 1 && pair.len == 2 && (mate in pair) && light == 20 && !far && pushed && T.upright() && !T.busy && (locate(/obj/structure/rails/turntable) in platform_turf(312, 12)) && !(locate(/obj/structure/rails) in platform_turf(314, 10)))
	var/list/gap = last.rail_target(WEST)
	platform_check("turntable/road_ends_at_the_pit", !gap)

	// Brought back, the engine backs on and is turned right round, then a
	// quarter more to leave by the road it came in on, facing the other way.
	T.swing(-90)
	E.reverser = -1
	var/backed = 0
	for (var/i in 1 to 4)
		E.automovement = TRUE
		if (E.process_rail_reverse())
			backed++
	E.automovement = FALSE
	E.reverser = 1
	var/on_again = backed == 4 && E.loc == platform_turf(314, 10) && !T.turn_problem()
	var/round = T.swing(180)
	platform_check("turntable/turned_right_round", on_again && round && E.loc == platform_turf(310, 10) && E.dir == WEST && last.loc == platform_turf(313, 10) && !T.upright() && heavy_parts_placed(E) && platform_parts_placed(body) && driver.loc == platform_turf(312, 9))
	var/south = T.swing(90)
	var/away = platform_step(E, 3)
	E.automovement = FALSE
	platform_check("turntable/leaves_facing_back", south && E.dir == SOUTH && away == 3 && E.loc == platform_turf(312, 5) && last.loc == platform_turf(312, 8) && heavy_parts_placed(E) && !E.derailed && E.health == initial(E.health))

	// The large table: eleven tiles of bridge. It is taken up with nothing
	// on it, and goes with its pivot.
	var/obj/structure/train_turntable/large/edge = new(platform_turf(world.maxx - 2, 19))
	var/near_edge = edge.lay_problem()
	qdel(edge)
	var/obj/structure/train_turntable/large/big = new(platform_turf(316, 19))
	big.set_dir(EAST)
	var/big_laid = big.lay() && big.bridge_rails().len == 11 && !big.upright() && (locate(/obj/structure/rails/turntable) in platform_turf(321, 19)) && !big.turn_problem()
	var/big_turned = big.swing(90) && big.upright() && (locate(/obj/structure/rails/turntable) in platform_turf(316, 24))
	platform_check("turntable/large_table", findtext(near_edge, "too near the edge") && big_laid && big_turned)
	var/busy_table = T.take_up_problem()
	var/taken = big.take_up() && !big.laid && !big.bridge_rails().len && !big.overlays.len
	big.lay()
	qdel(big)
	platform_check("turntable/taken_up", findtext(busy_table, "off the table") && taken && !(locate(/obj/structure/rails/turntable) in platform_turf(316, 24)) && !(locate(/obj/structure/rails/turntable) in platform_turf(316, 19)))

// Step 15: track wear. Traffic wears the rails, worn track brings the line
// speed down, and a platelayer packs it or puts in new sleepers.
/proc/platform_trackwear_run()
	for (var/ty in 13 to 25)
		platform_track(320, ty, NORTH)
	var/list/states = icon_states('icons/obj/vehicles/train_platforms.dmi')
	var/obj/structure/rails/R = locate(/obj/structure/rails) in platform_turf(320, 24)
	var/sound = R && !R.wear && !R.wear_state() && !R.line_speed() && findtext(R.wear_text(), "good order")
	R.take_traffic(10, 3)
	var/slow = R.wear
	R.take_traffic(10, 6)
	var/fast = R.wear - slow
	R.wear = 30
	R.take_traffic(10, 3)
	var/rough = R.wear - 30
	R.take_traffic(8000, 3)
	platform_check("trackwear/traffic_wears_the_rails", sound && abs(slow - 0.1) < 0.001 && abs(fast - 0.15) < 0.001 && abs(rough - 0.15) < 0.001 && R.wear == 100)
	R.wear = 49
	R.show_wear()
	var/no_mark = R.wear_state() == 1 && !R.line_speed() && !R.wear_image && !R.overlays.len
	R.wear = 49.95
	R.take_traffic(10, 3)
	var/worn = R.wear_state() == 2 && R.line_speed() == 5 && R.wear_image && R.wear_image.icon_state == "track_worn" && R.overlays.len == 1
	R.wear = 80
	R.show_wear()
	platform_check("trackwear/worn_track_shows_and_slows", ("track_worn" in states) && ("track_bad" in states) && no_mark && worn && R.wear_state() == 3 && R.line_speed() == 2 && R.wear_image.icon_state == "track_bad" && R.overlays.len == 1 && findtext(R.wear_text(), "new sleepers"))

	// The platelayer: a hammer packs rough and worn track, and bad track
	// wants a new set of sleepers.
	var/mob/living/human/platform_rider/ganger = new(platform_turf(321, 24))
	var/obj/item/weapon/hammer/hammer = new(ganger.loc)
	var/obj/item/stack/rail_sleepers/sleepers = new(ganger.loc)
	sleepers.amount = 2
	R.attackby(hammer, ganger)
	var/too_far_gone = R.wear == 80
	R.attackby(sleepers, ganger)
	var/relaid = R.wear == 0 && sleepers.amount == 1 && !R.wear_image && !R.overlays.len
	R.attackby(sleepers, ganger)
	var/not_wasted = sleepers.amount == 1
	R.wear = 60
	R.show_wear()
	R.attackby(hammer, ganger)
	var/packed = R.wear == 30 && !R.wear_image
	R.attackby(hammer, ganger)
	platform_check("trackwear/platelayer_keeps_it_up", too_far_gone && relaid && not_wasted && packed && R.wear == 0 && !R.track_maintain(hammer, ganger))

	// In the cab: told as the track gets worse, and off the rails when worn
	// track is taken faster than its line speed.
	var/obj/structure/trains/locomotive/E = platform_car("loco_steam", 320, 17, NORTH)
	if (!istype(E))
		platform_check("trackwear/cab_is_told", FALSE)
		return
	E.fuel = 100
	E.on = TRUE
	E.refresh_consist()
	var/obj/structure/rails/under = locate(/obj/structure/rails) in E.loc
	E.rail_speed = 6
	var/clean = !E.meet_track() && under.wear > 0 && under.wear < 1 && !E.track_told
	under.wear = 30
	var/told_rough = !E.meet_track() && E.track_told == 1
	under.wear = 60
	E.rail_speed = 5
	var/told_worn = !E.meet_track() && E.track_told == 2 && !E.derailed
	under.wear = 85
	E.rail_speed = 2
	var/told_bad = !E.meet_track() && E.track_told == 3 && !E.derailed
	platform_check("trackwear/cab_is_told", clean && told_rough && told_worn && told_bad)
	under.attackby(hammer, ganger)
	var/train_in_the_way = under.wear > 85
	E.rail_speed = 2.5
	var/off = E.meet_track()
	platform_check("trackwear/too_fast_leaves_the_rails", train_in_the_way && off && E.derailed && E.rail_speed == 0)

	// From the drive loop: a train run over a stretch leaves wear behind it.
	var/obj/structure/trains/locomotive/coal/L = new(platform_turf(320, 19))
	L.dir = NORTH
	L.fuel = 100
	L.on = TRUE
	L.throttle = 1
	L.drive()
	var/limit = 300
	while (L.driving && L.y < 23 && limit > 0)
		sleep(1)
		limit--
	L.throttle = 0
	var/obj/structure/rails/passed = locate(/obj/structure/rails) in platform_turf(320, 21)
	platform_check("trackwear/driving_wears_the_line", L.y >= 21 && passed && passed.wear > 0)

// Freight handling (train_goods.dm): columns 326 and 330.
/proc/platform_goods_run()
	for (var/tx in list(326, 330))
		for (var/ty in 2 to 25)
			platform_track(tx, ty, NORTH)
	var/list/depot_sheet = icon_states('icons/obj/vehicles/rail_water.dmi')
	var/list/states = icon_states('icons/obj/vehicles/train_platforms.dmi')

	// The loading stage: one kind heaped on it, run down the chute into a wagon.
	var/obj/structure/trains/platform/wagon = platform_car("open_wagon", 326, 12, NORTH)
	var/obj/structure/trains/platform/store = wagon.bulk_store()
	var/obj/structure/rail_depot/loading_stage/stage = new(platform_turf(328, 9))
	var/obj/item/stack/ore/coal/C = new(platform_turf(329, 8))
	C.amount = 40
	var/obj/item/stack/ore/iron/I = new(platform_turf(329, 8))
	I.amount = 30
	var/bare = stage.icon_state == "loading_stage_empty" && !stage.fill_takers() && !stage.take_off(50, platform_turf(329, 8))
	var/heaped = stage.load_bulk(C) == 40 && stage.bulk_amount == 40 && stage.icon_state == "loading_stage_coal" && !stage.load_bulk(I) && I.amount == 30
	var/list/near = stage.takers()
	var/ran = near.len == 1 && near[1] == store && stage.fill_takers() == 40 && store.bulk_amount == 40 && store.bulk_path == "/obj/item/stack/ore/coal" && stage.bulk_amount == 0 && isnull(stage.bulk_path) && stage.icon_state == "loading_stage_empty"
	platform_check("goods/loading_stage_fills_a_wagon", bare && heaped && ran && train_track_fixture(stage) && ("loading_stage_empty" in depot_sheet) && ("loading_stage_coal" in depot_sheet) && ("loading_stage_ore" in depot_sheet) && ("loading_stage_sand" in depot_sheet))

	// A wagon of another kind takes nothing, a full one only what it has room
	// for, and a shovel takes the heap back off.
	var/other = stage.load_bulk(I) == 30 && stage.icon_state == "loading_stage_ore" && stage.fill_takers() == 0 && stage.bulk_amount == 30 && store.bulk_amount == 40
	var/turf/side = platform_turf(329, 8)
	var/off = stage.take_off(50, side) == 30 && stage.bulk_amount == 0 && isnull(stage.bulk_path)
	var/dug = 0
	for (var/obj/item/stack/ore/iron/S in side)
		dug += S.amount
		qdel(S)
	var/obj/item/stack/ore/coal/more = new(side)
	more.amount = 50
	stage.load_bulk(more)
	store.bulk_amount = wagon.bulk_max() - 20
	var/mob/living/human/platform_rider/hand = new(platform_turf(329, 9))
	stage.attack_hand(hand)
	platform_check("goods/loading_stage_one_kind_and_no_overfill", other && off && dug == 30 && store.bulk_amount == wagon.bulk_max() && stage.bulk_amount == 30 && stage.icon_state == "loading_stage_coal")
	stage.bulk_amount = 2990
	var/obj/item/stack/ore/coal/last = new(side)
	last.amount = 40
	platform_check("goods/loading_stage_holds_so_much", stage.load_bulk(last) == 10 && last.amount == 30 && stage.bulk_amount == 3000 && !stage.load_bulk(last))
	qdel(last)

	// The goods crane: a load swings onto a car's deck, and off it again.
	var/obj/structure/trains/platform/flat = platform_car("flatbed", 330, 12, NORTH)
	var/obj/structure/workshop_machine/shear_legs/crane/goods/crane = new(platform_turf(332, 11))
	var/obj/structure/closet/crate/load = new(platform_turf(333, 11))
	var/list/choices = crane.haul_choices(load)
	var/turf/aboard = null
	var/turf/beside = null
	for (var/label in choices)
		if (findtext(label, "Swing it onto"))
			aboard = choices[label]
		if (findtext(label, "beside the track"))
			beside = choices[label]
	var/obj/structure/trains/platform/landed = train_deck_at(aboard)
	var/on_car = aboard && landed && flat && landed.car_id == flat.car_id && get_dist(aboard, crane) <= 3 && crane.sling_reach() == 3
	var/on_ground = beside && !train_deck_at(beside) && !(locate(/obj/structure/rails) in beside) && beside != load.loc
	platform_check("goods/crane_swings_a_load_onto_a_car", on_car && on_ground && ("goods_crane" in states) && ("goods_crane_haul" in states))
	if (aboard)
		load.forceMove(aboard)
	choices = crane.haul_choices(load)
	var/turf/down = null
	var/again = FALSE
	for (var/label in choices)
		if (findtext(label, "beside the track"))
			down = choices[label]
		if (findtext(label, "Swing it onto"))
			again = TRUE
	platform_check("goods/crane_sets_a_load_down", aboard && down && !train_deck_at(down) && !(locate(/obj/structure/rails) in down) && get_dist(down, crane) <= 3 && !again)

	// The livestock ramp: it wants a car at its head and the door open.
	var/obj/structure/trains/platform/stock = platform_car("stock_car", 326, 25, NORTH)
	var/obj/structure/train_livestock_ramp/ramp = new(platform_turf(328, 22))
	ramp.set_dir(WEST)
	var/obj/structure/train_livestock_ramp/lone = new(platform_turf(328, 15))
	lone.set_dir(WEST)
	var/obj/structure/train_part/edge/gate = null
	for (var/obj/structure/train_part/edge/G in platform_turf(327, 22))
		if (G.is_door())
			gate = G
	var/mob/living/simple_animal/train_probe_dummy/cow = new(platform_turf(329, 22))
	var/mob/living/simple_animal/train_probe_dummy/calf = new(platform_turf(329, 23))
	var/mob/living/simple_animal/train_probe_dummy/stray = new(platform_turf(332, 22))
	var/mob/living/human/platform_rider/drover = new(platform_turf(329, 21))
	var/shut = gate && gate.density && findtext(ramp.ramp_problem(), "in the way") && !ramp.drive_aboard()
	if (gate)
		gate.set_open(TRUE)
	platform_check("goods/ramp_wants_a_car_and_an_open_door", stock && shut && isnull(ramp.ramp_problem()) && ramp.car() && findtext(lone.ramp_problem(), "No car") && train_track_fixture(ramp) && ("livestock_ramp" in states))
	qdel(lone)

	// Penned animals go aboard, nearest first; people and strays stay.
	var/went = ramp.work(drover, TRUE)
	var/obj/structure/trains/platform/under_cow = train_deck_at(cow.loc)
	var/obj/structure/trains/platform/under_calf = train_deck_at(calf.loc)
	platform_check("goods/ramp_drives_animals_aboard", went == 2 && cow.loc == platform_turf(327, 22) && under_cow && under_calf && under_cow.car_id == stock.car_id && under_calf.car_id == stock.car_id && stray.loc == platform_turf(332, 22) && drover.loc == platform_turf(329, 21) && !ramp.drive_aboard() && train_livestock(cow) && !train_livestock(drover))
	var/came = ramp.drive_off()
	platform_check("goods/ramp_drives_animals_off", came == 2 && !train_deck_at(cow.loc) && !train_deck_at(calf.loc) && cow.loc != ramp.loc && calf.loc != ramp.loc && get_dist(cow, ramp) <= 3 && get_dist(calf, ramp) <= 3 && cow.x >= 328 && calf.x >= 328 && !ramp.drive_off())
	cow.stat = DEAD
	platform_check("goods/ramp_leaves_the_dead", !train_livestock(cow) && ramp.drive_aboard() == 1 && !train_deck_at(cow.loc) && train_deck_at(calf.loc))
	qdel(cow)
	qdel(calf)
	qdel(stray)

	// Destination cards: one to a car, read on examine and in the guard's journal.
	var/list/segs = wagon.car_segments()
	var/obj/structure/trains/platform/tail = segs[segs.len]
	var/obj/item/weapon/wrench/tool = new(side)
	var/blank = isnull(wagon.card_text()) && findtext(wagon.card_line(), "holder is empty") && !wagon.card_use(tool, hand)
	var/carded = tail.set_card("Port Town, coal") && wagon.card_text() == "Port Town, coal" && tail.card_text() == "Port Town, coal" && !wagon.set_card("Port Town, coal") && findtext(tail.card_line(), "reads: Port Town, coal")
	var/listed = FALSE
	for (var/line in train_list_lines(wagon))
		if (findtext(line, "carded \"Port Town, coal\""))
			listed = TRUE
	var/long = wagon.set_card("A very long destination that runs right off the edge of any card") && length(wagon.card_text()) <= 40
	var/wiped = wagon.set_card("") && isnull(tail.card_text()) && isnull(flat.card_text())
	platform_check("goods/destination_cards", blank && carded && listed && long && wiped)

// Early rails (train_early.dm): columns 338 and 341.
/proc/platform_early_run()
	for (var/ty in 2 to 25)
		platform_track(338, ty, NORTH)
	var/list/states = icon_states('icons/obj/vehicles/train_platforms.dmi')

	// The hand car: a rider on it pumps the beam and it rolls.
	var/obj/structure/trains/transport/handcar/H = new(platform_turf(338, 4))
	H.dir = NORTH
	var/mob/living/human/platform_rider/pumper = new(platform_turf(338, 4))
	var/mob/living/human/platform_rider/mate = new(platform_turf(337, 4))
	pumper.dir = NORTH
	var/afoot = findtext(H.pump_problem(mate), "Climb onto") && !H.pump(mate, NORTH) && isnull(H.pump_problem(pumper))
	var/stroke = H.pump(pumper, NORTH)
	var/list/motion = H.train_motion()
	var/off = stroke && motion && abs(H.roll_speed - 0.8) < 0.01 && H.travel_way(motion) == NORTH && H.pump_way == NORTH && !H.pump(pumper, NORTH) && abs(H.roll_speed - 0.8) < 0.01
	var/rolled = H.roll_step() > 0
	platform_check("early/hand_car_is_pumped_along", afoot && off && rolled && H.y == 5 && pumper.loc == H.loc && H.roll_speed < 0.8 && ("handcar" in states))

	// One rider keeps it to a steady speed, two go faster, and pumping
	// against the roll stops it.
	for (var/i in 1 to 6)
		H.pumped["\ref[pumper]"] = world.time - 20
		H.pump(pumper, EAST)
	var/alone = abs(H.roll_speed - 1.5) < 0.01 && H.pump_crew() == 1
	mate.loc = H.loc
	for (var/i in 1 to 4)
		H.pumped["\ref[mate]"] = world.time - 10
		H.pump(mate, NORTH)
	var/paired = H.pump_crew() == 2 && abs(H.roll_speed - 2.25) < 0.01
	var/strokes = 0
	while (H.roll_speed > 0 && strokes < 10)
		H.pumped["\ref[pumper]"] = world.time - 20
		H.pump(pumper, SOUTH)
		strokes++
	platform_check("early/hand_car_speed_and_braking", alone && paired && strokes == 2 && H.roll_speed == 0 && isnull(H.train_motion()) && H.pump_way == SOUTH)

	// It will not move braked or overloaded.
	H.set_handbrake(TRUE)
	var/braked = findtext(H.pump_problem(pumper), "handbrake")
	H.set_handbrake(FALSE)
	H.train_weight = 5
	var/heavy = findtext(H.pump_problem(pumper), "too heavy")
	H.train_weight = initial(H.train_weight)
	platform_check("early/hand_car_limits", braked && heavy && isnull(H.pump_problem(pumper)) && H.y == 5)
	mate.loc = platform_turf(336, 3)
	pumper.loc = platform_turf(336, 4)

	// A horse harnessed to the end of a string of wagons draws it.
	// The fixture boots without the global lists the observers count in.
	if (!GLOB.event_sources_count)
		GLOB.event_sources_count = list()
	if (!GLOB.event_listen_count)
		GLOB.event_listen_count = list()
	var/obj/structure/trains/storage/chaldron/C1 = new(platform_turf(338, 14))
	var/obj/structure/trains/storage/chaldron/C2 = new(platform_turf(338, 13))
	var/obj/structure/trains/storage/chaldron/C3 = new(platform_turf(338, 12))
	C1.dir = NORTH
	C2.dir = NORTH
	C3.dir = NORTH
	C1.connected = C2
	C2.connected = C3
	var/mob/living/simple_animal/horse/horse = new(platform_turf(338, 15))
	var/mob/living/simple_animal/train_probe_dummy/sheep = new(platform_turf(337, 14))
	var/mob/living/simple_animal/horse/far_horse = new(platform_turf(341, 20))
	var/refused = findtext(C1.harness_refusal(sheep), "Only a horse") && findtext(C2.harness_refusal(horse), "one end") && findtext(C1.harness_refusal(far_horse), "next to") && !C1.harness(sheep)
	C1.train_weight = 20
	var/overweight = findtext(C1.harness_refusal(horse), "too heavy")
	C1.train_weight = initial(C1.train_weight)
	var/in_traces = isnull(C1.harness_refusal(horse)) && C1.harness(horse) && C1.draft_animal == horse && horse.hitched_train == C1 && horse.hitch_drag() > 0 && findtext(C1.draft_line(), "harnessed") && isnull(C2.draft_line()) && findtext(C3.harness_refusal(far_horse), "already draws")
	platform_check("early/horse_is_harnessed_to_an_end", refused && overweight && in_traces && train_draft_load(horse) == 8 && ("chaldron" in states))
	qdel(sheep)
	horse.forceMove(platform_turf(338, 16))
	var/one = C1.y == 15 && C2.y == 14 && C3.y == 13
	horse.forceMove(platform_turf(338, 17))
	horse.forceMove(platform_turf(338, 18))
	platform_check("early/train_follows_the_horse", one && C1.y == 17 && C2.y == 16 && C3.y == 15 && C1.draft_animal == horse && !C1.roll_speed && !C1.automovement)

	// From the other end it draws the train back the way it came.
	C1.unharness()
	horse.forceMove(platform_turf(338, 14))
	var/turned = !horse.hitched_train && !horse.hitch_drag() && C3.harness(horse) && C3.draft_animal == horse
	horse.forceMove(platform_turf(338, 13))
	platform_check("early/horse_draws_from_either_end", turned && C3.y == 14 && C2.y == 15 && C1.y == 16 && C3.train_head() == C3)

	// A brake left on, or a horse that wanders off, lets the traces go.
	C2.set_handbrake(TRUE)
	horse.forceMove(platform_turf(338, 12))
	var/held = !C3.draft_animal && !horse.hitched_train && C3.y == 14
	C2.set_handbrake(FALSE)
	var/again = C3.harness(horse) == FALSE && C3.draw() == FALSE
	horse.forceMove(platform_turf(338, 13))
	again = !again ? FALSE : C3.harness(horse)
	horse.forceMove(platform_turf(341, 10))
	platform_check("early/traces_come_loose", held && again && !C3.draft_animal && !horse.hitched_train && C3.y == 14)
	qdel(horse)
	qdel(far_horse)

	// Wooden rails: laid like iron ones, and an engine wears them fast.
	var/obj/structure/rail_bed/B = track_place_bed(platform_turf(341, 5), NORTH)
	var/obj/item/stack/rail_lengths/wooden/timber = new(platform_turf(342, 5))
	B.lay_rails(timber, pumper)
	var/laid = B.railed && B.wooden && B.color == WOODEN_RAIL_COLOR
	var/obj/structure/rails/W = B.spike()
	var/obj/structure/rails/iron = locate() in platform_turf(338, 20)
	var/wooden = istype(W) && W.wooden && W.color == WOODEN_RAIL_COLOR && W.name == "wagonway" && iron && !iron.wooden && isnull(iron.color)
	W.take_traffic(10, 1)
	var/before = iron.wear
	iron.take_traffic(10, 1)
	platform_check("early/wooden_rails_wear_under_an_engine", laid && wooden && abs(W.wear - 0.8) < 0.001 && abs(iron.wear - before - 0.1) < 0.001)
	var/obj/structure/rail_bed/back = W.pry_apart()
	var/loose = istype(back) && back.wooden && back.railed
	var/obj/item/stack/rail_lengths/lifted = back ? back.pry() : null
	platform_check("early/wooden_rails_come_up_as_wood", loose && istype(lifted, /obj/item/stack/rail_lengths/wooden) && lifted.color == WOODEN_RAIL_COLOR && back && !back.railed && !back.wooden)

/obj/structure/engine/train_probe_engine
	maxpower = 200
	on = TRUE
	anchored = TRUE
/obj/structure/engine/train_probe_engine/New()
	return

/proc/platform_electric_isolation(obj/structure/train_catenary/M1, obj/structure/train_catenary/M2)
	// A separate parallel row sits nine tiles away, within the old network
	// radius but outside the feeder point's reach and off the wire centerline.
	for (var/ty in 2 to 12)
		platform_track(359, ty, NORTH)
	var/obj/structure/train_catenary/parallel = new(platform_turf(361, 6))
	var/parallel_up = parallel.put_up()
	var/obj/structure/trains/locomotive/electric/unfed = platform_car("loco_electric", 359, 6, NORTH)
	platform_check("electric/parallel_line_has_no_traction_power", parallel_up && !parallel.powersource && M1.line_live() && parallel.network() != M1.network() && unfed && train_catenary_over(unfed.loc) == parallel && findtext(unfed.start_problem(), "overhead line is dead"))
	if (unfed)
		qdel(unfed)
	qdel(parallel)

	// A five-tile offset stops the crossing wire one tile short; four joins.
	platform_track(355, 6, EAST)
	var/obj/structure/train_catenary/short_crossing = new(platform_turf(355, 4))
	platform_check("electric/short_crossing_does_not_join", short_crossing.put_up() && short_crossing.dir == NORTH && short_crossing.network() != M1.network())
	qdel(short_crossing)
	platform_track(354, 6, EAST)
	var/obj/structure/train_catenary/crossing = new(platform_turf(354, 4))
	platform_check("electric/reaching_crossing_joins", crossing.put_up() && crossing.dir == NORTH && crossing.network() == M1.network())
	qdel(crossing)

	var/obj/structure/train_catenary/across_gap = new(platform_turf(352, 25))
	platform_check("electric/one_tile_gap_breaks_wire", across_gap.put_up() && across_gap.dir == WEST && across_gap.network() != M2.network())
	qdel(across_gap)

/proc/platform_electric_run()
	for (var/ty in 2 to 25)
		platform_track(350, ty, NORTH)
	var/list/states = icon_states('icons/obj/vehicles/train_platforms.dmi')
	// A small grid: an engine on a cable, and a transformer on that cable.
	release_cable_autolink()
	var/obj/structure/cable/C = new(platform_turf(354, 8))
	var/obj/structure/engine/train_probe_engine/G = new(platform_turf(354, 8))
	C.connections |= G
	G.connections |= C
	var/obj/structure/power_point/transformer/T = new(platform_turf(354, 8))
	T.anchored = TRUE
	T.attach_cable()

	// Masts stand two tiles from the rails and turn their arm to the track.
	var/obj/structure/train_catenary/M1 = new(platform_turf(352, 6))
	var/obj/structure/train_catenary/M2 = new(platform_turf(352, 15))
	var/obj/structure/train_catenary/stray = new(platform_turf(353, 22))
	var/refused = !stray.put_up() && !stray.anchored && !(stray in train_catenary)
	var/up = M1.put_up() && M2.put_up() && M1.dir == WEST && M1.wire_turf() == platform_turf(350, 6)
	var/hung = M1.covers(platform_turf(350, 2)) && M1.covers(platform_turf(350, 10)) && !M1.covers(platform_turf(350, 11)) && M1.covers(platform_turf(351, 6)) && !M1.covers(platform_turf(352, 6))
	var/along = train_catenary_over(platform_turf(350, 19)) == M2 && !train_catenary_over(platform_turf(350, 20))
	var/art = ("catenary_mast" in states) && ("catenary_arm" in states) && ("catenary_hanger" in states) && ("catenary_wire" in states)
	platform_check("electric/masts_hang_the_wire", refused && up && hung && along && art && M1.wire_images && M1.wire_images.len == 11 && !stray.wire_images)

	// Masts whose wires meet are one line, live when one is fed from the grid.
	var/datum/catenary_net/N = M1.network()
	var/one_line = N && M2.network() == N && N.masts.len == 2
	var/list/fed = N.feeders()
	var/live = N.energise() && M1.line_live()
	var/idle_draw = C.currentflow
	// A mast restored from a save joins its line again.
	train_catenary -= M1
	M1.net = null
	M1.after_load()
	platform_check("electric/line_is_fed_from_the_grid", one_line && M1.power_point == T && !M2.power_point && fed.len == 1 && fed[1] == M1 && live && idle_draw == 1 && (M1 in train_catenary) && M1.network() == M2.network() && findtext(M1.line_text(M1.network()), "The wire is live"))
	platform_electric_isolation(M1, M2)
	N = M1.network()

	// The electric locomotive: a cab at each end, a hood between, no fuel.
	var/obj/structure/trains/locomotive/electric/E = platform_car("loco_electric", 350, 9, NORTH)
	if (!istype(E))
		platform_check("electric/locomotive_builds", FALSE)
		return
	var/list/body = platform_segments(E.connected)
	var/obj/structure/trains/platform/hood = body[1]
	var/obj/structure/trains/platform/rear = E.rear_cab()
	var/loco_art = ("loco_electric_1c" in states) && ("loco_electric_4r" in states) && ("roof_loco_electric_l" in states) && ("roof_loco_electric_bc" in states)
	platform_check("electric/locomotive_builds", body.len == 3 && !E.density && hood.density && rear && rear.seg_index == 4 && !rear.density && loco_art && E.roof_images && E.roof_images.len == 3 && rear.roof_images && rear.roof_images.len == 3 && !hood.roof_images && E.car_load_weight() + 3 * hood.car_load_weight() == 5 && !E.max_fuel && E.works_in_multiple() && E.has_deadman())

	// Pantograph up: it draws from the grid through the line, by its throttle.
	var/mob/living/human/platform_rider/driver = new(platform_turf(350, 9))
	var/ready = isnull(E.start_problem())
	E.on = TRUE
	E.started(driver)
	var/standing = E.line_live && C.currentflow == 6
	E.throttle = 3
	var/pulling = E.steam_factor() == 1 && C.currentflow == 156 && N.demand() == 155
	E.refresh_consist()
	platform_check("electric/draws_from_the_grid_by_its_throttle", ready && standing && pulling && E.cruise_speed() > 0 && findtext(E.state_text(), "taking"))

	// It burns nothing as it runs, and passes from one mast's wire to the next.
	var/ran = platform_step(E, 3)
	platform_check("electric/runs_without_fuel", ran == 3 && E.y == 12 && E.fuel == 1 && E.on && E.line_check(TRUE) && train_catenary_over(E.loc) == M2 && E.fuel_per_tile(3, 10) == 0)

	// Off the end of the wire it has no power and lets go of the grid.
	ran = platform_step(E, 8)
	var/lost = !E.line_check(TRUE) && E.steam_factor() == 0 && E.cruise_speed() == 0 && E.on
	platform_check("electric/coasts_off_the_wire", ran == 8 && E.y == 20 && lost && C.currentflow == 1 && findtext(E.start_problem(), "no overhead line") && findtext(E.no_power_text(), "overhead line"))
	E.on = FALSE
	E.throttle = 0
	E.stopped(driver)

	// The tram: a platform at each end, a saloon with seats between, a roof
	// over every section.
	var/obj/structure/trains/locomotive/electric/tram/TR = platform_car("loco_tram", 350, 9, NORTH)
	if (!istype(TR))
		platform_check("electric/tram_builds", FALSE)
		return
	body = platform_segments(TR.connected)
	var/roofs = TR.roof_images ? 1 : 0
	var/seats = 0
	var/windows = 0
	var/walk_in = !TR.density
	for (var/obj/structure/trains/platform/P in body)
		if (P.roof_images && P.roof_images.len == 3)
			roofs++
		if (P.density)
			walk_in = FALSE
		for (var/turf/S in train_platform_tiles(P.loc, P.dir))
			for (var/obj/structure/bed/chair/chair in S)
				seats++
		for (var/obj/structure/train_part/edge/W in P.deck_parts)
			if (W.style == "window")
				windows++
	var/tram_art = ("loco_tram_2c" in states) && ("roof_loco_tram_ml" in states) && ("roof_loco_tram_bc" in states) && ("roof_loco_tram_c" in states)
	rear = TR.rear_cab()
	platform_check("electric/tram_builds", body.len == 3 && walk_in && roofs == 4 && seats == 4 && windows == 4 && tram_art && rear && rear.seg_index == 4 && TR.haul == 10 && TR.max_train_speed == 2 && TR.line_draw == 40)

	// A grid that cannot carry the engine at full throttle refuses it, keeps
	// the line live and takes it at a lower notch.
	G.maxpower = 30
	driver.loc = platform_turf(350, 9)
	TR.on = TRUE
	TR.started(driver)
	var/idling = TR.line_live
	TR.throttle = 3
	var/too_much = TR.steam_factor() == 0 && N.live && C.currentflow == 1
	TR.throttle = 1
	platform_check("electric/overloaded_grid_refuses_the_engine", idling && too_much && TR.steam_factor() == 1 && C.currentflow > 15 && C.currentflow < 18)

	// With the generator stopped the wire is dead.
	G.on = FALSE
	var/dead = !M1.line_live() && !TR.line_check(TRUE) && findtext(TR.start_problem(), "dead") && findtext(M1.line_text(N), "The wire is dead")
	var/mob/living/human/platform_rider/rider = new(platform_turf(350, 8))
	var/safe = !train_catenary_strike(rider, SOUTH)
	platform_check("electric/dead_line", dead && safe)

	// Somebody on a car roof under a live wire is struck; off the wire not.
	G.on = TRUE
	G.maxpower = 200
	var/struck = train_catenary_strike(rider, SOUTH)
	rider.loc = platform_turf(350, 22)
	platform_check("electric/live_wire_strikes_a_roof_rider", struck && rider.probe_burn == 40 && !train_catenary_strike(rider, SOUTH) && rider.probe_burn == 40)

	// A mast taken down takes its wire with it and lets go of the grid.
	TR.on = FALSE
	TR.throttle = 0
	TR.stopped(driver)
	M2.take_down()
	var/datum/catenary_net/alone = M1.network()
	var/down = !M2.anchored && !M2.wire_images && !train_catenary_over(platform_turf(350, 15)) && alone.masts.len == 1
	qdel(M1)
	platform_check("electric/mast_comes_down", down && !(M1 in train_catenary) && !(M1 in T.served) && !(M1 in C.connections) && !train_catenary_over(platform_turf(350, 6)))

/proc/platform_stations_run()
	for (var/ty in 2 to 25)
		platform_track(290, ty, NORTH)
	var/list/states = icon_states('icons/obj/vehicles/train_platforms.dmi')
	var/obj/structure/trains/locomotive/A = platform_car("loco_diesel", 290, 12, NORTH)
	if (!istype(A))
		platform_check("stations/name_board", FALSE)
		return
	var/list/body = platform_segments(A.connected)
	var/obj/structure/trains/platform/rear = body[body.len]
	var/mob/living/human/platform_rider/driver = new(A.loc)
	var/mob/living/human/platform_rider/rider = new(rear.loc)

	// A name board speaks to trains both ways, and to everybody aboard.
	var/obj/structure/train_lineside/station/board = new(platform_turf(292, 18))
	board.set_dir(SOUTH)
	var/blank = !board.station && isnull(board.sighting(A))
	var/named = board.set_station("Port Town") && board.station == "Port Town" && findtext(board.name, "Port Town") && !board.set_station("Port Town")
	A.reverser = 1
	A.refresh_consist()
	A.lineside_seen = null
	A.lineside_watch()
	var/list/read = A.lineside_seen
	var/list/riders = A.train_riders()
	platform_check("stations/name_board", blank && named && board.speaks_to(NORTH) && board.speaks_to(SOUTH) && read && (board in read) && riders.len == 2 && (driver in riders) && (rider in riders) && ("station_board" in states))

	// The driver has the whistle, the bell and the headlamp.
	var/list/stand = A.station_controls(A.cab_station(driver))
	var/has = ("Sound the horn" in stand) && ("Ring the bell" in stand) && ("Light the headlamp" in stand) && A.whistle_name() == "horn"
	A.on = FALSE
	var/silent = isnull(A.sound_whistle(driver))
	A.on = TRUE
	var/blown = A.sound_whistle(driver) == 0 && A.sound_bell(driver)
	A.work_control("Light the headlamp", driver)
	stand = A.station_controls(A.cab_station(driver))
	var/lit = A.headlamp && ("Put out the headlamp" in stand) && findtext(A.control_summary(), "Headlamp lit")
	A.work_control("Put out the headlamp", driver)
	platform_check("stations/whistle_bell_and_headlamp", has && silent && blown && lit && !A.headlamp)

	// In the dark a train with no light ahead runs blind, at half speed.
	var/was = time_of_day
	A.refresh_consist()
	var/by_day = A.lead_factor == 1 && !A.running_blind && !train_is_dark()
	time_of_day = "Night"
	A.refresh_consist()
	var/blind = train_is_dark() && A.lead_factor == 0.5 && A.running_blind && findtext(A.control_summary(), "Running blind")
	A.set_headlamp(TRUE)
	A.refresh_consist()
	var/lamp_lit = A.lead_factor == 1 && !A.running_blind && A.lamp_range == 5
	var/stepped = platform_step(A, 1) == 1 && A.light_range == 5
	A.set_headlamp(FALSE)
	var/obj/item/train_lamp/lamp = new(A.loc)
	lamp.set_shade("red")
	A.refresh_consist()
	var/red_is_no_light = A.lead_factor == 0.5 && A.lamp_range == 2
	lamp.set_shade("white")
	A.refresh_consist()
	var/white_lights_the_way = A.lead_factor == 1 && !A.running_blind
	time_of_day = was
	A.refresh_consist()
	platform_check("stations/running_blind_at_night", by_day && blind && lamp_lit && stepped && red_is_no_light && white_lights_the_way && A.lead_factor == 1)

	// The hand lamp turns through its colours; red on the last car is the tail lamp.
	lamp.set_shade(null)
	var/list/shown = list()
	for (var/i in 1 to 4)
		lamp.attack_self(driver)
		shown += lamp.shade ? lamp.shade : "out"
	var/turns = jointext(shown, ",") == "white,red,green,out" && lamp.icon_state == "hand_lamp" && (lamp in train_lamps)
	var/list/cars = train_consist_list(A.train_head())
	var/none = findtext(train_tail_lamp_text(cars), "No tail lamp")
	lamp.set_shade("red")
	var/wrong_end = lamp.icon_state == "hand_lamp_red" && findtext(train_tail_lamp_text(cars), "No tail lamp") && train_lamp_on(A, "red") == lamp
	lamp.loc = get_step(rear, EAST)
	var/list/lines = train_list_lines(A)
	platform_check("stations/hand_lamp_and_tail_lamp", turns && none && wrong_end && findtext(train_tail_lamp_text(cars), "Tail lamp showing") && isnull(train_lamp_on(A, "red")) && lines.len && findtext(lines[1], "Tail lamp showing") && ("hand_lamp" in states) && ("hand_lamp_white" in states) && ("hand_lamp_red" in states) && ("hand_lamp_green" in states))

// How many of a type stand on a car's deck.
/proc/platform_fitted(list/segs, kind)
	. = 0
	for (var/obj/structure/trains/platform/P in segs)
		for (var/turf/T in train_platform_tiles(P.loc, P.dir))
			for (var/atom/movable/AM in T)
				if (AM.type == kind)
					.++

// Special stock (train_stock.dm).
/proc/platform_stock_run()
	for (var/tx in list(235, 241, 247))
		for (var/ty in 2 to 25)
			platform_track(tx, ty, NORTH)
	var/list/states = icon_states('icons/obj/vehicles/train_platforms.dmi')

	// The stock car: slatted sides, straw and a sliding door each side.
	var/obj/structure/trains/platform/stock = platform_car("stock_car", 235, 25, NORTH)
	var/list/pens = platform_segments(stock)
	var/list/SL = train_car_layout("stock_car")
	var/obj/structure/trains/platform/gate_seg = pens[4]
	var/obj/structure/train_part/edge/gate = null
	var/slats = 0
	for (var/obj/structure/trains/platform/P in pens)
		for (var/obj/structure/train_part/edge/G in P.deck_parts)
			if (G.style == "slat")
				slats++
	for (var/obj/structure/train_part/edge/G in gate_seg.deck_parts)
		if (G.style == "slat_door")
			gate = G
	var/shut = gate && gate.is_door() && gate.density && findtext(gate.name, "door")
	if (gate)
		gate.set_open(TRUE)
	platform_check("stock/slatted_car_with_sliding_doors", pens.len == 8 && SL["center"] == "straw" && SL["roof"] == "stock" && slats == 18 && shut && !gate.density && gate.icon_state == "edge_slat_door_open" && stock.icon_state == "deck_center_straw" && ("edge_slat" in states) && ("edge_slat_door" in states) && ("edge_slat_door_open" in states) && ("deck_side_straw" in states) && ("roof_stock_mc" in states))

	// The ice car: one bunker at the front, cold lockers down both sides.
	var/obj/structure/trains/platform/ice = platform_car("ice_car", 235, 16, NORTH)
	var/list/bays = platform_segments(ice)
	var/list/front = train_platform_tiles(ice.loc, ice.dir)
	var/obj/structure/closet/ice_house/reefer/bunker = locate() in front[1]
	var/obj/structure/closet/ice_house/cold_locker/locker = locate() in front[3]
	var/obj/structure/trains/platform/far = bays[8]
	var/list/back = train_platform_tiles(far.loc, far.dir)
	var/obj/structure/closet/ice_house/cold_locker/last_locker = locate() in back[1]
	var/obj/structure/trains/platform/under = train_ice_car(bunker)
	platform_check("ice/built_with_a_bunker_and_lockers", bays.len == 8 && bunker && locker && last_locker && platform_fitted(bays, /obj/structure/closet/ice_house/reefer) == 1 && platform_fitted(bays, /obj/structure/closet/ice_house/cold_locker) == 11 && under && under.car_id == ice.car_id && !train_ice_car(stock) && ("edge_cold" in states) && ("edge_cold_door" in states) && ("edge_cold_door_open" in states) && ("roof_reefer_fc" in states) && ("ice_bunker" in states) && ("ice_bunker_open" in states) && ("cold_locker" in states) && ("cold_locker_open" in states))

	// The lockers are as cold as the bunker on their car.
	var/warm = !locker.is_cold() && !last_locker.is_cold() && last_locker.bunker() == bunker
	bunker.cold = 60
	var/cold = locker.is_cold() && last_locker.is_cold() && locker.bunker() == bunker && bunker.is_cold()
	var/obj/structure/closet/ice_house/cold_locker/loose = new(platform_turf(238, 4))
	var/obj/structure/closet/ice_house/reefer/spare = new(platform_turf(238, 5))
	spare.cold = 60
	platform_check("ice/lockers_cold_with_the_bunker", warm && cold && !loose.is_cold() && !loose.bunker() && bunker.slow_melt() && !spare.slow_melt() && findtext(bunker.slow_melt_text(), "insulated"))
	bunker.cold = 0
	platform_check("ice/melted_bunker_warms_the_lockers", !locker.is_cold() && !last_locker.is_cold())

	// Snow and ice offered to a locker go into the bunker.
	var/mob/living/human/platform_rider/hand = new(platform_turf(233, 12))
	var/obj/item/weapon/ice_block/block = new(platform_turf(233, 12))
	last_locker.attackby(block, hand)
	var/obj/item/weapon/ice_block/wasted = new(platform_turf(233, 12))
	loose.attackby(wasted, hand)
	platform_check("ice/ice_goes_to_the_bunker", QDELETED(block) && bunker.cold == 180 && locker.is_cold() && !QDELETED(wasted) && !loose.is_cold())
	qdel(wasted)
	qdel(loose)
	qdel(spare)

	// The baggage and mail van.
	var/obj/structure/trains/platform/mail = platform_car("mail_van", 247, 25, NORTH)
	var/list/rooms = mail ? platform_segments(mail) : list()
	platform_check("mail/sorting_office_and_baggage_room", mail && rooms.len == 8 && platform_fitted(rooms, /obj/structure/table/wood) == 2 && platform_fitted(rooms, /obj/structure/closet/cabinet) == 4 && platform_fitted(rooms, /obj/structure/closet/crate/large) == 2 && mail.roof_images && mail.roof_images.len == 3)

	// The long sleeper and dining cars.
	var/obj/structure/trains/platform/sleeper = platform_car("bogie_sleeper", 241, 25, NORTH)
	var/list/berths = sleeper ? platform_segments(sleeper) : list()
	var/obj/structure/trains/platform/dining = platform_car("bogie_dining", 241, 16, NORTH)
	var/list/tables = dining ? platform_segments(dining) : list()
	var/slept = berths.len == 8 && platform_fitted(berths, /obj/structure/bed) == 12
	var/dined = tables.len == 8 && platform_fitted(tables, /obj/structure/oven/stove) == 1 && platform_fitted(tables, /obj/structure/sink) == 1 && platform_fitted(tables, /obj/structure/closet/fridge) == 1 && platform_fitted(tables, /obj/structure/table/modern/table) == 5 && platform_fitted(tables, /obj/structure/bed/chair/comfy/diner_booth) == 6
	platform_check("long/sleeper_and_dining_cars", slept && dined)

// The crane car (train_crane.dm). It shares column 247 with the mail van.
/proc/platform_crane_run()
	var/obj/structure/trains/platform/car = platform_car("crane_car", 247, 16, NORTH)
	var/list/segs = platform_segments(car)
	var/list/front = train_platform_tiles(car.loc, car.dir)
	var/obj/structure/railway_gun_brace/lever = locate() in front[1]
	var/obj/structure/workshop_machine/shear_legs/crane/steam/rail/crane = locate() in platform_turf(247, 15)
	var/obj/structure/workshop_machine/shear_legs/legs = new(platform_turf(250, 3))
	var/list/L = train_car_layout("crane_car")
	var/list/sheet = icon_states('icons/obj/vehicles/train_loads.dmi')
	platform_check("crane/built_on_a_ballasted_car", segs.len == 4 && L["weight"] == 1 && lever && crane && crane.dir == NORTH && crane.anchored && crane.sling_reach() == 5 && legs.sling_reach() == 1 && train_deck_at(crane.loc) && !train_deck_at(legs.loc) && ("rail_crane" in sheet) && ("rail_crane_haul" in sheet))
	qdel(legs)

	// It lifts only with the outriggers down.
	var/mob/living/human/platform_rider/hand = new(platform_turf(246, 15))
	var/unbraced = findtext(crane.rail_problem(), "outriggers") && !crane.hauler_ready(hand)
	for (var/obj/structure/trains/platform/P in segs)
		P.last_moved = -1000
	var/braced = lever && !lever.set_braced(TRUE) && car.braced && isnull(crane.rail_problem()) && crane.hauler_ready(hand)
	var/obj/structure/workshop_machine/shear_legs/crane/steam/rail/loose = new(platform_turf(250, 3))
	platform_check("crane/lifts_only_when_braced", unbraced && braced && findtext(loose.rail_problem(), "rail car") && crane.out_of_fuel(hand))
	qdel(loose)

	// A load within reach swings onto another car or down beside the track.
	var/obj/structure/trains/platform/flat = platform_car("flatbed", 247, 11, NORTH)
	var/obj/structure/closet/crate/load = new(platform_turf(244, 15))
	var/list/choices = crane.haul_choices(load)
	var/turf/aboard = null
	var/turf/beside = null
	for (var/label in choices)
		if (findtext(label, "Swing it onto"))
			aboard = choices[label]
		if (findtext(label, "beside the track"))
			beside = choices[label]
	var/obj/structure/trains/platform/landed = train_deck_at(aboard)
	var/on_car = aboard && landed && flat && landed.car_id == flat.car_id && get_dist(aboard, crane) <= 5 && get_dist(load, crane) == 3 && isnull(crane.sling_problem(load))
	var/on_ground = beside && !train_deck_at(beside) && !(locate(/obj/structure/rails) in beside) && beside != load.loc
	platform_check("crane/swings_a_load_onto_a_car", on_car && on_ground)
	if (aboard)
		load.forceMove(aboard)
	choices = crane.haul_choices(load)
	var/turf/off = null
	var/turf/again = null
	for (var/label in choices)
		if (findtext(label, "beside the track"))
			off = choices[label]
		if (findtext(label, "Swing it onto"))
			again = choices[label]
	var/obj/structure/trains/platform/other = train_deck_at(again)
	platform_check("crane/sets_a_load_down_beside_the_track", aboard && off && !train_deck_at(off) && get_dist(off, crane) <= 5 && (!again || (other && other.car_id != car.car_id && again != load.loc)))
	// Outriggers up: nothing can be hauled, and the far side of reach is refused.
	lever.set_braced(FALSE)
	var/obj/structure/closet/crate/far_load = new(platform_turf(240, 15))
	platform_check("crane/reach_and_brace_limit_it", !car.braced && !crane.hauler_ready(hand) && get_dist(far_load, crane) > crane.sling_reach())
	qdel(far_load)

// Building a car around people: nobody is left shut inside a solid section.
/proc/platform_entomb_run()
	for (var/ty in 2 to 25)
		platform_track(358, ty, NORTH)
	var/mob/living/human/platform_rider/builder = new(platform_turf(358, 19))
	var/mob/living/human/platform_rider/beside = new(platform_turf(357, 17))
	var/mob/living/human/platform_rider/in_cab = new(platform_turf(359, 15))
	var/obj/structure/trains/locomotive/coal/mainline/E = platform_car("loco_mainline", 358, 20, NORTH)
	var/list/body = istype(E) ? platform_segments(E.connected) : list()
	var/list/footprint = list()
	for (var/ty in 15 to 20)
		for (var/tx in 357 to 359)
			footprint += platform_turf(tx, ty)
	var/freed = istype(E) && body.len == 5 && !(builder.loc in footprint) && !(beside.loc in footprint) && !train_tile_walled(builder.loc) && !train_tile_walled(beside.loc) && get_dist(builder, platform_turf(358, 19)) <= 2 && get_dist(beside, platform_turf(357, 17)) <= 2
	platform_check("assembly/nobody_shut_inside", freed && train_tile_walled(platform_turf(358, 19)) && train_tile_walled(platform_turf(357, 17)))
	platform_check("assembly/cab_rider_stays", in_cab.loc == platform_turf(359, 15) && !train_tile_walled(in_cab.loc))

// Crowbars: one-tile cars come apart into part of their cost, heavy engines
// and tenders fold back into their kits.
/proc/platform_dismantle_run()
	for (var/ty in 2 to 25)
		platform_track(444, ty, NORTH)
		platform_track(448, ty, NORTH)
	craftlist_lists["dismantle_probe"] = list(list("/material/iron/", "flatbed wagon", "/obj/structure/trains/transport/flatbed", "4", "250", "1"))
	crafted_refund_stack_cache = list()
	crafted_refund_units_cache = list()
	var/obj/structure/trains/transport/flatbed/flat = new(platform_turf(444, 3))
	var/obj/structure/trains/storage/closed/box = new(platform_turf(444, 4))
	var/obj/structure/trains/locomotive/coal/loco = new(platform_turf(444, 7))
	box.connected = flat
	var/coupled = findtext(flat.wagon_dismantle_problem(), "Uncouple") && findtext(box.wagon_dismantle_problem(), "Uncouple")
	box.connected = null
	var/obj/item/stack/material/iron/bar = new(box.storage)
	var/full = findtext(box.wagon_dismantle_problem(), "Empty")
	qdel(bar)
	var/mob/living/human/platform_rider/aboard = new(platform_turf(444, 3))
	var/ridden_wagon = findtext(flat.wagon_dismantle_problem(), "is on")
	qdel(aboard)
	loco.on = TRUE
	var/running = findtext(loco.wagon_dismantle_problem(), "Shut")
	loco.on = FALSE
	platform_check("dismantle/one_tile_refusals", coupled && full && ridden_wagon && running && !flat.wagon_dismantle_problem() && !box.wagon_dismantle_problem() && !loco.wagon_dismantle_problem())
	var/turf/flat_at = flat.loc
	var/obj/item/stack/material/iron/back = flat.take_apart()
	platform_check("dismantle/one_tile_half_cost", QDELETED(flat) && istype(back) && back.loc == flat_at && back.amount == 2 && crafted_refund_units(/obj/structure/trains/transport/flatbed) == 4)
	craftlist_lists -= "dismantle_probe"

	var/obj/structure/trains/locomotive/coal/heavy/E = platform_car("loco_steam", 448, 20, NORTH)
	var/obj/structure/trains/platform/F = platform_car("flatbed", 448, 16, NORTH)
	var/list/F_segs = platform_segments(F)
	var/obj/structure/trains/last = istype(E) ? train_unit_last(E) : null
	last.connected = F
	var/linked = findtext(E.pack_problem(), "Uncouple")
	last.connected = null
	var/mob/living/human/platform_rider/rider = new(platform_turf(447, 18))
	var/ridden = findtext(E.pack_problem(), "Clear everything")
	qdel(rider)
	var/id = E.car_id
	var/ready = !E.pack_problem()
	var/obj/structure/train_car_kit/K = ready ? E.pack_into_kit() : null
	var/left = 0
	for (var/obj/structure/trains/TR in world)
		if (TR.car_id == id && !QDELETED(TR) && TR.loc)
			left++
	platform_check("dismantle/heavy_engine_into_kit", linked && ridden && istype(K) && K.car_kind == "loco_steam" && !K.furnished && K.loc == platform_turf(448, 20) && left == 0 && !(locate(/obj/structure/train_part) in platform_turf(447, 19)) && F_segs.len == TRAIN_CAR_LENGTH)
	var/obj/structure/trains/platform/T = platform_car("tender", 444, 20, NORTH)
	var/tender_ready = istype(T) && !T.dismantle_problem()
	var/obj/structure/train_car_kit/TK = tender_ready ? T.pack_car() : null
	platform_check("dismantle/tender_into_kit", tender_ready && istype(TK) && TK.car_kind == "tender" && !(locate(/obj/structure/trains) in platform_turf(444, 18)) && K && !K.assembly_problem(NORTH))
// Room to turn (train_bends.dm): bends closer together than a car is long
// fold it onto itself, so track refuses them and trains stop short.
/proc/platform_bend_line(x, east)
	for (var/ty in 2 to 10)
		platform_track(x, ty, NORTH)
	for (var/tx in x + 1 to x + east)
		platform_track(tx, 10, EAST)
	for (var/ty in 11 to 25)
		platform_track(x + east, ty, NORTH)

/proc/platform_bends_run()
	// An S-bend with its bends two tiles apart, and one with them five apart.
	platform_bend_line(366, 2)
	platform_bend_line(371, 5)
	var/tight = rail_bend_at(platform_turf(366, 10)) && rail_bend_at(platform_turf(368, 10)) && rail_bend_gap(platform_turf(366, 10), NORTH, 7) == 2
	var/wide = rail_bend_at(platform_turf(371, 10)) && rail_bend_at(platform_turf(376, 10)) && rail_bend_gap(platform_turf(371, 10), NORTH, 7) == 5 && !rail_bend_gap(platform_turf(371, 10), NORTH, 4)
	platform_check("bends/gap_measured", tight && wide && track_bend_spacing(platform_turf(367, 10)) == 2 && track_bend_spacing(platform_turf(372, 10)) == 5)
	// Laying: two tiles apart is refused, five is allowed with a warning for
	// long bogie stock, and a lone corner is fine.
	platform_check("bends/laying_refuses_close_bends", track_bend_problem(platform_turf(367, 10)) && !track_bend_problem(platform_turf(372, 10)) && track_bend_warning(platform_turf(372, 10)) && !track_bend_problem(platform_turf(10, 20)) && !track_bend_warning(platform_turf(10, 20)))
	// A four-tile car stops short of the tight bends; its engine stays on the rails.
	var/obj/structure/trains/platform/front = platform_car("flatbed", 366, 6, NORTH)
	var/obj/structure/trains/locomotive/coal/L = new(platform_turf(366, 7))
	L.dir = NORTH
	L.fuel = 100
	L.on = TRUE
	L.connected = front
	var/stepped = platform_step(L, 10)
	platform_check("bends/long_car_stops_short", stepped == 2 && L.loc == platform_turf(366, 9) && train_longest_car(train_consist_list(L)) == 4 && train_bend_problem(train_consist_list(L), platform_turf(366, 10), NORTH) && !L.derailed)
	// One-tile wagons take the tight bends; the four-tile car takes the wider ones.
	var/obj/structure/trains/locomotive/coal/S = new(platform_turf(366, 5))
	S.dir = NORTH
	S.fuel = 100
	S.on = TRUE
	qdel(L)
	for (var/obj/structure/trains/platform/P in platform_segments(front))
		qdel(P)
	var/obj/structure/trains/W = new /obj/structure/trains/transport/flatbed(platform_turf(366, 4))
	W.dir = NORTH
	S.connected = W
	platform_check("bends/short_wagons_take_tight_bends", platform_step(S, 12) == 12 && S.loc == platform_turf(368, 15) && W.loc == platform_turf(368, 14))
	var/obj/structure/trains/platform/car = platform_car("flatbed", 371, 6, NORTH)
	var/obj/structure/trains/locomotive/coal/E = new(platform_turf(371, 7))
	E.dir = NORTH
	E.fuel = 100
	E.on = TRUE
	E.connected = car
	// Driven at the tight bends faster than a crawl, the train leaves the rails.
	platform_bend_line(380, 2)
	var/obj/structure/trains/platform/fast_car = platform_car("flatbed", 380, 6, NORTH)
	var/obj/structure/trains/locomotive/coal/F = new(platform_turf(380, 7))
	F.dir = NORTH
	F.fuel = 100
	F.on = TRUE
	F.connected = fast_car
	F.throttle = 3
	F.rail_speed = 3.5
	F.drive()
	drive_wait(F)
	// A light engine stalls rather than leave the rails; the car behind it comes off.
	platform_check("bends/fast_into_tight_bends_derails", !F.driving && fast_car.derailed && F.y <= 9 && F.rail_speed == 0)
	platform_check("bends/car_takes_wider_bends", platform_step(E, 18) == 18 && E.loc == platform_turf(376, 20) && platform_parts_placed(platform_segments(car)))

// A corner at (x, y): track north from y 2, then east for east tiles.
/proc/platform_arc_line(x, east, y = 10)
	for (var/ty in 2 to y)
		platform_track(x, ty, NORTH)
	for (var/tx in x + 1 to x + east)
		platform_track(tx, y, EAST)
	return locate(/obj/structure/rails/turn) in platform_turf(x, y)

/proc/platform_arcs_run()
	// Easing a corner: radius 8 needs eight straight tiles each side.
	var/obj/structure/rails/turn/short = platform_arc_line(432, 6)
	platform_check("arcs/needs_straights", short && short.arc_problem(8) && !short.arc_problem(4))
	// Too fast for the curve, the train leaves the rails; under its limit,
	// which is above a sharp corner's, it does not.
	train_arc_ease(short, 4)
	var/obj/structure/trains/platform/fast_car = platform_car("flatbed", 432, 5, NORTH)
	var/obj/structure/trains/locomotive/coal/F = new(platform_turf(432, 6))
	F.dir = NORTH
	F.fuel = 100
	F.on = TRUE
	F.connected = fast_car
	var/calm = F.rail_speed
	F.rail_speed = 3.8
	var/under = !F.curve_check(F, EAST, platform_turf(432, 5)) && !fast_car.derailed
	F.rail_speed = calm
	F.throttle = 3
	F.rail_speed = 6.5
	F.drive()
	drive_wait(F)
	platform_check("arcs/too_fast_leaves_the_rails", under && fast_car.derailed && !F.driving)
	var/obj/structure/rails/turn/C = platform_arc_line(402, 10)
	var/obj/structure/trains/W0 = new /obj/structure/trains/transport/flatbed(platform_turf(402, 8))
	var/blocked = C.arc_problem(4)
	qdel(W0)
	var/turf/S = train_arc_ease(C, 4)
	var/arcs = 0
	for (var/turf/T in block(platform_turf(400, 2), platform_turf(412, 12)))
		if (train_arc_at(T))
			arcs++
	var/obj/structure/rails/arc/first = train_arc_at(platform_turf(402, 6))
	var/obj/structure/rails/arc/last = train_arc_at(platform_turf(406, 10))
	// The curve may be laid from either end; it is the same curve.
	platform_check("arcs/eases_corner", blocked && (S == platform_turf(402, 6) || S == platform_turf(406, 10)) && arcs == 9 && first && last && !rail_at(platform_turf(402, 10)) && rail_at(platform_turf(402, 5)) && (SOUTH in first.exits()) && (EAST in last.exits()) && !rail_bend_at(platform_turf(403, 8)))
	// A short engine and wagon run round it and out along the straight.
	var/obj/structure/trains/locomotive/coal/L = new(platform_turf(402, 4))
	L.dir = NORTH
	L.fuel = 100
	L.on = TRUE
	var/obj/structure/trains/W = new /obj/structure/trains/transport/flatbed(platform_turf(402, 3))
	W.dir = NORTH
	L.connected = W
	var/stepped = platform_step(L, 13)
	platform_check("arcs/train_runs_round", stepped == 13 && L.loc == platform_turf(409, 10) && L.dir == EAST && W.loc == platform_turf(408, 10) && !L.train_arc_posed && !L.pixel_x && !L.pixel_y)
	// Speed: a wide curve is taken faster than a sharp corner, not without limit.
	platform_check("arcs/speed_limits", rail_arc_speed_at(platform_turf(403, 8)) == 4 && !rail_arc_speed_at(platform_turf(402, 5)) && train_arc_speed(8) == 6)
	// Put back to a sharp corner with a crowbar.
	qdel(L)
	qdel(W)
	var/obj/structure/rails/arc/A = train_arc_at(platform_turf(403, 8))
	var/sharp_ok = !A.sharpen_problem()
	train_arc_sharpen(A)
	platform_check("arcs/sharpens_back", sharp_ok && rail_bend_at(platform_turf(402, 10)) && !train_arc_at(platform_turf(403, 8)) && !rail_at(platform_turf(403, 8)) && rail_at(platform_turf(402, 7)) && rail_at(platform_turf(406, 10)))
	// A four-section car rounds a radius 8 curve: its deck lies across the
	// staircase, it is drawn on the circle, and it comes out square.
	var/obj/structure/rails/turn/C8 = platform_arc_line(414, 20, 20)
	var/turf/S8 = train_arc_ease(C8, 8)
	var/obj/structure/trains/platform/car = platform_car("flatbed", 414, 8, NORTH)
	var/obj/structure/trains/locomotive/coal/E = new(platform_turf(414, 9))
	E.dir = NORTH
	E.fuel = 100
	E.on = TRUE
	E.connected = car
	var/list/segs = platform_segments(car)
	var/worst = 0
	var/posed = FALSE
	var/placed = TRUE
	var/flips = 0
	var/last_dir = E.dir
	for (var/i in 1 to 24)
		if (!platform_step(E, 1))
			break
		var/list/tiles = platform_car_tiles(segs)
		var/list/seen = list()
		var/twice = 0
		for (var/turf/T in tiles)
			if (T in seen)
				twice++
			seen += T
		worst = max(worst, twice)
		if (E.dir != last_dir)
			flips++
		last_dir = E.dir
		if (!platform_parts_placed(segs))
			placed = FALSE
		for (var/obj/structure/trains/platform/P in segs)
			if (P.train_arc_posed && (P.pixel_x || P.pixel_y || !(P.transform ~= matrix())))
				posed = TRUE
	var/square = TRUE
	for (var/obj/structure/trains/platform/P in segs)
		if (P.train_arc_posed || P.pixel_x || P.pixel_y || P.dir != EAST)
			square = FALSE
		for (var/obj/structure/train_part/part in P.deck_parts)
			if (part.train_arc_posed || part.pixel_x || part.pixel_y)
				square = FALSE
	platform_check("arcs/car_deck_lies_across", placed && worst <= 2)
	// It faces the way the track mostly runs, turning once, not at every step.
	platform_check("arcs/car_drawn_on_circle", posed && flips == 1)
	platform_check("arcs/car_comes_out_square", (S8 == platform_turf(414, 12) || S8 == platform_turf(422, 20)) && E.loc == platform_turf(427, 20) && square)
	// Furniture aboard turns once over the whole curve, not at every step.
	platform_check("arcs/turns_once", train_turning(platform_turf(414, 15), NORTH, platform_turf(415, 15), EAST) == 0 && train_turning(platform_turf(414, 5), NORTH, platform_turf(414, 6), NORTH) == 0)

// A rail plan: north from (5,14) to (5,5) and east from (5,14) to (14,14).
/proc/platform_rail_plan_l()
	var/datum/rail_plan/D = new
	D.name = "Branch line"
	for (var/y in 5 to 14)
		D.set_track(5, y, TRUE)
	for (var/x in 6 to 14)
		D.set_track(x, 14, TRUE)
	return D

/proc/platform_rail_plans_run()
	var/datum/rail_plan/D = platform_rail_plan_l()
	var/eased = D.set_curve(5, 14, 4)
	var/datum/rail_plan/back = rail_plan_from_code(D.to_code())
	var/list/done = D.finished_tiles()
	platform_check("rail_plan/code_round_trip", eased && back && back.name == "Branch line" && back.tile_count() == 19 && back.curve_at(5, 14) == 4 && D.is_corner(5, 14) && !D.curve_problem(5, 14) && done.len == 19 && !done["5,14"] && !rail_plan_from_code("C13RAIL/1/x/41,1,1/") && !rail_plan_from_code("C13RAIL/1/x/5,5,1/6,6,4"))
	var/datum/design_report/R = D.check_design()
	var/clean = !R.blocked()
	qdel(R)
	// Radius 8 takes eight straight tiles each side: both legs have them,
	// until a branch off the east leg leaves it short.
	D.set_curve(5, 14, 8)
	var/fits8 = !D.curve_problem(5, 14)
	D.set_track(13, 13, TRUE)
	var/short = D.curve_problem(5, 14)
	qdel(D)
	// Corners two tiles apart fold a car and are refused; five apart only
	// trouble long cars.
	var/datum/rail_plan/S = new
	for (var/y in 1 to 5)
		S.set_track(1, y, TRUE)
	S.set_track(2, 5, TRUE)
	S.set_track(3, 5, TRUE)
	for (var/y in 6 to 10)
		S.set_track(3, y, TRUE)
	R = S.check_design()
	var/folded = R.blocked()
	qdel(R)
	qdel(S)
	S = new
	for (var/y in 1 to 5)
		S.set_track(1, y, TRUE)
	for (var/x in 2 to 6)
		S.set_track(x, 5, TRUE)
	for (var/y in 6 to 10)
		S.set_track(6, y, TRUE)
	R = S.check_design()
	var/warned = !R.blocked() && R.count(DESIGN_WARNING) && S.bend_gap(1, 5) == 5
	qdel(R)
	qdel(S)
	platform_check("rail_plan/checks_bends_and_curves", clean && fits8 && short && folded && warned)
	// Pegged out: one peg on every tile of the line, the eased corner noted;
	// laying track on a pegged tile pulls its peg.
	D = platform_rail_plan_l()
	D.set_curve(5, 14, 4)
	var/list/result = rail_plan_peg_out(D, 275, 24, 1, "rail-probe")
	var/obj/effect/build_marker/corner = build_marker_at(platform_turf(280, 10), "rail-probe")
	var/pegs = length(build_markers_of("rail-probe"))
	platform_track(280, 19, NORTH)
	var/obj/effect/build_marker/laid = build_marker_at(platform_turf(280, 19), "rail-probe")
	if (laid)
		laid.look()
	platform_check("rail_plan/pegged_out", result && result["pegs"] == 19 && pegs == 19 && corner && findtext(corner.note, "radius 4") && (!laid || QDELETED(laid)) && build_marker_built("rail", platform_turf(280, 19)))
	build_markers_pull("rail-probe")
	qdel(D)

/world/New()
	OpenPort("none")
	GLOB.all_observable_events = list()
	GLOB.moved_event = new /decl/observ/moved
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.name_set_event = new /decl/observ/name_set
	GLOB.stat_set_event = new /decl/observ/stat_set
	GLOB.destroyed_event = new
	try
		platform_probe_run()
		platform_warfare_run()
		platform_warehouse_run()
		platform_driving_run()
		platform_heavy_run()
		platform_viewers_run()
		platform_position_run()
		platform_facing_run()
		platform_long_run()
		platform_coupling_run()
		platform_boiler_run()
		platform_tender_run()
		platform_cab_run()
		platform_crash_run()
		platform_brake_run()
		platform_rolling_run()
		platform_adhesion_run()
		platform_shunting_run()
		platform_servicing_run()
		platform_depot_run()
		platform_snow_run()
		platform_freight_run()
		platform_tank_run()
		platform_stock_run()
		platform_crane_run()
		platform_diesel_run()
		platform_conductor_run()
		platform_signals_run()
		platform_token_isolation()
		platform_derail_run()
		platform_stations_run()
		platform_big_warehouse_run()
		platform_trackworks_run()
		platform_turntable_run()
		platform_trackwear_run()
		platform_goods_run()
		platform_early_run()
		platform_electric_run()
		platform_entomb_run()
		platform_dismantle_run()
		platform_bends_run()
		platform_arcs_run()
		platform_rail_plans_run()
		platform_rail_grade_run()
	catch (var/exception/E)
		platform_probe_runtime_error = TRUE
		world.log << "Fixture aborted: [E] at [E.file]:[E.line]"
	text2file(json_encode(list("commit" = world.params["tested_commit"], "check_count" = platform_probe_checks.len, "failed_labels" = platform_probe_failed, "runtime_error" = platform_probe_runtime_error, "checks" = platform_probe_checks)), "result.json")
	world.log << "COMPLETE train platform fixture"
	del(world)
