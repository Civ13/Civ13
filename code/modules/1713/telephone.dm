
/////////////////////////////TELEPHONE/////////////////////////////////////
/obj/item/weapon/telephone
	name = "telephone"
	desc = "Used to communicate with other telephones. No number."
	icon = 'icons/obj/modern_structures.dmi'
	icon_state = "telephone"
	flammable = FALSE
	density = FALSE
	opacity = FALSE
	force = WEAPON_FORCE_WEAK+3
	throwforce = WEAPON_FORCE_WEAK
	var/phonenumber = 0
	var/ringing = FALSE
	var/ringingnum = FALSE
	var/obj/item/weapon/telephone/origincall = null
	var/connected = FALSE

	var/wireless = FALSE
	var/maxrange = 0

var/list/global/phone_numbers = list()

/obj/item/weapon/telephone/New()
	..()
	if (phonenumber == 0)
		new_phonenumber()

/obj/item/weapon/telephone/proc/new_phonenumber()
	var/tempnum = 0
	tempnum = rand(1000,9999)
	if (tempnum in phone_numbers)
		new_phonenumber()
		return
	else
		phonenumber = tempnum
		phone_numbers += tempnum
		desc = "Used to communicate with other telephones. Number: [phonenumber]."
		return

/obj/item/weapon/telephone/proc/ringproc(var/origin,var/obj/item/weapon/telephone/ocall)
	ringing = TRUE
	ringingnum = origin
	origincall = ocall
	spawn(0)
		if (ringing)
			ring(origin)
	spawn(40)
		if (ringing)
			ring(origin)
	spawn(80)
		if (ringing)
			ring(origin)
	spawn(120)
		if (ringing)
			ring(origin)
	spawn(160)
		if (ringing)
			ring(origin)
	spawn(200)
		ringing = FALSE
		ringingnum = FALSE
		if (!connected)
			origincall = null
	return
/obj/item/weapon/telephone/proc/ring()
	if (ringing)
		playsound(loc, 'sound/machines/telephone.ogg', 65)
		visible_message("\The [src] rings!")
	else
		return

/obj/item/weapon/telephone/proc/broadcast(var/msg, var/mob/living/carbon/human/speaker)

	// ignore emotes.
	if (dd_hasprefix(msg, "*"))
		return

	var/list/tried_mobs = list()

	for (var/mob/living/carbon/human/hearer in human_mob_list)
		if (tried_mobs.Find(hearer))
			continue
		tried_mobs += hearer
		if (hearer.stat == CONSCIOUS)
			for (var/obj/item/weapon/telephone/phone in view(7, hearer))
				if (src == phone.origincall)
					hearer.hear_phone(msg, speaker.default_language, speaker, src, phone)

/obj/item/weapon/telephone/attack_self(var/mob/user as mob)
	if (!connected && !ringing)
		var/input = input(user, "Choose the number to call: (4 digits, no decimals)") as num
		if (!input)
			return
		var/tgtnum = 0
		tgtnum = sanitize_integer(input, min=1000, max=9999, default=0) //0 as a first digit doesnt really work
		if (tgtnum == 0)
			return
		if (!wireless)
			for (var/obj/structure/phoneline/PL in range(2,loc))
				PL.ring_phone(tgtnum,phonenumber, src)
				visible_message("<b><font size=2 color=#FFAE19>\icon[getFlatIcon(src)] Telephone:</b> </font>Ringing [tgtnum]...")
				spawn(200)
					if (!connected)
						visible_message("<b><font size=2 color=#FFAE19>\icon[getFlatIcon(src)] Telephone:</b> </font>Nobody picked up the phone at [tgtnum].")
						return
		else
			var/found_tower = FALSE
			for (var/obj/structure/cell_tower/CT in range(maxrange,loc))
				found_tower = TRUE
				CT.ring_phone(tgtnum,phonenumber, src)
				user << "<b><font size=2 color=#FFAE19>\icon[getFlatIcon(src)] Telephone:</b> </font>Ringing [tgtnum]..."
				spawn(200)
					if (!connected)
						user << "<b><font size=2 color=#FFAE19>\icon[getFlatIcon(src)] Telephone:</b> </font>Nobody picked up the phone at [tgtnum]."
						return
			if (!found_tower)
				user << "<font size=2 color=#FFAE19>No signal.</font>"
				return
	if (connected)
		connected = FALSE
		origincall.connected = FALSE
		origincall.origincall = null
		origincall = null
		user << "You hang up the phone."

	if (ringing && ringingnum)
		ringing = FALSE
		connected = ringingnum
		if (origincall)
			origincall.connected = phonenumber
			origincall.ringing = FALSE
			origincall.origincall = src
		user << "You pick up the phone."

/////////////////////////////MOBILE PHONE/////////////////////////////////////
/obj/item/weapon/telephone/mobile
	name = "cellphone"
	desc = "Used to communicate with other telephones. No number."
	icon = 'icons/obj/device.dmi'
	icon_state = "cellphone"
	force = WEAPON_FORCE_WEAK+3
	throwforce = WEAPON_FORCE_WEAK
	wireless = TRUE
	maxrange = 30

/////////////////////////////CELLPHONE TOWER/////////////////////////////////////
/obj/structure/cell_tower
	name = "cell tower"
	desc = "A steel tower used to relay mobile communications."
	icon = 'icons/obj/obj32x64.dmi'
	icon_state = "radio_powered"
	flammable = TRUE
	not_movable = TRUE
	not_disassemblable = TRUE
	density = FALSE
	opacity = FALSE
	var/maxrange = 30
	var/lastproc = 0

/obj/structure/cell_tower/proc/ring_phone(var/target, var/origin, var/obj/item/weapon/telephone/originphone)
	if (!origin || !target)
		return
	if (world.time <= lastproc)
		return
	else
		for (var/obj/item/weapon/telephone/TLG in range(maxrange,src))
			if (TLG.phonenumber == target && TLG.phonenumber != origin)
				if (!TLG.ringing)
					TLG.ringproc(origin, originphone)
	lastproc = world.time+3
