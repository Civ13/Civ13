// ============================================================
// Satellites (orbital stations, stage E)
// ------------------------------------------------------------
// A party builds a satellite, loads it into a satellite launcher beside an
// approved launch pad and launches it. Nothing travels to another world: the
// satellite is recorded in the nearest ground station, which talks to it
// from then on.
//
// - Weather satellite (1969): the ground station reads the current weather,
//   the next season and how long until it starts, and storms on the way.
// - Comms satellite (1969): every long-range relay within reach of the
//   ground station needs no antenna and wears half as fast.
// - Navigation satellite (2013): GPS receivers in this world show where you
//   are and steer you to saved waypoints.
// - Survey orbiter (1969): flown from a pad pointed at the Moon or Mars, it
//   maps the whole world from orbit for the mission console beside the
//   launcher and marks a few flat landing sites.
// - Spy satellite (1969): the ground station shows its owners where rival
//   ground stations, launch pads, vehicles and groups of people outdoors are
//   on this world's surface, from imagery taken as it passes over.
//
// A ground station holds one satellite of each kind. Its satellites belong to
// the party that first launched one to it, and serve only that party: GPS
// fixes and the station's reports. Another party can break into the station
// (30 seconds at its desk, any time) to take it over or cut one satellite's
// link; the owners online are warned. A cut satellite is lost, not gone:
// whoever holds the station can reacquire it with a minute at the desk. A station nobody has launched to yet
// serves everyone. Nothing here is a world.time stamp; satellites never wear.
// ============================================================

#define SATELLITE_LAUNCH_PROPELLANT 150
#define SATELLITE_STATION_RANGE 7
#define SATELLITE_COMMS_RANGE 7
#define SATELLITE_SURVEY_SITES 6
#define SATELLITE_WAYPOINTS 5
#define SATELLITE_HACK_DELAY 300
#define SATELLITE_RELINK_DELAY 600
#define SATELLITE_SPY_LINES 6
#define SATELLITE_SPY_GRID 16

var/global/list/satellite_stations = list()

// kind = list(name, minimum age)
var/global/list/satellite_kinds = list(
	"weather" = list("weather satellite", 7),
	"comms" = list("comms satellite", 7),
	"navigation" = list("navigation satellite", 8),
	"survey" = list("survey orbiter", 7),
	"spy" = list("spy satellite", 7))

// TRUE when a ground station in this world holds a satellite of kind that
// serves party (its own, or a station nobody owns).
/proc/satellite_service(kind, party = null)
	for (var/obj/structure/satellite_station/S in satellite_stations)
		if (!QDELETED(S) && isturf(S.loc) && (kind in S.satellites) && S.serves(party))
			return TRUE
	return FALSE

// The nearest ground station within range of A, or null.
/proc/satellite_station_near(atom/A, range = SATELLITE_STATION_RANGE)
	var/turf/T = get_turf(A)
	if (!T)
		return null
	var/obj/structure/satellite_station/best = null
	for (var/obj/structure/satellite_station/S in satellite_stations)
		if (QDELETED(S) || !isturf(S.loc) || S.z != T.z || get_dist(S, T) > range)
			continue
		if (!best || get_dist(S, T) < get_dist(best, T))
			best = S
	return best

// ---------------------------------------------------------------- satellites

/obj/item/satellite
	name = "satellite"
	desc = "A satellite folded for launch."
	icon = 'icons/obj/ammo.dmi'
	icon_state = "rocketcasing_booster"
	w_class = ITEM_SIZE_HUGE
	flammable = FALSE
	var/kind = null

/obj/item/satellite/examine(mob/user)
	..()
	to_chat(user, SPAN_NOTICE("Load it into a satellite launcher beside an approved launch pad. [kind == "survey" ? "Point the pad at the Moon or Mars, with a mission console near the launcher." : "Point the pad at orbit, with a ground station near the launcher."]"))

/obj/item/satellite/weather
	name = "weather satellite"
	desc = "Cameras and a radiometer that watch the sky from orbit. A ground station reads its forecasts."
	color = "#c8e0ff"
	kind = "weather"

/obj/item/satellite/comms
	name = "comms satellite"
	desc = "A transponder that carries long-range radio between relays. Relays near its ground station need no antenna and wear half as fast."
	color = "#ffe0a0"
	kind = "comms"

/obj/item/satellite/navigation
	name = "navigation satellite"
	desc = "A timing beacon. Once one is up, GPS receivers in this world can find themselves."
	color = "#c0ffc8"
	kind = "navigation"

/obj/item/satellite/survey
	name = "survey orbiter"
	desc = "A mapping camera that circles another world. Flown to the Moon or Mars, it maps the whole surface for a mission console and picks flat landing sites."
	color = "#e8c8ff"
	kind = "survey"

/obj/item/satellite/spy
	name = "spy satellite"
	desc = "A long-lens camera that photographs the ground as it passes over. Its ground station shows rival stations, launch pads, vehicles and gatherings outdoors."
	color = "#ffc0c0"
	kind = "spy"

// ---------------------------------------------------------------- launcher

/obj/structure/crewed_lander/satellite_launcher
	name = "satellite launcher"
	desc = "A slim uncrewed rocket with a payload fairing for one satellite. Load a satellite, fill it with rocket propellant or methalox beside an approved launch pad and launch it."
	seats = 0
	cargo_max = 1
	propellant_needed = SATELLITE_LAUNCH_PROPELLANT
	ascent_propellant = 0
	fuels = list("rocket_propellant", "methalox")

/obj/structure/crewed_lander/satellite_launcher/stow_refusal(obj/item/W)
	if (!istype(W, /obj/item/satellite))
		return "Only a satellite fits the fairing."
	if (length(hold()))
		return "The fairing already holds a satellite."
	return null

/obj/structure/crewed_lander/satellite_launcher/proc/payload()
	return locate(/obj/item/satellite) in contents

/obj/structure/crewed_lander/satellite_launcher/attack_hand(mob/user)
	var/mob/living/human/H = user
	if (!istype(H) || !H.client)
		return
	var/obj/item/satellite/S = payload()
	var/list/options = list("Launch")
	if (S)
		options += "Unload"
	options += "Cancel"
	var/choice = WWinput(H, "[fuel_kind == "methalox" ? "Methalox" : "Propellant"] [propellant]/[propellant_needed]. Payload: [S ? S.name : "none"].", capitalize(name), "Cancel", options)
	if (QDELETED(src) || !H.client || !in_range(src, H) || H.incapacitated())
		return
	switch (choice)
		if ("Launch")
			var/reason = launch_satellite(H)
			if (reason)
				to_chat(H, SPAN_WARNING(reason))
		if ("Unload")
			unload(H)

// Null when the payload may fly now, otherwise why not.
/obj/structure/crewed_lander/satellite_launcher/proc/satellite_refusal(mob/living/human/user = null)
	var/obj/item/satellite/S = payload()
	if (!S)
		return "Load a satellite first."
	var/list/info = satellite_kinds[S.kind]
	if (!info)
		return "\The [S] cannot fly."
	if (!map || map.ordinal_age < info[2])
		return "\The [S] needs a later age."
	var/obj/structure/region_gate/trail_marker/launch_pad/pad = find_pad()
	if (!pad)
		return "\The [src] must stand beside a launch pad."
	if (!pad.approved || !pad.destination)
		return "The launch pad is not approved yet."
	if (propellant < propellant_needed)
		return "\The [src] needs [propellant_needed] units of rocket propellant or methalox ([propellant] loaded)."
	if (S.kind == "survey")
		if (!survey_region_ok(pad.destination) || !get_space_survey_map(pad.destination))
			return "Point the pad at the Moon or Mars to send a survey orbiter."
		var/closed = survey_region_closed_reason(pad.destination)
		if (closed)
			return closed
		if (!(locate(/obj/structure/survey_console) in range(SATELLITE_STATION_RANGE, src)))
			return "A survey orbiter needs a mission console within [SATELLITE_STATION_RANGE] tiles to send its maps to."
		return null
	if (!space_flight_orbit_ok(pad.destination))
		return "Point the pad at orbit to put \the [S] up."
	var/obj/structure/satellite_station/G = satellite_station_near(src)
	if (!G)
		return "\The [S] needs a ground station within [SATELLITE_STATION_RANGE] tiles to talk to."
	var/party = user ? party_train_party_of(user) : null
	if (user && !G.serves(party))
		return "\The [G] answers to [party_train_party_name(G.owner)]. Take it over first."
	if (S.kind in G.satellites)
		return "\The [G] already talks to a [info[1]]."
	return null

// Puts the payload up. Returns null once it flew, or why it did not.
/obj/structure/crewed_lander/satellite_launcher/proc/launch_satellite(mob/user)
	var/reason = satellite_refusal(user)
	if (reason)
		return reason
	var/obj/item/satellite/S = payload()
	var/kind = S.kind
	var/obj/structure/region_gate/trail_marker/launch_pad/pad = find_pad()
	if (kind == "survey")
		var/obj/structure/survey_console/C = locate() in range(SATELLITE_STATION_RANGE, src)
		var/sites = satellite_survey(C, get_space_survey_map(pad.destination))
		visible_message(SPAN_NOTICE("\The [C] fills with a map of [survey_world_name(pad.destination)] from orbit: [sites] landing site\s marked."))
	else
		var/obj/structure/satellite_station/G = satellite_station_near(src)
		G.satellites |= kind
		G.lost -= kind
		var/party = istype(user, /mob/living/human) ? party_train_party_of(user) : null
		if (!G.owner && party)
			G.owner = party
		G.visible_message(SPAN_NOTICE("\The [G]'s dish swings round and locks on to the new [S.name]."))
	log_game("Satellite: [user ? key_name(user) : "nobody"] launched a [S.name] from [x],[y],[z][kind == "survey" ? " to [pad.destination]" : ""].")
	qdel(S)
	visible_message(SPAN_DANGER("\The [src] roars off the pad on a column of fire!"))
	qdel(src)
	return null

// Maps the whole of M for console C and marks up to SATELLITE_SURVEY_SITES
// flat landing sites. Returns how many sites are new.
/proc/satellite_survey(obj/structure/survey_console/C, datum/survey_map/M)
	if (!C || !M)
		return 0
	C.switch_record(M.region)
	if (C.map_region != M.region || C.map_seed != M.seed || C.map_digest != M.digest() || C.map_width != M.width || C.map_height != M.height || length(C.revealed) != M.width * M.height)
		C.reset_survey(M)
	var/list/ones = list()
	for (var/i in 1 to M.width * M.height)
		ones += "1"
	C.revealed = jointext(ones, "")
	var/list/plains = M.plain_cells()
	var/added = 0
	while (length(plains) && added < SATELLITE_SURVEY_SITES)
		var/list/cell = pick(plains)
		plains -= list(cell)
		var/site = "[cell[1]],[cell[2]]"
		if (site in C.landing_sites)
			continue
		C.landing_sites += site
		added++
	return added

// ---------------------------------------------------------------- ground station

/obj/structure/satellite_station
	name = "ground station"
	desc = "A tracking dish and a desk of receivers that talk to this world's satellites. Launch satellites from a pad within seven tiles of it. They serve the party that launched them, until someone breaks in."
	icon = 'icons/obj/obj32x64.dmi'
	icon_state = "radio_powered"
	anchored = TRUE
	density = TRUE
	flammable = FALSE
	// Kinds of satellite this station talks to.
	var/list/satellites = list()
	// The party its satellites serve, or null while they serve everyone.
	var/owner = null
	// Kinds whose link a raider cut; they can be reacquired here.
	var/list/lost = list()

/obj/structure/satellite_station/New()
	..()
	satellite_stations |= src

/obj/structure/satellite_station/Destroy()
	satellite_stations -= src
	return ..()

/obj/structure/satellite_station/examine(mob/user)
	..()
	var/list/names = list()
	for (var/kind in satellites)
		var/list/info = satellite_kinds[kind]
		if (info)
			names += info[1]
	to_chat(user, SPAN_NOTICE(names.len ? "It talks to: [english_list(names)]." : "No satellite is up yet."))
	if (owner)
		to_chat(user, SPAN_NOTICE("Its satellites answer to [party_train_party_name(owner)]."))
	if (length(lost))
		to_chat(user, SPAN_WARNING("Out of contact: [english_list(satellite_kind_names(lost))]."))

/proc/satellite_kind_names(list/kinds)
	var/list/names = list()
	for (var/kind in kinds)
		var/list/info = satellite_kinds[kind]
		names += info ? info[1] : kind
	return names

// TRUE when this station's satellites serve party.
/obj/structure/satellite_station/proc/serves(party)
	return !owner || owner == party

/obj/structure/satellite_station/attack_hand(mob/living/human/user)
	if (!istype(user))
		return
	if (!serves(party_train_party_of(user)))
		hack_prompt(user)
		return
	if (length(lost))
		var/list/options = list("Read the receivers")
		for (var/kind in lost)
			var/list/info = satellite_kinds[kind]
			options += "Reacquire the [info ? info[1] : kind]"
		options += "Cancel"
		var/choice = WWinput(user, "Out of contact: [english_list(satellite_kind_names(lost))].", capitalize(name), "Cancel", options)
		if (choice == "Cancel" || QDELETED(src) || !in_range(src, user) || user.incapacitated())
			return
		if (choice != "Read the receivers")
			for (var/kind in lost)
				var/list/info = satellite_kinds[kind]
				if (choice == "Reacquire the [info ? info[1] : kind]")
					relink_prompt(user, kind)
					return
			return
	if (!length(satellites))
		to_chat(user, SPAN_NOTICE("The receivers hiss. No satellite is up yet: launch one from a pad within [SATELLITE_STATION_RANGE] tiles."))
		return
	var/list/lines = list()
	if ("weather" in satellites)
		lines += satellite_weather_report()
	if ("comms" in satellites)
		var/relays = 0
		for (var/obj/structure/telecom/relay/R in range(SATELLITE_COMMS_RANGE, src))
			relays++
		lines += "<b>Comms:</b> [relays] long-range relay\s within [SATELLITE_COMMS_RANGE] tiles are linked through the satellite. They need no antenna and wear half as fast."
	if ("navigation" in satellites)
		lines += "<b>Navigation:</b> GPS receivers in this world have a fix. This station stands at [x], [y]."
	if ("spy" in satellites)
		lines += satellite_spy_report(owner, z)
	to_chat(user, SPAN_NOTICE(jointext(lines, "<br>")))

// ---------------------------------------------------------------- raids

// Null when user may break into this station, otherwise why not.
/obj/structure/satellite_station/proc/hack_refusal(mob/living/human/user)
	var/party = party_train_party_of(user)
	if (!party)
		return "You have no party to take it for."
	if (serves(party))
		return "\The [src] already answers to you."
	if (!length(satellites))
		return "\The [src] talks to no satellite."
	return null

/obj/structure/satellite_station/proc/hack_prompt(mob/living/human/user)
	var/reason = hack_refusal(user)
	if (reason)
		to_chat(user, SPAN_WARNING("\The [src] answers to [party_train_party_name(owner)]. [reason]"))
		return
	var/list/options = list("Take it over")
	for (var/kind in satellites)
		var/list/info = satellite_kinds[kind]
		if (info)
			options += "Cut the [info[1]]"
	options += "Cancel"
	var/choice = WWinput(user, "\The [src] answers to [party_train_party_name(owner)]. Breaking into its receivers takes a while, and its owners will know.", capitalize(name), "Cancel", options)
	if (choice == "Cancel" || QDELETED(src) || !in_range(src, user) || user.incapacitated())
		return
	satellite_raid_alert(owner, "Someone is breaking into your [name] at [x], [y]!")
	user.visible_message(SPAN_WARNING("[user] pries open \the [src]'s desk and starts rewiring the receivers."))
	if (!do_after(user, SATELLITE_HACK_DELAY, src) || QDELETED(src))
		return
	reason = hack_refusal(user)
	if (reason)
		to_chat(user, SPAN_WARNING(reason))
		return
	var/kind = null
	if (choice != "Take it over")
		for (var/k in satellites)
			var/list/info = satellite_kinds[k]
			if (info && choice == "Cut the [info[1]]")
				kind = k
		if (!kind)
			return
	to_chat(user, SPAN_NOTICE(hack(user, kind)))

// Breaks in for user: takes the station over, or with kind, cuts that
// satellite's link. Returns what happened.
/obj/structure/satellite_station/proc/hack(mob/living/human/user, kind = null)
	var/party = party_train_party_of(user)
	var/old = owner
	if (kind)
		satellites -= kind
		lost |= kind
		var/list/info = satellite_kinds[kind]
		log_game("Satellite: [key_name(user)] of [party] cut the [kind] satellite of [old] at [x],[y],[z].")
		satellite_raid_alert(old, "Your [info ? info[1] : "satellite"] has gone silent.")
		return "The [info ? info[1] : "satellite"] drifts out of contact. Its owners can still reacquire it here."
	owner = party
	log_game("Satellite: [key_name(user)] took the ground station of [old] at [x],[y],[z] for [party].")
	satellite_raid_alert(old, "Your [name] at [x], [y] no longer answers to you.")
	return "\The [src] now answers to [party_train_party_name(party)]."

/obj/structure/satellite_station/proc/relink_prompt(mob/living/human/user, kind)
	user.visible_message(SPAN_NOTICE("[user] starts sweeping the sky with \the [src]'s dish."))
	if (!do_after(user, SATELLITE_RELINK_DELAY, src) || QDELETED(src))
		return
	to_chat(user, SPAN_NOTICE(relink(user, kind)))

// Reacquires a lost satellite of kind for user. Returns what happened.
/obj/structure/satellite_station/proc/relink(mob/living/human/user, kind)
	if (!(kind in lost))
		return "That satellite is not lost."
	if (!serves(party_train_party_of(user)))
		return "\The [src] no longer answers to you."
	lost -= kind
	satellites |= kind
	var/list/info = satellite_kinds[kind]
	log_game("Satellite: [key_name(user)] reacquired the [kind] satellite at [x],[y],[z] for [owner].")
	return "The dish locks on to the [info ? info[1] : "satellite"] again."

// Warns party's members online.
/proc/satellite_raid_alert(party, text)
	if (!party)
		return
	for (var/mob/living/human/H in human_mob_list)
		if (H.client && H.stat != DEAD && party_train_party_of(H) == party)
			to_chat(H, SPAN_DANGER(text))

// What the weather satellite sees: today's weather, the next season and
// when it starts, and storms on the way.
/proc/satellite_weather_report()
	var/list/lines = list("<b>Weather:</b> [weather_report_name(weather)][weather != WEATHER_NONE ? " (strength [round(weather_intensity)] of 3)" : ""]. Season: [season ? lowertext(season) : "none"].")
	if (!map)
		return lines
	var/list/timers = map.durable_callbacks ? map.durable_callbacks.snapshot() : list()
	var/next = map.season_next_phase()
	if (next && isnum(timers["season_loop"]))
		lines += "<b>Forecast:</b> [lowertext(next)] begins in about [max(1, round(timers["season_loop"] / 600))] minute\s."
	else
		lines += "<b>Forecast:</b> no change of season is due."
	for (var/storm in list("blizzard", "heat", "sandstorm"))
		var/storm_name = storm == "heat" ? "heat wave" : storm
		if (isnum(timers["[storm]_start"]))
			lines += "<b>Warning:</b> a [storm_name] arrives in about [max(1, round(timers["[storm]_start"] / 600))] minute\s."
		else if (isnum(timers["[storm]_end"]))
			lines += "<b>Warning:</b> a [storm_name] is under way; it should pass in about [max(1, round(timers["[storm]_end"] / 600))] minute\s."
	return lines

/proc/weather_report_name(w)
	switch (w)
		if (WEATHER_NONE)
			return "Clear skies"
		if (WEATHER_WET)
			return "Rain or snow"
		if (WEATHER_EXTREME)
			return "Storms"
		if (WEATHER_SMOG)
			return "Smog"
	return "Unsettled"

// ---------------------------------------------------------------- spy

// What a spy satellite sees on level z for party: rival ground stations,
// launch pads, vehicles and groups of people outdoors, nearest grid square
// for people. Indoors and underground stay hidden.
/proc/satellite_spy_report(party, z)
	var/list/lines = list()
	var/list/found = list()
	for (var/obj/structure/satellite_station/S in satellite_stations)
		if (!QDELETED(S) && S.z == z && S.owner && S.owner != party && satellite_spy_sees(S))
			found += "[party_train_party_name(S.owner)] at [S.x], [S.y]"
	lines += satellite_spy_line("Ground stations", found)
	found = list()
	for (var/obj/structure/region_gate/trail_marker/launch_pad/P in region_gates)
		if (!QDELETED(P) && P.z == z && satellite_spy_sees(P))
			found += "[P.x], [P.y]"
	lines += satellite_spy_line("Launch pads", found)
	found = list()
	for (var/obj/structure/vehicleparts/axis/A in vehicle_axes)
		if (!QDELETED(A) && A.z == z && satellite_spy_sees(A))
			found += "[A.x], [A.y]"
	lines += satellite_spy_line("Vehicles", found)
	var/list/groups = list()
	for (var/mob/living/human/H in human_mob_list)
		if (H.z != z || H.stat == DEAD || !satellite_spy_sees(H))
			continue
		if (party && party_train_party_of(H) == party)
			continue
		var/cell = "[round(H.x, SATELLITE_SPY_GRID)], [round(H.y, SATELLITE_SPY_GRID)]"
		groups[cell] = (groups[cell] || 0) + 1
	found = list()
	for (var/cell in groups)
		found += "[groups[cell]] near [cell]"
	lines += satellite_spy_line("People outdoors", found)
	return lines

// TRUE when A stands outdoors, where a camera in orbit can see it.
/proc/satellite_spy_sees(atom/A)
	var/turf/T = get_turf(A)
	if (!T)
		return FALSE
	var/area/R = get_area(T)
	return R && R.location == AREA_OUTSIDE

/proc/satellite_spy_line(label, list/found)
	if (!length(found))
		return "<b>Imagery, [lowertext(label)]:</b> none seen."
	var/more = length(found) - SATELLITE_SPY_LINES
	if (more > 0)
		found.Cut(SATELLITE_SPY_LINES + 1)
	return "<b>Imagery, [lowertext(label)]:</b> [jointext(found, "; ")][more > 0 ? " and [more] more" : ""]."

// ---------------------------------------------------------------- comms

// A relay near a ground station with a comms satellite needs no antenna and
// wears half as fast (radio_relay.dm asks this).
/proc/satellite_comms_link(atom/A)
	var/obj/structure/satellite_station/G = satellite_station_near(A, SATELLITE_COMMS_RANGE)
	return G && ("comms" in G.satellites)

// ---------------------------------------------------------------- GPS

/obj/item/gps_receiver
	name = "GPS receiver"
	desc = "A handheld receiver that finds itself from the navigation satellites overhead. Use it to see where you are, save waypoints and steer to them."
	icon = 'icons/obj/device.dmi'
	icon_state = "tracking"
	w_class = ITEM_SIZE_SMALL
	flammable = FALSE
	// "name" = "x,y,z"
	var/list/waypoints = list()

/obj/item/gps_receiver/attack_self(mob/user)
	var/turf/T = get_turf(src)
	if (!T)
		return
	if (!satellite_service("navigation", ishuman(user) ? party_train_party_of(user) : null))
		to_chat(user, SPAN_WARNING("No fix. No navigation satellite here answers to you."))
		return
	var/list/options = list("Where am I")
	if (length(waypoints) < SATELLITE_WAYPOINTS)
		options += "Save waypoint"
	if (length(waypoints))
		options += list("Steer to waypoint", "Forget waypoint")
	options += "Cancel"
	var/choice = WWinput(user, "Fix: [T.x], [T.y], level [T.z].", "GPS receiver", "Cancel", options)
	if (QDELETED(src) || loc != user)
		return
	T = get_turf(src)
	switch (choice)
		if ("Where am I")
			to_chat(user, SPAN_NOTICE("You are at [T.x], [T.y], level [T.z]."))
		if ("Save waypoint")
			var/label = sanitize(input(user, "Name the waypoint", "GPS receiver", "Waypoint [length(waypoints) + 1]") as null|text, 24)
			if (!label || QDELETED(src) || loc != user || length(waypoints) >= SATELLITE_WAYPOINTS)
				return
			waypoints[label] = "[T.x],[T.y],[T.z]"
			to_chat(user, SPAN_NOTICE("Saved [label] at [T.x], [T.y]."))
		if ("Steer to waypoint")
			var/label = input(user, "Steer to which waypoint?", "GPS receiver") as null|anything in waypoints
			if (!label || QDELETED(src) || loc != user)
				return
			to_chat(user, SPAN_NOTICE(gps_bearing(get_turf(src), waypoints[label], label)))
		if ("Forget waypoint")
			var/label = input(user, "Forget which waypoint?", "GPS receiver") as null|anything in waypoints
			if (label)
				waypoints -= label

// A line steering from T to a saved "x,y,z".
/proc/gps_bearing(turf/T, spot, label)
	var/list/parts = splittext("[spot]", ",")
	if (!T || parts.len != 3)
		return "The waypoint is unreadable."
	var/wx = text2num(parts[1])
	var/wy = text2num(parts[2])
	var/wz = text2num(parts[3])
	if (wx == T.x && wy == T.y && wz == T.z)
		return "You are at [label]."
	var/dx = wx - T.x
	var/dy = wy - T.y
	var/dir = 0
	if (dy > 0)
		dir |= NORTH
	else if (dy < 0)
		dir |= SOUTH
	if (dx > 0)
		dir |= EAST
	else if (dx < 0)
		dir |= WEST
	var/distance = max(abs(dx), abs(dy))
	var/level = wz == T.z ? "" : (wz > T.z ? " It is [wz - T.z] level\s up." : " It is [T.z - wz] level\s down.")
	return distance ? "[label] is [distance] tile\s [dir2text(dir)].[level]" : "[label] is right here.[level]"

#undef SATELLITE_LAUNCH_PROPELLANT
#undef SATELLITE_STATION_RANGE
#undef SATELLITE_COMMS_RANGE
#undef SATELLITE_SURVEY_SITES
#undef SATELLITE_WAYPOINTS
#undef SATELLITE_HACK_DELAY
#undef SATELLITE_RELINK_DELAY
#undef SATELLITE_SPY_LINES
#undef SATELLITE_SPY_GRID
