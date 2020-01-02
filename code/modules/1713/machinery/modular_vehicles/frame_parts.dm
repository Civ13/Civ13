
//types of walls/borders
//format: type of wall, opacity, density, armor, current health, can open/close, is open?
var/global/list/vehicle_walls = list( \
	"" = list("",FALSE,FALSE,0,40,FALSE,FALSE), \
	"c_wall" = list("c_window",FALSE,TRUE,20,50,FALSE,FALSE), \
	"c_window" = list("c_wall",TRUE,TRUE,10,40,FALSE,FALSE), \
	"c_windshield" = list("c_windshield",FALSE,TRUE,6,35,FALSE,FALSE), \
	"c_armoredfront" = list("c_armoredfront",FALSE,TRUE,45,80,FALSE,FALSE), \
	"c_armoredwall" = list("c_armoredwall",TRUE,TRUE,55,90,FALSE,FALSE), \
	"c_door" = list("c_door",TRUE,TRUE,20,45,TRUE,TRUE), \
	"c_windowdoor" = list("c_windowdoor",FALSE,TRUE,28,60,TRUE,TRUE), \
	 \
)

/obj/structure/vehicleparts/frame/wood
	name = "wood frame"
	desc = "a wood vehicle frame."
	icon_state = "frame_wood"
	flammable = TRUE
	resistance = 90

/obj/structure/vehicleparts/frame/defaultarmored/lwall
	w_left = list("c_wall",TRUE,TRUE,20,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/defaultarmored/rwall
	w_right = list("c_wall",TRUE,TRUE,20,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/defaultarmored/fwall
	w_front = list("c_wall",TRUE,TRUE,20,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/defaultarmored/bwall
	w_back = list("c_wall",TRUE,TRUE,20,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/defaultarmored/ldoor
	w_left = list("c_door",TRUE,TRUE,20,45,TRUE,TRUE)
/obj/structure/vehicleparts/frame/defaultarmored/rdoor
	w_right = list("c_door",TRUE,TRUE,20,45,TRUE,TRUE)
/obj/structure/vehicleparts/frame/defaultarmored/fdoor
	w_front = list("c_door",TRUE,TRUE,20,45,TRUE,TRUE)
/obj/structure/vehicleparts/frame/defaultarmored/bdoor
	w_back = list("c_door",TRUE,TRUE,20,45,TRUE,TRUE)
/obj/structure/vehicleparts/frame/defaultarmored/lwall/armored
	w_left = list("c_armoredwall",TRUE,TRUE,55,90,FALSE,FALSE)
/obj/structure/vehicleparts/frame/defaultarmored/rwall/armored
	w_right = list("c_armoredwall",TRUE,TRUE,55,90,FALSE,FALSE)
/obj/structure/vehicleparts/frame/defaultarmored/fwall/armored
	w_front = list("c_armoredwall",TRUE,TRUE,55,90,FALSE,FALSE)
/obj/structure/vehicleparts/frame/defaultarmored/bwall/armored
	w_back = list("c_armoredwall",TRUE,TRUE,55,90,FALSE,FALSE)
/obj/structure/vehicleparts/frame/defaultarmored/rb
	w_right = list("c_wall",TRUE,TRUE,20,50,FALSE,FALSE)
	w_back = list("c_wall",TRUE,TRUE,20,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/defaultarmored/lb
	w_left = list("c_wall",TRUE,TRUE,20,50,FALSE,FALSE)
	w_back = list("c_wall",TRUE,TRUE,20,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/defaultarmored/rf
	w_right = list("c_wall",TRUE,TRUE,20,50,FALSE,FALSE)
	w_front = list("c_armoredfront",FALSE,TRUE,20,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/defaultarmored/lf
	w_left = list("c_wall",TRUE,TRUE,20,50,FALSE,FALSE)
	w_front = list("c_armoredfront",FALSE,TRUE,20,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/defaultarmored/rb/armored
	w_right = list("c_armoredwall",TRUE,TRUE,55,90,FALSE,FALSE)
	w_back = list("c_armoredwall",TRUE,TRUE,55,90,FALSE,FALSE)
/obj/structure/vehicleparts/frame/defaultarmored/lb/armored
	w_left = list("c_armoredwall",TRUE,TRUE,55,90,FALSE,FALSE)
	w_back = list("c_armoredwall",TRUE,TRUE,55,90,FALSE,FALSE)
/obj/structure/vehicleparts/frame/defaultarmored/rf/armored
	w_right = list("c_armoredwall",TRUE,TRUE,55,90,FALSE,FALSE)
	w_front = list("c_armoredfront",TRUE,TRUE,55,90,FALSE,FALSE)
/obj/structure/vehicleparts/frame/defaultarmored/lf/armored
	w_left = list("c_armoredwall",TRUE,TRUE,55,90,FALSE,FALSE)
	w_front = list("c_armoredfront",TRUE,TRUE,55,90,FALSE,FALSE)

/obj/structure/vehicleparts/frame/car
/obj/structure/vehicleparts/frame/car/lf/truck
	w_left = list("c_windoweddoor",TRUE,TRUE,0,4,TRUE,TRUE)
	w_front = list("c_windshield",FALSE,TRUE,0,0.1,FALSE,FALSE)
/obj/structure/vehicleparts/frame/car/rf/truck
	w_right = list("c_windoweddoor",TRUE,TRUE,0,4,TRUE,TRUE)
	w_front = list("c_windshield",FALSE,TRUE,0,0.1,FALSE,FALSE)
/obj/structure/vehicleparts/frame/car/front
	w_right = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_left = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_front = list("c_armoredfront",FALSE,TRUE,0,0.1,FALSE,FALSE)
/obj/structure/vehicleparts/frame/car/back
	w_right = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_left = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_back = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)
/obj/structure/vehicleparts/frame/car/left
	name = "wood frame"
	desc = "a wood vehicle frame."
	icon_state = "frame_wood"
	flammable = TRUE
	resistance = 90
	noroof = TRUE
	w_left = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)
/obj/structure/vehicleparts/frame/car/right
	name = "wood frame"
	desc = "a wood vehicle frame."
	icon_state = "frame_wood"
	flammable = TRUE
	resistance = 90
	noroof = TRUE
	w_right = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)
/obj/structure/vehicleparts/frame/car/rb
	w_right = list("c_windoweddoor",TRUE,TRUE,5,0.1,TRUE,TRUE)
	w_back = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)
/obj/structure/vehicleparts/frame/car/lb
	w_left = list("c_windoweddoor",TRUE,TRUE,5,0.1,TRUE,TRUE)
	w_back = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)
/obj/structure/vehicleparts/frame/car/rf
	w_right = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_front = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)
/obj/structure/vehicleparts/frame/car/lf
	w_left = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_front = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)

/obj/structure/vehicleparts/frame/panzervi

/obj/structure/vehicleparts/frame/panzervi/front
	w_front = list("c_armoredwall",FALSE,TRUE,102,130,FALSE,FALSE)
/obj/structure/vehicleparts/frame/panzervi/back
	w_back = list("c_wall",TRUE,TRUE,50,70,FALSE,FALSE)
/obj/structure/vehicleparts/frame/panzervi/left
	w_left = list("c_wall",TRUE,TRUE,70,80,FALSE,FALSE)
/obj/structure/vehicleparts/frame/panzervi/right
	w_right = list("c_wall",TRUE,TRUE,70,80,FALSE,FALSE)
/obj/structure/vehicleparts/frame/panzervi/back/door
	w_back = list("c_door",TRUE,TRUE,45,50,TRUE,TRUE)
	doorcode = 11940
/obj/structure/vehicleparts/frame/panzervi/rb
	w_right = list("c_wall",TRUE,TRUE,70,80,FALSE,FALSE)
	w_back = list("c_wall",TRUE,TRUE,50,70,FALSE,FALSE)
/obj/structure/vehicleparts/frame/panzervi/lb
	w_left = list("c_wall",TRUE,TRUE,70,80,FALSE,FALSE)
	w_back = list("c_wall",TRUE,TRUE,50,70,FALSE,FALSE)
/obj/structure/vehicleparts/frame/panzervi/rf
	w_right = list("c_wall",TRUE,TRUE,70,80,FALSE,FALSE)
	w_front = list("c_armoredfront2",FALSE,TRUE,102,130,FALSE,FALSE)
/obj/structure/vehicleparts/frame/panzervi/lf
	w_left = list("c_wall",TRUE,TRUE,70,80,FALSE,FALSE)
	w_front = list("c_armoredfront2",FALSE,TRUE,102,130,FALSE,FALSE)

/obj/structure/vehicleparts/frame/panzeriv

/obj/structure/vehicleparts/frame/panzeriv/front
	w_front = list("c_wall",TRUE,TRUE,45,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/panzeriv/back
	w_back = list("c_wall",TRUE,TRUE,30,30,FALSE,FALSE)
/obj/structure/vehicleparts/frame/panzeriv/left
	w_left = list("c_wall",TRUE,TRUE,30,40,FALSE,FALSE)
/obj/structure/vehicleparts/frame/panzeriv/right
	w_right = list("c_wall",TRUE,TRUE,30,40,FALSE,FALSE)
/obj/structure/vehicleparts/frame/panzeriv/left/door
	w_left = list("c_door",TRUE,TRUE,26,28,TRUE,TRUE)
	doorcode = 11940
/obj/structure/vehicleparts/frame/panzeriv/right/door
	w_right = list("c_door",TRUE,TRUE,26,28,TRUE,TRUE)
	doorcode = 11940
/obj/structure/vehicleparts/frame/panzeriv/rb
	w_right = list("c_wall",TRUE,TRUE,30,30,FALSE,FALSE)
	w_back = list("c_wall",TRUE,TRUE,30,30,FALSE,FALSE)
/obj/structure/vehicleparts/frame/panzeriv/lb
	w_left = list("c_wall",TRUE,TRUE,30,30,FALSE,FALSE)
	w_back = list("c_wall",TRUE,TRUE,30,30,FALSE,FALSE)
/obj/structure/vehicleparts/frame/panzeriv/rf
	w_right = list("c_wall",TRUE,TRUE,35,50,FALSE,FALSE)
	w_front = list("c_armoredfront",TRUE,TRUE,45,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/panzeriv/lf
	w_left = list("c_wall",TRUE,TRUE,35,50,FALSE,FALSE)
	w_front = list("c_armoredfront",TRUE,TRUE,45,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/t34

/obj/structure/vehicleparts/frame/t34/front
	w_front = list("c_wall",TRUE,TRUE,50,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/t34/back
	w_back = list("c_wall",TRUE,TRUE,40,35,FALSE,FALSE)
/obj/structure/vehicleparts/frame/t34/left
	w_left = list("c_wall",TRUE,TRUE,40,40,FALSE,FALSE)
/obj/structure/vehicleparts/frame/t34/right
	w_right = list("c_wall",TRUE,TRUE,40,40,FALSE,FALSE)
/obj/structure/vehicleparts/frame/t34/left/door
	w_left = list("c_door",TRUE,TRUE,26,28,TRUE,TRUE)
	doorcode = 4975
/obj/structure/vehicleparts/frame/t34/right/door
	w_right = list("c_door",TRUE,TRUE,26,28,TRUE,TRUE)
	doorcode = 4975
/obj/structure/vehicleparts/frame/t34/rb
	w_right = list("c_wall",TRUE,TRUE,40,40,FALSE,FALSE)
	w_back = list("c_wall",TRUE,TRUE,40,35,FALSE,FALSE)
/obj/structure/vehicleparts/frame/t34/lb
	w_left = list("c_wall",TRUE,TRUE,40,40,FALSE,FALSE)
	w_back = list("c_wall",TRUE,TRUE,40,35,FALSE,FALSE)
/obj/structure/vehicleparts/frame/t34/rf
	w_right = list("c_wall",TRUE,TRUE,40,50,FALSE,FALSE)
	w_front = list("c_armoredfront",TRUE,TRUE,50,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/t34/lf
	w_left = list("c_wall",TRUE,TRUE,40,50,FALSE,FALSE)
	w_front = list("c_armoredfront",TRUE,TRUE,50,50,FALSE,FALSE)


/obj/structure/vehicleparts/frame/i_go

/obj/structure/vehicleparts/frame/i_go/front
	w_front = list("c_wall",TRUE,TRUE,17,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/i_go/back
	w_back = list("c_wall",TRUE,TRUE,17,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/i_go/left
	w_left = list("c_wall",TRUE,TRUE,17,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/i_go/right
	w_right = list("c_wall",TRUE,TRUE,17,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/i_go/left/door
	w_left = list("c_door",TRUE,TRUE,17,50,TRUE,TRUE)
	doorcode = 1011
/obj/structure/vehicleparts/frame/i_go/right/door
	w_right = list("c_door",TRUE,TRUE,17,50,TRUE,TRUE)
	doorcode = 1011
/obj/structure/vehicleparts/frame/i_go/rb
	w_right = list("c_wall",TRUE,TRUE,17,50,FALSE,FALSE)
	w_back = list("c_wall",TRUE,TRUE,17,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/i_go/lb
	w_left = list("c_wall",TRUE,TRUE,17,50,FALSE,FALSE)
	w_back = list("c_wall",TRUE,TRUE,17,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/i_go/rf
	w_right = list("c_wall",TRUE,TRUE,17,50,FALSE,FALSE)
	w_front = list("c_armoredfront",TRUE,TRUE,17,50,FALSE,FALSE)
/obj/structure/vehicleparts/frame/i_go/lf
	w_left = list("c_wall",TRUE,TRUE,17,50,FALSE,FALSE)
	w_front = list("c_armoredfront",TRUE,TRUE,17,50,FALSE,FALSE)

/obj/structure/vehicleparts/frame/proc/adding_walls()

/obj/structure/vehicleparts/frame/attackby(var/obj/item/I, var/mob/living/carbon/human/H)
	if (!I || !H)
		return
	if (istype (I, /obj/item/stack/material/steel))
		var/obj/item/stack/material/steel/S = I
		var/list/optlist = list("Cancel")
		if (w_left[1] == "")
			optlist += "left"
		if (w_right[1] == "")
			optlist += "right"
		if (w_front[1] == "")
			optlist += "front"
		if (w_back[1] == "")
			optlist += "back"

		if (optlist.len <= 1)
			return

		var/choice1 = WWinput(H, "Which side to add a wall?", "Wall Creation", "Cancel", optlist)
		var/choice2 = 0
		if (choice1 == "Cancel")
			return
		else
			choice2 = input(H, "How thick should the armor be? 1 steel = 10mm. 0 to 200mm.") as num
			if (!isnum(choice2))
				return
			else if (choice2 <= 0)
				return
			else if (choice2 > 200)
				return
			else if (choice2/10 > S.amount)
				H << "<span class='warning'>Not enough steel!</span>"
				return

		var/choice3 = WWinput(H, "Which type of wall?", "Wall Creation", "Cancel", list("Cancel","wall","door","armoredfront","window","windshield"))
		if (choice3 == "Cancel")
			return

		if (choice1 == "left")
			S.amount -= choice2/10
			if (S.amount <= 0)
				qdel(S)
			if (choice3 == "door")
				w_left = list("c_door",TRUE,TRUE,choice2,choice2,TRUE,TRUE)
			else
				w_left = list("c_[choice3]",TRUE,TRUE,choice2,choice2*1.5,FALSE,FALSE)
		else if (choice1 == "right")
			S.amount -= choice2/10
			if (S.amount <= 0)
				qdel(S)
			if (choice3 == "door")
				w_right = list("c_door",TRUE,TRUE,choice2,choice2,TRUE,TRUE)
			else
				w_right = list("c_[choice3]",TRUE,TRUE,choice2,choice2*1.5,FALSE,FALSE)
		else if (choice1 == "front")
			S.amount -= choice2/10
			if (S.amount <= 0)
				qdel(S)
			if (choice3 == "door")
				w_front = list("c_door",TRUE,TRUE,choice2,choice2,TRUE,TRUE)
			else
				w_front = list("c_[choice3]",TRUE,TRUE,choice2,choice2*1.5,FALSE,FALSE)
		else if (choice1 == "back")
			S.amount -= choice2/10
			if (S.amount <= 0)
				qdel(S)
			if (choice3 == "door")
				w_back = list("c_door",TRUE,TRUE,choice2,choice2,TRUE,TRUE)
			else
				w_back = list("c_[choice3]",TRUE,TRUE,choice2,choice2*1.5,FALSE,FALSE)
		update_icon()
	else
		..()
/*
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

*/