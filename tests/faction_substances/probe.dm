// Native faction substances probe, included by tests/ecology_spawning/run_linux.py,
// never by the game DME. It drives code/game/mob/groups/faction_substances.dm.
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
/obj/map_metadata/subst_probe/New()
	map = src
/mob/living/human/subst_probe
	var/obj/item/probe_hand = null
/mob/living/human/subst_probe/New()
	icon_update = FALSE
	bloodstr = new/datum/reagents/metabolism(1000, src, CHEM_BLOOD)
	ingested = new/datum/reagents/metabolism(1000, src, CHEM_INGEST)
	touching = new/datum/reagents/metabolism(1000, src, CHEM_TOUCH)
	reagents = bloodstr
	return
/mob/living/human/subst_probe/get_active_hand()
	return probe_hand
/mob/living/human/subst_probe/get_inactive_hand()
	return null
/mob/living/human/subst_probe/restrained()
	return FALSE
/mob/living/human/subst_probe/put_in_hands(obj/item/W)
	return FALSE
var/subst_p_failures = 0
var/subst_p_runtime_error = FALSE
/proc/subst_p_check(condition, label)
	if (!condition)
		subst_p_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	subst_p_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/subst_probe
		for (var/turf/T in block(locate(1, 1, 1), locate(30, 30, 1)))
			T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
		initialize_chemical_reactions()
		subst_p_checks()
	catch(var/exception/e)
		subst_p_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = subst_p_failures, "runtime_error" = subst_p_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/subst_p_person(name, ckey, x, faction)
	var/mob/living/human/subst_probe/H = new(locate(x, 10, 1))
	H.real_name = name
	H.name = name
	H.stat = CONSCIOUS
	H.civilization = faction
	H.persistence_owner_ckey = ckey
	human_mob_list |= H
	return H

/proc/subst_p_checks()
	var/mob/living/human/subst_probe/L = subst_p_person("Ada Reeve", "adareeve", 10, "Eagles")
	map.custom_civs["Eagles"] = list(0, 0, 0, L, 0, 0, 0, 0, 5, 5, list())
	map.land_register("Eagles", "the market", locate(5, 5, 1), locate(15, 15, 1), "Ada Reeve")
	var/turf/inside = locate(11, 10, 1)
	var/turf/outside = locate(25, 25, 1)
	var/obj/item/weapon/reagent_containers/pill/opium/O = new(inside)
	var/obj/item/stack/material/coca/C = new(inside, 2)
	var/obj/item/stack/material/wood/W = new(inside, 2)
	var/obj/item/weapon/reagent_containers/glass/beaker/B = new(inside)
	B.reagents.add_reagent("ethanol", 5)

	subst_p_check(("opioid" in item_substance_classes(O)) && ("stimulant" in item_substance_classes(C)) && !length(item_substance_classes(W)), "items know their drug class, raw crops included")
	subst_p_check("alcohol" in item_substance_classes(B), "drinks count as alcohol")
	subst_p_check(!item_substance_rule(O, inside) && map.substance_rule("Eagles", "opioid") == "allowed", "everything is allowed by default")
	subst_p_check(!item_sniffable(O, inside) && item_sniffable(O, outside), "dogs only sniff the old contraband list off faction land")
	map.substance_set_rule("Eagles", "opioid", "banned")
	map.substance_set_rule("Eagles", "alcohol", "licensed")
	var/list/rule = item_substance_rule(O, inside)
	subst_p_check(rule && rule[1] == "Eagles" && rule[2] == "banned", "a banned class shows on the land")
	subst_p_check(item_sniffable(O, inside) && !item_sniffable(C, inside), "dogs sniff for what the faction bans there")
	rule = item_substance_rule(B, inside)
	subst_p_check(rule && rule[2] == "licensed" && !item_sniffable(B, inside), "a licensed class is not sniffed")
	subst_p_check(!item_substance_rule(O, outside), "off the land nothing applies")
	var/list/lines = map.substance_rule_lines("Eagles")
	subst_p_check(lines.len == 2 && findtext(jointext(lines, " "), "opiates are banned") && findtext(jointext(lines, " "), "substance licence"), "the rules are listed with the laws")
	var/serial = map.papers_issue("Eagles", "substance", "Cy Trader", "cytrader", 0, "Ada Reeve")
	subst_p_check(serial && map.papers_row("Eagles", serial)[1] == "substance", "a substance licence is a faction paper")
	map.papers_record("Eagles")["substances"]["nonsense"] = "banned"
	map.papers_record("Eagles")["substances"]["cannabis"] = "maybe"
	map.papers_normalize()
	subst_p_check(!("nonsense" in map.substance_rules("Eagles")) && !("cannabis" in map.substance_rules("Eagles")) && map.substance_rule("Eagles", "opioid") == "banned", "bad rules are dropped on load")
	map.substance_set_rule("Eagles", "opioid", "allowed")
	subst_p_check(!item_substance_rule(O, inside), "a ban can be lifted")
	subst_p_check(!map.substance_set_rule("Eagles", "caffeine", "banned"), "only listed classes can be ruled on")
