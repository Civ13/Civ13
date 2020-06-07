//////////////////////////////////////////////////////////////
/obj/structure/computer/nopower/aotd
	name = "Desktop Computer"
	desc = "A desktop computer running the latest version of Unga OS. Has a floppy drive."
	powered = TRUE
	powerneeded = FALSE
	anchored = TRUE
	display = "<b>unga OS</b>"
	operatingsystem = "unga OS 94"

/obj/structure/computer/nopower/aotd/New()
	..()
	programs += new/datum/program/monkeysoftmail
	programs += new/datum/program/deepnet
	programs += new/datum/program/orion_trail

/obj/structure/computer/nopower/aotd/attack_hand(var/mob/living/human/H)
	..()
/obj/structure/computer/nopower/aotd/attackby(var/obj/item/W, var/mob/living/human/H)
	if (istype(W, /obj/item/weapon/disk))
		if (istype(W, /obj/item/weapon/disk/os))
			var/obj/item/weapon/disk/os/OSD = W
			if (OSD.operatingsystem != src.operatingsystem)
				src.operatingsystem = OSD.operatingsystem
				src.programs = list()
				src.boot(OSD.operatingsystem)
				H << "You sucessfully install \the [src.operatingsystem] on this machine."
				playsound(get_turf(src), 'sound/machines/computer/floppydisk.ogg', 100, TRUE)
			else
				H << "You already have this operating system installed."
			return
		else if (istype(W, /obj/item/weapon/disk/program))
			var/obj/item/weapon/disk/program/PD = W	
			if (!(operatingsystem in PD.compatible_os))
				H << "This operating system is not supported."
				return
			if (PD.included)
				var/datum/program/NP = new PD.included
				for(var/datum/program/EP in programs)
					if (istype(EP,NP))
						H << "This program is already installed on this machine."
						return
				programs += NP
				playsound(get_turf(src), 'sound/machines/computer/floppydisk.ogg', 100, TRUE)
				H << "You load \the [NP.name] into this machine."
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
	operatingsystem = "unga OS 94"
	New()
		..()
		programs += new/datum/program/cartrader

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
	New()
		..()
		programs += new/datum/program/permits
		programs += new/datum/program/warrants
		programs += new/datum/program/squadtracker
		programs += new/datum/program/licenseplates
//////////////////////////////////////////
/////////DISKS///////////////////////////

/obj/item/weapon/disk
	name = "diskette"
	desc = "Some kind of diskette."
	icon = 'icons/obj/bureaucracy.dmi'
	icon_state = "disk_red"
	item_state = "disk_red"
	flammable = FALSE
	density = FALSE
	opacity = FALSE
	force = 4.0
	throwforce = 3.0
	attack_verb = list("bashed", "bludgeoned", "whacked")
	sharp = FALSE
	edge = FALSE
	w_class = 1.0

	var/fake = FALSE
	var/used = FALSE
	var/faction = null
	var/exchange_state = -1 //0-both fake, 1-one is real, 2-both real
	var/datum/program/program
/obj/item/weapon/disk/examine(mob/user)
	..()
	if (faction)
		if (used)
			user << "<font color='yellow'><i><b>The disk was already decrypted and wiped</b></i></font>."
		if (exchange_state == -1)
			user << "The disk is <b><font color='red'>inactive</font></b>."
		else
			user << "The disk is <b><font color='green'>active</font></b>."
		if (ishuman(user))
			var/mob/living/human/H = user
			if (H.civilization == faction)
				H << "This is a <b>[fake ? "<font color ='red'>fake</font>" : "<font color ='green'>real</font>"]</b> disk."
		else if (isghost(user))
			user << "This is a <b>[fake ? "<font color ='red'>fake</font>" : "<font color ='green'>real</font>"]</b> disk."

/obj/item/weapon/disk/attackby(var/obj/item/weapon/disk/D, var/mob/living/human/H)
	if (istype(D, /obj/item/weapon/disk))
		H.setClickCooldown(20)
		if (src.faction == D.faction)
			H << "These disks are of the same faction, you need another faction's disk to activate them."
			return
		else if (src.used)
			H << "\The [src] has already been used and wiped."
			return
		else if (D.used)
			H << "\The [src] has already been used and wiped."
			return
		else if (src.exchange_state != -1 && D.exchange_state != -1)
			visible_message("<big><font color='red'>Both disks are already active.</font></big>")
			return
		else if (src.exchange_state != -1)
			visible_message("<big><font color='yellow'>\The [src] has already been activated.</font></big>")
			return
		else if (D.exchange_state != -1)
			visible_message("<big><font color='yellow'>\The [D] has already been activated.</font></big>")
			return

		if (D.fake && src.fake) //both fake
			D.exchange_state = 0
			src.exchange_state = 0
			visible_message("<big><font color='green'>Both disks get activated, completing the transaction.</font></big>")
			return
		else if ((D.fake && !src.fake) || (!D.fake && src.fake)) //one is fake
			D.exchange_state = 1
			src.exchange_state = 1
			visible_message("<big><font color='green'>Both disks get activated, completing the transaction.</font></big>")
			return
		else if (!D.fake && !src.fake) //both real
			D.exchange_state = 2
			src.exchange_state = 2
			visible_message("<big><font color='green'>Both disks get activated, completing the transaction.</font></big>")
			return
	else
		..()
/obj/item/weapon/disk/red
	name = "red diskette"
	icon_state = "disk_red"
	item_state = "disk_red"
	faction = "Rednikov Industries"

/obj/item/weapon/disk/red/fake
	name = "red diskette"
	faction = "Rednikov Industries"
	fake = TRUE

/obj/item/weapon/disk/blue
	name = "blue diskette"
	icon_state = "disk_blue"
	item_state = "disk_blue"
	faction = "Giovanni Blu Stocks"

/obj/item/weapon/disk/blue/fake
	name = "blue diskette"
	faction = "Giovanni Blu Stocks"
	fake = TRUE

/obj/item/weapon/disk/yellow
	name = "yellow diskette"
	icon_state = "disk_yellow"
	item_state = "disk_yellow"
	faction = "Goldstein Solutions"

/obj/item/weapon/disk/yellow/fake
	name = "yellow diskette"
	faction = "Goldstein Solutions"
	fake = TRUE

/obj/item/weapon/disk/green
	name = "green diskette"
	icon_state = "disk_green"
	item_state = "disk_green"
	faction = "MacGreene Traders"

/obj/item/weapon/disk/green/fake
	name = "green diskette"
	faction = "MacGreene Traders"
	fake = TRUE
///OSes/////////////////

/obj/item/weapon/disk/os
	name = "unga OS boot disk"
	desc = "A disk used to boot unga OS."
	icon = 'icons/obj/bureaucracy.dmi'
	icon_state = "disk_uos0"
	item_state = "disk_uos0"
	var/operatingsystem = "unga OS"

	attackby(obj/item/W, mob/living/M)
		return

/obj/item/weapon/disk/os/uos94
	name = "unga OS 94 boot disk"
	desc = "A disk used to boot unga OS 94."
	icon_state = "disk_uos94"
	item_state = "disk_uos94"
	operatingsystem = "unga OS 94"

/obj/item/weapon/disk/os/uos94pe
	name = "unga OS 94 PE boot disk"
	desc = "A disk used to boot unga OS 94 Police Edition."
	icon_state = "disk_uos94"
	item_state = "disk_uos94"
	operatingsystem = "unga OS 94 Police Edition"

//////////////////programs////////////////////

/obj/item/weapon/disk/program
	name = "program disk"
	desc = "A disk used to boot unga OS."
	icon = 'icons/obj/bureaucracy.dmi'
	icon_state = "disk_black"
	item_state = "disk_black"
	var/included
	var/list/compatible_os = list()

	attackby(obj/item/W, mob/living/M)
		return

/obj/item/weapon/disk/program/orion_trail
	name = "Orion Trail installation disk"
	desc = "Learn how our descendants will get to Orion, and have fun in the process!"
	compatible_os = list("unga OS 94")
	New()
		..()
		included = /datum/program/orion_trail

/obj/item/weapon/disk/program/monkeysoftmail
	name = "MonkeySoft Mail installation disk"
	desc = "Send and Receive emails using the latest MonkeySoft Mail Client!"
	compatible_os = list("unga OS 94", "unga OS")
	New()
		..()
		included = /datum/program/monkeysoftmail