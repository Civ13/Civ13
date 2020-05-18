/obj/structure/vehicleparts/frame/ship/attackby(var/obj/item/I, var/mob/living/human/H)
	if (!I || !H)
		return
	if (((istype (I, /obj/item/stack/material/wood) && !istype(src, /obj/structure/vehicleparts/frame/ship/steel)) || (istype (I, /obj/item/stack/material/steel) && istype(src, /obj/structure/vehicleparts/frame/ship/steel))) && !axis)
		var/obj/item/stack/material/S = I
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
			choice2 = input(H, "How thick should the armor be? 1 [S] = 5mm. 0 to 50mm.") as num
			if (!isnum(choice2))
				return
			else if (choice2 <= 0)
				return
			else if (choice2 > 50)
				return
			else if (choice2/5 > S.amount)
				H << "<span class='warning'>Not enough [S]!</span>"
				return

		var/choice3 = WWinput(H, "Which type of wall?", "Wall Creation", "Cancel", list("Cancel","wall","crenelated wall","open window"))
		if (choice3 == "Cancel")
			return

		if (choice1 == "left")
			S.amount -= choice2/5
			if (S.amount <= 0)
				qdel(S)
			if (choice3 == "crenelated wall")
				w_left = list("boat_port2",TRUE,TRUE,choice2,choice2*0.75,FALSE,TRUE)
			else if (choice3 == "open window")
				w_left = list("boat_port1",TRUE,TRUE,choice2,choice2,FALSE,FALSE)
			else
				w_left = list("boat_port0",TRUE,TRUE,choice2,choice2*1.5,FALSE,FALSE)
		else if (choice1 == "right")
			S.amount -= choice2/10
			if (S.amount <= 0)
				qdel(S)
			if (choice3 == "crenelated wall")
				w_right = list("boat_port2",TRUE,TRUE,choice2,choice2*0.75,FALSE,TRUE)
			else if (choice3 == "open window")
				w_right = list("boat_port1",TRUE,TRUE,choice2,choice2,FALSE,FALSE)
			else
				w_right = list("boat_port0",TRUE,TRUE,choice2,choice2*1.5,FALSE,FALSE)
		else if (choice1 == "front")
			S.amount -= choice2/10
			if (S.amount <= 0)
				qdel(S)
			if (choice3 == "crenelated wall")
				w_front = list("boat_port2",TRUE,TRUE,choice2,choice2*0.75,FALSE,TRUE)
			else if (choice3 == "open window")
				w_front = list("boat_port1",TRUE,TRUE,choice2,choice2,FALSE,FALSE)
			else
				w_front = list("boat_port0",TRUE,TRUE,choice2,choice2*1.5,FALSE,FALSE)
		else if (choice1 == "back")
			S.amount -= choice2/10
			if (S.amount <= 0)
				qdel(S)
			if (choice3 == "crenelated wall")
				w_back = list("boat_port2",TRUE,TRUE,choice2,choice2*0.75,FALSE,TRUE)
			else if (choice3 == "open window")
				w_back = list("boat_port1",TRUE,TRUE,choice2,choice2,FALSE,FALSE)
			else
				w_back = list("boat_port0",TRUE,TRUE,choice2,choice2*1.5,FALSE,FALSE)
		update_icon()

	else
		..()

/obj/structure/vehicleparts/frame/ship/lwall
	w_left = list("boat_port2",TRUE,TRUE,20,15,FALSE,TRUE)

/obj/structure/vehicleparts/frame/ship/rwall
	w_right = list("boat_port2",TRUE,TRUE,20,15,FALSE,TRUE)

/obj/structure/vehicleparts/frame/ship/front
	w_front = list("boat_port1",TRUE,TRUE,20,20,FALSE,FALSE)

/obj/structure/vehicleparts/frame/ship/bow
	w_front = list("boat_port0",TRUE,TRUE,20,30,FALSE,FALSE)
	w_left = list("boat_port0",TRUE,TRUE,20,30,FALSE,FALSE)
	w_right = list("boat_port0",TRUE,TRUE,20,30,FALSE,FALSE)

/obj/structure/vehicleparts/frame/ship/stern
	w_back = list("boat_port0",TRUE,TRUE,20,30,FALSE,FALSE)
	w_left = list("boat_port0",TRUE,TRUE,20,30,FALSE,FALSE)
	w_right = list("boat_port0",TRUE,TRUE,20,30,FALSE,FALSE)

/obj/structure/vehicleparts/frame/ship/back
	w_back = list("boat_port0",TRUE,TRUE,20,30,FALSE,FALSE)

/obj/structure/vehicleparts/frame/ship/bl
	w_back = list("boat_port0",TRUE,TRUE,20,30,FALSE,FALSE)
	w_left = list("boat_port0",TRUE,TRUE,20,30,FALSE,FALSE)
/obj/structure/vehicleparts/frame/ship/br
	w_back = list("boat_port0",TRUE,TRUE,20,30,FALSE,FALSE)
	w_right = list("boat_port0",TRUE,TRUE,20,30,FALSE,FALSE)

/obj/structure/vehicleparts/frame/ship/fl
	w_front = list("boat_port0",TRUE,TRUE,20,30,FALSE,FALSE)
	w_left = list("boat_port2",TRUE,TRUE,20,15,FALSE,TRUE)
/obj/structure/vehicleparts/frame/ship/fr
	w_front = list("boat_port0",TRUE,TRUE,20,30,FALSE,FALSE)
	w_right = list("boat_port2",TRUE,TRUE,20,15,FALSE,TRUE)