/obj/structure/sign/map
	desc = "A detailed area map for planning operations."
	name = "area map"
	icon_state = "areamap"
	var/image/img
/obj/structure/sign/map/New()
	..()
	img = image(icon = 'icons/minimaps.dmi', icon_state = "minimap")

/obj/structure/sign/map/examine(mob/user)
	user << browse(img,"window=popup;size=620x620")

/obj/structure/sign/map/attackby(obj/item/I as obj, mob/user as mob)
	if (!istype(I, /obj/item/weapon/pen))
		return
	var/nr = ""
	var/ico_dir = 1
	var/c_color = WWinput("Which color do you want to use?","Color","Cancel",list("Cancel","White","Red","Green","Yellow","Blue"))
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
	var/c_icon = WWinput("Which icon do you want to use?","Icon","Cancel",list("Cancel","Circle","X","Arrow","Number"))
	switch(c_icon)
		if ("Cancel")
			return
		if ("Circle")
			c_icon = "map_circle"
		if ("X")
			c_icon = "map_x"
		if ("Arrow")
			c_icon = "map_arrow"
			ico_dir = WWinput("Choose a direction:","Number","Cancel",list("Cancel","North","South","East","West","Northeast","Northwest","Southeast","Southwest"))
			if (ico_dir == "Cancel")
				return
			else
				ico_dir = text2dir(ico_dir)
		if ("Number")
			nr = WWinput("Choose a number:","Number","Cancel",list("Cancel","1","2","3","4","5","6","7","8","9"))
			if (nr == "Cancel")
				return
			else
				c_icon = "map_number_[nr]"
	var/x_dist = 0
	var/y_dist = 0
	var/c_location = WWinput("Where do you want to place it (column)?","Location","Cancel",list("Cancel","A","B","C","D","E","F","G","H","I","J"))
	var/c_location2 = WWinput("Where do you want to place it (line)?","Location","Cancel",list("Cancel","1","2","3","4","5","6","7","8","9","10"))
	y_dist = (text2num(c_location2)-60)*60
	switch(c_location)
		if ("A")
			y_dist = 0
		if ("B")
			y_dist = 60*1
		if ("C")
			y_dist = 60*2
		if ("D")
			y_dist = 60*3
		if ("E")
			y_dist = 60*4
		if ("F")
			y_dist = 60*5
		if ("G")
			y_dist = 60*6
		if ("H")
			y_dist = 60*7
		if ("I")
			y_dist = 60*8
		if ("J")
			y_dist = 60*9
	var/image/symbol_ico = image(icon='icons/mob/screen/effects.dmi', icon_state = c_icon, dir=ico_dir)
	symbol_ico.pixel_x = x_dist
	symbol_ico.pixel_y = y_dist
	img.overlays += symbol_ico
	return

/obj/structure/sign/map/verb/clear()
	set name = "Clear"
	set category = null
	set src in oview(1)

	if (!ishuman(usr))
		return
	usr << "You clear the map."
	img.overlays.Cut()
