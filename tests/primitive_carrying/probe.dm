// Headless probe for the early carrying gear (code/modules/1713/primitive_carrying.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/primitive_carrying/probe.dm
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

// Era gate only: a node counts as done once its era is reached.
/obj/map_metadata/carry_probe/New()
	return
/obj/map_metadata/carry_probe/is_node_done(faction, node_id)
	var/datum/research_node/N = get_research_node(node_id)
	return N && N.era_tier <= ordinal_age

var/carry_failures = 0
var/carry_runtime_error = FALSE
/proc/carry_check(condition, label)
	if (!condition)
		carry_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	carry_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		map = new /obj/map_metadata/carry_probe
		build_research_tree()
		carry_recipe_checks()
		carry_capacity_checks()
		carry_sprite_checks()
		carry_travois_checks()
	catch(var/exception/e)
		carry_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = carry_failures, "runtime_error" = carry_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/carry_recipe_paths(material_name)
	var/material/M = get_material_by_name(material_name)
	M.generate_recipes_civs(list(0,0,0), "global")
	. = list()
	for (var/R in M.recipes)
		if (istype(R, /datum/stack_recipe))
			var/datum/stack_recipe/SR = R
			. += SR.result_type
		else if (istype(R, /datum/stack_recipe_list))
			var/datum/stack_recipe_list/L = R
			for (var/datum/stack_recipe/SR in L.recipes)
				. += SR.result_type

/proc/carry_recipe_checks()
	var/list/catalog = list()
	for (var/line in file2list("config/crafting/material_recipes_global.txt", "\n"))
		if (findtext(line, "RECIPE: ") && !findtext(line, "//"))
			catalog += list(splittext(replacetext(line, "RECIPE: ", ""), ","))
	craftlist_lists["global"] = catalog
	carry_check(catalog.len > 100, "global crafting catalog loaded")

	map.ordinal_age = 0
	var/list/rope = carry_recipe_paths("rope")
	var/list/wolf = carry_recipe_paths("wolfpelt")
	var/list/leather = carry_recipe_paths("leather")
	var/list/wood = carry_recipe_paths("wood")
	carry_check(/obj/item/weapon/storage/belt/carry_net in rope, "Stone Age: rope makes a grass carry net")
	carry_check(/obj/item/weapon/storage/backpack/sling_bag in wolf, "Stone Age: a wolf pelt makes a hide sling bag")
	carry_check(/obj/item/weapon/storage/backpack/sling_bag in leather, "Stone Age: leather makes a hide sling bag")
	carry_check(/obj/item/weapon/storage/backpack/pack_basket in wood, "Stone Age: wood makes a pack basket")
	carry_check(/obj/structure/closet/crate/travois in wood, "Stone Age: wood makes a travois")
	carry_check(!(/obj/item/weapon/storage/backpack/pack_frame in wood), "Stone Age: no pack frame yet")
	carry_check(!(/obj/item/weapon/storage/backpack in leather), "Stone Age: leather backpack still waits for Cooperage")

	map.ordinal_age = 1
	wood = carry_recipe_paths("wood")
	carry_check(/obj/item/weapon/storage/backpack/pack_frame in wood, "Bronze Age: wood makes a pack frame")
	carry_check(get_recipe_node_req("/obj/item/weapon/storage/backpack/pack_frame") == get_recipe_node_req("/obj/item/weapon/storage/backpack"), "pack frame shares the leather backpack's node")

/proc/carry_capacity_checks()
	var/turf/T = locate(5, 5, 1)
	var/obj/item/weapon/storage/belt/carry_net/net = new(T)
	var/obj/item/weapon/storage/backpack/sling_bag/sling = new(T)
	var/obj/item/weapon/storage/backpack/pack_basket/basket = new(T)
	var/obj/item/weapon/storage/backpack/backpack = new(T)
	var/obj/item/weapon/storage/backpack/pack_frame/frame = new(T)
	carry_check(net.slot_flags & SLOT_BELT, "carry net is worn on the belt")
	carry_check((sling.slot_flags & SLOT_BACK) && (basket.slot_flags & SLOT_BACK) && (frame.slot_flags & SLOT_BACK), "bags, basket and frame are worn on the back")
	carry_check(net.max_storage_space < sling.max_storage_space && sling.max_storage_space < basket.max_storage_space && basket.max_storage_space < backpack.max_storage_space && backpack.max_storage_space < frame.max_storage_space, "each step holds more than the last")
	carry_check(net.max_w_class == ITEM_SIZE_SMALL && sling.max_w_class == ITEM_SIZE_NORMAL && basket.max_w_class == ITEM_SIZE_NORMAL && frame.max_w_class == ITEM_SIZE_LARGE, "item size limits climb with the tier")
	carry_check(frame.carry_slowdown > 0 && !backpack.carry_slowdown && !sling.carry_slowdown && !basket.carry_slowdown, "only the pack frame slows its wearer")
	// A normal-sized item fits the sling bag but not the net.
	var/obj/item/weapon/storage/box/probe_item = new(T)
	probe_item.w_class = ITEM_SIZE_NORMAL
	carry_check(!net.can_be_inserted(probe_item, TRUE) && sling.can_be_inserted(probe_item, TRUE), "a normal-sized item fits the sling bag, not the net")
	probe_item.w_class = ITEM_SIZE_LARGE
	carry_check(!basket.can_be_inserted(probe_item, TRUE) && frame.can_be_inserted(probe_item, TRUE), "a large item fits the pack frame, not the basket")

/proc/carry_sprite_checks()
	var/list/item_states = icon_states('icons/obj/primitive_carrying.dmi')
	var/list/worn_states = icon_states('icons/mob/primitive_carrying.dmi')
	for (var/state in list("carry_net", "sling_bag", "pack_basket", "pack_frame", "travois", "travois_open"))
		carry_check(state in item_states, "item icon state [state]")
	for (var/state in list("carry_net", "sling_bag", "pack_basket", "pack_frame"))
		carry_check(state in worn_states, "worn icon state [state]")
	carry_check(length(icon('icons/mob/primitive_carrying.dmi', "pack_basket", NORTH).GetPixel(16, 16)), "worn basket is drawn facing north")

/proc/carry_travois_checks()
	var/turf/T = locate(10, 10, 1)
	var/obj/structure/closet/crate/travois/V = new(T)
	V.open()
	for (var/i = 1 to 20)
		new /obj/item/weapon/storage/box(T)
	V.close()
	var/stored = 0
	for (var/obj/item/I in V)
		stored++
	carry_check(stored == V.storagecap && V.storagecap == 15, "a travois holds 15 things (stored [stored])")
	carry_check(!V.climbable && !V.anchored, "a travois can be pulled and is not a climbing block")
