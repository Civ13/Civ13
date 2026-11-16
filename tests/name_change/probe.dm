// Native name change probe, included by tests/ecology_spawning/run_linux.py,
// never by the game DME. It drives code/game/mob/living/carbon/human/name_change.dm.
/world
	hub = ""
	hub_password = ""
	maxx = 30
	maxy = 30
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/names_probe
	persistence = TRUE
/obj/map_metadata/names_probe/New()
	map = src
/mob/living/human/names_probe/New()
	icon_update = FALSE
	return
/mob/living/human/names_probe/restrained()
	return FALSE
/mob/living/human/names_probe/put_in_hands(obj/item/W)
	return FALSE
var/names_p_failures = 0
var/names_p_runtime_error = FALSE
/proc/names_p_check(condition, label)
	if (!condition)
		names_p_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	names_p_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/names_probe
		for (var/turf/T in block(locate(1, 1, 1), locate(30, 30, 1)))
			T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
		names_p_checks()
	catch(var/exception/e)
		names_p_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = names_p_failures, "runtime_error" = names_p_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/names_p_member(name, ckey, x, faction)
	var/mob/living/human/names_probe/H = new(locate(x, 10, 1))
	H.real_name = name
	H.name = name
	H.stat = CONSCIOUS
	H.civilization = faction
	H.persistence_owner_ckey = ckey
	human_mob_list |= H
	return H

/proc/names_p_checks()
	var/mob/living/human/names_probe/L = names_p_member("Ada Reeve", "adareeve", 10, "Eagles")
	map.custom_civs["Eagles"] = list(0, 0, 0, L, 0, 0, 0, 0, 5, 5, list())
	map.faction_roster_add("Eagles", "adareeve")
	var/mob/living/human/names_probe/C = names_p_member("Cy Trader", "cytrader", 11, "Eagles")
	map.faction_roster_add("Eagles", "cytrader")
	var/mob/living/human/names_probe/O = names_p_member("Di Vale", "divale", 14, "none")

	names_p_check(name_change_enabled(), "names change in a persistent world")
	names_p_check(C.name_change_clean("  bo  smith ") == "Bo Smith", "a new name is cleaned like a setup name")
	names_p_check(!C.name_change_clean("1"), "a name of no letters is refused")
	names_p_check(C.name_change_refusal("Ada Reeve"), "a name someone here goes by is refused")
	names_p_check(C.name_change_refusal("Cy Trader"), "the same name is refused")
	names_p_check(!C.name_change_refusal("Bo Smith"), "a free name is accepted")

	// Records keyed by the account that also show the name.
	var/serial = map.papers_issue("Eagles", "citizenship", "Cy Trader", "cytrader", 0, "Ada Reeve")
	var/obj/item/faction_papers/P = map.papers_make("Eagles", serial, C)
	map.office_appoint("Eagles", "Treasurer", "cytrader", "Cy Trader", 0)
	map.justice_warrant("Wolves", "cytrader", "Cy Trader", "theft", "Ma Wolf")
	var/datum/craft_register/R = new
	R.party = "nobody"
	R.set_role("Cy Trader", CRAFT_ROLE_HELMSMAN)
	R.bar("Di Vale")
	var/obj/structure/stone_age_trap/pit/T = new(locate(20, 20, 1))
	T.setter_name = "Cy Trader"

	names_p_check(C.take_new_name("Bo Smith", "probe"), "the name is taken")
	names_p_check(C.real_name == "Bo Smith" && C.name == "Bo Smith", "the character goes by the new name")
	names_p_check(C.former_names && ("Cy Trader" in C.former_names), "the old name is kept")
	names_p_check(C.name_history && C.name_history.len == 1 && findtext(C.name_history[1], "Cy Trader became Bo Smith"), "the character's history has a dated line")
	names_p_check(C.name_change_wait_text() && C.name_change_refusal("Bo Other"), "a second change waits 7 days")
	var/list/N = map.recruitment_state()["names"]
	names_p_check(islist(N) && islist(N["cytrader"]) && N["cytrader"].len == 1, "the region keeps the account's record")
	names_p_check(findtext(C.name_history_admin_html(), "Cy Trader became Bo Smith"), "admins see the history")
	names_p_check(map.papers_row("Eagles", serial)[2] == "Bo Smith" && P.holder == "Bo Smith" && P.name == "citizenship papers of Eagles for Bo Smith", "papers are rewritten to the new name and stay in force")
	names_p_check(map.office_holder_row("Eagles", "Treasurer")[2] == "Bo Smith", "the office shows the new name")
	var/list/J = map.justice_record("Wolves")
	names_p_check(J["warrants"]["cytrader"][1] == "Bo Smith", "a warrant follows the account and shows the new name")
	names_p_check(findtext(jointext(J["record"], "\n"), "Cy Trader now goes by Bo Smith"), "the court record notes the change")
	names_p_check(R.role_of(C) == CRAFT_ROLE_HELMSMAN && R.may_steer(C), "a crew place kept under the old name still counts")
	names_p_check(T.knows_pit(C), "the setter still knows their own pit trap")
	names_p_check(C.answers_to_name("Cy Trader") && !O.answers_to_name("Cy Trader"), "only the renamed character answers to the old name")
	O.take_new_name("Ez Vale", "probe")
	names_p_check(R.is_barred(O), "a barred character stays barred under a new name")

	// Travel keeps the trail.
	names_p_check(name_history_valid(C.former_names) && name_history_valid(C.name_history), "the history passes travel checks")
	var/list/long = list()
	for (var/i in 1 to 21)
		long += "Name [i]"
	names_p_check(!name_history_valid(long) && !name_history_valid(list(5)), "oversized or malformed history is refused")

	// The clerk's log reads with the census.
	map.papers_name_change_log("Eagles", "Cy Trader took the name Bo Smith, recorded by Ada Reeve.")
	names_p_check(findtext(jointext(map.census_lines("Eagles"), "\n"), "Cy Trader took the name Bo Smith"), "the census lists changes of name")
	map.papers_normalize()
	names_p_check(map.papers_name_change_lines("Eagles").len == 1, "the log survives the register clean-up")
