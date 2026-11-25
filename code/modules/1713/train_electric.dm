// Electric traction (docs/trains.md#electric-traction). An electric engine
// carries no fuel: it takes its power from a wire hung over the track, and the
// wire takes it from the same grid that lights a town (machinery/cables.dm).
//
// - Overhead line masts stand two tiles from the rails with an arm over the
//   track. Each carries the wire four tiles either way along the line, so a
//   mast every nine tiles makes an unbroken line. Masts whose wires meet form
//   one line; it is live when a power point in reach of any of its masts
//   feeds that mast from a grid with power to spare.
// - Every engine under the line draws from the grid through it, by its
//   throttle. A grid that cannot carry one more engine refuses that engine
//   and keeps the ones it already has.
// - Off the end of the wire, or under a dead one, an electric train coasts.
// - The electric locomotive has a cab at each end and works in multiple; the
//   tram is a four-section car that carries its passengers itself.

#define CATENARY_REACH 4 // tiles of wire a mast carries either way along the track
#define CATENARY_IDLE 1 // kW a feeding mast draws with nothing running
#define CATENARY_STALE 300 // deciseconds an engine's demand stands without being asked again
#define CATENARY_SHOCK 40

// Every mast that is secured, and a serial that changes with that list.
var/global/list/train_catenary = list()
var/global/train_catenary_serial = 0

/////////////////////////////////////////////////////////////////////////////
// The line

/datum/catenary_net
	var/serial = 0
	var/list/masts = list()
	var/list/drawing = list() // engine -> kW it has asked for
	var/list/drawn_at = list() // engine -> when it last asked
	var/live = FALSE

/datum/catenary_net/proc/feeders()
	. = list()
	for (var/obj/structure/train_catenary/M in masts)
		if (!QDELETED(M) && M.anchored && M.powersource)
			. += M

/datum/catenary_net/proc/demand()
	. = 0
	for (var/E in drawing.Copy())
		var/obj/structure/trains/locomotive/L = E
		if (QDELETED(L) || world.time - drawn_at[E] > CATENARY_STALE)
			drawing -= E
			drawn_at -= E
			continue
		. += drawing[E]

// Puts the whole demand on the first feeder whose grid can carry it; the
// others stand by on their idle draw. Returns whether the line is live.
/datum/catenary_net/proc/energise()
	var/total = demand()
	live = FALSE
	for (var/obj/structure/train_catenary/M in feeders())
		if (!live)
			M.powerneeded = CATENARY_IDLE + total
			if (M.draw_cable_power())
				live = TRUE
				continue
		M.powerneeded = CATENARY_IDLE
		M.draw_cable_power()
	return live

// An engine asks for kw. A line that cannot carry it refuses this engine and
// keeps what the others draw.
/datum/catenary_net/proc/request(obj/structure/trains/locomotive/L, kw)
	drawing[L] = kw
	drawn_at[L] = world.time
	if (energise())
		return TRUE
	drawing -= L
	drawn_at -= L
	energise()
	return FALSE

/datum/catenary_net/proc/release(obj/structure/trains/locomotive/L)
	if (!(L in drawing))
		return
	drawing -= L
	drawn_at -= L
	energise()

/////////////////////////////////////////////////////////////////////////////
// Masts

/obj/structure/train_catenary
	name = "overhead line mast"
	desc = "A steel mast with an arm that hangs a contact wire over a railway track. Stand it two tiles from the rails and secure it with a wrench; a mast every nine tiles along the track makes an unbroken line."
	icon = 'icons/obj/vehicles/train_platforms.dmi'
	icon_state = "catenary_mast"
	anchored = FALSE
	density = TRUE
	layer = 4.1
	not_movable = FALSE
	not_disassemblable = FALSE
	flammable = FALSE
	var/tmp/datum/catenary_net/net = null
	var/tmp/list/wire_images = null

/obj/structure/train_catenary/Destroy()
	take_down()
	return ..()

/obj/structure/train_catenary/after_load()
	..()
	if (anchored && isturf(loc))
		powerneeded = CATENARY_IDLE
		train_catenary |= src
		train_catenary_serial++
		// A power point restored before this mast has already looked for it.
		if (!powersource)
			seek_power_point()
	draw_wire()

/obj/structure/train_catenary/persistence_runtime_var(key)
	return (key in list("net", "wire_images")) || ..()

// The tile under the wire: two out along the arm.
/obj/structure/train_catenary/proc/wire_turf()
	var/turf/T = get_step(src, dir)
	return T ? get_step(T, dir) : null

// TRUE when this mast's wire hangs over T.
/obj/structure/train_catenary/proc/covers(turf/T)
	var/turf/C = wire_turf()
	if (!anchored || !C || !T || T.z != C.z)
		return FALSE
	var/upright = (dir == NORTH || dir == SOUTH) // the arm runs north-south, the wire east-west
	var/along = upright ? abs(T.x - C.x) : abs(T.y - C.y)
	var/across = upright ? abs(T.y - C.y) : abs(T.x - C.x)
	return along <= CATENARY_REACH && across <= 1

// The mast whose wire hangs over T, or null.
/proc/train_catenary_over(turf/T)
	if (!T)
		return null
	for (var/obj/structure/train_catenary/M in train_catenary)
		if (M.covers(T))
			return M
	return null

// Physical wire continuity uses the drawn centerlines, not the deliberately
// wider collector pickup area. Collinear wires on neighboring tiles meet.
/proc/catenary_spans_join(turf/C, c_dir, turf/D, d_dir)
	if (!C || !D || C.z != D.z || !(c_dir in cardinal) || !(d_dir in cardinal))
		return FALSE
	var/c_horizontal = c_dir == NORTH || c_dir == SOUTH
	var/d_horizontal = d_dir == NORTH || d_dir == SOUTH
	var/dx = abs(C.x - D.x)
	var/dy = abs(C.y - D.y)
	if (c_horizontal == d_horizontal)
		return c_horizontal ? !dy && dx <= CATENARY_REACH * 2 + 1 : !dx && dy <= CATENARY_REACH * 2 + 1
	// A crossing connects only if both wires actually reach its tile.
	return dx <= CATENARY_REACH && dy <= CATENARY_REACH

// The line this mast is part of: every mast whose wire meets the wire of
// another in it. Rebuilt when a mast goes up or comes down.
/obj/structure/train_catenary/proc/network()
	if (!anchored || !isturf(loc))
		return null
	if (net && net.serial == train_catenary_serial)
		return net
	var/datum/catenary_net/N = new
	N.serial = train_catenary_serial
	var/list/pending = list(src)
	N.masts[src] = TRUE
	while (pending.len)
		var/obj/structure/train_catenary/M = pending[pending.len]
		pending.len--
		var/turf/C = M.wire_turf()
		for (var/obj/structure/train_catenary/O in train_catenary)
			if (N.masts[O] || QDELETED(O) || !O.anchored)
				continue
			var/turf/D = O.wire_turf()
			if (catenary_spans_join(C, M.dir, D, O.dir))
				N.masts[O] = TRUE
				pending += O
	for (var/obj/structure/train_catenary/M in N.masts)
		M.net = N
		M.powerneeded = CATENARY_IDLE
	return N

// The way to the track a mast here would serve, or 0: rails two tiles off,
// square to the mast, and none on the tile between.
/obj/structure/train_catenary/proc/track_way()
	for (var/d in list(dir, NORTH, SOUTH, EAST, WEST))
		var/turf/near = get_step(src, d)
		var/turf/far = near ? get_step(near, d) : null
		if (!far || near.density || (locate(/obj/structure/rails) in near))
			continue
		if (locate(/obj/structure/rails) in far)
			return d
	return 0

/obj/structure/train_catenary/proc/put_up(mob/user)
	var/way = track_way()
	if (!way)
		if (user)
			to_chat(user, SPAN_WARNING("Stand \the [src] two tiles from the rails, square to the track, with the tile between clear of track."))
		return FALSE
	dir = way
	anchored = TRUE
	powerneeded = CATENARY_IDLE
	train_catenary |= src
	train_catenary_serial++
	power_point_moved()
	draw_wire()
	return TRUE

/obj/structure/train_catenary/proc/take_down()
	var/datum/catenary_net/N = net
	net = null
	train_catenary -= src
	train_catenary_serial++
	if (power_point)
		var/obj/structure/power_point/P = power_point
		if (istype(P))
			P.release(src)
		power_point = null
	if (powersource)
		powersource.connections -= src
		powersource.update_power(0, 1, src)
		powersource = null
	powerneeded = 0
	anchored = FALSE
	if (N)
		N.masts -= src
	draw_wire()

// The arm over the side of the track, the hanger over the rails and the wire
// along them, drawn above the roofs of the cars.
/obj/structure/train_catenary/proc/draw_wire()
	if (wire_images)
		overlays -= wire_images
	wire_images = null
	if (!anchored || !isturf(loc))
		return
	var/list/drawn = list()
	var/ox = (dir == EAST) - (dir == WEST)
	var/oy = (dir == NORTH) - (dir == SOUTH)
	var/tile = world.icon_size
	for (var/i in 1 to 2)
		var/image/A = image(icon, (i == 1) ? "catenary_arm" : "catenary_hanger", layer = 8.2, dir = dir)
		A.pixel_x = ox * tile * i
		A.pixel_y = oy * tile * i
		drawn += A
	for (var/k in -CATENARY_REACH to CATENARY_REACH)
		var/image/W = image(icon, "catenary_wire", layer = 8.1, dir = dir)
		W.pixel_x = ox * tile * 2 + oy * tile * k
		W.pixel_y = oy * tile * 2 + ox * tile * k
		drawn += W
	wire_images = drawn
	overlays += wire_images

/obj/structure/train_catenary/proc/line_live()
	var/datum/catenary_net/N = network()
	return N ? N.energise() : FALSE

/obj/structure/train_catenary/attackby(obj/item/W, mob/user)
	if (!is_tool(W, TOOL_WRENCH))
		return ..()
	var/mob/living/human/H = user
	if (!istype(H) || H.stat != CONSCIOUS || get_dist(H, src) > 1)
		return
	if (anchored)
		take_down()
		playsound(loc, 'sound/items/Ratchet.ogg', 100, TRUE)
		to_chat(user, SPAN_NOTICE("You unfasten \the [src] and take its wire down."))
		return
	if (!put_up(user))
		return
	playsound(loc, 'sound/items/Ratchet.ogg', 100, TRUE)
	var/datum/catenary_net/N = network()
	to_chat(user, SPAN_NOTICE("You secure \the [src] and hang its wire over the track. [line_text(N)]"))

/obj/structure/train_catenary/proc/line_text(datum/catenary_net/N)
	if (!N)
		return "It is not secured."
	var/list/fed = N.feeders()
	var/count = N.masts.len
	if (!fed.len)
		return "The line has [count] mast\s and no supply: stand a distribution transformer, a wall outlet or a utility pole on a powered cable within reach of one of them."
	if (!N.energise())
		return "The line has [count] mast\s, [fed.len] of them fed, but the grid behind it has no power to spare. The wire is dead."
	return "The line has [count] mast\s, [fed.len] of them fed, and carries [power_text(N.demand())] for the trains under it. The wire is live."

/obj/structure/train_catenary/attack_hand(mob/user)
	if (!anchored)
		return ..()
	if (!powersource)
		seek_power_point()
	to_chat(user, SPAN_NOTICE("You look the line over. [line_text(network())]"))

/obj/structure/train_catenary/examine(mob/user)
	. = ..()
	if (!anchored)
		to_chat(user, "It is not secured. Stand it two tiles from the rails and use a wrench.")
		return
	to_chat(user, "Its wire hangs over the track for [CATENARY_REACH] tiles either way. [line_text(network())]")

// Somebody riding on a car roof meets a live wire (vehicle_decks.dm). Returns
// TRUE when they were struck.
/proc/train_catenary_strike(mob/living/human/H, back_dir)
	if (!train_catenary.len || !H || !isturf(H.loc))
		return FALSE
	var/obj/structure/train_catenary/M = train_catenary_over(H.loc)
	if (!M || !M.line_live())
		return FALSE
	H.visible_message(SPAN_DANGER("[H] touches the overhead wire in a shower of sparks!"), SPAN_DANGER("You touch the live overhead wire!"))
	playsound(H.loc, "sparks", 80, TRUE)
	H.adjustBurnLoss(CATENARY_SHOCK)
	H.Weaken(4)
	H.vehicle_deck_thrown(back_dir, "The shock throws you off the roof!")
	return TRUE

/////////////////////////////////////////////////////////////////////////////
// Engines

/obj/structure/trains/locomotive/electric
	name = "electric locomotive"
	desc = "An electric locomotive with a cab at each end and a pantograph on its roof. It carries no fuel: it runs only under a live overhead line, and works in multiple with other units coupled next to it."
	body_kind = "electric"
	health = 2500
	// No fuel of its own: the tank is never looked at, and never runs dry.
	max_fuel = 0
	fuel = 1
	train_weight = 3.5 // 5 with its body sections
	haul = 40
	fuel_store = "overhead line"
	start_text = "Raise the pantograph"
	stop_text = "Lower the pantograph"
	var/collector = "pantograph"
	var/line_draw = 150 // kW at full throttle
	var/line_idle = 5 // kW with the collector up and the throttle shut
	var/tmp/line_live = FALSE
	var/tmp/line_checked = -100
	var/tmp/line_asked = -1
	var/tmp/datum/catenary_net/line_net = null

/obj/structure/trains/locomotive/electric/Destroy()
	if (line_net)
		line_net.release(src)
	line_net = null
	return ..()

// What it has from the line is found again by asking; none of it is saved.
/obj/structure/trains/locomotive/electric/persistence_runtime_var(key)
	return (key in list("line_live", "line_checked", "line_asked", "line_net")) || ..()

/obj/structure/trains/locomotive/electric/fuel_per_tile(notch, weight)
	return 0

// What the engine wants from the line just now.
/obj/structure/trains/locomotive/electric/proc/line_demand()
	return (on && !engine_disabled()) ? line_idle + line_draw * throttle_share() : 0

// Asks the line for power, at most once a second while nothing changes.
// Returns TRUE while the engine has it.
/obj/structure/trains/locomotive/electric/proc/line_check(force = FALSE)
	var/want = line_demand()
	if (!force && want == line_asked && world.time - line_checked < 10)
		return line_live
	line_checked = world.time
	line_asked = want
	var/was = line_live
	var/obj/structure/train_catenary/M = isturf(loc) ? train_catenary_over(loc) : null
	var/datum/catenary_net/N = M ? M.network() : null
	if (line_net && line_net != N)
		line_net.release(src)
	line_net = N
	if (!N)
		line_live = FALSE
	else if (want > 0)
		line_live = N.request(src, want)
	else
		N.release(src)
		line_live = FALSE
	if (on && was && !line_live && isturf(loc))
		visible_message(SPAN_WARNING("\The [src]'s [collector] loses its power: [M ? "the overhead line cannot carry it" : "the overhead line ends here"]. It coasts."))
	else if (on && !was && line_live && rail_speed > 0 && isturf(loc))
		visible_message("\The [src]'s [collector] takes power from the line again.")
	return line_live

/obj/structure/trains/locomotive/electric/steam_factor()
	return line_check() ? 1 : 0

/obj/structure/trains/locomotive/electric/no_power_text()
	return "There is no power in the overhead line here."

/obj/structure/trains/locomotive/electric/start_problem()
	var/obj/structure/train_catenary/M = isturf(loc) ? train_catenary_over(loc) : null
	if (!M)
		return "There is no overhead line above \the [src] here."
	if (!M.line_live())
		return "The overhead line is dead: none of its masts is fed from a grid with power to spare."
	return null

/obj/structure/trains/locomotive/electric/started(mob/user)
	line_check(TRUE)
	visible_message("[user] raises \the [src]'s [collector] to the wire.", "You raise the [collector]. [line_live ? "It takes power from the line." : "The line gives it no power."]")

/obj/structure/trains/locomotive/electric/stopped(mob/user)
	line_check(TRUE)
	visible_message("[user] lowers \the [src]'s [collector].", "You lower the [collector]. The train will roll on until it slows or you brake.")

// Switched off some other way (a linked unit, a wreck): let go of the line.
/obj/structure/trains/locomotive/electric/update_icon()
	..()
	if (line_asked > 0 && line_demand() <= 0)
		line_check(TRUE)

/obj/structure/trains/locomotive/electric/drive_ended()
	line_check(TRUE)

/obj/structure/trains/locomotive/electric/state_text()
	if (!on)
		return "The [collector] is down."
	return "The [collector] is up, [line_check() ? "taking [power_text(line_asked)] from the line" : "with no power in the line"]."

/obj/structure/trains/locomotive/electric/works_in_multiple()
	return TRUE

/obj/structure/trains/locomotive/electric/has_deadman()
	return TRUE

/obj/structure/trains/locomotive/electric/ex_act(severity)
	blast_couplings(severity)
	heavy_damage(severity == 1.0 ? 450 : (severity == 2.0 ? 220 : 80))
	update_icon()

/obj/structure/trains/locomotive/electric/attackby(obj/item/W as obj, mob/user as mob)
	if (heavy_weld(W, user))
		return
	return ..()

/obj/structure/trains/locomotive/electric/examine(mob/user)
	..()
	heavy_examine(user)
	to_chat(user, "It runs only under a live overhead line and draws up to [power_text(line_idle + line_draw)] from the grid. Off the wire it coasts.")
	to_chat(user, "It has a dead-man's handle: with nobody fit to drive in a cab, the power shuts off and the brakes go on within a dozen tiles.")
	var/list/units = linked_units()
	if (units && units.len > 1)
		to_chat(user, "[units.len] units are coupled together and work in multiple: any of their cabs starts, stops, drives and brakes them all.")

// The town tram: one car with a driving platform at each end and seats
// between. Light and slow, it pulls a trailer car at most.
/obj/structure/trains/locomotive/electric/tram
	name = "tram"
	desc = "An electric tram with a driving platform at each end, seats between them and bow collectors on its roof. It runs only under a live overhead line."
	body_kind = "tram"
	health = 1200
	train_weight = 1.5 // 3 with its body sections
	haul = 10
	train_speed = 2
	max_train_speed = 2
	start_text = "Raise the bow collector"
	stop_text = "Lower the bow collector"
	collector = "bow collector"
	line_draw = 40
	line_idle = 2

/proc/train_electric_layouts(list/layouts)
	var/list/cab_end = list(list(-1, "back", "cab_end"), list(0, "back", "cab_end"), list(1, "back", "cab_end"))
	var/list/windows = list(list(-1, "out", "window"), list(1, "out", "window"))
	var/list/seats = list(/obj/structure/bed/chair/comfy/blue, null, /obj/structure/bed/chair/comfy/blue)
	layouts["loco_electric"] = list(
		"name" = "electric locomotive", "desc" = "An electric locomotive with a cab at each end and a pantograph on its roof. It carries no fuel: it runs only under a live overhead line, and works in multiple with other units coupled next to it.",
		"body" = "electric", "cab" = 1, "cab2" = 4, "roof" = "loco_electric", "engine" = /obj/structure/trains/locomotive/electric,
		"segments" = list(
			list("edges" = list(), "solid" = 0),
			list("edges" = list(), "solid" = 1),
			list("edges" = list(), "solid" = 1),
			list("edges" = cab_end, "solid" = 0)))
	layouts["loco_tram"] = list(
		"name" = "tram", "desc" = "An electric tram with a driving platform at each end, seats between them and bow collectors on its roof. It runs only under a live overhead line.",
		"body" = "tram", "cab" = 1, "cab2" = 4, "roof" = "loco_tram", "engine" = /obj/structure/trains/locomotive/electric/tram,
		"segments" = list(
			list("edges" = list(), "solid" = 0),
			list("edges" = windows, "solid" = 0, "fit" = seats),
			list("edges" = windows, "solid" = 0, "fit" = seats),
			list("edges" = cab_end, "solid" = 0)))

/obj/structure/train_car_kit/loco_electric
	name = "electric locomotive kit"
	car_kind = "loco_electric"
/obj/structure/train_car_kit/loco_tram
	name = "tram kit"
	car_kind = "loco_tram"

#undef CATENARY_REACH
#undef CATENARY_IDLE
#undef CATENARY_STALE
#undef CATENARY_SHOCK
