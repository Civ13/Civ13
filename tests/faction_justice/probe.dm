// Native faction justice probe, included by tests/ecology_spawning/run_linux.py,
// never by the game DME. It drives code/game/mob/groups/faction_justice.dm.
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
/obj/map_metadata/justice_probe/New()
	map = src
/mob/living/human/justice_probe
	var/obj/item/probe_hand = null
/mob/living/human/justice_probe/New()
	icon_update = FALSE
	return
/mob/living/human/justice_probe/get_active_hand()
	return probe_hand
/mob/living/human/justice_probe/get_inactive_hand()
	return null
/mob/living/human/justice_probe/restrained()
	return FALSE
/mob/living/human/justice_probe/put_in_hands(obj/item/W)
	return FALSE
var/justice_p_failures = 0
var/justice_p_runtime_error = FALSE
/proc/justice_p_check(condition, label)
	if (!condition)
		justice_p_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	justice_p_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/justice_probe
		for (var/turf/T in block(locate(1, 1, 1), locate(30, 30, 1)))
			T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
		justice_p_checks()
	catch(var/exception/e)
		justice_p_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = justice_p_failures, "runtime_error" = justice_p_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/justice_p_member(name, ckey, x)
	var/mob/living/human/justice_probe/H = new(locate(x, 10, 1))
	H.real_name = name
	H.name = name
	H.stat = CONSCIOUS
	H.civilization = "Eagles"
	H.persistence_owner_ckey = ckey
	human_mob_list |= H
	return H

/proc/justice_p_checks()
	map.civilizations = TRUE // a civilization world, not a team round
	var/mob/living/human/justice_probe/L = justice_p_member("Ada Reeve", "adareeve", 10)
	map.custom_civs["Eagles"] = list(0, 0, 0, L, 0, 0, 0, 0, 5, 5, list())
	var/mob/living/human/justice_probe/J = justice_p_member("Bo Tanner", "botanner", 11)
	var/mob/living/human/justice_probe/A = justice_p_member("Cy Miller", "cymiller", 12)
	A.civilization = "Wolves"

	justice_p_check(!justice_can_jail(J), "an ordinary member cannot set cell timers")
	var/list/O = map.office_record("Eagles")
	O["offices"]["Judge"] = list("justice")
	map.office_appoint("Eagles", "Judge", "botanner", "Bo Tanner", 0)
	justice_p_check(justice_can_jail(J) && can_set_cell_timer(J), "a judge can set cell timers")
	justice_p_check(can_set_cell_timer(L), "so can the leader")

	justice_p_check(map.justice_warrant("Eagles", "cymiller", "Cy Miller", "theft", "Bo Tanner"), "a warrant is issued")
	var/list/lines = justice_examine_lines(A)
	justice_p_check(lines.len == 1 && findtext(lines[1], "warrant"), "examining the wanted person shows the warrant")

	var/line = map.justice_sentence("Eagles", "cymiller", "Cy Miller", "theft", "Fine", 30, "Bo Tanner")
	var/list/R = map.justice_record("Eagles")
	justice_p_check(findtext(line, "fined 30 silver") && R["fines"]["cymiller"][2] == 30 && !R["warrants"]["cymiller"], "a fine is recorded and the warrant ends")
	justice_p_check(!justice_examine_lines(A).len, "a fined person is not wanted")
	map.justice_sentence("Eagles", "cymiller", "Cy Miller", "theft", "Fine", 9999, "Bo Tanner")
	justice_p_check(R["fines"]["cymiller"][2] == 530, "fines add up, each capped")
	justice_p_check(map.justice_pay_fine("Eagles", "cymiller", 30) == 500, "paying part leaves the rest")
	justice_p_check(map.justice_pay_fine("Eagles", "cymiller", 600) == 0 && !R["fines"]["cymiller"], "paying in full clears the fine")

	map.justice_sentence("Eagles", "cymiller", "Cy Miller", "murder", "Outlawry", 0, "Bo Tanner")
	lines = justice_examine_lines(A)
	justice_p_check(lines.len == 1 && findtext(lines[1], "outlaw of Eagles"), "an outlaw is shown as one")
	justice_p_check(findtext(map.justice_sentence("Eagles", "cymiller", "Cy Miller", "x", "Jail", 99, "Bo Tanner"), "30 minutes"), "jail is capped at 30 minutes")
	justice_p_check(map.justice_pardon("Eagles", "cymiller", "Ada Reeve") == "Cy Miller" && !justice_examine_lines(A).len, "a pardon clears everything")
	justice_p_check(!map.justice_pardon("Eagles", "nobody", "Ada Reeve"), "nobody to pardon, nothing happens")
	var/list/record = R["record"]
	justice_p_check(record.len >= 5 && findtext(record[record.len], "pardoned Cy Miller"), "the court record keeps every ruling")

	var/obj/item/weapon/paper/P = justice_paper(locate(5, 5, 1), "wanted: Cy Miller", justice_warrant_text("Eagles", "Cy <b>Miller</b>", "theft", "Bo Tanner"))
	justice_p_check(P.name == "wanted: Cy Miller" && findtext(P.info, "WANTED") && !findtext(P.info, "<b>Miller"), "a warrant prints as a wanted poster with names escaped")

	justice_p_check(justice_text_clean("  steal no horses  ") == "steal no horses", "laws are trimmed")
	R["warrants"]["bad"] = list("x")
	R["fines"]["zero"] = list("Z", 0)
	R["laws"] += 7
	map.justice_normalize()
	justice_p_check(!R["warrants"]["bad"] && !R["fines"]["zero"] && !(7 in R["laws"]), "malformed rows are dropped")
	var/list/laws = R["laws"]
	laws += list("Cancel", "Something else", "Cancel", "No theft")
	var/list/offered = laws.Copy()
	var/list/options = justice_law_choices(offered)
	justice_p_check(!("Cancel" in options) && !("Something else" in options) && options["1. Cancel"] == 1 && options["2. Something else"] == 2 && options["3. Cancel"] == 3, "reserved words and duplicate laws have independent choice labels")
	justice_p_check(isnull(justice_repeal_law_at(laws, offered, options["Cancel"])) && laws.len == 4, "the cancel control cannot repeal a law named Cancel")
	justice_p_check(justice_repeal_law_at(laws, offered, options["3. Cancel"]) == "Cancel" && laws.len == 3 && laws[1] == "Cancel", "repealing one duplicate leaves the other intact")
	justice_p_check(isnull(justice_repeal_law_at(laws, offered, options["2. Something else"])) && laws.len == 3 && laws[2] == "Something else", "a concurrent repeal invalidates a stale numbered choice")
	var/list/reordered = offered.Copy()
	reordered.Swap(1, 2)
	justice_p_check(isnull(justice_repeal_law_at(reordered, offered, options["3. Cancel"])) && reordered.len == 4, "an equal-length concurrent reorder also invalidates the menu")
	var/literal_warrant = offered[options["2. Something else"]]
	map.justice_warrant("Eagles", "cymiller", "Cy Miller", literal_warrant, "Bo Tanner")
	justice_p_check(R["warrants"]["cymiller"][2] == "Something else", "the warrant records the original law, not its numbered label or control")
	var/literal_trial = offered[options["1. Cancel"]]
	var/sentence = map.justice_sentence("Eagles", "cymiller", "Cy Miller", literal_trial, "Warning", 0, "Bo Tanner")
	var/latest_record = record[record.len]
	var/judgment = justice_judgment_text("Eagles", "Cy Miller", literal_trial, sentence, "Bo Tanner")
	justice_p_check(findtext(latest_record, "guilty of Cancel:") && findtext(judgment, "Cancel") && !findtext(judgment, "1. Cancel"), "the trial log and paper keep the original Cancel law without its display label")
	map.justice_rename("Eagles", "Hawks")
	justice_p_check(islist(map.justice_state()["Hawks"]) && !map.justice_state()["Eagles"], "the court follows a faction rename")
