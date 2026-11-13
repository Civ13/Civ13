// ============================================================
// Vehicle assembly (docs/craft-core.md): building a land vehicle by hand
// ------------------------------------------------------------
// A player lays vehicle frames side by side, stands the parts on them and
// sets an axis down on any one frame. Clicking the axis surveys what is
// joined to that frame, the way a helm surveys a hull: the frames must fill
// a rectangle, and the survey says in plain words what it found and what a
// vehicle still needs to drive. Assembling binds every frame and part in
// one step, facing the way the builder chose.
//
// This replaces the old routine, where the axis had to sit on the top left
// frame, every frame within two tiles was swallowed whether it belonged or
// not, and nothing said why a vehicle would not move.
//
// A hand-built vehicle can be taken apart again by its owners, and parts
// stood on it later are fitted from the same menu.
//
// A boat built from ship frames is assembled the same way from its rudder
// axis: its frames must lie on water, it takes a ship's wheel in place of a
// driver's seat, and masts or an engine in place of wheels.
// ============================================================

#define VEHICLE_ASSEMBLY_MIN 2

/obj/structure/vehicleparts/axis
	var/hand_built = FALSE   // Assembled by a player from loose frames.

// The frame on a tile that this axis could take or already has: ship
// frames for a rudder axis, land frames for any other.
/proc/vehicle_assembly_frame(turf/T, obj/structure/vehicleparts/axis/A)
	if (!T || !A)
		return null
	for (var/obj/structure/vehicleparts/frame/F in T)
		if (istype(F, /obj/structure/vehicleparts/frame/ship) != (A.ship ? TRUE : FALSE))
			continue
		// Airframe sections and submarine hull sections only take their own controls.
		if (!vehicle_assembly_kind_matches(F, A))
			continue
		if (!F.axis || F.axis == A)
			return F
	return null

// The longest side a vehicle on this axis may have.
/obj/structure/vehicleparts/axis/proc/assembly_max_size()
	return VEHICLE_CONSTANTS.MAX_VEHICLE_SIZE

// ---- The survey ----

/datum/vehicle_survey
	var/obj/structure/vehicleparts/axis/axis
	var/list/frames = list()
	var/min_x = 0
	var/max_x = 0
	var/min_y = 0
	var/max_y = 0
	var/width = 0                // Tiles west to east.
	var/height = 0               // Tiles south to north.
	var/refusal = null           // Why this cannot be a vehicle, or null.
	var/ship = FALSE             // A boat of ship frames, surveyed from a rudder axis.
	var/obj/structure/engine/engine
	var/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank
	var/obj/structure/bed/chair/drivers/seat
	var/obj/structure/vehicleparts/shipwheel/helm
	var/obj/structure/vehicleparts/sub_station/station  // A submarine's ballast and periscope station.
	var/list/movers = list()     // Wheels and tracks standing on corner frames.
	var/loose_movers = 0         // Wheels and tracks standing anywhere else.
	var/list/masts = list()
	var/list/turrets = list()    // Built turrets standing on the frames.

/datum/vehicle_survey/New(obj/structure/vehicleparts/axis/A)
	..()
	axis = A
	if (!A)
		refusal = "there is no axis"
		return
	ship = A.ship ? TRUE : FALSE
	var/obj/structure/vehicleparts/frame/first = vehicle_assembly_frame(get_turf(A), A)
	if (!first)
		refusal = ship ? "the rudder axis must stand on one of the boat's ship frames" : "the axis must stand on one of the vehicle's frames"
		return
	var/limit = VEHICLE_CONSTANTS.MAX_COMPONENTS
	var/list/queue = list(first)
	frames += first
	while (queue.len)
		var/obj/structure/vehicleparts/frame/F = queue[1]
		queue.Cut(1, 2)
		for (var/d in list(NORTH, SOUTH, EAST, WEST))
			var/obj/structure/vehicleparts/frame/N = vehicle_assembly_frame(get_step(F, d), A)
			if (!N || (N in frames))
				continue
			frames += N
			queue += N
		if (frames.len > limit)
			refusal = "more than [limit] frames are joined here; a vehicle can have [limit] at most"
			return
	min_x = first.x
	max_x = first.x
	min_y = first.y
	max_y = first.y
	for (var/obj/structure/vehicleparts/frame/F in frames)
		min_x = min(min_x, F.x)
		max_x = max(max_x, F.x)
		min_y = min(min_y, F.y)
		max_y = max(max_y, F.y)
	width = max_x - min_x + 1
	height = max_y - min_y + 1
	var/most = A.assembly_max_size()
	if (width > most || height > most)
		refusal = "the frames are [width] by [height] tiles; a vehicle can be [most] long and wide at most"
		return
	if (width < VEHICLE_ASSEMBLY_MIN || height < VEHICLE_ASSEMBLY_MIN)
		refusal = "the frames are [width] by [height] tiles; a vehicle needs [VEHICLE_ASSEMBLY_MIN] by [VEHICLE_ASSEMBLY_MIN] at least"
		return
	var/gaps = width * height - frames.len
	if (gaps)
		refusal = "the frames must fill a rectangle: [gaps] of the [width] by [height] tiles [gaps == 1 ? "has" : "have"] no frame"
		return
	refusal = A.assembly_refusal(src)
	if (refusal)
		return
	if (ship)
		var/dry = 0
		for (var/obj/structure/vehicleparts/frame/F in frames)
			var/turf/T = get_turf(F)
			if (!istype(T, /turf/floor/beach/water) && !istype(T, /turf/floor/trench/flooded))
				dry++
		if (dry)
			refusal = "every ship frame must lie on water: [dry] [dry == 1 ? "does" : "do"] not"
			return
	find_parts()

// TRUE for the four corner tiles of the surveyed rectangle.
/datum/vehicle_survey/proc/is_corner(turf/T)
	return T && (T.x == min_x || T.x == max_x) && (T.y == min_y || T.y == max_y)

// What stands on the frames and could be fitted.
/datum/vehicle_survey/proc/find_parts()
	for (var/obj/structure/vehicleparts/frame/F in frames)
		var/turf/T = get_turf(F)
		for (var/obj/structure/engine/E in T)
			if (!engine && (ship || istype(E, /obj/structure/engine/internal)))
				engine = E
		for (var/obj/item/weapon/reagent_containers/glass/barrel/fueltank/K in T)
			if (!tank)
				tank = K
		for (var/obj/structure/bed/chair/drivers/D in T)
			// A plane is flown from a pilot's seat, whose column climbs and descends.
			if (istype(axis, /obj/structure/vehicleparts/axis/aircraft) != istype(D, /obj/structure/bed/chair/drivers/aircraft))
				continue
			if (!seat && (!D.axis || D.axis == axis))
				seat = D
		for (var/obj/structure/turret/built/B in T)
			turrets += B
		for (var/obj/structure/vehicleparts/shipwheel/W in T)
			if (!helm && (!W.ship || W.ship == axis))
				helm = W
		if (!station)
			station = locate(/obj/structure/vehicleparts/sub_station) in T
		for (var/obj/structure/vehicleparts/movement/M in T)
			if (M.axis && M.axis != axis)
				continue
			if (istype(M, /obj/structure/vehicleparts/movement/sail))
				if (ship)
					masts |= M
				continue
			if (ship)
				continue
			if (is_corner(T))
				movers += M
			else
				loose_movers++
		// A fitted wheel lies inside its frame.
		if (F.mwheel && F.mwheel.axis == axis)
			if (istype(F.mwheel, /obj/structure/vehicleparts/movement/sail))
				masts |= F.mwheel
			else
				movers |= F.mwheel
	// A tank already connected to the engine by hand counts.
	if (engine && engine.fueltank)
		tank = engine.fueltank

// What the vehicle still needs before it will drive, in words.
/datum/vehicle_survey/proc/missing()
	. = list()
	if (ship)
		if (!helm)
			. += "a ship's wheel"
		if (!masts.len && !engine)
			. += "a mast or an engine"
		if (istype(engine, /obj/structure/engine/internal) && !tank)
			. += "a fuel tank for the engine"
		if (istype(axis, /obj/structure/vehicleparts/axis/ship/submarine) && !station)
			. += "a ballast and periscope station to dive"
		return
	if (!engine)
		. += "an engine"
	if (!tank)
		. += "a fuel tank"
	if (!seat)
		. += istype(axis, /obj/structure/vehicleparts/axis/aircraft) ? "a pilot's seat" : "a driver's seat"
	if (movers.len < 4)
		. += "a wheel or track on each corner frame ([movers.len] of 4 fitted)"

/datum/vehicle_survey/proc/report()
	if (refusal)
		return "This cannot be made into a [ship ? "boat" : "vehicle"]: [refusal]."
	var/list/lines = list("<b>[width] by [height] frames</b>, [frames.len] in all.")
	var/list/found = list()
	if (engine)
		found += "\the [engine]"
	if (tank)
		found += "\the [tank]"
	if (seat)
		found += "\the [seat]"
	if (helm)
		found += "\the [helm]"
	if (station && istype(axis, /obj/structure/vehicleparts/axis/ship/submarine))
		found += "\the [station]"
	if (masts.len)
		found += "[masts.len] mast\s"
	if (movers.len)
		found += "[movers.len] wheel\s or track\s on the corners"
	lines += found.len ? "Found on the frames: [english_list(found)]." : "Nothing is fitted on the frames yet."
	var/list/need = missing()
	if (need.len)
		lines += "Before it will [ship ? "sail" : "drive"] it still needs [english_list(need)]. Stand them on the frames; they can be fitted after assembly too."
	else
		lines += "It has everything a [ship ? "boat needs to sail" : "vehicle needs to drive"]."
	if (loose_movers)
		lines += "[loose_movers] wheel\s or track\s not on a corner frame will be left out."
	lines += turret_lines()
	return jointext(lines, "<br>")

// What each turret would still need once the things on its tile are fitted.
/datum/vehicle_survey/proc/turret_lines()
	. = list()
	for (var/obj/structure/turret/built/B in turrets)
		var/turf/T = get_turf(B)
		var/list/need = B.lacking()
		if (locate(/obj/structure/cannon/modern/tank) in T)
			need -= "a tank cannon"
		for (var/obj/structure/bed/chair/gunner/G in T)
			if (!G.turret)
				need -= "a gunner's seat"
		if (need.len)
			. += "Its turret cannot fire yet: stand [english_list(need)] on the turret's tile."
		else
			. += "Its turret has a gun and a gunner's seat."

// ---- Assembling ----

// The turning square: the body's front left corner, then to its right and
// to its back, as the workshop and the map vehicles lay it out.
/obj/structure/vehicleparts/axis/proc/assembly_square()
	. = list()
	var/obj/front_left = corners[2]
	if (!front_left)
		return
	var/right = turn(dir, -90)
	var/back = turn(dir, 180)
	for (var/i = 0, i < maxdist, i++)
		var/turf/row = get_turf(front_left)
		for (var/n = 1, n <= i && row, n++)
			row = get_step(row, back)
		for (var/j = 0, j < maxdist && row, j++)
			. += row
			row = get_step(row, right)

// Fits the engine, tank, seat and corner wheels now standing on this
// vehicle's frames. Returns how many parts were newly fitted.
/obj/structure/vehicleparts/axis/proc/fit_parts()
	. = 0
	var/datum/vehicle_survey/S = new(src)
	if (S.refusal)
		return
	if (S.engine && engine != S.engine)
		engine = S.engine
		engine.anchored = TRUE
		if (istype(engine, /obj/structure/engine/internal))
			engine.icon = 'icons/obj/vehicles/vehicleparts.dmi'
			if (istype(src, /obj/structure/vehicleparts/axis/car))
				engine.engineclass = "carengine"
				engine.density = TRUE
			else
				engine.engineclass = "engine"
			engine.update_icon()
		.++
	if (engine && S.tank && engine.fueltank != S.tank)
		engine.fueltank = S.tank
		S.tank.anchored = TRUE
		if (istype(src, /obj/structure/vehicleparts/axis/car))
			S.tank.icon_state = "fueltank_incar"
		.++
	if (S.seat && S.seat.wheel && wheel != S.seat.wheel)
		S.seat.anchored = TRUE
		S.seat.dir = dir
		S.seat.axis = src
		wheel = S.seat.wheel
		wheel.control = vehicle_assembly_frame(get_turf(S.seat), src)
		.++
	if (S.helm && S.helm.ship != src)
		S.helm.anchored = TRUE
		S.helm.dir = dir
		S.helm.ship = src
		.++
	for (var/obj/structure/vehicleparts/movement/sail/M in S.masts)
		if (M in masts)
			continue
		masts += M
		M.axis = src
		M.anchored = TRUE
		M.dir = dir
		M.update_icon()
		.++
	for (var/obj/structure/vehicleparts/movement/M in S.movers)
		if (M.axis == src && (M in wheels))
			continue
		var/obj/structure/vehicleparts/frame/F = vehicle_assembly_frame(get_turf(M), src)
		if (!F || F.mwheel)
			continue
		M.MouseDrop(F)
		if (M in wheels)
			.++
	for (var/obj/structure/turret/built/B in S.turrets)
		. += B.fit()
	for (var/obj/structure/vehicleparts/frame/F in S.frames)
		for (var/obj/structure/lamp/lamp_small/tank/L in get_turf(F))
			L.connection = engine
		for (var/obj/structure/vehicleparts/license_plate/P in get_turf(F))
			if (reg_number == "000")
				new_number()
			P.axis = src
			P.reg_number = reg_number
			P.name = "[reg_number]"

// Binds the surveyed frames and parts into a vehicle whose front points
// facing. Returns null, or why it could not be done.
/obj/structure/vehicleparts/axis/proc/assemble(facing = NORTH)
	if (components.len)
		return "it is assembled already"
	if (!(facing in list(NORTH, SOUTH, EAST, WEST)))
		facing = NORTH
	var/datum/vehicle_survey/S = new(src)
	if (S.refusal)
		return S.refusal
	dir = facing
	for (var/obj/structure/vehicleparts/frame/F in S.frames)
		F.axis = src
		F.anchored = TRUE
		F.dir = facing
		F.name = name
		if (doorcode)
			F.doorcode = doorcode
		components |= F
	if (!check_corners())
		take_apart()
		return "its corners could not be found"
	var/turf/front_left = get_turf(corners[2])
	if (get_turf(src) != front_left && !persistence_set_loc(front_left))
		take_apart()
		return "the axis cannot be moved to its place"
	for (var/turf/T in assembly_square())
		if (vehicle_assembly_frame(T, src) in components)
			continue
		var/obj/effect/pseudovehicle/P = new(T)
		P.link = src
		P.dir = facing
		components += P
	check_matrix()
	fit_parts()
	hand_built = TRUE
	for (var/obj/O in components)
		O.update_icon()
	return null

// Why this character may not take the vehicle apart, or null.
/obj/structure/vehicleparts/axis/proc/take_apart_refusal(mob/living/human/H)
	if (!components.len)
		return "it is not assembled"
	if (!hand_built)
		return "it was not built by hand"
	if (moving || currentspeed || (engine && engine.on))
		return "stop it and switch the engine off first"
	var/datum/craft/vehicle/C = craft_of_axis(src, FALSE)
	if (H && C && C.register && C.register.party && !C.register.is_owner(H))
		return "it is registered to [party_train_party_name(C.register.party)]"
	for (var/obj/structure/vehicleparts/frame/F in components)
		for (var/mob/living/L in get_turf(F))
			if (L.buckled)
				return "[L] is still seated in it"
	return null

// Unbinds everything: the frames and parts stay where they stand, loose.
/obj/structure/vehicleparts/axis/proc/take_apart()
	for (var/obj/structure/vehicleparts/movement/M in wheels)
		var/obj/structure/vehicleparts/frame/F = M.connected
		if (istype(F))
			if (F.mwheel == M)
				F.mwheel = null
			M.forceMove(get_turf(F))
		M.axis = null
		M.connected = null
		M.update_icon()
	wheels = list()
	for (var/obj/structure/turret/built/B in built_turrets())
		B.release()
	for (var/obj/structure/vehicleparts/movement/sail/M in masts)
		M.axis = null
		M.anchored = FALSE
		M.update_icon()
	masts = list()
	for (var/obj/O in components)
		for (var/obj/structure/vehicleparts/shipwheel/W in get_turf(O))
			if (W.ship == src)
				W.ship = null
				W.anchored = FALSE
	for (var/obj/O in components)
		if (istype(O, /obj/effect/pseudovehicle))
			qdel(O)
			continue
		var/obj/structure/vehicleparts/frame/F = O
		if (istype(F) && F.axis == src)
			F.axis = null
			F.name = initial(F.name)
			F.update_icon()
	components = list()
	if (engine)
		if (engine.fueltank)
			engine.fueltank.anchored = FALSE
			engine.fueltank = null
		engine.on = FALSE
		engine.anchored = FALSE
		engine = null
	if (wheel)
		var/obj/structure/bed/chair/drivers/D = wheel.drivingchair
		wheel.control = null
		if (D)
			D.axis = null
			D.anchored = FALSE
		wheel = null
	driver = null
	transporting = list()
	corners = list(null, null, null, null)
	matrix = list()
	matrix_current_locs = list()
	matrix_l = 0
	matrix_h = 0

// ---- What the builder sees ----

/obj/structure/vehicleparts/axis/proc/build_sheet()
	var/datum/vehicle_survey/S = new(src)
	if (!components.len)
		return S.report()
	var/list/lines = list("<b>[name]</b>, assembled.")
	if (!S.refusal)
		var/list/need = S.missing()
		if (need.len)
			lines += "Before it will [ship ? "sail" : "drive"] it still needs [english_list(need)]."
		else
			lines += "It has everything a [ship ? "boat needs to sail" : "vehicle needs to drive"]."
	if (!S.refusal)
		lines += S.turret_lines()
	var/weight = get_weight()
	var/carry = (engine && !ship) ? min(maxpower, engine.maxpower * 2) : maxpower
	lines += "It weighs [weight]; [engine ? "this axis and engine move" : "this axis carries"] up to [carry]."
	if (weight > carry)
		lines += "It is too heavy to move."
	return jointext(lines, "<br>")

var/global/list/vehicle_assembly_colors = list(
	"light gray" = "#A9A9A9",
	"medium gray" = "#585A5C",
	"dark gray" = "#3B3F41",
	"green" = "#3d5931",
	"pale green" = "#636351",
	"Feldgrau (WW1)" = "#5D5D3D",
	"Feldgrau (WW2)" = "#4D5D53",
	"light khaki" = "#F0E68C",
	"dark khaki" = "#BDB76B",
	"olive drab" = "#555346",
	"redmenian red" = "#774D4C",
	"blugoslavian blue" = "#8383C2",
)

// The colours this builder may paint a new vehicle.
/obj/structure/vehicleparts/axis/proc/assembly_colors(mob/living/human/H)
	if (map && (map.ID == MAP_NOMADS_PERSISTENCE_BETA || map.ID == MAP_NATIONSRP_COLDWAR_CMP))
		if (H.faction_text == REDFACTION)
			return list("redmenian red")
		if (H.faction_text == BLUEFACTION)
			return list("blugoslavian blue")
	return list("light gray", "medium gray", "dark gray", "green", "pale green", "Feldgrau (WW1)", "Feldgrau (WW2)", "light khaki", "dark khaki", "olive drab")

/obj/structure/vehicleparts/axis/attack_hand(mob/living/human/H)
	if (!ishuman(H))
		return
	var/list/options = list()
	if (components.len)
		if (hand_built)
			options += list("Fit new parts", "Take it apart")
			if (length(built_turrets()))
				options += "Turret style"
	else
		var/datum/vehicle_survey/S = new(src)
		if (!S.refusal)
			options += "Assemble it"
	var/choice = WWinput(H, build_sheet(), "Vehicle assembly", "Cancel", options + list("Cancel"))
	if (!(choice in options) || QDELETED(src) || get_dist(H, src) > 1)
		return
	switch (choice)
		if ("Fit new parts")
			var/fitted = fit_parts()
			to_chat(H, SPAN_NOTICE(fitted ? "You fit [fitted] part\s to \the [src]." : "There is nothing new on its frames to fit."))
		if ("Turret style")
			var/list/styles = built_turret_styles()
			var/style = WWinput(H, "Which turret should it carry?", "Vehicle assembly", "plain", styles + list("Cancel"))
			if (!(style in styles) || QDELETED(src) || get_dist(H, src) > 1)
				return
			for (var/obj/structure/turret/built/B in built_turrets())
				B.turret_icon = styles[style]
				B.update_icon()
		if ("Take it apart")
			var/why = take_apart_refusal(H)
			if (why)
				to_chat(H, SPAN_WARNING("You cannot take it apart: [why]."))
				return
			if (WWinput(H, "Take [name] apart? Its frames and parts stay where they stand, loose.", "Vehicle assembly", "No", list("No", "Yes")) != "Yes")
				return
			if (QDELETED(src) || get_dist(H, src) > 1 || take_apart_refusal(H))
				return
			log_game("[key_name(H)] took the vehicle [name] apart at [x],[y],[z].")
			visible_message(SPAN_NOTICE("[H] takes \the [src] apart."))
			take_apart()
			name = initial(name)
		if ("Assemble it")
			var/list/ways = list("North" = NORTH, "East" = EAST, "South" = SOUTH, "West" = WEST)
			var/way = WWinput(H, "Which way does its front point?", "Vehicle assembly", "North", list("North", "East", "South", "West", "Cancel"))
			if (!(way in ways))
				return
			var/new_name = player_input(H, "What do you want to name this [ship ? "boat" : "vehicle"]?", null, null, "text", null, FALSE)
			var/paint = null
			if (!ship)
				var/list/colors = assembly_colors(H)
				paint = WWinput(H, "Choose this vehicle's color:", "Vehicle assembly", colors[1], colors)
			if (QDELETED(src) || get_dist(H, src) > 1 || components.len)
				return
			new_name = sanitize(copytext("[new_name]", 1, 40))
			name = length(new_name) ? new_name : "[H]'s [ship ? "boat" : "vehicle"]"
			if (paint in vehicle_assembly_colors)
				color = vehicle_assembly_colors[paint]
			var/why = assemble(ways[way])
			if (why)
				name = initial(name)
				to_chat(H, SPAN_WARNING("It cannot be assembled: [why]."))
				return
			log_game("[key_name(H)] assembled the vehicle [name] at [x],[y],[z].")
			playsound(loc, 'sound/effects/lever.ogg', 100, TRUE)
			visible_message(SPAN_NOTICE("[H] assembles \the [src]."))
			to_chat(H, SPAN_NOTICE(build_sheet()))

#undef VEHICLE_ASSEMBLY_MIN
