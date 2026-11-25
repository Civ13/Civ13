// Native faction treasury probe, included by tests/ecology_spawning/run_linux.py,
// never by the game DME. It drives code/game/mob/groups/faction_treasury.dm.
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
/obj/map_metadata/treasury_probe/New()
	map = src
/mob/living/human/treasury_probe
	var/obj/item/probe_hand = null
/mob/living/human/treasury_probe/New()
	icon_update = FALSE
	return
/mob/living/human/treasury_probe/get_active_hand()
	return probe_hand
/mob/living/human/treasury_probe/get_inactive_hand()
	return null
/mob/living/human/treasury_probe/restrained()
	return FALSE
/mob/living/human/treasury_probe/put_in_hands(obj/item/W)
	return FALSE
var/treasury_p_failures = 0
var/treasury_p_runtime_error = FALSE
/proc/treasury_p_check(condition, label)
	if (!condition)
		treasury_p_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	treasury_p_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/treasury_probe
		for (var/turf/T in block(locate(1, 1, 1), locate(30, 30, 1)))
			T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
		treasury_p_checks()
	catch(var/exception/e)
		treasury_p_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = treasury_p_failures, "runtime_error" = treasury_p_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/treasury_p_turf_worth(turf/T)
	var/worth = 0
	for (var/obj/item/stack/money/M in T)
		worth += M.amount * M.value
	return round(worth, 0.1)

/proc/treasury_p_checks()
	var/mob/living/human/treasury_probe/L = new(locate(10, 10, 1))
	L.real_name = "Ada Reeve"
	L.stat = CONSCIOUS
	L.civilization = "Eagles"
	L.persistence_owner_ckey = "adareeve"
	map.custom_civs["Eagles"] = list(0, 0, 0, L, 12, 0, 0, 0, 5, 5, list())
	var/mob/living/human/treasury_probe/M = new(locate(11, 10, 1))
	M.real_name = "Bo Tanner"
	M.stat = CONSCIOUS
	M.civilization = "Eagles"
	M.persistence_owner_ckey = "botanner"
	var/mob/living/human/treasury_probe/O = new(locate(9, 10, 1))
	O.real_name = "Cy Outland"
	O.stat = CONSCIOUS
	O.civilization = "Wolves"
	O.persistence_owner_ckey = "cyoutland"

	var/obj/structure/closet/crate/faction_strongbox/B = new(locate(10, 11, 1))
	treasury_p_check(!B.locked && !length(B.faction), "a new strongbox is a plain chest")
	treasury_p_check(B.designate(L, "Eagles"), "the leader designates it")
	treasury_p_check(B.locked && B.anchored && B.name == "strongbox of Eagles", "a designated box locks, anchors and names its faction")
	treasury_p_check(map.faction_strongbox("Eagles") == B, "the faction's strongbox is found")
	treasury_p_check(!B.designate(M, "Eagles"), "a member cannot designate")

	treasury_p_check(B.holds_key(L), "the leader holds the key")
	treasury_p_check(!B.holds_key(M), "an ordinary member does not")
	var/obj/item/weapon/stamp/faction_seal/S = new(locate(11, 10, 1))
	S.seal_faction = "Eagles"
	S.seal_office = "Treasurer"
	S.seal_serial = map.faction_seal_register("Eagles", "Treasurer")
	M.probe_hand = S
	treasury_p_check(B.holds_key(M), "a bearer of the Treasurer's seal holds the key")
	var/list/O_rec = map.office_record("Eagles")
	O_rec["offices"]["Treasurer"] -= "treasury"
	treasury_p_check(!B.holds_key(M), "not once the office loses the treasury power")
	O_rec["offices"]["Treasurer"] += "treasury"
	var/list/R = map.treasury_record("Eagles")
	map.faction_seal_revoke("Eagles", S.seal_serial)
	treasury_p_check(!B.holds_key(M), "nor with a revoked seal")
	O.probe_hand = S
	S.seal_faction = "Eagles"
	treasury_p_check(!B.holds_key(O), "a stolen revoked seal opens nothing")
	M.probe_hand = null
	O.probe_hand = null

	B.collect_taxes(L)
	treasury_p_check(map.custom_civs["Eagles"][5] == 0 && B.coin_worth() == 12, "collecting taxes moves the tax ledger into coin in the box")
	map.custom_civs["Eagles"][5] = 0.5
	B.collect_taxes(L)
	treasury_p_check(map.custom_civs["Eagles"][5] == 0.5 && B.coin_worth() == 12, "a fraction of a coin waits in the ledger")

	map.treasury_set_wage("Eagles", "botanner", "Bo Tanner", 3)
	var/list/wages = R["wages"]
	var/list/row = wages["botanner"]
	row[3] -= 864000 * 2
	treasury_p_check(abs(treasury_wage_accrue(row, recruitment_now()) - 6) < 0.2, "two days at three silver a day owes six")
	row[3] -= 864000 * 30
	treasury_p_check(abs(treasury_wage_accrue(row, recruitment_now()) - 21) < 0.01, "unpaid wages stop at seven days")
	treasury_p_check(map.treasury_set_wage("Eagles", "x", "X", 999) == 50, "wages are capped")

	// A new online character can use an old name held by a legacy saved wage.
	var/list/online_names = list("new_tanner" = "Bo Tanner", "x" = "X")
	var/list/choices = treasury_wage_choices(online_names, wages)
	treasury_p_check(choices.len == 3, "each account appears once including the offline wage under a reused name")
	treasury_p_check(choices["1. Bo Tanner (online)"][1] == "new_tanner" && choices["3. Bo Tanner (saved wage)"][1] == "botanner", "colliding labels resolve to the correct distinct accounts")
	map.treasury_refresh_wage_name("botanner", "Bo Tanner", "Bo Reeve")
	map.treasury_refresh_wage_name("botanner", "Another character", "Different name")
	choices = treasury_wage_choices(online_names, wages)
	treasury_p_check(choices["3. Bo Reeve (saved wage)"][2] == "Bo Reeve" && row[1] == 3 && row[2] == 21, "legal rename changes the label and preserves the rate and accrued balance")

	var/turf/T = get_turf(M)
	B.collect_wages(M)
	treasury_p_check(treasury_p_turf_worth(T) == 12 && B.coin_worth() == 0 && row[2] == 9, "a member collects what the box holds and is owed the rest")
	B.collect_wages(M)
	treasury_p_check(row[2] == 9, "an empty box pays nothing and owes on")

	var/obj/item/stack/money/goldcoin/G = new(B, 3)
	G.apply_coin_mark("Eagles", 1)
	treasury_p_check(B.coin_worth() == 12, "coin put in the box counts")
	var/paid = B.pay_out(5, M)
	treasury_p_check(paid == 4 && B.coin_worth() == 8, "paying out never overpays with a large coin")

	var/obj/item/stack/money/silvercoin/C = new(T, 7)
	M.probe_hand = C
	B.pay_dues(M)
	treasury_p_check(B.coin_worth() == 15 && map.treasury_dues_paid("Eagles", "botanner") == 7, "dues paid go into the box and onto the ledger")
	M.probe_hand = null

	var/list/ledger = R["ledger"]
	treasury_p_check(ledger.len >= 4 && findtext(B.ledger_text(), "Bo Tanner"), "the ledger records who paid and collected")

	R["wages"]["bad"] = list("x")
	R["ledger"] += 5
	map.treasury_normalize()
	treasury_p_check(!("bad" in R["wages"]) && !(5 in R["ledger"]), "malformed rows are dropped")

	map.treasury_rename("Eagles", "Hawks")
	treasury_p_check(B.faction == "Hawks" && B.name == "strongbox of Hawks" && islist(map.treasury_state()["Hawks"]) && !map.treasury_state()["Eagles"], "renaming the faction renames its treasury")

	var/obj/structure/closet/crate/faction_strongbox/B2 = new(locate(12, 11, 1))
	map.custom_civs["Hawks"] = map.custom_civs["Eagles"]
	L.civilization = "Hawks"
	B2.faction = "Hawks"
	B2.update_box_name()
	treasury_p_check(map.faction_strongbox("Hawks") in list(B, B2), "a faction's box is found after the rename")
	qdel(B2)
	treasury_p_check(!(B2 in faction_strongboxes), "a destroyed box leaves the list")
