// Native familiarity probe, included by tests/ecology_spawning/run_linux.py,
// never by the game DME. It drives code/modules/research_tree/familiarity.dm.
/world
	hub = ""
	hub_password = ""
	maxx = 20
	maxy = 20
	maxz = 1
	turf = /turf/floor/plating
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/client/New()
	del(src)
	return
/obj/map_metadata/familiar_probe/New()
	map = src
	persistence = TRUE
	recipe_books = TRUE
/mob/living/human/familiar_tester/New()
	return
/mob/living/human/familiar_tester/adaptStat(stat, amount)
	return
var/familiar_failures = 0
var/familiar_runtime_error = FALSE
/proc/familiar_check(condition, label)
	if (!condition)
		familiar_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	familiar_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/familiar_probe
		build_research_tree()
		familiar_cap_checks()
		familiar_use_checks()
		familiar_limit_checks()
	catch(var/exception/e)
		familiar_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = familiar_failures, "runtime_error" = familiar_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/familiar_tester()
	var/mob/living/human/H = new /mob/living/human/familiar_tester(locate(5, 5, 1))
	H.real_name = "Tester"
	H.stat = CONSCIOUS
	return H

// A subject of the given era with at least `kinds` plain item kinds, and those kinds.
/proc/familiar_subject(tier, kinds)
	get_node_recipe_paths(null)
	for (var/id in recipe_paths_by_node)
		var/datum/research_node/N = get_research_node(id)
		if (!N || N.era_tier != tier || N.mode == RESEARCH_MODE_BOOK || research_node_dormant(N))
			continue
		var/list/found = list()
		for (var/path in recipe_paths_by_node[id])
			if (!ispath(path, /obj/item) || ispath(path, /obj/item/stack))
				continue
			var/obj/item/I = new path(locate(10, 10, 1))
			if (!QDELETED(I) && familiarity_node_of(I) == id)
				found += I
			if (found.len >= kinds)
				return list(id, found)
	return null

/proc/familiar_cap_checks()
	var/datum/research_node/stone = new
	stone.era_tier = 0
	var/datum/research_node/industrial = new
	industrial.era_tier = 4
	var/datum/research_node/digital = new
	digital.era_tier = 9
	familiar_check(familiarity_cap(stone) == 0.5, "familiarity can teach half of a Stone Age subject")
	familiar_check(abs(familiarity_cap(industrial) - 0.3) < 0.001, "and less of a later one (Industrial 30%)")
	familiar_check(abs(familiarity_cap(digital) - 0.05) < 0.001, "and only 5% of the newest")
	var/below_one = TRUE
	for (var/tier in 0 to 12)
		var/datum/research_node/N = new
		N.era_tier = tier
		if (familiarity_cap(N) >= 1 || familiarity_cap(N) < 0.05)
			below_one = FALSE
	familiar_check(below_one, "no era lets familiarity teach a whole subject")

/proc/familiar_use_checks()
	map.ordinal_age = 0
	var/list/pick = familiar_subject(0, 3)
	familiar_check(islist(pick), "a Stone Age subject with three kinds of things exists")
	if (!pick)
		return
	var/node_id = pick[1]
	var/list/things = pick[2]
	var/mob/living/human/H = familiar_tester()
	H.known_recipe_nodes = list()
	var/obj/item/first = things[1]
	familiar_check(H.note_familiar_use(first) == 0.05 && H.study_fraction(node_id) == 0.05, "the first use of a kind teaches 5%")
	familiar_check(H.note_familiar_use(first) == 0.01, "the next use teaches 1%")
	familiar_check(!H.note_familiar_use(first), "using it again straight away teaches nothing")
	H.familiar_last_use[node_id] = -1000000
	familiar_check(H.note_familiar_use(first) == 0.01, "after a pause it teaches 1% again")
	var/obj/item/second = things[2]
	familiar_check(abs(H.note_familiar_sight(second) - 0.02) < 0.001, "noticing a new kind nearby teaches 2%")
	familiar_check(!H.note_familiar_sight(second), "noticing the same kind again teaches nothing")
	// Reading and watching share the same progress.
	familiar_check(abs(H.familiarity_value(node_id) - H.study_fraction(node_id)) < 0.001, "familiarity adds to the same study progress")
	// A known subject, the dead and other worlds learn nothing.
	var/mob/living/human/knower = familiar_tester()
	knower.known_recipe_nodes = list(node_id)
	familiar_check(!knower.note_familiar_use(things[3]), "nothing more is learned of a known subject")
	var/mob/living/human/corpse = familiar_tester()
	corpse.stat = DEAD
	familiar_check(!corpse.note_familiar_use(things[3]), "the dead learn nothing")
	map.book_research = FALSE
	var/mob/living/human/elsewhere = familiar_tester()
	familiar_check(!elsewhere.note_familiar_use(things[3]), "nothing is learned off a book-research world")
	map.book_research = TRUE

/proc/familiar_limit_checks()
	var/list/pick = familiar_subject(0, 3)
	if (!pick)
		return
	var/node_id = pick[1]
	var/obj/item/thing = pick[2][1]
	var/datum/research_node/N = get_research_node(node_id)
	var/mob/living/human/H = familiar_tester()
	H.known_recipe_nodes = list()
	// One day: at most 10% however much it is used.
	H.familiar_last_use = list()
	H.note_familiar_use(thing)
	for (var/i in 1 to 50)
		H.familiar_last_use[node_id] = -1000000
		H.note_familiar_use(thing)
	familiar_check(abs(H.study_fraction(node_id) - 0.1) < 0.001, "familiarity adds at most 10% of a subject a day")
	// Day after day it stops at its cap and never finishes the subject.
	for (var/day in 1 to 30)
		H.familiarity["day"] = -1
		for (var/i in 1 to 20)
			H.familiar_last_use[node_id] = -1000000
			H.note_familiar_use(thing)
	familiar_check(abs(H.familiarity_value(node_id) - familiarity_cap(N)) < 0.001 && abs(H.study_fraction(node_id) - familiarity_cap(N)) < 0.001, "familiarity alone stops at its cap ([H.study_percent(node_id)]%)")
	familiar_check(!H.knows_recipe_node(node_id), "familiarity alone never teaches the subject")
	// Combined with reading it can fill up to the last step, which it never takes.
	var/mob/living/human/reader = familiar_tester()
	reader.known_recipe_nodes = list()
	reader.familiar_last_use = list()
	reader.note_study_progress(node_id, 0.97)
	reader.note_familiar_use(thing)
	familiar_check(abs(reader.study_fraction(node_id) - 0.99) < 0.001 && !reader.knows_recipe_node(node_id), "after reading most of it, familiarity fills to 99% and leaves the last step")
	familiar_check(!reader.note_familiar_sight(pick[2][2]), "nothing more once only the last step is left")
	// An old day's count is dropped when cleaned, the rest kept.
	var/list/saved = list("day" = -5, "t:[node_id]" = 0.1, "u:/obj/item" = 1, "bogus" = 3)
	saved[node_id] = 0.2
	var/list/clean = clean_familiarity(saved)
	familiar_check(!clean["t:[node_id]"] && clean[node_id] == 0.2 && clean["u:/obj/item"] == 1 && !clean["bogus"] && clean["day"] == familiarity_today(), "cleaning keeps what was learned and drops an old day's count")
