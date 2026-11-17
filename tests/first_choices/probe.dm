// Native probe of code/modules/research_tree/first_choices.dm and the bottom hover line,
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
/obj/map_metadata/choice_probe/New()
	map = src
/mob/living/human/choice_tester/New()
	return
var/choice_failures = 0
var/choice_runtime_error = FALSE
/proc/choice_check(condition, label)
	if (!condition)
		choice_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	choice_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		choice_check(hover_name_bottom_loc(480, 100) == "6:31,2:4", "the bottom line is centred above the bottom HUD row")
		choice_check(hover_name_bottom_loc(480, 480) == "1:1,2:4" && hover_name_bottom_loc(480, 600) == "1:1,2:4", "a line as wide as the view starts at its left edge")
		choice_check(first_choice_current(first_choice_hover, 2) == "In a line at the bottom of the screen" && first_choice_current(first_choice_hover, 0) == "Hidden", "the current hover choice is preselected")
		choice_check(first_choice_current(first_choice_movement, FALSE) == "I stop exactly where I let go of the key", "the current movement choice is preselected")
		choice_check(first_choice_current(first_choice_hud, "1713Style") == "1713 (the classic HUD)" && first_choice_current(first_choice_hud, "gone") == first_choice_hud[1], "the current HUD style is preselected, else the first")
		var/all_styles = first_choice_hud.len == all_ui_styles.len
		for (var/label in first_choice_hud)
			if (!(first_choice_hud[label] in all_ui_styles))
				all_styles = FALSE
		choice_check(all_styles, "every HUD style is offered")
		var/datum/preferences/P = new
		choice_check(!P.first_choices_done && !P.hover_text_bottom && P.hover_text_enabled && P.tap_step, "a new account has not chosen and starts with the defaults")
	catch(var/exception/e)
		choice_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = choice_failures, "runtime_error" = choice_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
