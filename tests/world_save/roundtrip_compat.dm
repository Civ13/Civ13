// Current loader dependencies for the ordinary roundtrip world only.
// Keep shared stubs.dm frozen: dedicated source packets pin its original bytes.
// There are no /obj/roof or roof-climate subtypes here. This type declaration
// does not enable roof reconstruction; all existing topology refusals remain.
/area/caribbean/roofed

// Match the production registry's ordinary (non-topology-restore) membership.
// The fixture uses immediate del(), not the game's qdel/Destroy lifecycle.
// Explicit empty instances must remain discoverable by the real roof finder.
var/global/list/area_list = list()
/area/New()
	..()
	area_list |= src
/area/Del()
	area_list -= src
	..()

// Production scalar/overlay defaults and icon projection, without weather
// sampling, registration, accumulation or floor after_load behavior. The
// ordinary /turf/test fixture exercises only the loader's clear-ground reset.
/turf
	var/weather_snow = 0 // Durable generated loose-snow units; authored snow uses available_snow.
	var/tmp/image/weather_snow_overlay = null

/turf/proc/snowfall_ground_icon()
	if (weather_snow_overlay)
		overlays -= weather_snow_overlay
	if (weather_snow > 0)
		if (!weather_snow_overlay)
			weather_snow_overlay = image('icons/turf/snow.dmi', icon_state = "snow", layer = 2.03)
			weather_snow_overlay.plane = plane
		overlays += weather_snow_overlay
	else
		weather_snow_overlay = null
