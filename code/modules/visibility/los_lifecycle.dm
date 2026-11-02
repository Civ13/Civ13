// Client-owned presentation is rebuilt, never persisted or transferred between bodies.
/client/var/tmp/los_enabled = TRUE
/client/var/tmp/los_dirty = TRUE
/client/var/tmp/los_last_policy
/client/var/tmp/los_next_audit = 0
/client/var/tmp/los_last_error
/client/var/tmp/los_camera_radius_x = 0
/client/var/tmp/los_camera_radius_y = 0
/client/var/tmp/los_camera_pan_x = 0
/client/var/tmp/los_camera_pan_y = 0
/client/var/tmp/los_camera_union_until = -1

// animate() changes endpoint vars immediately. Preserve the previous viewport
// and every still-active endpoint until the declared animation finishes. This
// is client-owned so rebuilding the HUD/context cannot drop the in-flight sweep.
/client/proc/los_prepare_camera_pan(target_x, target_y, animation_time, previous_view)
	var/list/old_dimensions = getviewsize(previous_view)
	var/list/new_dimensions = getviewsize(view)
	if(!old_dimensions || old_dimensions.len != 2 || !new_dimensions || new_dimensions.len != 2)
		return
	var/view_x = max(round(old_dimensions[1] / 2), round(new_dimensions[1] / 2))
	var/view_y = max(round(old_dimensions[2] / 2), round(new_dimensions[2] / 2))
	var/pan_x = max(-round(-abs(pixel_x) / 32), -round(-abs(target_x) / 32))
	var/pan_y = max(-round(-abs(pixel_y) / 32), -round(-abs(target_y) / 32))
	if(world.time <= los_camera_union_until)
		// Retain view and pan separately: a new larger viewport also applies
		// to the old pan while interpolation is still crossing that endpoint.
		view_x = max(view_x, los_camera_radius_x - los_camera_pan_x)
		view_y = max(view_y, los_camera_radius_y - los_camera_pan_y)
		pan_x = max(pan_x, los_camera_pan_x)
		pan_y = max(pan_y, los_camera_pan_y)
	los_camera_pan_x = pan_x
	los_camera_pan_y = pan_y
	los_camera_radius_x = view_x + pan_x
	los_camera_radius_y = view_y + pan_y
	// One decisecond margin also covers tick quantization at the endpoint.
	los_camera_union_until = max(los_camera_union_until, world.time + max(0, animation_time) + 1)
	los_dirty = TRUE

/client/proc/set_geometric_los(enabled)
	los_enabled = !!enabled
	if(!los_enabled)
		if(los_context)
			los_context.retire()
		if(root_tree_presenter)
			root_tree_presenter.retire()
		if(los_presenter)
			los_presenter.retire()
	los_dirty = TRUE
	los_last_policy = null

/client/proc/reconcile_geometric_los()
	if(!CIV13_GEOMETRIC_LOS_CORE || !los_enabled || !ishuman(mob))
		if(los_context)
			los_context.retire()
		return
	if(los_context && (los_context.body != mob || los_context.retired))
		los_context.retire()
	if(!los_context)
		new /datum/los_context(src)
	var/datum/los_context/V = los_context
	if(!V)
		return
	// A temporary capture suspension is not an observer/camera exemption.
	// Ordinary saves allow read-only geometry refresh as players still move.
	// World reconstruction/mutation retains denied masks rather than exposing
	// native corner leaks while fresh capture is unavailable.
	if(V.eligible() && ((persistence_active_operation && persistence_active_operation.kind != "save") || V.mutations.len))
		if(root_tree_presenter)
			root_tree_presenter.invalidate()
		los_dirty = TRUE
		return
	var/key = V.presentation_key()
	if(!key || !mob.hud_used)
		// Native blindness, observer/camera vision and loading retain their own
		// policy. Never leave stale tree/weather leases on a replaced HUD.
		if(root_tree_presenter)
			root_tree_presenter.retire()
		if(los_presenter)
			los_presenter.retire()
		los_last_policy = null
		los_dirty = TRUE
		return
	if(!los_dirty && key == los_last_policy && world.time < los_next_audit)
		return
	if(root_tree_presenter && !root_tree_presenter.planes_admitted())
		root_tree_presenter.retire()
	if(!root_tree_presenter && CIV13_ROOT_TREE_PRESENTATION)
		new /datum/root_tree_presenter(src, V)
	if(CIV13_ROOT_TREE_PRESENTATION && !root_tree_presenter)
		los_last_error = "root compositor admission failed"
		los_dirty = TRUE
		return
	if(!los_presenter)
		new /datum/los_presenter(src, V)
	var/datum/los_snapshot/S = V.capture(TRUE)
	if(!S)
		// Deferred viewer publication is safe only with a fresh snapshot.
		if(root_tree_presenter)
			root_tree_presenter.invalidate()
		if(los_presenter)
			los_presenter.invalidate()
		los_dirty = TRUE
		return
	var/published = TRUE
	if(root_tree_presenter && !root_tree_presenter.refresh(S))
		published = FALSE
	if(los_presenter && !los_presenter.refresh(S))
		published = FALSE
	if(!published)
		los_dirty = TRUE
		return
	los_last_error = null
	los_last_policy = key
	los_dirty = FALSE
	V.movement_turf = get_turf(mob)
	// Recheck raw opacity/art writers which have no central setter. This is a
	// presentation audit, not an information-release lease: reads capture fresh.
	los_next_audit = world.time + 5

/proc/los_invalidate(atom/changed, possible_opacity = FALSE, viewer_refresh = FALSE)
	if(!CIV13_GEOMETRIC_LOS_CORE || !los_active_contexts)
		return
	var/turf/T = get_turf(changed)
	// Null-space HUD/helper retirement has no world neighborhood to invalidate.
	if(!T)
		return
	for(var/datum/los_context/V in los_active_contexts)
		var/client/C = V.owner
		if(!C || !V.body)
			continue
		var/list/radii = V.viewport_radii()
		if(T && changed != V.body && (T.z != V.body.z || !radii || abs(T.x-V.body.x) > radii[1]+6 || abs(T.y-V.body.y) > radii[2]+6))
			continue
		C.los_dirty = TRUE
		if(C.root_tree_presenter)
			C.root_tree_presenter.invalidate(changed, possible_opacity, viewer_refresh)
		if(C.los_presenter)
			C.los_presenter.invalidate(changed, possible_opacity, viewer_refresh)

// Transparent player geometry is tile anchored. Before a movement attempt,
// neither its eye nor its target footprint has changed; failed/offset-only
// moves must not withdraw tree images or dirty every nearby viewer.
/proc/los_invalidate_movement(atom/movable/A)
	if(!CIV13_GEOMETRIC_LOS_CORE || !A)
		return
	if(ishuman(A) && !A.opacity)
		var/mob/living/human/H = A
		if(H.client && H.client.los_context && !H.client.los_context.retired && H.client.los_context.body == H && H.client.los_context.owner == H.client)
			return
	// Opaque actors and other movers still change physical blocker geometry.
	los_invalidate(A)

// Called after authoritative movement callbacks, before the movement proc
// returns to a yielding locomotion loop. Native client timing remains tested
// separately; this avoids intentionally waiting for the next process tick.
/proc/los_refresh_moved_viewer(atom/movable/A, force_refresh = FALSE)
	if(!CIV13_GEOMETRIC_LOS_CORE || !A)
		return
	var/turf/previous_turf = null
	var/turf/current_turf = get_turf(A)
	var/tile_changed = FALSE
	if(ishuman(A))
		var/mob/living/human/H = A
		if(H.client && H.client.los_context)
			var/datum/los_context/V = H.client.los_context
			var/turf/T = get_turf(H)
			if(!force_refresh && !H.opacity && !V.retired && V.body == H && V.owner == H.client && T && V.movement_turf == T)
				return
			previous_turf = V.movement_turf
			tile_changed = previous_turf != T
			V.movement_turf = T
	// Entered handles old/new tile neighborhoods. Blocker offsets still need
	// immediate withdrawal even without a native tile transition. Transparent
	// viewers revalidate before returning without first blanking unchanged trees.
	los_invalidate(A, FALSE, !force_refresh)
	if(tile_changed && previous_turf)
		los_invalidate(previous_turf, A.opacity)
	var/mob/M = null
	if(ismob(A))
		M = A
	if(M && M.client && M.client.los_context)
		M.client.los_dirty = TRUE
		M.client.reconcile_geometric_los()
	// Pre-write invalidation marked both old/new neighborhoods. Nonclient
	// blockers must not leave their viewers blank until the budgeted tick.
	if(A.opacity && los_active_contexts)
		for(var/datum/los_context/blocked_context in los_active_contexts.Copy())
			var/client/blocked_client = blocked_context.owner
			if(blocked_client && blocked_client.los_dirty)
				blocked_client.reconcile_geometric_los()
	if(!M)
		return
	// A human's target footprint moved too. Refresh nearby other viewers at
	// this tile boundary before returning, so a previously visible character
	// cannot retain a visible image after entering a denied tile. Offset-only
	// pulses never enter this path; opaque actors retain blocker invalidation.
	if(tile_changed && M.client && los_active_contexts)
		for(var/datum/los_context/other_context in los_active_contexts.Copy())
			var/client/C = other_context.owner
			if(!C || C == M.client || !los_movement_affects_context(other_context, previous_turf, current_turf))
				continue
			C.los_dirty = TRUE
			C.reconcile_geometric_los()

/proc/los_movement_affects_context(datum/los_context/V, turf/old_turf, turf/new_turf)
	if(!V || !V.owner || !V.body)
		return FALSE
	var/list/radii = V.viewport_radii()
	if(!radii)
		return FALSE
	for(var/turf/T in list(old_turf, new_turf))
		if(T && T.z == V.body.z && abs(T.x-V.body.x) <= radii[1]+6 && abs(T.y-V.body.y) <= radii[2]+6)
			return TRUE
	return FALSE
