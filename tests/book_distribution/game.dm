// Full production logic; isolate physiology, client presence and action waits.
var/distribution_failures = 0
var/distribution_wait_result = TRUE
var/distribution_wait_count = 0
var/distribution_mutation = null
/world
	hub = ""
	hub_password = ""
	maxx = 8
	maxy = 8
	maxz = 1
	turf = /turf
	visibility = 0
/world/OpenPort(port)
	return port == "none" ? ..() : FALSE
/obj/map_metadata/distribution_fixture
	recipe_books = TRUE
/obj/map_metadata/distribution_fixture/New()
	return
/mob/living/human/distribution_fixture/New()
	initialize_recipe_knowledge()
/mob/living/human/distribution_fixture/incapacitated()
	return stat != CONSCIOUS
/mob/living/human/distribution_fixture/restrained()
	return FALSE
/mob/living/human/distribution_fixture/remove_from_mob(obj/O)
	if(l_hand == O) l_hand = null
	if(r_hand == O) r_hand = null
	O.loc = get_turf(src)
	return TRUE
/mob/living/human/distribution_fixture/put_in_hands(obj/item/I)
	I.loc = src
	if(!l_hand) l_hand = I
	else if(!r_hand) r_hand = I
	return TRUE
/mob/living/human/distribution_fixture/update_icons()
	return
/proc/distribution_wait(mob/living/human/H, delay, atom/target)
	distribution_wait_count++
	if(distribution_mutation == "paper")
		var/obj/item/weapon/paper/P = locate() in H
		if(P) P.info = "used during wait"
	if(distribution_mutation == "knowledge") H.known_recipe_nodes = list()
	if(distribution_mutation == "era") map.ordinal_age = -1
	if(distribution_mutation == "student" && ishuman(target))
		var/mob/living/human/student = target
		student.stat = UNCONSCIOUS
	return distribution_wait_result
/proc/distribution_check(condition, label)
	if(!condition) distribution_failures++
	world.log << "[condition ? "PASS" : "FAIL:"] [label]"
/world/Error(exception/e)
	distribution_failures++
	world.log << "runtime error: [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	generate_gameid()
	GLOB.all_observable_events = list()
	GLOB.moved_event = new /decl/observ/moved
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.name_set_event = new /decl/observ/name_set
	GLOB.stat_set_event = new /decl/observ/stat_set
	movementMachine = new
	map = new /obj/map_metadata/distribution_fixture(locate(1,1,1))
	map.persistence = TRUE
	map.ordinal_age = 6
	build_research_tree()
	try
		var/mob/living/human/distribution_fixture/H = new(locate(2,2,1))
		var/obj/item/weapon/pen/pen = new(H)
		var/obj/item/weapon/paper/paper = new(H)
		H.l_hand = pen
		H.r_hand = paper
		distribution_check(!H.copy_recipe_manual("basic_tools", pen, paper), "unknown node cannot be copied")
		H.learn_recipe_node("basic_tools")
		distribution_wait_result = FALSE
		distribution_check(!H.copy_recipe_manual("basic_tools", pen, paper) && paper.loc == H, "cancelled copying preserves paper")
		distribution_wait_result = TRUE
		distribution_mutation = "paper"
		distribution_check(!H.copy_recipe_manual("basic_tools", pen, paper) && paper.loc == H, "changed paper rejected after wait")
		paper.info = null
		distribution_mutation = "knowledge"
		distribution_check(!H.copy_recipe_manual("basic_tools", pen, paper), "lost knowledge rejected after wait")
		H.learn_recipe_node("basic_tools")
		distribution_mutation = "era"
		distribution_check(!H.copy_recipe_manual("basic_tools", pen, paper), "changed research ceiling rejected after wait")
		map.ordinal_age = 6
		distribution_mutation = null
		distribution_check(H.copy_recipe_manual("basic_tools", pen, paper), "paid hand copy succeeds")
		distribution_check(pen.loc == H && (!paper || paper.gcDestroyed || !paper.loc), "copy keeps pen but consumes paper")
		var/obj/item/weapon/book/node_book/B = H.r_hand
		distribution_check(istype(B) && B.node_id == "basic_tools", "copy stores node ID")
		var/obj/structure/printingpress/press = new(locate(2,3,1))
		H.remove_from_mob(pen)
		paper = new(H)
		H.l_hand = B
		H.r_hand = paper
		H.hand = 0
		// Explicit active/inactive hand selection follows production hand field.
		if(H.get_inactive_hand() != paper) H.hand = !H.hand
		distribution_wait_result = FALSE
		distribution_check(!press.print_recipe_manual(B, H) && !press.copying && paper.loc == H, "cancelled printing clears lock without cost")
		distribution_wait_result = TRUE
		distribution_check(press.print_recipe_manual(B, H) && B.loc == H && (!paper || paper.gcDestroyed || !paper.loc), "printing consumes paper and preserves original")
		var/mob/living/human/distribution_fixture/student = new(locate(3,2,1))
		distribution_mutation = "student"
		distribution_check(!H.teach_recipe_node(student, "basic_tools") && !student.knows_recipe_node("basic_tools"), "unconscious student cancels teaching")
		student.stat = CONSCIOUS
		distribution_mutation = null
		distribution_wait_count = 0
		distribution_check(H.teach_recipe_node(student, "basic_tools") && student.knows_recipe_node("basic_tools") && distribution_wait_count == 120, "teaching requires every timed segment")
		distribution_check(!H.teach_recipe_node(student, "basic_tools"), "known student cannot repeat lesson")
		var/obj/item/weapon/book/node_compendium/C = new(locate(4,4,1))
		C.node_ids = list("basic_tools", "primitive_construction", "missing", 5, "basic_tools")
		C.after_load()
		distribution_check(C.node_ids.len == 2, "compendium restoration sanitizes and deduplicates text IDs")
		var/kind = region_travel_item_kind(C)
		distribution_check(region_travel_item_path(kind, 1) == /obj/item/weapon/book/node_compendium && recipe_compendium_wire_ids(kind).len == 2, "compendium travels as bounded text IDs")
		distribution_check(!recipe_compendium_wire_ids("compendium:[json_encode(list("missing"))]") && !region_travel_item_path(kind, 2), "invalid compendium wire refuses")
		C.node_ids = clean_recipe_node_ids(research_nodes)
		C.after_load()
		distribution_check(C.node_ids.len == 16, "compendium chapter count bounded")
		C.node_ids = list("basic_tools", "primitive_construction")
		var/savefile/F = new("compendium.sav")
		F["node_ids"] << C.node_ids
		C.node_ids = list()
		F["node_ids"] >> C.node_ids
		C.after_load()
		distribution_check(C.node_ids.len == 2 && istext(C.node_ids[1]), "native saved chapter IDs remain strings")
		var/obj/structure/recipe_book_cache/starter/cache = new(locate(2,3,1))
		map.ordinal_age = 0
		var/obj/item/weapon/book/node_book/loot = cache.claim_manual(H)
		distribution_check(loot && get_research_node(loot.node_id).era_tier == 0, "starter cache only yields current early-era manual")
		distribution_check(!cache.claim_manual(H) && cache.restock_remaining > 0, "same cache cannot regenerate twice immediately")
		F["cooldown"] << cache.restock_remaining
		cache.restock_remaining = 0
		F["cooldown"] >> cache.restock_remaining
		cache.after_load()
		distribution_check(!cache.claim_manual(H), "saved cooldown prevents reload farming")
		map.recipe_books = FALSE
		cache.restock_remaining = 0
		distribution_check(!cache.claim_manual(H), "disabled flag blocks cache")
		var/datum/specialist_trader/provisioner/dealer = specialist_trader_get("provisioner")
		var/list/entry = dealer.catalogue[1]
		distribution_check(!dealer.entry_in_season(entry), "starter stock hidden while flag disabled")
		map.recipe_books = TRUE
		distribution_check(dealer.entry_in_season(entry) && dealer.entry_researched(entry, H) && entry[5] == 2 && entry[6] == 3, "starter stock is cheap bounded and ceiling checked")
	catch(var/exception/e)
		distribution_failures++
		world.log << "FAIL: exception [e] [e.file]:[e.line]"
	var/list/params = params2list(world.params)
	text2file(json_encode(list("failures" = distribution_failures, "commit" = params["tested_commit"], "byond_build" = world.byond_build)), "result.json")
	shutdown()
