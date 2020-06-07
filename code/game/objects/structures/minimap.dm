/obj/structure/sign/map
	desc = "A detailed area map for planning operations."
	name = "area map"
	icon_state = "areamap"
	var/image/img
	var/list/overlay_list = list()
/obj/structure/sign/map/New()
	..()
	img = image(icon = 'icons/minimaps.dmi', icon_state = "minimap")

/obj/structure/sign/map/examine(mob/user)
	user << browse(getFlatIcon(img),"window=popup;size=630x630")

/obj/structure/sign/map/attackby(obj/item/I as obj, mob/user as mob)
	if (istype(I, /obj/item/weapon/pen))
		var/nr = ""
		var/ico_dir = 2
		var/c_color = WWinput(user,"Which color do you want to use?","Color","Cancel",list("Cancel","White","Red","Green","Yellow","Blue"))
		switch(c_color)
			if ("Cancel")
				return
			if ("White")
				c_color = COLOR_WHITE
			if ("Red")
				c_color = COLOR_RED
			if ("Green")
				c_color = COLOR_GREEN
			if ("Yellow")
				c_color = COLOR_YELLOW
			if ("Blue")
				c_color = COLOR_BLUE
		var/c_icon = WWinput(user,"Which icon do you want to use?","Icon","Cancel",list("Cancel","Circle","X","Arrow","Number"))
		switch(c_icon)
			if ("Cancel")
				return
			if ("Circle")
				c_icon = "map_circle"
			if ("X")
				c_icon = "map_x"
			if ("Arrow")
				c_icon = "map_arrow"
				ico_dir = WWinput(user,"Choose a direction:","Number","Cancel",list("Cancel","North","South","East","West","Northeast","Northwest","Southeast","Southwest"))
				if (ico_dir == "Cancel")
					return
				else
					ico_dir = text2dir(ico_dir)
			if ("Number")
				nr = WWinput(user,"Choose a number:","Number","Cancel",list("Cancel","1","2","3","4","5","6","7","8","9"))
				if (nr == "Cancel")
					return
				else
					c_icon = "map_number_[nr]"
		var/x_dist = 0
		var/y_dist = 0
		var/c_location = WWinput(user,"Where do you want to place it (column)?","Location","Cancel",list("Cancel","A","B","C","D","E","F","G","H","I","J"))
		var/c_location2 = WWinput(user,"Where do you want to place it (line)?","Location","Cancel",list("Cancel","1","2","3","4","5","6","7","8","9","10"))
		y_dist = 600-(text2num(c_location2)*60)
		switch(c_location)
			if ("A")
				x_dist = 0
			if ("B")
				x_dist = 60*1
			if ("C")
				x_dist = 60*2
			if ("D")
				x_dist = 60*3
			if ("E")
				x_dist = 60*4
			if ("F")
				x_dist = 60*5
			if ("G")
				x_dist = 60*6
			if ("H")
				x_dist = 60*7
			if ("I")
				x_dist = 60*8
			if ("J")
				x_dist = 60*9
		var/image/symbol_ico = image(icon='icons/minimap_effects.dmi', icon_state = c_icon, dir=ico_dir, layer=src.layer+1)
		symbol_ico.pixel_x = x_dist
		symbol_ico.pixel_y = y_dist
		symbol_ico.color = c_color
		overlay_list+=symbol_ico
		img.overlays += symbol_ico
		return
	else
		..()

/obj/structure/sign/map/verb/clear()
	set name = "Clear"
	set category = null
	set src in oview(1)

	if (!ishuman(usr))
		return
	usr << "You clear the map."
	overlay_list = list()
	img.overlays.Cut()

/obj/structure/sign/map/update_icon()
	..()
	img.overlays.Cut()
	for (var/image/I in overlay_list)
		img.overlays += I

/obj/structure/sign/map/attack_hand(mob/user)
	examine(user)
//////////////////////////////////////////
/obj/item/weapon/map
	desc = "A portable map of the area."
	name = "folding map"
	icon = 'icons/obj/decals.dmi'
	icon_state = "portable_areamap"
	var/image/img
	var/image/playerloc
	throwforce = WEAPON_FORCE_HARMLESS
	force = WEAPON_FORCE_HARMLESS
	w_class = 1.0

/obj/item/weapon/map/New()
	img = image(icon = 'icons/minimaps.dmi', icon_state = "minimap")
	playerloc = image(icon = 'icons/effects/mapeffects.dmi', icon_state = "blinking",layer=src.layer+1)

/obj/item/weapon/map/examine(mob/user)
	update_icon()
	user << browse("<img src=minimap.png></img>","window=popup;size=630x630")

/obj/item/weapon/map/update_icon()
	..()
	img.overlays.Cut()
	playerloc.pixel_x = min(600,ceil(get_turf(src).x*2.72))
	playerloc.pixel_y = min(600,ceil(get_turf(src).y*2.72))
	img.overlays += playerloc

/obj/item/weapon/map/attack_self(mob/user)
	update_icon()
	examine(user)