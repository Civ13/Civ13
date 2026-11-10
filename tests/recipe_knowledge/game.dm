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
	human_mob_list |= src
	human_mob_list |= src
	species = new /datum/species/human
	body_build = new /datum/body_build
	bloodstr = new /datum/reagents/metabolism(1000, src, CHEM_BLOOD)
	ingested = new /datum/reagents/metabolism(1000, src, CHEM_INGEST)
	touching = new /datum/reagents/metabolism(1000, src, CHEM_TOUCH)
	reagents = bloodstr
	vessel = new /datum/reagents(1000, src)
	if (!persistence_saved_atom_construction)
		initialize_recipe_knowledge()
/obj/structure/research_bench/knowledge_fixture/New()
	research_benches |= src
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
		knowledge_check(!crafting_node_allowed(H, node_id) && !crafting_recipe_allowed(H, "/obj/item/stack/material/rope") && !crafting_recipe_allowed(H, "/obj/item/stack/material/stonebrick"), "unknown node blocked and rope/stone bricks need manuals")
		knowledge_check(crafting_recipe_allowed(H, "/obj/structure/research_bench") && crafting_recipe_allowed(H, "/obj/item/weapon/clay/mold/axehead") && crafting_recipe_manual_hint(H, "/obj/structure/research_bench") == "", "research bench and era prototypes need no manual")
		knowledge_check(!crafting_recipe_allowed(H, "/obj/item/weapon/telephone/mobile") && is_research_essential_recipe("/obj/item/weapon/telephone/mobile") && is_research_essential_recipe("/obj/item/stack/cable_coil/red"), "prototype still needs the world's research")
		map.persistence = FALSE
		knowledge_check(crafting_node_allowed(H, node_id), "round maps bypass personal knowledge")
		map.persistence = TRUE
		knowledge_check(!H.migrate_recipe_knowledge() && !H.knows_recipe_node(node_id), "new body never receives legacy grant")
		knowledge_check(!H.learn_recipe_node(null) && !H.learn_recipe_node(12) && !H.learn_recipe_node("missing") && !H.learn_recipe_node(future_id), "invalid IDs and future research rejected")
		knowledge_check(H.learn_recipe_node(node_id) && H.learn_recipe_node(node_id) && H.known_recipe_nodes.len == 1, "learning is idempotent")
		knowledge_check(crafting_node_allowed(H, node_id) && !crafting_node_allowed(H, future_id), "learned node crafts only under research ceiling")
		var/obj/item/weapon/book/node_book/B = create_node_book(locate(2,2,1), node_id)
		knowledge_check(B && B.node_id == node_id && !create_node_book(H, "missing"), "book creation validates text IDs")
		B.attack_self(H)
		knowledge_check(!QDELETED(B) && H.known_recipe_nodes.len == 1, "repeated reading preserves reusable book")
		var/mob/living/human/knowledge_fixture/fresh = new(locate(3,2,1))
		knowledge_check(!fresh.knows_recipe_node(node_id), "fresh body does not inherit another body's knowledge")
		check_manual_menu_views(H, fresh, node_id)
		H.forget_recipe_knowledge()
		H.stat = DEAD
		knowledge_check(!H.knows_recipe_node(node_id) && !H.known_recipe_nodes.len && !H.migrate_recipe_knowledge(), "death clears knowledge and closes migration")
		H.stat = CONSCIOUS
		knowledge_check(H.learn_recipe_node(node_id), "revived body can relearn from reusable book")
		map.recipe_books = FALSE
		var/mob/living/human/knowledge_fixture/legacy = new(locate(4,2,1))
		knowledge_check(!legacy.recipe_knowledge_initialized && !legacy.can_learn_recipe_node(node_id), "disabled mode preserves legacy migration eligibility")
		persistence_save_in_progress = TRUE
		knowledge_check(!map.activate_recipe_books() && !map.recipe_books && !legacy.recipe_knowledge_initialized, "activation refuses an in-progress save or load")
		persistence_save_in_progress = FALSE
		map.activate_recipe_books()
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
		var/obj/item/weapon/book/node_compendium/compendium = new(locate(6,2,1))
		compendium.node_ids = list("basic_tools", "primitive_construction")
		var/obj/structure/recipe_book_cache/cache = new(locate(7,2,1))
		cache.restock_remaining = 12345
		var/obj/structure/research_bench/knowledge_fixture/bench = new(locate(6,2,1))
		bench.faction = "Fixture"
		knowledge_check(map.complete_node("Fixture", future_id), "research transitions to completed")
		var/book_count = 0
		for (var/obj/item/weapon/book/node_book/copy in locate(6,2,1))
			if (copy.node_id == future_id) book_count++
		knowledge_check(book_count == 1 && !map.complete_node("Fixture", future_id), "one first manual and duplicate completion refused")
		H.civilization = "Fixture"
		knowledge_check(H.learn_recipe_node(future_id) && crafting_node_allowed(H, future_id), "completed faction research allows learning and crafting")
		map.ordinal_age = 6
		H.civilization = "Other faction"
		knowledge_check(H.knows_recipe_node(future_id) && !crafting_node_allowed(H, future_id), "changing factions retains knowledge but not another faction's ceiling")
		H.civilization = "none"
		check_book_research()
		knowledge_check(map_storage.Save_World() && map_storage.validate_world_save(), "native body and book durable save")
		map_storage.ClearMap()
		knowledge_check(map_storage.Load_World(), "native durable reload")
		H = locate(/mob/living/human/knowledge_fixture) in locate(2,2,1)
		fresh = locate(/mob/living/human/knowledge_fixture) in locate(3,2,1)
		B = locate(/obj/item/weapon/book/node_book) in locate(2,2,1)
		knowledge_check(H && H.knows_recipe_node(node_id) && H.recipe_knowledge_initialized, "learned body knowledge survives actual reload")
		knowledge_check(fresh && fresh.recipe_knowledge_initialized && !fresh.known_recipe_nodes.len, "empty fresh saved body remains empty after reload")
		knowledge_check(B && B.node_id == node_id, "book text node id survives reload")
		compendium = locate(/obj/item/weapon/book/node_compendium) in locate(6,2,1)
		cache = locate(/obj/structure/recipe_book_cache) in locate(7,2,1)
		knowledge_check(compendium && compendium.node_ids.len == 2 && istext(compendium.node_ids[1]) && ("basic_tools" in compendium.node_ids), "compendium text IDs survive production world reload")
		knowledge_check(cache && cache.restock_remaining == 12345, "cache cooldown survives production world reload")
		knowledge_check(!("recipe_books" in durable_metadata_map_schema()), "opt-in configuration does not expand durable map metadata")
		var/obj/structure/research_bench/knowledge_fixture/open_bench = locate() in locate(7,6,1)
		var/obj/item/weapon/book/journal = open_bench ? locate(/obj/item/weapon/book) in open_bench.contents : null
		knowledge_check(journal && journal.has_research_chapter("iron_tools") && journal.dat == "Day one.", "book on the bench keeps its chapter and writing across reload")
		var/mob/living/human/knowledge_fixture/reloaded_scholar = locate() in locate(7,7,1)
		knowledge_check(reloaded_scholar && reloaded_scholar.scholar_level("engineering") >= 74, "scholarship survives reload")
		var/obj/item/weapon/book/reloaded_diary
		for (var/obj/item/weapon/book/candidate in locate(6,6,1))
			if (candidate.has_research_chapter("basic_tools"))
				reloaded_diary = candidate
		knowledge_check(reloaded_diary && reloaded_diary.page_list().len == 2 && findtext(reloaded_diary.dat, "New entry.") && !reloaded_diary.page_busy, "pages and written chapters survive reload, without a busy lock")
	catch (var/exception/e)
		knowledge_failures++
		world.log << "FAIL: exception [e] [e.file]:[e.line]"
	var/list/params = params2list(world.params)
	text2file(json_encode(list("failures" = knowledge_failures, "commit" = params["tested_commit"], "byond_build" = world.byond_build)), "result.json")
	shutdown()

// Call the production action directly, as a saved/stale craft href would.
/obj/item/stack/manual_menu_fixture/New()
	amount = 10

/proc/check_manual_menu_views(mob/living/human/known, mob/living/human/unknown, node_id)
	var/list/recipe = list("research_status" = "gated", "research_nodes" = list(node_id))
	var/snapshot = json_encode(recipe)
	knowledge_check(!crafting_atlas_tgui_presenter.manual_hint(known, recipe), "known reader has no manual hint")
	knowledge_check(crafting_atlas_tgui_presenter.manual_hint(unknown, recipe), "unknown reader sees manual hint")
	knowledge_check(!crafting_atlas_tgui_presenter.manual_hint(known, recipe), "alternating readers cannot poison hints")
	knowledge_check(json_encode(recipe) == snapshot, "manual hints do not mutate catalog records")
	recipe["research_status"] = "excluded"
	knowledge_check(!crafting_atlas_tgui_presenter.manual_hint(unknown, recipe), "reaction and acquisition exclusions ignore output gate")
	recipe["research_status"] = "basic"
	knowledge_check(!crafting_atlas_tgui_presenter.manual_hint(unknown, recipe), "basic route has no manual hint")
	recipe["research_status"] = "gated"
	recipe["manual_free"] = TRUE
	knowledge_check(!crafting_atlas_tgui_presenter.manual_hint(unknown, recipe), "research essential route has no manual hint")
	recipe -= "manual_free"
	map.recipe_books = FALSE
	knowledge_check(!crafting_node_manual_hint(unknown, node_id), "disabled maps have no personal hint")
	map.recipe_books = TRUE
	var/output_type = /obj/item/weapon/material/pickaxe
	knowledge_check(!crafting_recipe_allowed(unknown, "[output_type]"), "unknown direct craft is gated")
	var/obj/item/stack/manual_menu_fixture/materials = new(unknown.loc)
	var/datum/stack_recipe/stale = new("stale fixture", output_type, 1)
	var/before = unknown.loc.contents.len
	materials.produce_recipe(stale, 1, unknown)
	knowledge_check(materials.amount == 10 && unknown.loc.contents.len == before, "stale direct recipe consumes nothing and creates nothing")
	qdel(materials)

/mob/living/human/knowledge_fixture/research_presence()
	return TRUE

// Book research (Val, 2026-11-10): an unowned bench writes research into the
// book placed on it, and nobody learns a node until they study the chapter.
/proc/check_book_research()
	map.book_research = TRUE
	var/mob/living/human/knowledge_fixture/scholar = new(locate(7,7,1))
	scholar.civilization = "none"
	var/obj/structure/research_bench/knowledge_fixture/bench = new(locate(7,6,1))
	bench.tier = 1
	var/obj/item/weapon/book/journal = new(locate(7,7,1))
	journal.dat = "Day one."
	bench.book_place(journal, scholar)
	knowledge_check(bench.placed_book() == journal && !bench.faction, "any book can be placed on an unowned bench")
	bench.try_assign_node(scholar, "iron_tools")
	knowledge_check(bench.assigned_node == "iron_tools", "a factionless character can set the subject")
	bench.analysis_tick()
	knowledge_check(!journal.research_ticks("iron_tools"), "no progress without someone who knows the groundwork")
	knowledge_check(scholar.can_learn_recipe_node("basic_tools") && scholar.learn_recipe_node("basic_tools"), "a root node can be learned without faction research")
	bench.analysis_tick()
	knowledge_check(!journal.research_ticks("iron_tools") && node_discipline("iron_tools") == "engineering" && node_scholar_requirement("iron_tools") == 24, "no progress without the discipline's skill")
	var/list/open_disciplines = list()
	for (var/node_id in research_nodes)
		if (!node_scholar_requirement(node_id))
			open_disciplines |= node_discipline(node_id)
	knowledge_check(open_disciplines.len == scholar_disciplines.len && !node_scholar_requirement("early_cells"), "every discipline, Natural Science included, has nodes a beginner can research")
	scholar.scholarship = list("engineering" = 24, "mathematics" = 12)
	bench.analysis_tick()
	knowledge_check(journal.research_ticks("iron_tools") == bench.base_tick_rate, "research is written into the book")
	knowledge_check(scholar.scholar_level("engineering") > 24 && scholar.scholar_level("mathematics") > 12, "researching raises the discipline and mathematics")
	scholar.scholarship["engineering"] = 74
	knowledge_check(scholar.scholar_research_rate("iron_tools") == 2 && scholar.scholar_research_rate("basic_tools") == 2, "skill well above the requirement doubles the pace")
	var/before = scholar.scholar_level("engineering")
	scholar.gain_scholarship("basic_tools", 1)
	knowledge_check(scholar.scholar_level("engineering") - before < 0.2, "old low-tier work teaches little")
	var/list/cleaned = clean_scholarship(list("engineering" = 150, "bogus" = 5, "medicine" = "x"))
	knowledge_check(cleaned.len == 1 && cleaned["engineering"] == 100, "restored scholarship is validated and capped")
	knowledge_check(research_node_known(scholar, "basic_tools") && !research_node_known(scholar, "field_defenses"), "older research checks follow personal knowledge")
	var/datum/research_node/N = get_research_node("iron_tools")
	knowledge_check(journal.add_research_work("iron_tools", N.cost_ticks) && journal.has_research_chapter("iron_tools") && !journal.research_ticks("iron_tools"), "finished work becomes a chapter")
	knowledge_check(!scholar.knows_recipe_node("iron_tools") && !crafting_node_allowed(scholar, "iron_tools"), "finishing research teaches no one")
	var/mob/living/human/knowledge_fixture/novice = new(locate(6,7,1))
	knowledge_check(!novice.can_learn_recipe_node("iron_tools") && scholar.can_learn_recipe_node("iron_tools"), "studying a chapter needs its groundwork")
	knowledge_check(scholar.learn_recipe_node("iron_tools") && crafting_node_allowed(scholar, "iron_tools"), "studying the chapter allows crafting")
	knowledge_check(!crafting_node_allowed(novice, "basic_tools") && crafting_recipe_allowed(novice, "/obj/structure/research_bench"), "no era grants, but anyone can build a bench")
	check_book_pages(scholar, novice, journal)
	var/obj/item/weapon/book/other = new(locate(7,7,1))
	bench.book_place(other, scholar)
	var/obj/item/weapon/book/third = new(locate(7,7,1))
	bench.book_place(third, scholar)
	knowledge_check(bench.placed_books().len == 2 && bench.placed_book() == journal && third.loc != bench, "up to two books per bench; research goes into the first")
	var/obj/item/weapon/paper/copy_sheet = new(locate(7,7,1))
	novice.stats["stamina"][1] = 100
	knowledge_check(!novice.knows_recipe_node("iron_tools") && bench.copy_chapter_commit(novice, journal, other, "iron_tools", copy_sheet) && other.has_research_chapter("iron_tools") && QDELETED(copy_sheet), "a scribe copies a chapter between the two books without knowing it")
	var/obj/item/weapon/paper/again = new(locate(7,7,1))
	knowledge_check(!bench.copy_chapter_commit(novice, journal, other, "iron_tools", again), "a chapter the other book has can't be copied again")
	bench.studied_samples = list(/obj/item/weapon/paper)
	bench.book_swap(scholar)
	knowledge_check(bench.placed_book() == other && !bench.studied_samples, "the other book can become the research book, with no sample credit carried over")
	bench.book_swap(scholar)
	knowledge_check(bench.placed_book() == journal, "swapping back restores the first book")
	bench.book_take(scholar, 2)
	knowledge_check(other.loc != bench && bench.placed_books().len == 1, "a chosen book can be taken off the bench")
	qdel(other)
	qdel(third)
	qdel(again)
	check_book_clock(journal)
	check_book_fabricator()
	check_scholarship_travel(scholar)
	map.book_research = FALSE

// Books from memory (Val, 2026-11-10): pages, chapters written from memory,
// ripping pages out and putting them back, parchment and writing supplies.
/proc/check_book_pages(mob/living/human/scholar, mob/living/human/novice, obj/item/weapon/book/journal)
	knowledge_check(crafting_recipe_allowed(novice, "/obj/item/weapon/pen/pencil") && crafting_recipe_allowed(novice, "/obj/item/weapon/paper") && crafting_recipe_allowed(novice, "/obj/item/weapon/book") && !crafting_recipe_allowed(novice, "/obj/item/weapon/pen"), "pencil, paper and blank book are free; the pen is not")
	var/obj/item/weapon/book/diary = new(locate(6,6,1))
	diary.dat = "Old entry."
	knowledge_check(diary.add_written_page("New entry.") && diary.page_list().len == 2 && findtext(diary.dat, "Old entry.") && findtext(diary.dat, "New entry."), "a book is written as pages, older text first")
	var/obj/item/weapon/paper/torn = diary.tear_out_page(1, locate(6,6,1))
	knowledge_check(torn && torn.info == "Old entry." && diary.page_list().len == 1 && !findtext(diary.dat, "Old entry."), "a ripped-out page takes its writing with it")
	knowledge_check(bindable_loose_page(torn) && diary.bind_loose_page(torn) && diary.page_list().len == 2, "a loose page can be bound back in")
	qdel(torn)
	var/obj/item/weapon/paper/stamped_doc = new(locate(6,6,1))
	stamped_doc.info = "Decree."
	stamped_doc.stamps = "<br><i>Stamped.</i>"
	var/obj/item/weapon/paper/recorded_doc = new(locate(6,6,1))
	recorded_doc.info = "Ledger."
	recorded_doc.document_record = list("sections" = list())
	knowledge_check(!bindable_loose_page(stamped_doc) && !bindable_loose_page(recorded_doc), "stamped sheets and documents can't be bound")
	knowledge_check(!diary.reinsert_page(scholar, stamped_doc) && !QDELETED(stamped_doc) && stamped_doc.stamps && diary.page_list().len == 2, "refusing to bind a document keeps it intact")
	qdel(stamped_doc)
	qdel(recorded_doc)
	var/obj/item/weapon/paper/parchment/sheet = new(locate(6,6,1))
	knowledge_check(blank_writing_sheet(sheet), "parchment works as a blank sheet")
	scholar.stats["stamina"][1] = 100
	knowledge_check(diary.commit_written_chapter(scholar, "basic_tools", sheet) && diary.has_research_chapter("basic_tools") && QDELETED(sheet) && scholar.stats["stamina"][1] == 100 - BOOK_WRITE_STAMINA(0), "writing a known node uses a sheet and stamina")
	var/obj/item/weapon/paper/spare = new(locate(6,6,1))
	knowledge_check(!diary.commit_written_chapter(novice, "basic_tools", spare) && !diary.commit_written_chapter(scholar, "iron_smithing", spare), "only known, unwritten nodes can be written")
	scholar.stats["stamina"][1] = 1
	var/obj/item/weapon/book/tired = new(locate(6,6,1))
	knowledge_check(!tired.commit_written_chapter(scholar, "basic_tools", spare) && !QDELETED(spare), "too tired to write")
	scholar.stats["stamina"][1] = 100
	var/obj/item/weapon/paper/research_page/page = journal.tear_out_page("iron_tools", locate(6,6,1))
	knowledge_check(istype(page) && page.node_id == "iron_tools" && !journal.has_research_chapter("iron_tools") && page.holds_research_chapter("iron_tools"), "a ripped-out chapter becomes a studyable page")
	knowledge_check(journal.bind_loose_page(page) && journal.has_research_chapter("iron_tools"), "a torn chapter can be bound back in")
	qdel(page)
	qdel(spare)
	qdel(tired)
	diary.page_busy = TRUE
	knowledge_check(!("page_busy" in diary.get_saved_vars()), "a book's busy lock is never saved")

// No clock (Val, 2026-11-10): book research starts at 5000 B.C. with no WW2
// floor and no auto-research; only a finished capstone moves the era.
/proc/check_book_clock(obj/item/weapon/book/journal)
	var/old_age = map.age
	var/old_ordinal = map.ordinal_age
	var/old_auto = map.autoresearch
	var/list/old_flags = list()
	for (var/i = 1, i <= 9, i++)
		old_flags += map.vars["age[i]_done"]
	map.age = "5000 B.C."
	map.ordinal_age = 0
	map.autoresearch = TRUE
	map.apply_persistence_age_floor()
	knowledge_check(map.age == "5000 B.C." && map.ordinal_age == 0 && !map.autoresearch, "book research has no 1943 floor and no auto-research")
	var/datum/research_node/cap = get_research_node("bronze_working")
	journal.add_research_work("bronze_working", cap.cost_ticks)
	knowledge_check(map.ordinal_age == 0 && !journal.has_research_chapter("bronze_working"), "a capstone needs its prototype before it is finished")
	journal.add_research_work("bronze_working", 0, TRUE)
	knowledge_check(journal.has_research_chapter("bronze_working") && map.ordinal_age == 1 && map.age == "313 B.C.", "finishing a capstone moves the era")
	map.age = "1969"
	map.ordinal_age = 7
	map.age1_done = TRUE
	map.autoresearch = TRUE
	knowledge_check(map.start_book_research_world() && map.age == "5000 B.C." && !map.ordinal_age && !map.age1_done && !map.autoresearch, "a fresh book research world starts in the Stone Age")
	var/list/stone = stone_age_node_ids()
	var/stone_ok = stone.len >= 5 && ("basic_tools" in stone)
	for (var/node_id in stone)
		var/datum/research_node/SN = get_research_node(node_id)
		if (SN.era_tier > 0)
			stone_ok = FALSE
	knowledge_check(stone_ok, "the Stone Age set holds only era-0 nodes")
	var/mob/living/human/knowledge_fixture/founder = new(locate(5,5,1))
	var/obj/item/weapon/book/master = founder.receive_founding_books()
	knowledge_check(master && master.loc == founder && master.research_chapter_list().len == stone.len && (locate(/obj/item/weapon/pen/pencil) in founder.contents), "a founder gets the Stone Age master book and a pencil")
	knowledge_check(!founder.knows_recipe_node("basic_tools") && founder.can_learn_recipe_node("basic_tools"), "the master book's chapters still have to be studied")
	map.age = old_age
	map.ordinal_age = old_ordinal
	map.autoresearch = old_auto
	for (var/i = 1, i <= 9, i++)
		map.vars["age[i]_done"] = old_flags[i]

// With book research a fabricator lists what its user knows, even when the
// faction never researched it (review finding, 2026-11-10).
/proc/check_book_fabricator()
	var/datum/factory_recipe/R = null
	var/list/recipes = factory_get_recipes()
	for (var/name in recipes)
		var/datum/factory_recipe/candidate = recipes[name]
		if (candidate.tier == 1 && valid_recipe_node_id(candidate.node))
			R = candidate
			break
	var/obj/structure/factory_fabricator/F = new(locate(2,6,1))
	F.tier = 3
	var/mob/living/human/knowledge_fixture/worker = new(locate(2,7,1))
	worker.civilization = "none"
	var/before = R && !(R.name in F.available_recipes("none", worker))
	worker.known_recipe_nodes = list(R ? R.node : "basic_tools")
	knowledge_check(before && (R.name in F.available_recipes("none", worker)), "a fabricator lists recipes its user has learned")
	qdel(F)
	qdel(worker)

// Region travel carries scholarship (review finding, 2026-11-10).
/proc/check_scholarship_travel(mob/living/human/scholar)
	var/old_owner = scholar.persistence_owner_ckey
	scholar.persistence_owner_ckey = "fixturescholar"
	var/list/P = region_travel_decode(scholar.region_travel_payload(list()))
	scholar.persistence_owner_ckey = old_owner
	knowledge_check(P && P["v"] == 3 && region_travel_scholarship_valid(P["scholarship"]), "a scholar travels with version 3 and their scholarship")
	knowledge_check(P && P["scholarship"]["engineering"] == scholar.scholar_level("engineering") && P["scholarship"]["mathematics"] == scholar.scholar_level("mathematics"), "the payload carries each discipline's level")
	knowledge_check(!region_travel_scholarship_valid(list("bogus" = 5)) && !region_travel_scholarship_valid(list("engineering" = 500)) && !region_travel_scholarship_valid(list()), "travelling scholarship is validated")
	if (P)
		P["v"] = 2
		knowledge_check(!region_travel_decode(json_encode(P)), "an older payload version can't smuggle scholarship")
