// Native faction seal probe, included by tests/ecology_spawning/run_linux.py,
// never by the game DME. It drives code/modules/paperwork/faction_seals.dm.
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
/obj/map_metadata/seal_probe/New()
	map = src
/mob/living/human/seal_probe
	var/obj/item/probe_hand = null
/mob/living/human/seal_probe/New()
	icon_update = FALSE
	return
/mob/living/human/seal_probe/get_active_hand()
	return probe_hand
/mob/living/human/seal_probe/restrained()
	return FALSE
var/seal_failures = 0
var/seal_runtime_error = FALSE
/proc/seal_check(condition, label)
	if (!condition)
		seal_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	seal_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/seal_probe
		for (var/turf/T in block(locate(1, 1, 1), locate(30, 30, 1)))
			T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
		seal_checks()
	catch(var/exception/e)
		seal_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = seal_failures, "runtime_error" = seal_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/seal_probe_stamp(mob/living/human/seal_probe/H, obj/item/weapon/stamp/S)
	var/obj/item/weapon/paper/P = new(get_turf(H))
	H.probe_hand = S
	S.forceMove(H)
	var/result = paper_document_apply_stamp(P, S, H)
	return result == "stamped" ? P : null

/proc/seal_checks()
	var/mob/living/human/seal_probe/H = new(locate(10, 10, 1))
	H.real_name = "Ada Reeve"
	H.stat = CONSCIOUS
	H.civilization = "Eagles"
	map.custom_civs["Eagles"] = list(0, 0, 0, H, 0, 0, 0, 0, 0, 0, list())
	seal_check(map.can_manage_faction_seals(H, "Eagles"), "the leader may manage the faction's seals")
	var/mob/living/human/seal_probe/other = new(locate(11, 10, 1))
	other.civilization = "Eagles"
	seal_check(!map.can_manage_faction_seals(other, "Eagles"), "an ordinary member may not")

	seal_check(faction_seal_office_clean("Tax | Collector") == "Tax / Collector", "office names cannot carry the record separator")
	seal_check(faction_seal_office_clean("") == "", "an empty office is refused")

	var/serial = map.faction_seal_register("Eagles", "Leader")
	seal_check(serial == "1", "the first seal is no. 1")
	var/obj/item/weapon/stamp/faction_seal/S = new(locate(10, 10, 1))
	S.seal_faction = "Eagles"
	S.seal_office = "Leader"
	S.seal_serial = serial
	S.update_seal_name()
	seal_check(S.name == "seal of Eagles (Leader)", "a cut seal names its faction and office")
	seal_check(S.impression_state() == "seal-court", "a faction seal leaves the court seal impression")

	var/obj/item/weapon/paper/P = seal_probe_stamp(H, S)
	seal_check(P && islist(P.seal_records) && P.seal_records.len == 1, "a seal impression is recorded on the paper")
	seal_check(P && ("seal-court" in P.stamped), "the impression is drawn like any stamp")
	seal_check(P && findtext(faction_seal_verdict(P.seal_records[1]), "<b>impression matches the current register</b>; does not authenticate the current contents"), "a seal in force verifies only the impression")

	var/obj/item/weapon/stamp/faction_seal/blank = new(locate(10, 10, 1))
	var/obj/item/weapon/paper/B = seal_probe_stamp(H, blank)
	seal_check(B && !length(B.seal_records), "an uncut matrix leaves no record")
	seal_check(B && findtext(faction_seal_check_text(B), "no seal record"), "an unrecorded impression is reported as unproven")

	seal_check(map.faction_seal_revoke("Eagles", serial), "the leader can revoke a seal")
	seal_check(!map.faction_seal_revoke("Eagles", serial), "a revoked seal cannot be revoked again")
	seal_check(findtext(faction_seal_verdict(P.seal_records[1]), "<b>impression matches the current register</b>"), "papers sealed before the revocation stay good")
	var/obj/item/weapon/paper/late = seal_probe_stamp(H, S)
	seal_check(late && findtext(faction_seal_verdict(late.seal_records[1]), "<b>void</b>"), "a revoked seal's new impressions are void")

	seal_check(findtext(faction_seal_verdict("Wolves|Leader|1|[num2text(world.realtime, 12)]|1"), "<b>unknown</b>"), "a seal the faction never cut is unknown")
	var/serial2 = map.faction_seal_register("Eagles", "Treasurer")
	seal_check(findtext(faction_seal_verdict("Eagles|Leader|[serial2]|[num2text(world.realtime, 12)]|1"), "does not match"), "a seal claiming the wrong office does not match")
	seal_check(!faction_seal_verdict("broken"), "a malformed record is ignored")

	var/obj/item/weapon/stamp/faction_seal/T = new(locate(10, 10, 1))
	T.seal_faction = "Eagles"
	T.seal_office = "Treasurer"
	T.seal_serial = serial2
	map.faction_seal_rename("Eagles", "Hawks")
	seal_check(map.faction_seal_row("Hawks", serial2) && !map.faction_seal_row("Eagles", serial2), "renaming a faction moves its seal register")
	seal_check(T.seal_faction == "Hawks" && T.name == "seal of Hawks (Treasurer)", "renaming a faction renames its seals")

	var/full = 0
	for (var/i in 1 to 40)
		if (map.faction_seal_register("Hawks", "Clerk"))
			full++
	seal_check(full == 23, "a faction keeps at most 24 seals in force")

	var/list/seals = map.faction_seal_state()
	var/list/hawk_rows = seals["Hawks"]
	hawk_rows["junk"] = "bad"
	seals["Ghosts"] = "not a list"
	map.faction_seal_normalize()
	seal_check(!("junk" in hawk_rows) && !("Ghosts" in seals) && map.faction_seal_row("Hawks", serial2), "normalize drops malformed rows and keeps good ones")
