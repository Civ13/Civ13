/obj/structure/vehicleparts/frame/ship/attackby(var/obj/item/I, var/mob/living/carbon/human/H)
	if (!I || !H)
		return
	if (istype (I, /obj/item/stack/material/wood))
		var/obj/item/stack/material/wood/S = I
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
			choice2 = input(H, "How thick should the armor be? 1 wood = 10mm. 0 to 200mm.") as num
			if (!isnum(choice2))
				return
			else if (choice2 <= 0)
				return
			else if (choice2 > 200)
				return
			else if (choice2/10 > S.amount)
				H << "<span class='warning'>Not enough wood!</span>"
				return

		var/choice3 = WWinput(H, "Which type of wall?", "Wall Creation", "Cancel", list("Cancel","wall","crenelated wall","open window"))
		if (choice3 == "Cancel")
			return

		if (choice1 == "left")
			S.amount -= choice2/10
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