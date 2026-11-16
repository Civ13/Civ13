// Native faction bills probe, included by tests/ecology_spawning/run_linux.py,
// never by the game DME. It drives code/game/mob/groups/faction_bills.dm.
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
/obj/map_metadata/bill_probe/New()
	map = src
/mob/living/human/bill_probe
	var/obj/item/probe_hand = null
/mob/living/human/bill_probe/New()
	icon_update = FALSE
	return
/mob/living/human/bill_probe/get_active_hand()
	return probe_hand
/mob/living/human/bill_probe/get_inactive_hand()
	return null
/mob/living/human/bill_probe/restrained()
	return FALSE
/mob/living/human/bill_probe/put_in_hands(obj/item/W)
	return FALSE
var/bill_p_failures = 0
var/bill_p_runtime_error = FALSE
/proc/bill_p_check(condition, label)
	if (!condition)
		bill_p_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	bill_p_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/bill_probe
		for (var/turf/T in block(locate(1, 1, 1), locate(30, 30, 1)))
			T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
		bill_p_checks()
	catch(var/exception/e)
		bill_p_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = bill_p_failures, "runtime_error" = bill_p_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/bill_p_member(name, ckey, x)
	var/mob/living/human/bill_probe/H = new(locate(x, 10, 1))
	H.real_name = name
	H.name = name
	H.stat = CONSCIOUS
	H.civilization = "Eagles"
	H.persistence_owner_ckey = ckey
	human_mob_list |= H
	return H

/proc/bill_p_turf_worth(turf/T)
	var/worth = 0
	for (var/obj/item/stack/money/M in T)
		worth += M.amount * M.value
	return round(worth, 0.1)

/proc/bill_p_checks()
	var/mob/living/human/bill_probe/L = bill_p_member("Ada Reeve", "adareeve", 10)
	map.custom_civs["Eagles"] = list(0, 0, 0, L, 0, 0, 0, 0, 5, 5, list())
	var/mob/living/human/bill_probe/T = bill_p_member("Cy Trader", "cytrader", 5)
	T.civilization = "Wolves"
	var/obj/structure/closet/crate/faction_strongbox/B = new(locate(10, 11, 1))
	B.designate(L, "Eagles")
	var/obj/item/stack/money/silvercoin/S = new(B, 15)
	S.apply_coin_mark("Eagles", 1)

	var/serial = map.bill_draw("Eagles", 10, "Ada Reeve")
	var/obj/item/faction_bill/bill = map.bill_make("Eagles", serial, 10, locate(5, 5, 1))
	bill_p_check(serial == "1" && bill.owed() == 10 && bill.name == "bill of exchange on Eagles for 10 silver", "a bill is drawn and registered")
	bill_p_check(map.bills_outstanding("Eagles") == 10, "the ledger counts what is promised")
	var/obj/item/faction_bill/fake = map.bill_make("Eagles", "99", 500, locate(5, 5, 1))
	bill_p_check(fake.owed() == 0, "a bill the register does not know is worth nothing")

	var/turf/feet = get_turf(T)
	bill_p_check(B.redeem_bill(bill, T) && bill_p_turf_worth(feet) == 10 && QDELETED(bill), "an outsider redeems a bill at the box and it is torn up")
	bill_p_check(B.coin_worth() == 5 && !map.bill_row("Eagles", serial), "the coin leaves the box and the bill closes")

	var/serial2 = map.bill_draw("Eagles", 12, "Ada Reeve")
	var/obj/item/faction_bill/big = map.bill_make("Eagles", serial2, 12, locate(5, 5, 1))
	B.redeem_bill(big, T)
	bill_p_check(!QDELETED(big) && big.owed() == 7 && B.coin_worth() == 0, "a run: the box pays what it holds and owes the rest")
	B.redeem_bill(big, T)
	bill_p_check(big.owed() == 7, "an empty box pays nothing")
	var/obj/item/stack/money/silvercoin/S2 = new(B, 10)
	S2.apply_coin_mark("Eagles", 1)
	B.redeem_bill(big, T)
	bill_p_check(QDELETED(big) && B.coin_worth() == 3, "refilled, the box pays the rest")

	var/obj/item/faction_bill/other = map.bill_make("Wolves", "1", 5, locate(5, 5, 1))
	bill_p_check(!B.redeem_bill(other, T), "a bill on another faction is not paid here")

	var/obj/item/weapon/paper/P = new(get_turf(T))
	var/obj/item/weapon/paper/W = new(get_turf(T))
	W.info = "a letter"
	var/list/blank = bill_blank_supply(T)
	bill_p_check(blank.len == 1 && (P in blank), "only blank sheets can become bills")

	bill_p_check(map.bill_draw("Eagles", 9999, "x") && map.bill_row("Eagles", "3")[1] == 500, "a bill is capped at 500 silver")
	map.bill_record("Eagles")["open"]["bad"] = list(0, "x", 0)
	map.bill_normalize()
	bill_p_check(!map.bill_row("Eagles", "bad") && map.bill_row("Eagles", "3"), "malformed bills are dropped")
	map.bill_rename("Eagles", "Hawks")
	bill_p_check(map.bill_row("Hawks", "3") && fake.faction == "Hawks", "bills follow a faction rename")
