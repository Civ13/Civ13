// Source-only minimal native adapter. These are NOT the game's climate, topology,
// scheduler, floor definitions, persistence serializer, or complete lifecycle.
#define TRUE 1
#define FALSE 0
#define EXCEPTION(message) new /exception(message)
#define SECONDS *10
#define AREA_INSIDE 0
#define AREA_OUTSIDE 1
#define WEATHER_NONE 1
#define WEATHER_WET 2
#define WEATHER_EXTREME 3
#define WEATHER_SMOG 4
#define PROCESS_PRIORITY_LOW 4
#define GAME_STATE_PLAYING 3

var/global/datum/process_list/processes = new
var/global/persistence_save_in_progress = FALSE
var/global/persistence_active_operation = null
var/global/persistence_load_recovery_required = FALSE
var/global/snow_fixture_temperature_calls = 0
var/global/snow_fixture_topology_calls = 0
var/global/list/snow_fixture_links = list()
var/global/area/caribbean/snow_fixture_outdoors

/area
	var/location = AREA_OUTSIDE
	var/weather = WEATHER_WET
	var/weather_intensity = 1
	icon_state = "snow1"
/area/caribbean
/area/snow_fixture_other

/atom/proc/get_saved_vars()
	return list("fixture_saved_sentinel")
/atom/proc/persistence_runtime_var(key)
	return key == "fixture_parent_runtime"
/atom/proc/after_load()
	return

/decl/flooring
	var/name
	var/desc
	var/icon
	var/icon_base
	var/has_base_range = 0

/turf
	var/available_snow = 0
	var/available_dirt = 0
	var/soil_nutrition = 0
	var/fixture_saved_sentinel = "durable fixture value"
	var/fixture_temperature_c = 0
	var/fixture_temperature_calls = 0
/turf/sky
/turf/floor
	var/decl/flooring/flooring = null
	var/set_update_icon = null
	var/flooring_override = null
	var/overrided_icon_state = null
	icon = null
	icon_state = "fixture_ground"
/turf/floor/dirt
/turf/floor/dirt/fixture_subtype
/turf/floor/dirt/ploughed
/turf/floor/dirt/underground
/turf/floor/grass
/turf/floor/grass/fixture_subtype
/turf/floor/winter
	icon = 'icons/turf/snow.dmi'
	icon_state = "snow"
/turf/floor/winter/grass
/turf/floor/beach
/turf/floor/beach/water
/turf/floor/beach/water/ice
/turf/floor/beach/sand
/turf/floor/wood
/turf/floor/broken_floor
/turf/floor/space

/obj/roof
/obj/covers
/obj/snow_fixture_sentinel

/datum/process_list
	var/process/snowfall_ground/snowfall_ground = null

/process
	var/name
	var/schedule_interval
	var/start_delay
	var/priority
	var/list/fires_at_gamestates
/process/proc/setup()
	return
/process/proc/fire()
	return
/process/proc/reset_current_list()
	return

/proc/get_area(atom/A)
	while (A && !istype(A, /area))
		A = A.loc
	return A

// Explicit, per-turf Celsius injection, never actual climate or heater service.
/proc/get_temp(turf/T)
	snow_fixture_temperature_calls++
	T.fixture_temperature_calls++
	return T.fixture_temperature_c

/proc/snow_fixture_key(turf/T)
	return "[T.x],[T.y],[T.z]"

// Only upward adjacent same-coordinate fixture links are admissible. This makes
// the synthetic provider finite and acyclic without adopting game z topology.
/proc/snow_fixture_link(turf/lower, turf/upper)
	if (!lower || !upper || lower.x != upper.x || lower.y != upper.y || upper.z != lower.z + 1 || upper.z > 3)
		return FALSE
	snow_fixture_links[snow_fixture_key(lower)] = upper.z
	return TRUE

/proc/GetAbove(turf/T)
	snow_fixture_topology_calls++
	var/upper_z = snow_fixture_links[snow_fixture_key(T)]
	if (isnull(upper_z))
		return null
	if (!isnum(upper_z) || upper_z != T.z + 1 || upper_z > 3)
		throw EXCEPTION("Invalid synthetic topology link")
	return locate(T.x, T.y, upper_z)
