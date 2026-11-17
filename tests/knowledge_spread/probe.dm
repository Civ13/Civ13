// Native knowledge-spread probe, included by tests/ecology_spawning/run_linux.py,
// never by the game DME. It drives code/modules/research_tree/knowledge_spread.dm.
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
/obj/map_metadata/spread_probe/New()
	map = src
	persistence = TRUE
	recipe_books = TRUE
/mob/living/human/spread_tester/New()
	return
/mob/living/human/spread_tester/adaptStat(stat, amount)
	return
var/spread_failures = 0
var/spread_runtime_error = FALSE
/proc/spread_check(condition, label)
	if (!condition)
		spread_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	spread_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/spread_probe
		build_research_tree()
		spread_band_checks()
		spread_common_checks()
		spread_learning_checks()
		spread_rediscovery_checks()
	catch(var/exception/e)
		spread_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = spread_failures, "runtime_error" = spread_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

// The first ordinary subject of an era.
/proc/spread_node_of_tier(tier)
	for (var/id in research_nodes)
		var/datum/research_node/N = research_nodes[id]
		if (N.era_tier == tier && N.mode != RESEARCH_MODE_BOOK && !research_node_dormant(N))
			return id
	return null

/proc/spread_band_checks()
	spread_check(knowledge_spreading_lag() == 2 && knowledge_common_lag() == 4, "the lags default to 2 and 4 eras")
	spread_check(knowledge_band_for(9, 9, 2, 4) == KNOWLEDGE_GUARDED && knowledge_band_for(8, 9, 2, 4) == KNOWLEDGE_GUARDED, "the world's era and the one before it are guarded")
	spread_check(knowledge_band_for(7, 9, 2, 4) == KNOWLEDGE_SPREADING && knowledge_band_for(6, 9, 2, 4) == KNOWLEDGE_SPREADING, "two and three eras behind are spreading")
	spread_check(knowledge_band_for(5, 9, 2, 4) == KNOWLEDGE_COMMON && knowledge_band_for(0, 9, 2, 4) == KNOWLEDGE_COMMON, "four or more eras behind are common")
	spread_check(knowledge_band_for(3, 2, 2, 4) == KNOWLEDGE_GUARDED, "a subject ahead of the world is guarded")
	spread_check(knowledge_band_for(0, 3, 3, 3) == KNOWLEDGE_COMMON, "common wins when the lags overlap")
	spread_check(knowledge_band_for(0, 9, 10, 10) == KNOWLEDGE_GUARDED, "a lag of 10 never happens")
	var/stone = spread_node_of_tier(0)
	var/medieval = spread_node_of_tier(2)
	var/industrial = spread_node_of_tier(4)
	map.ordinal_age = 0
	spread_check(!length(knowledge_band_node_ids(KNOWLEDGE_COMMON)) && !length(knowledge_band_node_ids(KNOWLEDGE_SPREADING)), "a Stone Age world has nothing spreading or common")
	map.ordinal_age = 1
	spread_check(knowledge_band(stone) == KNOWLEDGE_GUARDED, "a Classical world still guards the Stone Age")
	map.ordinal_age = 2
	spread_check(knowledge_band(stone) == KNOWLEDGE_SPREADING && knowledge_band(medieval) == KNOWLEDGE_GUARDED, "a Medieval world spreads the Stone Age")
	map.ordinal_age = 4
	spread_check(knowledge_band(stone) == KNOWLEDGE_COMMON && knowledge_band(medieval) == KNOWLEDGE_SPREADING && knowledge_band(industrial) == KNOWLEDGE_GUARDED, "an Industrial world: Stone common, Medieval spreading, Industrial guarded")
	var/datum/research_node/S = get_research_node(stone)
	var/datum/research_node/M = get_research_node(medieval)
	var/datum/research_node/I = get_research_node(industrial)
	spread_check(research_era_label(S) == "Stone Age - common knowledge" && research_era_label(M) == "Medieval Age - spreading" && research_era_label(I) == "Industrial Age", "the era label names the band unless guarded")
	for (var/id in book_only_research_nodes)
		spread_check(knowledge_band(id) == KNOWLEDGE_GUARDED, "book-only subject [id] stays guarded")
		break
	map.ordinal_age = 9
	var/common = length(knowledge_band_node_ids(KNOWLEDGE_COMMON))
	var/spreading = length(knowledge_band_node_ids(KNOWLEDGE_SPREADING))
	spread_check(common > 0 && spreading > 0 && common + spreading < research_nodes.len, "a Digital world has all three bands ([common] common, [spreading] spreading of [research_nodes.len])")
	map.ordinal_age = 2
	spread_check(knowledge_band(stone) == KNOWLEDGE_SPREADING, "the bands fall back when the era falls")
	map.book_research = FALSE
	spread_check(knowledge_band(stone) == KNOWLEDGE_GUARDED, "nothing spreads off a book-research world")
	map.book_research = TRUE

/proc/spread_tester()
	var/mob/living/human/H = new /mob/living/human/spread_tester(locate(5, 5, 1))
	H.real_name = "Tester"
	return H

/proc/spread_common_checks()
	var/stone = spread_node_of_tier(0)
	var/classical = spread_node_of_tier(1)
	var/medieval = spread_node_of_tier(2)
	map.ordinal_age = 3
	var/mob/living/human/early = spread_tester()
	spread_check(knowledge_common_era() == -1 && !early.grant_common_knowledge() && !length(early.known_recipe_nodes), "nothing is common before the fourth era after the Stone Age")
	map.ordinal_age = 4
	var/stone_count = length(stone_age_node_ids())
	var/mob/living/human/fresh = spread_tester()
	spread_check(fresh.grant_common_knowledge() == stone_count && fresh.knows_recipe_node(stone) && !fresh.knows_recipe_node(classical), "a new character in an Industrial world starts with the [stone_count] Stone Age subjects and no more")
	spread_check(!fresh.grant_common_knowledge(), "common knowledge is given once")
	spread_check(!length(fresh.scholarship), "common knowledge brings no scholarship")
	// A living character who already knows some of it gains the rest and keeps the others.
	var/mob/living/human/old = spread_tester()
	old.known_recipe_nodes = list(stone, medieval)
	old.note_study_progress(classical, 0.5)
	human_mob_list += old
	map.ordinal_age = 5
	var/reached = knowledge_era_advanced()
	spread_check(reached >= 1 && old.knows_recipe_node(classical) && old.knows_recipe_node(medieval), "when the era advances the living gain what became common and keep the rest")
	spread_check(!old.study_fraction(classical), "a half-read chapter that became common is finished")
	// The era falls: nothing is taken back, and a new character gets the lower floor.
	map.ordinal_age = 4
	spread_check(old.knows_recipe_node(classical), "what was gained is kept when the era falls")
	var/mob/living/human/later = spread_tester()
	later.grant_common_knowledge()
	spread_check(later.knows_recipe_node(stone) && !later.knows_recipe_node(classical), "a character made after the fall gets the lower floor")
	// The dead learn nothing, and other worlds are untouched.
	var/mob/living/human/corpse = spread_tester()
	corpse.stat = DEAD
	spread_check(!corpse.grant_common_knowledge() && !length(corpse.known_recipe_nodes), "the dead gain nothing")
	map.book_research = FALSE
	var/mob/living/human/elsewhere = spread_tester()
	spread_check(!elsewhere.grant_common_knowledge(), "nothing is common off a book-research world")
	map.book_research = TRUE
	// Every common subject's groundwork is common too, so nothing is known without its footing.
	map.ordinal_age = 9
	var/list/common = knowledge_band_node_ids(KNOWLEDGE_COMMON)
	var/gaps = 0
	for (var/id in common)
		var/datum/research_node/N = get_research_node(id)
		for (var/req in N.prereqs)
			var/datum/research_node/R = get_research_node(req)
			if (R && !research_node_dormant(R) && R.mode != RESEARCH_MODE_BOOK && !(req in common))
				gaps++
	spread_check(!gaps, "every common subject's groundwork is common as well")
	human_mob_list -= old

/proc/spread_learning_checks()
	var/mob/living/human/reader = spread_tester()
	var/cold_war = spread_node_of_tier(7)
	var/datum/research_node/N = get_research_node(cold_war)
	map.ordinal_age = 7
	var/guarded_time = reader.scholar_study_time(N.era_tier, cold_war)
	spread_check(knowledge_study_mult(cold_war) == 1 && trade_learning_cap(N) == 0.5, "a guarded late subject reads at full length and hands teach half of it")
	map.ordinal_age = 9
	var/spreading_time = reader.scholar_study_time(N.era_tier, cold_war)
	spread_check(knowledge_band(cold_war) == KNOWLEDGE_SPREADING && spreading_time == round(guarded_time / 2), "a spreading chapter reads in half the time ([guarded_time] to [spreading_time])")
	spread_check(trade_learning_cap(N) == 1, "hands can teach the whole of a spreading subject")
	// Hearing it read aloud is paced by the same reading time.
	var/mob/living/human/listener = spread_tester()
	listener.known_recipe_nodes = N.prereqs ? N.prereqs.Copy() : list()
	listener.hear_chapter_read(cold_war, 600, reader)
	var/heard_spreading = listener.study_fraction(cold_war)
	map.ordinal_age = 7
	listener.clear_study_progress(cold_war)
	listener.hear_chapter_read(cold_war, 600, reader)
	var/heard_guarded = listener.study_fraction(cold_war)
	spread_check(heard_guarded > 0 && abs(heard_spreading - heard_guarded * 2) < 0.01, "a minute of listening fills twice as much of a spreading chapter")
	var/modern = spread_node_of_tier(8)
	map.ordinal_age = 9
	var/datum/research_node/M = get_research_node(modern)
	spread_check(knowledge_study_mult(modern) == 1 && trade_learning_cap(M) == 0.5, "the newest two eras are untouched")

/proc/spread_rediscovery_checks()
	var/cold_war = spread_node_of_tier(7)
	var/modern = spread_node_of_tier(8)
	var/stone = spread_node_of_tier(0)
	map.ordinal_age = 9
	spread_check(knowledge_rediscovery_rate(cold_war) == 3, "bench work on a spreading subject counts three times")
	spread_check(knowledge_rediscovery_rate(modern) == 1, "bench work on a guarded subject counts once")
	spread_check(knowledge_rediscovery_rate(stone) == 1, "a common subject needs no research, so its rate is plain")
	map.ordinal_age = 7
	spread_check(knowledge_rediscovery_rate(cold_war) == 1, "the same subject at the frontier counts once")
	map.ordinal_age = 9
	map.book_research = FALSE
	spread_check(knowledge_rediscovery_rate(cold_war) == 1, "no rediscovery rate off a book-research world")
	map.book_research = TRUE
