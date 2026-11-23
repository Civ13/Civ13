// ============================================================
// Building a rocket (docs/rocket-plans.md)
// ------------------------------------------------------------
// A rocket sheet (rocket_plan.dm) is never one recipe. Any land can import
// one, but only a local rocket works and launch stand build and fly it:
//
// - The rocket works takes a sheet as its order and builds its pieces one
//   at a time from the steel, aluminium, copper and electronics delivered to
//   it. Each comes out as a rocket section: a heavy part only a hoist lifts
//   between levels, carrying its own condition.
// - A launch stand beside a launch pad takes the same sheet and mounts the
//   sections in its order, from the pad up. The stack is a modular rocket
//   standing on the stand's tile; crew strap in, cargo is stowed and
//   propellant loaded there, like any crewed lander (lander.dm).
// - Each storey holds ROCKET_STOREY_SECTIONS sections. Storey 1 mounts on
//   the stand's own level; storey 2 and up mount from the levels above it,
//   through open sky, from a platform players build beside the column. A
//   section reaches those levels by crane (power_cranes.dm, lifting_machines.dm).
//   Where the world has fewer levels above, the storeys past them mount from
//   the highest it has.
//
// The launch planner (rocket_plan legs) is checked again at launch with the
// real cargo, and launch offers only what the pad's destination and the
// supported legs allow. Nothing here stores world.time or an object ref.
// ============================================================

#define ROCKET_WORKS_STOCK_CAP 800
#define ROCKET_WORKS_BUILD_TIME 80
#define ROCKET_MOUNT_TIME 40
// A hold item weighs this much on the launch planner, in tonnes.
#define ROCKET_ITEM_TONNES 0.25

// The stack type each stock key takes.
/proc/rocket_works_stock_types()
	var/static/list/table
	if (!table)
		table = list(
		"steel" = /obj/item/stack/material/steel,
		"aluminium" = /obj/item/stack/material/aluminium,
		"copper" = /obj/item/stack/material/copper,
		"electronics" = /obj/item/stack/material/electronics,
		)
	return table

// What piece key at position i of plan D costs, with the frame named.
/proc/rocket_piece_cost(datum/rocket_plan/D, key)
	. = list()
	var/list/C = rocket_plan_piece_costs(key)
	for (var/material in C)
		var/to_material = material == "frame" ? (D.frame == "a" ? "aluminium" : "steel") : material
		.[to_material] = (.[to_material] || 0) + C[material]

/proc/rocket_cost_text(list/C)
	var/list/parts = list()
	for (var/material in C)
		parts += "[C[material]] [material]"
	return english_list(parts)

// ---------------------------------------------------------------- sections

/obj/structure/rocket_section
	name = "rocket section"
	desc = "A section of a rocket, built at a rocket works. Mount it on a launch stand in the order its sheet calls for. It is too heavy for a ladder: hoist it."
	icon = 'icons/obj/decals_wider.dmi'
	icon_state = "rocket"
	anchored = FALSE
	density = TRUE
	flammable = FALSE
	var/piece = "T"
	// "s" or "a" for framed pieces, null for the rest.
	var/frame = null
	// 0 to 100, plain numbers; never a world.time stamp.
	var/condition = 100
	var/flights = 0
	var/inspected = TRUE

/obj/structure/rocket_section/New(loc, new_piece, new_frame)
	..()
	if (new_piece)
		piece = new_piece
	if (new_frame)
		frame = new_frame
	refresh_name()

/obj/structure/rocket_section/proc/refresh_name()
	var/list/P = rocket_plan_pieces()[piece]
	if (!P)
		return
	var/list/F = frame ? rocket_plan_frames()[frame] : null
	name = F ? "[F["name"]] [P["name"]]" : P["name"]

/obj/structure/rocket_section/examine(mob/user)
	..()
	var/list/P = rocket_plan_pieces()[piece]
	if (P)
		to_chat(user, SPAN_NOTICE(P["what"]))
	to_chat(user, SPAN_NOTICE("Condition: [round(condition)]%. Flights: [flights].[inspected ? "" : " It has not been inspected since its last flight."]"))

// Why it will not mount, or null.
/obj/structure/rocket_section/proc/mount_refusal()
	if (condition < ROCKET_SECTION_MIN_CONDITION)
		return "\The [src] is too worn to fly ([round(condition)]%). Repair it first."
	if (!inspected)
		return "\The [src] has not been inspected since its last flight."
	return null

// The upper storeys of a stack: the rocket's body on the levels above its
// stand, where those storeys' sections are mounted. Never used by hand
// except to drop a section onto it.
/obj/structure/rocket_storey
	name = "rocket"
	desc = "The upper storeys of a rocket on its launch stand. Drag the next section here to mount it."
	icon = 'icons/obj/decals_wider.dmi'
	icon_state = "rocket"
	anchored = TRUE
	density = TRUE
	not_movable = TRUE
	flammable = FALSE

/obj/structure/rocket_storey/ex_act(severity)
	return

/obj/structure/rocket_storey/proc/stand()
	var/turf/T = get_turf(src)
	var/level = T ? T.z : 0
	for (var/i in 1 to ROCKET_PLAN_MAX_SECTIONS)
		level = multiz_level_below(level)
		if (!level)
			return null
		var/obj/structure/rocket_stand/S = locate() in locate(x, y, level)
		if (S)
			return S
	return null

/obj/structure/rocket_storey/MouseDrop_T(atom/movable/O, mob/living/human/user)
	var/obj/structure/rocket_stand/S = stand()
	if (S)
		S.mount(user, O)

// ---------------------------------------------------------------- rocket works

/obj/structure/rocket_works
	name = "rocket works"
	desc = "A tall assembly hall with jigs, welding bays and a test cell. Feed it steel, aluminium, copper and electronics, give it a rocket sheet, and it builds the sheet's sections one by one."
	icon = 'icons/obj/structures.dmi'
	icon_state = "workbench"
	anchored = TRUE
	density = TRUE
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	var/list/stock = list("steel" = 0, "aluminium" = 0, "copper" = 0, "electronics" = 0)
	// The sheet it builds, as a design code, and how many of its pieces are built.
	var/order_code = ""
	var/built = 0
	var/tmp/busy = FALSE

/obj/structure/rocket_works/New()
	..()
	if (!islist(stock))
		stock = list()

/obj/structure/rocket_works/after_load()
	..()
	busy = FALSE

/obj/structure/rocket_works/proc/order()
	return order_code ? rocket_plan_from_code(order_code) : null

/obj/structure/rocket_works/proc/allowed(mob/living/human/H)
	return H && research_node_known(H, "orbital_flight")

/obj/structure/rocket_works/proc/stock_text()
	var/list/parts = list()
	for (var/key in rocket_works_stock_types())
		parts += "[stock[key] || 0] [key]"
	return english_list(parts)

/obj/structure/rocket_works/attackby(obj/item/I, mob/living/human/H)
	if (busy || !istype(H) || !Adjacent(H))
		return
	var/obj/item/ship_draught/sheet = I
	if (istype(sheet) && sheet.rocket_plan_kind())
		take_order(H, sheet)
		return
	var/obj/item/stack/S = I
	if (istype(S))
		var/list/types = rocket_works_stock_types()
		for (var/key in types)
			if (!istype(S, types[key]))
				continue
			var/amount = min(S.amount, ROCKET_WORKS_STOCK_CAP - (stock[key] || 0))
			if (amount <= 0)
				to_chat(H, SPAN_WARNING("\The [src] holds no more [key]."))
				return
			if (S.use(amount))
				stock[key] = (stock[key] || 0) + amount
				to_chat(H, SPAN_NOTICE("You stock \the [src] with [amount] [key]. Stored: [stock_text()]."))
			return
	return ..()

/obj/structure/rocket_works/proc/order_refusal(mob/living/human/H, datum/rocket_plan/D)
	if (!D)
		return "That rocket sheet cannot be read."
	if (!allowed(H))
		return "Orbital Flight research is required to work the rocket works."
	var/list/problems = D.problems()
	if (problems.len)
		return "The [D.name] cannot be built as drawn: [problems[1]]"
	return null

/obj/structure/rocket_works/proc/take_order(mob/living/human/H, obj/item/ship_draught/sheet)
	var/datum/rocket_plan/D = sheet.rocket_plan()
	var/reason = order_refusal(H, D)
	if (reason)
		to_chat(H, SPAN_WARNING(reason))
		if (D)
			qdel(D)
		return FALSE
	if (order_code && built && order_code != D.to_code())
		if (WWinput(H, "\The [src] has built [built] piece\s of another rocket. Start this one instead?", name, "Cancel", list("Start it", "Cancel")) != "Start it" || QDELETED(src) || !Adjacent(H))
			qdel(D)
			return FALSE
	if (order_code != D.to_code())
		order_code = D.to_code()
		built = 0
	log_game("Rocket works: [key_name(H)] set the works at [x],[y],[z] to build [D.name] ([order_code]).")
	to_chat(H, SPAN_NOTICE("\The [src] will build the [D.name]: [D.stack.len] pieces for [D.costs_text()]."))
	qdel(D)
	return TRUE

/obj/structure/rocket_works/attack_hand(mob/living/human/H)
	if (busy || !istype(H) || !Adjacent(H))
		return
	if (!allowed(H))
		to_chat(H, SPAN_WARNING("Orbital Flight research is required to work the rocket works."))
		return
	var/datum/rocket_plan/D = order()
	var/list/options = list()
	var/text = "Stored: [stock_text()]."
	if (D)
		text += " Building the [D.name]: [built]/[D.stack.len] pieces built."
		if (built < D.stack.len)
			var/key = D.stack[built + 1]
			var/list/P = rocket_plan_pieces()[key]
			options["Build the next piece: [P["name"]] ([rocket_cost_text(rocket_piece_cost(D, key))])"] = "build"
		options["Build it again from the first piece"] = "restart"
	else
		text += " Use a rocket sheet on it to give it an order."
	options["Unload the stock"] = "unload"
	var/choice = WWinput(H, text, name, "Cancel", options + list("Cancel"))
	if (QDELETED(src) || busy || !Adjacent(H) || !(choice in options))
		qdel(D)
		return
	switch (options[choice])
		if ("build")
			build_next(H)
		if ("restart")
			built = 0
			to_chat(H, SPAN_NOTICE("\The [src] starts the [D.name] again from its first piece."))
		if ("unload")
			unload()
	qdel(D)

// Where a new section is set down: a clear floor beside the works.
/obj/structure/rocket_works/proc/output_turf()
	for (var/d in list(EAST, SOUTH, WEST, NORTH))
		var/turf/T = get_step(src, d)
		if (!T || T.density || !istype(T, /turf/floor))
			continue
		var/clear = TRUE
		for (var/atom/movable/A in T)
			if (A.density)
				clear = FALSE
				break
		if (clear)
			return T
	return null

// Builds the next piece of the order. Returns the section, or null.
/obj/structure/rocket_works/proc/build_next(mob/living/human/H)
	var/datum/rocket_plan/D = order()
	if (!D || built >= D.stack.len)
		qdel(D)
		return null
	var/key = D.stack[built + 1]
	var/list/cost = rocket_piece_cost(D, key)
	var/list/short = list()
	for (var/material in cost)
		if ((stock[material] || 0) < cost[material])
			short += "[cost[material] - (stock[material] || 0)] more [material]"
	if (short.len)
		to_chat(H, SPAN_WARNING("The next piece needs [english_list(short)]."))
		qdel(D)
		return null
	if (!output_turf())
		to_chat(H, SPAN_WARNING("Clear a floor tile beside \the [src] for the section to come out on."))
		qdel(D)
		return null
	busy = TRUE
	visible_message(SPAN_NOTICE("[H] starts \the [src] on the next section."))
	var/done = H ? do_after(H, ROCKET_WORKS_BUILD_TIME, src) : TRUE
	busy = FALSE
	var/turf/T = output_turf()
	if (QDELETED(src) || !done || !T || order_code != D.to_code() || D.stack[built + 1] != key)
		qdel(D)
		return null
	for (var/material in cost)
		if ((stock[material] || 0) < cost[material])
			qdel(D)
			return null
	for (var/material in cost)
		stock[material] -= cost[material]
	var/list/P = rocket_plan_pieces()[key]
	var/obj/structure/rocket_section/S = new(T, key, P["framed"] ? D.frame : null)
	built++
	visible_message(SPAN_NOTICE("\The [src] rolls out \a [S] ([built]/[D.stack.len])."))
	qdel(D)
	return S

/obj/structure/rocket_works/proc/unload()
	var/list/types = rocket_works_stock_types()
	for (var/key in types)
		var/path = types[key]
		while ((stock[key] || 0) > 0)
			var/obj/item/stack/S = new path(get_turf(src))
			S.amount = min(stock[key], S.max_amount)
			stock[key] -= S.amount
			S.update_icon()

// ---------------------------------------------------------------- launch stand

/obj/structure/rocket_stand
	name = "launch stand"
	desc = "A steel launch mount with hold-down clamps and a flame trench, built beside a launch pad. Give it a rocket sheet and mount the sections on it in order from the bottom; storeys above the first mount from the levels above, so hoist their sections up by crane."
	icon = 'icons/obj/structures.dmi'
	icon_state = "catwalk"
	anchored = TRUE
	density = FALSE
	flammable = FALSE
	not_movable = TRUE
	layer = TURF_LAYER + 0.1
	var/plan_code = ""
	var/tmp/busy = FALSE

/obj/structure/rocket_stand/ex_act(severity)
	return

/obj/structure/rocket_stand/after_load()
	..()
	busy = FALSE

/obj/structure/rocket_stand/proc/plan()
	return plan_code ? rocket_plan_from_code(plan_code) : null

/obj/structure/rocket_stand/proc/rocket()
	return locate(/obj/structure/crewed_lander/modular_rocket) in get_turf(src)

/obj/structure/rocket_stand/proc/find_pad()
	for (var/obj/structure/region_gate/trail_marker/launch_pad/P in range(1, src))
		if (!QDELETED(P))
			return P
	return null

/obj/structure/rocket_stand/proc/mounted()
	var/obj/structure/crewed_lander/modular_rocket/R = rocket()
	return R ? R.sections() : list()

// The storey (1 up) the piece at stack position i is part of. A fitting
// belongs to the storey of the section below it.
/proc/rocket_storey_of(datum/rocket_plan/D, i)
	var/height = 0
	for (var/j = 1, j <= i, j++)
		var/list/P = rocket_plan_pieces()[D.stack[j]]
		if (P && P["height"])
			height++
	return max(1, ceil(height / ROCKET_STOREY_SECTIONS))

// The turf of the column over the stand where storey n mounts: the level
// n - 1 above the stand, or the highest the world has.
/obj/structure/rocket_stand/proc/storey_turf(n)
	var/level = z
	for (var/k = 2, k <= n, k++)
		var/up = multiz_level_above(level)
		if (!up)
			break
		level = up
	return locate(x, y, level)

// Why section S cannot be mounted next by user, or null.
/obj/structure/rocket_stand/proc/mount_refusal(mob/living/human/user, obj/structure/rocket_section/S)
	if (!istype(S))
		return "Only rocket sections mount on \the [src]."
	if (!find_pad())
		return "\The [src] must stand beside a launch pad."
	var/datum/rocket_plan/D = plan()
	if (!D)
		return "Use a rocket sheet on \the [src] first, so it knows what to stack."
	var/list/have = mounted()
	var/i = have.len + 1
	if (i > D.stack.len)
		qdel(D)
		return "The [D.name] is complete."
	var/key = D.stack[i]
	var/list/P = rocket_plan_pieces()[key]
	var/frame = P["framed"] ? D.frame : null
	if (S.piece != key || S.frame != frame)
		var/list/F = frame ? rocket_plan_frames()[frame] : null
		qdel(D)
		return "The [D.name] needs [F ? "a [F["name"]] [P["name"]]" : "a [P["name"]]"] next, not \a [S]."
	var/reason = S.mount_refusal()
	if (reason)
		qdel(D)
		return reason
	var/turf/column = storey_turf(rocket_storey_of(D, i))
	qdel(D)
	if (!column)
		return "There is no room above \the [src] for that storey."
	if (column.z != z)
		if (!(locate(/obj/structure/rocket_storey) in column) && !edge_open_air(column))
			return "The rocket rises through the sky over \the [src]; the tile above it on that level must be open."
	if (S.z != column.z || get_dist(S, column) > 1)
		return column.z == z ? "Bring \the [S] beside \the [src]." : "That section belongs on a higher storey: hoist it to a platform beside the rocket on the level above and mount it from there."
	if (user && (user.z != column.z || get_dist(user, S) > 1 || user.incapacitated()))
		return "Stand beside \the [S] to mount it."
	if (S.anchored || S.pulledby && S.pulledby != user)
		return "Someone else is holding \the [S]."
	return null

/obj/structure/rocket_stand/MouseDrop_T(atom/movable/O, mob/living/human/user)
	mount(user, O)

/obj/structure/rocket_stand/proc/mount(mob/living/human/user, obj/structure/rocket_section/S)
	if (busy || !istype(S))
		return FALSE
	var/reason = mount_refusal(user, S)
	if (reason)
		if (user)
			to_chat(user, SPAN_WARNING(reason))
		return FALSE
	if (user)
		busy = TRUE
		var/done = do_after(user, ROCKET_MOUNT_TIME, S)
		busy = FALSE
		if (!done || QDELETED(src) || QDELETED(S))
			return FALSE
		reason = mount_refusal(user, S)
		if (reason)
			to_chat(user, SPAN_WARNING(reason))
			return FALSE
	return attach(S, user)

// Puts S on the stack (checks done). Returns TRUE.
/obj/structure/rocket_stand/proc/attach(obj/structure/rocket_section/S, mob/user = null)
	var/datum/rocket_plan/D = plan()
	var/obj/structure/crewed_lander/modular_rocket/R = rocket()
	if (!R)
		R = new(get_turf(src))
		R.plan_code = plan_code
	if (S.pulledby)
		S.pulledby.stop_pulling()
	S.forceMove(R)
	var/list/have = R.sections()
	var/turf/column = storey_turf(rocket_storey_of(D, have.len))
	if (column && column.z != z && !(locate(/obj/structure/rocket_storey) in column))
		new /obj/structure/rocket_storey(column)
	R.refresh()
	if (user)
		user.visible_message(SPAN_NOTICE("[user] mounts \the [S] on the rocket ([have.len]/[D.stack.len])."))
	if (have.len >= D.stack.len)
		visible_message(SPAN_NOTICE("The [D.name] stands complete on \the [src]. Load its propellant and check it with the launch planner."))
	qdel(D)
	return TRUE

/obj/structure/rocket_stand/attackby(obj/item/I, mob/living/human/H)
	var/obj/item/ship_draught/sheet = I
	if (istype(sheet) && sheet.rocket_plan_kind())
		take_plan(H, sheet)
		return TRUE
	return ..()

/obj/structure/rocket_stand/proc/take_plan(mob/living/human/H, obj/item/ship_draught/sheet)
	var/datum/rocket_plan/D = sheet.rocket_plan()
	if (!D)
		to_chat(H, SPAN_WARNING("That rocket sheet cannot be read."))
		return FALSE
	var/list/problems = D.problems()
	if (problems.len)
		to_chat(H, SPAN_WARNING("The [D.name] cannot be built as drawn: [problems[1]]"))
		qdel(D)
		return FALSE
	if (mounted().len && D.to_code() != plan_code)
		to_chat(H, SPAN_WARNING("A rocket is already being stacked here. Take it down first."))
		qdel(D)
		return FALSE
	plan_code = D.to_code()
	to_chat(H, SPAN_NOTICE("\The [src] will stack the [D.name]: [D.section_count()] sections in [rocket_storey_of(D, D.stack.len)] storey\s."))
	qdel(D)
	return TRUE

/obj/structure/rocket_stand/attack_hand(mob/living/human/H)
	if (!istype(H) || !Adjacent(H))
		return
	var/datum/rocket_plan/D = plan()
	if (!D)
		to_chat(H, SPAN_NOTICE("Use a rocket sheet on \the [src] to stack that rocket here."))
		return
	var/list/have = mounted()
	var/list/options = list("Launch planner" = "planner")
	if (have.len)
		options["Take down the top section"] = "down"
	var/next = have.len < D.stack.len ? D.stack[have.len + 1] : null
	var/list/P = next ? rocket_plan_pieces()[next] : null
	var/text = "[D.name]: [have.len]/[D.stack.len] pieces mounted.[P ? " Next: [P["name"]], on storey [rocket_storey_of(D, have.len + 1)]." : " It is complete."]"
	var/choice = WWinput(H, text, name, "Cancel", options + list("Cancel"))
	if (QDELETED(src) || !Adjacent(H) || !(choice in options))
		qdel(D)
		return
	switch (options[choice])
		if ("planner")
			var/obj/structure/crewed_lander/modular_rocket/R = rocket()
			to_chat(H, R ? R.planner_text() : D.summary_text())
		if ("down")
			take_down(H)
	qdel(D)

// Takes the top section off and sets it down beside the column on its level.
/obj/structure/rocket_stand/proc/take_down(mob/living/human/H)
	var/obj/structure/crewed_lander/modular_rocket/R = rocket()
	var/datum/rocket_plan/D = plan()
	if (!R || !D)
		qdel(D)
		return null
	var/list/have = R.sections()
	if (!have.len)
		qdel(D)
		return null
	var/obj/structure/rocket_section/S = have[have.len]
	var/turf/column = storey_turf(rocket_storey_of(D, have.len))
	var/turf/drop = null
	for (var/d in cardinal)
		var/turf/T = get_step(column, d)
		if (T && !T.density && ledge_landing_clear(T))
			drop = T
			break
	if (!drop)
		to_chat(H, SPAN_WARNING("There is no clear platform beside the rocket on that level to set the section down on."))
		qdel(D)
		return null
	S.forceMove(drop)
	if (have.len == 1)
		qdel(R)
	else
		var/turf/above = storey_turf(rocket_storey_of(D, have.len - 1))
		if (column.z != z && above != column)
			var/obj/structure/rocket_storey/top = locate() in column
			if (top)
				qdel(top)
		R.refresh()
	to_chat(H, SPAN_NOTICE("You take \the [S] down from the rocket."))
	qdel(D)
	return S

// ---------------------------------------------------------------- the rocket

/obj/structure/crewed_lander/modular_rocket
	name = "rocket"
	desc = "A rocket stacked on its launch stand from a rocket sheet. Load propellant, strap in on its tile and check the launch planner before you launch."
	ascent_propellant = 0
	propellant_needed = 0
	seats = 0
	cargo_max = 0
	fuels = list("rocket_propellant", "methalox")
	var/plan_code = ""

/obj/structure/crewed_lander/modular_rocket/Destroy()
	// Its upper storeys go with it, and its sections leave with it.
	var/obj/structure/rocket_stand/S = locate() in get_turf(src)
	if (S)
		var/turf/T = get_turf(S)
		var/level = T.z
		for (var/k in 1 to ROCKET_PLAN_MAX_SECTIONS)
			level = multiz_level_above(level)
			if (!level)
				break
			var/obj/structure/rocket_storey/top = locate() in locate(T.x, T.y, level)
			if (top)
				qdel(top)
	for (var/obj/structure/rocket_section/R in contents)
		qdel(R)
	return ..()

/obj/structure/crewed_lander/modular_rocket/proc/plan()
	return plan_code ? rocket_plan_from_code(plan_code) : null

/obj/structure/crewed_lander/modular_rocket/proc/sections()
	. = list()
	for (var/obj/structure/rocket_section/S in contents)
		. += S

/obj/structure/crewed_lander/modular_rocket/proc/complete()
	var/datum/rocket_plan/D = plan()
	. = D && sections().len >= D.stack.len
	qdel(D)

// Seats, hold and tank follow what is mounted.
/obj/structure/crewed_lander/modular_rocket/proc/refresh()
	var/datum/rocket_plan/D = plan()
	if (!D)
		return
	name = D.name
	propellant_needed = D.propellant_units()
	var/capsules = 0
	var/bays = 0
	for (var/obj/structure/rocket_section/S in sections())
		if (S.piece == "C")
			capsules++
		if (S.piece == "K")
			bays++
	seats = capsules * 3
	cargo_max = min(LANDER_CARGO_MAX, bays * ROCKET_BAY_ITEMS + capsules * 5)
	qdel(D)

// The hold's mass on the planner, in tonnes.
/obj/structure/crewed_lander/modular_rocket/proc/cargo_tonnes()
	return length(hold()) * ROCKET_ITEM_TONNES

/obj/structure/crewed_lander/modular_rocket/proc/planner_text()
	var/datum/rocket_plan/D = plan()
	if (!D)
		return "This rocket has no sheet."
	var/list/lines = list("<b>[D.name]</b> launch planner, with [length(hold())] item\s in the hold ([cargo_tonnes()] t):")
	lines += D.planner_lines(cargo_tonnes())
	var/list/have = sections()
	if (have.len < D.stack.len)
		lines += "<span class='warning'>[D.stack.len - have.len] piece\s still to mount.</span>"
	for (var/obj/structure/rocket_section/S in have)
		var/reason = S.mount_refusal()
		if (reason)
			lines += "<span class='warning'>[reason]</span>"
	lines += "Propellant: [propellant]/[propellant_needed] units."
	qdel(D)
	return jointext(lines, "<br>")

/obj/structure/crewed_lander/modular_rocket/examine(mob/user)
	..()
	to_chat(user, planner_text())

/obj/structure/crewed_lander/modular_rocket/MouseDrop_T(atom/movable/O, mob/living/human/user)
	var/obj/structure/rocket_stand/S = locate() in get_turf(src)
	if (S)
		S.mount(user, O)

// A rocket flies wherever its legs reach: orbit from 1969, the Moon once
// probes fly (a later phase). The crew orbit only when it can bring them home
// or a station takes them in.
/obj/structure/crewed_lander/modular_rocket/vehicle_refusal(destination)
	var/datum/rocket_plan/D = plan()
	if (!D)
		return "\The [src] has no sheet."
	. = null
	if (!complete())
		. = "\The [src] is not finished: mount every section first."
	else
		for (var/obj/structure/rocket_section/S in sections())
			var/reason = S.mount_refusal()
			if (reason)
				. = reason
				break
	if (!. && !space_flight_orbit_ok(destination))
		. = "\The [src] flies to orbit. Point the pad at an orbit to launch it."
	if (!.)
		var/list/L = D.legs(cargo_tonnes())
		var/list/orbit = L[ROCKET_LEG_ORBIT]
		if (!orbit["ok"])
			. = "The launch planner says it cannot reach orbit with this load: [orbit["why"]]."
	if (!. && !D.count("C"))
		. = "Nobody rides an uncrewed rocket. Its cargo and probe missions fly from a later works."
	if (!.)
		var/list/peer = shard_group && shard_group.peers[destination]
		if (space_flight_orbit_full(destination) && !(islist(peer) && length(peer["docking_ports"])))
			. = "Every plane in [region_trail_name(destination)] is taken and no station has a free docking port. Wait until one is freed."
	qdel(D)

/obj/structure/crewed_lander/modular_rocket/flight_extras(list/flight)
	flight["seats"] = max(1, seats)
	var/list/capsule = capsule_record()
	if (capsule)
		flight["capsule"] = capsule

// The crew are warned before they fly with no way home of their own.
/obj/structure/crewed_lander/modular_rocket/orbit_launch_prompt(mob/living/human/H, obj/structure/region_gate/trail_marker/launch_pad/pad, region)
	var/datum/rocket_plan/D = plan()
	var/home = D && D.supports(ROCKET_LEG_RETURN, cargo_tonnes())
	qdel(D)
	if (!home && WWinput(H, "The launch planner says this rocket cannot bring its crew home: they can only come down from a station. Launch anyway?", "Launch", "Cancel", list("Launch anyway", "Cancel")) != "Launch anyway")
		return
	if (QDELETED(src) || !H.client || !in_range(src, H))
		return
	return ..()

#undef ROCKET_WORKS_STOCK_CAP
#undef ROCKET_WORKS_BUILD_TIME
#undef ROCKET_MOUNT_TIME
#undef ROCKET_ITEM_TONNES
