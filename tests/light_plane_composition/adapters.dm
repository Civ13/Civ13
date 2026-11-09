// Collaborators the production plane and overlay code gained after this fixture
// was written. No client preferences, root tree compositor, client daylight or
// lighting corners exist in this fixture, so each adapter takes its inert path.
/client/var/prefs = null
/datum/client_preference/ambient_occlusion
/client/proc/is_preference_enabled(preference)
	return TRUE
/datum/root_tree_presenter
	var/retired = TRUE
	var/scene_active = FALSE
	var/obj/screen/plane_master/game_plane
	var/obj/screen/plane_master/scene_plane
	var/list/original_filters
/client/var/datum/root_tree_presenter/root_tree_presenter = null
/proc/daylight_on_client()
	return FALSE
/proc/daylight_lum()
	return 0
/turf/proc/get_corner(i)
	return null
