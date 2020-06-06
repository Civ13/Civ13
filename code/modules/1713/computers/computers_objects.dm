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
/obj/structure/computer/nopower/carsales/attack_hand(mob/living/human/H)
	WWalert(H,"You need to use money on it.","CARTRADER terminal")
	return
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
	density = TRUE
	operatingsystem = "unga OS 94 Police Edition"

//////////////////////////////////////////
