////////////////////////FRAMES//////////////////////
/obj/structure/vehicleparts/frame
	name = "steel frame"
	desc = "a steel vehicle frame."
	icon = 'icons/obj/vehicleparts.dmi'
	icon_state = "frame_steel"
	powerneeded = 0
	flammable = FALSE
	layer = 2.98
	var/resistance = 150
	var/obj/structure/vehicleparts/axis/axis = null
	//format: type of wall, opacity, density, armor, current health, can open/close, is open?
	var/list/w_front = list("",FALSE,FALSE,0,40,FALSE,FALSE)
	var/list/w_back = list("",FALSE,FALSE,0,40,FALSE,FALSE)
	var/list/w_left = list("",FALSE,FALSE,0,40,FALSE,FALSE)
	var/list/w_right = list("",FALSE,FALSE,0,40,FALSE,FALSE)

	var/image/roof
	not_movable = TRUE
	not_disassemblable = TRUE
	var/total_weight = 10

	New()
		..()
		roof = image(icon=icon, loc=src, icon_state="roof_steel", layer=8)
		roof.override = TRUE
		spawn(1)
			update_icon()
	relaymove(var/mob/mob, direction)
		..()
		update_icon()
	Move(newloc, direct)
		..()
		update_icon()

/obj/structure/vehicleparts/frame/MouseDrop(var/obj/structure/vehicleparts/frame/VP)
	if (istype(VP, /obj/structure/vehicleparts/frame) && VP.axis && !axis)
		for(var/obj/structure/vehicleparts/frame/FR in range(1,src))
			if (VP.axis.components.len > 25)
				usr << "<span class='notice'>The vehicle is too big already!</span>"
				return
			if (FR != src && FR.axis == VP.axis)
				playsound(loc, 'sound/effects/lever.ogg',100, TRUE)
				usr << "You connect \the [src] to \the [VP.axis]."
				axis = VP.axis
				var/found = FALSE
				for (var/obj/structure/vehicleparts/frame/F in axis.components)
					if (F == src)
						found = TRUE
				if (!found)
					axis.components += src
				anchored = TRUE
				VP.dir = dir
				return
/obj/structure/vehicleparts/frame/MouseDrop_T(var/obj/structure/VP, var/mob/living/user)
	if (istype(VP, /obj/structure/engine/internal) && axis && !axis.engine && !VP.anchored)
		playsound(loc, 'sound/effects/lever.ogg',100, TRUE)
		usr << "You connect \the [VP] to \the [axis]."
		axis.engine = VP
		VP.forceMove(loc)
		VP.anchored = TRUE
		return
	else if (istype(VP, /obj/structure/bed/chair/drivers) && axis && !VP.anchored && !axis.wheel)
		playsound(loc, 'sound/effects/lever.ogg',100, TRUE)
		usr << "You place \the [VP] in \the [axis]."
		VP.forceMove(loc)
		VP.anchored = TRUE
		VP.dir = dir
		var/obj/structure/bed/chair/drivers/VPP = VP
		axis.wheel = VPP.wheel
		axis.wheel.control = src
		return

/obj/structure/vehicleparts/frame/wood
	name = "wood frame"
	desc = "a wood vehicle frame."
	icon_state = "frame_wood"
	flammable = TRUE
	resistance = 90

/obj/structure/vehicleparts/frame/update_icon()
	..()
	overlays.Cut()
	var/turf/T = get_turf(src)
	for(var/obj/structure/cannon/C in T)
		for (var/obj/structure/vehicleparts/frame/F in get_turf(locate(x-1,y-1,z)))
			roof = image(icon='icons/obj/vehicles96x96.dmi',loc=F, icon_state="tank_turret_g", layer=11, dir=C.dir)
	var/comp = ""
	switch (dir)
		if (NORTH)
			if (w_left[1] != "")
				var/image/tmpimg3 = image(icon=icon, icon_state="[w_left[1]]_g", layer=10, dir=WEST)
				overlays += tmpimg3
				comp = "[comp]l"
				roof.overlays += tmpimg3
			if (w_right[1] != "")
				var/image/tmpimg4 = image(icon=icon, icon_state="[w_right[1]]_g", layer=10, dir=EAST)
				overlays += tmpimg4
				comp = "[comp]r"
				roof.overlays += tmpimg4
			if (w_front[1] != "")
				var/image/tmpimg1 = image(icon=icon, icon_state="[w_front[1]]_g", layer=10, dir=NORTH)
				overlays += tmpimg1
				comp = "[comp]f"
				roof.overlays += tmpimg1
			if (w_back[1] != "")
				var/image/tmpimg2 = image(icon=icon, icon_state="[w_back[1]]_g", layer=10, dir=SOUTH)
				overlays += tmpimg2
				comp = "[comp]b"
				roof.overlays += tmpimg2
		if (SOUTH)
			if (w_left[1] != "")
				var/image/tmpimg3 = image(icon=icon, icon_state="[w_left[1]]_g", layer=10, dir=EAST)
				overlays += tmpimg3
				comp = "[comp]l"
				roof.overlays += tmpimg3
			if (w_right[1] != "")
				var/image/tmpimg4 = image(icon=icon, icon_state="[w_right[1]]_g", layer=10, dir=WEST)
				overlays += tmpimg4
				comp = "[comp]r"
				roof.overlays += tmpimg4
			if (w_front[1] != "")
				var/image/tmpimg1 = image(icon=icon, icon_state="[w_front[1]]_g", layer=10, dir=SOUTH)
				overlays += tmpimg1
				comp = "[comp]f"
				roof.overlays += tmpimg1
			if (w_back[1] != "")
				var/image/tmpimg2 = image(icon=icon, icon_state="[w_back[1]]_g", layer=10, dir=NORTH)
				overlays += tmpimg2
				comp = "[comp]b"
				roof.overlays += tmpimg2
		if (EAST)
			if (w_left[1] != "")
				var/image/tmpimg3 = image(icon=icon, icon_state="[w_left[1]]_g", layer=10, dir=NORTH)
				overlays += tmpimg3
				comp = "[comp]l"
				roof.overlays += tmpimg3
			if (w_right[1] != "")
				var/image/tmpimg4 = image(icon=icon, icon_state="[w_right[1]]_g", layer=10, dir=SOUTH)
				overlays += tmpimg4
				comp = "[comp]r"
				roof.overlays += tmpimg4
			if (w_front[1] != "")
				var/image/tmpimg1 = image(icon=icon, icon_state="[w_front[1]]_g", layer=10, dir=EAST)
				overlays += tmpimg1
				comp = "[comp]f"
				roof.overlays += tmpimg1
			if (w_back[1] != "")
				var/image/tmpimg2 = image(icon=icon, icon_state="[w_back[1]]_g", layer=10, dir=WEST)
				overlays += tmpimg2
				comp = "[comp]b"
				roof.overlays += tmpimg2
		if (WEST)
			if (w_left[1] != "")
				var/image/tmpimg3 = image(icon=icon, icon_state="[w_left[1]]_g", layer=10, dir=SOUTH)
				overlays += tmpimg3
				comp = "[comp]l"
				roof.overlays += tmpimg3
			if (w_right[1] != "")
				var/image/tmpimg4 = image(icon=icon, icon_state="[w_right[1]]_g", layer=10, dir=NORTH)
				overlays += tmpimg4
				comp = "[comp]r"
				roof.overlays += tmpimg4
			if (w_front[1] != "")
				var/image/tmpimg1 = image(icon=icon, icon_state="[w_front[1]]_g", layer=10, dir=WEST)
				overlays += tmpimg1
				comp = "[comp]f"
				roof.overlays += tmpimg1
			if (w_back[1] != "")
				var/image/tmpimg2 = image(icon=icon, icon_state="[w_back[1]]_g", layer=10, dir=EAST)
				overlays += tmpimg2
				comp = "[comp]b"
				roof.overlays += tmpimg2

/obj/structure/vehicleparts/frame/lwall
	w_left = list("c_wall",TRUE,TRUE,20,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/rwall
	w_right = list("c_wall",TRUE,TRUE,20,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/fwall
	w_front = list("c_wall",TRUE,TRUE,20,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/bwall
	w_back = list("c_wall",TRUE,TRUE,20,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/lwall/armored
	w_left = list("c_armoredwall",TRUE,TRUE,55,90,FALSE,FALSE)
/obj/structure/vehicleparts/frame/rwall/armored
	w_right = list("c_armoredwall",TRUE,TRUE,55,90,FALSE,FALSE)
/obj/structure/vehicleparts/frame/fwall/armored
	w_front = list("c_armoredwall",TRUE,TRUE,55,90,FALSE,FALSE)
/obj/structure/vehicleparts/frame/bwall/armored
	w_back = list("c_armoredwall",TRUE,TRUE,55,90,FALSE,FALSE)
/obj/structure/vehicleparts/frame/rb
	w_right = list("c_wall",TRUE,TRUE,20,50,FALSE,FALSE)
	w_back = list("c_wall",TRUE,TRUE,20,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/lb
	w_left = list("c_wall",TRUE,TRUE,20,50,FALSE,FALSE)
	w_back = list("c_wall",TRUE,TRUE,20,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/rf
	w_right = list("c_wall",TRUE,TRUE,20,50,FALSE,FALSE)
	w_front = list("c_wall",FALSE,TRUE,6,35,FALSE,FALSE)
/obj/structure/vehicleparts/frame/lf
	w_left = list("c_wall",TRUE,TRUE,20,50,FALSE,FALSE)
	w_front = list("c_wall",FALSE,TRUE,6,35,FALSE,FALSE)
/obj/structure/vehicleparts/frame/rb/armored
	w_right = list("c_armoredwall",TRUE,TRUE,55,90,FALSE,FALSE)
	w_back = list("c_armoredwall",TRUE,TRUE,55,90,FALSE,FALSE)
/obj/structure/vehicleparts/frame/lb/armored
	w_left = list("c_armoredwall",TRUE,TRUE,55,90,FALSE,FALSE)
	w_back = list("c_armoredwall",TRUE,TRUE,55,90,FALSE,FALSE)
/obj/structure/vehicleparts/frame/rf/armored
	w_right = list("c_armoredwall",TRUE,TRUE,55,90,FALSE,FALSE)
	w_front = list("c_armoredfront",TRUE,TRUE,55,90,FALSE,FALSE)
/obj/structure/vehicleparts/frame/lf/armored
	w_left = list("c_armoredwall",TRUE,TRUE,55,90,FALSE,FALSE)
	w_front = list("c_armoredfront",TRUE,TRUE,55,90,FALSE,FALSE)

/obj/structure/vehicleparts/frame/verb/add_walls()
	set category = null
	set name = "Add walls"
	set src in range(1, usr)

	var/ndir = WWinput(usr, "Which dir to set first?", "Wall Placer", "Cancel", list("North","South","East","West", "Cancel"))
	if (ndir == "Cancel")
		return
	else
		dir = text2dir(ndir)
		var/position = WWinput(usr, "Which position?", "Wall Placer", "Cancel", list("left","right","front","back", "Cancel"))
		if (position == "Cancel")
			return
		else
			position = "w_[position]"
			var/ntype = WWinput(usr, "Which type?", "Wall Placer", "Cancel", list("wall","windshield","window", "armored front", "armoredwall", "door", "windowed door", "Cancel"))
			if (ntype == "Cancel")
				return
			else
				ntype = "c_[type]"
				ntype = replacetext(ntype, " ", "")
				switch(position)
					if ("w_left")
						w_left = vehicle_walls[ntype]
					if ("w_right")
						w_right = vehicle_walls[ntype]
					if ("w_front")
						w_front = vehicle_walls[ntype]
					if ("w_back")
						w_back = vehicle_walls[ntype]
	update_icon()
//types of walls/borders
//format: type of wall, opacity, density, armor, current health, can open/close, is open?
var/global/list/vehicle_walls = list( \
	"c_wall" = list("c_window",FALSE,TRUE,20,50,FALSE,FALSE), \
	"c_window" = list("c_wall",TRUE,TRUE,10,40,FALSE,FALSE), \
	"c_windshield" = list("c_windshield",FALSE,TRUE,6,35,FALSE,FALSE), \
	"c_armoredfront" = list("c_armoredfront",FALSE,TRUE,45,80,FALSE,FALSE), \
	"c_armoredwall" = list("c_armoredwall",TRUE,TRUE,55,90,FALSE,FALSE), \
	"c_door" = list("c_door",TRUE,TRUE,20,45,TRUE,TRUE), \
	"c_windowdoor" = list("c_windowdoor",FALSE,TRUE,28,60,TRUE,TRUE), \
	 \
)