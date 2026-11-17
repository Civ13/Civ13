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
