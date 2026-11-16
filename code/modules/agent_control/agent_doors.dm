// What an agent character sees about a door, window or trapdoor in view
// (docs/agent-control.md#doors), so it can tell a door it can walk through
// from one that is locked, barred or braced, and which side it is on.

/proc/agent_door_row(obj/structure/simple_door/D, mob/M)
	. = list()
	.["kind"] = D.is_trapdoor() ? "trapdoor" : (D.is_window_door() ? "window" : "door")
	.["open"] = D.state ? TRUE : FALSE
	if (!D.state)
		// Walking into it (or clicking it, for a trapdoor) opens it for this character now.
		.["passable"] = D.door_route_passable(M) ? TRUE : FALSE
	var/mine = D.door_side_of(M)
	var/inner = D.door_inner_side()
	if (inner && mine)
		.["inside"] = (inner == mine) ? "your side" : "far side"
	if (D.door_lock)
		var/list/lock = list("kind" = D.door_lock.name(), "locked" = D.door_lock.blocks() ? TRUE : FALSE)
		if (D.door_lock.side && mine)
			lock["keyhole"] = (D.door_lock.side == mine) ? "your side" : "far side"
		.["lock"] = lock
	if (D.door_brackets)
		var/list/bars = list()
		for (var/side in D.door_brackets)
			var/where = (mine && side == mine) ? "your side" : "far side"
			bars[where] = D.door_bar_on(side) ? "barred" : "brackets"
		.["bars"] = bars
	if (D.door_bolt_side)
		.["bolt"] = list("side" = (mine && D.door_bolt_side == mine) ? "your side" : "far side", "shot" = D.door_bolt_shot ? TRUE : FALSE)
	var/obj/item/door_hold/hold = D.door_held()
	if (hold && hold.holder)
		.[istype(hold, /obj/item/door_hold/brace) ? "braced_by" : "held_by"] = hold.holder == M ? "you" : "[hold.holder]"
	if (D.door_closer)
		.["closer"] = D.door_fitting_name(D.door_closer)
	if (D.door_wedge && D.state)
		.["wedged"] = TRUE
