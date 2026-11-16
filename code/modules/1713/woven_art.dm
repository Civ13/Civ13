// Woven rugs and tapestries: a blank of cloth warp is woven at a loom in the
// painting editor, pixel for pixel at the size it shows, with the dyes the
// weaver knows (tailoring_dye_tiers in dressmaking.dm) instead of pigments.
// A finished rug is laid on the floor and counts as art and floor cover for
// a home; a finished tapestry hangs on a wall like a painting. Art by Fable
// (icons/obj/woven_<format>.dmi: blank, edge, item; woven_items.dmi holds
// the carried rolls cropped to 32x32 by tests/sprites/create_woven_items.py).

#define WOVEN_UNDYED "#e8dcbe"

/obj/item/canvas/woven
	name = "small rug warp"
	desc = "Cloth warp strung for a small rug. Hold it beside a loom and use it to weave the design with the dyes you know."
	icon = 'icons/obj/woven_items.dmi'
	icon_state = "rug_small"
	w_class = ITEM_SIZE_NORMAL
	format = "rug_small"
	format_weight = 0.25
	needs_easel = FALSE
	uses_pigments = FALSE
	base_colour = WOVEN_UNDYED
	canvas_w = 28
	canvas_h = 22
	art_w = 28
	art_h = 22
	art_left = 2
	art_top = 5
	value = 3
	var/woven_icon = 'icons/obj/woven_rug_small.dmi'
	var/rug = TRUE
	var/footprint_w = 1 // tiles covered when laid, from its tile east and north
	var/footprint_h = 1

/obj/item/canvas/woven/runner
	name = "runner warp"
	desc = "Cloth warp strung for a long runner rug, two tiles wide. Hold it beside a loom and use it to weave the design with the dyes you know."
	icon_state = "rug_runner"
	format = "rug_runner"
	format_weight = 0.5
	canvas_w = 52
	canvas_h = 24
	art_w = 52
	art_h = 24
	art_left = 6
	art_top = 4
	woven_icon = 'icons/obj/woven_rug_runner.dmi'
	footprint_w = 2

/obj/item/canvas/woven/large
	name = "large rug warp"
	desc = "Cloth warp strung for a large rug, two tiles by two. Hold it beside a loom and use it to weave the design with the dyes you know."
	icon_state = "rug_large"
	w_class = ITEM_SIZE_LARGE
	format = "rug_large"
	format_weight = 1
	canvas_w = 58
	canvas_h = 50
	art_w = 58
	art_h = 50
	art_left = 3
	art_top = 7
	woven_icon = 'icons/obj/woven_rug_large.dmi'
	footprint_w = 2
	footprint_h = 2
	value = 5

/obj/item/canvas/woven/tapestry
	name = "tapestry warp"
	desc = "Cloth warp strung for a wall tapestry. Hold it beside a loom and use it to weave the design with the dyes you know, then hang it on a wall."
	icon_state = "tapestry"
	format = "tapestry"
	canvas_w = 22
	canvas_h = 19
	art_w = 22
	art_h = 19
	art_left = 5
	art_top = 7
	woven_icon = 'icons/obj/woven_tapestry.dmi'
	rug = FALSE

/obj/item/canvas/woven/tapestry/wide
	name = "wide tapestry warp"
	desc = "Cloth warp strung for a wide wall tapestry, two tiles across. Hold it beside a loom and use it to weave the design with the dyes you know, then hang it on a wall to your north."
	icon_state = "tapestry_wide"
	format = "tapestry_wide"
	format_weight = 0.5
	canvas_w = 52
	canvas_h = 19
	art_w = 52
	art_h = 19
	art_left = 6
	art_top = 7
	woven_icon = 'icons/obj/woven_tapestry_wide.dmi'
	wide_hang = TRUE

// Carried, it is a roll or a folded cloth; the design shows once laid or hung.
/obj/item/canvas/woven/update_icon()
	overlays.Cut()

/obj/item/canvas/woven/framed_overlays()
	var/list/out = list()
	var/icon/I = small ? painting_build_icon(small, art_w, art_h, art_left, art_top, woven_icon, "blank") : null
	if (I)
		out += image(I)
	out += image(woven_icon, "edge")
	return out

// The dyes this weaver knows; with textile mills, every named dye.
/obj/item/canvas/woven/extra_colours(mob/user)
	var/list/out = list()
	var/list/dyes = ishuman(user) ? tailoring_known_dyes(user) : list()
	if (isnull(dyes))
		for (var/node in tailoring_dye_tiers)
			for (var/name in tailoring_dye_tiers[node])
				out |= painting_hex(tailoring_dye_tiers[node][name])
		return out
	for (var/name in dyes)
		out |= painting_hex(dyes[name])
	return out

/obj/item/canvas/woven/painting_name_text()
	return title ? "\"[title]\"" : "an untitled [rug ? "rug" : "tapestry"]"

/obj/item/canvas/woven/attack_self(mob/user)
	if (finished)
		painting_show_full(user, src)
		return
	if (!(locate(/obj/structure/loom) in range(1, user)))
		to_chat(user, SPAN_NOTICE("Stand beside a loom to weave \the [src]."))
		return
	painting_open_editor(user, src)

/obj/item/canvas/woven/afterattack(atom/target, mob/user, proximity_flag, params)
	if (!proximity_flag || !finished)
		return
	if (rug)
		if (!painting_is_wall(target))
			woven_lay_rug(user, src, get_turf(target))
		return
	if (painting_is_wall(target))
		painting_hang(user, src, target)

/proc/woven_lay_rug(mob/user, obj/item/canvas/woven/C, turf/T)
	if (!T || T.density || painting_is_wall_turf(T) || get_dist(user, T) > 1)
		return FALSE
	if (locate(/obj/structure/woven_rug) in T)
		to_chat(user, SPAN_WARNING("A rug already lies there."))
		return FALSE
	var/obj/structure/woven_rug/R = new(T)
	user.drop_from_inventory(C, R)
	C.forceMove(R)
	R.update_icon()
	user.visible_message(SPAN_NOTICE("[user] lays [C.painting_name_text()] on the floor."), SPAN_NOTICE("You lay [C.painting_name_text()] on the floor."))
	return TRUE

/////////////////////////////// A laid rug ///////////////////////////////

/obj/structure/woven_rug
	name = "rug"
	desc = "A woven rug laid on the floor."
	icon = 'icons/obj/woven_rug_small.dmi'
	icon_state = "blank"
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	layer = 2.05 // over the floor, under furniture and what lies on it
	flammable = TRUE
	not_movable = TRUE

/obj/structure/woven_rug/persistence_runtime_var(key)
	return key == "overlays" || ..()

/obj/structure/woven_rug/proc/held_canvas()
	return locate(/obj/item/canvas/woven) in contents

/obj/structure/woven_rug/after_load()
	..()
	update_icon()

/obj/structure/woven_rug/update_icon()
	overlays.Cut()
	var/obj/item/canvas/woven/C = held_canvas()
	if (!C)
		return
	icon = C.woven_icon
	name = C.title ? "\"[C.title]\"" : "rug"
	overlays += C.framed_overlays()

/obj/structure/woven_rug/examine(mob/user)
	..()
	var/obj/item/canvas/C = held_canvas()
	if (C)
		to_chat(user, "\"[C.title ? html_encode(C.title) : "Untitled"]\"[C.author_name ? ", woven by [html_encode(C.author_name)]" : ""].")
		painting_show_full(user, C)

/obj/structure/woven_rug/verb/roll_up_rug()
	set name = "Roll Up Rug"
	set category = null
	set src in view(1)
	var/mob/living/human/H = usr
	if (!istype(H) || H.incapacitated() || !Adjacent(H))
		return
	var/obj/item/canvas/C = held_canvas()
	if (!do_after(H, 20, src))
		return
	if (QDELETED(src) || !C || C.loc != src)
		return
	H.visible_message(SPAN_NOTICE("[H] rolls up \the [src]."), SPAN_NOTICE("You roll up \the [src]."))
	H.put_in_hands(C)
	qdel(src)

/obj/structure/woven_rug/ex_act(severity)
	qdel(src)

/obj/structure/woven_rug/Destroy()
	for (var/obj/item/canvas/C in contents)
		C.forceMove(get_turf(src))
	return ..()

// Whether a laid rug covers T (a wide rug reaches east, a large one north too).
/proc/woven_rug_covers(turf/T)
	if (!T)
		return FALSE
	for (var/dx = 0, dx <= 1, dx++)
		for (var/dy = 0, dy <= 1, dy++)
			var/turf/from = locate(T.x - dx, T.y - dy, T.z)
			if (!from)
				continue
			for (var/obj/structure/woven_rug/R in from)
				var/obj/item/canvas/woven/C = R.held_canvas()
				if (C && dx < C.footprint_w && dy < C.footprint_h)
					return TRUE
	return FALSE

#undef WOVEN_UNDYED
