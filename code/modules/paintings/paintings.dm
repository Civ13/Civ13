// Player paintings: pigments, canvases, the easel, wall frames and lockets.
// Storage and drawing live in painting_codec.dm, the editor in
// painting_editor.dm and the admin list in painting_admin.dm.

// Paintings per world: code/__defines/paintings.dm
#define PAINT_PIXELS_PER_USE 256 // painted pixels one use of a pigment covers
#define PAINT_LOCKET_LEFT 12 // the locket's 8x8 window in icons/mob/paintings.dmi, SOUTH
#define PAINT_LOCKET_TOP 14

/////////////////////////////// Pigments ///////////////////////////////

/obj/item/pigment
	name = "pigment"
	desc = "Ground colour for painting. Carry it to paint with its colours."
	icon = 'icons/obj/paintings.dmi'
	icon_state = "pigment_charcoal"
	w_class = ITEM_SIZE_TINY
	flammable = FALSE
	value = 1
	var/list/pigment_colors = list("#2a2522")
	var/pigment_uses = 10

/obj/item/pigment/examine(mob/user)
	..()
	to_chat(user, "There is enough for about [pigment_uses] more [pigment_uses == 1 ? "painting" : "paintings"].")

/obj/item/pigment/charcoal
	name = "charcoal pigment"
	desc = "Charcoal ground to a fine black powder. Gives black and dark grey."
	icon_state = "pigment_charcoal"
	pigment_colors = list("#1e1b19", "#55504a")

/obj/item/pigment/ochre_red
	name = "red ochre"
	desc = "Iron-rich earth ground to a rusty red powder. Gives deep and bright red."
	icon_state = "pigment_red_ochre"
	pigment_colors = list("#7d2f1e", "#a8492e")

/obj/item/pigment/ochre_yellow
	name = "yellow ochre"
	desc = "Clay earth ground to a warm yellow powder. Gives ochre and pale yellow."
	icon_state = "pigment_yellow_ochre"
	pigment_colors = list("#b8873a", "#dcb35e")

/obj/item/pigment/bone_white
	name = "bone white"
	desc = "Bone ground to a pale powder. Gives white and warm grey."
	icon_state = "pigment_bone_white"
	pigment_colors = list("#ece6d6", "#b9ae98")

// Mineral pigments of later ages, from mined ores and stones.
/obj/item/pigment/malachite
	name = "malachite green"
	desc = "Copper ore ground to a green powder. Gives deep and light green."
	icon_state = "pigment_malachite"
	pigment_colors = list("#2f6e45", "#5e9a62")

/obj/item/pigment/vermilion
	name = "vermilion"
	desc = "Cinnabar ground to a brilliant red powder. Gives scarlet and orange-red."
	icon_state = "pigment_vermilion"
	pigment_colors = list("#c8321e", "#e0603a")

/obj/item/pigment/lead_white
	name = "lead white"
	desc = "Lead ore ground and washed to a cool white powder. Gives bright white and pale grey."
	icon_state = "pigment_lead_white"
	pigment_colors = list("#e8e4da", "#c9c6bc")

/obj/item/pigment/ultramarine
	name = "ultramarine"
	desc = "A blue stone ground to a costly deep blue powder. Gives deep and light blue."
	icon_state = "pigment_ultramarine"
	pigment_colors = list("#2a3f8f", "#5068b8")
	value = 4

// Fine Arts: a box of ready-mixed oil paints, many colours and many uses.
/obj/item/pigment/oil_paints
	name = "box of oil paints"
	desc = "Ready-mixed oil paints in a wooden box. Gives eight colours and lasts a long time."
	icon_state = "oil_paints"
	w_class = ITEM_SIZE_SMALL
	flammable = TRUE
	value = 6
	pigment_colors = list("#141414", "#f4f1ea", "#b0202a", "#e0b020", "#1f4fa0", "#2e7d3a", "#6e4424", "#d8822a")
	pigment_uses = 40

// What grinds into a pigment in the stone mortar (herbalism.dm).
/proc/mortar_pigment_result(obj/item/I)
	if (istype(I, /obj/item/stack/ore/charcoal))
		return /obj/item/pigment/charcoal
	if (istype(I, /obj/item/stack/ore/iron))
		return /obj/item/pigment/ochre_red
	if (istype(I, /obj/item/stack/material/clay))
		return /obj/item/pigment/ochre_yellow
	if (istype(I, /obj/item/stack/material/bone))
		return /obj/item/pigment/bone_white
	if (istype(I, /obj/item/stack/ore/copper))
		return /obj/item/pigment/malachite
	if (istype(I, /obj/item/stack/ore/mercury))
		return /obj/item/pigment/vermilion
	if (istype(I, /obj/item/stack/ore/lead))
		return /obj/item/pigment/lead_white
	if (istype(I, /obj/item/stack/ore/gem/sapphire))
		return /obj/item/pigment/ultramarine
	return null

/obj/item/weapon/reagent_containers/glass/mortar/proc/grind_pigment(obj/item/W, mob/user)
	var/pigment_type = mortar_pigment_result(W)
	if (grinding || !pigment_type || !user || QDELETED(W))
		return FALSE
	if (!grind_access(user))
		return FALSE
	if (!wait_for_grinding(W, user, "You start grinding \the [W] into pigment."))
		return FALSE
	if (!grind_access(user))
		return FALSE
	if (persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required)
		to_chat(user, SPAN_WARNING("You cannot grind during persistence operations."))
		return FALSE
	if (istype(W, /obj/item/stack))
		var/obj/item/stack/S = W
		if (!S.use(1))
			return FALSE
	else
		qdel(W)
	var/obj/item/pigment/P = new pigment_type(get_turf(user))
	user.put_in_hands(P)
	to_chat(user, SPAN_NOTICE("You grind it down into \a [P]."))
	return TRUE

// Colours the user may paint with: the canvas colour, every carried
// pigment's colours, and any two of those mixed half and half.
/proc/painting_allowed_colours(mob/user, obj/item/canvas/C)
	var/list/base = list(C.base_colour) | C.extra_colours(user)
	for (var/obj/item/pigment/P in (C.uses_pigments ? user.get_contents() : list()))
		if (P.pigment_uses <= 0)
			continue
		for (var/hex in P.pigment_colors)
			base |= painting_hex(hex)
	var/list/out = base.Copy()
	for (var/i = 1, i <= base.len, i++)
		for (var/j = i + 1, j <= base.len, j++)
			out |= painting_mix(base[i], base[j])
	return out

/proc/painting_carried_pigments(mob/user)
	var/list/out = list()
	for (var/obj/item/pigment/P in user.get_contents())
		if (P.pigment_uses > 0)
			out += P
	return out

/////////////////////////////// Canvases ///////////////////////////////

/obj/item/canvas
	name = "wall canvas"
	desc = "A stretched canvas for a painting to hang on a wall. Set it on an easel to paint it."
	icon = 'icons/obj/paintings.dmi'
	icon_state = "canvas_wall"
	w_class = ITEM_SIZE_NORMAL
	flammable = TRUE
	value = 2
	var/format = "wall"
	var/format_weight = 1 // share of the region's painting cap
	var/needs_easel = TRUE
	var/canvas_w = 64 // painted size
	var/canvas_h = 64
	var/art_w = 32 // size shown in the world
	var/art_h = 32
	var/art_left = 0 // where the shown art sits in the sprite, from its top left
	var/art_top = 0
	var/frame_state = "frame_wall"
	var/base_colour = "#e9dfc8"
	var/pixel_use_scale = 1 // big canvases use pigment more thinly
	var/palette = null // "#rrggbb,..." painting_codec.dm
	var/paint_data = null // packed pixels
	var/small = null // shrunk copy, 3 hex digits per pixel
	var/finished = FALSE
	var/title = null
	var/author_ckey = null
	var/author_name = null
	var/painted_at = null // date text
	var/imported_design = FALSE // painted from a pasted design code (design_codes.dm)
	var/uses_pigments = TRUE // FALSE: colours come only from extra_colours() (woven dyes)
	var/wide_hang = FALSE // hangs two tiles wide on a wall to the north
	var/tmp/mob/editing = null
	var/tmp/list/upload_parts = null
	var/tmp/upload_count = 0
	var/tmp/upload_palette = null
	var/tmp/worn_small = null // 8x8 copy for lockets

/obj/item/canvas/persistence_runtime_var(key)
	return key == "editing" || key == "upload_parts" || key == "upload_count" || key == "upload_palette" || key == "worn_small" || key == "overlays" || ..()

/obj/item/canvas/miniature
	name = "miniature panel"
	desc = "A small primed wooden panel for a miniature. Paint it in your hands, then set it into a necklace as a locket."
	icon_state = "canvas_miniature"
	w_class = ITEM_SIZE_TINY
	format = "miniature"
	format_weight = 0.25
	needs_easel = FALSE
	canvas_w = 16
	canvas_h = 16
	art_w = 16
	art_h = 16
	art_left = 8
	art_top = 8
	frame_state = "frame_miniature"
	value = 1

/obj/item/canvas/table
	name = "table picture"
	desc = "A small primed panel in a standing frame, for a picture on a table or shelf. Paint it in your hands."
	icon_state = "canvas_table"
	w_class = ITEM_SIZE_SMALL
	format = "table"
	format_weight = 0.25
	needs_easel = FALSE
	canvas_w = 32
	canvas_h = 32
	art_w = 16
	art_h = 16
	art_left = 8
	art_top = 6
	frame_state = "frame_table"

// Fine Arts: gallery canvases for museums and halls, shown 2x2 or 2x1 tiles
// in a gilded frame (icons/obj/paintings_gallery.dmi) when hung.
/obj/item/canvas/gallery
	name = "gallery canvas"
	desc = "A large stretched canvas for a museum painting. Set it on an easel to paint it, then hang it on a wall to your north."
	icon_state = "canvas_gallery"
	w_class = ITEM_SIZE_LARGE
	format = "gallery"
	canvas_w = 128
	canvas_h = 128
	art_w = 56
	art_h = 56
	art_left = 4
	art_top = 4
	frame_state = "gallery"
	wide_hang = TRUE
	pixel_use_scale = 8 // a full 128x128 canvas uses at most 8 of a pigment
	value = 4

/obj/item/canvas/gallery/wide
	name = "wide gallery canvas"
	desc = "A large stretched landscape canvas for a museum painting. Set it on an easel to paint it, then hang it on a wall to your north."
	icon_state = "canvas_gallery_wide"
	canvas_w = 128
	canvas_h = 64
	art_w = 56
	art_h = 24
	art_top = 36
	frame_state = "gallery_wide"

// Held and on an easel a gallery canvas shows its plain sprite; the art
// shows in its frame on the wall.
/obj/item/canvas/gallery/update_icon()
	overlays.Cut()

/obj/item/canvas/proc/framed_overlays()
	if (!small)
		return list()
	update_icon()
	return overlays.Copy()

/obj/item/canvas/gallery/framed_overlays()
	var/list/out = list()
	var/icon/I = small ? painting_build_icon(small, art_w, art_h, art_left, art_top, 'icons/obj/paintings_gallery.dmi', frame_state) : null
	if (I)
		out += image(I)
	out += image('icons/obj/paintings_gallery.dmi', frame_state)
	return out

/obj/item/canvas/New()
	..()
	if (finished && !restoring)
		painting_registry |= src

/obj/item/canvas/after_load()
	..()
	if (finished)
		painting_registry |= src
	update_icon()

/obj/item/canvas/Destroy()
	painting_registry -= src
	if (editing)
		painting_close_editor(editing)
	editing = null
	return ..()

/obj/item/canvas/update_icon()
	overlays.Cut()
	if (!small)
		return
	var/icon/I = painting_build_icon(small, art_w, art_h, art_left, art_top, icon, icon_state)
	if (I)
		overlays += image(I)
	overlays += image(icon, frame_state)

/obj/item/canvas/examine(mob/user)
	..()
	if (!paint_data)
		to_chat(user, "It is blank.")
		return
	if (finished)
		to_chat(user, "It is a finished painting called \"[title ? html_encode(title) : "Untitled"]\"[author_name ? ", painted by [html_encode(author_name)]" : ""].")
	else
		to_chat(user, "Someone has started painting it.")
	if (get_dist(user, src) <= 1 || isobserver(user))
		painting_show_full(user, src)

/obj/item/canvas/attack_self(mob/user)
	if (finished)
		painting_show_full(user, src)
		return
	if (needs_easel)
		to_chat(user, SPAN_NOTICE("Set \the [src] on an easel to paint it."))
		return
	painting_open_editor(user, src)

/obj/item/canvas/afterattack(atom/target, mob/user, proximity_flag, params)
	if (!proximity_flag || !(format in list("wall", "gallery")) || !finished)
		return ..()
	if (!painting_is_wall(target))
		return ..()
	painting_hang(user, src, target)

// Colours this canvas offers besides pigments (a sketch offers the pen's ink).
/obj/item/canvas/proc/extra_colours(mob/user)
	return list()

// After a finish has been kept and the editor closed.
/obj/item/canvas/proc/on_finished(mob/user)
	return

// The painter closed the editor.
/obj/item/canvas/proc/editor_closed()
	return

/obj/item/canvas/proc/painting_name_text()
	return title ? "\"[title]\"" : "an untitled painting"

// The shown copies, rebuilt from the saved pixels.
/obj/item/canvas/proc/refresh_small()
	var/list/pal = painting_palette_list(palette)
	var/plain = pal ? painting_unpack(paint_data, canvas_w * canvas_h) : null
	if (!plain)
		small = null
		worn_small = null
		return FALSE
	small = painting_shrink(plain, pal, canvas_w, canvas_h, art_w, art_h)
	worn_small = null
	return TRUE

/obj/item/canvas/proc/get_worn_small()
	if (!worn_small)
		var/list/pal = painting_palette_list(palette)
		var/plain = pal ? painting_unpack(paint_data, canvas_w * canvas_h) : null
		if (plain)
			worn_small = painting_shrink(plain, pal, canvas_w, canvas_h, 8, 8)
	return worn_small

/proc/painting_weight_total()
	var/total = 0
	for (var/obj/item/canvas/C in painting_registry)
		total += C.format_weight
	return total

// Pigment for a finished painting: each pigment whose colours it uses loses
// one use per PAINT_PIXELS_PER_USE pixels painted with them.
/obj/item/canvas/proc/use_pigments(mob/user, plain, list/pal)
	if (!uses_pigments)
		return
	var/list/counts = list()
	for (var/i = 1, i <= length(plain), i++)
		var/d = copytext(plain, i, i + 1)
		counts[d] = (counts[d] || 0) + 1
	var/list/pigments = painting_carried_pigments(user)
	var/list/need = list()
	for (var/d in counts)
		var/hex = pal[hex2num(d) + 1]
		if (hex == base_colour)
			continue
		for (var/obj/item/pigment/P in pigments)
			for (var/c in P.pigment_colors)
				var/pc = painting_hex(c)
				if (pc == hex || painting_colour_uses(hex, pc, user, src))
					need[P] = (need[P] || 0) + counts[d]
					break
	for (var/obj/item/pigment/P in need)
		P.pigment_uses -= max(1, round(need[P] / (PAINT_PIXELS_PER_USE * pixel_use_scale) + 0.999))
		if (P.pigment_uses <= 0)
			to_chat(user, SPAN_NOTICE("You use up the last of \the [P]."))
			qdel(P)

// Whether hex is pc mixed with any other colour the user may paint with.
/proc/painting_colour_uses(hex, pc, mob/user, obj/item/canvas/C)
	var/list/base = list(C.base_colour)
	for (var/obj/item/pigment/P in user.get_contents())
		for (var/c in P.pigment_colors)
			base |= painting_hex(c)
	for (var/other in base)
		if (other != pc && painting_mix(pc, other) == hex)
			return TRUE
	return FALSE

/////////////////////////////// Easel ///////////////////////////////

/obj/structure/easel
	name = "easel"
	desc = "A wooden stand that holds a canvas upright while you paint."
	icon = 'icons/obj/paintings.dmi'
	icon_state = "easel"
	density = TRUE
	anchored = FALSE
	flammable = TRUE

/obj/structure/easel/persistence_runtime_var(key)
	return key == "overlays" || ..()

/obj/structure/easel/after_load()
	..()
	update_icon()

/obj/structure/easel/proc/held_canvas()
	return locate(/obj/item/canvas) in contents

/obj/structure/easel/update_icon()
	overlays.Cut()
	if (held_canvas())
		overlays += image(icon, "easel_canvas")

/obj/structure/easel/attackby(obj/item/I, mob/user)
	if (istype(I, /obj/item/canvas))
		if (held_canvas())
			to_chat(user, SPAN_WARNING("\The [src] already holds a canvas."))
			return
		user.drop_from_inventory(I, src)
		I.forceMove(src)
		update_icon()
		user.visible_message(SPAN_NOTICE("[user] sets \the [I] on \the [src]."), SPAN_NOTICE("You set \the [I] on \the [src]."))
		return
	return ..()

/obj/structure/easel/attack_hand(mob/user)
	var/obj/item/canvas/C = held_canvas()
	if (!C)
		to_chat(user, SPAN_NOTICE("\The [src] is empty. Set a canvas on it."))
		return
	var/list/choices = list("Take the canvas", "Cancel")
	if (!C.finished)
		choices.Insert(1, "Paint")
	else
		choices.Insert(1, "Look at it")
	var/choice = WWinput(user, "What do you want to do with \the [C]?", "Easel", choices[1], choices)
	if (!choice || choice == "Cancel" || !Adjacent(user) || C.loc != src)
		return
	switch (choice)
		if ("Paint")
			painting_open_editor(user, C)
		if ("Look at it")
			painting_show_full(user, C)
		if ("Take the canvas")
			if (C.editing)
				painting_close_editor(C.editing)
			user.put_in_hands(C)
			update_icon()

/obj/structure/easel/examine(mob/user)
	..()
	var/obj/item/canvas/C = held_canvas()
	if (C)
		to_chat(user, "It holds \a [C].")
		if (C.paint_data && get_dist(user, src) <= 1)
			painting_show_full(user, C)

/obj/structure/easel/Destroy()
	for (var/obj/item/canvas/C in contents)
		C.forceMove(get_turf(src))
	return ..()

/////////////////////////////// Hanging on walls ///////////////////////////////

/proc/painting_is_wall(atom/A)
	if (isturf(A))
		return A.density
	if (istype(A, /obj/covers))
		var/obj/covers/C = A
		return C.wall && C.density
	return FALSE

/proc/painting_hang(mob/user, obj/item/canvas/C, atom/wall)
	var/mob/living/holder = user
	return wall_frame_mount(holder, C, wall)

/obj/item/ship_draught/afterattack(atom/target, mob/user, proximity_flag, params)
	var/mob/living/holder = user
	if (!proximity_flag || !istype(holder) || !painting_is_wall(target))
		return ..()
	if (loc != holder || !holder.item_is_in_hands(src))
		return
	var/datum/framed_plan_diagram/V = framed_plan_diagram()
	if (!V)
		to_chat(holder, SPAN_NOTICE("Only a sheet with a supported drawing can be framed."))
		return
	wall_frame_mount(holder, src, target, V)
	qdel(V)

// A loose sketch is art, but its accompanying writing is not exposed by
// the frame. Recover the original sheet before editing or reading it.
/obj/item/weapon/paper/afterattack(atom/target, mob/user, proximity_flag, params)
	var/mob/living/holder = user
	if (!proximity_flag || !istype(holder) || !length(drawings) || !painting_is_wall(target))
		return ..()
	wall_frame_mount(holder, src, target)

/proc/painting_frame_occupies(turf/T, facing)
	for (var/obj/structure/painting_frame/F in T)
		if (!QDELETED(F) && F.dir == facing)
			return TRUE
	if (facing == NORTH)
		for (var/obj/structure/painting_frame/F in get_step(T, WEST))
			var/obj/item/canvas/C = F.held_canvas()
			if (!QDELETED(F) && F.dir == NORTH && C && C.wide_hang)
				return TRUE
	return FALSE

/proc/wall_frame_mount(mob/living/user, obj/item/original, atom/wall, datum/framed_plan_diagram/V)
	if (!istype(user) || QDELETED(user) || QDELETED(original) || QDELETED(wall) || user.incapacitated() || original.loc != user || !user.item_is_in_hands(original) || !painting_is_wall(wall))
		return FALSE
	var/obj/item/canvas/C = istype(original, /obj/item/canvas) ? original : null
	if (istype(C))
		if (!C.finished || !(C.format in list("wall", "gallery")))
			return FALSE
	else if (istype(original, /obj/item/ship_draught))
		if (!V || !V.layers.len)
			return FALSE
	else if (istype(original, /obj/item/weapon/paper))
		if (!framed_sketch_thumbnail(original))
			return FALSE
	else
		return FALSE
	var/turf/T = user.loc
	var/turf/W = get_turf(wall)
	if (!isturf(T) || T.density || !W)
		return FALSE
	var/dir = get_dir(T, W)
	if (!(dir in cardinal) || get_step(T, dir) != W || !wall.Adjacent(user))
		to_chat(user, SPAN_WARNING("Stand straight in front of the wall to hang it."))
		return FALSE
	var/list/spots = list(T)
	if (C?.wide_hang)
		// Two tiles wide, from the painter's tile to the east, on a wall to the north.
		var/turf/E = get_step(T, EAST)
		if (dir != NORTH || !E || !painting_is_wall_turf(get_step(E, NORTH)) || E.density)
			to_chat(user, SPAN_WARNING("\The [original] hangs on a wall to your north, two tiles wide: the wall must run on to your right."))
			return FALSE
		spots += E
	for (var/turf/spot in spots)
		if (painting_frame_occupies(spot, dir))
			to_chat(user, SPAN_WARNING("A frame already hangs there."))
			return FALSE
		for (var/obj/structure/banner/B in spot)
			if (B.banner_mount_dir == dir)
				to_chat(user, SPAN_WARNING("A banner already hangs there."))
				return FALSE
		for (var/obj/structure/noticeboard/B in spot)
			if (B.board_mount_dir == dir)
				to_chat(user, SPAN_WARNING("A noticeboard already hangs there."))
				return FALSE
	var/obj/structure/painting_frame/F = new(T)
	F.dir = dir
	if (!user.transfer_held_item_to(original, F))
		qdel(F)
		return FALSE
	F.place(V)
	F.add_fingerprint(user)
	user.visible_message(SPAN_NOTICE("[user] hangs \the [original] on the wall."), SPAN_NOTICE("You hang \the [original] on the wall."))
	return TRUE

/proc/painting_is_wall_turf(turf/T)
	if (!T)
		return FALSE
	if (T.density)
		return TRUE
	for (var/obj/covers/C in T)
		if (C.wall && C.density)
			return TRUE
	return FALSE

/obj/structure/painting_frame
	name = "painting"
	desc = "A painting hanging on the wall."
	icon = 'icons/obj/paintings.dmi'
	icon_state = ""
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	layer = 3.5
	flammable = TRUE

/obj/structure/painting_frame/persistence_runtime_var(key)
	return key == "overlays" || ..()

/obj/structure/painting_frame/proc/held_canvas()
	return locate(/obj/item/canvas) in contents

/obj/structure/painting_frame/proc/held_plan()
	return locate(/obj/item/ship_draught) in contents

/obj/structure/painting_frame/proc/held_sketch()
	return locate(/obj/item/weapon/paper) in contents

/obj/structure/painting_frame/proc/place(datum/framed_plan_diagram/V)
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
	update_icon(V)

/obj/structure/painting_frame/after_load()
	..()
	place()

/obj/structure/painting_frame/update_icon(datum/framed_plan_diagram/V)
	overlays.Cut()
	var/obj/item/canvas/C = held_canvas()
	if (C)
		name = C.title ? "\"[C.title]\"" : "painting"
		overlays += C.framed_overlays()
		return
	var/obj/item/ship_draught/P = held_plan()
	if (!P)
		var/obj/item/weapon/paper/S = held_sketch()
		if (S)
			name = "framed sketch"
			desc = "A sketch on paper in a wall frame. Examine it up close to see the drawings."
			var/icon/art = framed_sketch_thumbnail(S)
			if (art)
				overlays += image(art)
			overlays += image('icons/obj/paintings.dmi', "frame_table")
		return
	name = "framed plan"
	desc = "A framed plan hanging on the wall. Examine it up close to see the full drawing."
	var/rebuilt = !V
	if (rebuilt)
		V = P.framed_plan_diagram()
	if (V)
		overlays += image(V.thumbnail())
		if (rebuilt)
			qdel(V)
	overlays += image('icons/obj/paintings.dmi', "frame_table")

/obj/structure/painting_frame/examine(mob/user)
	..()
	show_framed_work(user)

/obj/structure/painting_frame/attack_hand(mob/user)
	show_framed_work(user)

/obj/structure/painting_frame/proc/show_framed_work(mob/user)
	if (QDELETED(src) || !user?.client)
		return
	var/obj/item/canvas/C = held_canvas()
	if (C)
		to_chat(user, "\"[C.title ? html_encode(C.title) : "Untitled"]\"[C.author_name ? ", painted by [html_encode(C.author_name)]" : ""].")
		// Existing wall paintings retain their normal Examine range.
		painting_show_full(user, C)
		return
	if (!isobserver(user) && !Adjacent(user))
		return
	var/obj/item/ship_draught/P = held_plan()
	var/datum/framed_plan_diagram/V = P?.framed_plan_diagram()
	if (V)
		show_browse(user, V.html(), "window=framed_plan;size=[V.window_size()]")
		qdel(V)
		return
	var/obj/item/weapon/paper/S = held_sketch()
	var/html = S ? drawings_html(S, user) : null
	if (length(html))
		show_browse(user, "<html><head><meta charset='utf-8'><title>Framed drawings</title></head><body style='background:#f4efe1'>[html]</body></html>", "window=framed_sketch;size=640x640")

/obj/structure/painting_frame/attackby(obj/item/I, mob/user)
	if (!is_tool(I, TOOL_HAMMER))
		return ..()
	var/mob/living/holder = user
	if (!istype(holder) || holder.incapacitated() || !Adjacent(holder) || QDELETED(I) || I.loc != holder || !holder.item_is_in_hands(I))
		return TRUE
	var/obj/item/original = held_canvas()
	if (!original)
		original = held_plan()
	if (!original)
		original = held_sketch()
	if (original)
		holder.put_in_hands(original)
		if (QDELETED(original) || original.loc == src)
			return TRUE
	holder.visible_message(SPAN_NOTICE("[holder] takes down \the [src]."), SPAN_NOTICE("You take down \the [src]."))
	qdel(src)
	return TRUE

/obj/structure/painting_frame/ex_act(severity)
	qdel(src)

/obj/structure/painting_frame/Destroy()
	var/turf/T = get_turf(src)
	if (T)
		for (var/obj/item/O in contents)
			O.forceMove(T)
	return ..()

/////////////////////////////// Lockets ///////////////////////////////

/obj/item/clothing/accessory/necklace/proc/held_miniature()
	return locate(/obj/item/canvas/miniature) in contents

/obj/item/clothing/accessory/necklace/attackby(obj/item/I, mob/user)
	if (istype(I, /obj/item/canvas/miniature))
		var/obj/item/canvas/miniature/M = I
		if (!M.finished)
			to_chat(user, SPAN_WARNING("Finish the miniature before setting it into \the [src]."))
			return
		if (held_miniature() || set_gem)
			to_chat(user, SPAN_WARNING("\The [src] already has a pendant."))
			return
		user.drop_from_inventory(M, src)
		M.forceMove(src)
		update_icon()
		to_chat(user, SPAN_NOTICE("You set [M.painting_name_text()] into \the [src] as a locket."))
		return
	return ..()

/obj/item/clothing/accessory/necklace/verb/take_out_miniature()
	set name = "Take Out Miniature"
	set category = "Object"
	set src in usr
	var/obj/item/canvas/miniature/M = held_miniature()
	if (!M || usr.incapacitated())
		return
	usr.put_in_hands(M)
	update_icon()
	if (ismob(loc))
		var/mob/W = loc
		W.regenerate_icons()
	to_chat(usr, SPAN_NOTICE("You take [M.painting_name_text()] out of \the [src]."))

/obj/item/clothing/accessory/necklace/proc/add_locket_overlay(target, worn)
	var/obj/item/canvas/miniature/M = held_miniature()
	if (!M || !target)
		return
	if (worn)
		var/icon/art = painting_build_icon(M.get_worn_small(), 8, 8, PAINT_LOCKET_LEFT, PAINT_LOCKET_TOP, 'icons/mob/paintings.dmi', "locket", SOUTH)
		target:overlays += image('icons/mob/paintings.dmi', "locket")
		if (art)
			target:overlays += image(art, "locket")
	else
		M.update_icon()
		var/image/I = image(M.icon, M.icon_state)
		I.overlays = M.overlays
		I.transform = matrix() * 0.5
		target:overlays += I

/obj/item/clothing/accessory/necklace/examine(mob/user)
	..()
	var/obj/item/canvas/miniature/M = held_miniature()
	if (M)
		to_chat(user, "It holds a miniature locket, [M.painting_name_text()].")
		if (get_dist(user, src) <= 1)
			painting_show_full(user, M)
