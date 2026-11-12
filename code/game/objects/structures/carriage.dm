// ============================================================
// Carriages: a wagon drawn by a team of horses or oxen
// ------------------------------------------------------------
// A carriage stands on a footprint two tiles wide and three long, laid along
// the way it faces, with its team in harness in a lane ahead of it. Its pace
// comes from the team's pull against what it carries, the ground and the
// slope; the driver urges and reins in the team with the reins. It turns only
// where there is room for its new footprint and team, and steps one whole
// tile at a time, gliding its riders, cargo and team with it.
//
// Seats hold passengers or cargo (crates, barrels and other loose
// structures). A party can register a carriage in its papers like any
// vehicle (code/modules/craft/carriage_papers.dm).
//
// Everything aboard stands on the carriage's own tile (its bottom-left
// corner) and is drawn in place with pixel offsets from lay_out().
// ============================================================

#define CARRIAGE_SEATS 5
#define CARRIAGE_MAX_TEAM 4
// Load one unit of pull draws at the slowest unladen pace.
#define CARRIAGE_PULL_CAPACITY 120
// The carriage itself, and what a seated person or a loaded structure adds
// before what they carry.
#define CARRIAGE_EMPTY_WEIGHT 120
#define CARRIAGE_PERSON_WEIGHT 70
#define CARRIAGE_CARGO_WEIGHT 30
// Past this many times its capacity the team cannot start the carriage.
#define CARRIAGE_MAX_LOAD_RATIO 4
#define CARRIAGE_SLOWEST_STEP 30
#define CARRIAGE_FASTEST_STEP 1.5
// Below this an animal is starving (husbandry_feeding.dm) and pulls at half.
#define CARRIAGE_STARVING_HUNGER 180

var/global/list/carriage_gear_names = list("walk", "trot", "canter")
// Deciseconds a tile at each gear, unladen and on level built ground.
var/global/list/carriage_gear_delays = list(7, 4, 2.2)

// What one draft animal adds to the team's pull, or 0 when it cannot pull.
/proc/draft_animal_pull(mob/living/simple_animal/A)
	if (!istype(A) || QDELETED(A) || A.stat == DEAD)
		return 0
	var/pull = 0
	if (istype(A, /mob/living/simple_animal/horse))
		pull = 2
	else if (istype(A, /mob/living/simple_animal/cattle))
		var/mob/living/simple_animal/cattle/C = A
		pull = C.calf ? 0 : 1
	// A starving animal pulls at half strength.
	if (pull && A.simplehunger < CARRIAGE_STARVING_HUNGER)
		pull /= 2
	return pull

/proc/is_draft_animal(mob/living/simple_animal/A)
	if (istype(A, /mob/living/simple_animal/horse))
		return TRUE
	if (istype(A, /mob/living/simple_animal/cattle))
		var/mob/living/simple_animal/cattle/C = A
		return !C.calf
	return FALSE

// The fastest gear a team of this pull can keep: oxen walk, a horse trots and
// a pair of horses can canter.
/proc/carriage_top_gear(pull)
	if (pull >= 4)
		return 3
	if (pull >= 2)
		return 2
	return pull > 0 ? 1 : 0

// Deciseconds for one tile at this gear and load, before ground and slope.
/proc/carriage_step_delay(gear, load_ratio)
	gear = clamp(gear, 1, carriage_gear_delays.len)
	return carriage_gear_delays[gear] * max(1, load_ratio)

// Tiles of the footprint across (x) and along (y) for a facing.
/proc/carriage_footprint_size(facing)
	return (facing == EAST || facing == WEST) ? list(3, 2) : list(2, 3)

// The turfs a carriage with its corner at (x, y) covers when facing that way,
// with the lane its team stands in: lane_depth tiles ahead, two tiles wide.
/proc/carriage_cells(x, y, z, facing, lane_depth = 0)
	. = list()
	var/list/size = carriage_footprint_size(facing)
	for (var/dx = 0 to size[1] - 1)
		for (var/dy = 0 to size[2] - 1)
			var/turf/T = locate(x + dx, y + dy, z)
			if (!T)
				return null
			. += T
	for (var/i = 1 to lane_depth)
		for (var/side = 0 to 1)
			var/turf/T = null
			switch (facing)
				if (NORTH) T = locate(x + side, y + 2 + i, z)
				if (SOUTH) T = locate(x + side, y - i, z)
				if (EAST) T = locate(x + 2 + i, y + side, z)
				if (WEST) T = locate(x - i, y + side, z)
			if (!T)
				return null
			. += T

// A point on the carriage given along (from the rear, toward the front) and
// across (from the left of someone facing forward), in pixels from its corner.
/proc/carriage_local_point(facing, along, across)
	switch (facing)
		if (SOUTH) return list(64 - across, 96 - along)
		if (EAST) return list(along, 64 - across)
		if (WEST) return list(96 - along, across)
	return list(across, along)

/obj/structure/vehicle/carriage
	name = "carriage"
	desc = "A wooden carriage for a team of horses or oxen. Drag a horse or an ox onto it to put it in harness, drag yourself onto it to take the reins or a seat, and drag crates or barrels onto it to load them. Use the reins to urge the team on and their secondary action to rein in."
	icon = 'icons/obj/vehicles/vehicles96x96.dmi'
	icon_state = "simple_carriage"
	anchored = TRUE
	density = TRUE
	opacity = FALSE
	flammable = TRUE
	not_movable = TRUE
	not_disassemblable = FALSE
	vehicle_m_delay = 7
	layer = 3.9
	health = 150
	wheeled = TRUE
	bound_width = 64
	bound_height = 96
	pixel_x = -18
	mobcapacity = CARRIAGE_SEATS + 1
	storagecapacity = CARRIAGE_SEATS
	leave_time = 20
	// The way the footprint is laid out; dir follows it.
	var/facing = SOUTH
	// Draft animals in harness, front pair first.
	var/list/team = list()
	// Passengers or cargo by seat; null for an empty seat.
	var/list/seats = list(null, null, null, null, null)
	// 0 when standing, else an index into carriage_gear_names.
	var/gear = 0
	// The crew register's register_state() text, saved with the carriage.
	var/register_state = ""
	var/tmp/datum/craft/vehicle/carriage/craft
	var/tmp/step_timer = null
	var/tmp/safety_timer = null
	var/tmp/next_step = 0
	var/tmp/stepping = FALSE
	var/tmp/last_refusal_message = 0

/obj/structure/vehicle/carriage/New()
	..()
	// Saved reins come back with the carriage; never make a second set.
	if (!persistence_saved_atom_construction)
		dwheel = new /obj/item/vehicleparts/wheel/rope(src)
		dwheel.origin = src
	if (!(dir in cardinal))
		dir = SOUTH
	facing = dir
	apply_shape()

/obj/structure/vehicle/carriage/persistence_restore_finished()
	..()
	stopmovementloop()
	if (!istype(dwheel, /obj/item/vehicleparts/wheel/rope))
		dwheel = new /obj/item/vehicleparts/wheel/rope(src)
	dwheel.origin = src
	if (!(facing in cardinal))
		facing = SOUTH
	if (!islist(seats) || seats.len != CARRIAGE_SEATS)
		seats = list(null, null, null, null, null)
	if (!islist(team))
		team = list()
	apply_shape()
	check_aboard()
	if (!safety_timer)
		safety_check()

/obj/structure/vehicle/carriage/Destroy()
	stopmovementloop()
	if (safety_timer)
		deltimer(safety_timer)
		safety_timer = null
	for (var/atom/movable/A in everything_aboard())
		let_off(A)
	if (craft)
		var/datum/craft/vehicle/carriage/C = craft
		craft = null
		if (!QDELETED(C))
			var/datum/craft_body/B = C.body
			qdel(C)
			if (B && !QDELETED(B))
				qdel(B)
	return ..()

/obj/structure/vehicle/carriage/persistence_runtime_var(key)
	return key == "craft" || key == "step_timer" || key == "safety_timer" || key == "next_step" || key == "stepping" || key == "last_refusal_message" || key == "moving" || key == "movement_processes" || key == "gear" || ..()

// ---- Shape and layout ----

// Tiles of lane the team needs ahead of the carriage.
/obj/structure/vehicle/carriage/proc/lane_depth()
	if (!team.len)
		return 0
	var/ranks = round((team.len + 1) / 2)
	return ceil((2 + ranks * team_rank_length()) / world.icon_size)

/obj/structure/vehicle/carriage/proc/team_rank_length()
	for (var/mob/living/simple_animal/horse/H in team)
		return 52
	return 30

/obj/structure/vehicle/carriage/proc/cells_at(turf/corner, way, depth = -1)
	if (!corner)
		return null
	if (depth < 0)
		depth = lane_depth()
	return carriage_cells(corner.x, corner.y, corner.z, way, depth)

// Sets bounds and sprite offset for the facing.
/obj/structure/vehicle/carriage/proc/apply_shape()
	dir = facing
	var/list/size = carriage_footprint_size(facing)
	bound_width = size[1] * world.icon_size
	bound_height = size[2] * world.icon_size
	// Centre the sprite's wheels over the footprint (measured from the icon).
	var/narrow = (icon_state == "simple_carriage2")
	switch (facing)
		if (SOUTH)
			pixel_x = -18
			pixel_y = 0
		if (NORTH)
			pixel_x = -15
			pixel_y = 0
		if (EAST)
			pixel_x = 0
			pixel_y = narrow ? -10 : -18
		if (WEST)
			pixel_x = 0
			pixel_y = narrow ? -10 : -15

// Where a seat, the driver or a team animal is drawn: list(along, across).
/obj/structure/vehicle/carriage/proc/seat_point(seat)
	switch (seat)
		if (0) return list(78, 22) // the driver's bench, left
		if (1) return list(78, 44)
		if (2) return list(52, 18)
		if (3) return list(52, 46)
		if (4) return list(26, 18)
		if (5) return list(26, 46)
	return list(48, 32)

/obj/structure/vehicle/carriage/proc/team_point(index)
	var/rank = round((index - 1) / 2)
	var/side = (index - 1) % 2
	var/rank_length = team_rank_length()
	return list(96 + 2 + rank * rank_length + rank_length / 2, side ? 46 : 18)

// The pixel offset that centres this thing's sprite on a point of the carriage.
/obj/structure/vehicle/carriage/proc/place_at(atom/movable/A, list/local)
	var/list/p = carriage_local_point(facing, local[1], local[2])
	var/cx = 16
	var/cy = 16
	if (istype(A, /mob/living/simple_animal/horse))
		cx = 30
		cy = 28
	else if (istype(A, /mob/living/simple_animal/cattle))
		cy = 13
	A.pixel_x = round(p[1] - cx)
	A.pixel_y = round(p[2] - cy)
	A.dir = facing

/obj/structure/vehicle/carriage/proc/lay_out()
	if (driver)
		place_at(driver, seat_point(0))
	for (var/i = 1 to CARRIAGE_SEATS)
		var/atom/movable/A = seats[i]
		if (A)
			place_at(A, seat_point(i))
	for (var/i = 1 to team.len)
		place_at(team[i], team_point(i))

/obj/structure/vehicle/carriage/update_icon()
	dir = facing
	buckle_dir = facing

/obj/structure/vehicle/carriage/update_overlay()
	return

// Called after the driver's direction keys set dir: turn if there is room.
/obj/structure/vehicle/carriage/updatepassdir()
	if (dir != facing)
		var/want = dir
		dir = facing
		try_turn(want)
	lay_out()

/obj/structure/vehicle/carriage/proc/try_turn(want)
	if (!(want in cardinal) || want == facing || !isturf(loc))
		return FALSE
	if (want == turn(facing, 180) && gear > 1)
		refuse("Slow to a walk before turning \the [src] around.")
		return FALSE
	var/list/now = cells_at(loc, facing)
	var/list/after = cells_at(loc, want)
	if (!after)
		refuse("There is no room to turn here.")
		return FALSE
	for (var/turf/T in after - now)
		var/why = cell_refusal(T, FALSE)
		if (why)
			refuse("There is no room to turn: [why].")
			return FALSE
	var/old = facing
	facing = want
	apply_shape()
	if (craft)
		craft.on_turn(craft_turn_angle(old, want))
	return TRUE

/obj/structure/vehicle/carriage/proc/refuse(text)
	if (driver && world.time >= last_refusal_message + 10)
		last_refusal_message = world.time
		to_chat(driver, SPAN_WARNING(text))

// ---- Who and what is aboard ----

/obj/structure/vehicle/carriage/proc/everything_aboard()
	. = list()
	if (driver)
		. += driver
	for (var/atom/movable/A in seats)
		. += A
	for (var/atom/movable/A in team)
		. += A

/obj/structure/vehicle/carriage/proc/free_seat()
	for (var/i = 1 to CARRIAGE_SEATS)
		if (!seats[i])
			return i
	return 0

/obj/structure/vehicle/carriage/proc/is_aboard(atom/movable/A)
	return A && (A == driver || (A in seats) || (A in team))

/obj/structure/vehicle/carriage/proc/team_pull()
	. = 0
	for (var/mob/living/simple_animal/A in team)
		. += draft_animal_pull(A)

// Everything the team draws, in kilograms as item weights are.
/obj/structure/vehicle/carriage/proc/load_weight()
	. = CARRIAGE_EMPTY_WEIGHT
	for (var/atom/movable/A in seats + driver)
		if (ismob(A))
			. += CARRIAGE_PERSON_WEIGHT + bicycle_carried_weight(A)
		else if (A)
			. += CARRIAGE_CARGO_WEIGHT + carriage_cargo_weight(A)

// What a crate or barrel holds. Most items carry no weight of their own, so
// those count by their size, and a stack by how many it holds.
/proc/carriage_cargo_weight(atom/container)
	. = 0
	for (var/obj/item/I in container.contents)
		var/each = I.get_weight()
		if (each <= 0)
			each = I.w_class
		if (istype(I, /obj/item/stack))
			var/obj/item/stack/S = I
			each *= max(1, S.amount / 5)
		. += each
		if (!istype(I, /obj/item/weapon/gun/projectile) && !istype(I, /obj/item/ammo_magazine))
			. += carriage_cargo_weight(I)
	if (container.reagents)
		. += container.reagents.total_volume / 10

/obj/structure/vehicle/carriage/proc/load_ratio()
	var/pull = team_pull()
	if (pull <= 0)
		return INFINITY
	return load_weight() / (pull * CARRIAGE_PULL_CAPACITY)

// Takes on board: a seat for a person or cargo, the driver's bench, or harness.
/obj/structure/vehicle/carriage/proc/take_seat(atom/movable/A, seat)
	A.forceMove(loc)
	seats[seat] = A
	if (isliving(A))
		var/mob/living/M = A
		M.settle_on_tile()
		M.buckled = src
		M.update_canmove()
		ontop |= M
	else
		var/obj/O = A
		O.anchored = TRUE
		O.density = FALSE
		O.layer = layer + 0.01
		ontop_o |= O
	place_at(A, seat_point(seat))

/obj/structure/vehicle/carriage/proc/take_reins(mob/living/human/H)
	if (!H.put_in_active_hand(dwheel))
		to_chat(H, SPAN_WARNING("You need a free hand for the reins."))
		return FALSE
	H.stop_pulling()
	H.forceMove(loc)
	H.settle_on_tile()
	driver = H
	H.driver = TRUE
	H.driver_vehicle = src
	buckled_mob = H
	H.buckled = src
	H.update_canmove()
	ontop |= H
	place_at(H, seat_point(0))
	return TRUE

/obj/structure/vehicle/carriage/proc/hitch(mob/living/simple_animal/A)
	A.forceMove(loc)
	A.settle_on_tile()
	A.buckled = src
	A.update_canmove()
	team += A
	ontop |= A
	lay_out()

// Lets anything aboard go: back on its own feet beside the carriage.
/obj/structure/vehicle/carriage/proc/let_off(atom/movable/A, turf/to_turf = null)
	if (!A)
		return
	A.release_carriage_glide()
	var/index = seats.Find(A)
	if (index)
		seats[index] = null
	if (A in team)
		team -= A
		stopmovementloop() // the team halts while an animal is taken out
	ontop -= A
	ontop_o -= A
	if (A == driver)
		var/mob/living/human/H = driver
		if (dwheel && dwheel.loc == H)
			H.remove_from_mob(dwheel)
			dwheel.forceMove(src)
		H.driver = FALSE
		H.driver_vehicle = null
		driver = null
		buckled_mob = null
		stopmovementloop()
		H.update_icons()
	A.pixel_x = initial(A.pixel_x)
	A.pixel_y = initial(A.pixel_y)
	if (isliving(A))
		var/mob/living/M = A
		if (M.buckled == src)
			M.buckled = null
		M.anchored = initial(M.anchored)
		M.update_canmove()
	else if (isobj(A))
		var/obj/O = A
		O.anchored = initial(O.anchored)
		O.density = initial(O.density)
		O.layer = initial(O.layer)
	if (!to_turf && !QDELETED(src))
		to_turf = beside_turf(A)
	if (to_turf && !QDELETED(A))
		A.forceMove(to_turf)
	if (team_pull() <= 0)
		stopmovementloop()

// A clear turf next to the carriage, or its own corner when there is none.
/obj/structure/vehicle/carriage/proc/beside_turf(atom/movable/A)
	if (!isturf(loc))
		return null
	var/list/mine = cells_at(loc, facing)
	if (!mine)
		return get_turf(src)
	var/list/candidates = list()
	for (var/turf/T in mine)
		for (var/d in cardinal)
			var/turf/N = get_step(T, d)
			if (N && !(N in mine) && !(N in candidates) && !cell_refusal(N, FALSE))
				candidates += N
	if (!candidates.len)
		return get_turf(src)
	// The side the thing is drawn nearest to.
	var/px = loc.x * world.icon_size + A.pixel_x + 16
	var/py = loc.y * world.icon_size + A.pixel_y + 16
	var/turf/best = null
	var/best_dist = INFINITY
	for (var/turf/T in candidates)
		var/d = abs(T.x * world.icon_size + 16 - px) + abs(T.y * world.icon_size + 16 - py)
		if (d < best_dist)
			best = T
			best_dist = d
	return best

// Drops anything that is no longer really aboard (moved away, deleted, dead
// animals are kept until the next step stops the carriage).
/obj/structure/vehicle/carriage/proc/check_aboard()
	for (var/atom/movable/A in everything_aboard())
		var/mob/living/M = A
		if (QDELETED(A) || A.loc != loc || (istype(M) && M.buckled != src))
			let_off(A, QDELETED(A) ? null : get_turf(A))
	for (var/i = 1 to CARRIAGE_SEATS)
		var/atom/movable/A = seats[i]
		if (A && QDELETED(A))
			seats[i] = null
	lay_out()

/obj/structure/vehicle/carriage/safety_check()
	safety_timer = null
	if (gcDestroyed || persistence_saved_atom_construction)
		return
	check_aboard()
	if (moving && !driver_ready())
		stopmovementloop()
	release_stale_ride_glides()
	safety_timer = addtimer(CALLBACK(src, PROC_REF(safety_check)), 20, TIMER_STOPPABLE)

/obj/structure/vehicle/carriage/unbuckle_mob()
	if (driver)
		var/mob/living/M = driver
		let_off(M)
		return M
	return null

/obj/structure/vehicle/carriage/user_unbuckle_mob(mob/user)
	if (is_aboard(user))
		let_off(user)
		return user
	return null

/obj/structure/vehicle/carriage/controls_released(mob/living/human/H)
	stopmovementloop()

/obj/structure/vehicle/carriage/take_driver_seat(mob/living/human/user)
	var/index = seats.Find(user)
	if (index)
		seats[index] = null
	driver = user
	user.driver = TRUE
	user.driver_vehicle = src
	buckled_mob = user
	user.buckled = src
	ontop |= user
	lay_out()

/obj/structure/vehicle/carriage/driver_died(mob/living/human/H)
	if (H != driver)
		return FALSE
	let_off(H, get_turf(src))
	return TRUE

// ---- Clicks ----

/obj/structure/vehicle/carriage/MouseDrop_T(atom/A, mob/living/human/user)
	if (!istype(user) || !ismovable(A) || user.incapacitated() || !Adjacent(user))
		return
	if (A != user && (!user.Adjacent(A) || !Adjacent(A)))
		return
	var/atom/movable/M = A
	// Something already aboard: take it off.
	if (is_aboard(M))
		if (M == user)
			return attack_hand(user)
		if (!can_handle(user))
			return
		user.visible_message(SPAN_NOTICE("[user] starts taking [M] off \the [src]..."), SPAN_NOTICE("You start taking [M] off \the [src]..."))
		if (do_after(user, (M in team) ? 40 : 30, src) && is_aboard(M))
			let_off(M, get_turf(user))
			user.visible_message(SPAN_NOTICE("[user] takes [M] off \the [src]."), SPAN_NOTICE("You take [M] off \the [src]."))
		return
	if (M == user)
		if (user.driver || user.buckled || user.anchored)
			return
		var/as_driver = !driver
		if (!as_driver && !free_seat())
			to_chat(user, SPAN_WARNING("\The [src] is full."))
			return
		user.visible_message(SPAN_NOTICE("[user] starts climbing onto \the [src]..."), SPAN_NOTICE("You start climbing onto \the [src]..."))
		if (!do_after(user, 30, src) || user.buckled || !Adjacent(user))
			return
		if (as_driver && !driver)
			if (take_reins(user))
				user.visible_message(SPAN_NOTICE("[user] takes the reins of \the [src]."), SPAN_NOTICE("You take the reins. [driving_hint()]"))
			return
		var/seat = free_seat()
		if (seat)
			take_seat(user, seat)
			user.visible_message(SPAN_NOTICE("[user] sits on \the [src]."), SPAN_NOTICE("You sit on \the [src]. Click it to get off."))
		return
	if (istype(M, /mob/living/simple_animal) && is_draft_animal(M))
		var/mob/living/simple_animal/SA = M
		var/why = hitch_refusal(SA)
		if (why)
			to_chat(user, SPAN_WARNING(why))
			return
		user.visible_message(SPAN_NOTICE("[user] starts putting [SA] in harness..."), SPAN_NOTICE("You start putting [SA] in harness..."))
		if (!do_after(user, 30, src) || hitch_refusal(SA) || !Adjacent(SA))
			return
		if (!can_fit_lane(team.len + 1))
			to_chat(user, SPAN_WARNING("There is no room ahead of \the [src] for another animal."))
			return
		hitch(SA)
		user.visible_message(SPAN_NOTICE("[user] puts [SA] in harness to \the [src]."), SPAN_NOTICE("You put [SA] in harness. The team pulls [team_pull()]."))
		return
	if (isliving(M) || (istype(M, /obj/structure) && can_load(M)))
		if (!free_seat())
			to_chat(user, SPAN_WARNING("\The [src] is full."))
			return
		if (isliving(M))
			var/mob/living/L = M
			if (L.buckled || L.anchored)
				return
		user.visible_message(SPAN_NOTICE("[user] starts putting [M] on \the [src]..."), SPAN_NOTICE("You start putting [M] on \the [src]..."))
		if (!do_after(user, 30, src) || is_aboard(M) || !Adjacent(M))
			return
		if (istype(M, /obj/structure) && (!can_load(M) || !M.persistence_set_loc(loc)))
			return
		var/seat = free_seat()
		if (seat)
			take_seat(M, seat)
			user.visible_message(SPAN_NOTICE("[user] puts [M] on \the [src]."), SPAN_NOTICE("You put [M] on \the [src]."))

/obj/structure/vehicle/carriage/proc/can_handle(mob/living/human/user)
	return user && !user.incapacitated() && Adjacent(user)

/obj/structure/vehicle/carriage/proc/can_load(obj/structure/O)
	return istype(O) && O != src && !O.anchored && !istype(O, /obj/structure/vehicle) && !istype(O, /obj/structure/vehicleparts) && !O.buckled_mob && O.bound_width <= world.icon_size && O.bound_height <= world.icon_size

/obj/structure/vehicle/carriage/proc/hitch_refusal(mob/living/simple_animal/A)
	if (!is_draft_animal(A) || A.stat == DEAD)
		return "That animal cannot pull \the [src]."
	if (A in team)
		return "It is already in harness."
	if (A.buckled || A.rider || A.ride)
		return "It is tied up or ridden."
	if (team.len >= CARRIAGE_MAX_TEAM)
		return "\The [src] has a full team."
	if (team.len && istype(A, /mob/living/simple_animal/horse) != istype(team[1], /mob/living/simple_animal/horse))
		return "Horses and oxen do not pull well together. Use one kind for the team."
	return null

// TRUE when a team of this many would fit the lane ahead.
/obj/structure/vehicle/carriage/proc/can_fit_lane(count)
	if (!isturf(loc))
		return FALSE
	var/ranks = round((count + 1) / 2)
	var/depth = ceil((2 + ranks * team_rank_length()) / world.icon_size)
	var/list/now = cells_at(loc, facing)
	var/list/after = cells_at(loc, facing, depth)
	if (!after)
		return FALSE
	// Animals waiting to be harnessed may stand there; only the ground counts.
	for (var/turf/T in after - now)
		if (cell_refusal(T, FALSE, FALSE))
			return FALSE
	return TRUE

/obj/structure/vehicle/carriage/attack_hand(mob/living/human/user)
	if (!istype(user))
		return
	if (retake_controls(user))
		return
	if (is_aboard(user))
		user.visible_message(SPAN_NOTICE("[user] starts getting off \the [src]..."), SPAN_NOTICE("You start getting off \the [src]..."))
		if (do_after(user, leave_time, src) && is_aboard(user))
			let_off(user)
			user.visible_message(SPAN_NOTICE("[user] gets off \the [src]."), SPAN_NOTICE("You get off \the [src]."))
		return
	var/list/cargo = list()
	for (var/obj/O in seats)
		cargo += O
	if (!cargo.len)
		to_chat(user, SPAN_NOTICE(status_text()))
		return
	var/obj/O = cargo[1]
	if (cargo.len > 1)
		O = WWinput(user, "What do you take off?", "Unload [src]", cargo[1], cargo)
	if (!O || !(O in seats) || !can_handle(user))
		return
	if (do_after(user, 15, src) && (O in seats))
		let_off(O, get_turf(user))
		user.visible_message(SPAN_NOTICE("[user] takes [O] off \the [src]."), SPAN_NOTICE("You take [O] off \the [src]."))

/obj/structure/vehicle/carriage/attackby(obj/item/W, mob/living/human/user)
	if (W == dwheel)
		return attack_hand(user)
	return ..()

/obj/structure/vehicle/carriage/proc/driving_hint()
	return "Use the reins to urge the team on; their secondary action reins in. Direction keys steer."

/obj/structure/vehicle/carriage/proc/status_text()
	var/pull = team_pull()
	var/list/lines = list()
	if (!team.len)
		lines += "No animals are in harness."
	else
		lines += "Team: [team.len] animal\s, pulling [pull]."
		if (pull > 0)
			var/ratio = load_ratio()
			if (ratio > CARRIAGE_MAX_LOAD_RATIO)
				lines += "It is loaded too heavily for this team to move."
			else
				lines += "Top pace: [carriage_gear_names[carriage_top_gear(pull)]][ratio > 1 ? ", slowed by its load" : ""]."
	if (gear)
		lines += "It is going at a [carriage_gear_names[gear]]."
	var/riders = 0
	var/cargo = 0
	for (var/atom/movable/A in seats)
		if (ismob(A))
			riders++
		else
			cargo++
	lines += "Seats: [riders] taken by passengers, [cargo] by cargo, [CARRIAGE_SEATS - riders - cargo] free."
	return jointext(lines, " ")

/obj/structure/vehicle/carriage/examine(mob/user, distance = -1)
	. = ..()
	to_chat(user, SPAN_NOTICE(status_text()))
	if (craft && craft.register && craft.register.party)
		to_chat(user, SPAN_NOTICE("It is registered to [party_train_party_name(craft.register.party)]. Right-click it and choose Vehicle Papers to read its papers."))
	else
		to_chat(user, SPAN_NOTICE("Right-click it and choose Vehicle Papers to register it."))

// ---- Driving ----

/obj/structure/vehicle/carriage/proc/driver_ready()
	if (!driver || driver.stat != CONSCIOUS || driver.ssd_check() || !isturf(loc))
		return FALSE
	if (driver.driver_vehicle != src || driver.buckled != src || driver.loc != loc)
		return FALSE
	if (driver.incapacitated(INCAPACITATION_DISABLED|INCAPACITATION_RESTRAINED))
		return FALSE
	return dwheel && dwheel.loc == driver && (driver.l_hand == dwheel || driver.r_hand == dwheel)

// The reins: urge the team one gear faster, starting it if it stands.
/obj/structure/vehicle/carriage/proc/urge(mob/living/human/H)
	if (H != driver || !driver_ready())
		return
	if (!carriage_papers_allow(H))
		return
	if (H != driver || !driver_ready())
		return
	var/pull = team_pull()
	if (pull <= 0)
		to_chat(H, SPAN_WARNING("There is nothing in harness to pull \the [src]."))
		return
	if (load_ratio() > CARRIAGE_MAX_LOAD_RATIO)
		to_chat(H, SPAN_WARNING("The team strains, but \the [src] is too heavy for it to move. Unload it or harness more animals."))
		return
	var/top = carriage_top_gear(pull)
	if (gear >= top)
		to_chat(H, SPAN_NOTICE("The team is already at its best pace, a [carriage_gear_names[gear]]."))
		return
	gear++
	to_chat(H, SPAN_NOTICE("You shake the reins. The team goes at a [carriage_gear_names[gear]]."))
	if (!moving)
		startmovementloop()

// The reins' secondary action: one gear slower, stopping from a walk.
/obj/structure/vehicle/carriage/proc/rein_in(mob/living/human/H)
	if (H != driver)
		return
	if (gear <= 1)
		stopmovementloop()
		to_chat(H, SPAN_NOTICE("You rein in. The team stops."))
		return
	gear--
	to_chat(H, SPAN_NOTICE("You rein in to a [carriage_gear_names[gear]]."))

/obj/structure/vehicle/carriage/processmove(m_dir = null)
	return

/obj/structure/vehicle/carriage/startmovementloop()
	if (moving || !gear || !driver_ready())
		return
	moving = TRUE
	movement_processes = 1
	next_step = max(next_step, world.time)
	step_timer = addtimer(CALLBACK(src, PROC_REF(movementloop)), max(world.tick_lag, next_step - world.time), TIMER_STOPPABLE)

/obj/structure/vehicle/carriage/movementloop()
	step_timer = null
	if (!moving || stepping || !gear || !driver_ready())
		stopmovementloop()
		return
	stepping = TRUE
	var/success = FALSE
	try
		success = do_move(facing)
	catch (var/exception/E)
		stepping = FALSE
		stopmovementloop()
		throw E
	stepping = FALSE
	if (!success || !moving)
		stopmovementloop()
		return
	step_timer = addtimer(CALLBACK(src, PROC_REF(movementloop)), max(world.tick_lag, next_step - world.time), TIMER_STOPPABLE)

/obj/structure/vehicle/carriage/stopmovementloop()
	moving = FALSE
	gear = 0
	movement_processes = 0
	if (step_timer)
		deltimer(step_timer)
		step_timer = null
	release_carriage_glides()

// Why this turf stops the carriage (a phrase), or null. With hurt set, people
// and small animals in the way are run into; without count_mobs only the
// ground and structures count.
/obj/structure/vehicle/carriage/proc/cell_refusal(turf/T, hurt = FALSE, count_mobs = TRUE)
	if (!T)
		return "the edge of the world"
	if (T.density)
		return "\the [T] is in the way"
	if (istype(T, /turf/floor/beach/water/deep) || istype(T, /turf/floor/broken_floor))
		var/bridged = FALSE
		for (var/obj/covers/C in T)
			if (!C.density && !C.wall)
				bridged = TRUE
		if (!bridged)
			return "the water is too deep"
	for (var/obj/O in T)
		if (O == src || is_aboard(O) || !O.density)
			continue
		if (istype(O, /obj/structure) || istype(O, /obj/covers))
			return "\the [O] is in the way"
	for (var/mob/living/L in T)
		if (!count_mobs || is_aboard(L) || (L.stat == DEAD && !L.density))
			continue
		if (ishuman(L))
			if (hurt)
				run_into(L)
			return "[L] is in the way"
		if (istype(L, /mob/living/simple_animal))
			var/mob/living/simple_animal/SA = L
			if (SA.mob_size >= MOB_MEDIUM || !hurt)
				if (hurt)
					run_into(L)
				return "\the [SA] is in the way"
			run_into(L)
	var/area/A = get_area(T)
	if (map && A && map.caribbean_blocking_area_types.Find(A.type))
		if (!map.faction1_can_cross_blocks() && !map.faction2_can_cross_blocks())
			return "you cannot cross there yet"
	if (map && driver && map.check_caribbean_block(driver, T))
		return "you cannot cross there yet"
	return null

/obj/structure/vehicle/carriage/proc/run_into(mob/living/L)
	var/hit = rand(4, 9) * max(1, gear)
	if (ishuman(L))
		var/mob/living/human/H = L
		H.adjustBruteLoss(hit)
		if (gear >= 2)
			H.Weaken(rand(2, 4))
	else
		var/mob/living/simple_animal/SA = L
		SA.adjustBruteLoss(hit)
	visible_message(SPAN_WARNING("\The [src] runs into [L]!"))

// The pace for the next step from start to target, before the schedule.
/obj/structure/vehicle/carriage/proc/step_interval(turf/start, turf/target)
	var/interval = carriage_step_delay(gear, load_ratio())
	if (!target.terrain_smoothed())
		interval *= 1.15
	if (target.has_snow_cover() && !target.terrain_floor_covered())
		interval += 1.5
	if (istype(target, /turf/floor/beach/water))
		interval *= 1.5
	interval += terrain_slope_delay(start, target, interval)
	return clamp(interval, CARRIAGE_FASTEST_STEP, CARRIAGE_SLOWEST_STEP)

/obj/structure/vehicle/carriage/do_vehicle_check()
	return driver_ready() && team_pull() > 0

/obj/structure/vehicle/carriage/do_move(m_dir = null, interval = null)
	if (!moving || !gear || !(m_dir in cardinal) || world.time < next_step || !isturf(loc))
		return FALSE
	// Dead animals are cut out of the harness; the rest must still pull.
	for (var/mob/living/simple_animal/A in team.Copy())
		if (A.stat == DEAD || QDELETED(A))
			visible_message(SPAN_WARNING("The dead [A.name] is cut loose from \the [src]!"))
			let_off(A, get_turf(src))
			return FALSE
	if (!do_vehicle_check())
		return FALSE
	var/ratio = load_ratio()
	if (ratio > CARRIAGE_MAX_LOAD_RATIO)
		refuse("\The [src] is too heavy for the team.")
		return FALSE
	gear = min(gear, carriage_top_gear(team_pull()))
	if (!gear)
		return FALSE
	var/turf/start = loc
	var/turf/target = get_step(start, m_dir)
	var/list/now = cells_at(start, facing)
	var/list/after = cells_at(target, facing)
	if (!target || !now || !after)
		refuse("\The [src] cannot go further that way.")
		return FALSE
	for (var/turf/T in after - now)
		var/why = cell_refusal(T, TRUE)
		if (why)
			refuse("\The [src] stops: [why].")
			health -= rand(1, 3) * gear
			return FALSE
	interval = step_interval(start, target)
	vehicle_m_delay = interval
	// Timers land on whole server ticks. Keep to the schedule while it is
	// less than one step behind, so late ticks do not stretch the pace.
	var/due = next_step
	if (due < world.time - interval)
		due = world.time
	next_step = due + interval
	var/datum/carriage_glide_lease/lease = claim_ride_glides(m_dir, interval)
	try
		for (var/atom/movable/A in everything_aboard())
			A.forceMove(target)
		forceMove(target)
	catch (var/exception/E)
		lease.release()
		throw E
	for (var/atom/movable/member in lease.members)
		member.carriage_glide_step = null
	feed_team(terrain_step_levels(start, target))
	lay_out()
	if (craft)
		craft.on_hop(start)
	return loc == target

// Pulling makes the team hungry, more so uphill; harness halves it.
/obj/structure/vehicle/carriage/proc/feed_team(levels)
	var/hill = levels > 0 ? 1 + levels * 0.5 : 1
	for (var/mob/living/simple_animal/A in team)
		A.simplehunger -= A.animal_draft_hunger_cost() * hill

/obj/structure/vehicle/carriage/claim_ride_glides(m_dir, interval)
	. = ..()
	var/datum/carriage_glide_lease/lease = .
	var/turf/destination = get_step(src, m_dir)
	if (destination)
		for (var/atom/movable/A in everything_aboard())
			if (!(A in lease.members))
				lease.claim(A, interval, m_dir, destination)

/obj/structure/vehicle/carriage/release_stale_ride_glides()
	var/datum/carriage_glide_lease/lease = carriage_glide
	if (lease)
		for (var/atom/movable/A in lease.members.Copy())
			if (A != src && (!is_aboard(A) || A.loc != loc))
				A.release_carriage_glide()
	if (!moving)
		release_carriage_glides()

#undef CARRIAGE_SEATS
#undef CARRIAGE_MAX_TEAM
#undef CARRIAGE_PULL_CAPACITY
#undef CARRIAGE_EMPTY_WEIGHT
#undef CARRIAGE_PERSON_WEIGHT
#undef CARRIAGE_CARGO_WEIGHT
#undef CARRIAGE_MAX_LOAD_RATIO
#undef CARRIAGE_SLOWEST_STEP
#undef CARRIAGE_FASTEST_STEP
#undef CARRIAGE_STARVING_HUNGER
