// Client-owned presentation is rebuilt, never persisted or transferred between bodies.
/client/var/tmp/los_enabled = TRUE
/client/var/tmp/los_dirty = TRUE
/client/var/tmp/los_last_policy
/client/var/tmp/los_next_audit = 0
/client/var/tmp/los_last_error

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
	var/key = V.policy_key()
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
	var/datum/los_snapshot/S = V.capture()
	if(!S)
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
	// Recheck raw opacity/art writers which have no central setter. This is a
	// presentation audit, not an information-release lease: reads capture fresh.
	los_next_audit = world.time + 5

/proc/los_invalidate(atom/changed)
	if(!CIV13_GEOMETRIC_LOS_CORE || !los_active_contexts)
		return
	var/turf/T = get_turf(changed)
	for(var/datum/los_context/V in los_active_contexts)
		var/client/C = V.owner
		if(!C || !V.body)
			continue
		var/list/dimensions = V.viewport()
		if(T && changed != V.body && (T.z != V.body.z || !dimensions || abs(T.x-V.body.x) > dimensions[1]/2+6 || abs(T.y-V.body.y) > dimensions[2]/2+6))
			continue
		C.los_dirty = TRUE
		if(C.root_tree_presenter)
			C.root_tree_presenter.invalidate(changed)
		if(C.los_presenter)
			C.los_presenter.invalidate(changed)
