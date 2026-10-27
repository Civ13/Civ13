world
	maxx = 8
	maxy = 8
	maxz = 1
	fps = 10
/obj
	var/powered = FALSE
	var/obj/structure/cable/powersource
/obj/structure/engine
	var/list/connections = list()
	var/on = TRUE
	var/broken = FALSE
	var/maxpower = 10
/obj/structure/cable
	var/list/connections = list()
	var/lastupdate = 0
	var/lastupdate2 = 0
	var/powerflow = 0
	var/currentflow = 0
	var/d1 = 0
	var/cable_color = "red"
/proc/isemptylist(list/L)
	return !L.len
/proc/check(label, actual, expected)
	world.log << "CHECK [label]: actual=[actual] expected=[expected] [actual == expected ? "PASS" : "FAIL"]"
	if (actual != expected)
		failures++
var/failures = 0
/world/OpenPort(port)
	return port == "none" ? ..() : FALSE
/world/New()
	OpenPort("none")
	var/obj/structure/cable/A = new(locate(1,1,1))
	var/obj/structure/cable/B = new(locate(2,1,1))
	var/obj/structure/cable/C = new(locate(3,1,1))
	var/obj/structure/engine/E = new(locate(1,1,1))
	A.connections = list(B,E)
	B.connections = list(A,C)
	C.connections = list(B)
	E.connections = list(A)
	sleep(30)
	A.power_on(10)
	check("single source", C.powerflow, 10)
	A.update_power(4,1)
	B.update_power(6,1)
	check("same tick total demand", C.currentflow, 10)
	A.update_power(-4,1)
	check("release propagates immediately", C.currentflow, 6)
	B.update_power(-6,1)
	check("all demand released", C.currentflow, 0)
	for (var/i = 1, i <= 4, i++)
		sleep(30)
		A.power_on(10)
	check("repeated generation root", A.powerflow, 10)
	check("repeated generation remote", C.powerflow, 10)
	B.disconnect()
	check("split disconnected supply", C.powerflow, 0)
	E.on = FALSE
	A.power_off(10)
	check("source stopped", A.powerflow, 0)
	world.log << "POWER_PROBE failures=[failures]"
	del(world)
