// Player submarines: a steel ship that dives into the sea layer (sea_layer.dm).
//
// On the surface a submarine is an ordinary engine-driven ship: it steers
// from its ship wheel, sails over any water and comes alongside piers, where
// its crew walk on and off through the open hatches amidships and carry crates
// aboard. Submerged, the whole boat, crew and cargo drop to the level below,
// where it can go only where the ocean above is open: the coast, islands and
// shallows are rock down there. Nobody can leave a submerged boat.
//
// The ballast and periscope station aboard dives, surfaces, raises the
// periscope (the surface straight above, following the boat) and lists the
// contacts in range: ships and aircraft above, and other submerged boats by
// sonar.

// Tiles at which the periscope picks out ships and aircraft on the surface,
// and sonar other submerged boats.
#define SUBMARINE_PERISCOPE_RANGE 30
#define SUBMARINE_SONAR_RANGE 20
// How long flooding or blowing the ballast tanks takes.
#define SUBMARINE_BALLAST_TIME (3 SECONDS)
// How often the periscope checks its watchers are still at the eyepiece.
#define SUBMARINE_PERISCOPE_CHECK (1 SECONDS)

var/global/list/player_submarines = list()

/obj/structure/vehicleparts/axis/ship/submarine
	name = "submarine"
	desc = "The rudder and dive planes of a steel submarine."
	speeds = 3
	maxpower = 2500
	speedlist = alist(1=16,2=12,3=9)
	var/submerged = FALSE
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
	if (. && periscope_watchers.len)
		update_periscopes()

// Below the surface the boat is in the dark; its lamps light the hull.
/obj/structure/vehicleparts/axis/ship/submarine/proc/update_boat_lights()
	for (var/obj/structure/vehicleparts/sub_station/S in transporting)
		S.update_light_state(submerged)

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

// ---- The ballast and periscope station ----

/obj/structure/vehicleparts/sub_station
	name = "ballast and periscope station"
	desc = "Valve wheels for the ballast tanks and the eyepiece of the periscope. Use it to dive, surface, raise the periscope or read the contacts."
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
	var/list/options = list(B.submerged ? "Surface" : "Dive", "Contacts")
	if (B.submerged)
		options += (user in B.periscope_watchers) ? "Lower periscope" : "Raise periscope"
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
		if ("Raise periscope")
			B.raise_periscope(user, src)
		if ("Lower periscope")
			B.lower_periscope(user)

// ---- Hull ----

// A steel hull section: decked and roofed, dark grey from outside.
/obj/structure/vehicleparts/frame/ship/steel/submarine
	name = "submarine hull"
	desc = "A riveted steel pressure hull section."
	noroof = FALSE

/obj/structure/vehicleparts/frame/ship/steel/submarine/update_icon()
	..()
	if (roof)
		roof.color = "#46505a"

/obj/structure/vehicleparts/frame/ship/steel/submarine/bow_right
	w_front = list("boat_port0",TRUE,TRUE,30,40,FALSE,FALSE)
	w_right = list("boat_port0",TRUE,TRUE,30,40,FALSE,FALSE)
/obj/structure/vehicleparts/frame/ship/steel/submarine/bow
	w_front = list("boat_port0",TRUE,TRUE,30,40,FALSE,FALSE)
/obj/structure/vehicleparts/frame/ship/steel/submarine/bow_left
	w_front = list("boat_port0",TRUE,TRUE,30,40,FALSE,FALSE)
	w_left = list("boat_port0",TRUE,TRUE,30,40,FALSE,FALSE)
/obj/structure/vehicleparts/frame/ship/steel/submarine/right
	w_right = list("boat_port0",TRUE,TRUE,30,40,FALSE,FALSE)
/obj/structure/vehicleparts/frame/ship/steel/submarine/left
	w_left = list("boat_port0",TRUE,TRUE,30,40,FALSE,FALSE)
// Amidships the sides open: the hatches crew and cargo use on the surface.
/obj/structure/vehicleparts/frame/ship/steel/submarine/hatch
/obj/structure/vehicleparts/frame/ship/steel/submarine/stern_right
	w_back = list("boat_port0",TRUE,TRUE,30,40,FALSE,FALSE)
	w_right = list("boat_port0",TRUE,TRUE,30,40,FALSE,FALSE)
/obj/structure/vehicleparts/frame/ship/steel/submarine/stern
	w_back = list("boat_port0",TRUE,TRUE,30,40,FALSE,FALSE)
/obj/structure/vehicleparts/frame/ship/steel/submarine/stern_left
	w_back = list("boat_port0",TRUE,TRUE,30,40,FALSE,FALSE)
	w_left = list("boat_port0",TRUE,TRUE,30,40,FALSE,FALSE)

// A 3-wide, 5-long boat facing south, as "column,row" from its bow; column 1
// is the starboard (west) side. Like the landing craft it steers from a ship
// wheel and runs on a diesel engine.
var/global/list/submarine_layout = list(
	"1,1" = list(/obj/structure/vehicleparts/frame/ship/steel/submarine/bow_right),
	"2,1" = list(/obj/structure/vehicleparts/frame/ship/steel/submarine/bow),
	"3,1" = list(/obj/structure/vehicleparts/frame/ship/steel/submarine/bow_left),
	"1,2" = list(/obj/structure/vehicleparts/frame/ship/steel/submarine/right),
	"2,2" = list(/obj/structure/vehicleparts/frame/ship/steel/submarine, /obj/structure/vehicleparts/shipwheel),
	"3,2" = list(/obj/structure/vehicleparts/frame/ship/steel/submarine/left),
	"1,3" = list(/obj/structure/vehicleparts/frame/ship/steel/submarine/hatch),
	"2,3" = list(/obj/structure/vehicleparts/frame/ship/steel/submarine, /obj/structure/vehicleparts/sub_station),
	"3,3" = list(/obj/structure/vehicleparts/frame/ship/steel/submarine/hatch),
	"1,4" = list(/obj/structure/vehicleparts/frame/ship/steel/submarine/right),
	"2,4" = list(/obj/structure/vehicleparts/frame/ship/steel/submarine),
	"3,4" = list(/obj/structure/vehicleparts/frame/ship/steel/submarine/left),
	"1,5" = list(/obj/structure/vehicleparts/frame/ship/steel/submarine/stern_right),
	"2,5" = list(/obj/structure/vehicleparts/frame/ship/steel/submarine/stern, /obj/structure/engine/internal/diesel/premade/chiha, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank),
	"3,5" = list(/obj/structure/vehicleparts/frame/ship/steel/submarine/stern_left),
	)

#define SUBMARINE_SQUARE 5
#define SUBMARINE_WIDTH 3

// Builds a submarine in one call, origin being the bottom-left turf of its
// 5x5 turning square; the hull lies against the square's east edge with the
// bow to the south. Returns the axis, or null when a tile is off the map.
/proc/build_submarine(turf/origin, name = null)
	if (!origin)
		return null
	var/obj/structure/vehicleparts/axis/ship/submarine/A = new()
	if (name)
		A.name = name
	A.dir = SOUTH
	A.anchor = FALSE
	A.new_number()
	var/list/parts = list()
	for (var/coords in submarine_layout)
		var/list/C = splittext(coords, ",")
		var/turf/T = locate(origin.x + SUBMARINE_SQUARE - SUBMARINE_WIDTH + text2num(C[1]) - 1, origin.y + text2num(C[2]) - 1, origin.z)
		if (!T)
			for (var/obj/O in parts)
				qdel(O)
			qdel(A)
			return null
		for (var/partpath in submarine_layout[coords])
			var/obj/O = new partpath(T)
			parts += O
			O.dir = SOUTH
			O.anchored = TRUE
			if (istype(O, /obj/structure/vehicleparts/frame))
				var/obj/structure/vehicleparts/frame/F = O
				F.axis = A
				F.name = A.name
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
	for (var/dx = 0, dx < SUBMARINE_SQUARE, dx++)
		for (var/dy = 0, dy < SUBMARINE_SQUARE, dy++)
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

// A slipway press on the shore that launches a submarine into the 5x5 square
// of water northeast of it, like the aircraft hangar builds a plane.
/obj/structure/car_workshop/submarine_pen
	name = "submarine pen"
	desc = "A covered slipway and riveting press. Feed it steel, glass and cable. It launches a submarine into the clear 5x5 square of water northeast of the press. The boat leaves with an empty diesel tank."
	icon_state = "workbench"

/obj/structure/car_workshop/submarine_pen/models()
	return list("Submarine" = /obj/structure/vehicleparts/axis/ship/submarine)

/obj/structure/car_workshop/submarine_pen/required_nodes()
	return list("submarines")

/obj/structure/car_workshop/submarine_pen/model_size(model)
	return (model in models()) ? SUBMARINE_SQUARE : 0

/obj/structure/car_workshop/submarine_pen/costs(model)
	if (!(model in models()))
		return null
	return list("steel" = 90, "glass" = 4, "cable" = 12)

/obj/structure/car_workshop/submarine_pen/bay_floor(turf/T)
	return istype(T, /turf/floor/beach/water/deep/saltwater) && !sea_layer_cell(T) && !T.density

/obj/structure/car_workshop/submarine_pen/build_refusal(mob/living/human/H, turf/origin)
	. = ..()
	if (.)
		. = replacetext(., "a dry, open [SUBMARINE_SQUARE]x[SUBMARINE_SQUARE] floor bay", "a [SUBMARINE_SQUARE]x[SUBMARINE_SQUARE] square of open deep sea")

/obj/structure/car_workshop/submarine_pen/menu_text()
	return "Stored: [stock["steel"]] steel, [stock["glass"]] glass, [stock["cable"]] cable. A submarine costs 90 steel, 4 glass and 12 cable. Keep the 5x5 square of deep sea northeast of the press clear."

/obj/structure/car_workshop/submarine_pen/assembled_message(model)
	return "Your submarine is launched. Fill its tank with diesel, then use the ballast and periscope station aboard to dive once you reach open ocean."

/obj/structure/car_workshop/submarine_pen/complete_assembly(model)
	if (!has_inputs(model) || !clear_footprint(model))
		return null
	var/obj/structure/vehicleparts/axis/ship/submarine/A = build_submarine(locate(x + 1, y + 1, z))
	if (!A)
		return null
	var/list/required = costs(model)
	for (var/key in required)
		stock[key] -= required[key]
	if (!vehicle_key_service.issue_constructed(A, get_turf(src)))
		return null
	return A

#undef SUBMARINE_SQUARE
#undef SUBMARINE_WIDTH
#undef SUBMARINE_PERISCOPE_RANGE
#undef SUBMARINE_SONAR_RANGE
#undef SUBMARINE_BALLAST_TIME
#undef SUBMARINE_PERISCOPE_CHECK
