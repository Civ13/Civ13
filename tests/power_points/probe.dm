// Power point fixture (tests/power_points/run.py). The fixture replaces
// world/New, so map autolink is still held at start.
/world
	maxx = 12
	maxy = 12
	maxz = 1
	turf = /turf/floor/plating
	area = /area/caribbean
	hub = ""
	hub_password = ""

/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

/turf/pp_wall
	density = TRUE
	opacity = TRUE

/obj/structure/engine/pp_tester
	maxpower = 100
	on = TRUE
	anchored = TRUE

/obj/structure/engine/pp_tester/New()
	return

/obj/structure/pp_lamp
	powerneeded = 10
	anchored = TRUE
	density = FALSE

var/global/pp_failures = 0
/proc/pp_check(label, actual, expected)
	world.log << "POWER POINT CHECK [label]: [actual] expected [expected] [actual == expected ? "PASS" : "FAIL"]"
	if (actual != expected)
		pp_failures++

/proc/pp_lamp_at(x, y)
	return new /obj/structure/pp_lamp(locate(x, y, 1))

// Moves without movement events, which the fixture has no hub for.
/proc/pp_place(obj/O, x, y)
	O.loc = locate(x, y, 1)
	O.power_point_moved()

/world/New()
	OpenPort("none")
	sleep(1)
	try
		// Map placement: a secured transformer on a cable feeds a lamp once released.
		var/obj/structure/cable/mc = new(locate(10, 10, 1))
		var/obj/structure/engine/pp_tester/ME = new(locate(10, 10, 1))
		var/obj/structure/power_point/transformer/secured/MT = new(locate(10, 10, 1))
		var/obj/structure/pp_lamp/ML = pp_lamp_at(8, 9)
		pp_check("held: mapped lamp waits", ML.powersource ? 1 : 0, 0)
		release_cable_autolink()
		pp_check("mapped engine joined", (ME in mc.connections) ? 1 : 0, 1)
		pp_check("mapped transformer on its cable", MT.in_service() ? 1 : 0, 1)
		pp_check("mapped lamp fed", ML.draw_cable_power() ? 1 : 0, 1)

		// Engine and transformer on a two-cable run at 2,2 and 3,2.
		var/obj/structure/cable/c1 = new(locate(2, 2, 1))
		var/obj/structure/cable/c2 = new(locate(3, 2, 1))
		c2.link_end_neighbors()
		var/obj/structure/engine/pp_tester/E = new(locate(2, 2, 1))
		c1.connections |= E
		E.connections |= c1
		var/obj/structure/power_point/transformer/T = new(locate(3, 2, 1))
		var/obj/structure/pp_lamp/near = pp_lamp_at(6, 4)
		var/obj/structure/pp_lamp/behind_wall = pp_lamp_at(8, 2)
		var/obj/structure/pp_lamp/too_far = pp_lamp_at(3, 8)
		new /turf/pp_wall(locate(6, 2, 1))
		var/obj/structure/cable/own = new(locate(4, 7, 1))
		var/obj/structure/pp_lamp/cabled = pp_lamp_at(4, 7)
		cabled.powersource = own
		own.connections |= cabled
		pp_check("unsecured transformer serves nothing", T.serve_nearby(), 0)
		T.anchored = TRUE
		pp_check("secured transformer finds its cable", T.attach_cable() ? 1 : 0, 1)
		pp_check("serves the one clear lamp in reach", T.serve_nearby(), 1)
		pp_check("near lamp draws through the transformer", near.draw_cable_power() ? 1 : 0, 1)
		pp_check("lamp behind a wall is not fed", behind_wall.powersource ? 1 : 0, 0)
		pp_check("lamp six tiles away is not fed", too_far.powersource ? 1 : 0, 0)
		pp_check("cabled lamp keeps its own cable", cabled.powersource == own ? 1 : 0, 1)
		pp_check("grid demand counts the fed lamp", c1.currentflow, 10)

		// Built in reach after the transformer: joins by itself.
		var/obj/structure/pp_lamp/built = pp_lamp_at(4, 5)
		pp_check("lamp built in reach joins", built.power_point == T ? 1 : 0, 1)
		pp_check("built lamp draws", built.draw_cable_power() ? 1 : 0, 1)
		pp_check("grid demand counts both", c1.currentflow, 20)

		// Moving out of reach releases the reservation; back in rejoins.
		pp_place(built, 11, 4)
		pp_check("moved away: released", built.powersource ? 1 : 0, 0)
		pp_check("moved away: demand released", c1.rebuild_supply() ? c1.currentflow : -1, 10)
		pp_place(built, 4, 4)
		pp_check("moved back: rejoins", built.power_point == T ? 1 : 0, 1)
		pp_check("moved back: draws", built.draw_cable_power() ? 1 : 0, 1)

		// A draw past reach is refused even if the lamp still lists the cable.
		built.loc = locate(10, 2, 1)
		pp_check("stale lamp out of reach refused", built.draw_cable_power() ? 1 : 0, 0)
		pp_place(built, 4, 4)

		// Simulated reload: links on the machines survive, the transformer's are runtime.
		near.power_point = null
		built.power_point = null
		T.served = list()
		pp_check("before reload: near refused", near.draw_cable_power() ? 1 : 0, 0)
		T.after_load()
		pp_check("after reload: near adopted", near.power_point == T ? 1 : 0, 1)
		pp_check("after reload: near draws", near.draw_cable_power() ? 1 : 0, 1)

		// Unfastening drops every fed machine.
		T.detach_cable()
		T.anchored = FALSE
		pp_check("unfastened: near released", near.powersource ? 1 : 0, 0)
		pp_check("unfastened: built released", built.powersource ? 1 : 0, 0)
		pp_check("unfastened: no demand left", c1.rebuild_supply() ? c1.currentflow : -1, 0)

		// Secured again, then the cable under it is cut.
		T.anchored = TRUE
		T.attach_cable()
		pp_check("resecured serves both", T.serve_nearby(), 2)
		qdel(c2)
		pp_check("cut cable: near loses power", near.powersource ? 1 : 0, 0)
		pp_check("cut cable: transformer out of service", T.in_service() ? 1 : 0, 0)
		qdel(T)
		pp_check("destroyed transformer leaves the registry", (T in power_points) ? 1 : 0, 0)
	catch (var/exception/ex)
		world.log << "POWER POINT EXCEPTION: [ex.name] [ex.file]:[ex.line]"
		pp_failures++
	text2file("[pp_failures ? "FAIL" : "PASS"]: power points failures=[pp_failures]", "result.txt")
	shutdown()
