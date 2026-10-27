// Production graph procedures, isolated source/consumer adapters.
world
	maxx = 32
	maxy = 16
	maxz = 1
/obj
	var/powerneeded = 0
	var/powered = FALSE
	var/obj/structure/cable/powersource
/datum/proc/persistence_runtime_var(key)
	return FALSE
/obj/item/connector/proc/forget_cable(obj/structure/cable/C)
	return
/atom/movable/proc/forceMove(atom/destination, special_event)
	loc = destination
	return TRUE
/obj/structure/cable
	var/list/connections = list()
	var/list/power_consumers = list()
	var/powerflow = 0
	var/currentflow = 0
	var/d1 = 0
	var/cable_color = "red"
/obj/structure/engine
	var/list/connections = list()
	var/on = TRUE
	var/broken = FALSE
	var/maxpower = 1000
	var/battery_charge_epoch = -1
	var/battery_charge_power = 0
/obj/structure/battery/proc/available_output()
	return 0
/obj/structure/civ_generator/proc/available_output()
	return 0
/obj/structure/civ_generator/proc/stop_generation()
	return
/proc/isemptylist(list/L)
	return !L.len
var/grid_probe_calls = 0
var/grid_probe_steps = 0
var/grid_probe_failures = 0
/proc/grid_check(condition, label)
	world.log << "[condition ? "PASS" : "FAIL"] [label]"
	if (!condition)
		grid_probe_failures++
/world/OpenPort(port)
	return port == "none" ? ..() : FALSE
/world/New()
	OpenPort("none")
	grid_check(!world.port, "offline fixture")
	var/list/graph = list()
	for (var/y = 1, y <= 16, y++)
		for (var/x = 1, x <= 32, x++)
			var/obj/structure/cable/C = new(locate(x,y,1))
			graph += C
			for (var/obj/structure/cable/N in range(1,C))
				if (N != C && get_dist(N,C) == 1)
					C.connections |= N
					N.connections |= C
	var/obj/structure/cable/root = graph[1]
	var/obj/structure/engine/E = new(root.loc)
	E.connections = list(root)
	root.connections |= E
	var/obj/consumer = new(root.loc)
	consumer.powerneeded = 4
	consumer.powersource = root
	root.connections |= consumer
	grid_probe_calls = 0
	grid_probe_steps = 0
	for (var/i = 1, i <= 20, i++)
		grid_check(consumer.draw_cable_power(), "load admitted")
	grid_check(root.currentflow == 4, "repeated reservation remains four units")
#ifdef GRID_CURRENT
	grid_check(grid_probe_calls == 20, "one traversal per draw")
	grid_check(grid_probe_steps == 20 * 512, "one discovery per cable per draw")
	grid_check(root.component_size == 512, "large component size")
	var/obj/structure/cable/last = graph[graph.len]
	grid_check(root.component_id == last.component_id, "large graph shares identity")
#else
	grid_check(grid_probe_calls == 40, "baseline two traversals per draw")
#endif
	var/before = 0
	for (var/obj/structure/cable/C in graph)
		before += C.connections.len + C.power_consumers.len
	for (var/i = 1, i <= 20, i++)
		consumer.draw_cable_power()
	var/after = 0
	for (var/obj/structure/cable/C in graph)
		after += C.connections.len + C.power_consumers.len
	grid_check(before == after, "repeated draws retain no graph entries")
	world.log << "GRID_METRICS nodes=512 draws=40 rebuilds=[grid_probe_calls] queue_steps=[grid_probe_steps] retained_before=[before] retained_after=[after] failures=[grid_probe_failures]"
	del(world)
