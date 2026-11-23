// Native probe: money printer payouts keep the value they cannot pay out (issue 6973).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/money_printer_payout/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 30
	maxy = 8
	maxz = 1
	turf = /turf/floor/dirt
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/money_printer_probe/New()
	return
var/mp_failures = 0
var/mp_runtime_error = FALSE
/proc/mp_check(condition, label)
	if (!condition)
		mp_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	mp_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		map = new /obj/map_metadata/money_printer_probe
		mp_checks()
	catch(var/exception/e)
		mp_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = mp_failures, "runtime_error" = mp_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/mp_value_at(turf/T)
	var/total = 0
	for (var/obj/item/stack/money/M in T)
		if (!istype(M, /obj/item/stack/money/fiat))
			total += M.amount * M.value
	return round(total, 0.01)

/proc/mp_near(a, b)
	return abs(a - b) < 0.001

/proc/mp_checks()
	var/obj/structure/money_printer/P = new(locate(4, 4, 1))
	mp_check(P.real_money_payout_value(P.real_money_payout(41)) == 41, "41 silver of backing is payable in full")
	var/paid = P.dispense_real_money(41)
	mp_check(paid == 41 && mp_value_at(P.loc) == 41, "dispensing 41 pays gold and silver worth exactly 41")
	var/obj/structure/money_printer/Q = new(locate(8, 4, 1))
	paid = Q.dispense_real_money(5.37)
	mp_check(mp_near(paid, 5.3) && mp_near(mp_value_at(Q.loc), 5.3), "a value below one copper is not paid out")
	var/obj/structure/money_printer/R = new(locate(12, 4, 1))
	fiat.currency_list["mpt"] = list("probe notes", "probe note", "probe notes", "dollar", 1, 0)
	R.fiat_id = "mpt"
	R.exchange_rate = 0.05
	R.real_money_inside = 10
	var/mob/living/simple_animal/sheep/U = new(locate(13, 4, 1))
	var/obj/item/stack/money/fiat/F = new(locate(13, 4, 1), 1, "mpt")
	R.attackby(F, U)
	mp_check(!QDELETED(F) && R.real_money_inside == 10, "a redemption worth less than one copper is refused and keeps the notes")
	F.amount = 3
	R.attackby(F, U)
	mp_check(mp_near(R.real_money_inside, 9.9) && mp_near(mp_value_at(R.loc), 0.1), "a redemption deducts only what it pays out")
