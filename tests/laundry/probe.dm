// Native probe: soap and detergent leave a dirt-resistant laundry finish.
// Run: python3 tests/ecology_spawning/run_linux.py . tests/laundry/probe.dm
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
/obj/map_metadata/ld_probe/New()
	return

var/ld_failures = 0
var/ld_runtime_error = FALSE
/proc/ld_check(condition, label)
	if (!condition)
		ld_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	ld_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/ld_probe
		ld_checks()
	catch(var/exception/e)
		ld_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = ld_failures, "runtime_error" = ld_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

// A stand-in mob: hand_wash only asks for the other hand.
/mob/ld_probe
	var/obj/item/other_hand = null
// Skip the mob constructor; the probe only needs the hand lookup.
/mob/ld_probe/New()
	return
/mob/ld_probe/get_inactive_hand()
	return other_hand

/proc/ld_checks()
	var/turf/T = locate(2, 2, 1)
	// Worn dirt is reduced while the finish lasts, then the finish wears off.
	var/obj/item/clothing/C = new /obj/item/clothing/under(T)
	C.apply_laundry_treatment(75, 2)
	C.gain_dirt(1)
	ld_check(abs(C.dirtyness - 0.25) < 0.001 && C.dirt_resist_left == 1, "a 75% finish blocks most dirt and counts down")
	C.gain_dirt(1)
	ld_check(C.dirt_resist_left == 0 && C.dirt_resist == 0, "the finish ends when its worn ticks run out")
	C.gain_dirt(1)
	ld_check(abs(C.dirtyness - 1.5) < 0.001, "dirt builds normally once the finish is gone")
	C.gain_dirt(500)
	ld_check(C.dirtyness == 100, "dirt still caps at 100")

	// Hand washing with soap in the other hand applies the soap finish and spends the bar.
	var/mob/ld_probe/M = new(T)
	var/obj/item/weapon/soap/S = new(T)
	M.other_hand = S
	var/obj/item/clothing/H = new /obj/item/clothing/under(T)
	H.dirtyness = 80
	H.fleas = TRUE
	ld_check(H.hand_wash(M) == S, "hand washing uses the soap in the other hand")
	ld_check(!H.dirtyness && !H.fleas && H.dirt_resist == 50 && H.dirt_resist_left == 3600, "soap cleans and leaves a 50% finish")
	ld_check(S.used == 2, "a laundry wash spends two uses of the bar")
	var/obj/item/clothing/plain = new /obj/item/clothing/under(T)
	M.other_hand = null
	ld_check(!plain.hand_wash(M) && !plain.dirt_resist_left, "washing without a cleaner leaves no finish")
	var/obj/item/clothing/lard_washed = new /obj/item/clothing/under(T)
	M.other_hand = new /obj/item/weapon/soap/lard(T)
	lard_washed.hand_wash(M)
	ld_check(lard_washed.dirt_resist == 35, "lard soap leaves a weaker finish")

	// A washing machine takes one detergent dose and its cycle spends it on every garment.
	var/obj/machinery/washing_machine/W = new(T)
	var/obj/item/weapon/laundry_detergent/D = new(T)
	ld_check(W.load_detergent(D, M) && D.doses == 19, "loading detergent takes one dose from the box")
	ld_check(!W.load_detergent(D, M) && D.doses == 19, "a second dose is refused while one is loaded")
	var/obj/item/clothing/A = new /obj/item/clothing/under(W)
	var/obj/item/clothing/B = new /obj/item/clothing/under(W)
	W.washing += A
	W.washing += B
	W.state = 4
	W.complete_wash()
	ld_check(A.dirt_resist == 75 && B.dirt_resist_left == 7200, "the cycle leaves a detergent finish on every garment")
	ld_check(!W.detergent_ticks && !W.detergent_resist && isnull(W.detergent_name), "the dose is spent by the cycle")
	var/obj/item/clothing/E = new /obj/item/clothing/under(W)
	W.washing = list(E)
	W.complete_wash()
	ld_check(!E.dirt_resist_left && E.dirtyness == -100, "a cycle without detergent still cleans but leaves no finish")
	D.doses = 1
	W.load_detergent(D, M)
	ld_check(QDELETED(D), "the last dose empties the box")

	// Persistence: the finish and a loaded dose are saved fields.
	var/list/cloth_fields = A.get_saved_vars()
	ld_check(("dirt_resist" in cloth_fields) && ("dirt_resist_left" in cloth_fields), "a garment saves its finish")
	var/list/machine_fields = W.get_saved_vars()
	ld_check(("detergent_resist" in machine_fields) && ("detergent_ticks" in machine_fields) && ("detergent_name" in machine_fields) && ("water_stored" in machine_fields), "a washing machine saves its loaded dose and water")
	// After a load the wash list is rebuilt from the machine's contents.
	W.washing.Cut()
	W.state = 5
	W.after_load()
	ld_check(W.state == 4 && (A in W.washing) && (E in W.washing), "after a load the machine finds the clothes inside, door closed")
