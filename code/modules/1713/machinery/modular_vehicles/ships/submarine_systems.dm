// A player submarine's submerged systems (ocean phase 3).
//
// - Battery: submerged, the motor, the floodlights and the sonar run on the
//   battery bank; on the surface the diesel charges it. A flat battery
//   stops the boat where it is until it surfaces.
// - Floodlights: a white beam from the bow, switched at the ballast station,
//   that drains the battery while the boat is submerged.
// - Hull depth rating: a steel hull is built for open water. Deeper than its
//   rating the hull groans and springs leaks; each leak vents hull air (the
//   blowers then spend the air bank) until a shoring kit plugs it. Deep hull
//   plating, fitted at the ballast station, rates the hull for the deep.
// - Sonar ping: a loud pulse that reports the rock around the boat and the
//   contacts in range, for a slice of the battery.
//
// All of it is plain numbers on the boat (saved) and is advanced with the
// hull air (submarine_air.dm), so an empty boat costs nothing.

// Battery capacity and costs, in battery units (one unit = one second of floodlights).
#define SUB_BATTERY_MAX 5400
#define SUB_BATTERY_PER_TILE 2
#define SUB_BATTERY_FLOODLIGHTS_PER_SECOND 1
#define SUB_BATTERY_PING 30
#define SUB_BATTERY_CHARGE_PER_SECOND 45
#define SUB_FLOODLIGHT_RANGE 7
// Per second and per zone too deep: chance (percent) of a new leak.
#define SUB_LEAK_CHANCE_PER_SECOND 3
#define SUB_LEAKS_MAX 6
#define SUB_SONAR_RANGE 20
#define SUB_SHORING_TIME (5 SECONDS)
#define SUB_PLATING_TIME (10 SECONDS)

/obj/structure/vehicleparts/axis/ship/submarine
	var/battery = SUB_BATTERY_MAX
	var/floodlights = FALSE
	// The deepest sea zone (seabed.dm) the hull stands up to.
	var/hull_rating = SEA_ZONE_OPEN
	var/hull_leaks = 0
	var/tmp/battery_warned = FALSE
	var/tmp/obj/floodlight_source = null

/obj/structure/vehicleparts/axis/ship/submarine/persistence_runtime_var(key)
	return (key in list("battery_warned", "floodlight_source")) || ..(key)

// Draws from the battery; TRUE when it held enough.
/obj/structure/vehicleparts/axis/ship/submarine/proc/battery_draw(amount)
	if (amount <= 0)
		return TRUE
	if (battery < amount)
		battery = 0
		if (!battery_warned)
			battery_warned = TRUE
			crew_message(SPAN_DANGER("The battery is flat! The motors, floodlights and sonar are dead until you surface to charge it."))
			update_floodlights()
		return FALSE
	battery -= amount
	return TRUE

// One systems step of seconds, run with the hull air.
/obj/structure/vehicleparts/axis/ship/submarine/proc/systems_step(seconds)
	if (seconds <= 0)
		return
	if (!submerged)
		battery = min(SUB_BATTERY_MAX, battery + SUB_BATTERY_CHARGE_PER_SECOND * seconds)
		battery_warned = FALSE
		return
	if (floodlights && battery > 0)
		battery_draw(SUB_BATTERY_FLOODLIGHTS_PER_SECOND * seconds)
	hull_pressure_step(seconds)

// The depth zone the boat lies in now (0 on the surface).
/obj/structure/vehicleparts/axis/ship/submarine/proc/boat_zone()
	return submerged ? sea_zone_of(boat_turf()) : 0

/obj/structure/vehicleparts/axis/ship/submarine/proc/hull_pressure_step(seconds)
	var/over = boat_zone() - hull_rating
	if (over <= 0)
		return
	if (prob(min(100, SUB_LEAK_CHANCE_PER_SECOND * over * seconds)) && hull_leaks < SUB_LEAKS_MAX)
		hull_leaks++
		crew_message(SPAN_DANGER("A rivet bursts with a crack and water sprays into the hull! ([hull_leaks] leak\s)"))
	else if (prob(10))
		crew_message(SPAN_WARNING("The hull groans under the weight of the water. It is not built for [sea_zone_name(boat_zone())]."))

// ---- Floodlights ----

/obj/structure/vehicleparts/axis/ship/submarine/proc/floodlight_holder()
	for (var/obj/structure/vehicleparts/shipwheel/W in transporting)
		if (W.ship == src)
			return W
	return null

/obj/structure/vehicleparts/axis/ship/submarine/proc/floodlights_lit()
	return floodlights && submerged && battery > 0

/obj/structure/vehicleparts/axis/ship/submarine/proc/update_floodlights()
	var/obj/O = floodlight_holder()
	if (floodlight_source && floodlight_source != O)
		floodlight_source.set_light(0)
		floodlight_source = null
	if (!O)
		return
	if (floodlights_lit())
		O.set_light(SUB_FLOODLIGHT_RANGE, 1, "#e8f4ff")
		floodlight_source = O
	else
		O.set_light(0)
		floodlight_source = null

/obj/structure/vehicleparts/axis/ship/submarine/proc/set_floodlights(on, mob/user)
	floodlights = on
	update_floodlights()
	if (user)
		to_chat(user, SPAN_NOTICE(on ? "You throw the floodlight switch.[submerged ? "" : " They light once the boat dives."]" : "You switch the floodlights off."))

// ---- Sonar ----

// Tiles of open sea from T in direction d before rock, up to range.
/proc/sonar_clear_run(turf/T, d, range)
	. = 0
	var/turf/at = T
	while (. < range)
		at = get_step(at, d)
		if (!sea_layer_cell(at))
			return
		.++

/obj/structure/vehicleparts/axis/ship/submarine/proc/sonar_lines()
	. = list()
	var/turf/here = boat_turf()
	. += "Depth: [sea_zone_name(boat_zone())]. Hull rated for [sea_zone_name(hull_rating)]."
	var/list/rock = list()
	for (var/d in alldirs)
		var/run = sonar_clear_run(here, d, SUB_SONAR_RANGE)
		if (run < SUB_SONAR_RANGE)
			rock += "[dir2text(d)] [run + 1]"
	. += rock.len ? "Rock: [jointext(rock, ", ")] tiles." : "Open water all around."
	. += contacts()

/obj/structure/vehicleparts/axis/ship/submarine/proc/sonar_ping(mob/user)
	if (!submerged)
		to_chat(user, SPAN_WARNING("The sonar only works submerged."))
		return FALSE
	if (battery < SUB_BATTERY_PING)
		to_chat(user, SPAN_WARNING("The battery is too low for a ping."))
		return FALSE
	battery_draw(SUB_BATTERY_PING)
	// Every animal in range hears it (sea_life.dm).
	sea_noise(boat_turf(), SUB_SONAR_RANGE)
	crew_message(SPAN_NOTICE("<b>PING.</b> [user] sends a sonar pulse:"))
	for (var/line in sonar_lines())
		crew_message(line)
	return TRUE

// A blow to the hull (a mine, naval/naval_mines.dm) springs this many leaks.
/obj/structure/vehicleparts/axis/ship/submarine/proc/spring_leaks(count)
	var/was = hull_leaks
	hull_leaks = min(SUB_LEAKS_MAX, hull_leaks + count)
	if (hull_leaks > was)
		crew_message(SPAN_DANGER("Plates buckle and water sprays into the hull! ([hull_leaks] leak\s)"))

// ---- Reports and repairs ----

/obj/structure/vehicleparts/axis/ship/submarine/proc/systems_report()
	return "Battery [round(100 * battery / SUB_BATTERY_MAX)]%[submerged ? "" : ", charging"]. Floodlights [floodlights ? "on" : "off"]. Hull rated for [sea_zone_name(hull_rating)]; [hull_leaks ? "[hull_leaks] leak\s" : "no leaks"]. [craft_of_axis(src).magnetic_text()]"

/obj/item/sub_hull_plating
	name = "deep hull plating"
	desc = "Curved steel plates and stiffening ribs that rate a submarine's hull for the deep. Use it on the boat's ballast and periscope station."
	icon = 'icons/obj/materials.dmi'
	icon_state = "sheet-plasteel"
	w_class = ITEM_SIZE_LARGE

/obj/structure/vehicleparts/sub_station/attackby(obj/item/W, mob/user)
	var/obj/structure/vehicleparts/axis/ship/submarine/B = boat()
	if (B && istype(W, /obj/item/weapon/shoring_kit))
		if (!B.hull_leaks)
			to_chat(user, SPAN_NOTICE("The hull has no leaks to shore up."))
			return
		to_chat(user, SPAN_NOTICE("You wedge timbers against the worst leak..."))
		if (!do_after(user, SUB_SHORING_TIME, src) || QDELETED(W) || QDELETED(B) || !B.hull_leaks)
			return
		B.hull_leaks--
		qdel(W)
		B.crew_message(SPAN_NOTICE("[user] shores up a leak. [B.hull_leaks ? "[B.hull_leaks] leak\s left." : "The hull is tight again."]"))
		return
	if (B && istype(W, /obj/item/sub_hull_plating))
		if (B.hull_rating >= SEA_ZONE_DEEP)
			to_chat(user, SPAN_NOTICE("\The [B] already has deep hull plating."))
			return
		if (B.submerged)
			to_chat(user, SPAN_WARNING("Fit the plating on the surface."))
			return
		to_chat(user, SPAN_NOTICE("You start riveting the plating over the hull..."))
		if (!do_after(user, SUB_PLATING_TIME, src) || QDELETED(W) || QDELETED(B) || B.submerged)
			return
		B.hull_rating = SEA_ZONE_DEEP
		B.hull_leaks = 0
		qdel(W)
		to_chat(user, SPAN_NOTICE("\The [B] is now rated for the deep."))
		return
	return ..()

// ---- Hard dive suit ----

/obj/item/clothing/suit/pressure_suit/diving/hard
	name = "hard dive suit"
	desc = "A jointed steel suit with a hard torso, built to walk the seabed down to the deep. Sealed with a hard dive helmet and an air bottle. It is heavy and slow."
	icon_state = "hard_dive_suit"
	item_state = "hard_dive_suit"
	depth_rating = SEA_ZONE_DEEP
	slowdown = 3
	armor = list(melee = 30, arrow = 20, gun = 10, energy = 5, bomb = 30, bio = 100, rad = 40)

/obj/item/clothing/head/pressure_helmet/diving/hard
	name = "hard dive helmet"
	desc = "A heavy steel helmet with thick ports and a bright lamp. It locks onto a diving dress or a hard dive suit. Use it in hand to switch the lamp."
	icon_state = "hard_dive_helmet"
	item_state = "hard_dive_helmet"
	brightness_on = 6
	armor = list(melee = 30, arrow = 20, gun = 10, energy = 5, bomb = 30, bio = 100, rad = 40)

#undef SUB_BATTERY_FLOODLIGHTS_PER_SECOND
#undef SUB_BATTERY_CHARGE_PER_SECOND
#undef SUB_FLOODLIGHT_RANGE
#undef SUB_LEAK_CHANCE_PER_SECOND
#undef SUB_LEAKS_MAX
#undef SUB_SONAR_RANGE
#undef SUB_SHORING_TIME
#undef SUB_PLATING_TIME
