/obj/item/weapon/flame/candle
	name = "red candle"
	desc = "a small pillar candle."
	icon = 'icons/obj/candle.dmi'
	icon_state = "candle1"
	item_state = "candle1"
	w_class = ITEM_SIZE_TINY
	light_color = "#E09D37"
	var/wax = 1000
	flammable = TRUE

/obj/item/weapon/flame/candle/New()
	wax = rand(900, 1050) //30-40 minutes on average.
	pixel_x = rand(-8, 8)
	pixel_y = rand(-8, 8)
	..()

/obj/item/weapon/flame/candle/on
	New()
		..()
		light()

/obj/item/weapon/flame/candle/update_icon()
	var/i
	if (wax > 800)
		i = TRUE
	else if (wax > 500)
		i = 2
	else i = 3
	icon_state = "candle[i][lit ? "_lit" : ""]"


/obj/item/weapon/flame/candle/attackby(obj/item/weapon/W as obj, mob/user as mob)
	..()
	if (istype(W, /obj/item/weapon/flame/lighter))
		var/obj/item/weapon/flame/lighter/L = W
		if (L.lit)
			light()
	else if (istype(W, /obj/item/weapon/flame/match))
		var/obj/item/weapon/flame/match/M = W
		if (M.lit)
			light()
	else if (istype(W, /obj/item/weapon/flame/candle))
		var/obj/item/weapon/flame/candle/C = W
		if (C.lit)
			light()
	else if (istype(W, /obj/item/flashlight))
		var/obj/item/flashlight/F = W
		if(F.on)
			light()
	update_icon()


/obj/item/weapon/flame/candle/proc/light(var/flavor_text = "<span class='notice'>\The [usr] lights the [name].</span>")
	if (!lit)
		lit = TRUE
		for (var/mob/O in viewers(usr, null))
			O.show_message(flavor_text, TRUE)
		set_light(CANDLE_LUM)
		processing_objects += src


/obj/item/weapon/flame/candle/process()
	if (!lit)
		return
	wax--
	if (!wax)
		new/obj/item/trash/candle(loc)
		if (istype(loc, /mob))
			dropped()
		qdel(src)
	update_icon()

/obj/item/weapon/flame/candle/attack_self(mob/user as mob)
	if (lit)
		lit = FALSE
		update_icon()
		set_light(0)

/obj/item/weapon/flame/candle/lard
	name = "lard candle"
	desc = "A poorly shaped small pillar candle. A bit stinky and oily."
	icon = 'icons/obj/candle.dmi'
	icon_state = "candle1_lard"
	item_state = "candle1_lard"

/obj/item/weapon/flame/candle/lard/update_icon()
	var/i
	if (wax > 800)
		i = TRUE
	else if (wax > 500)
		i = 2
	else i = 3
	icon_state = "candle[i][lit ? "_lit" : ""]_lard"

/obj/item/weapon/flame/candle/lard/process()
	if (!lit)
		return
	wax--
	if (!wax)
		new/obj/item/trash/candle/lard(loc)
		if (istype(loc, /mob))
			dropped()
		qdel(src)
	update_icon()

/obj/item/weapon/flame/candle/lard/on
	New()
		..()
		light()