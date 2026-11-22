// Shared weather across regions (docs/weather-shared.md).
//
// Every region is its own world, so each used to roll its own lows, highs and
// storms, and a storm that reached an edge simply vanished. On the world
// calendar (world_calendar.dm) the regions now share them without sending any
// messages: each region's systems are drawn from a seed of its region id and
// the calendar's 5-minute slot, so every world works out the same systems.
// A world builds its own and, for each neighbour across a map edge
// (world_links / world_sea_links), the neighbour's systems near that edge,
// carried over the edge to the matching stretch of this map. A storm heading
// for the edge therefore rolls on into the next region at the same moment.
//
// Systems drift with the prevailing winds of their latitude: east in the
// middle latitudes, west in the tropics and near the poles. Afternoon
// thunderstorms and heat waves still form locally. An island inside an ocean
// (Gaia, Greenland) takes the ocean's lows and highs, scaled to the island,
// and keeps its own storms, since one ocean storm would cover the island.

#define WEATHER_SHARED_SLOT 3000 // ds of calendar time per seed slot
#define WEATHER_SHARED_LOOKBACK 13 // slots back: longer than any system lives
#define WEATHER_SHARED_CENTRES 5 // the most lows and highs kept over a map
#define WEATHER_SHARED_CENTRE_CHANCE 0.45 // a new low or high per region per slot
#define WEATHER_SHARED_STORM_CHANCE 0.21 // per storm place per slot, times the wet share

/obj/map_metadata
	// This region's id in the world links tables; null keeps local weather.
	var/world_region = null

/obj/map_metadata/persistence_runtime_var(var/key)
	if (key == "world_region")
		return TRUE
	return ..(key)

/datum/weather_system
	var/shared_key = null // set on a storm drawn from the shared seed

// Land id = list(width, height, latitude). The oceans' sizes come from
// world_oceans; their latitudes are here.
var/global/list/weather_region_frames = weather_region_frames_table()
/proc/weather_region_frames_table()
	return list(
	"northamerica" = list(1132, 920, 35),
	"southamerica" = list(848, 1224, -20),
	"gaia" = list(500, 350, 45),
	"europe" = list(846, 572, 50),
	"mediterranean" = list(1280, 396, 38),
	"africa" = list(976, 969, 5),
	"asia" = list(1057, 854, 40),
	"oceania" = list(1212, 728, -25),
	"greenland" = list(760, 816, 72),
	"antarctica" = list(1024, 1024, -78),
	"atlantic" = list(600, 900, 30),
	"pacific" = list(900, 900, 15),
	"indian" = list(600, 600, -15),
	"arctic" = list(1000, 300, 78),
	"southern" = list(1200, 300, -60))

var/global/list/weather_shared_cache = list()
var/global/list/weather_shared_centre_datums = list() // key = /datum/weather_centre
var/global/weather_shared_last_slot = null

/proc/weather_shared_region()
	if (!world_calendar_synced() || !istext(map.world_region) || !weather_region_frames[map.world_region])
		return null
	return map.world_region

/proc/weather_shared_on()
	return !!weather_shared_region()

// The ocean an island sits inside, or null.
/proc/weather_shared_parent(region)
	for (var/ocean in world_insets)
		var/list/boxes = world_insets[ocean]
		if (boxes[region])
			return ocean
	return null

// TRUE when this world's storms come from the shared seed.
/proc/weather_shared_storms_on()
	var/region = weather_shared_region()
	return region && !weather_shared_parent(region)

// ---- the seed ----------------------------------------------------------------

/datum/weather_seed
	var/key = ""
	var/n = 0

/datum/weather_seed/New(seed_key)
	key = seed_key

// 0 to just under 1, the same on every world for the same key.
/datum/weather_seed/proc/next()
	n++
	return text2num(copytext(md5("[key]|[n]"), 1, 7), 16) / 16777216

/datum/weather_seed/proc/between(low, high)
	return low + next() * (high - low)

// list(slot, ds into it) of the calendar now.
/proc/weather_shared_now()
	var/list/now = world_calendar_now()
	var/in_day = round(now[2] / WEATHER_SHARED_SLOT)
	return list(now[1] * (864000 / WEATHER_SHARED_SLOT) + in_day, now[2] - in_day * WEATHER_SHARED_SLOT)

// The season over a region at the start of a slot.
/proc/weather_shared_season(region, slot)
	var/list/frame = weather_region_frames[region]
	var/length = world_calendar_season_minutes()
	var/minutes = world_calendar_fmod(slot * (WEATHER_SHARED_SLOT / 600), length * 4)
	var/index = clamp(round(minutes / length), 0, 3)
	if (frame[3] < 0)
		index = (index + 2) % 4
	return world_calendar_seasons[index + 1]

// Unit vector a system drifts along: east in the middle latitudes, west in
// the tropics and near the poles, give or take 40 degrees.
/proc/weather_shared_course(latitude, datum/weather_seed/R)
	var/bearing = (abs(latitude) >= 30 && abs(latitude) < 60) ? 90 : 270
	bearing += R.between(-40, 40)
	return list(sin(bearing), cos(bearing))

// The lows, highs and storms born over a region in one slot, as lists:
// list("c", key, kind, depth, radius, lifetime, born, x, y, vx, vy) and
// list("s", key, severe, rx, ry, peak, wobble, lifetime, born, x, y, vx, vy),
// born in ds into the slot, x and y where it was then.
/proc/weather_shared_slot(region, slot)
	var/cache_key = "[region]|[slot]"
	var/list/cached = weather_shared_cache[cache_key]
	if (cached)
		return cached
	. = weather_shared_centres_only(region, slot).Copy()
	var/list/frame = weather_region_frames[region]
	var/width = frame[1]
	var/height = frame[2]
	var/datum/weather_seed/R = new("wxs|[region]|[slot]")
	var/season_name = weather_shared_season(region, slot)
	// Storms: as many places as the map holds storms, each a wet roll of the season.
	var/wet_share = 0.5
	var/severe_share = 0
	if (season_name == SEASON_WINTER || season_name == SEASON_SPRING)
		wet_share = 2 / 3
		severe_share = 0.5
	var/places = clamp(round((width * height) / 40000), 1, WEATHER_SYSTEM_MAX)
	for (var/i = 1 to places)
		if (R.next() >= WEATHER_SHARED_STORM_CHANCE * wet_share)
			continue
		var/severe = R.next() < severe_share
		var/size = R.between(35, 91)
		var/rx = size * R.between(0.7, 1)
		var/ry = size * R.between(0.7, 1)
		var/peak = severe ? 1 : R.between(0.55, 1)
		var/wobble = round(R.next() * 360)
		var/lifetime = round(R.between(9000, 24000))
		var/born = round(R.next() * WEATHER_SHARED_SLOT)
		var/list/course = weather_shared_course(frame[3], R)
		var/speed = 0.0125 + 0.007 * R.between(0, 4)
		// It forms on the front of the deepest low about, else anywhere.
		var/list/aim = weather_shared_front(region, slot, born, R)
		if (!aim)
			aim = list(width * R.between(0.1, 0.9), height * R.between(0.1, 0.9))
		var/back = max(rx, ry) + R.next() * 3000 * speed
		lifetime = max(lifetime, round((back + max(rx, ry)) / speed) + 1200)
		. += list(list("s", "s|[cache_key]|[i]", severe, rx, ry, peak, wobble, lifetime, born, aim[1] - course[1] * back, aim[2] - course[2] * back, course[1] * speed, course[2] * speed))
	weather_shared_cache[cache_key] = .

// Where the deepest of a region's own lows rains at a moment (slot, ds into it).
/proc/weather_shared_front(region, slot, at, datum/weather_seed/R)
	var/list/best = null
	var/best_age = 0
	var/best_power = 0
	for (var/back = 0 to WEATHER_SHARED_LOOKBACK)
		var/s = slot - back
		var/list/records = weather_shared_centres_only(region, s)
		for (var/list/C in records)
			if (C[1] != "c" || C[3] != WEATHER_CENTRE_LOW)
				continue
			var/age = back * WEATHER_SHARED_SLOT + at - C[7]
			if (age < 0 || age >= C[6])
				continue
			var/power = C[4] * clamp(min(age / 3000, (C[6] - age) / 3000), 0, 1)
			if (power > best_power)
				best = C
				best_age = age
				best_power = power
	if (!best)
		return null
	var/list/frame = weather_region_frames[region]
	var/cx = best[8] + best[10] * best_age
	var/cy = best[9] + best[11] * best_age
	var/speed = sqrt(best[10] * best[10] + best[11] * best[11])
	var/ux = speed ? best[10] / speed : 1
	var/uy = speed ? best[11] / speed : 0
	var/across = best[5] * R.between(-0.5, 0.5)
	var/ahead = best[5] * 0.4
	return list(clamp(cx + ux * ahead - uy * across, 1, frame[1]), clamp(cy + uy * ahead + ux * across, 1, frame[2]))

// A slot's low or high alone (0 or 1 of them), cached on its own: storms ask
// for the lows about when they form.
/proc/weather_shared_centres_only(region, slot)
	var/cache_key = "C|[region]|[slot]"
	var/list/cached = weather_shared_cache[cache_key]
	if (cached)
		return cached
	. = list()
	weather_shared_cache[cache_key] = .
	var/list/frame = weather_region_frames[region]
	var/datum/weather_seed/R = new("wx|[region]|[slot]")
	var/season_name = weather_shared_season(region, slot)
	if (R.next() >= WEATHER_SHARED_CENTRE_CHANCE)
		return
	var/low_chance = 50
	if (season_name == SEASON_SUMMER)
		low_chance = 35
	else if (season_name == SEASON_WINTER)
		low_chance = 65
	var/kind = R.next() * 100 < low_chance ? WEATHER_CENTRE_LOW : WEATHER_CENTRE_HIGH
	var/depth = kind == WEATHER_CENTRE_LOW ? round(R.between(10, 31)) : round(R.between(8, 21))
	var/radius = round(R.between(0.25, 0.5) * max(frame[1], frame[2])) + 40
	var/lifetime = round(R.between(18000, 36000))
	var/born = round(R.next() * WEATHER_SHARED_SLOT)
	var/list/course = weather_shared_course(frame[3], R)
	var/speed = (0.0125 + 0.007 * R.between(0, 4)) * 0.6
	. += list(list("c", "c|[region]|[slot]", kind, depth, radius, lifetime, born, 1 + R.next() * (frame[1] - 1), 1 + R.next() * (frame[2] - 1), course[1] * speed, course[2] * speed))

// ---- carrying systems over an edge ------------------------------------------

/proc/weather_shared_opposite(side)
	switch (side)
		if ("north") return "south"
		if ("south") return "north"
		if ("east") return "west"
		if ("west") return "east"
	return null

// The stretch of region's side that leads to other: list(from, to), or null.
/proc/weather_shared_segment(region, side, other)
	for (var/list/table in list(world_links, world_sea_links))
		var/list/sides = table[region]
		if (!islist(sides))
			continue
		var/list/stretches = sides[side]
		if (islist(stretches) && islist(stretches[other]))
			return stretches[other]
	return null

// Every way from a neighbour into here: list(neighbour, its side, list(a0, a1),
// our side, list(b0, b1)).
/proc/weather_shared_links(region)
	. = list()
	var/list/seen = list()
	for (var/list/table in list(world_links, world_sea_links))
		var/list/sides = table[region]
		if (!islist(sides))
			continue
		for (var/side in sides)
			var/list/stretches = sides[side]
			if (!islist(stretches))
				continue
			for (var/other in stretches)
				if (!weather_region_frames[other] || seen["[other]|[side]"])
					continue
				var/far_side = weather_shared_opposite(side)
				var/list/theirs = weather_shared_segment(other, far_side, region)
				if (!theirs)
					continue
				seen["[other]|[side]"] = TRUE
				. += list(list(other, far_side, theirs, side, stretches[other]))

// A transform from a neighbour's tiles to ours over one link:
// list(scale, their side, their edge length, a0, our side, our width, our height, b0, our edge length, a1, b1).
/proc/weather_shared_transform(list/link, region)
	var/list/theirs = weather_region_frames[link[1]]
	var/list/ours = weather_region_frames[region]
	var/their_len = (link[2] == "east" || link[2] == "west") ? theirs[2] : theirs[1]
	var/our_len = (link[4] == "east" || link[4] == "west") ? ours[2] : ours[1]
	var/list/a = link[3]
	var/list/b = link[5]
	if (a[2] <= a[1] || b[2] <= b[1])
		return null
	var/scale = ((b[2] - b[1]) * our_len) / ((a[2] - a[1]) * their_len)
	return list(scale, link[2], their_len, a[1], link[4], ours[1], ours[2], b[1], our_len, a[2], theirs[1], theirs[2])

// list(along, depth) of a neighbour point against its linked edge.
/proc/weather_shared_edge_place(list/T, x, y)
	switch (T[2])
		if ("east") return list(y, T[11] - x)
		if ("west") return list(y, x)
		if ("north") return list(x, T[12] - y)
	return list(x, y)

// A neighbour point in our tiles.
/proc/weather_shared_carry_point(list/T, x, y)
	var/list/place = weather_shared_edge_place(T, x, y)
	var/along = T[8] * T[9] + (place[1] - T[4] * T[3]) * T[1]
	var/out = place[2] * T[1]
	switch (T[5])
		if ("west") return list(1 - out, along)
		if ("east") return list(T[6] + out, along)
		if ("south") return list(along, 1 - out)
	return list(along, T[7] + out)

// A neighbour vector in our tiles: the compass is kept, the size scaled.
/proc/weather_shared_carry_vector(list/T, vx, vy)
	return list(vx * T[1], vy * T[1])

// TRUE when a neighbour point lies off the linked stretch's edge, within reach.
/proc/weather_shared_near_edge(list/T, x, y, reach)
	var/list/place = weather_shared_edge_place(T, x, y)
	var/start = T[4] * T[3] - reach
	var/stop = T[10] * T[3] + reach
	return place[1] >= start && place[1] <= stop && place[2] < reach

// An island's tiles from its ocean's: list(scale x, scale y, box x0, box y0).
/proc/weather_shared_inset(region, ocean)
	var/list/boxes = world_insets[ocean]
	var/list/box = boxes[region]
	var/list/frame = weather_region_frames[region]
	return list(frame[1] / (box[3] - box[1] + 1), frame[2] / (box[4] - box[2] + 1), box[1], box[2])

// ---- what this world sees ----------------------------------------------------

// Every shared system over or near this map now, in this map's tiles:
// list(kind "c"/"s", key, record, age, x at birth, y at birth, vx, vy, scale).
/proc/weather_shared_systems(region = null)
	if (isnull(region))
		region = weather_shared_region()
	. = list()
	if (!region)
		return
	var/list/now = weather_shared_now()
	var/slot = now[1]
	var/in_slot = now[2]
	var/list/frame = weather_region_frames[region]
	var/parent = weather_shared_parent(region)
	var/list/sources = list()
	if (parent)
		sources += list(list(parent, null))
	else
		sources += list(list(region, null))
		for (var/list/link in weather_shared_links(region))
			var/list/T = weather_shared_transform(link, region)
			if (T)
				sources += list(list(link[1], T))
	for (var/list/source in sources)
		var/from = source[1]
		var/list/T = source[2]
		for (var/back = 0 to WEATHER_SHARED_LOOKBACK)
			for (var/list/rec in weather_shared_slot(from, slot - back))
				if (parent && rec[1] != "c")
					continue // an island keeps its own storms
				var/is_centre = rec[1] == "c"
				var/born = is_centre ? rec[7] : rec[9]
				var/lifetime = is_centre ? rec[6] : rec[8]
				var/age = back * WEATHER_SHARED_SLOT + in_slot - born
				if (age < 0 || age >= lifetime)
					continue
				var/x0 = is_centre ? rec[8] : rec[10]
				var/y0 = is_centre ? rec[9] : rec[11]
				var/vx = is_centre ? rec[10] : rec[12]
				var/vy = is_centre ? rec[11] : rec[13]
				var/size = is_centre ? rec[5] : max(rec[4], rec[5])
				var/scale = 1
				if (parent)
					var/list/I = weather_shared_inset(region, parent)
					x0 = (x0 - I[3]) * I[1] + 1
					y0 = (y0 - I[4]) * I[2] + 1
					vx *= I[1]
					vy *= I[2]
					scale = sqrt(I[1] * I[2])
				else if (T)
					var/reach = is_centre ? size * 2 : size * 1.2 + sqrt(vx * vx + vy * vy) * 6000
					if (!weather_shared_near_edge(T, x0 + vx * age, y0 + vy * age, reach))
						continue
					var/list/p = weather_shared_carry_point(T, x0, y0)
					var/list/v = weather_shared_carry_vector(T, vx, vy)
					x0 = p[1]
					y0 = p[2]
					vx = v[1]
					vy = v[2]
					scale = T[1]
				// Still over or near this map?
				var/x = x0 + vx * age
				var/y = y0 + vy * age
				var/r = size * scale * (is_centre ? 2 : 1.2)
				var/lead = is_centre ? 0 : sqrt(vx * vx + vy * vy) * 6000
				if (x < -r - lead || y < -r - lead || x > frame[1] + r + lead || y > frame[2] + r + lead)
					continue
				. += list(list(rec[1], rec[2], rec, age, x0, y0, vx, vy, scale))

// Keeps this world's lows, highs and storms on the shared set (weather_fronts.dm
// calls this each weather tick on a synced map).
/proc/weather_shared_sync()
	var/list/systems = weather_shared_systems()
	var/list/now = weather_shared_now()
	if (weather_shared_last_slot != now[1])
		weather_shared_last_slot = now[1]
		weather_shared_prune(now[1])
	var/list/centres = list()
	var/list/storms = list()
	for (var/list/S in systems)
		if (S[1] == "c")
			centres += list(S)
		else
			storms += list(S)
	weather_shared_sync_centres(centres)
	if (weather_shared_storms_on() && map.weather_policy_valid() && (WEATHER_WET in map.valid_weather_types))
		weather_shared_sync_storms(storms)

/proc/weather_shared_sync_centres(list/centres)
	// The strongest few, by depth and age.
	var/list/ranked = list()
	for (var/list/S in centres)
		var/list/rec = S[3]
		var/age = S[4]
		var/power = rec[4] * clamp(min(age / 3000, (rec[6] - age) / 3000), 0, 1)
		var/at = 1
		while (at <= ranked.len)
			var/list/other = ranked[at]
			if (other[2] < power)
				break
			at++
		ranked.Insert(at, null)
		ranked[at] = list(S, power)
	if (ranked.len > WEATHER_SHARED_CENTRES)
		ranked.Cut(WEATHER_SHARED_CENTRES + 1)
	var/list/keep = list()
	for (var/list/pair in ranked)
		var/list/S = pair[1]
		var/list/rec = S[3]
		var/datum/weather_centre/C = weather_shared_centre_datums[S[2]]
		if (!C || !(C in weather_centres))
			C = new
			C.id = ++weather_centre_serial
			weather_centres += C
			weather_shared_centre_datums[S[2]] = C
		C.kind = rec[3]
		C.depth = rec[4]
		C.radius = rec[5] * S[9]
		C.lifetime = rec[6]
		C.born = world.time - S[4]
		C.origin_time = C.born
		C.origin_x = S[5]
		C.origin_y = S[6]
		C.vel_x = S[7]
		C.vel_y = S[8]
		keep[S[2]] = C
	weather_shared_centre_datums = keep
	// Nothing else holds a centre on a synced map.
	weather_centres.Cut()
	for (var/key in keep)
		weather_centres += keep[key]

/proc/weather_shared_sync_storms(list/storms)
	var/list/present = list()
	for (var/datum/weather_system/S in weather_systems)
		if (S.shared_key)
			present[S.shared_key] = S
	var/list/wanted = list()
	for (var/list/X in storms)
		var/list/rec = X[3]
		var/key = X[2]
		wanted[key] = TRUE
		var/datum/weather_system/S = present[key]
		if (!S)
			if (weather_systems.len >= WEATHER_SYSTEM_MAX)
				continue
			S = new
			S.id = ++weather_system_serial
			S.kind = WEATHER_SYSTEM_STORM
			S.shared_key = key
			S.lifetime = rec[8]
			weather_systems += S
			weather_storm_count++
			weather_sample_time = -1
		S.severe = rec[3]
		S.radius_x = rec[4] * X[9]
		S.radius_y = rec[5] * X[9]
		S.peak = rec[6]
		S.wobble = rec[7]
		S.born = world.time - X[4]
		// A storm broken up here (weather_disperse) stays shorter.
		S.lifetime = min(S.lifetime, rec[8])
		S.origin_time = S.born
		S.origin_x = X[5]
		S.origin_y = X[6]
		S.vel_x = X[7]
		S.vel_y = X[8]
	for (var/key in present)
		if (!wanted[key])
			weather_system_end(present[key])

/proc/weather_shared_prune(slot)
	if (weather_shared_cache.len < 200)
		return
	for (var/key in weather_shared_cache.Copy())
		var/bar = findlasttext(key, "|")
		if (text2num(copytext(key, bar + 1)) < slot - WEATHER_SHARED_LOOKBACK - 1)
			weather_shared_cache -= key

#undef WEATHER_SHARED_SLOT
#undef WEATHER_SHARED_LOOKBACK
#undef WEATHER_SHARED_CENTRES
#undef WEATHER_SHARED_CENTRE_CHANCE
#undef WEATHER_SHARED_STORM_CHANCE
