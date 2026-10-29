// Isolated real-client pixel fixture. No game startup, live state or credentials.
#define TRUE 1
#define FALSE 0
#define GAME_PLANE 1
#define LIGHTING_PLANE 3
#define LIGHTING_MASK_PLANE 4
#define ROOT_TREE_PLANE 6
#define ROOT_WEATHER_PLANE 7
#define HUD_PLANE 15
#define LIGHTING_COMPOSITION_V2 1
#define CIV13_GEOMETRIC_LOS_CORE 1
#define CIV13_ROOT_TREE_PRESENTATION 1
#define INVISIBILITY_LIGHTING 20
#define INVISIBILITY_LEVEL_TWO 45
#define LIGHTING_LAYER 13
#define GAME_STATE_PREGAME 1
#define RR 1
#define GR 5
#define BR 9
#define AR 13
#define LIGHTING_BASE_MATRIX list(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1)
#define ismovable(A) istype(A,/atom/movable)
#define isturf(A) istype(A,/turf)
#define OPPOSITE_DIR(D) turn(D,180)
/world
	name = "Civ13 root RGB pixel fixture"
	hub = ""
	visibility = 0
	view = 7
	fps = 20
	maxx = 21
	maxy = 21
	maxz = 1
	turf = /turf/floor/plating
	mob = /mob/living/human
/datum
	var/should_save = FALSE
	proc/Destroy()
		return
/atom
	var/gcDestroyed = FALSE
	var/gc_destroyed = FALSE
	var/simulated = FALSE
	proc/InCone(mob/user, facing)
		return FALSE
/atom/movable
	var/anchored = FALSE
/area
	var/dynamic_lighting = TRUE
/turf
	var/atom/movable/lighting_overlay/lighting_overlay
	var/list/corners = list()
	proc/get_window_coeff()
		return 1
/turf/floor/plating
	icon = 'icons/turf/floors.dmi'
	icon_state = "white"
	luminosity = 1
/turf/wall
/obj/structure/simple_door
/obj/structure/wild/tree/live_tree
	name = "tree"
	icon = 'icons/obj/flora/bigtrees.dmi'
	icon_state = "tree_1"
	pixel_x = -16
	layer = 5.11
	opacity = TRUE
	density = TRUE
	anchored = TRUE
/atom/movable/lighting_overlay
	icon = 'icons/effects/icon.png'
	color = LIGHTING_BASE_MATRIX
	plane = LIGHTING_MASK_PLANE
	layer = 13
	blend_mode = BLEND_OVERLAY
	var/needs_update = FALSE
	var/list/last_color
	var/last_luminosity
/atom/movable/lighting_fullbright
/datum/lighting_corner
	var/lum_r
	var/lum_g
	var/lum_b
	var/list/masters = list()
/obj/screen
	plane = HUD_PLANE
/obj/screen/fov
/obj/screen/plane_master
	screen_loc = "CENTER"
	appearance_flags = PLANE_MASTER | NO_CLIENT_COLOR
	blend_mode = BLEND_OVERLAY
	mouse_opacity = 0
	proc/backdrop(mob/M)
		return
/obj/screen/plane_master/game
	plane = GAME_PLANE
/obj/screen/plane_master/weather
	plane = LIGHTING_PLANE
/obj/screen/plane_master/light_mask
	plane = LIGHTING_MASK_PLANE
	blend_mode = BLEND_MULTIPLY
	color = list(1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,1)
	var/last_lighting_bypass
/obj/screen/calibration
	icon = 'icons/turf/floors.dmi'
	icon_state = "white"
	color = "#f012b3"
	plane = HUD_PLANE
	screen_loc = "WEST,SOUTH"
	mouse_opacity = 0
/obj/hidden_witness
	icon = 'icons/turf/floors.dmi'
	icon_state = "white"
	color = "#ff00ff"
	invisibility = 100
/datum/hud
	var/list/plane_masters = list()
/datum/configuration
	var/disable_fov = TRUE
/datum/fixture_global_hud
	var/obj/screen/fov/fov = new
/mob
	var/datum/hud/hud_used
/mob/living/human
	var/list/HUDtech = list()
	var/stat = 0
	var/resting = FALSE
	var/lying = FALSE
	var/prone = FALSE
	var/mob/pulling
/proc/is_blind(mob/M)
	return FALSE
/proc/isobserver(mob/M)
	return FALSE
/proc/get_area(atom/A)
	return isturf(A) ? A.loc : null
/proc/environment_sweep_pause(work)
	return FALSE
/datum/fixture_map
	var/list/zlevels_without_lighting = list()
var/global/datum/fixture_map/map
/proc/warning(message)
	CRASH(message)
/proc/qdel(datum/D)
	if(D)
		root_tree_invalidate(D)
		D.Destroy()
		del(D)
var/global/lighting_startup_in_progress = FALSE
var/global/created_lighting_corners_and_overlays = TRUE
var/global/persistence_active_operation
var/global/datum/configuration/config = new
var/global/datum/fixture_global_hud/global_hud = new
var/global/list/time_of_day2luminosity = list("test"=0)
var/global/time_of_day = "test"
var/global/list/fixture_trees = list()
var/global/datum/root_tree_presenter/fixture_presenter
var/global/image/fixture_weather
var/global/client/fixture_client

/client/New()
	if(fixture_client)
		return null
	fixture_client = src
	return ..()
/client/var/adminobs = FALSE

/client/Del()
	if(root_tree_presenter)
		root_tree_presenter.retire()
	if(fixture_client == src)
		fixture_client = null
	return ..()

/proc/set_fixture_light(turf/T, red, green, blue)
	if(!T.lighting_overlay)
		var/atom/movable/lighting_overlay/L = new(T)
		T.lighting_overlay = L
	T.corners.Cut()
	for(var/d in list(NORTHEAST,SOUTHEAST,SOUTHWEST,NORTHWEST))
		var/datum/lighting_corner/C = new
		C.lum_r = red
		C.lum_g = green
		C.lum_b = blue
		C.masters[T] = d
		T.corners += C
	T.lighting_overlay.update_overlay()

/world/New()
	..()
	for(var/turf/T in world)
		set_fixture_light(T, 1, 1, 1)
	for(var/point in list(list(9,12),list(10,12),list(14,11),list(16,13)))
		var/obj/structure/wild/tree/live_tree/T = new(locate(point[1],point[2],1))
		fixture_trees += T
	var/obj/structure/wild/tree/live_tree/hidden = fixture_trees[4]
	hidden.color = "#0000ff"
	fixture_weather = image('icons/turf/floors.dmi', locate(10,12,1), "white")
	fixture_weather.color = "#24c8ff"
	fixture_weather.plane = LIGHTING_PLANE
	fixture_weather.layer = 20
	fixture_weather.pixel_y = 32

/mob/living/human/Login()
	..()
	if(copytext(key,1,6) != "Guest")
		text2file("FAILED_NON_GUEST", "client-ready.txt")
		del(client)
		return
	loc = locate(11,8,1)
	client.eye = src
	client.view = 7
	see_invisible = 25
	HUDtech["fov"] = new /obj/screen/fov
	hud_used = new
	for(var/path in list(/obj/screen/plane_master/game,/obj/screen/plane_master/weather,/obj/screen/plane_master/light_mask))
		var/obj/screen/plane_master/P = new path
		hud_used.plane_masters["[P.plane]"] = P
		client.screen += P
	client.screen += new /obj/screen/calibration
	client.images += fixture_weather
	update_lighting_plane()
	text2file("READY", "client-ready.txt")
	spawn(1)
		var/phase = 0
		while(client && phase < 9)
			var/requested = text2num(file2text("phase.request"))
			if(requested != phase+1)
				sleep(1)
				continue
			phase = requested
			fixture_phase(phase, src)
			sleep(5)
			text2file(json_encode(list("phase"=phase,"x"=x,"y"=y,"view"=client.view)),"phase.ready.json")
		text2file("COMPLETE", "complete.txt")

/proc/fixture_phase(phase, mob/living/human/M)
	if(phase == 1)
		return // Native identity baseline; no root presenter.
	if(phase == 2)
		var/datum/los_context/V = new(M.client)
		for(var/obj/structure/wild/tree/live_tree/T in fixture_trees)
			if(!V.admit_root_tree(T))
				CRASH("Root admission failed")
		fixture_presenter = new(M.client, V)
		if(fixture_presenter.retired)
			CRASH("Presenter admission failed")
	else
		fixture_presenter.invalidate()
	if(phase == 3)
		set_fixture_light(locate(9,12,1), 1, 0.2, 0.1)
		set_fixture_light(locate(10,12,1), 0.1, 1, 0.2)
		set_fixture_light(locate(14,11,1), 0.12, 0.18, 0.24)
		set_fixture_light(locate(9,13,1), 0, 0, 0)
	if(phase == 4)
		var/obj/structure/wild/tree/live_tree/T = fixture_trees[1]
		T.loc = locate(8,12,1)
		set_fixture_light(T.loc, 0.2, 0.3, 1)
	if(phase == 5)
		var/obj/structure/wild/tree/live_tree/T = fixture_trees[2]
		qdel(T)
	if(phase == 6)
		M.client.view = "15x15"
	if(phase == 7)
		M.see_invisible = INVISIBILITY_LEVEL_TWO
		M.update_lighting_plane()
	if(phase == 8)
		M.see_invisible = 25
		M.update_lighting_plane()
		var/turf/T = locate(14,11,1)
		var/atom/movable/lighting_overlay/L = T.lighting_overlay
		T.lighting_overlay = null
		qdel(L)
		var/area/A = T.loc
		A.dynamic_lighting = FALSE
		T.sync_fullbright_coverage()
	if(phase == 9)
		new /obj/hidden_witness(locate(11,12,1))
	var/accepted = fixture_presenter.refresh()
	if(!accepted && phase != 9)
		CRASH("Frame rejected")
