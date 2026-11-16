// Native coin mint probe, included by tests/ecology_spawning/run_linux.py,
// never by the game DME. It drives code/modules/1713/coin_mint.dm.
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
/obj/map_metadata/mint_p_probe/New()
	map = src
/mob/living/human/mint_p_probe
	var/obj/item/probe_hand = null
/mob/living/human/mint_p_probe/New()
	icon_update = FALSE
	return
/mob/living/human/mint_p_probe/get_active_hand()
	return probe_hand
/mob/living/human/mint_p_probe/restrained()
	return FALSE
var/mint_p_failures = 0
var/mint_p_runtime_error = FALSE
/proc/mint_p_check(condition, label)
	if (!condition)
		mint_p_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	mint_p_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/mint_p_probe
		for (var/turf/T in block(locate(1, 1, 1), locate(30, 30, 1)))
			T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
		mint_p_checks()
	catch(var/exception/e)
		mint_p_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = mint_p_failures, "runtime_error" = mint_p_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/mint_p_checks()
	var/list/Y = mint_yield(3, 1)
	mint_p_check(Y[1] == 30 && Y[2] == 0, "three full sheets strike thirty coins with no copper")
	Y = mint_yield(1, 0.5)
	mint_p_check(Y[1] == 20 && Y[2] == 1, "a half-fine sheet strikes twenty coins and needs one copper sheet")
	Y = mint_yield(2, 0.9)
	mint_p_check(Y[1] == 22 && Y[2] == 1, "two 90% sheets strike 22 coins and need one copper sheet (rounded up)")
	Y = mint_yield(1, 0.75)
	mint_p_check(Y[1] == 13 && Y[2] == 1, "a 75% sheet strikes 13 coins")

	var/obj/item/stack/money/silvercoin/A = new(locate(5, 5, 1), 10)
	A.apply_coin_mark("Eagles", 1)
	mint_p_check(A.name == "Eagles silver coins" && A.value == 1, "full coins name their issuer and keep full value")
	var/obj/item/stack/money/silvercoin/B = new(locate(6, 5, 1), 10)
	B.apply_coin_mark("Eagles", 0.5)
	mint_p_check(abs(B.value - 0.55) < 0.001, "a half-fine silver coin is worth its silver plus its copper")
	var/list/W = weighed_money_of(B)
	mint_p_check(W && abs(W[3] - 5.5) < 0.001, "the balance weighs debased coin at its real worth")
	mint_p_check(findtext(weighed_money_line(B), "debased silver (50% fine)"), "the balance shows the debasement")
	mint_p_check(!findtext(B.desc, "50"), "the coin itself does not admit its fineness")

	mint_p_check(!A.stack_compatible(B) && !B.merge(A), "coins of different fineness do not merge")
	var/obj/item/stack/money/silvercoin/C = new(locate(7, 5, 1), 5)
	C.apply_coin_mark("Wolves", 1)
	mint_p_check(!A.stack_compatible(C) && !C.merge(A) && A.amount == 10, "coins of different issuers do not merge")
	mint_p_check(!C.transfer_to(A, 2) && C.amount == 5, "nor transfer into each other")
	var/obj/item/stack/money/silvercoin/D = new(locate(5, 5, 1), 4)
	D.apply_coin_mark("Eagles", 1)
	D.merge(A)
	mint_p_check(A.amount == 14, "matching coins merge")
	var/obj/item/stack/money/silvercoin/E = A.split(3)
	mint_p_check(E && E.issuer == "Eagles" && E.fineness == 1 && E.name == "Eagles silver coins" && A.amount == 11, "a split keeps the mark")
	var/obj/item/stack/money/coppercoin/K = new(locate(5, 5, 1), 3)
	K.apply_coin_mark("Eagles", 0.5)
	mint_p_check(K.fineness == 1 && abs(K.value - 0.1) < 0.001, "copper coins cannot be debased")
	var/obj/item/stack/money/silvercoin/U = new(locate(8, 5, 1), 2)
	mint_p_check(!U.stack_compatible(A), "unmarked coins do not merge with marked ones")
	var/obj/item/stack/money/silvercoin/L = new(locate(9, 5, 1), 2)
	L.issuer = "Eagles"
	L.fineness = 0.75
	L.after_load()
	mint_p_check(abs(L.value - 0.775) < 0.001 && L.name == "Eagles silver coins", "a loaded stack restores its value and name")
	mint_p_check(mint_coin_type("gold") == /obj/item/stack/money/goldcoin && !mint_coin_type("iron"), "only copper, silver and gold strike coins")

	var/obj/item/coin_die/die = new(locate(5, 5, 1))
	die.issuer = "Eagles"
	map.coin_issuer_rename("Eagles", "Hawks")
	mint_p_check(die.issuer == "Hawks" && die.name == "coin die of Hawks", "a faction rename renames its dies")

	var/obj/structure/machinery/factory/coinsmelter/F = new(locate(12, 12, 1))
	var/mob/living/human/mint_p_probe/H = new(locate(12, 11, 1))
	H.a_intent = I_HELP
	var/obj/item/stack/money/silvercoin/melt = new(locate(12, 11, 1), 20)
	melt.apply_coin_mark("Hawks", 0.5)
	F.attackby(melt, H)
	mint_p_check(abs(F.silver - 1) < 0.001 && abs(F.copper - 1) < 0.001, "the smelter melts coins by their metal content")
	var/obj/item/stack/money/coppercoin/cc = new(locate(12, 11, 1), 10)
	F.attackby(cc, H)
	mint_p_check(abs(F.copper - 2) < 0.001, "ten copper coins melt to one copper sheet")
