// Designed pottery: an unfired vessel is thrown into one of eight shapes,
// given a painted band (the painting editor at the band's own size, with the
// painter's carried pigments as slips) and a glaze, then fired in an oven or
// kiln into a working container that shows all three. A decorated pot set
// down in a room counts as art for mood and for a home. Art by Fable
// (icons/obj/pottery_designs.dmi: <shape>_unfired, <shape>, <shape>_glaze,
// <shape>_shade).

#define POTTERY_BISQUE "#c97b52" // the band's unpainted colour, left bare

// shape -> name, volume, size, band left/top/width/height from the icon's top left
var/global/list/pottery_shapes = pottery_shapes_table()
/proc/pottery_shapes_table()
	return list(
	"cup" = list("name" = "cup", "volume" = 30, "w_class" = ITEM_SIZE_TINY, "band" = list(12, 22, 8, 3)),
	"bowl" = list("name" = "bowl", "volume" = 50, "w_class" = ITEM_SIZE_SMALL, "band" = list(10, 22, 12, 3)),
	"jug" = list("name" = "jug", "volume" = 100, "w_class" = ITEM_SIZE_SMALL, "band" = list(11, 19, 10, 4)),
	"jar" = list("name" = "jar", "volume" = 100, "w_class" = ITEM_SIZE_SMALL, "band" = list(10, 18, 12, 4)),
	"vase" = list("name" = "vase", "volume" = 130, "w_class" = ITEM_SIZE_SMALL, "band" = list(11, 17, 10, 4)),
	"amphora" = list("name" = "amphora", "volume" = 150, "w_class" = ITEM_SIZE_NORMAL, "band" = list(10, 13, 12, 5)),
	"flask" = list("name" = "pilgrim flask", "volume" = 60, "w_class" = ITEM_SIZE_SMALL, "band" = list(10, 19, 12, 4)),
	"storage_jar" = list("name" = "storage jar", "volume" = 200, "w_class" = ITEM_SIZE_NORMAL, "band" = list(8, 11, 16, 6)),
)

// glaze -> colour and the research it needs (null: anyone who can make pots)
var/global/list/pottery_glazes = list(
	"white slip" = list("color" = "#e9dcc0", "node" = null),
	"red ochre slip" = list("color" = "#b5442f", "node" = null),
	"black gloss" = list("color" = "#2e2927", "node" = "pottery_storage"),
	"wood-ash glaze" = list("color" = "#a3a878", "node" = "pottery_storage"),
	"turquoise glaze" = list("color" = "#35b3ad", "node" = "glassworking"),
	"amber lead glaze" = list("color" = "#cf8f2c", "node" = "glassworking"),
	"green lead glaze" = list("color" = "#4c9450", "node" = "glassworking"),
	"celadon" = list("color" = "#a9cbab", "node" = "fine_arts"),
	"tin white glaze" = list("color" = "#f3f1e9", "node" = "fine_arts"),
	"cobalt blue" = list("color" = "#3353ad", "node" = "fine_arts"),
)

var/global/list/pottery_band_cache = list()

/proc/pottery_glaze_allowed(mob/user, glaze)
	var/list/G = pottery_glazes[glaze]
	if (!G)
		return FALSE
	return !G["node"] || research_node_known(user, G["node"])

// The band as an icon over the pot: painted pixels only, unpainted ones bare.
/proc/pottery_band_icon(shape, band_palette, band_data)
	var/list/S = pottery_shapes[shape]
	if (!S || !band_palette || !band_data)
		return null
	var/key = "[shape]|[band_palette]|[band_data]"
	if (key in pottery_band_cache)
		return pottery_band_cache[key]
	var/list/rect = S["band"]
	var/w = rect[3]
	var/h = rect[4]
	var/list/pal = painting_palette_list(band_palette)
	var/plain = pal ? painting_unpack(band_data, w * h) : null
	var/icon/I = null
	if (plain && painting_max_index(plain) < pal.len)
		I = icon('icons/obj/pottery_designs.dmi', "[shape]_shade")
		I.Blend("#00000000", ICON_MULTIPLY)
		var/drawn = FALSE
		for (var/y = 0, y < h, y++)
			var/iy = 32 - rect[2] - y
			for (var/x = 0, x < w, x++)
				var/code = text2ascii(plain, y * w + x + 1)
				var/hex = pal[(code <= 57 ? code - 48 : code - 87) + 1]
				if (hex == POTTERY_BISQUE)
					continue
				I.DrawBox(hex, rect[1] + x + 1, iy)
				drawn = TRUE
		if (!drawn)
			I = null
	pottery_band_cache[key] = I
	return I

// The overlays of a pot: glaze, band and the shading over the band.
/proc/pottery_overlays(shape, glaze, band_palette, band_data, fired)
	var/list/out = list()
	if (!pottery_shapes[shape])
		return out
	if (fired && pottery_glazes[glaze])
		var/image/G = image('icons/obj/pottery_designs.dmi', "[shape]_glaze")
		G.color = pottery_glazes[glaze]["color"]
		out += G
	var/icon/B = pottery_band_icon(shape, band_palette, band_data)
	if (B)
		out += image(B)
	if (fired)
		var/image/S = image('icons/obj/pottery_designs.dmi', "[shape]_shade")
		S.appearance_flags = RESET_COLOR
		out += S
	return out

/proc/pottery_describe(shape, glaze, band_data, band_by, fired)
	var/list/out = list()
	if (glaze)
		out += fired ? "It is finished in [glaze]." : "It will be finished in [glaze] when fired."
	if (band_data)
		out += "A painted band runs round it[band_by ? ", by [band_by]" : ""]."
	return jointext(out, " ")

/////////////////////////////// Unfired vessel ///////////////////////////////

/obj/item/weapon/clay/vessel
	name = "unfired clay vessel"
	desc = "A lump of clay ready to be thrown into a pot of your own design. Use it in hand to shape it, paint a band round it and choose a glaze, then fire it."
	icon = 'icons/obj/pottery_designs.dmi'
	icon_state = "jar_unfired"
	result = /obj/item/weapon/reagent_containers/food/drinks/clay/designed
	var/shape = "jar"
	var/glaze = null
	var/band_palette = null
	var/band_data = null
	var/band_by = null
	var/tmp/obj/item/canvas/pottery_band/band_canvas = null

/obj/item/weapon/clay/vessel/persistence_runtime_var(key)
	return key == "band_canvas" || key == "overlays" || ..()

/obj/item/weapon/clay/vessel/New()
	..()
	update_icon()

/obj/item/weapon/clay/vessel/after_load()
	..()
	update_icon()

/obj/item/weapon/clay/vessel/Destroy()
	if (band_canvas && !QDELETED(band_canvas))
		qdel(band_canvas)
	band_canvas = null
	return ..()

/obj/item/weapon/clay/vessel/update_icon()
	icon_state = "[shape]_unfired"
	name = "unfired clay [pottery_shapes[shape]["name"]]"
	w_class = pottery_shapes[shape]["w_class"]
	overlays.Cut()
	overlays += pottery_overlays(shape, glaze, band_palette, band_data, FALSE)

/obj/item/weapon/clay/vessel/examine(mob/user)
	..()
	var/text = pottery_describe(shape, glaze, band_data, band_by, FALSE)
	if (text)
		to_chat(user, text)

/obj/item/weapon/clay/vessel/attack_self(mob/user)
	if (!ishuman(user))
		return
	var/choice = WWinput(user, "Work the [name].", "Pottery", "Done", list("Shape", "Paint band", "Clear band", "Glaze", "Done"))
	if (!choice || choice == "Done" || loc != user || user.incapacitated())
		return
	switch (choice)
		if ("Shape")
			var/list/names = list()
			for (var/id in pottery_shapes)
				names[pottery_shapes[id]["name"]] = id
			var/pick = WWinput(user, "Throw it into which shape? Changing the shape wipes the band.", "Pottery", pottery_shapes[shape]["name"], names + "Cancel")
			if (!pick || pick == "Cancel" || loc != user || !names[pick])
				return
			if (names[pick] != shape)
				shape = names[pick]
				band_palette = null
				band_data = null
				band_by = null
				to_chat(user, SPAN_NOTICE("You throw the clay into \a [pick]."))
		if ("Paint band")
			paint_band(user)
		if ("Clear band")
			if (band_data)
				band_palette = null
				band_data = null
				band_by = null
				to_chat(user, SPAN_NOTICE("You smooth the band off the clay."))
		if ("Glaze")
			var/list/options = list("None")
			for (var/g in pottery_glazes)
				if (pottery_glaze_allowed(user, g))
					options += g
			var/pick = WWinput(user, "Dip it in which slip or glaze? It shows once fired. Pottery, glassworking and fine arts teach more.", "Pottery", glaze || "None", options + "Cancel")
			if (!pick || pick == "Cancel" || loc != user)
				return
			glaze = pick == "None" ? null : pick
			to_chat(user, SPAN_NOTICE(glaze ? "You dip it in [glaze]." : "You leave it bare."))
	update_icon()

/obj/item/weapon/clay/vessel/proc/paint_band(mob/user)
	if (band_canvas && !QDELETED(band_canvas) && band_canvas.editing && band_canvas.editing != user)
		to_chat(user, SPAN_WARNING("[band_canvas.editing] is already painting it."))
		return
	if (band_canvas && !QDELETED(band_canvas))
		qdel(band_canvas)
	var/list/rect = pottery_shapes[shape]["band"]
	var/obj/item/canvas/pottery_band/C = new(null)
	C.target = src
	C.canvas_w = rect[3]
	C.canvas_h = rect[4]
	C.art_w = rect[3]
	C.art_h = rect[4]
	C.name = "band round \the [src]"
	C.title = "Band"
	if (band_data)
		C.palette = band_palette
		C.paint_data = band_data
	band_canvas = C
	painting_open_editor(user, C)
	if (C.editing != user)
		qdel(C)
		band_canvas = null

// A pile of unfired bricks fires into a pile (clay blocks yield two each).
/obj/item/weapon/clay/proc/fired_result(atom/where)
	if (loose_pile_max)
		return loose_pile_spawn(result, where, amount * fired_yield)
	return new result(where)

/obj/item/weapon/clay/vessel/fired_result(atom/where)
	var/obj/item/weapon/reagent_containers/food/drinks/clay/designed/P = new result(where)
	P.set_design(shape, glaze, band_palette, band_data, band_by)
	return P

/////////////////////////////// Band canvas ///////////////////////////////

// The band painted at its own size in the painting editor; finishing it
// puts the pixels on the vessel. Carried pigments are the slips.
/obj/item/canvas/pottery_band
	name = "pot band"
	format = "pottery"
	format_weight = 0
	needs_easel = FALSE
	base_colour = POTTERY_BISQUE
	var/tmp/obj/item/weapon/clay/vessel/target = null

/obj/item/canvas/pottery_band/persistence_runtime_var(key)
	return key == "target" || ..()

/obj/item/canvas/pottery_band/refresh_small()
	small = null
	return TRUE

/obj/item/canvas/pottery_band/update_icon()
	return

/obj/item/canvas/pottery_band/on_finished(mob/user)
	painting_registry -= src
	if (QDELETED(target))
		qdel(src)
		return
	target.band_palette = palette
	target.band_data = paint_data
	target.band_by = user.real_name
	target.band_canvas = null
	target.update_icon()
	to_chat(user, SPAN_NOTICE("You paint the band round \the [target]."))
	qdel(src)

/obj/item/canvas/pottery_band/editor_closed()
	if (!QDELETED(target) && target.band_canvas == src)
		target.band_canvas = null
	if (!QDELETED(src))
		qdel(src)

/////////////////////////////// Fired pot ///////////////////////////////

/obj/item/weapon/reagent_containers/food/drinks/clay/designed
	name = "clay jar"
	desc = "A fired clay pot of someone's own design."
	icon = 'icons/obj/pottery_designs.dmi'
	icon_state = "jar"
	volume = 100
	amount_per_transfer_from_this = 10
	var/shape = "jar"
	var/glaze = null
	var/band_palette = null
	var/band_data = null
	var/band_by = null

/obj/item/weapon/reagent_containers/food/drinks/clay/designed/persistence_runtime_var(key)
	return key == "overlays" || ..()

/obj/item/weapon/reagent_containers/food/drinks/clay/designed/proc/set_design(new_shape, new_glaze, new_palette, new_data, new_by)
	shape = pottery_shapes[new_shape] ? new_shape : "jar"
	glaze = pottery_glazes[new_glaze] ? new_glaze : null
	band_palette = new_palette
	band_data = new_data
	band_by = new_by
	volume = pottery_shapes[shape]["volume"]
	if (reagents)
		reagents.maximum_volume = volume
	update_icon()

/obj/item/weapon/reagent_containers/food/drinks/clay/designed/after_load()
	..()
	update_icon()

/obj/item/weapon/reagent_containers/food/drinks/clay/designed/update_icon()
	if (!pottery_shapes[shape])
		shape = "jar"
	icon_state = shape
	var/what = pottery_shapes[shape]["name"]
	name = glaze ? "[glaze] [what]" : "clay [what]"
	w_class = pottery_shapes[shape]["w_class"]
	overlays.Cut()
	overlays += pottery_overlays(shape, glaze, band_palette, band_data, TRUE)

/obj/item/weapon/reagent_containers/food/drinks/clay/designed/examine(mob/user)
	..()
	var/text = pottery_describe(shape, glaze, band_data, band_by, TRUE)
	if (text)
		to_chat(user, text)

// Glazed or painted, set down in a room, it is a piece of art.
/obj/item/weapon/reagent_containers/food/drinks/clay/designed/proc/decorated()
	return glaze || band_data

#undef POTTERY_BISQUE
