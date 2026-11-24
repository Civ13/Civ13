// Practice rooms fixture: the real practice_rooms.dm level, room and step
// procs on a small world. No client joins; the lobby link, key transfer and
// HUD clicks are not driven. Steps are satisfied by the state a click leaves.
/world
	hub = ""
	hub_password = ""
	// The tutorial map's own size (maps/special/tutorial.dmm).
	maxx = 397
	maxy = 257
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

// The tutorial map, without its startup.
/obj/map_metadata/tutorial/practice_probe/New()
	return

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
	// The tutorial region's own plot, on the map's ground level: lesson rooms on
	// one corridor line along the south, and two yards to dig and build in.
	map = new /obj/map_metadata/tutorial/practice_probe
	practice_probe_check("tutorial/levels_enabled", map.dig_down_underground && map.building_levels == 10 && underground_depth_limit() == 4 && R.room_z() == 1 && R.ensure_level() && !practice_room_z && world.maxz == 1)
	var/list/TP = R.build_room(1)
	var/list/TO = R.slot_origin(1)
	var/list/TO2 = R.slot_origin(2)
	var/tz = R.room_z()
	var/turf/t_start = TP["start"]
	var/obj/t_door = TP["door"]
	var/obj/t_camp_door = TP["camp_door"]
	var/obj/t_shop_door = TP["workshop_door"]
	var/obj/t_paved_door = TP["paved_door"]
	var/obj/t_yard_door = TP["yard_door"]
	var/obj/t_exit = TP["exit"]
	var/obj/structure/practice_workshop_desk/t_desk = TP["workshop_desk"]
	var/obj/structure/practice_lesson_board/t_board = TP["lesson_board"]
	var/obj/t_fire = TP["fire"]
	var/list/t_shop = TP["shop"]
	var/list/t_paved = TP["paved"]
	var/list/t_field = TP["field"]
	var/list/t_plot = TP["plot"]
	var/list/t_stores = TP["stores"]
	var/px = t_paved[1]
	var/py = t_paved[2]
	practice_probe_check("tutorial/room_spaces", istype(t_start, /turf/floor/wood) && istype(get_turf(t_fire), /turf/floor/dirt) && istype(get_turf(TP["bed"]), /turf/floor/grass) && istype(get_turf(t_desk), /turf/floor/wood) && istype(locate(px, py, tz), /turf/floor/plating/concrete) && istype(locate(t_paved[3], t_paved[4], tz), /turf/floor/plating/concrete) && istype(locate(t_field[1], t_field[2], tz), /turf/floor/grass))
	practice_probe_check("tutorial/doors_on_one_line", t_door.y == TO[2] + 7 && t_camp_door.y == t_door.y && t_shop_door.y == t_door.y && t_paved_door.y == t_door.y && t_door.x == TP["split"] && t_camp_door.x == TP["camp"] && t_shop_door.x == t_shop[1] - 1 && t_paved_door.x == px - 1 && t_yard_door.y == t_field[2] - 1 && istype(locate(t_shop_door.x, t_shop_door.y + 1, tz), /turf/wall/indestructable))
	practice_probe_check("tutorial/ring_walled", istype(locate(TO[1], TO[2], tz), /turf/wall/indestructable) && istype(locate(TO[1] + 63, TO[2] + 61, tz), /turf/wall/indestructable) && t_plot[1] == TO[1] + 1 && t_plot[3] == TO[1] + 62 && t_plot[4] == TO[2] + 60 && TO2[1] - TO[1] == 66)
	practice_probe_check("tutorial/yards_are_large", t_paved[3] - px + 1 == 31 && t_paved[4] - py + 1 == 60 && t_field[3] - t_field[1] + 1 == 62 && t_field[4] - t_field[2] + 1 == 46)
	practice_probe_check("tutorial/exit_off_the_path", t_exit.y != t_door.y && get_dist(t_exit, t_shop_door) >= 4 && t_exit.x < t_shop_door.x)
	// Every prop can be walked to: flood from the start over open floor and doors.
	var/list/reached = list()
	reached[t_start] = TRUE
	var/list/frontier = list(t_start)
	var/at = 1
	while (at <= frontier.len)
		var/turf/here = frontier[at++]
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
	for (var/atom/fixture in list(TP["dummy"], TP["fire"], TP["puddle"], TP["bed"], t_desk) + t_stores)
		var/near = FALSE
		for (var/d in cardinal)
			if (reached[get_step(fixture, d)])
				near = TRUE
		if (!near)
			walkable = FALSE
	practice_probe_check("tutorial/everything_reachable", walkable && reached[locate(t_paved[3], t_paved[4], tz)] && reached[locate(t_field[1], t_field[4], tz)])

	var/datum/practice_session/TS = new(R, 1, TP)
	R.sessions["1"] = TS
	TS.body = new /mob/living/human/practice(get_step(t_desk, SOUTH))
	TS.body.practice = TS
	var/mob/living/human/practice/TH = TS.body
	practice_probe_check("tutorial/workshop_private", TS.owns_workshop(t_desk) && TS.owns_workshop(TH) && !TS.owns_workshop(t_start) && TS.owns_room(t_start) && !TS.owns_workshop(t_board) && tutorial_workshop_access(TH, t_desk))
	TH.forceMove(get_step(t_board, EAST))
	practice_probe_check("tutorial/board_in_camp", t_board.readable_by(TH) && TS.owns_room(t_board) && !TS.owns_room(locate(TO[1] + 63, TO[2] + 5, tz)) && !TS.owns_room(locate(TO2[1] + 5, TO2[2] + 5, tz)))

	// The stores hand out full stacks without limit, to the plot's trainee only.
	var/obj/structure/practice_stores/t_store = t_stores[1]
	TH.forceMove(get_step(t_store, SOUTH))
	var/obj/item/stack/material/wood/t_wood = t_store.hand_out(TH, "Wood")
	var/obj/item/t_shovel = t_store.hand_out(TH, "Shovel")
	var/mob/living/human/practice/stranger = new(get_step(t_store, WEST))
	practice_probe_check("tutorial/stores_hand_out", istype(t_wood) && t_wood.amount == t_wood.max_amount && t_wood.loc == TH.loc && istype(t_shovel, /obj/item/weapon/material/shovel) && istype(t_store.hand_out(TH, "Wood"), /obj/item/stack/material/wood) && isnull(t_store.hand_out(TH, "Crown jewels")))
	practice_probe_check("tutorial/stores_private", t_stores.len == 3 && t_store.usable_by(TH) && !t_store.usable_by(stranger) && isnull(t_store.hand_out(stranger, "Wood")) && TS.owns_workshop(t_stores[1]) && TS.owns_rect(t_stores[2], t_paved) && TS.owns_rect(t_stores[3], t_field))
	var/every_kind = TRUE
	var/list/t_stock = practice_stores_stock()
	for (var/label in t_stock)
		if (!ispath(t_stock[label], /obj/item))
			every_kind = FALSE
	practice_probe_check("tutorial/stores_stock", every_kind && t_stock.len >= 25 && t_stock["Stone"] && t_stock["Steel"] && t_stock["Pickaxe"] && t_stock["Rail lengths"])
	qdel(stranger)
	TH.forceMove(get_step(t_desk, SOUTH))

	// Digging: the map's own underground, walled to the plot by bedrock.
	practice_probe_check("tutorial/dig_admitted", isnull(underground_dig_error(1)) && underground_create(1) && world.maxz == 2)
	var/cave = underground_z_at(1)
	var/turf/t_dug = locate(t_field[1] + 4, t_field[2] + 10, cave)
	practice_probe_check("tutorial/underground_walled", cave == 2 && multiz_level_below(tz) == cave && istype(locate(TO[1], TO[2], cave), /turf/wall/rockwall/bedrock) && istype(locate(TO[1] + 63, TO[2] + 30, cave), /turf/wall/rockwall/bedrock) && istype(locate(TO[1] + 20, TO[2] + 61, cave), /turf/wall/rockwall/bedrock) && dug_underground_unformed(t_dug) && dug_underground_unformed(locate(TO2[1], TO2[2], cave)))
	t_dug = dug_underground_form(t_dug)
	t_dug = t_dug.ChangeTurf(/turf/floor/dirt)
	dug_underground_form_around(t_dug)
	new /obj/item/weapon/flint(t_dug)
	var/turf/t_rim = locate(t_plot[1], t_field[2] + 10, cave)
	t_rim = dug_underground_form(t_rim)
	t_rim = t_rim.ChangeTurf(/turf/floor/dirt)
	dug_underground_form_around(t_rim)
	practice_probe_check("tutorial/tunnels_stay_inside", !dug_underground_unformed(t_dug) && istype(locate(TO[1], t_rim.y, cave), /turf/wall/rockwall/bedrock) && istype(locate(TO[1], t_rim.y + 1, cave), /turf/wall/rockwall/bedrock) && dug_underground_unformed(locate(TO[1] - 1, t_rim.y, cave)))
	practice_probe_check("tutorial/deeper_levels", isnull(underground_dig_error(2)) && underground_create(2) && world.maxz == 3 && istype(locate(TO[1], TO[2], underground_z_at(2)), /turf/wall/rockwall/bedrock) && findtext(underground_dig_error(5), "bedrock"))

	// Building up: the map's own open-air levels, held to the plot by the
	// trainee's own reach.
	practice_probe_check("tutorial/build_up_admitted", building_stack_room(tz) && building_allocate_level(world.maxz + 1) && world.maxz == 4 && multiz_level_above(tz) == 4 && building_levels_built() == 1)
	var/air = 4
	var/turf/t_up = locate(px + 5, py + 20, air)
	t_up = t_up.ChangeTurf(/turf/floor/wood)
	new /obj/item/weapon/flint(t_up)
	var/turf/t_edge = locate(t_plot[3], py + 20, air)
	t_edge = t_edge.ChangeTurf(/turf/floor/wood)
	var/turf/t_beyond = locate(t_plot[3] + 1, py + 20, air)
	t_beyond = t_beyond.ChangeTurf(/turf/floor/wood)
	TH.forceMove(t_edge)
	var/refused = !TH.Move(t_beyond, EAST)
	practice_probe_check("tutorial/kept_to_plot", refused && TH.loc == t_edge && TS.may_stand(t_edge) && TS.may_stand(t_dug) && !TS.may_stand(t_beyond) && !TS.may_stand(locate(TO2[1] + 5, TO2[2] + 5, tz)))
	TH.forceMove(get_step(t_desk, SOUTH))
	// Plans peg out in either yard on any level, never across the rooms or the wall.
	practice_probe_check("tutorial/plans_fit_yards", tutorial_workshop_footprint(TH, t_field[1], t_field[2], t_field[1] + 19, t_field[2] + 19, tz) && tutorial_workshop_footprint(TH, px, py, px + 19, py + 19, air) && tutorial_workshop_footprint(TH, px + 1, py + 1, px + 29, py + 40, tz) && !tutorial_workshop_footprint(TH, t_field[1], t_field[2] - 5, t_field[1] + 19, t_field[2] + 14, tz) && !tutorial_workshop_footprint(TH, t_plot[3] - 5, py, t_plot[3] + 1, py + 5, air) && !tutorial_workshop_footprint(TH, TO2[1] + 40, TO2[2] + 5, TO2[1] + 45, TO2[2] + 10, tz))

	// Each built exercise fits its fixtures inside the paved yard.
	var/text = TS.setup_workshop("car")
	var/obj/structure/car_workshop/practice/t_press = locate() in locate(px, py, tz)
	practice_probe_check("tutorial/press_bay", findtext(text, "automobile workshop") && t_press && t_press.bay_clear(VEHICLE_DRAUGHT_MAX) && t_press.allowed(TH) && (locate(/obj/item/ship_draught) in range(7, t_desk)))
	// Switching at the desk empties both yards on every level and keeps the rest.
	TS.props["workshop_selected"] = "Build a car or tank"
	TS.clear_workshop(t_desk)
	t_dug = locate(t_dug.x, t_dug.y, cave)
	t_up = locate(t_up.x, t_up.y, air)
	practice_probe_check("tutorial/switch_clears_yards", QDELETED(t_press) && !TS.props["workshop_selected"] && !QDELETED(t_desk) && !QDELETED(TH) && !QDELETED(t_board) && !QDELETED(t_stores[2]) && !QDELETED(t_stores[3]) && !(locate(/obj/item/ship_draught) in range(7, t_desk)) && istype(locate(px, py, tz), /turf/floor/plating/concrete))
	practice_probe_check("tutorial/switch_fills_tunnels", dug_underground_unformed(t_dug) && !(locate(/obj/item) in t_dug) && istype(locate(TO[1], t_dug.y, cave), /turf/wall/rockwall/bedrock) && underground_depth_of(cave) == 1)
	practice_probe_check("tutorial/switch_clears_storeys", istype(t_up, /turf/sky/building) && !(locate(/obj/item) in t_up) && istype(locate(t_beyond.x, t_beyond.y, air), /turf/floor/wood))
	TS.setup_workshop("air")
	var/obj/structure/car_workshop/airship_yard/practice/t_yard = locate() in locate(px, py, tz)
	practice_probe_check("tutorial/airship_bay", t_yard && t_yard.bay_clear(AIR_DRAUGHT_MAX) && TS.owns_rect(locate(t_yard.x + AIR_DRAUGHT_MAX, t_yard.y + AIR_DRAUGHT_MAX, tz), t_paved))
	TS.clear_workshop(t_desk)
	TS.setup_workshop("train")
	var/obj/structure/rail_works/practice/t_works = locate() in locate(px + 27, py, tz)
	var/track = 0
	var/turf/rail = t_works ? t_works.centre() : null
	while (rail && rail_straight_along(rail, SOUTH) && TS.owns_rect(rail, t_paved))
		track++
		rail = get_step(rail, NORTH)
	practice_probe_check("tutorial/train_track", t_works && (SOUTH in t_works.headings()) && track == 60)
	TS.clear_workshop(t_desk)
	practice_probe_check("tutorial/switch_lifts_track", !(locate(/obj/structure/rails) in locate(px + 29, py + 30, tz)) && !(locate(/obj/structure/rail_works) in locate(px + 27, py, tz)))
	TS.setup_workshop("ship")
	var/obj/structure/slipway/practice/t_slip = locate() in locate(px + 15, py, tz)
	var/list/t_berth = t_slip ? block(locate(t_slip.x - 2, t_slip.y + 1, tz), locate(t_slip.x + 2, t_slip.y + 5, tz)) : list()
	var/dry = TRUE
	for (var/turf/T in t_berth)
		if (!slipway_ground(T) || istype(T, /turf/floor/beach/water))
			dry = FALSE
	practice_probe_check("tutorial/ship_launches", t_slip && t_slip.dir == NORTH && t_berth.len == 25 && dry && t_slip.draught_landing(t_berth, 5) > 0)
	// The largest hull a sheet holds, built out over the pool.
	var/list/t_long = t_slip ? block(locate(px + 1, py + 1, tz), locate(px + 29, py + 40, tz)) : list()
	var/list/t_wide = t_slip ? block(locate(px, py + 1, tz), locate(px + 30, py + 40, tz)) : list()
	practice_probe_check("tutorial/large_ship_launches", t_slip && t_slip.draught_landing(t_long, 40) > 0 && t_slip.draught_landing(t_wide, 40) < 0 && istype(locate(px + 1, t_paved[4], tz), /turf/floor/beach/water) && istype(locate(px, t_paved[4], tz), /turf/floor/plating/concrete))
	TS.clear_workshop(t_desk)
	practice_probe_check("tutorial/switch_drains_pool", istype(locate(px + 10, py + 30, tz), /turf/floor/plating/concrete) && !(locate(/obj/structure/slipway) in locate(px + 15, py, tz)))
	TS.setup_workshop("rocket")
	var/obj/structure/rocket_works/practice/t_rocket = locate() in locate(px, py, tz)
	practice_probe_check("tutorial/rocket_output", t_rocket && t_rocket.output_turf() && t_rocket.allowed(TH))
	TS.clear_workshop(t_desk)
	text = TS.setup_workshop("house")
	practice_probe_check("tutorial/house_exercise", findtext(text, "as many storeys") && !(locate(/obj/structure) in locate(px, py, tz)) && (locate(/obj/item/ship_draught) in range(7, t_desk)))
	TS.clear_workshop(t_desk)
	text = TS.setup_workshop("sub")
	var/obj/structure/vehicleparts/axis/ship/submarine/controls/practice/sub = locate() in locate(px + 9, py + 7, tz)
	var/frames = 0
	for (var/turf/T in block(locate(px + 8, py + 3, tz), locate(px + 10, py + 7, tz)))
		if (locate(/obj/structure/vehicleparts/frame/ship/steel/submarine/section) in T)
			frames++
	practice_probe_check("workshop/submarine_hull", findtext(text, "five-row") && sub && frames == 15 && sub.session == TS && sub.depth_refusal(TRUE))
	var/sub_ground_ok = sub && sub.practice_site()
	if (sub)
		sub.forceMove(locate(px + 9, py + 7, air))
	var/sub_air_refused = sub && !sub.practice_site()
	if (sub)
		sub.forceMove(locate(px + 9, py + 7, cave))
	var/sub_cave_refused = sub && !sub.practice_site()
	if (sub)
		sub.forceMove(locate(px + 9, py + 7, tz))
	practice_probe_check("workshop/submarine_ground_only", sub_ground_ok && sub_air_refused && sub_cave_refused)
	practice_probe_check("workshop/no_restock", isnull(TS.setup_workshop("water")) && TS.props["workshop_kind"] == "sub")
	TS.clear_workshop(t_desk)
	text = TS.setup_workshop("harbor")
	practice_probe_check("workshop/harbor_spans", findtext(text, "two-span") && istype(locate(px + 9, py + 6, tz), /turf/floor/beach/water/shallowsaltwater) && istype(locate(px + 10, py + 6, tz), /turf/floor/beach/water/shallowsaltwater) && (locate(/obj/structure/workshop_machine/pile_driver) in locate(px + 8, py + 7, tz)) && (locate(/obj/item/weapon/bridge_span/timber) in range(7, TH)))
	TS.clear_workshop(t_desk)
	text = TS.setup_workshop("water")
	practice_probe_check("workshop/aqueduct_stock", findtext(text, "fountain") && istype(locate(px + 8, py + 6, tz), /turf/floor/beach/water) && (locate(/obj/item/stack/material/stone) in range(7, TH)))
	TH.forceMove(locate(px + 9, py + 6, tz))
	practice_probe_check("workshop/aqueduct_permission", tutorial_waterworks_recipe(TH, "/obj/structure/aqueduct_intake") && tutorial_waterworks_recipe(TH, "/obj/structure/aqueduct/channel") && tutorial_waterworks_recipe(TH, "/obj/structure/sink/aqueduct_fountain") && !tutorial_waterworks_recipe(TH, "/obj/structure/sewer_piece/drain/floor"))
	TH.forceMove(locate(t_field[1] + 5, t_field[2] + 5, tz))
	var/water_field_refused = !tutorial_waterworks_recipe(TH, "/obj/structure/aqueduct_intake")
	TH.forceMove(locate(px + 9, py + 6, air))
	practice_probe_check("workshop/water_ground_paved_only", water_field_refused && !tutorial_waterworks_recipe(TH, "/obj/structure/aqueduct_intake"))
	TH.forceMove(locate(TO2[1] + 35, TO2[2] + 20, tz))
	practice_probe_check("workshop/water_other_plot_refused", !tutorial_waterworks_recipe(TH, "/obj/structure/aqueduct_intake") && !tutorial_waterworks_recipe(null, "/obj/structure/aqueduct_intake"))
	TH.forceMove(get_step(t_desk, SOUTH))
	TS.clear_workshop(t_desk)
	TH.forceMove(locate(px + 9, py + 6, tz))
	practice_probe_check("workshop/water_permission_revoked", !tutorial_waterworks_recipe(TH, "/obj/structure/aqueduct_intake") && !TS.props["workshop_kind"])
	TH.forceMove(get_step(t_desk, SOUTH))
	text = TS.setup_workshop("mech")
	var/obj/structure/bell/t_bell = locate() in locate(px + 9, py + 7, tz)
	practice_probe_check("workshop/bell_fixture", findtext(text, "ring it") && t_bell && (locate(/obj/item/stack/material/rope) in range(7, TH)))
	practice_probe_check("workshop/cord_contained", t_bell && tutorial_workshop_pair(TH, TH.loc, t_bell) && !tutorial_workshop_pair(TH, t_bell, locate(TO2[1] + 2, TO2[2] + 2, tz)))
	TS.clear_workshop(t_desk)
	text = TS.setup_workshop("station")
	var/turf/centre = locate(px + 10, py + 6, tz)
	practice_probe_check("workshop/station_stock", findtext(text, "four tiles north") && (locate(/obj/item/habitat_kit/workshop) in range(7, TH)) && (locate(/obj/item/habitat_kit/airlock) in range(7, TH)))
	practice_probe_check("workshop/station_contained", centre && !habitat_module_refusal(centre, TH) && habitat_module_refusal(locate(t_shop[1] + 2, t_shop[2] + 7, tz), TH))
	practice_probe_check("workshop/station_other_plot_refused", !tutorial_station_module_site(TH, locate(TO2[1] + 35, TO2[2] + 20, tz), 2) && !tutorial_station_module_site(null, centre, 2) && !tutorial_station_module_site(TH, locate(px + 10, py + 6, air), 2) && !tutorial_station_module_site(TH, locate(px + 10, py + 6, cave), 2) && !tutorial_station_module_site(TH, locate(t_field[1] + 5, t_field[2] + 5, tz), 2))
	var/obj/item/habitat_kit/workshop/kit = locate() in range(7, TH)
	var/obj/structure/habitat_core/core = centre && kit ? habitat_unfold(centre, kit.kind, kit.core_type) : null
	practice_probe_check("workshop/station_unfolded", core && core.z == tz && istype(get_turf(core), /turf/floor/habitat))
	TS.clear_workshop(t_desk)
	practice_probe_check("workshop/station_reset", QDELETED(core) && !TS.props["workshop_kind"] && !tutorial_station_module_site(TH, locate(px + 10, py + 6, tz), 2))
	TH.forceMove(get_step(t_desk, SOUTH))
	// Leaving empties the whole plot on every level; the levels stay for the next trainee.
	var/turf/t_under_camp = locate(TO[1] + 15, TO[2] + 5, cave)
	t_under_camp = dug_underground_form(t_under_camp)
	t_under_camp.ChangeTurf(/turf/floor/dirt)
	TS.end(null)
	practice_probe_check("tutorial/room_closes", !R.sessions.len && world.maxz == 4 && !practice_room_z && QDELETED(t_desk) && QDELETED(t_stores[1]) && dug_underground_unformed(locate(TO[1] + 15, TO[2] + 5, cave)))
	// The next trainee's plot is walled on the levels that already exist.
	R.build_room(2)
	practice_probe_check("tutorial/next_plot_walled", istype(locate(TO2[1], TO2[2], cave), /turf/wall/rockwall/bedrock) && istype(locate(TO2[1] + 63, TO2[2] + 61, underground_z_at(2)), /turf/wall/rockwall/bedrock) && dug_underground_unformed(locate(TO2[1] + 5, TO2[2] + 5, cave)))
	R.wipe_room(2)

	practice_probe_check("tutorial/more_rooms", R.capacity() == 24 && isnull(world_z_budget.error(world.maxz + 1, "roof")) && world_z_budget.building_admitted(building_base_maxz() + 14) && !world_z_budget.building_admitted(building_base_maxz() + 15))
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
