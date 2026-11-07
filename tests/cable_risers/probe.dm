// Cable riser and bus tie fixture (tests/cable_risers/run.py). Three levels,
// no map metadata, so multiz_level_above/below are plain z + 1 and z - 1.
/world
	maxx = 6
	maxy = 6
	maxz = 3
	turf = /turf/floor/plating
	area = /area/caribbean
	hub = ""
	hub_password = ""

/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

/obj/structure/engine/riser_tester
	maxpower = 100
	on = TRUE

/obj/structure/engine/riser_tester/New()
	return

/obj/riser_lamp
	powerneeded = 10

var/global/riser_failures = 0
/proc/riser_check(label, actual, expected)
	world.log << "RISER CHECK [label]: [actual] expected [expected] [actual == expected ? "PASS" : "FAIL"]"
	if (actual != expected)
		riser_failures++

/proc/riser_cable(x, y, z)
	var/obj/structure/cable/C = new(locate(x, y, z))
	C.d1 = 0
	C.d2 = EAST
	return C

/proc/riser_secure(type, x, y, z)
	var/obj/item/connector/R = new type(locate(x, y, z))
	R.anchored = TRUE
	R.connect_cables()
	return R

/world/New()
	OpenPort("none")
	sleep(1)
	try
		// Engine on level 1, lamp on level 3, one cable on each level at 3,3.
		var/obj/structure/cable/bottom = riser_cable(3, 3, 1)
		var/obj/structure/cable/middle = riser_cable(3, 3, 2)
		var/obj/structure/cable/top = riser_cable(3, 3, 3)
		var/obj/structure/engine/riser_tester/E = new(locate(3, 3, 1))
		bottom.connections |= E
		E.connections |= bottom
		var/obj/riser_lamp/L = new(locate(3, 3, 3))
		L.powersource = top
		top.connections |= L
		riser_check("no risers: lamp unpowered", L.draw_cable_power() ? 1 : 0, 0)

		var/obj/item/connector/riser/R1 = riser_secure(/obj/item/connector/riser, 3, 3, 1)
		var/obj/item/connector/riser/R2 = riser_secure(/obj/item/connector/riser, 3, 3, 2)
		riser_check("two risers: level 2 joined", middle.rebuild_supply(), 100)
		riser_check("two risers: level 3 still apart", top.rebuild_supply(), 0)
		var/obj/item/connector/riser/R3 = riser_secure(/obj/item/connector/riser, 3, 3, 3)
		riser_check("three risers: lamp powered across levels", L.draw_cable_power() ? 1 : 0, 1)
		riser_check("three risers: one component", top.component_size, 3)
		riser_check("riser partners in the middle", R2.riser_partners().len, 2)
		riser_check("nothing saved across levels", bottom.persistence_runtime_var("riser_links") ? 1 : 0, 1)

		// Unfastening the middle riser splits the grid; securing it rejoins.
		R2.anchored = FALSE
		R2.disconnect_cables()
		riser_check("middle riser off: lamp unpowered", L.draw_cable_power() ? 1 : 0, 0)
		riser_check("middle riser off: no stale links", bottom.riser_links ? bottom.riser_links.len : 0, 0)
		R2.anchored = TRUE
		R2.connect_cables()
		riser_check("middle riser back: lamp powered", L.draw_cable_power() ? 1 : 0, 1)

		// Cutting the middle cable splits the grid and leaves no reference.
		qdel(middle)
		riser_check("middle cable cut: lamp unpowered", L.draw_cable_power() ? 1 : 0, 0)
		riser_check("middle cable cut: bottom forgets it", (bottom.riser_links && (middle in bottom.riser_links)) ? 1 : 0, 0)
		middle = riser_cable(3, 3, 2)
		R2.connect_cables()
		riser_check("new middle cable: lamp powered", L.draw_cable_power() ? 1 : 0, 1)

		// A riser off the same x and y joins nothing on the next level.
		var/obj/structure/cable/side = riser_cable(5, 5, 2)
		riser_secure(/obj/item/connector/riser, 5, 5, 2)
		riser_check("unpaired riser: no supply", side.rebuild_supply(), 0)

		// Destroying the top riser cuts level 3.
		qdel(R3)
		riser_check("top riser destroyed: lamp unpowered", L.draw_cable_power() ? 1 : 0, 0)
		R3 = riser_secure(/obj/item/connector/riser, 3, 3, 3)
		riser_check("top riser replaced: lamp powered", L.draw_cable_power() ? 1 : 0, 1)

		// Bus tie: two cables on one tile, only the switch joins them.
		var/obj/structure/cable/run_a = riser_cable(1, 1, 1)
		var/obj/structure/cable/run_b = riser_cable(1, 1, 1)
		run_b.cable_color = "blue"
		var/obj/structure/engine/riser_tester/E2 = new(locate(1, 1, 1))
		run_a.connections |= E2
		E2.connections |= run_a
		riser_check("bus tie absent: run b unpowered", run_b.rebuild_supply(), 0)
		var/obj/item/connector/bus_tie/S = riser_secure(/obj/item/connector/bus_tie, 1, 1, 1)
		riser_check("bus tie closed: run b powered", run_b.rebuild_supply(), 100)
		S.closed = FALSE
		S.connect_cables()
		riser_check("bus tie open: run b unpowered", run_b.rebuild_supply(), 0)
		S.closed = TRUE
		S.connect_cables()
		riser_check("bus tie closed again: run b powered", run_b.rebuild_supply(), 100)
		riser_check("bottom riser kept", R1.anchored ? 1 : 0, 1)

		// Ladders pair through multiz_level_above/below.
		var/obj/structure/multiz/ladder/up/LU = new(locate(2, 2, 1))
		var/obj/structure/multiz/ladder/LT = new(locate(2, 2, 2))
		LU.find_target()
		LT.find_target()
		riser_check("ladder up finds the top", LU.target == LT ? 1 : 0, 1)
		riser_check("ladder top finds the bottom", LT.target == LU ? 1 : 0, 1)
		var/obj/structure/multiz/ladder/up/lonely = new(locate(4, 4, 3))
		lonely.find_target()
		riser_check("ladder on the top level has no target", lonely.target ? 1 : 0, 0)
	catch (var/exception/E)
		world.log << "RISER EXCEPTION: [E.name] [E.file]:[E.line]"
		riser_failures++
	text2file("[riser_failures ? "FAIL" : "PASS"]: cable risers failures=[riser_failures]", "result.txt")
	shutdown()
