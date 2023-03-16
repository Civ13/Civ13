//////////////////////////////////////////////////////////////
/obj/structure/computer/nopower/aotd
	name = "desktop computer"
	desc = "A desktop computer running the latest version of Unga OS. Has a floppy drive."
	powered = TRUE
	powerneeded = FALSE
	anchored = TRUE
	display = "<b>unga OS</b>"
	operatingsystem = "unga OS 94"

/obj/structure/computer/nopower/aotd/civilian/New()
	..()
	programs += new/datum/program/monkeysoftmail
	programs += new/datum/program/deepnet
	programs += new/datum/program/orion_trail
	programs += new/datum/program/junglebank

/obj/structure/computer/nopower/aotd/green/New()
	..()
	programs += new/datum/program/monkeysoftmail/green
	programs += new/datum/program/deepnet
	programs += new/datum/program/elektra
	programs += new/datum/program/orion_trail

/obj/structure/computer/nopower/aotd/red/New()
	..()
	programs += new/datum/program/monkeysoftmail/red
	programs += new/datum/program/deepnet
	programs += new/datum/program/elektra
	programs += new/datum/program/orion_trail

/obj/structure/computer/nopower/aotd/yellow/New()
	..()
	programs += new/datum/program/monkeysoftmail/yellow
	programs += new/datum/program/deepnet
	programs += new/datum/program/elektra
	programs += new/datum/program/orion_trail

/obj/structure/computer/nopower/aotd/blue/New()
	..()
	programs += new/datum/program/monkeysoftmail/blue
	programs += new/datum/program/deepnet
	programs += new/datum/program/elektra
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
		else if (H.civilization == "Sheriff Office")
			H << "<span class='notice'>You do not know how to decrypt this... You should put it in the evidence room instead.</span>"
			return
		else if (H.civilization == "Paramedics")
			H << "<span class='notice'>You do not know how to decrypt this... You should hand it over to the Sheriff Office instead.</span>"
			return
		else if (H.civilization == "Government")
			H << "<span class='notice'>You do not know how to decrypt this... You should hand it over to the Sheriff Office instead.</span>"
			return
		else if (D.used)
			H << "<span class='notice'>This disk has already been decrypted and wiped.</span>"
			return
		else
			playsound(get_turf(src), 'sound/machines/computer/floppydisk.ogg', 100, TRUE)
			switch(D.exchange_state)
				if (-1)
					if (D.fake)
						map.scores[H.civilization] -= 100
						D.used = TRUE
						qdel(D)
						spawn(1)
							WWalert(H,"This is a fake inactive disk! You lose 100 points.", "Fake Disk")
					else
						map.scores[H.civilization] += 100
						map.give_stock_points(H.civilization,100)
						var/obj/item/stack/money/dollar/DLR = new/obj/item/stack/money/dollar(loc)
						DLR.amount = 40
						DLR.update_icon()
						D.used = TRUE
						qdel(D)
						spawn(1)
							WWalert(H,"This is a real inactive disk! You gain 100 dollars and 100 points.", "Real Disk")

				if (0)
					if (D.fake)
						map.scores[H.civilization] -= 400
						D.used = TRUE
						qdel(D)
						spawn(1)
							WWalert(H,"This is a fake disk! Since you exchanged it with a fake disk too, both factions lose 400 points.", "Fake Disk")


				if (1)
					if (D.fake)
						D.used = TRUE
						qdel(D)
						spawn(1)
							WWalert(H,"This is a fake disk! Since you exchanged it with a real disk, you gain nothing and the other faction gains 200 dollars and 200 points.", "Fake Disk")

					else
						map.scores[H.civilization] += 200
						map.give_stock_points(H.civilization,200)
						var/obj/item/stack/money/dollar/DLR = new/obj/item/stack/money/dollar(loc)
						DLR.amount = 40
						DLR.update_icon()
						D.used = TRUE
						qdel(D)
						spawn(1)
							WWalert(H,"This is a real disk! Since you exchanged it with a fake disk, you gain 200 dollars, 200 points and the other faction gains nothing.", "Real Disk")

				if (2)
					if (!D.fake)
						map.scores[H.civilization] += 400
						map.give_stock_points(H.civilization,400)
						var/obj/item/stack/money/dollar/DLR = new/obj/item/stack/money/dollar(loc)
						DLR.amount = 80
						DLR.update_icon()
						D.used = TRUE
						qdel(D)
						spawn(1)
							WWalert(H,"This is a real disk! Since you exchanged it with a real disk too, both factions gain 400 dollars and 400 points.", "Real Disk")


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

/obj/structure/computer/nopower/carspawn
	name = "Vehicle Supply Terminal"
	desc = "A computer terminal connected to the supply network."
	powered = TRUE
	powerneeded = FALSE
	anchored = TRUE
	operatingsystem = "unga OS 94"
	New()
		..()
		programs += new/datum/program/carspawn


//////////////////////////////////////////////////////////////
/obj/structure/computer/nopower/police
	name = "Police Processing Terminal"
	desc = "A computer running unga OS 94 Law Enforcement Edition, with access to both civilians and LEOs."
	icon_state = "research_on"
	powered = TRUE
	powerneeded = FALSE
	anchored = TRUE
	density = TRUE
	operatingsystem = "unga OS 94 Law Enforcement Edition"
	New()
		..()
		programs += new/datum/program/permits
		programs += new/datum/program/warrants

/obj/structure/computer/nopower/police/inside
	New()
		..()
		programs += new/datum/program/monkeysoftmail/police
		programs += new/datum/program/squadtracker
		programs += new/datum/program/gunregistry
		programs += new/datum/program/licenseplates
		programs += new/datum/program/fingerprintregistry
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
	w_class = ITEM_SIZE_TINY

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
	faction = "Kogama Kraftsmen"

/obj/item/weapon/disk/green/fake
	name = "green diskette"
	faction = "Kogama Kraftsmen"
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
	name = "unga OS 94 LE boot disk"
	desc = "A disk used to boot unga OS 94 Law Enforcement Edition."
	icon_state = "disk_uos94"
	item_state = "disk_uos94"
	operatingsystem = "unga OS 94 Law Enforcement Edition"
///////////////components/////////////////////
/obj/item/stack/component
	icon = 'icons/obj/computers.dmi'
	name = "electronic component"
	desc = "A basic electronic chip."
	icon_state = "generic_chip"
	amount = 1
	value = 400
	w_class = ITEM_SIZE_TINY
	max_amount = 20
	flags = CONDUCT

/obj/item/stack/component/red
	name = "RDKV S-445 chip"
	desc = "A highly advanced chip, manufactured by Rednikov Industries."
	icon_state = "card_red"

/obj/item/stack/component/green
	name = "KOGM S5R1 chip"
	desc = "A highly advanced chip, manufactured by Kogama Kraftsmen."
	icon_state = "card_ram"

/obj/item/stack/component/blue
	name = "GBSA-1994 chip"
	desc = "A highly advanced chip, manufactured by Giovanni Blu Stocks."
	icon_state = "cpu_chip_blue"

/obj/item/stack/component/yellow
	name = "GS-IC-M3 chip"
	desc = "A highly advanced chip, manufactured by Goldstein Solutions."
	icon_state = "yellow_card"
/////////////////precursors///////////////////
///////////////components/////////////////////
/obj/item/stack/precursor
	icon = 'icons/obj/mining.dmi'
	name = "crystal"
	desc = "A rare chemical, in crystallized form."
	icon_state = "ore_diamond"
	var/produces = /obj/item/stack/component
	amount = 1
	value = 60
	w_class = ITEM_SIZE_TINY
	max_amount = 20

/obj/item/stack/precursor/red
	name = "crimsonite crystals"
	desc = "A rare chemical, in crystallized form. Has a red tinge."
	icon_state = "ore_crimsonite"
	produces = /obj/item/stack/component/red

/obj/item/stack/precursor/green
	name = "verdine crystals"
	desc = "A rare chemical, in crystallized form. Has a green tinge."
	icon_state = "ore_verdine"
	produces = /obj/item/stack/component/green

/obj/item/stack/precursor/blue
	name = "indigon crystals"
	desc = "A rare chemical, in crystallized form. Has a blue tinge."
	icon_state = "ore_indigon"
	produces = /obj/item/stack/component/blue

/obj/item/stack/precursor/yellow
	name = "galdonium crystals"
	desc = "A rare chemical, in crystallized form. Has a yellow tinge."
	icon_state = "ore_galdonium"
	produces = /obj/item/stack/component/yellow

//////////////////assembler/////////////////////
/obj/structure/assembler
	name = "assembler"
	desc = "An automated machine, part of a conveyor belt, that assembles a circuit."
	icon = 'icons/obj/modern_structures.dmi'
	icon_state = "stacker0"
	var/base_icon = "stacker"
	anchored = TRUE
	density = TRUE
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	var/on = FALSE
	var/requires = /obj/item/stack/precursor
	var/faction
/obj/structure/assembler/processor

/obj/structure/assembler/loader
	name = "loader"
	desc = "An automated machine, part of a conveyor belt, that loads the precursors."
	icon_state = "loader0"
	base_icon = "loader"

/obj/structure/assembler/unloader
	name = "unloader"
	desc = "An automated machine, part of a conveyor belt, that unloads the final product."
	icon_state = "unloader0"
	base_icon = "unloader"

/obj/structure/assembler/loader/red
	requires = /obj/item/stack/precursor/red
	faction = "Rednikov Industries"

/obj/structure/assembler/loader/green
	requires = /obj/item/stack/precursor/green
	faction = "Kogama Kraftsmen"

/obj/structure/assembler/loader/yellow
	requires = /obj/item/stack/precursor/yellow
	faction = "Goldstein Solutions"

/obj/structure/assembler/loader/blue
	requires = /obj/item/stack/precursor/blue
	faction = "Giovanni Blu Stocks"

/obj/structure/assembler/update_icon()
	if (on)
		icon_state = "[base_icon]1"
	else
		icon_state = "[base_icon]0"

/obj/structure/assembler/loader/attackby(var/obj/item/I, var/mob/living/human/H)
	var/found1 = FALSE
	var/found2 = FALSE
	if (faction && H.civilization != faction)
		H << "You are not trained to operate this machine."
		return
	if (on)
		H << "The assembler is busy, please wait..."
		return
	for(var/obj/structure/assembler/processor/A in locate(x+1,y,z))
		found1 = TRUE
	for(var/obj/structure/assembler/unloader/A in locate(x+2,y,z))
		found2 = TRUE
	if (!found1 && !found2)
		H << "The assembler is incomplete and cannot be used."
		return
	if (istype(I, requires))
		H.drop_from_inventory(I)
		I.forceMove(locate(1,1,1))
		manufacture(I,H)
	else
		H << "<span class='warning'>This is the wrong precursor!</span>"
		return
/obj/structure/assembler/loader/manufacture(var/obj/item/stack/precursor/P,var/mob/living/human/H)
	if (istype(P,/obj/item/stack/precursor))
		for(var/mob/L in range(7,src))
			L << sound('sound/machines/steam_loop.ogg', 1, 0, 987, 100)
			spawn(520)
				L << sound(null, channel = 987)
		on = TRUE
		update_icon()
		spawn(20)
			if (P)
				on = FALSE
				update_icon()
				for(var/obj/structure/assembler/processor/A in locate(x+1,y,z))
					A.manufacture(P)
					return
			else
				on = FALSE
				update_icon()
				return
/obj/structure/assembler/proc/manufacture(var/obj/item/stack/precursor/P,var/mob/living/human/H)
	return

/obj/structure/assembler/processor/manufacture(var/obj/item/stack/precursor/P,var/mob/living/human/H)
	on = TRUE
	update_icon()
	spawn(500)
		on = FALSE
		update_icon()
		for(var/obj/structure/assembler/unloader/A in locate(x+1,y,z))
			A.manufacture(P)
			return
/obj/structure/assembler/unloader/manufacture(var/obj/item/stack/precursor/P,var/mob/living/human/H)
	on = TRUE
	update_icon()
	spawn(20)
		for(var/i=1, i<=P.amount,i++)
			new P.produces(loc)
		on = FALSE
		qdel(P)
		update_icon()
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

/obj/item/weapon/disk/program/squadtracker
	name = "Squad-Trak installation disk"
	desc = "Tracks the location of your squad."
	compatible_os = list("unga OS 94","unga OS 94 Law Enforcement Edition")
	New()
		..()
		included = /datum/program/squadtracker