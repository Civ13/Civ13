//Creates a new turf
/turf/proc/ChangeTurf(var/path, var/tell_universe=1, var/force_lighting_update = FALSE)
	if (!path)
		return
	if(path == type)
		return src

	// This makes sure that turfs are not changed to space when one side is part of a zone
	overlays.Cut()
	var/old_opacity = opacity
	var/old_dynamic_lighting = dynamic_lighting
	var/list/old_affecting_lights = affecting_lights
	var/old_lighting_overlay = lighting_overlay
	var/list/old_lighting_corners = corners
	var/old_radiation = radiation
	var/turf/W = new path(src)

	W.levelupdate()
	. =  W
//end of else
	lighting_overlay = old_lighting_overlay
	affecting_lights = old_affecting_lights
	corners = old_lighting_corners
	rad_act(old_radiation)

	for (var/atom/A in contents)
		if (A.light)
			A.light.force_update = TRUE

	for (var/i = TRUE to 4)//Generate more light corners when needed. If removed - pitch black shuttles will come for your soul!
		if (corners[i]) // Already have a corner on this direction.
			continue
		corners[i] = new/datum/lighting_corner(src, LIGHTING_CORNER_DIAGONAL[i])

	if ((old_opacity != opacity) || (dynamic_lighting != old_dynamic_lighting) || force_lighting_update)
		reconsider_lights()

	if (dynamic_lighting != old_dynamic_lighting)
		if (dynamic_lighting)
			lighting_build_overlay()
		else
			lighting_clear_overlay()

	fix_broken_daylights()
	update_icon()

	return W

/turf/proc/transport_properties_from(turf/other)
	if(!istype(other, src.type))
		return FALSE
	src.set_dir(other.dir)
	src.icon_state = other.icon_state
	src.icon = other.icon
	// copy_overlays(other)
	src.underlays = other.underlays.Copy()
	if(other.decals)
		src.decals = other.decals.Copy()
		src.update_icon()
	return TRUE