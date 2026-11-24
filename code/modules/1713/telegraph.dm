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
	var/yn = player_input(usr, "Name this telegraph?", null, null, "anything", list("Yes", "No"), FALSE)
	if (yn == "Yes")
		var/_name = player_input(usr, "What name?", null, null, "text", null, FALSE)
		name = sanitize(_name, 20)
	return

/obj/structure/telegraph/proc/transmit(var/msg, var/stripmsg)
	if (!msg)
		return
	for (var/obj/structure/phoneline/PL in range(2,src))
		PL.transmit(msg,stripmsg,src,PL,list())
		return

// A clinic notice and its copies carry a short reference. This sends only an
// acknowledgement for that reference, not the request's paper text or metadata.
/obj/structure/telegraph/verb/confirm_clinic_shipment()
	set category = null
	set name = "Confirm Clinic Shipment"
	set src in view(1)
	var/mob/living/human/H = usr
	if (!istype(H))
		return
	var/client/operator_client = H.client
	var/turf/terminal = get_turf(src)
	if (!clinic_operator_valid(H, operator_client, terminal))
		return
	var/destination = player_input(H, "Name of the receiving telegraph (from the posted request):", "Confirm Clinic Shipment", "", "text", null, FALSE)
	if (!destination || !clinic_operator_valid(H, operator_client, terminal))
		return
	var/reference = player_input(H, "Request reference (1 to 12 letters or digits):", "Confirm Clinic Shipment", "", "text", null, FALSE)
	if (!reference || !clinic_operator_valid(H, operator_client, terminal))
		return
	destination = lowertext(sanitize(destination, 20))
	reference = clinic_reference(reference)
	if (!destination || !reference)
		to_chat(H, SPAN_WARNING("Enter a station name and a request reference of 1 to 12 letters or digits."))
		return
	var/list/stations = list()
	for (var/obj/structure/phoneline/PL in range(2, src))
		PL.collect_clinic_stations(src, list(), stations)
		break
	var/obj/structure/telegraph/receiver = clinic_receiver(stations, destination)
	if (!receiver)
		to_chat(H, SPAN_WARNING("Shipment confirmation not sent: no unique, reachable station by that name. Check the line and station name, then try again."))
		return
	var/origin_label = html_encode(html_decode(name))
	var/payload = "Clinic shipment dispatched. Request [reference]. From [origin_label]."
	var/printed = receiver.receive("<b>[origin_label] to [receiver.clinic_station_label()]:</b> [payload]", payload)
	if (printed)
		to_chat(H, SPAN_NOTICE("Shipment confirmation reached [receiver.clinic_station_label()] and was printed."))
	else
		to_chat(H, SPAN_NOTICE("Shipment confirmation reached [receiver.clinic_station_label()], but no teleprinter recorded it."))

/obj/structure/telegraph/proc/clinic_operator_valid(mob/living/human/H, client/operator_client, turf/terminal)
	return !QDELETED(src) && !QDELETED(H) && operator_client && H.client == operator_client && operator_client.mob == H && !H.incapacitated() && terminal && loc == terminal && isturf(H.loc) && H.z == terminal.z && get_dist(H, src) <= 1

/obj/structure/telegraph/proc/clinic_station_label()
	return html_encode(html_decode(name))

/obj/structure/telegraph/proc/clinic_reference(value)
	if (!istext(value) || !length(value) || length(value) > 12)
		return null
	var/result = ""
	for (var/i = 1, i <= length(value), i++)
		var/character = text2ascii(value, i)
		switch (character)
			if (48 to 57, 65 to 90)
				result += ascii2text(character)
			if (97 to 122)
				result += ascii2text(character - 32)
			else
				return null
	return result

/obj/structure/telegraph/proc/clinic_receiver(list/stations, destination)
	var/obj/structure/telegraph/match = null
	for (var/obj/structure/telegraph/candidate in stations)
		if (candidate != src && lowertext(candidate.clinic_station_label()) == destination)
			if (match)
				return null
			match = candidate
	return match

/obj/structure/telegraph/proc/receive(var/msg, var/stripmsg)
	if (!msg || !stripmsg)
		return
	playsound(loc, 'sound/machines/telegraph.ogg', 65)
	visible_message(msg)
	var/printed = FALSE
	for (var/obj/structure/teleprinter/TP in range(1,src))
		if (TP.print(stripmsg))
			printed = TRUE
	return printed

/obj/structure/telegraph/attack_hand(var/mob/user as mob)
	var/message = player_input(usr, "Write a word. Up to 10 characters, no spaces, symbols or numbers.", null, null, "text", null, FALSE)
	message = sanitize(message, 10)
	message = convertmsg(message)
	if (message && message != "")
		var/stripmsg = message
		currmsg = "<b><font size=2 color=#FFAE19>\icon[getFlatIcon(src)] [name]:</b></font> \"...[message]...\""
		transmit(currmsg,stripmsg)
		nomad_request(user, stripmsg) // CARAVAN, MEDICINE and the like call the nomad clans
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
		var/obj/item/weapon/paper/document = W
		if (!isnull(document.document_record))
			to_chat(user, "This paper cannot be used in the teleprinter.")
			return
		if (isemptylist(inpaper))
			inpaper += W
			to_chat(user, "You put the paper in the teleprinter.")
			user.drop_from_inventory(W)
			W.forceMove(locate(0,0,0))
			icon_state = "teleprinter1"
			update_icon()
		else
			to_chat(user, "There already is a paper inside! Remove it first.")
			return

/obj/structure/teleprinter/attack_hand(var/mob/user as mob)
	for(var/obj/item/weapon/C in inpaper)
		to_chat(user, "You remove \the [C].")
		C.loc = get_turf(src)
		inpaper -= C
		icon_state = "teleprinter0"
		update_icon()
	return

/obj/structure/teleprinter/proc/print(var/new_text)
	if (isemptylist(inpaper))
		return FALSE
	var/entry = "<b><font face='Courier New'>Telegram at [roundduration2text_days()]: [new_text]</b></font><br>"
	var/cost = length(strip_html_properly(entry))
	var/printed = FALSE
	for (var/obj/item/weapon/paper/C in inpaper)
		if (C.gc_destroyed || !isnull(C.loc) || !isnull(C.document_record))
			continue
		if (C.free_space >= max(22, cost))
			C.info += entry
			C.free_space -= cost
			printed = TRUE
	return printed

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

// reached holds the telegraphs this transmission has already delivered to, so
// a telegraph within reach of two poles prints the message once (#6235).
/obj/structure/phoneline/proc/transmit(var/msg, var/stripmsg, var/obj/structure/telegraph/TL, var/obj/structure/phoneline/origin, var/list/reached = null)
	if (!msg || !TL)
		return
	if (world.time <= lastproc)
		return
	else
		// Mark this pole before forwarding so loops in the pole network end here.
		lastproc = world.time+3
		if (isnull(reached))
			reached = list()
		//left
		for (var/obj/structure/phoneline/PL in get_turf(locate(x-3,y,z)))
			if (PL != origin && PL != src)
				PL.transmit(msg,stripmsg,TL,src,reached)

		//right
		for (var/obj/structure/phoneline/PL in get_turf(locate(x+3,y,z)))
			if (PL != origin && PL != src)
				PL.transmit(msg,stripmsg,TL,src,reached)

		//up
		for (var/obj/structure/phoneline/PL in get_turf(locate(x,y+3,z)))
			if (PL != origin && PL != src)
				PL.transmit(msg,stripmsg,TL,src,reached)

		//down
		for (var/obj/structure/phoneline/PL in get_turf(locate(x,y-3,z)))
			if (PL != origin && PL != src)
				PL.transmit(msg,stripmsg,TL,src,reached)

		//right next to it
		for (var/obj/structure/phoneline/PL in range(1,src))
			if (PL != origin && PL != src)
				PL.transmit(msg,stripmsg,TL,src,reached)

		for (var/obj/structure/telegraph/TLG in range(2,src))
			if (TLG != TL && !(TLG in reached))
				reached += TLG
				TLG.receive(msg,stripmsg)
// A lookup must inspect the whole connected network without consuming the
// shared transmission cooldown. Keep traversal state local to this lookup.
/obj/structure/phoneline/proc/collect_clinic_stations(obj/structure/telegraph/TL, list/visited, list/reached)
	if (src in visited)
		return
	visited += src
	for (var/obj/structure/phoneline/PL in get_turf(locate(x-3,y,z)))
		PL.collect_clinic_stations(TL, visited, reached)
	for (var/obj/structure/phoneline/PL in get_turf(locate(x+3,y,z)))
		PL.collect_clinic_stations(TL, visited, reached)
	for (var/obj/structure/phoneline/PL in get_turf(locate(x,y+3,z)))
		PL.collect_clinic_stations(TL, visited, reached)
	for (var/obj/structure/phoneline/PL in get_turf(locate(x,y-3,z)))
		PL.collect_clinic_stations(TL, visited, reached)
	for (var/obj/structure/phoneline/PL in range(1,src))
		PL.collect_clinic_stations(TL, visited, reached)
	for (var/obj/structure/telegraph/TLG in range(2,src))
		if (TLG != TL && !(TLG in reached))
			reached += TLG

/obj/structure/phoneline/proc/ring_phone(var/target, var/origin, var/obj/item/weapon/telephone/originphone)
	if (!origin || !target)
		return
	if (world.time <= lastproc)
		return
	else
		// Mark this pole before forwarding so loops in the pole network end here.
		lastproc = world.time+3
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
		var/input3 = player_input(usr, "What phrase? Maximum 100 characters.", null, null, "text", null, FALSE)
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
		to_chat(usr, "You turn the [src] off.")
		on = FALSE
		update_icon()
		return
	else
		to_chat(usr, "You turn the [src] on.")
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
