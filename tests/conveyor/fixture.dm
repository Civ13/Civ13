/atom/movable
	var/anchored = 0
/obj/proc/process()
	return
world
	maxx = 32
	maxy = 32
	fps = 10
/obj/machinery/conveyor
	var/operating = 1
	var/movedir = EAST
	var/list/affecting
var/failures = 0
/proc/check(condition, label)
	if (!condition)
		failures++
		world.log << "FAIL: [label]"
/proc/retained(list/belts)
	var/count = 0
	for (var/obj/machinery/conveyor/C in belts)
		count += length(C.affecting)
	return count
/world/New()
	..()
	spawn(0)
		run_tests()
/proc/run_tests()
	var/obj/machinery/conveyor/C = new(locate(2,2,1))
	var/obj/cargo = new(C.loc)
	var/obj/fixed = new(C.loc)
	fixed.anchored = 1
	C.process()
	check(cargo.x == 2, "one tick delay")
	sleep(2)
	check(cargo.x == 3, "east movement")
	check(fixed.x == 2, "anchored stays")
	C.operating = 0
	C.process()
	sleep(2)
	check(cargo.x == 3, "off stays idle")
	C.operating = 1
	C.movedir = WEST
	cargo.loc = C.loc
	C.process()
	cargo.loc = locate(10,10,1)
	sleep(2)
	check(cargo.x == 10 && cargo.y == 10, "departed cargo stays")
	var/list/capped = list()
	for (var/i in 1 to 12)
		capped += new /obj(C.loc)
	C.process()
	sleep(2)
	var/moved = 0
	for (var/obj/O in capped)
		if (O.x == 1)
			moved++
	check(moved == 10, "ten object cap and reverse")
	C.loc = null
	C.process()
	sleep(2)
	var/list/belts = list()
	for (var/y in 5 to 24)
		for (var/x in 2 to 21)
			var/obj/machinery/conveyor/B = new(locate(x,y,1))
			belts += B
			for (var/i in 1 to 40)
				var/obj/O = new(B.loc)
				O.anchored = 1
	world.log << "PHASE baseline"
	sleep(20)
	var/start = world.realtime
	for (var/obj/machinery/conveyor/B in belts)
		B.process()
	sleep(2)
	world.log << "RESULT occupied_elapsed_ds=[world.realtime-start] retained_entries=[retained(belts)] belts=[belts.len]"
	for (var/obj/machinery/conveyor/B in belts)
		B.operating = 0
	world.log << "PHASE settled"
	sleep(30)
	for (var/obj/machinery/conveyor/B in belts)
		for (var/obj/O in B.loc)
			if (!istype(O, /obj/machinery/conveyor))
				del(O)
		B.operating = 1
	start = world.realtime
	for (var/i in 1 to 250)
		for (var/obj/machinery/conveyor/B in belts)
			B.process()
		sleep(2)
	world.log << "RESULT empty_elapsed_ds=[world.realtime-start] calls=100000 failures=[failures]"
	world.log << "PHASE complete"
	sleep(10)
	del(world)
