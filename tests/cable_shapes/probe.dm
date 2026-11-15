// Smart cable shapes and map wiring fixture (tests/cable_shapes/run.py).
// The fixture replaces world/New, so map autolink is still held at start, as
// it is while a compiled map is being placed.
/world
	maxx = 8
	maxy = 8
	maxz = 1
	turf = /turf/floor/plating
	area = /area/caribbean
	hub = ""
	hub_password = ""

/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

/obj/structure/engine/shape_tester
	maxpower = 100
	on = TRUE
	anchored = TRUE

/obj/structure/engine/shape_tester/New()
	return

/obj/shape_lamp
	powerneeded = 10
	anchored = TRUE

/obj/structure/cable/shape_vertical
	icon_state = "vertical"

/obj/structure/cable/shape_corner_north_west
	icon_state = "1-8"

var/global/shape_failures = 0
/proc/shape_check(label, actual, expected)
	world.log << "SHAPE CHECK [label]: [actual] expected [expected] [actual == expected ? "PASS" : "FAIL"]"
	if (actual != expected)
		shape_failures++

/proc/shape_ends(obj/structure/cable/C)
	var/list/ends = C.cable_ends()
	return ends.len == 2 ? "[min(ends[1], ends[2])],[max(ends[1], ends[2])]" : ""

// The fixture skips global controllers, so dir events have no hub here.
/obj/structure/cable/set_dir(new_dir)
	dir = new_dir
	return TRUE

// What place_turf does after paying for the piece.
/proc/shape_lay(x, y, dirn)
	var/turf/T = locate(x, y, 1)
	var/list/corner = cable_corner_for(T, dirn)
	var/obj/structure/cable/C = new(T)
	C.tiledir = (dirn == NORTH || dirn == SOUTH) ? "vertical" : "horizontal"
	if (corner)
		C.set_cable_shape(corner[1], corner[2])
	C.update_icon()
	C.link_end_neighbors()
	return C

/world/New()
	OpenPort("none")
	sleep(1)
	try
		// Map wiring: placed while held, joined once on release.
		// Engine on a straight run at 2,2 and 3,2; corner at 4,2 turning
		// north; vertical at 4,3; a crossing at 4,4 with a secured connector;
		// a horizontal at 5,4 under a lamp.
		shape_check("held at start", cable_autolink_holds, 1)
		var/obj/structure/cable/m1 = new(locate(2, 2, 1))
		new /obj/structure/cable(locate(3, 2, 1))
		var/obj/structure/cable/corner = new /obj/structure/cable/shape_corner_north_west(locate(4, 2, 1))
		new /obj/structure/cable/shape_vertical(locate(4, 3, 1))
		var/obj/structure/cable/cross_v = new /obj/structure/cable/shape_vertical(locate(4, 4, 1))
		var/obj/structure/cable/cross_h = new(locate(4, 4, 1))
		var/obj/structure/cable/m_end = new(locate(5, 4, 1))
		var/obj/structure/engine/shape_tester/E = new(locate(2, 2, 1))
		var/obj/shape_lamp/L = new(locate(5, 4, 1))
		shape_check("map corner reads its icon_state", corner.tiledir, "corner")
		shape_check("map corner ends", shape_ends(corner), "1,8")
		shape_check("map vertical reads its icon_state", cross_v.tiledir, "vertical")
		shape_check("nothing joined while held", m1.connections.len, 0)
		shape_check("queue holds the map cables", cable_autolink_queue.len, 7)
		// The corner's north end is turned west: 1-8 joins 3,2 and 4,3.
		release_cable_autolink()
		shape_check("released", cable_autolink_holds, 0)
		shape_check("engine attached", (m1 in E.connections) && (E in m1.connections) ? 1 : 0, 1)
		shape_check("lamp attached", L.powersource == m_end ? 1 : 0, 1)
		shape_check("crossing stays insulated without a connector", L.draw_cable_power() ? 1 : 0, 0)
		shape_check("vertical crossing piece is on the engine grid", cross_v.rebuild_supply(), 100)
		shape_check("horizontal crossing piece is apart", cross_h.rebuild_supply(), 0)

		var/obj/item/connector/secured/J = new(locate(4, 4, 1))
		shape_check("secured connector joins at once after release", (cross_h in cross_v.connections) ? 1 : 0, 1)
		shape_check("lamp powered through corner and junction", L.draw_cable_power() ? 1 : 0, 1)
		shape_check("one grid of seven cables", m_end.component_size, 7)
		qdel(J)

		// A second held read: a mapped connector joins on release.
		hold_cable_autolink()
		var/obj/item/connector/secured/J2 = new(locate(4, 4, 1))
		shape_check("held connector waits", (cross_h in cross_v.connections) ? 1 : 0, 0)
		shape_check("nested release reports nothing new", release_cable_autolink(), 0)
		shape_check("held connector joined on release", (cross_h in cross_v.connections) ? 1 : 0, 1)
		qdel(J2)

		// Laying by hand. A straight run west to east ending at 2,6.
		var/obj/structure/cable/h1 = shape_lay(1, 6, EAST)
		var/obj/structure/cable/h2 = shape_lay(2, 6, EAST)
		shape_check("straight run joins", (h1 in h2.connections) ? 1 : 0, 1)
		shape_check("continuing a run stays straight", cable_corner_for(locate(3, 6, 1), EAST) ? 1 : 0, 0)
		// Turning north at 3,6: loose end to the west, nothing behind (south).
		var/obj/structure/cable/turn1 = shape_lay(3, 6, NORTH)
		shape_check("turn becomes a corner", turn1.tiledir, "corner")
		shape_check("corner draws its d1-d2 state", turn1.icon_state, "1-8")
		shape_check("corner joins the run", (h2 in turn1.connections) && (turn1 in h2.connections) ? 1 : 0, 1)
		var/obj/structure/cable/up = shape_lay(3, 7, NORTH)
		shape_check("vertical after the corner stays straight", up.tiledir, "vertical")
		shape_check("vertical joins the corner's north end", (turn1 in up.connections) ? 1 : 0, 1)
		shape_check("whole run is one grid", h1.battery_network().len, 4)

		// Loose ends on both sides stay straight; so does a corner that
		// would overlap a cable already there.
		new /obj/structure/cable(locate(5, 7, 1))
		new /obj/structure/cable(locate(7, 7, 1))
		shape_check("two loose sides stay straight", cable_corner_for(locate(6, 7, 1), NORTH) ? 1 : 0, 0)
		new /obj/structure/cable(locate(7, 6, 1))
		shape_check("one loose side turns", jointext(cable_corner_for(locate(6, 6, 1), NORTH), ","), "4,1")
		var/obj/structure/cable/blocker = new /obj/structure/cable/shape_vertical(locate(6, 6, 1))
		shape_check("corner over a crossing piece stays straight", cable_corner_for(locate(6, 6, 1), NORTH) ? 1 : 0, 0)
		qdel(blocker)
		shape_check("diagonal facing stays straight", cable_corner_for(locate(6, 6, 1), NORTHEAST) ? 1 : 0, 0)

		// A craft turning a quarter turn turns the corner's ends with it.
		turn1.craft_turned(null, 90)
		shape_check("quarter turn of 1-8", turn1.icon_state, "2-8")
		turn1.craft_turned(null, 180)
		shape_check("half turn of 2-8", turn1.icon_state, "1-4")
		h1.craft_turned(null, 90)
		shape_check("straight piece still swaps on a quarter turn", h1.tiledir, "vertical")
	catch (var/exception/ex)
		world.log << "SHAPE EXCEPTION: [ex.name] [ex.file]:[ex.line]"
		shape_failures++
	text2file("[shape_failures ? "FAIL" : "PASS"]: cable shapes failures=[shape_failures]", "result.txt")
	shutdown()
