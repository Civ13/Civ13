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
	return sun_enabled() ? sun_phase_tint[time_of_day] : null

// ---- Tree shadows ----
// Each tree wears one soft shadow sprite (icons/effects/sun_shadow.dmi, drawn
// by tests/sprites/create_sun_tree_shadow.py) as an overlay on the floor plane:
// above the ground and its slope shading, below every object, never clickable.
// The sprite lies straight up from its bottom centre; a matrix stretches it by
// the sun's height, turns it away from the sun and pins the bottom centre to
// the trunk base. Images are shared per (shape, size, trunk position, sun), so
// a phase change is one overlay swap per tree.
#define SUN_TREE_SHADOW_LAYER 2.036
// The shadow sprite's size in pixels.
#define SUN_TREE_SHADOW_SPRITE 64
// A shadow is never longer than this many times the tree's height.
#define SUN_TREE_SHADOW_MAX 2.2

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
		sun_tree_shadow_images[key] = I
	return I

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
	if (sun_same_angles(angles, sun_tree_angles))
		return
	sun_tree_angles = angles
	sun_shadows_busy = TRUE
	sun_tree_shadows_apply()
	sun_ambient_shadow_refresh()
	sun_shadows_busy = FALSE

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
