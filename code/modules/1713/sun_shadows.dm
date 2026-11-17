// PROTOTYPE (not for merge): the sun's path through the day on hill maps.
// The day already moves in coarse phases (code/__defines/time_of_day.dm), so
// the sun takes one position per phase: low in the east at Early Morning, high
// in the south at Midday, low in the west at Evening, gone at Night (the last
// position stays, unseen in the dark, until morning).
//
// Hills are lit from the sun instead of the fixed north-west, and higher ground
// casts shadows away from the sun, long at dawn and dusk and short at noon.
// Both reuse the baked slope sprites (icons/turf/terrain_shade.dmi): a corner in
// shadow simply takes the darkest light level, and the Gouraud blend between
// corners softens the shadow edge. No new art for the terrain part.
//
// Cost model: each phase's corner lights are computed once per z-level and
// cached as row strings (the same shape as light_rows), so a phase change only
// swaps the overlay on tiles whose sprite key changed.

var/global/sun_shadows_enabled = FALSE
// Time of day whose sun the hills show now, null before the first sunny phase.
var/global/sun_phase_current = null
// TRUE while a phase change is re-shading the map.
var/global/sun_shadows_busy = FALSE

// Time of day -> list(azimuth in degrees clockwise from north, elevation in
// degrees). A northern-hemisphere sun: it rises north of east in summer and
// passes south of the zenith at noon. Phases without an entry have no sun.
var/global/list/sun_phase_angles = list(
	"Early Morning" = list(80, 10),
	"Morning" = list(115, 38),
	"Midday" = list(180, 62),
	"Afternoon" = list(245, 38),
	"Evening" = list(280, 10))

// One height level is this many tiles tall when shadows are cast.
#define SUN_LEVEL_TILES 1
// No shadow reaches further than this many tiles.
#define SUN_SHADOW_RANGE 24
// Same as terrain_height.dm (undefined there), so lights match the baked sprites.
#define SUN_RELIEF 1.6
#define SUN_LIGHT_STEP 0.22

// "z|phase" -> list of (maxy + 1) strings of (maxx + 1) light chars a-e.
/datum/terrain_heights/var/list/sun_rows_by_key = list()

/proc/sun_phase_for(tod)
	return sun_phase_angles[tod] ? tod : null

/datum/terrain_heights/proc/sun_light_rows(z, phase)
	var/key = "[z]|[phase]"
	if (sun_rows_by_key[key])
		return sun_rows_by_key[key]
	var/list/rows = rows_by_z["[z]"]
	var/list/angles = sun_phase_angles[phase]
	if (!rows || !angles)
		return null
	var/width = maxx + 1
	var/list/corner = new /list(width * (maxy + 1))
	var/top = 0
	for (var/cy in 0 to maxy)
		for (var/cx in 0 to maxx)
			var/h = (level_rc(rows, cy, cx) + level_rc(rows, cy + 1, cx) + level_rc(rows, cy, cx + 1) + level_rc(rows, cy + 1, cx + 1)) / 4
			corner[cy * width + cx + 1] = h
			if (h > top)
				top = h
		CHECK_TICK
	var/az = angles[1]
	var/el = angles[2]
	// Toward the sun, in corner columns (east +) and rows (south +).
	var/east = sin(az)
	var/south = -cos(az)
	var/light_x = east * cos(el)
	var/light_y = south * cos(el)
	var/light_z = sin(el)
	// Levels the sun's ray climbs per tile walked toward it.
	var/rise = tan(el) / SUN_LEVEL_TILES
	var/list/out = list()
	for (var/cy in 0 to maxy)
		var/list/chars = list()
		for (var/cx in 0 to maxx)
			var/h0 = corner[cy * width + cx + 1]
			// Cast shadow: march toward the sun until the ray clears the highest ground.
			var/shadow = FALSE
			var/reach = min(SUN_SHADOW_RANGE, ceil((top - h0) / rise))
			for (var/k in 1 to reach)
				var/px = round(cx + k * east, 1)
				var/py = round(cy + k * south, 1)
				if (px < 0 || px > maxx || py < 0 || py > maxy)
					break
				if (corner[py * width + px + 1] - h0 > k * rise)
					shadow = TRUE
					break
			if (shadow)
				chars += "a"
				continue
			var/gx = (corner[cy * width + min(cx + 1, maxx) + 1] - corner[cy * width + max(cx - 1, 0) + 1]) / 2
			var/gy = (corner[min(cy + 1, maxy) * width + cx + 1] - corner[max(cy - 1, 0) * width + cx + 1]) / 2
			var/nx = -gx * SUN_RELIEF
			var/ny = -gy * SUN_RELIEF
			var/intensity = (nx * light_x + ny * light_y + light_z) / sqrt(nx * nx + ny * ny + 1) - light_z
			chars += ascii2text(99 + clamp(floor(intensity / SUN_LIGHT_STEP + 0.5), -2, 2))
		out += jointext(chars, "")
		CHECK_TICK
	sun_rows_by_key[key] = out
	return out

// Player grading changes heights: drop this z-level's sun lights (prototype;
// a real build would recompute the 2 * SUN_SHADOW_RANGE box around the tile).
/datum/terrain_heights/proc/sun_heights_changed(z)
	for (var/key in sun_rows_by_key.Copy())
		if (findtext(key, "[z]|") == 1)
			sun_rows_by_key -= key

// Re-shades a box of one z-level for the current sun. Returns tiles changed.
/proc/sun_shadows_reshade(z, x1, y1, x2, y2)
	var/datum/terrain_heights/H = map ? map.terrain_heights() : null
	if (!H)
		return 0
	. = 0
	for (var/y in max(1, y1) to min(H.maxy, y2))
		for (var/x in max(1, x1) to min(H.maxx, x2))
			var/turf/T = locate(x, y, z)
			if (!T || istype(T, /turf/floor/beach/water) || T.terrain_smoothed())
				continue
			var/key = H.shade_key(x, y, z)
			var/image/shade = (key && key != "cccc") ? terrain_shade_image(key, T.terrain_shade_snowy()) : null
			if (shade != T.terrain_shade_overlay)
				T.terrain_shade_set(shade, T.terrain_terrace_overlay)
				.++
		CHECK_TICK

// Called when the time of day settles. For the hills, night keeps the last sun;
// tree shadows are taken away at night, so firelight never shows a sun shadow.
/proc/sun_shadows_phase(tod)
	set waitfor = FALSE
	if (!sun_shadows_enabled || !map)
		return
	var/phase = sun_phase_for(tod)
	var/trees = phase != sun_tree_phase
	var/hills = phase && phase != sun_phase_current && map.terrain_height_file
	if (!trees && !hills)
		return
	sun_shadows_busy = TRUE
	if (trees)
		sun_tree_phase = phase
		sun_tree_shadows_apply()
	if (hills)
		sun_phase_current = phase
		sun_ambient_shadow_refresh()
		if (terrain_shading_applied)
			var/datum/terrain_heights/H = map.terrain_heights()
			if (H)
				for (var/zkey in H.rows_by_z)
					sun_shadows_reshade(text2num(zkey), 1, 1, H.maxx, H.maxy)
	sun_shadows_busy = FALSE

// ---- Daylight colour ----
// Time of day -> list(red, green, blue) multipliers on the daylight term: low,
// warm light at dawn and dusk, neutral at noon, a little cool moonlight at
// night. Used by both daylight paths (lighting_overlay.dm on the server,
// plane_master.dm on the client). Kept close to 1 so the ground stays readable.
var/global/list/sun_phase_tint = list(
	"Early Morning" = list(1.18, 1.00, 0.78),
	"Morning" = list(1.04, 1.00, 0.93),
	"Midday" = list(1.00, 1.00, 1.00),
	"Afternoon" = list(1.05, 0.99, 0.90),
	"Evening" = list(1.30, 0.97, 0.70),
	"Night" = list(0.84, 0.93, 1.14))

// The daylight colour now, or null for the usual grey.
/proc/sun_daylight_tint()
	return sun_shadows_enabled ? sun_phase_tint[time_of_day] : null

// ---- Tree shadows ----
// Each tree wears one soft shadow sprite (icons/effects/sun_shadow.dmi, drawn
// by tests/sprites/create_sun_tree_shadow.py) as an overlay on the floor plane:
// above the ground and its slope shading, below every object, never clickable.
// The sprite lies straight up from its bottom centre; a matrix stretches it by
// the sun's height, turns it away from the sun and pins the bottom centre to
// the trunk base. Images are shared per (shape, size, trunk position, phase),
// so a phase change is one overlay swap per tree.
#define SUN_TREE_SHADOW_LAYER 2.036
// The shadow sprite's size in pixels.
#define SUN_TREE_SHADOW_SPRITE 64
// A shadow is never longer than this many times the tree's height.
#define SUN_TREE_SHADOW_MAX 2.2

// Phase whose shadows the trees wear now, null at night and before the first phase.
var/global/sun_tree_phase = null
var/global/list/sun_tree_shadow_images = list()

// Shadow sprite state, null for no shadow.
/obj/structure/wild/var/sun_shadow_shape = null
// The tree's height in tiles.
/obj/structure/wild/var/sun_shadow_size = 1.7
/obj/structure/wild/var/tmp/image/sun_shadow_overlay = null

/obj/structure/wild/tree
	sun_shadow_shape = "canopy"
	sun_shadow_size = 1.1
/obj/structure/wild/tree/cactus
	sun_shadow_shape = "bare"
	sun_shadow_size = 1
/obj/structure/wild/tree/dead_tree
	sun_shadow_shape = "bare"
	sun_shadow_size = 1.7
/obj/structure/wild/tree/dead_tree/destroyed
	sun_shadow_size = 0.8
/obj/structure/wild/tree/live_tree
	sun_shadow_size = 1.7
/obj/structure/wild/tree/live_tree/pine
	sun_shadow_shape = "pine"
	sun_shadow_size = 2.5
/obj/structure/wild/palm
	sun_shadow_shape = "canopy"
	sun_shadow_size = 1.7
/obj/structure/wild/jungle
	sun_shadow_shape = "canopy"
	sun_shadow_size = 2.4

// Leafless sheets (autumn, winter, dead) cast the bare shadow.
/obj/structure/wild/proc/sun_shadow_state()
	if (sun_shadow_shape == "canopy")
		var/sheet = "[icon]"
		if (findtext(sheet, "dead") || findtext(sheet, "winter"))
			return "bare"
	return sun_shadow_shape

/proc/sun_tree_shadow_image(shape, size, base_x, base_y, phase)
	var/key = "[shape]|[size]|[base_x]|[base_y]|[phase]"
	var/image/I = sun_tree_shadow_images[key]
	if (!I)
		var/list/angles = sun_phase_angles[phase]
		var/el = angles[2]
		var/scale = size * world.icon_size / SUN_TREE_SHADOW_SPRITE
		var/matrix/M = matrix()
		// Transforms turn about the sprite's centre: bring the trunk base there first.
		M.Translate(0, SUN_TREE_SHADOW_SPRITE / 2)
		M.Scale(scale, scale * min(1 / tan(el), SUN_TREE_SHADOW_MAX))
		M.Turn(angles[1] + 180)
		M.Translate(base_x - SUN_TREE_SHADOW_SPRITE / 2, base_y + 1 - SUN_TREE_SHADOW_SPRITE / 2)
		I = image('icons/effects/sun_shadow.dmi', icon_state = shape, layer = SUN_TREE_SHADOW_LAYER)
		I.plane = FLOOR_PLANE
		I.mouse_opacity = 0
		I.appearance_flags = RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM
		I.transform = M
		// A low sun's long shadow is fainter than the short one under a high sun.
		I.alpha = round(185 + 70 * sin(el))
		sun_tree_shadow_images[key] = I
	return I

// Gives this tree the shadow for the current phase. Returns TRUE when it changed.
/obj/structure/wild/proc/sun_shadow_update()
	var/image/want = null
	if (sun_shadows_enabled && sun_tree_phase && sun_shadow_shape && isturf(loc))
		want = sun_tree_shadow_image(sun_shadow_state(), sun_shadow_size, trunk_center_x || 16, trunk_base_y, sun_tree_phase)
	if (want == sun_shadow_overlay)
		return FALSE
	if (sun_shadow_overlay)
		overlays -= sun_shadow_overlay
	sun_shadow_overlay = want
	if (want)
		overlays += want
	return TRUE

// Swaps every tree's shadow to the current phase. Returns trees changed.
/proc/sun_tree_shadows_apply()
	. = 0
	for (var/obj/structure/wild/W in world)
		if (W.sun_shadow_shape && W.sun_shadow_update())
			.++
		CHECK_TICK

// ---- Ambient shadow ----
// The game plane's soft drop shadow (plane_master.dm) leans away from the sun:
// west at dawn, straight down at noon, east at dusk.
/proc/sun_ambient_shadow_x()
	var/list/angles = (sun_shadows_enabled && sun_phase_current) ? sun_phase_angles[sun_phase_current] : null
	return angles ? round(-2 * sin(angles[1]), 1) : 0

/proc/sun_ambient_shadow_refresh()
	for (var/client/C in clients)
		C.refresh_ambient_occlusion()

#undef SUN_TREE_SHADOW_LAYER
#undef SUN_TREE_SHADOW_SPRITE
#undef SUN_TREE_SHADOW_MAX
#undef SUN_LEVEL_TILES
#undef SUN_SHADOW_RANGE
#undef SUN_RELIEF
#undef SUN_LIGHT_STEP
