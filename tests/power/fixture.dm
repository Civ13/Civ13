world
	maxx = 8
	maxy = 8
	maxz = 1
	fps = 10
/obj
	var/powerneeded = 0
	var/powered = FALSE
	var/obj/structure/cable/powersource
/datum/proc/persistence_runtime_var(key)
	return FALSE
/obj/item/connector/proc/forget_cable(obj/structure/cable/C)
	return
/atom/proc/examine(mob/user)
	return
/proc/to_chat(mob/user, message)
	return
/obj/structure/engine
	var/list/connections = list()
	var/currentspeed = 0
	var/on = TRUE
	var/broken = FALSE
	var/maxpower = 10
	var/battery_charge_epoch = -1
	var/battery_charge_power = 0
/obj/structure/cable
	var/list/connections = list()
	var/list/power_consumers = list()
	var/lastupdate = 0
	var/lastupdate2 = 0
	var/powerflow = 0
	var/currentflow = 0
	var/d1 = 0
	var/cable_color = "red"
/proc/isemptylist(list/L)
	return !L.len
/proc/check(label, actual, expected)
	var/passed = actual == expected || (isnum(actual) && isnum(expected) && abs(actual - expected) < 0.0001)
	world.log << "CHECK [label]: actual=[actual] expected=[expected] [passed ? "PASS" : "FAIL"]"
	if (!passed)
		failures++
var/failures = 0
/world/OpenPort(port)
	return port == "none" ? ..() : FALSE
/world/New()
	world.OpenPort("none")
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
	check("component identity agrees", A.component_id, C.component_id)
	check("loop traversal visits each cable once", A.rebuild_visits, 3)
	check("component identity excluded from saves", A.persistence_runtime_var("component_id"), TRUE)
	var/obj/L = new(locate(1,1,1))
	var/obj/M = new(locate(2,1,1))
	L.powersource = A
	M.powersource = B
	L.powerneeded = 4
	M.powerneeded = 6
	A.connections += L
	B.connections += M
	A.update_power(4,1,L)
	B.update_power(6,1,M)
	check("same tick total demand", C.currentflow, 10)
	check("fully reserved consumer stays powered", M.draw_cable_power(), TRUE)
	check("repeated reservation not duplicated", C.currentflow, 10)
	var/obj/N = new(locate(3,1,1))
	N.powersource = C
	N.powerneeded = 1
	C.connections += N
	check("capacity exhausted", N.draw_cable_power(), FALSE)
	A.update_power(-4,1,L)
	check("release propagates immediately", C.currentflow, 6)
	B.update_power(-6,1,M)
	check("all demand released", C.currentflow, 0)
	A.update_power(-4,1,L)
	check("double release is not negative", C.currentflow, 0)
	check("new load admitted after release", N.draw_cable_power(), TRUE)
	check("normal load accounted", A.currentflow, 1)
	C.update_power(-1,1,N)
	var/obj/structure/radio/R = new(locate(1,1,1))
	var/obj/structure/lamp/P = new(locate(2,1,1))
	R.powersource = A
	P.powersource = B
	A.connections += R
	B.connections += P
	check("radio starts", R.check_power(), TRUE)
	check("lamp starts same tick", P.check_power(), TRUE)
	check("normal consumer demand", C.currentflow, 7)
	check("radio repeated poll", R.check_power(), TRUE)
	check("lamp repeated poll", P.check_power(), TRUE)
	check("normal demand stays constant", C.currentflow, 7)
	E.on = FALSE
	A.power_off(10)
	check("radio loses source", R.check_power(), FALSE)
	check("lamp loses source", P.check_power(), FALSE)
	check("stopped consumer demand released", C.currentflow, 0)
	E.on = TRUE
	R.Destroy()
	P.Destroy()
	A.power_on(10)
	for (var/i = 1, i <= 4, i++)
		sleep(30)
		A.power_on(10)
	check("repeated generation root", A.powerflow, 10)
	check("repeated generation remote", C.powerflow, 10)
	B.disconnect()
	check("split disconnected supply", C.powerflow, 0)
	check("split has distinct identities", A.component_id != C.component_id, TRUE)
	var/obj/structure/engine/F = new(locate(3,1,1))
	F.maxpower = 7
	F.connections = list(C)
	C.connections += F
	B.connections = list(A,C)
	A.connections |= B
	C.connections |= B
	A.connections |= C
	C.connections |= A
	A.power_on(10)
	check("loop two sources", C.powerflow, 17)
	check("merge shares identity", A.component_id, C.component_id)
	check("cycle visits each cable once", A.rebuild_visits, 3)
	M.powersource = B
	B.connections += M
	A.update_power(4,1,L)
	B.update_power(6,1,M)
	check("engine demand share", round(E.process_power_output(),0.01), 5.88)
	check("second engine demand share", round(F.process_power_output(),0.01), 4.12)
	check("engine accounting retains root power", A.powered, TRUE)
	A.update_power(-4,1,L)
	B.update_power(-6,1,M)
	A.power_on(10)
	check("same tick does not duplicate", A.powerflow, 17)
	E.broken = TRUE
	A.power_on(10)
	check("broken source excluded", A.powerflow, 7)
	E.broken = FALSE
	E.on = FALSE
	A.power_off(10)
	check("other engine survives shutdown", C.powerflow, 7)
	F.on = FALSE
	C.power_off(7)
	check("all sources stopped", A.powerflow, 0)
	E.on = TRUE
	A.power_on(10)
	C.forceMove(locate(8,8,1))
	C.rebuild_supply()
	check("moved cable has no remote supply", C.powerflow, 0)
	A.rebuild_supply()
	check("valid source retained after movement", A.powerflow, 10)
	E.on = FALSE
	A.power_off(10)
	check("source stopped", A.powerflow, 0)
	E.on = TRUE
	A.power_on(10)
	check("consumer reserves before deletion", L.draw_cable_power(), TRUE)
	L.Destroy()
	check("consumer deletion releases demand", A.currentflow, 0)
	E.Destroy()
	check("engine deletion removes supply", A.powerflow, 0)
	var/obj/structure/engine/G = new(locate(1,1,1))
	G.maxpower = 12
	G.connections = list(A)
	A.connections += G
	for (var/i = 1, i <= 6, i++)
		var/obj/structure/cable/branch = new(locate(2,1,1))
		branch.connections = list(A)
		A.connections += branch
	A.power_on(12)
	for (var/obj/structure/cable/branch in A.connections)
		check("branch supplied", branch.powerflow, 12)
	B.Destroy()
	check("cable deletion retains valid generation", A.powerflow, 12)
	for (var/i = 1, i <= 10, i++)
		A.disconnect()
		check("disconnect has no supply", A.powerflow, 0)
		G.connections = list(A)
		A.connections = list(G)
		A.power_on(12)
		check("reconnect counts engine once", A.powerflow, 12)
	G.forceMove(locate(8,8,1))
	check("moved engine removes supply", A.powerflow, 0)
	check("moved engine detaches cables", G.connections.len, 0)
	G.Destroy()
	world.log << "POWER_PROBE failures=[failures]"
	del(world)





/atom/proc/Destroy()
	return
var/list/processing_objects = list()

/atom/movable/proc/forceMove(atom/destination, var/special_event)
	if (loc == destination)
		return FALSE
	loc = destination
	return TRUE


/obj/structure/radio
	var/on = FALSE
	powerneeded = 5
/obj/structure/lamp
	var/on = FALSE
	powerneeded = 2

/obj/structure/battery/proc/available_output()
	return 0
