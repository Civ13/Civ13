// Building collapse: one queue for every roof that may have lost its support.
//
// A roof asks to be checked (collapse_check) when a wall, pillar or floor near
// it goes. Checks wait in three first-in-first-out queues instead of one
// spawn() each, and a pass handles at most BUILDING_COLLAPSE_PER_PASS of them,
// so a whole house coming down spreads over a few seconds instead of freezing
// a tick. Nothing runs while the queues are empty.
//
// - fast: a support was knocked out. After 3 s an unsupported roof creaks and
//   sheds dust, and goes on the final queue.
// - final: 2 s after the creak, a roof that is still unsupported falls.
// - slow: a support wore out (seasonal weathering). The roof sags for a minute
//   first (sag() in roof_stuff.dm).
//
// A falling roof hurts people under it by what it is made of, leaves rubble,
// and lands on the floor below: a heavy roof can break a weak floor, which
// takes its own roof and everything on it down a level (pancaking). Walls and
// pillars standing on a floor that gives way fall too (building_remove_roof()
// in building_levels.dm), and each of those asks the roofs it held to check.

#define BUILDING_COLLAPSE_FAST_DELAY 30
#define BUILDING_COLLAPSE_FINAL_DELAY 20
#define BUILDING_COLLAPSE_SLOW_DELAY 10
#define BUILDING_COLLAPSE_PASS_DELAY 2
#define BUILDING_COLLAPSE_PER_PASS 40
// Force of a falling wooden roof on the floor under it, in wood-part hit points.
#define BUILDING_DEBRIS_FORCE 60

// roof -> world.time it is due, in the order they were queued.
var/global/list/building_collapse_fast = list()
var/global/list/building_collapse_final = list()
var/global/list/building_collapse_slow = list()
var/global/building_collapse_running = FALSE

/proc/building_collapse_queue(obj/roof/R, slow = FALSE)
	if (!R || QDELETED(R))
		return
	if (slow)
		if (!building_collapse_slow[R])
			building_collapse_slow[R] = world.time + BUILDING_COLLAPSE_SLOW_DELAY
	else if (!building_collapse_fast[R] && !building_collapse_final[R])
		building_collapse_fast[R] = world.time + BUILDING_COLLAPSE_FAST_DELAY
	building_collapse_wake()

/proc/building_collapse_pending()
	return length(building_collapse_fast) + length(building_collapse_final) + length(building_collapse_slow)

/proc/building_collapse_wake()
	if (building_collapse_running)
		return
	building_collapse_running = TRUE
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(building_collapse_pass)), BUILDING_COLLAPSE_PASS_DELAY)

// One pass over the due heads of the queues. Saves wait: a roof never falls
// while the world is being written.
/proc/building_collapse_pass()
	if (!persistence_save_in_progress)
		var/budget = BUILDING_COLLAPSE_PER_PASS
		budget -= building_collapse_run(building_collapse_final, budget, "final")
		budget -= building_collapse_run(building_collapse_fast, budget, "fast")
		building_collapse_run(building_collapse_slow, budget, "slow")
	if (!building_collapse_pending())
		building_collapse_running = FALSE
		return
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(building_collapse_pass)), BUILDING_COLLAPSE_PASS_DELAY)

// Handle up to budget due roofs from the head of queue. Returns how many.
/proc/building_collapse_run(list/queue, budget, stage)
	var/done = 0
	while (done < budget && queue.len)
		var/obj/roof/R = queue[1]
		if (!QDELETED(R) && queue[R] > world.time)
			break
		queue.Cut(1, 2)
		done++
		if (!QDELETED(R))
			R.building_collapse_step(stage)
	return done

/obj/roof/proc/building_collapse_step(stage)
	if (is_supported())
		return
	switch (stage)
		if ("slow")
			sag()
		if ("fast")
			visible_message(SPAN_DANGER("\The [src] creaks and groans as dust pours down. It is coming down!"))
			playsound(src, 'sound/effects/rocksfalling.ogg', 40, 0, 4)
			building_collapse_final[src] = world.time + BUILDING_COLLAPSE_FINAL_DELAY
		if ("final")
			building_collapse_fall()

// ---- what falls ---------------------------------------------------------

// How heavy falling debris of a material is: wood is 1.
/proc/building_debris_weight(material)
	switch (lowertext("[material]"))
		if ("cloth", "canvas", "hide", "leather", "paper")
			return 0.2
		if ("thatch", "straw", "palm", "leaves")
			return 0.5
		if ("glass")
			return 0.8
		if ("clay", "adobe", "mud", "dirt", "cob")
			return 1.5
		if ("stone", "brick", "sandstone", "marble", "granite", "basalt", "tiles", "rock")
			return 2
		if ("concrete", "cement", "steel", "iron", "metal")
			return 2.5
	return 1

// What a roof leaves to salvage when it comes down: list(type, amount) or null.
/obj/roof/proc/building_salvage()
	switch (structure_impact_material())
		if ("wood")
			return list(/obj/item/stack/material/wood, 1)
		if ("stone")
			return list(/obj/item/stack/material/stone, 1)
	return null

/obj/roof/proc/building_collapse_fall()
	var/turf/T = get_turf(src)
	var/weight = building_debris_weight(structure_impact_material())
	var/list/salvage = building_salvage()
	playsound(src, 'sound/effects/rocksfalling.ogg', 100, 0, 6)
	visible_message(SPAN_DANGER("\The [src] collapses!"))
	for (var/mob/living/human/M in range(1, src))
		M.adjustBruteLoss(round(rand(17, 27) * weight))
		M.Weaken(15)
		to_chat(M, SPAN_DANGER("The roof collapses!"))
	qdel(src)
	if (T)
		building_collapse_dust(T)
		building_debris_land(T, weight, salvage)

// Debris of the given weight lands on T: it hits the floor there (an upper
// floor can give way under it) and leaves rubble when it is heavy enough.
/proc/building_debris_land(turf/T, weight, list/salvage)
	if (!T)
		return
	if (building_open_turf(T))
		for (var/obj/covers/C in T)
			if (QDELETED(C) || C.wall || !C.building_roof())
				continue
			C.structure_impact(BUILDING_DEBRIS_FORCE * weight, IMPACT_CRUSH)
			break
	if (weight < 1 || T.density || (locate(/obj/structure/rubble) in T))
		return
	new /obj/structure/rubble(T, salvage ? salvage[1] : null, salvage ? salvage[2] : 0)

// A wall, pillar or door whose floor is gone falls to the level below and
// breaks there. Returns TRUE when it fell.
/atom/movable/proc/building_fall(material, list/salvage)
	var/turf/T = get_turf(src)
	if (!T)
		return FALSE
	var/below_z = multiz_level_below(T.z)
	var/turf/below = below_z ? locate(T.x, T.y, below_z) : null
	var/weight = building_debris_weight(material)
	visible_message(SPAN_DANGER("\The [src] topples down to the level below!"))
	if (below)
		for (var/mob/living/human/M in below)
			M.adjustBruteLoss(round(rand(20, 35) * weight))
			M.Weaken(10)
			to_chat(M, SPAN_DANGER("\The [src] comes crashing down on you!"))
		playsound(below, 'sound/effects/rocksfalling.ogg', 80, 0, 6)
		building_collapse_dust(below)
	qdel(src)
	if (below)
		building_debris_land(below, weight, salvage)
	return TRUE

/obj/covers/proc/building_wall_salvage()
	if (!buildstack)
		return null
	return list(buildstack, max(1, round(buildstackamount / 2)))

// ---- rubble ------------------------------------------------------------------

#define RUBBLE_CLEAR_HAND 60
#define RUBBLE_CLEAR_SHOVEL 20

/obj/structure/rubble
	name = "rubble"
	desc = "Broken pieces of a building. Clear it by hand or with a shovel to salvage what is left."
	icon = 'icons/obj/structures.dmi'
	icon_state = "debris1"
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	layer = 2.9
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	var/salvage_type = null
	var/salvage_amount = 0
	var/tmp/clearing = FALSE

/obj/structure/rubble/New(newloc, type_to_salvage, amount)
	..()
	if (type_to_salvage)
		salvage_type = type_to_salvage
		salvage_amount = amount
	if (!restoring && icon_state == initial(icon_state)) // a load keeps the saved look
		icon = 'icons/obj/rubble.dmi'
		icon_state = "rubble_[rubble_material()][rand(1, 3)]"

// What the rubble looks like it was: wood, brick or stone.
/obj/structure/rubble/proc/rubble_material()
	if (ispath(salvage_type, /obj/item/stack/material/wood) || ispath(salvage_type, /obj/item/stack/material/straw) || ispath(salvage_type, /obj/item/stack/material/bamboo))
		return "wood"
	var/text = "[salvage_type]"
	if (findtext(text, "brick") || findtext(text, "clay"))
		return "brick"
	return "stone"

// A cloud of dust where part of a building came down.
/obj/effect/collapse_dust
	name = "dust"
	icon = 'icons/effects/collapse_dust.dmi'
	icon_state = "dust"
	anchored = TRUE
	mouse_opacity = FALSE
	layer = 4.5

/obj/effect/collapse_dust/New()
	..()
	QDEL_IN(src, 10)

/proc/building_collapse_dust(turf/T)
	if (T && !(locate(/obj/effect/collapse_dust) in T))
		new /obj/effect/collapse_dust(T)

/obj/structure/rubble/attack_hand(mob/living/user)
	clear(user, null)

/obj/structure/rubble/attackby(obj/item/W, mob/user)
	if (is_tool(W, TOOL_SHOVEL))
		clear(user, W)
		return
	return ..()

/obj/structure/rubble/proc/clear(mob/living/user, obj/item/tool)
	if (!ishuman(user) || clearing || !Adjacent(user))
		return
	clearing = TRUE
	user.visible_message(SPAN_NOTICE("[user] starts clearing \the [src]."), SPAN_NOTICE("You start clearing \the [src]."))
	var/ok = do_after(user, tool ? RUBBLE_CLEAR_SHOVEL : RUBBLE_CLEAR_HAND, src)
	clearing = FALSE
	if (!ok || QDELETED(src))
		return
	user.visible_message(SPAN_NOTICE("[user] clears \the [src]."), SPAN_NOTICE("You clear \the [src][salvage_amount > 0 ? " and save what you can" : ""]."))
	rubble_salvage()
	qdel(src)

// Drop what can be saved from the rubble on its tile.
/obj/structure/rubble/proc/rubble_salvage()
	if (!salvage_type || salvage_amount <= 0 || !ispath(salvage_type, /obj/item))
		return
	var/turf/T = get_turf(src)
	if (ispath(salvage_type, /obj/item/stack))
		new salvage_type(T, salvage_amount)
		return
	for (var/i in 1 to min(salvage_amount, 4))
		new salvage_type(T)

#undef RUBBLE_CLEAR_HAND
#undef RUBBLE_CLEAR_SHOVEL
#undef BUILDING_COLLAPSE_FAST_DELAY
#undef BUILDING_COLLAPSE_FINAL_DELAY
#undef BUILDING_COLLAPSE_SLOW_DELAY
#undef BUILDING_COLLAPSE_PASS_DELAY
#undef BUILDING_COLLAPSE_PER_PASS
#undef BUILDING_DEBRIS_FORCE
