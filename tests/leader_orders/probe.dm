/world
	hub = ""
	hub_password = ""
	maxx = 30
	maxy = 30
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
var/probe_failures = 0
var/probe_checks = 0
var/probe_runtime_error = FALSE
/obj/map_metadata/leader_orders_probe/New()
	return
/proc/probe_check(condition, label)
	probe_checks++
	if (!condition)
		probe_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	probe_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.stat_set_event = new
		movementMachine = new
		map = new /obj/map_metadata/leader_orders_probe
		if (!all_species.len)
			makeDatumRefLists()
		for (var/turf/T in block(locate(1, 1, 1), locate(30, 30, 1)))
			T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
		leader_order_checks()
	catch(var/exception/e)
		probe_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("checks" = probe_checks, "failures" = probe_failures, "runtime_error" = probe_runtime_error)), "result.json")
	del(world)

/proc/probe_soldier(x, y, faction, name)
	var/mob/living/human/H = new(locate(x, y, 1))
	H.name = name
	H.real_name = name
	H.faction_text = faction
	return H

/proc/leader_order_checks()
	var/mob/living/human/leader = probe_soldier(10, 10, "Red", "Leader")
	var/datum/job/J = new
	J.is_squad_leader = TRUE
	leader.original_job = J
	var/mob/living/human/near = probe_soldier(12, 10, "Red", "Near ally")
	var/mob/living/human/far = probe_soldier(25, 25, "Red", "Far ally")
	var/mob/living/human/enemy = probe_soldier(11, 11, "Blue", "Enemy")

	probe_check(near.issue_leader_order("move") == 0, "a soldier without a leader job cannot give orders")
	probe_check(leader.issue_leader_order("bogus") == 0, "unknown orders are refused")
	probe_check(leader.issue_leader_order("move") == 2, "an order reaches the leader and the ally in range only")
	probe_check(near.leader_order_move_mult() == 0.96, "a squad leader's move order makes allies run 4% faster")
	probe_check(far.leader_order_move_mult() == 1, "allies out of range get nothing")
	probe_check(enemy.leader_order_move_mult() == 1, "enemies in range get nothing")
	probe_check(leader.issue_leader_order("hold") == 0, "the cooldown refuses a second order")

	leader.leader_order_ready_at = 0
	new /obj/item/weapon/whistle(leader)
	probe_check(leader.issue_leader_order("focus") == 2, "a whistle order reaches the ally")
	probe_check(near.leader_order_focus_mult() == 0.8, "a whistle adds one strength (20% tighter aim)")
	probe_check(leader.leader_order_ready_at - world.time == 900, "a whistle order has a 90 second cooldown")
	probe_check(near.order_focus_until - world.time == 300, "strength 2 lasts 30 seconds")

	leader.leader_order_ready_at = 0
	far.loc = locate(19, 10, 1)
	probe_check(leader.issue_leader_order("hold") == 3, "a whistle stretches the range to 10 tiles")
	probe_check(near.leader_order_hold_mult() == 0.8, "hold reduces pain by 10% per strength")
	near.order_hold_until = world.time - 1
	probe_check(near.leader_order_hold_mult() == 1, "an expired order has no effect")

	J.is_squad_leader = FALSE
	J.is_commander = TRUE
	leader.leader_order_ready_at = 0
	probe_check(leader.issue_leader_order("move") == 3 && near.order_move_strength == 3, "a commander with a whistle reaches the strength cap of 3")

	probe_check(near.persistence_runtime_var("order_move_until") && near.persistence_runtime_var("leader_order_ready_at"), "order state is never saved")
