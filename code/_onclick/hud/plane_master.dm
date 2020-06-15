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
	invisibility	 = INVISIBILITY_LEVEL_TWO
	appearance_flags = NO_CLIENT_COLOR | PLANE_MASTER// | KEEP_TOGETHER
	mouse_opacity = 0

/obj/screen/plane_master/hud
	name = "hud plane master"
	plane = HUD_PLANE
	blend_mode = BLEND_OVERLAY
	appearance_flags = NO_CLIENT_COLOR | PLANE_MASTER