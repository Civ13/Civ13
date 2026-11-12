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

var/global/list/weather_chunk_images = list() // "cx,cy,z" = image

/client/var/tmp/list/weather_chunk_shown // "cx,cy,z" = image this client holds

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

// What to draw over one chunk: list(precipitation look or null, its opacity,
// cloud shadow opacity), or null for clear sky. The shadow reaches further
// out than the rain does, so the cloud is seen arriving before it breaks.
/proc/weather_chunk_state(cx, cy, z)
	var/x = cx * WEATHER_CHUNK + 1
	var/y = cy * WEATHER_CHUNK + 1
	var/strength = weather_storm_strength(x + WEATHER_CHUNK / 2, y + WEATHER_CHUNK / 2)
	if (strength < 0.02)
		return null
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
	var/list/state = weather_storm_state(place.climate, strength, severe)
	// Zone weather already draws itself on the area.
	if (!state || (place.weather == state[2] && place.weather_intensity >= state[3]))
		return list(null, 0, shadow)
	var/alpha = 255
	if (strength < WEATHER_BAND_STEADY)
		alpha = round(70 + 185 * (strength - WEATHER_BAND_LIGHT) / (WEATHER_BAND_STEADY - WEATHER_BAND_LIGHT))
	return list(state[1], alpha, shadow)

// The cloud shadow slides the way the wind carries the storms.
/proc/weather_shadow_look()
	var/list/wind = weather_wind_vector()
	if (wind[1] > 0)
		return "shadow_e"
	if (wind[1] < 0)
		return "shadow_w"
	return wind[2] > 0 ? "shadow_n" : "shadow_s"

// The shared image for one layer of one chunk, set to this look and opacity.
/proc/weather_chunk_image(key, cx, cy, z, sheet, look, alpha, layer)
	var/image/I = weather_chunk_images[key]
	if (!I)
		I = image(sheet, locate(cx * WEATHER_CHUNK + 1, cy * WEATHER_CHUNK + 1, z), look)
		I.plane = LIGHTING_PLANE
		I.layer = layer
		I.mouse_opacity = 0
		I.alpha = 0
		weather_chunk_images[key] = I
	else if (I.icon_state != look)
		I.icon_state = look
	if (I.alpha != alpha)
		animate(I, alpha = alpha, time = 20)
	return I

/proc/weather_chunks_step()
	if (!weather_storm_count && !weather_chunk_images.len)
		return
	var/list/live = list() // image key = image, drawn for somebody this step
	var/list/known = list() // chunk key = its state, or FALSE for clear sky
	var/shadow_look = weather_shadow_look()
	for (var/client/C in clients)
		var/list/want = list()
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
								live[key] = weather_chunk_image(key, cx, cy, T.z, 'icons/effects/weather_chunks.dmi', state[1], state[2], 10)
							live["s[key]"] = weather_chunk_image("s[key]", cx, cy, T.z, 'icons/effects/weather_storm.dmi', shadow_look, state[3], 9)
					if (!state)
						continue
					if (state[1])
						want[key] = live[key]
					want["s[key]"] = live["s[key]"]
		var/list/shown = C.weather_chunk_shown
		if (shown)
			for (var/key in shown)
				if (want[key] != shown[key])
					C.images -= shown[key]
		for (var/key in want)
			if (!shown || shown[key] != want[key])
				C.images += want[key]
		C.weather_chunk_shown = want.len ? want : null
	for (var/key in weather_chunk_images)
		if (!live[key])
			weather_chunk_images -= key
	weather_lightning_step()

#undef WEATHER_CHUNK
