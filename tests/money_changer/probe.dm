// Native money changer probe, included by tests/ecology_spawning/run_linux.py,
// never by the game DME. It drives code/modules/1713/money_changer.dm.
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
/obj/map_metadata/changer_probe/New()
	map = src
/mob/living/human/changer_probe
	var/obj/item/probe_hand = null
/mob/living/human/changer_probe/New()
	icon_update = FALSE
	return
/mob/living/human/changer_probe/get_active_hand()
	return probe_hand
/mob/living/human/changer_probe/get_inactive_hand()
	return null
/mob/living/human/changer_probe/restrained()
	return FALSE
/mob/living/human/changer_probe/put_in_hands(obj/item/W)
	return FALSE
var/changer_p_failures = 0
var/changer_p_runtime_error = FALSE
/proc/changer_p_check(condition, label)
	if (!condition)
		changer_p_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	changer_p_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/changer_probe
		for (var/turf/T in block(locate(1, 1, 1), locate(30, 30, 1)))
			T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
		changer_p_checks()
	catch(var/exception/e)
		changer_p_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = changer_p_failures, "runtime_error" = changer_p_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/changer_p_person(name, ckey, x)
	var/mob/living/human/changer_probe/H = new(locate(x, 10, 1))
	H.real_name = name
	H.name = name
	H.stat = CONSCIOUS
	H.civilization = "none"
	H.persistence_owner_ckey = ckey
	human_mob_list |= H
	return H

/proc/changer_p_coins(type, amount, issuer, atom/where)
	var/obj/item/stack/money/M = new type(where, amount)
	M.apply_coin_mark(issuer, 1)
	return M

/proc/changer_p_worth(turf/T, issuer)
	var/worth = 0
	for (var/obj/item/stack/money/M in T)
		if (isnull(issuer) || M.issuer == issuer)
			worth += M.amount * M.value
	return round(worth, 0.1)

/proc/changer_p_checks()
	var/mob/living/human/changer_probe/K = changer_p_person("Ada Keeper", "adakeeper", 10)
	var/mob/living/human/changer_probe/C = changer_p_person("Bo Client", "boclient", 12)
	var/obj/structure/closet/crate/money_changer/T = new(locate(11, 11, 1))
	T.owner_account = "adakeeper"
	T.owner_name = "Ada Keeper"
	T.locked = TRUE
	changer_p_check(T.is_keeper(K) && !T.is_keeper(C), "the keeper is known by account")
	changer_p_check(!T.can_open(), "a kept table's till stays shut")

	changer_p_coins(/obj/item/stack/money/silvercoin, 20, "Eagles", T)
	changer_p_coins(/obj/item/stack/money/coppercoin, 30, "Eagles", T)
	changer_p_check(T.stock_worth("Eagles") == 23 && T.stock_worth() == 23, "the till counts its coin by issuer")

	var/obj/item/stack/money/W = changer_p_coins(/obj/item/stack/money/silvercoin, 10, "Wolves", get_turf(C))
	changer_p_check(T.change_coins(W, C) && !(W in T), "a coin the table doesn't buy stays with its owner")

	T.rates["Wolves"] = 90
	changer_p_check(findtext(T.rates_text(), "Buys Wolves coin at 90%"), "the rates can be read")
	changer_p_check(coin_pay_from(T.stock("Eagles"), 9, null, TRUE) == 9 && T.stock_worth("Eagles") == 23, "a dry run moves nothing")

	var/turf/feet = get_turf(C)
	var/paid = coin_pay_from(T.stock("Eagles"), 9, C)
	changer_p_check(paid == 9 && changer_p_worth(feet, "Eagles") == 9 && T.stock_worth("Eagles") == 14, "the till pays exactly what is owed, largest coins first")
	changer_p_check(coin_pay_from(T.stock("Eagles"), 100, C, TRUE) == 14, "it never pays more than it holds")

	var/obj/structure/closet/crate/faction_strongbox/B = new(locate(20, 20, 1))
	changer_p_coins(/obj/item/stack/money/goldcoin, 2, "Eagles", B)
	changer_p_check(B.pay_out(5, C) == 4 && B.coin_worth() == 4, "the strongbox pays through the same counter and never overpays")
