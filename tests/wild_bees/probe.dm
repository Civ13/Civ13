// Native probe for wild bees and honey hunting (code/modules/1713/wild_bees.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/wild_bees/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 24
	maxy = 12
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/wild_bee_probe/New()
	return
/mob/living/human/wild_bee_probe/New()
	return
/mob/living/human/wild_bee_probe/adaptStat(statname, multiplier = 1, source = null)
	return
// A bare probe body has no icons to update: hands are just slots here.
/mob/living/human/wild_bee_probe/put_in_hands(obj/item/W)
	W.loc = src
	l_hand = W
	return TRUE
/mob/living/human/wild_bee_probe/drop_from_inventory(obj/item/W, atom/target = null)
	if (l_hand == W)
		l_hand = null
	if (r_hand == W)
		r_hand = null
	W.loc = target ? target : loc
	return TRUE

var/wb_failures = 0
var/wb_runtime_error = FALSE
/proc/wb_check(condition, label)
	if (!condition)
		wb_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	wb_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/wild_bee_probe
		populate_material_list()
		wild_bee_checks()
	catch(var/exception/e)
		wb_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = wb_failures, "runtime_error" = wb_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
	return

/proc/wb_count(turf/T, item_type)
	var/count = 0
	for (var/obj/item/I in T)
		if (istype(I, item_type))
			count++
	return count

/proc/wb_hold(mob/living/human/U, obj/item/I)
	I.loc = U
	U.hand = TRUE
	U.l_hand = I

/proc/wild_bee_checks()
	var/area/A = get_area(locate(1, 1, 1))
	A.location = AREA_OUTSIDE
	A.climate = "temperate"
	season = SEASON_SUMMER

	// Placement: only on a living tree, in a bee climate, fitted to the trunk.
	var/turf/bare = locate(2, 2, 1)
	wb_check(isnull(wild_bee_place_nest(bare)), "no nest without a tree")
	var/turf/tree_turf = locate(4, 2, 1)
	var/obj/structure/wild/tree/live_tree/tree = new(tree_turf)
	var/obj/structure/wild_bee_nest/nest = wild_bee_place_nest(tree_turf)
	wb_check(istype(nest) && nest.pixel_x == tree.pixel_x + tree.trunk_center_x - 15 && nest.pixel_y == tree.pixel_y, "a nest is placed on a living tree's trunk")
	wb_check(isnull(wild_bee_place_nest(tree_turf)), "one nest per tree")
	A.climate = "desert"
	var/turf/desert_turf = locate(6, 2, 1)
	new /obj/structure/wild/tree/live_tree(desert_turf)
	wb_check(isnull(wild_bee_place_nest(desert_turf)), "no nests in the desert")
	A.climate = "temperate"
	wb_check(nest in wild_bee_nests, "nests join the registry")

	// Season gate and refill.
	season = SEASON_WINTER
	wb_check(!wild_bee_season_active() && wild_bee_cycle(null) == 0, "nothing happens in winter")
	season = SEASON_WET
	wb_check(wild_bee_season_active(), "the wet season is active on tropical maps")
	season = SEASON_SUMMER
	nest.comb = 0
	for (var/i = 1, i <= 400, i++)
		wild_bee_cycle(null)
	wb_check(nest.comb == 4, "combs refill in season up to four")
	nest.occupied = FALSE
	nest.comb = 0
	for (var/i = 1, i <= 3000 && !nest.occupied, i++)
		wild_bee_cycle(null)
	wb_check(nest.occupied && nest.comb >= 1, "a swarm settles an empty nest again")

	// Smoked robbing takes one comb with no chase; the last comb empties it.
	var/mob/living/human/wild_bee_probe/hunter = new(tree_turf)
	var/obj/item/weapon/smoke_bundle/bundle = new(tree_turf)
	var/obj/effect/fire/flame = new(locate(5, 2, 1))
	wb_check(is_bee_smoke(bundle) == FALSE, "an unlit bundle is not smoke")
	bundle.light(null, flame)
	wb_check(bundle.lit && is_bee_smoke(bundle), "a lit bundle smokes")
	nest.comb = 2
	nest.attackby(bundle, hunter)
	wb_check(nest.smoked(), "smoke calms the nest")
	nest.rob(hunter, TRUE)
	wb_check(nest.comb == 1 && wb_count(tree_turf, /obj/item/weapon/reagent_containers/food/snacks/honeycomb) == 1, "a smoked nest gives up one comb")
	wb_check(hunter.bee_chase_until == 0, "no stings while the nest is smoked")
	nest.rob(hunter, TRUE)
	wb_check(!nest.occupied && nest.icon_state == "nest_empty", "taking the last comb drives the colony away")

	// Robbing unsmoked sets the bees on that one person only.
	var/turf/angry_turf = locate(10, 6, 1)
	new /obj/structure/wild/tree/live_tree(angry_turf)
	var/obj/structure/wild_bee_nest/angry = wild_bee_place_nest(angry_turf)
	angry.comb = 3
	var/mob/living/human/wild_bee_probe/robber = new(angry_turf)
	var/mob/living/human/wild_bee_probe/bystander = new(angry_turf)
	spawn(0) angry.rob(robber, TRUE)
	sleep(5)
	wb_check(robber.bee_chase_until > world.time && bystander.bee_chase_until == 0, "unsmoked robbing sets the bees on the robber alone")
	wb_check(locate(/obj/effect/bee_swarm) in angry_turf, "a swarm follows the robber")
	robber.loc = locate(22, 6, 1)
	// The probe world runs no timer subsystem: drive the next chase step here.
	robber.bee_chase_step(angry_turf, locate(/obj/effect/bee_swarm) in angry_turf)
	sleep(5)
	var/swarm_left = FALSE
	for (var/obj/effect/bee_swarm/S in world)
		if (!QDELETED(S))
			swarm_left = TRUE
	wb_check(robber.bee_chase_until == 0 && !swarm_left, "the bees give up once the robber runs away")
	wb_check(angry.comb == 3, "running off cancels the comb")

	// Felling the tree drops the remaining combs.
	var/turf/fell_turf = locate(14, 2, 1)
	var/obj/structure/wild/tree/live_tree/fell_tree = new(fell_turf)
	var/obj/structure/wild_bee_nest/fell_nest = wild_bee_place_nest(fell_turf)
	fell_nest.comb = 2
	qdel(fell_tree)
	wb_check(QDELETED(fell_nest) && wb_count(fell_turf, /obj/item/weapon/reagent_containers/food/snacks/honeycomb) == 2, "a felled tree drops its nest's combs")

	// Comb to honey, wax and a candle.
	var/turf/work = locate(18, 8, 1)
	var/mob/living/human/wild_bee_probe/cook = new(work)
	var/obj/item/weapon/reagent_containers/glass/bucket/B = new(work)
	var/obj/item/weapon/reagent_containers/food/snacks/honeycomb/C = new(work)
	wb_hold(cook, C)
	C.resolve_attackby(B, cook)
	wb_check(QDELETED(C) && B.reagents.get_reagent_amount("honey") == 10, "squeezing comb runs its honey into a bucket")
	var/obj/item/weapon/crushed_comb/W = locate() in cook
	if (!W)
		W = locate() in work
	wb_check(istype(W), "squeezing leaves crushed comb")
	var/obj/effect/fire/work_fire = new(locate(19, 8, 1))
	if (W)
		wb_hold(cook, W)
		W.resolve_attackby(work_fire, cook)
	var/obj/item/weapon/beeswax/wax = locate() in cook
	if (!wax)
		wax = locate() in work
	wb_check(istype(wax) && QDELETED(W), "melting crushed comb gives beeswax")
	if (wax)
		wax.loc = work
		var/obj/item/stack/material/rope/R = new(work)
		R.amount = 2
		wax.attackby(R, cook)
		wb_check(QDELETED(wax) && R.amount == 1 && wb_count(work, /obj/item/weapon/flame/candle/beeswax) == 1, "a rope wick dipped in beeswax makes a beeswax candle")
	var/obj/item/weapon/flame/candle/beeswax/candle = locate() in work
	if (candle)
		candle.light()
		wb_check(candle.icon_state == "candle1_lit_beeswax", "a lit beeswax candle shows its flame")
		candle.wax = 100
		candle.update_icon()
		wb_check(candle.icon_state == "candle3_lit_beeswax", "a burnt-down beeswax candle shows its stub")
