// Walkable platform cars (docs/train-platforms.md). A car is three tiles wide
// and TRAIN_CAR_LENGTH tiles long: one segment per rail tile, each a
// /obj/structure/trains on the track with a deck tile either side. Segments
// are hitched to each other like ordinary wagons, so a car follows the track
// round curves. Everything standing on a segment's three tiles (people,
// furniture, crates) rides along when the segment moves.
//
// Deck tiles and the car's walls, windows and doors are train_part objects.
// They are never saved: a segment rebuilds them from its car kind, its place
// in the car and its saved door state (open_doors).

#define TRAIN_CAR_LENGTH 4
#define TRAIN_LEFT -1
#define TRAIN_RIGHT 1

// The load of every platform segment in the train taking the current step,
// planned before any of them moves so that a tight curve, where one car's
// new tiles are another's old ones, never hands cargo from car to car.
// segment -> list(atom -> slot 1..3).
var/global/list/train_platform_plan = list()
var/global/train_platform_plan_time = -1

/proc/train_platform_reset_plan()
	train_platform_plan = list()
	train_platform_plan_time = world.time

/proc/train_platform_plan_from(obj/structure/trains/platform/first)
	var/list/claimed = list()
	var/obj/structure/trains/car = first
	var/list/seen = list()
	while (istype(car, /obj/structure/trains/platform) && !(car in seen))
		seen += car
		var/list/cargo = list()
		var/list/tiles = train_platform_tiles(car.loc, car.dir)
		for (var/i in list(2, 1, 3))
			var/turf/T = tiles[i]
			if (!T)
				continue
			// A side tile that is another wagon's centre belongs to that wagon.
			if (i != 2 && train_centre_of_other(T, car))
				continue
			for (var/atom/movable/AM in T)
				if (AM.loc == T && !claimed[AM] && train_platform_carries(AM))
					cargo[AM] = i
					claimed[AM] = TRUE
		train_platform_plan[car] = cargo
		car = car.connected

// The car kinds. Each segment entry lists fittings (left, centre, right) put
// down when a furnished kit is assembled, and edges: list(side, edge, style)
// where side is TRAIN_LEFT, 0 or TRAIN_RIGHT and edge is "out", "in" (side
// tiles only), "front" or "back".
/proc/train_car_layout(kind)
	var/static/list/layouts = null
	if (!layouts)
		layouts = list()
		var/list/vestibule = list(list(TRAIN_LEFT, "out", "door"), list(TRAIN_RIGHT, "out", "door"),
			list(TRAIN_LEFT, "front", "wall"), list(0, "front", "door"), list(TRAIN_RIGHT, "front", "wall"))
		var/list/back_end = list(list(TRAIN_LEFT, "back", "wall"), list(0, "back", "door"), list(TRAIN_RIGHT, "back", "wall"))
		var/list/windows = list(list(TRAIN_LEFT, "out", "window"), list(TRAIN_RIGHT, "out", "window"))
		var/list/walls = list(list(TRAIN_LEFT, "out", "wall"), list(TRAIN_RIGHT, "out", "wall"))
		var/list/compartment = list(list(TRAIN_LEFT, "in", "inner_door"), list(TRAIN_RIGHT, "in", "inner_door"),
			list(TRAIN_LEFT, "front", "partition"), list(TRAIN_RIGHT, "front", "partition"))
		var/list/rails = list(list(TRAIN_LEFT, "out", "rail"), list(TRAIN_RIGHT, "out", "rail"))
		layouts["flatbed"] = list(
			"name" = "platform car", "desc" = "An open flatbed car with a plank deck and side railings. Walk about on it, or load crates and machines.",
			"center" = "wood", "side" = "wood",
			"segments" = list(
				list("edges" = rails),
				list("edges" = list()),
				list("edges" = list()),
				list("edges" = rails)))
		layouts["coach"] = list(
			"name" = "passenger coach", "desc" = "A carriage with rows of seats either side of a carpeted aisle.",
			"center" = "carpet", "side" = "floor",
			"segments" = list(
				list("edges" = vestibule),
				list("edges" = windows, "fit" = list(/obj/structure/bed/chair/comfy/blue, null, /obj/structure/bed/chair/comfy/blue)),
				list("edges" = windows, "fit" = list(/obj/structure/bed/chair/comfy/blue, null, /obj/structure/bed/chair/comfy/blue)),
				list("edges" = windows + back_end, "fit" = list(/obj/structure/bed/chair/comfy/blue, null, /obj/structure/bed/chair/comfy/blue))))
		layouts["sleeper"] = list(
			"name" = "sleeper car", "desc" = "A carriage of private sleeping compartments, each with a bed and a sliding door.",
			"center" = "carpet", "side" = "floor",
			"segments" = list(
				list("edges" = vestibule),
				list("edges" = windows + compartment, "fit" = list(/obj/structure/bed, null, /obj/structure/bed)),
				list("edges" = windows + compartment, "fit" = list(/obj/structure/bed, null, /obj/structure/bed)),
				list("edges" = windows + compartment + back_end, "fit" = list(/obj/structure/bed, null, /obj/structure/bed))))
		layouts["dining"] = list(
			"name" = "dining car", "desc" = "A galley kitchen with a stove, sink and fridge, and booths to eat at.",
			"center" = "floor", "side" = "floor",
			"segments" = list(
				list("edges" = vestibule),
				list("edges" = windows, "fit" = list(/obj/structure/oven/stove, null, /obj/structure/sink)),
				list("edges" = windows, "fit" = list(/obj/structure/closet/fridge, null, /obj/structure/table/modern/table)),
				list("edges" = windows + back_end, "fit" = list(/obj/structure/bed/chair/comfy/diner_booth, null, /obj/structure/bed/chair/comfy/diner_booth))))
		layouts["storage"] = list(
			"name" = "storage car", "desc" = "A steel car of lockable-looking storage compartments either side of a walkway.",
			"center" = "steel", "side" = "steel",
			"segments" = list(
				list("edges" = vestibule),
				list("edges" = walls + compartment, "fit" = list(/obj/structure/closet/cabinet, null, /obj/structure/closet/cabinet)),
				list("edges" = walls + compartment, "fit" = list(/obj/structure/closet/crate/large, null, /obj/structure/closet/crate/large)),
				list("edges" = walls + compartment + back_end, "fit" = list(/obj/structure/closet/cabinet, null, /obj/structure/closet/cabinet))))
		// Wartime cars (train_warfare.dm).
		var/list/armor_sides = list(list(TRAIN_LEFT, "out", "armor"), list(TRAIN_RIGHT, "out", "armor"))
		var/list/armor_doors = list(list(TRAIN_LEFT, "out", "armor_door"), list(TRAIN_RIGHT, "out", "armor_door"),
			list(TRAIN_LEFT, "front", "armor"), list(0, "front", "armor_door"), list(TRAIN_RIGHT, "front", "armor"))
		var/list/armor_back = list(list(TRAIN_LEFT, "back", "armor"), list(0, "back", "armor_door"), list(TRAIN_RIGHT, "back", "armor"))
		layouts["railgun"] = list(
			"name" = "railway gun car", "desc" = "A heavy steel car carrying a long-range gun on a turntable. Brace the car before firing.",
			"center" = "steel", "side" = "steel", "armored" = TRUE,
			"segments" = list(
				list("edges" = rails, "fit" = list(/obj/structure/railway_gun_brace, null, /obj/structure/shellrack)),
				list("edges" = rails, "fit" = list(null, /obj/structure/cannon/modern/railway, null)),
				list("edges" = rails),
				list("edges" = rails)))
		layouts["armored"] = list(
			"name" = "armored wagon", "desc" = "A steel-plated car. Its armor stops bullets from outside while the crew fires machine guns through the slits.",
			"center" = "steel", "side" = "steel", "armored" = TRUE,
			"segments" = list(
				list("edges" = armor_doors),
				list("edges" = armor_sides, "fit" = list(/obj/item/weapon/gun/projectile/automatic/stationary/maxim, null, /obj/item/weapon/gun/projectile/automatic/stationary/maxim)),
				list("edges" = armor_sides),
				list("edges" = armor_sides + armor_back, "fit" = list(/obj/item/weapon/gun/projectile/automatic/stationary/maxim, null, /obj/item/weapon/gun/projectile/automatic/stationary/maxim))))
		layouts["flak"] = list(
			"name" = "flak car", "desc" = "An open car mounting autocannons that reach aircraft at cruising height.",
			"center" = "steel", "side" = "steel", "armored" = TRUE,
			"segments" = list(
				list("edges" = rails),
				list("edges" = rails, "fit" = list(/obj/item/weapon/gun/projectile/automatic/stationary/autocannon, null, /obj/item/weapon/gun/projectile/automatic/stationary/autocannon)),
				list("edges" = rails),
				list("edges" = rails, "fit" = list(/obj/structure/closet/crate, null, /obj/structure/closet/crate))))
	return layouts[kind]

// The three tiles of a segment at T facing heading: left, centre, right.
/proc/train_platform_tiles(turf/T, heading)
	if (!T)
		return list(null, null, null)
	return list(get_step(T, turn(heading, 90)), T, get_step(T, turn(heading, -90)))

/proc/train_centre_of_other(turf/T, obj/structure/trains/self)
	for (var/obj/structure/trains/TR in T)
		if (TR != self)
			return TRUE
	return FALSE

// What a moving deck carries along: people and objects standing on it, but not
// track, cables, flora, floor covers or the train's own parts.
/proc/train_platform_carries(atom/movable/AM)
	if (!AM || QDELETED(AM))
		return FALSE
	if (isliving(AM))
		return TRUE
	if (!isobj(AM))
		return FALSE
	if (istype(AM, /obj/structure/trains) || istype(AM, /obj/structure/train_part) || istype(AM, /obj/effect))
		return FALSE
	if (istype(AM, /obj/structure/rails) || istype(AM, /obj/structure/rail_bed) || istype(AM, /obj/structure/cable) || istype(AM, /obj/covers))
		return FALSE
	if (istype(AM, /obj/structure/wild) || istype(AM, /obj/structure/sign) || istype(AM, /obj/structure/lamp))
		return FALSE
	return TRUE

/////////////////////////////////////////////////////////////////////////////
// Segments

/obj/structure/trains/platform
	name = "platform car"
	desc = "A walkable rail car."
	icon = 'icons/obj/vehicles/train_platforms.dmi'
	icon_state = "deck_center_wood"
	density = FALSE
	layer = 2.6
	health = 1500
	var/car_kind = "flatbed"
	var/car_id = ""
	var/seg_index = 1
	var/open_doors = 0 // bit per edge index (1-based) of this segment's layout
	var/braced = FALSE // railway gun car outriggers down (train_warfare.dm)
	var/wrecked = FALSE // knocked off the track by explosions until welded back
	var/tmp/last_moved = -1000
	var/tmp/list/deck_parts = null

/obj/structure/trains/platform/on_runtime_spawn()
	..()
	if (!car_id)
		car_id = "[rand(100000, 999999)]-[rand(100000, 999999)]"
	apply_layout()

/obj/structure/trains/platform/after_load()
	..()
	apply_layout()

/obj/structure/trains/platform/Destroy()
	clear_parts()
	for (var/obj/structure/trains/TR in range(2, src))
		if (TR.connected == src)
			TR.connected = null
	connected = null
	return ..()

/obj/structure/trains/platform/proc/layout()
	return train_car_layout(car_kind)

/obj/structure/trains/platform/proc/segment_layout()
	var/list/L = layout()
	if (!L)
		return null
	var/list/segs = L["segments"]
	return segs[clamp(seg_index, 1, segs.len)]

/obj/structure/trains/platform/proc/clear_parts()
	for (var/obj/structure/train_part/P in deck_parts)
		P.segment = null
		qdel(P)
	deck_parts = null

/obj/structure/trains/platform/proc/apply_layout()
	var/list/L = layout()
	if (!L)
		return
	name = wrecked ? "wrecked [L["name"]]" : L["name"]
	desc = L["desc"]
	icon_state = "deck_center_[L["center"]]"
	overlays.Cut()
	if (wrecked)
		overlays += image(icon, "wreck", layer = layer + 0.01)
	clear_parts()
	deck_parts = list()
	for (var/side in list(TRAIN_LEFT, TRAIN_RIGHT))
		var/obj/structure/train_part/deck/D = new(null)
		D.setup(src, side, "out", "deck_side_[L["side"]]")
		deck_parts += D
	var/list/edges = segment_layout()["edges"]
	for (var/i in 1 to edges.len)
		var/list/E = edges[i]
		var/obj/structure/train_part/edge/G = new(null)
		G.edge_index = i
		G.setup(src, E[1], E[2], E[3])
		G.set_open(open_doors & (1 << (i - 1)))
		deck_parts += G
	place_parts(loc, dir)

/obj/structure/trains/platform/proc/place_parts(turf/T, heading)
	var/list/tiles = train_platform_tiles(T, heading)
	for (var/obj/structure/train_part/P in deck_parts)
		var/turf/where = tiles[P.side + 2]
		if (!where)
			continue
		P.dir = P.facing(heading)
		if (P.loc != where)
			P.persistence_set_loc(where)

// Spawns the kit's fittings on this segment's tiles.
/obj/structure/trains/platform/proc/furnish()
	var/list/fit = segment_layout()["fit"]
	if (!fit)
		return
	var/list/tiles = train_platform_tiles(loc, dir)
	for (var/i in 1 to 3)
		var/fit_type = fit[i]
		if (!fit_type || !tiles[i])
			continue
		var/atom/movable/F = new fit_type(tiles[i])
		if (istype(F, /obj/structure/bed/chair))
			F.set_dir(dir)
		else
			F.dir = (i == 1) ? turn(dir, -90) : turn(dir, 90)

/obj/structure/trains/platform/proc/heading_for(turf/newloc, fdir)
	for (var/obj/structure/trains/TR in orange(1, newloc))
		if (TR.connected == src && TR.loc != newloc)
			var/d = get_dir(newloc, TR.loc)
			if (d in cardinal)
				return d
	return fdir

// Segments are moved by the wagon ahead and never by walking into a tile, so
// the move skips turf entry checks: the car's own walls and doors would refuse
// it. train_consist_obstacle() has already checked the way is clear.
/obj/structure/trains/platform/Move(var/turf/newloc, var/fdir = dir)
	if (moving_train || !isturf(loc) || !isturf(newloc))
		return FALSE
	if (train_platform_plan_time != world.time)
		train_platform_reset_plan()
	check_connections()
	var/turf/oldloc = loc
	var/newdir = heading_for(newloc, fdir)
	var/list/old_tiles = train_platform_tiles(oldloc, dir)
	var/list/new_tiles = train_platform_tiles(newloc, newdir)
	// Carry the deck's load before followers move into these tiles.
	if (!(src in train_platform_plan))
		train_platform_plan_from(src)
	var/list/cargo = train_platform_plan[src]
	train_platform_plan -= src
	moving_train = TRUE
	if (!persistence_set_loc(newloc))
		moving_train = FALSE
		return FALSE
	last_moved = world.time
	var/turning = 0
	if (newdir == turn(dir, 90))
		turning = 90
	else if (newdir == turn(dir, -90))
		turning = -90
	dir = newdir
	for (var/atom/movable/AM in cargo)
		if (AM.loc == old_tiles[cargo[AM]] && new_tiles[cargo[AM]] && AM.persistence_set_loc(new_tiles[cargo[AM]]))
			// Furniture turns with the car round a curve.
			if (turning && isobj(AM))
				AM.set_dir(turn(AM.dir, turning))
			if (ismob(AM))
				var/mob/M = AM
				if (M.client)
					M.update_vision_cone()
	place_parts(newloc, newdir)
	if (connected)
		connected.Move(oldloc, newdir)
	moving_train = FALSE
	return TRUE

// Platform cars couple at their ends only; the segments inside a car stay hitched.
/obj/structure/trains/platform/hitch()
	set category = null
	set name = "Hitch"
	set desc = "Hitch or unhitch to the wagon ahead."
	set src in view(1)
	if (seg_index != 1)
		to_chat(usr, "Cars are coupled at their front end. Use the front of \the [src].")
		return FALSE
	return ..()

/obj/structure/trains/platform/examine(mob/user)
	..()
	to_chat(user, "This is section [seg_index] of [TRAIN_CAR_LENGTH]. A crowbar takes an empty, uncoupled car apart into a kit.")
	if (wrecked)
		to_chat(user, SPAN_WARNING("It has been blown off the rails. Weld it back together before the train can move."))
	else if (health < initial(health))
		to_chat(user, "It is damaged ([round(100 * health / initial(health))]%). A welding tool repairs it.")
	if (braced)
		to_chat(user, "Its outriggers are down: the car is braced and cannot move.")

/obj/structure/trains/platform/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/crowbar))
		dismantle_car(user)
		return
	if (istype(W, /obj/item/weapon/weldingtool))
		weld_repair(user)
		return
	return ..()

/obj/structure/trains/platform/proc/car_segments()
	var/list/segs = list()
	for (var/obj/structure/trains/platform/P in range(TRAIN_CAR_LENGTH + 1, src))
		if (P.car_id == car_id && P.car_kind == car_kind)
			segs += P
	return segs

/obj/structure/trains/platform/proc/dismantle_problem()
	var/list/segs = car_segments()
	var/obj/structure/trains/platform/front = null
	var/obj/structure/trains/platform/back = null
	for (var/obj/structure/trains/platform/P in segs)
		if (P.automovement)
			return "The car is moving."
		if (P.seg_index == 1)
			front = P
		if (P.seg_index == TRAIN_CAR_LENGTH)
			back = P
	if (segs.len != TRAIN_CAR_LENGTH || !front || !back)
		return "The car is not whole."
	if (back.connected)
		return "Uncouple the car behind first."
	for (var/obj/structure/trains/TR in range(2, front))
		if (TR.connected == front)
			return "Uncouple the car from the one ahead first."
	for (var/obj/structure/trains/platform/P in segs)
		for (var/turf/T in train_platform_tiles(P.loc, P.dir))
			for (var/atom/movable/AM in T)
				if (AM.loc == T && train_platform_carries(AM))
					return "Clear everything off the deck first, including \the [AM]."
	return null

/obj/structure/trains/platform/proc/dismantle_car(mob/user)
	var/problem = dismantle_problem()
	if (problem)
		to_chat(user, SPAN_WARNING(problem))
		return FALSE
	user.visible_message("[user] starts taking \the [src] apart...", "You start taking \the [src] apart...")
	if (!do_after(user, 80, src))
		return FALSE
	problem = dismantle_problem()
	if (problem)
		to_chat(user, SPAN_WARNING(problem))
		return FALSE
	var/obj/structure/train_car_kit/K = pack_car()
	user.visible_message("[user] takes the car apart into \a [K].", "You take the car apart into \a [K].")
	return K

// Packs the whole car back into an unfurnished kit at its front tile.
/obj/structure/trains/platform/proc/pack_car()
	var/turf/T = null
	for (var/obj/structure/trains/platform/P in car_segments())
		if (P.seg_index == 1)
			T = P.loc
	var/obj/structure/train_car_kit/K = new(T)
	K.set_kind(car_kind)
	K.furnished = FALSE
	for (var/obj/structure/trains/platform/P in car_segments())
		qdel(P)
	return K

/////////////////////////////////////////////////////////////////////////////
// Deck tiles, walls, windows and doors

/obj/structure/train_part
	name = "platform car"
	icon = 'icons/obj/vehicles/train_platforms.dmi'
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	flammable = FALSE
	crushable = FALSE
	should_save = FALSE
	layer = 2.6
	var/obj/structure/trains/platform/segment = null
	var/side = 0
	var/edge_kind = "out"

/obj/structure/train_part/Destroy()
	if (segment && segment.deck_parts)
		segment.deck_parts -= src
	segment = null
	return ..()

/obj/structure/train_part/ex_act(severity)
	return

/obj/structure/train_part/proc/setup(obj/structure/trains/platform/S, new_side, new_edge, state)
	segment = S
	side = new_side
	edge_kind = new_edge
	name = S.name
	desc = S.desc
	icon_state = state

// The direction of the tile edge this part sits on, for a car facing heading.
/obj/structure/train_part/proc/facing(heading)
	switch (edge_kind)
		if ("front")
			return heading
		if ("back")
			return OPPOSITE_DIR(heading)
		if ("in")
			return side == TRAIN_LEFT ? turn(heading, -90) : turn(heading, 90)
	return side == TRAIN_LEFT ? turn(heading, 90) : turn(heading, -90)

/obj/structure/train_part/examine(mob/user)
	if (segment)
		return segment.examine(user)
	return ..()

/obj/structure/train_part/attackby(obj/item/W as obj, mob/user as mob)
	if (segment)
		return segment.attackby(W, user)
	return ..()

/obj/structure/train_part/deck
	layer = 2.6

// A wall, window, railing or door along one edge of a deck tile.
/obj/structure/train_part/edge
	layer = 3.2
	flags = ON_BORDER
	density = TRUE
	throwpass = TRUE
	var/style = "wall"
	var/edge_index = 0
	var/open = FALSE

/obj/structure/train_part/edge/setup(obj/structure/trains/platform/S, new_side, new_edge, state)
	..(S, new_side, new_edge, "edge_[state]")
	style = state
	switch (style)
		if ("window")
			name = "[S.name] window"
		if ("door", "inner_door", "armor_door")
			name = "[S.name] door"
		if ("armor")
			name = "[S.name] armor plate"
		if ("rail")
			name = "[S.name] railing"
		else
			name = "[S.name] wall"

/obj/structure/train_part/edge/proc/is_door()
	return style == "door" || style == "inner_door" || style == "armor_door"

/obj/structure/train_part/edge/proc/is_armor()
	return style == "armor" || style == "armor_door"

// Armor stops projectiles fired from outside the car; the crew shoots out.
/obj/structure/train_part/edge/proc/stops_projectile(obj/item/projectile/P)
	if (!is_armor() || !P || !P.starting)
		return FALSE
	return (get_dir(loc, P.starting) & dir) != 0

/obj/structure/train_part/edge/proc/set_open(state)
	if (!is_door())
		return
	open = !!state
	density = !open
	icon_state = open ? "edge_[style]_open" : "edge_[style]"

/obj/structure/train_part/edge/attack_hand(mob/user)
	if (!is_door() || !segment || !ishuman(user))
		return ..()
	set_open(!open)
	var/bit = 1 << (edge_index - 1)
	if (open)
		segment.open_doors |= bit
	else
		segment.open_doors &= ~bit
	playsound(loc, 'sound/effects/lever.ogg', 40, TRUE)
	user.visible_message("[user] [open ? "opens" : "closes"] \the [src].", "You [open ? "open" : "close"] \the [src].")
	return TRUE

/obj/structure/train_part/edge/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)
	if (!density || !mover)
		return TRUE
	if (istype(mover, /obj/item/projectile))
		return !stops_projectile(mover)
	if (istype(mover) && mover.checkpass(PASSTABLE) && style == "rail")
		return TRUE
	return get_dir(loc, target) != dir

/obj/structure/train_part/edge/CheckExit(atom/movable/O as mob|obj, target as turf, exit_direction = null)
	if (!density || !O)
		return TRUE
	if (istype(O, /obj/item/projectile))
		return !stops_projectile(O)
	if (istype(O) && O.checkpass(PASSTABLE) && style == "rail")
		return TRUE
	return (isnull(exit_direction) ? get_dir(O.loc, target) : exit_direction) != dir

/////////////////////////////////////////////////////////////////////////////
// Clearance: a train with platform cars stops before any deck would scrape a
// wall, tree or another train. Called by process_rail_movement (trains.dm)
// for the leading wagon before it moves.

/proc/train_consist_list(obj/structure/trains/head)
	var/list/cars = list()
	var/obj/structure/trains/car = head
	while (car && !(car in cars) && cars.len < 200)
		cars += car
		car = car.connected
	return cars

/proc/train_consist_tiles(list/cars)
	var/list/tiles = list()
	for (var/obj/structure/trains/car in cars)
		if (istype(car, /obj/structure/trains/platform))
			for (var/turf/T in train_platform_tiles(car.loc, car.dir))
				tiles[T] = TRUE
		else if (isturf(car.loc))
			tiles[car.loc] = TRUE
	return tiles

// Null when the step is clear, else the blocking atom.
/proc/train_consist_obstacle(obj/structure/trains/head, turf/target, heading)
	train_platform_reset_plan()
	var/list/cars = train_consist_list(head)
	var/has_platform = FALSE
	for (var/obj/structure/trains/car in cars)
		if (istype(car, /obj/structure/trains/platform))
			has_platform = TRUE
			break
	var/list/ours = train_consist_tiles(cars)
	// The head's own new tile may not lie on another train's deck.
	if (target && !ours[target])
		for (var/obj/structure/train_part/P in target)
			if (!(P.segment in cars))
				return P
	if (!has_platform)
		return null
	for (var/obj/structure/trains/platform/P in cars)
		if (P.wrecked || P.braced)
			return P
	var/turf/next_loc = target
	var/next_dir = heading
	for (var/obj/structure/trains/car in cars)
		if (istype(car, /obj/structure/trains/platform))
			var/list/tiles = train_platform_tiles(next_loc, next_dir)
			for (var/i in list(1, 3))
				var/turf/T = tiles[i]
				if (!T)
					return car
				if (ours[T])
					continue
				if (T.density)
					return T
				for (var/atom/movable/AM in T)
					if (istype(AM, /obj/structure/trains) || istype(AM, /obj/structure/train_part))
						return AM
					if (AM.density && !isliving(AM) && !istype(AM, /obj/structure/rails))
						return AM
		var/turf/car_loc = car.loc
		if (car_loc && next_loc && car_loc != next_loc)
			next_dir = get_dir(car_loc, next_loc)
			if (!(next_dir in cardinal))
				next_dir = car.dir
		else
			next_dir = car.dir
		next_loc = car_loc
	return null

/////////////////////////////////////////////////////////////////////////////
// Kits

/obj/structure/train_car_kit
	name = "platform car kit"
	desc = "The frame, bogies and deck of a rail car, packed for assembly. Set it on straight track with three more straight tiles behind it, face the way the car should face, and use a hammer on it."
	icon = 'icons/obj/vehicles/train_platforms.dmi'
	icon_state = "car_kit"
	density = TRUE
	anchored = FALSE
	flammable = FALSE
	var/car_kind = "flatbed"
	var/furnished = TRUE

/obj/structure/train_car_kit/proc/set_kind(kind)
	var/list/L = train_car_layout(kind)
	if (!L)
		return
	car_kind = kind
	name = "[L["name"]] kit"

/obj/structure/train_car_kit/coach
	name = "passenger coach kit"
	car_kind = "coach"
/obj/structure/train_car_kit/sleeper
	name = "sleeper car kit"
	car_kind = "sleeper"
/obj/structure/train_car_kit/dining
	name = "dining car kit"
	car_kind = "dining"
/obj/structure/train_car_kit/storage
	name = "storage car kit"
	car_kind = "storage"

/obj/structure/train_car_kit/examine(mob/user)
	..()
	if (!furnished)
		to_chat(user, "Its fittings were left behind when it was taken apart.")

/obj/structure/train_car_kit/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/hammer))
		var/heading = user.dir
		var/problem = assembly_problem(heading)
		if (problem)
			to_chat(user, SPAN_WARNING(problem))
			return
		user.visible_message("[user] starts assembling \the [src]...", "You start assembling \the [src]...")
		if (!do_after(user, 100, src))
			return
		problem = assembly_problem(heading)
		if (problem)
			to_chat(user, SPAN_WARNING(problem))
			return
		var/obj/structure/trains/platform/front = assemble(heading)
		if (front)
			user.visible_message("[user] assembles \a [front].", "You assemble \a [front].")
		return
	return ..()

// Tiles of the car's segments from the front, when built here facing heading.
/obj/structure/train_car_kit/proc/car_turfs(heading)
	var/list/turfs = list()
	var/turf/T = get_turf(src)
	for (var/i in 1 to TRAIN_CAR_LENGTH)
		if (!T)
			return null
		turfs += T
		T = get_step(T, OPPOSITE_DIR(heading))
	return turfs

/obj/structure/train_car_kit/proc/assembly_problem(heading)
	if (!isturf(loc))
		return "Set the kit down on the track first."
	if (!(heading in cardinal))
		return "Face along the track."
	var/list/turfs = car_turfs(heading)
	if (!turfs)
		return "There is no room for the car here."
	for (var/turf/T in turfs)
		var/straight = FALSE
		for (var/obj/structure/rails/R in T)
			if (R.type == /obj/structure/rails/regular || R.type == /obj/structure/rails/regular/horizontal || R.type == /obj/structure/rails)
				if (R.dir == heading || R.dir == OPPOSITE_DIR(heading))
					straight = TRUE
		if (!straight)
			return "The car needs four tiles of straight track running the way you face, starting under the kit."
		for (var/obj/structure/trains/TR in T)
			return "\The [TR] is in the way."
		for (var/turf/S in train_platform_tiles(T, heading))
			if (!S || S.density)
				return "The deck needs a clear tile either side of the track."
			for (var/atom/movable/AM in S)
				if (AM == src)
					continue
				if (istype(AM, /obj/structure/trains) || istype(AM, /obj/structure/train_part) || (AM.density && !isliving(AM)))
					return "\The [AM] is in the way of the deck."
	return null

/obj/structure/train_car_kit/proc/assemble(heading)
	var/list/turfs = car_turfs(heading)
	var/id = "[rand(100000, 999999)]-[rand(100000, 999999)]"
	var/obj/structure/trains/platform/front = null
	var/obj/structure/trains/platform/ahead = null
	for (var/i in 1 to TRAIN_CAR_LENGTH)
		var/obj/structure/trains/platform/P = new(turfs[i])
		P.dir = heading
		P.car_kind = car_kind
		P.car_id = id
		P.seg_index = i
		P.apply_layout()
		if (furnished)
			P.furnish()
		if (ahead)
			ahead.connected = P
		else
			front = P
		ahead = P
	qdel(src)
	return front
