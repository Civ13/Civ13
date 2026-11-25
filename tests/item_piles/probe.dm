// Headless probe for item piles and loose piles (code/game/objects/items/item_piles.dm),
// roofing piles (code/game/objects/roof_stuff.dm) and brick piles (clay_items.dm).
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
		pile_distinct_hitbox_checks()
		roofing_pile_checks()
		brick_pile_checks()
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
	B.loose_pile_update()
	item_pile_flush()
	pile_check(A.mouse_opacity && B.mouse_opacity, "items with different names are not collapsed together")

// The loot in the player report uses scattered snack offsets. Set the
// positions explicitly so the failure is deterministic.
/proc/pile_distinct_hitbox_checks()
	var/turf/T = locate(12, 4, 1)
	var/obj/item/weapon/reagent_containers/food/snacks/rawcutlet/left = new(T)
	var/obj/item/weapon/reagent_containers/food/snacks/rawcutlet/copy = new(T)
	var/obj/item/weapon/reagent_containers/food/snacks/rawcutlet/right = new(T)
	left.pixel_x = -6
	copy.pixel_x = -6
	right.pixel_x = 6
	left.pixel_y = 0
	copy.pixel_y = 0
	right.pixel_y = 0
	item_pile_flush()
	pile_check(!left.mouse_opacity && copy.mouse_opacity && right.mouse_opacity, "two offset cutlets stay clickable; an exact duplicate still groups")
	item_pile_refresh(T)
	pile_check(!left.mouse_opacity && copy.mouse_opacity && right.mouse_opacity, "rechecking a hidden duplicate keeps the same representatives")

	// Equal position isn't sufficient: hitboxes can differ due to direction,
	// transform, appearance overlays, plane or mouse mask.
	copy.transform = matrix(1, 0, 0, 0, 0.5, 0)
	item_pile_refresh(T)
	pile_check(left.mouse_opacity && copy.mouse_opacity, "differing transforms preserve hitboxes even with equal offsets")
	copy.transform = left.transform
	copy.mouse_opacity = 2
	item_pile_refresh(T)
	pile_check(left.mouse_opacity == 1 && copy.mouse_opacity == 2, "different native mouse masks remain intact")

	copy.mouse_opacity = left.mouse_opacity
	item_pile_refresh(T)
	pile_check(left.pile_hidden, "a matching appearance groups again")
	left.persistence_set_loc(locate(13, 4, 1))
	pile_check(left.mouse_opacity && !left.pile_hidden, "raw turf-to-turf move restores clickability before delayed regroup")

/proc/roofing_pile_checks()
	var/turf/T = locate(12, 12, 1)
	var/obj/item/weapon/roofbuilder/clay/black/A = new(T)
	var/obj/item/weapon/roofbuilder/clay/black/B = new(T)
	pile_check(A.loose_pile_add(B) == 1 && A.amount == 2 && QDELETED(B), "roofing joins a pile of the same roofing")
	pile_check(A.name == "black clay roofing (2)", "a pile shows its count in its name")
	var/obj/item/weapon/roofbuilder/clay/blue/C = new(T)
	pile_check(!A.loose_pile_add(C) && C.amount == 1, "different roofing does not pile")
	A.amount = A.loose_pile_max
	var/obj/item/weapon/roofbuilder/clay/black/D = new(T)
	pile_check(!A.loose_pile_add(D) && !QDELETED(D), "a full pile takes no more")
	A.amount = 2
	A.done = TRUE
	A.use_one_roofing(null)
	pile_check(A.amount == 1 && !A.done && A.name == "black clay roofing", "building uses one roofing and leaves the rest usable")
	A.use_one_roofing(null)
	pile_check(QDELETED(A), "the last roofing is used up")

	var/turf/T2 = locate(14, 12, 1)
	var/obj/item/weapon/roofbuilder/clay/black/E = new(T2)
	var/obj/item/weapon/roofbuilder/clay/black/F = new(T2)
	F.loose_pile_join_here()
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


/proc/brick_pile_count(atom/where, path)
	. = 0
	for (var/obj/item/I in where)
		if (I.type == path && !QDELETED(I))
			. += I.amount

/proc/brick_pile_checks()
	var/turf/T = locate(4, 16, 1)
	var/obj/item/weapon/clay/advclaybricks/fired/A = new(T)
	var/obj/item/weapon/clay/advclaybricks/fired/B = new(T)
	pile_check(A.loose_pile_add(B) == 1 && A.amount == 2 && QDELETED(B) && A.name == "bricks (2)", "fired bricks pile up and show the count")
	var/obj/item/weapon/clay/advclaybricks/fired/cement/C = new(T)
	pile_check(!A.loose_pile_add(C) && C.amount == 1, "cement bricks and bricks stay apart")
	var/obj/item/weapon/clay/advclaybricks/U = new(T)
	pile_check(!A.loose_pile_add(U), "unfired and fired bricks stay apart")
	pile_check(A.loose_pile_use(1) == 1 && A.amount == 1 && A.name == "bricks", "building uses one brick from the pile")
	pile_check(A.loose_pile_use(1) == 1 && QDELETED(A), "the last brick is used up")

	// The brick bench and crates put out one pile, not separate bricks.
	var/turf/T2 = locate(6, 16, 1)
	var/obj/item/weapon/clay/claybricks/P = loose_pile_spawn(/obj/item/weapon/clay/claybricks, T2, 30)
	var/piles = 0
	for (var/obj/item/weapon/clay/claybricks/X in T2)
		piles++
	pile_check(istype(P) && piles == 2 && brick_pile_count(T2, /obj/item/weapon/clay/claybricks) == 30, "30 unfired clay blocks make two piles (25 + 5)")
	var/obj/item/weapon/barrier/D = loose_pile_spawn(/obj/item/weapon/barrier, T2, 3)
	var/dirt = 0
	for (var/obj/item/weapon/barrier/X in T2)
		dirt++
	pile_check(istype(D) && dirt == 3 && D.amount == 1, "items that do not pile still come out one by one")

	// Kiln: a pile of unfired bricks fires into one pile; clay blocks yield two each.
	var/obj/kiln = new /obj(locate(8, 16, 1))
	var/obj/item/weapon/clay/advclaybricks/UB = new(null)
	UB.amount = 5
	UB.loose_pile_update()
	var/obj/item/weapon/clay/advclaybricks/fired/FB = UB.fired_result(kiln)
	pile_check(istype(FB) && FB.amount == 5 && FB.loc == kiln, "five unfired bricks fire into a pile of five")
	var/obj/item/weapon/clay/claybricks/UC = new(null)
	UC.amount = 4
	UC.loose_pile_update()
	UC.fired_result(kiln)
	pile_check(brick_pile_count(kiln, /obj/item/weapon/clay/claybricks/fired) == 8, "four clay blocks fire into eight, as before")
	var/obj/item/weapon/clay/roofing/black/UR = new(null)
	UR.amount = 3
	UR.loose_pile_update()
	var/obj/item/weapon/roofbuilder/RR = UR.fired_result(kiln)
	pile_check(istype(RR) && RR.amount == 3, "a pile of unfired roof tiles fires into one roofing pile")

	// Dropping onto a pile joins it; a full pile refuses more.
	var/turf/T3 = locate(10, 16, 1)
	var/obj/item/weapon/clay/advclaybricks/fired/cement/E = new(T3)
	var/obj/item/weapon/clay/advclaybricks/fired/cement/F = new(T3)
	F.loose_pile_join_here()
	pile_check(QDELETED(F) && E.amount == 2, "a cement brick dropped on a pile joins it")
	E.amount = E.loose_pile_max
	var/obj/item/weapon/clay/advclaybricks/fired/cement/G = new(T3)
	G.loose_pile_join_here()
	pile_check(!QDELETED(G) && G.amount == 1, "a full pile takes no more")

	// Repairs and builds take several pieces from one pile.
	var/turf/T4 = locate(12, 16, 1)
	var/obj/item/weapon/clay/advclaybricks/fired/R = new(T4)
	R.amount = 10
	R.loose_pile_update()
	var/used = R.loose_pile_use(2)
	pile_check(used == 2 && R.amount == 8, "a repair takes only the bricks it needs")
