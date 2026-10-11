// Loaded only by run-game.ps1, never by the production dme.
var/global/datum/train_game_probe/train_game_probe = new
/datum/train_game_probe
	var/failures = 0
	var/list/cars = list()
/datum/train_game_probe/New()
	if(config)
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
	spawn(200)
		run_probe()
/datum/train_game_probe/proc/check(condition, label)
	if(!condition)
		failures++
		world.log << "TRAIN FAIL: [label]"
	else
		world.log << "TRAIN PASS: [label]"
/datum/train_game_probe/proc/car(x,y,d = EAST)
	var/obj/structure/trains/T = new /obj/structure/trains/transport/flatbed(locate(x,y,1))
	T.dir = d
	cars += T
	return T
/datum/train_game_probe/proc/clear()
	for(var/obj/structure/trains/T in cars)
		qdel(T)
	cars.Cut()
/datum/train_game_probe/proc/run_probe()
	try
		if(!map || !ticker)
			throw EXCEPTION("Startup did not create map/ticker")
		world.name = "Civ13 LOCAL train collision probe"
		// Only this isolated world is changed. Prepare an open test track.
		for(var/x in 20 to 35)
			for(var/y in 20 to 25)
				var/turf/T = locate(x,y,1)
				for(var/atom/movable/A in T)
					qdel(A)
				T = T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
				var/obj/structure/rails/R = new(T)
				R.dir = EAST
		var/obj/structure/trains/A = car(25,22)
		var/obj/structure/trains/B = car(24,22)
		var/obj/structure/trains/C = car(23,22)
		A.connected = B
		B.connected = C
		check(!A.can_connect_to(C), "reject coupling cycle")
		check(A.Move(locate(26,22,1),EAST), "three-car movement")
		check(A.x == 26 && B.x == 25 && C.x == 24, "followers occupy vacated turfs")
		B.connected = A
		check(A.Move(locate(27,22,1),EAST), "malformed cycle terminates")
		check(!A.moving_train && !B.moving_train, "guards released")
		clear()
		A = car(25,22)
		B = car(24,22)
		A.connected = B
		var/turf/blocked = locate(26,22,1)
		blocked.density = TRUE
		check(!A.Move(blocked,EAST), "blocked move reports failure")
		check(A.x == 25 && B.x == 24, "blocked move preserves follower")
		blocked.density = FALSE
		clear()
		for(var/direction in list(WEST,EAST,NORTH))
			A = car(25,22,EAST)
			B = car(26,22,direction)
			A.automovement = TRUE
			check(!A.process_rail_movement() && A.health == 995 && !A.automovement, "stop and damage at contact [direction]")
			check(!A.Move(B.loc,EAST), "direct collision reports failure [direction]")
			sleep(3)
			check(A.x == 25 && B.x == 26, "no deferred push cascade [direction]")
			clear()
		A = car(25,22)
		B = car(24,22)
		A.connected = B
		A.automovement = TRUE
		check(A.process_rail_movement() && A.x == 26 && B.x == 25, "normal automatic movement")
		text2file(json_encode(list("commit" = world.params["tested_commit"], "map_id" = map.ID, "maxx" = world.maxx, "maxy" = world.maxy, "maxz" = world.maxz, "version" = world.byond_version, "build" = world.byond_build, "failures" = failures)), "train-result.json")
		text2file("RESULT failures=[failures]", "train-result.txt")
	catch(var/exception/e)
		text2file("FAIL: [e]", "train-result.txt")
	if(!world.params["visual"])
		del(world)
	else
		prepare_visual()
/datum/train_game_probe/proc/prepare_visual()
	clear()
	var/obj/structure/trains/locomotive/coal/left = new(locate(24,22,1))
	left.dir = EAST
	left.fuel = left.max_fuel
	var/obj/structure/trains/locomotive/coal/right = new(locate(30,22,1))
	right.dir = WEST
	right.fuel = right.max_fuel
	cars += left
	cars += right
	var/obj/structure/trains/B = car(23,22)
	var/obj/structure/trains/C = car(22,22)
	left.connected = B
	B.connected = C
/client/verb/inspect_train_probe()
	set name = "Inspect local train probe"
	set category = "Local Verification"
	if(!world.params["visual"])
		return
	screen.Cut()
	eye = locate(27,22,1)
	perspective = EYE_PERSPECTIVE
	view = 7
	to_chat(src, "<b>Isolated train collision probe</b><br>Commit: [world.params["tested_commit"]]<br>Map: [map.ID] [world.maxx]x[world.maxy]x[world.maxz]<br>[file2text("train-result.txt")]<br>Two real steam locomotives, one with two flatbed followers. Use Run local train collision to exercise normal rail movement.")
/client/verb/run_train_probe()
	set name = "Run local train collision"
	set category = "Local Verification"
	if(!world.params["visual"])
		return
	train_game_probe.prepare_visual()
	for(var/obj/structure/trains/locomotive/L in train_game_probe.cars)
		L.on = TRUE
		L.locomotive()
	sleep(60)
	for(var/obj/structure/trains/locomotive/L in train_game_probe.cars)
		to_chat(src, "[L.name] at ([L.x],[L.y],[L.z]): health=[L.health], automovement=[L.automovement].")
