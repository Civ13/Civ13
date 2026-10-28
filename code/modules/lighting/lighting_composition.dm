// Presentation-only coverage. This is not a light source and cannot reveal a
// hidden turf: normal native turf-root visibility still owns its appearance.
/atom/movable/lighting_fullbright
	name = ""
	icon = 'icons/effects/icon.png'
	plane = LIGHTING_MASK_PLANE
	layer = 13
	blend_mode = BLEND_OVERLAY
	color = list(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1)
	invisibility = INVISIBILITY_LIGHTING
	mouse_opacity = FALSE
	anchored = TRUE
	simulated = FALSE
	luminosity = 0
	should_save = FALSE

// Missing masks alone are not evidence of fullbright policy. Failed or pending
// dynamic lighting startup must remain dark rather than silently become white.
/turf/proc/needs_fullbright_coverage()
	if(lighting_overlay)
		return FALSE
	var/area/A = get_area(src)
	return (A && !A.dynamic_lighting) || (map && map.zlevels_without_lighting.Find(z))

/turf/proc/sync_fullbright_coverage()
	#if LIGHTING_COMPOSITION_V2
	#ifndef OPENDREAM
	var/needed = needs_fullbright_coverage()
	var/atom/movable/lighting_fullbright/retained
	for(var/atom/movable/lighting_fullbright/F in src)
		if(needed && !retained)
			retained = F
		else
			// Detach synchronously, so repeated refreshes cannot see stale owners.
			F.loc = null
			qdel(F)
	if(needed && !retained)
		new /atom/movable/lighting_fullbright(src)
	#endif
	#endif

/proc/sync_fullbright_coverage_world()
	#if LIGHTING_COMPOSITION_V2
	#ifndef OPENDREAM
	var/work = 0
	for(var/turf/T in world)
		T.sync_fullbright_coverage()
		if(environment_sweep_pause(++work))
			work = 0
	#endif
	#endif
