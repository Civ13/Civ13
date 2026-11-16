// Headless probe for item piles (code/game/objects/items/item_piles.dm) and
// roofing piles (code/game/objects/roof_stuff.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/item_piles/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 20
	maxy = 20
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

var/pile_failures = 0
var/pile_runtime_error = FALSE
/proc/pile_check(condition, label)
	if (!condition)
		pile_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	pile_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		pile_collapse_checks()
		roofing_pile_checks()
	catch(var/exception/e)
		pile_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = pile_failures, "runtime_error" = pile_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/pile_clickable(turf/T, path)
	. = 0
	for (var/obj/item/I in T)
		if (istype(I, path) && I.mouse_opacity && !QDELETED(I))
			.++

/proc/pile_collapse_checks()
	var/turf/T = locate(5, 5, 1)
	var/list/made = list()
	for (var/i in 1 to 70)
		made += new /obj/item/weapon/roofbuilder/clay/black(T)
	for (var/i in 1 to 3)
		new /obj/item/weapon/clay/roofing/black(T)
	var/obj/item/weapon/clay/roofing/black/kept_hidden = new(T)
	kept_hidden.mouse_opacity = 0 // hidden by its own code (a rack, a flood)
	item_pile_flush()
	pile_check(pile_clickable(T, /obj/item/weapon/roofbuilder/clay/black) == 1, "70 identical roofing on a tile: one menu entry")
	pile_check(pile_clickable(T, /obj/item/weapon/clay/roofing/black) == 1, "a different item keeps its own single entry")
	pile_check(!kept_hidden.mouse_opacity && !kept_hidden.pile_hidden, "an item hidden by other code is left alone")
	var/obj/item/top = made[made.len]
	pile_check(top.mouse_opacity && !top.pile_hidden, "the last (top-drawn) item is the clickable one")

	var/turf/T2 = locate(6, 5, 1)
	top.forceMove(T2)
	pile_check(top.mouse_opacity == 1, "an item leaving the pile is clickable at once")
	item_pile_flush()
	pile_check(pile_clickable(T, /obj/item/weapon/roofbuilder/clay/black) == 1, "the next item becomes clickable when the top leaves")
	pile_check(pile_clickable(T2, /obj/item/weapon/roofbuilder/clay/black) == 1, "the moved item is clickable on its new tile")

	var/obj/item/next = null
	for (var/obj/item/weapon/roofbuilder/clay/black/R in T)
		if (R.mouse_opacity)
			next = R
	var/obj/holder = new /obj(locate(1, 1, 1))
	next.persistence_set_loc(holder)
	pile_check(next.mouse_opacity == 1 && !next.pile_hidden, "a raw move into a holder reveals the item")
	item_pile_flush()
	pile_check(pile_clickable(T, /obj/item/weapon/roofbuilder/clay/black) == 1, "a raw move off the tile still reveals the next item")

	var/obj/item/hidden = null
	for (var/obj/item/weapon/roofbuilder/clay/black/R in T)
		if (R.pile_hidden)
			hidden = R
			break
	hidden.pickup(null)
	pile_check(hidden.mouse_opacity == 1, "picking up an item always makes it clickable")

	// Different names are different menu entries (roofing piles show counts).
	var/turf/T3 = locate(8, 5, 1)
	var/obj/item/weapon/roofbuilder/clay/black/A = new(T3)
	var/obj/item/weapon/roofbuilder/clay/black/B = new(T3)
	B.amount = 4
	B.update_roofing_pile()
	item_pile_flush()
	pile_check(A.mouse_opacity && B.mouse_opacity, "items with different names are not collapsed together")

/proc/roofing_pile_checks()
	var/turf/T = locate(12, 12, 1)
	var/obj/item/weapon/roofbuilder/clay/black/A = new(T)
	var/obj/item/weapon/roofbuilder/clay/black/B = new(T)
	pile_check(A.add_to_roofing_pile(B) == 1 && A.amount == 2 && QDELETED(B), "roofing joins a pile of the same roofing")
	pile_check(A.name == "black clay roofing (2)", "a pile shows its count in its name")
	var/obj/item/weapon/roofbuilder/clay/blue/C = new(T)
	pile_check(!A.add_to_roofing_pile(C) && C.amount == 1, "different roofing does not pile")
	A.amount = A.pile_max
	var/obj/item/weapon/roofbuilder/clay/black/D = new(T)
	pile_check(!A.add_to_roofing_pile(D) && !QDELETED(D), "a full pile takes no more")
	A.amount = 2
	A.done = TRUE
	A.use_one_roofing(null)
	pile_check(A.amount == 1 && !A.done && A.name == "black clay roofing", "building uses one roofing and leaves the rest usable")
	A.use_one_roofing(null)
	pile_check(QDELETED(A), "the last roofing is used up")

	var/turf/T2 = locate(14, 12, 1)
	var/obj/item/weapon/roofbuilder/clay/black/E = new(T2)
	var/obj/item/weapon/roofbuilder/clay/black/F = new(T2)
	F.join_roofing_pile_here()
	pile_check(QDELETED(F) && E.amount == 2, "roofing dropped on a pile joins it")

	var/obj/kiln = new /obj(locate(16, 12, 1))
	var/obj/item/weapon/clay/roofing/black/U1 = new(null)
	var/obj/item/weapon/clay/roofing/black/U2 = new(null)
	var/obj/item/weapon/roofbuilder/R1 = U1.fired_result(kiln)
	var/obj/item/weapon/roofbuilder/R2 = U2.fired_result(kiln)
	var/n = 0
	for (var/obj/item/weapon/roofbuilder/R in kiln)
		n++
	pile_check(R1 == R2 && n == 1 && R1.amount == 2, "fired roof tiles pile up in the kiln")
