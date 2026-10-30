// Conservative geometric presentation on top of BYOND's native visibility.
// It never grants visibility or gameplay authority. A denied root/tree is owned
// by root_tree_presenter; terrain masking stays below canopies, not on a screen
// plane that would clip an otherwise visible whole tree.
/client/var/tmp/datum/los_presenter/los_presenter

/datum/los_presenter
	should_save = FALSE
	var/client/owner
	var/datum/los_context/context
	var/list/images = list()
	var/list/owned_images = list()
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
/datum/los_presenter/proc/invalidate(atom/changed)
	if(retired || !owner || !context || !context.body)
		return
	// A moving blocker can affect every target behind it in this viewport.
	// Only the caller can filter old/new positions safely; null means all.
	dirty = TRUE

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

/datum/los_presenter/proc/refresh(datum/los_snapshot/S)
	if(retired || !owner || owner.los_presenter != src || !context || owner.los_context != context)
		return FALSE
	if(!context.eligible())
		clear_images()
		last_policy = null
		return FALSE
	if(!S)
		S = context.capture()
	if(!S || S.policy != context.policy_key())
		// Keep previous conservative masks while a mutation is in flight. Do not
		// black out the screen or publish a partial fresh geometry decision.
		dirty = TRUE
		return FALSE
	var/list/next = list()
	var/list/next_owned = list()
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
			for(var/atom/movable/A in T)
				if(!owns_atom(A))
					continue
				if(context.decision_snapshot(A, S, "visual") == LOS_DENY)
					var/image/atom_mask = hidden_image(A)
					next[A] = atom_mask
					next_owned += atom_mask
	if(S.policy != context.policy_key() || S.revision != context.revision)
		dirty = TRUE
		return FALSE
	// This non-sleeping publication removes stale masks and adds only changed
	// ones. Existing image identities are reused instead of resent each tick.
	owner.images -= owned_images - next_owned
	owner.images |= next_owned - owned_images
	images = next
	owned_images = next_owned
	last_policy = S.policy
	last_refresh = world.time
	dirty = FALSE
	return TRUE

/datum/los_presenter/proc/clear_images()
	if(owner)
		owner.images -= owned_images
	images.Cut()
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
