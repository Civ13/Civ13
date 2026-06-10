// Returns the lowest turf available on a given Z-level
var/global/list/base_turf_by_z = list(
	"1" = /turf/floor/dirt,
	)

proc/get_base_turf(var/z)
	return base_turf_by_z["[z]"]

//An area can override the z-level base turf, so our solar array areas etc. can be space-based.
proc/get_base_turf_by_area(var/turf/T)
	var/area/A = T.loc
	if (A.base_turf)
		return A.base_turf
	return get_base_turf(T.z)
