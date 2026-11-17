// Native probe of code/modules/research_tree/skill_guide.dm,
// included by tests/ecology_spawning/run_linux.py, never by the game DME.
/world
	hub = ""
	hub_password = ""
	maxx = 5
	maxy = 5
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
/obj/map_metadata/skill_probe/New()
	map = src
/mob/living/human/skill_tester/New()
	return
var/skill_failures = 0
var/skill_runtime_error = FALSE
/proc/skill_check(condition, label)
	if (!condition)
		skill_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	skill_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/obj/map_metadata/skill_probe/var/books = FALSE
/obj/map_metadata/skill_probe/book_research_enabled()
	return books
/world/New()
	OpenPort("none")
	try
		var/obj/map_metadata/skill_probe/M = new
		var/list/next = skill_guide_next_recipes("crafting", 1)
		skill_check(next && next[1] == 110 && ("wall" in next[2]), "a beginner's next Crafting recipes are the ones at 110")
		next = skill_guide_next_recipes("crafting", 1.7)
		skill_check(next && next[1] == 180 && ("catapult" in next[2]), "at 170 the next recipes are at 180")
		skill_check(isnull(skill_guide_next_recipes("crafting", 2.2)), "nothing is listed past the highest recipe")
		next = skill_guide_next_recipes("crafting", 0.9)
		skill_check(next && next[1] == 100 && ("locked door" in next[2]), "a need given as parts of a name lists them together")
		next = skill_guide_next_recipes("philosophy", 1)
		skill_check(next && next[1] == 135 && length(next[2]) == 1 && istext(next[2][1]) && length(next[2][1]), "a need given as a type lists that thing's name")
		skill_check(isnull(skill_guide_next_recipes("swords", 1)), "a skill no recipe needs lists nothing")
		var/mob/living/human/skill_tester/H = new(locate(1, 1, 1))
		for (var/statname in skill_guide_rows)
			H.stats[statname] = list(100, 100)
		H.stats["crafting"] = list(112, 112)
		var/html = H.skill_guide_html()
		var/all_rows = TRUE
		for (var/statname in skill_guide_rows)
			if (!findtext(html, "<b>[capitalize(statname == "machinegun" ? "machine gun" : statname)]</b>"))
				all_rows = FALSE
		skill_check(all_rows, "every body skill has a row")
		skill_check(findtext(html, "<span class='lvl'>112</span>"), "the viewer's own level is shown")
		skill_check(findtext(html, "At 125 you can make:"), "the next recipes for the viewer's level are shown")
		skill_check(findtext(html, "Things you have not made before teach far more than repeats."), "each skill says what raises it")
		skill_check(!findtext(html, "Scholarship") && !findtext(html, "you become"), "worlds without book research show no scholarship")
		skill_check(!findtext(lowertext(html), "magic"), "magic is left out")
		M.books = TRUE
		H.scholarship = list("engineering" = 17.6)
		html = H.skill_guide_html()
		var/all_disciplines = TRUE
		for (var/discipline in scholar_disciplines)
			if (!findtext(html, "<b>[scholar_disciplines[discipline]]</b>") || !istext(discipline_guide_rows[discipline]))
				all_disciplines = FALSE
		skill_check(all_disciplines && scholar_disciplines.len == discipline_guide_rows.len, "book-research worlds list every discipline")
		skill_check(findtext(html, "<span class='lvl'>17</span>"), "the viewer's discipline level is shown")
		skill_check(findtext(html, "At 150 you become skilled and gain 4 levels of Engineering."), "the next mastery milestone is shown")
		H.stats["crafting"] = list(250, 250)
		html = H.skill_guide_html()
		skill_check(!findtext(html, "levels of Engineering") && !findtext(html, "At 125 you can make:"), "a mastered skill lists nothing further")
		H.stats -= "bows"
		skill_check(!findtext(H.skill_guide_html(), "<b>Bows</b>"), "a skill the character lacks is skipped")
	catch(var/exception/e)
		skill_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = skill_failures, "runtime_error" = skill_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
