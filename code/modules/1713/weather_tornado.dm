// Local surface gusts and a bounded, storm-owned land tornado. The air grid
// does not model vertical profiles: steering flow minus surface flow is a
// shear proxy for play, not a meteorological forecast.
#define TORNADO_LEAD 450
#define TORNADO_LIFE 1050
#define TORNADO_LOOKAHEAD 550
#define TORNADO_COOLDOWN 18000
#define TORNADO_RADIUS 5
#define TORNADO_ROOM_LIMIT 64
#define TORNADO_STEP_BUDGET 32
#define TORNADO_TOTAL_BUDGET 512

var/global/datum/weather_tornado/weather_tornado = null
var/global/weather_tornado_cooldown_until = 0

/datum/weather_system
	var/tornado_support = 0
	var/tornado_spawned = FALSE

/datum/weather_tornado
	should_save = FALSE
	var/datum/weather_system/parent_storm
	var/z
	var/landfall
	var/expires
	var/origin_x
	var/origin_y
	var/vel_x
	var/vel_y
	var/spin
	var/list/warned = list()
	var/list/affected = list()
	var/image/funnel

/datum/weather_tornado/proc/x_at(at)
	return origin_x + vel_x * (at - landfall)

/datum/weather_tornado/proc/y_at(at)
	return origin_y + vel_y * (at - landfall)

/datum/weather_tornado/proc/strength(at)
	if (at < landfall || at >= expires)
		return 0
	return min(1, 0.4 + (at - landfall) / 180, (expires - at) / 220)

// A tornado has a narrow rotating core and an inflow, both fading away from
// the funnel. Returns a local wind contribution, never feeds the air grid.
/datum/weather_tornado/proc/gust(turf/T, at)
	if (!T || T.z != z)
		return null
	var/dx = T.x - x_at(at)
	var/dy = T.y - y_at(at)
	var/r = sqrt(dx * dx + dy * dy)
	var/power = strength(at)
	if (!power || r >= TORNADO_RADIUS)
		return null
	if (r < 0.25)
		return list(vel_x * 250, vel_y * 250)
	var/band = min(r / 1.5, (TORNADO_RADIUS - r) / (TORNADO_RADIUS - 1.5))
	var/tangent = 58 * power * band / r
	var/inward = 0.28 * tangent
	return list(-spin * dy * tangent - dx * inward, spin * dx * tangent - dy * inward)

/datum/weather_tornado/proc/threatens(turf/T, at)
	if (!T || T.z != z || at >= expires)
		return FALSE
	var/start = max(at, landfall)
	var/end = min(expires, at + TORNADO_LOOKAHEAD)
	if (end < start)
		return FALSE
	var/dx = T.x - x_at(start)
	var/dy = T.y - y_at(start)
	var/velocity_squared = vel_x * vel_x + vel_y * vel_y
	var/ahead = velocity_squared ? clamp((dx * vel_x + dy * vel_y) / velocity_squared, 0, end - start) : 0
	dx -= vel_x * ahead
	dy -= vel_y * ahead
	// Margin for players on the outer edge of the projected track.
	return dx * dx + dy * dy <= (TORNADO_RADIUS + 2) ** 2

/proc/weather_tornado_land(turf/T)
	if (!T || (!istype(T, /turf/floor) && !istype(T, /turf/wall)) || building_open_turf(T) || istype(T, /turf/floor/beach/water) || istype(T, /turf/floor/lava))
		return FALSE
	var/area/caribbean/A = T.loc
	return istype(A) && !istype(A, /area/caribbean/void) && !istype(T, /turf/floor/dirt/underground)

// The same rain-sky gate as lightning, but classify this parent rather than
// whichever overlapping storm currently owns the tile's general weather.
/proc/weather_tornado_rain_sky(turf/T, strength)
	var/area/caribbean/A = T ? T.loc : null
	if (!istype(A) || strength < WEATHER_BAND_HEAVY)
		return FALSE
	var/list/state = weather_storm_state(A.climate, strength, TRUE)
	return state && (state[1] == "monsoon" || findtext(state[1], "rain") == 1)

// Require moist, warm inflow, a mature intense convective parent, and both
// speed/directional contrast between surface air and estimated steering flow.
// Return the signed crosswind, which also determines the model's rotation.
/proc/weather_tornado_shear(datum/weather_system/S, turf/T)
	if (!weather_air || !S || S.kind != WEATHER_SYSTEM_STORM || !S.severe || !S.convective || S.power() < 0.8 || !weather_tornado_land(T) || T.density || home_turf_inside(T))
		return 0
	if (!weather_tornado_rain_sky(T, S.strength_at(T.x, T.y)) || weather_air_temp_at(T) < 24 || weather_dew_point_at(T) < 16)
		return 0
	var/track_speed = sqrt(S.vel_x * S.vel_x + S.vel_y * S.vel_y)
	if (track_speed < 0.005)
		return 0
	var/list/surface = weather_wind_vector_at(T)
	var/ux = S.vel_x / track_speed
	var/uy = S.vel_y / track_speed
	var/steering = clamp(track_speed * 650, 15, 28)
	var/dx = ux * steering - surface[1]
	var/dy = uy * steering - surface[2]
	var/crosswind = surface[1] * uy - surface[2] * ux
	return dx * dx + dy * dy >= 144 && abs(crosswind) >= 3 ? crosswind : 0

/proc/weather_tornado_form(datum/weather_system/S, turf/T, shear, at = world.time)
	if (weather_tornado || !S || S.tornado_spawned || !shear || !weather_tornado_land(T))
		return null
	var/datum/weather_tornado/V = new
	V.parent_storm = S
	V.z = T.z
	V.origin_x = T.x
	V.origin_y = T.y
	V.landfall = at + TORNADO_LEAD
	V.expires = V.landfall + TORNADO_LIFE
	V.vel_x = S.vel_x
	V.vel_y = S.vel_y
	V.spin = shear > 0 ? 1 : -1
	S.tornado_spawned = TRUE
	weather_tornado_cooldown_until = at + TORNADO_COOLDOWN
	weather_tornado = V
	return V

// Once per normal weather tick, after the grid updates. No new standalone
// random weather event: each parent must sustain favorable conditions.
/proc/weather_tornado_consider(roll = null)
	if (weather_tornado || world.time < weather_tornado_cooldown_until || !map?.persistence || !weather_fronts_allowed(WEATHER_EXTREME) || persistence_admission_blocked())
		return
	var/list/allowed = map.weather_policy_choices(list(WEATHER_EXTREME))
	if (!(WEATHER_EXTREME in allowed))
		return
	var/z = underground_surface_z()
	for (var/datum/weather_system/S in weather_systems)
		if (!S.convective || !S.severe || S.tornado_spawned)
			continue
		// Sample the warm leading flank, ahead of the model's rain-cooled centre.
		var/x = round(S.centre_x() + S.vel_x * TORNADO_LEAD)
		var/y = round(S.centre_y() + S.vel_y * TORNADO_LEAD)
		var/turf/T = locate(x, y, z)
		var/shear = weather_tornado_shear(S, T)
		S.tornado_support = shear ? min(3, S.tornado_support + 1) : 0
		if (S.tornado_support == 3 && (isnull(roll) ? prob(3) : roll < 3))
			weather_tornado_form(S, T, shear)
			return

// Use room boundaries, but a curtain, glazing, unfinished wall or open door
// is not a windproof boundary. Limit each search and rebuild per impact pulse.
/proc/weather_tornado_solid_edge(turf/T)
	if (!T)
		return FALSE
	if (T.density)
		return TRUE
	for (var/obj/covers/C in T)
		if (C.wall && C.density && !C.incomplete && C.health > 0)
			return TRUE
	for (var/obj/structure/simple_door/D in T)
		if (D.door_seals_room() && !istype(D, /obj/structure/simple_door/key_door/anyone/casement) && !istype(D, /obj/structure/simple_door/key_door/anyone/window_shutters))
			return TRUE
	return FALSE

/proc/weather_tornado_sheltered(turf/start, list/pulse_cache)
	if (!start)
		return TRUE
	if (underground_depth_of(start.z))
		return TRUE
	if (!home_turf_inside(start) || home_turf_bounds_room(start))
		return FALSE
	if (pulse_cache && (start in pulse_cache))
		return pulse_cache[start]
	var/list/room = list(start)
	var/list/seen = list(start)
	var/sealed = TRUE
	for (var/i = 1; i <= room.len && sealed; i++)
		var/turf/T = room[i]
		if ((locate(/obj/roof/thatch) in T) || (locate(/obj/roof/palm) in T) || (locate(/obj/roof/glass) in T))
			sealed = FALSE
			break
		for (var/direction in cardinal)
			var/turf/N = get_step(T, direction)
			if (!N)
				sealed = FALSE
				break
			if (N in seen)
				continue
			seen += N
			if (weather_tornado_solid_edge(N))
				continue
			if (!home_turf_inside(N) || home_turf_bounds_room(N) || room.len >= TORNADO_ROOM_LIMIT)
				sealed = FALSE
				break
			room += N
	if (pulse_cache)
		// Only cache failed searches locally: the next tile may belong to a
		// different enclosure if this search stopped at a doorway or limit.
		if (!sealed)
			pulse_cache[start] = FALSE
		else
			for (var/turf/T in room)
				pulse_cache[T] = TRUE
	return sealed

/datum/weather_tornado/proc/impact(turf/centre, at)
	var/radius = TORNADO_RADIUS
	var/list/shelter = list()
	var/list/mob_targets = list()
	var/list/debris = list()
	var/list/tile_targets = list()
	var/scan_budget = TORNADO_STEP_BUDGET * 8
	// Gather before moving anything, so a pushed atom cannot be acted on twice.
	for (var/turf/T in block(locate(max(1, centre.x-radius), max(1, centre.y-radius), z), locate(min(world.maxx, centre.x+radius), min(world.maxy, centre.y+radius), z)))
		if (!weather_tornado_land(T) || weather_tornado_sheltered(T, shelter))
			continue
		var/list/v = gust(T, at)
		if (!v)
			continue
		var/speed_squared = v[1] * v[1] + v[2] * v[2]
		if (speed_squared < 256)
			continue
		var/tile_budget = 16
		for (var/atom/movable/A in T)
			if (tile_budget-- <= 0 || --scan_budget < 0)
				break
			if (QDELETED(A) || (A in affected))
				continue
			if (isliving(A))
				var/mob/living/L = A
				if (L.stat != DEAD && !L.buckled && !L.anchored && !L.throwing && speed_squared >= 576)
					mob_targets[L] = v
			else if (isitem(A))
				var/obj/item/I = A
				if (!I.anchored && !I.density && !I.pulledby && !I.throwing && I.w_class <= ITEM_SIZE_SMALL)
					debris[I] = v
			else if (speed_squared >= 1444 && (istype(A, /obj/structure/farming/plant) || istype(A, /obj/roof/thatch) || istype(A, /obj/roof/palm)))
				tile_targets[A] = speed_squared
		if (scan_budget <= 0)
			break
	var/budget = TORNADO_STEP_BUDGET
	// Living targets go first. Cap work on busy turf contents and on the track.
	for (var/list/group in list(mob_targets, debris, tile_targets))
		for (var/atom/movable/A in group)
			if (budget-- <= 0 || affected.len >= TORNADO_TOTAL_BUDGET || persistence_admission_blocked())
				return
			if (QDELETED(A) || !isturf(A.loc))
				continue
			if (group == tile_targets)
				affected += A
				if (istype(A, /obj/structure/farming/plant))
					var/obj/structure/farming/plant/P = A
					if (!P.vstatic && P.stage <= P.readyStageMax)
						P.set_dead("wind-battered")
				else
					var/obj/roof/R = A
					// Repairable damage only; this first pass cannot collapse roofs.
					if (R.health > 1)
						R.damage_seasonal_construction(min(8, R.health - 1))
				continue
			var/list/v = group[A]
			var/direction = turn(weather_wind_dir_from_vector(v[1], v[2]), 180)
			var/turf/destination = get_step(A, direction)
			affected += A
			// Use real movement, never teleport through walls or push off land/into shafts.
			if (weather_tornado_land(destination) && !destination.density && !(locate(/obj/structure/multiz/ladder/ww2/tunneltop) in destination) && A.Adjacent(destination))
				step(A, direction)
			if (isliving(A))
				var/mob/living/L = A
				L.Weaken(2)
				to_chat(L, SPAN_WARNING("Rotating winds knock you off balance!"))

/client/var/tmp/image/weather_tornado_shown

/datum/weather_tornado/proc/announce(turf/centre, at)
	if (centre)
		if (!funnel)
			funnel = image('icons/obj/magic_icon.dmi', centre, "gust")
			funnel.mouse_opacity = 0
			funnel.plane = GAME_PLANE
			funnel.layer = MOB_LAYER + 1
			var/matrix/marker_scale = matrix()
			marker_scale.Scale(2, 2)
			funnel.transform = marker_scale
		else if (funnel.loc != centre)
			funnel.loc = centre
	for (var/client/C in clients)
		var/mob/M = C.mob
		var/turf/T = get_turf(M)
		if (isliving(M) && M.stat != DEAD && threatens(T, at) && C.ckey && !(C.ckey in warned))
			warned += C.ckey
			var/dx = x_at(max(at, landfall)) - T.x
			var/dy = y_at(max(at, landfall)) - T.y
			var/where = abs(dx) + abs(dy) < 1 ? "nearby" : "to the [weather_bearing(dx, dy)]"
			to_chat(M, SPAN_DANGER("A funnel [at < landfall ? "is forming" : "is on the ground"] [where]. Its track may pass here shortly! Seek an enclosed room or go below ground."))
		var/turf/eye = get_turf(C.eye) || T
		var/image/show = centre && eye && eye.z == z && get_dist(eye, centre) <= 18 ? funnel : null
		if (C.weather_tornado_shown == show)
			continue
		if (C.weather_tornado_shown)
			C.images -= C.weather_tornado_shown
		C.weather_tornado_shown = show
		if (show)
			C.images += show

/proc/weather_tornado_clear()
	if (!weather_tornado)
		return
	for (var/client/C in clients)
		if (C.weather_tornado_shown)
			C.images -= C.weather_tornado_shown
			C.weather_tornado_shown = null
	qdel(weather_tornado)
	weather_tornado = null

/proc/weather_tornado_step(at = world.time)
	var/datum/weather_tornado/V = weather_tornado
	if (!V)
		return
	// Do not resume a funnel beyond its last warned corridor after a world hold.
	if (persistence_admission_blocked())
		weather_tornado_clear()
		return
	if (at >= V.expires || QDELETED(V.parent_storm) || !(V.parent_storm in weather_systems))
		weather_tornado_clear()
		return
	if (at < V.landfall)
		V.announce(null, at)
		return
	var/turf/T = locate(round(V.x_at(at)), round(V.y_at(at)), V.z)
	if (!weather_tornado_land(T) || V.parent_storm.strength_at(T.x, T.y) < WEATHER_BAND_STEADY)
		weather_tornado_clear()
		return
	V.announce(T, at)
	V.impact(T, at)

#undef TORNADO_LEAD
#undef TORNADO_LIFE
#undef TORNADO_LOOKAHEAD
#undef TORNADO_COOLDOWN
#undef TORNADO_RADIUS
#undef TORNADO_ROOM_LIMIT
#undef TORNADO_STEP_BUDGET
#undef TORNADO_TOTAL_BUDGET
