//Creates a new turf
/turf/proc/ChangeTurf(var/path, var/tell_universe=1, var/force_lighting_update = FALSE, datum/durable_nomads_event/nomads_event = null)
	if (!path)
		return
	// Construction/replacement is an explicit activation, including same-type use.
	activate_reserved_lighting()
	if(path == type)
		return src

	// This makes sure that turfs are not changed to space when one side is part of a zone
	overlays.Cut()
	var/old_opacity = opacity
	var/old_dynamic_lighting = dynamic_lighting
	var/list/old_affecting_lights = affecting_lights
	var/old_lighting_overlay = lighting_overlay
	// Turf refs are positional: after the replacement src is the new turf, so
	// the shared corners are saved by value and put back on it.
	var/datum/lighting_corner/old_corner_ne = corner_ne
	var/datum/lighting_corner/old_corner_se = corner_se
	var/datum/lighting_corner/old_corner_sw = corner_sw
	var/datum/lighting_corner/old_corner_nw = corner_nw
	var/old_radiation = radiation
	var/old_terrain_grade = terrain_grade
	var/old_pollution = pollution
	var/old_pollution_index = pollution_index
	var/turf/W
	if(nomads_event && ispath(path, /turf/floor/lava))
		W = new path(src, null, nomads_event)
	else
		W = new path(src)

	W.levelupdate()
	// Graded ground stays at its height when the turf on it changes.
	W.terrain_grade = old_terrain_grade
	// Ground pollution stays too (ploughing or flooring does not clean it).
	if (old_pollution || old_pollution_index)
		W.pollution_take_over(old_pollution, old_pollution_index)
	. =  W
//end of else
	lighting_overlay = old_lighting_overlay
	affecting_lights = old_affecting_lights
	corner_ne = old_corner_ne
	corner_se = old_corner_se
	corner_sw = old_corner_sw
	corner_nw = old_corner_nw
	// A replacement subtype may itself have a map-authored reservation default.
	// Restore graph ownership before activation can build any missing overlay.
	W.activate_reserved_lighting()
	rad_act(old_radiation)

	for (var/atom/A in contents)
		if (A.light)
			A.light.force_update = TRUE

	for (var/i = TRUE to 4)//Generate more light corners when needed. If removed - pitch black shuttles will come for your soul!
		if (get_corner(i)) // Already have a corner on this direction.
			continue
		set_corner(i, new/datum/lighting_corner(src, LIGHTING_CORNER_DIAGONAL[i]))

	if ((old_opacity != opacity) || (dynamic_lighting != old_dynamic_lighting) || force_lighting_update)
		reconsider_lights()

	if (dynamic_lighting != old_dynamic_lighting)
		if (dynamic_lighting)
			lighting_build_overlay()
		else
			lighting_clear_overlay()

	fix_broken_daylights()
	update_icon()

	W.sync_fullbright_coverage()
	if (terrain_shading_applied)
		W.terrain_shade_refresh()
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
