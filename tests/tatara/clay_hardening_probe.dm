// Native probe: a steel katana forged on the anvil, clay in the other hand and
// a watered quench tub beside it, comes off clay-hardened with a hamon.
// Each forge is the real timed craft (about 15 seconds), hence the long timeout.
// Run: python3 tests/ecology_spawning/run_linux.py . tests/tatara/clay_hardening_probe.dm 600
/world
	hub = ""
	hub_password = ""
	maxx = 5
	maxy = 3
	maxz = 1
	turf = /turf
	area = /area

/obj/map_metadata/clay_hardening_ci/New()
	return

/mob/living/human/clay_hardening_ci
	New()
		return
	incapacitated(incapacitation_flags = INCAPACITATION_DEFAULT)
		return FALSE
	update_icons()
		return

var/ch_failures = 0
var/ch_runtime_error = FALSE

/world/Error(exception/E)
	ch_runtime_error = TRUE
	world.log << "runtime error [E] [E.file]:[E.line]"

/proc/ch_check(condition, label)
	if (!condition)
		ch_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"

/world/New()
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		ch_checks()
	catch(var/exception/e)
		ch_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = ch_failures, "runtime_error" = ch_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/ch_smith(turf/T)
	var/mob/living/human/clay_hardening_ci/H = new(T)
	H.civilization = "clay_hardening_ci"
	H.may_do_after = TRUE
	H.hand = FALSE
	return H

/proc/ch_hold(mob/living/human/H, obj/item/active, obj/item/other)
	H.hand = FALSE
	H.r_hand = active
	active.loc = H
	H.l_hand = other
	if (other)
		other.loc = H

/proc/ch_forge_katana(obj/structure/anvil/A, mob/living/human/H, steel_type = /obj/item/stack/material/steel)
	var/obj/item/stack/material/S = new steel_type(H)
	S.amount = 20
	var/obj/item/C = H.l_hand
	ch_hold(H, S, C)
	A.in_use = FALSE
	H.may_do_after = TRUE
	var/iron = istype(S, /obj/item/stack/material/iron)
	A.forge_stack_recipe(S, H, H, "swords", iron ? 6 : 5, iron ? "iron" : "steel", "Katana - ")
	for (var/obj/item/weapon/material/sword/katana/K in get_turf(A))
		if (!K.forge_probe_seen)
			K.forge_probe_seen = TRUE
			return K
	return null

/obj/item/weapon/material/sword/katana/var/forge_probe_seen = FALSE

/proc/ch_checks()
	populate_material_list()
	build_research_tree()
	map = new /obj/map_metadata/clay_hardening_ci
	map.ordinal_age = 2
	map.faction_baseline_era["clay_hardening_ci"] = 0
	for (var/node in list("steel_blades", "tatara_smelting", "japanese_swordsmithing"))
		map.ensure_node_entry("clay_hardening_ci", node)[RNODE_ENTRY_STATUS] = RNODE_DONE
	var/turf/T = locate(1, 1, 1)
	var/mob/living/human/H = ch_smith(T)
	var/obj/structure/anvil/steel_faced/A = new(locate(2, 1, 1))
	var/obj/structure/quench_tub/Q = new(locate(3, 1, 1))
	Q.water_store = 60
	var/obj/item/stack/material/clay/C = new(H)
	C.amount = 5
	H.l_hand = C

	ch_check(crafting_node_allowed(H, "japanese_swordsmithing"), "the smith knows Japanese Swordsmithing")
	ch_check(A.quench_tub() == Q, "the watered tub counts beside the anvil")
	ch_check(A.hardening_clay(H) == C, "clay in the other hand counts")

	var/obj/item/weapon/material/sword/katana/K = ch_forge_katana(A, H)
	ch_check(K, "the katana is forged onto the anvil's tile")
	ch_check(K && K.hamon, "a steel katana forged with clay in hand and a watered tub beside the anvil gets a hamon ([K ? K.crafting_quality : "none"])")
	ch_check(C.amount == 4, "clay hardening uses one clay ([C.amount] left)")

	// Fine steel (tamahagane folded) still gets its hamon.
	K = ch_forge_katana(A, H, /obj/item/stack/material/steel/fine)
	ch_check(K && K.hamon, "a fine steel katana gets a hamon")

	// Unfired clay lumps count as clay too.
	var/obj/item/weapon/clay/U = new(H)
	H.l_hand = U
	K = ch_forge_katana(A, H)
	ch_check(K && K.hamon, "an unfired clay lump in the other hand counts")
	ch_check(QDELETED(U) || !U.loc || U.loc == null, "the unfired lump is used up")

	// Clay on the anvil's tile counts.
	H.l_hand = null
	var/obj/item/stack/material/clay/Floor = new(get_turf(A))
	Floor.amount = 2
	K = ch_forge_katana(A, H)
	ch_check(K && K.hamon && Floor.amount == 1, "clay on the anvil's tile counts")
	qdel(Floor)

	// Each missing piece: no hamon, and the clay is kept.
	C = new(H)
	C.amount = 5
	H.l_hand = C
	K = ch_forge_katana(A, H, /obj/item/stack/material/iron)
	ch_check(K && !K.hamon && C.amount == 5, "an iron katana takes no hamon and keeps the clay")
	Q.anchored = FALSE
	K = ch_forge_katana(A, H)
	ch_check(K && !K.hamon && C.amount == 5, "a loose tub does not clay-harden")
	ch_check(findtext(A.clay_tub_problem(), "loose"), "a loose tub is named as the problem")
	Q.anchored = TRUE
	Q.water_store = 0
	K = ch_forge_katana(A, H)
	ch_check(K && !K.hamon && C.amount == 5, "a dry tub does not clay-harden")
	ch_check(findtext(A.clay_tub_problem(), "dry"), "a dry tub is named as the problem")
	Q.water_store = 60
	map.get_node_entry("clay_hardening_ci", "japanese_swordsmithing")[RNODE_ENTRY_STATUS] = RNODE_LOCKED
	K = ch_forge_katana(A, H)
	ch_check(K && !K.hamon && C.amount == 5, "without Japanese Swordsmithing there is no hamon")
	map.get_node_entry("clay_hardening_ci", "japanese_swordsmithing")[RNODE_ENTRY_STATUS] = RNODE_DONE

	// Only ten water left: clay hardening takes it, not the plain quench first.
	Q.water_store = 10
	K = ch_forge_katana(A, H)
	ch_check(K && K.hamon && Q.water_store == 0, "clay hardening comes before the plain quench")
