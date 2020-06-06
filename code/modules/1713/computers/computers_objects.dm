
//////////////////////////////////////////////////////////////
/obj/structure/computer/nopower/aotd
	name = "Desktop Computer"
	desc = "A desktop computer running the latest version of Unga OS. Has a floppy drive."
	powered = TRUE
	powerneeded = FALSE
	anchored = TRUE
	display = "<b>unga OS</b>"
	operatingsystem = "unga OS"
/obj/structure/computer/nopower/aotd/attack_hand(var/mob/living/human/H)
	..()
/obj/structure/computer/nopower/aotd/attackby(var/obj/item/W, var/mob/living/human/H)
	if (istype(W, /obj/item/stack/money))
		return
	else if (istype(W, /obj/item/weapon/disk))
		if (istype(W, /obj/item/weapon/disk/os))
			var/obj/item/weapon/disk/os/OSD = W
			if (OSD.operatingsystem != src.operatingsystem)
				src.operatingsystem = OSD.operatingsystem
				src.boot(OSD.operatingsystem)
				playsound(get_turf(src), 'sound/machines/computer/floppydisk.ogg', 100, TRUE)
			return
		var/obj/item/weapon/disk/D = W
		if (D.faction == H.civilization)
			H << "<span class='notice'>You can't read a disk belonging to your company.</span>"
			return
		else if (H.civilization == "Police")
			H << "<span class='notice'>You do not know how to decrypt this... Should put it in the evidence room instead.</span>"
			return
		else if (D.used)
			H << "<span class='notice'>This disk has already been decrypted and wiped.</span>"
			return
		else
			playsound(get_turf(src), 'sound/machines/computer/floppydisk.ogg', 100, TRUE)
			switch(D.exchange_state)
				if (-1)
					if (D.fake)
						WWalert(H,"This is a fake inactive disk! You lose 100 points.", "Fake Disk")
						map.scores[H.civilization] -= 100
						D.used = TRUE
						qdel(D)
					else
						WWalert(H,"This is a real inactive disk! You gain 100 dollars and 100 points.", "Real Disk")
						map.scores[H.civilization] += 100
						var/obj/item/stack/money/dollar/DLR = new/obj/item/stack/money/dollar(loc)
						DLR.amount = 40
						DLR.update_icon()
						D.used = TRUE
						qdel(D)
				if (0)
					if (D.fake)
						WWalert(H,"This is a fake disk! Since you exchanged it with a fake disk too, both factions lose 400 points.", "Fake Disk")
						map.scores[H.civilization] -= 400
						D.used = TRUE
						qdel(D)

				if (1)
					if (D.fake)
						WWalert(H,"This is a fake disk! Since you exchanged it with a real disk, you gain nothing and the other faction gains 200 dollars and 200 points.", "Fake Disk")
						D.used = TRUE
						qdel(D)
					else
						WWalert(H,"This is a real disk! Since you exchanged it with a fake disk, you gain 200 dollars, 200 points and the other faction gains nothing.", "Real Disk")
						map.scores[H.civilization] += 200
						var/obj/item/stack/money/dollar/DLR = new/obj/item/stack/money/dollar(loc)
						DLR.amount = 40
						DLR.update_icon()
						D.used = TRUE
						qdel(D)
				if (2)
					if (!D.fake)
						WWalert(H,"This is a real disk! Since you exchanged it with a real disk too, both factions gain 400 dollars and 400 points.", "Real Disk")
						map.scores[H.civilization] += 400
						var/obj/item/stack/money/dollar/DLR = new/obj/item/stack/money/dollar(loc)
						DLR.amount = 80
						DLR.update_icon()
						D.used = TRUE
						qdel(D)

//////////////////////////////////////////////////////////////
/obj/structure/computer/nopower/carsales
	name = "CARTRADER Terminal"
	desc = "A computer terminal connected to the CARTRADER network."
	powered = TRUE
	powerneeded = FALSE
	anchored = TRUE
	operatingsystem = "unga 0S"
/obj/structure/computer/nopower/carsales/attackby(var/obj/item/D, var/mob/living/human/H)
	var/found = FALSE
	for(var/turf/T in get_area_turfs(/area/caribbean/supply))
		if (found)
			break
		for (var/obj/structure/ST in T)
			found = TRUE
			break
		for (var/mob/living/human/HT in T)
			found = TRUE
			break
	if (found)
		H << "Clear the arrival area first."
		return
	if (istype(D, /obj/item/stack/money))
		var/choice = WWinput(H, "Which model do you want to purchase?","Car Purchase","Cancel",list("Cancel","Yamasaki M125 motorcycle (160)",,"ASNO Piccolino (400)","ASNO Quattroporte (500)","Yamasaki Kazoku (600)","SMC Wyoming (700)","SMC Falcon (750)","Ubermacht Erstenklasse (800)","Yamasaki Shinobu 5000 (900)"))
		if (choice == "Cancel")
			return
		else
			for(var/turf/T in get_area_turfs(/area/caribbean/supply))
				if (found)
					break
				for (var/obj/structure/ST in T)
					found = TRUE
					break
				for (var/mob/living/human/HT in T)
					found = TRUE
					break
			if (found)
				H << "Clear the arrival area first."
				return
			var/c_cost = splittext(choice,"(")[2]
			c_cost = replacetext(c_cost,"(","")
			c_cost = text2num(c_cost)
			if (choice == "Yamasaki M125 motorcycle (160)")
				if (D.value*D.amount >= c_cost*4)
					D.amount-=c_cost/5
				else
					H << "<span class='warning'>Not enough money!</span>"
					return
				new /obj/structure/vehicle/motorcycle/m125/full(locate(x+4,y-1,z))
				new /obj/item/clothing/head/helmet/motorcycle(locate(x+4,y-1,z))
				return
			else
				var/obj/effects/premadevehicles/PV
				var/chosencolor = WWinput(H,"Which color do you want?","Car Purchase","Black",list("Black","Red","Blue","Green","Yellow","Dark Grey","Light Grey","White"))
				var/basecolor = chosencolor
				switch(chosencolor)
					if ("Black")
						chosencolor = "#181717"
					if ("Light Grey")
						chosencolor = "#919191"
					if ("Dark Grey")
						chosencolor = "#616161"
					if ("White")
						chosencolor = "#FFFFFF"
					if ("Green")
						chosencolor = "#007F00"
					if ("Red")
						chosencolor = "#7F0000"
					if ("Yellow")
						chosencolor = "#b8b537"
					if ("Blue")
						chosencolor = "#00007F"
				for(var/turf/T in get_area_turfs(/area/caribbean/supply))
					if (found)
						break
					for (var/obj/structure/ST in T)
						found = TRUE
						break
					for (var/mob/living/human/HT in T)
						found = TRUE
						break
				if (found)
					H << "Clear the arrival area first."
					return
				if (D.value*D.amount >= c_cost*4)
					D.amount-=c_cost/5
				else
					H << "<span class='warning'>Not enough money!</span>"
					return
				if (choice == "ASNO Quattroporte (500)")
					PV = new /obj/effects/premadevehicles/asno/quattroporte(locate(x+3,y-3,z))
					spawn(5)
						map.vehicle_registations += list(list("[PV.reg_number]",H.civilization, "ASNO Quattroporte", basecolor))

				else if (choice == "ASNO Piccolino (400)")
					PV = new /obj/effects/premadevehicles/asno/piccolino(locate(x+3,y-3,z))
					spawn(5)
						map.vehicle_registations += list(list("[PV.reg_number]",H.civilization, "ASNO Piccolino", basecolor))

				else if (choice == "Ubermacht Erstenklasse (800)")
					PV = new /obj/effects/premadevehicles/ubermacht/erstenklasse(locate(x+3,y-3,z))
					spawn(5)
						map.vehicle_registations += list(list("[PV.reg_number]",H.civilization, "Ubermacht Erstenklasse", basecolor))

				else if (choice == "SMC Falcon (750)")
					PV = new /obj/effects/premadevehicles/smc/falcon(locate(x+3,y-3,z))
					spawn(5)
						map.vehicle_registations += list(list("[PV.reg_number]",H.civilization, "SMC Falcon", basecolor))

				else if (choice == "Yamasaki Kazoku (600)")
					PV = new /obj/effects/premadevehicles/yamasaki/kazoku(locate(x+3,y-3,z))
					spawn(5)
						map.vehicle_registations += list(list("[PV.reg_number]",H.civilization, "Yamasaki Kazoku", basecolor))

				else if (choice == "Yamasaki Shinobu 5000 (900)")
					PV = new /obj/effects/premadevehicles/yamasaki/shinobu(locate(x+3,y-3,z))
					spawn(5)
						map.vehicle_registations += list(list("[PV.reg_number]",H.civilization, "Yamasaki Shinobu 5000", basecolor))
				else if  (choice == "SMC Wyoming (700)")
					PV = new /obj/effects/premadevehicles/smc/wyoming(locate(x+3,y-3,z))
					spawn(5)
						map.vehicle_registations += list(list("[PV.reg_number]",H.civilization, "SMC Wyoming", basecolor))

				PV.custom_color = chosencolor
				PV.doorcode = rand(1000,9999)
				PV.new_number()
				var/obj/item/weapon/key/civ/C = new /obj/item/weapon/key/civ(loc)
				C.name = "[PV.reg_number] key"
				C.icon_state = "modern"
				C.code = PV.doorcode
				var/obj/item/weapon/key/civ/C2 = new /obj/item/weapon/key/civ(loc)
				C2.name = "[PV.reg_number] key"
				C2.icon_state = "modern"
				C2.code = PV.doorcode
	else
		..()

//////////////////////////////////////////////////////////////
/obj/structure/computer/nopower/police
	name = "Police Processing Terminal"
	desc = "A computer running unga OS 94 Police Edition, with access to both civilians and Police."
	icon_state = "research_on"
	powered = TRUE
	powerneeded = FALSE
	anchored = TRUE
	operatingsystem = "unga OS 94 Police Edition"
	var/list/pending_warrants = list()

/obj/structure/computer/nopower/police/attack_hand(var/mob/living/human/H)
	if (!ishuman(H))
		return
	var/what = WWinput(H, "Welcome to the Police Processing Terminal. What do you want to do?", "P.P.T.", "Quit",list("Quit","Check Warrants", "Print Warrant", "Register Suspect"))
	switch(what)
		if ("Quit")
			return
		if ("Check Warrants")
			var/list/tlist = list()
			for(var/obj/item/weapon/paper/police/warrant/SW in pending_warrants)
				tlist += "[SW.arn]: [SW.tgt], working for [SW.tgtcmp]"
			tlist += "Quit"
			var/choice = WWinput(H, "Current Warrants:","P.P.T.","Quit",tlist)
			if (choice)
				return
		if ("Print Warrant")
			var/list/tlist = list()
			for(var/obj/item/weapon/paper/police/warrant/SW in pending_warrants)
				tlist += "[SW.arn]: [SW.tgt], working for [SW.tgtcmp]"
			tlist += "Quit"
			var/choice = WWinput(H, "Choose a Warrant to print:","P.P.T.","Quit",tlist)
			if (choice == "Quit")
				return
			else
				choice = splittext(choice,":")[1]
				for(var/obj/item/weapon/paper/police/warrant/SW in pending_warrants)
					if (SW.arn == text2num(choice))
						var/obj/item/weapon/paper/police/warrant/NW = new/obj/item/weapon/paper/police/warrant(loc)
						NW.tgt_mob = SW.tgt_mob
						NW.tgt = SW.tgt
						NW.tgtcmp = SW.tgtcmp
						NW.arn = SW.arn
						return
		if ("Register Suspect")
			var/done = FALSE
			var/found = FALSE
			for (var/mob/living/human/S in range(2,src))
				found = TRUE
				for(var/obj/item/weapon/paper/police/warrant/SW in pending_warrants)
					if (SW.tgt_mob == S)
						map.scores["Police"] += 300
						done = TRUE
						pending_warrants -= SW
						visible_message("<big><font color='green'>Processed warrant no. [SW.arn] for [SW.tgt].</font></big>")
						pending_warrants -= SW
						SW.forceMove(null)
						qdel(SW)
			if (!done && found)
				visible_message("<big><font color='yellow'>There are no outstanding warrants for any of the suspects.</font></big>")
			else if (!done && !found)
				visible_message("<big><font color='yellow'>There are no suspects present.</font></big>")
			else if (done && found)
				visible_message("<big><font color='green'><b>All suspects in the bench have been sucessfully registed into the system and can be released now.</b></font></big>")


//////////////////////////////////////////////////////////////
/obj/structure/computer/nopower/police_registry
	name = "Police Registration Terminal"
	desc = "A terminal that processes gun and car licences."
	icon_state = "1980_computer_on"
	operatingsystem = "unga OS 94 Police Edition"
	powered = TRUE
	powerneeded = FALSE
	anchored = TRUE

/obj/structure/computer/nopower/police_registry/attackby(var/obj/item/D, var/mob/living/human/H)
	if (H.civilization == "Police" || H.civilization == "Paramedics")
		H << "You cannot use this, it is a civilian terminal."
		return
	if (istype(D, /obj/item/stack/money))
		var/choice = WWinput(H, "Welcome to the Police Registration Terminal. What do you want to do?", "P.R.T.", "Quit", list("Quit","Request Gun Licence"))
		switch(choice)
			if ("Quit")
				return
			if ("Request Gun Licence")
				if (H.gun_permit)
					H << "<font color='yellow'>You are already licenced.</span>"
					return
				else if  (H.real_name in map.warrants)
					H << "<font color='red'>You have, or had, a warrant in your name, so your request was <b>denied</b>.</font>"
					return
				else
					var/obj/item/stack/money/M = D
					if (M.value*M.amount >= 100*4)
						M.amount-=100/5
					else
						H << "<font color='red'>Not enough money!</font>"
						return
					H.gun_permit = TRUE
					H << "<font color='green'>Your licence was <b>approved</b>.</span>"
					map.scores["Police"] += 100
	else
		..()
/obj/structure/computer/nopower/police_registry/attack_hand(var/mob/living/human/H)
	if (H.civilization == "Police" || H.civilization == "Paramedics")
		H << "You cannot use this, it is a civilian terminal."
		return
	var/choice = WWinput(H, "Welcome to the Police Registration Terminal. What do you want to do?", "P.R.T.", "Quit", list("Quit","Citizens Arrest"))
	switch(choice)
		if ("Quit")
			return
		if ("Citizens Arrest")
			var/done = FALSE
			var/found = FALSE
			var/obj/structure/computer/nopower/police/PTER = null
			for(var/obj/structure/computer/nopower/police/PTER2 in world)
				PTER = PTER2
			if (!PTER)
				return
			for (var/mob/living/human/S in range(2,src))
				if (S.civilization != H.civilization && S.handcuffed && S != H)
					found = TRUE
					for(var/obj/item/weapon/paper/police/warrant/SW in PTER.pending_warrants)
						if (SW.tgt_mob == S)
							map.scores["Police"] += 100
							var/obj/item/stack/money/dollar/DLR = new/obj/item/stack/money/dollar(loc)
							DLR.amount = 20
							DLR.update_icon()
							done = TRUE
							visible_message("<big><font color='green'>Processed warrant no. [SW.arn] for [SW.tgt], as a citizens arrest. Thank you for your service.</font></big>")
							PTER.pending_warrants -= SW
							SW.forceMove(null)
							qdel(SW)
							for(var/mob/living/human/HP in player_list)
								if (HP.civilization == "Police")
									HP << "<big><font color='yellow'>A suspect with a pending warrant has been dropped off at the Police station by a citizens arrest.</font></big>"
				if (!done && found)
					visible_message("<big><font color='yellow'>There are no outstanding warrants for any of the suspects.</font></big>")
				else if (!done && !found)
					visible_message("<big><font color='yellow'>There are no suspects present.</font></big>")
				else
					visible_message("<big><font color='yellow'>There are no outstanding warrants for any of the suspects.</font></big>")
				return
