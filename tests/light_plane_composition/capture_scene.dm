// SOURCE-ONLY PROPOSAL. No world/client entry point or native admission here.
// A separately reviewed hosted scene must supply ownership and guest admission.
#define LIGHTING_CAPTURE_SCENE_RELEASED FALSE

/obj/structure/wild/tree/live_tree/pine/lighting_capture
	// Fixed original art/offsets only; retain native opacity, density and layer.
	New()
		..()
		icon_state = "new_pine_1"
		pixel_x = -16
		pixel_y = 0

/obj/effect/lighting_capture_marker
	icon = 'icons/effects/icon.png'
	color = "#ff00ff"
	luminosity = 0
	opacity = FALSE
	density = FALSE
	anchored = TRUE
	plane = GAME_PLANE

/proc/lighting_capture_require_release()
	if(!LIGHTING_CAPTURE_SCENE_RELEASED)
		throw EXCEPTION("Lighting capture held: source review and exact hosted scope required")

// Call only after actual guest admission and production lighting initialization.
// This asserts production HUD construction; it does not claim production Login.
/proc/lighting_capture_attach_hud(mob/living/human/H)
	lighting_capture_require_release()
	if(!H || !H.client || H.hud_used)
		throw EXCEPTION("Expected one real guest with no prior fixture HUD")
	H.hud_used = new /datum/hud(H)
	H.update_lighting_plane()

/proc/lighting_capture_witness(mob/living/human/H, var/clear_control = FALSE)
	lighting_capture_require_release()
	if(world.maxx != 15 || world.maxy != 13 || world.maxz != 1)
		throw EXCEPTION("Wrong authored map dimensions")
	if(!H || !H.client || H.loc != locate(8,5,1) || H.client.eye != H || H.client.perspective != EYE_PERSPECTIVE || H.client.view != 3 || H.client.pixel_x || H.client.pixel_y || H.step_x || H.step_y)
		throw EXCEPTION("Wrong native camera identity or geometry")
	if(H.see_invisible >= INVISIBILITY_LEVEL_TWO || (H.sight & (SEE_TURFS|SEE_MOBS|SEE_OBJS)))
		throw EXCEPTION("Ordinary scene must retain ordinary native sight")
	var/obj/structure/wild/tree/live_tree/pine/lighting_capture/P = locate() in locate(8,6,1)
	var/obj/effect/lighting_capture_marker/hidden_marker = locate() in locate(8,7,1)
	var/obj/effect/lighting_capture_marker/visible_marker = locate() in locate(7,5,1)
	if(!P || P.opacity != !clear_control || P.icon_state != "new_pine_1" || P.pixel_x != -16 || P.pixel_y != 0 || !hidden_marker || !visible_marker)
		throw EXCEPTION("Authored tree/marker witness mismatch")
	var/list/native_view = view(H.client.view, H)
	if(!(P in native_view) || !(visible_marker in native_view) || ((hidden_marker in native_view) != clear_control))
		throw EXCEPTION("Native root visibility did not produce the required control")
	if(!created_lighting_corners_and_overlays || lighting_startup_in_progress || !H.hud_used)
		throw EXCEPTION("Production lighting/HUD startup is incomplete")
	var/obj/screen/plane_master/G = H.hud_used.plane_masters["[GAME_PLANE]"]
	var/obj/screen/plane_master/L = H.hud_used.plane_masters["[LIGHTING_PLANE]"]
	if(!G || !L || !(G in H.client.screen) || !(L in H.client.screen))
		throw EXCEPTION("Production plane masters are not attached")
	if(H.client.images.len || H.client.screen.len != H.hud_used.plane_masters.len)
		throw EXCEPTION("Unexpected fixture images or screen objects")
	for(var/obj/screen/S in H.client.screen)
		if(!istype(S, /obj/screen/plane_master) || H.hud_used.plane_masters["[S.plane]"] != S)
			throw EXCEPTION("Screen object is not an owned production plane master")
	#if LIGHTING_COMPOSITION_V2
	var/obj/screen/plane_master/M = H.hud_used.plane_masters["[LIGHTING_MASK_PLANE]"]
	if(!M || !(M in H.client.screen))
		throw EXCEPTION("Candidate light-only master is not attached")
	#endif
	var/turf/T = locate(8,5,1)
	if(!T.lighting_overlay || T.lighting_overlay.invisibility > H.see_invisible)
		throw EXCEPTION("Production dynamic mask is unavailable to this viewer")
	return TRUE

/proc/lighting_capture_clear_control()
	lighting_capture_require_release()
	var/obj/structure/wild/tree/live_tree/pine/lighting_capture/P = locate() in locate(8,6,1)
	if(!P || !P.opacity)
		throw EXCEPTION("Missing opaque baseline tree")
	// Declared clear-root causal control, identical in both compiled modes.
	P.opacity = FALSE

// Bounded scalar appearance/lighting witnesses, not a saved object graph.
// The future owner must bind these to the actual capture and retain them.
/proc/lighting_capture_snapshot(mob/living/human/H, var/clear_control = FALSE)
	lighting_capture_witness(H, clear_control)
	var/list/native_view = view(H.client.view, H)
	var/list/rows = list()
	for(var/turf/T in range(H.client.view, H))
		var/area/A = get_area(T)
		var/atom/movable/lighting_overlay/O = T.lighting_overlay
		rows += list(list("x" = T.x, "y" = T.y, "z" = T.z, "visible" = (T in native_view), "area" = "[A.type]", "dynamic" = A.dynamic_lighting, "mask" = !!O, "mask_plane" = O ? O.plane : null, "mask_invisibility" = O ? O.invisibility : null, "mask_color" = O ? O.color : null, "lumcount" = T.get_lumcount()))
	if(rows.len != 49)
		throw EXCEPTION("Expected exactly 49 native turf witnesses")
	return list("schema" = 1, "view" = H.client.view, "see_invisible" = H.see_invisible, "sight" = H.sight, "time_of_day" = time_of_day, "weather" = weather, "cells" = rows)
