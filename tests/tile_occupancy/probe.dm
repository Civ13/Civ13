// Full-source probe: one floor and one wall per tile.
/world
	hub = ""
	visibility = 0
	maxx = 20
	maxy = 20
	maxz = 1
	fps = 20
	turf = /turf/floor/dirt
	area = /area

/world/OpenPort(port)
	if (port == "none")
		return ..("none")
	return FALSE

/world/Topic()
	return null

/client/New()
	del(src)

/obj/map_metadata/tile_probe/New()
	map = src

var/tile_probe_checks = 0
var/list/tile_probe_notes = list()

/proc/tile_probe_assert(ok, label)
	tile_probe_checks++
	if (!ok)
		throw EXCEPTION(label)

/proc/tile_probe_count(turf/T, path)
	. = 0
	for (var/atom/A in T)
		if (istype(A, path) && !QDELETED(A))
			.++

/proc/tile_probe_floors(turf/T)
	. = 0
	for (var/obj/covers/C in T)
		if (C.is_floor_cover() && !QDELETED(C))
			.++

/proc/tile_probe_walls(turf/T)
	. = 0
	for (var/obj/O in T)
		if (O.takes_wall_slot() && !QDELETED(O))
			.++

/proc/tile_probe_builder(tx, ty)
	var/mob/living/human/H = new(locate(tx, ty, 1))
	H.canmove = TRUE
	H.stat = CONSCIOUS
	H.stats = list("strength" = list(100,100), "crafting" = list(220,220))
	return H

// Build through the real crafting menu path with a stack in the active hand.
/proc/tile_probe_build(mob/living/human/H, stack_type, title, result_type)
	var/obj/item/stack/S = new stack_type(H, 50, FALSE)
	H.r_hand = S
	H.hand = FALSE
	// A refusal must come from the tile, never from a research gate.
	tile_probe_assert(crafting_recipe_allowed(H, "[result_type]"), "recipe_allowed [result_type]")
	var/datum/stack_recipe/R = new(title, result_type, 1, 1, 1, 0)
	S.produce_recipe(R, 1, H)
	. = S.amount
	H.r_hand = null
	qdel(S)

/proc/tile_probe_run()
	config = new
	config.webhook_can_fire = FALSE
	makeDatumRefLists()
	GLOB.all_observable_events = list()
	GLOB.moved_event = new
	GLOB.dir_set_event = new
	GLOB.destroyed_event = new
	GLOB.stat_set_event = new
	GLOB.name_set_event = new
	movementMachine = new
	populate_material_list()
	build_research_tree()
	map = new /obj/map_metadata/tile_probe
	map.ordinal_age = 8
	tile_probe_assert(world.byond_version == 516 && world.byond_build == 1688, "pinned_native_engine")

	// Every floor and wall type is classified by the shared rule.
	var/floors = 0
	var/walls = 0
	for (var/path in typesof(/obj/covers))
		if (cover_type_is_floor(path))
			floors++
		if (type_takes_wall_slot(path))
			walls++
		tile_probe_assert(!(cover_type_is_floor(path) && type_takes_wall_slot(path)), "floor_or_wall_not_both [path]")
	tile_probe_notes["floor_types"] = floors
	tile_probe_notes["wall_types"] = walls
	tile_probe_assert(cover_type_is_floor(/obj/covers/wood) && cover_type_is_floor(/obj/covers/concretefloor), "wood_and_concrete_are_floors")
	tile_probe_assert(type_takes_wall_slot(/obj/covers/wood_wall/adjustable) && type_takes_wall_slot(/obj/structure/simple_door/key_door/anyone/wood) && type_takes_wall_slot(/obj/structure/window_frame/stone) && type_takes_wall_slot(/obj/structure/wallframe), "walls_doors_windows_take_slot")

	// Concrete over wood: refused, through the crafting path, for both orders.
	var/mob/living/human/H = tile_probe_builder(5, 5)
	var/turf/T = get_turf(H)
	tile_probe_assert(tile_probe_build(H, /obj/item/stack/material/wood, "wood floor", /obj/covers/wood) == 49, "first_floor_built")
	tile_probe_assert(tile_probe_floors(T) == 1, "one_wood_floor")
	tile_probe_assert(tile_probe_build(H, /obj/item/stack/material/stone, "concrete floor", /obj/covers/concretefloor) == 50, "concrete_over_wood_refused_unpaid")
	tile_probe_assert(tile_probe_build(H, /obj/item/stack/material/wood, "wood floor", /obj/covers/wood) == 50, "wood_over_wood_refused_unpaid")
	tile_probe_assert(tile_probe_floors(T) == 1 && tile_probe_count(T, /obj/covers/concretefloor) == 0, "still_one_floor")
	// Removing the old floor frees the tile.
	for (var/obj/covers/C in T)
		qdel(C)
	tile_probe_assert(tile_probe_build(H, /obj/item/stack/material/stone, "concrete floor", /obj/covers/concretefloor) == 49, "concrete_after_removal")
	tile_probe_assert(tile_probe_floors(T) == 1 && tile_probe_count(T, /obj/covers/concretefloor) == 1, "concrete_alone")

	// A wall may stand on that floor, but only one wall.
	tile_probe_assert(tile_probe_build(H, /obj/item/stack/material/wood, "wood wall", /obj/covers/wood_wall/adjustable) == 49, "wall_on_floor_built")
	tile_probe_assert(tile_probe_build(H, /obj/item/stack/material/wood, "wood wall", /obj/covers/wood_wall/adjustable) == 50, "second_wall_refused")
	tile_probe_assert(tile_probe_build(H, /obj/item/stack/material/stone, "stone block wall", /obj/covers/stone_wall/classic) == 50, "other_wall_refused")
	tile_probe_assert(tile_probe_build(H, /obj/item/stack/material/wood, "wood door", /obj/structure/simple_door/key_door/anyone/wood) == 50, "door_in_wall_refused")
	tile_probe_assert(tile_probe_build(H, /obj/item/stack/material/stone, "stone window", /obj/structure/window_frame/stone) == 50, "window_in_wall_refused")
	tile_probe_assert(tile_probe_walls(T) == 1 && tile_probe_floors(T) == 1, "one_wall_one_floor")

	// A door may hang in a doorway, once.
	var/mob/living/human/D = tile_probe_builder(8, 5)
	var/turf/DT = get_turf(D)
	new /obj/covers/stone_wall/classic/archway(DT)
	tile_probe_assert(tile_probe_build(D, /obj/item/stack/material/wood, "wood door", /obj/structure/simple_door/key_door/anyone/wood) == 49, "door_in_archway")
	tile_probe_assert(tile_probe_build(D, /obj/item/stack/material/wood, "wood door", /obj/structure/simple_door/key_door/anyone/wood) == 50, "second_door_refused")
	tile_probe_assert(tile_probe_build(D, /obj/item/stack/material/wood, "wood wall", /obj/covers/wood_wall/adjustable) == 50, "wall_in_archway_refused")

	// Wall foundations laid from bricks, dirt and snow.
	var/mob/living/human/B = tile_probe_builder(11, 5)
	var/turf/BT = get_turf(B)
	new /obj/covers/wood_wall(BT)
	for (var/path in list(/obj/item/weapon/clay/advclaybricks/fired, /obj/item/weapon/clay/advclaybricks/fired/cement, /obj/item/weapon/barrier, /obj/item/weapon/snowwall))
		var/obj/item/I = new path(B)
		I.attack_self(B)
		tile_probe_assert(!QDELETED(I), "foundation_kept [path]")
		qdel(I)
	tile_probe_assert(tile_probe_walls(BT) == 1, "no_foundation_on_wall")
	var/mob/living/human/F = tile_probe_builder(14, 5)
	var/obj/item/weapon/clay/advclaybricks/fired/bricks = new(F)
	bricks.attack_self(F)
	tile_probe_assert(QDELETED(bricks) && tile_probe_count(get_turf(F), /obj/covers/brick_wall/incomplete) == 1, "foundation_on_free_tile")
	var/obj/item/weapon/clay/advclaybricks/fired/more = new(F)
	more.attack_self(F)
	tile_probe_assert(!QDELETED(more) && tile_probe_walls(get_turf(F)) == 1, "second_foundation_refused")

/world/New()
	OpenPort("none")
	var/error = null
	try
		tile_probe_run()
	catch (var/exception/probe_error)
		error = "[probe_error.name] ([probe_error.file]:[probe_error.line])"
	text2file(error ? "FAIL [error]" : "PASS", "result.txt")
	text2file(json_encode(list("checks" = tile_probe_checks, "error" = error, "notes" = tile_probe_notes, "byond_build" = byond_build)), "receipt.json")
	del(world)
