// Native probe: inlaying diamonds into gold and silver crowns
// (apparel_medieval.dm inlay_crown_diamond).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/crown_inlay/probe.dm
/world
	hub = ""
	hub_password = ""
	visibility = 0
	maxx = 8
	maxy = 4
	maxz = 1
	turf = /turf/floor/plating

/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

/client/New()
	del(src)
	return

/obj/map_metadata/ci_probe/New()
	return

// Skip the human constructor; these checks only use hands.
/mob/living/human/ci_probe/New()
	return
/mob/living/human/ci_probe/update_inv_l_hand()
	return
/mob/living/human/ci_probe/update_inv_r_hand()
	return
/mob/living/human/ci_probe/update_inv_head()
	return
/mob/living/human/ci_probe/update_action_buttons()
	return
/mob/living/human/ci_probe/update_icons()
	return

var/ci_failures = 0
var/ci_runtime_error = FALSE
/proc/ci_check(condition, label)
	if (!condition)
		ci_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"

/world/Error(exception/e)
	ci_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new /decl/observ/moved
		GLOB.dir_set_event = new /decl/observ/dir_set
		GLOB.name_set_event = new /decl/observ/name_set
		GLOB.stat_set_event = new /decl/observ/stat_set
		map = new /obj/map_metadata/ci_probe
		map.civilizations = TRUE
		ci_checks()
	catch(var/exception/e)
		ci_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = ci_failures, "runtime_error" = ci_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/ci_count(turf/T, path)
	. = 0
	for (var/atom/A in T)
		if (istype(A, path))
			.++

/proc/ci_checks()
	var/turf/T = locate(2, 2, 1)
	var/mob/living/human/ci_probe/H = new
	H.loc = T

	// A cut diamond (from chiselling a rough one) inlays a gold crown on the floor.
	var/obj/item/clothing/head/helmet/gold_crown/gold = new(T)
	var/obj/item/stack/gemstone/diamond/cut = new(H)
	cut.amount = 2
	H.r_hand = cut
	H.hand = FALSE
	ci_check(cut.resolve_attackby(gold, H), "a cut diamond on a gold crown is handled")
	ci_check(QDELETED(gold), "the plain gold crown is used up")
	ci_check(ci_count(T, /obj/item/clothing/head/helmet/gold_crown_diamond) == 1, "an inlaid gold crown appears")
	ci_check(cut.amount == 1, "one cut diamond is used")

	// A refined diamond sheet still works, on a silver crown held in the other hand.
	var/obj/item/clothing/head/helmet/silver_crown/silver = new(H)
	H.l_hand = silver
	var/obj/item/stack/material/diamond/sheet = new(H)
	H.r_hand = sheet
	ci_check(sheet.resolve_attackby(silver, H), "a diamond sheet on a held silver crown is handled")
	ci_check(QDELETED(silver), "the plain silver crown is used up")
	ci_check(istype(H.l_hand, /obj/item/clothing/head/helmet/silver_crown_diamond) || istype(H.r_hand, /obj/item/clothing/head/helmet/silver_crown_diamond), "the inlaid silver crown lands in a hand")
	ci_check(QDELETED(sheet), "the last diamond sheet is used up")

	// A rough diamond is refused with a hint and nothing is used.
	var/obj/item/clothing/head/helmet/gold_crown/gold2 = new(T)
	var/obj/item/stack/ore/diamond/rough = new(H)
	rough.amount = 3
	H.l_hand = null
	H.r_hand = rough
	ci_check(rough.resolve_attackby(gold2, H), "a rough diamond on a crown is handled")
	ci_check(!QDELETED(gold2) && rough.amount == 3, "a rough diamond is not inlaid")

	// Other cut stones still reach the chisel gem setting on clothing.
	var/obj/item/stack/gemstone/ruby/ruby = new(H)
	H.r_hand = ruby
	ci_check(!inlay_crown_diamond(gold2, /obj/item/clothing/head/helmet/gold_crown_diamond, ruby, H), "a ruby is left to gem setting")
	gold2.set_gem = "ruby"
	var/obj/item/stack/gemstone/diamond/cut2 = new(H)
	H.r_hand = cut2
	cut2.resolve_attackby(gold2, H)
	ci_check(!QDELETED(gold2) && cut2.amount == 1, "a crown already set with a stone is not inlaid")
