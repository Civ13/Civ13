//ported from tg on 19/04/2020

///////////
// EASEL //
///////////

/obj/structure/easel
	name = "easel"
	desc = "Only for the finest of art!"
	icon = 'icons/obj/artstuff.dmi'
	icon_state = "easel"
	density = TRUE
	flammable = TRUE
	var/obj/item/canvas/painting = null

//Adding canvases
/obj/structure/easel/attackby(obj/item/I, mob/user, params)
	if(istype(I, /obj/item/canvas))
		var/obj/item/canvas/C = I
		user.drop_from_inventory(C)
		painting = C
		C.forceMove(get_turf(src))
		C.layer = layer+0.1
		user.visible_message("<span class='notice'>[user] puts \the [C] on \the [src].</span>","<span class='notice'>You place \the [C] on \the [src].</span>")
	else
		return ..()


//Stick to the easel like glue
/obj/structure/easel/Move()
	var/turf/T = get_turf(src)
	. = ..()
	if(painting && painting.loc == T) //Only move if it's near us.
		painting.forceMove(get_turf(src))
	else
		painting = null

/obj/item/canvas
	name = "canvas"
	desc = "Draw out your soul on this canvas!"
	icon = 'icons/obj/artstuff.dmi'
	icon_state = "11x11"
	flammable = TRUE
	var/width = 11
	var/height = 11
	var/list/grid
	var/canvas_color = "#ffffff" //empty canvas color
	var/ui_x = 400
	var/ui_y = 400
	var/used = FALSE
	var/painting_name //Painting name, this is set after framing.
	var/finalized = FALSE //Blocks edits
	var/author_ckey
	var/icon_generated = FALSE
	var/icon/generated_icon

	// Painting overlay offset when framed
	var/framed_offset_x = 11
	var/framed_offset_y = 10

	pixel_x = 10
	pixel_y = 9

/obj/item/canvas/New()
	..()
	reset_grid()

/obj/item/canvas/proc/reset_grid()
	grid = new/list(width,height)
	for(var/x in 1 to width)
		for(var/y in 1 to height)
			grid[x][y] = canvas_color

/obj/item/canvas/attack_self(mob/user)
	..()
	ui_interact(user)
/*
/obj/item/canvas/ui_interact(mob/user, ui_key = "main", datum/tgui/ui = null, force_open = FALSE, \
										datum/tgui/master_ui = null, datum/ui_state/state = GLOB.default_state)

	ui = SStgui.try_update_ui(user, src, ui_key, ui, force_open)
	if(!ui)
		ui = new(user, src, ui_key, "canvas", name, ui_x, ui_y, master_ui, state)
		ui.set_autoupdate(FALSE)
		ui.open()
*/
/obj/item/canvas/attackby(obj/item/I, mob/living/user, params)
	if(user.a_intent == I_HELP)
		ui_interact(user)
	else
		return ..()

/obj/item/canvas/ui_data(mob/user)
	. = ..()
	.["grid"] = grid
	.["name"] = painting_name
	.["finalized"] = finalized

/obj/item/canvas/examine(mob/user)
	. = ..()
	ui_interact(user)

/obj/item/canvas/ui_act(action, params)
	. = ..()
	if(. || finalized)
		return
	var/mob/user = usr
	switch(action)
		if("paint")
			var/obj/item/I = user.get_active_held_item()
			var/color = get_paint_tool_color(I)
			if(!color)
				return FALSE
			var/x = text2num(params["x"])
			var/y = text2num(params["y"])
			grid[x][y] = color
			used = TRUE
			update_icon()
			. = TRUE
		if("finalize")
			. = TRUE
			if(!finalized)
				finalize(user)

/obj/item/canvas/proc/finalize(mob/user)
	finalized = TRUE
	author_ckey = user.ckey
	generate_proper_overlay()
	try_rename(user)

/obj/item/canvas/update_icon()
	. = ..()
	if(!icon_generated)
		if(used)
			var/mutable_appearance/detail = mutable_appearance(icon,"[icon_state]wip")
			detail.pixel_x = 1
			detail.pixel_y = 1
			. += detail
	else
		var/mutable_appearance/detail = mutable_appearance(generated_icon)
		detail.pixel_x = 1
		detail.pixel_y = 1
		. += detail

/obj/item/canvas/proc/generate_proper_overlay()
	if(icon_generated)
		return
	var/png_filename = "data/paintings/temp_painting.png"
	var/result = rustg_dmi_create_png(png_filename,"[width]","[height]",get_data_string())
	if(result)
		CRASH("Error generating painting png : [result]")
	generated_icon = new(png_filename)
	icon_generated = TRUE
	update_icon()

/obj/item/canvas/proc/get_data_string()
	var/list/data = list()
	for(var/y in 1 to height)
		for(var/x in 1 to width)
			data += grid[x][y]
	return data.Join("")

//Todo make this element ?
/obj/item/canvas/proc/get_paint_tool_color(obj/item/I)
	if(!I)
		return
	else if(istype(I, /obj/item/weapon/pen))
		return I.color
	else if(istype(I, /obj/item/weapon/soap) || istype(I, /obj/item/stack/material/rags))
		return canvas_color

/obj/item/canvas/proc/try_rename(mob/user)
	var/new_name = input(user,"What do you want to name the painting?","painting","painting") as text
	if(!painting_name && new_name)
		painting_name = new_name

/obj/item/canvas/nineteenXnineteen
	icon_state = "19x19"
	width = 19
	height = 19
	ui_x = 600
	ui_y = 600
	pixel_x = 6
	pixel_y = 9
	framed_offset_x = 8
	framed_offset_y = 9

/obj/item/canvas/twentythreeXnineteen
	icon_state = "23x19"
	width = 23
	height = 19
	ui_x = 800
	ui_y = 600
	pixel_x = 4
	pixel_y = 10
	framed_offset_x = 6
	framed_offset_y = 8

/obj/item/canvas/twentythreeXtwentythree
	icon_state = "23x23"
	width = 23
	height = 23
	ui_x = 800
	ui_y = 800
	pixel_x = 5
	pixel_y = 9
	framed_offset_x = 5
	framed_offset_y = 6

/obj/item/wallframe/painting
	name = "painting frame"
	desc = "The perfect showcase for your favorite deathtrap memories."
	icon = 'icons/obj/decals.dmi'
	icon_state = "frame-empty"
	var/result_path = /obj/structure/sign/painting

/obj/structure/sign/painting
	name = "Painting"
	desc = "Art or \"Art\"? You decide."
	icon = 'icons/obj/decals.dmi'
	icon_state = "frame-empty"
	var/obj/item/canvas/C

/obj/structure/sign/painting/attackby(obj/item/I, mob/user, params)
	if(!C && istype(I, /obj/item/canvas))
		frame_canvas(user,I)
	else if(C && !C.painting_name && istype(I,/obj/item/weapon/pen))
		try_rename(user)
	else
		return ..()

/obj/structure/sign/painting/examine(mob/user)
	..()
	if(C)
		C.ui_interact(user,state = GLOB.physical_obscured_state)

/obj/structure/sign/painting/attackby(obj/item/I, mob/living/user)
	..()
	if(C)
		C.forceMove(user.loc)
		C = null
		to_chat(user, "<span class='notice'>You remove the painting from the frame.</span>")
		update_icon()
		return TRUE

/obj/structure/sign/painting/proc/frame_canvas(mob/user,obj/item/canvas/new_canvas)
	new_canvas.forceMove(src)
	C = new_canvas
	if(!C.finalized)
		C.finalize(user)
	to_chat(user,"<span class='notice'>You frame [C].</span>")
	update_icon()

/obj/structure/sign/painting/proc/try_rename(mob/user)
	if(!C.painting_name)
		C.try_rename(user)

/obj/structure/sign/painting/update_icon()
	. = ..()
	if(C && C.generated_icon)
		icon_state = null
	else
		icon_state = "frame-empty"
	if(C && C.generated_icon)
		var/mutable_appearance/MA = mutable_appearance(C.generated_icon)
		MA.pixel_x = C.framed_offset_x
		MA.pixel_y = C.framed_offset_y
		. += MA
		var/mutable_appearance/frame = mutable_appearance(C.icon,"[C.icon_state]frame")
		frame.pixel_x = C.framed_offset_x - 1
		frame.pixel_y = C.framed_offset_y - 1
		. += frame
