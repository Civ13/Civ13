// Castle defences (docs/siege-engines.md#castle-defences).
//
// - Arrow slits and gun loops: cut through a built wall from the inside. The
//   person standing right behind the slit shoots out through its outside face;
//   shots from outside nearly always hit the stone. The wall stays solid for
//   movement but can be seen through.
// - Battlements: a crenelated wall built by a player covers the side its
//   builder faced away from. The inside shoots out over it freely, the outside
//   is mostly stopped and someone crouching behind it is fully covered.
//
// Both use directional_cover_verdict(), which the projectile asks for every
// object in a tile it enters (projectile.dm).

#define SLIT_OUT_PASS 95		// % of shots from the slit's own inside tile that pass out
#define SLIT_IN_BLOCK 95		// % of shots from outside that hit the slit's stone
#define BATTLEMENT_IN_BLOCK 85	// % of shots from outside stopped by a battlement
#define SLIT_CUT_TIME 150		// ds to cut a slit, before skill
#define SLIT_FILL_TIME 50		// ds to fill one in again
#define SLIT_HEALTH_CUT 0.2		// share of the wall's health lost to the opening

/obj/covers
	var/slit = SLIT_NONE
	var/slit_dir = 0		// the outside face: the way a shot leaves through it
	var/slit_lost_health = 0	// maxhealth the opening took, given back when filled

/obj/structure/barricade
	var/outward_dir = 0		// a player-built battlement: the side it covers against

// ---- the shared cover rule ---------------------------------------------------

// What a one-sided defence at A does to the shot P entering its tile.
/proc/directional_cover_verdict(atom/A, obj/item/projectile/P)
	var/out = 0
	var/out_pass = 100
	var/in_block = 0
	var/is_battlement = FALSE
	if (istype(A, /obj/covers))
		var/obj/covers/C = A
		if (!C.slit || !C.slit_dir || !C.density)
			return DIRECTIONAL_COVER_DEFAULT
		out = C.slit_dir
		out_pass = SLIT_OUT_PASS
		in_block = SLIT_IN_BLOCK
	else if (istype(A, /obj/structure/barricade))
		var/obj/structure/barricade/B = A
		if (!B.outward_dir || !B.density)
			return DIRECTIONAL_COVER_DEFAULT
		out = B.outward_dir
		in_block = BATTLEMENT_IN_BLOCK
		is_battlement = TRUE
	else
		return DIRECTIONAL_COVER_DEFAULT
	var/back = turn(out, 180)
	var/travel = P.get_direction()
	var/turf/inside = get_step(A, back)
	// Leaving through the outside face: only from the tile right behind it.
	if ((travel & out) && !(travel & back))
		if (inside && P.starting == inside)
			return prob(out_pass) ? DIRECTIONAL_COVER_PASS : DIRECTIONAL_COVER_BLOCK
		return DIRECTIONAL_COVER_DEFAULT
	// Coming in from outside.
	if (travel & back)
		if (is_battlement && inside)
			for (var/mob/living/L in inside)
				if (L.lying || L.prone)
					return DIRECTIONAL_COVER_BLOCK
		return prob(in_block) ? DIRECTIONAL_COVER_BLOCK : DIRECTIONAL_COVER_PASS
	return DIRECTIONAL_COVER_DEFAULT

// ---- arrow slits and gun loops -----------------------------------------------

/obj/covers/proc/slit_name(kind = slit)
	return kind == SLIT_GUN ? "gun loop" : "arrow slit"

// Walls solid enough to hold an opening: stone, clay and timber, not straw or
// paper screens, and not unfinished walls or archways.
/obj/covers/proc/can_take_slit()
	if (!wall || !density || incomplete || afloat)
		return FALSE
	if (istype(src, /obj/covers/straw_wall) || istype(src, /obj/covers/wood_wall/shoji) || istype(src, /obj/covers/wood_wall/shoji_divider) || istype(src, /obj/covers/divider_wall))
		return FALSE
	return material == "Stone" || material == "Clay" || material == "Wood"

// The tool that cuts this wall: a chisel through stone and clay, a chisel or
// hatchet through timber.
/obj/covers/proc/slit_tool(obj/item/W)
	if (is_tool(W, TOOL_CHISEL))
		return TRUE
	return material == "Wood" && is_tool(W, TOOL_HATCHET)

// Why user can't cut an opening here now, or null.
/obj/covers/proc/slit_cut_refusal(mob/living/human/user)
	if (!can_take_slit())
		return "\The [src] is not a wall you can cut a loophole through."
	if (slit)
		return "\The [src] already has \a [slit_name()]."
	var/turf/U = get_turf(user)
	if (!U || U.z != z || !(get_dir(src, U) in cardinal) || get_dist(src, U) != 1)
		return "Stand right against the inside of the wall, square on, to cut a loophole."
	return null

// The openings user knows how to cut.
/proc/slit_kinds_known(mob/living/human/user)
	. = list()
	if (research_node_known(user, "fortifications"))
		. += "Cut an arrow slit"
	if (research_node_known(user, "gunpowder"))
		. += "Cut a gun loop"

/obj/covers/proc/cut_slit(kind, outside)
	slit = kind
	slit_dir = outside
	slit_lost_health = round(maxhealth * SLIT_HEALTH_CUT)
	maxhealth -= slit_lost_health
	health = min(health, maxhealth)
	set_opacity(FALSE)
	var/turf/T = get_turf(src)
	if (T)
		T.recalc_atom_opacity()
	update_icon()

/obj/covers/proc/fill_slit()
	slit = SLIT_NONE
	slit_dir = 0
	maxhealth += slit_lost_health
	slit_lost_health = 0
	set_opacity(initial(opacity))
	var/turf/T = get_turf(src)
	if (T)
		T.recalc_atom_opacity()
	update_icon()

// Help intent with a chisel (or a hatchet on timber) cuts an opening from the
// side user stands on, which becomes the inside; the wall's own material
// fills it in again. Returns TRUE if it handled the click.
/obj/covers/proc/slit_attackby(obj/item/W, mob/living/human/user)
	if (!wall || !ishuman(user) || user.a_intent != I_HELP)
		return FALSE
	if (slit && istype(W, /obj/item/stack) && istype(W, buildstack))
		var/obj/item/stack/S = W
		user.visible_message(SPAN_NOTICE("[user] starts filling in \the [slit_name()] in \the [src]."), SPAN_NOTICE("You start filling in \the [slit_name()]."))
		if (!do_after(user, SLIT_FILL_TIME, src) || !slit || !S.use(1))
			return TRUE
		fill_slit()
		user.visible_message(SPAN_NOTICE("[user] fills in the opening in \the [src]."))
		return TRUE
	if (!slit_tool(W))
		return FALSE
	var/refusal = slit_cut_refusal(user)
	if (refusal)
		to_chat(user, SPAN_WARNING(refusal))
		return TRUE
	var/list/kinds = slit_kinds_known(user)
	if (!kinds.len)
		to_chat(user, SPAN_WARNING("You don't know how to cut a loophole that holds up. Arrow slits come with Fortifications."))
		return TRUE
	var/choice = player_input(user, "Cut an opening through \the [src]? The side you stand on becomes the inside; you shoot out through the far side.", "Loophole", null, "anything", kinds + "Cancel", TRUE)
	if (!choice || choice == "Cancel")
		return TRUE
	var/kind = choice == "Cut a gun loop" ? SLIT_GUN : SLIT_ARROW
	var/outside = get_dir(user, src)
	var/cut_time = SLIT_CUT_TIME / max(0.25, user.getStatCoeff("crafting"))
	user.visible_message(SPAN_NOTICE("[user] starts cutting \a [slit_name(kind)] through \the [src]."), SPAN_NOTICE("You start cutting \a [slit_name(kind)] through \the [src]."))
	if (!do_after(user, cut_time, src))
		return TRUE
	refusal = slit_cut_refusal(user)
	if (refusal || get_dir(user, src) != outside)
		to_chat(user, SPAN_WARNING(refusal || "You moved away from where you were cutting."))
		return TRUE
	cut_slit(kind, outside)
	playsound(get_turf(src), 'sound/weapons/smash.ogg', 50, TRUE)
	user.visible_message(SPAN_NOTICE("[user] cuts \a [slit_name()] through \the [src]."), SPAN_NOTICE("You finish \the [slit_name()]. Stand right behind it to shoot out."))
	return TRUE

/obj/covers/attackby(obj/item/W, mob/user)
	if (slit_attackby(W, user))
		return TRUE
	return ..()

/obj/covers/update_icon()
	..()
	if (slit && slit_dir)
		overlays += image(icon = 'icons/obj/castle_defences.dmi', icon_state = slit == SLIT_GUN ? "gun_loop" : "arrow_slit", dir = slit_dir, layer = layer + 0.03)

/obj/covers/examine(mob/user)
	..()
	if (slit && slit_dir)
		to_chat(user, SPAN_NOTICE("\A [slit_name()] is cut through it, opening to the [dir2text(slit_dir)]. Stand right behind it on the [dir2text(turn(slit_dir, 180))] side to shoot out."))

/obj/covers/after_load()
	..()
	if (slit)
		update_icon()

// ---- battlements ----------------------------------------------------------------

/proc/is_battlement_type(obj/O)
	return istype(O, /obj/structure/barricade/stone_h/crenelated) || istype(O, /obj/structure/barricade/stone_v/crenelated) || istype(O, /obj/structure/barricade/sandstone_h/crenelated) || istype(O, /obj/structure/barricade/sandstone_v/crenelated)

// A player builds a crenelated wall standing on its tile and facing out, so it
// covers the side they faced. Mapped ones keep the old two-way cover.
/proc/battlement_after_build(obj/O, mob/user)
	if (!is_battlement_type(O) || !user)
		return
	var/obj/structure/barricade/B = O
	B.outward_dir = user.dir

/obj/structure/barricade/examine(mob/user)
	..()
	if (outward_dir)
		to_chat(user, SPAN_NOTICE("It faces [dir2text(outward_dir)]: it covers whoever stands behind it on the [dir2text(turn(outward_dir, 180))] side, and they can shoot out over it."))

#undef SLIT_OUT_PASS
#undef SLIT_IN_BLOCK
#undef BATTLEMENT_IN_BLOCK
#undef SLIT_CUT_TIME
#undef SLIT_FILL_TIME
#undef SLIT_HEALTH_CUT
