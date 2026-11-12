// ============================================================
// Lightning and thunder (docs/weather-systems.md)
// ------------------------------------------------------------
// The heavy core of a rain storm throws lightning. A strike is seen and
// heard, and that is all it is: it starts no fire and hurts nobody. Each
// player near enough sees the sky flash, sees the bolt if the place it lands
// is on their screen, and hears the thunder after a wait that grows with the
// distance.
// ============================================================

#define WEATHER_THUNDER_RANGE 90 // tiles the flash and thunder carry

var/global/weather_lightning_count = 0 // strikes so far, for tests and reports

/obj/screen/weather_flash
	name = "lightning"
	icon = 'icons/effects/weather_roof.dmi'
	icon_state = "roof"
	screen_loc = "WEST,SOUTH to EAST,NORTH"
	plane = HUD_PLANE
	layer = -1
	mouse_opacity = 0
	alpha = 0
	should_save = FALSE

/client/var/tmp/obj/screen/weather_flash/weather_flash

// Each storm strong enough rolls for one strike a step (2 s): about one
// every 20 s, or every 8 s in a severe storm.
/proc/weather_lightning_step()
	if (!weather_storm_count)
		return
	for (var/datum/weather_system/S in weather_systems)
		if (S.kind != WEATHER_SYSTEM_STORM || S.power() < WEATHER_BAND_HEAVY)
			continue
		if (!prob(S.severe ? 25 : 10))
			continue
		// Somewhere in the inner part of the oval, where the rain is heaviest.
		var/angle = rand(0, 359)
		var/out = rand(0, 55) / 100
		var/x = round(S.centre_x() + cos(angle) * S.radius_x * out)
		var/y = round(S.centre_y() + sin(angle) * S.radius_y * out)
		if (x < 1 || y < 1 || x > world.maxx || y > world.maxy)
			continue
		weather_lightning(x, y)

// TRUE when the storm over this tile is one that throws lightning: heavy
// rain, not snow or blowing sand.
/proc/weather_lightning_sky(turf/T)
	var/area/place = T ? T.loc : null
	if (!istype(place, /area/caribbean))
		return FALSE
	var/strength = weather_storm_strength(T.x, T.y)
	if (strength < WEATHER_BAND_HEAVY)
		return FALSE
	var/list/state = weather_storm_state(place.climate, strength, weather_storm_severe)
	return state && (state[1] == "monsoon" || findtext(state[1], "rain") == 1)

// One strike at x,y on every level under that sky. Returns how many players
// saw or heard it.
/proc/weather_lightning(x, y)
	. = 0
	weather_lightning_count++
	var/look = "bolt[rand(1, 4)]"
	var/list/bolts = list() // "z" = image
	for (var/client/C in clients)
		var/mob/M = C.mob
		var/turf/T = M ? get_turf(M) : null
		if (!T)
			continue
		var/turf/strike = locate(x, y, T.z)
		if (!weather_lightning_sky(strike))
			continue
		var/dx = x - T.x
		var/dy = y - T.y
		var/distance = sqrt(dx * dx + dy * dy)
		if (distance > WEATHER_THUNDER_RANGE)
			continue
		.++
		var/area/place = T.loc
		var/outside = istype(place) && place.location == AREA_OUTSIDE
		var/near = 1 - distance / WEATHER_THUNDER_RANGE
		// The sky lights up: a soft wash of white that fades in half a second.
		if (!C.weather_flash)
			C.weather_flash = new
		C.screen |= C.weather_flash
		var/flash = round((outside ? 70 : 25) * near)
		animate(C.weather_flash, alpha = flash, time = 1)
		animate(alpha = round(flash / 3), time = 1)
		animate(alpha = flash, time = 1)
		animate(alpha = 0, time = 5)
		// The bolt itself, if it lands where this player can see.
		var/list/size = getviewsize(C.view)
		if (abs(dx) <= round(size[1] / 2) + 1 && abs(dy) <= round(size[2] / 2) + 5)
			var/image/bolt = bolts["[T.z]"]
			if (!bolt)
				bolt = image('icons/effects/weather_bolt.dmi', strike, look)
				bolt.plane = CHAT_PLANE
				bolt.pixel_x = -16
				bolt.mouse_opacity = 0
				bolt.appearance_flags = RESET_COLOR | RESET_ALPHA
				animate(bolt, alpha = 110, time = 1)
				animate(alpha = 255, time = 1)
				animate(alpha = 0, time = 4)
				bolts["[T.z]"] = bolt
			C.images += bolt
			weather_bolt_clear(C, bolt)
		if (outside && distance <= 6 && isliving(M) && !M.stat)
			to_chat(M, "<span class='danger'>Lightning strikes close by!</span>")
		weather_thunder(M, distance, outside)

/proc/weather_bolt_clear(client/C, image/bolt)
	set waitfor = FALSE
	sleep(8)
	if (C)
		C.images -= bolt

// Thunder follows the flash: a third of a second for every ten tiles.
/proc/weather_thunder(mob/M, distance, outside)
	set waitfor = FALSE
	sleep(round(distance / 3))
	if (!M || !M.client || M.ear_deaf > 0)
		return
	var/volume = round((outside ? 85 : 45) * (1 - distance / (WEATHER_THUNDER_RANGE * 1.2)))
	if (volume <= 0)
		return
	var/sound/S = sound(distance <= 25 ? 'sound/effects/thunder_near.ogg' : 'sound/effects/thunder_far.ogg')
	S.wait = FALSE
	S.channel = 0
	S.volume = volume
	S.frequency = rand(90, 110) / 100
	M << S

#undef WEATHER_THUNDER_RANGE
