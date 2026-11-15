// Rock art: paint straight onto natural rock with ground pigments. See
// docs/rock-art.md. Built on the painting editor (code/modules/paintings/):
// a rock canvas held by a rock art structure on the painter's tile, drawn onto
// the face of the rock wall it faces. The canvas's base colour is left bare,
// so only the pigment shows on the stone.

#define ROCK_ART_BASE "#887766"

var/global/list/rock_art_icon_cache = list()

/proc/rock_art_surface(atom/A)
	return istype(A, /turf/wall/rockwall)

/obj/item/canvas/rock
	name = "rock painting"
	desc = "Pigment painted straight onto the rock."
	format = "rock"
	format_weight = 0.5
	needs_easel = FALSE
	canvas_w = 32
	canvas_h = 32
	art_w = 32
	art_h = 32
	art_left = 0
	art_top = 0
	frame_state = null
	base_colour = ROCK_ART_BASE
	flammable = FALSE
	w_class = ITEM_SIZE_HUGE

// Only the paint, with the bare rock left clear.
/obj/item/canvas/rock/proc/rock_icon()
	if (!small)
		return null
	var/icon/cached = rock_art_icon_cache[small]
	if (cached)
		return cached
	var/icon/I = painting_build_icon(small, art_w, art_h, art_left, art_top, 'icons/obj/paintings.dmi', "canvas_wall")
	if (!I)
		return null
	I = icon(I)
	I.SwapColor(ROCK_ART_BASE, "#00000000")
	rock_art_icon_cache[small] = I
	return I

/obj/item/canvas/rock/update_icon()
	overlays.Cut()
	if (istype(loc, /obj/structure/rock_art))
		var/obj/structure/rock_art/R = loc
		R.update_icon()

/obj/item/canvas/rock/afterattack(atom/target, mob/user, proximity_flag, params)
	return

/obj/structure/rock_art
	name = "rock art"
	desc = "Pigment painted onto the rock."
	icon = 'icons/obj/paintings.dmi'
	icon_state = ""
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	layer = 3.4
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE

/obj/structure/rock_art/persistence_runtime_var(key)
	return key == "overlays" || ..()

/obj/structure/rock_art/proc/held_canvas()
	return locate(/obj/item/canvas/rock) in contents

/obj/structure/rock_art/proc/place()
	pixel_x = 0
	pixel_y = 0
	switch (dir)
		if (NORTH)
			pixel_y = 32
		if (SOUTH)
			pixel_y = -32
		if (EAST)
			pixel_x = 32
		if (WEST)
			pixel_x = -32
	update_icon()

/obj/structure/rock_art/after_load()
	..()
	var/obj/item/canvas/rock/C = held_canvas()
	if (C && C.paint_data && !C.small)
		C.refresh_small()
	place()

/obj/structure/rock_art/update_icon()
	overlays.Cut()
	var/obj/item/canvas/rock/C = held_canvas()
	if (!C)
		return
	name = C.finished && C.title ? "\"[C.title]\"" : "rock art"
	var/icon/I = C.rock_icon()
	if (I)
		var/image/over = image(I)
		over.alpha = 215
		overlays += over

/obj/structure/rock_art/examine(mob/user)
	..()
	var/obj/item/canvas/rock/C = held_canvas()
	if (!C)
		return
	if (C.finished)
		to_chat(user, "\"[C.title ? html_encode(C.title) : "Untitled"]\"[C.author_name ? ", painted by [html_encode(C.author_name)]" : ""].")
		painting_show_full(user, C)
	else
		to_chat(user, "Someone has started painting here. Use a pigment on the rock to carry on.")

/obj/structure/rock_art/attack_hand(mob/user)
	var/obj/item/canvas/rock/C = held_canvas()
	if (!C)
		return
	if (C.finished)
		painting_show_full(user, C)
	else
		painting_open_editor(user, C)

// Scrubbing the rock clean with a chisel or hammer.
/obj/structure/rock_art/attackby(obj/item/I, mob/user)
	if (is_tool(I, TOOL_CHISEL) || is_tool(I, TOOL_HAMMER))
		user.visible_message(SPAN_NOTICE("[user] starts scraping \the [src] off the rock."), SPAN_NOTICE("You start scraping \the [src] off the rock."))
		if (do_after(user, 80, src) && !QDELETED(src))
			var/obj/item/canvas/rock/C = held_canvas()
			if (C)
				log_game("[key_name(user)] scraped off rock art \"[C.title]\" by [C.author_name] at ([x],[y],[z]).")
				qdel(C)
			qdel(src)
		return TRUE
	return ..()

/obj/structure/rock_art/Destroy()
	for (var/obj/item/canvas/rock/C in contents)
		qdel(C)
	return ..()

/proc/rock_art_on(turf/T, dir)
	for (var/obj/structure/rock_art/R in T)
		if (R.dir == dir)
			return R
	return null

// Using a pigment on natural rock you stand straight in front of starts (or
// carries on with) a painting on that face of the rock.
/obj/item/pigment/afterattack(atom/target, mob/user, proximity_flag, params)
	if (!proximity_flag || !ishuman(user) || !rock_art_surface(target))
		return ..()
	var/turf/T = get_turf(user)
	var/turf/W = get_turf(target)
	if (!T || !W || T == W || T.density)
		return ..()
	var/dir = get_dir(T, W)
	if (!(dir in cardinal))
		to_chat(user, SPAN_WARNING("Stand straight in front of the rock to paint it."))
		return TRUE
	var/obj/structure/rock_art/R = rock_art_on(T, dir)
	if (R)
		var/obj/item/canvas/rock/C = R.held_canvas()
		if (C && C.finished)
			to_chat(user, SPAN_WARNING("This rock is already painted. Scrape it clean with a chisel first."))
			return TRUE
		if (C)
			painting_open_editor(user, C)
			return TRUE
	R = new(T)
	R.dir = dir
	var/obj/item/canvas/rock/C = new(R)
	R.place()
	painting_open_editor(user, C)
	return TRUE
