// Local ground pollution. Smoke from furnaces, factories, boilers and engines,
// and spilled fuel or chemicals, soil the ground around them. Soiled ground
// slows plant growth and heavily soiled ground stops it: crops, tree
// seedlings, wild plants, stump regrowth and tree spawners. Pollution clears
// slowly by itself, faster in rain and under trees, and crushed charcoal
// scattered on the ground soaks it up.
//
// Each floor turf keeps its own amount (0-100). It is saved with the turf
// only while it is above zero, like hill grading, and survives the turf being
// changed (ploughing, flooring). Only polluted turfs are registered, and one
// low-priority process decays them in bounded batches. Sources do not spread
// pollution themselves: they queue an amount on their turf, and the process
// spreads each queued turf once per run.

#define POLLUTION_MAX 100
#define POLLUTION_VISIBLE 15 // light soot stain
#define POLLUTION_SLOW 30 // plants grow at about half speed; no wild plants
#define POLLUTION_BLOCK 60 // nothing grows
#define POLLUTION_DECAY_PER_MINUTE 0.5
#define POLLUTION_DECAY_BATCH 1024
#define POLLUTION_EMIT_BATCH 128
#define POLLUTION_MAX_RADIUS 4
#define POLLUTION_STAIN_LAYER 2.006

var/global/list/polluted_turfs = list()
var/global/polluted_turfs_cursor = 1
// Queued emissions: turf -> amount, and turf -> largest radius asked for.
var/global/list/pollution_pending = list()
var/global/list/pollution_pending_radius = list()
var/global/list/pollution_stain_objects = list()
var/global/pollution_emitted_total = 0
var/global/pollution_cleaned_total = 0

/turf/var/pollution = 0
/turf/var/tmp/pollution_index = 0
/turf/var/tmp/pollution_decay_tick = 0
/turf/var/tmp/pollution_stain = 0

/turf/get_saved_vars()
	. = ..()
	if (pollution)
		. |= "pollution"

/turf/after_load()
	..()
	if (pollution)
		pollution_set(pollution)

// Ground that can hold pollution: floors, not open water.
/turf/proc/pollution_can_hold()
	return istype(src, /turf/floor) && !istype(src, /turf/floor/beach/water)

/turf/proc/pollution_set(amount)
	if (!isnum(amount) || !pollution_can_hold())
		amount = 0
	pollution = clamp(round(amount, 0.01), 0, POLLUTION_MAX)
	if (pollution > 0)
		if (!pollution_index)
			polluted_turfs += src
			pollution_index = polluted_turfs.len
			pollution_decay_tick = world.time
	else
		pollution_unregister()
	pollution_update_stain()

// Swap-remove, as the soil recovery registry does.
/turf/proc/pollution_unregister()
	if (!pollution_index)
		return
	var/index = pollution_index
	pollution_index = 0
	if (index <= polluted_turfs.len && polluted_turfs[index] == src)
		pollution_registry_remove_at(index)
	else
		polluted_turfs -= src

/proc/pollution_registry_remove_at(index)
	var/last = polluted_turfs.len
	if (index < 1 || index > last)
		return
	if (index != last)
		var/turf/moved = polluted_turfs[last]
		polluted_turfs[index] = moved
		if (istype(moved))
			moved.pollution_index = index
	polluted_turfs.len = last - 1

// ChangeTurf builds a new turf in the same place; it keeps the pollution and
// the registry slot of the turf it replaced (turf references are positional).
/turf/proc/pollution_take_over(amount, index)
	pollution_index = index
	pollution_decay_tick = world.time
	for (var/obj/effect/pollution_stain/S in vis_contents)
		vis_contents -= S
	pollution_stain = 0
	pollution_set(amount)

/proc/pollution_stain_level(amount)
	if (amount >= POLLUTION_BLOCK)
		return 3
	if (amount >= POLLUTION_SLOW)
		return 2
	if (amount >= POLLUTION_VISIBLE)
		return 1
	return 0

// Stains are shared objects in turf vis_contents, like hill shading: drawn
// just above the ground, never clickable, never saved.
/obj/effect/pollution_stain
	icon = 'icons/effects/pollution.dmi'
	layer = POLLUTION_STAIN_LAYER
	mouse_opacity = 0
	anchored = TRUE
	vis_flags = VIS_INHERIT_PLANE
	should_save = FALSE

/proc/pollution_stain_object(level, variant)
	var/key = "pollution[level]_[variant]"
	var/obj/effect/pollution_stain/S = pollution_stain_objects[key]
	if (!S)
		S = new
		S.icon_state = key
		pollution_stain_objects[key] = S
	return S

/turf/proc/pollution_update_stain()
	var/level = pollution_stain_level(pollution)
	if (level == pollution_stain)
		return
	var/variant = (x + y * 3) % 4
	if (pollution_stain)
		vis_contents -= pollution_stain_object(pollution_stain, variant)
	pollution_stain = level
	if (level)
		vis_contents += pollution_stain_object(level, variant)

// Adds (or with a negative amount removes) pollution on one turf and
// returns the change.
/proc/pollution_add(turf/T, amount)
	if (!istype(T) || !amount || !T.pollution_can_hold())
		return 0
	var/before = T.pollution
	T.pollution_set(before + amount)
	return T.pollution - before

// Spreads an amount around a turf: full at the centre, fading to nothing
// just past the radius. Returns the total change.
/proc/pollution_spread(turf/center, amount, radius)
	if (!istype(center) || !amount)
		return 0
	radius = clamp(round(radius), 0, POLLUTION_MAX_RADIUS)
	if (!radius)
		return pollution_add(center, amount)
	. = 0
	var/turf/low = locate(max(1, center.x - radius), max(1, center.y - radius), center.z)
	var/turf/high = locate(min(world.maxx, center.x + radius), min(world.maxy, center.y + radius), center.z)
	for (var/turf/T in block(low, high))
		var/distance = sqrt((T.x - center.x) ** 2 + (T.y - center.y) ** 2)
		if (distance > radius + 0.5)
			continue
		. += pollution_add(T, amount * (1 - distance / (radius + 1)))

// Sources call this: cheap, it only queues the amount on the source's turf.
/proc/pollution_emit(atom/source, amount, radius = 2)
	if (!source || !isnum(amount) || amount <= 0)
		return
	var/turf/T = get_turf(source)
	if (!T)
		return
	pollution_pending[T] += amount
	if (radius > pollution_pending_radius[T])
		pollution_pending_radius[T] = radius

/proc/pollution_flush_pending(budget = POLLUTION_EMIT_BATCH)
	var/done = 0
	while (pollution_pending.len && done < budget)
		var/turf/T = pollution_pending[1]
		var/amount = pollution_pending[T]
		var/radius = pollution_pending_radius[T]
		pollution_pending.Cut(1, 2)
		pollution_pending_radius -= T
		pollution_emitted_total += max(0, pollution_spread(T, amount, radius))
		done++
	return done

// Rain washes the ground and trees take pollution up, so both speed recovery.
/turf/proc/pollution_cleanup_factor()
	. = 1
	var/area/A = loc
	if (istype(A) && A.weather == WEATHER_WET)
		. += 1
	if ((locate(/obj/structure/wild/tree) in src) || (locate(/obj/structure/wild/palm) in src) || (locate(/obj/structure/wild/jungle) in src))
		. += 2
	else if (istype(src, /turf/floor/grass))
		. += 0.5

/turf/proc/pollution_decay()
	var/elapsed = clamp(world.time - pollution_decay_tick, 0, 10 MINUTES)
	pollution_decay_tick = world.time
	if (!elapsed)
		return
	pollution_set(pollution - POLLUTION_DECAY_PER_MINUTE * pollution_cleanup_factor() * elapsed / (1 MINUTE))

/proc/pollution_decay_batch(budget = POLLUTION_DECAY_BATCH)
	var/checks = min(budget, polluted_turfs.len)
	while (checks-- > 0 && polluted_turfs.len)
		if (polluted_turfs_cursor > polluted_turfs.len)
			polluted_turfs_cursor = 1
		var/index = polluted_turfs_cursor
		var/turf/T = polluted_turfs[index]
		if (!istype(T) || T.pollution_index != index)
			pollution_registry_remove_at(index)
			continue
		T.pollution_decay()
		if (T.pollution_index == index)
			polluted_turfs_cursor++

// Growth: soiled ground halves the chance of a growth step, heavily soiled
// ground stops it.
/proc/pollution_allows_growth(turf/T)
	if (!istype(T))
		return TRUE
	if (T.pollution >= POLLUTION_BLOCK)
		return FALSE
	if (T.pollution >= POLLUTION_SLOW)
		return prob(50)
	return TRUE

/obj/structure/farming/plant/advance_stage_if_allowed(allow_stage)
	if (allow_stage && !pollution_allows_growth(get_turf(src)))
		allow_stage = FALSE
	return ..(allow_stage)

/obj/structure/farming/plant/tree/process_interval(configured_seconds = 2)
	if (isturf(loc) && !persistence_active_operation && !vstatic && stage <= readyStageMax && !pollution_allows_growth(loc))
		last_growth_tick = world.time
		return
	return ..()

/obj/structure/farming/plant/farming_diagnostics(farming_skill)
	. = ..()
	var/turf/T = get_turf(src)
	if (!T || vstatic || stage > readyStageMax || farming_skill < 1.3)
		return
	if (T.pollution >= POLLUTION_BLOCK)
		. += "The ground here is too polluted for it to grow. Scatter crushed charcoal on it or wait for it to clear."
	else if (T.pollution >= POLLUTION_SLOW)
		. += "Pollution in the ground is slowing its growth."

/datum/flora_regrowth/plant_site_error(turf/T)
	if (istype(T) && T.pollution >= POLLUTION_SLOW)
		return "polluted"
	return ..()

/datum/flora_regrowth/regrow_stump(obj/structure/wild/tree_stump/regrowing/S)
	var/turf/T = S ? S.loc : null
	if (istype(T) && T.pollution >= POLLUTION_BLOCK)
		return null
	return ..()

/obj/effect/spawner/objspawner/spawnTarget()
	if (!ispath(create_path, /obj/structure/wild))
		return ..()
	var/turf/emptyTurf = getEmptyTurf()
	if (emptyTurf && emptyTurf.pollution < POLLUTION_BLOCK)
		new create_path(emptyTurf)

// Sources: fuel burnt in furnaces, factories, ovens, kilns and boilers.
/obj/structure/proc/fuel_pollution()
	if (istype(src, /obj/structure/furnace/kiln))
		return list(1, 2)
	if (istype(src, /obj/structure/furnace) || istype(src, /obj/structure/machinery/factory))
		return list(2, 3)
	return list(0.5, 1)

/obj/structure/burn_structure_fuel(requested)
	. = ..()
	if (. > 0)
		var/list/rate = fuel_pollution()
		pollution_emit(src, . * rate[1], rate[2])

// Cleanup: crushed charcoal soaks pollution up around the tile.
/turf/floor/attackby(obj/item/C as obj, mob/user as mob)
	if (istype(C, /obj/item/stack/ore/charcoal) && pollution >= 1 && ishuman(user))
		pollution_scatter_charcoal(C, user)
		return TRUE
	return ..()

/turf/floor/proc/pollution_scatter_charcoal(obj/item/stack/ore/charcoal/C, mob/living/human/user)
	if (get_dist(src, user) > 1)
		return FALSE
	user.visible_message(SPAN_NOTICE("[user] starts scattering crushed charcoal over the soiled ground."), SPAN_NOTICE("You start scattering crushed charcoal over the soiled ground."))
	if (!do_after(user, 30, src))
		return FALSE
	if (QDELETED(C) || C.amount < 1 || user.get_active_hand() != C || get_dist(src, user) > 1 || pollution < 1)
		return FALSE
	C.use(1)
	var/cleaned = -pollution_spread(src, -20, 1)
	pollution_cleaned_total += cleaned
	to_chat(user, SPAN_NOTICE("The charcoal soaks up the soot and oil. [pollution_ground_description()]"))
	return TRUE

/turf/proc/pollution_ground_description()
	if (pollution >= POLLUTION_BLOCK)
		return "The ground is fouled with soot and oil; nothing will grow here until it is cleaned."
	if (pollution >= POLLUTION_SLOW)
		return "The ground is grimy with soot and oil; plants grow slowly here."
	if (pollution >= POLLUTION_VISIBLE)
		return "The ground is stained with soot, but plants still grow here."
	if (pollution >= 1)
		return "The ground is faintly sooty."
	return "The ground looks clean."

/turf/floor/examine(mob/user, distance = -1, infix = "", suffix = "")
	. = ..()
	if (pollution >= 1 && user && get_dist(src, user) <= 2)
		to_chat(user, SPAN_NOTICE(pollution_ground_description()))
		if (ishuman(user))
			var/mob/living/human/H = user
			if (H.getStatCoeff("farming") >= 2.2)
				to_chat(user, "The ground's pollution is at <b>[round(pollution)]/[POLLUTION_MAX]</b>.")

/client/proc/pollution_status()
	set category = "Debug"
	set name = "Pollution Status"
	if (!check_rights(R_DEBUG))
		return
	var/heavy = 0
	var/peak = 0
	for (var/turf/T in polluted_turfs)
		if (T.pollution >= POLLUTION_BLOCK)
			heavy++
		peak = max(peak, T.pollution)
	to_chat(src, SPAN_NOTICE("Ground pollution: [polluted_turfs.len] polluted tiles, [heavy] too polluted to grow, peak [round(peak)]. Queued sources: [pollution_pending.len]. Emitted [round(pollution_emitted_total)], cleaned with charcoal [round(pollution_cleaned_total)]."))

/client/proc/set_local_pollution()
	set category = "Debug"
	set name = "Set Pollution Here"
	if (!check_rights(R_DEBUG))
		return
	var/turf/T = get_turf(mob)
	if (!T)
		return
	var/amount = player_input(src, "Pollution at the centre (0-[POLLUTION_MAX]); it fades over the radius. 0 clears the area.", "Set Pollution Here", 70, "num", null, TRUE)
	if (isnull(amount))
		return
	var/radius = player_input(src, "Radius in tiles (0-[POLLUTION_MAX_RADIUS]).", "Set Pollution Here", 3, "num", null, TRUE)
	if (isnull(radius))
		return
	amount = clamp(amount, 0, POLLUTION_MAX)
	radius = clamp(round(radius), 0, POLLUTION_MAX_RADIUS)
	for (var/turf/near in block(locate(max(1, T.x - radius), max(1, T.y - radius), T.z), locate(min(world.maxx, T.x + radius), min(world.maxy, T.y + radius), T.z)))
		var/distance = sqrt((near.x - T.x) ** 2 + (near.y - T.y) ** 2)
		if (distance <= radius + 0.5)
			near.pollution_set(amount * (1 - distance / (radius + 1)))
	log_admin("[key_name(src)] set ground pollution [amount] radius [radius] at ([T.x],[T.y],[T.z]).")
	message_admins("[key_name(src)] set ground pollution [amount] radius [radius] at ([T.x],[T.y],[T.z]).", key_name(src))

#undef POLLUTION_MAX
#undef POLLUTION_VISIBLE
#undef POLLUTION_SLOW
#undef POLLUTION_BLOCK
#undef POLLUTION_DECAY_PER_MINUTE
#undef POLLUTION_DECAY_BATCH
#undef POLLUTION_EMIT_BATCH
#undef POLLUTION_MAX_RADIUS
#undef POLLUTION_STAIN_LAYER
