// Native probe for agent typed prompts (code/modules/agent_control/agent_prompts.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/agent_control/prompts_probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 10
	maxy = 10
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/mob/living/human/prompt_probe/New()
	return
/mob/living/human/prompt_probe/update_icons()
	return
/obj/prompt_probe_thing
	name = "Iron Pick"
var/prompt_failures = 0
var/prompt_runtime_error = FALSE
/proc/prompt_check(condition, label)
	if (!condition)
		prompt_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	prompt_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		prompt_checks()
	catch(var/exception/e)
		prompt_check(FALSE, "exception [e] [e.file]:[e.line] [e.desc]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = prompt_failures, "runtime_error" = prompt_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/prompt_answer(datum/agent_character/C, answer)
	C.pending_choice = answer
	C.pending_choice_until = world.time + 100

/proc/prompt_checks()
	var/turf/T = locate(5, 5, 1)
	var/mob/living/human/prompt_probe/H = new(T)
	var/datum/agent_character/C = new
	C.body = H
	agent_characters[H] = C

	prompt_answer(C, "Ada's camp")
	prompt_check(player_input(H, "Name it", "Label", null, "text", null, TRUE) == "Ada's camp", "a text prompt takes the step's answer")
	prompt_check(isnull(C.pending_choice), "an answer is used once")
	prompt_answer(C, "12")
	prompt_check(player_input(H, "How many?", "Split", 1, "num", null, FALSE) == 12, "a number prompt converts the answer")
	prompt_answer(C, "lots")
	prompt_check(player_input(H, "How many?", "Split", 3, "num", null, FALSE) == 3 && C.prompts.len == 1, "a non-number answer falls back to the default and is listed")
	C.pending_choice = null
	var/obj/prompt_probe_thing/pick = new(T)
	var/list/things = list("Stone", pick)
	prompt_answer(C, "iron pick")
	prompt_check(player_input(H, "Which?", "Pick", null, "anything", things, TRUE) == pick, "a list prompt matches an object choice by name, ignoring case")
	prompt_answer(C, "Gold")
	prompt_check(isnull(player_input(H, "Which?", "Pick", null, "anything", things, TRUE)), "an answer that is not a choice picks nothing")
	var/list/row = C.prompts[C.prompts.len]
	prompt_check(row["title"] == "Pick" && row["choices"][2] == "Iron Pick", "the unanswered prompt lists its choices")
	C.pending_choice = null
	prompt_check(player_input(H, "Which?", "Pick", "Stone", "anything", things, FALSE) == "Stone", "an unanswered list prompt takes a default that is a choice")
	prompt_answer(C, "#00ff00")
	prompt_check(player_input(H, "Colour?", "Paint", null, "color", null, FALSE) == "#00ff00", "a colour prompt takes a hex answer")
	prompt_answer(C, "no")
	prompt_check(player_alert(H, "Sure?", "Confirm", list("Yes", "No")) == "No", "an alert takes a button named by the answer")
	C.pending_choice = null
	prompt_check(isnull(player_alert(H, "Sure?", "Confirm", list("Yes", "No"))), "an unanswered alert presses nothing")
	prompt_answer(C, "Yes")
	C.pending_choice_until = world.time - 1
	prompt_check(isnull(player_alert(H, "Sure?", "Confirm", list("Yes", "No"))), "a stale answer is not used")
