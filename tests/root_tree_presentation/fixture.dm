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
	plane = GAME_PLANE
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
var/global/fixture_failed = FALSE
var/global/fixture_run
var/global/fixture_manifest
var/global/fixture_head
var/global/fixture_failure_control
var/global/list/fixture_identity_controls = list()

/proc/fixture_fail(reason)
	if(!fixture_failed)
		fixture_failed = TRUE
		fdel("phase.ready.json")
		fdel("complete.txt")
		text2file(json_encode(list("schema"=2,"run"=fixture_run,"status"="failed","reason"=reason)), "fixture.failed.json")
	return FALSE

/world/Error(exception/E, datum/E_src)
	fixture_fail("native_runtime")
	return ..()

/proc/fixture_hex(value, size)
	if(!istext(value) || length(value) != size)
		return FALSE
	for(var/i = 1, i <= size, i++)
		if(!findtext("0123456789abcdef", copytext(value, i, i+1)))
			return FALSE
	return TRUE

/proc/fixture_check(name, passed)
	if(passed != TRUE)
		return fixture_fail("identity_control_[name]")
	fixture_identity_controls[name] = TRUE
	return TRUE

/client/New()
	if(fixture_client)
		return null
	fixture_client = src
	return ..()
/client/var/adminobs = FALSE

/client/Del()
	if(los_context)
		los_context.retire()
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
	var/list/binding = json_decode(file2text("run.binding.json"))
	if(!islist(binding) || binding["schema"] != 2 || !fixture_hex(binding["run"], 32) || !fixture_hex(binding["manifest"], 64) || !fixture_hex(binding["head"], 40) || !(binding["failure_control"] in list(null, "runtime", "admission")))
		fixture_fail("run_binding")
		return
	fixture_run = binding["run"]
	fixture_manifest = binding["manifest"]
	fixture_head = binding["head"]
	fixture_failure_control = binding["failure_control"]
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
	if(fixture_failed || !fixture_run)
		fixture_fail("login_after_failure")
		del(client)
		return
	if(copytext(key,1,6) != "Guest")
		fixture_fail("non_guest")
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
		while(client && phase < 9 && !fixture_failed)
			var/requested = text2num(file2text("phase.request"))
			if(requested != phase+1)
				sleep(1)
				continue
			phase = requested
			if(fixture_phase(phase, src) != TRUE || fixture_failed)
				fixture_fail("phase_failed")
				break
			sleep(5)
			var/list/witness = fixture_checkpoint(phase, src)
			if(fixture_failed || !witness)
				fixture_fail("settled_frame_failed")
				break
			fdel("phase.ready.json")
			text2file(json_encode(witness),"phase.ready.json")
		if(phase == 9 && !fixture_failed)
			text2file("COMPLETE", "complete.txt")

/proc/fixture_phase(phase, mob/living/human/M)
	if(phase == 1)
		return TRUE // Native identity baseline; no root presenter.
	if(phase == 2)
		if(fixture_failure_control == "runtime")
			CRASH("Injected fixture runtime control")
		if(fixture_failure_control == "admission")
			var/obj/structure/wild/tree/live_tree/rejected_tree = fixture_trees[1]
			rejected_tree.pixel_w = 1
		var/datum/los_context/V = new(M.client)
		for(var/obj/structure/wild/tree/live_tree/T in fixture_trees)
			if(!V.admit_root_tree(T))
				return fixture_fail("root_admission")
		if(!fixture_transform_controls(M, V))
			return FALSE
		fixture_presenter = new(M.client, V)
		if(fixture_presenter.retired)
			return fixture_fail("presenter_admission")
		if(!fixture_plane_refresh_controls(M))
			return FALSE
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
	if((phase == 9 && accepted) || (phase != 9 && !accepted))
		return fixture_fail("frame_admission")
	return !fixture_failed

// Native controls execute before phase 2 can be acknowledged. No controller
// may infer that a runtime in this callee automatically aborts its caller.
/proc/fixture_transform_controls(mob/living/human/M, datum/los_context/V)
	var/obj/structure/wild/tree/live_tree/T = fixture_trees[1]
	var/obj/screen/plane_master/G = M.hud_used.plane_masters["[GAME_PLANE]"]
	var/matrix/original_tree = T.transform
	var/matrix/original_plane = G.transform
	if(!fixture_check("helper_null", root_tree_identity_transform(null)) || !fixture_check("tree_default", V.root_tree_admitted(T)))
		return FALSE
	T.transform = null
	if(!fixture_check("tree_null", V.root_tree_admitted(T)))
		return FALSE
	T.transform = matrix(1,0,0,0,1,0)
	if(!fixture_check("tree_identity", V.root_tree_admitted(T)))
		return FALSE
	var/list/changes = list("translate"=matrix(1,0,1,0,1,0), "scale"=matrix(2,0,0,0,1,0), "shear"=matrix(1,1,0,0,1,0), "rotate"=matrix(0,-1,0,1,0,0))
	for(var/name in changes)
		T.transform = changes[name]
		if(!fixture_check("tree_[name]", !root_tree_identity_transform(T.transform) && !V.root_tree_admitted(T)))
			return FALSE
	T.transform = original_tree
	if(!fixture_check("plane_default", root_tree_identity_transform(G.transform)))
		return FALSE
	G.transform = null
	if(!fixture_check("plane_null", root_tree_identity_transform(G.transform)))
		return FALSE
	G.transform = matrix(1,0,0,0,1,0)
	if(!fixture_check("plane_identity", root_tree_identity_transform(G.transform)))
		return FALSE
	for(var/name in changes)
		G.transform = changes[name]
		var/datum/root_tree_presenter/probe = new(M.client, V)
		var/rejected = probe.retired
		probe.retire()
		qdel(probe)
		if(!fixture_check("plane_constructor_[name]", rejected))
			return FALSE
	G.transform = matrix(1,0,0,0,1,0)
	var/datum/root_tree_presenter/identity_probe = new(M.client, V)
	var/identity_admitted = !identity_probe.retired && identity_probe.planes_admitted()
	identity_probe.retire()
	qdel(identity_probe)
	if(!fixture_check("plane_constructor_identity", identity_admitted))
		return FALSE
	G.transform = original_plane
	return !fixture_failed

/proc/fixture_plane_refresh_controls(mob/living/human/M)
	var/obj/screen/plane_master/G = M.hud_used.plane_masters["[GAME_PLANE]"]
	var/matrix/original_plane = G.transform
	var/list/changes = list("translate"=matrix(1,0,1,0,1,0), "scale"=matrix(2,0,0,0,1,0), "shear"=matrix(1,1,0,0,1,0), "rotate"=matrix(0,-1,0,1,0,0))
	for(var/name in changes)
		G.transform = changes[name]
		if(!fixture_check("plane_refresh_[name]", !fixture_presenter.planes_admitted() && !fixture_presenter.refresh() && (fixture_presenter.shutter in M.client.screen)))
			return FALSE
	G.transform = matrix(1,0,0,0,1,0)
	if(!fixture_check("plane_refresh_identity", fixture_presenter.planes_admitted() && fixture_presenter.refresh()))
		return FALSE
	G.transform = original_plane
	return fixture_check("plane_restore", fixture_presenter.planes_admitted() && fixture_presenter.refresh())

/proc/fixture_checkpoint(phase, mob/living/human/M)
	if(fixture_failed || !M || !M.client)
		return null
	var/active = fixture_presenter && !fixture_presenter.retired && M.client.root_tree_presenter == fixture_presenter
	var/rendered = 0
	var/closed = FALSE
	if(phase > 1)
		if(!active)
			return null
		var/accepted = fixture_presenter.refresh()
		closed = fixture_presenter.shutter in M.client.screen
		for(var/image/I in fixture_presenter.owned_images)
			if(I.icon)
				rendered++
		var/expected = phase == 9 ? 0 : (phase < 5 ? 3 : 2)
		if(rendered != expected || (phase == 9 ? (accepted || !closed) : (!accepted || closed)))
			return null
	return list("schema"=2,"run"=fixture_run,"manifest"=fixture_manifest,"head"=fixture_head,"phase"=phase,"status"=(phase == 9 ? "denied" : "ready"),"renderer_active"=!!active,"rendered"=rendered,"shutter"=closed,"identity_controls"=fixture_identity_controls.Copy())
