// One optional workshop per tutorial session. It shares the practice plane
// and teardown, but never appears in the live-world fallback room. The hall
// itself is laid out by build_tutorial_room (practice_rooms.dm), which records
// its interior as props["shop"] and its building bay as props["bay"].
//
// The hall, from its south-west interior corner (sx, sy):
//
//   sx..sx+4      drawing office: desk (sx+2, sy+8), supplies on the six
//                 tiles sx+1..sx+3 by sy+2..sy+3, press or yard at (sx+4, sy)
//   sx+5..sx+16   building bay. A press or yard builds on the square to its
//                 north-east, which is the bay from row sy+1 up: 12 x 12, the
//                 largest airship a sheet holds.
//   ship          slipway (sx+10, sy) facing north, berth above it, and a pool
//                 across the bay's north half (rows sy+7..sy+12)
//   train         rail works (sx+5, sy+9) facing north onto a 12-tile track
//                 along row sy+11

// TRUE when A stands inside this session's own rectangle (x1, y1, x2, y2).
/datum/practice_session/proc/owns_rect(atom/A, list/rect)
	if (!tutorial_region_here() || ending || !body || body.practice != src || owner.sessions["[slot]"] != src || !practice_room_z)
		return FALSE
	if (QDELETED(A) || !rect)
		return FALSE
	var/turf/T = get_turf(A)
	return T && T.z == practice_room_z && T.x >= rect[1] && T.x <= rect[3] && T.y >= rect[2] && T.y <= rect[4]

/datum/practice_session/proc/owns_workshop(atom/A)
	return owns_rect(A, props["shop"])

// Anywhere in the trainee's own room, for fixtures outside the workshop.
/datum/practice_session/proc/owns_room(atom/A)
	var/list/O = owner.slot_origin(slot)
	return owns_rect(A, list(O[1], O[2], O[1] + owner.pitch_x() - 3, O[2] + owner.pitch_y() - 3))

/proc/tutorial_workshop_access(mob/living/human/H, atom/station)
	var/mob/living/human/practice/P = H
	return istype(P) && P.practice && P.practice.owns_workshop(P) && P.practice.owns_workshop(station)

// Marker-based plans use this after the construction wait and before pulling
// any old pegs. The eligible footprint is the rectangle in the one active bay,
// so checking opposite corners is enough even for an oversized imported plan.
/proc/tutorial_workshop_footprint(mob/H, low_x, low_y, high_x, high_y, z)
	if (!practice_room_z || z != practice_room_z)
		return TRUE
	var/mob/living/human/practice/P = H
	return istype(P) && P.practice && P.practice.owns_workshop(P) && P.practice.owns_workshop(locate(low_x, low_y, z)) && P.practice.owns_workshop(locate(high_x, high_y, z))

// Station modules lay new turfs; exclude the drawing office and walkways.
/proc/tutorial_station_module_site(mob/H, turf/centre, radius)
	if (!practice_room_z || centre.z != practice_room_z)
		return TRUE
	var/mob/living/human/practice/P = H
	if (!istype(P))
		return FALSE
	var/datum/practice_session/S = P.practice
	if (!S || S.props["workshop_kind"] != "station" || !S.owns_workshop(P))
		return FALSE
	var/list/bay = S.props["bay"]
	return S.owns_rect(locate(centre.x - radius, centre.y - radius, centre.z), bay) && S.owns_rect(locate(centre.x + radius, centre.y + radius, centre.z), bay)

// A cord interaction may never target the adjoining private room.
/proc/tutorial_workshop_pair(mob/living/human/H, atom/source, atom/target)
	var/turf/A = get_turf(source)
	var/turf/B = get_turf(target)
	if (!practice_room_z || (A?.z != practice_room_z && B?.z != practice_room_z))
		return TRUE
	return tutorial_workshop_access(H, source) && tutorial_workshop_access(H, target)

/proc/draught_age_available(mob/living/human/H, age)
	return (map && map.ordinal_age >= age) || tutorial_workshop_access(H, H)

/obj/structure/practice_workshop_desk
	name = "practice workshop desk"
	desc = "Choose a workshop exercise here. Each one comes with clean drawing sheets, a pencil, and the fixtures and materials for that lesson."
	icon = 'icons/obj/structures.dmi'
	icon_state = "workbench"
	anchored = TRUE
	density = TRUE
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	should_save = FALSE

/obj/structure/practice_workshop_desk/attack_hand(mob/living/human/practice/H)
	if (!tutorial_workshop_access(H, src) || !Adjacent(H))
		return
	H.practice.choose_workshop(src)

/datum/practice_session/proc/choose_workshop(obj/structure/practice_workshop_desk/desk)
	if (!tutorial_workshop_access(body, desk) || !desk.Adjacent(body))
		return
	if (props["workshop_selected"])
		to_chat(body, SPAN_NOTICE("[props["workshop_selected"]] is set up. To clear it and get a fresh kit, leave and open another practice room."))
		return
	var/list/exercises = list(
		"Build a car or tank" = "car",
		"Build a plane" = "plane",
		"Build an airship" = "air",
		"Build a train" = "train",
		"Make rocket sections" = "rocket",
		"Build a small ship" = "ship",
		"Assemble a submarine" = "sub",
		"Build a short railway" = "rail",
		"Build a ground floor" = "house",
		"Build a short pier" = "harbor",
		"Build an aqueduct" = "water",
		"Rig a bell" = "mech",
		"Unfold a station workshop" = "station",
	)
	var/client/connection = body.client
	var/choice = WWinput(body, "Choose an exercise. This workshop is yours alone. Every exercise provides a kit for a small physical build using the live game's designer.", desk.name, "Cancel", exercises + list("Cancel"))
	if (!exercises[choice] || !connection || body?.client != connection || connection.mob != body || !tutorial_workshop_access(body, desk) || !desk.Adjacent(body) || props["workshop_selected"])
		return
	var/instructions = setup_workshop(exercises[choice])
	if (instructions)
		props["workshop_selected"] = choice
		to_chat(body, SPAN_NOTICE(instructions))

// Fits the hall out for one exercise and returns the instructions.
/datum/practice_session/proc/setup_workshop(exercise)
	if (!owns_workshop(body) || !exercise || props["workshop_kind"])
		return null
	props["workshop_kind"] = exercise
	var/list/shop = props["shop"]
	var/sx = shop[1]
	var/sy = shop[2]
	var/z = practice_room_z
	// Each kind of supply lies on its own tile of the office floor.
	var/list/supply = block(locate(sx + 1, sy + 2, z), locate(sx + 3, sy + 3, z))
	new /obj/item/ship_draught(supply[1])
	new /obj/item/ship_draught(supply[1])
	new /obj/item/weapon/pen/pencil(supply[2])
	var/turf/worksite = locate(sx + 4, sy, z)
	. = "Pick up a blank draught and the pencil from the floor south of the desk. Use the draught in hand and select the corresponding Draw option. Use the designer's Checks and parts list to improve your design."
	switch (exercise)
		if ("car")
			setup_practice_press(new /obj/structure/car_workshop/practice(worksite))
			. += " Use the saved vehicle or tank sheet on the stocked automobile workshop in the south of the hall. It builds on the concrete bay to its northeast."
		if ("plane")
			setup_practice_press(new /obj/structure/car_workshop/hangar/practice(worksite))
			. += " Use the saved plane sheet on the stocked aircraft hangar in the south of the hall. It builds on the concrete bay to its northeast."
		if ("air")
			setup_practice_press(new /obj/structure/car_workshop/airship_yard/practice(worksite))
			. += " Use the saved airship sheet on the stocked airship yard in the south of the hall. It lays her deck on the concrete bay to its northeast, which holds the largest airship a sheet can. The yard commissions the ship with its gas and fuel tanks empty."
		if ("ship")
			var/obj/structure/slipway/practice/W = new(locate(sx + 10, sy, z))
			W.session = src
			W.set_dir(NORTH)
			for (var/turf/T in block(locate(sx + 6, sy + 7, z), locate(sx + 15, sy + 12, z)))
				new /turf/floor/beach/water/deep(T)
			var/list/stacks = list(/obj/item/stack/material/wood, /obj/item/stack/material/woodplank, /obj/item/stack/material/iron, /obj/item/stack/material/steel)
			for (var/i in 1 to stacks.len)
				practice_workshop_stack(supply[2 + i], stacks[i], 4)
			. += " Draw a single deck ship up to five tiles long and five wide, with no upper decks or hold. Pin its draught to the slipway at the south wall of the bay, fit pieces using the stacks by the desk, and launch it north into the pool."
		if ("train")
			var/obj/structure/rail_works/practice/W = new(locate(sx + 5, sy + 9, z))
			W.set_dir(NORTH)
			for (var/turf/T in block(locate(sx + 5, sy + 11, z), locate(sx + 16, sy + 11, z)))
				track_make_rail(T, EAST, FALSE)
			for (var/material in W.stock)
				W.stock[material] = W.stock_cap(material)
			. += " Use the saved train sheet on the stocked rail works beside the track in the north of the bay. Choose a west-facing build for up to twelve tiles of consist; the track is shorter than a main-world rail yard."
		if ("house")
			practice_workshop_stack(supply[3], /obj/item/stack/material/wood, 3)
			practice_workshop_stack(supply[4], /obj/item/stack/material/woodplank, 2)
			practice_workshop_stack(supply[5], /obj/item/stack/material/stone, 2)
			new /obj/item/weapon/hammer(supply[6])
			. += " Draw a small house's ground-floor walls, door, and floor, leaving roofs and upper floors off the sheet. Peg it out on the concrete bay. Open Construction on the supplied wood or stone and build on the matching pegs."
		if ("rail")
			new /obj/item/stack/rail_sleepers(supply[3], 10)
			new /obj/item/stack/rail_lengths(supply[4], 10)
			new /obj/item/weapon/hammer(supply[5])
			. += " Draw up to ten tiles of track and peg them out on the concrete bay. Lay sleepers on each marker, add rails, then use the hammer to spike them down."
		if ("rocket")
			var/obj/structure/rocket_works/practice/W = new(worksite)
			for (var/material in W.stock)
				W.stock[material] = 1000
			. += " Use the saved rocket sheet on the stocked rocket works in the south of the hall, then click the works to make each section. Move each finished section out of the way. This exercise does not stack or launch a rocket."
		if ("sub")
			for (var/col = sx + 6 to sx + 13)
				for (var/row = sy + 2 to sy + 9)
					var/turf/T = locate(col, row, z)
					new /turf/floor/beach/water(T)
			for (var/col = sx + 8 to sx + 10)
				for (var/row = sy + 3 to sy + 7)
					new /obj/structure/vehicleparts/frame/ship/steel/submarine/section(locate(col, row, z))
			var/obj/structure/vehicleparts/axis/ship/submarine/controls/practice/W = new(locate(sx + 9, sy + 7, z))
			W.session = src
			new /obj/structure/vehicleparts/shipwheel(locate(sx + 9, sy + 6, z))
			new /obj/structure/vehicleparts/sub_station/loose(locate(sx + 9, sy + 5, z))
			new /obj/structure/engine/internal/diesel/premade/chiha(locate(sx + 9, sy + 3, z))
			new /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank(locate(sx + 9, sy + 3, z))
			. += " Draw a five-row submarine, with a helm in the centre of row two, a ballast station in the centre of row three, and a side hatch. The supplied 3 by 5 hull carries those fittings, a diesel engine and an empty fuel tank. Apply the saved sheet to its controls, then select Assemble it and North. The practice boat cannot drive or dive."
		if ("harbor")
			var/turf/start = locate(sx + 8, sy + 6, z)
			new /obj/effect/practice_marker(start)
			for (var/col = sx + 9 to sx + 10)
				var/turf/T = locate(col, sy + 6, z)
				new /turf/floor/beach/water/shallowsaltwater(T)
			new /obj/structure/workshop_machine/pile_driver(locate(sx + 8, sy + 7, z))
			for (var/i in 1 to 2)
				new /obj/item/weapon/bridge_span(supply[3])
				new /obj/item/weapon/bridge_span/timber(supply[4])
			. += " Draw a two-span pier. Stand on the marker and face east to survey it. Install spans one at a time from the shore outward. The pile driver stands beside the start if you choose timber. This bay teaches a pier, not a dry dock or boathouse."
		if ("water")
			new /obj/effect/practice_marker(locate(sx + 9, sy + 6, z))
			var/turf/T = locate(sx + 8, sy + 6, z)
			new /turf/floor/beach/water(T)
			practice_workshop_stack(supply[3], /obj/item/stack/material/stone, 1)
			new /obj/item/weapon/reagent_containers/glass/small_pot(supply[4])
			. += " In an aqueduct plan place an intake, channel and fountain on three consecutive tiles running east from the marker. Preview and peg the route while standing on the marker. Build all three pieces from the supplied stone over their pegs. Wait a minute for the channel to feed the fountain, then fill the pot."
		if ("mech")
			practice_workshop_stack(supply[3], /obj/item/stack/material/wood, 1)
			practice_workshop_stack(supply[4], /obj/item/stack/material/rope, 1)
			new /obj/structure/bell(locate(sx + 9, sy + 7, z))
			. += " Draw a lever and bell with a cord between them. Build the lever from the supplied wood within seven tiles of the actual bell, use rope on the lever to tie it to the bell, then throw the lever to ring it."
		if ("station")
			new /obj/effect/practice_marker(locate(sx + 7, sy + 6, z))
			new /obj/item/habitat_kit/workshop(supply[3])
			new /obj/item/habitat_kit/airlock(supply[4])
			new /obj/item/habitat_kit/airlock(supply[4])
			. += " Draw a command module with a keel airlock at one end and a docking airlock at the other. Unfold the workshop three tiles east of the marker, then unfold one airlock four tiles north and one four tiles south. This practice build does not allocate orbit, launch, or install a live docking port."


/proc/practice_workshop_stack(turf/T, path, count)
	for (var/n in 1 to count)
		var/obj/item/stack/S = new path(T)
		S.amount = min(S.max_amount, 50)
		S.update_icon()

/datum/practice_session/proc/setup_practice_press(obj/structure/car_workshop/W)
	for (var/material in W.stock)
		W.stock[material] = material == "wheels" ? 8 : W.stock_cap(material)
	if (istype(W, /obj/structure/car_workshop/airship_yard))
		W.stock["plastic"] = W.stock_cap("plastic")
		W.stock["casings"] = W.stock_cap("casings")

// Training power applies to these fixed practice machines only. Existing
// production presses never see this path. They still check bay geometry and
// charge their ordinary bill of materials.
/obj/structure/car_workshop/practice
	should_save = FALSE

/obj/structure/car_workshop/practice/allowed(mob/living/human/H)
	return tutorial_workshop_access(H, src)

/obj/structure/car_workshop/practice/draw_cable_power()
	return TRUE

/obj/structure/car_workshop/hangar/practice
	should_save = FALSE

/obj/structure/car_workshop/hangar/practice/allowed(mob/living/human/H)
	return tutorial_workshop_access(H, src)

/obj/structure/car_workshop/hangar/practice/draw_cable_power()
	return TRUE

/obj/structure/car_workshop/airship_yard/practice
	should_save = FALSE

/obj/structure/car_workshop/airship_yard/practice/allowed(mob/living/human/H)
	return tutorial_workshop_access(H, src)

/obj/structure/car_workshop/airship_yard/practice/draw_cable_power()
	return TRUE

/obj/structure/rail_works/practice
	should_save = FALSE

/obj/structure/rocket_works/practice
	should_save = FALSE

/obj/structure/rocket_works/practice/allowed(mob/living/human/H)
	return tutorial_workshop_access(H, src)

// The real-character tutorial's text is also discoverable here. Never attach
// its progress tracker to a trainee; leaving the room must not finish it.
/obj/structure/practice_lesson_board
	name = "practice lesson board"
	desc = "Read any lesson from the character tutorial. Use the tree, grass and flint in camp to try primitive toolmaking."
	icon = 'icons/obj/structures.dmi'
	icon_state = "nboard05"
	anchored = TRUE
	density = FALSE
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	should_save = FALSE

/obj/structure/practice_lesson_board/proc/readable_by(mob/living/human/practice/H)
	return istype(H) && H.practice && H.practice.owns_room(H) && H.practice.owns_room(src) && Adjacent(H)

/obj/structure/practice_lesson_board/attack_hand(mob/living/human/practice/H)
	if (!readable_by(H))
		return
	var/list/lessons = list(
		"Move" = "move", "Read the HUD" = "hud", "Pick up an item" = "pick_up",
		"Swap hands" = "swap", "Stow an item" = "stow", "Choose an intent" = "intent",
		"Use the Crafting Atlas" = "atlas", "Eat and drink" = "eat",
		"Get a branch" = "branch", "Knap flint and make twine" = "twine",
		"Whittle a stick and make an axe" = "whittle", "Light a fire" = "fire",
		"Drink safely" = "water", "Use chat" = "chat", "Learn about book research" = "research",
		"Find help" = "help",
	)
	var/client/connection = H.client
	var/choice = WWinput(H, "Choose a topic to read. Camp has a tree, grass and flint for hands-on practice. Book research is explained here; book progression is not enabled in the tutorial region.", name, "Cancel", lessons + list("Cancel"))
	if (lessons[choice] && connection && H.client == connection && connection.mob == H && readable_by(H))
		to_chat(H, SPAN_NOTICE(tutorial_step_text(lessons[choice], connection)))

/obj/structure/slipway/practice
	should_save = FALSE
	var/tmp/datum/practice_session/session

/obj/structure/slipway/practice/attack_hand(mob/living/human/H)
	if (tutorial_workshop_access(H, src))
		return ..()

/obj/structure/slipway/practice/attackby(obj/item/I, mob/living/human/H)
	if (tutorial_workshop_access(H, src))
		return ..()

/obj/structure/slipway/practice/add_piece(mob/living/human/H, obj/item/I, atom/target)
	if (tutorial_workshop_access(H, src) && session?.owns_workshop(target))
		return ..()
	return FALSE

/obj/structure/slipway/practice/keel_refusal(datum/slipway_design/D, mob/living/human/H)
	return "Use your own small ship draught for this practice slipway."

/obj/structure/slipway/practice/draught_refusal(datum/ship_draught/D)
	if (dir != NORTH || !session?.owns_workshop(src) || !D || length(D.decks["-1"]) || length(D.decks["1"]) || length(D.decks["2"]))
		return "This practice slipway only builds a single deck, facing north."
	var/list/B = D.extent()
	if (!B || B[3] - B[1] >= 5 || B[4] - B[2] >= 5)
		return "Draw a practice hull no more than five tiles long and five tiles wide."
	var/list/berth = draught_berth(D)
	for (var/turf/T in berth)
		if (!session.owns_workshop(T))
			return "Keep the hull inside your practice berth."
	return ..()

/obj/structure/slipway/practice/draught_landing(list/berth, length)
	var/slide = ..()
	if (slide < 0 || !session?.owns_workshop(src) || dir != NORTH)
		return -1
	for (var/turf/T in berth)
		var/turf/landing = locate(T.x, T.y + slide, T.z)
		if (!session.owns_workshop(T) || !session.owns_workshop(landing))
			return -1
	return slide

// Construction permissions are for these three outputs and their selected
// practice exercise, not knowledge, XP, any other recipe or a real character.
/proc/tutorial_waterworks_recipe(mob/living/human/H, result_path_string)
	var/mob/living/human/practice/P = H
	return istype(P) && P.practice && P.practice.props["workshop_kind"] == "water" && P.practice.owns_workshop(P) && (result_path_string in list(
		"/obj/structure/aqueduct_intake",
		"/obj/structure/aqueduct/channel",
		"/obj/structure/sink/aqueduct_fountain",
	))

/obj/structure/vehicleparts/axis/ship/submarine/controls/practice
	should_save = FALSE
	var/tmp/datum/practice_session/session

/obj/structure/vehicleparts/axis/ship/submarine/controls/practice/attack_hand(mob/living/human/H)
	if (tutorial_workshop_access(H, src))
		return ..()

/obj/structure/vehicleparts/axis/ship/submarine/controls/practice/attackby(obj/item/I, mob/H)
	if (tutorial_workshop_access(H, src))
		return ..()

/obj/structure/vehicleparts/axis/ship/submarine/controls/practice/assembly_refusal(datum/vehicle_survey/S)
	var/datum/sub_draught/D = sheet()
	var/is_five = D && D.length == 5
	qdel(D)
	if (!is_five || !session?.owns_workshop(src) || S.width != 3 || S.height != 5)
		return "use a five-row submarine sheet on the supplied hull"
	// The controls also lay out a five-wide turning square.
	if (!session.owns_workshop(locate(S.min_x - 2, S.min_y, z)) || !session.owns_workshop(locate(S.max_x + 2, S.max_y, z)))
		return "keep the whole hull and its turning space inside your bay"
	return ..()

/obj/structure/vehicleparts/axis/ship/submarine/controls/practice/depth_refusal(diving)
	return "The practice basin is for assembling a submarine, not diving."

/obj/structure/vehicleparts/axis/ship/submarine/controls/practice/do_vehicle_check()
	moving = FALSE
	stopmovementloop()
	return FALSE
