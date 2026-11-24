// The tutorial region's workshop, stores and plot rules. They share the
// practice session and its teardown, and never appear in the fallback room on
// other regions. The plot is laid out by build_tutorial_room
// (practice_rooms.dm), which records its interior as props["plot"], the
// drawing office as props["shop"], the paved yard as props["paved"] and the
// full-width field north of the rooms as props["field"].
//
// The desk fits the paved yard out for one exercise at a time, from the
// yard's south-west corner (px, py):
//
//   press, yard   at (px, py): it builds on the square to its north-east,
//   or works      12 x 12 for the largest airship a sheet holds
//   ship          slipway (px+15, py) facing north with five rows of dry
//                 apron, then a pool to the yard's north wall (px+1..px+29,
//                 rows py+6..py+59): room for a full 40-tile sheet
//   train         rail works (px+27, py) facing east onto a 60-tile track up
//                 the yard's east side (px+29)

// TRUE when A stands inside this session's own rectangle (x1, y1, x2, y2), on
// any level: the plot runs from the deepest rock to the highest storey.
/datum/practice_session/proc/owns_rect(atom/A, list/rect)
	if (!tutorial_region_here() || ending || !body || body.practice != src || owner.sessions["[slot]"] != src)
		return FALSE
	if (QDELETED(A) || !rect)
		return FALSE
	var/turf/T = get_turf(A)
	return T && T.x >= rect[1] && T.x <= rect[3] && T.y >= rect[2] && T.y <= rect[4]

// The drawing office.
/datum/practice_session/proc/owns_workshop(atom/A)
	return owns_rect(A, props["shop"])

// Anywhere inside the plot's outer wall.
/datum/practice_session/proc/owns_room(atom/A)
	return owns_rect(A, props["plot"])

// TRUE when the rectangle fits one of the two yards' rectangles whole.
/datum/practice_session/proc/owns_yard_box(low_x, low_y, high_x, high_y, z)
	var/turf/low = locate(low_x, low_y, z)
	var/turf/high = locate(high_x, high_y, z)
	for (var/key in list("paved", "field"))
		if (owns_rect(low, props[key]) && owns_rect(high, props[key]))
			return TRUE
	return FALSE

// Where the trainee may walk: their own plot, on every level. Elsewhere than
// a tutorial region the room's own walls are the limit.
/datum/practice_session/proc/may_stand(turf/T)
	if (!tutorial_region_here() || ending || !props["plot"])
		return TRUE
	var/list/plot = props["plot"]
	return T && T.x >= plot[1] && T.x <= plot[3] && T.y >= plot[2] && T.y <= plot[4]

/proc/tutorial_workshop_access(mob/living/human/H, atom/station)
	var/mob/living/human/practice/P = H
	return istype(P) && P.practice && P.practice.owns_room(P) && P.practice.owns_room(station)

// Marker-based plans use this after the construction wait and before pulling
// any old pegs. In a tutorial region the footprint must fit one of the
// trainee's yards, on whichever level it is pegged; checking opposite corners
// is enough even for an oversized imported plan. The fallback practice level
// on other regions takes no plans.
/proc/tutorial_workshop_footprint(mob/H, low_x, low_y, high_x, high_y, z)
	if (tutorial_region_here())
		var/mob/living/human/practice/P = H
		return istype(P) && P.practice && P.practice.owns_room(P) && P.practice.owns_yard_box(low_x, low_y, high_x, high_y, z)
	return !practice_room_z || z != practice_room_z

// Limit workshop structures to the trainee's own yard on Tutorial's map levels.
/proc/tutorial_station_module_site(mob/H, turf/centre, radius)
	if (!tutorial_region_here())
		return !practice_room_z || centre.z != practice_room_z
	var/mob/living/human/practice/P = H
	if (!istype(P) || !P.practice || P.practice.props["workshop_kind"] != "station" || !P.practice.owns_room(P) || centre.z != P.practice.owner.room_z())
		return FALSE
	var/list/paved = P.practice.props["paved"]
	return P.practice.owns_rect(locate(centre.x - radius, centre.y - radius, centre.z), paved) && P.practice.owns_rect(locate(centre.x + radius, centre.y + radius, centre.z), paved)

// A cord interaction may never target another trainee's plot.
/proc/tutorial_workshop_pair(mob/living/human/H, atom/source, atom/target)
	var/turf/A = get_turf(source)
	var/turf/B = get_turf(target)
	if (!tutorial_region_here() && (!practice_room_z || (A?.z != practice_room_z && B?.z != practice_room_z)))
		return TRUE
	return tutorial_workshop_access(H, source) && tutorial_workshop_access(H, target)

// The first workshop is sealed. Check the supplied site, the airlock kit,
// and its clear southward exit before and after the construction wait.
/proc/tutorial_station_kit_refusal(mob/user, obj/item/habitat_kit/kit, turf/centre, spacing, radius)
	if (!tutorial_region_here() || !istype(kit, /obj/item/habitat_kit/workshop))
		return null
	var/mob/living/human/practice/P = user
	if (!istype(P) || !P.practice || P.practice.props["workshop_kind"] != "station")
		return null
	if (P.get_active_hand() != kit || !istype(P.get_inactive_hand(), /obj/item/habitat_kit/airlock))
		return "Hold an airlock kit in your other hand before unfolding the workshop, so you can open a way out."
	var/list/paved = P.practice.props["paved"]
	if (!P.practice.owner || !paved || !centre || centre != get_turf(P) || centre != locate(paved[1] + 10, paved[2] + 10, P.practice.owner.room_z()))
		return "Stand three tiles east of the marker to unfold the practice workshop."
	var/turf/airlock_site = locate(centre.x, centre.y - spacing, centre.z)
	var/turf/exit = locate(centre.x, centre.y - spacing - radius - 1, centre.z)
	if (!airlock_site || !exit || !P.practice.owns_rect(exit, paved) || exit.density || istype(exit, /turf/floor/habitat) || habitat_module_refusal(airlock_site, P))
		return "Keep the ground south of the workshop clear for the airlock and its exit."
	for (var/atom/movable/A in exit)
		if (A.density)
			return "Keep the ground south of the workshop clear for the airlock and its exit."
	return null

/proc/draught_age_available(mob/living/human/H, age)
	return (map && map.ordinal_age >= age) || tutorial_workshop_access(H, H)

/obj/structure/practice_workshop_desk
	name = "practice workshop desk"
	desc = "Choose a workshop exercise here. Each one comes with clean drawing sheets, a pencil, and its fixtures in the paved yard. Materials and tools come from the practice stores."
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
		"Write and print a notice" = "paper",
		"Build a car or tank" = "car",
		"Build a plane" = "plane",
		"Build an airship" = "air",
		"Build a train" = "train",
		"Make rocket sections" = "rocket",
		"Build a ship" = "ship",
		"Assemble a submarine" = "sub",
		"Build a railway" = "rail",
		"Build a house" = "house",
		"Build a short pier" = "harbor",
		"Build an aqueduct" = "water",
		"Rig a bell" = "mech",
		"Unfold a station workshop" = "station",
	)
	var/client/connection = body.client
	var/current = props["workshop_selected"]
	var/prompt = "Choose an exercise. This workshop is yours alone, and you can come back to the desk to switch to another."
	if (current)
		prompt = "\"[current]\" is set up. Choosing an exercise now clears both yards on every level, with everything built, dug or left in them, and lays out the new one."
	var/choice = WWinput(body, "[prompt] The writing lesson uses a press; the other exercises provide small physical builds with the live game's designers.", desk.name, "Cancel", exercises + list("Cancel"))
	if (!exercises[choice] || !connection || body?.client != connection || connection.mob != body || !tutorial_workshop_access(body, desk) || !desk.Adjacent(body) || props["workshop_selected"] != current)
		return
	if (current)
		clear_workshop(desk)
	props["workshop_selected"] = choice
	to_chat(body, SPAN_NOTICE(setup_workshop(exercises[choice])))

// Empties the yards for the next exercise: everything in them goes on every
// level, tunnels fill and the ground is laid fresh, as when the plot was
// built. The lesson rooms and what the trainee carries stay as they are.
/datum/practice_session/proc/clear_workshop(obj/structure/practice_workshop_desk/desk)
	// Revoke the active lesson before clearing its press or its contents.
	props["practice_press"] = null
	props["practice_paper_done"] = null
	var/list/stores = props["stores"]
	for (var/key in list("paved", "field"))
		owner.clear_column(props[key], stores)
		owner.lay_tutorial_ground(slot, props[key])
	// Sheets and pencils left on the supply floor.
	for (var/turf/T in supply_floor())
		for (var/obj/item/I in T)
			qdel(I)
	props["workshop_selected"] = null
	props["workshop_kind"] = null

// The office floor the desk lays sheets on, south of it.
/datum/practice_session/proc/supply_floor()
	var/list/shop = props["shop"]
	return block(locate(shop[1] + 1, shop[2] + 2, owner.room_z()), locate(shop[1] + 3, shop[2] + 3, owner.room_z()))

// Fits the paved yard out for one exercise and returns the instructions.
/datum/practice_session/proc/setup_workshop(exercise)
	if (!owns_room(body) || !exercise || props["workshop_kind"])
		return null
	props["workshop_kind"] = exercise
	var/list/paved = props["paved"]
	var/px = paved[1]
	var/py = paved[2]
	var/z = owner.room_z()
	var/list/supply = supply_floor()
	if (exercise == "paper")
		return setup_practice_paper(supply[1], locate(px, py, z))
	new /obj/item/ship_draught(supply[1])
	new /obj/item/ship_draught(supply[1])
	new /obj/item/weapon/pen/pencil(supply[2])
	var/turf/worksite = locate(px, py, z)
	. = "Pick up a blank draught and the pencil from the floor south of the desk. Use the draught in hand and select the corresponding Draw option. Use the designer's Checks and parts list to improve your design. The practice stores in the office and in both yards hand out any materials and tools you need."
	switch (exercise)
		if ("car")
			setup_practice_press(new /obj/structure/car_workshop/practice(worksite))
			. += " Use the saved vehicle or tank sheet on the stocked automobile workshop just inside the paved yard, through the office's east door. It builds on the paving to its northeast."
		if ("plane")
			setup_practice_press(new /obj/structure/car_workshop/hangar/practice(worksite))
			. += " Use the saved plane sheet on the stocked aircraft hangar just inside the paved yard, through the office's east door. It builds on the paving to its northeast."
		if ("air")
			setup_practice_press(new /obj/structure/car_workshop/airship_yard/practice(worksite))
			. += " Use the saved airship sheet on the stocked airship yard just inside the paved yard, through the office's east door. It lays her deck on the paving to its northeast, with room for the largest airship a sheet can hold. The yard commissions the ship with its gas and fuel tanks empty."
		if ("ship")
			var/obj/structure/slipway/practice/W = new(locate(px + 15, py, z))
			W.session = src
			W.set_dir(NORTH)
			for (var/turf/T in block(locate(px + 1, py + 6, z), locate(px + 29, paved[4], z)))
				new /turf/floor/beach/water/deep(T)
			. += " Draw a ship of any size the sheet allows, up to 29 tiles in the beam. Pin its draught to the slipway at the south wall of the paved yard, fit the pieces with materials from the stores, and launch it north into the pool. A hull longer than five tiles is built out over the water, as on a real slip."
		if ("train")
			var/obj/structure/rail_works/practice/W = new(locate(px + 27, py, z))
			W.set_dir(EAST)
			for (var/turf/T in block(locate(px + 29, py, z), locate(px + 29, paved[4], z)))
				track_make_rail(T, NORTH, FALSE)
			for (var/material in W.stock)
				W.stock[material] = W.stock_cap(material)
			. += " Use the saved train sheet on the stocked rail works at the south end of the track, in the paved yard's south-east corner. Choose a south-facing build: the track holds a train up to sixty tiles long."
		if ("house")
			. += " Draw a house of any size, with as many storeys as the sheet holds, and peg it out in either yard. Take wood, planks, stone and a hammer from the stores, open Construction on them and build on the matching pegs. The soil yard carries two storeys; build taller houses on the paved yard, which is founded ground."
		if ("rail")
			. += " Draw a line of track and peg it out in either yard. Take sleepers, rails and a hammer from the stores. Lay sleepers on each marker, add rails, then use the hammer to spike them down."
		if ("rocket")
			var/obj/structure/rocket_works/practice/W = new(worksite)
			for (var/material in W.stock)
				W.stock[material] = 1000
			. += " Use the saved rocket sheet on the stocked rocket works just inside the paved yard, then click the works to make each section. Move each finished section out of the way. This exercise does not stack or launch a rocket."
		if ("sub")
			for (var/col = px + 6 to px + 13)
				for (var/row = py + 2 to py + 9)
					var/turf/T = locate(col, row, z)
					new /turf/floor/beach/water(T)
			for (var/col = px + 8 to px + 10)
				for (var/row = py + 3 to py + 7)
					new /obj/structure/vehicleparts/frame/ship/steel/submarine/section(locate(col, row, z))
			var/obj/structure/vehicleparts/axis/ship/submarine/controls/practice/W = new(locate(px + 9, py + 7, z))
			W.session = src
			new /obj/structure/vehicleparts/shipwheel(locate(px + 9, py + 6, z))
			new /obj/structure/vehicleparts/sub_station/loose(locate(px + 9, py + 5, z))
			new /obj/structure/engine/internal/diesel/premade/chiha(locate(px + 9, py + 3, z))
			new /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank(locate(px + 9, py + 3, z))
			. += " Draw a five-row submarine, with a helm in the centre of row two, a ballast station in the centre of row three, and a side hatch. The supplied 3 by 5 hull carries those fittings, a diesel engine and an empty fuel tank. Apply the saved sheet to its controls, then select Assemble it and North. The practice boat cannot drive or dive."
		if ("harbor")
			var/turf/start = locate(px + 8, py + 6, z)
			new /obj/effect/practice_marker(start)
			for (var/col = px + 9 to px + 10)
				var/turf/T = locate(col, py + 6, z)
				new /turf/floor/beach/water/shallowsaltwater(T)
			new /obj/structure/workshop_machine/pile_driver(locate(px + 8, py + 7, z))
			for (var/i in 1 to 2)
				new /obj/item/weapon/bridge_span(supply[3])
				new /obj/item/weapon/bridge_span/timber(supply[4])
			. += " Draw a two-span pier. Stand on the marker and face east to survey it. Install spans one at a time from the shore outward. The pile driver stands beside the start if you choose timber. This yard teaches a pier, not a dry dock or boathouse."
		if ("water")
			new /obj/effect/practice_marker(locate(px + 9, py + 6, z))
			var/turf/T = locate(px + 8, py + 6, z)
			new /turf/floor/beach/water(T)
			practice_workshop_stack(supply[3], /obj/item/stack/material/stone, 1)
			new /obj/item/weapon/reagent_containers/glass/small_pot(supply[4])
			. += " In an aqueduct plan place an intake, channel and fountain on three consecutive tiles running east from the marker. Preview and peg the route while standing on the marker. Build all three pieces from the supplied stone over their pegs. Wait a minute for the channel to feed the fountain, then fill the pot."
		if ("mech")
			practice_workshop_stack(supply[3], /obj/item/stack/material/wood, 1)
			practice_workshop_stack(supply[4], /obj/item/stack/material/rope, 1)
			new /obj/structure/bell(locate(px + 9, py + 7, z))
			. += " Draw a lever and bell with a cord between them. Build the lever from the supplied wood within seven tiles of the actual bell, use rope on the lever to tie it to the bell, then throw the lever to ring it."
		if ("station")
			new /obj/effect/practice_marker(locate(px + 7, py + 10, z))
			new /obj/item/habitat_kit/workshop(supply[3])
			new /obj/item/habitat_kit/airlock(supply[4])
			new /obj/item/habitat_kit/airlock(supply[4])
			. += " Draw a command module with a keel airlock at one end and a docking airlock at the other. Hold an airlock kit in one hand and the workshop kit in the other. Unfold the workshop three tiles east of the marker. Inside, step one tile south of its core, swap hands, and unfold the airlock. Open the connecting hatch and outer hatch to leave, then fetch the second airlock and unfold it four tiles north of the workshop. Open its outer hatch and step north to leave. This practice build does not allocate orbit, launch, or install a live docking port."


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
	if (tutorial_workshop_access(H, src) && session?.owns_rect(target, session.props["paved"]))
		return ..()
	return FALSE

/obj/structure/slipway/practice/keel_refusal(datum/slipway_design/D, mob/living/human/H)
	return "Use your own ship draught on this practice slipway."

/obj/structure/slipway/practice/draught_refusal(datum/ship_draught/D)
	if (dir != NORTH || !session?.owns_rect(src, session.props["paved"]) || !D)
		return "This practice slipway only builds facing north, in its own yard."
	var/list/berth = draught_berth(D)
	for (var/turf/T in berth)
		if (!session.owns_rect(T, session.props["paved"]))
			return "The hull is too wide for the yard: keep it to 29 tiles in the beam."
	return ..()

/obj/structure/slipway/practice/draught_landing(list/berth, length)
	var/slide = ..()
	if (slide < 0 || !session || dir != NORTH)
		return -1
	for (var/turf/T in berth)
		var/turf/landing = locate(T.x, T.y + slide, T.z)
		if (!session.owns_rect(T, session.props["paved"]) || !session.owns_rect(landing, session.props["paved"]))
			return -1
	return slide

// Practice stores: materials and tools for the yards, without limit. Only the
// plot's own trainee can draw from them, and only inside the plot, so nothing
// reaches the live game.
/obj/structure/practice_stores
	name = "practice stores"
	desc = "Building materials and tools for practice. Take as much as you like; it never runs out."
	icon = 'icons/obj/storage.dmi'
	icon_state = "wood_crate_opened"
	anchored = TRUE
	density = TRUE
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	should_save = FALSE

// What the stores hand out: label -> type. A stack comes full.
/proc/practice_stores_stock()
	return list(
		"Wood" = /obj/item/stack/material/wood,
		"Wood planks" = /obj/item/stack/material/woodplank,
		"Stone" = /obj/item/stack/material/stone,
		"Stone bricks" = /obj/item/stack/material/stonebrick,
		"Sandstone" = /obj/item/stack/material/sandstone,
		"Marble" = /obj/item/stack/material/marble,
		"Clay" = /obj/item/stack/material/clay,
		"Concrete" = /obj/item/stack/material/concrete,
		"Glass" = /obj/item/stack/material/glass,
		"Iron" = /obj/item/stack/material/iron,
		"Steel" = /obj/item/stack/material/steel,
		"Copper" = /obj/item/stack/material/copper,
		"Bronze" = /obj/item/stack/material/bronze,
		"Aluminium" = /obj/item/stack/material/aluminium,
		"Cloth" = /obj/item/stack/material/cloth,
		"Leather" = /obj/item/stack/material/leather,
		"Rope" = /obj/item/stack/material/rope,
		"Straw" = /obj/item/stack/material/straw,
		"Rail sleepers" = /obj/item/stack/rail_sleepers,
		"Rail lengths" = /obj/item/stack/rail_lengths,
		"Shovel" = /obj/item/weapon/material/shovel,
		"Pickaxe" = /obj/item/weapon/material/pickaxe,
		"Hammer" = /obj/item/weapon/hammer,
		"Saw" = /obj/item/weapon/saw,
		"Chisel" = /obj/item/weapon/chisel,
		"Wrench" = /obj/item/weapon/wrench,
		"Knife" = /obj/item/weapon/material/kitchen/utensil/knife,
		"Torch" = /obj/item/flashlight/torch,
		"Lantern" = /obj/item/flashlight/lantern,
		"Blank draught" = /obj/item/ship_draught,
		"Pencil" = /obj/item/weapon/pen/pencil,
	)

/obj/structure/practice_stores/proc/usable_by(mob/living/human/practice/H)
	return istype(H) && H.practice && H.practice.owns_room(H) && H.practice.owns_room(src) && Adjacent(H)

// Puts one of a stocked kind at the trainee's feet. Returns it, or null.
/obj/structure/practice_stores/proc/hand_out(mob/living/human/practice/H, label)
	var/path = practice_stores_stock()[label]
	if (!path || !usable_by(H))
		return null
	var/turf/T = get_turf(H)
	var/loose = 0
	for (var/obj/item/I in T)
		loose++
	if (loose >= 20)
		to_chat(H, SPAN_WARNING("The pile at your feet is in the way. Pick some of it up or step aside first."))
		return null
	var/obj/item/made = new path(T)
	var/obj/item/stack/S = made
	if (istype(S))
		S.amount = S.max_amount
		S.update_icon()
	return made

/obj/structure/practice_stores/attack_hand(mob/living/human/practice/H)
	if (!usable_by(H))
		return
	var/client/connection = H.client
	var/list/stock = practice_stores_stock()
	var/list/labels = list()
	for (var/label in stock)
		labels += label
	var/choice = WWinput(H, "Take what from the stores? It is put at your feet, a full stack at a time, and there is always more.", name, "Cancel", labels + list("Cancel"))
	if (!stock[choice] || !connection || H.client != connection || connection.mob != H)
		return
	var/obj/item/made = hand_out(H, choice)
	if (made)
		to_chat(H, SPAN_NOTICE("You take \a [made] from the stores."))

// Construction permissions are for these three outputs and their selected
// practice exercise, not knowledge, XP, any other recipe or a real character.
/proc/tutorial_waterworks_recipe(mob/living/human/H, result_path_string)
	var/mob/living/human/practice/P = H
	return istype(P) && P.practice && P.practice.props["workshop_kind"] == "water" && P.practice.owns_rect(P, P.practice.props["paved"]) && P.z == P.practice.owner.room_z() && (result_path_string in list(
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

/obj/structure/vehicleparts/axis/ship/submarine/controls/practice/proc/practice_site()
	return session && session.owner && z == session.owner.room_z() && session.owns_rect(src, session.props["paved"])

/obj/structure/vehicleparts/axis/ship/submarine/controls/practice/assembly_refusal(datum/vehicle_survey/S)
	var/datum/sub_draught/D = sheet()
	var/is_five = D && D.length == 5
	qdel(D)
	if (!is_five || !practice_site() || S.width != 3 || S.height != 5)
		return "use a five-row submarine sheet on the supplied hull"
	// The controls also lay out a five-wide turning square.
	if (!session.owns_rect(locate(S.min_x - 2, S.min_y, z), session.props["paved"]) || !session.owns_rect(locate(S.max_x + 2, S.max_y, z), session.props["paved"]))
		return "keep the whole hull and its turning space inside your bay"
	return ..()

/obj/structure/vehicleparts/axis/ship/submarine/controls/practice/depth_refusal(diving)
	return "The practice basin is for assembling a submarine, not diving."

/obj/structure/vehicleparts/axis/ship/submarine/controls/practice/do_vehicle_check()
	moving = FALSE
	stopmovementloop()
	return FALSE
