// The sun's path through the day (docs/sun-and-shadows.md). The day already
// moves in coarse phases (code/__defines/time_of_day.dm), so the sun takes one
// position per daylight phase, worked out from the map's latitude and the
// season: it rises in the east, stands highest at Midday (south of overhead in
// the northern hemisphere, north of it in the southern) and sets in the west.
// Summer suns climb higher and stay up longer; near the poles a winter sun may
// not rise at all. Night has no sun.
//
// The sun colours daylight and gives trees a ground shadow pointing away from
// it, long when it is low and short when it is high. Maps opt in with
// sun_latitude (the continent maps set it; see map_metadata).

// Daylight phase -> share of the day from sunrise (0) to sunset (1) at which
// that phase's sun is drawn. Phases not listed are sunless.
var/global/list/sun_phase_day_share = list(
	"Early Morning" = 0.1,
	"Morning" = 0.3,
	"Midday" = 0.5,
	"Afternoon" = 0.7,
	"Evening" = 0.9)

// Tilt of the earth's axis: the sun's declination at midsummer.
#define SUN_AXIAL_TILT 23.44
// A sun lower than this many degrees casts no shadow.
#define SUN_MIN_ELEVATION 2

/obj/map_metadata
	// Degrees north (+) or south (-) for the sun's path; null keeps the old,
	// sunless daylight. Continent maps set it.
	var/sun_latitude = null

// Map data, not world state: never saved.
/obj/map_metadata/persistence_runtime_var(var/key)
	if (key == "sun_latitude")
		return TRUE
	return ..(key)

// TRUE when this map's daylight follows a sun.
/proc/sun_enabled()
	return map && !isnull(map.sun_latitude)

// The sun's declination for the season, signed so that the local summer sun
// stands high in either hemisphere. Wet seasons are the tropical summer.
/proc/sun_declination(latitude, season_name)
	var/hemisphere = latitude < 0 ? -1 : 1
	switch (season_name)
		if (SEASON_SUMMER, SEASON_WET)
			return SUN_AXIAL_TILT * hemisphere
		if (SEASON_WINTER, SEASON_DRY)
			return -SUN_AXIAL_TILT * hemisphere
	return 0

// list(azimuth in degrees clockwise from north, elevation in degrees) of the
// sun at a share of the day from sunrise to sunset, or null below the horizon.
// A midnight sun treats the whole 24 hours as the day.
/proc/sun_position(latitude, declination, day_share)
	var/rise = -tan(latitude) * tan(declination)
	if (rise >= 1)
		return null
	var/half_day = rise <= -1 ? 180 : arccos(rise)
	var/hour = -half_day + 2 * half_day * day_share
	var/elevation = arcsin(sin(latitude) * sin(declination) + cos(latitude) * cos(declination) * cos(hour))
	// Azimuth measured from the south toward the west, then turned to north-clockwise.
	var/from_south = arctan(cos(hour) * sin(latitude) - tan(declination) * cos(latitude), sin(hour))
	var/azimuth = (from_south + 180) % 360
	if (azimuth < 0)
		azimuth += 360
	return list(round(azimuth, 1), round(elevation, 1))

var/global/list/sun_angles_cache = list()

// The sun for a time of day on this map now, or null when there is none.
/proc/sun_angles(tod = time_of_day)
	if (!sun_enabled())
		return null
	var/share = sun_phase_day_share[tod]
	if (isnull(share))
		return null
	var/key = "[map.sun_latitude]|[season]|[tod]"
	if (key in sun_angles_cache)
		return sun_angles_cache[key]
	var/list/angles = sun_position(map.sun_latitude, sun_declination(map.sun_latitude, season), share)
	if (angles && angles[2] < SUN_MIN_ELEVATION)
		angles = null
	sun_angles_cache[key] = angles
	return angles

// ---- Daylight colour ----
// list(red, green, blue) multipliers on the daylight term, used by both
// daylight paths (lighting_overlay.dm on the server, plane_master.dm on the
// client). The colour follows the sun's height, not the phase's name: a high
// sun is neutral white and the light warms as the sun sinks, so dawn and dusk
// glow, a winter noon is a little warmer than a summer one, and a daylight
// phase with no sun (polar night) gets no warm cast. Kept close to 1 so the
// ground and the water stay readable.
// The sun is neutral from this many degrees up.
#define SUN_TINT_NEUTRAL_ELEVATION 40
// The warmest light, reached with the sun on the horizon.
#define SUN_TINT_LOW_RED 1.18
#define SUN_TINT_LOW_GREEN 1.00
#define SUN_TINT_LOW_BLUE 0.78
// A little cool moonlight at night.
var/global/list/sun_night_tint = list(0.84, 0.93, 1.14)
// Elevation -> its colour, so the same sun always hands out the same list.
var/global/list/sun_tint_cache = list()

/proc/sun_elevation_tint(elevation)
	var/key = "[elevation]"
	var/list/tint = sun_tint_cache[key]
	if (!tint)
		var/low = min(max((SUN_TINT_NEUTRAL_ELEVATION - elevation) / SUN_TINT_NEUTRAL_ELEVATION, 0), 1)
		tint = list(
			round(1 + (SUN_TINT_LOW_RED - 1) * low, 0.01),
			round(1 + (SUN_TINT_LOW_GREEN - 1) * low, 0.01),
			round(1 + (SUN_TINT_LOW_BLUE - 1) * low, 0.01))
		sun_tint_cache[key] = tint
	return tint

// The daylight colour now, or null for the usual grey.
/proc/sun_daylight_tint(tod = time_of_day)
	if (!sun_enabled())
		return null
	if (tod == "Night")
		return sun_night_tint
	var/list/angles = sun_angles(tod)
	return angles ? sun_elevation_tint(angles[2]) : null

// ---- Tree shadows ----
// Each tree wears one soft shadow sprite (icons/effects/sun_shadow.dmi, drawn
// by tests/sprites/create_sun_tree_shadow.py) as an overlay on the floor plane:
// above the ground and its slope shading, below every object, never clickable.
// The sprite lies straight up from its bottom centre; a matrix stretches it by
// the sun's height, turns it away from the sun and pins the bottom centre to
// the trunk base. Under a high sun that shadow is short and hides behind the
// tree, so the image also carries a soft pool of shade around the trunk's foot
// (the "pool" state), stronger the higher the sun, which the stretch and turn
// leave alone. Images are shared per (shape, size, trunk position, sun), so a
// phase change is one overlay swap per tree.
#define SUN_TREE_SHADOW_LAYER 2.036
// The shadow sprite's size in pixels.
#define SUN_TREE_SHADOW_SPRITE 64
// A shadow is never longer than this many times the tree's height.
#define SUN_TREE_SHADOW_MAX 2.2
// The pool's width is the tree's height times this, up to the cap in tiles.
#define SUN_TREE_POOL_WIDTH 0.85
#define SUN_TREE_POOL_MAX 1.7
// The pool slides this many pixels away from the sun.
#define SUN_TREE_POOL_SHIFT 3

// The sun the trees' shadows show now, list(azimuth, elevation) or null.
var/global/list/sun_tree_angles = null
var/global/list/sun_tree_shadow_images = list()
// Every object that can cast a sun shadow (registered in New, dropped in Destroy).
var/global/list/sun_shadow_casters = list()
// TRUE while a phase change is updating the shadows.
var/global/sun_shadows_busy = FALSE

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

// The pool of a leafless tree is this share of a leafy one's.
#define SUN_TREE_POOL_BARE 0.45

// Leafless sheets (autumn, winter, dead) cast the bare shadow.
/obj/structure/wild/proc/sun_shadow_state()
	if (sun_shadow_shape == "canopy")
		var/sheet = "[icon]"
		if (findtext(sheet, "dead") || findtext(sheet, "winter"))
			return "bare"
	return sun_shadow_shape

/proc/sun_tree_shadow_image(shape, size, base_x, base_y, list/angles)
	var/key = "[shape]|[size]|[base_x]|[base_y]|[angles[1]]|[angles[2]]"
	var/image/I = sun_tree_shadow_images[key]
	if (!I)
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
		I.overlays += sun_tree_pool_image(shape, size, base_x, base_y, angles)
		sun_tree_shadow_images[key] = I
	return I

// The shade pooled at the trunk's foot: the "pool" sprite (a soft flat ellipse
// about the sprite's centre) sized to the crown, centred on the trunk base and
// nudged away from the sun. It rides on the shadow image as an overlay.
/proc/sun_tree_pool_image(shape, size, base_x, base_y, list/angles)
	var/width = min(size * SUN_TREE_POOL_WIDTH, SUN_TREE_POOL_MAX)
	var/strength = 0.3 + 0.7 * sin(angles[2])
	if (shape == "bare")
		width *= 0.7
		strength *= SUN_TREE_POOL_BARE
	var/scale = width * world.icon_size / SUN_TREE_SHADOW_SPRITE
	var/matrix/M = matrix()
	M.Scale(scale, scale)
	M.Translate(base_x - SUN_TREE_SHADOW_SPRITE / 2 - SUN_TREE_POOL_SHIFT * sin(angles[1]), base_y + 1 - SUN_TREE_SHADOW_SPRITE / 2 - SUN_TREE_POOL_SHIFT * cos(angles[1]))
	var/image/P = image('icons/effects/sun_shadow.dmi', icon_state = "pool", layer = SUN_TREE_SHADOW_LAYER)
	P.plane = FLOOR_PLANE
	P.mouse_opacity = 0
	P.appearance_flags = RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM
	P.transform = M
	P.alpha = round(255 * strength)
	return P

// Gives this tree the shadow for the current sun. Returns TRUE when it changed.
/obj/structure/wild/proc/sun_shadow_update()
	var/image/want = null
	if (sun_tree_angles && sun_shadow_shape && isturf(loc))
		want = sun_tree_shadow_image(sun_shadow_state(), sun_shadow_size, trunk_center_x || 16, trunk_base_y, sun_tree_angles)
	if (want == sun_shadow_overlay)
		return FALSE
	if (sun_shadow_overlay)
		overlays -= sun_shadow_overlay
	sun_shadow_overlay = want
	if (want)
		overlays += want
	return TRUE

/obj/structure/wild/proc/sun_shadow_register()
	if (sun_shadow_shape)
		sun_shadow_casters += src
		if (sun_tree_angles)
			sun_shadow_update()

// Swaps every caster's shadow to the current sun. Returns casters changed.
/proc/sun_tree_shadows_apply()
	. = 0
	var/list/casters = sun_shadow_casters.Copy()
	for (var/i in 1 to casters.len)
		var/obj/structure/wild/W = casters[i]
		if (!QDELETED(W) && W.sun_shadow_update())
			.++
		CHECK_TICK

// Called when the time of day settles (apply_time_of_day_effects) and when the
// season turns. Shadows follow the new sun; at night they are taken away.
/proc/sun_shadows_phase(tod = time_of_day)
	set waitfor = FALSE
	var/list/angles = sun_angles(tod)
	// The hills keep the last sun through the night (sun_hills.dm).
	sun_hills_phase(angles, sun_next_tod(tod))
	if (sun_same_angles(angles, sun_tree_angles))
		return
	sun_tree_angles = angles
	sun_shadows_busy = TRUE
	sun_tree_shadows_apply()
	sun_ambient_shadow_refresh()
	sun_shadows_busy = FALSE

// The time of day after tod in this map's cycle.
/proc/sun_next_tod(tod)
	var/i = times_of_day.Find(tod)
	return i ? times_of_day[i % times_of_day.len + 1] : null

/proc/sun_same_angles(list/a, list/b)
	if (!a || !b)
		return !a && !b
	return a[1] == b[1] && a[2] == b[2]

// ---- Ambient shadow ----
// The game plane's soft drop shadow (plane_master.dm) leans away from the sun:
// west in the morning, straight down at noon, east in the evening.
/proc/sun_ambient_shadow_x()
	return sun_tree_angles ? round(-2 * sin(sun_tree_angles[1]), 1) : 0

/proc/sun_ambient_shadow_refresh()
	for (var/client/C in clients)
		C.refresh_ambient_occlusion()

#undef SUN_AXIAL_TILT
#undef SUN_MIN_ELEVATION
#undef SUN_TREE_SHADOW_LAYER
#undef SUN_TREE_SHADOW_SPRITE
#undef SUN_TREE_SHADOW_MAX
#undef SUN_TREE_POOL_WIDTH
#undef SUN_TREE_POOL_MAX
#undef SUN_TREE_POOL_SHIFT
#undef SUN_TREE_POOL_BARE
#undef SUN_TINT_NEUTRAL_ELEVATION
#undef SUN_TINT_LOW_RED
#undef SUN_TINT_LOW_GREEN
#undef SUN_TINT_LOW_BLUE
