world
	maxx = 8
	maxy = 8
	maxz = 1
	fps = 10
/obj
	var/anchored = FALSE
	var/powered = FALSE
	var/powerneeded = 0
	var/obj/structure/cable/powersource
/datum/proc/persistence_runtime_var(key)
	return FALSE
/obj/item/connector/proc/forget_cable(obj/structure/cable/C)
	return
/world/OpenPort(port)
	return port == "none" ? ..() : FALSE
/obj/structure/engine
	var/list/connections = list()
	var/on = TRUE
	var/broken = FALSE
	var/maxpower = 10
	var/battery_charge_epoch = -1
	var/battery_charge_power = 0
/obj/structure/cable
	var/list/connections = list()
	var/list/power_consumers = list()
	var/powerflow = 0
	var/currentflow = 0
	var/d1 = 0
	var/cable_color = "red"
/obj/structure/battery
	anchored = TRUE
	var/stored_energy = 0
	var/energy_capacity = 600
	var/discharge_rate = 1
	var/charge_rate = 10
	var/rechargeable = FALSE
	var/commissioned = TRUE
	var/mode = "off"
	var/output_power = 0
	var/output_until = 0
	var/last_tick = -1
	var/retired = FALSE
/proc/check(label, actual, expected)
	world.log << "CHECK [label]: [actual] expected [expected] [actual == expected ? "PASS" : "FAIL"]"
	if (actual != expected) failures++
var/failures = 0
/obj/structure/civ_generator/proc/available_output()
	return 0
/obj/structure/civ_generator/proc/reserve_charge(requested)
	return 0
/obj/structure/civ_generator/proc/stop_generation()
	return
/proc/connect(obj/structure/battery/B, obj/structure/cable/C)
	B.loc = C.loc
	B.powersource = C
	C.connections |= B
/world/New()
	OpenPort("none")
	var/obj/structure/cable/A = new(locate(1,1,1))
	var/obj/structure/cable/C = new(locate(2,1,1))
	A.connections |= C
	C.connections |= A
	var/obj/structure/engine/E = new(A.loc)
	E.connections = list(A)
	A.connections |= E
	var/obj/structure/battery/B = new(A.loc)
	connect(B,A)
	B.stored_energy = 3
	B.mode = "discharge"
	B.settle_tick()
	check("discharge rate", B.available_output(), 1)
	check("prepaid energy", B.stored_energy, 2)
	B.settle_tick()
	check("idempotent tick", B.stored_energy, 2)
	B.mode = "off"
	check("off removes output", B.available_output(), 0)
	sleep(10)
	B.stored_energy = 0.5
	B.mode = "discharge"
	B.settle_tick()
	check("partial final output", B.available_output(), 0.5)
	check("empty bound", B.stored_energy, 0)
	sleep(10)
	B.settle_tick()
	check("empty output", B.available_output(), 0)
	B.rechargeable = TRUE
	B.mode = "charge"
	var/obj/load = new(C.loc)
	load.powerneeded = 6
	load.powersource = C
	C.connections |= load
	sleep(10)
	B.settle_tick()
	check("consumer capacity first", B.stored_energy, 4)
	check("engine charge ledger", E.battery_charge_power, 4)
	check("reserved charging reduces cable supply", C.powerflow, 6)
	var/obj/structure/battery/B2 = new(C.loc)
	connect(B2,C)
	B2.rechargeable = TRUE
	B2.mode = "charge"
	B2.settle_tick()
	check("multiple devices same budget", B2.stored_energy, 0)
	A.connections -= B
	B.powersource = null
	del(B)
	check("deletion cannot reclaim generation", A.reserve_battery_charge(10), 0)
	sleep(10)
	var/before_stop = B2.stored_energy
	E.on = FALSE
	B2.settle_tick()
	check("no engine preserves prior storage", B2.stored_energy, before_stop)
	var/obj/structure/battery/P = new(C.loc)
	connect(P,C)
	P.stored_energy = 100
	P.discharge_rate = 20
	P.mode = "discharge"
	P.settle_tick()
	check("battery cannot charge battery", C.reserve_battery_charge(10), 0)
	check("battery alone powers cable", C.powerflow, 20)
	check("consumer draws stored power", load.draw_cable_power(), TRUE)
	E.on = TRUE
	load.powerneeded = 0
	sleep(10)
	B2.stored_energy = 599
	B2.settle_tick()
	check("full clamp", B2.stored_energy, 600)
	check("charge actual deficit", E.battery_charge_power, 1)
	C.connections -= A
	A.connections -= C
	sleep(10)
	B2.stored_energy = 100
	B2.settle_tick()
	check("split no charge", B2.stored_energy, 100)
	A.connections |= C
	C.connections |= A
	sleep(10)
	B2.settle_tick()
	check("reconnect resumes charge", B2.stored_energy, 110)
	B2.powersource = null
	sleep(10)
	B2.mode = "discharge"
	B2.settle_tick()
	check("disconnected discharge preserves storage", B2.stored_energy, 110)
	check("disconnected output", B2.available_output(), 0)
	connect(B2,C)
	B2.stored_energy = -5
	sleep(10)
	B2.settle_tick()
	check("negative energy bound", B2.stored_energy, 0)
	B2.stored_energy = 900
	B2.mode = "off"
	sleep(10)
	B2.settle_tick()
	check("maximum energy bound", B2.stored_energy, 600)
	B2.rechargeable = FALSE
	B2.stored_energy = 0
	B2.mode = "charge"
	sleep(10)
	B2.settle_tick()
	check("primary cannot recharge", B2.stored_energy, 0)
	var/savefile/S = new("battery.sav")
	S["energy"] << 137.5
	S["energy"] >> B2.stored_energy
	check("energy scalar save/load", B2.stored_energy, 137.5)
	world.log << "BATTERY_PROBE failures=[failures]"
	del(world)

/atom/movable/proc/forceMove(atom/destination, var/special_event)
	loc = destination
	return TRUE
