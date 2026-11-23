// Native probe: animal medical stacks treat burns and are kept when useless (issue 6970);
// the acid bath rejects lead (issue 6968).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/animal_medical/probe.dm
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
/obj/map_metadata/animal_medical_probe/New()
	return
var/am_failures = 0
var/am_runtime_error = FALSE
/proc/am_check(condition, label)
	if (!condition)
		am_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	am_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		map = new /obj/map_metadata/animal_medical_probe
		am_checks()
	catch(var/exception/e)
		am_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = am_failures, "runtime_error" = am_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/am_checks()
	var/mob/living/simple_animal/sheep/S = new(locate(4, 4, 1))
	var/mob/living/simple_animal/sheep/U = new(locate(5, 4, 1))
	S.stat = CONSCIOUS
	S.adjustBurnLoss(10)
	S.updatehealth()
	var/obj/item/stack/medical/advanced/ointment/K = new(locate(6, 4, 1))
	var/kits = K.amount
	S.attackby(K, U)
	am_check(S.getBurnLoss() == 0, "a burn kit heals an animal's burns")
	am_check(K.amount == kits - 1, "a burn kit that treats burns is used up")
	S.adjustBruteLoss(5)
	var/obj/item/stack/medical/advanced/sulfa/P = new(locate(6, 4, 1))
	var/packs = P.amount
	S.attackby(P, U)
	am_check(P.amount == packs, "sulfa that cannot heal brute or burn is kept")
	kits = K.amount
	S.attackby(K, U)
	am_check(K.amount == kits, "a burn kit is kept when the animal has no burns")
	am_check(S.getBruteLoss() == 5, "a burn kit does not heal brute")
	var/obj/item/stack/medical/advanced/bruise_pack/B = new(locate(6, 4, 1))
	var/bruises = B.amount
	S.attackby(B, U)
	am_check(S.getBruteLoss() < 5 && B.amount == bruises - 1, "a trauma kit still heals brute")
	var/obj/structure/converter/acid_bath/A = new(locate(8, 4, 1))
	var/obj/item/stack/material/lead/L = new(locate(9, 4, 1))
	L.amount = 5
	A.attackby(L, U)
	am_check(L.amount == 5 && !A.filled, "the acid bath rejects lead")
	var/obj/item/stack/material/rawkevlar/R = new(locate(9, 4, 1))
	am_check(istype(R, A.input), "the acid bath still takes raw kevlar")
