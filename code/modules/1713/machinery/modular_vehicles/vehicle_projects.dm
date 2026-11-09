// Vehicle projects (docs/piece-projects.md): the automobile workshop and the
// aircraft hangar can build a car or a plane piece by piece in their bay, the
// way the slipway builds a ship. A player starts a project for one model;
// then anyone brings the materials for each piece in turn (chassis, wheels,
// engine, bodywork, windows, seats) to the press or to any part of the
// vehicle in the bay, and the vehicle grows in the bay from the back to the
// front. When the last piece is fitted the press rolls it out, drawing power
// like an ordinary assembly, and the finished vehicle is exactly the one the
// press builds in one go.
//
// The project lives in the press's saved vars (project, project_done,
// project_paid); the parts shown in the bay are rebuilt from them and are
// never saved.

#define VEHICLE_PIECE_TIME 30 // ticks to fit one piece by hand

/obj/structure/car_workshop
	var/piece_projects = TRUE     // offers piece-by-piece projects
	var/project = null            // model being built piece by piece
	var/project_done = 0
	var/list/project_paid = list()
	var/tmp/list/project_frames = list()

/obj/structure/car_workshop/shipyard
	piece_projects = FALSE
/obj/structure/car_workshop/submarine_pen
	piece_projects = FALSE
/obj/structure/car_workshop/rover_bay
	piece_projects = FALSE
/obj/structure/car_workshop/extraction_private
	piece_projects = FALSE

var/global/list/vehicle_project_plans = list()  // "type|model" -> plan
var/global/list/vehicle_project_layouts = list() // "type|model" -> layout

// What each stage of a project is called on this press: part -> list(stage
// name, piece name).
/obj/structure/car_workshop/proc/project_words()
	return list(
		"frames" = list("Chassis", "chassis section"),
		"wheels" = list("Wheels", "wheel"),
		"engine" = list("Engine", "engine and wiring"),
		"body" = list("Bodywork", "set of body panels"),
		"windows" = list("Windows", "set of windows"),
		"seats" = list("Seats", "set of seats"),
	)

// The piece plan for model, made from the press's ordinary costs, so a
// project costs exactly what a one-go assembly does.
/obj/structure/car_workshop/proc/project_plan(model)
	if (!piece_projects || !(model in models()))
		return null
	var/key = "[type]|[model]"
	if (vehicle_project_plans[key])
		return vehicle_project_plans[key]
	var/list/cost = costs(model)
	if (!cost)
		return null
	var/list/words = project_words()
	var/steel = cost["steel"] || 0
	var/per = round(steel / 5)
	var/datum/piece_plan/P = new
	P.name = model
	var/list/stages = list()
	if (per > 0)
		stages += list(list("name" = words["frames"][1], "pieces" = 2, "cost" = list("steel" = per), "part" = "frames", "verb" = words["frames"][2]))
	if (cost["wheels"])
		stages += list(list("name" = words["wheels"][1], "pieces" = cost["wheels"], "cost" = list("wheels" = 1), "part" = "wheels", "verb" = words["wheels"][2]))
	var/list/engine = list("steel" = steel - 4 * per)
	if (cost["cable"])
		engine["cable"] = cost["cable"]
	stages += list(list("name" = words["engine"][1], "pieces" = 1, "cost" = engine, "part" = "engine", "verb" = words["engine"][2]))
	if (per > 0)
		stages += list(list("name" = words["body"][1], "pieces" = 2, "cost" = list("steel" = per), "part" = "body", "verb" = words["body"][2]))
	if (cost["glass"])
		stages += list(list("name" = words["windows"][1], "pieces" = 1, "cost" = list("glass" = cost["glass"]), "part" = "windows", "verb" = words["windows"][2]))
	if (cost["cloth"])
		stages += list(list("name" = words["seats"][1], "pieces" = 1, "cost" = list("cloth" = cost["cloth"]), "part" = "seats", "verb" = words["seats"][2]))
	P.stages = stages
	vehicle_project_plans[key] = P
	return P

// Where the parts of model stand in the bay: "dx,dy" from the press -> part
// paths, the same cells complete_assembly() fills.
/obj/structure/car_workshop/proc/project_layout(model)
	var/key = "[type]|[model]"
	if (vehicle_project_layouts[key])
		return vehicle_project_layouts[key]
	var/list/choices = models()
	var/path = choices[model]
	if (!ispath(path, /obj/effects/premadevehicles))
		return null
	var/size = model_size(model)
	var/obj/effects/premadevehicles/B = new path(null, TRUE)
	. = list()
	for (var/coords in B.tocreate)
		var/list/C = splittext(coords, ",")
		.["[size - 2 + text2num(C[1])],[text2num(C[2])]"] = B.tocreate[coords]
	qdel(B)
	vehicle_project_layouts[key] = .

/obj/structure/car_workshop/hangar/project_words()
	return list(
		"frames" = list("Airframe", "airframe section"),
		"wheels" = list("Landing gear", "landing wheel"),
		"engine" = list("Engine", "engine and propeller"),
		"body" = list("Skin", "run of skin panels"),
		"windows" = list("Canopy", "canopy"),
		"seats" = list("Seats", "pair of seats"),
	)

/obj/structure/car_workshop/hangar/project_layout(model)
	var/list/layout = aircraft_model_layout(model)
	if (!layout)
		return null
	. = list()
	// build_aircraft(): origin x + 1, body against the east edge of the 4x4.
	for (var/coords in layout)
		var/list/C = splittext(coords, ",")
		.["[1 + 4 - 3 + text2num(C[1]) - 1],[text2num(C[2])]"] = layout[coords]

/obj/structure/car_workshop/proc/get_project_plan()
	return project ? project_plan(project) : null

/obj/structure/car_workshop/proc/project_finished()
	var/datum/piece_plan/P = get_project_plan()
	return P && !P.next_piece(project_done)

/obj/structure/car_workshop/proc/project_needed()
	var/datum/piece_plan/P = get_project_plan()
	return P ? P.still_needed(project_done, project_paid) : list()

/obj/structure/car_workshop/proc/project_status()
	var/datum/piece_plan/P = get_project_plan()
	if (!P)
		return "No project is under way in the bay."
	if (project_finished())
		return "The [P.name] is finished ([P.total_pieces()] pieces). Roll it out from the [name] (assembly draws 20 power)."
	return P.progress_text(project_done, project_paid)

// Why a project for model could not start here, or null.
/obj/structure/car_workshop/proc/project_refusal(model, mob/living/human/H)
	if (!piece_projects || !project_plan(model) || !project_layout(model))
		return "The [name] cannot build a [model] piece by piece."
	if (project)
		return "A [project] is already being built in the bay."
	if (H && !allowed(H))
		return requirement_text(H)
	if (!clear_footprint(model))
		return "Clear the northeast [model_size(model)]x[model_size(model)] bay of people and objects, on dry open floor, before starting."
	return null

/obj/structure/car_workshop/proc/start_project(model)
	project = model
	project_done = 0
	project_paid = list()
	update_project_frames()

/obj/structure/car_workshop/proc/abandon_project()
	project = null
	project_done = 0
	project_paid = list()
	clear_project_frames()

// One piece is fitted once it is fully paid.
/obj/structure/car_workshop/proc/project_piece_paid()
	var/list/left = project_needed()
	if (left.len)
		return FALSE
	project_done++
	project_paid = list()
	update_project_frames()
	return TRUE

// Pays from a stack. Returns the amount taken.
/obj/structure/car_workshop/proc/project_pay(obj/item/stack/S)
	var/datum/piece_plan/P = get_project_plan()
	if (!P)
		return 0
	var/list/result = piece_pay(P, project_done, project_paid, S)
	if (result[2])
		project_piece_paid()
	return result[1]

// Pays one free wheel. TRUE when it was taken.
/obj/structure/car_workshop/proc/project_pay_wheel(obj/structure/vehicleparts/movement/W)
	var/list/needed = project_needed()
	if (!needed["wheels"] || W.type != /obj/structure/vehicleparts/movement || W.axis || W.connected || W.broken || W.anchored)
		return FALSE
	project_paid["wheels"] = (project_paid["wheels"] || 0) + 1
	qdel(W)
	project_piece_paid()
	return TRUE

/obj/structure/car_workshop/proc/wait_for_piece(mob/living/human/H, atom/target)
	return do_after(H, VEHICLE_PIECE_TIME, target || src)

// A player brings a stack or a wheel to the press or to the vehicle in the bay.
/obj/structure/car_workshop/proc/project_add(mob/living/human/H, atom/movable/I, atom/target)
	if (busy || !istype(H) || QDELETED(I))
		return FALSE
	var/datum/piece_plan/P = get_project_plan()
	if (!P)
		return FALSE
	if (!allowed(H))
		to_chat(H, SPAN_WARNING(requirement_text(H)))
		return TRUE
	var/list/next = P.next_piece(project_done)
	if (!next)
		to_chat(H, SPAN_NOTICE("The [P.name] is finished. Roll it out from the [name]."))
		return TRUE
	var/list/needed = project_needed()
	var/key = istype(I, /obj/structure/vehicleparts/movement) ? "wheels" : (istype(I, /obj/item/stack) ? piece_material(I) : null)
	if (!key || !needed[key])
		to_chat(H, SPAN_WARNING("The next piece needs [piece_cost_text(needed)], not [I.name]."))
		return TRUE
	var/list/stage = P.stages[next[1]]
	busy = TRUE
	to_chat(H, SPAN_NOTICE("You start work on the [stage["verb"]]..."))
	var/index = P.index_of(next)
	if (!wait_for_piece(H, target) || QDELETED(src) || QDELETED(I) || project != P.name || project_done != index)
		busy = FALSE
		return TRUE
	var/before = project_done
	var/took = key == "wheels" ? project_pay_wheel(I) : project_pay(I)
	busy = FALSE
	if (!took)
		return TRUE
	if (project_done > before)
		log_game("[key_name(H)] fitted [stage["verb"]] [next[2]]/[stage["pieces"]] of a [P.name] at [x],[y],[z].")
		H.visible_message(SPAN_NOTICE("[H] fits the [stage["verb"]] on the [P.name]."), SPAN_NOTICE("You fit the [stage["verb"]]. [project_status()]"))
	else
		to_chat(H, SPAN_NOTICE("You set out [took] [key] for the [stage["verb"]]; it still needs [piece_cost_text(project_needed())]."))
	return TRUE

// The finished project goes through the press's ordinary assembly: its
// materials are credited to the stock and spent by complete_assembly(), so
// cars get their keys and planes their empty tank exactly as in one go.
/obj/structure/car_workshop/proc/roll_out_project(mob/living/human/H)
	if (busy || !project_finished())
		return null
	var/datum/piece_plan/P = get_project_plan()
	var/model = project
	clear_project_frames()
	if (!clear_footprint(model))
		update_project_frames()
		to_chat(H, SPAN_WARNING("Move everyone and everything loose out of the bay first."))
		return null
	busy = TRUE
	powerneeded = 20
	if (!draw_cable_power())
		finish_work()
		update_project_frames()
		to_chat(H, SPAN_WARNING("Connect an active cable supply with 20 available power."))
		return null
	var/completed = wait_for_assembly(H)
	if (QDELETED(src))
		return null
	var/obj/structure/vehicleparts/axis/result
	if (completed && project == model && Adjacent(H) && allowed(H) && draw_cable_power())
		var/list/cost = P.total_cost()
		for (var/key in cost)
			stock[key] = (stock[key] || 0) + cost[key]
		result = complete_assembly(model)
		if (result)
			project = null
			project_done = 0
			project_paid = list()
			log_game("[key_name(H)] rolled out a [model] built piece by piece at [x],[y],[z].")
			to_chat(H, SPAN_NOTICE(assembled_message(model)))
		else
			for (var/key in cost)
				stock[key] -= cost[key]
	finish_work()
	if (!result)
		update_project_frames()
	return result

// Menu entries for projects: label -> action.
/obj/structure/car_workshop/proc/project_options()
	. = list()
	if (!piece_projects)
		return
	if (!project)
		for (var/model in models())
			if (project_plan(model) && project_layout(model))
				.["Start a [model] piece by piece"] = model
		return
	if (project_finished())
		.["Roll out the [project]"] = "roll out"
	.["Abandon the [project]"] = "abandon"

/obj/structure/car_workshop/proc/project_action(mob/living/human/H, action)
	if (action == "roll out")
		roll_out_project(H)
		return
	if (action == "abandon")
		var/datum/piece_plan/P = get_project_plan()
		if (!P || WWinput(H, "Break up the [P.name]? Everything fitted so far is lost.", name, "No", list("Yes", "No")) != "Yes" || busy || !Adjacent(H))
			return
		log_game("[key_name(H)] abandoned a [P.name] project ([project_done] pieces) at [x],[y],[z].")
		abandon_project()
		to_chat(H, SPAN_NOTICE("The bay is cleared."))
		return
	var/refusal = project_refusal(action, H)
	if (refusal)
		to_chat(H, SPAN_WARNING(refusal))
		return
	start_project(action)
	var/datum/piece_plan/P = get_project_plan()
	log_game("[key_name(H)] started a [action] project at [x],[y],[z].")
	to_chat(H, SPAN_NOTICE("The jig is set up for a [action]: [P.total_pieces()] pieces, [piece_cost_text(P.total_cost())] in all. [project_status()] Bring the materials to the press or to the vehicle in the bay; drag wheels onto either."))

// ---- The vehicle in the bay ----

// One cell of the vehicle being built. It shows the bare cell, the chassis
// or the finished body with the parts fitted so far, and takes materials
// and wheels like the press.
/obj/structure/vehicle_project_part
	name = "vehicle under construction"
	desc = "Part of a vehicle being built piece by piece. Bring the materials for the next piece here or to the press."
	icon = 'icons/obj/vehicles/vehicleparts_boats.dmi'
	icon_state = "grid"
	anchored = TRUE
	density = FALSE
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	layer = TURF_LAYER + 0.1
	should_save = FALSE
	var/tmp/obj/structure/car_workshop/workshop

/obj/structure/vehicle_project_part/Destroy()
	if (workshop)
		workshop.project_frames -= src
		workshop = null
	return ..()

/obj/structure/vehicle_project_part/examine(mob/user, distance)
	..()
	if (workshop)
		to_chat(user, workshop.project_status())

/obj/structure/vehicle_project_part/attackby(obj/item/W as obj, mob/user as mob)
	if (workshop && istype(W, /obj/item/stack))
		workshop.project_add(user, W, src)
		return
	return ..()

/obj/structure/vehicle_project_part/MouseDrop_T(atom/movable/O, mob/living/human/H)
	if (workshop && istype(O, /obj/structure/vehicleparts/movement) && istype(H) && Adjacent(H) && O.Adjacent(H))
		workshop.project_add(H, O, src)
		return
	return ..()

/obj/structure/car_workshop/proc/clear_project_frames()
	for (var/obj/structure/vehicle_project_part/F in project_frames.Copy())
		F.workshop = null
		qdel(F)
	project_frames = list()

// The look of a frame part: list(icon, state), as the chassis (bare) or the
// finished body seen from outside.
/proc/vehicle_project_frame_look(path, finished)
	if (ispath(path, /obj/structure/vehicleparts/frame/car/aircraft))
		var/obj/structure/vehicleparts/frame/car/aircraft/A = path
		var/hull = initial(A.hull_state)
		return list('icons/obj/vehicles/lightplane.dmi', (finished || initial(A.noroof)) ? hull : "[hull]_floor")
	var/obj/structure/vehicleparts/frame/F = path
	return list(initial(F.icon), initial(F.icon_state))

var/global/list/vehicle_project_body_cache = list()

// The bodywork a finished frame draws over itself facing south (its walls,
// doors, windows and trim, tinted like the car), as frame update_icon() does.
/proc/vehicle_project_body(path, tint)
	var/key = "[path]|[tint]"
	if (vehicle_project_body_cache[key])
		return vehicle_project_body_cache[key]
	. = list()
	if (ispath(path, /obj/structure/vehicleparts/frame/car/aircraft))
		if (ispath(path, /obj/structure/vehicleparts/frame/car/aircraft/nose/center))
			. += image(icon = 'icons/obj/vehicles/lightplane.dmi', icon_state = "prop", dir = SOUTH)
	else
		var/obj/structure/vehicleparts/frame/F = new path(null)
		F.should_save = FALSE
		var/list/walls = list(list(F.w_left, EAST), list(F.w_right, WEST), list(F.w_front, SOUTH), list(F.w_back, NORTH))
		for (var/list/W in walls)
			var/list/spec = W[1]
			if (!islist(spec) || !spec.len || spec[1] == "" || spec[1] == "none")
				continue
			var/image/I = image(icon = F.normal_icon, icon_state = "[spec[1]]", dir = W[2])
			if (spec.len <= 8 && tint)
				I.color = tint
			. += I
		if (F.hasoverlay)
			. += image(icon = F.normal_icon, icon_state = F.hasoverlay, dir = NORTH)
		qdel(F)
	vehicle_project_body_cache[key] = .

var/global/list/vehicle_project_wheel_cache = list() // wheel and seat looks by path

// A part fitted in a cell, as the finished vehicle shows it. side is -1 on
// the right-hand (west) column, 1 on the left and 0 in the middle.
/proc/vehicle_project_image(path, part, side)
	if (part == "wheels")
		var/key = "[path]"
		var/list/look = vehicle_project_wheel_cache[key]
		if (!look)
			var/obj/structure/vehicleparts/movement/W = new path(null)
			W.should_save = FALSE
			look = list(W.icon, W.wconfig ? W.wconfig.base_icon_state : W.icon_state)
			qdel(W)
			vehicle_project_wheel_cache[key] = look
		var/image/I = image(icon = look[1], icon_state = look[2], dir = SOUTH)
		I.pixel_x = 16 * side
		return I
	if (part == "seats")
		var/key = "[path]"
		var/list/look = vehicle_project_wheel_cache[key]
		if (!look)
			// Seats take their colour from their upholstery when made.
			var/obj/structure/bed/chair/seat = new path(null)
			seat.should_save = FALSE
			seat.update_icon()
			look = list(seat.icon, seat.icon_state, seat.color)
			qdel(seat)
			vehicle_project_wheel_cache[key] = look
		var/image/I = image(icon = look[1], icon_state = look[2], dir = SOUTH)
		I.color = look[3]
		return I
	var/obj/O = path
	var/icon_file = initial(O.icon)
	var/state = initial(O.icon_state)
	if (part == "engine")
		if (ispath(path, /obj/structure/engine))
			icon_file = 'icons/obj/vehicles/vehicleparts.dmi'
			state = "carengine_static"
		else
			state = "fueltank_incar"
	var/image/I = image(icon = icon_file, icon_state = state, dir = SOUTH)
	I.pixel_x = initial(O.pixel_x)
	I.pixel_y = initial(O.pixel_y)
	return I

// Lays out the bay for the project as it stands. Each stage covers the
// vehicle from the back row to the front, a share per piece fitted.
/obj/structure/car_workshop/proc/update_project_frames()
	clear_project_frames()
	var/datum/piece_plan/P = get_project_plan()
	var/list/layout = project ? project_layout(project) : null
	if (!P || !layout || !isturf(loc))
		return
	var/list/done = P.stage_progress(project_done)
	// Rows from the back (north, highest dy) to the front.
	var/front = null
	var/back = null
	for (var/coords in layout)
		var/list/C = splittext(coords, ",")
		var/dy = text2num(C[2])
		front = isnull(front) ? dy : min(front, dy)
		back = isnull(back) ? dy : max(back, dy)
	var/nrows = back - front + 1
	var/left_col = null
	var/right_col = null
	for (var/coords in layout)
		var/list/C = splittext(coords, ",")
		var/dx = text2num(C[1])
		left_col = isnull(left_col) ? dx : min(left_col, dx)
		right_col = isnull(right_col) ? dx : max(right_col, dx)
	var/list/reach = list()
	var/list/part_stages = list()
	for (var/i in 1 to P.stages.len)
		var/list/stage = P.stages[i]
		part_stages[stage["part"]] = i
		reach[stage["part"]] = CEILING(nrows * done["[i]"] / stage["pieces"], 1)
	// Wheels go on one at a time, back wheels first.
	var/list/wheel_cells = list()
	for (var/dy = back, dy >= front, dy--)
		for (var/coords in layout)
			var/list/C = splittext(coords, ",")
			if (text2num(C[2]) != dy)
				continue
			for (var/path in layout[coords])
				if (ispath(path, /obj/structure/vehicleparts/movement))
					wheel_cells += coords
	var/wheels_on = part_stages["wheels"] ? done["[part_stages["wheels"]]"] : 0
	var/obj/effects/premadevehicles/look_color
	var/list/choices = models()
	var/model_path = choices[project]
	var/tint = null
	if (ispath(model_path, /obj/effects/premadevehicles))
		look_color = model_path
		tint = initial(look_color.custom_color)
	for (var/coords in layout)
		var/list/C = splittext(coords, ",")
		var/turf/T = locate(x + text2num(C[1]), y + text2num(C[2]), z)
		if (!T)
			continue
		// Rank 1 is the back row.
		var/rank = back - text2num(C[2]) + 1
		var/obj/structure/vehicle_project_part/F = new(T)
		F.workshop = src
		project_frames += F
		var/frame_path = null
		for (var/path in layout[coords])
			if (ispath(path, /obj/structure/vehicleparts/frame))
				frame_path = path
		var/body_done = reach["body"] && rank <= reach["body"]
		var/frame_done = reach["frames"] && rank <= reach["frames"]
		var/list/fitted = list()
		if (frame_path && (frame_done || body_done))
			var/list/look = vehicle_project_frame_look(frame_path, body_done)
			F.icon = look[1]
			F.icon_state = look[2]
			F.name = body_done ? "body of a [P.name]" : "chassis of a [P.name]"
		else
			F.icon = 'icons/obj/vehicles/vehicleparts_boats.dmi'
			F.icon_state = "grid"
			F.alpha = 110
			F.name = "assembly jig"
		// Under an aircraft's skin the engine and seats are out of sight.
		var/skinned = FALSE
		if (body_done && ispath(frame_path, /obj/structure/vehicleparts/frame/car/aircraft))
			var/obj/structure/vehicleparts/frame/car/aircraft/AF = frame_path
			skinned = !initial(AF.noroof)
		var/dx = text2num(C[1])
		// Car wheels stand out at the sides; a plane's sit under the airframe.
		var/side = ispath(frame_path, /obj/structure/vehicleparts/frame/car/aircraft) ? 0 : (dx == left_col ? -1 : (dx == right_col ? 1 : 0))
		for (var/path in layout[coords])
			var/part = vehicle_project_part_of(path)
			if (!part || (skinned && part != "wheels"))
				continue
			var/shown = FALSE
			if (part == "wheels")
				var/at = wheel_cells.Find(coords)
				shown = at && at <= wheels_on
			else
				shown = reach[part] && rank <= reach[part]
			if (shown)
				fitted += vehicle_project_image(path, part, side)
		if (body_done && frame_path)
			fitted += vehicle_project_body(frame_path, tint)
		F.overlays += fitted

// Which stage shows a part that is not a frame, or null for none.
/proc/vehicle_project_part_of(path)
	if (ispath(path, /obj/structure/vehicleparts/movement))
		return "wheels"
	if (ispath(path, /obj/structure/engine) || ispath(path, /obj/item/weapon/reagent_containers/glass/barrel/fueltank))
		return "engine"
	if (ispath(path, /obj/structure/bed/chair))
		return "seats"
	if (ispath(path, /obj/structure/vehicleparts/license_plate))
		return "windows"
	return null

#undef VEHICLE_PIECE_TIME
