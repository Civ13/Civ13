// Player submarines: a steel ship that dives into the sea layer (sea_layer.dm).
//
// On the surface a submarine is an ordinary engine-driven ship: it steers
// from its ship wheel, sails over any water and comes alongside piers, where
// its crew walk on and off through the open hatches amidships and carry crates
// aboard. Submerged, the whole boat, crew and cargo drop to the level below,
// where it can go only where the ocean above is open: the coast, islands and
// shallows are rock down there. Divers leave a submerged boat only through
// the lock-out hatches (seabed.dm).
//
// Two models share one rounded hull: the 3x5 Scout and the 3x7 Explorer
// (submarine_layouts). Bow to stern: the helm under a glass bow, the ballast
// station, the lock-out chambers amidships and the engine room with the
// battery and air bank behind a watertight door.
//
// The ballast and periscope station aboard dives, surfaces, raises the
// periscope (the surface straight above, following the boat) and lists the
// contacts in range: ships and aircraft above, and other submerged boats by
// sonar. Submerged systems (battery, floodlights, hull depth, sonar ping)
// are in submarine_systems.dm, the hull air in submarine_air.dm.

// Tiles at which the periscope picks out ships and aircraft on the surface,
// and sonar other submerged boats.
#define SUBMARINE_PERISCOPE_RANGE 30
#define SUBMARINE_SONAR_RANGE 20
// How long flooding or blowing the ballast tanks takes.
#define SUBMARINE_BALLAST_TIME (3 SECONDS)
// How often the periscope checks its watchers are still at the eyepiece.
#define SUBMARINE_PERISCOPE_CHECK (1 SECONDS)

// The stripe colour a boat leaves the pen with (drawn into the roof art).
#define SUBMARINE_STRIPE_DEFAULT "#E89628"
// How long repainting the hull stripes takes.
#define SUBMARINE_PAINT_TIME (5 SECONDS)

var/global/list/player_submarines = list()
// The paints kept in a boat's stores for its hull stripes.
var/global/list/submarine_stripe_paints = list(
	"Orange" = SUBMARINE_STRIPE_DEFAULT,
	"Red" = "#C8281E",
	"Yellow" = "#F0D040",
	"Green" = "#3C9A3C",
	"Blue" = "#2C6CD0",
	"Purple" = "#8040A8",
	"White" = "#F0F0F0",
	"Black" = "#202428",
	)

/obj/structure/vehicleparts/axis/ship/submarine
	name = "submarine"
	desc = "The rudder and dive planes of a steel submarine."
	speeds = 3
	maxpower = 2500
	speedlist = alist(1=16,2=12,3=9)
	var/submerged = FALSE
	// Which layout and hull art the boat has (submarine_layouts).
	var/hull_class = "scout"
	// The colour of the stripes across the hull; the crew repaint them at the
	// ballast station.
	var/stripe_color = SUBMARINE_STRIPE_DEFAULT
	// Mobs looking through the periscope. Runtime only.
	var/tmp/list/periscope_watchers = list()
	var/tmp/periscope_check_queued = FALSE

/obj/structure/vehicleparts/axis/ship/submarine/persistence_runtime_var(key)
	return (key in list("periscope_watchers", "periscope_check_queued")) || ..(key)

/obj/structure/vehicleparts/axis/ship/submarine/New()
	..()
	player_submarines |= src

/obj/structure/vehicleparts/axis/ship/submarine/Destroy()
	player_submarines -= src
	end_all_periscopes()
	return ..()

// The axis can sit inside a frame, where its own z reads 0.
/obj/structure/vehicleparts/axis/ship/submarine/proc/boat_turf()
	return get_turf(src)

/obj/structure/vehicleparts/axis/ship/submarine/proc/frames()
	. = list()
	for (var/obj/structure/vehicleparts/frame/F in components)
		if (F.axis == src && !QDELETED(F))
			. += F

/obj/structure/vehicleparts/axis/ship/submarine/proc/crew_message(text)
	for (var/mob/living/M in transporting)
		to_chat(M, text)

// What would stop the boat taking up target_z under (or over) its frames, or
// null. Submerging needs open sea under every frame; surfacing needs open
// ocean over every frame with nothing floating or built there.
/obj/structure/vehicleparts/axis/ship/submarine/proc/level_blocker(target_z, diving)
	for (var/obj/structure/vehicleparts/frame/F in frames())
		var/turf/T = locate(F.x, F.y, target_z)
		if (!T)
			return "the edge of the world"
		if (diving ? !sea_layer_cell(T) : !sea_layer_open_surface(T))
			return diving ? "the seabed: the water here is too shallow" : "the coast: there is no open water above"
		if (T.density)
			return T
		for (var/obj/O in T)
			if (O == src || (O in transporting) || (O in components))
				continue
			if (istype(O, /obj/covers) || istype(O, /obj/structure/vehicleparts) || istype(O, /obj/structure/vehicle) || O.density)
				return O
	return null

// Moves the whole boat and everything aboard straight to target_z.
/obj/structure/vehicleparts/axis/ship/submarine/proc/shift_level(target_z)
	if (!target_z || transforming_vehicle)
		return FALSE
	add_transporting(FALSE)
	var/list/movers = list()
	var/list/destinations = list()
	var/list/tiles = list()
	for (var/atom/movable/M in (transporting | components))
		if (QDELETED(M) || !isturf(M.loc))
			continue
		var/turf/D = locate(M.x, M.y, target_z)
		if (!D)
			return FALSE
		movers += M
		destinations[M] = D
		tiles |= M.loc
		tiles |= D
	transforming_vehicle = TRUE
	transform_tiles = tiles
	for (var/turf/T in tiles)
		T.vehicle_transforming = src
	try
		// Frames first, so whatever stands on them arrives on a deck.
		for (var/obj/structure/vehicleparts/frame/F in movers)
			F.forceMove(destinations[F])
		for (var/atom/movable/M in movers)
			if (istype(M, /obj/structure/vehicleparts/frame) || QDELETED(M))
				continue
			M.forceMove(destinations[M])
	catch (var/exception/e)
		release_transform_tiles(tiles)
		throw e
	release_transform_tiles(tiles)
	for (var/obj/O in movers)
		O.update_icon()
	refresh_passenger_vision()
	return TRUE

// Why the boat cannot dive or surface now, or null.
/obj/structure/vehicleparts/axis/ship/submarine/proc/depth_refusal(diving)
	if (diving == submerged)
		return diving ? "The boat is already submerged." : "The boat is already on the surface."
	if (moving)
		return "Bring the boat to a stop first."
	var/turf/here = boat_turf()
	if (!here)
		return "The boat is not in the water."
	var/target = diving ? multiz_level_below(here.z) : multiz_level_above(here.z)
	if (!target || (diving && target != sea_layer_z()))
		return diving ? "There is no deep sea to dive into here." : "There is no surface above."
	var/hit = level_blocker(target, diving)
	if (hit)
		return diving ? "The boat can't dive here: [hit] is below." : "The boat can't surface here: [hit] is above."
	return null

// Floods or blows the ballast tanks at once. Returns null on success, or why not.
/obj/structure/vehicleparts/axis/ship/submarine/proc/change_depth(diving)
	var/reason = depth_refusal(diving)
	if (reason)
		return reason
	var/turf/here = boat_turf()
	var/target = diving ? multiz_level_below(here.z) : multiz_level_above(here.z)
	if (!shift_level(target))
		return "The ballast tanks jam. Try again."
	submerged = diving
	update_boat_lights()
	if (submerged)
		crew_message(SPAN_NOTICE("Water roars into the ballast tanks and [src] slips beneath the waves."))
	else
		end_all_periscopes()
		crew_message(SPAN_NOTICE("Compressed air blows the ballast tanks and [src] breaks the surface."))
	return null

// A user at the station dives or surfaces after the tanks have time to work.
/obj/structure/vehicleparts/axis/ship/submarine/proc/order_depth(mob/user, diving)
	var/reason = depth_refusal(diving)
	if (reason)
		to_chat(user, SPAN_WARNING(reason))
		return FALSE
	crew_message(SPAN_NOTICE(diving ? "[user] floods the ballast tanks: dive, dive!" : "[user] blows the ballast tanks: surface!"))
	if (!do_after(user, SUBMARINE_BALLAST_TIME, user))
		return FALSE
	reason = change_depth(diving)
	if (reason)
		to_chat(user, SPAN_WARNING(reason))
		return FALSE
	return TRUE

// Submerged, the sea layer ends where the ocean above does: a clear message
// instead of ramming the rock.
/obj/structure/vehicleparts/axis/ship/submarine/do_vehicle_check()
	if (submerged && !anchor && battery <= 0)
		visible_message(SPAN_WARNING("\The [src]'s motors whine down: the battery is flat."))
		moving = FALSE
		stopmovementloop()
		return FALSE
	if (submerged && !anchor)
		var/m_dir = reverse ? OPPOSITE_DIR(dir) : dir
		for (var/obj/structure/vehicleparts/frame/F in frames())
			var/turf/T = get_step(get_turf(F), m_dir)
			if (!sea_layer_cell(T))
				visible_message(SPAN_WARNING("\The [src]'s sonar pings off the seabed rising ahead. It stops."))
				moving = FALSE
				stopmovementloop()
				return FALSE
	return ..()

/obj/structure/vehicleparts/axis/ship/submarine/do_move()
	. = ..()
	if (. && submerged)
		battery_draw(SUB_BATTERY_PER_TILE)
	if (. && periscope_watchers.len)
		update_periscopes()

// Below the surface the boat is in the dark; its lamps light the hull.
/obj/structure/vehicleparts/axis/ship/submarine/proc/update_boat_lights()
	for (var/obj/structure/vehicleparts/sub_station/S in transporting)
		S.update_light_state(submerged)
	update_floodlights()

// ---- Periscope ----

/obj/structure/vehicleparts/axis/ship/submarine/proc/periscope_turf()
	var/turf/here = boat_turf()
	if (!here)
		return null
	if (!submerged)
		return here
	var/up = multiz_level_above(here.z)
	return up ? locate(here.x, here.y, up) : null

/obj/structure/vehicleparts/axis/ship/submarine/proc/raise_periscope(mob/user, obj/structure/vehicleparts/sub_station/station)
	if (!user || !user.client)
		return FALSE
	if (!submerged)
		to_chat(user, SPAN_NOTICE("On the surface you can see well enough from the deck."))
		return FALSE
	var/turf/view = periscope_turf()
	if (!view)
		return FALSE
	periscope_watchers[user] = station
	user.client.perspective = EYE_PERSPECTIVE
	user.client.eye = view
	to_chat(user, SPAN_NOTICE("You put your eyes to the periscope. Step away from it to lower it."))
	queue_periscope_check()
	return TRUE

/obj/structure/vehicleparts/axis/ship/submarine/proc/lower_periscope(mob/user)
	if (!(user in periscope_watchers))
		return
	periscope_watchers -= user
	if (user.client)
		user.client.perspective = MOB_PERSPECTIVE
		user.client.eye = user

/obj/structure/vehicleparts/axis/ship/submarine/proc/end_all_periscopes()
	for (var/mob/M in periscope_watchers.Copy())
		lower_periscope(M)

/obj/structure/vehicleparts/axis/ship/submarine/proc/update_periscopes()
	var/turf/view = periscope_turf()
	for (var/mob/M in periscope_watchers.Copy())
		var/obj/structure/vehicleparts/sub_station/S = periscope_watchers[M]
		if (!view || QDELETED(M) || !M.client || M.stat != CONSCIOUS || QDELETED(S) || !M.Adjacent(S))
			lower_periscope(M)
			continue
		M.client.eye = view

/obj/structure/vehicleparts/axis/ship/submarine/proc/queue_periscope_check()
	if (periscope_check_queued)
		return
	periscope_check_queued = TRUE
	addtimer(CALLBACK(src, PROC_REF(periscope_check)), SUBMARINE_PERISCOPE_CHECK)

/obj/structure/vehicleparts/axis/ship/submarine/proc/periscope_check()
	periscope_check_queued = FALSE
	if (QDELETED(src))
		return
	update_periscopes()
	if (periscope_watchers.len)
		queue_periscope_check()

// ---- Contacts ----

/proc/submarine_bearing(turf/from, turf/target)
	var/d = get_dir(from, target)
	return d ? dir2text(d) : "overhead"

// Lines describing what the periscope and sonar pick up around the boat.
/obj/structure/vehicleparts/axis/ship/submarine/proc/contacts()
	. = list()
	var/turf/here = boat_turf()
	if (!here)
		return
	var/turf/surface = submerged ? periscope_turf() : here
	if (surface)
		for (var/obj/structure/vehicleparts/axis/ship/S in ship_axes)
			if (S == src)
				continue
			var/turf/T = get_turf(S)
			if (!T)
				continue
			var/obj/structure/vehicleparts/axis/ship/submarine/other = S
			var/other_submerged = istype(other) && other.submerged
			if (other_submerged)
				if (!submerged || T.z != here.z || get_dist(T, here) > SUBMARINE_SONAR_RANGE)
					continue
				. += "Sonar: a submerged boat [get_dist(T, here)] tiles [submarine_bearing(here, T)], heading [dir2text(S.dir)][S.moving ? "" : ", stopped"]."
				continue
			if (T.z != surface.z || get_dist(T, surface) > SUBMARINE_PERISCOPE_RANGE)
				continue
			. += "Ship: [S.name], [get_dist(T, surface)] tiles [submarine_bearing(surface, T)], heading [dir2text(S.dir)][S.moving ? "" : ", stopped"]."
		for (var/obj/structure/vehicleparts/axis/aircraft/A in airborne_aircraft)
			var/turf/T = get_turf(A)
			if (!T || abs(T.x - surface.x) > SUBMARINE_PERISCOPE_RANGE || abs(T.y - surface.y) > SUBMARINE_PERISCOPE_RANGE)
				continue
			if (multiz_level_below(T.z) != surface.z)
				continue
			. += "Aircraft: [A.name], [get_dist(locate(T.x, T.y, surface.z), surface)] tiles [submarine_bearing(surface, locate(T.x, T.y, surface.z))], heading [dir2text(A.dir)]."

// Every ship axis in the world, kept as ships are made and destroyed.
var/global/list/ship_axes = list()

/obj/structure/vehicleparts/axis/ship/New()
	..()
	ship_axes |= src

/obj/structure/vehicleparts/axis/ship/Destroy()
	ship_axes -= src
	return ..()

/obj/structure/vehicleparts/axis/ship/submarine/proc/report_contacts(mob/user)
	var/list/lines = contacts()
	to_chat(user, SPAN_NOTICE("<b>[src] contacts</b> ([submerged ? "periscope and sonar" : "lookout"]):"))
	if (!lines.len)
		to_chat(user, "Nothing in range.")
		return
	for (var/line in lines)
		to_chat(user, line)

// ---- Name and stripe ----

// Gives the boat a name: her hull sections carry it too, so it is what
// people read when they look at her.
/obj/structure/vehicleparts/axis/ship/submarine/proc/rename_boat(new_name)
	new_name = sanitize(copytext("[new_name]", 1, 40))
	if (!length(new_name))
		return FALSE
	name = new_name
	for (var/obj/structure/vehicleparts/frame/F in frames())
		F.name = new_name
	return TRUE

// Repaints the stripes across the hull. Returns FALSE for a colour that is
// not one of the boat's paints.
/obj/structure/vehicleparts/axis/ship/submarine/proc/paint_stripe(paint)
	var/new_color = submarine_stripe_paints[paint]
	if (!new_color)
		return FALSE
	stripe_color = new_color
	for (var/obj/structure/vehicleparts/frame/F in frames())
		F.update_icon()
	return TRUE

/obj/structure/vehicleparts/axis/ship/submarine/proc/stripe_paint_name()
	for (var/paint in submarine_stripe_paints)
		if (submarine_stripe_paints[paint] == stripe_color)
			return paint
	return "Orange"

/obj/structure/vehicleparts/axis/ship/submarine/proc/order_name(mob/living/human/user, obj/structure/vehicleparts/sub_station/station)
	var/new_name = player_input(user, "What is she called? Her name is what people read on her hull.", "Name the boat", name, "text", null, TRUE)
	if (isnull(new_name) || QDELETED(src) || QDELETED(station) || !station.Adjacent(user) || station.boat() != src)
		return
	if (rename_boat(new_name))
		crew_message(SPAN_NOTICE("[user] names the boat the [name]."))

// The stripes are on the outside of the hull: nobody paints them submerged.
/obj/structure/vehicleparts/axis/ship/submarine/proc/order_paint(mob/living/human/user, obj/structure/vehicleparts/sub_station/station)
	if (submerged)
		to_chat(user, SPAN_WARNING("The stripes are on the outside of the hull. Surface first."))
		return
	var/list/paints = list()
	for (var/paint in submarine_stripe_paints)
		paints += paint
	paints += "Cancel"
	var/choice = WWinput(user, "The hull stripes are [lowertext(stripe_paint_name())]. Which paint?", "Paint the stripes", "Cancel", paints)
	if (!choice || choice == "Cancel" || QDELETED(src) || QDELETED(station) || !station.Adjacent(user) || station.boat() != src)
		return
	if (submarine_stripe_paints[choice] == stripe_color)
		to_chat(user, SPAN_NOTICE("The stripes are already [lowertext(choice)]."))
		return
	user.visible_message(SPAN_NOTICE("[user] takes a brush and a pot of [lowertext(choice)] paint up through the hatch."))
	if (!do_after(user, SUBMARINE_PAINT_TIME, user))
		return
	if (QDELETED(src) || QDELETED(station) || station.boat() != src)
		return
	if (submerged)
		to_chat(user, SPAN_WARNING("The boat dived before you could paint."))
		return
	if (paint_stripe(choice))
		crew_message(SPAN_NOTICE("[user] paints the hull stripes [lowertext(choice)]."))

// ---- The ballast and periscope station ----

/obj/structure/vehicleparts/sub_station
	name = "ballast and periscope station"
	desc = "Valve wheels for the ballast tanks and the eyepiece of the periscope. Use it to dive, surface, raise the periscope or read the contacts. The boat's name board and stripe paint are kept here too."
	icon = 'icons/obj/machines/submarine.dmi'
	icon_state = "ballast"
	anchored = TRUE
	density = FALSE
	layer = 2.99

/obj/structure/vehicleparts/sub_station/proc/boat()
	for (var/obj/structure/vehicleparts/frame/F in loc)
		if (istype(F.axis, /obj/structure/vehicleparts/axis/ship/submarine))
			return F.axis
	return null

/obj/structure/vehicleparts/sub_station/proc/update_light_state(submerged)
	if (submerged)
		set_light(5, 1, "#a8c8ff")
	else
		set_light(0)

/obj/structure/vehicleparts/sub_station/attack_hand(mob/living/human/user)
	if (!ishuman(user) || !Adjacent(user))
		return
	var/obj/structure/vehicleparts/axis/ship/submarine/B = boat()
	if (!B)
		to_chat(user, SPAN_WARNING("The station is not fitted to a submarine."))
		return
	var/list/options = list(B.submerged ? "Surface" : "Dive", "Contacts", "Status", B.floodlights ? "Floodlights off" : "Floodlights on")
	if (B.submerged)
		options += "Sonar ping"
	if (B.submerged)
		options += (user in B.periscope_watchers) ? "Lower periscope" : "Raise periscope"
	options += "Name the boat"
	if (!B.submerged)
		options += "Paint the stripes"
	options += "Cancel"
	var/choice = WWinput(user, "[B] is [B.submerged ? "submerged" : "on the surface"].", name, "Cancel", options)
	if (QDELETED(src) || QDELETED(B) || !Adjacent(user) || boat() != B)
		return
	switch (choice)
		if ("Dive")
			B.order_depth(user, TRUE)
		if ("Surface")
			B.order_depth(user, FALSE)
		if ("Contacts")
			B.report_contacts(user)
		if ("Status")
			to_chat(user, SPAN_NOTICE(B.air_report()))
			to_chat(user, SPAN_NOTICE(B.systems_report()))
		if ("Floodlights on", "Floodlights off")
			B.set_floodlights(choice == "Floodlights on", user)
		if ("Sonar ping")
			B.sonar_ping(user)
		if ("Raise periscope")
			B.raise_periscope(user, src)
		if ("Lower periscope")
			B.lower_periscope(user)
		if ("Name the boat")
			B.order_name(user, src)
		if ("Paint the stripes")
			B.order_paint(user, src)

// ---- Hull ----

// Hull walls, in the frame wall format: name, opacity, density, armour,
// health, can open, is open. The outer hull and the glass of the bow are
// drawn into the deck art; bulkheads and watertight doors are overlays.
#define SUB_WALL_HULL list("boat_port0",TRUE,TRUE,30,40,FALSE,FALSE)
#define SUB_WALL_GLASS list("sub_glass",FALSE,TRUE,30,40,FALSE,FALSE)
#define SUB_WALL_BULKHEAD list("sub_bulkhead",TRUE,TRUE,30,40,FALSE,FALSE)
#define SUB_WALL_DOOR list("sub_door",TRUE,TRUE,30,40,TRUE,FALSE)
// The plating over a sealed tank space: a wall with nothing to draw.
#define SUB_WALL_TANK list("sub_tank",TRUE,TRUE,30,40,FALSE,FALSE)

// A steel hull section: decked and roofed. Its deck and roof art is one tile
// of the whole boat's drawing (scripts/draw_submarine_hull.py), picked by
// hull_tile: "<class>_<column>_<row>" of the layout table.
/obj/structure/vehicleparts/frame/ship/steel/submarine
	name = "submarine hull"
	desc = "A riveted steel pressure hull section."
	icon = 'icons/obj/vehicles/submarine_hull.dmi'
	icon_state = "plain_deck"
	normal_icon = 'icons/obj/vehicles/submarine_hull.dmi'
	broken_icon = 'icons/obj/vehicles/submarine_hull.dmi'
	prefix = ""
	noroof = FALSE
	var/hull_tile = "plain"

/obj/structure/vehicleparts/frame/ship/steel/submarine/update_icon()
	overlays.Cut()
	if (!axis)
		dir = NORTH
	icon_state = "[hull_tile]_deck"
	// One roof image for the frame's life: clients that already hold it see
	// it turn with the boat.
	if (!roof || roof.icon != icon)
		roof = image(icon = icon, loc = src, icon_state = "[hull_tile]_roof", layer = 11)
	roof.icon_state = axis ? "[hull_tile]_roof" : ""
	roof.dir = dir
	// Repainted stripes lie over the factory ones drawn into the roof.
	roof.overlays.Cut()
	var/obj/structure/vehicleparts/axis/ship/submarine/boat = axis
	if (istype(boat) && boat.stripe_color != SUBMARINE_STRIPE_DEFAULT && has_stripe())
		var/image/stripe = image(icon = icon, icon_state = "[hull_tile]_stripe", dir = dir)
		stripe.color = boat.stripe_color
		roof.overlays += stripe
	var/list/sides = list(list(w_front, dir), list(w_back, turn(dir, 180)), list(w_left, turn(dir, 90)), list(w_right, turn(dir, -90)))
	for (var/list/side in sides)
		var/list/wall = side[1]
		var/state = null
		switch (wall[1])
			if ("sub_bulkhead")
				state = "sub_bulkhead"
			if ("sub_door")
				state = wall[7] ? "sub_door_open" : "sub_door_closed"
		if (state)
			overlays += image(icon = icon, icon_state = state, layer = 2.99, dir = side[2])

// Whether one of the hull stripes crosses this section's roof.
/obj/structure/vehicleparts/frame/ship/steel/submarine/proc/has_stripe()
	var/static/list/stripe_states = null
	if (!stripe_states)
		stripe_states = list()
		for (var/state in icon_states('icons/obj/vehicles/submarine_hull.dmi'))
			if (findtext(state, "_stripe"))
				stripe_states[state] = TRUE
	return stripe_states["[hull_tile]_stripe"]

// The watertight doors in the bulkheads swing by hand from either side.
/obj/structure/vehicleparts/frame/ship/steel/submarine/proc/door_walls()
	. = list()
	for (var/list/wall in list(w_front, w_back, w_left, w_right))
		if (wall[1] == "sub_door")
			. += list(wall)

/obj/structure/vehicleparts/frame/ship/steel/submarine/proc/toggle_doors(mob/user)
	var/list/doors = door_walls()
	if (!doors.len)
		return FALSE
	var/list/first = doors[1]
	var/open = !first[7]
	for (var/list/wall in doors)
		wall[7] = open
	update_icon()
	playsound(loc, 'sound/effects/door_lock_unlock.ogg', 60)
	if (user)
		user.visible_message(SPAN_NOTICE("[user] [open ? "spins the wheel and swings the watertight door open" : "swings the watertight door shut and dogs it down"]."))
	return TRUE

/obj/structure/vehicleparts/frame/ship/steel/submarine/attack_hand(mob/living/human/user)
	if (ishuman(user) && Adjacent(user) && toggle_doors(user))
		return
	return ..()

/obj/structure/vehicleparts/frame/ship/steel/submarine/examine(mob/user)
	. = ..()
	var/list/doors = door_walls()
	if (doors.len)
		var/list/first = doors[1]
		to_chat(user, SPAN_NOTICE("Its watertight door is [first[7] ? "open" : "shut"]. Use the hull section with an empty hand to work it."))

// Amidships the sides open: the hatches crew and cargo use on the surface,
// and the lock-out chambers divers use submerged (seabed.dm).
/obj/structure/vehicleparts/frame/ship/steel/submarine/hatch

// Sets a hull section's walls from a layout code: letters for the sides
// (F bow side, B stern side, L port, R starboard), each followed by its
// wall (h hull, g glass, b bulkhead, d watertight door, t tank plating),
// as in "Fg Rg".
/obj/structure/vehicleparts/frame/ship/steel/submarine/proc/set_hull_walls(code)
	for (var/part in splittext(code, " "))
		if (length(part) != 2)
			continue
		var/list/wall = null
		switch (copytext(part, 2, 3))
			if ("h")
				wall = SUB_WALL_HULL
			if ("g")
				wall = SUB_WALL_GLASS
			if ("b")
				wall = SUB_WALL_BULKHEAD
			if ("d")
				wall = SUB_WALL_DOOR
			if ("t")
				wall = SUB_WALL_TANK
		if (!wall)
			continue
		switch (copytext(part, 1, 2))
			if ("F")
				w_front = wall
			if ("B")
				w_back = wall
			if ("L")
				w_left = wall
			if ("R")
				w_right = wall

// ---- Fittings ----

// The boat's battery and air bank are numbers on the boat; these are where
// the crew can see them.
/obj/structure/vehicleparts/sub_fitting
	name = "submarine fitting"
	desc = "A fitting bolted to a submarine's deck."
	icon = 'icons/obj/vehicles/submarine_hull.dmi'
	anchored = TRUE
	density = TRUE
	layer = 2.99

/obj/structure/vehicleparts/sub_fitting/proc/boat()
	return submarine_at(get_turf(src))

/obj/structure/vehicleparts/sub_fitting/proc/reading(obj/structure/vehicleparts/axis/ship/submarine/B)
	return null

/obj/structure/vehicleparts/sub_fitting/examine(mob/user)
	. = ..()
	var/obj/structure/vehicleparts/axis/ship/submarine/B = boat()
	if (B)
		to_chat(user, SPAN_NOTICE(reading(B)))

/obj/structure/vehicleparts/sub_fitting/battery
	name = "battery bank"
	desc = "Racks of lead-acid cells that drive the boat's motor, floodlights and sonar while it is submerged. The diesel charges them on the surface."
	icon_state = "battery_bank"

/obj/structure/vehicleparts/sub_fitting/battery/reading(obj/structure/vehicleparts/axis/ship/submarine/B)
	return B.systems_report()

/obj/structure/vehicleparts/sub_fitting/air
	name = "air bank"
	desc = "Flasks of compressed air that keep the hull air fresh, blow the lock-out chambers dry and fill diving bottles. The compressor refills them on the surface."
	icon_state = "air_bank"

/obj/structure/vehicleparts/sub_fitting/air/reading(obj/structure/vehicleparts/axis/ship/submarine/B)
	return B.air_report()

// A locker for diving dress, helmets and bottles beside the lock-out chambers.
/obj/structure/closet/dive_locker
	name = "dive locker"
	desc = "A steel locker for diving dress, helmets and air bottles."
	anchored = TRUE

// ---- Layouts ----

// Each boat is 3 wide and faces south when built, as "column,row" from its
// bow; column 1 is the starboard (west) side. An entry lists the hull
// section's type, its wall code (set_hull_walls) and whatever is fitted
// there. Like the landing craft a submarine steers from a ship wheel and
// runs on a diesel engine. The stern quarters are sealed tank spaces.
#define SUB_HULL /obj/structure/vehicleparts/frame/ship/steel/submarine
#define SUB_HATCH /obj/structure/vehicleparts/frame/ship/steel/submarine/hatch
var/global/list/submarine_layouts = list(
	// Scout: helm under the glass bow, the lock-out chambers amidships and
	// the engine room behind a watertight door.
	"scout" = list(
		"1,1" = list(SUB_HULL, "Fg Rg"),
		"2,1" = list(SUB_HULL, "Fg", /obj/structure/vehicleparts/shipwheel),
		"3,1" = list(SUB_HULL, "Fg Lg"),
		"1,2" = list(SUB_HULL, "Rh", /obj/structure/vehicleparts/sub_station),
		"2,2" = list(SUB_HULL, ""),
		"3,2" = list(SUB_HULL, "Lh", /obj/structure/closet/dive_locker),
		"1,3" = list(SUB_HATCH, "Fb"),
		"2,3" = list(SUB_HULL, ""),
		"3,3" = list(SUB_HATCH, "Fb"),
		"1,4" = list(SUB_HULL, "Rh Fb", /obj/structure/vehicleparts/sub_fitting/battery),
		"2,4" = list(SUB_HULL, "Fd"),
		"3,4" = list(SUB_HULL, "Lh Fb", /obj/structure/vehicleparts/sub_fitting/air),
		"1,5" = list(SUB_HULL, "Rh Bh Ft Lt"),
		"2,5" = list(SUB_HULL, "Bh", /obj/structure/engine/internal/diesel/premade/chiha, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank),
		"3,5" = list(SUB_HULL, "Lh Bh Ft Rt"),
		),
	// Explorer: the Scout's plan with a berth forward of the lock-out
	// chambers and a locker space aft of them.
	"explorer" = list(
		"1,1" = list(SUB_HULL, "Fg Rg"),
		"2,1" = list(SUB_HULL, "Fg", /obj/structure/vehicleparts/shipwheel),
		"3,1" = list(SUB_HULL, "Fg Lg"),
		"1,2" = list(SUB_HULL, "Rh", /obj/structure/vehicleparts/sub_station),
		"2,2" = list(SUB_HULL, ""),
		"3,2" = list(SUB_HULL, "Lh", /obj/structure/closet),
		"1,3" = list(SUB_HULL, "Rh Fb", /obj/structure/bed),
		"2,3" = list(SUB_HULL, "Fd"),
		"3,3" = list(SUB_HULL, "Lh Fb", /obj/structure/bed),
		"1,4" = list(SUB_HATCH, "Fb"),
		"2,4" = list(SUB_HULL, ""),
		"3,4" = list(SUB_HATCH, "Fb"),
		"1,5" = list(SUB_HULL, "Rh Fb", /obj/structure/closet/dive_locker),
		"2,5" = list(SUB_HULL, ""),
		"3,5" = list(SUB_HULL, "Lh Fb", /obj/structure/closet),
		"1,6" = list(SUB_HULL, "Rh Fb", /obj/structure/vehicleparts/sub_fitting/battery),
		"2,6" = list(SUB_HULL, "Fd"),
		"3,6" = list(SUB_HULL, "Lh Fb", /obj/structure/vehicleparts/sub_fitting/air),
		"1,7" = list(SUB_HULL, "Rh Bh Ft Lt"),
		"2,7" = list(SUB_HULL, "Bh", /obj/structure/engine/internal/diesel/premade/chiha, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank),
		"3,7" = list(SUB_HULL, "Lh Bh Ft Rt"),
		),
	)
#undef SUB_HULL
#undef SUB_HATCH

#define SUBMARINE_WIDTH 3

// The Explorer: a longer boat with berths and lockers. Slower than the Scout.
/obj/structure/vehicleparts/axis/ship/submarine/explorer
	name = "explorer submarine"
	desc = "The rudder and dive planes of a long steel submarine."
	hull_class = "explorer"
	speedlist = alist(1=18,2=14,3=11)

/obj/structure/vehicleparts/axis/ship/submarine/proc/hull_layout()
	return submarine_layouts[hull_class] || submarine_layouts["scout"]

// The side of the square of water the boat turns in: its length.
/obj/structure/vehicleparts/axis/ship/submarine/proc/hull_square()
	. = 0
	for (var/coords in hull_layout())
		. = max(., text2num(splittext(coords, ",")[2]))

// Builds a submarine of the given model in one call, origin being the
// bottom-left turf of its turning square; the hull lies against the square's
// east edge with the bow to the south. Returns the axis, or null when a tile
// is off the map.
/proc/build_submarine(turf/origin, name = null, model = /obj/structure/vehicleparts/axis/ship/submarine)
	if (!origin || !ispath(model, /obj/structure/vehicleparts/axis/ship/submarine))
		return null
	var/obj/structure/vehicleparts/axis/ship/submarine/A = new model()
	if (name)
		A.name = name
	A.dir = SOUTH
	A.anchor = FALSE
	A.new_number()
	var/list/layout = A.hull_layout()
	var/square = A.hull_square()
	var/list/parts = list()
	for (var/coords in layout)
		var/list/C = splittext(coords, ",")
		var/turf/T = locate(origin.x + square - SUBMARINE_WIDTH + text2num(C[1]) - 1, origin.y + text2num(C[2]) - 1, origin.z)
		if (!T)
			for (var/obj/O in parts)
				qdel(O)
			qdel(A)
			return null
		var/list/entry = layout[coords]
		for (var/partpath in entry)
			if (!ispath(partpath))
				continue
			var/obj/O = new partpath(T)
			parts += O
			O.dir = SOUTH
			O.anchored = TRUE
			if (istype(O, /obj/structure/vehicleparts/frame))
				var/obj/structure/vehicleparts/frame/ship/steel/submarine/F = O
				F.axis = A
				F.name = A.name
				F.hull_tile = "[A.hull_class]_[C[1]]_[C[2]]"
				F.set_hull_walls(entry[2])
				A.components += F
			if (istype(O, /obj/structure/engine))
				var/obj/structure/engine/E = O
				A.engine = E
				E.key_axis = A
				E.engineclass = "engine"
				E.icon = 'icons/obj/vehicles/vehicleparts.dmi'
			if (istype(O, /obj/structure/vehicleparts/shipwheel))
				var/obj/structure/vehicleparts/shipwheel/W = O
				W.ship = A
	for (var/obj/item/weapon/reagent_containers/glass/barrel/fueltank/F in parts)
		A.engine.fueltank = F
	A.check_corners()
	A.loc = A.corners[2]
	for (var/dx = 0, dx < square, dx++)
		for (var/dy = 0, dy < square, dy++)
			var/turf/T = locate(origin.x + dx, origin.y + dy, origin.z)
			if (T && !(locate(/obj/structure/vehicleparts/frame) in T))
				var/obj/effect/pseudovehicle/P = new(T)
				P.link = A
				P.dir = SOUTH
				A.components += P
	A.check_matrix()
	A.add_transporting(FALSE)
	for (var/obj/O in parts)
		O.update_icon()
	return A

// ---- Submarine pen: players build the boat ----

// A slipway press on the shore that launches a submarine into the square of
// water northeast of it, like the aircraft hangar builds a plane: 5x5 for the
// Scout and 7x7 for the Explorer.
/obj/structure/car_workshop/submarine_pen
	name = "submarine pen"
	desc = "A covered slipway and riveting press. Feed it steel, glass and cable. It launches a submarine into the clear square of deep sea northeast of the press: 5x5 for a Scout, 7x7 for an Explorer. The boat leaves with an empty diesel tank."
	icon_state = "workbench"

/obj/structure/car_workshop/submarine_pen/models()
	return list("Scout submarine" = /obj/structure/vehicleparts/axis/ship/submarine, "Explorer submarine" = /obj/structure/vehicleparts/axis/ship/submarine/explorer)

/obj/structure/car_workshop/submarine_pen/required_nodes()
	return list("submarines")

/obj/structure/car_workshop/submarine_pen/model_size(model)
	var/list/M = models()
	if (!(model in M))
		return 0
	var/modelpath = M[model]
	var/obj/structure/vehicleparts/axis/ship/submarine/A = modelpath
	var/list/layout = submarine_layouts[initial(A.hull_class)]
	. = 0
	for (var/coords in layout)
		. = max(., text2num(splittext(coords, ",")[2]))

// The pen only has to fit the Scout where it stands; an Explorer needs its
// larger square clear when it is launched.
/obj/structure/car_workshop/submarine_pen/largest_model_size()
	return model_size("Scout submarine")

/obj/structure/car_workshop/submarine_pen/costs(model)
	switch (model)
		if ("Scout submarine")
			return list("steel" = 90, "glass" = 4, "cable" = 12)
		if ("Explorer submarine")
			return list("steel" = 140, "glass" = 8, "cable" = 20)
	return null

/obj/structure/car_workshop/submarine_pen/bay_floor(turf/T)
	return istype(T, /turf/floor/beach/water/deep/saltwater) && !sea_layer_cell(T) && !T.density

/obj/structure/car_workshop/submarine_pen/build_refusal(mob/living/human/H, turf/origin)
	. = ..()
	if (.)
		var/size = largest_model_size()
		. = replacetext(., "a dry, open [size]x[size] floor bay", "a [size]x[size] square of open deep sea")

/obj/structure/car_workshop/submarine_pen/menu_text()
	return "Stored: [stock["steel"]] steel, [stock["glass"]] glass, [stock["cable"]] cable. A Scout costs 90 steel, 4 glass and 12 cable and needs the 5x5 square of deep sea northeast of the press clear. An Explorer costs 140 steel, 8 glass and 20 cable and needs a 7x7 square."

/obj/structure/car_workshop/submarine_pen/assembled_message(model)
	return "Your [lowertext(model)] is launched. Fill its tank with diesel, then use the ballast and periscope station aboard to dive once you reach open ocean."

/obj/structure/car_workshop/submarine_pen/complete_assembly(model)
	if (!has_inputs(model) || !clear_footprint(model))
		return null
	var/list/M = models()
	var/obj/structure/vehicleparts/axis/ship/submarine/A = build_submarine(locate(x + 1, y + 1, z), null, M[model])
	if (!A)
		return null
	var/list/required = costs(model)
	for (var/key in required)
		stock[key] -= required[key]
	if (!vehicle_key_service.issue_constructed(A, get_turf(src)))
		return null
	return A

#undef SUBMARINE_WIDTH
#undef SUBMARINE_STRIPE_DEFAULT
#undef SUBMARINE_PAINT_TIME
#undef SUB_WALL_HULL
#undef SUB_WALL_GLASS
#undef SUB_WALL_BULKHEAD
#undef SUB_WALL_DOOR
#undef SUB_WALL_TANK
#undef SUBMARINE_PERISCOPE_RANGE
#undef SUBMARINE_SONAR_RANGE
#undef SUBMARINE_BALLAST_TIME
#undef SUBMARINE_PERISCOPE_CHECK
