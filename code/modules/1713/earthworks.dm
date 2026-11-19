// Earthworks: the steam roller and the steam shovel.
//
// Both are site machines like the cranes (power_cranes.dm): pulled into
// place, stoked with solid fuel counted in jobs, and worked from beside them.
// A job is one wait and nothing ticks.
//
// The steam roller lays a straight run of road from stone in its hopper and
// ends the job standing on the last tile it laid. The steam shovel digs the
// loose dirt and sand out of the ground within reach into piles at its foot.

#define ROLLER_TILE_TIME 8
#define ROLLER_MAX_RUN 12
#define ROLLER_STONE_LIMIT 60
#define SHOVEL_UNIT_TIME 8
#define SHOVEL_MAX_LOAD 12

// Road types a roller lays, in the order offered.
var/global/list/road_roller_types = list(
	"roman road" = /obj/covers/roads/roman,
	"cobble street" = /obj/covers/roads/cobble,
	"modern road" = /obj/covers/roads/modern,
)

/obj/structure/workshop_machine/steam_site
	name = "steam site machine"
	icon = 'icons/obj/earthworks.dmi'
	var/fuel = 0 // jobs it can still do
	var/fuel_limit = 40

/obj/structure/workshop_machine/steam_site/examine(mob/user, distance)
	..(user, distance)
	to_chat(user, SPAN_NOTICE("It has fuel for [round(fuel)] of [fuel_limit] jobs."))

// TRUE, with the reason told, when it cannot work for want of fuel.
/obj/structure/workshop_machine/steam_site/proc/out_of_fuel(mob/user)
	if (fuel >= 1)
		return FALSE
	to_chat(user, SPAN_WARNING("\The [src] has no steam. Load coal, charcoal or wood first."))
	return TRUE

// TRUE when the item was fuel and was dealt with.
/obj/structure/workshop_machine/steam_site/proc/stoke(obj/item/I, mob/living/human/H)
	var/obj/item/stack/S = I
	var/each = istype(S) ? solid_fuel_unit_value(S, steam_crane_fuel_rates) : 0
	if (!each)
		return FALSE
	var/moved = min(S.amount, round((fuel_limit - fuel) / each))
	if (moved <= 0)
		to_chat(H, SPAN_WARNING("\The [src]'s bunker is full."))
		return TRUE
	record_wood_fuel(S, moved * each)
	fuel += moved * each
	S.use(moved)
	visible_message(SPAN_NOTICE("[H] stokes \the [src]."))
	return TRUE

/obj/structure/workshop_machine/steam_site/proc/operator_ready(mob/living/human/H)
	return !QDELETED(src) && isturf(loc) && istype(H) && get_dist(src, H) <= 1 && H.z == z && !H.incapacitated() && !persistence_save_in_progress && !persistence_active_operation && !persistence_load_recovery_required

/obj/structure/workshop_machine/steam_site/attackby(obj/item/I, mob/living/human/H)
	if (!istype(H))
		return
	if (stoke(I, H))
		return
	if (handle_machine_tool(I, H))
		return
	return ..()

//////////////////////////////////////////////////////////////////////////////
// Steam roller

/obj/structure/workshop_machine/steam_site/road_roller
	name = "steam roller"
	desc = "A steam engine on three broad iron rolls, with a stone hopper. Load stone and fuel, stand behind it and click it with an empty hand: it rolls straight away from you and lays a road as it goes, one stone a tile, up to twelve tiles in a job. It must be unfastened to roll."
	icon_state = "steam_roller"
	var/stone = 0

/obj/structure/workshop_machine/steam_site/road_roller/examine(mob/user, distance)
	..(user, distance)
	to_chat(user, SPAN_NOTICE("Its hopper holds [stone] of [ROLLER_STONE_LIMIT] stone."))

/obj/structure/workshop_machine/steam_site/road_roller/dismantled()
	if (stone > 0)
		new /obj/item/stack/material/stone(get_turf(src), stone)
	..()

/obj/structure/workshop_machine/steam_site/road_roller/attackby(obj/item/I, mob/living/human/H)
	if (!istype(H))
		return
	if (I && I.type == /obj/item/stack/material/stone)
		var/obj/item/stack/material/stone/S = I
		var/moved = min(S.amount, ROLLER_STONE_LIMIT - stone)
		if (moved <= 0)
			to_chat(H, SPAN_WARNING("\The [src]'s hopper is full."))
			return
		stone += moved
		S.use(moved)
		visible_message(SPAN_NOTICE("[H] tips [moved] stone into \the [src]'s hopper."))
		return
	return ..()

// Why a road of this type cannot go on this tile, or null when it can.
/obj/structure/workshop_machine/steam_site/road_roller/proc/tile_problem(turf/T, road_type)
	if (!T || T.density || building_open_turf(T))
		return "there is no ground"
	if (istype(T, /turf/floor/beach/water) || istype(T, /turf/floor/lava))
		return "the ground is not solid"
	for (var/atom/movable/A in T)
		if (A != src && A.density)
			return "\the [A] is in the way"
	return tile_build_refusal(T, road_type)

// The tiles a job would pave, starting under the roller and running in direction.
/obj/structure/workshop_machine/steam_site/road_roller/proc/run_tiles(direction, road_type, list/why)
	var/list/run = list()
	var/turf/T = get_turf(src)
	var/limit = min(ROLLER_MAX_RUN, stone)
	while (T && run.len < limit)
		var/problem = tile_problem(T, road_type)
		if (problem)
			if (why)
				why += problem
			break
		run += T
		T = get_step(T, direction)
	return run

/obj/structure/workshop_machine/steam_site/road_roller/attack_hand(mob/living/human/H)
	if (!istype(H))
		return
	if (busy)
		to_chat(H, SPAN_WARNING("\The [src] is already rolling."))
		return
	if (anchored)
		to_chat(H, SPAN_WARNING("Unfasten \the [src] first; it has to roll."))
		return
	if (out_of_fuel(H))
		return
	if (stone <= 0)
		to_chat(H, SPAN_WARNING("\The [src]'s hopper is empty. Load stone first."))
		return
	var/direction = get_dir(H, src)
	if (!direction || (direction & (direction - 1)))
		to_chat(H, SPAN_WARNING("Stand straight behind \the [src], facing the way the road should run."))
		return
	var/list/choices = list()
	for (var/label in road_roller_types)
		if (crafting_recipe_allowed(H, "[road_roller_types[label]]"))
			choices += label
	if (!length(choices))
		to_chat(H, SPAN_WARNING("You do not know how to lay any road yet."))
		return
	var/choice = length(choices) == 1 ? choices[1] : player_input(H, "Which road should \the [src] lay?", "Steam roller", null, "anything", choices, TRUE)
	if (!choice || !(choice in choices) || busy || anchored || !operator_ready(H) || get_dir(H, src) != direction)
		return
	pave(H, direction, road_roller_types[choice])

// One job: the run is paved and the roller moved only when the whole wait succeeds.
/obj/structure/workshop_machine/steam_site/road_roller/proc/pave(mob/living/human/H, direction, road_type)
	if (busy || anchored || fuel < 1 || !operator_ready(H))
		return 0
	var/list/why = list()
	var/list/run = run_tiles(direction, road_type, why)
	if (!length(run))
		to_chat(H, SPAN_WARNING("\The [src] cannot lay a road here: [length(why) ? why[1] : "nothing to pave"]."))
		return 0
	busy = TRUE
	fuel = max(0, fuel - 1)
	icon_state = "steam_roller_on"
	visible_message(SPAN_NOTICE("[H] opens \the [src]'s regulator and it starts to roll."))
	var/done = do_after(H, max(10, ROLLER_TILE_TIME * length(run)), src)
	busy = FALSE
	if (QDELETED(src))
		return 0
	icon_state = initial(icon_state)
	if (!done || anchored || !operator_ready(H))
		to_chat(H, SPAN_WARNING("\The [src] stops; no road is laid."))
		return 0
	var/laid = 0
	var/turf/last = null
	for (var/turf/T in run)
		if (stone <= 0 || tile_problem(T, road_type) || !persistence_movement_allowed(src, T))
			break
		var/obj/covers/roads/R = new road_type(T)
		R.vertical = (direction == NORTH || direction == SOUTH) ? TRUE : FALSE
		R.dir = R.vertical ? 1 : 4
		R.icon_state = "[R.roadtype][R.vertical ? "vr" : "hr"]"
		stone -= 1
		laid += 1
		last = T
	if (last && last != loc)
		if (pulledby)
			pulledby.stop_pulling()
		persistence_set_loc(last)
	if (laid)
		visible_message(SPAN_NOTICE("\The [src] has laid [laid] tile\s of road."))
	else
		to_chat(H, SPAN_WARNING("\The [src] stops; no road is laid."))
	return laid

//////////////////////////////////////////////////////////////////////////////
// Steam shovel

/obj/structure/workshop_machine/steam_site/steam_shovel
	name = "steam shovel"
	desc = "A steam excavator with a dipper on a boom. Fasten it down, load fuel and click it with an empty hand: it digs the loose dirt and sand out of the ground within two tiles and heaps it at its foot, up to twelve piles in a job, or cuts the ground within reach down a level."
	icon_state = "steam_shovel"
	var/reach = 2

// Tiles within reach it can cut down a level, up to a load (not its own tile).
/obj/structure/workshop_machine/steam_site/steam_shovel/proc/cuttings()
	. = list()
	var/turf/here = get_turf(src)
	for (var/turf/floor/T in range(reach, here))
		if (length(.) >= SHOVEL_MAX_LOAD)
			break
		if (T == here || terrain_grade_problem(T, -1))
			continue
		. += T

// Cuts what it still can and heaps the spoil at the shovel's foot. Returns the tiles cut.
/obj/structure/workshop_machine/steam_site/steam_shovel/proc/cut_down(mob/living/human/H)
	var/turf/heap = get_turf(src)
	var/cut = 0
	for (var/turf/T in cuttings())
		var/grade = T.terrain_grade - 1
		if (!istype(T, /turf/floor/dirt) || istype(T, /turf/floor/dirt/winter))
			T = T.ChangeTurf(/turf/floor/dirt)
		T.terrain_grade = grade
		T.terrain_grade_apply()
		new /obj/item/weapon/barrier(heap)
		cut++
	if (cut)
		visible_message(SPAN_NOTICE("\The [src] cuts [cut] tile\s of ground down a level and heaps the spoil at its foot."))
	else if (H)
		to_chat(H, SPAN_WARNING("\The [src] finds no ground left to cut."))
	return cut

// list(turf = units to take) of loose dirt and sand within reach, up to a load.
/obj/structure/workshop_machine/steam_site/steam_shovel/proc/diggings()
	var/list/found = list()
	var/left = SHOVEL_MAX_LOAD
	for (var/turf/floor/T in range(reach, get_turf(src)))
		if (left <= 0)
			break
		if (locate(/obj/covers) in T)
			continue
		var/loose = 0
		if (istype(T, /turf/floor/dirt))
			loose = T.available_dirt
		else if (istype(T, /turf/floor/beach/sand))
			loose = T.available_sand
		loose = min(loose, left)
		if (loose > 0)
			found[T] = loose
			left -= loose
	return found

/obj/structure/workshop_machine/steam_site/steam_shovel/attack_hand(mob/living/human/H)
	if (!istype(H))
		return
	if (busy)
		to_chat(H, SPAN_WARNING("\The [src] is already digging."))
		return
	if (!anchored)
		to_chat(H, SPAN_WARNING("Fasten \the [src] down first."))
		return
	if (out_of_fuel(H))
		return
	var/list/found = diggings()
	var/list/cuts = cuttings()
	var/job = "dig"
	if (length(cuts) && length(found))
		job = input(H, "What should \the [src] do?", "Steam shovel") as null|anything in list("Dig loose earth", "Cut the ground down a level")
		if (!job || busy || !operator_ready(H))
			return
		job = job == "Dig loose earth" ? "dig" : "cut"
	else if (length(cuts))
		job = "cut"
	else if (!length(found))
		to_chat(H, SPAN_NOTICE("There is no loose dirt or sand left within [reach] tiles of \the [src], and no ground it can cut."))
		return
	if (job == "cut")
		steam_cut_job(H, length(cuts))
		return
	var/units = 0
	for (var/turf/T in found)
		units += found[T]
	busy = TRUE
	fuel = max(0, fuel - 1)
	icon_state = "steam_shovel_on"
	visible_message(SPAN_NOTICE("[H] sets \the [src] digging."))
	playsound(src, 'sound/effects/shovelling.ogg', 100, TRUE)
	var/done = do_after(H, max(10, SHOVEL_UNIT_TIME * units), src)
	busy = FALSE
	if (QDELETED(src))
		return
	icon_state = initial(icon_state)
	if (!done || !anchored || !operator_ready(H))
		to_chat(H, SPAN_WARNING("\The [src] stops; nothing is dug."))
		return
	dig(H)

/obj/structure/workshop_machine/steam_site/steam_shovel/proc/steam_cut_job(mob/living/human/H, tiles)
	busy = TRUE
	fuel = max(0, fuel - 1)
	icon_state = "steam_shovel_on"
	visible_message(SPAN_NOTICE("[H] sets \the [src] cutting the ground down."))
	playsound(src, 'sound/effects/shovelling.ogg', 100, TRUE)
	var/done = do_after(H, max(10, SHOVEL_UNIT_TIME * 2 * tiles), src)
	busy = FALSE
	if (QDELETED(src))
		return
	icon_state = initial(icon_state)
	if (!done || !anchored || !operator_ready(H))
		to_chat(H, SPAN_WARNING("\The [src] stops; nothing is cut."))
		return
	cut_down(H)

// Take what is still there and heap it at the shovel's foot. Returns the piles made.
/obj/structure/workshop_machine/steam_site/steam_shovel/proc/dig(mob/living/human/H)
	var/turf/heap = get_turf(src)
	var/list/found = diggings()
	var/dirt = 0
	var/sand = 0
	for (var/turf/floor/T in found)
		var/take = found[T]
		if (istype(T, /turf/floor/dirt))
			T.available_dirt -= take
			dirt += take
		else
			T.available_sand -= take
			sand += take
	for (var/i = 1 to dirt)
		new /obj/item/weapon/barrier(heap)
	if (sand > 0)
		new /obj/item/stack/ore/glass(heap, sand)
	if (dirt + sand > 0)
		visible_message(SPAN_NOTICE("\The [src] heaps up [dirt] pile\s of dirt and [sand] of sand."))
	else if (H)
		to_chat(H, SPAN_WARNING("\The [src] finds nothing left to dig."))
	return dirt + sand

#undef ROLLER_TILE_TIME
#undef ROLLER_MAX_RUN
#undef ROLLER_STONE_LIMIT
#undef SHOVEL_UNIT_TIME
#undef SHOVEL_MAX_LOAD
