// Native probe for agent HUD toggles (code/modules/agent_control/agent_stance.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/agent_control/stance_probe.dm
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
/mob/living/human/stance_probe/New()
	return
/mob/living/human/stance_probe/update_icons()
	return
var/stance_failures = 0
var/stance_runtime_error = FALSE
/proc/stance_check(condition, label)
	if (!condition)
		stance_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	stance_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		stance_checks()
	catch(var/exception/e)
		stance_check(FALSE, "exception [e] [e.file]:[e.line] [e.desc]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = stance_failures, "runtime_error" = stance_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/stance_fail(datum/agent_character/C, list/req)
	try
		agent_control.agent_stance(C, req)
	catch(var/exception/e)
		return e.desc
	return null

/proc/stance_checks()
	var/turf/T = locate(5, 5, 1)
	var/mob/living/human/stance_probe/H = new(T)
	var/datum/agent_character/C = new
	C.body = H
	agent_characters[H] = C
	H.species = new /datum/species/human
	H.m_intent = "walk"
	var/crawl_error = stance_fail(C, list("move" = "crawl"))
	stance_check(isnull(crawl_error), "crawl is accepted [crawl_error]")
	stance_check(H.m_intent == "proning" && H.prone, "crawling lies the character down")
	stance_check(isnull(stance_fail(C, list("move" = "run"))) && H.m_intent == "run" && !H.prone, "running stands it up")
	stance_check(isnull(stance_fail(C, list("move" = "sneak"))) && H.m_intent == "stealth", "sneak sets stealth")
	stance_check(findtext(stance_fail(C, list("move" = "fly")), "bad_args:") == 1, "an unknown move mode is refused")
	stance_check(isnull(stance_fail(C, list("defense" = "parry", "tactic" = "defend", "secondary" = "bite"))), "several toggles at once")
	stance_check(H.defense_intent == I_PARRY && H.tactic == "defend" && H.middle_click_intent == "bite", "defense, tactic and secondary are set")
	stance_check(isnull(stance_fail(C, list("face_lock" = TRUE))) && H.facing_dir, "face lock on")
	stance_check(isnull(stance_fail(C, list("face_lock" = FALSE))) && !H.facing_dir, "face lock off")
	stance_check(isnull(stance_fail(C, list("aim" = TRUE))) && H.aiming && H.aiming.active, "aim mode on")
	stance_check(isnull(stance_fail(C, list("aim" = FALSE))) && !H.aiming.active, "aim mode off")
	stance_check(findtext(stance_fail(C, list()), "bad_args:") == 1, "an empty stance is refused")
	var/list/row = agent_stance_row(H)
	stance_check(row["move"] == "stealth" && row["defense"] == I_PARRY && row["aim"] == FALSE, "the stance row reports the toggles")

	var/obj/item/weapon/storage/S = new /obj/item/weapon/storage(locate(6, 5, 1))
	var/obj/item/I = new /obj/item(S)
	I.name = "coin"
	var/list/contents = agent_container_contents(S)
	stance_check(contents.len == 1 && contents[1]["name"] == "coin", "a container next to the character lists its contents")
	stance_check(agent_click_reaches_container(H, I), "an item in an adjacent container can be clicked")
	S.loc = locate(8, 5, 1)
	stance_check(!agent_click_reaches_container(H, I), "an item in a distant container cannot")
	S.loc = H
	stance_check(agent_click_reaches_container(H, I), "an item in a carried container can be clicked")
	try
		agent_equip_slot(H, I, "wings")
		stance_check(FALSE, "an unknown slot is refused")
	catch(var/exception/e)
		stance_check(findtext(e.desc, "bad_args:") == 1, "an unknown slot is refused")
