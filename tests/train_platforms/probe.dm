// Train platform fixture: real train_platforms.dm, trains.dm and track laying
// procs on a small map. A locomotive pulls platform cars along straight track
// and round a curve; decks, walls and cargo must stay with each segment.
/world
	hub = ""
	hub_password = ""
	maxx = 208
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
	platform_check("heavy/one_piece", findtext(boiler.dismantle_problem(), "one piece") && rail_warehouse_too_long(E) && rail_warehouse_too_long(bunker))
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
	platform_check("tender/built_in_one_piece", last && tender.icon_state == "loco_tender_1c" && !tender.density && last.density && tender.tender_store() == tender && last.tender_store() == tender && tender.dismantle_problem() && tender.coupler_f && last.coupler_r && ("loco_tender_1l" in states) && ("loco_tender_4r" in states) && platform_parts_placed(segs))
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
	platform_check("cab/each_station_has_its_controls", stand.len == 5 && ("Throttle up" in stand) && ("Brake" in stand) && ("Sand the rails" in stand) && !("Light the fire" in stand) && door.len == 1 && door[1] == "Light the fire" && side.len == 1 && side[1] == "Injector off")
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
	platform_check("cab/small_engines_have_one_place", !small.has_stations() && small.cab_station(guest) == "all" && small.at_firebox(guest) && all.len == 7 && !diesel["stations"] && steam["stations"] && armored["stations"])

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
	catch (var/exception/E)
		platform_probe_runtime_error = TRUE
		world.log << "Fixture aborted: [E] at [E.file]:[E.line]"
	text2file(json_encode(list("commit" = world.params["tested_commit"], "check_count" = platform_probe_checks.len, "failed_labels" = platform_probe_failed, "runtime_error" = platform_probe_runtime_error, "checks" = platform_probe_checks)), "result.json")
	world.log << "COMPLETE train platform fixture"
	del(world)
