/////////////////////////////RADIO/////////////////////////////////////
/obj/structure/radio
	name = "radio receiver"
	desc = "Used to communicate with distant places. Set to 150kHz."
	icon = 'icons/obj/device.dmi'
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

	var/multifreq = FALSE
	var/list/multifreqlist = list(150)
	var/list/multifreqlist_selectable = list(150)
	anchored = TRUE
/obj/structure/radio/transmitter
	name = "radio transmitter"
	icon_state = "radio_transmitter"
	transmitter = TRUE
	receiver = FALSE
	receiver_on = FALSE
	transmitter_on = TRUE
	powerneeded = 20

/obj/structure/radio/transmitter_receiver
	name = "two-way radio"
	icon_state = "radio"
	transmitter = TRUE
	receiver = TRUE
	receiver_on = TRUE
	transmitter_on = TRUE
	powerneeded = 20

/obj/structure/radio/transmitter_receiver/nopower/tank
	name = "tank radio"
	desc = "A small and robust tank radio, allowing you to communicate with your fellows over long distances."
	icon_state = "tankradio"
	transmitter = TRUE
	receiver = TRUE
	receiver_on = TRUE
	transmitter_on = TRUE

/obj/structure/radio/transmitter_receiver/nopower/tank/New()
	desc = "A small and robust tank radio, allowing you to communicate with your fellows over long distances. Set to [freq]kHz."

/obj/structure/radio/transmitter_receiver/nopower/tank/faction1/New()
	..()
	freq = FREQ1
	desc = "A small and robust tank radio, allowing you to communicate with your fellows over long distances. Set to [freq]kHz."

/obj/structure/radio/transmitter_receiver/nopower/tank/faction2/New()
	..()
	freq = FREQ2
	desc = "A small and robust tank radio, allowing you to communicate with your fellows over long distances. Set to [freq]kHz."

/obj/structure/radio/transmitter_receiver/nopower
	name = "two-way radio"
	icon_state = "radio"
	transmitter = TRUE
	receiver = TRUE
	receiver_on = TRUE
	transmitter_on = TRUE
	powerneeded = 0

var/global/FREQ1 = rand(150,200)
var/global/FREQ2 = rand(201,250)

var/global/FREQR = rand(1,20)
var/global/FREQB = rand(21,40)
var/global/FREQY = rand(41,60)
var/global/FREQG = rand(61,80)
var/global/FREQP = rand(81,100)
var/global/FREQM = rand(101,120)
/obj/structure/radio/transmitter_receiver/nopower/faction1/New()
	..()
	freq = FREQ1
	desc = "Used to communicate with distant places. Set to [freq]kHz."
/obj/structure/radio/transmitter_receiver/nopower/faction2/New()
	..()
	freq = FREQ2
	desc = "Used to communicate with distant places. Set to [freq]kHz."

/obj/structure/radio/receiver/loudspeaker
	name = "loudspeaker"
	icon_state = "loudspeaker"
	transmitter = FALSE
	receiver = TRUE
	receiver_on = TRUE
	transmitter_on = FALSE
	powerneeded = 0

/obj/structure/radio/receiver/loudspeaker/faction1/New()
	..()
	freq = FREQ1
	desc = "Used to communicate with distant places. Set to [freq]kHz."

/obj/structure/radio/faction1/New()
	freq = FREQ1
	desc = "Used to communicate with distant places. Set to [freq]kHz."
	powerneeded = 0
/obj/structure/radio/faction2/New()
	freq = FREQ2
	desc = "Used to communicate with distant places. Set to [freq]kHz."
	powerneeded = 0
/obj/structure/radio/receiver/loudspeaker/faction2/New()
	..()
	freq = FREQ2
	desc = "Used to communicate with distant places. Set to [freq]kHz."
/obj/structure/radio/attackby(obj/item/W as obj, mob/user as mob)
	if (!anchored && !istype(W, /obj/item/weapon/wrench))
		user << "<span class='notice'>Fix the radio in place with a wrench first.</span>"
		return
	if (istype(W, /obj/item/stack/cable_coil))
		if (powersource)
			user << "There's already a cable connected here! Split it further from the [src]."
			return
		var/obj/item/stack/cable_coil/CC = W
		powersource = CC.place_turf(get_turf(src), user, turn(get_dir(user,src),180))
		if (!powersource)
			return
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
		if (multifreq)
			var/input = WWinput(user, "Choose the frequency to broadcast to:", "Radio", freq, multifreqlist_selectable)
			if (!input || input == freq)
				return
			freq = input
			user << "Frequency set to <b>[freq]</b>."
			do_html(user)
			return

		else
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
		if (check_power() == FALSE && powerneeded > 0)
			m << browse({"

			<br>
			<html>

			<head>
			[common_browser_style]
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
				[common_browser_style]
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
				<b><font size=2>Frequency: <a href='?src=\ref[src];set_frequency=1'>[freq][multifreq ? "" : "kHz"]</a><br><br>
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
				[common_browser_style]
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
				<b><font size=2>Frequency: <a href='?src=\ref[src];set_frequency=1'>[freq][multifreq ? "" : "kHz"]</a><br><br>
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
				[common_browser_style]
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
				<b><font size=2>Frequency: <a href='?src=\ref[src];set_frequency=1'>[freq][multifreq ? "" : "kHz"]</a><br><br>
				Transmitter: <a href='?src=\ref[src];transmitter=1'>[transmitter_on ? "ON" : "OFF"]</a><br><br>
				</font></b><br>
				</body>
				</html>
				<br>
				"},  "window=artillery_window;border=1;can_close=1;can_resize=1;can_minimize=0;titlebar=1;size=500x500")

/obj/structure/radio/proc/broadcast(var/msg, var/mob/living/human/speaker)

	// ignore emotes.
	if (dd_hasprefix(msg, "*"))
		return
	if (!transmitter || !transmitter_on)
		return
	var/list/tried_mobs = list()

	for (var/mob/living/human/hearer in human_mob_list)
		if (tried_mobs.Find(hearer))
			continue
		tried_mobs += hearer
		var/list/used_radios = list()
		if (hearer.stat == CONSCIOUS)
			var/list/radios = list()
			for (var/obj/structure/radio/radio in view(7, hearer))
				if (radio.receiver_on)
					radios |= radio
				if (used_radios.Find(radio))
					continue
				used_radios += radio
				if (check_freq(radio) && radio.receiver_on && (radio.check_power() || radio.powerneeded == 0))
					hearer.hear_radio(msg, speaker.default_language, speaker, radio, src)
			for (var/obj/item/weapon/radio/radio in view(2,hearer))
				if (isturf(radio.loc) && radio.receiver_on)
					radios |= radio
				if (used_radios.Find(radio))
					continue
				used_radios += radio
				if (check_freq(radio) && radio.receiver_on)
					hearer.hear_radio(msg, speaker.default_language, speaker, radio, src)
			for (var/obj/item/weapon/radio/radio in hearer.contents)
				if (radio.receiver_on)
					radios |= radio
				if (used_radios.Find(radio))
					continue
				used_radios += radio
				if (check_freq(radio) && radio.receiver_on)
					hearer.hear_radio(msg, speaker.default_language, speaker, radio, src)
	// let observers hear it
	// let observers hear it
	for (var/mob/observer/O in mob_list)
		O.hear_radio(msg, speaker.default_language, speaker, src, src)

//broadcasts an announcement on the Police/Emergency frequency
/proc/global_broadcast(var/tfreq, var/msg)

	var/list/tried_mobs = list()

	for (var/mob/living/human/hearer in human_mob_list)
		if (tried_mobs.Find(hearer))
			continue
		tried_mobs += hearer
		var/list/used_radios = list()
		if (hearer.stat == CONSCIOUS)
			var/list/radios = list()
			for (var/obj/structure/radio/radio in view(7, hearer))
				if (radio.receiver_on)
					radios |= radio
				if (used_radios.Find(radio))
					continue
				used_radios += radio
				if (radio.freq == tfreq && radio.receiver_on && (radio.check_power() || radio.powerneeded == 0))
					hearer.hear_radio_broadcast(msg, radio)
			for (var/obj/item/weapon/radio/radio in range(1,get_turf(src)))
				if (radio.receiver_on)
					radios |= radio
				if (used_radios.Find(radio))
					continue
				used_radios += radio
				if (radio.freq == tfreq && radio.receiver_on)
					hearer.hear_radio_broadcast(msg, radio)
			for (var/obj/item/weapon/radio/radio in hearer.contents)
				if (radio.receiver_on)
					radios |= radio
				if (used_radios.Find(radio))
					continue
				used_radios += radio
				if (radio.freq == tfreq && radio.receiver_on)
					hearer.hear_radio_broadcast(msg, radio)
	// let observers hear it
	for (var/mob/observer/O in mob_list)
		O.hear_radio_broadcast(msg, null)

/mob/proc/hear_radio_broadcast(var/message, var/obj/origin = null, var/obj/destination = null)

	if (!client || !message)
		return

	message = capitalize(message)
	if (origin && !destination)
		destination = origin
	if (sleeping || stat==1) //If unconscious or sleeping
		hear_sleep(message)
		return

	if ((sdisabilities & DEAF) || ear_deaf || find_trait("Deaf"))
		if (prob(20))
			src << "<span class='warning'>You feel the radio vibrate but can hear nothing from it!</span>"
	else
		var/fontsize = 2
		var/full_message = ""
		if (origin)
			if (istype(origin, /obj/structure/radio))
				var/obj/structure/radio/RD = origin
				if (RD)
					full_message = "<font size = [fontsize] color=#FFAE19><b>[origin.name], <i>[RD.freq] kHz</i>:</font></b><font size = [fontsize]> <b>Dispatch</b>: \"[message]\"</font>"
			else
				var/obj/item/weapon/radio/RD = origin
				if (RD)
					full_message = "<font size = [fontsize] color=#FFAE19><b>[origin.name], <i>[RD.freq] kHz</i>:</font></b><font size = [fontsize]> <b>Dispatch</b>: \"[message]\"</font>"
		else
			full_message = "<font size = [fontsize] color=#FFAE19><b>Radio:</font></b><font size = [fontsize]>\"[message]\"</font>"
		on_hear_obj(destination, full_message)

////////////////PORTABLE RADIOS//////////////////
/obj/item/weapon/radio
	name = "portable radio"
	desc = "Used to communicate with distant places. Set to 150kHz."
	icon = 'icons/obj/device.dmi'
	icon_state = "portable_radio3"
	item_state = "portable_radio3"
	flammable = FALSE
	density = FALSE
	opacity = FALSE
	var/freq = 150 //150 to 300
	var/receiver = TRUE
	var/transmitter = TRUE
	var/receiver_on = TRUE
	var/transmitter_on = TRUE
	var/mob/user = null
	powerneeded = 0
	var/on = FALSE
	force = 4.0
	throwforce = 3.0

	var/multifreq = FALSE
	var/list/multifreqlist = list(150)
	var/list/multifreqlist_selectable = list(150)
	attack_verb = list("bashed", "bludgeoned", "whacked")
	sharp = FALSE
	edge = FALSE
	w_class = ITEM_SIZE_LARGE
	slot_flags = SLOT_BACK
	nothrow = TRUE
/obj/item/weapon/radio/faction1/New()
	..()
	freq = FREQ1
	desc = "Used to communicate with distant places. Set to [freq]kHz."
/obj/item/weapon/radio/faction1/spaceradio
	icon_state = "portable_radio5"
	item_state = "portable_radio5"
/obj/item/weapon/radio/faction2/New()
	..()
	freq = FREQ2
	desc = "Used to communicate with distant places. Set to [freq]kHz."

/obj/item/weapon/radio/faction2/spaceradio
	icon_state = "portable_radio5"
	item_state = "portable_radio5"
/obj/item/weapon/radio/attack_self(mob/user)
	interact(user)

/obj/item/weapon/radio/interact(var/mob/m)
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

/obj/item/weapon/radio/Topic(href, href_list, hsrc)

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
		if (multifreq)
			var/input = WWinput(user, "Choose the frequency to broadcast to:", "Radio", freq, multifreqlist_selectable)
			if (!input || input == freq)
				return
			freq = input
			user << "Frequency set to <b>[freq]</b>."
			do_html(user)
			return
		else
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


/obj/item/weapon/radio/verb/name_radio()
	set category = null
	set name = "Name"
	set desc = "Name this radio."

	set src in view(1)
	var/yn = input(usr, "Name this radio?") in list("Yes", "No")
	if (yn == "Yes")
		var/_name = input(usr, "What name?") as text
		name = sanitize(_name, 20)
	return

/obj/item/weapon/radio/proc/do_html(var/mob/m)
	var/style = "PORTABLE RADIO"
	if (m)
		m << browse({"

		<br>
		<html>

		<head>
		[common_browser_style]
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
		<b><font size=2>Frequency: <a href='?src=\ref[src];set_frequency=1'>[freq][multifreq ? "" : "kHz"]</a><br><br>
		Transmitter: <a href='?src=\ref[src];transmitter=1'>[transmitter_on ? "ON" : "OFF"]</a><br><br>
		Receiver: <a href='?src=\ref[src];receiver=1'>[receiver_on ? "ON" : "OFF"]</a><br><br>
		</font></b><br>
		</body>
		</html>
		<br>
		"},  "window=artillery_window;border=1;can_close=1;can_resize=1;can_minimize=0;titlebar=1;size=500x500")

/obj/item/weapon/radio/proc/broadcast(var/msg, var/mob/living/human/speaker)

	// ignore emotes.
	if (dd_hasprefix(msg, "*"))
		return
	if (!transmitter || !transmitter_on)
		return
	var/list/tried_mobs = list()

	for (var/mob/living/human/hearer in human_mob_list)
		if (tried_mobs.Find(hearer))
			continue
		tried_mobs += hearer
		var/list/used_radios = list()
		if (hearer.stat == CONSCIOUS)
			var/list/radios = list()
			for (var/obj/structure/radio/radio in view(7, hearer))
				if (radio.receiver_on)
					radios |= radio
				if (used_radios.Find(radio))
					continue
				used_radios += radio
				if (check_freq(radio) && radio.receiver_on && (radio.check_power() || radio.powerneeded == 0))
					hearer.hear_radio(msg, speaker.default_language, speaker, radio, src)
			for (var/obj/item/weapon/radio/radio in view(2,hearer))
				if (isturf(radio.loc) && radio.receiver_on)
					radios |= radio
				if (used_radios.Find(radio))
					continue
				used_radios += radio
				if (check_freq(radio) && radio.receiver_on)
					hearer.hear_radio(msg, speaker.default_language, speaker, radio, src)
			for (var/obj/item/weapon/radio/radio in hearer.contents)
				if (radio.receiver_on)
					radios |= radio
				if (used_radios.Find(radio))
					continue
				used_radios += radio
				if (check_freq(radio) && radio.receiver_on)
					hearer.hear_radio(msg, speaker.default_language, speaker, radio, src)
	// let observers hear it
	for (var/mob/observer/O in mob_list)
		O.hear_radio(msg, speaker.default_language, speaker, src, src)

/obj/item/weapon/radio/galacticbattles
	name = "portable communications backpack"
	desc = "Used to communicate with others from a far. Set to 150kHz."
	icon = 'icons/obj/device.dmi'
	icon_state = "portable_radio5"
	item_state = "portable_radio5"
	flammable = FALSE
	density = FALSE
	opacity = FALSE
	powerneeded = 0
	force = 4.0
	throwforce = 3.0

//////////////"POUCH SLOT" RADIOS///////////////////////////
//For modern radios worn on your chest
/obj/item/weapon/radio/walkietalkie
	name = "walkie-talkie radio"
	desc = "Used to communicate with distant places. Set to 150kHz."
	icon = 'icons/obj/device.dmi'
	icon_state = "portable_radio4"
	item_state = "portable_radio4"
	flammable = FALSE
	density = FALSE
	opacity = FALSE
	powerneeded = 0
	w_class = ITEM_SIZE_SMALL
	slot_flags = SLOT_BELT|SLOT_ID
	nothrow = FALSE
	icon_override = 'icons/mob/pouch.dmi'

/obj/item/weapon/radio/walkietalkie/faction1/New()
	..()
	freq = FREQ1
	desc = "Used to communicate with distant places. Set to [freq]kHz."




/obj/item/weapon/radio/walkietalkie/faction2/New()
	..()
	freq = FREQ2
	desc = "Used to communicate with distant places. Set to [freq]kHz."

/obj/item/weapon/radio/walkietalkie/faction1/earradio1
	icon_state = "radio_headset"
	item_state = "radio_headset"
	slot_flags = SLOT_EARS | SLOT_TWOEARS
	var/ear_safety = 2

/obj/item/weapon/radio/walkietalkie/faction2/earradio2
	icon_state = "radio_headset"
	item_state = "radio_headset"
	slot_flags = SLOT_EARS | SLOT_TWOEARS
	var/ear_safety = 2

/obj/item/weapon/radio/walkietalkie/faction1/comlink
	name = "comlink"
	icon_state = "comlink"
	item_state = "comlink"

/obj/item/weapon/radio/walkietalkie/faction2/comlink
	name = "comlink"
	icon_state = "comlink"
	item_state = "comlink"

/obj/item/weapon/radio/walkietalkie/factionred/New()
	..()
	freq = FREQR
	desc = "Used to communicate with distant places. Set to [freq]kHz."

/obj/item/weapon/radio/walkietalkie/factionblue/New()
	..()
	freq = FREQB
	desc = "Used to communicate with distant places. Set to [freq]kHz."
/obj/item/weapon/radio/walkietalkie/factionyellow/New()
	..()
	freq = FREQY
	desc = "Used to communicate with distant places. Set to [freq]kHz."
/obj/item/weapon/radio/walkietalkie/factiongreen/New()
	..()
	freq = FREQG
	desc = "Used to communicate with distant places. Set to [freq]kHz."
/obj/item/weapon/radio/walkietalkie/factionmckellen/New()
	..()
	freq = FREQM
	desc = "Used to communicate with distant places. Set to [freq]kHz."
/obj/item/weapon/radio/walkietalkie/factionpolice/New()
	..()
	freq = FREQP
	desc = "Used to communicate with distant places. Set to [freq]kHz."

/obj/item/weapon/radio/walkietalkie/red/New()
	..()
	name = "Red radio"
	freq = "Red (private)"
	multifreq = TRUE
	multifreqlist = list("Red (private)","Blue to Red","Red to Blue","Green to Red","Red to Green","Yellow to Red", "Red to Yellow")
	multifreqlist_selectable = list("Red (private)","Red to Blue","Red to Green","Red to Yellow")
	desc = "Used to communicate with distant places."
/obj/item/weapon/radio/walkietalkie/green/New()
	..()
	name = "Green radio"
	freq = "Green (private)"
	multifreq = TRUE
	multifreqlist = list("Green (private)","Blue to Green","Green to Blue","Red to Green","Green to Red", "Yellow to Green", "Green to Yellow")
	multifreqlist_selectable = list("Green (private)","Green to Blue","Green to Red","Green to Yellow")
	desc = "Used to communicate with distant places."
/obj/item/weapon/radio/walkietalkie/blue/New()
	..()
	name = "Blue radio"
	freq = "Blue (private)"
	multifreq = TRUE
	multifreqlist = list("Blue (private)","Red to Blue","Blue to Red","Green to Blue","Blue to Green","Yellow to Blue", "Blue to Yellow")
	multifreqlist_selectable = list("Blue (private)","Blue to Red","Blue to Green","Blue to Yellow")
	desc = "Used to communicate with distant places."
/obj/item/weapon/radio/walkietalkie/yellow/New()
	..()
	name = "Yellow radio"
	freq = "Yellow (private)"
	multifreq = TRUE
	multifreqlist = list("Yellow (private)","Blue to Yellow","Yellow to Blue","Green to Yellow","Yellow to Green","Red to Yellow", "Yellow to Red")
	multifreqlist_selectable = list("Yellow (private)","Yellow to Blue","Yellow to Green","Yellow to Red")
	desc = "Used to communicate with distant places."

/obj/item/weapon/radio/proc/check_freq(var/obj/original)
	if (!original)
		return
	var/obj/item/weapon/radio/R = null
	var/obj/structure/radio/SR = null
	if (istype(original, /obj/item/weapon/radio))
		R = original
	else if (istype(original, /obj/structure/radio))
		SR = original
	else
		return FALSE
	if (SR)
		if (multifreq)
			if (SR.freq in src.multifreqlist)
				return TRUE
		else
			if (SR.freq == src.freq)
				return TRUE
	else if (R)
		if (multifreq)
			if (R.freq in src.multifreqlist)
				return TRUE
		else
			if (R.freq == src.freq)
				return TRUE
	return FALSE
/obj/structure/radio/proc/check_freq(var/obj/original)
	if (!original)
		return
	var/obj/item/weapon/radio/R = null
	var/obj/structure/radio/SR = null
	if (istype(original, /obj/item/weapon/radio))
		R = original
	else if (istype(original, /obj/structure/radio))
		SR = original
	else
		return FALSE
	if (SR)
		if (multifreq)
			if (SR.freq in src.multifreqlist)
				return TRUE
		else
			if (SR.freq == src.freq)
				return TRUE
	else if (R)
		if (multifreq)
			if (R.freq in src.multifreqlist)
				return TRUE
		else
			if (R.freq == src.freq)
				return TRUE
	return FALSE

/proc/reploc(message,mob/living/human/speaker)
	if (map.ID == MAP_CAMPAIGN)
		return "Reporting in, current location is [speaker.get_coded_loc(speaker)] ([speaker.x],[speaker.y])."
	else
		return message
/proc/ten_code(message,mob/living/human/speaker)
	if (!speaker)
		return message
	if (speaker.civilization != "Sheriff Office")
		return message
	var/dmessage = message
	dmessage = splittext(dmessage,"10-")
	var/tcode = copytext(dmessage[2],1)
	var/converted = FALSE
	switch(tcode)
		if ("0")
			converted = TRUE
			dmessage = "10-0: <b>On my way</b>, currently at [speaker.get_coded_loc(speaker)] ([speaker.x],[speaker.y])."
		if ("1")
			converted = TRUE
			dmessage = "10-1: Reporting in, current location is [speaker.get_coded_loc(speaker)] ([speaker.x],[speaker.y])."
		if ("2")
			converted = TRUE
			dmessage = "10-2: Reporting in, currently available."
		if ("3")
			converted = TRUE
			dmessage = "10-3: Reporting in, currently busy."
		if ("4")
			converted = TRUE
			dmessage = "10-4: Affirmative!"
		if ("5")
			converted = TRUE
			dmessage = "10-5: Negative!"
		if ("6")
			converted = TRUE
			dmessage = "10-6: Returning to the station."
		if ("7")
			converted = TRUE
			dmessage = "10-7: Prisoner in custody."
		if ("8")
			converted = TRUE
			dmessage = "10-8: NEED IMMEDIATE ASSISTANCE AT [speaker.get_coded_loc()] ([speaker.x],[speaker.y])!"

	if (converted)
		return dmessage
	else
		return message