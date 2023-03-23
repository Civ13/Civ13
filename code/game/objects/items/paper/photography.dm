/*	Photography! Ported from Baystation12 on 28/03/2020
 *	Contains:
 *		Camera
 *		Camera Film
 *		Photos
 *		Photo Albums
 *		And now a (prop) video camera too!
 */

/*******
* film *
*******/
/obj/item/camera_film
	name = "film cartridge"
	icon = 'icons/obj/device.dmi'
	desc = "A camera film cartridge. Insert it into a camera to reload it."
	icon_state = "film"
	item_state = "film"
	w_class = ITEM_SIZE_TINY


/********
* photo *
********/
var/global/photo_count = 0

/obj/item/weapon/photo
	name = "photo"
	icon = 'icons/obj/device.dmi'
	icon_state = "photo"
	item_state = "paper"
	flags = FALSE
	w_class = ITEM_SIZE_TINY
	var/id
	var/icon/img	//Big photo image
	var/scribble	//Scribble on the back.
	var/image/tiny
	var/photo_size = 3

/obj/item/weapon/photo/New()
	id = photo_count++
	pixel_x = rand(-7,7)
	pixel_y = rand(-7,7)

/obj/item/weapon/photo/attack_self(mob/user as mob)
	user.examinate(src)

/obj/item/weapon/photo/update_icon()
	overlays.Cut()
	var/scale = 8/(photo_size*32)
	var/image/small_img = image(img)
	small_img.transform *= scale
	small_img.pixel_x = -32*(photo_size-1)/2 - 3
	small_img.pixel_y = -32*(photo_size-1)/2
	overlays |= small_img

	tiny = image(img)
	tiny.transform *= 0.5*scale
	tiny.underlays += image('icons/obj/bureaucracy.dmi',"photo")
	tiny.pixel_x = -32*(photo_size-1)/2 - 3
	tiny.pixel_y = -32*(photo_size-1)/2 + 3

/obj/item/weapon/photo/attackby(obj/item/weapon/P as obj, mob/user as mob)
	if(istype(P, /obj/item/weapon/pen))
		var/txt = sanitize(input(user, "What would you like to write on the back?", "Photo Writing", null)  as text, 128)
		if(loc == user && user.stat == 0)
			scribble = txt
	..()

/obj/item/weapon/photo/examine(mob/user, distance)
	. = TRUE
	if(!img)
		return
	if(distance <= 1)
		show(user)
		to_chat(user, desc)
	else
		to_chat(user, "<span class='notice'>It is too far away.</span>")

/obj/item/weapon/photo/proc/show(mob/user as mob)
	send_rsc(user, img, "tmp_photo_[id].png")
	var/output = "<html><head><title>[name]</title></head>"
	output += "<body style='overflow:hidden;margin:0;text-align:center'>"
	output += "<img src='tmp_photo_[id].png' width='[64*photo_size]' style='-ms-interpolation-mode:nearest-neighbor' />"
	output += "[scribble ? "<br>Written on the back:<br><i>[scribble]</i>" : ""]"
	output += "</body></html>"
	show_browser(user, output, "window=book;size=[64*photo_size]x[scribble ? 400 : 64*photo_size]")
	onclose(user, "[name]")
	return

/obj/item/weapon/photo/verb/rename()
	set name = "Rename photo"
	set category = null
	set src in usr

	var/n_name = sanitizeSafe(input(usr, "What would you like to label the photo?", "Photo Labelling", null)  as text, MAX_NAME_LEN)
	//loc.loc check is for making possible renaming photos in clipboards
	name = n_name
	if (( (loc == usr || (loc.loc && loc.loc == usr)) && usr.stat == FALSE))
		name = "[(n_name ? text("[n_name]") : "photo")]"
	add_fingerprint(usr)
	return


/**************
* photo album *
**************/
/obj/item/weapon/storage/photo_album
	name = "Photo album"
	icon = 'icons/obj/bureaucracy.dmi'
	icon_state = "album"
	item_state = "briefcase"
	w_class = ITEM_SIZE_SMALL //same as book
	storage_slots = 8 //yes, that's storage_slots. Photos are w_class 1 so this has as many slots equal to the number of photos you could put in a box
	can_hold = list(/obj/item/weapon/photo)
	flags = FALSE
/obj/item/weapon/storage/photo_album/MouseDrop(obj/over_object as obj)

	if((istype(usr, /mob/living/human)))
		var/mob/M = usr
		if(!( istype(over_object, /obj/screen) ))
			return ..()
		playsound(loc, "rustle", 50, 1, -5)
		if((!( M.restrained() ) && !( M.stat ) && M.back == src))
			switch(over_object.name)
				if("r_hand")
					if(M.unEquip(src))
						M.put_in_r_hand(src)
				if("l_hand")
					if(M.unEquip(src))
						M.put_in_l_hand(src)
			add_fingerprint(usr)
			return
		if(over_object == usr && in_range(src, usr) || usr.contents.Find(src))
			if(usr.s_active)
				usr.s_active.close(usr)
			show_to(usr)
			return
	return

/*********
* camera *
*********/
/obj/item/camera
	name = "camera"
	icon = 'icons/obj/device.dmi'
	desc = "A polaroid camera."
	icon_state = "camera_modern"
	item_state = "camera"
	w_class = ITEM_SIZE_SMALL
	flags = CONDUCT
	slot_flags = SLOT_BELT
	var/pictures_max = 10
	var/pictures_left = 0
	var/size = 3
	var/colorset = "color" //sepia, oldgrayscale, grayscale, oldcolor, color

/obj/item/camera/early
	name = "camera"
	desc = "An early wooden camera. Takes sepia photos."
	icon_state = "camera_early"
	colorset = "sepia"
	pictures_max = 1

/obj/item/camera/earlymodern
	name = "camera"
	desc = "An early 20th century camera. Takes black and white photos."
	icon_state = "camera_ww2"
	colorset = "grayscale"
	pictures_max = 5

/obj/item/camera/coldwar
	name = "camera"
	desc = "A late 20th century camera. Takes vintage color photos."
	icon_state = "camera_coldwar"
	colorset = "oldcolor"
	pictures_max = 8

/obj/item/video_camera
	name = "video camera"
	icon = 'icons/obj/device.dmi'
	desc = "A video camera used for broadcasting on news channels."
	icon_state = "video_camera"
	item_state = "video_camera"

/obj/item/camera/verb/change_size()
	set name = "Set Photo Focus"
	set category = null
	var/nsize = input("Photo Size","Pick a size of resulting photo.") as null|anything in list(1,3,5,7)
	if(nsize)
		size = nsize
		to_chat(usr, "<span class='notice'>Camera will now take [size]x[size] photos.</span>")

/obj/item/camera/attack(mob/living/human/M as mob, mob/user as mob)
	return

/obj/item/camera/attackby(obj/item/I as obj, mob/user as mob)
	if(istype(I, /obj/item/camera_film))
		if(pictures_left)
			to_chat(user, "<span class='notice'>[src] still has some film in it!</span>")
			return
		to_chat(user, "<span class='notice'>You insert [I] into [src].</span>")
		qdel(I)
		pictures_left = pictures_max
		return
	..()


/obj/item/camera/proc/get_mobs(turf/the_turf as turf)
	var/mob_detail
	for(var/mob/living/human/A in the_turf)
		if(A.invisibility) continue
		var/holding = null
		if(A.l_hand || A.r_hand)
			if(A.l_hand) holding = "They are holding \a [A.l_hand]"
			if(A.r_hand)
				if(holding)
					holding += " and \a [A.r_hand]"
				else
					holding = "They are holding \a [A.r_hand]"

		if(!mob_detail)
			mob_detail = "You can see [A] on the photo[(A.health / A.maxHealth) < 0.75 ? " - [A] looks hurt":""].[holding ? " [holding]":"."]. "
		else
			mob_detail += "You can also see [A] on the photo[(A.health / A.maxHealth)< 0.75 ? " - [A] looks hurt":""].[holding ? " [holding]":"."]."
	return mob_detail

/obj/item/camera/afterattack(atom/target as mob|obj|turf|area, mob/user as mob, flag)
	if(!pictures_left || ismob(target.loc)) return
	captureimage(target, user, flag)

	playsound(loc, pick('sound/items/polaroid1.ogg', 'sound/items/polaroid2.ogg'), 75, 1, -3)
	visible_message("Click!")
	pictures_left--
	to_chat(user, "<span class='notice'>[pictures_left] photos left.</span>")

	update_icon()

/obj/item/camera/examine(mob/user)
	. = ..()
	to_chat(user, "It has [pictures_left] photo\s left.")

//Proc for capturing check
/mob/living/proc/can_capture_turf(turf/T)
	var/viewer = src
	if(src.client)		//To make shooting through security cameras possible
		viewer = src.client.eye
	var/can_see = (T in view(viewer))
	return can_see

/obj/item/camera/proc/captureimage(atom/target, mob/living/user, flag)
	var/x_c = target.x - (size-1)/2
	var/y_c = target.y + (size-1)/2
	var/z_c	= target.z
	var/mobs = ""
	for(var/i = 1 to size)
		for(var/j = 1 to size)
			var/turf/T = locate(x_c, y_c, z_c)
			if(user.can_capture_turf(T))
				mobs += get_mobs(T)
			x_c++
		y_c--
		x_c = x_c - size

	var/obj/item/weapon/photo/p = createpicture(target, user, mobs, flag)
	printpicture(user, p)

/obj/item/camera/proc/createpicture(atom/target, mob/user, mobs, flag)
	var/x_c = target.x - (size-1)/2
	var/y_c = target.y - (size-1)/2
	var/z_c	= target.z
	var/icon/photoimage = generate_image(x_c, y_c, z_c, size, 1, user, 0)
	switch(colorset)
		if ("sepia")
			photoimage.GrayScale()
			photoimage.ColorTone(rgb(112, 66, 20))
		if ("oldgrayscale")
			photoimage.GrayScale()
			photoimage.ColorTone(rgb(231, 231, 231))
		if ("grayscale")
			photoimage.GrayScale()
//		if ("oldcolor")
//			var/icon/tic = icon('icons/effects/96x96.dmi', "oldphoto")
//			photoimage.Blend(tic, BLEND_MULTIPLY)
//			photoimage = tic
	var/obj/item/weapon/photo/p = new()
	p.img = photoimage
	p.desc = mobs
	p.photo_size = size
	p.update_icon()

	return p

/obj/item/camera/proc/printpicture(mob/user, obj/item/weapon/photo/p)
	if(!user.put_in_inactive_hand(p))
		p.loc = user.loc

/obj/item/weapon/photo/proc/copy(var/copy_id = 0)
	var/obj/item/weapon/photo/p = new/obj/item/weapon/photo()

	p.appearance = appearance

	p.tiny = new
	p.tiny.appearance = tiny.appearance
	p.img = icon(img)

	p.photo_size = photo_size
	p.scribble = scribble

	if(copy_id)
		p.id = id

	return p

/*
generate_image function generates image of specified range and location
arguments tx, ty, tz are target coordinates (requred), range defines render distance to opposite corner (requred)
cap_mode is capturing mode (optional), user is capturing mob (requred only wehen cap_mode = CAPTURE_MODE_REGULAR),
lighting determines lighting capturing (optional), suppress_errors suppreses errors and continues to capture (optional).
*/
proc/generate_image(var/tx as num, var/ty as num, var/tz as num, var/range as num, var/cap_mode = 1, var/mob/living/user, var/lighting = 0, var/suppress_errors = 1)
	var/list/turfstocapture = list()
	//Lines below determine what tiles will be rendered
	for(var/xoff = 0 to range)
		for(var/yoff = 0 to range)
			var/turf/T = locate(tx + xoff,ty + yoff,tz)
			if(T)
				if(cap_mode == 1)
					if(user.can_capture_turf(T))
						turfstocapture.Add(T)
						continue
				else
					turfstocapture.Add(T)
			else
				//Capture includes non-existan turfs
				if(!suppress_errors)
					return
	//Lines below determine what objects will be rendered
	var/list/atoms = list()
	for(var/turf/T in turfstocapture)
		atoms.Add(T)
		for(var/atom/A in T)
			if(istype(A, /atom/movable/lighting_overlay)) //Special case for lighting
				if (lighting && A.icon_state)
					atoms.Add(A)
					continue
			else if(A.invisibility)
				continue
			else
				atoms.Add(A)
	//Lines below actually render all colected data
	atoms = sort_atoms_by_layer(atoms)
	var/icon/cap = icon('icons/effects/96x96.dmi', "")
	cap.Scale(range*32, range*32)
	cap.Blend("#000", ICON_OVERLAY)
	for(var/atom/A in atoms)
		if(A)
			var/icon/img = getFlatIcon(A)
			if(istype(img, /icon))
				if(istype(A, /mob/living) && A:lying)
					img.BecomeLying()
				var/xoff = (A.x - tx) * 32
				var/yoff = (A.y - ty) * 32
				cap.Blend(img, blendMode2iconMode(A.blend_mode),  A.pixel_x + xoff, A.pixel_y + yoff)

	return cap