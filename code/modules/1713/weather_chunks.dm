// ============================================================
// Drawing the weather systems (docs/weather-systems.md)
// ------------------------------------------------------------
// The rain, snow or sand under a moving system is drawn for the players near
// it, as images four tiles on a side that only their clients hold. An image
// is not an object: it is in no turf's contents, it is never saved, and an
// empty stretch of map costs nothing. Each image takes its look from the
// climate under it and its opacity from the storm's strength there, so the
// edge of the rain is a real line on the ground that moves with the storm.
//
// Roofed areas cut the weather away. They draw a mask on their own plane, and
// the weather plane removes whatever the mask covers.
// ============================================================

#define WEATHER_CHUNK 4
#define WEATHER_EDGE_LEVELS 3 // steps of fade at a piece's corner

var/global/list/weather_chunk_images = list() // image key = image

/client/var/tmp/list/weather_chunk_shown // image key = image this client holds
/client/var/tmp/list/weather_chunk_fading // images fading out, dropped next step

/obj/screen/plane_master/weather_roof_mask
	name = "weather roof mask plane master"
	plane = WEATHER_ROOF_PLANE
	render_target = "*weather_roof"
	blend_mode = BLEND_OVERLAY
	mouse_opacity = 0
	appearance_flags = NO_CLIENT_COLOR | PLANE_MASTER
	// Roofed areas draw their mask almost clear, so a client without this
	// plane master sees nothing of it. Here it is made solid.
	color = list(1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,255, 0,0,0,0)

// A roofed area keeps the weather off its tiles. Safe to call again after a
// load has restored the area's saved icon state or location.
/area/proc/weather_roof_mask()
	if (location == AREA_INSIDE)
		icon = 'icons/effects/weather_roof.dmi'
		icon_state = "roof"
		plane = WEATHER_ROOF_PLANE
		alpha = 3
	else if (plane == WEATHER_ROOF_PLANE)
		icon = 'icons/effects/weather.dmi'
		icon_state = ""
		plane = LIGHTING_PLANE
		alpha = 255

// How strongly the cloud shadow and the rain are drawn at a point, 0 to
// WEATHER_EDGE_LEVELS. The corners of the pieces are asked, and a corner is
// shared by the four pieces round it, so the fade runs unbroken from one
// piece to the next.
/proc/weather_shadow_level(x, y)
	return round(WEATHER_EDGE_LEVELS * min(1, weather_storm_strength(x, y) / WEATHER_BAND_STEADY), 1)

/proc/weather_rain_level(x, y)
	var/strength = weather_storm_strength(x, y)
	if (strength < WEATHER_BAND_LIGHT)
		return 0
	return min(WEATHER_EDGE_LEVELS, 1 + round((WEATHER_EDGE_LEVELS - 1) * (strength - WEATHER_BAND_LIGHT) / (WEATHER_BAND_STEADY - WEATHER_BAND_LIGHT), 1))

// The fade of one piece, from the levels at its four corners (south-west,
// south-east, north-west, north-east): a state of weather_edge.dmi such as
// "m0123", "" where it is drawn whole, or null where nothing is drawn.
/proc/weather_edge_mask(sw, se, nw, ne)
	if (!sw && !se && !nw && !ne)
		return null
	if (sw == WEATHER_EDGE_LEVELS && se == sw && nw == sw && ne == sw)
		return ""
	return "m[sw][se][nw][ne]"

// What to draw over one chunk: list(precipitation look or null, its opacity
// at the middle, cloud shadow opacity, shadow fade, precipitation fade), or
// null for clear sky. The fades are weather_edge_mask() answers. The shadow
// reaches further out than the rain does, so the cloud is seen arriving
// before it breaks.
/proc/weather_chunk_state(cx, cy, z)
	var/x = cx * WEATHER_CHUNK + 1
	var/y = cy * WEATHER_CHUNK + 1
	// Tiles are centred on whole numbers, so the piece's edges lie half a tile out.
	var/west = x - 0.5
	var/east = x + WEATHER_CHUNK - 0.5
	var/south = y - 0.5
	var/north = y + WEATHER_CHUNK - 0.5
	var/shadow_mask = weather_edge_mask(weather_shadow_level(west, south), weather_shadow_level(east, south), weather_shadow_level(west, north), weather_shadow_level(east, north))
	if (isnull(shadow_mask))
		return null
	var/rain_mask = weather_edge_mask(weather_rain_level(west, south), weather_rain_level(east, south), weather_rain_level(west, north), weather_rain_level(east, north))
	var/strength = weather_storm_strength(x + WEATHER_CHUNK / 2, y + WEATHER_CHUNK / 2)
	var/severe = weather_storm_severe
	// The climate of the open ground in the chunk: its middle, else a corner.
	var/area/place
	for (var/list/at in list(list(2, 2), list(0, 0), list(3, 3), list(0, 3), list(3, 0)))
		var/turf/T = locate(min(x + at[1], world.maxx), min(y + at[2], world.maxy), z)
		var/area/here = T ? T.loc : null
		if (istype(here, /area/caribbean) && here.location == AREA_OUTSIDE)
			place = here
			break
	if (!place)
		return null
	var/shadow = round(190 * min(1, strength / WEATHER_BAND_STEADY))
	var/list/state = isnull(rain_mask) ? null : weather_storm_state(place.climate, max(strength, WEATHER_BAND_LIGHT), severe)
	// Zone weather already draws itself on the area.
	if (!state || (place.weather == state[2] && place.weather_intensity >= state[3]))
		return list(null, 0, shadow, shadow_mask, null)
	var/alpha = 255
	if (strength < WEATHER_BAND_STEADY)
		alpha = round(70 + 185 * max(0, strength - WEATHER_BAND_LIGHT) / (WEATHER_BAND_STEADY - WEATHER_BAND_LIGHT))
	return list(state[1], alpha, shadow, shadow_mask, rain_mask)

// The cloud shadow slides the way the wind carries the storms.
/proc/weather_shadow_look()
	var/list/wind = weather_wind_vector()
	if (wind[1] > 0)
		return "shadow_e"
	if (wind[1] < 0)
		return "shadow_w"
	return wind[2] > 0 ? "shadow_n" : "shadow_s"

// The cloud is one field two chunks on a side, so the pattern repeats every
// eight tiles: each chunk shows the quarter of it that its place calls for.
/proc/weather_shadow_piece(look, cx, cy)
	return "[look]_[cx % 2][cy % 2]"

// One icon for each fade, made the first time it is asked for.
var/global/list/weather_edge_icons = list()

/proc/weather_edge_icon(mask)
	var/icon/fade = weather_edge_icons[mask]
	if (!fade)
		fade = icon('icons/effects/weather_edge.dmi', mask)
		weather_edge_icons[mask] = fade
	return fade

// The shared image for one layer of one chunk. A piece on the storm's edge
// is cut by a fade (mask): the mask then carries the strength, and the image
// is drawn at the layer's full opacity under it. The key names the mask, so
// a piece whose fade changes is a new image that fades in while the old one
// fades out.
/proc/weather_chunk_image(key, cx, cy, z, sheet, look, alpha, layer, mask)
	var/image/I = weather_chunk_images[key]
	if (!I)
		I = image(sheet, locate(cx * WEATHER_CHUNK + 1, cy * WEATHER_CHUNK + 1, z), look)
		I.plane = LIGHTING_PLANE
		I.layer = layer
		I.mouse_opacity = 0
		I.alpha = 0
		if (mask)
			I.filters = filter(type = "alpha", icon = weather_edge_icon(mask))
		weather_chunk_images[key] = I
	else if (I.icon_state != look)
		I.icon_state = look
	if (I.alpha != alpha)
		animate(I, alpha = alpha, time = 20)
	return I

var/global/weather_chunks_fading = FALSE // some client still holds a faded image

/proc/weather_chunks_step()
	if (!weather_storm_count && !weather_chunk_images.len && !weather_chunks_fading)
		return
	weather_chunks_fading = FALSE
	var/list/live = list() // image key = image, drawn for somebody this step
	var/list/known = list() // chunk key = its state, or FALSE for clear sky
	var/list/wants = list() // client = the images it should hold
	var/shadow_look = weather_shadow_look()
	for (var/client/C in clients)
		var/list/want = list()
		wants[C] = want
		var/turf/T = get_turf(C.eye) || get_turf(C.mob)
		if (T && weather_storm_count)
			var/list/size = getviewsize(C.view)
			var/reach_x = round(size[1] / 2) + WEATHER_CHUNK
			var/reach_y = round(size[2] / 2) + WEATHER_CHUNK
			var/cx_low = max(0, round((T.x - reach_x - 1) / WEATHER_CHUNK))
			var/cx_high = min(round((world.maxx - 1) / WEATHER_CHUNK), round((T.x + reach_x - 1) / WEATHER_CHUNK))
			var/cy_low = max(0, round((T.y - reach_y - 1) / WEATHER_CHUNK))
			var/cy_high = min(round((world.maxy - 1) / WEATHER_CHUNK), round((T.y + reach_y - 1) / WEATHER_CHUNK))
			for (var/cx = cx_low, cx <= cx_high, cx++)
				for (var/cy = cy_low, cy <= cy_high, cy++)
					var/key = "[cx],[cy],[T.z]"
					var/list/state = known[key]
					if (isnull(state))
						state = weather_chunk_state(cx, cy, T.z)
						known[key] = state || FALSE
						if (state)
							if (state[1])
								var/rain_key = "[key]:[state[5]]"
								live[rain_key] = weather_chunk_image(rain_key, cx, cy, T.z, 'icons/effects/weather_chunks.dmi', state[1], state[5] ? 255 : state[2], 10, state[5])
							var/shadow_key = "s[key]:[state[4]]"
							live[shadow_key] = weather_chunk_image(shadow_key, cx, cy, T.z, 'icons/effects/weather_storm.dmi', weather_shadow_piece(shadow_look, cx, cy), 190, 9, state[4])
					if (!state)
						continue
					if (state[1])
						want["[key]:[state[5]]"] = live["[key]:[state[5]]"]
					want["s[key]:[state[4]]"] = live["s[key]:[state[4]]"]
	for (var/client/C in wants)
		var/list/want = wants[C]
		// Images that were fading out last step have gone clear.
		if (C.weather_chunk_fading)
			C.images -= C.weather_chunk_fading
			C.weather_chunk_fading = null
		var/list/shown = C.weather_chunk_shown
		if (shown)
			for (var/key in shown)
				if (want[key] == shown[key])
					continue
				if (live[key] == shown[key])
					// Still drawn for somebody: it only left this player's view.
					C.images -= shown[key]
				else
					// No longer drawn at all: it fades out below, then goes.
					if (!C.weather_chunk_fading)
						C.weather_chunk_fading = list()
					C.weather_chunk_fading += shown[key]
					weather_chunks_fading = TRUE
		for (var/key in want)
			if (!shown || shown[key] != want[key])
				C.images += want[key]
		C.weather_chunk_shown = want.len ? want : null
	for (var/key in weather_chunk_images)
		if (!live[key])
			var/image/gone = weather_chunk_images[key]
			animate(gone, alpha = 0, time = 20)
			weather_chunk_images -= key
	weather_lightning_step()

#undef WEATHER_EDGE_LEVELS
#undef WEATHER_CHUNK
