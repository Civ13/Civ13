// The slipway (docs/slipway.md): ships built piece by piece beside the water,
// like the rail warehouse and platform cars are built on the track. The
// slipway post stands on the shore facing the water; the ship's berth is the
// ground in front of it, stern at the post and bow to the water. The keel is
// laid for one design, then players bring the materials for each piece in
// turn (keel, frames, hull, deck, fittings), and the hull grows on the berth
// from stern to bow. When the last piece is fitted the ship is launched: she
// slides down the ways along the post's facing until she floats on open deep
// water, with everyone standing on her aboard.
//
// The berth may be open ground on the shore, or a dug trench (a dry dock):
// a dry dock must be flooded (opened to the sea) before the launch.
//
// The project lives in the post's saved vars (design, pieces_done, paid). The
// frame objects showing the hull on the berth are rebuilt from them and are
// never saved. The launched ship is an ordinary turf-built vessel (vessel.dm).

#define SLIPWAY_PIECE_TIME 50 // ticks to fit one piece
#define SLIPWAY_RUN 12        // tiles a ship may slide past her own length to float

// ---- Designs ----

// A ship design is a piece plan (piece_projects.dm) with the berth looks.
/datum/slipway_design
	parent_type = /datum/piece_plan
	name = "ship"
	var/vessel_type = null
	// The berth looks: a keel timber, the ribs, and the cradle under bare ground.
	var/keel_icon = 'icons/turf/floors.dmi'
	var/keel_state = "wood_ship1"
	var/rib_icon = 'icons/obj/vehicles/vehicleparts_boats.dmi'
	var/rib_state = "grid"
	// Stage parts: keel/frames/hull/deck/below/fittings.

/datum/slipway_design/schooner
	name = "sailing schooner"
	vessel_type = /datum/vessel/schooner
	node = "wagons_ships"
	blurb = "a two-masted wooden schooner, 14 tiles long and 5 wide, sailing on the wind without fuel"
	stages = list(
		list("name" = "Keel", "pieces" = 2, "cost" = list("wood" = 10), "part" = "keel", "verb" = "keel timber"),
		list("name" = "Frames", "pieces" = 4, "cost" = list("wood" = 10), "part" = "frames", "verb" = "set of ribs"),
		list("name" = "Planking", "pieces" = 4, "cost" = list("wood" = 15), "part" = "hull", "verb" = "strake of planking"),
		list("name" = "Deck", "pieces" = 3, "cost" = list("wood" = 10), "part" = "deck", "verb" = "run of deck planks"),
		list("name" = "Masts and rigging", "pieces" = 2, "cost" = list("wood" = 10, "cloth" = 10, "rope" = 2), "part" = "fittings", "verb" = "mast with its sails"),
		list("name" = "Wheel", "pieces" = 1, "cost" = list("wood" = 10), "part" = "fittings", "verb" = "wheel and rudder"),
	)

/datum/slipway_design/freighter
	name = "motor freighter"
	vessel_type = /datum/vessel/freighter
	node = "combustion"
	blurb = "a steel motor ship, 20 tiles long and 7 wide, with a wheelhouse on deck and a cargo hold and engine room below; she burns diesel or petroleum"
	keel_icon = 'icons/turf/floors.dmi'
	keel_state = "steel_grid"
	rib_icon = 'icons/turf/floors.dmi'
	rib_state = "catwalk_plated"
	stages = list(
		list("name" = "Keel", "pieces" = 2, "cost" = list("steel" = 10), "part" = "keel", "verb" = "keel section"),
		list("name" = "Frames", "pieces" = 4, "cost" = list("steel" = 10), "part" = "frames", "verb" = "set of frames"),
		list("name" = "Hull plating", "pieces" = 6, "cost" = list("steel" = 12), "part" = "hull", "verb" = "run of hull plates"),
		list("name" = "Hold and bulkheads", "pieces" = 2, "cost" = list("steel" = 10), "part" = "below", "verb" = "bulkhead"),
		list("name" = "Deck", "pieces" = 4, "cost" = list("steel" = 8), "part" = "deck", "verb" = "run of deck plating"),
		list("name" = "Engine", "pieces" = 1, "cost" = list("steel" = 20, "cable" = 20), "part" = "below", "verb" = "engine"),
		list("name" = "Wheelhouse and fittings", "pieces" = 1, "cost" = list("steel" = 10, "glass" = 10), "part" = "fittings", "verb" = "wheelhouse fit-out"),
	)

var/global/list/slipway_designs = null

/proc/slipway_design_list()
	if (!slipway_designs)
		slipway_designs = list()
		for (var/path in list(/datum/slipway_design/schooner, /datum/slipway_design/freighter))
			var/datum/slipway_design/D = new path
			slipway_designs[D.name] = D
	return slipway_designs

// ---- The post ----

/obj/structure/slipway
	name = "slipway"
	desc = "The head of a slipway, where the shipwright's plans are pinned. Build it on the shore facing the water; the ground in front of it is the berth where a ship is built, stern to the post and bow to the water. Lay a keel here, bring the materials for each piece, and launch her down the ways when she is finished."
	icon = 'icons/obj/structures.dmi'
	icon_state = "nboard00"
	anchored = TRUE
	density = TRUE
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	var/design = null        // name of the /datum/slipway_design being built
	var/pieces_done = 0
	var/list/paid = list()   // material -> amount paid towards the next piece
	var/tmp/busy = FALSE
	var/tmp/list/frames = list()

/obj/structure/slipway/persistence_runtime_var(key)
	return (key in list("busy", "frames")) || ..(key)

/obj/structure/slipway/after_load()
	..()
	busy = FALSE
	update_frames()

/obj/structure/slipway/Destroy()
	clear_frames()
	return ..()

/obj/structure/slipway/proc/get_design()
	return design ? slipway_design_list()[design] : null

// A fresh unplaced vessel of the design, for geometry and fit checks.
/obj/structure/slipway/proc/prototype(datum/slipway_design/D)
	if (!D || !D.vessel_type)
		return null
	var/path = D.vessel_type
	return new path

/obj/structure/slipway/proc/base_level(datum/vessel/V)
	for (var/datum/vessel_level/L in V.levels)
		if (!L.dz)
			return L
	return null

// The box corner of the ship slid k tiles along the ways: list(x, y).
/obj/structure/slipway/proc/corner(datum/vessel/V, k = 0)
	var/turf/front = get_step(src, dir)
	if (!front)
		return null
	var/mid = round((V.beam - 1) / 2)
	var/dx = 0
	var/dy = 0
	switch (dir)
		if (EAST) dx = 1
		if (WEST) dx = -1
		if (NORTH) dy = 1
		if (SOUTH) dy = -1
	return list(front.x - V.cell_dx(0, mid, dir) + dx * k, front.y - V.cell_dy(0, mid, dir) + dy * k)

// The surface cells of the ship slid k tiles along the ways: turf -> list(u, v).
// Null when any cell is off the map.
/obj/structure/slipway/proc/berth_cells(datum/vessel/V, k = 0)
	var/list/C = corner(V, k)
	var/datum/vessel_level/L = base_level(V)
	if (!C || !L)
		return null
	. = list()
	for (var/v = 0, v < V.beam, v++)
		for (var/u = 0, u < V.length, u++)
			if (!L.spec_at(u, v))
				continue
			var/turf/T = locate(C[1] + V.cell_dx(u, v, dir), C[2] + V.cell_dy(u, v, dir), z)
			if (!T)
				return null
			.[T] = list(u, v)

// Whether a berth tile is ground a hull can be built on.
/proc/slipway_ground(turf/T)
	return istype(T, /turf/floor) && !T.density

// The first slide (0 for a ship built afloat) at which V floats, or -1.
/obj/structure/slipway/proc/launch_offset(datum/vessel/V)
	var/list/C
	for (var/k = 0, k <= V.length + SLIPWAY_RUN, k++)
		C = corner(V, k)
		if (C && V.fits(C[1], C[2], z, dir))
			return k
	return -1

// Why a keel of design D could not be laid here, or null.
/obj/structure/slipway/proc/keel_refusal(datum/slipway_design/D, mob/living/human/H)
	if (!isturf(loc))
		return "The slipway must stand on the ground."
	if (design)
		return "A [design] is already on the berth."
	if (H && (!map || !research_node_known(H, D.node)))
		var/datum/research_node/N = get_research_node(D.node)
		return "The [D.name] needs [N ? N.name : D.node] research."
	var/datum/vessel/V = prototype(D)
	. = berth_problem(V)
	if (!.)
		if (launch_offset(V) < 0)
			. = "There is no open deep water for a [D.name] [V.length] tiles long and [V.beam] wide within [V.length + SLIPWAY_RUN] tiles [dir2text(dir)] of the slipway[V.last_refusal ? " ([V.last_refusal])" : ""]. Face the slipway to the water with a wrench."
	qdel(V)

// Why the berth in front of the post cannot carry V's hull, or null.
/obj/structure/slipway/proc/berth_problem(datum/vessel/V)
	var/list/cells = berth_cells(V)
	if (!cells)
		return "The berth runs off the edge of the world."
	for (var/turf/T in cells)
		if (!slipway_ground(T))
			return "The berth must be open ground, trench or water: [T.name] at [T.x],[T.y] is in the way."
		if (vessel_at(T))
			return "A ship lies on the berth."
		for (var/atom/movable/M in T)
			if (M.loc != T || !M.simulated || isliving(M))
				continue
			if (istype(M, /obj/structure/slipway_frame))
				return "Another ship is being built across this berth."
			if (M.density)
				return "\The [M] is in the way on the berth at [T.x],[T.y]."
	return null

// ---- Progress ----

// list(stage index, piece index within it), both from 1, for the next piece;
// null when the ship is finished.
/obj/structure/slipway/proc/next_piece()
	var/datum/slipway_design/D = get_design()
	return D ? D.next_piece(pieces_done) : null

/obj/structure/slipway/proc/finished()
	return design && !next_piece()

// What the next piece still needs: material -> amount.
/obj/structure/slipway/proc/still_needed()
	var/datum/slipway_design/D = get_design()
	return D ? D.still_needed(pieces_done, paid) : list()

// How many pieces of each stage are fitted: stage index -> count.
/obj/structure/slipway/proc/stage_progress()
	var/datum/slipway_design/D = get_design()
	return D ? D.stage_progress(pieces_done) : list()

/obj/structure/slipway/proc/status_text()
	var/datum/slipway_design/D = get_design()
	if (!D)
		return "The berth is empty."
	if (!next_piece())
		return "The [D.name] is finished ([D.total_pieces()] pieces) and ready to launch."
	return D.progress_text(pieces_done, paid)

/obj/structure/slipway/examine(mob/user, distance)
	..()
	to_chat(user, status_text())

// Pays what the held stack can towards the next piece and fits it when it is
// paid for. Returns the amount taken.
/obj/structure/slipway/proc/pay(obj/item/stack/S)
	var/datum/slipway_design/D = get_design()
	if (!D)
		return 0
	var/list/result = piece_pay(D, pieces_done, paid, S)
	if (result[2])
		pieces_done++
		paid = list()
		update_frames()
	return result[1]

// A player brings materials to the berth (the post or any part of the hull).
/obj/structure/slipway/proc/add_piece(mob/living/human/H, obj/item/I, atom/target)
	if (busy || !istype(H) || !istype(I, /obj/item/stack))
		return FALSE
	var/datum/slipway_design/D = get_design()
	if (!D)
		to_chat(H, SPAN_WARNING("No keel has been laid here. Use the slipway post to lay one."))
		return TRUE
	var/list/next = next_piece()
	if (!next)
		to_chat(H, SPAN_NOTICE("The [D.name] is finished. Launch her from the slipway post."))
		return TRUE
	var/key = piece_material(I)
	var/list/needed = still_needed()
	if (!key || !needed[key])
		to_chat(H, SPAN_WARNING("The next piece needs [piece_cost_text(needed)], not [I.name]."))
		return TRUE
	var/list/stage = D.stages[next[1]]
	busy = TRUE
	to_chat(H, SPAN_NOTICE("You start work on the [stage["verb"]]..."))
	if (!do_after(H, SLIPWAY_PIECE_TIME, target || src) || QDELETED(src) || QDELETED(I) || design != D.name || pieces_done != next_index_of(next))
		busy = FALSE
		return TRUE
	var/before = pieces_done
	var/took = pay(I)
	busy = FALSE
	if (!took)
		return TRUE
	if (pieces_done > before)
		log_game("[key_name(H)] fitted [stage["verb"]] [next[2]]/[stage["pieces"]] of a [D.name] at [x],[y],[z].")
		H.visible_message(SPAN_NOTICE("[H] fits the [stage["verb"]] on the [D.name]."), SPAN_NOTICE("You fit the [stage["verb"]]. [status_text()]"))
	else
		to_chat(H, SPAN_NOTICE("You set out [took] [key] for the [stage["verb"]]; it still needs [piece_cost_text(still_needed())]."))
	return TRUE

// pieces_done as it stood when next was read.
/obj/structure/slipway/proc/next_index_of(list/next)
	var/datum/slipway_design/D = get_design()
	return D.index_of(next)

/obj/structure/slipway/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/wrench) && !busy && !design)
		set_dir(turn(dir, -90))
		playsound(loc, 'sound/items/Ratchet.ogg', 50, TRUE)
		to_chat(user, "You turn \the [src] to face [dir2text(dir)]: the berth now runs [dir2text(dir)] from it.")
		return
	if (istype(W, /obj/item/stack) && design)
		add_piece(user, W)
		return
	return ..()

/obj/structure/slipway/attack_hand(mob/living/human/H)
	if (busy || !istype(H) || !Adjacent(H))
		return
	var/datum/slipway_design/D = get_design()
	var/list/options = list()
	if (!D)
		for (var/name in slipway_design_list())
			var/datum/slipway_design/S = slipway_design_list()[name]
			options["Lay the keel of a [S.name]"] = S
	else
		if (finished())
			options["Launch the [D.name]"] = "launch"
		options["Abandon the [D.name]"] = "abandon"
	var/text = status_text()
	if (!D)
		var/list/lines = list(text, "The berth runs [dir2text(dir)] from the post; turn it with a wrench before a keel is laid.")
		for (var/name in slipway_design_list())
			var/datum/slipway_design/S = slipway_design_list()[name]
			lines += "A [S.name] is [S.blurb]. She takes [S.total_pieces()] pieces: [piece_cost_text(S.total_cost())] in all."
		text = jointext(lines, " ")
	var/choice = WWinput(H, text, name, "Cancel", options + list("Cancel"))
	if (!(choice in options) || busy || !Adjacent(H))
		return
	var/action = options[choice]
	if (istype(action, /datum/slipway_design))
		var/datum/slipway_design/S = action
		var/refusal = keel_refusal(S, H)
		if (refusal)
			to_chat(H, SPAN_WARNING(refusal))
			return
		lay_keel(S)
		log_game("[key_name(H)] laid the keel of a [S.name] at [x],[y],[z].")
		to_chat(H, SPAN_NOTICE("The berth is marked out for a [S.name]. [status_text()] Bring the materials to the post or to any part of the hull."))
	else if (action == "launch")
		var/name_was = D.name
		var/result = launch()
		if (istype(result, /datum/vessel))
			log_game("[key_name(H)] launched a [name_was] from [src] at [x],[y],[z].")
			to_chat(H, SPAN_NOTICE("You knock away the chocks."))
		else
			to_chat(H, SPAN_WARNING(result))
	else if (action == "abandon")
		if (WWinput(H, "Break up the [D.name]? Everything fitted so far is lost.", name, "No", list("Yes", "No")) != "Yes" || busy || !Adjacent(H))
			return
		log_game("[key_name(H)] abandoned a [D.name] ([pieces_done] pieces) at [x],[y],[z].")
		abandon()
		to_chat(H, SPAN_NOTICE("The berth is cleared."))

/obj/structure/slipway/proc/lay_keel(datum/slipway_design/D)
	design = D.name
	pieces_done = 0
	paid = list()
	update_frames()

/obj/structure/slipway/proc/abandon()
	design = null
	pieces_done = 0
	paid = list()
	clear_frames()

// ---- Launch ----

// Why the finished ship cannot be launched yet, or null. Fills place with
// list(vessel, k) when she can.
/obj/structure/slipway/proc/launch_problem(list/place)
	var/datum/slipway_design/D = get_design()
	if (!D)
		return "No ship is being built here."
	if (!finished())
		return "The [D.name] is not finished: [status_text()]"
	var/datum/vessel/V = prototype(D)
	var/list/berth = berth_cells(V)
	if (!berth)
		qdel(V)
		return "The berth runs off the edge of the world."
	for (var/turf/T in berth)
		if (istype(T, /turf/floor/trench) && !istype(T, /turf/floor/trench/flooded))
			qdel(V)
			return "The dry dock is not flooded: open it to the water first."
	var/k = launch_offset(V)
	if (k < 0)
		var/why = V.last_refusal
		qdel(V)
		return "There is no open deep water for her within [SLIPWAY_RUN] tiles past the berth, [dir2text(dir)] of the slipway[why ? " ([why])" : ""]."
	// The ways: every tile she slides over on the way must be clear.
	for (var/step = 1, step < k, step++)
		var/list/cells = berth_cells(V, step)
		for (var/turf/T in cells)
			if (T in berth)
				continue
			if (T.density || (istype(T, /turf/floor/trench) && !istype(T, /turf/floor/trench/flooded)))
				qdel(V)
				return "[capitalize(T.name)] at [T.x],[T.y] is in the way down the ways."
			for (var/atom/movable/M in T)
				if (M.loc == T && M.simulated && M.density)
					qdel(V)
					return "\The [M] at [T.x],[T.y] is in the way down the ways."
	place += V
	place += k
	return null

// Launches the finished ship. Returns the vessel, or the reason she stayed.
/obj/structure/slipway/proc/launch()
	var/list/place = list()
	var/problem = launch_problem(place)
	if (problem)
		return problem
	var/datum/vessel/V = place[1]
	var/k = place[2]
	var/list/berth = berth_cells(V)
	// Everyone and everything loose on the hull goes with her.
	var/list/riders = list()
	for (var/turf/T in berth)
		for (var/atom/movable/M in T)
			if (M.loc != T || QDELETED(M) || !M.simulated)
				continue
			if (istype(M, /obj/structure/slipway_frame))
				continue
			if (isobj(M))
				var/obj/O = M
				if (O.anchored)
					continue
			riders[M] = berth[T]
	clear_frames()
	var/list/C = corner(V, k)
	if (!V.place(C[1], C[2], z, dir))
		var/why = V.last_refusal
		qdel(V)
		update_frames()
		return "The launch failed: [why]."
	V.anchored = TRUE
	V.speed = VESSEL_SPEED_STOP
	for (var/atom/movable/M in riders)
		var/list/cell = riders[M]
		var/turf/D = V.cell_turf(base_level(V), cell[1], cell[2], V.ox, V.oy, V.dir)
		if (D && !QDELETED(M))
			M.forceMove(D)
	var/datum/vessel_level/L = base_level(V)
	var/turf/stern = V.cell_turf(L, 0, round((V.beam - 1) / 2), V.ox, V.oy, V.dir)
	if (stern)
		stern.visible_message(SPAN_NOTICE("The [V.name] slides down the ways and into the water with a great splash!"))
	design = null
	pieces_done = 0
	paid = list()
	return V

// ---- The hull on the berth ----

// One tile of the ship being built. It shows the cradle, keel, ribs or the
// finished hull and deck of its cell, and takes materials like the post.
/obj/structure/slipway_frame
	name = "ship under construction"
	desc = "Part of a ship being built on a slipway. Bring the materials for the next piece here or to the slipway post."
	icon = 'icons/obj/vehicles/vehicleparts_boats.dmi'
	icon_state = "grid"
	anchored = TRUE
	density = FALSE
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	layer = TURF_LAYER + 0.1
	should_save = FALSE
	var/tmp/obj/structure/slipway/slipway

/obj/structure/slipway_frame/Destroy()
	if (slipway)
		slipway.frames -= src
		slipway = null
	return ..()

/obj/structure/slipway_frame/examine(mob/user, distance)
	..()
	if (slipway)
		to_chat(user, slipway.status_text())

/obj/structure/slipway_frame/attackby(obj/item/W as obj, mob/user as mob)
	if (slipway && istype(W, /obj/item/stack))
		slipway.add_piece(user, W, src)
		return
	return ..()

/obj/structure/slipway/proc/clear_frames()
	for (var/obj/structure/slipway_frame/F in frames.Copy())
		F.slipway = null
		qdel(F)
	frames = list()

// Whether cell (u, v) of level L lies on the outside of the hull.
/proc/slipway_edge_cell(datum/vessel_level/L, u, v)
	return !L.spec_at(u - 1, v) || !L.spec_at(u + 1, v) || !L.spec_at(u, v - 1) || !L.spec_at(u, v + 1)

// Lays out the frames for the project as it stands. Each stage covers its
// cells from stern to bow, a share per piece fitted.
/obj/structure/slipway/proc/update_frames()
	clear_frames()
	var/datum/slipway_design/D = get_design()
	if (!D || !isturf(loc))
		return
	var/datum/vessel/V = prototype(D)
	var/datum/vessel_level/L = base_level(V)
	var/list/cells = berth_cells(V)
	if (!cells || !L)
		qdel(V)
		return
	// How far towards the bow each part has reached (u below this is done).
	var/list/reach = list("keel" = 0, "frames" = 0, "hull" = 0, "deck" = 0, "fittings" = 0)
	var/list/done = stage_progress()
	var/list/fit_stages = list()
	for (var/i in 1 to D.stages.len)
		var/list/stage = D.stages[i]
		if (stage["part"] == "fittings")
			fit_stages += i
	for (var/i in 1 to D.stages.len)
		var/list/stage = D.stages[i]
		var/part = stage["part"]
		if (!(part in reach) || part == "fittings")
			continue
		reach[part] = max(reach[part], CEILING(V.length * done["[i]"] / stage["pieces"], 1))
	// Fittings: each fittings stage fits its share of the fitting cells, stern first.
	var/list/fitted = list()
	var/list/fit_cells = list()
	for (var/turf/T in cells)
		var/list/uv = cells[T]
		var/list/spec = L.spec_at(uv[1], uv[2])
		if (spec["spawn"])
			fit_cells += list(uv)
	if (fit_stages.len && fit_cells.len)
		// Split the fitting cells between the stages in template order.
		var/list/order = list()
		for (var/u = 0, u < V.length, u++)
			for (var/list/uv in fit_cells)
				if (uv[1] == u)
					order += list(uv)
		var/list/shares = piece_split(order, fit_stages.len)
		for (var/n in 1 to fit_stages.len)
			var/list/stage = D.stages[fit_stages[n]]
			var/list/share = shares[n]
			var/count = CEILING(share.len * done["[fit_stages[n]]"] / stage["pieces"], 1)
			for (var/j in 1 to min(count, share.len))
				var/list/uv = share[j]
				fitted["[uv[1]],[uv[2]]"] = TRUE
	var/mid = round((V.beam - 1) / 2)
	for (var/turf/T in cells)
		var/list/uv = cells[T]
		var/u = uv[1]
		var/v = uv[2]
		var/list/spec = L.spec_at(u, v)
		var/obj/structure/slipway_frame/F = new(T)
		F.slipway = src
		F.dir = dir
		frames += F
		var/edge = slipway_edge_cell(L, u, v)
		var/built = edge ? u < reach["hull"] : u < reach["deck"]
		if (built)
			var/turf/path = spec["turf"]
			F.icon = initial(path.icon)
			F.icon_state = initial(path.icon_state)
			F.name = D.name
		else if (u < reach["frames"])
			F.icon = D.rib_icon
			F.icon_state = D.rib_state
			F.name = "frames of a [D.name]"
		else if (v == mid && u < reach["keel"])
			F.icon = D.keel_icon
			F.icon_state = D.keel_state
			F.name = "keel of a [D.name]"
		else
			F.icon = 'icons/obj/vehicles/vehicleparts_boats.dmi'
			F.icon_state = "grid"
			F.alpha = 110
			F.name = "slipway cradle"
		if (fitted["[u],[v]"])
			for (var/path in spec["spawn"])
				var/obj/O = path
				F.overlays += image(icon = initial(O.icon), icon_state = initial(O.icon_state))
	qdel(V)

// ---- The ships ----

/turf/floor/schooner_deck
	name = "schooner deck"
	desc = "The planked deck of a sailing schooner."
	icon = 'icons/turf/floors.dmi'
	icon_state = "wood_ship"
	stepsound = "wood"

/turf/floor/plating/carrier_deck/freighter
	name = "freighter deck"
	desc = "The steel deck plating of a motor freighter."
	runway = FALSE

/turf/wall/sub_hull/freighter
	name = "wheelhouse wall"
	desc = "The riveted steel wall of the freighter's wheelhouse."

/turf/wall/sub_hull/freighter/hold
	name = "freighter hull"
	desc = "The riveted steel hull of a motor freighter, below the waterline."

/turf/wall/sub_bulkhead/freighter
	name = "freighter bulkhead"

/turf/floor/sub_deck/freighter
	name = "cargo hold floor"
	compartment_id = FREIGHTER_COMP_HOLD

/turf/floor/sub_deck/freighter/engine_room
	name = "engine room floor"
	compartment_id = FREIGHTER_COMP_ENGINE_ROOM

// A ship's mast with its sails furled on the yards.
/obj/structure/vessel_mast
	name = "mast"
	desc = "A tall wooden mast with its sails and rigging."
	icon = 'icons/turf/walls.dmi'
	icon_state = "wood_mast"
	anchored = TRUE
	density = TRUE
	not_movable = TRUE
	not_disassemblable = TRUE
	crushable = FALSE

// The schooner: one wooden deck on the surface, two masts on the centreline
// and the wheel at the stern. She sails on the wind and never needs fuel,
// but makes no more than half ahead.
/datum/vessel/schooner
	name = "sailing schooner"
	length = 14
	beam = 5
	top_speed = VESSEL_SPEED_HALF
	max_speed = VESSEL_SPEED_HALF
	fuel_capacity = 0

/datum/vessel/schooner/New()
	..()
	var/datum/vessel_level/L = new
	L.dz = 0
	L.allowed = list(/turf/floor/beach/water/deep)
	L.rows = list(
		".DDDDDDDDDDD..",
		"DDDDDDDDDDDDD.",
		"DWDDMDDDDMDDDD",
		"DDDDDDDDDDDDD.",
		".DDDDDDDDDDD..",
	)
	L.legend = list(
		"D" = list("turf" = /turf/floor/schooner_deck),
		"W" = list("turf" = /turf/floor/schooner_deck, "spawn" = list(/obj/structure/vessel_helm)),
		"M" = list("turf" = /turf/floor/schooner_deck, "spawn" = list(/obj/structure/vessel_mast)),
	)
	levels += L

/datum/vessel/schooner/fuel_burn(at_speed)
	return 0

// The freighter: a steel deck with the wheelhouse at the stern and a ladder
// down to the cargo hold; below the waterline the hold and, aft of a
// bulkhead with a blast door, the engine room with the bunker filling point.
/datum/vessel/freighter
	name = "motor freighter"
	length = 20
	beam = 7
	fuel_capacity = 400

/datum/vessel/freighter/New()
	..()
	var/datum/vessel_level/hold = new
	hold.dz = -1
	hold.allowed = list(/turf/wall/rockwall, /turf/floor/beach/water/deep)
	hold.rows = list(
		".HHHHHHHHHHHHHHHHH..",
		"HHeeeeBhhhhhhhhhhhH.",
		"HeeTeeBhhhhhhhhhhhhH",
		"Heeeee1LhhhhhhhhhhhH",
		"HeeeeeBhhhhhhhhhhhhH",
		"HHeeeeBhhhhhhhhhhhH.",
		".HHHHHHHHHHHHHHHHH..",
	)
	hold.legend = list(
		"H" = list("turf" = /turf/wall/sub_hull/freighter/hold),
		"B" = list("turf" = /turf/wall/sub_bulkhead/freighter),
		"e" = list("turf" = /turf/floor/sub_deck/freighter/engine_room),
		"h" = list("turf" = /turf/floor/sub_deck/freighter),
		"1" = list("turf" = /turf/floor/sub_deck/freighter/engine_room, "spawn" = list(/obj/structure/simple_door/blast)),
		"L" = list("turf" = /turf/floor/sub_deck/freighter, "spawn" = list(/obj/structure/multiz/ladder/up)),
		"T" = list("turf" = /turf/floor/sub_deck/freighter/engine_room, "spawn" = list(/obj/structure/vessel_bunker)),
	)
	levels += hold
	var/datum/vessel_level/deck = new
	deck.dz = 0
	deck.allowed = list(/turf/floor/beach/water/deep)
	deck.rows = list(
		".DDDDDDDDDDDDDDDDD..",
		"DDDDDDDDDDDDDDDDDDD.",
		"DHHHHDDDDDDDDDDDDDDD",
		"DHWfODDLDDDDDDDDDDDD",
		"DHHHHDDDDDDDDDDDDDDD",
		"DDDDDDDDDDDDDDDDDDD.",
		".DDDDDDDDDDDDDDDDD..",
	)
	deck.legend = list(
		"D" = list("turf" = /turf/floor/plating/carrier_deck/freighter),
		"H" = list("turf" = /turf/wall/sub_hull/freighter),
		"f" = list("turf" = /turf/floor/plating/carrier_deck/freighter),
		"W" = list("turf" = /turf/floor/plating/carrier_deck/freighter, "spawn" = list(/obj/structure/vessel_helm)),
		"O" = list("turf" = /turf/floor/plating/carrier_deck/freighter, "spawn" = list(/obj/structure/simple_door/key_door/anyone/ship)),
		"L" = list("turf" = /turf/floor/plating/carrier_deck/freighter, "spawn" = list(/obj/structure/multiz/ladder)),
	)
	levels += deck

/datum/vessel/freighter/sink_threshold()
	return 2

// Ladders spawned at runtime pair up after every move, as on the carrier.
/datum/vessel/freighter/relocate(x, y, heading)
	. = ..()
	if (.)
		for (var/turf/T in cells())
			for (var/obj/structure/multiz/M in T)
				M.crushable = FALSE
				M.find_target()

#undef SLIPWAY_PIECE_TIME
#undef SLIPWAY_RUN
