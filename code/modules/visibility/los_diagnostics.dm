// Self-only, bounded rendering metadata. This does not refresh or mutate the
// scene, inspect world objects, or provide a general variable-reader capability.
/proc/los_diagnostic_text(value)
	if(isnull(value))
		return "(none)"
	return html_encode(copytext("[value]", 1, 257))

/client/verb/visibility_diagnostics()
	set name = "Visibility Diagnostics"
	set category = "OOC"
	set desc = "Show your own visibility compositor state without changing it."
	if(!mob || usr != mob || mob.client != src)
		return
	var/datum/root_tree_presenter/P = root_tree_presenter
	if(P && (P.owner != src || P.retired))
		P = null
	if(P)
		to_chat(src, "Visibility: scene_active=[P.scene_active]; fallback_reason=[los_diagnostic_text(P.fallback_reason)]")
	else
		to_chat(src, "Visibility: scene_active=0; fallback_reason=no owned compositor")
	if(!mob.hud_used)
		to_chat(src, "GAME render_target=(no HUD); mask render_target=(no HUD)")
		return
	var/obj/screen/plane_master/G = mob.hud_used.plane_masters["[GAME_PLANE]"]
	var/obj/screen/plane_master/L = mob.hud_used.plane_masters["[LIGHTING_MASK_PLANE]"]
	to_chat(src, "GAME render_target=[los_diagnostic_text(G ? G.render_target : null)]; mask render_target=[los_diagnostic_text(L ? L.render_target : null)]")
	if(!P)
		return
	// Only this presenter's owned relay list, never arbitrary client screens or
	// client images. Layer filters have no independent plane/layer: report their
	// parent relay's values and their actual attached blend/source parameters.
	var/relays = 0
	for(var/i = 1, i <= min(length(P.screens), 16), i++)
		var/obj/screen/root_scene_relay/R = P.screens[i]
		if(!istype(R))
			continue
		if(++relays > 8)
			break
		to_chat(src, "relay [relays]: plane=[R.plane]; layer=[R.layer]; blend=[R.blend_mode]; render_source=[los_diagnostic_text(R.render_source)]")
		for(var/j = 1, j <= min(length(R.filters), 2), j++)
			var/F = R.filters[j]
			if(F:type != "layer")
				continue
			to_chat(src, "mask layer-filter: parent_plane=[R.plane]; parent_layer=[R.layer]; blend=[F:blend_mode]; render_source=[los_diagnostic_text(F:render_source)]")
		// The current path uses a layer filter, not a mask child. If a future
		// owned relay has child appearances, expose only the same four fields.
		to_chat(src, "relay [relays] child_count=[length(R.overlays)]")
		for(var/k = 1, k <= min(length(R.overlays), 2), k++)
			var/child = R.overlays[k]
			to_chat(src, "relay child: plane=[child:plane]; layer=[child:layer]; blend=[child:blend_mode]; render_source=[los_diagnostic_text(child:render_source)]")
	if(!relays)
		to_chat(src, "owned relays=(none)")
