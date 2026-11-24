// One optional workshop per tutorial session. It shares the practice plane
// and teardown, but never appears in the live-world fallback room.

/datum/practice_session/proc/owns_workshop(atom/A)
	if (!tutorial_region_here() || ending || !body || body.practice != src || owner.sessions["[slot]"] != src || !practice_room_z)
		return FALSE
	if (QDELETED(A))
		return FALSE
	var/turf/T = get_turf(A)
	var/list/O = owner.slot_origin(slot)
	return T && T.z == practice_room_z && T.x > O[1] + 16 && T.x < O[1] + 34 && T.y > O[2] && T.y < O[2] + 14

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
	desc = "Choose a workshop exercise. Each exercise comes with a clean drawing sheet, a pencil, and the fixtures needed for that lesson."
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
		"Draw a submarine" = "sub",
		"Build a short railway" = "rail",
		"Build a ground floor" = "house",
		"Plan a harbor" = "harbor",
		"Plan waterworks" = "water",
		"Plan a contraption" = "mech",
		"Plan a space station" = "station",
	)
	var/client/connection = body.client
	var/choice = WWinput(body, "Choose an exercise. This workshop is yours alone. Only exercises marked Build or Make include physical construction; the others use the same designers as the live game.", desk.name, "Cancel", exercises + list("Cancel"))
	if (!exercises[choice] || !connection || body?.client != connection || connection.mob != body || !tutorial_workshop_access(body, desk) || !desk.Adjacent(body) || props["workshop_selected"])
		return
	props["workshop_selected"] = choice
	var/list/O = owner.slot_origin(slot)
	var/x = O[1]
	var/y = O[2]
	var/z = practice_room_z
	var/turf/supply = locate(x + 19, y + 11, z)
	new /obj/item/ship_draught(supply)
	new /obj/item/ship_draught(supply)
	new /obj/item/weapon/pen/pencil(supply)
	var/turf/worksite = locate(x + 19, y + 1, z)
	var/instructions = "Pick up a blank draught and a pencil. Use the draught in hand and select the corresponding Draw option. Use the designer's Checks and parts list to improve your design."
	switch (exercises[choice])
		if ("car")
			setup_practice_press(new /obj/structure/car_workshop/practice(worksite))
			instructions += " Use the saved vehicle or tank sheet on the stocked automobile workshop. Keep its square to the northeast clear."
		if ("plane")
			setup_practice_press(new /obj/structure/car_workshop/hangar/practice(worksite))
			instructions += " Use the saved plane sheet on the stocked aircraft hangar. Keep its square to the northeast clear."
		if ("air")
			setup_practice_press(new /obj/structure/car_workshop/airship_yard/practice(worksite))
			instructions += " Use the saved airship sheet on the stocked airship yard. Keep the ground to the northeast clear. The yard commissions the ship with its gas and fuel tanks empty."
		if ("ship")
			var/obj/structure/slipway/practice/W = new(locate(x + 27, y + 2, z))
			W.session = src
			W.dir = NORTH
			for (var/col = x + 22 to x + 32)
				for (var/row = y + 8 to y + 13)
					var/turf/T = locate(col, row, z)
					new /turf/floor/beach/water/deep(T)
			var/list/stacks = list(/obj/item/stack/material/wood, /obj/item/stack/material/woodplank, /obj/item/stack/material/iron, /obj/item/stack/material/steel)
			for (var/path in stacks)
				practice_workshop_stack(supply, path, 4)
			instructions += " Draw a single deck ship up to five tiles long and five wide, with no upper decks or hold. Pin its draught to the slipway, fit pieces using the stacks by the desk, and launch it into this small pool."
		if ("train")
			var/obj/structure/rail_works/practice/W = new(locate(x + 19, y + 4, z))
			W.dir = EAST
			for (var/row = y + 2 to y + 13)
				track_make_rail(locate(x + 21, row, z), NORTH, FALSE)
			for (var/material in W.stock)
				W.stock[material] = W.stock_cap(material)
			instructions += " Use the saved train sheet on the stocked rail works. Choose a south-facing build for up to eight tiles of consist; the track is shorter than a main-world rail yard."
		if ("house")
			practice_workshop_stack(supply, /obj/item/stack/material/wood, 3)
			practice_workshop_stack(supply, /obj/item/stack/material/woodplank, 2)
			practice_workshop_stack(supply, /obj/item/stack/material/stone, 2)
			new /obj/item/weapon/hammer(supply)
			instructions += " Draw a small house's ground-floor walls, door, and floor, leaving roofs and upper floors off the sheet. Peg it out on the clear workshop floor. Open Construction on the supplied wood or stone and build on the matching pegs."
		if ("rail")
			new /obj/item/stack/rail_sleepers(supply, 10)
			new /obj/item/stack/rail_lengths(supply, 10)
			new /obj/item/weapon/hammer(supply)
			instructions += " Draw up to ten tiles of track and peg them out on the clear floor. Lay sleepers on each marker, add rails, then use the hammer to spike them down."
		if ("rocket")
			var/obj/structure/rocket_works/practice/W = new(worksite)
			for (var/material in W.stock)
				W.stock[material] = 1000
			instructions += " Use the saved rocket sheet on the stocked rocket works, then click the works to make each section. Move each finished section out of the way. This exercise does not stack or launch a rocket."
		else
			instructions += " This is a paper exercise; this bay does not build that plan into the world."
	to_chat(body, SPAN_NOTICE(instructions))

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
	parent_type = /obj/structure/practice_workshop_desk
	name = "practice lesson board"
	desc = "Read any lesson from the character tutorial. Use the tree, grass and flint in camp to try primitive toolmaking."

/obj/structure/practice_lesson_board/attack_hand(mob/living/human/practice/H)
	if (!tutorial_workshop_access(H, src) || !Adjacent(H))
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
	if (lessons[choice] && connection && H.client == connection && connection.mob == H && tutorial_workshop_access(H, src) && Adjacent(H))
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
