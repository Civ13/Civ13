// Full production sources; isolate startup, map and human physiology only.
var/knowledge_failures = 0
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
/obj/map_metadata/knowledge_fixture
	recipe_books = TRUE
/obj/map_metadata/knowledge_fixture/New()
	return
/mob/living/human/knowledge_fixture/New()
	species = new /datum/species/human
	body_build = new /datum/body_build
	bloodstr = new /datum/reagents/metabolism(1000, src, CHEM_BLOOD)
	ingested = new /datum/reagents/metabolism(1000, src, CHEM_INGEST)
	touching = new /datum/reagents/metabolism(1000, src, CHEM_TOUCH)
	reagents = bloodstr
	vessel = new /datum/reagents(1000, src)
	if (!persistence_saved_atom_construction)
		initialize_recipe_knowledge()
/proc/knowledge_check(condition, label)
	if (!condition)
		knowledge_failures++
	world.log << "[condition ? "PASS" : "FAIL:"] [label]"
/world/Error(exception/e)
	knowledge_failures++
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
	map = new /obj/map_metadata/knowledge_fixture(locate(1,1,1))
	map.ID = MAP_NOMADS_CONTINENTAL
	map.ordinal_age = 6
	map.persistence = TRUE
	build_research_tree()
	try
		knowledge_check(!world.port, "offline fixture")
		var/node_id
		var/future_id
		for (var/id in research_nodes)
			var/datum/research_node/N = research_nodes[id]
			if (N.tree == "Main" && N.era_tier <= 6) node_id = id
			if (N.tree == "Main" && N.era_tier > 6) future_id = id
		knowledge_check(node_id && future_id, "real node registry supplies era boundaries")
		var/mob/living/human/knowledge_fixture/H = new(locate(2,2,1))
		knowledge_check(H.recipe_knowledge_initialized && !H.known_recipe_nodes.len, "new enabled body starts empty")
		knowledge_check(!H.migrate_recipe_knowledge() && !H.knows_recipe_node(node_id), "new body never receives legacy grant")
		knowledge_check(!H.learn_recipe_node(null) && !H.learn_recipe_node(12) && !H.learn_recipe_node("missing") && !H.learn_recipe_node(future_id), "invalid IDs and future research rejected")
		knowledge_check(H.learn_recipe_node(node_id) && H.learn_recipe_node(node_id) && H.known_recipe_nodes.len == 1, "learning is idempotent")
		var/obj/item/weapon/book/node_book/B = create_node_book(locate(2,2,1), node_id)
		knowledge_check(B && B.node_id == node_id && !create_node_book(H, "missing"), "book creation validates text IDs")
		B.attack_self(H)
		knowledge_check(!QDELETED(B) && H.known_recipe_nodes.len == 1, "repeated reading preserves reusable book")
		var/mob/living/human/knowledge_fixture/fresh = new(locate(3,2,1))
		knowledge_check(!fresh.knows_recipe_node(node_id), "fresh body does not inherit another body's knowledge")
		H.forget_recipe_knowledge()
		H.stat = DEAD
		knowledge_check(!H.knows_recipe_node(node_id) && !H.known_recipe_nodes.len && !H.migrate_recipe_knowledge(), "death clears knowledge and closes migration")
		H.stat = CONSCIOUS
		knowledge_check(H.learn_recipe_node(node_id), "revived body can relearn from reusable book")
		map.recipe_books = FALSE
		var/mob/living/human/knowledge_fixture/legacy = new(locate(4,2,1))
		knowledge_check(!legacy.recipe_knowledge_initialized && !legacy.can_learn_recipe_node(node_id), "disabled mode preserves legacy migration eligibility")
		map.activate_recipe_books()
		// Fixture New skips production registration, so register this body explicitly.
		legacy.migrate_recipe_knowledge()
		knowledge_check(legacy.knows_recipe_node(node_id) && !legacy.knows_recipe_node(future_id), "activation grants current research only")
		map.ordinal_age = 9
		knowledge_check(!legacy.migrate_recipe_knowledge() && !legacy.knows_recipe_node(future_id), "later eras cannot repeat migration")
		map.ordinal_age = 6
		var/mob/living/human/knowledge_fixture/old_save = new(locate(5,2,1))
		old_save.persistence_import_fields(list())
		knowledge_check(!old_save.recipe_knowledge_initialized && old_save.migrate_recipe_knowledge() && old_save.knows_recipe_node(node_id), "omitted old-save fields receive one grant")
		old_save.known_recipe_nodes = list(node_id, node_id, "missing", 17)
		old_save.persistence_import_fields(list("recipe_knowledge_initialized", "known_recipe_nodes"))
		knowledge_check(old_save.known_recipe_nodes.len == 1, "restored IDs are text-only validated and deduplicated")
		knowledge_check(map_storage.Save_World() && map_storage.validate_world_save(), "native body and book durable save")
		map_storage.ClearMap()
		knowledge_check(map_storage.Load_World(), "native durable reload")
		H = locate(/mob/living/human/knowledge_fixture) in locate(2,2,1)
		fresh = locate(/mob/living/human/knowledge_fixture) in locate(3,2,1)
		B = locate(/obj/item/weapon/book/node_book) in locate(2,2,1)
		knowledge_check(H && H.knows_recipe_node(node_id) && H.recipe_knowledge_initialized, "learned body knowledge survives actual reload")
		knowledge_check(fresh && fresh.recipe_knowledge_initialized && !fresh.known_recipe_nodes.len, "empty fresh saved body remains empty after reload")
		knowledge_check(B && B.node_id == node_id, "book text node id survives reload")
		knowledge_check(!("recipe_books" in durable_metadata_map_schema()), "opt-in configuration does not expand durable map metadata")
	catch (var/exception/e)
		knowledge_failures++
		world.log << "FAIL: exception [e] [e.file]:[e.line]"
	var/list/params = params2list(world.params)
	text2file(json_encode(list("failures" = knowledge_failures, "commit" = params["tested_commit"], "byond_build" = world.byond_build)), "result.json")
	shutdown()
