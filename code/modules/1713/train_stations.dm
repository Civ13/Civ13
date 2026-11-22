// Stations and warnings (docs/trains.md#stations-and-warnings).
//
// - A station name board beside the line tells everybody aboard a train where
//   it is coming into, whichever way it runs.
// - The driver sounds the whistle (a horn on a diesel), heard far beyond
//   sight, and rings the bell.
// - In the dark a train needs a light at its leading end: the headlamp of
//   the engine that leads, or a hand lamp showing white on the leading car.
//   Without one it runs blind, at half speed.
// - The guard's hand lamp shows white, red or green. Showing red on the last
//   car it is the tail lamp the guard's journal looks for.

#define TRAIN_WHISTLE_RANGE 40
#define TRAIN_BELL_RANGE 12
#define TRAIN_HEADLAMP_RANGE 5
#define TRAIN_RUNNING_LIGHT 2

var/global/list/train_lamps = list()

/obj/structure/trains
	var/tmp/lamp_range = TRAIN_RUNNING_LIGHT // the light it shows while it moves at the head of a train

/obj/structure/trains/locomotive
	var/headlamp = FALSE // lit from the driver's stand
	var/tmp/running_blind = FALSE // in the dark with no light ahead

/proc/train_is_dark()
	return time_of_day == "Night" || time_of_day == "Dark Night"

/////////////////////////////////////////////////////////////////////////////
// Station name boards

/obj/structure/train_lineside/station
	name = "station name board"
	desc = "A long white board on two posts beside the line. Write the name of the station on it with a pen."
	icon_state = "station_board"
	var/station = null

/obj/structure/train_lineside/station/speaks_to(heading)
	return TRUE

// Names the station. TRUE when the board changed.
/obj/structure/train_lineside/station/proc/set_station(text)
	text = sanitize(text, 40)
	if (!text || text == station)
		return FALSE
	station = text
	name = "station name board ([station])"
	return TRUE

/obj/structure/train_lineside/station/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/pen))
		var/text = player_input(user, "What is this station called?", "[name]", station, "text", null, TRUE)
		if (!text || QDELETED(src) || !user || user.incapacitated() || get_dist(user, src) > 1)
			return
		if (set_station(text))
			user.visible_message("[user] letters \the [src].", "You letter the board: [station].")
		return
	return ..()

// Everybody aboard is told, not only the cab.
/obj/structure/train_lineside/station/sighting(obj/structure/trains/locomotive/L)
	if (!station || !L)
		return null
	for (var/mob/M in L.train_riders())
		to_chat(M, "The train is coming into <b>[station]</b>.")
	return null

/obj/structure/train_lineside/station/examine(mob/user)
	..()
	to_chat(user, station ? "It reads: [station]. Everybody aboard a train that comes up to it is told so." : "It is blank. Use a pen on it to name the station.")

// The people riding the train this engine drives.
/obj/structure/trains/locomotive/proc/train_riders()
	. = list()
	for (var/obj/structure/trains/car in train_consist_list(train_head()))
		for (var/turf/T in car.crash_tiles())
			for (var/mob/living/human/H in T)
				. |= H

/////////////////////////////////////////////////////////////////////////////
// Whistle and bell

/obj/structure/trains/locomotive/proc/whistle_name()
	return "whistle"

/obj/structure/trains/locomotive/heavy_diesel/whistle_name()
	return "horn"

// Sounds the whistle. Returns how many people out of sight heard it, or null
// when it made no sound.
/obj/structure/trains/locomotive/proc/sound_whistle(mob/user)
	if (!isturf(loc))
		return null
	if (!on || steam_factor() <= 0)
		if (user)
			to_chat(user, SPAN_WARNING(whistle_name() == "horn" ? "Start the engine first: the horn works off its air." : "There is no steam to blow the whistle with."))
		return null
	. = 0
	var/horn = (whistle_name() == "horn")
	playsound(loc, horn ? 'sound/effects/blowing_horn.ogg' : 'sound/effects/whistle.ogg', 100, FALSE, 10)
	visible_message("<b>\The [src]</b> sounds its [whistle_name()].")
	var/list/near = viewers(world.view, src)
	for (var/mob/living/human/H in human_mob_list)
		if (!H.client || H.stat != CONSCIOUS || H.z != z || (H in near) || get_dist(H, src) > TRAIN_WHISTLE_RANGE)
			continue
		to_chat(H, "You hear a train [whistle_name()] to the [dir2text(get_dir(H, src))].")
		.++

/obj/structure/trains/locomotive/proc/sound_bell(mob/user)
	if (!isturf(loc))
		return FALSE
	playsound(loc, 'sound/effects/handbell.ogg', 100, FALSE, TRAIN_BELL_RANGE - 7)
	visible_message("The bell of <b>\the [src]</b> rings.")
	return TRUE

/////////////////////////////////////////////////////////////////////////////
// Lamps

/obj/structure/trains/locomotive/proc/set_headlamp(state, mob/user)
	if (!!headlamp == !!state)
		return FALSE
	headlamp = !!state
	if (user)
		user.visible_message("[user] [headlamp ? "lights" : "puts out"] the headlamp of \the [src].", "You [headlamp ? "light" : "put out"] the headlamp.")
	if (driving)
		lead_factor = leading_factor(train_consist_list(train_head())) * night_factor()
	return TRUE

// A hand lamp showing this colour on the car, in a hand or set down.
/proc/train_lamp_on(obj/structure/trains/car, shade)
	if (!car || !train_lamps.len)
		return null
	var/list/tiles = null
	for (var/obj/item/train_lamp/L in train_lamps)
		if (QDELETED(L) || L.shade != shade)
			continue
		var/turf/where = get_turf(L)
		if (!where || where.z != car.z || get_dist(where, car) > 1)
			continue
		if (!tiles)
			tiles = car.crash_tiles()
		if (where in tiles)
			return L
	return null

// 1, or 0.5 when the train this engine drives runs in the dark with no
// light at its leading end. Also sets the light the leading car shows.
/obj/structure/trains/locomotive/proc/night_factor()
	var/way = train_way()
	var/obj/structure/trains/lead = (way > 0) ? drive_head : drive_tail
	if (!lead || QDELETED(lead))
		lead = src
	var/obj/structure/trains/locomotive/E = istype(lead, /obj/structure/trains/locomotive) ? lead : lead.unit_engine()
	var/lit = (E && E.headlamp)
	lead.lamp_range = lit ? TRAIN_HEADLAMP_RANGE : TRAIN_RUNNING_LIGHT
	lamp_range = headlamp ? TRAIN_HEADLAMP_RANGE : TRAIN_RUNNING_LIGHT
	var/was_blind = running_blind
	running_blind = FALSE
	if (!train_is_dark() || lit || train_lamp_on(lead, "white"))
		return 1
	running_blind = TRUE
	if (!was_blind && driving)
		for (var/mob/M in cab_crew())
			to_chat(M, SPAN_WARNING("It is dark and the train shows no light ahead: it runs blind, at half speed. Light the headlamp[E ? "" : ", or have somebody show a white lamp on the leading car"]."))
	return 0.5

/obj/structure/trains/locomotive/proc/night_text()
	if (running_blind)
		return " Running blind in the dark."
	return headlamp ? " Headlamp lit." : ""

// What the guard's journal says of the tail lamp (train_conductor.dm).
/proc/train_tail_lamp_text(list/cars)
	if (!cars || !cars.len)
		return ""
	return train_lamp_on(cars[cars.len], "red") ? " Tail lamp showing." : " No tail lamp on the last vehicle."

/obj/item/train_lamp
	name = "hand lamp"
	desc = "A railway hand lamp with a turning shade. Use it in your hand to show white, red or green, or to put it out. Showing red on the last car of a train it is the tail lamp; showing white on the leading car it lights the way for a train that is pushed."
	icon = 'icons/obj/vehicles/train_platforms.dmi'
	icon_state = "hand_lamp"
	w_class = 2
	force = 3
	throwforce = 3
	var/shade = null // null when out, else "white", "red" or "green"

/obj/item/train_lamp/New()
	..()
	train_lamps += src

/obj/item/train_lamp/Destroy()
	train_lamps -= src
	return ..()

// Turns the shade. Returns what the lamp shows now.
/obj/item/train_lamp/proc/set_shade(new_shade)
	if (!(new_shade in list("white", "red", "green")))
		new_shade = null
	shade = new_shade
	update_icon()
	return shade

/obj/item/train_lamp/update_icon()
	icon_state = shade ? "hand_lamp_[shade]" : "hand_lamp"
	switch (shade)
		if ("white")
			set_light(3, 1, "#fff2c8")
		if ("red")
			set_light(2, 1, "#ff4030")
		if ("green")
			set_light(2, 1, "#40e060")
		else
			set_light(0)

/obj/item/train_lamp/attack_self(mob/living/user)
	if (!istype(user) || user.incapacitated())
		return
	var/list/order = list(null, "white", "red", "green")
	var/at = order.Find(shade)
	set_shade(order[(at % order.len) + 1])
	playsound(user.loc, 'sound/effects/lever.ogg', 20, TRUE)
	to_chat(user, shade ? "You turn the shade: the lamp shows [shade]." : "You put the lamp out.")

/obj/item/train_lamp/examine(mob/user)
	..()
	to_chat(user, shade ? "It shows [shade]." : "It is out.")
	to_chat(user, "By night: white swung across the body is stop, green held steady is right away, red is danger.")

#undef TRAIN_WHISTLE_RANGE
#undef TRAIN_BELL_RANGE
#undef TRAIN_HEADLAMP_RANGE
#undef TRAIN_RUNNING_LIGHT
