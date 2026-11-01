// Conservative geometric presentation on top of BYOND's native visibility.
// It never grants gameplay authority. A denied root/tree is owned
// by root_tree_presenter; terrain masking stays below canopies, not on a screen
// plane that would clip an otherwise visible whole tree.
/client/var/tmp/datum/los_presenter/los_presenter

/datum/los_presenter
	should_save = FALSE
	var/client/owner
	var/datum/los_context/context
	var/list/images = list()
	var/list/owned_images = list()
	var/list/visible_targets = list()
	var/list/tree_images = list()
	var/list/tree_appearances = list()
	var/retired = FALSE
	var/dirty = TRUE
	var/last_policy
	var/last_refresh = -1

/datum/los_presenter/New(client/C, datum/los_context/V)
	..()
	if(!CIV13_GEOMETRIC_LOS_CORE || !C || !V || C.los_context != V || V.owner != C)
		retired = TRUE
		return
	if(C.los_presenter)
		C.los_presenter.retire()
	owner = C
	context = V
	owner.los_presenter = src

// Movement/opacity hooks mark the local viewport dirty. The shared process
// supplies a fresh capture; this owner never starts its own sleeping driver.
/datum/los_presenter/proc/invalidate(atom/changed, possible_opacity = FALSE)
	if(retired || !owner || !context || !context.body)
		return
	dirty = TRUE
	owner.los_dirty = TRUE
	// Allowed fallback canopies can span several physical cells. Withdraw
	// their copies conservatively before a blocker or viewer/context change;
	// the ordinary root-footprint filter below cannot cover every owned edge.
	if(!changed || changed == context.body || possible_opacity || changed.opacity)
		for(var/atom/A in tree_images.Copy())
			var/image/tree_mask = hidden_image(A)
			images[A] = tree_mask
			owned_images |= tree_mask
			owner.images |= tree_mask
	// Before a blocker write/move, withdraw only content potentially behind
	// that cell. Do not leave previously visible content exposed until the
	// budgeted refresh, and do not shutter unrelated map regions or the HUD.
	if(!changed || (!possible_opacity && !changed.opacity))
		return
	var/turf/cell = get_turf(changed)
	if(!cell || changed == context.body || cell.z != context.body.z)
		return
	var/ex = context.body.x
	var/ey = context.body.y
	var/cx = cell.x - ex
	var/cy = cell.y - ey
	if(ismovable(changed))
		var/atom/movable/blocker = changed
		cx += blocker.step_x / 32
		cy += blocker.step_y / 32
	for(var/atom/A in visible_targets)
		if(!A || !owns_atom(A) || A.z != cell.z)
			continue
		var/tx = A.x - ex
		var/ty = A.y - ey
		if(ismovable(A) && !ishuman(A))
			var/atom/movable/target = A
			tx += target.step_x / 32
			ty += target.step_y / 32
		// A blocker does not conceal content rooted on its own native tile.
		// Step offsets do not change tile ownership; other blockers still mask it.
		if(get_turf(A) == cell)
			continue
		if(los_footprint_hits_cell(0, 0, tx, ty, 0.5, cx, cy))
			var/image/I = hidden_image(A)
			images[A] = I
			owned_images |= I
			owner.images |= I

/datum/los_presenter/proc/owns_atom(atom/A)
	if(!A || A.gcDestroyed || A.gc_destroyed)
		return FALSE
	if(istype(A, /obj/screen) || istype(A, /atom/movable/lighting_overlay) || istype(A, /atom/movable/lighting_fullbright))
		return FALSE
	if(A == context.body)
		return FALSE
	if(owner.root_tree_presenter && !owner.root_tree_presenter.retired && owner.root_tree_presenter.owns_tree(A))
		return FALSE
	// Only world roots; carried items and HUD appearances retain their normal
	// owner-specific visibility and must not be blanked through their loc chain.
	return isturf(A) || isturf(A.loc)

/datum/los_presenter/proc/hidden_image(atom/A)
	withdraw_tree_image(A)
	var/image/I = images[A]
	if(I)
		return I
	I = image(null, A)
	I.override = TRUE
	I.mouse_opacity = 0
	I.appearance_flags = RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM
	if(isturf(A))
		I.icon = 'icons/turf/areas.dmi'
		I.icon_state = "black"
		I.plane = A.plane
		I.layer = A.layer
		I.alpha = 255
		I.color = "#000000"
	// A blank override keeps the real atom's interaction identity, but removes
	// its icon and all nested appearances for this viewer only.
	return I

// Native fallback still needs an allowed per-client copy: /atom inherits
// TILE_BOUND, which would otherwise clip an admitted overhanging canopy.
// Keep the real atom, native light/plane and mouse identity; remove only the
// engine's tile clipping flag. Screen compositor ownership remains separate.
/datum/los_presenter/proc/native_tree_image(atom/A)
	var/image/I = tree_images[A]
	if(I && tree_appearances[A] == A.appearance)
		return I
	I = image(A.appearance, A)
	I.pixel_x = 0
	I.pixel_y = 0
	I.appearance_flags &= ~TILE_BOUND
	I.appearance_flags |= RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM
	I.override = TRUE
	I.mouse_opacity = A.mouse_opacity
	return I

/datum/los_presenter/proc/withdraw_tree_image(atom/A)
	var/image/I = tree_images[A]
	if(!I)
		return
	if(owner)
		owner.images -= I
	owned_images -= I
	tree_images -= A
	tree_appearances -= A

/datum/los_presenter/proc/refresh(datum/los_snapshot/S)
	if(retired || !owner || owner.los_presenter != src || !context || owner.los_context != context)
		return FALSE
	if(!context.eligible())
		clear_images()
		last_policy = null
		return FALSE
	if(!S)
		S = context.capture(TRUE)
	if(!S || S.policy != context.policy_key())
		// Keep previous conservative masks while a mutation is in flight. Do not
		// black out the screen or publish a partial fresh geometry decision.
		dirty = TRUE
		return FALSE
	var/list/next = list()
	var/list/next_owned = list()
	var/list/next_visible = list()
	var/list/next_trees = list()
	var/list/next_appearances = list()
	// Two extra root tiles cover ordinary non-tree oversized art. Trees have
	// their own appearance-aware discovery and whole-root ownership.
	for(var/cx = max(1, context.body.x-S.radius_x-2), cx <= min(world.maxx, context.body.x+S.radius_x+2), cx++)
		for(var/cy = max(1, context.body.y-S.radius_y-2), cy <= min(world.maxy, context.body.y+S.radius_y+2), cy++)
			var/turf/T = locate(cx, cy, S.eye_z)
			if(!T)
				continue
			if(context.decision_snapshot(T, S, "visual") == LOS_DENY)
				var/image/turf_mask = hidden_image(T)
				next[T] = turf_mask
				next_owned += turf_mask
			else
				next_visible += T
			for(var/atom/movable/A in T)
				// Native contents repeats atoms whose bounds overlap turfs.
				if(A in next_visible || next[A])
					continue
				if(!owns_atom(A))
					continue
				var/visual_operation = root_tree_family(A) && A.opacity ? "visual_tree" : "visual"
				if(context.decision_snapshot(A, S, visual_operation) == LOS_DENY)
					var/image/atom_mask = hidden_image(A)
					next[A] = atom_mask
					next_owned += atom_mask
				else
					next_visible += A
					if(visual_operation == "visual_tree")
						var/image/tree_image = native_tree_image(A)
						next_trees[A] = tree_image
						next_appearances[A] = A.appearance
						next_owned |= tree_image
	if(S.policy != context.policy_key() || S.revision != context.revision)
		dirty = TRUE
		return FALSE
	// This non-sleeping publication removes stale masks and adds only changed
	// ones. Existing image identities are reused instead of resent each tick.
	owner.images -= owned_images - next_owned
	owner.images |= next_owned - owned_images
	visible_targets = next_visible
	images = next
	tree_images = next_trees
	tree_appearances = next_appearances
	owned_images = next_owned
	last_policy = S.policy
	last_refresh = world.time
	dirty = FALSE
	return TRUE

/datum/los_presenter/proc/clear_images()
	if(owner)
		owner.images -= owned_images
	images.Cut()
	tree_images.Cut()
	tree_appearances.Cut()
	visible_targets.Cut()
	owned_images.Cut()
	dirty = TRUE

/datum/los_presenter/proc/retire()
	if(retired)
		return
	retired = TRUE
	clear_images()
	if(owner && owner.los_presenter == src)
		owner.los_presenter = null
	owner = null
	context = null

/datum/los_presenter/Destroy()
	retire()
	return ..()
