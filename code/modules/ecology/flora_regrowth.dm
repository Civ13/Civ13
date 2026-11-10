// Natural flora regrowth on maps that opt in (every Nomads map by default).
//
// Wild plants: a few ripe crops (grains, vegetables, herbs, fibre plants)
// grow sparsely on natural outdoor ground that suits their biome and the
// current season, away from settlements and out of every player's view.
// They do not grow or need water; harvest them like a farmed crop for produce
// and seeds. Out of season they wither away a few at a time.
//
// Tree regrowth: a tree chopped down leaves a stump that remembers the tree.
// Once in a while (on average every few hours) the stump grows back into that
// tree, outside winter and while nobody is watching. Dig a stump out with a
// shovel, or chop it, to keep cleared land clear.
//
// Cost: one worker wakes once a minute. It visits each stump with one prob()
// call, tries at most FLORA_PLANT_BUDGET plant sites, and samples a few
// hundred turfs every half hour to size the wild plant target. Nothing here
// scans the world. Stumps and wild plants are ordinary saved objects; their
// registries are runtime lists rebuilt by New() and after_load().

#define FLORA_CYCLE (60 SECONDS)
#define FLORA_WARMUP (2 MINUTES)
#define FLORA_VIEW_MARGIN 12
#define FLORA_SETTLEMENT_RANGE 3
#define FLORA_PLANT_BUDGET 4
#define FLORA_PLANT_ATTEMPTS 12
#define FLORA_WITHER_BUDGET 8
#define FLORA_HABITAT_SAMPLES 600
#define FLORA_HABITAT_REFRESH (30 MINUTES)

var/global/datum/flora_regrowth/flora_regrowth = null
var/global/list/wild_plant_list = list()
var/global/list/regrowing_stump_list = list()

/obj/map_metadata
	var/flora_regrowth = FALSE // Wild plants and stump regrowth.
	var/wild_plant_density = 2.5 // Wild plants per 1000 tiles of natural outdoor ground.
	var/wild_plant_cap = 250
	var/stump_regrowth_minutes = 240 // Average minutes for a stump to grow back.

/obj/map_metadata/nomads
	flora_regrowth = TRUE

// Author policy: code changes take effect on load instead of a saved copy.
/obj/map_metadata/persistence_runtime_var(var/key)
	if (key == "flora_regrowth" || key == "wild_plant_density" || key == "wild_plant_cap" || key == "stump_regrowth_minutes")
		return TRUE
	return ..(key)

// Wild crops: picked by the plant's own biomes and seasons.
/proc/wild_plant_pool()
	return list(
		/obj/structure/farming/plant/herbs = 4,
		/obj/structure/farming/plant/mushroom = 3,
		/obj/structure/farming/plant/wheat = 2,
		/obj/structure/farming/plant/oat = 2,
		/obj/structure/farming/plant/barley = 2,
		/obj/structure/farming/plant/rice = 2,
		/obj/structure/farming/plant/potato = 2,
		/obj/structure/farming/plant/carrot = 2,
		/obj/structure/farming/plant/cabbage = 1,
		/obj/structure/farming/plant/turnip = 2,
		/obj/structure/farming/plant/parsnip = 1,
		/obj/structure/farming/plant/beans = 1,
		/obj/structure/farming/plant/tomato = 1,
		/obj/structure/farming/plant/corn = 1,
		/obj/structure/farming/plant/pumpkin = 1,
		/obj/structure/farming/plant/zucchini = 1,
		/obj/structure/farming/plant/redpepper = 1,
		/obj/structure/farming/plant/celery = 1,
		/obj/structure/farming/plant/parsley = 1,
		/obj/structure/farming/plant/grapes = 1,
		/obj/structure/farming/plant/watermelon = 1,
		/obj/structure/farming/plant/agave = 1,
		/obj/structure/farming/plant/juniper = 1,
		/obj/structure/farming/plant/flax = 2,
		/obj/structure/farming/plant/cotton = 2,
	)

/////// Wild plants

/obj/structure/farming/plant
	var/wild = FALSE // grown by flora regrowth: ripe, static, not tended

// A wild plant neither grows nor dries out; it waits to be harvested.
/obj/structure/farming/plant/growth()
	if (wild)
		return
	return ..()

/obj/structure/farming/plant/proc/make_wild()
	wild = TRUE
	stage = readyStageMin
	plant_nutrition = 50 // an ordinary yield, not a fertilised field's
	water = max_water
	var/sprite_name = sprite_plant ? sprite_plant : plant
	icon_state = "[sprite_name]-harvest"
	name = "wild [plant] plant"
	desc = "A wild [plant] plant, ready to harvest with a knife, scythe or hatchet."
	wild_plant_list |= src

/obj/structure/farming/plant/after_load()
	. = ..()
	if (wild)
		wild_plant_list |= src

/obj/structure/farming/plant/Destroy()
	wild_plant_list -= src
	return ..()

/obj/structure/farming/plant/Del()
	wild_plant_list -= src
	..()

/////// Stumps that grow back

/obj/structure/wild/tree_stump/regrowing
	desc = "What is left of a felled tree. Given time it may grow back; dig it out with a shovel to keep the land clear."
	var/regrow_type = /obj/structure/wild/tree/live_tree

/obj/structure/wild/tree_stump/regrowing/New()
	..()
	icon_state = pick("tree_stump", "tree_stump2")
	regrowing_stump_list |= src

/obj/structure/wild/tree_stump/regrowing/get_saved_vars()
	. = ..()
	// Wild objects save an allowlist; the tree to regrow is part of the stump.
	. |= "regrow_type"

/obj/structure/wild/tree_stump/regrowing/after_load()
	. = ..()
	if (!ispath(regrow_type, /obj/structure/wild))
		regrow_type = /obj/structure/wild/tree/live_tree
	regrowing_stump_list |= src

/obj/structure/wild/tree_stump/regrowing/Destroy()
	regrowing_stump_list -= src
	return ..()

/obj/structure/wild/tree_stump/regrowing/Del()
	regrowing_stump_list -= src
	..()

/obj/structure/wild/tree_stump/regrowing/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/weapon/material/shovel))
		user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
		user.visible_message(SPAN_NOTICE("[user] starts digging out \the [src]."), SPAN_NOTICE("You start digging out \the [src]."))
		if (do_after(user, 50, src))
			if (QDELETED(src))
				return TRUE
			user.visible_message(SPAN_NOTICE("[user] digs out \the [src]."), SPAN_NOTICE("You dig out \the [src]."))
			qdel(src)
		return TRUE
	return ..()

// The tree a felled tree grows back as, or null when it should not regrow.
/proc/flora_regrow_type(obj/structure/wild/W)
	if (istype(W, /obj/structure/wild/tree/live_tree))
		return W.type
	if (istype(W, /obj/structure/wild/palm))
		return /obj/structure/wild/palm
	if (istype(W, /obj/structure/wild/jungle))
		if (istype(W, /obj/structure/wild/jungle/acacia/dead) || istype(W, /obj/structure/wild/jungle/medpine/dead) || istype(W, /obj/structure/wild/jungle/cherry/dead) || istype(W, /obj/structure/wild/jungle/yucca))
			return null
		return W.type
	return null

// A tree cut down to zero health (chopping) leaves a stump. Fire, shells,
// admin deletes and world loads destroy trees at other health and leave none.
/obj/structure/wild/Destroy()
	if (health <= 0 && map && map.flora_regrowth && !persistence_active_operation && !persistence_save_in_progress)
		var/regrow = flora_regrow_type(src)
		var/turf/T = get_turf(src)
		if (regrow && T && !(locate(/obj/structure/wild/tree_stump) in T))
			var/obj/structure/wild/tree_stump/regrowing/S = new(T)
			S.regrow_type = regrow
	return ..()

/////// The worker

/datum/flora_regrowth
	should_save = FALSE
	var/tmp/enabled = FALSE
	var/tmp/loop_generation = 0
	var/tmp/started_at = 0
	var/tmp/habitat_tiles = 0
	var/tmp/habitat_at = -1
	var/tmp/plant_target = 0
	var/tmp/plants_grown = 0
	var/tmp/plants_withered = 0
	var/tmp/trees_regrown = 0
	var/tmp/last_report = "not started"
	var/tmp/list/plant_fit = list() // path -> list(biomes, seasons), read from a real plant

/datum/flora_regrowth/persistence_runtime_var(key)
	if (key in list("enabled", "loop_generation", "started_at", "habitat_tiles", "habitat_at", "plant_target", "plants_grown", "plants_withered", "trees_regrown", "last_report", "plant_fit"))
		return TRUE
	return ..()

/datum/flora_regrowth/proc/start()
	if (enabled)
		return FALSE
	enabled = TRUE
	started_at = world.time
	habitat_at = -1
	loop_generation++
	var/generation = loop_generation
	spawn (0)
		while (enabled && generation == loop_generation)
			cycle()
			sleep(FLORA_CYCLE)
	return TRUE

/datum/flora_regrowth/proc/stop()
	if (!enabled)
		return FALSE
	enabled = FALSE
	loop_generation++
	return TRUE

// Natural outdoor ground a wild plant may stand on.
/proc/flora_ground(turf/T)
	return ecology_ground(T) & (ECO_GRASS | ECO_DIRT | ECO_SAND)

// Player construction, fields or crops close by: leave the land to its owner.
/proc/flora_near_settlement(turf/T, range = FLORA_SETTLEMENT_RANGE)
	for (var/obj/O in range(range, T))
		if (istype(O, /obj/covers) || istype(O, /obj/roof))
			return TRUE
		if (istype(O, /obj/structure) && !istype(O, /obj/structure/wild))
			return TRUE
	for (var/turf/floor/dirt/ploughed/P in range(range, T))
		return TRUE
	return FALSE

// Estimates natural outdoor ground from random samples; never scans the world.
/datum/flora_regrowth/proc/size_plant_target()
	var/hits = 0
	for (var/i = 1, i <= FLORA_HABITAT_SAMPLES, i++)
		var/turf/T = locate(rand(1, world.maxx), rand(1, world.maxy), rand(1, world.maxz))
		if (flora_ground(T) && ecology_outdoor_climate(T))
			hits++
	habitat_tiles = round(world.maxx * world.maxy * world.maxz * hits / FLORA_HABITAT_SAMPLES)
	var/density = map ? map.wild_plant_density : 2.5
	var/cap = map ? map.wild_plant_cap : 250
	plant_target = clamp(round(habitat_tiles * density / 1000), 0, cap)
	habitat_at = world.time

/datum/flora_regrowth/proc/plant_site_error(turf/T)
	if (!flora_ground(T))
		return "ground"
	if (!ecology_outdoor_climate(T))
		return "habitat"
	if (!istype(T, /turf/floor))
		return "ground"
	var/turf/floor/F = T
	if (!F.isemptyfloor() || (locate(/mob/living) in T) || (locate(/obj/item) in T))
		return "occupied"
	if (ecology_visible_to_players(T, FLORA_VIEW_MARGIN))
		return "seen"
	if (flora_near_settlement(T))
		return "settled"
	return null

// Biomes and seasons of a plant type, read once from a real instance.
/datum/flora_regrowth/proc/plant_fits(path, climate, obj/structure/farming/plant/P = null)
	var/list/fit = plant_fit[path]
	if (!fit && P)
		fit = list(P.biomes.Copy(), P.seasons.Copy())
		plant_fit[path] = fit
	if (!fit)
		return null
	var/list/biomes = fit[1]
	var/list/seasons = fit[2]
	return (climate in biomes) && (season in seasons)

// Grows one wild plant suited to T, or returns null.
/datum/flora_regrowth/proc/grow_plant(turf/T)
	var/climate = ecology_outdoor_climate(T)
	var/list/pool = wild_plant_pool()
	var/list/order = list()
	while (pool.len)
		var/path = pickweight(pool)
		pool -= path
		order += path
	for (var/path in order)
		var/known = plant_fits(path, climate)
		if (known == FALSE)
			continue
		var/obj/structure/farming/plant/P = new path(T)
		if (!plant_fits(path, climate, P))
			qdel(P)
			continue
		P.make_wild()
		return P
	return null

// Out of season, unseen wild plants wither a few at a time.
/datum/flora_regrowth/proc/wither_plants()
	var/withered = 0
	var/remaining = min(wild_plant_list.len, FLORA_WITHER_BUDGET * 4)
	while (remaining > 0 && wild_plant_list.len && withered < FLORA_WITHER_BUDGET)
		var/obj/structure/farming/plant/P = wild_plant_list[1]
		wild_plant_list.Cut(1, 2)
		remaining--
		if (QDELETED(P) || !P.wild)
			continue
		if (season in P.seasons)
			wild_plant_list += P
			continue
		var/turf/T = get_turf(P)
		if (T && ecology_visible_to_players(T, FLORA_VIEW_MARGIN))
			wild_plant_list += P
			continue
		qdel(P)
		withered++
	plants_withered += withered
	return withered

/datum/flora_regrowth/proc/regrow_stumps()
	var/minutes = map ? map.stump_regrowth_minutes : 240
	if (minutes <= 0 || season == "WINTER")
		return 0
	var/chance = 100 / minutes
	var/grown = 0
	for (var/obj/structure/wild/tree_stump/regrowing/S in regrowing_stump_list.Copy())
		if (!prob(chance))
			continue
		if (QDELETED(S) || !isturf(S.loc))
			regrowing_stump_list -= S
			continue
		if (regrow_stump(S))
			grown++
	trees_regrown += grown
	return grown

// Grows the stump back into its tree when the tile is still open, outdoor
// and unwatched. Returns the new tree or null.
/datum/flora_regrowth/proc/regrow_stump(obj/structure/wild/tree_stump/regrowing/S)
	var/turf/T = S.loc
	if (!ecology_outdoor_climate(T) || (locate(/obj/roof) in T))
		return null
	if (ecology_site_blocked(T, S))
		return null
	if (ecology_visible_to_players(T, FLORA_VIEW_MARGIN))
		return null
	var/path = ispath(S.regrow_type, /obj/structure/wild) ? S.regrow_type : /obj/structure/wild/tree/live_tree
	qdel(S)
	var/obj/structure/wild/W = new path(T)
	if (istype(W, /obj/structure/wild/tree/live_tree))
		var/obj/structure/wild/tree/live_tree/L = W
		L.change_season()
	return W

/datum/flora_regrowth/proc/cycle()
	if (!enabled)
		return 0
	if (persistence_active_operation || persistence_save_in_progress)
		last_report = "paused for a world save"
		return 0
	if (world.time - started_at < FLORA_WARMUP)
		last_report = "warming up"
		return 0
	if (habitat_at < 0 || world.time - habitat_at > FLORA_HABITAT_REFRESH)
		size_plant_target()
	var/regrown = regrow_stumps()
	var/withered = wither_plants()
	var/grown = 0
	var/missing = plant_target - wild_plant_list.len
	for (var/i = 1, i <= min(missing, FLORA_PLANT_BUDGET), i++)
		for (var/try_n = 1, try_n <= FLORA_PLANT_ATTEMPTS, try_n++)
			var/turf/T = locate(rand(1, world.maxx), rand(1, world.maxy), rand(1, world.maxz))
			if (plant_site_error(T))
				continue
			if (grow_plant(T))
				grown++
				break
	plants_grown += grown
	last_report = "[wild_plant_list.len]/[plant_target] wild plants (+[grown], -[withered] withered), [regrowing_stump_list.len] stumps, +[regrown] trees regrown; totals: [plants_grown] plants, [trees_regrown] trees"
	return grown + regrown

// Started by the ticker once a round is playing, including after a world load.
/proc/flora_autostart_check()
	if (!map || !map.flora_regrowth)
		return
	if (!ticker || ticker.current_state != GAME_STATE_PLAYING)
		return
	if (flora_regrowth && flora_regrowth.enabled)
		return
	if (!flora_regrowth)
		flora_regrowth = new
	flora_regrowth.start()
	log_game("Flora regrowth started on [map.title].")

#undef FLORA_CYCLE
#undef FLORA_WARMUP
#undef FLORA_VIEW_MARGIN
#undef FLORA_SETTLEMENT_RANGE
#undef FLORA_PLANT_BUDGET
#undef FLORA_PLANT_ATTEMPTS
#undef FLORA_WITHER_BUDGET
#undef FLORA_HABITAT_SAMPLES
#undef FLORA_HABITAT_REFRESH
