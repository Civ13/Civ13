// The Barracks annex: the level above the Barracks (stairs in the arrival hall)
// holds the Red and Blue faction conference rooms, a joint briefing room, a
// race circuit and an airfield; the level above that is open sky for flying.
// Faction rooms open only for their members, coordinators and admins.

#define BARRACKS_FACTIONS_FILE "data/tdm_barracks/factions.json"
#define BARRACKS_ORDERS_FILE "data/tdm_barracks/orders.json"
#define BARRACKS_RED "Red"
#define BARRACKS_BLUE "Blue"
#define BARRACKS_COORDINATOR "Coordinator"
// Deciseconds between two vehicles from one bay.
#define BARRACKS_BAY_COOLDOWN 600

// -- areas ----------------------------------------------------------------------------

/area/caribbean/barracks/annex
	name = "Barracks Annex"
	icon_state = "blue1"

/area/caribbean/barracks/annex/briefing
	name = "Barracks Briefing Room"

/area/caribbean/barracks/annex/faction_room
	name = "Red Faction Conference Room"
	icon_state = "red1"
	var/faction = BARRACKS_RED

/area/caribbean/barracks/annex/faction_room/red

/area/caribbean/barracks/annex/faction_room/coordinator
	name = "Barracks Coordinators' Office"
	icon_state = "yellow"
	faction = BARRACKS_COORDINATOR

/area/caribbean/barracks/annex/faction_room/blue
	name = "Blue Faction Conference Room"
	icon_state = "blue2"
	faction = BARRACKS_BLUE

// Someone who slips in behind a member is walked back out.
/area/caribbean/barracks/annex/faction_room/Entered(atom/movable/A, atom/OldLoc)
	..()
	if (!ismob(A) || !isturf(OldLoc) || get_area(OldLoc) == src)
		return
	var/mob/M = A
	if (!M.client || isobserver(M) || barracks_faction_admits(M, faction))
		return
	M.forceMove(OldLoc)
	to_chat(M, SPAN_WARNING(faction == BARRACKS_COORDINATOR ? "This office is for coordinators and admins." : "This room is for the [faction] faction. Ask a coordinator to put you on the roster."))

/area/caribbean/barracks/annex/track
	name = "Barracks Race Circuit"
	icon_state = "yellow"

/area/caribbean/barracks/annex/airfield
	name = "Barracks Airfield"
	icon_state = "purple"

/area/caribbean/barracks/annex/sky
	name = "Barracks Sky"
	icon_state = "white"

// -- faction roster -------------------------------------------------------------------
// ckey -> Red, Blue or Coordinator. Admins and coordinators open both rooms.

var/global/list/barracks_factions = null

/proc/barracks_faction_roster()
	if (islist(barracks_factions))
		return barracks_factions
	barracks_factions = list()
	if (!fexists(BARRACKS_FACTIONS_FILE))
		return barracks_factions
	var/list/saved = null
	try
		saved = json_decode(file2text(BARRACKS_FACTIONS_FILE))
	catch
		saved = null
	if (!islist(saved))
		log_game("TDM barracks: [BARRACKS_FACTIONS_FILE] is not readable; starting an empty roster.")
		return barracks_factions
	for (var/ckey in saved)
		var/role = saved[ckey]
		if (istext(ckey) && (role in list(BARRACKS_RED, BARRACKS_BLUE, BARRACKS_COORDINATOR)))
			barracks_factions[ckey] = role
	return barracks_factions

/proc/barracks_faction_save()
	var/text = json_encode(barracks_faction_roster())
	var/temporary = "[BARRACKS_FACTIONS_FILE].new"
	fdel(temporary)
	if (!text2file(text, temporary))
		log_game("TDM barracks: could not write [temporary].")
		return FALSE
	fdel(BARRACKS_FACTIONS_FILE)
	fcopy(temporary, BARRACKS_FACTIONS_FILE)
	fdel(temporary)
	return TRUE

/proc/barracks_faction_of(mob/M)
	if (!M || !M.ckey)
		return null
	return barracks_faction_roster()[M.ckey]

/proc/barracks_faction_admits(mob/M, faction)
	if (!M || !M.ckey)
		return FALSE
	if (M.client && M.client.holder)
		return TRUE
	var/role = barracks_faction_of(M)
	return role && (role == faction || role == BARRACKS_COORDINATOR)

/proc/barracks_faction_names(role)
	. = list()
	var/list/roster = barracks_faction_roster()
	for (var/ckey in roster)
		if (roster[ckey] == role)
			. += ckey

// -- faction doors --------------------------------------------------------------------

/obj/structure/simple_door/key_door/faction_door/barracks
	name = "faction door"
	breachable = FALSE
	faction = BARRACKS_RED

/obj/structure/simple_door/key_door/faction_door/barracks/red
	name = "Red faction door"
	faction = BARRACKS_RED

/obj/structure/simple_door/key_door/faction_door/barracks/blue
	name = "Blue faction door"
	faction = BARRACKS_BLUE

/obj/structure/simple_door/key_door/faction_door/barracks/coordinator
	name = "coordinators' door"
	faction = BARRACKS_COORDINATOR

/obj/structure/simple_door/key_door/faction_door/barracks/examine(mob/user)
	..()
	to_chat(user, SPAN_NOTICE("It opens for the [faction] faction, its coordinators and admins."))

/obj/structure/simple_door/key_door/faction_door/barracks/door_hand_locked(mob/user)
	return !barracks_faction_admits(user, faction)

/obj/structure/simple_door/key_door/faction_door/barracks/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/lockpick))
		to_chat(user, SPAN_WARNING("This lock does not take a pick."))
		return
	return attack_hand(user)

/obj/structure/simple_door/key_door/faction_door/barracks/Bumped(atom/user)
	if (!ismob(user))
		return
	if (barracks_faction_admits(user, faction))
		if (!state && !isSwitchingStates)
			Open()
		return
	var/mob/M = user
	if (!door_noise_ready())
		return
	M.visible_message(SPAN_NOTICE("[M] knocks at the door."), SPAN_NOTICE("You knock at the door. It opens only for the [faction] faction."))
	playsound(get_turf(src), "doorknock", 75, TRUE)

/obj/structure/simple_door/key_door/faction_door/barracks/Crossed(atom/movable/A)
	if (ismob(A) && state)
		close_behind()

/obj/structure/simple_door/key_door/faction_door/barracks/proc/close_behind()
	set waitfor = FALSE
	sleep(10)
	if (QDELETED(src) || !state || isSwitchingStates)
		return
	for (var/mob/living/L in loc)
		return
	Close()

/obj/structure/simple_door/key_door/faction_door/barracks/ex_act(severity)
	return

/obj/structure/simple_door/key_door/faction_door/barracks/bullet_act(obj/item/projectile/P, def_zone)
	return

// -- the roster board -----------------------------------------------------------------

/obj/structure/barracks/faction_roster
	name = "faction roster"
	desc = "Who sits in the Red and Blue conference rooms for the next faction event. Admins and coordinators keep it."
	icon = 'icons/obj/decals.dmi'
	icon_state = "map_board"
	density = FALSE

/obj/structure/barracks/faction_roster/examine(mob/user)
	..()
	if (user)
		var/role = barracks_faction_of(user)
		to_chat(user, SPAN_NOTICE(role ? "You are on the roster as [role]." : "You are not on the roster."))

/obj/structure/barracks/faction_roster/proc/roster_text()
	var/list/lines = list()
	for (var/role in list(BARRACKS_RED, BARRACKS_BLUE, BARRACKS_COORDINATOR))
		var/list/names = barracks_faction_names(role)
		lines += "[role]: [names.len ? jointext(names, ", ") : "nobody"]."
	return jointext(lines, " ")

/obj/structure/barracks/faction_roster/attack_hand(mob/user)
	if (!user || !user.client)
		return
	var/manager = user.client.holder || barracks_faction_of(user) == BARRACKS_COORDINATOR
	if (!manager)
		to_chat(user, SPAN_NOTICE(roster_text()))
		return
	var/list/options = list("Close", "Add to Red", "Add to Blue", "Add a coordinator", "Remove someone", "Clear Red and Blue")
	var/choice = WWinput(user, roster_text(), "Faction Roster", "Close", options)
	switch (choice)
		if ("Add to Red")
			add_member(user, BARRACKS_RED)
		if ("Add to Blue")
			add_member(user, BARRACKS_BLUE)
		if ("Add a coordinator")
			if (!user.client.holder)
				to_chat(user, SPAN_WARNING("Only admins add coordinators."))
				return
			add_member(user, BARRACKS_COORDINATOR)
		if ("Remove someone")
			var/list/roster = barracks_faction_roster()
			if (!roster.len)
				to_chat(user, SPAN_NOTICE("The roster is empty."))
				return
			var/list/names = list("Cancel") + roster
			var/who = WWinput(user, "Take whom off the roster?", "Faction Roster", "Cancel", names)
			if (!who || who == "Cancel" || !(who in roster))
				return
			if (roster[who] == BARRACKS_COORDINATOR && !user.client.holder)
				to_chat(user, SPAN_WARNING("Only admins remove coordinators."))
				return
			roster -= who
			barracks_faction_save()
			log_admin("[key_name(user)] removed [who] from the Barracks faction roster.")
			to_chat(user, SPAN_NOTICE("[who] is off the roster."))
		if ("Clear Red and Blue")
			var/list/roster = barracks_faction_roster()
			for (var/ckey in roster.Copy())
				if (roster[ckey] != BARRACKS_COORDINATOR)
					roster -= ckey
			barracks_faction_save()
			log_admin("[key_name(user)] cleared the Red and Blue Barracks faction rosters.")
			to_chat(user, SPAN_NOTICE("Red and Blue are cleared; coordinators stay."))

/obj/structure/barracks/faction_roster/proc/add_member(mob/user, role)
	var/list/names = list("Cancel")
	for (var/client/C in clients)
		if (C.ckey)
			names += C.ckey
	var/who = WWinput(user, "Who joins [role]? Players online now:", "Faction Roster", "Cancel", names)
	if (!who || who == "Cancel")
		return
	var/list/roster = barracks_faction_roster()
	roster[who] = role
	barracks_faction_save()
	log_admin("[key_name(user)] put [who] on the Barracks faction roster as [role].")
	to_chat(user, SPAN_NOTICE("[who] is on the roster as [role]."))
	for (var/client/C in clients)
		if (C.ckey == who && C.mob)
			to_chat(C.mob, SPAN_NOTICE("You are on the Barracks faction roster as [role]. The conference rooms are up the annex stairs in the arrival hall."))

// -- orders boards --------------------------------------------------------------------
// A faction's written orders (or, with no faction, the public event programme).
// Admins and coordinators write them; they last across restarts.

var/global/list/barracks_orders = null

/proc/barracks_orders_list()
	if (islist(barracks_orders))
		return barracks_orders
	barracks_orders = list()
	if (fexists(BARRACKS_ORDERS_FILE))
		var/list/saved = null
		try
			saved = json_decode(file2text(BARRACKS_ORDERS_FILE))
		catch
			saved = null
		if (islist(saved))
			for (var/board in saved)
				if (istext(board) && istext(saved[board]))
					barracks_orders[board] = saved[board]
	return barracks_orders

/proc/barracks_orders_save()
	var/text = json_encode(barracks_orders_list())
	var/temporary = "[BARRACKS_ORDERS_FILE].new"
	fdel(temporary)
	if (!text2file(text, temporary))
		log_game("TDM barracks: could not write [temporary].")
		return FALSE
	fdel(BARRACKS_ORDERS_FILE)
	fcopy(temporary, BARRACKS_ORDERS_FILE)
	fdel(temporary)
	return TRUE

/obj/structure/barracks/orders_board
	name = "event programme"
	desc = "The programme for the next faction event, kept by the coordinators."
	icon = 'icons/obj/decals.dmi'
	icon_state = "map_board"
	density = FALSE
	var/faction = null

/obj/structure/barracks/orders_board/red
	name = "Red orders board"
	desc = "The coordinators' orders for the Red faction."
	faction = BARRACKS_RED

/obj/structure/barracks/orders_board/blue
	name = "Blue orders board"
	desc = "The coordinators' orders for the Blue faction."
	faction = BARRACKS_BLUE

/obj/structure/barracks/orders_board/proc/board_key()
	return faction ? faction : "programme"

/obj/structure/barracks/orders_board/attack_hand(mob/user)
	if (!user || !user.client)
		return
	if (faction && !barracks_faction_admits(user, faction))
		to_chat(user, SPAN_WARNING("These orders are for the [faction] faction."))
		return
	var/text = barracks_orders_list()[board_key()]
	var/datum/browser/popup = new(user, "barracks_orders", name, 460, 460)
	popup.set_content(text ? replacetext(html_encode(text), "\n", "<br>") : "Nothing is written yet.")
	popup.open()
	if (!user.client.holder && barracks_faction_of(user) != BARRACKS_COORDINATOR)
		return
	var/choice = WWinput(user, "Write new [faction ? "orders" : "programme"] on [src]?", name, "Close", list("Close", "Write new text"))
	if (choice != "Write new text")
		return
	var/new_text = player_input(user, "Up to 2000 characters. This replaces what is on the board.", name, text, "message", null, TRUE)
	if (isnull(new_text) || QDELETED(src))
		return
	new_text = copytext(new_text, 1, 2001)
	var/list/orders = barracks_orders_list()
	orders[board_key()] = new_text
	barracks_orders_save()
	log_admin("[key_name(user)] wrote the Barracks [board_key()] board.")
	for (var/mob/M in range(12, src))
		if (M.client)
			to_chat(M, SPAN_NOTICE("[user] updates \the [src]."))

// -- vehicle bays ---------------------------------------------------------------------
// Each bay builds one vehicle in the clear square northeast of its console, with
// fuel, whenever the square is empty. The doors lock, so whoever calls a car
// gets its key (a premade car with no door code can never be opened).

/obj/structure/barracks/vehicle_bay
	name = "motor pool console"
	desc = "Builds a fuelled practice vehicle in the bay beside it."
	icon = 'icons/obj/structures.dmi'
	icon_state = "workbench"
	var/model_name = "Yamasaki Shinobu"
	var/model = /obj/effects/premadevehicles/yamasaki/shinobu
	var/size = 5
	var/last_build = 0

/obj/structure/barracks/vehicle_bay/New()
	..()
	name = "[model_name] bay"
	barracks_bay_turfs |= bay_turfs()

/obj/structure/barracks/vehicle_bay/examine(mob/user)
	..()
	to_chat(user, SPAN_NOTICE("Click it to have a [model_name] built in the bay to its northeast. The bay must be empty."))

/obj/structure/barracks/vehicle_bay/proc/bay_turfs()
	return block(locate(x + 1, y + 1, z), locate(min(world.maxx, x + size), min(world.maxy, y + size), z))

/obj/structure/barracks/vehicle_bay/proc/bay_clear()
	for (var/turf/T in bay_turfs())
		if (T.density)
			return FALSE
		for (var/obj/structure/vehicleparts/V in T)
			return FALSE
		for (var/obj/structure/engine/E in T)
			return FALSE
		for (var/mob/living/L in T)
			return FALSE
	return TRUE

/obj/structure/barracks/vehicle_bay/attack_hand(mob/user)
	if (!ishuman(user))
		return
	if (last_build && world.time < last_build + BARRACKS_BAY_COOLDOWN)
		to_chat(user, SPAN_WARNING("The bay is still being cleaned. Try again in [round((last_build + BARRACKS_BAY_COOLDOWN - world.time) / 10)] seconds."))
		return
	if (!bay_clear())
		to_chat(user, SPAN_WARNING("The bay is not empty. Drive the last vehicle out, or stand clear, first."))
		return
	last_build = world.time
	build(user)
	user.visible_message(SPAN_NOTICE("[user] calls a [model_name] up in the bay."), SPAN_NOTICE("A [model_name] is being rolled into the bay."))

/obj/structure/barracks/vehicle_bay/proc/build(mob/user)
	var/obj/effects/premadevehicles/PV = new model(get_turf(src))
	PV.doorcode = rand(1000, 9999)
	PV.new_number()
	var/obj/item/weapon/key/civ/K = new(get_turf(user))
	K.name = "[PV.reg_number] key"
	K.icon_state = "modern"
	K.code = PV.doorcode
	user.put_in_hands(K)
	to_chat(user, SPAN_NOTICE("You take the [K.name]. Use it on a door of the car to unlock it."))

/obj/structure/barracks/vehicle_bay/piccolino
	model_name = "ASNO Piccolino"
	model = /obj/effects/premadevehicles/asno/piccolino

/obj/structure/barracks/vehicle_bay/falcon
	model_name = "SMC Falcon"
	model = /obj/effects/premadevehicles/smc/falcon

/obj/structure/barracks/vehicle_bay/erstenklasse
	model_name = "Ubermacht Erstenklasse"
	model = /obj/effects/premadevehicles/ubermacht/erstenklasse

/obj/structure/barracks/vehicle_bay/kazoku
	model_name = "Yamasaki Kazoku"
	model = /obj/effects/premadevehicles/yamasaki/kazoku

/obj/structure/barracks/vehicle_bay/quattroporte
	model_name = "ASNO Quattroporte"
	model = /obj/effects/premadevehicles/asno/quattroporte

/obj/structure/barracks/vehicle_bay/type95
	model_name = "Kurogane Type 95"
	model = /obj/effects/premadevehicles/kurogane/type95

/obj/structure/barracks/vehicle_bay/wyoming
	model_name = "SMC Wyoming"
	model = /obj/effects/premadevehicles/smc/wyoming

/obj/structure/barracks/vehicle_bay/plane
	name = "hangar console"
	desc = "Rolls a fuelled light plane out onto the apron beside it."
	model_name = "light plane"
	model = null
	size = 4

/obj/structure/barracks/vehicle_bay/plane/examine(mob/user)
	..()
	to_chat(user, SPAN_NOTICE("Taxi onto the runway and roll down it at full throttle: the plane lifts off by itself after 8 tiles. Descend at low speed to land, on the runway or on dry open ground (a rough landing). Weld the airframe to fix it after a crash."))

/obj/structure/barracks/vehicle_bay/plane/build(mob/user)
	build_light_plane(locate(x + 1, y + 1, z))

#undef BARRACKS_BAY_COOLDOWN
