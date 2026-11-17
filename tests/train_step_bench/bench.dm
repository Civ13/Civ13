// Train step benchmark (docs/train-step-cost.md): the real train code on a
// bare map. Each scenario builds one train on its own line, steps it a fixed
// number of tiles and reports the mean and worst cost of a step in
// milliseconds, with the number of objects the step moves.
/world
	hub = ""
	hub_password = ""
	maxx = 190
	maxy = 110
	maxz = 1
	turf = /turf/floor/dirt
	area = /area/caribbean
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/world/Topic(T, addr, master, key)
	return "Closed train step benchmark"

/mob/living/human/bench_rider/New()
	return
/mob/living/human/bench_rider/update_icons()
	return

#define BENCH_STEPS 20
#define BENCH_WARMUP 2

var/global/list/bench_rows = list()
var/global/bench_runtime_error = FALSE
var/global/bench_line = 0

/world/Error(exception/E)
	bench_runtime_error = TRUE
	world.log << "Unexpected benchmark runtime: [E] at [E.file]:[E.line]"
	return ..()

/proc/bench_ms(t)
	return (world.tick_usage - t) * world.tick_lag

/proc/bench_track(x, y, facing)
	var/obj/structure/rail_bed/B = track_place_bed(locate(x, y, 1), facing)
	B.place_rails()
	return B.spike()

/proc/bench_kit(kind, x, y, heading)
	var/obj/structure/train_car_kit/K = new(locate(x, y, 1))
	K.set_kind(kind)
	var/problem = K.assembly_problem(heading)
	if (problem)
		CRASH("assembly problem for [kind] at [x],[y]: [problem]")
	return K.assemble(heading)

/proc/bench_tail(obj/structure/trains/head)
	var/obj/structure/trains/car = head
	while (car.connected)
		car = car.connected
	return car

// A heavy steam engine at (x, y) facing east with `cars` cars of `kind`
// coupled behind it. riders: people standing on each car.
/proc/bench_train(kind, cars, x, y, riders = 0)
	var/obj/structure/trains/locomotive/coal/heavy/E = bench_kit("loco_steam", x, y, EAST)
	E.fuel = E.max_fuel
	E.on = TRUE
	var/obj/structure/trains/tail = bench_tail(E)
	var/at = x - TRAIN_CAR_LENGTH
	for (var/i in 1 to cars)
		var/obj/structure/trains/platform/front = bench_kit(kind, at, y, EAST)
		tail.connected = front
		tail = bench_tail(front)
		for (var/r in 1 to riders)
			new /mob/living/human/bench_rider(locate(at - ((r - 1) % TRAIN_CAR_LENGTH), y + ((r % 2) ? 1 : -1), 1))
		at -= TRAIN_CAR_LENGTH
	return E

// The one-tile stock: a small steam engine and closed wagons.
/proc/bench_small_train(cars, x, y)
	var/obj/structure/trains/locomotive/coal/E = new(locate(x, y, 1))
	E.dir = EAST
	E.fuel = E.max_fuel
	E.on = TRUE
	var/obj/structure/trains/tail = E
	for (var/i in 1 to cars)
		var/obj/structure/trains/storage/closed/W = new(locate(x - i, y, 1))
		W.dir = EAST
		tail.connected = W
		tail = W
	return E

// What one step has to move: sections, their deck and wall parts, and the load.
/proc/bench_census(obj/structure/trains/locomotive/E)
	var/list/cars = train_consist_list(E)
	var/parts = 0
	var/load = 0
	var/list/seen = list()
	for (var/obj/structure/trains/car in cars)
		if (istype(car, /obj/structure/trains/platform))
			var/obj/structure/trains/platform/P = car
			if (P.deck_parts)
				parts += P.deck_parts.len
		else if (istype(car, /obj/structure/trains/locomotive))
			var/obj/structure/trains/locomotive/L = car
			if (L.body_parts)
				parts += L.body_parts.len
		if (!car.wide_body())
			continue
		for (var/turf/T in train_platform_tiles(car.loc, car.dir))
			for (var/atom/movable/AM in T)
				if (!seen[AM] && train_platform_carries(AM))
					seen[AM] = TRUE
					load++
	return list("sections" = cars.len, "parts" = parts, "load" = load)

/proc/bench_measure(name, obj/structure/trains/locomotive/E, backward = FALSE)
	var/list/census = bench_census(E)
	E.refresh_consist()
	E.reverser = backward ? -1 : 1
	var/total = 0
	var/worst = 0
	var/done = 0
	for (var/i in 1 to BENCH_WARMUP + BENCH_STEPS)
		// One step per tick, so a slow step never borrows from the next.
		sleep(world.tick_lag)
		E.automovement = TRUE
		E.fuel = E.max_fuel
		var/t = world.tick_usage
		var/moved = backward ? E.process_rail_reverse() : E.process_rail_movement()
		var/ms = bench_ms(t)
		if (!moved)
			break
		if (i > BENCH_WARMUP)
			total += ms
			worst = max(worst, ms)
			done++
	// The clearance check on its own, with the train standing.
	var/list/route = E.rail_target(E.dir)
	var/check = 0
	if (route && !backward)
		sleep(world.tick_lag)
		var/t = world.tick_usage
		for (var/i in 1 to 10)
			train_consist_obstacle(E, route[1], route[2])
		check = bench_ms(t) / 10
	var/list/row = list("name" = name, "sections" = census["sections"], "parts" = census["parts"], "load" = census["load"],
		"steps" = done, "mean_ms" = done ? total / done : 0, "worst_ms" = worst, "clearance_ms" = check)
	bench_rows += list(row)
	world.log << "BENCH [name]: [census["sections"]] sections, [census["parts"]] parts, [census["load"]] carried, [done] steps, mean [row["mean_ms"]] ms, worst [worst] ms, clearance [check] ms"

// A straight line long enough for the longest train and its run.
/proc/bench_straight()
	bench_line += 4
	for (var/x in 2 to 185)
		bench_track(x, bench_line, EAST)
	return bench_line

/proc/bench_run()
	for (var/cars in list(1, 3, 6, 12, 24, 29))
		bench_measure("flatbed x[cars]", bench_train("flatbed", cars, 150, bench_straight()))
	for (var/cars in list(1, 3, 6, 12, 24, 29))
		bench_measure("coach x[cars]", bench_train("coach", cars, 150, bench_straight()))
	for (var/cars in list(6, 12, 24))
		bench_measure("coach x[cars] with 8 riders a car", bench_train("coach", cars, 150, bench_straight(), 8))
	bench_measure("storage x12", bench_train("storage", 12, 150, bench_straight()))
	bench_measure("sleeper x12", bench_train("sleeper", 12, 150, bench_straight()))
	bench_measure("coach x12 backward", bench_train("coach", 12, 175, bench_straight()), TRUE)
	for (var/cars in list(12, 48))
		bench_measure("one-tile wagons x[cars]", bench_small_train(cars, 150, bench_straight()))
	// Round a curve: east along the line, then north.
	bench_line += 4
	var/y0 = bench_line
	for (var/x in 2 to 60)
		bench_track(x, y0, EAST)
	for (var/y in y0 + 1 to y0 + 24)
		bench_track(60, y, NORTH)
	bench_measure("coach x6 round a curve", bench_train("coach", 6, 50, y0))

/world/New()
	OpenPort("none")
	GLOB.all_observable_events = list()
	GLOB.moved_event = new /decl/observ/moved
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.name_set_event = new /decl/observ/name_set
	GLOB.stat_set_event = new /decl/observ/stat_set
	GLOB.destroyed_event = new
	spawn(0)
		try
			bench_run()
		catch (var/exception/E)
			bench_runtime_error = TRUE
			world.log << "Benchmark aborted: [E] at [E.file]:[E.line]"
		text2file(json_encode(list("commit" = world.params["tested_commit"], "tick_lag" = world.tick_lag, "steps" = BENCH_STEPS, "runtime_error" = bench_runtime_error, "rows" = bench_rows)), "result.json")
		world.log << "COMPLETE train step benchmark"
		del(world)
