// The annex race circuit, rally stage and sky lap: timing lines, lap and
// flight boards, race control with countdown races, and the sweep that clears
// vehicles nobody uses (the Barracks never reboots, so nothing else would).

#define BARRACKS_RECORDS_FILE "data/tdm_barracks/race_records.json"
// Deciseconds: one line crossing per vehicle per line (a car has several frames).
#define BARRACKS_LINE_DEBOUNCE 30
// A lap or run shorter than this is a vehicle wobbling on the line, not a lap.
#define BARRACKS_SHORTEST_RUN 50
#define BARRACKS_SWEEP_INTERVAL 1200
#define BARRACKS_SWEEP_IDLE 6000
#define BARRACKS_SWEEP_IDLE_MANUAL 1200
#define BARRACKS_RACE_LIMIT 6000

var/global/list/barracks_race_records = null
var/global/list/barracks_runs = list()
var/global/list/barracks_line_seen = list()
var/global/list/barracks_last_race = list()
var/global/datum/barracks_race/barracks_race = null
var/global/datum/barracks_vehicle_sweep/barracks_vehicle_sweep = null
var/global/list/barracks_bay_turfs = list()

/proc/barracks_track_name(track)
	switch (track)
		if ("circuit")
			return "circuit lap"
		if ("drag")
			return "drag strip"
		if ("rally")
			return "rally stage"
		if ("sky")
			return "sky lap"
	return track

/proc/barracks_records(track)
	if (!islist(barracks_race_records))
		barracks_race_records = list()
		if (fexists(BARRACKS_RECORDS_FILE))
			var/list/saved = null
			try
				saved = json_decode(file2text(BARRACKS_RECORDS_FILE))
			catch
				saved = null
			if (islist(saved))
				for (var/name in saved)
					if (istext(name) && islist(saved[name]))
						barracks_race_records[name] = saved[name]
	if (!islist(barracks_race_records[track]))
		barracks_race_records[track] = list()
	return barracks_race_records[track]

/proc/barracks_records_save()
	var/text = json_encode(barracks_race_records)
	var/temporary = "[BARRACKS_RECORDS_FILE].new"
	fdel(temporary)
	if (!text2file(text, temporary))
		log_game("TDM barracks: could not write [temporary].")
		return FALSE
	fdel(BARRACKS_RECORDS_FILE)
	fcopy(temporary, BARRACKS_RECORDS_FILE)
	fdel(temporary)
	return TRUE

// Adds a time to a track's top ten; returns the place it took, or 0.
/proc/barracks_record_time(track, seconds, who, vehicle)
	var/list/R = barracks_records(track)
	var/place = R.len + 1
	for (var/i = 1 to R.len)
		var/list/E = R[i]
		if (!islist(E) || seconds < E["seconds"])
			place = i
			break
	if (place > 10)
		return 0
	R.Insert(place, list(list("seconds" = seconds, "key" = who, "vehicle" = vehicle)))
	while (R.len > 10)
		R.Cut(R.len)
	barracks_records_save()
	return place

/proc/barracks_records_text(track, count = 10)
	var/list/R = barracks_records(track)
	if (!R.len)
		return "No [barracks_track_name(track)] times yet."
	var/list/lines = list()
	for (var/i = 1 to min(count, R.len))
		var/list/E = R[i]
		lines += "[i]. [E["key"]] - [E["seconds"]] s ([E["vehicle"]])"
	return jointext(lines, "<br>")

/proc/barracks_axis_pilot(obj/structure/vehicleparts/axis/A)
	if (A && A.driver && A.driver.key)
		return A.driver.key
	return "nobody at the wheel"

/proc/barracks_tell_near(atom/centre, text, range_tiles = 12)
	for (var/mob/M in range(range_tiles, centre))
		if (M.client)
			to_chat(M, text)

// -- timing lines -----------------------------------------------------------------------

/obj/effect/step_trigger/barracks_timing
	name = "timing line"
	stopper = FALSE
	var/track = "circuit"
	var/role = "lap"

/obj/effect/step_trigger/barracks_timing/Trigger(atom/movable/A)
	if (!istype(A, /obj/structure/vehicleparts/frame))
		return FALSE
	var/obj/structure/vehicleparts/frame/F = A
	var/obj/structure/vehicleparts/axis/V = F.axis
	if (!V)
		return FALSE
	var/seen_key = "\ref[V]|[track]|[role]"
	if (barracks_line_seen[seen_key] && world.time < barracks_line_seen[seen_key] + BARRACKS_LINE_DEBOUNCE)
		return FALSE
	barracks_line_seen[seen_key] = world.time
	var/run_key = "\ref[V]|[track]"
	var/started = barracks_runs[run_key]
	switch (role)
		if ("lap")
			if (started && world.time - started >= BARRACKS_SHORTEST_RUN)
				finish_run(V, started)
			barracks_runs[run_key] = world.time
			if (track == "circuit" && barracks_race)
				barracks_race.crossed(V)
		if ("start")
			barracks_runs[run_key] = world.time
			if (V.driver)
				to_chat(V.driver, SPAN_NOTICE("The [barracks_track_name(track)] clock is running."))
		if ("finish")
			if (started && world.time - started >= BARRACKS_SHORTEST_RUN)
				finish_run(V, started)
			barracks_runs -= run_key
	return TRUE

/obj/effect/step_trigger/barracks_timing/proc/finish_run(obj/structure/vehicleparts/axis/V, started)
	var/seconds = round((world.time - started) / 10, 0.1)
	var/who = barracks_axis_pilot(V)
	var/place = barracks_record_time(track, seconds, who, V.name)
	barracks_tell_near(src, SPAN_NOTICE("[who]: [barracks_track_name(track)] in [seconds] s[place ? ", number [place] on the board" : ""]."))

// -- lap boards -------------------------------------------------------------------------

/obj/structure/barracks/lap_board
	name = "lap board"
	desc = "The best times on the circuit."
	icon = 'icons/obj/decals.dmi'
	icon_state = "goldenplaque"
	density = FALSE
	var/track = "circuit"

/obj/structure/barracks/lap_board/New()
	..()
	name = "[barracks_track_name(track)] board"

/obj/structure/barracks/lap_board/examine(mob/user)
	..()
	if (user)
		to_chat(user, barracks_records_text(track, 3))

/obj/structure/barracks/lap_board/attack_hand(mob/user)
	if (!user || !user.client)
		return
	var/text = "<b>[capitalize(barracks_track_name(track))] - best ten</b><br>[barracks_records_text(track)]"
	if (track == "circuit" && barracks_last_race.len)
		text += "<br><br><b>Last race</b><br>[jointext(barracks_last_race, "<br>")]"
	var/datum/browser/popup = new(user, "barracks_lap_board", "Lap Board", 420, 420)
	popup.set_content(text)
	popup.open()
	if (user.client.holder || barracks_faction_of(user) == BARRACKS_COORDINATOR)
		var/choice = WWinput(user, "Reset the [barracks_track_name(track)] board?", "Lap Board", "Keep it", list("Keep it", "Reset the board"))
		if (choice == "Reset the board")
			var/list/R = barracks_records(track)
			R.Cut()
			barracks_records_save()
			log_admin("[key_name(user)] reset the Barracks [track] board.")
			to_chat(user, SPAN_NOTICE("The board is cleared."))

// -- races ------------------------------------------------------------------------------

/datum/barracks_race
	var/laps = 3
	var/go_time = 0
	var/list/counts = list()
	var/list/finishers = list()
	var/obj/structure/barracks/race_control/control

/datum/barracks_race/proc/announce(text)
	for (var/client/C in clients)
		if (C.mob && istype(get_area(C.mob), /area/caribbean/barracks/annex/track))
			to_chat(C.mob, text)

/datum/barracks_race/proc/begin()
	set waitfor = FALSE
	announce(SPAN_NOTICE("<b>A [laps]-lap race starts in five seconds.</b> Line up behind the white line."))
	for (var/n = 5, n >= 1, n--)
		announce(SPAN_NOTICE("[n]..."))
		sleep(10)
	if (barracks_race != src)
		return
	go_time = world.time
	announce(SPAN_NOTICE("<b>GO!</b>"))
	if (control)
		playsound(get_turf(control), 'sound/effects/football_whistle.ogg', 100, 1)
	sleep(BARRACKS_RACE_LIMIT)
	if (barracks_race == src)
		finish("time is up")

// Every start/finish crossing after GO: the first starts the car's count.
/datum/barracks_race/proc/crossed(obj/structure/vehicleparts/axis/V)
	if (!go_time)
		return
	var/key = "\ref[V]"
	if (key in finishers)
		return
	if (!(key in counts))
		counts[key] = 0
		return
	counts[key]++
	var/done = counts[key]
	if (done >= laps)
		finishers[key] = list(barracks_axis_pilot(V), round((world.time - go_time) / 10, 0.1))
		announce(SPAN_NOTICE("<b>[barracks_axis_pilot(V)] finishes [finishers.len == 1 ? "first" : "in place [finishers.len]"]</b> in [finishers[key][2]] s."))
		if (finishers.len >= counts.len)
			finish("every car is home")
	else
		announce(SPAN_NOTICE("[barracks_axis_pilot(V)] completes lap [done] of [laps]."))

/datum/barracks_race/proc/finish(reason)
	if (barracks_race != src)
		return
	barracks_race = null
	var/list/lines = list()
	for (var/key in finishers)
		var/list/E = finishers[key]
		lines += "[lines.len + 1]. [E[1]] - [E[2]] s"
	barracks_last_race = lines.len ? lines : list("Nobody finished.")
	announce(SPAN_NOTICE("<b>The race is over</b> ([reason]). [lines.len ? jointext(lines, "; ") : "Nobody finished."]"))

/obj/structure/barracks/race_control
	name = "race control"
	desc = "Starts countdown races, shows the lap board and clears abandoned cars."
	icon = 'icons/obj/device.dmi'
	icon_state = "tracking"

/obj/structure/barracks/race_control/New()
	..()
	if (!barracks_vehicle_sweep)
		barracks_vehicle_sweep = new
		barracks_vehicle_sweep.start()

/obj/structure/barracks/race_control/attack_hand(mob/user)
	if (!user || !user.client)
		return
	var/choice = WWinput(user, barracks_race ? "A [barracks_race.laps]-lap race is on." : "No race is running.", "Race Control", "Close", list("Close", "Start a race", "Lap board", "Clear the circuit"))
	switch (choice)
		if ("Start a race")
			if (barracks_race)
				to_chat(user, SPAN_WARNING("A race is already running."))
				return
			var/laps_text = WWinput(user, "How many laps?", "Race Control", "3", list("1", "2", "3", "5", "10"))
			var/laps = text2num(laps_text)
			if (!laps || barracks_race)
				return
			barracks_race = new
			barracks_race.laps = laps
			barracks_race.control = src
			barracks_race.begin()
		if ("Lap board")
			for (var/obj/structure/barracks/lap_board/B in range(3, src))
				B.attack_hand(user)
				return
		if ("Clear the circuit")
			var/n = barracks_vehicle_sweep ? barracks_vehicle_sweep.sweep(list(/area/caribbean/barracks/annex/track), BARRACKS_SWEEP_IDLE_MANUAL) : 0
			to_chat(user, SPAN_NOTICE(n ? "[n] abandoned vehicle\s cleared." : "Nothing to clear: vehicles go once they have stood empty and still for two minutes."))

// -- flight board -----------------------------------------------------------------------

/obj/structure/barracks/flight_board
	name = "flight board"
	desc = "Who is up, the sky lap times, and the apron sweep."
	icon = 'icons/obj/decals.dmi'
	icon_state = "map_board"
	density = FALSE

/obj/structure/barracks/flight_board/proc/airborne_here()
	. = list()
	for (var/obj/structure/vehicleparts/axis/aircraft/A in airborne_aircraft)
		if (A.flight_z() == z + 1)
			. += A

/obj/structure/barracks/flight_board/examine(mob/user)
	..()
	if (user)
		var/list/up = airborne_here()
		to_chat(user, SPAN_NOTICE("[up.len] aircraft airborne."))

/obj/structure/barracks/flight_board/attack_hand(mob/user)
	if (!user || !user.client)
		return
	var/list/lines = list()
	for (var/obj/structure/vehicleparts/axis/aircraft/A in airborne_here())
		lines += "[A.name]: [barracks_axis_pilot(A)], [A.flight_state == AIRCRAFT_CRUISE ? "cruise" : "low flight"]"
	var/text = "<b>Airborne</b><br>[lines.len ? jointext(lines, "<br>") : "Nobody is up."]<br><br><b>Sky lap - best ten</b><br>[barracks_records_text("sky")]"
	var/datum/browser/popup = new(user, "barracks_flight_board", "Flight Board", 420, 420)
	popup.set_content(text)
	popup.open()
	var/choice = WWinput(user, "Clear aircraft that have stood empty on the airfield for two minutes?", "Flight Board", "Close", list("Close", "Clear the apron"))
	if (choice == "Clear the apron")
		var/n = barracks_vehicle_sweep ? barracks_vehicle_sweep.sweep(list(/area/caribbean/barracks/annex/airfield), BARRACKS_SWEEP_IDLE_MANUAL) : 0
		to_chat(user, SPAN_NOTICE(n ? "[n] stranded aircraft cleared." : "Nothing to clear yet."))

// -- the sky lap ------------------------------------------------------------------------
// Gates 4, 5, 6, 7, 1, 2, 3 in low flight, closed by gate 4 again.

var/global/list/barracks_gate_order = list(4, 5, 6, 7, 1, 2, 3)
var/global/list/barracks_gate_progress = list()

/obj/effect/barracks_air_gate
	name = "air gate"
	desc = "A pylon of the sky lap. Fly through the gates in order, in low flight."
	icon = 'icons/obj/decals.dmi'
	icon_state = "cone1"
	color = "#ff9933"
	anchored = TRUE
	density = FALSE
	layer = 8
	var/gate = 1

/obj/effect/barracks_air_gate/New()
	..()
	name = "air gate [gate]"

/obj/effect/barracks_air_gate/Crossed(atom/movable/A)
	..()
	if (!istype(A, /obj/structure/vehicleparts/frame))
		return
	var/obj/structure/vehicleparts/frame/F = A
	var/obj/structure/vehicleparts/axis/aircraft/V = F.axis
	if (!istype(V) || V.flight_state != AIRCRAFT_LOW)
		return
	var/key = "\ref[V]"
	var/list/P = barracks_gate_progress[key]
	if (P && P["last"] == gate && world.time < P["at"] + BARRACKS_LINE_DEBOUNCE)
		return
	if (P)
		P["last"] = gate
		P["at"] = world.time
	var/first = barracks_gate_order[1]
	if (P && P["next"] <= barracks_gate_order.len && barracks_gate_order[P["next"]] == gate)
		P["next"]++
		V.pilot_message(SPAN_NOTICE("Gate [gate]."))
		return
	if (gate != first)
		barracks_gate_progress -= key
		return
	if (P && P["next"] > barracks_gate_order.len)
		var/seconds = round((world.time - P["start"]) / 10, 0.1)
		var/who = barracks_axis_pilot(V)
		var/place = barracks_record_time("sky", seconds, who, V.name)
		V.pilot_message(SPAN_NOTICE("Sky lap in [seconds] s[place ? ", number [place] on the flight board" : ""]."))
	barracks_gate_progress[key] = list("next" = 2, "start" = world.time, "last" = gate, "at" = world.time)
	V.pilot_message(SPAN_NOTICE("Gate [gate]: the sky lap clock is running."))

/obj/effect/barracks_airspace_marker
	name = "airspace marker"
	desc = "The edge of the Barracks airspace. Turn back here."
	icon = 'icons/obj/decals.dmi'
	icon_state = "cone2"
	anchored = TRUE
	density = FALSE
	layer = 8

// -- the sweep --------------------------------------------------------------------------
// Vehicles on the circuit and airfield that stand empty and still for long
// enough are taken away, except in the bays they were built in.

/datum/barracks_vehicle_sweep
	var/list/seen = list()

/datum/barracks_vehicle_sweep/proc/start()
	set waitfor = FALSE
	while (TRUE)
		sleep(BARRACKS_SWEEP_INTERVAL)
		if (!map || map.ID != MAP_TDM_BARRACKS)
			return
		sweep(list(/area/caribbean/barracks/annex/track, /area/caribbean/barracks/annex/airfield), BARRACKS_SWEEP_IDLE)

/datum/barracks_vehicle_sweep/proc/occupied(obj/structure/vehicleparts/axis/V)
	for (var/mob/living/L in V.transporting)
		if (L.stat != DEAD)
			return TRUE
	for (var/obj/structure/vehicleparts/frame/F in V.components)
		for (var/mob/living/L in get_turf(F))
			if (L.stat != DEAD)
				return TRUE
	return FALSE

/datum/barracks_vehicle_sweep/proc/where(obj/structure/vehicleparts/axis/V)
	var/list/spots = list()
	for (var/obj/structure/vehicleparts/frame/F in V.components)
		var/turf/T = get_turf(F)
		if (T)
			spots += "[T.x],[T.y],[T.z]"
	return jointext(spots, ";")

/datum/barracks_vehicle_sweep/proc/sweep(list/area_types, idle)
	var/list/vehicles = list()
	for (var/area_type in area_types)
		var/area/A = locate(area_type)
		if (A)
			for (var/obj/structure/vehicleparts/frame/F in A)
				if (F.axis && !(F.axis in vehicles))
					vehicles += F.axis
	var/cleared = 0
	for (var/obj/structure/vehicleparts/axis/V in vehicles)
		if (QDELETED(V) || V.moving || occupied(V) || in_bay(V))
			seen -= "\ref[V]"
			continue
		var/key = "\ref[V]"
		var/spot = where(V)
		var/list/S = seen[key]
		if (!S || S["spot"] != spot)
			seen[key] = list("spot" = spot, "since" = world.time)
			continue
		if (world.time - S["since"] < idle)
			continue
		seen -= key
		remove_vehicle(V)
		cleared++
	return cleared

/datum/barracks_vehicle_sweep/proc/in_bay(obj/structure/vehicleparts/axis/V)
	for (var/obj/structure/vehicleparts/frame/F in V.components)
		if (get_turf(F) in barracks_bay_turfs)
			return TRUE
	return FALSE

/datum/barracks_vehicle_sweep/proc/remove_vehicle(obj/structure/vehicleparts/axis/V)
	var/list/turfs = list()
	for (var/obj/structure/vehicleparts/frame/F in V.components)
		var/turf/T = get_turf(F)
		if (T)
			turfs |= T
	var/list/doomed = list()
	for (var/turf/T in turfs)
		for (var/obj/O in T)
			if (O == V || (O in V.components) || (O in V.transporting) || istype(O, /obj/structure/vehicleparts) || istype(O, /obj/structure/engine) || istype(O, /obj/structure/bed/chair/drivers) || istype(O, /obj/item/weapon/reagent_containers/glass/barrel/fueltank))
				doomed |= O
	doomed |= V
	for (var/obj/O in doomed)
		if (!QDELETED(O))
			qdel(O)

#undef BARRACKS_RECORDS_FILE
#undef BARRACKS_LINE_DEBOUNCE
#undef BARRACKS_SHORTEST_RUN
#undef BARRACKS_SWEEP_INTERVAL
#undef BARRACKS_SWEEP_IDLE
#undef BARRACKS_SWEEP_IDLE_MANUAL
#undef BARRACKS_RACE_LIMIT
