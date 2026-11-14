// Terrain height (docs/terrain-height.md): optional per-tile hill levels for
// one native z-level. Walking uphill costs extra move delay, walking downhill
// saves a little. Off unless a map names a height file; every tile then reads 0.
// Heights are fixed map data loaded from a text file, so saves do not change.

// Slope speed curve (docs/terrain-height.md). A step's delay is multiplied by
// a factor from its grade, the levels climbed (+) or descended (-) per tile.
// Uphill: 1 + 0.4 g + 0.1 g^2, so each extra level costs more than the last.
#define TERRAIN_UPHILL_LINEAR 0.4
#define TERRAIN_UPHILL_SQUARE 0.1
// Downhill: 1 / (1 + 0.45 g), never below TERRAIN_DOWNHILL_BEST; grades past
// TERRAIN_DOWNHILL_EASY_GRADE are picked down more carefully again.
#define TERRAIN_DOWNHILL_GAIN 0.45
#define TERRAIN_DOWNHILL_BEST 0.55
#define TERRAIN_DOWNHILL_EASY_GRADE 2
#define TERRAIN_DOWNHILL_CAREFUL 0.1
// Free movement momentum (0-1): gained running or walking downhill, it speeds
// the next steps on flat ground and pays part of the next climb.
#define TERRAIN_MOMENTUM_GAIN 0.25
#define TERRAIN_MOMENTUM_SPEED 0.2
#define TERRAIN_MOMENTUM_FLAT_DECAY 0.34
#define TERRAIN_MOMENTUM_CLIMB_SHARE 0.6
#define TERRAIN_MOMENTUM_CLIMB_COST 0.5
// Grades within this of flat count as flat for momentum.
#define TERRAIN_MOMENTUM_FLAT_GRADE 0.25
// A pause longer than this (deciseconds) between free steps loses momentum.
#define TERRAIN_MOMENTUM_KEEP 4
// No slope or momentum makes a step faster than this share of its delay.
#define TERRAIN_FASTEST_SHARE 0.45
// A one-tile step never counts more than this many levels.
#define TERRAIN_MAX_LEVEL_STEP 4
// Share of the uphill delay paid when stepping onto packed ground (tamped earth).
#define TERRAIN_PACKED_UPHILL_SHARE 0.5
// A step of this many levels or more is steep: it tires the climber and is
// described in chat.
#define TERRAIN_STEEP_LEVELS 3
// Stamina spent per level climbed on a steep step.
#define TERRAIN_CLIMB_STAMINA 0.5
// Running down a steep step (TERRAIN_STEEP_LEVELS or more) can trip you:
// percent chance per level past 2, plus for full momentum and for running on
// an empty stamina bar. Walking down picks a safe way.
#define TERRAIN_TRIP_PER_LEVEL 10
#define TERRAIN_TRIP_MOMENTUM 10
#define TERRAIN_TRIP_TIRED 10
#define TERRAIN_TRIP_MAX 50
// A fall rolls on while the ground keeps dropping this many levels a tile,
// up to TERRAIN_TUMBLE_MAX tiles, for TERRAIN_TUMBLE_DAMAGE brute per tile.
#define TERRAIN_TUMBLE_DROP 2
#define TERRAIN_TUMBLE_MAX 6
#define TERRAIN_TUMBLE_DAMAGE 2
// Deciseconds between two steep-slope messages to the same mob.
#define TERRAIN_SLOPE_MESSAGE_DELAY 100

/mob/var/next_slope_message = -1
/mob/living/human/var/tmp/terrain_momentum = 0
/mob/living/human/var/tmp/terrain_momentum_at = -1
/mob/living/human/var/tmp/terrain_momentum_dir = 0
/mob/living/human/var/tmp/terrain_pace_carry = 0

/obj/map_metadata
	// Project-relative height file, for example "maps/heights/nomads_gaia.txt".
	var/terrain_height_file = null
	var/tmp/datum/terrain_heights/terrain_heights_cache = null

/obj/map_metadata/persistence_runtime_var(var/key)
	if (key == "terrain_height_file" || key == "terrain_heights_cache" || key == "river_flow_cache" || key == "river_flow_loaded")
		return TRUE
	return ..(key)

/datum/terrain_heights
	should_save = FALSE
	var/maxx = 0
	var/maxy = 0
	// "z" -> list of row strings, north row first, with player grading applied.
	var/list/rows_by_z = list()
	// "z" -> the same rows as loaded from the file, before any grading.
	var/list/base_rows_by_z = list()
	var/error = null

/datum/terrain_heights/proc/at(x, y, z)
	var/list/rows = rows_by_z["[z]"]
	if (!rows || x < 1 || x > maxx || y < 1 || y > maxy)
		return 0
	var/code = text2ascii(rows[maxy - y + 1], x)
	if (code >= 97)
		return code - 87
	return code - 48

// Parses the height text. Returns null and sets error on any problem, so a bad
// file leaves the map flat instead of half-loaded.
/proc/terrain_heights_parse(text, world_maxx, world_maxy, world_maxz)
	var/datum/terrain_heights/H = new
	if (!istext(text) || !length(text))
		H.error = "empty height file"
		return H
	var/list/lines = splittext(replacetext(text, ascii2text(13), ""), "\n")
	var/i = 1
	var/list/header = splittext(lines[i++], " ")
	if (header.len != 2 || header[1] != "civ13-terrain-heights" || header[2] != "1")
		H.error = "missing 'civ13-terrain-heights 1' header"
		return H
	var/list/size = i <= lines.len ? splittext(lines[i++], " ") : list()
	if (size.len != 3 || size[1] != "size")
		H.error = "missing 'size X Y' line"
		return H
	H.maxx = text2num(size[2])
	H.maxy = text2num(size[3])
	if (H.maxx != world_maxx || H.maxy != world_maxy)
		H.error = "size [size[2]]x[size[3]] does not match the world ([world_maxx]x[world_maxy])"
		return H
	while (i <= lines.len)
		var/line = lines[i++]
		if (!length(line))
			continue
		var/list/zline = splittext(line, " ")
		var/z = zline.len == 2 && zline[1] == "z" ? text2num(zline[2]) : null
		if (!isnum(z) || z != round(z) || z < 1 || z > world_maxz || H.rows_by_z["[z]"])
			H.error = "bad or repeated z line '[line]'"
			return H
		var/list/rows = list()
		for (var/r in 1 to H.maxy)
			if (i > lines.len)
				H.error = "z [z] has [rows.len] of [H.maxy] rows"
				return H
			var/row = lines[i++]
			if (length(row) != H.maxx || !terrain_height_row_valid(row))
				H.error = "z [z] row [r] must be [H.maxx] characters of 0-9 or a-f"
				return H
			rows += row
		H.rows_by_z["[z]"] = rows
		H.base_rows_by_z["[z]"] = rows.Copy()
	if (!H.rows_by_z.len)
		H.error = "no z levels"
	return H

// The file's level for a tile, ignoring grading.
/datum/terrain_heights/proc/base_at(x, y, z)
	var/list/rows = base_rows_by_z["[z]"]
	if (!rows || x < 1 || x > maxx || y < 1 || y > maxy)
		return 0
	var/code = text2ascii(rows[maxy - y + 1], x)
	return code >= 97 ? code - 87 : code - 48

// Sets a graded tile's level and updates the corner lights around it.
/datum/terrain_heights/proc/set_level(x, y, z, level)
	var/list/rows = rows_by_z["[z]"]
	if (!rows || x < 1 || x > maxx || y < 1 || y > maxy)
		return FALSE
	level = clamp(round(level), 0, 15)
	var/r = maxy - y + 1
	var/row = rows[r]
	rows[r] = copytext(row, 1, x) + ascii2text(level < 10 ? 48 + level : 87 + level) + copytext(row, x + 1)
	var/list/lights = light_rows_by_z["[z]"]
	if (lights)
		// A tile moves the 4 corners around it; each light reads corners one step away.
		for (var/cy in max(0, r - 3) to min(maxy, r + 2))
			var/list/chars = list()
			for (var/cx in max(0, x - 3) to min(maxx, x + 2))
				chars += light_char(rows, cy, cx)
			var/first = max(0, x - 3) + 1
			var/old = lights[cy + 1]
			lights[cy + 1] = copytext(old, 1, first) + jointext(chars, "") + copytext(old, first + chars.len)
	// Line of sight caches terrain answers per eye position (los_terrain.dm).
	los_terrain_heights_changed(locate(x, y, z))
	return TRUE

/proc/terrain_height_row_valid(row)
	var/static/regex/bad = regex(@"[^0-9a-f]")
	return !bad.Find(row)

/obj/map_metadata/proc/terrain_heights()
	if (!terrain_height_file)
		return null
	if (!terrain_heights_cache)
		var/text = fexists(terrain_height_file) ? file2text(terrain_height_file) : null
		terrain_heights_cache = terrain_heights_parse(text, world.maxx, world.maxy, world.maxz)
		if (terrain_heights_cache.error)
			log_debug("Terrain heights [terrain_height_file] ignored: [terrain_heights_cache.error]")
	if (terrain_heights_cache.error)
		return null
	return terrain_heights_cache

/proc/terrain_height_at(turf/T)
	if (!T || !map || !map.terrain_height_file)
		return 0
	var/datum/terrain_heights/H = map.terrain_heights()
	return H ? H.at(T.x, T.y, T.z) : 0

// Built ground (wood, stone, tiles, roads, decks, built walls, tamped earth)
// is laid level: it has no slope cost and no shading. Natural ground keeps the
// hill unless a player-built floor or road cover lies on it.
/turf/proc/terrain_smoothed()
	return terrain_floor_covered()

// Packed paths (tamped earth) keep the hill but are easier to climb.
/turf/proc/terrain_packed()
	return FALSE

// Floor and road covers (not cover walls) are built level over the slope.
/turf/proc/terrain_floor_covered()
	for (var/obj/covers/CV in src)
		if (!CV.wall && !QDELETED(CV))
			return TRUE
	return FALSE

/turf/floor/terrain_smoothed()
	return TRUE

/turf/floor/grass/terrain_smoothed()
	return terrain_floor_covered()

/turf/floor/dirt/terrain_smoothed()
	return terrain_floor_covered()

/turf/floor/winter/terrain_smoothed()
	return terrain_floor_covered()

/turf/floor/beach/terrain_smoothed()
	return terrain_floor_covered()

/turf/floor/rocky/terrain_smoothed()
	return terrain_floor_covered()

/turf/floor/gravel/terrain_smoothed()
	return terrain_floor_covered()

/turf/floor/mining/terrain_smoothed()
	return terrain_floor_covered()

/turf/floor/trench/terrain_smoothed()
	return terrain_floor_covered()

/turf/floor/lava/terrain_smoothed()
	return terrain_floor_covered()

/turf/wall/terrain_smoothed()
	return TRUE

/turf/wall/rockwall/terrain_smoothed()
	return terrain_floor_covered()

// Signed level change of one step between two neighbouring turfs, capped at
// TERRAIN_MAX_LEVEL_STEP either way; 0 across built ground or without heights.
/proc/terrain_step_levels(turf/origin, turf/destination)
	if (!origin || !destination || origin.z != destination.z || !map || !map.terrain_height_file)
		return 0
	if (origin.terrain_smoothed() || destination.terrain_smoothed())
		return 0
	return clamp(terrain_height_at(destination) - terrain_height_at(origin), -TERRAIN_MAX_LEVEL_STEP, TERRAIN_MAX_LEVEL_STEP)

// Humans feel a steep step: scrambling up spends stamina (half of it on packed
// ground) and either direction is described in chat, at most once per
// TERRAIN_SLOPE_MESSAGE_DELAY. distance_fraction is the share of a tile moved.
/proc/terrain_climb_effects(mob/living/human/H, turf/origin, turf/destination, distance_fraction = 1)
	var/levels = terrain_step_levels(origin, destination)
	if (abs(levels) < TERRAIN_STEEP_LEVELS)
		return 0
	if (levels > 0 && H.stats["stamina"][1] > 0)
		var/cost = levels * TERRAIN_CLIMB_STAMINA * distance_fraction
		if (destination.terrain_packed())
			cost *= TERRAIN_PACKED_UPHILL_SHARE
		H.stats["stamina"][1] = max(0, H.stats["stamina"][1] - cost)
	if (world.time >= H.next_slope_message)
		H.next_slope_message = world.time + TERRAIN_SLOPE_MESSAGE_DELAY
		if (levels > 0)
			to_chat(H, SPAN_NOTICE("You scramble up the steep slope."))
		else
			to_chat(H, SPAN_NOTICE("You pick your way down the steep slope."))
	return levels

// Percent chance that this step trips a running human; 0 when it cannot.
/proc/terrain_trip_chance(mob/living/human/H, turf/origin, turf/destination, distance_fraction = 1)
	if (distance_fraction < 1 || H.m_intent != "run" || H.lying || H.buckled)
		return 0
	var/drop = -terrain_step_levels(origin, destination)
	if (drop < TERRAIN_STEEP_LEVELS)
		return 0
	var/chance = (drop - 2) * TERRAIN_TRIP_PER_LEVEL + H.terrain_momentum * TERRAIN_TRIP_MOMENTUM
	if (H.stats["stamina"][1] <= 0)
		chance += TERRAIN_TRIP_TIRED
	// Hobnails and crampons bite; snowshoes and pattens wobble (weather_footwear.dm).
	chance *= footwear_slope_grip(H)
	return min(TERRAIN_TRIP_MAX, chance)

// Running down a steep slope may trip the runner, who falls once the step is
// done and tumbles on down the hill. step_delay is the step's duration.
/proc/terrain_trip_check(mob/living/human/H, turf/origin, turf/destination, distance_fraction = 1, step_delay = 0)
	var/chance = terrain_trip_chance(H, origin, destination, distance_fraction)
	if (!chance || !prob(chance))
		return FALSE
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(terrain_tumble), H), max(world.tick_lag, step_delay))
	return TRUE

// Where a fall from T rolls to: down the steepest neighbour, tile by tile,
// while each tile drops at least TERRAIN_TUMBLE_DROP levels.
/proc/terrain_tumble_path(turf/T)
	. = list()
	var/turf/at = T
	for (var/i in 1 to TERRAIN_TUMBLE_MAX)
		var/turf/best = null
		var/best_drop = 0
		for (var/d in alldirs)
			var/turf/N = get_step(at, d)
			if (!N || N.density || istype(N, /turf/floor/beach/water))
				continue
			var/drop = -terrain_step_levels(at, N)
			if (d in cornerdirs)
				drop /= 1.4142
			if (drop >= TERRAIN_TUMBLE_DROP && drop > best_drop)
				best = N
				best_drop = drop
		if (!best)
			break
		. += best
		at = best

// The fall: the human is knocked down and rolls down the slope, bruised for
// every tile rolled. Things in the way stop the roll as any thrown body does.
/proc/terrain_tumble(mob/living/human/H)
	if (QDELETED(H) || H.stat == DEAD || H.lying || H.buckled || !isturf(H.loc))
		return FALSE
	var/list/path = terrain_tumble_path(H.loc)
	H.terrain_momentum = 0
	H.Weaken(2)
	if (!path.len)
		H.visible_message(SPAN_WARNING("[H] trips and falls on the slope!"), SPAN_DANGER("You trip and fall on the steep slope!"))
		H.adjustBruteLoss(TERRAIN_TUMBLE_DAMAGE)
		return TRUE
	H.visible_message(SPAN_WARNING("[H] trips and tumbles down the slope!"), SPAN_DANGER("You lose your footing and tumble down the slope!"))
	H.adjustBruteLoss(TERRAIN_TUMBLE_DAMAGE * path.len)
	H.throw_at(path[path.len], path.len, 1)
	return TRUE

// Delay factor for a grade in levels per tile (negative downhill), capped at
// TERRAIN_MAX_LEVEL_STEP. Packed ground halves the extra climbing cost.
/proc/terrain_grade_factor(grade, packed = FALSE)
	grade = clamp(grade, -TERRAIN_MAX_LEVEL_STEP, TERRAIN_MAX_LEVEL_STEP)
	if (grade > 0)
		var/extra = grade * TERRAIN_UPHILL_LINEAR + grade * grade * TERRAIN_UPHILL_SQUARE
		return 1 + extra * (packed ? TERRAIN_PACKED_UPHILL_SHARE : 1)
	if (grade < 0)
		var/drop = -grade
		if (drop > TERRAIN_DOWNHILL_EASY_GRADE)
			return TERRAIN_DOWNHILL_BEST + (drop - TERRAIN_DOWNHILL_EASY_GRADE) * TERRAIN_DOWNHILL_CAREFUL
		return max(TERRAIN_DOWNHILL_BEST, 1 / (1 + drop * TERRAIN_DOWNHILL_GAIN))
	return 1

// Extra move delay (negative when it saves time) for one whole-tile step
// between two neighbouring turfs, given the step's delay before this term.
// Tile steps (tap to step, pulling, riding, NPC agents, bicycles) use this.
/proc/terrain_slope_delay(turf/origin, turf/destination, step_delay)
	var/levels = terrain_step_levels(origin, destination)
	if (!levels)
		return 0
	return max(0, step_delay) * (terrain_grade_factor(levels, destination.terrain_packed()) - 1)

// Height at a point in tile coordinates, where tile centres are whole numbers,
// blended between the four nearest tile centres.
/datum/terrain_heights/proc/sample(u, v, z)
	var/x0 = floor(u)
	var/y0 = floor(v)
	var/fx = u - x0
	var/fy = v - y0
	var/south = at(x0, y0, z) * (1 - fx) + at(x0 + 1, y0, z) * fx
	var/north = at(x0, y0 + 1, z) * (1 - fx) + at(x0 + 1, y0 + 1, z) * fx
	return south * (1 - fy) + north * fy

// Grade of a free (sub-tile) step: the blended height one tile ahead of the
// body's exact position minus the height under it, per tile travelled. Between
// tile centres it changes smoothly, so the pace follows the hill as you slide.
/proc/terrain_free_grade(mob/living/human/M, turf/destination, direct)
	var/turf/origin = M.loc
	if (!isturf(origin) || !destination || origin.z != destination.z || !map || !map.terrain_height_file)
		return 0
	if (origin.terrain_smoothed() || destination.terrain_smoothed())
		return 0
	var/datum/terrain_heights/H = map.terrain_heights()
	if (!H)
		return 0
	var/u = M.x + M.step_x / 32
	var/v = M.y + M.step_y / 32
	var/dx = (direct & EAST) ? 1 : ((direct & WEST) ? -1 : 0)
	var/dy = (direct & NORTH) ? 1 : ((direct & SOUTH) ? -1 : 0)
	if (!dx && !dy)
		return 0
	// A straight slide reads the row (or column) the body is on, so a level
	// path is not slowed by a hillside beside it when the body sits a few
	// pixels off the path's centre line.
	if (!dy)
		v = round(v, 1)
	else if (!dx)
		u = round(u, 1)
	var/rise = clamp(H.sample(u + dx, v + dy, M.z) - H.sample(u, v, M.z), -TERRAIN_MAX_LEVEL_STEP, TERRAIN_MAX_LEVEL_STEP)
	return (dx && dy) ? rise / 1.4142 : rise

// Slope factor for a free step. held is TRUE for a held slide (not a 2px
// nudge): only held slides build and spend downhill momentum.
/proc/terrain_free_factor(mob/living/human/M, turf/destination, direct, step_delay, held = TRUE)
	var/grade = terrain_free_grade(M, destination, direct)
	var/factor = terrain_grade_factor(grade, destination && destination.terrain_packed())
	if (held)
		var/momentum = M.terrain_momentum
		if (world.time - M.terrain_momentum_at > max(TERRAIN_MOMENTUM_KEEP, step_delay * 2) || (M.terrain_momentum_dir && direct == reverse_dir[M.terrain_momentum_dir]))
			momentum = 0
			M.terrain_pace_carry = 0
		if (grade > TERRAIN_MOMENTUM_FLAT_GRADE)
			// Speed carried into a climb pays part of it, and is spent doing so.
			factor = 1 + (factor - 1) * (1 - momentum * TERRAIN_MOMENTUM_CLIMB_SHARE)
			momentum = max(0, momentum - grade * TERRAIN_MOMENTUM_CLIMB_COST)
		else
			factor *= 1 - momentum * TERRAIN_MOMENTUM_SPEED
			if (grade < -TERRAIN_MOMENTUM_FLAT_GRADE)
				var/before = momentum
				momentum = min(1, momentum - grade * TERRAIN_MOMENTUM_GAIN)
				if (momentum >= 1 && before < 1 && world.time >= M.next_slope_message)
					M.next_slope_message = world.time + TERRAIN_SLOPE_MESSAGE_DELAY
					to_chat(M, SPAN_NOTICE("You gather speed down the slope."))
			else
				momentum = max(0, momentum - TERRAIN_MOMENTUM_FLAT_DECAY)
		M.terrain_momentum = momentum
		M.terrain_momentum_at = world.time
		M.terrain_momentum_dir = direct
	return max(TERRAIN_FASTEST_SHARE, factor)

// Extra move delay for a free step. A held slide's pace is whole server ticks
// plus one (human_subtile_held_pace), which used to swallow most of a gentle
// slope. Held slides therefore aim at factor x the flat pace and carry the
// part of a tick left over into the next step, so over a few steps the pace
// follows the hill exactly. Flat ground keeps exactly the flat pace.
/proc/terrain_free_slope_delay(mob/living/human/M, turf/destination, direct, step_delay, held = TRUE)
	step_delay = max(0, step_delay)
	var/factor = terrain_free_factor(M, destination, direct, step_delay, held)
	if (!held)
		return step_delay * (factor - 1)
	var/tick = world.tick_lag
	if (factor == 1 && !M.terrain_pace_carry)
		return 0
	var/flat_pace = (max(1, ceil(round(step_delay / tick, 0.001))) + 1) * tick
	var/want = flat_pace * factor - tick + M.terrain_pace_carry
	var/ticks = max(1, round(want / tick, 1))
	M.terrain_pace_carry = clamp(want - ticks * tick, -tick, tick)
	return ticks * tick - step_delay

// Slope shading (scripts/terrain_heights.py bake-shading makes the sprites).
// Each tile corner gets a light level from -2 (shadow) to 2 (lit), from the
// heights around it, lit from the north-west. A tile shows the sprite for its
// four corner levels, blended across the tile, so neighbours join smoothly.
// Sprites are shared images in the turf's own overlays, on the turf's plane:
// turf vis_contents never reached the screen in the real client, so the hills
// were flat in play. Overlays are never clickable and never saved (the turf
// allowlist holds only icon_state and name). They sit above the ground, its
// decals and fallen snow (layer 2.03, which is opaque and would hide the hills
// all winter) and below objects; the copies of decals that winter lifts above
// the snow (2.04) stay on top. Floor icon rebuilds put them back.
#define TERRAIN_LIGHT_STEP 0.22
#define TERRAIN_RELIEF 1.6
#define TERRAIN_SHADE_LAYER 2.035

var/global/list/terrain_shade_images = list()
// TRUE once the map's shading has been placed this round.
var/global/terrain_shading_applied = FALSE

/turf/var/tmp/image/terrain_shade_overlay = null

/proc/terrain_shade_image(key)
	var/image/I = terrain_shade_images[key]
	if (!I)
		I = image('icons/turf/terrain_shade.dmi', icon_state = key, layer = TERRAIN_SHADE_LAYER)
		I.plane = FLOOR_PLANE
		I.mouse_opacity = 0
		terrain_shade_images[key] = I
	return I

// "z" -> list of (maxy + 1) strings of (maxx + 1) light chars a-e, north first.
/datum/terrain_heights/var/list/light_rows_by_z = list()

// Level at a north-first row and column, clamped to the edge like the tool.
/datum/terrain_heights/proc/level_rc(list/rows, row, col)
	var/code = text2ascii(rows[clamp(row, 1, maxy)], clamp(col, 1, maxx))
	return code >= 97 ? code - 87 : code - 48

/datum/terrain_heights/proc/light_rows(z)
	var/key = "[z]"
	if (light_rows_by_z[key])
		return light_rows_by_z[key]
	var/list/rows = rows_by_z[key]
	if (!rows)
		return null
	var/width = maxx + 1
	// Corner heights: corner (cx, cy), 0-based, north first, between rows cy/cy+1 and columns cx/cx+1.
	var/list/corner = new /list(width * (maxy + 1))
	for (var/cy in 0 to maxy)
		for (var/cx in 0 to maxx)
			corner[cy * width + cx + 1] = (level_rc(rows, cy, cx) + level_rc(rows, cy + 1, cx) + level_rc(rows, cy, cx + 1) + level_rc(rows, cy + 1, cx + 1)) / 4
	var/static/light_x = -1 / sqrt(3.44)
	var/static/light_y = -1 / sqrt(3.44)
	var/static/light_z = 1.2 / sqrt(3.44)
	var/list/out = list()
	for (var/cy in 0 to maxy)
		var/list/chars = list()
		for (var/cx in 0 to maxx)
			var/gx = (corner[cy * width + min(cx + 1, maxx) + 1] - corner[cy * width + max(cx - 1, 0) + 1]) / 2
			var/gy = (corner[min(cy + 1, maxy) * width + cx + 1] - corner[max(cy - 1, 0) * width + cx + 1]) / 2
			var/nx = -gx * TERRAIN_RELIEF
			var/ny = -gy * TERRAIN_RELIEF
			var/intensity = (nx * light_x + ny * light_y + light_z) / sqrt(nx * nx + ny * ny + 1) - light_z
			chars += ascii2text(99 + clamp(floor(intensity / TERRAIN_LIGHT_STEP + 0.5), -2, 2))
		out += jointext(chars, "")
		CHECK_TICK
	light_rows_by_z[key] = out
	return out

// One corner light, computed alone; matches light_rows() exactly.
/datum/terrain_heights/proc/corner_level(list/rows, cy, cx)
	cy = clamp(cy, 0, maxy)
	cx = clamp(cx, 0, maxx)
	return (level_rc(rows, cy, cx) + level_rc(rows, cy + 1, cx) + level_rc(rows, cy, cx + 1) + level_rc(rows, cy + 1, cx + 1)) / 4

/datum/terrain_heights/proc/light_char(list/rows, cy, cx)
	var/static/light_x = -1 / sqrt(3.44)
	var/static/light_y = -1 / sqrt(3.44)
	var/static/light_z = 1.2 / sqrt(3.44)
	var/gx = (corner_level(rows, cy, min(cx + 1, maxx)) - corner_level(rows, cy, max(cx - 1, 0))) / 2
	var/gy = (corner_level(rows, min(cy + 1, maxy), cx) - corner_level(rows, max(cy - 1, 0), cx)) / 2
	var/nx = -gx * TERRAIN_RELIEF
	var/ny = -gy * TERRAIN_RELIEF
	var/intensity = (nx * light_x + ny * light_y + light_z) / sqrt(nx * nx + ny * ny + 1) - light_z
	return ascii2text(99 + clamp(floor(intensity / TERRAIN_LIGHT_STEP + 0.5), -2, 2))

// Sprite key for a tile: corner lights nw, ne, sw, se; "cccc" means flat.
/datum/terrain_heights/proc/shade_key(x, y, z)
	var/list/lights = light_rows(z)
	if (!lights || x < 1 || x > maxx || y < 1 || y > maxy)
		return null
	var/row = maxy - y + 1
	return copytext(lights[row], x, x + 2) + copytext(lights[row + 1], x, x + 2)

/turf/proc/terrain_shade_refresh()
	var/image/shade = null
	// Water wears flow lines in the same slot (river_flow.dm); it is never shaded.
	if (istype(src, /turf/floor/beach/water))
		terrain_shade_set(water_flow_image(src))
		return
	if (map && map.terrain_height_file && !istype(src, /turf/floor/beach/water) && !terrain_smoothed())
		var/datum/terrain_heights/H = map.terrain_heights()
		var/key = H ? H.shade_key(x, y, z) : null
		if (key && key != "cccc")
			shade = terrain_shade_image(key)
	terrain_shade_set(shade)

/turf/proc/terrain_shade_set(image/shade)
	if (terrain_shade_overlay)
		overlays -= terrain_shade_overlay
	terrain_shade_overlay = shade
	if (shade)
		overlays += shade

// Floor icon rebuilds clear every overlay; this puts the shading back.
/turf/proc/terrain_shade_icon()
	if (terrain_shade_overlay)
		overlays -= terrain_shade_overlay
		overlays += terrain_shade_overlay

// A floor cover laid or removed after the shading was placed changes whether
// its tile is shaded. Covers call updateturf() shortly after they are placed.
/obj/covers/updateturf()
	. = ..()
	var/turf/T = get_turf(src)
	if (T && !wall && terrain_shading_applied)
		T.terrain_shade_refresh()

/obj/covers/Destroy()
	var/turf/T = get_turf(src)
	var/floor_cover = !wall
	. = ..()
	if (T && floor_cover && terrain_shading_applied)
		T.terrain_shade_refresh()

/proc/terrain_shading_apply()
	var/datum/terrain_heights/H = map ? map.terrain_heights() : null
	if (!H)
		return 0
	var/count = 0
	for (var/zkey in H.rows_by_z)
		var/z = text2num(zkey)
		H.light_rows(z)
		for (var/y in 1 to H.maxy)
			for (var/x in 1 to H.maxx)
				var/turf/T = locate(x, y, z)
				if (istype(T, /turf/floor/beach/water))
					var/image/flow = water_flow_image(T)
					if (flow)
						T.terrain_shade_set(flow)
					continue
				if (!T || T.terrain_smoothed())
					continue
				var/key = H.shade_key(x, y, z)
				if (key != "cccc")
					T.terrain_shade_set(terrain_shade_image(key))
					count++
			CHECK_TICK
	return count

// Called by the ticker every 2 seconds; places the shading once per round.
/proc/terrain_shading_check()
	if (terrain_shading_applied || !map || !map.terrain_height_file)
		return
	terrain_shading_applied = TRUE
	terrain_shading_place()

// Runs on its own so the ticker is not held while tiles are shaded.
/proc/terrain_shading_place()
	set waitfor = FALSE
	var/started = REALTIMEOFDAY
	var/count = terrain_shading_apply()
	log_game("Terrain shading placed on [count] tiles of [map ? map.title : "no map"] in [(REALTIMEOFDAY - started) / 10] s.")

// Admin view: the height number on every tile in view, until toggled off.
/client/var/tmp/list/terrain_height_images

/client/proc/toggle_terrain_heights()
	set category = "Debug"
	set name = "Show Terrain Heights"
	if (!check_rights(R_DEBUG))
		return
	if (terrain_height_images)
		images -= terrain_height_images
		terrain_height_images = null
		to_chat(src, SPAN_NOTICE("Terrain heights hidden."))
		return
	if (!map || !map.terrain_height_file)
		to_chat(src, SPAN_NOTICE("This map has no terrain height file; every tile is height 0."))
		return
	if (!map.terrain_heights())
		to_chat(src, SPAN_WARNING("[map.terrain_height_file] could not be loaded: [map.terrain_heights_cache ? map.terrain_heights_cache.error : "unknown error"]."))
		return
	terrain_height_images = list()
	for (var/turf/T in view(world.view, mob))
		var/height = terrain_height_at(T)
		var/image/I = image(loc = T, layer = FLY_LAYER)
		I.plane = HUD_PLANE
		I.maptext = "<span style='font-family: Small Fonts; font-size: 7px; color: [height ? "#ffe680" : "#9ad0ff"]; -dm-text-outline: 1px black'>[height]</span>"
		I.maptext_x = 12
		I.maptext_y = 10
		I.mouse_opacity = 0
		terrain_height_images += I
	images += terrain_height_images
	to_chat(src, SPAN_NOTICE("Showing terrain heights around you; use the verb again to hide them."))

#undef TERRAIN_UPHILL_LINEAR
#undef TERRAIN_UPHILL_SQUARE
#undef TERRAIN_DOWNHILL_GAIN
#undef TERRAIN_DOWNHILL_BEST
#undef TERRAIN_DOWNHILL_EASY_GRADE
#undef TERRAIN_DOWNHILL_CAREFUL
#undef TERRAIN_MOMENTUM_GAIN
#undef TERRAIN_MOMENTUM_SPEED
#undef TERRAIN_MOMENTUM_FLAT_DECAY
#undef TERRAIN_MOMENTUM_CLIMB_SHARE
#undef TERRAIN_MOMENTUM_CLIMB_COST
#undef TERRAIN_MOMENTUM_FLAT_GRADE
#undef TERRAIN_MOMENTUM_KEEP
#undef TERRAIN_FASTEST_SHARE
#undef TERRAIN_TRIP_PER_LEVEL
#undef TERRAIN_TRIP_MOMENTUM
#undef TERRAIN_TRIP_TIRED
#undef TERRAIN_TRIP_MAX
#undef TERRAIN_TUMBLE_DROP
#undef TERRAIN_TUMBLE_MAX
#undef TERRAIN_TUMBLE_DAMAGE
#undef TERRAIN_MAX_LEVEL_STEP
#undef TERRAIN_PACKED_UPHILL_SHARE
#undef TERRAIN_LIGHT_STEP
#undef TERRAIN_RELIEF
#undef TERRAIN_SHADE_LAYER
