// Native faction permits probe, included by tests/ecology_spawning/run_linux.py,
// never by the game DME. It drives code/game/mob/groups/faction_permits.dm.
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
/obj/map_metadata/permit_probe/New()
	map = src
/mob/living/human/permit_probe
	var/obj/item/probe_hand = null
/mob/living/human/permit_probe/New()
	icon_update = FALSE
	return
/mob/living/human/permit_probe/get_active_hand()
	return probe_hand
/mob/living/human/permit_probe/get_inactive_hand()
	return null
/mob/living/human/permit_probe/restrained()
	return FALSE
/mob/living/human/permit_probe/put_in_hands(obj/item/W)
	return FALSE
var/permit_p_failures = 0
var/permit_p_runtime_error = FALSE
/proc/permit_p_check(condition, label)
	if (!condition)
		permit_p_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	permit_p_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/permit_probe
		for (var/turf/T in block(locate(1, 1, 1), locate(30, 30, 1)))
			T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
		permit_p_checks()
	catch(var/exception/e)
		permit_p_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = permit_p_failures, "runtime_error" = permit_p_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/permit_p_person(name, ckey, x, faction)
	var/mob/living/human/permit_probe/H = new(locate(x, 10, 1))
	H.real_name = name
	H.name = name
	H.stat = CONSCIOUS
	H.civilization = faction
	H.persistence_owner_ckey = ckey
	human_mob_list |= H
	return H

/proc/permit_p_checks()
	var/mob/living/human/permit_probe/L = permit_p_person("Ada Reeve", "adareeve", 10, "Eagles")
	map.custom_civs["Eagles"] = list(0, 0, 0, L, 0, 0, 0, 0, 5, 5, list())
	var/mob/living/human/permit_probe/O = permit_p_person("Cy Trader", "cytrader", 11, "Wolves")
	var/plot = map.land_register("Eagles", "the market", locate(5, 5, 1), locate(15, 15, 1), "Ada Reeve")
	var/turf/inside = locate(11, 10, 1)
	var/turf/outside = locate(25, 25, 1)
	var/datum/stack_recipe/wall = new
	wall.title = "wood wall"
	wall.result_type = /obj/structure/simple_door/fence
	var/datum/stack_recipe/stall = new
	stall.title = "market stall"
	stall.result_type = /obj/structure/vending/sales/market_stall
	var/datum/stack_recipe/knife = new
	knife.title = "knife"
	knife.result_type = /obj/item/weapon/material/kitchen/utensil/knife // paper now needs water to make

	permit_p_check(!permit_missing(O, inside, "build") && !craft_guard_refusal(O, wall, CRAFT_GUARD_START), "permits are off by default")
	map.permit_set_required("Eagles", "build", TRUE)
	permit_p_check(permit_missing(O, inside, "build") == "Eagles" && craft_guard_refusal(O, wall, CRAFT_GUARD_START), "an outsider can't build on the land once permits are required")
	permit_p_check(craft_guard_refusal(O, wall, CRAFT_GUARD_FINISH) == "", "and is refused again, silently, after the wait")
	permit_p_check(!craft_guard_refusal(O, stall, CRAFT_GUARD_START), "a stall needs a trading licence, not a building permit")
	permit_p_check(!craft_guard_refusal(O, knife, CRAFT_GUARD_START), "items are never guarded")
	permit_p_check(!permit_missing(L, inside, "build"), "members never need a permit")
	O.forceMove(outside)
	permit_p_check(!craft_guard_refusal(O, wall, CRAFT_GUARD_START), "off the registered land nothing is needed")
	O.forceMove(inside)

	var/serial = map.papers_issue("Eagles", "build", "Cy Trader", "cytrader", 0, "Ada Reeve")
	var/obj/item/faction_papers/P = map.papers_make("Eagles", serial, O)
	permit_p_check(P.name == "building permit of Eagles for Cy Trader" && !map.papers_row("Eagles", serial)[5], "a permit with no days lasts until revoked")
	permit_p_check(!craft_guard_refusal(O, wall, CRAFT_GUARD_START), "a building permit lets an outsider build")
	var/obj/structure/simple_door/key_door/faction_door/D = new(locate(20, 20, 1))
	D.faction = "Eagles"
	D.admits = 2
	permit_p_check(!D.faction_door_admits(O), "a permit opens no border door")
	map.papers_revoke("Eagles", serial)
	permit_p_check(craft_guard_refusal(O, wall, CRAFT_GUARD_START), "a revoked permit counts for nothing")

	map.permit_set_required("Eagles", "trade", TRUE)
	permit_p_check(craft_guard_refusal(O, stall, CRAFT_GUARD_START), "a stall needs a trading licence once required")
	var/lic = map.papers_issue("Eagles", "trade", "Cy Trader", "cytrader", 5, "Ada Reeve")
	map.papers_make("Eagles", lic, O)
	permit_p_check(!craft_guard_refusal(O, stall, CRAFT_GUARD_START) && map.papers_row("Eagles", lic)[5] > recruitment_now(), "a trading licence for some days lets them set up")

	var/obj/item/land_deed/deed = map.land_issue_deed("Eagles", plot, O)
	permit_p_check(istype(deed) && !craft_guard_refusal(O, wall, CRAFT_GUARD_START), "the plot's deed holder needs no permit")
	qdel(deed)
	map.papers_record("Eagles")["require"] += "nonsense"
	map.papers_normalize()
	permit_p_check(!("nonsense" in map.papers_record("Eagles")["require"]) && map.permit_required("Eagles", "build"), "unknown requirements are dropped")
	map.permit_set_required("Eagles", "build", FALSE)
	permit_p_check(!map.permit_required("Eagles", "build") && map.permit_required("Eagles", "trade"), "a requirement can be lifted")
	map.papers_rename("Eagles", "Hawks")
	permit_p_check(map.permit_required("Hawks", "trade"), "requirements follow a faction rename")
