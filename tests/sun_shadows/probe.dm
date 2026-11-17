// Full-source probe for the sun (code/modules/1713/sun_shadows.dm): its path by
// latitude and season, the daylight colour, and tree shadows. Isolated startup.
/world
	hub = ""
	visibility = 0
	maxx = 8
	maxy = 8
	maxz = 1
	fps = 20
	turf = /turf/floor/grass
	area = /area

/world/OpenPort(port)
	if (port == "none")
		return ..("none")
	return FALSE

/world/Topic()
	return null

/client/New()
	del(src)

/obj/map_metadata/sun_shadows_probe
	sun_latitude = 45

// Skip the real metadata constructor (schedules, factions); only the map global matters.
/obj/map_metadata/sun_shadows_probe/New()
	map = src

/obj/map_metadata/sun_shadows_probe/sunless
	sun_latitude = null

// A plain caster: no seasons, branches or spawned timers.
/obj/structure/wild/sun_shadows_probe_tree
	icon = 'icons/obj/flora/bigtrees.dmi'
	sun_shadow_shape = "canopy"
	sun_shadow_size = 1.5

/obj/structure/wild/sun_shadows_probe_tree/New()
	sun_shadow_register()

var/sun_shadows_probe_checks = 0

/proc/sun_shadows_probe_assert(ok, label)
	sun_shadows_probe_checks++
	if (!ok)
		throw EXCEPTION(label)

/proc/sun_shadows_probe_shadows(atom/A)
	. = 0
	for (var/O in A.overlays)
		if (O:icon == 'icons/effects/sun_shadow.dmi')
			.++

// The seven continents' latitudes as the maps set them.
var/list/sun_shadows_probe_latitudes = list(35, -20, 45, 50, 25, 2, 40)

/proc/sun_shadows_probe_run()
	// Equinox at 45 north: due south at noon, 45 degrees up.
	var/list/A = sun_position(45, 0, 0.5)
	sun_shadows_probe_assert(A[1] == 180 && A[2] == 45, "equinox_noon_south")
	// Southern hemisphere: the noon sun stands in the north.
	A = sun_position(-20, sun_declination(-20, SEASON_WINTER), 0.5)
	sun_shadows_probe_assert(A[1] == 0 && A[2] > 40 && A[2] < 50, "south_winter_noon_north")
	// Local summer is higher than local winter in both hemispheres.
	for (var/lat in list(50, -20))
		var/list/summer = sun_position(lat, sun_declination(lat, SEASON_SUMMER), 0.5)
		var/list/winter = sun_position(lat, sun_declination(lat, SEASON_WINTER), 0.5)
		sun_shadows_probe_assert(summer[2] > winter[2] + 40, "summer_higher_[lat]")
	// Tropical seasons: wet is the summer sun, dry the winter one.
	sun_shadows_probe_assert(sun_declination(25, SEASON_WET) > 20 && sun_declination(25, SEASON_DRY) < -20 && sun_declination(25, SEASON_SPRING) == 0, "tropical_seasons")
	// Polar night: no sunrise; midnight sun: up all day.
	sun_shadows_probe_assert(!sun_position(75, sun_declination(75, SEASON_WINTER), 0.5), "polar_night")
	A = sun_position(75, sun_declination(75, SEASON_SUMMER), 0.1)
	sun_shadows_probe_assert(A && A[2] > 5, "midnight_sun")
	// Every continent and season: the sun rises in the east half, sets in the
	// west half, and is highest at Midday.
	for (var/lat in sun_shadows_probe_latitudes)
		for (var/s in list(SEASON_SPRING, SEASON_SUMMER, SEASON_FALL, SEASON_WINTER))
			var/dec = sun_declination(lat, s)
			var/list/rise = sun_position(lat, dec, 0.1)
			var/list/noon = sun_position(lat, dec, 0.5)
			var/list/set_sun = sun_position(lat, dec, 0.9)
			sun_shadows_probe_assert(rise[1] > 0 && rise[1] < 180, "rises_east_[lat]_[s]")
			sun_shadows_probe_assert(set_sun[1] > 180 && set_sun[1] < 360, "sets_west_[lat]_[s]")
			sun_shadows_probe_assert(noon[2] > rise[2] && noon[2] > set_sun[2], "noon_highest_[lat]_[s]")

	// A map without a latitude keeps the old daylight: no sun, no colour.
	map = new /obj/map_metadata/sun_shadows_probe/sunless
	time_of_day = "Midday"
	sun_shadows_probe_assert(!sun_angles() && !sun_daylight_tint(), "sunless_map")
	map = new /obj/map_metadata/sun_shadows_probe
	season = SEASON_SPRING
	sun_shadows_probe_assert(sun_angles("Midday") && !sun_angles("Night"), "night_no_sun")
	sun_shadows_probe_assert(islist(sun_daylight_tint()), "tinted_daylight")
	sun_shadows_probe_assert(map.persistence_runtime_var("sun_latitude"), "latitude_not_saved")

	// Trees: one shared image per sun, swapped on phase changes, gone at night.
	var/obj/structure/wild/sun_shadows_probe_tree/T1 = new(locate(2, 2, 1))
	var/obj/structure/wild/sun_shadows_probe_tree/T2 = new(locate(5, 5, 1))
	sun_shadows_probe_assert((T1 in sun_shadow_casters) && (T2 in sun_shadow_casters), "casters_registered")
	sun_shadows_phase("Morning")
	sun_shadows_probe_assert(sun_shadows_probe_shadows(T1) == 1 && T1.sun_shadow_overlay && T1.sun_shadow_overlay == T2.sun_shadow_overlay, "morning_shared_shadow")
	sun_shadows_probe_assert(T1.sun_shadow_overlay.mouse_opacity == 0 && T1.sun_shadow_overlay.plane == FLOOR_PLANE, "shadow_not_clickable")
	var/image/morning = T1.sun_shadow_overlay
	sun_shadows_phase("Evening")
	sun_shadows_probe_assert(sun_shadows_probe_shadows(T1) == 1 && T1.sun_shadow_overlay != morning, "evening_swaps")
	// A tree placed mid-day takes the current shadow at once.
	var/obj/structure/wild/sun_shadows_probe_tree/T3 = new(locate(7, 7, 1))
	sun_shadows_probe_assert(T3.sun_shadow_overlay == T1.sun_shadow_overlay, "new_tree_current_shadow")
	sun_shadows_phase("Night")
	sun_shadows_probe_assert(!sun_shadows_probe_shadows(T1) && !T1.sun_shadow_overlay && !sun_tree_angles, "night_clears")
	// The season turning moves the sun on the next phase.
	sun_shadows_phase("Midday")
	var/list/spring_noon = sun_tree_angles
	season = SEASON_WINTER
	sun_shadows_phase("Midday")
	sun_shadows_probe_assert(sun_tree_angles && sun_tree_angles[2] < spring_noon[2], "season_lowers_sun")
	qdel(T3)
	sun_shadows_probe_assert(!(T3 in sun_shadow_casters), "destroy_unregisters")
	sun_shadows_probe_assert(sun_ambient_shadow_x() == 0, "noon_shadow_straight_down")

/world/New()
	OpenPort("none")
	var/error = null
	try
		sun_shadows_probe_run()
	catch (var/exception/probe_error)
		error = probe_error.name
	text2file(error ? "FAIL [error]" : "PASS", "result.txt")
	text2file(json_encode(list("checks" = sun_shadows_probe_checks, "error" = error, "byond_build" = byond_build)), "receipt.json")
	del(world)
