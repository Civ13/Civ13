// Diagnostic surface only. No world/New, login bypass, socket, shell, save or
// compiler invocation. Full game startup still needs separate isolation review.
#ifndef GAIA_VISIBILITY_FIXTURE_BUILD
#error Include this file only through the prepared gaia_visibility.dme
#endif

/proc/gaia_visibility_fixture_report()
	var/list/result = list("fixture" = "gaia_visibility", "world_width" = world.maxx, "world_height" = world.maxy, "world_levels" = world.maxz)
	var/list/rows = list()
	var/eligible_clients = 0
	for(var/client/C in clients)
		var/list/row = list("body_type" = C.mob ? "[C.mob.type]" : "none", "view" = "[C.view]", "enabled" = C.los_enabled)
		var/datum/los_context/V = C.los_context
		row["has_context"] = !!V
		if(V && V.eligible())
			eligible_clients++
			row["x"] = V.body.x
			row["y"] = V.body.y
			row["z"] = V.body.z
			var/datum/los_snapshot/S = V.capture()
			row["snapshot_ready"] = !!S
			row["blockers"] = S ? S.blockers.len : 0
		var/datum/root_tree_presenter/P = C.root_tree_presenter
		row["tree_presenter"] = !!P
		if(P)
			row["tree_images"] = P.images.len
			row["fallback_reason"] = P.fallback_reason
			row["fallback_count"] = P.fallback_count
		row["los_masks"] = C.los_presenter ? C.los_presenter.owned_images.len : 0
		rows += list(row)
	result["clients"] = rows
	result["eligible_clients"] = eligible_clients
	result["three_client_precondition"] = eligible_clients >= 3
	// These are prerequisites/diagnostics, never pixel acceptance or a PASS.
	result["pixel_acceptance"] = "not measured"
	result["input_acceptance"] = "not measured"
	result["performance_acceptance"] = "not measured"
	return result

/proc/gaia_visibility_fixture_root_report(atom/tree, mob/viewer)
	if(!tree || !viewer || !viewer.client || !isturf(tree.loc))
		return list("error" = "world root and real client required")
	var/client/C = viewer.client
	var/datum/los_context/V = C.los_context
	if(!V)
		return list("error" = "no context")
	var/datum/los_snapshot/S = V.capture()
	return list("root_type" = "[tree.type]", "x" = tree.x, "y" = tree.y, "z" = tree.z, "root_rgb" = root_light_rgb(tree.loc, viewer), "visual_decision" = S ? V.decision_snapshot(tree, S, "visual") : LOS_DENY, "hover_decision" = V.decision(viewer, tree, "hover"), "examine_decision" = V.decision(viewer, tree, "examine"), "snapshot_ready" = !!S)
