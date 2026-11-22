// ============================================================
// Ship's gun turrets and their barbettes (docs/craft-core.md "Gun turrets")
// ------------------------------------------------------------
// A ship's gun turret is a breech-loading gun in an armoured house that
// stands on her deck. Its shells come up the barbette, the armoured trunk
// under it, from a shell rack in her magazine below: a loader beside the
// turret hoists one straight into the breech, without carrying it up a
// ladder.
//
// The barbette is found by position only, the way ladders and stairs are:
// the rack must stand on the tile right under the turret, one or two decks
// down, and on a ship every tile on the way down must be one of her own
// decks. Nothing links the turret to its rack, so nothing is saved and a
// hop or a turn carries both without a fix-up.
// ============================================================

#define SHIP_TURRET_HOIST_TIME 50 // ds to hoist one shell up the barbette
#define SHIP_TURRET_DEPTH 2       // decks a barbette reaches down

/obj/structure/cannon/modern/ship_turret
	name = "ship's gun turret"
	desc = "A breech-loading gun in a turning armoured house, made to stand on a ship's deck. Its shells come up the barbette from a shell rack right under it, one or two decks down."
	icon = 'icons/obj/cannon.dmi'
	icon_state = "modern_ship"
	pixel_x = -16
	bound_height = 32
	bound_width = 32
	density = TRUE
	anchored = TRUE
	not_movable = FALSE
	ammotype = /obj/item/cannon_ball/shell
	caliber = 105
	minrange = 10
	maxrange = 120
	distance = 20
	firedelay = 1

/obj/structure/cannon/modern/ship_turret/examine(mob/user)
	..()
	to_chat(user, SPAN_NOTICE(barbette_text()))

/obj/structure/cannon/modern/ship_turret/AltClick(mob/user)
	if (!user || get_dist(user, src) > 1)
		return ..()
	hoist_shell(user)

/obj/structure/cannon/modern/ship_turret/verb/hoist_shell_verb()
	set category = null
	set name = "Hoist a Shell"
	set src in range(1)
	if (isliving(usr))
		hoist_shell(usr)

// The shell rack its barbette reaches, or null.
/obj/structure/cannon/modern/ship_turret/proc/magazine()
	var/turf/T = get_turf(src)
	if (!T)
		return null
	var/datum/craft/C = craft_holding(T)
	for (var/i = 1, i <= SHIP_TURRET_DEPTH, i++)
		var/below = multiz_level_below(T.z)
		var/turf/B = below ? locate(T.x, T.y, below) : null
		if (!B || (C && !C.body.carries(B)))
			return null
		for (var/obj/structure/shellrack/R in B)
			if (!istype(R, /obj/structure/shellrack/bombs))
				return R
		T = B
	return null

// The first shell in that rack this gun takes, or null.
/obj/structure/cannon/modern/ship_turret/proc/magazine_shell(obj/structure/shellrack/R)
	if (!R || !R.storage)
		return null
	for (var/obj/item/cannon_ball/S in R.storage.contents)
		if (istype(S, ammotype))
			return S
	return null

/obj/structure/cannon/modern/ship_turret/proc/barbette_text()
	var/obj/structure/shellrack/R = magazine()
	if (!R)
		return "Its barbette reaches no shell rack. Set one on the tile right under it, one or two decks down."
	var/shells = 0
	for (var/obj/item/cannon_ball/S in R.storage.contents)
		if (istype(S, ammotype))
			shells++
	return "Its barbette reaches a shell rack below with [shells] shell\s for it. Alt-click the turret to hoist one into the breech."

// Brings one shell up the barbette into the breech. TRUE when it did.
/obj/structure/cannon/modern/ship_turret/proc/hoist_shell(mob/living/M)
	if (!M || M.stat || M.restrained())
		return FALSE
	if (broken)
		to_chat(M, SPAN_WARNING("\The [src] is broken. Repair it first."))
		return FALSE
	if (loaded.len >= max_loaded)
		to_chat(M, SPAN_WARNING("There is already a shell in the breech."))
		return FALSE
	if (is_loading)
		return FALSE
	var/obj/structure/shellrack/R = magazine()
	if (!magazine_shell(R))
		to_chat(M, SPAN_WARNING(R ? "The rack below holds no shells for this gun." : "The barbette reaches no shell rack below."))
		return FALSE
	is_loading = TRUE
	to_chat(M, SPAN_NOTICE("You work the hoist, bringing a shell up the barbette..."))
	. = do_after(M, SHIP_TURRET_HOIST_TIME, src)
	is_loading = FALSE
	if (!.)
		return FALSE
	// Everything may have moved or emptied while the hoist ran.
	if (get_dist(M, src) > 1 || !take_from_magazine())
		to_chat(M, SPAN_WARNING("The hoist comes up empty."))
		return FALSE
	to_chat(M, SPAN_NOTICE("A shell rides up the barbette into the breech of \the [src]."))
	if (M == user)
		do_html(M)
	return TRUE

// Moves one shell from the rack below into the breech. TRUE when it did.
/obj/structure/cannon/modern/ship_turret/proc/take_from_magazine()
	if (broken || loaded.len >= max_loaded)
		return FALSE
	var/obj/structure/shellrack/R = magazine()
	var/obj/item/cannon_ball/S = magazine_shell(R)
	if (!S)
		return FALSE
	R.storage.remove_from_storage(S, src)
	S.loc = src
	loaded += S
	R.update_icon()
	return TRUE

// The craft with T on any of her decks, or null.
/proc/craft_holding(turf/T)
	if (!T)
		return null
	. = craft_at(T)
	if (.)
		return
	for (var/datum/craft/C in crafts)
		if (C.body && C.body.carries(T))
			return C
	return null

#undef SHIP_TURRET_HOIST_TIME
#undef SHIP_TURRET_DEPTH
