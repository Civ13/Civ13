// Native land registry probe, included by tests/ecology_spawning/run_linux.py,
// never by the game DME. It drives code/game/mob/groups/land_registry.dm.
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
/obj/map_metadata/land_probe/New()
	map = src
/mob/living/human/land_probe
	var/obj/item/probe_hand = null
/mob/living/human/land_probe/New()
	icon_update = FALSE
	return
/mob/living/human/land_probe/get_active_hand()
	return probe_hand
/mob/living/human/land_probe/get_inactive_hand()
	return null
/mob/living/human/land_probe/restrained()
	return FALSE
/mob/living/human/land_probe/put_in_hands(obj/item/W)
	return FALSE
var/land_p_failures = 0
var/land_p_runtime_error = FALSE
/proc/land_p_check(condition, label)
	if (!condition)
		land_p_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	land_p_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/land_probe
		for (var/turf/T in block(locate(1, 1, 1), locate(30, 30, 1)))
			T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
		land_p_checks()
	catch(var/exception/e)
		land_p_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = land_p_failures, "runtime_error" = land_p_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/land_p_checks()
	var/mob/living/human/land_probe/L = new(locate(10, 10, 1))
	L.real_name = "Ada Reeve"
	L.stat = CONSCIOUS
	L.civilization = "Eagles"
	map.custom_civs["Eagles"] = list(0, 0, 0, L, 0, 0, 0, 0, 5, 5, list())
	var/mob/living/human/land_probe/M = new(locate(4, 4, 1))
	M.real_name = "Bo Tanner"
	M.stat = CONSCIOUS
	M.civilization = "Eagles"

	land_p_check(map.faction_power(L, "Eagles", "registry"), "the leader acts as registrar")
	land_p_check(!map.faction_power(M, "Eagles", "registry"), "an ordinary member does not")
	var/obj/item/weapon/stamp/faction_seal/S = new(locate(4, 4, 1))
	S.seal_faction = "Eagles"
	S.seal_office = "Registrar"
	S.seal_serial = map.faction_seal_register("Eagles", "Registrar")
	M.probe_hand = S
	land_p_check(map.faction_power(M, "Eagles", "registry"), "a bearer of the Registrar's seal does")
	M.probe_hand = null

	var/id = map.land_register("Eagles", "the mill", locate(8, 2, 1), locate(2, 6, 1), "Ada Reeve")
	var/list/row = map.land_plot("Eagles", id)
	land_p_check(id == "1" && row && row[2] == 2 && row[3] == 2 && row[4] == 8 && row[5] == 6 && row[1] == "the mill", "a plot is registered between two corners in any order")
	land_p_check(copytext(map.land_register("Eagles", "", locate(5, 5, 1), locate(12, 12, 1), ""), 1, 2) == "!", "an overlapping plot is refused")
	land_p_check(copytext(map.land_register("Eagles", "", locate(1, 1, 1), locate(1, 1, 1), ""), 1, 2) == "!", "a plot too small is refused")
	var/list/at = map.land_plot_at(locate(3, 3, 1))
	land_p_check(at && at[1] == "Eagles" && at[2] == "1", "the plot covering a tile is found")
	land_p_check(!map.land_plot_at(locate(20, 20, 1)), "open land belongs to no plot")
	var/id2 = map.land_register("Eagles", "", locate(10, 10, 1), locate(12, 12, 1), "")
	land_p_check(id2 == "2" && map.land_plot("Eagles", id2)[1] == "Plot 2", "an unnamed plot takes its number")

	var/obj/item/land_deed/D = map.land_issue_deed("Eagles", id, locate(4, 4, 1))
	land_p_check(D.verdict() == "valid" && D.name == "deed to the mill", "a new deed is valid")
	row[7]++
	land_p_check(D.verdict() == "void", "a reissued plot voids the old deed")
	var/obj/item/land_deed/D2 = map.land_issue_deed("Eagles", id, locate(4, 4, 1))
	land_p_check(D2.verdict() == "valid", "the new deed is valid")

	var/obj/structure/closet/crate/C = new(locate(5, 4, 1))
	var/obj/structure/closet/crate/far = new(locate(9, 4, 1))
	var/obj/structure/closet/crate/faction_strongbox/B = new(locate(3, 4, 1))
	var/obj/structure/simple_door/key_door/custom/jail/woodjail/J = new(locate(4, 5, 1))
	var/list/locks = D2.lockables(M)
	var/list/found = list()
	for (var/k in locks)
		found += locks[k]
	land_p_check((C in found) && !(far in found) && !(B in found) && !(J in found), "the deed works chests on its land, not off it, nor the strongbox or jails")
	land_p_check(!D.lockables(M).len, "a void deed works no locks")

	row[8] = 5
	row[9] = recruitment_now() - 6048000 * 2
	land_p_check(abs(land_tax_owed(row, recruitment_now()) - 10) < 0.1, "two weeks at five silver owes ten")
	land_tax_pay(row, 4)
	land_p_check(abs(land_tax_owed(row, recruitment_now()) - 6) < 0.1, "paying four leaves six owed")
	land_tax_pay(row, 20)
	land_p_check(land_tax_owed(row, recruitment_now()) == 0, "paying ahead leaves nothing owed")

	map.land_plots("Eagles")["bad"] = list(1, 2)
	map.land_normalize()
	land_p_check(!("bad" in map.land_plots("Eagles")) && map.land_plot("Eagles", id), "malformed plots are dropped and good ones kept")
	map.land_rename("Eagles", "Hawks")
	land_p_check(map.land_plot("Hawks", id) && D2.faction == "Hawks" && D2.verdict() == "valid", "a faction rename keeps its plots and deeds")
