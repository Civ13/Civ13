// Stubs for the research tree's world dependencies; the logic under test is
// the production code copied next to this file by run.py.
var/global/list/human_mob_list = list()
var/global/list/living_mob_list = list()
var/global/list/research_benches = list()
var/global/obj/map_metadata/map
var/global/list/probe_failures = list()

/proc/to_chat(target, message)
	return
/proc/log_debug(text)
	return
/proc/agent_character_for(mob/M)
	return null

/mob/living/human
	var/civilization = "none"
	var/leader = FALSE
	var/research_role = null

/obj/structure/research_bench
	var/faction = null
/obj/structure/research_bench/adminbench

/obj/map_metadata
	var/age = "5000 B.C."
	var/ordinal_age = 0
	var/persistence = FALSE
	var/autoresearch = FALSE
	var/list/custom_civs = list()
	var/age1_done = FALSE
	var/age2_done = FALSE
	var/age3_done = FALSE
	var/age4_done = FALSE
	var/age5_done = FALSE
	var/age6_done = FALSE
	var/age7_done = FALSE
	var/age8_done = FALSE
	var/age9_done = FALSE

/proc/check(condition, label)
	if (!condition)
		probe_failures += label

/proc/set_legacy_age(obj/map_metadata/M, reached)
	var/list/names = list("age1_done", "age2_done", "age3_done", "age4_done", "age5_done", "age6_done", "age7_done", "age8_done", "age9_done")
	for (var/i = 1, i <= names.len, i++)
		M.vars[names[i]] = (i <= reached)

/world/New()
	..()
	try
		run_probe()
	catch(var/exception/E)
		probe_failures += "runtime: [E.name]"
	text2file(probe_failures.len ? "FAIL: [jointext(probe_failures, "; ")]\n" : "PASS\n", "result.txt")
	del(world)

/proc/run_probe()
	register_research_node(new /datum/research_node("main7", "Main 7", "Industrial", 100, 0, RESEARCH_MODE_ANALYSIS, null, 7))
	register_research_node(new /datum/research_node("main8", "Main 8", "Industrial", 100, 0, RESEARCH_MODE_ANALYSIS, null, 8))
	register_research_node(new /datum/research_node("spec6", "Specialist 6", "Textiles", 100, 0, RESEARCH_MODE_ANALYSIS, null, 6, null, "Tailoring"))
	register_research_node(new /datum/research_node("spec7", "Specialist 7", "Textiles", 100, 0, RESEARCH_MODE_ANALYSIS, null, 7, null, "Tailoring"))

	// Gaia as saved on 2026-11-05: Auto-Research reached the Cold War (7) and
	// half the factions were founded in WW2 (baseline 6).
	map = new /obj/map_metadata
	map.persistence = TRUE
	map.autoresearch = TRUE
	map.ordinal_age = 7
	map.age = "1969"
	set_legacy_age(map, 7)
	map.faction_baseline_era = list("Old" = 6, "New" = 7)
	check(map.legacy_age_reached() == 7, "legacy age from flags")
	check(map.is_node_done(null, "main7"), "factionless gets era-7 main node")
	map.sync_autoresearch_baselines()
	check(map.faction_baseline_era["Old"] == 7, "old faction baseline follows the clock")
	check(map.is_node_done("Old", "main7"), "old faction gets era-7 main node")

	// A capstone raised the era without the flag: others still research it.
	map.ordinal_age = 8
	map.age = "2013"
	map.sync_autoresearch_baselines()
	check(map.faction_baseline_era["Old"] == 7, "capstone era is not granted to other factions")
	check(!map.is_node_done("Old", "main8"), "capstone era-8 node still needs research")

	// The legacy step for an age a capstone already passed never goes back.
	map.ordinal_age = 9
	map.age = "2026"
	check(!map.legacy_age_advance(8, "2013", "x"), "legacy step behind the era is skipped")
	check(map.ordinal_age == 9 && map.age == "2026", "era not lowered by legacy step")
	map.ordinal_age = 7
	map.age = "1969"
	check(map.legacy_age_advance(8, "2013", "x") && map.ordinal_age == 8 && map.age == "2013", "legacy step still advances")

	// age9_done is not saved; a raised baseline is, and is never lowered.
	set_legacy_age(map, 9)
	map.sync_autoresearch_baselines()
	check(map.faction_baseline_era["Old"] == 9, "baseline reaches the Digital Age")
	set_legacy_age(map, 8)
	map.sync_autoresearch_baselines()
	check(map.faction_baseline_era["Old"] == 9, "restart does not lower a baseline")

	// Classic research: one faction's totals drive the legacy age-up.
	var/obj/map_metadata/classic = new
	classic.faction_baseline_era = list("Old" = 6)
	set_legacy_age(classic, 7)
	map = classic
	classic.sync_autoresearch_baselines()
	check(classic.faction_baseline_era["Old"] == 6, "classic research keeps founding baselines")

	// Specialist trees on persistent worlds.
	map = new /obj/map_metadata
	map.persistence = TRUE
	map.ordinal_age = 7
	map.faction_baseline_era = list("Old" = 7)
	check(map.is_node_done("Old", "spec6"), "faction gets WW2 specialist node")
	check(!map.is_node_done("Old", "spec7"), "post-WW2 specialist node still earned")
	check(!map.is_node_done(null, "spec6") && !map.is_node_done("none", "spec6"), "factionless never get specialist nodes")
	map.persistence = FALSE
	check(!map.is_node_done("Old", "spec6"), "non-persistent rounds research specialist trees")
