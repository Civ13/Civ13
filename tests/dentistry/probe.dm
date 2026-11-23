// Native dentistry probe, included by tests/ecology_spawning/run_linux.py, never
// by the game DME. It drives code/modules/1713/dentistry.dm on a bare head organ.
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
/obj/map_metadata/dental_probe/New()
	map = src
/mob/living/human/dental_probe/New()
	icon_update = FALSE // no species: skip body overlays when held items change
	return
var/dental_failures = 0
var/dental_runtime_error = FALSE
/proc/dental_check(condition, label)
	if (!condition)
		dental_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	dental_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/dental_probe
		initialize_chemical_reactions()
		season = "SUMMER"
		for (var/turf/T in block(locate(1, 1, 1), locate(30, 30, 1)))
			T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
		dental_state_checks()
		dental_stack_checks()
		dental_eating_checks()
		dental_prosthetic_checks()
	catch(var/exception/e)
		dental_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = dental_failures, "runtime_error" = dental_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

var/obj/item/organ/external/head/dental_probe_head = null
/mob/living/human/dental_probe/dental_head()
	return dental_probe_head

/proc/dental_new_mouth(turf/T, teeth = 32)
	var/mob/living/human/dental_probe/M = new(T)
	M.real_name = "Probe [T.x]"
	var/obj/item/organ/external/head/H = new(T)
	H.owner = M
	var/obj/item/stack/teeth/human/S = new(H, teeth)
	H.teeth_list = list(S)
	H.max_teeth = 32
	dental_probe_head = H
	return M

/proc/dental_state_checks()
	var/turf/T = locate(3, 3, 1)
	var/mob/living/human/dental_probe/M = dental_new_mouth(T)
	var/obj/item/organ/external/head/H = dental_probe_head
	var/datum/reagents/R = new(30)
	R.add_reagent("sugar", 10)
	R.add_reagent("nutriment", 10)
	H.add_food_plaque(R, 10)
	dental_check(abs(H.dental_plaque - 5.2) < 0.01, "a sweet bite adds capped plaque (got [H.dental_plaque])")
	H.clean_teeth(100)
	dental_check(H.dental_plaque == 0, "cleaning clears plaque")
	H.dental_plaque = 150
	for (var/i = 1 to 300)
		M.life_tick = 0
		M.handle_teeth()
		if (H.decayed_teeth)
			break
	dental_check(H.decayed_teeth == 1 && H.dental_plaque < 150, "heavy plaque rots a tooth")
	M.life_tick = 1
	var/before = H.caries_minutes
	M.handle_teeth()
	dental_check(H.caries_minutes == before, "dental checks run once a minute")
	H.decayed_teeth = 2
	H.filled_teeth = 3
	var/obj/item/stack/teeth/P = H.remove_natural_tooth(TRUE)
	dental_check(istype(P) && P.rotten_tooth && H.decayed_teeth == 1 && H.get_teeth() == 31, "drawing takes a rotten tooth first")
	dental_check(!P.is_fresh_for(M), "a rotten tooth cannot be replanted")
	H.decayed_teeth = 0
	H.remove_natural_tooth(TRUE)
	dental_check(H.get_teeth() == 30 && H.decayed_teeth == 0, "a sound tooth can be drawn")
	H.add_natural_tooth()
	dental_check(H.get_teeth() == 31, "a replanted tooth counts again")
	H.decayed_teeth = 40
	H.prepared_teeth = 50
	H.abscess = TRUE
	H.clamp_dental_state()
	dental_check(H.decayed_teeth == 31 && H.prepared_teeth == 31 && H.filled_teeth == 0 && H.abscess, "counts stay inside the natural teeth")
	H.decayed_teeth = 0
	H.clamp_dental_state()
	dental_check(!H.abscess && !H.prepared_teeth, "no rotten teeth, no abscess")
	H.bridge_teeth = 3
	var/obj/item/stack/teeth/S = H.teeth_list[1]
	S.amount = 1
	H.lose_dental_teeth(30, 31)
	dental_check(!H.bridge_teeth && locate(/obj/item/dental_bridge) in T, "a bridge falls out without anchors")
	H.reset_dental_state()
	dental_check(!H.bridge_teeth && !H.denture_type && !H.dental_plaque, "reset clears dental state")
	for (var/obj/O in T)
		qdel(O)
	qdel(M)

/proc/dental_stack_checks()
	var/turf/T = locate(8, 8, 1)
	var/mob/living/human/dental_probe/M = dental_new_mouth(T)
	var/obj/item/organ/external/head/H = dental_probe_head
	var/obj/item/stack/teeth/human/A = new(T, 2)
	A.mark_fresh(M)
	dental_check(A.is_fresh_for(M), "a knocked-out tooth is fresh for its owner")
	var/mob/living/human/dental_probe/other = new(T)
	other.real_name = "Someone Else"
	dental_check(!A.is_fresh_for(other), "but not for anyone else")
	var/obj/item/stack/teeth/human/B = A.split(1)
	dental_check(istype(B) && B.is_fresh_for(M) && A.amount == 1, "a split tooth keeps its freshness")
	var/obj/item/stack/teeth/human/C = new(T, 1)
	C.merge(A)
	dental_check(!A.is_fresh_for(M) && A.amount == 2, "merging a stale tooth makes the pile stale")
	B.knocked_out_at = -(10 MINUTES) - 1
	dental_check(!B.is_fresh_for(M), "a tooth out too long is no longer fresh")
	dental_check(H.get_teeth() == 32, "mouth untouched by loose teeth")
	H.knock_out_teeth(NORTH, 5)
	var/fresh = 0
	for (var/obj/item/stack/teeth/K in range(4, T))
		if (K.is_fresh_for(M))
			fresh += K.amount
	dental_check(fresh > 0 && fresh == 32 - H.get_teeth(), "knocked-out teeth come out fresh ([fresh])")
	for (var/obj/O in range(4, T))
		qdel(O)
	qdel(other)
	qdel(M)

/proc/dental_eating_checks()
	var/turf/T = locate(14, 14, 1)
	var/mob/living/human/dental_probe/M = dental_new_mouth(T, 32)
	var/obj/item/organ/external/head/H = dental_probe_head
	var/obj/item/weapon/reagent_containers/food/snacks/S = new(T)
	S.create_reagents(20)
	S.reagents.add_reagent("nutriment", 20)
	dental_check(M.dental_bite(S, 4) == 4, "a full set bites at full size")
	var/obj/item/stack/teeth/K = H.teeth_list[1]
	K.amount = 0
	dental_check(M.dental_bite(S, 4) == 2, "no teeth halves the bite")
	var/changed = FALSE
	for (var/i = 1 to 50)
		if (M.dental_speech("yes sir") != "yes sir")
			changed = TRUE
			break
	dental_check(changed, "a toothless mouth whistles its s")
	H.denture_type = /obj/item/dentures/acrylic
	H.denture_teeth = 32
	dental_check(M.dental_bite(S, 4) == 4, "acrylic dentures bite at full size")
	var/same = TRUE
	for (var/i = 1 to 50)
		if (M.dental_speech("yes sir") != "yes sir")
			same = FALSE
	dental_check(same, "a full denture set speaks clearly")
	H.denture_type = /obj/item/dentures/bone
	dental_check(abs(H.chewing_teeth() - 9.6) < 0.01 && H.visible_teeth() == 32, "carved bone sets look whole but chew poorly")
	for (var/obj/O in T)
		qdel(O)
	qdel(M)

/proc/dental_prosthetic_checks()
	var/turf/T = locate(20, 20, 1)
	var/mob/living/human/dental_probe/M = dental_new_mouth(T, 20)
	var/obj/item/organ/external/head/H = dental_probe_head
	H.denture_type = /obj/item/dentures/vulcanite
	H.denture_teeth = 12
	dental_check(M.take_out_dentures() && !H.denture_type && !H.denture_teeth, "dentures come out")
	var/obj/item/dentures/vulcanite/V = locate() in M.contents + T.contents
	dental_check(istype(V), "the set is handed back")
	var/flew = FALSE
	for (var/i = 1 to 40)
		H.denture_type = /obj/item/dentures/acrylic
		H.denture_teeth = 12
		if (H.knock_out_prosthetics())
			flew = TRUE
			break
	dental_check(flew && !H.denture_type, "a blow can knock dentures out")
	var/obj/item/weapon/clay/porcelain_dentures/U = new(T)
	dental_check(U.result == /obj/item/dentures/porcelain, "unfired porcelain fires into dentures")
	for (var/obj/O in range(4, T))
		qdel(O)
	qdel(M)
