/obj/structure/telegraph
	name = "telegraph"
	desc = "Used to communicate with distant places."
	icon = 'icons/obj/device.dmi'
	icon_state = "telegraph"
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE
	density = FALSE
	opacity = FALSE
	var/currmsg = ""
	var/list/allowedlist = list("a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z","A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z")
/obj/structure/telegraph/proc/convertmsg(var/message)
	var/output = ""
	for (var/i=1, i<=length(message), i++)
		var/ascii_char = text2ascii(message,i)
		switch(ascii_char)
			// A  .. Z
			if (65 to 90)			//Uppercase Letters
				output += ascii2text(ascii_char)

			// a  .. z
			if (97 to 122)			//Lowercase Letters
				output += ascii2text(ascii_char-32)
	return output


/obj/structure/telegraph/verb/name_telegraph()
	set category = null
	set name = "Name"
	set desc = "Name this telegraph."

	set src in view(1)
	var/yn = input(usr, "Name this telegraph?") in list("Yes", "No")
	if (yn == "Yes")
		var/_name = input(usr, "What name?") as text
		name = sanitize(_name, 20)
	return

/obj/structure/telegraph/proc/transmit(var/msg, var/stripmsg)
	if (!msg)
		return
	for (var/obj/structure/phoneline/PL in range(2,src))
		PL.transmit(msg,stripmsg,src,PL)
		return

/obj/structure/telegraph/proc/receive(var/msg, var/stripmsg)
	if (!msg || !stripmsg)
		return
	playsound(loc, 'sound/machines/telegraph.ogg', 65)
	visible_message(msg)
	for (var/obj/structure/teleprinter/TP in range(1,src))
		TP.print(stripmsg)
	return

/obj/structure/telegraph/attack_hand(var/mob/user as mob)
	var/message = input(usr, "Write a word. Up to 10 characters, no spaces, symbols or numbers.") as text
	message = sanitize(message, 10)
	message = convertmsg(message)
	if (message && message != "")
		var/stripmsg = message
		currmsg = "<b><font size=2 color=#FFAE19>\icon[getFlatIcon(src)] [name]:</b></font> \"...[message]...\""
		transmit(currmsg,stripmsg)
		playsound(loc, 'sound/machines/telegraph.ogg', 65)
		icon_state = "telegraph_active"
		update_icon()
		spawn(22)
			icon_state = "telegraph"
			update_icon()
	return

/obj/structure/teleprinter
	name = "teleprinter"
	desc = "Will convert telegraph messages to paper."
	icon = 'icons/obj/device.dmi'
	icon_state = "teleprinter0"
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE
	density = FALSE
	opacity = FALSE
	var/list/inpaper = list()

/obj/structure/teleprinter/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/paper))
		if (isemptylist(inpaper))
			inpaper += W
			user << "You put the paper in the teleprinter."
			user.drop_from_inventory(W)
			W.forceMove(locate(0,0,0))
			icon_state = "teleprinter1"
			update_icon()
		else
			user << "There already is a paper inside! Remove it first."
			return

/obj/structure/teleprinter/attack_hand(var/mob/user as mob)
	for(var/obj/item/weapon/C in inpaper)
		user << "You remove \the [C]."
		C.loc = get_turf(src)
		inpaper -= C
		icon_state = "teleprinter0"
		update_icon()
	return

/obj/structure/teleprinter/proc/print(var/new_text)
	if (isemptylist(inpaper))
		return
	else
		for(var/obj/item/weapon/paper/C in inpaper)
			if (C.free_space >= 22)
				new_text = "<b><font face='Courier New'>Telegram at [roundduration2text_days()]: [new_text]</b></font><br>"
				C.info += new_text
				C.free_space -= length(strip_html_properly(new_text))

/obj/structure/phoneline
	name = "utility pole"
	desc = "A wood pole with cable hooks on top. Used for phone and telegraph wiring."
	icon = 'icons/obj/obj32x64.dmi'
	icon_state = "powerline"
	flammable = TRUE
	not_movable = TRUE
	not_disassemblable = TRUE
	density = FALSE
	opacity = FALSE
	var/obj/structure/phonecable/horizontal/h_cable = null
	var/obj/structure/phonecable/vertical/v_cable = null
	var/currmsg = ""
	var/lastproc = 0
	New()
		..()
		update_lines()

/obj/structure/phoneline/proc/transmit(var/msg, var/stripmsg, var/obj/structure/telegraph/TL, var/obj/structure/phoneline/origin)
	if (!msg || !TL)
		return
	if (world.time <= lastproc)
		return
	else
		//left
		for (var/obj/structure/phoneline/PL in get_turf(locate(x-3,y,z)))
			if (PL != origin && PL != src)
				PL.transmit(msg,stripmsg,TL,src)

		//right
		for (var/obj/structure/phoneline/PL in get_turf(locate(x+3,y,z)))
			if (PL != origin && PL != src)
				PL.transmit(msg,stripmsg,TL,src)

		//up
		for (var/obj/structure/phoneline/PL in get_turf(locate(x,y+3,z)))
			if (PL != origin && PL != src)
				PL.transmit(msg,stripmsg,TL,src)

		//down
		for (var/obj/structure/phoneline/PL in get_turf(locate(x,y-3,z)))
			if (PL != origin && PL != src)
				PL.transmit(msg,stripmsg,TL,src)

		//right next to it
		for (var/obj/structure/phoneline/PL in range(1,src))
			if (PL != origin && PL != src)
				PL.transmit(msg,stripmsg,TL,src)

		for (var/obj/structure/telegraph/TLG in range(2,src))
			if (TLG != TL)
				TLG.receive(msg,stripmsg)
	lastproc = world.time+3
/obj/structure/phoneline/proc/ring_phone(var/target, var/origin, var/obj/item/weapon/telephone/originphone)
	if (!origin || !target)
		return
	if (world.time <= lastproc)
		return
	else
		//left
		for (var/obj/structure/phoneline/PL in get_turf(locate(x-3,y,z)))
			if (PL != origin && PL != src)
				PL.ring_phone(target,origin, originphone)

		//right
		for (var/obj/structure/phoneline/PL in get_turf(locate(x+3,y,z)))
			if (PL != origin && PL != src)
				PL.ring_phone(target,origin, originphone)

		//up
		for (var/obj/structure/phoneline/PL in get_turf(locate(x,y+3,z)))
			if (PL != origin && PL != src)
				PL.ring_phone(target,origin, originphone)

		//down
		for (var/obj/structure/phoneline/PL in get_turf(locate(x,y-3,z)))
			if (PL != origin && PL != src)
				PL.ring_phone(target,origin, originphone)

		//right next to it
		for (var/obj/structure/phoneline/PL in range(1,src))
			if (PL != origin && PL != src)
				PL.ring_phone(target,origin, originphone)

		for (var/obj/item/weapon/telephone/TLG in range(2,src))
			if (TLG.phonenumber == target && TLG.phonenumber != origin)
				if (!TLG.ringing)
					TLG.ringproc(origin, originphone)
	lastproc = world.time+3
/obj/structure/phonecable
	name = "communications cable"
	desc = "A thin copper cable used for communications"
	icon = 'icons/obj/obj128x128.dmi'
	icon_state = "cable_h"
	flammable = TRUE
	not_movable = TRUE
	not_disassemblable = TRUE
	density = FALSE
	opacity = FALSE
	layer = 5

/obj/structure/phonecable/vertical
	icon_state = "cable_v"

/obj/structure/phonecable/horizontal
	icon_state = "cable_h"

/obj/structure/phonecable/vertical/v2
	icon_state = "cable_v2"

/obj/structure/phoneline/proc/update_lines()
	//left
	for (var/obj/structure/phoneline/PL in get_turf(locate(x-3,y,z)))
		if (!PL.h_cable)
			new/obj/structure/phonecable/horizontal(get_turf(PL))

	//right
	for (var/obj/structure/phoneline/PL in get_turf(locate(x+3,y,z)))
		if (!h_cable)
			new/obj/structure/phonecable/horizontal(get_turf(src))

	//up
	for (var/obj/structure/phoneline/PL in get_turf(locate(x,y+3,z)))
		if (!v_cable)
			new/obj/structure/phonecable/vertical(get_turf(locate(x,y+1,z)))

	//down
	for (var/obj/structure/phoneline/PL in get_turf(locate(x,y-3,z)))
		if (!PL.v_cable)
			new/obj/structure/phonecable/vertical/v2(get_turf(locate(x,y-2,z)))

//////////////////////////RADIO RECORDER////////////////////
// basically this enables you to schedule regular broadcasts.
/obj/structure/radiorecorder
	name = "voice recorder"
	desc = "Used to record programs to be broadcast by radio."
	icon = 'icons/obj/device.dmi'
	icon_state = "recorder"
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = TRUE
	density = FALSE
	opacity = FALSE
	var/list/storedphrases = list()
	var/on = FALSE
	var/bdrunning = FALSE
	var/mob/living/human/owner = null

/obj/structure/radiorecorder/update_icon()
	..()
	if (on)
		icon_state = "recorder_on"
	else
		icon_state = "recorder"

/obj/structure/radiorecorder/attack_hand(var/mob/user as mob)
	var/input1 = WWinput(user, "Do you want to add or remove phrases?", "Voice Recorder", "Cancel", list("Cancel","Add","Remove"))
	if (input1 == "Cancel")
		return
	else if (input1 == "Add")
		var/input3 = input(usr, "What phrase? Maximum 100 characters.") as text
		if (input3 == "")
			return
		else
			input3 = sanitize(input3, 100)
			storedphrases += input3
			return

	else if (input1 == "Remove")
		var/list/sp2 = storedphrases
		sp2 += "Cancel"
		var/input2 = WWinput(user, "What phrase to remove?", "Voice Recorder", "Cancel", storedphrases)
		if (input2 == "Cancel")
			return
		else
			storedphrases -= input2
			return

/obj/structure/radiorecorder/verb/turnon()
	set category = null
	set name = "Turn On/Off"
	set desc = "Make the recorder play or turn it off."

	set src in view(1)

	if (on)
		usr << "You turn the [src] off."
		on = FALSE
		update_icon()
		return
	else
		usr << "You turn the [src] on."
		on = TRUE
		update_icon()
		owner = usr
		if (!bdrunning)
			broadcast()
			bdrunning = TRUE
		return

/obj/structure/radiorecorder/proc/broadcast()
	if (!on)
		bdrunning = FALSE
		return
	else
		var/bdphrase = pick(storedphrases)
		for(var/obj/structure/radio/RD in range(1,src))
			if (RD.transmitter && RD.transmitter_on && (RD.check_power() || RD.powerneeded == 0))
				RD.broadcast(bdphrase, owner)
		spawn(150)
			broadcast()