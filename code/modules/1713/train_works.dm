// ============================================================
// The rail works (docs/train-sheets.md)
// ------------------------------------------------------------
// An erecting shop for whole trains. Build it facing the track with one
// tile between it and the rails, like the rail warehouse office. Feed it
// iron, steel, wood, glass and cloth, then use a train sheet (train_draught.dm)
// on it: it refuses a sheet whose checks fail, research it lacks, stock it
// lacks and track that is not straight and clear for the whole train, and
// otherwise, after the work is done, lays the train out on the track with
// its front car on the rail tile in front of the works, heading the way the
// builder chose along the line, and couples the cars together in order.
//
// With a blank sheet of paper in hand, "Draw the train on the track" draws
// the train standing on the track in front of the works onto it.
// ============================================================

#define RAIL_WORKS_REACH 6 // track tiles either side of the works' rail tile it looks along for a train to draw

/obj/structure/rail_works
	name = "rail works"
	desc = "An erecting shop for whole trains. Build it facing the track with one tile between it and the rails. Feed it iron, steel, wood, glass and cloth, then use a train sheet on it: it builds the train on the track in front of it, front car first, and couples it up."
	icon = 'icons/obj/structures.dmi'
	icon_state = "workbench"
	anchored = TRUE
	density = TRUE
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	var/list/stock = list("iron" = 0, "steel" = 0, "wood" = 0, "glass" = 0, "cloth" = 0)
	var/tmp/busy = FALSE

/obj/structure/rail_works/persistence_runtime_var(key)
	return key == "busy" || ..(key)

/obj/structure/rail_works/after_load()
	..()
	busy = FALSE

// The rail tile the train's front car is built on.
/obj/structure/rail_works/proc/centre()
	return get_step(get_step(src, dir), dir)

// The two ways along the track a train can be built heading.
/obj/structure/rail_works/proc/headings()
	return list(turn(dir, 90), turn(dir, -90))

/obj/structure/rail_works/proc/stock_key(obj/item/I)
	if (istype(I, /obj/item/stack/material/iron)) return "iron"
	if (istype(I, /obj/item/stack/material/steel)) return "steel"
	if (istype(I, /obj/item/stack/material/wood)) return "wood"
	if (istype(I, /obj/item/stack/material/glass)) return "glass"
	if (is_cloth_sheet(I)) return "cloth"
	return null

/obj/structure/rail_works/proc/stock_cap(key)
	return key == "cloth" ? 400 : 1500

/obj/structure/rail_works/proc/stock_text()
	var/list/parts = list()
	for (var/key in stock)
		parts += "[stock[key] || 0] [key]"
	return english_list(parts)

/obj/structure/rail_works/examine(mob/user)
	..()
	to_chat(user, "It holds [stock_text()].")

/obj/structure/rail_works/attackby(obj/item/I, mob/living/human/H)
	if (busy || QDELETED(I) || !istype(H) || !Adjacent(H))
		return ..()
	var/obj/item/ship_draught/S = I
	if (istype(S) && S.train_draught_kind())
		build_from_sheet(H, S)
		return
	var/key = stock_key(I)
	if (key)
		var/obj/item/stack/ST = I
		var/payment = min(ST.amount, stock_cap(key) - (stock[key] || 0))
		if (payment <= 0)
			to_chat(H, SPAN_WARNING("\The [src] holds all the [key] it can."))
			return
		if (ST.use(payment))
			stock[key] = (stock[key] || 0) + payment
			to_chat(H, SPAN_NOTICE("You stock \the [src] with [payment] [key]. It holds [stock_text()]."))
		return
	return ..()

/obj/structure/rail_works/attack_hand(mob/living/human/H)
	if (busy || !istype(H) || !Adjacent(H))
		return
	var/choice = WWinput(H, "It holds [stock_text()]. Use a train sheet on the works to build its train on the track in front of it: the front car is built on the rail tile two tiles out, and the rest of the train behind it along the line. Draw one on a ship's draught with \"Draw a train on the sheet\".", name, "Cancel", list("Draw the train on the track", "Unload stock", "Cancel"))
	if (busy || !Adjacent(H))
		return
	if (choice == "Unload stock")
		unload()
	else if (choice == "Draw the train on the track")
		draw_train(H)

/obj/structure/rail_works/proc/unload()
	var/list/paths = list("iron" = /obj/item/stack/material/iron, "steel" = /obj/item/stack/material/steel, "wood" = /obj/item/stack/material/wood, "glass" = /obj/item/stack/material/glass, "cloth" = /obj/item/stack/material/cloth)
	for (var/key in paths)
		var/path = paths[key]
		while ((stock[key] || 0) > 0)
			var/obj/item/stack/S = new path(get_turf(src))
			S.amount = min(stock[key], S.max_amount)
			stock[key] -= S.amount
			S.update_icon()

/obj/structure/rail_works/Destroy()
	busy = FALSE
	return ..()

/obj/structure/rail_works/proc/missing_research(mob/living/human/H, datum/train_draught/D)
	. = list()
	if ((istype(src, /obj/structure/rail_works/practice)) && tutorial_workshop_access(H, src))
		return
	for (var/node_id in D.nodes())
		if (!H || !map || !research_node_known(H, node_id))
			var/datum/research_node/N = get_research_node(node_id)
			. += N ? N.name : node_id

/obj/structure/rail_works/proc/shortages(datum/train_draught/D)
	. = list()
	var/list/costs = D.costs()
	for (var/key in costs)
		if ((stock[key] || 0) < costs[key])
			. += "[costs[key] - (stock[key] || 0)] more [key]"

// Why the works will not take on this sheet at all, or null.
/obj/structure/rail_works/proc/sheet_refusal(mob/living/human/H, datum/train_draught/D)
	if (istype(src, /obj/structure/rail_works/practice) && !tutorial_workshop_access(H, src))
		return "Only your own practice rail works can build here."
	if (!D)
		return "The sheet cannot be read."
	var/list/errors = D.problems()
	if (errors.len)
		var/list/first = list()
		for (var/i = 1, i <= min(errors.len, 3), i++)
			var/t = errors[i]
			if (copytext(t, -1) == ".")
				t = copytext(t, 1, -1)
			first += t
		return "The sheet's checks fail, so the works will not build it: [jointext(first, "; ")][errors.len > 3 ? "; and [errors.len - 3] more" : ""]. Fix the drawing first."
	var/list/research = missing_research(H, D)
	if (research.len)
		return "[english_list(research)] research [research.len == 1 ? "is" : "are"] required to build the [D.name]."
	var/list/short = shortages(D)
	if (short.len)
		return "The [D.name] costs [D.costs_text()]. The works needs [english_list(short)]."
	return null

// The rail tiles the whole train covers, front first, or null when the
// track runs out.
/obj/structure/rail_works/proc/train_turfs(datum/train_draught/D, heading)
	. = list()
	var/turf/T = centre()
	var/tiles = D.total_tiles()
	for (var/i in 1 to tiles)
		if (!T)
			return null
		. += T
		T = get_step(T, OPPOSITE_DIR(heading))

// Why the train cannot be laid out heading that way, or null.
/obj/structure/rail_works/proc/track_problem(datum/train_draught/D, heading)
	if (!isturf(loc))
		return "The works must stand on the ground."
	if (!(heading in cardinal))
		return "Choose a way along the track."
	var/list/turfs = train_turfs(D, heading)
	if (!turfs)
		return "The track in front of the works runs off the map before the [D.total_tiles()] tiles the train needs."
	for (var/i in 1 to turfs.len)
		var/turf/T = turfs[i]
		if (!rail_straight_along(T, heading))
			return "The [D.name] needs [turfs.len] tiles of straight track running [dir2text(heading)] from the rail tile in front of the works; tile [i] is not straight track that way."
		for (var/obj/structure/trains/TR in T)
			return "\The [TR] is on the track the train would be built on."
		for (var/turf/S in train_platform_tiles(T, heading))
			if (!S || S.density)
				return "The train needs a clear tile either side of the track all along it; tile [i] is blocked."
			for (var/atom/movable/AM in S)
				if (AM == src)
					continue
				if (istype(AM, /obj/structure/trains) || istype(AM, /obj/structure/train_part) || istype(AM, /obj/structure/train_car_kit) || (AM.density && !isliving(AM)))
					return "\The [AM] is in the way of the train's deck."
	return null

/obj/structure/rail_works/proc/build_from_sheet(mob/living/human/H, obj/item/ship_draught/S)
	var/datum/train_draught/D = S.train_draught()
	var/refusal = sheet_refusal(H, D)
	if (refusal)
		to_chat(H, SPAN_WARNING(refusal))
		qdel(D)
		return null
	var/list/ways = list()
	for (var/heading in headings())
		ways["Build it heading [dir2text(heading)]"] = heading
	var/choice = WWinput(H, "Build the [D.name], [D.cars.len] car\s and [D.total_tiles()] tiles long, for [D.costs_text()]? Its front car is built on the rail tile in front of the works and the rest of it behind, along the line, coupled up and with its engines cold and empty.", name, "Cancel", ways + list("Cancel"))
	if (!(choice in ways) || busy || !Adjacent(H) || S.loc != H)
		qdel(D)
		return null
	var/heading = ways[choice]
	var/problem = track_problem(D, heading)
	if (problem)
		to_chat(H, SPAN_WARNING(problem))
		qdel(D)
		return null
	busy = TRUE
	H.visible_message("[H] sets the rail works to building \the [D.name]...", "You set the works to building the [D.name]...")
	var/completed = do_after(H, trade_time(H, 60 + 20 * D.cars.len, "mechanic"), src)
	if (QDELETED(src))
		qdel(D)
		return null
	var/obj/structure/trains/head = null
	if (completed && Adjacent(H))
		refusal = sheet_refusal(H, D) || track_problem(D, heading)
		if (refusal)
			to_chat(H, SPAN_WARNING(refusal))
		else
			var/result = build_train(D, heading)
			if (istext(result))
				to_chat(H, SPAN_WARNING("The works could not build the [D.name]: [result]."))
			else
				head = result
				log_game("[key_name(H)] built the train [D.name] ([D.cars.len] cars) at the rail works at [x],[y],[z].")
				to_chat(H, SPAN_NOTICE("The [D.name] stands on the track, coupled up and heading [dir2text(heading)]. Its engines are cold and empty: fuel and water them before driving."))
	busy = FALSE
	qdel(D)
	return head

// The last section of the car or engine whose front is front.
/proc/train_unit_last(obj/structure/trains/front)
	var/obj/structure/trains/last = front
	var/list/seen = list(front)
	while (last.connected && last.connected.car_id && last.connected.car_id == front.car_id && !(last.connected in seen))
		last = last.connected
		seen += last
	return last

// Lays D out on the track and couples it: its front car, or why it could not
// be done. Spends the stock only on success.
/obj/structure/rail_works/proc/build_train(datum/train_draught/D, heading)
	var/problem = track_problem(D, heading)
	if (problem)
		return problem
	var/list/made = list()
	var/obj/structure/trains/head = null
	var/obj/structure/trains/behind = null // the last section built so far
	var/turf/T = centre()
	for (var/kind in D.cars)
		var/list/stock_row = train_draught_stock()[kind]
		var/kit_path = stock_row ? stock_row["kit"] : /obj/structure/train_car_kit
		var/obj/structure/train_car_kit/K = new kit_path(T)
		K.set_kind(kind)
		K.furnished = TRUE
		problem = K.assembly_problem(heading)
		if (problem)
			qdel(K)
			break
		var/obj/structure/trains/front = K.assemble(heading)
		if (!front)
			problem = "a car would not go together"
			break
		var/obj/structure/trains/last = train_unit_last(front)
		var/obj/structure/trains/section = front
		while (section)
			made += section
			if (section == last)
				break
			section = section.connected
		if (behind)
			behind.join_trains(FALSE, front, TRUE)
		else
			head = front
		behind = last
		T = get_step(last.loc, OPPOSITE_DIR(heading))
	if (problem)
		for (var/obj/structure/trains/M in made)
			if (!QDELETED(M))
				qdel(M)
		return problem
	var/list/costs = D.costs()
	for (var/key in costs)
		stock[key] -= costs[key]
	return head

// "Draw the train on the track": the train standing in front of the works,
// onto a blank sheet of paper in hand.
/obj/structure/rail_works/proc/train_in_front()
	var/turf/C = centre()
	if (!C)
		return null
	for (var/obj/structure/trains/TR in C)
		return TR.train_head()
	for (var/heading in headings())
		var/turf/T = C
		for (var/i in 1 to RAIL_WORKS_REACH)
			T = get_step(T, heading)
			if (!T)
				break
			for (var/obj/structure/trains/TR in T)
				return TR.train_head()
	return null

/obj/structure/rail_works/proc/draw_train(mob/living/human/H)
	var/obj/item/weapon/paper/P = H.get_active_hand()
	if (!recipe_blank_paper(P))
		P = H.get_inactive_hand()
	if (!recipe_blank_paper(P))
		to_chat(H, SPAN_WARNING("Hold a blank sheet of paper to draw the train on."))
		return
	var/obj/structure/trains/head = train_in_front()
	if (!head)
		to_chat(H, SPAN_WARNING("There is no train on the track in front of the works."))
		return
	var/survey = train_draught_survey(head)
	if (istext(survey))
		to_chat(H, SPAN_WARNING(survey))
		return
	var/datum/train_draught/D = survey
	if (!do_after(H, 50, src) || !recipe_blank_paper(P) || P.loc != H)
		qdel(D)
		return
	var/obj/item/ship_draught/S = new(get_turf(H))
	S.take_train(D)
	H.drop_from_inventory(P)
	qdel(P)
	H.put_in_hands(S)
	to_chat(H, SPAN_NOTICE("You draw the [D.name] on the sheet: [D.cars.len] car\s from the front[D.left_off ? ". [D.left_off] one-tile wagon\s or engine\s are left off" : ""]."))
	qdel(D)

#undef RAIL_WORKS_REACH
