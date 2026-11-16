// Mouse nest probe: settle growth, starving, the step clamp, the registry,
// emitted mice and the wild burrow target. Run with:
//   python3 tests/ecology_spawning/run_linux.py . tests/mouse_nests/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 20
	maxy = 20
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/mouse_probe/New()
	return
var/mouse_failures = 0
var/mouse_runtime_error = FALSE
/proc/mouse_check(condition, label)
	if (!condition)
		mouse_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	mouse_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/mouse_probe
		var/area/A = get_area(locate(1, 1, 1))
		A.location = AREA_OUTSIDE
		A.climate = "temperate"
		for (var/turf/T in block(locate(1, 1, 1), locate(20, 20, 1)))
			T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
		season = SEASON_SUMMER
		mouse_settle_checks()
		mouse_mob_checks()
		mouse_burrow_target_checks()
		mouse_food_checks()
		mouse_cat_checks()
		mouse_trap_checks()
		mouse_bait_flea_checks()
	catch(var/exception/e)
		mouse_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = mouse_failures, "runtime_error" = mouse_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/mouse_minutes_ago(minutes)
	return trap_minutes_text(trap_now_minutes() - minutes)

/proc/mouse_settle_checks()
	var/now = trap_now_minutes()
	var/obj/structure/mouse_nest/burrow/B = new(locate(5, 5, 1))
	mouse_check(B in mouse_nest_list, "a new burrow registers itself")
	mouse_check(B.icon_state == "burrow", "a burrow uses the burrow sprite")
	B.population = 0
	B.last_settle = mouse_minutes_ago(15)
	mouse_check(B.settle(now) == 3, "15 minutes settle three 5-minute steps")
	mouse_check(B.population == 2, "a burrow regrows to its floor of 2 and holds there without food (got [B.population])")
	mouse_check(B.settle(now) == 0, "a fresh settle applies nothing")

	B.last_settle = mouse_minutes_ago(100000)
	mouse_check(B.settle(now) == 12, "a long gap is clamped to 12 steps")

	season = SEASON_WINTER
	B.population = 0
	B.last_settle = mouse_minutes_ago(10)
	B.settle(now)
	mouse_check(B.population == 0, "an outdoor burrow does not breed in winter")
	season = SEASON_SUMMER

	var/obj/structure/mouse_nest/H = new(locate(10, 10, 1))
	H.population = 2
	H.last_settle = mouse_minutes_ago(5)
	H.settle(now)
	mouse_check(!QDELETED(H) && H.population == 1, "a house nest with no food loses a mouse each step")
	H.last_settle = mouse_minutes_ago(5)
	H.settle(now)
	mouse_check(QDELETED(H), "a starved house nest disappears")
	mouse_check(!(H in mouse_nest_list), "a deleted nest leaves the registry")

	var/obj/structure/mouse_nest/S = new(locate(12, 12, 1))
	S.population = 2
	S.update_icon()
	mouse_check(S.icon_state == "nest_light", "a small house nest looks light")
	S.population = 5
	S.update_icon()
	mouse_check(S.icon_state == "nest_used", "a middling house nest looks used")
	S.population = 8
	S.update_icon()
	mouse_check(S.icon_state == "nest_overrun", "a full house nest looks overrun")
	S.last_settle = mouse_minutes_ago(500)
	S.after_load()
	mouse_check(trap_minutes(S.last_settle) >= now, "loading restarts the settle clock")
	mouse_check(S.persistence_runtime_var("out_mice"), "out mice are never saved with the nest")
	qdel(S)
	qdel(B)

/proc/mouse_mob_checks()
	var/obj/structure/mouse_nest/N = new(locate(8, 8, 1))
	N.population = 4
	var/mob/living/simple_animal/mouse/M = new(locate(9, 8, 1))
	M.set_home(N)
	mouse_check(M in N.out_mice, "an emitted mouse is tracked by its nest")
	mouse_check(!M.should_save, "an emitted mouse is not saved")
	mouse_check(M in mouse_out_list, "an emitted mouse counts toward the world cap")
	N.mouse_returned(M)
	mouse_check(N.population == 4 && !(M in N.out_mice), "a mouse going home keeps the population")
	mouse_check(QDELETED(M) && !(M in mouse_out_list), "a mouse going home leaves the map")

	var/mob/living/simple_animal/mouse/K = new(locate(9, 8, 1))
	K.set_home(N)
	K.death()
	mouse_check(N.population == 3, "a killed mouse is one fewer in its nest")
	mouse_check(!(K in mouse_out_list), "a dead mouse leaves the out list")

	var/mob/living/simple_animal/mouse/L = new(locate(9, 8, 1))
	L.set_home(N)
	qdel(N)
	mouse_check(isnull(L.home) && L.stray, "digging out a nest strays the mice outside it")
	qdel(L)

	var/area/A = get_area(locate(1, 1, 1))
	time_of_day = "Midday"
	mouse_check(!mouse_active_time(locate(3, 3, 1)), "outdoor mice stay in at midday")
	time_of_day = "Night"
	mouse_check(mouse_active_time(locate(3, 3, 1)), "outdoor mice come out at night")
	time_of_day = "Midday"
	A.location = AREA_INSIDE
	mouse_check(mouse_active_time(locate(3, 3, 1)), "indoor mice keep their own hours")
	A.location = AREA_OUTSIDE

	var/mob/living/simple_animal/mouse/T = new(locate(4, 4, 1))
	mouse_check(T.behaviour == "scared" && T.melee_damage_upper == 0, "mice are timid")
	qdel(T)

/proc/mouse_burrow_target_checks()
	var/datum/ecology_spawner/E = new
	E.habitat_hits = list("temperate|[ECO_GRASS]" = 600)
	var/datum/ecology_species/S = E.mouse_burrow_species()
	mouse_check(S.target == 1, "6,400 habitat tiles hold one burrow (got [S.target])")
	E.habitat_hits = list("temperate|[ECO_GRASS]" = 30000)
	S = E.mouse_burrow_species()
	mouse_check(S.target == 30, "a huge land is capped at 30 burrows (got [S.target])")
	E.habitat_hits = list("desert|[ECO_SAND]" = 30000)
	S = E.mouse_burrow_species()
	mouse_check(S.target == 0, "deserts hold no burrows")

/proc/mouse_clear(x1, y1, x2, y2)
	for (var/turf/T in block(locate(x1, y1, 1), locate(x2, y2, 1)))
		for (var/atom/movable/A in T)
			if (!ismob(A))
				qdel(A)

/proc/mouse_food_checks()
	mouse_clear(1, 1, 20, 20)
	for (var/obj/structure/mouse_nest/old in mouse_nest_list.Copy())
		qdel(old)
	var/now = trap_now_minutes()

	// Only a clay jar of food nearby: nothing reachable, the nest starves.
	var/obj/structure/storage_container/storage_jar/J = new(locate(6, 5, 1))
	new /obj/item/weapon/reagent_containers/food/snacks/meat(J.ensure_storage())
	var/obj/structure/mouse_nest/H = new(locate(5, 5, 1))
	H.population = 3
	mouse_check(H.reachable_food_units() == 0, "food in a clay jar is out of reach")
	H.last_settle = mouse_minutes_ago(5)
	H.settle(now)
	mouse_check(H.population == 2, "a nest beside only a jar loses a mouse (got [H.population])")
	mouse_check(J.ensure_storage().contents.len == 1, "the jar's food is untouched")

	// A basket of food is open: the nest grows and eats.
	var/obj/structure/storage_container/basket/B = new(locate(4, 5, 1))
	for (var/i = 1, i <= 6, i++)
		new /obj/item/weapon/reagent_containers/food/snacks/meat(B.ensure_storage())
	mouse_check(H.reachable_food_units() == 6, "a basket's food is open to mice")
	H.last_settle = mouse_minutes_ago(5)
	H.settle(now)
	mouse_check(H.population == 3, "a nest with plenty of food grows (got [H.population])")
	mouse_check(B.ensure_storage().contents.len == 5, "a nest of 2 eats one item a step (left [B.ensure_storage().contents.len])")
	var/fouled = 0
	for (var/obj/item/weapon/reagent_containers/food/F in B.ensure_storage().contents)
		if (F.rodent_fouled)
			fouled++
			mouse_check(findtext(F.name, "gnawed") == 1, "fouled food is named gnawed")
	mouse_check(fouled == 1, "eating fouls one more item in the same store (got [fouled])")

	// A log chest is gnawed at a quarter of the rate.
	var/obj/structure/storage_container/log_chest/L = new(locate(7, 7, 1))
	for (var/i = 1, i <= 8, i++)
		new /obj/item/weapon/reagent_containers/food/snacks/meat(L.ensure_storage())
	mouse_check(H.reachable_food_units() == 5 + 2, "eight items in a log chest count as two units")

	// Seeds and ripe crops.
	var/obj/item/stack/farming/seeds/S = new /obj/item/stack/farming/seeds/wheat(locate(5, 6, 1))
	S.amount = 3
	rodent_eat(S)
	mouse_check(S.amount == 2, "mice eat one seed from a stack")
	var/obj/structure/farming/plant/P = new /obj/structure/farming/plant/wheat(locate(5, 7, 1))
	P.stage = P.readyStageMin
	mouse_check(P.rodent_strip_harvest() && !QDELETED(P) && P.stage < P.readyStageMin, "mice eat a ripe crop but the plant lives")
	qdel(P)
	qdel(S)

	// Spreading needs soft ground, room and nobody watching.
	var/turf/stone = locate(15, 15, 1)
	stone.ChangeTurf(/turf/floor/plating, FALSE, FALSE)
	mouse_check(mouse_nest_site_error(stone) == "floor", "no nest on a hard floor")
	mouse_check(isnull(mouse_nest_site_error(locate(12, 12, 1))), "grass far from players takes a nest")
	var/turf/wood = locate(13, 13, 1)
	wood.ChangeTurf(/turf/floor/wood, FALSE, FALSE)
	mouse_check(isnull(mouse_nest_site_error(wood)), "a wooden floor takes a nest")
	new /obj/structure/mouse_nest(locate(10, 12, 1))
	new /obj/structure/mouse_nest(locate(10, 14, 1))
	mouse_check(mouse_nest_site_error(locate(12, 12, 1)) == "crowded", "three nests within 15 tiles crowd out a fourth")
	H.population = 8
	var/list/scan = H.forage_scan()
	var/before = mouse_nest_list.len
	for (var/obj/structure/mouse_nest/N in mouse_nest_list.Copy())
		if (N != H)
			qdel(N)
	before = mouse_nest_list.len
	var/obj/structure/mouse_nest/child = null
	for (var/i = 1, i <= 20 && !child, i++)
		child = H.try_spread(scan)
	mouse_check(child && mouse_nest_list.len == before + 1 && child.commensal, "a full nest founds a house nest beside a store")
	mouse_check(child && get_dist(child, H) <= 12, "the new nest is within spreading range")
	mouse_check(H.population == 6, "the colony takes two mice from the old nest (got [H.population])")

/proc/mouse_cat_checks()
	mouse_clear(1, 1, 20, 20)
	for (var/obj/structure/mouse_nest/old in mouse_nest_list.Copy())
		qdel(old)
	var/now = trap_now_minutes()
	var/obj/structure/mouse_nest/H = new(locate(5, 5, 1))
	var/obj/structure/storage_container/basket/B = new(locate(4, 5, 1))
	for (var/i = 1, i <= 7, i++)
		new /obj/item/weapon/reagent_containers/food/snacks/meat(B.ensure_storage())
	H.population = 5
	mouse_check(H.predator_pressure() == 0, "no cats, no pressure")
	var/mob/living/simple_animal/pet/cat/C = new(locate(8, 5, 1))
	mouse_check(H.predator_pressure() == 1, "a cat within 7 tiles hunts the nest")
	mouse_check(C in mouser_cat_list, "cats register for the cat cap")
	H.last_settle = mouse_minutes_ago(5)
	H.settle(now)
	mouse_check(H.population == 5, "a cat cancels a well-fed nest's growth (got [H.population])")
	var/before = mouse_nest_list.len
	H.population = 8
	for (var/i = 1, i <= 30, i++)
		H.last_settle = mouse_minutes_ago(5)
		H.population = 8
		H.settle(now)
	mouse_check(mouse_nest_list.len == before, "a nest with a cat nearby never spreads")
	qdel(C)
	var/mob/living/simple_animal/pet/dog/D = new(locate(8, 5, 1))
	mouse_check(H.predator_pressure() == 0.5, "a dog counts for half a cat")
	qdel(D)

	var/mob/living/simple_animal/pet/cat/wild/W = new(locate(15, 15, 1))
	mouse_check(W.wild && W.name == "wildcat", "a wildcat starts wild")
	mouse_check(ecology_wild_animal(W), "a wild wildcat counts toward the ecology census")
	var/mob/feeder = new /mob(locate(16, 15, 1))
	for (var/i = 1, i <= 6, i++)
		W.tame_feeding(feeder, now + i * 20)
	mouse_check(!W.wild && W.name == "cat", "six spaced feedings tame a wildcat into a cat")
	mouse_check(!ecology_wild_animal(W), "a tamed cat leaves the wild census")
	qdel(W)
	qdel(feeder)
	qdel(H)
	qdel(B)

/proc/mouse_trap_checks()
	mouse_clear(1, 1, 20, 20)
	for (var/obj/structure/mouse_nest/old in mouse_nest_list.Copy())
		qdel(old)
	var/obj/structure/mouse_nest/H = new(locate(5, 5, 1))
	var/obj/structure/storage_container/basket/B = new(locate(4, 5, 1))
	for (var/i = 1, i <= 10, i++)
		new /obj/item/weapon/reagent_containers/food/snacks/meat(B.ensure_storage())
	H.population = 4
	var/obj/item/weapon/mousetrap/T = new(locate(6, 6, 1))
	mouse_check(!T.rodent_ready(), "a new snap trap is sprung")
	var/mob/user = new /mob(locate(7, 7, 1))
	T.attack_self(user)
	mouse_check(T.rodent_ready() && T.icon_state == "mousetrap", "using a snap trap in hand sets it")
	H.settle_step()
	mouse_check(T.caught && T.icon_state == "mousetrap_caught", "a set snap trap near a nest catches a mouse")
	mouse_check(H.population == 4, "growth then the trap: 4 + 1 - 1 (got [H.population])")
	H.settle_step()
	mouse_check(H.population == 5, "a full snap trap catches nothing more (got [H.population])")
	T.attack_self(user)
	mouse_check(!T.caught && !T.armed, "emptying the trap leaves it sprung")
	mouse_check(locate(/mob/living/simple_animal/mouse) in get_turf(user), "emptying the trap drops the dead mouse")

	var/obj/structure/stone_age_trap/deadfall/D = new(locate(3, 3, 1))
	D.arm()
	mouse_check(!D.rodent_ready(), "an unbaited deadfall does not take mice")
	var/obj/item/weapon/reagent_containers/food/snacks/meat/bait = new(locate(3, 4, 1))
	D.attackby(bait, user)
	mouse_check(D.baited && D.icon_state == "deadfall_baited" && QDELETED(bait), "food baits a set deadfall")
	H.population = 3
	H.settle_step()
	mouse_check(D.catch_type == /mob/living/simple_animal/mouse && !D.armed && !D.baited, "a baited deadfall near a nest falls on a mouse")
	var/area/A = get_area(D)
	A.location = AREA_INSIDE
	mouse_check(D.catch_chance() == 0, "indoors a deadfall catches no game, only mice")
	var/obj/item/weapon/trap_kit/deadfall/K = new(locate(2, 2, 1))
	mouse_check(K.target_ok(locate(2, 3, 1)), "a deadfall kit can be set on an indoor floor")
	A.location = AREA_OUTSIDE
	qdel(K)
	qdel(D)
	qdel(T)
	qdel(H)
	qdel(B)
	qdel(user)

/proc/mouse_bait_flea_checks()
	mouse_clear(1, 1, 20, 20)
	for (var/obj/structure/mouse_nest/old in mouse_nest_list.Copy())
		qdel(old)
	var/obj/structure/mouse_nest/H = new(locate(5, 5, 1))
	H.population = 8
	var/obj/item/weapon/reagent_containers/food/snacks/mouse_poison_bait/P = new(locate(6, 6, 1))
	mouse_check(!rodent_food_item(P), "poison bait is not counted as food")
	H.forage_scan()
	mouse_check(P in H.scan_baits, "the nest finds bait near it")
	mouse_check(H.take_bait(H.scan_baits) == 3 && H.population == 5, "a dose of bait kills three mice")
	H.take_bait(H.scan_baits)
	H.take_bait(H.scan_baits)
	mouse_check(QDELETED(P), "bait is used up after three doses")

	var/mob/user = new /mob(locate(7, 7, 1))
	var/obj/item/weapon/reagent_containers/glass/G = new /obj/item/weapon/reagent_containers/glass/beaker(locate(7, 7, 1))
	mouse_check(!mouse_bait_poison_source(G), "an empty beaker is no poison")
	G.reagents.add_reagent("arsenic", 10)
	mouse_check(mouse_bait_poison_source(G), "5u of arsenic makes bait")
	mouse_check(mouse_bait_poison_source(new /obj/item/weapon/reagent_containers/food/snacks/grown/greenpotato(locate(8, 8, 1))), "a green potato makes bait")
	qdel(G)
	qdel(user)

	map.ordinal_age = 2
	H.population = 8
	H.overrun_steps = 0
	H.fleas = FALSE
	for (var/i = 1, i <= 6, i++)
		H.flea_step()
	mouse_check(H.fleas, "six overrun steps in the plague eras breed fleas")
	H.population = 4
	H.flea_step()
	mouse_check(!H.fleas, "thinning the nest clears the fleas")
	map.ordinal_age = 5
	H.population = 8
	for (var/i = 1, i <= 8, i++)
		H.flea_step()
	mouse_check(!H.fleas, "no fleas outside the plague eras")
	map.ordinal_age = 2
	map.mouse_fleas = FALSE
	for (var/i = 1, i <= 8, i++)
		H.flea_step()
	mouse_check(!H.fleas, "maps can switch fleas off")
	map.mouse_fleas = TRUE
	map.ordinal_age = 0
	var/obj/structure/mouse_nest/burrow/W = new(locate(15, 15, 1))
	W.population = 8
	for (var/i = 1, i <= 8, i++)
		W.flea_step()
	mouse_check(!W.fleas, "wild burrows never get fleas")
	qdel(W)
	qdel(H)
