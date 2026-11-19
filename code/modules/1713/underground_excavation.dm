// Underground excavation (docs/underground-excavation.md): ways to get dirt by
// digging below ground. Cave rock is soft earth and stones, so a shovel can dig
// a tile out for its earth instead of breaking it with a pickaxe for stone and
// ore; a shovel also clears cave-in rubble, and digging a tunnel shaft leaves
// the earth from the shaft at its mouth. Every route drops ordinary dirt piles
// (/obj/item/weapon/barrier), the same piles a shovel scoops from dirt ground
// and grading cuts from a hill.

// Deciseconds to dig out a soft rock tile, before strength and shovel speed.
// A pickaxe takes 240 to break the same tile for stone and ore.
#define EXCAVATION_TIME 300
// Deciseconds to shovel away a pile of cave-in rubble.
#define EXCAVATION_DEBRIS_TIME 120
// Dirt piles from one dug-out rock tile, one cleared rubble tile and one shaft.
#define EXCAVATION_ROCK_PILES 2
#define EXCAVATION_DEBRIS_PILES 1
#define EXCAVATION_SHAFT_PILES 2
// Deciseconds to pack one dirt pile into an open tunnel tile.
#define BACKFILL_TIME 60

// Why this tile cannot be dug out with a shovel, or null when it can.
/proc/underground_excavation_problem(turf/T)
	if (!istype(T, /turf/floor/dirt/underground) || !T.density)
		return "There is no earth left to dig out here."
	if (istype(T, /turf/floor/dirt/underground/icy))
		return "The frozen earth is too hard for a shovel. Break it with a pickaxe."
	if (!T.is_mineable)
		return "This rock is too hard for a shovel."
	if (T.mining_in_progress || T.pickaxe_mining_owner)
		return "Someone is already digging here."
	return null

// Drops the dirt piles dug out of the ground onto T.
/proc/excavation_spoil(turf/T, piles)
	if (!T || piles <= 0)
		return
	for (var/i in 1 to piles)
		new /obj/item/weapon/barrier(T)

// The earth from a freshly dug tunnel shaft, left at the digger's feet.
/proc/excavation_shaft_spoil(mob/user)
	excavation_spoil(get_turf(user), EXCAVATION_SHAFT_PILES)
	to_chat(user, SPAN_NOTICE("You heap the earth from the shaft into dirt piles."))

// Digs out a soft rock tile, or clears a rubble tile, with a shovel. The tile
// opens like a mined one (same cave-in check), but gives dirt instead of
// stone and ore.
/proc/underground_excavate(turf/floor/dirt/underground/T, mob/living/human/H, obj/item/weapon/material/shovel/S)
	if (!istype(T) || !istype(H) || !istype(S))
		return FALSE
	var/problem = underground_excavation_problem(T)
	if (problem)
		to_chat(H, SPAN_WARNING(problem))
		return FALSE
	if (H.shoveling)
		return FALSE
	var/debris = istype(T, /turf/floor/dirt/underground/empty)
	var/delay = debris ? EXCAVATION_DEBRIS_TIME : EXCAVATION_TIME
	delay = work_delay_per_speed(H, delay, WORK_DIG, S)
	T.mining_in_progress = TRUE
	H.shoveling = TRUE
	if (debris)
		H.visible_message(SPAN_NOTICE("[H] starts shovelling away the rubble."), SPAN_NOTICE("You start shovelling away the rubble."), "You hear digging.")
	else
		H.visible_message(SPAN_NOTICE("[H] starts digging out the soft earth."), SPAN_NOTICE("You start digging out the soft earth."), "You hear digging.")
	playsound(T, 'sound/effects/shovelling.ogg', 100, TRUE)
	var/completed = do_after(H, delay, T)
	H.shoveling = FALSE
	T.mining_in_progress = FALSE
	if (!completed)
		return FALSE
	problem = underground_excavation_problem(T)
	if (problem)
		to_chat(H, SPAN_WARNING(problem))
		return FALSE
	underground_excavation_finish(T)
	H.adaptStat("strength", 1)
	if (debris)
		H.visible_message(SPAN_NOTICE("[H] clears the rubble and piles up the dirt."), SPAN_NOTICE("You clear the rubble and pile up the dirt."))
	else
		H.visible_message(SPAN_NOTICE("[H] digs out the earth and piles it up."), SPAN_NOTICE("You dig out the earth and pile it up."))
	return TRUE

// Opens a dug-out tile like a mined one (same cave-in check) and drops its
// dirt: two piles from soft rock (plus a sand pile from sandy rock), one from
// rubble. Returns the opened turf.
/proc/underground_excavation_finish(turf/floor/dirt/underground/T)
	var/debris = istype(T, /turf/floor/dirt/underground/empty)
	var/sandy = istype(T, /turf/floor/dirt/underground/sandy)
	var/packed = istype(T, /turf/floor/dirt/underground/empty/packed)
	T.collapse_check()
	T.change_the_turf()
	var/turf/opened = locate(T.x, T.y, T.z)
	if (packed)
		opened.available_dirt = 0 // the pile packed into it is all the earth it holds
	excavation_spoil(opened, debris ? EXCAVATION_DEBRIS_PILES : EXCAVATION_ROCK_PILES)
	if (sandy)
		new /obj/item/stack/ore/glass(opened)
	return opened

/turf/floor/dirt/underground/attackby(obj/item/C, mob/user)
	if (is_tool(C, TOOL_SHOVEL) && ishuman(user) && density)
		underground_excavate(src, user, C)
		return TRUE
	return ..()

// Backfilling: a shovel packs a dirt pile into an open tunnel tile, turning it
// back into solid ground. Packed earth is dense, so seepage and floodwater no
// longer stand on it (flood_cellars.dm), and digging it out again gives back
// the one pile it took and nothing more.
/turf/floor/dirt/underground/empty/packed
	name = "packed earth"
	desc = "Earth packed back into a dug-out tunnel. A shovel or pickaxe can clear it again."

/turf/floor/dirt/underground/empty/packed/mining_clear_debris()
	var/tx = x
	var/ty = y
	var/tz = z
	..()
	var/turf/T = locate(tx, ty, tz)
	if (T)
		T.available_dirt = 0

// TRUE when T lies on a level under the ground: the dug cave level, or a cave.
/proc/tunnel_level_turf(turf/T)
	if (!T)
		return FALSE
	var/dug = dug_underground_z()
	if (dug && T.z == dug)
		return TRUE
	return istype(T.loc, /area/caribbean/void/caves)

// A dirt pile for backfilling: in the user's other hand first, then on T.
/proc/backfill_pile(turf/T, mob/user, obj/item/tool)
	var/obj/item/weapon/barrier/B = user.get_inactive_hand()
	if (istype(B) && B != tool && !istype(B, /obj/item/weapon/barrier/sandbag))
		return B
	for (var/obj/item/weapon/barrier/P in T)
		if (!istype(P, /obj/item/weapon/barrier/sandbag))
			return P
	return null

// Why open tunnel tile T cannot be packed with earth, or null when it can.
/proc/tunnel_backfill_problem(turf/T, mob/user)
	if (!istype(T, /turf/floor/dirt) || T.density || istype(T, /turf/floor/dirt/underground))
		return "There is nothing to fill here."
	if (get_turf(user) == T)
		return "Step off the spot you want to fill."
	var/above_z = multiz_level_above(T.z)
	var/turf/above = above_z ? locate(T.x, T.y, above_z) : null
	if (above && (locate(/obj/structure/multiz) in above))
		return "The shaft above is still open. Fill the hole from above first."
	for (var/mob/living/M in T)
		return "[M] is in the way."
	for (var/obj/O in T)
		if (istype(O, /obj/item/weapon/barrier) || istype(O, /obj/effect))
			continue
		return "Clear \the [O] out of the way first."
	return null

// Uses up the pile and packs T solid. Returns the packed turf.
/proc/tunnel_backfill_finish(turf/T, obj/item/weapon/barrier/pile)
	qdel(pile)
	T.ChangeTurf(/turf/floor/dirt/underground/empty/packed)
	return locate(T.x, T.y, T.z)

/proc/tunnel_backfill(turf/floor/dirt/T, mob/living/human/H, obj/item/tool)
	if (H.shoveling || persistence_save_in_progress)
		return TRUE
	var/problem = tunnel_backfill_problem(T, H)
	if (problem)
		to_chat(H, SPAN_WARNING(problem))
		return TRUE
	var/delay = work_delay_per_speed(H, BACKFILL_TIME, WORK_DIG, tool)
	H.shoveling = TRUE
	H.visible_message(SPAN_NOTICE("[H] starts packing earth into the tunnel."), SPAN_NOTICE("You start packing earth into the tunnel."), "You hear digging.")
	playsound(T, 'sound/effects/shovelling.ogg', 100, TRUE)
	var/completed = do_after(H, delay, T)
	H.shoveling = FALSE
	if (!completed || persistence_save_in_progress || H.get_active_hand() != tool)
		return TRUE
	problem = tunnel_backfill_problem(T, H)
	if (problem)
		to_chat(H, SPAN_WARNING(problem))
		return TRUE
	var/obj/item/weapon/barrier/pile = backfill_pile(T, H, tool)
	if (!pile)
		return TRUE
	tunnel_backfill_finish(T, pile)
	H.adaptStat("strength", 1)
	H.visible_message(SPAN_NOTICE("[H] packs the tunnel full of earth."), SPAN_NOTICE("You pack the tunnel full of earth. Water can no longer stand here."))
	log_game("[key_name(H)] packed a tunnel tile with earth at [T.x],[T.y],[T.z]")
	return TRUE

// Help or grab intent with a shovel and a dirt pile (in the other hand or on
// the tile) packs an open tunnel tile; without a pile the shovel scoops as before.
/turf/floor/dirt/attackby(obj/item/C, mob/user)
	if (!density && is_tool(C, TOOL_SHOVEL) && ishuman(user) && (user.a_intent == I_HELP || user.a_intent == I_GRAB) && !istype(src, /turf/floor/dirt/underground) && tunnel_level_turf(src) && backfill_pile(src, user, C))
		return tunnel_backfill(src, user, C)
	return ..()

#undef BACKFILL_TIME
#undef EXCAVATION_TIME
#undef EXCAVATION_DEBRIS_TIME
#undef EXCAVATION_ROCK_PILES
#undef EXCAVATION_DEBRIS_PILES
#undef EXCAVATION_SHAFT_PILES
