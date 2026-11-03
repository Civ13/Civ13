/obj/screen/plane_master
	screen_loc = "CENTER"
//	icon_state = "blank"
	appearance_flags = NO_CLIENT_COLOR | PLANE_MASTER | RESET_TRANSFORM | RESET_COLOR | RESET_ALPHA
	blend_mode = BLEND_OVERLAY

/obj/screen/plane_master/proc/backdrop(mob/mymob)

/obj/screen/plane_master/game_world
	name = "game world plane master"
	plane = GAME_PLANE
	blend_mode = BLEND_OVERLAY
	appearance_flags = PLANE_MASTER
	invisibility	 = INVISIBILITY_LIGHTING

/obj/screen/plane_master/game_world/backdrop(mob/mymob)
	filters = list()
	if(istype(mymob) && mymob.client && mymob.client.ambient_occlusion_enabled())
		filters += filter(type="drop_shadow", x=0, y=-2, size=4, color="#04080FAA")

// Default on; preferences that are not loaded yet keep the usual look.
/client/proc/ambient_occlusion_enabled()
	if(!prefs)
		return TRUE
	return is_preference_enabled(/datum/client_preference/ambient_occlusion)

/client/proc/refresh_ambient_occlusion()
	if(!mob || !mob.hud_used)
		return
	var/obj/screen/plane_master/game_world/G = mob.hud_used.plane_masters["[GAME_PLANE]"]
	if(!istype(G))
		return
	// The root tree compositor leases this plane's filters onto its scene
	// plane. Retire it first so it hands them back, then rebuild it from the
	// new filter list in the same call so denied trees are not left unmasked
	// until the next scheduled LOS refresh.
	if(root_tree_presenter)
		root_tree_presenter.retire()
	G.backdrop(mob)
	los_dirty = TRUE
	reconcile_geometric_los()

/obj/screen/plane_master/lighting
	name = "lighting plane master"
	plane = LIGHTING_PLANE
	layer = LIGHTING_LAYER
	blend_mode = BLEND_MULTIPLY
	invisibility = INVISIBILITY_LEVEL_TWO
	appearance_flags = NO_CLIENT_COLOR | PLANE_MASTER
	mouse_opacity = 0

/obj/screen/plane_master/lighting/New()
	..()
	#ifdef OPENDREAM
	appearance_flags |= KEEP_TOGETHER
	invisibility = 0
	#else
	#if LIGHTING_COMPOSITION_V2
	// Weather remains on plane 3; it must never share the tile RGB surface.
	blend_mode = BLEND_OVERLAY
	invisibility = 0
	#endif
	#endif

/obj/screen/plane_master/light_mask
	name = "experimental light-only plane master"
	plane = LIGHTING_MASK_PLANE
	blend_mode = BLEND_MULTIPLY
	invisibility = 0
	appearance_flags = NO_CLIENT_COLOR | PLANE_MASTER
	mouse_opacity = 0
	var/tmp/last_lighting_bypass

/obj/screen/plane_master/light_mask/backdrop(mob/mymob)
	#if LIGHTING_COMPOSITION_V2
	#ifndef OPENDREAM
	var/bypass = mymob && mymob.see_invisible >= INVISIBILITY_LEVEL_TWO
	if(!isnull(last_lighting_bypass) && last_lighting_bypass == bypass)
		return
	last_lighting_bypass = bypass
	// Explicit white coverage marks intentionally mask-free visible tiles.
	// Only uncovered pixels on this light-only plane are made black.
	color = bypass ? list(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1) : list(1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,1)
	#endif
	#endif

/mob/proc/update_lighting_plane()
	if(!client || !hud_used)
		return
	var/obj/screen/plane_master/light_mask/P = hud_used.plane_masters["[LIGHTING_MASK_PLANE]"]
	if(P)
		P.backdrop(src)


/obj/screen/plane_master/hud
	name = "hud plane master"
	plane = HUD_PLANE
	blend_mode = BLEND_OVERLAY
	appearance_flags = NO_CLIENT_COLOR | PLANE_MASTER