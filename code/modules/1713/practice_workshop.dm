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
	var/list/exercises = list(
		"Build a car or tank" = "car",
		"Build a plane" = "plane",
		"Build an airship" = "air",
		"Build a train" = "train",
		"Make rocket sections" = "rocket",
		"Build a small ship" = "ship",
		"Draw a submarine" = "sub",
		"Build a short railway" = "rail",
		"Build a ground floor" = "house",
		"Plan a harbor" = "harbor",
		"Plan waterworks" = "water",
		"Plan a contraption" = "mech",
		"Plan a space station" = "station",
	)
	var/client/connection = body.client
	var/current = props["workshop_selected"]
	var/choice = WWinput(body, "[current ? "\"[current]\" is set up. Choosing an exercise now clears the hall, with everything drawn, built or left in it, and lays out a fresh kit." : "Choose an exercise. This workshop is yours alone, and you can come back to the desk to switch to another."] Only exercises marked Build or Make include physical construction; the others use the same designers as the live game.", desk.name, "Cancel", exercises + list("Cancel"))
	if (!exercises[choice] || !connection || body?.client != connection || connection.mob != body || !tutorial_workshop_access(body, desk) || !desk.Adjacent(body) || props["workshop_selected"] != current)
		return
	if (current)
		clear_workshop(desk)
	props["workshop_selected"] = choice
	to_chat(body, SPAN_NOTICE(setup_workshop(exercises[choice])))

// Empties the hall for the next exercise: everything in it goes except the
// desk and connected players, and the floors are laid fresh, as when the room
// was built. What the trainee carries is theirs to keep.
/datum/practice_session/proc/clear_workshop(obj/structure/practice_workshop_desk/desk)
	var/list/shop = props["shop"]
	var/list/hall = block(locate(shop[1], shop[2], practice_room_z), locate(shop[3], shop[4], practice_room_z))
	for (var/turf/T in hall)
		for (var/atom/movable/AM in T)
			if (AM == desk || AM == body || (ismob(AM) && AM:client) || istype(AM, /atom/movable/lighting_overlay))
				continue
			qdel(AM)
	// The desk and the trainee beside it stand on office floor no exercise
	// changes; those two tiles stay as they are.
	hall -= get_turf(desk)
	hall -= get_turf(body)
	for (var/turf/T in hall)
		if (T.x <= shop[1] + 4)
			new /turf/floor/wood(T)
		else
			new /turf/floor/plating/concrete(T)
	props["workshop_selected"] = null

// Fits the hall out for one exercise and returns the instructions.
/datum/practice_session/proc/setup_workshop(exercise)
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
		else
			. += " This is a paper exercise; this bay does not build that plan into the world."

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
