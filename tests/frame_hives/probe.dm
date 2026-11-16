// Native probe for moveable-frame hives (code/modules/1713/beekeeping.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/frame_hives/probe.dm
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
		frame_hive_checks()
	catch(var/exception/e)
		wb_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = wb_failures, "runtime_error" = wb_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
/proc/wb_count(turf/T, item_type)
	var/count = 0
	for (var/obj/item/I in T)
		if (istype(I, item_type))
			count++
	return count

/proc/frame_hive_checks()
	var/area/A = get_area(locate(1, 1, 1))
	A.location = AREA_OUTSIDE
	A.climate = "temperate"
	season = SEASON_SUMMER

	// A new frame hive is empty, closed and can be pulled about.
	var/turf/home = locate(5, 5, 1)
	var/obj/structure/beehive/F = new(home)
	wb_check(F.closed && !F.bee_count && !F.anchored && F.icon_state == "frame_hive", "a new frame hive is closed, empty and movable")
	wb_check(F in frame_hives, "frame hives join the colony registry")
	var/mob/living/human/wild_bee_probe/keeper = new(locate(5, 4, 1))
	var/obj/item/hive_tool/tool = new(keeper)
	var/obj/item/honey_frame/plain = new(keeper)
	F.attackby(plain, keeper)
	wb_check(F.frames == 0 && !QDELETED(plain), "frames need the lid off")
	F.attackby(tool, keeper)
	wb_check(!F.closed && F.icon_state == "frame_hive_open", "the hive tool prises the lid off")
	F.attackby(plain, keeper)
	var/obj/item/honey_frame/drawn/D = new(keeper)
	F.attackby(D, keeper)
	wb_check(F.frames == 2 && F.drawn_frames == 1, "plain and drawn frames go in and are counted")

	// A swarm shakes into an empty frame hive and fixes it in place.
	var/obj/structure/bee_swarm_cluster/S = new(locate(6, 5, 1), 40)
	S.attack_hand(keeper)
	wb_check(QDELETED(S) && F.bee_count == 40 && F.anchored, "a swarm settles in an empty frame hive")

	// Growth fills frames, drawn comb fills faster, an open hive barely fills.
	F.attackby(tool, keeper)
	for (var/i = 1, i <= 8, i++)
		new /obj/structure/farming/plant/wheat(locate(1 + i, 8, 1))
	F.forage = 16
	F.forage_at = world.time
	F.colony_tick(TRUE, FALSE)
	var/first = F.honeycombs
	wb_check(first > 0 && F.bee_count > 40, "a closed colony in season grows and fills its frames")
	var/obj/structure/beehive/bare = new(locate(12, 5, 1))
	bare.settle(40)
	bare.frames = 2
	bare.forage = 16
	bare.forage_at = world.time
	bare.colony_tick(TRUE, FALSE)
	wb_check(first > bare.honeycombs * 1.4, "drawn comb fills faster than bare foundation ([first] vs [bare.honeycombs])")
	var/obj/structure/beehive/open = new(locate(14, 5, 1))
	open.settle(40)
	open.frames = 2
	open.closed = FALSE
	open.forage = 16
	open.forage_at = world.time
	open.colony_tick(TRUE, FALSE)
	wb_check(open.honeycombs < bare.honeycombs, "an open hive stores less")
	for (var/i = 1, i <= 100, i++)
		F.colony_tick(TRUE, FALSE)
	wb_check(F.honeycombs == F.frames * 100, "honey is capped by the frames in the hive")

	// Lifting frames: unsmoked brings stings, smoked gives full frames.
	F.closed = FALSE
	spawn(0) F.attack_hand(keeper)
	sleep(1)
	wb_check(keeper.bee_chase_until > world.time && F.frames == 2, "reaching into an unsmoked hive brings stings and no frames")
	keeper.bee_chase_until = 0
	var/obj/item/bee_smoker/smoker = new(keeper)
	var/obj/item/stack/material/leaf/leaves = new(keeper, 3)
	var/obj/item/flashlight/torch/torch = new(keeper)
	smoker.attackby(torch, keeper)
	wb_check(!smoker.lit, "an empty smoker will not light")
	smoker.attackby(leaves, keeper)
	wb_check(smoker.loads == 1 && leaves.amount == 2, "leaves load the smoker")
	smoker.lit = FALSE
	smoker.light(keeper)
	wb_check(is_bee_smoke(smoker) && smoker.icon_state == "bee_smoker_lit", "a lit smoker counts as bee smoke")
	F.attackby(smoker, keeper)
	wb_check(F.smoked(), "the smoker calms the hive")
	spawn(0) F.attack_hand(keeper)
	sleep(80)
	wb_check(F.frames == 0 && F.honeycombs == 0 && wb_count(home, /obj/item/honey_frame/filled) == 2, "both full frames come out of a smoked hive")
	wb_check(keeper.bee_chase_until == 0, "a smoked hive does not sting")
	smoker.burn_down(smoker.burn_generation)
	wb_check(!smoker.lit && smoker.loads == 0 && !is_bee_smoke(smoker), "the smoker burns out when its leaves are gone")

	// The extractor spins honey out and hands back drawn comb.
	var/turf/shed = locate(5, 2, 1)
	var/obj/structure/honey_extractor/E = new(shed)
	for (var/obj/item/honey_frame/filled/full in home)
		E.attackby(full, keeper)
	wb_check(E.loaded == 2, "full frames go in the extractor")
	keeper.loc = locate(5, 3, 1)
	E.attack_hand(keeper)
	wb_check(E.loaded == 0 && E.reagents.get_reagent_amount("honey") == 40 && wb_count(shed, /obj/item/honey_frame/drawn) == 2, "cranking gives 20 honey and a drawn frame per full frame")
	var/obj/item/weapon/reagent_containers/glass/bucket/pail = new(keeper)
	pail.flags |= OPENCONTAINER
	E.attackby(pail, keeper)
	wb_check(pail.reagents.get_reagent_amount("honey") == 40 && E.reagents.total_volume == 0, "the honey gate fills a bucket")

	// A strong smoked colony splits into a nucleus box, which starts a new hive.
	F.bee_count = 80
	F.smoked_until = world.time + 600
	var/obj/item/nucleus_box/nuc = new(keeper)
	F.attackby(nuc, keeper)
	wb_check(nuc.full && nuc.colony_strength == 40 && F.bee_count == 40 && nuc.icon_state == "nucleus_box_full", "splitting a strong hive fills the nucleus box")
	var/obj/structure/beehive/second = new(locate(8, 5, 1))
	second.closed = FALSE
	second.attackby(nuc, keeper)
	wb_check(second.bee_count == 40 && !nuc.full, "a full nucleus box starts a new colony")
	F.bee_count = 50
	F.attackby(nuc, keeper)
	wb_check(!nuc.full && F.bee_count == 50, "a weak colony will not split")

	// A swarm can be caught in an empty nucleus box.
	var/obj/structure/bee_swarm_cluster/S2 = new(locate(10, 10, 1), 35)
	S2.attackby(nuc, keeper)
	wb_check(QDELETED(S2) && nuc.full && nuc.colony_strength == 35, "an empty nucleus box catches a swarm")

	// The minute cycle ticks frame hives with the kept hives.
	var/before = second.honeycombs
	second.frames = 4
	second.closed = TRUE
	second.forage = 16
	second.forage_at = world.time
	kept_hive_cycle_count = 2
	kept_hive_cycle()
	wb_check(second.honeycombs > before, "kept_hive_cycle ticks frame hives too")

	// Out of season the colony eats its honey, then dies.
	second.honeycombs = 50
	second.bee_count = 100
	for (var/i = 1, i <= 400 && second.bee_count > 0, i++)
		second.colony_tick(FALSE, FALSE)
	wb_check(!second.bee_count && second.honeycombs == 0 && !second.anchored, "with no honey left the colony dies out")
