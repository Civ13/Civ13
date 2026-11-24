// Practice rooms fixture: the real practice_rooms.dm level, room and step
// procs on a small world. No client joins; the lobby link, key transfer and
// HUD clicks are not driven. Steps are satisfied by the state a click leaves.
/world
	hub = ""
	hub_password = ""
	maxx = 80
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

// A fresh room for the next exercise. Rebuilding wipes every clientless mob,
// so the trainee steps out of the world for it.
/proc/practice_probe_refit(datum/practice_rooms/R, datum/practice_session/S)
	var/turf/stood = get_turf(S.body)
	S.body.loc = null
	S.props = R.build_room(S.slot)
	S.body.forceMove(locate(stood.x, stood.y, stood.z))

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
	practice_probe_check("room/camp_props", istype(props["camp_door"], /obj/structure/simple_door) && istype(props["fire"], /obj/structure/oven/fireplace/practice) && istype(props["puddle"], /obj/structure/sink/puddle/practice) && istype(props["soap"], /obj/item/weapon/soap) && istype(props["bed"], /obj/structure/bed))
	practice_probe_check("room/camp_wall", istype(locate(props["camp"], O[2] + 4, 2), /turf/wall/indestructable) && istype(locate(props["camp"], O[2] + 5, 2), /turf/floor/wood))
	var/list/O2 = R.slot_origin(2)
	practice_probe_check("room/separate", O2[1] - O[1] >= 13 || O2[2] - O[2] >= 13)

	var/datum/practice_session/S = new(R, 1, props)
	R.sessions["1"] = S
	S.body = new /mob/living/human/practice(inside)
	S.body.practice = S
	var/mob/living/human/H = S.body
	H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
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
	practice_probe_check("camp/pending", S.step_id() == "camp" && !S.step_done("camp"))
	H.forceMove(locate(props["camp"] + 2, O[2] + 5, 2))
	practice_probe_check("camp/needs_help_intent", !S.step_done("camp"))
	H.a_intent = I_HELP
	practice_probe_check("camp/done", S.step_done("camp"))
	S.advance()
	var/obj/structure/oven/fireplace/practice/F = props["fire"]
	practice_probe_check("fire/no_fuel", !S.step_done("fire") && F.fuel == 0)
	F.attackby(props["firewood"], H)
	F.attack_hand(H)
	practice_probe_check("fire/done", S.step_done("fire") && F.fuel > 0)
	S.advance()
	var/obj/item/weapon/reagent_containers/food/snacks/meat/meat = props["meat"]
	F.attackby(meat, H)
	practice_probe_check("cook/pending", S.step_id() == "cook" && meat.loc == F && !S.step_done("cook"))
	F.process()
	practice_probe_check("cook/done", meat.roasted && meat.loc == F.loc && S.step_done("cook"))
	S.advance()
	practice_probe_check("eat/pending", !S.step_done("eat"))
	meat.bitecount = 1
	practice_probe_check("eat/done", S.step_done("eat"))
	S.advance()
	var/obj/item/weapon/reagent_containers/glass/small_pot/pot = props["pot"]
	practice_probe_check("fill/pending", S.step_id() == "fill" && !S.step_done("fill"))
	pot.reagents.add_reagent("water", 10)
	pot.reagents.add_reagent("cholera", 1)
	practice_probe_check("fill/done", S.step_done("fill"))
	S.advance()
	practice_probe_check("boil/pending", !S.step_done("boil"))
	F.attackby(pot, H)
	practice_probe_check("boil/on_fire", pot.on_stove && !S.step_done("boil"))
	pot.on_stove = FALSE
	pot.reagents.kill_germs()
	practice_probe_check("boil/done", S.step_done("boil"))
	S.advance()
	practice_probe_check("drink/pending", S.step_id() == "drink" && !S.step_done("drink"))
	pot.reagents.remove_reagent("water", 5)
	practice_probe_check("drink/done", S.step_done("drink"))
	S.advance()
	practice_probe_check("clothes/fleas", S.shirt && S.shirt.fleas && !S.step_done("clothes"))
	var/obj/item/clothing/shirt = S.shirt
	H.remove_from_mob(shirt)
	shirt.hand_wash(H)
	practice_probe_check("clothes/done", S.step_done("clothes"))
	S.advance()
	practice_probe_check("wash/pending", !S.step_done("wash"))
	H.hygiene = HYGIENE_LEVEL_CLEAN
	practice_probe_check("wash/done", S.step_done("wash"))
	S.advance()
	practice_probe_check("dress/pending", !S.step_done("dress"))
	H.equip_to_slot_or_del(shirt, slot_w_uniform)
	practice_probe_check("dress/done", S.step_done("dress"))
	S.advance()
	var/obj/structure/bed/bed = props["bed"]
	practice_probe_check("rest/pending", S.step_id() == "rest" && !S.step_done("rest"))
	H.forceMove(bed.loc)
	bed.buckle_mob(H)
	practice_probe_check("rest/done", S.step_done("rest"))
	bed.unbuckle_mob()
	S.advance()
	var/obj/exit = props["exit"]
	H.forceMove(exit.loc)
	practice_probe_check("exit/done", S.step_id() == "exit" && S.step_done("exit"))

	// A second player keeps the level while the first one leaves.
	var/datum/practice_session/S2 = new(R, 2, R.build_room(2))
	R.sessions["2"] = S2
	S.end(null)
	practice_probe_check("end/freed", R.sessions.len == 1 && !S.body)
	practice_probe_check("end/room_wiped", !(locate(/obj/item) in inside) && !(locate(/obj/structure/practice_dummy) in get_turf(D)))
	practice_probe_check("end/level_kept_while_occupied", practice_room_z == 2 && world.maxz == 2)

	// Reopening a room replaces every turf, so marks on the old floor are gone.
	inside = locate(O[1] + 3, O[2] + 3, 2)
	inside.name = "marked floor"
	R.build_room(1)
	var/turf/rebuilt = locate(O[1] + 3, O[2] + 3, 2)
	practice_probe_check("room/rebuilt_fresh", istype(rebuilt, /turf/floor/wood) && rebuilt.name != "marked floor")
	R.wipe_room(1)

	S2.end(null)
	practice_probe_check("end/last_out_drops_level", !R.sessions.len && world.maxz == 1 && !practice_room_z && !R.idle_timer)

	R.ensure_level()
	practice_probe_check("save/drops_level", practice_rooms_close_for_save() && world.maxz == 1 && !practice_room_z)
	practice_probe_check("save/no_stale_turfs", !(null in turfs))
	practice_probe_check("budget/growth_free_again", isnull(world_z_budget.error(2, "underground")) || !findtext(world_z_budget.error(2, "underground"), "practice room"))
	practice_probe_check("level/reusable", R.ensure_level() && world.maxz == 2 && R.drop_level() && world.maxz == 1)

	// Tutorial region (tutorial_region.dm), with a hand-made group.
	shard_group.enabled = TRUE
	shard_group.group = "earth"
	shard_group.region = "tutorial"
	shard_group.kind = "TUTORIAL"
	shard_group.mainland = "gaia"
	shard_group.start_region = "gaia"
	shard_group.peers = list("gaia" = list("name" = "Gaia", "kind" = "SURFACE", "address" = "127.0.0.1:1714", "state" = "UP"))
	shard_group.order = list("gaia")
	practice_probe_check("tutorial/here", tutorial_region_here() && isnull(tutorial_region_peer()))
	practice_probe_check("tutorial/returns_to_mainland", tutorial_region_return_id() == "gaia" && tutorial_region_return_name() == "Gaia")
	var/mob/new_player/lobby = new
	practice_probe_check("tutorial/join_refused", tutorial_region_refuse_join(lobby))
	// The tutorial region's own room: four spaces on one corridor line.
	R.ensure_level()
	var/list/TP = R.build_room(1)
	var/list/TO = R.slot_origin(1)
	var/tz = practice_room_z
	var/turf/t_start = TP["start"]
	var/obj/t_door = TP["door"]
	var/obj/t_camp_door = TP["camp_door"]
	var/obj/t_shop_door = TP["workshop_door"]
	var/obj/t_exit = TP["exit"]
	var/obj/structure/practice_workshop_desk/t_desk = TP["workshop_desk"]
	var/obj/structure/practice_lesson_board/t_board = TP["lesson_board"]
	var/obj/t_fire = TP["fire"]
	var/list/t_shop = TP["shop"]
	var/list/t_bay = TP["bay"]
	practice_probe_check("tutorial/room_spaces", istype(t_start, /turf/floor/wood) && istype(get_turf(t_fire), /turf/floor/dirt) && istype(get_turf(TP["bed"]), /turf/floor/grass) && istype(get_turf(t_desk), /turf/floor/wood) && istype(locate(t_bay[1], t_bay[2], tz), /turf/floor/plating/concrete))
	practice_probe_check("tutorial/doors_on_one_line", t_door.y == TO[2] + 7 && t_camp_door.y == t_door.y && t_shop_door.y == t_door.y && t_door.x == TP["split"] && t_camp_door.x == TP["camp"] && t_shop_door.x == t_shop[1] - 1 && istype(locate(t_shop_door.x, t_shop_door.y + 1, tz), /turf/wall/indestructable))
	practice_probe_check("tutorial/ring_walled", istype(locate(TO[1], TO[2], tz), /turf/wall/indestructable) && istype(locate(TO[1] + 39, TO[2] + 14, tz), /turf/wall/indestructable) && t_shop[3] == TO[1] + 38 && t_shop[4] == TO[2] + 13)
	practice_probe_check("tutorial/exit_off_the_path", t_exit.y != t_door.y && get_dist(t_exit, t_shop_door) >= 4 && t_exit.x < t_shop_door.x)
	// Every prop can be walked to: flood from the start over open floor and doors.
	var/list/reached = list()
	reached[t_start] = TRUE
	var/list/frontier = list(t_start)
	while (frontier.len)
		var/turf/here = frontier[1]
		frontier.Cut(1, 2)
		for (var/d in cardinal)
			var/turf/next = get_step(here, d)
			if (!next || reached[next] || next.density)
				continue
			var/blocked = FALSE
			for (var/atom/movable/M in next)
				if (M.density && !istype(M, /obj/structure/simple_door))
					blocked = TRUE
			if (blocked)
				continue
			reached[next] = TRUE
			frontier += next
	var/walkable = TRUE
	for (var/key in list("marker", "knife", "hat", "gauze", "firewood", "meat", "pot", "soap", "exit", "lesson_board"))
		if (!reached[get_turf(TP[key])])
			walkable = FALSE
	for (var/key in list("dummy", "fire", "puddle", "bed", "workshop_desk"))
		var/near = FALSE
		for (var/d in cardinal)
			if (reached[get_step(TP[key], d)])
				near = TRUE
		if (!near)
			walkable = FALSE
	practice_probe_check("tutorial/everything_reachable", walkable && reached[locate(t_bay[3], t_bay[4], tz)])

	var/datum/practice_session/TS = new(R, 1, TP)
	R.sessions["1"] = TS
	TS.body = new /mob/living/human/practice(get_step(t_desk, SOUTH))
	TS.body.practice = TS
	var/mob/living/human/practice/TH = TS.body
	practice_probe_check("tutorial/workshop_private", TS.owns_workshop(t_desk) && TS.owns_workshop(TH) && !TS.owns_workshop(t_start) && !TS.owns_workshop(t_board) && tutorial_workshop_access(TH, t_desk))
	TH.forceMove(get_step(t_board, EAST))
	practice_probe_check("tutorial/board_in_camp", t_board.readable_by(TH) && TS.owns_room(t_board) && !TS.owns_room(locate(TO[1] + 40, TO[2], tz)))
	TH.forceMove(get_step(t_desk, SOUTH))

	// Each built exercise fits its fixtures inside the bay.
	var/text = TS.setup_workshop("car")
	var/obj/structure/car_workshop/practice/t_press = locate() in locate(t_shop[1] + 4, t_shop[2], tz)
	practice_probe_check("tutorial/press_bay", findtext(text, "automobile workshop") && t_press && t_press.bay_clear(VEHICLE_DRAUGHT_MAX) && t_press.allowed(TH) && (locate(/obj/item/ship_draught) in range(7, t_desk)))
	practice_probe_refit(R, TS)
	TS.setup_workshop("air")
	var/obj/structure/car_workshop/airship_yard/practice/t_yard = locate() in locate(t_shop[1] + 4, t_shop[2], tz)
	practice_probe_check("tutorial/airship_bay", t_yard && t_yard.bay_clear(AIR_DRAUGHT_MAX) && TS.owns_workshop(locate(t_yard.x + AIR_DRAUGHT_MAX, t_yard.y + AIR_DRAUGHT_MAX, tz)))
	practice_probe_refit(R, TS)
	TS.setup_workshop("train")
	var/obj/structure/rail_works/practice/t_works = locate() in locate(t_bay[1], t_shop[2] + 9, tz)
	var/track = 0
	var/turf/rail = t_works ? t_works.centre() : null
	while (rail && rail_straight_along(rail, WEST) && TS.owns_workshop(rail))
		track++
		rail = get_step(rail, EAST)
	practice_probe_check("tutorial/train_track", t_works && (WEST in t_works.headings()) && track == 12)
	practice_probe_refit(R, TS)
	TS.setup_workshop("ship")
	var/obj/structure/slipway/practice/t_slip = locate() in locate(t_shop[1] + 10, t_shop[2], tz)
	var/list/t_berth = t_slip ? block(locate(t_slip.x - 2, t_slip.y + 1, tz), locate(t_slip.x + 2, t_slip.y + 5, tz)) : list()
	var/dry = TRUE
	for (var/turf/T in t_berth)
		if (!slipway_ground(T) || istype(T, /turf/floor/beach/water))
			dry = FALSE
	practice_probe_check("tutorial/ship_launches", t_slip && t_slip.dir == NORTH && t_berth.len == 25 && dry && t_slip.draught_landing(t_berth, 5) > 0)
	practice_probe_refit(R, TS)
	TS.setup_workshop("rocket")
	var/obj/structure/rocket_works/practice/t_rocket = locate() in locate(t_shop[1] + 4, t_shop[2], tz)
	practice_probe_check("tutorial/rocket_output", t_rocket && t_rocket.output_turf() && t_rocket.allowed(TH))
	practice_probe_refit(R, TS)
	text = TS.setup_workshop("sub")
	practice_probe_check("tutorial/paper_exercise", findtext(text, "paper exercise") && !(locate(/obj/structure) in range(5, locate(t_bay[1] + 6, t_bay[2] + 6, tz))))
	TS.end(null)
	practice_probe_check("tutorial/room_closes", !R.sessions.len && world.maxz == 1 && !practice_room_z)

	world.maxx = 253
	world.maxy = 69
	practice_probe_check("tutorial/more_rooms", R.capacity() == 24)
	shard_group.region = "gaia"
	shard_group.kind = "SURFACE"
	shard_group.peers = list("tutorial" = list("name" = "Tutorial", "kind" = "TUTORIAL", "address" = "127.0.0.1:1760", "state" = "UP"))
	shard_group.order = list("tutorial")
	practice_probe_check("tutorial/other_regions_keep_eight", R.capacity() == 8 && !tutorial_region_refuse_join(lobby))
	practice_probe_check("tutorial/lobby_link_goes_there", tutorial_region_peer() == "tutorial" && practice_room_available())
	shard_group.peers["tutorial"]["state"] = "DOWN"
	practice_probe_check("tutorial/down_falls_back", isnull(tutorial_region_peer()))
	qdel(lobby)
	shard_group.enabled = FALSE

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
