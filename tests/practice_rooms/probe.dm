// Practice rooms fixture: the real practice_rooms.dm level, room and step
// procs on a small world. No client joins; the lobby link, key transfer and
// HUD clicks are not driven. Steps are satisfied by the state a click leaves.
/world
	hub = ""
	hub_password = ""
	maxx = 60
	maxy = 40
	maxz = 1
	// Production default: a plane added at runtime starts as open air.
	turf = /turf/sky/building
	area = /area/caribbean
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/world/Topic(T, addr, master, key)
	return "Closed practice rooms fixture"

var/global/list/practice_probe_checks = list()
var/global/list/practice_probe_failed = list()
var/global/practice_probe_runtime_error = FALSE

/world/Error(exception/E)
	practice_probe_runtime_error = TRUE
	world.log << "Unexpected fixture runtime: [E] at [E.file]:[E.line]"
	return ..()

/proc/practice_probe_check(label, passed)
	practice_probe_checks += list(list("label" = label, "passed" = !!passed))
	if (!passed)
		practice_probe_failed += label

/proc/practice_probe_run()
	makeDatumRefLists()
	if (!movementMachine)
		movementMachine = new
	var/datum/practice_rooms/R = practice_rooms
	practice_probe_check("capacity", R.capacity() == 8)
	practice_probe_check("budget/admits", isnull(world_z_budget.error(2, "practice")))
	practice_probe_check("level/added", R.ensure_level() && world.maxz == 2 && practice_room_z == 2)
	practice_probe_check("budget/blocks_other_growth", findtext(world_z_budget.error(3, "underground"), "practice room"))
	practice_probe_check("multiz/not_linked", !multiz_level_above(1) && !multiz_level_below(2) && !multiz_level_above(2))
	practice_probe_check("multiz/top_is_world", multiz_top_z() == 1)

	var/list/props = R.build_room(1)
	var/list/O = R.slot_origin(1)
	var/turf/corner = locate(O[1], O[2], 2)
	var/turf/inside = props["start"]
	practice_probe_check("room/walls", istype(corner, /turf/wall/indestructable))
	practice_probe_check("room/floor", istype(inside, /turf/floor/wood))
	practice_probe_check("room/area", istype(get_area(inside), /area/caribbean/admin/practice))
	practice_probe_check("room/props", istype(props["knife"], /obj/item) && istype(props["dummy"], /obj/structure/practice_dummy) && istype(props["door"], /obj/structure/simple_door))
	var/list/O2 = R.slot_origin(2)
	practice_probe_check("room/separate", O2[1] - O[1] >= 13 || O2[2] - O[2] >= 13)

	var/datum/practice_session/S = new(R, 1, props)
	R.sessions["1"] = S
	S.body = new /mob/living/human/practice(inside)
	S.body.practice = S
	var/mob/living/human/H = S.body
	practice_probe_check("body/not_saved", !H.should_save)
	H.persistence_owner_ckey = "realowner"
	H.record_persistence_owner()
	practice_probe_check("body/no_owner", isnull(H.persistence_owner_ckey))

	S.advance()
	practice_probe_check("walk/pending", S.step_id() == "walk" && !S.step_done("walk"))
	var/obj/marker = props["marker"]
	H.forceMove(marker.loc)
	practice_probe_check("walk/done", S.step_done("walk"))
	S.advance()
	H.put_in_active_hand(props["knife"])
	practice_probe_check("pick_up/done", S.step_id() == "pick_up" && S.step_done("pick_up"))
	S.advance()
	practice_probe_check("swap/pending", !S.step_done("swap"))
	H.swap_hand()
	practice_probe_check("swap/done", S.step_done("swap"))
	S.advance()
	practice_probe_check("wear/pending", !S.step_done("wear"))
	H.equip_to_slot_or_del(props["hat"], slot_head)
	practice_probe_check("wear/done", S.step_done("wear"))
	S.advance()
	practice_probe_check("door/pending", !S.step_done("door"))
	H.forceMove(locate(props["split"] + 2, O[2] + 5, 2))
	practice_probe_check("door/done", S.step_done("door"))
	S.advance()
	var/obj/structure/practice_dummy/indestructible/practice_room/D = props["dummy"]
	H.a_intent = I_HELP
	D.attack_hand(H)
	practice_probe_check("harm/needs_harm_intent", !S.step_done("harm"))
	H.a_intent = I_HARM
	D.attack_hand(H)
	practice_probe_check("harm/done", S.step_done("harm"))
	S.advance()
	practice_probe_check("bandage/cut_made", S.step_id() == "bandage" && !S.step_done("bandage"))
	for (var/obj/item/organ/external/E in H.organs)
		for (var/datum/wound/W in E.wounds)
			W.bandage()
	practice_probe_check("bandage/done", S.step_done("bandage"))
	S.advance()
	var/obj/item/weapon/reagent_containers/food/snacks/bread = props["bread"]
	practice_probe_check("eat/pending", !S.step_done("eat"))
	bread.bitecount = 1
	practice_probe_check("eat/done", S.step_done("eat"))
	S.advance()
	var/obj/exit = props["exit"]
	H.forceMove(exit.loc)
	practice_probe_check("exit/done", S.step_id() == "exit" && S.step_done("exit"))

	S.end(null)
	practice_probe_check("end/freed", !R.sessions.len && !S.body)
	practice_probe_check("end/room_wiped", !(locate(/obj/item) in inside) && !(locate(/obj/structure/practice_dummy) in get_turf(D)))

	practice_probe_check("save/drops_level", practice_rooms_close_for_save() && world.maxz == 1 && !practice_room_z)
	practice_probe_check("save/no_stale_turfs", !(null in turfs))
	practice_probe_check("budget/growth_free_again", isnull(world_z_budget.error(2, "underground")) || !findtext(world_z_budget.error(2, "underground"), "practice room"))
	practice_probe_check("level/reusable", R.ensure_level() && world.maxz == 2 && R.drop_level() && world.maxz == 1)

/world/New()
	OpenPort("none")
	GLOB.all_observable_events = list()
	GLOB.moved_event = new /decl/observ/moved
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.name_set_event = new /decl/observ/name_set
	GLOB.stat_set_event = new /decl/observ/stat_set
	practice_probe_run()
	text2file(json_encode(list("commit" = world.params["tested_commit"], "check_count" = practice_probe_checks.len, "failed_labels" = practice_probe_failed, "runtime_error" = practice_probe_runtime_error, "checks" = practice_probe_checks)), "result.json")
	world.log << "COMPLETE practice rooms fixture"
	del(world)
