// Native regression probe for Gulag13 boxing bets (#4241, #4242, #4243).
/world
	hub = ""
	hub_password = ""
	maxx = 8
	maxy = 8
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/boxing_probe/New()
	return
/mob/living/human/boxing_probe/New()
	return
/obj/effect/bet_processor/boxing_probe
	var/scans = 0
	var/starts = 0
/obj/effect/bet_processor/boxing_probe/New()
	return
/obj/effect/bet_processor/boxing_probe/process_combats()
	scans++
	..()
/obj/effect/bet_processor/boxing_probe/start_match()
	starts++

var/boxing_failures = 0
var/boxing_runtime_error = FALSE
/proc/boxing_check(condition, label)
	if (!condition)
		boxing_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	boxing_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/boxing_probe
		boxing_checks()
	catch(var/exception/e)
		boxing_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = boxing_failures, "runtime_error" = boxing_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
	return

/proc/boxing_checks()
	var/turf/T = locate(2, 2, 1)
	var/obj/effect/bet_processor/boxing_probe/P = new(T)
	P.curr_area = get_area(T)
	var/mob/living/human/boxing_probe/R = new(T)
	var/mob/living/human/boxing_probe/B = new(T)
	R.real_name = "Red"
	B.real_name = "Blue"
	R.w_uniform = new /obj/item/clothing/under/red_shorts(R)
	B.w_uniform = new /obj/item/clothing/under/red_shorts(B)
	P.process_combats()
	sleep(11)
	boxing_check(!P.match_running && P.starts == 0 && P.scans == 2, "same-colour contestants keep one scan loop alive")
	// Retire this loop so a broken admission cannot mask the later cases.
	P.match_running = TRUE
	P = new(T)
	P.curr_area = get_area(T)
	B.w_uniform = new /obj/item/clothing/under/blue_shorts(B)
	P.process_combats()
	boxing_check(P.match_running && P.starts == 1, "one red and one blue start a match")

	// Losing box is created first to exercise the old clear-before-transfer bug.
	var/obj/structure/betting_box/red/L = new(T)
	var/obj/structure/betting_box/blue/W = new(T)
	var/obj/structure/betting_box/blue/W2 = new(T)
	L.storedvalues = list(list(R, 60))
	W.storedvalues = list(list(R, 10), list(B, 20))
	W2.storedvalues = list(list(B, 30))
	W.payvalues = list(list(R, 7))
	L.match_running = TRUE
	W.match_running = TRUE
	W2.match_running = TRUE
	R.surrendered = TRUE
	P.process_match()
	boxing_check(!P.match_running && !L.match_running && !W.match_running && !W2.match_running, "settlement unlocks the processor and all boxes")
	boxing_check(!L.storedvalues.len && !W.storedvalues.len && !W2.storedvalues.len, "settlement clears every participating pool")
	boxing_check(W.payvalues.len == 3 && W.payvalues[1][2] == 7 && W.payvalues[2][2] == 20 && W.payvalues[3][2] == 40 && W2.payvalues[1][2] == 60, "losing pool is shared by all winning stakes and prior payouts survive")
	var/after_settlement = P.scans
	sleep(11)
	boxing_check(P.scans == after_settlement + 1 && P.starts == 1 && !P.match_running, "one scan resumes without restarting the finished pair")
	sleep(10)
	boxing_check(P.scans == after_settlement + 2 && P.starts == 1, "only one rescan loop remains")
	R.w_uniform = new /obj/item/clothing/under/blue_shorts(R)
	B.w_uniform = new /obj/item/clothing/under/red_shorts(B)
	sleep(10)
	boxing_check(P.starts == 1 && !P.match_running, "the finished pair cannot restart by swapping colours")
	B.w_uniform = new /obj/item/clothing/under/blue_shorts(B)
	R.loc = null
	sleep(10)
	var/mob/living/human/boxing_probe/R2 = new(T)
	R2.real_name = "New red"
	R2.w_uniform = new /obj/item/clothing/under/red_shorts(R2)
	sleep(10)
	boxing_check(P.starts == 2 && P.match_running, "a new pair can start after a contestant leaves")

	// Reverse the result with an empty winning pool; no division or payout occurs.
	L.storedvalues = list()
	W.storedvalues = list(list(B, 12))
	W2.storedvalues = list()
	P.red_player = R2
	P.blue_player = B
	P.match_running = TRUE
	B.surrendered = TRUE
	P.process_match()
	boxing_check(!P.match_running && !L.storedvalues.len && !W.storedvalues.len && !W2.storedvalues.len && !L.payvalues.len, "empty winning pool clears safely without a payout")
	L.storedvalues = list(list(R2, 20))
	W.storedvalues = list(list(B, 40))
	P.match_running = TRUE
	P.process_match()
	boxing_check(L.payvalues.len == 1 && L.payvalues[1][2] == 60 && !W.storedvalues.len, "red wins the blue pool when the winning box is encountered first")
