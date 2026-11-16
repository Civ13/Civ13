// Native fixture for code/game/objects/items/stacks/stack_spawn.dm. run.py adds
// the production helper plus /obj/item/stack/New and merge copied from stack.dm;
// only the vars and engine-side procs they touch are declared here.
var/list/checks = list()
var/list/failed = list()

/proc/check(label, ok)
	checks += label
	if (!ok)
		failed += "[label]"

/atom/proc/update_icon()
	return
/atom/movable/var/atom/movable/pulledby = null
/atom/movable/proc/start_pulling(atom/movable/AM)
	return
/proc/qdel(datum/D)
	if (istype(D, /atom/movable))
		var/atom/movable/AM = D
		AM.loc = null
	del(D)

/obj/item
	var/amount = 0
/obj/item/stack
	amount = 1
	var/max_amount = 50
	var/stacktype
	var/can_stack = FALSE
/obj/item/stack/proc/update_strings()
	return
/obj/item/stack/ingot
	can_stack = TRUE
/obj/item/stack/ingot/copper
/obj/item/stack/ingot/tin
/obj/item/stack/loose
	can_stack = FALSE

/proc/total(atom/T, path)
	. = 0
	for (var/obj/item/stack/S in T)
		if (istype(S, path))
			. += S.amount

/proc/piles(atom/T, path)
	. = 0
	for (var/obj/item/stack/S in T)
		if (istype(S, path))
			.++

/world
	maxx = 3
	maxy = 3
	maxz = 1

/world/New()
	..()
	var/turf/T = locate(1, 1, 1)

	// The reported bug: the old "new stack(loc); amount = n" pattern on an existing pile.
	new /obj/item/stack/ingot/copper(T, 5, FALSE)
	var/obj/item/stack/ingot/copper/old = new /obj/item/stack/ingot/copper(T)
	if (old)
		old.amount = 4
	check("old pattern loses ingots (control)", total(T, /obj/item/stack/ingot/copper) == 6)
	for (var/obj/item/stack/S in T)
		qdel(S)

	new /obj/item/stack/ingot/copper(T, 5, FALSE)
	var/obj/item/stack/kept = spawn_stack(/obj/item/stack/ingot/copper, T, 4)
	check("full amount merges", total(T, /obj/item/stack/ingot/copper) == 9)
	check("merged into one pile", piles(T, /obj/item/stack/ingot/copper) == 1)
	check("returns the pile", kept && kept.amount == 9)
	for (var/obj/item/stack/S in T)
		qdel(S)

	new /obj/item/stack/ingot/copper(T, 48, FALSE)
	kept = spawn_stack(/obj/item/stack/ingot/copper, T, 7)
	check("overflow keeps every ingot", total(T, /obj/item/stack/ingot/copper) == 55)
	check("overflow fills the pile", piles(T, /obj/item/stack/ingot/copper) == 2)
	check("overflow returns the new pile", kept && kept.amount == 5)
	for (var/obj/item/stack/S in T)
		qdel(S)

	new /obj/item/stack/ingot/copper(T, 50, FALSE)
	kept = spawn_stack(/obj/item/stack/ingot/copper, T, 3)
	check("full pile left alone", total(T, /obj/item/stack/ingot/copper) == 53 && kept && kept.amount == 3)
	for (var/obj/item/stack/S in T)
		qdel(S)

	new /obj/item/stack/ingot/tin(T, 5, FALSE)
	kept = spawn_stack(/obj/item/stack/ingot/copper, T, 4)
	check("other metal not merged", total(T, /obj/item/stack/ingot/tin) == 5 && total(T, /obj/item/stack/ingot/copper) == 4)
	for (var/obj/item/stack/S in T)
		qdel(S)

	kept = spawn_stack(/obj/item/stack/ingot/copper, T, 12)
	check("empty tile gets the full amount", kept && kept.amount == 12 && piles(T, /obj/item/stack/ingot/copper) == 1)
	for (var/obj/item/stack/S in T)
		qdel(S)

	new /obj/item/stack/loose(T, 5, FALSE)
	spawn_stack(/obj/item/stack/loose, T, 4)
	check("non-stacking types stay apart", piles(T, /obj/item/stack/loose) == 2 && total(T, /obj/item/stack/loose) == 9)
	for (var/obj/item/stack/S in T)
		qdel(S)

	check("zero amount makes nothing", isnull(spawn_stack(/obj/item/stack/ingot/copper, T, 0)) && piles(T, /obj/item/stack) == 0)

	text2file(json_encode(list("checks" = checks.len, "failed_labels" = failed)), "result.json")
	shutdown()
