// Train platform fixture: real train_platforms.dm, trains.dm and track laying
// procs on a small map. A locomotive pulls platform cars along straight track
// and round a curve; decks, walls and cargo must stay with each segment.
/world
	hub = ""
	hub_password = ""
	maxx = 70
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
	L.throttle = 0
	L.braking = TRUE
	platform_check("drive/brake_stops", drive_wait(L) && L.rail_speed == 0 && !L.automovement)

	// Load: fourteen loaded wagons are more than one engine's rated pull.
	var/obj/structure/trains/locomotive/coal/H = drive_train(56, 17, 14, /obj/structure/trains/storage/closed)
	H.throttle = 3
	H.refresh_consist()
	var/heavy_cruise = H.cruise_speed()
	platform_check("load/heavy_slower", H.pull_ratio() < 1 && heavy_cruise < 10 / H.max_train_speed && heavy_cruise > 0)

	// Braking distance grows with the train: both start at the same speed.
	for (var/obj/structure/trains/locomotive/E in list(L, H))
		E.throttle = 0
		E.braking = TRUE
		E.rail_speed = 2.5
	var/light_from = L.y
	var/heavy_from = H.y
	L.drive()
	H.drive()
	drive_wait(L)
	drive_wait(H)
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
	helper.throttle = 3
	helper.locomotive()
	platform_check("double_heading/helper_follows", helper.lead_car() == rear && !helper.driving)

	// Tender: the fireman tops up a low firebox from a hitched tender.
	var/obj/structure/trains/locomotive/coal/T = drive_train(52, 12, 0)
	var/obj/structure/trains/storage/tender/tender = new(platform_turf(52, 11))
	tender.dir = NORTH
	T.connected = tender
	var/obj/item/stack/ore/coal/coal = new(tender.storage)
	coal.amount = 5
	T.fuel = 20
	T.refresh_consist()
	platform_check("tender/feeds_firebox", T.fuel == 95 && QDELETED(coal))

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
	for (var/x in list(62, 66))
		for (var/y in 2 to 25)
			platform_track(x, y, NORTH)
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
	platform_check("heavy/one_piece", findtext(boiler.dismantle_problem(), "one piece") && rail_warehouse_too_long(E) && rail_warehouse_too_long(bunker))
	var/mob/living/human/platform_rider/driver = new(platform_turf(61, 10))
	bunker.attackby(new /obj/item/stack/ore/coal(platform_turf(61, 10)), driver)
	platform_check("heavy/fuel_from_any_section", E.fuel == 15)
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

	// Armored: plate over everything, bulletproof cab doors.
	var/obj/structure/trains/locomotive/coal/armored/heavy/AL = platform_car("loco_armored", 66, 24, NORTH)
	var/list/plated = istype(AL) ? platform_segments(AL.connected) : list()
	var/doors = 0
	var/obj/structure/trains/platform/armored_cab = plated.len == 3 ? plated[2] : null
	if (armored_cab)
		for (var/obj/structure/train_part/edge/G in armored_cab.deck_parts)
			if (G.is_armor() && G.is_door())
				doors++
	AL.ex_act(1.0)
	platform_check("armored_heavy/plated", istype(AL) && AL.overlays.len == 0 && doors == 2 && AL.health == 5700 && !AL.disabled && AL.haul == 40)

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
	catch (var/exception/E)
		platform_probe_runtime_error = TRUE
		world.log << "Fixture aborted: [E] at [E.file]:[E.line]"
	text2file(json_encode(list("commit" = world.params["tested_commit"], "check_count" = platform_probe_checks.len, "failed_labels" = platform_probe_failed, "runtime_error" = platform_probe_runtime_error, "checks" = platform_probe_checks)), "result.json")
	world.log << "COMPLETE train platform fixture"
	del(world)
