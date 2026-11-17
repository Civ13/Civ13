// Native faction offices probe, included by tests/ecology_spawning/run_linux.py,
// never by the game DME. It drives code/game/mob/groups/faction_offices.dm.
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
/obj/map_metadata/office_probe/New()
	map = src
/mob/living/human/office_probe
	var/obj/item/probe_hand = null
/mob/living/human/office_probe/New()
	icon_update = FALSE
	return
/mob/living/human/office_probe/get_active_hand()
	return probe_hand
/mob/living/human/office_probe/get_inactive_hand()
	return null
/mob/living/human/office_probe/restrained()
	return FALSE
/mob/living/human/office_probe/put_in_hands(obj/item/W)
	return FALSE
var/office_p_failures = 0
var/office_p_runtime_error = FALSE
/proc/office_p_check(condition, label)
	if (!condition)
		office_p_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	office_p_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/office_probe
		for (var/turf/T in block(locate(1, 1, 1), locate(30, 30, 1)))
			T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
		office_p_checks()
	catch(var/exception/e)
		office_p_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = office_p_failures, "runtime_error" = office_p_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/office_p_member(name, ckey, x)
	var/mob/living/human/office_probe/H = new(locate(x, 10, 1))
	H.real_name = name
	H.name = name
	H.stat = CONSCIOUS
	H.civilization = "Eagles"
	H.persistence_owner_ckey = ckey
	human_mob_list |= H
	return H

/proc/office_p_checks()
	var/mob/living/human/office_probe/L = office_p_member("Ada Reeve", "adareeve", 10)
	map.custom_civs["Eagles"] = list(0, 0, 0, L, 0, 0, 0, 0, 5, 5, list())
	var/mob/living/human/office_probe/M = office_p_member("Bo Tanner", "botanner", 11)
	var/mob/living/human/office_probe/N = office_p_member("Cy Miller", "cymiller", 12)
	office_p_member("Di Weaver", "diweaver", 13)

	var/list/R = map.office_record("Eagles")
	office_p_check(("Treasurer" in R["offices"]) && ("Registrar" in R["offices"]), "a faction starts with a Treasurer and a Registrar")
	office_p_check(map.faction_power(L, "Eagles", "justice") && map.faction_power(L, "Eagles", "mint"), "the leader holds every power")
	office_p_check(!map.faction_power(M, "Eagles", "treasury"), "an ordinary member holds none")

	R["offices"]["Judge"] = list("justice")
	office_p_check(map.office_find("Eagles", "judge") == "Judge", "offices are found without regard to case")
	office_p_check(map.office_appoint("Eagles", "Judge", "botanner", "Bo Tanner", 3), "the leader appoints a judge")
	office_p_check(map.faction_power(M, "Eagles", "justice") && !map.faction_power(M, "Eagles", "treasury"), "an officer holds only the office's powers")
	office_p_check(("Judge" in map.offices_held(M)), "the office shows as held")
	R["holders"]["Judge"][3] = recruitment_now() - 6000 // realtime is good to about a minute
	office_p_check(!map.faction_power(M, "Eagles", "justice"), "an appointment ends with its term")

	var/obj/item/weapon/stamp/faction_seal/S = new(locate(12, 10, 1))
	S.seal_faction = "Eagles"
	S.seal_office = "judge"
	S.seal_serial = map.faction_seal_register("Eagles", "judge")
	N.probe_hand = S
	office_p_check(map.faction_power(N, "Eagles", "justice"), "a seal of an office lends its powers")
	S.seal_office = "Herald"
	office_p_check(!map.faction_power(N, "Eagles", "justice"), "a seal of an office without the power lends nothing")
	N.probe_hand = null

	office_p_check(!map.office_leader_open("Eagles"), "members cannot call a leader election while the leader serves with no term")
	map.faction_roster_add("Eagles", "adareeve")
	var/list/lrow = map.faction_rosters()["Eagles"]["adareeve"]
	lrow[2] = recruitment_now() - 864000 * 2
	office_p_check(!map.office_leader_open("Eagles"), "a leader away for two days still serves")
	lrow[2] = recruitment_now() - 864000 * 4
	office_p_check(map.office_leader_away("Eagles") && map.office_leader_open("Eagles"), "members can call a leader election once the leader has been away over three days")
	map.faction_rosters()["Eagles"] -= "adareeve"
	map.office_leader_since("Eagles")
	R["leader"][2] = recruitment_now() - 864000 * 4
	office_p_check(map.office_leader_open("Eagles"), "without a roster row, away counts from when the leadership began")
	R["leader"][2] = recruitment_now()
	office_p_check(!map.office_leader_open("Eagles"), "a new leader is not away")
	R["term"] = 1
	map.office_leader_since("Eagles")
	R["leader"][2] = recruitment_now() - 864000 * 2
	office_p_check(map.office_leader_open("Eagles"), "they can once the leader's term has run out")

	office_p_check(map.office_election_open("Eagles", "Leader"), "a leader election opens")
	office_p_check(!map.office_election_open("Eagles", "Judge"), "only one election at a time")
	office_p_check(map.office_stand("Eagles", "adareeve", "Ada Reeve") && map.office_stand("Eagles", "botanner", "Bo Tanner"), "members stand")
	office_p_check(!map.office_stand("Eagles", "botanner", "Bo Tanner"), "nobody stands twice")
	office_p_check(map.office_vote("Eagles", "botanner", "botanner") && map.office_vote("Eagles", "cymiller", "botanner") && map.office_vote("Eagles", "diweaver", "adareeve"), "members vote")
	office_p_check(!map.office_vote("Eagles", "cymiller", "adareeve"), "nobody votes twice")
	office_p_check(!map.office_vote("Eagles", "adareeve", "cymiller"), "votes go only to candidates")
	office_p_check(map.office_election_close("Eagles") == "botanner", "the most votes wins")
	office_p_check(map.is_faction_leader(M, "Eagles") && !map.is_faction_leader(L, "Eagles"), "the elected leader takes the leadership")
	office_p_check(!map.office_leader_open("Eagles"), "a new term begins")

	R["offices"]["Judge"] = list("justice")
	map.office_election_open("Eagles", "judge")
	map.office_stand("Eagles", "cymiller", "Cy Miller")
	map.office_stand("Eagles", "diweaver", "Di Weaver")
	map.office_vote("Eagles", "adareeve", "diweaver")
	map.office_vote("Eagles", "botanner", "cymiller")
	office_p_check(map.office_election_close("Eagles") == "cymiller", "a tie goes to whoever stood first")
	office_p_check(map.faction_power(N, "Eagles", "justice") && R["holders"]["Judge"][3] > recruitment_now(), "the elected officer serves the faction's term")

	map.office_election_open("Eagles", "Judge")
	R["election"][2] = recruitment_now() - 6000
	office_p_check(!map.office_election("Eagles") && !R["election"], "an overdue election closes when looked at")

	R["offices"]["Odd"] = list("justice", "flying")
	R["holders"]["Gone"] = list("x", "y", 0)
	map.office_normalize()
	office_p_check(!("flying" in R["offices"]["Odd"]) && !("Gone" in R["holders"]), "unknown powers and holders of missing offices are dropped")
	map.office_rename("Eagles", "Hawks")
	office_p_check(islist(map.office_state()["Hawks"]) && !map.office_state()["Eagles"], "offices follow a faction rename")
	office_p_check(office_name_clean("leader") == "" && office_name_clean("Tax | Collector") == "Tax / Collector", "no office may be called Leader, and names are cleaned")
