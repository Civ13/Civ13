// Native faction treaties probe, included by tests/ecology_spawning/run_linux.py,
// never by the game DME. It drives code/game/mob/groups/faction_treaties.dm.
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
/obj/map_metadata/treaty_probe/New()
	map = src
/mob/living/human/treaty_probe
	var/obj/item/probe_hand = null
/mob/living/human/treaty_probe/New()
	icon_update = FALSE
	return
/mob/living/human/treaty_probe/get_active_hand()
	return probe_hand
/mob/living/human/treaty_probe/get_inactive_hand()
	return null
/mob/living/human/treaty_probe/restrained()
	return FALSE
/mob/living/human/treaty_probe/put_in_hands(obj/item/W)
	return FALSE
var/treaty_p_failures = 0
var/treaty_p_runtime_error = FALSE
/proc/treaty_p_check(condition, label)
	if (!condition)
		treaty_p_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	treaty_p_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/treaty_probe
		for (var/turf/T in block(locate(1, 1, 1), locate(30, 30, 1)))
			T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
		treaty_p_checks()
	catch(var/exception/e)
		treaty_p_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = treaty_p_failures, "runtime_error" = treaty_p_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/treaty_p_leader(name, ckey, x, faction)
	var/mob/living/human/treaty_probe/H = new(locate(x, 10, 1))
	H.real_name = name
	H.name = name
	H.stat = CONSCIOUS
	H.civilization = faction
	H.persistence_owner_ckey = ckey
	human_mob_list |= H
	map.custom_civs[faction] = list(0, 0, 0, H, 0, 0, 0, 0, 5, 5, list())
	return H

/proc/treaty_p_checks()
	var/mob/living/human/treaty_probe/A = treaty_p_leader("Ada Reeve", "adareeve", 10, "Eagles")
	treaty_p_leader("Bo Tanner", "botanner", 12, "Wolves")
	treaty_p_leader("Cy Lowe", "cylowe", 14, "Otters")
	treaty_p_check(map.faction_power(A, "Eagles", "diplomacy") && !map.faction_power(A, "Wolves", "diplomacy"), "a leader holds the diplomacy power for their own faction only")

	var/id = map.treaty_draft("Eagles", list("Wolves", "Otters", "Eagles"), "Peace of the Ford", "No raids across the ford.", "Ada Reeve")
	var/list/T = map.treaty_get(id)
	treaty_p_check(id == "1" && T && T["status"] == "draft" && T["parties"].len == 3, "a draft names every party once")
	treaty_p_check(islist(T["parties"]["Eagles"]) && T["parties"]["Wolves"] == 0, "the drafting faction signs at once")
	treaty_p_check(!map.treaty_draft("Eagles", list("Eagles"), "Alone", "x", "Ada Reeve"), "a treaty needs another party")
	treaty_p_check(!map.treaty_draft("Eagles", list("Wolves"), "", "x", "Ada Reeve"), "a treaty needs a title")
	treaty_p_check(!map.treaty_sign(id, "Eagles", "Ada Reeve"), "a party signs once")
	treaty_p_check(!map.treaty_sign(id, "Wolves", "Bo Tanner") && T["status"] == "draft", "it waits for every party")
	treaty_p_check(map.treaty_sign(id, "Otters", "Cy Lowe") && T["status"] == "in force", "the last signature puts it in force")
	treaty_p_check(!map.treaty_renounce(id, "Moles", "x", ""), "only a party can renounce")
	treaty_p_check(map.treaty_renounce(id, "Wolves", "Bo Tanner", "the ford dried up") && T["status"] == "renounced", "a party renounces it")
	treaty_p_check(findtext(jointext(T["history"], "\n"), "renounced it for Wolves: the ford dried up"), "the register keeps who broke it and why")
	treaty_p_check(findtext(treaty_text(id, T), "Signed for Otters by Cy Lowe"), "the treaty text shows the signatures")

	var/id2 = map.treaty_draft("Wolves", list("Eagles"), "Trade pact", "Free trade.", "Bo Tanner")
	treaty_p_check(map.treaty_refuse(id2, "Eagles", "Ada Reeve") && map.treaty_get(id2)["status"] == "refused" && !map.treaty_sign(id2, "Eagles", "Ada Reeve"), "a refused draft cannot be signed")

	map.treaty_list()["bad"] = list("title" = "x")
	map.treaty_normalize()
	treaty_p_check(!map.treaty_list()["bad"] && map.treaty_get(id), "malformed treaties are dropped")
	map.treaty_rename("Wolves", "Hounds")
	treaty_p_check(("Hounds" in T["parties"]) && !("Wolves" in T["parties"]) && map.treaty_get(id2)["drafted by"] == "Hounds", "treaties follow a faction rename")
