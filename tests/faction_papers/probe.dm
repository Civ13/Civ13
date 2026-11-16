// Native faction papers probe, included by tests/ecology_spawning/run_linux.py,
// never by the game DME. It drives code/game/mob/groups/faction_papers.dm.
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
/obj/map_metadata/papers_probe/New()
	map = src
/mob/living/human/papers_probe
	var/obj/item/probe_hand = null
/mob/living/human/papers_probe/New()
	icon_update = FALSE
	return
/mob/living/human/papers_probe/get_active_hand()
	return probe_hand
/mob/living/human/papers_probe/get_inactive_hand()
	return null
/mob/living/human/papers_probe/restrained()
	return FALSE
/mob/living/human/papers_probe/put_in_hands(obj/item/W)
	return FALSE
var/papers_p_failures = 0
var/papers_p_runtime_error = FALSE
/proc/papers_p_check(condition, label)
	if (!condition)
		papers_p_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	papers_p_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/papers_probe
		for (var/turf/T in block(locate(1, 1, 1), locate(30, 30, 1)))
			T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
		papers_p_checks()
	catch(var/exception/e)
		papers_p_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = papers_p_failures, "runtime_error" = papers_p_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/papers_p_member(name, ckey, x, faction)
	var/mob/living/human/papers_probe/H = new(locate(x, 10, 1))
	H.real_name = name
	H.name = name
	H.stat = CONSCIOUS
	H.civilization = faction
	H.persistence_owner_ckey = ckey
	human_mob_list |= H
	return H

/proc/papers_p_checks()
	var/mob/living/human/papers_probe/L = papers_p_member("Ada Reeve", "adareeve", 10, "Eagles")
	map.custom_civs["Eagles"] = list(0, 0, 0, L, 0, 0, 0, 0, 5, 5, list())
	map.faction_roster_add("Eagles", "adareeve")
	var/mob/living/human/papers_probe/T = papers_p_member("Cy Trader", "cytrader", 12, "Wolves")
	var/mob/living/human/papers_probe/V = papers_p_member("Di Vale", "divale", 14, "Wolves")

	papers_p_check(map.faction_power(L, "Eagles", "papers"), "the leader holds the papers power")
	papers_p_check(!map.faction_power(T, "Eagles", "papers"), "an outsider does not")

	var/citizen = map.papers_issue("Eagles", "citizenship", "Cy Trader", "cytrader", 0, "Ada Reeve")
	var/pass = map.papers_issue("Eagles", "pass", "Di Vale", "divale", 3, "Ada Reeve")
	papers_p_check(citizen == "1" && pass == "2", "papers are registered with serials")
	papers_p_check(map.papers_row("Eagles", pass)[5] > recruitment_now(), "a pass runs out")
	papers_p_check(!map.papers_issue("Eagles", "deed", "x", "x", 0, "y") && !map.papers_issue("Eagles", "pass", "x", "", 1, "y"), "only papers for an account of a known kind")

	var/obj/item/faction_papers/CP = map.papers_make("Eagles", citizen, T)
	var/obj/item/faction_papers/PP = map.papers_make("Eagles", pass, V)
	papers_p_check(CP.name == "citizenship papers of Eagles for Cy Trader" && PP.name == "travel pass to Eagles for Di Vale", "papers name their faction and holder")

	var/obj/structure/simple_door/key_door/faction_door/D = new(locate(20, 20, 1))
	D.faction = "Eagles"
	papers_p_check(!D.faction_door_admits(T) && D.faction_door_admits(L), "a door opens for members only by default")
	D.admits = 1
	papers_p_check(D.faction_door_admits(T) && !D.faction_door_admits(V), "set for citizens, it opens for a citizen but not a pass holder")
	D.admits = 2
	papers_p_check(D.faction_door_admits(V), "set for passes, it opens for a pass holder")
	PP.forceMove(T)
	CP.forceMove(V)
	papers_p_check(!D.faction_door_admits(V) && !D.faction_door_admits(T), "papers count only for their own holder")
	CP.forceMove(T)
	PP.forceMove(V)
	map.papers_revoke("Eagles", citizen)
	papers_p_check(!D.faction_door_admits(T) && !CP.in_force(), "revoked papers open nothing")
	map.papers_record("Eagles")["open"][pass][5] = recruitment_now() - 6000
	papers_p_check(!D.faction_door_admits(V) && !map.papers_row("Eagles", pass), "an expired pass opens nothing and leaves the register")

	var/list/census = map.census_lines("Eagles")
	papers_p_check(findtext(jointext(census, "\n"), "Ada Reeve, joined") && findtext(jointext(census, "\n"), "Office of Treasurer: vacant"), "the census lists members and offices")

	map.papers_issue("Eagles", "citizenship", "Cy Trader", "cytrader", 0, "Ada Reeve")
	map.papers_record("Eagles")["open"]["bad"] = list("pass", "x")
	map.papers_normalize()
	papers_p_check(!map.papers_record("Eagles")["open"]["bad"] && map.papers_row("Eagles", "3"), "malformed papers are dropped")
	map.papers_rename("Eagles", "Hawks")
	papers_p_check(map.papers_row("Hawks", "3") && CP.faction == "Hawks" && CP.name == "citizenship papers of Hawks for Cy Trader", "papers follow a faction rename")
