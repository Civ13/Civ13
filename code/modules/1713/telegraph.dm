/obj/structure/telegraph
	name = "telegraph"
	desc = "Used to communicate with distant places."
	icon = 'icons/obj/modern_structures.dmi'
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

/obj/structure/telegraph/proc/transmit(var/msg)
	if (!msg)
		return
	for (var/obj/structure/phoneline/PL in range(2,src))
		PL.transmit(msg,src)
		return

/obj/structure/telegraph/proc/receive(var/msg)
	if (!msg)
		return
	playsound(loc, 'sound/machines/telegraph.ogg', 65)
	visible_message(msg)
	return

/obj/structure/telegraph/attack_hand(var/mob/user as mob)
	var/message = input(usr, "Write a word. Up to 10 characters, no spaces, symbols or numbers.") as text
	message = sanitize(message, 10)
	message = convertmsg(message)
	if (message && message != "")
		currmsg = "<font color=#FFAE19><b>...[message]...</b></font>"
		transmit(currmsg)
		playsound(loc, 'sound/machines/telegraph.ogg', 65)
		icon_state = "telegraph_active"
		update_icon()
		spawn(22)
			icon_state = "telegraph"
			update_icon()
	return

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
	New()
		..()
		update_lines()

/obj/structure/phoneline/proc/transmit(var/msg, var/obj/structure/telegraph/TL, var/obj/structure/phoneline/origin)
	if (!msg || !TL)
		return
	else
		//left
		for (var/obj/structure/phoneline/PL in get_turf(locate(x-3,y,z)))
			if (PL != origin)
				PL.transmit(msg,TL,src)

		//right
		for (var/obj/structure/phoneline/PL in get_turf(locate(x+3,y,z)))
			if (PL != origin)
				PL.transmit(msg,TL,src)

		//up
		for (var/obj/structure/phoneline/PL in get_turf(locate(x,y+3,z)))
			if (PL != origin)
				PL.transmit(msg,TL,src)

		//down
		for (var/obj/structure/phoneline/PL in get_turf(locate(x,y-3,z)))
			if (PL != origin)
				PL.transmit(msg,TL,src)

		for (var/obj/structure/telegraph/TLG in range(2,src))
			if (TLG != TL)
				TLG.receive(msg)

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
