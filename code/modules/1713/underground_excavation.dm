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
	delay /= max(0.1, H.getStatCoeff("strength"))
	delay /= max(0.1, S.usespeed)
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
	T.collapse_check()
	T.change_the_turf()
	var/turf/opened = locate(T.x, T.y, T.z)
	excavation_spoil(opened, debris ? EXCAVATION_DEBRIS_PILES : EXCAVATION_ROCK_PILES)
	if (sandy)
		new /obj/item/stack/ore/glass(opened)
	return opened

/turf/floor/dirt/underground/attackby(obj/item/C, mob/user)
	if (istype(C, /obj/item/weapon/material/shovel) && ishuman(user) && density)
		underground_excavate(src, user, C)
		return TRUE
	return ..()

#undef EXCAVATION_TIME
#undef EXCAVATION_DEBRIS_TIME
#undef EXCAVATION_ROCK_PILES
#undef EXCAVATION_DEBRIS_PILES
#undef EXCAVATION_SHAFT_PILES
