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
	if(istype(mymob) && mymob.client)
		filters += filter(type="drop_shadow", x=0, y=-2, size=4, color="#04080FAA")

/obj/screen/plane_master/lighting
	name = "lighting plane master"
	plane = LIGHTING_PLANE
	layer = LIGHTING_LAYER
	blend_mode = BLEND_MULTIPLY
	invisibility = 0
	appearance_flags = NO_CLIENT_COLOR | PLANE_MASTER
	mouse_opacity = 0
	var/tmp/last_lighting_bypass

/obj/screen/plane_master/lighting/New()
	..()
	#ifdef OPENDREAM
	appearance_flags |= KEEP_TOGETHER
	invisibility = 0
	#endif
// Compose tile RGB on a transparent plane, then make uncovered pixels black.
// Never broaden native world visibility to obtain an occluded tile's mask.
/obj/screen/plane_master/lighting/backdrop(mob/mymob)
	#ifndef OPENDREAM
	var/bypass = mymob && mymob.see_invisible >= INVISIBILITY_LEVEL_TWO
	if(!isnull(last_lighting_bypass) && last_lighting_bypass == bypass)
		return
	last_lighting_bypass = bypass
	// Preserve the existing see>=45 lighting bypass (NVG/dead/observer sight).
	// This changes only the client's plane; corner data remains authoritative.
	color = bypass ? list(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1) : list(1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,1)
	#endif

/mob/proc/update_lighting_plane()
	if(!client || !hud_used)
		return
	var/obj/screen/plane_master/lighting/P = hud_used.plane_masters["[LIGHTING_PLANE]"]
	if(P)
		P.backdrop(src)


/obj/screen/plane_master/hud
	name = "hud plane master"
	plane = HUD_PLANE
	blend_mode = BLEND_OVERLAY
	appearance_flags = NO_CLIENT_COLOR | PLANE_MASTER