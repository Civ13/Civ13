/obj/covers/roads
	name = "road"
	icon = 'icons/turf/roads.dmi'
	icon_state = "road"
	passable = TRUE
	not_movable = TRUE
	amount = 0
	wood = FALSE
	layer = 1.98
	flammable = FALSE
	explosion_resistance = 10
	material = "Stone"
	var/vertical = FALSE
	buildstack = null
	var/roadtype = "road"

/obj/covers/roads/modern
	name = "modern road"
	icon_state = "tarmac"
	roadtype = "tarmac"

/obj/covers/roads/dirt
	name = "dirt road"
	icon_state = "d_road"
	roadtype = "d_road"

/obj/covers/roads/roman
	name = "roman road"
	icon_state = "r_road"
	roadtype = "r_road"

/obj/covers/roads/cobble
	name = "cobble street"
	icon_state = "street"
	roadtype = "street"

/obj/covers/roads/sandstone
	name = "sandstone road"
	icon_state = "s_stone"
	roadtype = "s_stone"

/obj/covers/roads/update_icon()
	..()
	spawn(1)
		overlays.Cut()
		var/list/sideslist = list()
		for (var/direction in list(NORTH,SOUTH,EAST,WEST))
			for(var/obj/covers/roads/R in get_step(src,direction))
				sideslist += direction
				continue
		for (var/direction in list(NORTHEAST,NORTHWEST,SOUTHEAST,SOUTHWEST))
			var/turf/T = null
			switch(direction)
				if (NORTHEAST)
					T = locate(src.x+1,src.y+1,src.z)
				if (NORTHWEST)
					T = locate(src.x-1,src.y+1,src.z)
				if (SOUTHEAST)
					T = locate(src.x+1,src.y-1,src.z)
				if (SOUTHWEST)
					T = locate(src.x-1,src.y-1,src.z)
			if (T)
				for(var/obj/covers/roads/R in T)
					sideslist += direction
					continue

		if ((NORTHWEST in sideslist) && (NORTH in sideslist) && (WEST in sideslist))
			overlays += image(icon=src.icon, icon_state = "[roadtype]nwc")
		if ((NORTHEAST in sideslist) && (NORTH in sideslist) && (EAST in sideslist))
			overlays += image(icon=src.icon, icon_state = "[roadtype]nec")
		if ((SOUTHEAST in sideslist) && (SOUTH in sideslist) && (EAST in sideslist))
			overlays += image(icon=src.icon, icon_state = "[roadtype]sec")
		if ((SOUTHWEST in sideslist) && (SOUTH in sideslist) && (WEST in sideslist))
			overlays += image(icon=src.icon, icon_state = "[roadtype]swc")

		if ((WEST in sideslist) && (EAST in sideslist) && (NORTH in sideslist) && (SOUTH in sideslist))
			icon_state = "[roadtype]+" //4 sides
			base_icon_state = icon_state
			return

		if (icon_state == "[roadtype]vr")
			if (WEST in sideslist)
				if (!(NORTH in sideslist))
					if (EAST in sideslist)
						icon_state = "[roadtype]tswe" //T, SOUTH EAST WEST
						base_icon_state = icon_state
					else
						icon_state = "[roadtype]sw" //Turn, SOUTH-WEST
						base_icon_state = icon_state
				else if (!(SOUTH in sideslist))
					if (EAST in sideslist)
						icon_state = "[roadtype]tnwe" //T, NORTH EAST WEST
						base_icon_state = icon_state
					else
						icon_state = "[roadtype]nw" //Turn, NORTH-WEST
						base_icon_state = icon_state
				else if ((SOUTH in sideslist) && (NORTH in sideslist))
					icon_state = "[roadtype]tnsw" //T, NORTH SOUTH WEST
					base_icon_state = icon_state
			else if (EAST in sideslist)
				if (!(NORTH in sideslist))
					icon_state = "[roadtype]se" //Turn, SOUTH-EAST
					base_icon_state = icon_state
					return
				else if (!(SOUTH in sideslist))
					icon_state = "[roadtype]ne" //Turn, NORTH-EAST
					base_icon_state = icon_state
				else if ((SOUTH in sideslist) && (NORTH in sideslist))
					icon_state = "[roadtype]tnse" //T, NORTH SOUTH EAST
					base_icon_state = icon_state
		else
			if (NORTH in sideslist)
				if (!(EAST in sideslist))
					icon_state = "[roadtype]nw" //Turn, NORTH-WEST
					base_icon_state = icon_state
				else if (!(WEST in sideslist))
					if (SOUTH in sideslist)
						icon_state = "[roadtype]tnse" //T, NORTH SOUTH EAST
						base_icon_state = icon_state
					else
						icon_state = "[roadtype]ne" //Turn, NORTH-EAST
						base_icon_state = icon_state
				else if ((WEST in sideslist) && (EAST in sideslist))
					icon_state = "[roadtype]tnwe" //T, NORTH EAST WEST
					base_icon_state = icon_state
			else if (SOUTH in sideslist)
				if (!(EAST in sideslist))
					icon_state = "[roadtype]sw" //Turn, SOUTH-WEST
					base_icon_state = icon_state
				else if (!(WEST in sideslist))
					icon_state = "[roadtype]se" //Turn, SOUTH-EAST
					base_icon_state = icon_state
				else if ((WEST in sideslist) && (EAST in sideslist))
					icon_state = "[roadtype]tswe" //T, EAST SOUTH WEST
					base_icon_state = icon_state
		if ((WEST in sideslist) && (NORTH in sideslist) && (SOUTH in sideslist))
			icon_state = "[roadtype]tnsw" //T, NORTH SOUTH WEST
			base_icon_state = icon_state
		if ((WEST in sideslist) && (NORTH in sideslist) && (EAST in sideslist))
			icon_state = "[roadtype]tnwe" //T, NORTH EAST WEST
			base_icon_state = icon_state
		if ((WEST in sideslist) && (EAST in sideslist) && (SOUTH in sideslist))
			icon_state = "[roadtype]tswe" //T, SOUTH EAST WEST
			base_icon_state = icon_state
		if ((EAST in sideslist) && (NORTH in sideslist) && (SOUTH in sideslist))
			icon_state = "[roadtype]tnse" //T, NORTH SOUTH EAST
			base_icon_state = icon_state

/obj/covers/roads/New()
	..()
	spawn(2)
		if (vertical)
			dir = 1
		else
			dir = 4
		for(var/obj/covers/roads/R in range(1,src))
			R.update_icon()
		update_icon()

/* Road Destruction*/

/obj/covers/roads/modern/attackby(obj/O as obj, mob/living/human/user as mob)
	if (istype(O,/obj/item/weapon/material/pickaxe/bone))
		playsound(src, 'sound/effects/pickaxe.ogg', 85, 1)
		user << "<span class='notice'>You begin breaking apart \the [src].</span>"
		if (do_after(user,65,src))
			user << "<span class='notice'>You break apart \the [src].</span>"
			new /obj/item/stack/material/stone(loc)
			qdel(src)
	else if (istype(O,/obj/item/weapon/material/pickaxe))
		playsound(src, 'sound/effects/pickaxe.ogg', 85, 1)
		user << "<span class='notice'>You begin breaking apart \the [src].</span>"
		if (do_after(user,45,src))
			user << "<span class='notice'>You break apart \the [src].</span>"
			new /obj/item/stack/material/stone(loc)
			qdel(src)
	else if (istype(O,/obj/item/weapon/material/pickaxe/jackhammer))
		playsound(src, 'sound/effects/pickaxe.ogg', 85, 1)
		user << "<span class='notice'>You begin breaking apart \the [src].</span>"
		if (do_after(user,25,src))
			user << "<span class='notice'>You break apart \the [src].</span>"
			new /obj/item/stack/material/stone(loc)
			qdel(src)

/obj/covers/roads/dirt/attackby(obj/O as obj, mob/living/human/user as mob)
	if (istype(O, /obj/item/weapon/material/shovel/bone))
		playsound(src, 'sound/effects/shovelling.ogg', 85, 1)
		user << "<span class='notice'>You begin filling over in the earth of \the [src].</span>"
		if (do_after(user,60,src))
			user << "<span class='notice'>You finish filling over \the [src].</span>"
			qdel(src)
	else if (istype(O, /obj/item/weapon/material/shovel))
		playsound(src, 'sound/effects/shovelling.ogg', 85, 1)
		user << "<span class='notice'>You begin filling over in the earth of \the [src].</span>"
		if (do_after(user,30,src))
			user << "<span class='notice'>You finish filling over \the [src].</span>"
			qdel(src)

/obj/covers/roads/roman/attackby(obj/O as obj, mob/living/human/user as mob)
	if (istype(O,/obj/item/weapon/material/pickaxe/bone))
		playsound(src, 'sound/effects/pickaxe.ogg', 85, 1)
		user << "<span class='notice'>You begin breaking apart \the [src].</span>"
		if (do_after(user,65,src))
			user << "<span class='notice'>You break apart \the [src].</span>"
			new /obj/item/stack/material/stone(loc)
			qdel(src)
	else if (istype(O,/obj/item/weapon/material/pickaxe))
		playsound(src, 'sound/effects/pickaxe.ogg', 85, 1)
		user << "<span class='notice'>You begin breaking apart \the [src].</span>"
		if (do_after(user,45,src))
			user << "<span class='notice'>You break apart \the [src].</span>"
			new /obj/item/stack/material/stone(loc)
			qdel(src)
	else if (istype(O,/obj/item/weapon/material/pickaxe/jackhammer))
		playsound(src, 'sound/effects/pickaxe.ogg', 85, 1)
		user << "<span class='notice'>You begin breaking apart \the [src].</span>"
		if (do_after(user,25,src))
			user << "<span class='notice'>You break apart \the [src].</span>"
			new /obj/item/stack/material/stone(loc)
			qdel(src)

/obj/covers/roads/cobble/attackby(obj/O as obj, mob/living/human/user as mob)
	if (istype(O,/obj/item/weapon/material/pickaxe/bone))
		playsound(src, 'sound/effects/pickaxe.ogg', 85, 1)
		user << "<span class='notice'>You begin breaking apart \the [src].</span>"
		if (do_after(user,65,src))
			user << "<span class='notice'>You break apart \the [src].</span>"
			new /obj/item/stack/material/stone(loc)
			qdel(src)
	else if (istype(O,/obj/item/weapon/material/pickaxe))
		playsound(src, 'sound/effects/pickaxe.ogg', 85, 1)
		user << "<span class='notice'>You begin breaking apart \the [src].</span>"
		if (do_after(user,45,src))
			user << "<span class='notice'>You break apart \the [src].</span>"
			new /obj/item/stack/material/stone(loc)
			qdel(src)
	else if (istype(O,/obj/item/weapon/material/pickaxe/jackhammer))
		playsound(src, 'sound/effects/pickaxe.ogg', 85, 1)
		user << "<span class='notice'>You begin breaking apart \the [src].</span>"
		if (do_after(user,25,src))
			user << "<span class='notice'>You break apart \the [src].</span>"
			new /obj/item/stack/material/stone(loc)
			qdel(src)

/obj/covers/roads/sandstone/attackby(obj/O as obj, mob/living/human/user as mob)
	if (istype(O,/obj/item/weapon/material/pickaxe/bone))
		playsound(src, 'sound/effects/pickaxe.ogg', 85, 1)
		user << "<span class='notice'>You begin breaking apart \the [src].</span>"
		if (do_after(user,65,src))
			user << "<span class='notice'>You break apart \the [src].</span>"
			new /obj/item/stack/material/sandstone(loc)
			qdel(src)
	else if (istype(O,/obj/item/weapon/material/pickaxe))
		playsound(src, 'sound/effects/pickaxe.ogg', 85, 1)
		user << "<span class='notice'>You begin breaking apart \the [src].</span>"
		if (do_after(user,45,src))
			user << "<span class='notice'>You break apart \the [src].</span>"
			new /obj/item/stack/material/sandstone(loc)
			qdel(src)
	else if (istype(O,/obj/item/weapon/material/pickaxe/jackhammer))
		playsound(src, 'sound/effects/pickaxe.ogg', 85, 1)
		user << "<span class='notice'>You begin breaking apart \the [src].</span>"
		if (do_after(user,25,src))
			user << "<span class='notice'>You break apart \the [src].</span>"
			new /obj/item/stack/material/sandstone(loc)
			qdel(src)
