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


/obj/structure/radio
	name = "radio receiver"
	desc = "Used to communicate with distant places. Set to 150kHz."
	icon = 'icons/obj/modern_structures.dmi'
	icon_state = "radio_vintage"
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE
	density = FALSE
	opacity = FALSE
	var/freq = 150 //150 to 300
	var/receiver = TRUE
	var/transmitter = FALSE
	var/receiver_on = TRUE
	var/transmitter_on = FALSE
	var/mob/user = null
	powerneeded = 5
	var/on = FALSE

/obj/structure/radio/transmitter
	name = "radio transmitter"
	icon_state = "radio_transmitter"
	transmitter = TRUE
	receiver = FALSE
	receiver_on = FALSE
	transmitter_on = TRUE
	powerneeded = 35

/obj/structure/radio/transmitter_receiver
	name = "two-way radio"
	icon_state = "radio"
	transmitter = TRUE
	receiver = TRUE
	receiver_on = TRUE
	transmitter_on = TRUE
	powerneeded = 20

/obj/structure/radio/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/stack/cable_coil))
		if (powersource)
			user << "There's already a cable connected here! Split it further from the [src]."
			return
		var/obj/item/stack/cable_coil/CC = W
		powersource = CC.place_turf(get_turf(src), user, turn(get_dir(user,src),180))
		powersource.connections += src
		var/opdir1 = 0
		var/opdir2 = 0
		if (powersource.tiledir == "horizontal")
			opdir1 = 4
			opdir2 = 8
		else if  (powersource.tiledir == "vertical")
			opdir1 = 1
			opdir2 = 2
		powersource.update_icon()

		if (opdir1 != 0 && opdir2 != 0)
			for(var/obj/structure/cable/NCOO in get_turf(get_step(powersource,opdir1)))
				if ((NCOO.tiledir == powersource.tiledir) && NCOO != powersource)
					if (!(powersource in NCOO.connections) && !list_cmp(powersource.connections, NCOO.connections))
						NCOO.connections += powersource
					if (!(NCOO in powersource.connections) && !list_cmp(powersource.connections, NCOO.connections))
						powersource.connections += NCOO
					user << "You connect the two cables."

			for(var/obj/structure/cable/NCOC in get_turf(get_step(powersource,opdir2)))
				if ((NCOC.tiledir == powersource.tiledir) && NCOC != powersource)
					if (!(powersource in NCOC.connections) && !list_cmp(powersource.connections, NCOC.connections))
						NCOC.connections += powersource
					if (!(NCOC in powersource.connections) && !list_cmp(powersource.connections, NCOC.connections))
						powersource.connections += NCOC
		user << "You connect the cable to the [src]."
	else
		..()

/obj/structure/radio/proc/check_power()
	if (!powersource || powerneeded == 0)
		return FALSE
	else
		if (powersource.powered && ((powersource.powerflow-powersource.currentflow) >= powerneeded))
			if (!on)
				powersource.update_power(powerneeded,1)
				on = TRUE
				powersource.currentflow += powerneeded
				powersource.lastupdate2 = world.time
			return TRUE
		else
			if (on)
				powersource.update_power(powerneeded,1)
				on = FALSE
				powersource.currentflow -= powerneeded
				powersource.lastupdate2 = world.time
			return FALSE


/obj/structure/radio/attack_hand(var/mob/attacker)
	interact(attacker)

/obj/structure/radio/interact(var/mob/m)
	if (user)
		if (get_dist(src, user) > 1)
			user = null
	restart
	if (user && user != m)
		if (user.client)
			return
		else
			user = null
			goto restart
	else
		user = m
		do_html(user)

/obj/structure/radio/Topic(href, href_list, hsrc)

	var/mob/user = usr

	if (!user || user.lying)
		return

	user.face_atom(src)

	if (!locate(user) in range(1,src))
		user << "<span class = 'danger'>Get close to the [src] to use it.</span>"
		return FALSE

	if (!user.can_use_hands())
		user << "<span class = 'danger'>You have no hands to use this with.</span>"
		return FALSE

	if (href_list["set_frequency"])
		var/input = input(user, "Choose the frequency to sintonize, in kHz: (150-300, no decimals)") as num
		if (!input)
			return
		freq = sanitize_integer(input, min=150, max=300, default=150)
		user << "Frequency set to [freq]kHz."
		desc = "Used to communicate with distant places. Set to [freq]kHz."
		do_html(user)
		return

	if (href_list["receiver"])
		if (receiver)
			receiver_on = !receiver_on
			do_html(user)
			return

	if (href_list["transmitter"])
		if (transmitter)
			transmitter_on = !transmitter_on
			do_html(user)
			return


	do_html(user)


/obj/structure/radio/verb/name_radio()
	set category = null
	set name = "Name"
	set desc = "Name this radio."

	set src in view(1)
	var/yn = input(usr, "Name this radio?") in list("Yes", "No")
	if (yn == "Yes")
		var/_name = input(usr, "What name?") as text
		name = sanitize(_name, 20)
	return

/obj/structure/radio/proc/do_html(var/mob/m)
	var/style = "Radio Receiver/Transmitter"
	if (receiver && !transmitter)
		style = "Radio Receiver"
	if (!receiver && transmitter)
		style = "Radio Transmitter"
	if (m)
		if (check_power() == FALSE)
			m << browse({"

			<br>
			<html>

			<head>
			<style>
			[common_browser_style]
			</style>
			</head>

			<body>

			<script language="javascript">

			function set(input) {
			  window.location="byond://?src=\ref[src];action="+input.name+"&value="+input.value;
			}

			</script>

			<center>
			<font size=3><b>[style]</b></font><br><br>
			<b><font size=2 color=#8b0000>POWER OFF</a><br><br>
			</center>
			</font></b><br>
			</body>
			</html>
			<br>
			"},  "window=artillery_window;border=1;can_close=1;can_resize=1;can_minimize=0;titlebar=1;size=500x500")
		else

			if (receiver && transmitter)
				m << browse({"

				<br>
				<html>

				<head>
				<style>
				[common_browser_style]
				</style>
				</head>

				<body>

				<script language="javascript">

				function set(input) {
				  window.location="byond://?src=\ref[src];action="+input.name+"&value="+input.value;
				}

				</script>

				<center>
				<font size=3><b>[style]</b></font><br><br>
				</center>
				<b><font size=2>Frequency: <a href='?src=\ref[src];set_frequency=1'>[freq]kHz</a><br><br>
				Transmitter: <a href='?src=\ref[src];transmitter=1'>[transmitter_on ? "ON" : "OFF"]</a><br><br>
				Receiver: <a href='?src=\ref[src];receiver=1'>[receiver_on ? "ON" : "OFF"]</a><br><br>
				</font></b><br>
				</body>
				</html>
				<br>
				"},  "window=artillery_window;border=1;can_close=1;can_resize=1;can_minimize=0;titlebar=1;size=500x500")
			else if (receiver && !transmitter)
				m << browse({"

				<br>
				<html>

				<head>
				<style>
				[common_browser_style]
				</style>
				</head>

				<body>

				<script language="javascript">

				function set(input) {
				  window.location="byond://?src=\ref[src];action="+input.name+"&value="+input.value;
				}

				</script>

				<center>
				<font size=3><b>[style]</b></font><br><br>
				</center>
				<b><font size=2>Frequency: <a href='?src=\ref[src];set_frequency=1'>[freq]kHz</a><br><br>
				Receiver: <a href='?src=\ref[src];receiver=1'>[receiver_on ? "ON" : "OFF"]</a><br><br>
				</font></b><br>
				</body>
				</html>
				<br>
				"},  "window=artillery_window;border=1;can_close=1;can_resize=1;can_minimize=0;titlebar=1;size=500x500")
			else if (!receiver && transmitter)
				m << browse({"

				<br>
				<html>

				<head>
				<style>
				[common_browser_style]
				</style>
				</head>

				<body>

				<script language="javascript">

				function set(input) {
				  window.location="byond://?src=\ref[src];action="+input.name+"&value="+input.value;
				}

				</script>

				<center>
				<font size=3><b>[style]</b></font><br><br>
				</center>
				<b><font size=2>Frequency: <a href='?src=\ref[src];set_frequency=1'>[freq]kHz</a><br><br>
				Transmitter: <a href='?src=\ref[src];transmitter=1'>[transmitter_on ? "ON" : "OFF"]</a><br><br>
				</font></b><br>
				</body>
				</html>
				<br>
				"},  "window=artillery_window;border=1;can_close=1;can_resize=1;can_minimize=0;titlebar=1;size=500x500")

/obj/structure/radio/proc/broadcast(var/msg, var/mob/living/carbon/human/speaker)

	// ignore emotes.
	if (dd_hasprefix(msg, "*"))
		return

	var/list/used_radios = list()
	var/list/tried_mobs = list()

	for (var/mob/living/carbon/human/hearer in human_mob_list)
		if (tried_mobs.Find(hearer))
			continue
		tried_mobs += hearer
		if (hearer.stat == CONSCIOUS)
			var/list/radios = list()
			for (var/obj/structure/radio/radio in view(world.view, hearer))
				if (radio.receiver_on)
					radios |= radio
			for (var/obj/structure/radio/radio in radios)
				if (!loc && radio == src)
					continue
				if (used_radios.Find(radio))
					continue
				used_radios += radio
				if (radio.freq == freq && radio.check_power())
					hearer.hear_radio(msg, speaker.default_language, speaker, src, radio)
	// let observers hear it
	for (var/mob/observer/O in mob_list)
		O.hear_radio(msg, speaker.default_language, speaker, src)