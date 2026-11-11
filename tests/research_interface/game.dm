// Research bench and book window data and one-click actions, on production
// source. Client presence, light, physiology and action waits are isolated.
var/interface_failures = 0
var/interface_wait_result = TRUE
var/interface_wait_count = 0
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
/obj/map_metadata/interface_fixture
	recipe_books = TRUE
	book_research = TRUE
/obj/map_metadata/interface_fixture/New()
	return
/mob/living/human/interface_fixture/New()
	initialize_recipe_knowledge()
/mob/living/human/interface_fixture/incapacitated()
	return stat != CONSCIOUS
/mob/living/human/interface_fixture/restrained()
	return FALSE
/mob/living/human/interface_fixture/research_presence()
	return TRUE
/mob/living/human/interface_fixture/remove_from_mob(obj/O)
	if(l_hand == O) l_hand = null
	if(r_hand == O) r_hand = null
	O.loc = get_turf(src)
	return TRUE
/mob/living/human/interface_fixture/put_in_hands(obj/item/I)
	I.loc = src
	if(!l_hand) l_hand = I
	else if(!r_hand) r_hand = I
	return TRUE
/mob/living/human/interface_fixture/update_icons()
	return
/mob/living/human/interface_fixture/proc/hold(obj/item/I)
	if(l_hand == I || r_hand == I) return
	put_in_hands(I)
/mob/living/human/interface_fixture/proc/empty_hands()
	for(var/obj/item/I in list(l_hand, r_hand))
		remove_from_mob(I)
/obj/structure/research_bench/interface_fixture
	var/fixture_lit = TRUE
/obj/structure/research_bench/interface_fixture/research_lit()
	return fixture_lit
/proc/interface_wait(mob/living/human/H, delay, atom/target)
	interface_wait_count++
	return interface_wait_result
/proc/interface_check(condition, label)
	if(!condition) interface_failures++
	world.log << "[condition ? "PASS" : "FAIL:"] [label]"
/proc/interface_node(list/data, node_id)
	for(var/list/tree in data["trees"])
		for(var/list/layer in tree["layers"])
			for(var/list/node in layer["nodes"])
				if(node["id"] == node_id) return node
	return null
/proc/interface_row(list/rows, node_id)
	for(var/list/row in rows)
		if(row["id"] == node_id) return row
	return null
/proc/interface_check_named(list/rows, fragment)
	for(var/list/row in rows)
		if(findtext(row["label"], fragment)) return row
	return null
/world/Error(exception/e)
	interface_failures++
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
	map = new /obj/map_metadata/interface_fixture(locate(1,1,1))
	map.persistence = TRUE
	map.ordinal_age = 0
	build_research_tree()
	try
		// A root anyone can research on a new bench, something built on it, and
		// something that needs a better bench.
		var/root = null
		var/child = null
		var/far = null
		for(var/node_id in research_nodes)
			var/datum/research_node/N = research_nodes[node_id]
			if(!root && !N.prereqs.len && N.min_bench_tier == 0 && N.mode == RESEARCH_MODE_ANALYSIS && !node_scholar_requirement(node_id))
				root = node_id
		for(var/node_id in research_nodes)
			var/datum/research_node/N = research_nodes[node_id]
			if(!child && N.prereqs.len == 1 && N.prereqs[1] == root && N.min_bench_tier == 0 && N.mode == RESEARCH_MODE_ANALYSIS)
				child = node_id
			if(!far && N.min_bench_tier >= 2 && N.mode == RESEARCH_MODE_ANALYSIS)
				far = node_id
		interface_check(root && child && far && root != child, "the tree has a root, a follow-up and a high-tier subject ([root], [child], [far])")
		var/datum/research_node/RN = get_research_node(root)
		var/datum/research_node/CN = get_research_node(child)

		var/mob/living/human/interface_fixture/H = new(locate(3,2,1))
		H.real_name = "Mira"
		H.name = "Mira"
		var/obj/structure/research_bench/interface_fixture/bench = new(locate(3,3,1))
		var/obj/item/weapon/pen/pencil/pencil = new(H)
		var/obj/item/weapon/book/journal = new(H)
		journal.name = "journal"
		var/obj/item/weapon/book/copybook = new(H)
		copybook.name = "copybook"

		// --- An empty bench ---
		var/list/data = bench.bench_ui_data(H)
		interface_check(data && data["book_mode"] && length(json_encode(data)) > 1000, "bench data is produced and encodes")
		var/list/node = interface_node(data, root)
		interface_check(node && node["state"] == "ready" && node["state_label"] == "Can be researched" && !node["assignable"], "a root reads as researchable, but nothing can be assigned without a book")
		node = interface_node(data, child)
		var/list/ground = node["groundwork"]
		interface_check(node["state"] == "locked" && ground.len == 1 && ground[1]["id"] == root && !ground[1]["known"], "a follow-up is locked and names the groundwork the viewer lacks")
		node = interface_node(data, far)
		interface_check(interface_check_named(node["research_needs"], "Bench tier") && !interface_check_named(node["research_needs"], "Bench tier")["ok"], "a high-tier subject lists the bench tier as not met")
		var/list/viewer = data["viewer"]
		interface_check(isnull(viewer["tool"]) && viewer["sheets"] == 0, "the viewer holds no tool or sheets yet")

		// --- Research with progress, pace and checklist ---
		H.hold(journal)
		bench.book_place(journal, H)
		interface_check(journal.loc == bench, "the journal is on the bench")
		bench.book_try_assign_node(H, root)
		interface_check(bench.assigned_node == root, "the root subject is assigned")
		var/list/assigned = bench.book_assigned_ui(H)
		interface_check(assigned["id"] == root && !assigned["working"] && isnull(assigned["eta_minutes"]) && interface_check_named(assigned["checks"], "writing slate") && !interface_check_named(assigned["checks"], "writing slate")["ok"], "with no tool in hand nobody is working, and the checklist says why")
		H.hold(pencil)
		bench.book_analysis_tick()
		assigned = bench.book_assigned_ui(H)
		interface_check(assigned["working"] && assigned["ticks"] > 0 && assigned["eta_minutes"] > 0 && assigned["pace"] == 0.5 && interface_check_named(assigned["checks"], "You are working on it"), "with a pencil the work goes on at half pace without supplies, with time left shown")
		bench.fixture_lit = FALSE
		assigned = bench.book_assigned_ui(H)
		interface_check(!assigned["working"] && !interface_check_named(assigned["checks"], "Light")["ok"], "a dark bench is reported as not working")
		bench.fixture_lit = TRUE
		data = bench.bench_ui_data(H)
		node = interface_node(data, root)
		interface_check(node["state"] == "progress" && findtext(node["state_label"], "% written") && data["books"][1]["unfinished"][1]["id"] == root, "the subject shows as in progress on the tree and in the book")
		interface_check(data["viewer"]["tool"] == pencil.name && data["assigned"]["id"] == root, "the viewer's tool and the current subject are in the data")

		// --- Finished chapter: study with one click ---
		journal.add_research_work(root, RN.cost_ticks)
		interface_check(journal.has_research_chapter(root), "the chapter is finished")
		data = bench.bench_ui_data(H)
		node = interface_node(data, root)
		interface_check(node["state"] == "study" && node["can_study"] && node["holder"] == 1 && node["study_minutes"] > 0 && !node["can_copy"], "the finished chapter is ready to study from the bench")
		interface_check(data["assigned"]["done"] && data["assigned"]["can_study"], "the finished subject offers studying")
		node = interface_node(data, child)
		var/skill_needed = node_scholar_requirement(child)
		interface_check(!skill_needed || (node["research_needs"][1]["ok"] == 0 && findtext(node["research_needs"][1]["label"], "(you have 0)")), "a subject past the scholar's skill lists the level needed and the level held")
		H.scholarship = list("engineering" = 30, "mathematics" = 30, "natural_science" = 30, "agriculture" = 30, "medicine" = 30, "military" = 30)
		interface_wait_result = FALSE
		interface_check(!bench.book_study_node(H, root) && !H.knows_recipe_node(root), "an interrupted study teaches nothing")
		interface_wait_result = TRUE
		interface_check(bench.book_study_node(H, root) && H.knows_recipe_node(root), "studying from the bench teaches the chapter")
		interface_check(!bench.book_study_node(H, child), "a chapter no book holds can't be studied")
		data = bench.bench_ui_data(H)
		interface_check(interface_node(data, root)["state"] == "known" && interface_node(data, child)["state"] == "ready" && interface_node(data, child)["groundwork"][1]["known"], "the chapter is known and its follow-up opens")

		// --- Queue ---
		bench.book_queue_node(H, far)
		bench.book_queue_node(H, child)
		interface_check(bench.assigned_node == child && bench.queue_list().len == 1 && bench.queue_list()[1] == far, "the queue starts the first subject this bench can work on and keeps the rest waiting")
		bench.book_queue_node(H, far)
		bench.book_queue_node(H, child)
		interface_check(bench.queue_list().len == 1, "a subject can't be queued twice or while it is being researched")
		data = bench.bench_ui_data(H)
		interface_check(interface_node(data, far)["queue_pos"] == 1 && !interface_node(data, far)["queueable"] && data["queue"][1]["id"] == far, "the queue position is shown on the subject")
		bench.book_unqueue_node(H, far)
		interface_check(!bench.queue_list().len, "a subject can be taken off the queue")
		bench.book_stop_research(H)
		interface_check(isnull(bench.assigned_node), "research can be stopped")
		for(var/node_id in research_nodes)
			bench.book_queue_node(H, node_id)
		interface_check(bench.queue_list().len <= 12, "the queue is capped")
		bench.set_queue(null)
		bench.book_stop_research(H)
		bench.book_queue_node(H, root)
		interface_check(!bench.queue_list().len && isnull(bench.assigned_node), "a chapter the research book already holds is not queued")

		// --- Two books: copy one chapter, then all ---
		H.empty_hands()
		H.hold(copybook)
		bench.book_place(copybook, H)
		H.hold(pencil)
		data = bench.bench_ui_data(H)
		node = interface_node(data, root)
		interface_check(node["can_copy"] && node["can_write"] && data["books"][1]["copy_missing"] == 1 && data["books"][1]["chapters"][1]["can_copy"] && data["books"][1]["other_name"] == "copybook" && data["can_copy"], "with two books the chapter can be copied or written")
		interface_check(!bench.book_copy_node(H, root) && !copybook.has_research_chapter(root), "copying needs a blank sheet")
		var/obj/item/weapon/paper/sheet = new(H)
		interface_check(H.blank_sheet_count() == 1 && H.ready_blank_sheet() == sheet && H.r_hand == sheet, "a blank sheet carried on the scholar comes to their free hand")
		var/stamina = H.stats["stamina"][1]
		interface_wait_result = FALSE
		interface_check(!bench.book_copy_node(H, root) && sheet.loc == H && !copybook.page_busy, "an interrupted copy costs nothing and frees the book")
		interface_wait_result = TRUE
		interface_check(bench.book_copy_node(H, root) && copybook.has_research_chapter(root) && H.stats["stamina"][1] < stamina && (!sheet || sheet.gcDestroyed || !sheet.loc), "one click copies the chapter for a sheet and stamina")
		interface_check(!bench.book_copy_node(H, root), "a chapter both books hold can't be copied again")
		var/list/extra = list()
		for(var/node_id in research_nodes)
			if(extra.len < 3 && node_id != root && get_research_node(node_id).era_tier == 0)
				extra += node_id
				journal.add_research_chapter(node_id)
		H.stats["stamina"][1] = 100
		new /obj/item/weapon/paper(H)
		new /obj/item/weapon/paper(H)
		interface_check(bench.book_copy_all(H, 1) == 2 && H.blank_sheet_count() == 0, "copy all goes on until the sheets run out")
		new /obj/item/weapon/paper(H)
		H.stats["stamina"][1] = 100
		interface_check(bench.book_copy_all(H, 1) == 1 && length(copybook.research_chapter_list()) == 4, "copy all finishes once more sheets are brought")
		interface_check(bench.book_copy_all(H, 1) == 0 && bench.book_copy_all(H, 3) == 0, "copy all does nothing when nothing is missing or the book is wrong")

		// --- Writing from memory at the bench ---
		interface_check(!bench.book_write_node(H, child), "an unknown chapter can't be written")
		interface_check(!bench.book_write_node(H, root), "a chapter both books hold is not written again")
		bench.book_take(H, 2)
		H.empty_hands()
		var/obj/item/weapon/book/blank = new(H)
		blank.name = "blank book"
		H.hold(blank)
		bench.book_place(blank, H)
		H.hold(pencil)
		new /obj/item/weapon/paper(H)
		H.stats["stamina"][1] = 100
		interface_check(bench.book_write_node(H, root) && blank.has_research_chapter(root) && H.blank_sheet_count() == 0, "one click writes a known chapter into the book that lacks it")

		// --- The book window ---
		bench.book_take(H, 2)
		H.empty_hands()
		blank.loc = get_turf(H)
		blank.add_research_work(child, 10)
		H.learn_recipe_node(extra[1])
		var/list/window = blank.research_book_ui_data(H)
		interface_check(length(json_encode(window)) > 100 && window["name"] == "blank book" && !window["held"], "book window data is produced and encodes")
		var/list/chapter = interface_row(window["chapters"], root)
		interface_check(chapter && chapter["state"] == "known" && chapter["study_minutes"] > 0 && islist(chapter["recipe_names"]), "the window lists the chapter as known with what it teaches")
		var/list/unfinished = interface_row(window["unfinished"], child)
		interface_check(unfinished && unfinished["ticks"] == 10 && unfinished["cost"] == CN.cost_ticks, "the window lists unfinished research with its progress")
		var/list/writable = interface_row(window["writable"], extra[1])
		interface_check(writable && writable["write_minutes"] > 0 && writable["stamina"] > 0 && !interface_row(window["writable"], root), "the window offers known chapters the book lacks for writing")
		H.hold(pencil)
		new /obj/item/weapon/paper(H)
		interface_check(blank.write_research_chapter(H, pencil, extra[1]) && blank.has_research_chapter(extra[1]), "a chosen chapter is written without the menu")
		interface_check(!blank.write_research_chapter(H, pencil, child), "a chosen chapter the writer doesn't know is refused")
		var/mob/living/human/interface_fixture/novice = new(locate(4,2,1))
		window = journal.research_book_ui_data(novice)
		interface_check(interface_row(window["chapters"], root)["state"] == "study" && !length(window["writable"]), "a newcomer sees a root chapter as ready to study and has nothing to write")
		copybook.add_research_chapter(child)
		window = copybook.research_book_ui_data(novice)
		chapter = interface_row(window["chapters"], child)
		interface_check(chapter["state"] == "locked" && !chapter["groundwork"][1]["known"], "a newcomer sees a follow-up chapter as needing groundwork")

		// Screen data for cloud previews of the two windows.
		bench.book_take(H, 1)
		H.empty_hands()
		journal.research_chapters = ""
		for(var/node_id in list(root) + extra)
			journal.add_research_chapter(node_id)
		H.hold(journal)
		bench.book_place(journal, H)
		H.hold(copybook)
		bench.book_place(copybook, H)
		H.hold(pencil)
		new /obj/item/weapon/paper(H)
		new /obj/item/weapon/paper(H)
		bench.book_try_assign_node(H, child)
		journal.add_research_work(child, round(CN.cost_ticks * 0.4))
		bench.book_queue_node(H, far)
		text2file(json_encode(bench.bench_ui_data(H)), "bench.json")
		text2file(json_encode(journal.research_book_ui_data(novice)), "book.json")
	catch(var/exception/e)
		interface_failures++
		world.log << "FAIL: exception [e] [e.file]:[e.line]"
	var/list/params = islist(world.params) ? world.params : params2list(world.params)
	text2file(json_encode(list("failures" = interface_failures, "commit" = params["tested_commit"], "byond_build" = world.byond_build)), "result.json")
	shutdown()
