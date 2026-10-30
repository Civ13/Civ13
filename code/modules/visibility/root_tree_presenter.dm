// Per-client root lighting. The scheduler owns refresh; no private polling loop.
/client/var/tmp/datum/root_tree_presenter/root_tree_presenter
var/global/list/root_tree_presenters

/proc/root_tree_identity_transform(matrix/M)
	return isnull(M) || (istype(M, /matrix) && M.a == 1 && M.b == 0 && M.c == 0 && M.d == 0 && M.e == 1 && M.f == 0)

/proc/root_tree_family(atom/A)
	return istype(A, /obj/structure/wild/tree) || istype(A, /obj/structure/wild/jungle) || istype(A, /obj/structure/wild/palm)

/datum/los_context/proc/root_tree_admitted(atom/A)
	return CIV13_ROOT_TREE_PRESENTATION && root_tree_family(A) && !A.gcDestroyed && !A.gc_destroyed && isturf(A.loc) && A.plane == GAME_PLANE && A.layer == 5.11 && abs(A.pixel_x) <= 32 && abs(A.pixel_y) <= 32 && !A.pixel_w && !A.pixel_z && root_tree_identity_transform(A.transform) && !length(A.overlays) && !length(A.underlays) && !length(A.filters) && !length(A:vis_contents) && !A.render_source && !A.render_target && !A.maptext

// Kept for isolated callers; production discovers roots in the current viewport.
/datum/los_context/proc/admit_root_tree(atom/T)
	if(!root_tree_admitted(T))
		return FALSE
	root_trees |= T
	return TRUE

// These are deliberately not plane_master subtypes: only a presenter owns them.
/obj/screen/root_scene_master
	screen_loc = "CENTER"
	appearance_flags = PLANE_MASTER | NO_CLIENT_COLOR | RESET_TRANSFORM | RESET_COLOR | RESET_ALPHA
	blend_mode = BLEND_OVERLAY
	mouse_opacity = 0
	should_save = FALSE

/obj/screen/root_scene_relay
	screen_loc = "WEST,SOUTH"
	appearance_flags = NO_CLIENT_COLOR | KEEP_TOGETHER
	mouse_opacity = 0
	should_save = FALSE

/datum/root_tree_presenter
	should_save = FALSE
	var/client/owner
	var/datum/los_context/context
	var/list/images = list()
	var/list/owned_images = list()
	var/list/frame_keys = list()
	var/list/source_appearances = list()
	var/list/frames = list()
	var/list/published_frames = list()
	var/list/light_keys = list()
	var/list/light_values = list()
	var/list/screens = list()
	var/list/leased_planes = list()
	var/list/lease_targets = list()
	var/obj/screen/plane_master/game_plane
	var/list/original_filters
	var/obj/screen/root_scene_master/scene_plane
	var/retired = FALSE
	var/scene_active = FALSE
	var/fallback_reason
	var/fallback_count = 0

/datum/root_tree_presenter/New(client/C, datum/los_context/V)
	..()
	if(!CIV13_ROOT_TREE_PRESENTATION || !CIV13_GEOMETRIC_LOS_CORE || !LIGHTING_COMPOSITION_V2 || !C || !V || V.owner != C || C.root_tree_presenter || !C.mob || !C.mob.hud_used)
		retired = TRUE
		return
	owner = C
	context = V
	owner.root_tree_presenter = src
	if(!root_tree_presenters)
		root_tree_presenters = list()
	root_tree_presenters += src

/datum/root_tree_presenter/proc/setup_scene()
	if(scene_active)
		return TRUE
	var/obj/screen/plane_master/G = owner.mob.hud_used.plane_masters["[GAME_PLANE]"]
	var/obj/screen/plane_master/L = owner.mob.hud_used.plane_masters["[LIGHTING_MASK_PLANE]"]
	var/obj/screen/plane_master/W = owner.mob.hud_used.plane_masters["[LIGHTING_PLANE]"]
	if(!G || !L || !W || G.render_target || L.render_target || W.render_target || G.color || G.alpha != 255 || !root_tree_identity_transform(G.transform))
		return FALSE
	game_plane = G
	original_filters = length(G.filters) ? G.filters.Copy() : list()
	var/game_target = lease(G, "game")
	var/mask_target = lease(L, "mask")
	var/weather_target = lease(W, "weather")
	var/obj/screen/root_scene_master/R = make_plane(ROOF_PLANE)
	var/roof_target = lease(R, "roof")
	var/obj/screen/root_scene_master/T = make_plane(ROOT_TREE_PLANE)
	var/tree_target = lease(T, "tree")
	scene_plane = make_plane(ROOT_SCENE_PLANE)
	// Apply the original scene filter ONCE to the game and tree union, not once
	// per tree. The shared shadow now follows root lighting (native acceptance).
	scene_plane.filters = original_filters.Copy()
	G.filters = list()
	make_lit_relay(game_target, mask_target, ROOT_SCENE_PLANE, 1)
	make_relay(tree_target, ROOT_SCENE_PLANE, 2)
	make_lit_relay(roof_target, mask_target, ROOT_ROOF_PLANE, 1)
	make_relay(weather_target, ROOT_WEATHER_PLANE, 1)
	// Keep floor/underfloor lighting even though the mask source is hidden.
	var/obj/screen/root_scene_relay/mask_copy = make_relay(mask_target, ROOT_FLOOR_LIGHT_PLANE, 1)
	mask_copy.blend_mode = BLEND_MULTIPLY
	scene_active = TRUE
	return TRUE

/datum/root_tree_presenter/proc/lease(obj/screen/P, suffix)
	var/target = "*root-[suffix]-\ref[src]"
	P.render_target = target
	leased_planes += P
	lease_targets[P] = target
	return target

/datum/root_tree_presenter/proc/make_plane(number)
	var/obj/screen/root_scene_master/P = new
	P.plane = number
	screens += P
	owner.screen += P
	return P

/datum/root_tree_presenter/proc/make_relay(source, number, order)
	var/obj/screen/root_scene_relay/R = new
	R.render_source = source
	R.plane = number
	R.layer = order
	screens += R
	owner.screen += R
	return R

/datum/root_tree_presenter/proc/make_lit_relay(source, mask_source, number, order)
	var/obj/screen/root_scene_relay/R = make_relay(source, number, order)
	var/image/M = image(null)
	M.render_source = mask_source
	M.blend_mode = BLEND_MULTIPLY
	M.appearance_flags = RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM
	R.overlays += M
	// Multiplication has viewport extent. Restore the original source alpha so
	// empty pixels do not black out the floor or other composited planes.
	R.filters += filter(type="alpha", render_source=source)
	return R

/datum/root_tree_presenter/proc/planes_admitted()
	if(!scene_active)
		return !retired && owner && !leased_planes.len && !screens.len
	if(retired || !owner || !owner.mob || !owner.mob.hud_used || owner.mob.hud_used.plane_masters["[GAME_PLANE]"] != game_plane || length(game_plane.filters) || game_plane.color || game_plane.alpha != 255 || !root_tree_identity_transform(game_plane.transform))
		return FALSE
	for(var/obj/screen/P in leased_planes)
		if(!(P in owner.screen) || P.render_target != lease_targets[P])
			return FALSE
	for(var/obj/screen/P in screens)
		if(!(P in owner.screen))
			return FALSE
	return TRUE

/datum/root_tree_presenter/proc/invalidate(atom/changed, possible_opacity = FALSE)
	if(retired || !owner)
		return
	owner.los_dirty = TRUE
	// Transparent clutter movement cannot occlude any tree. Lighting turf
	// notifications invalidate only roots actually owned by that turf.
	if(changed && changed != context.body && !possible_opacity && !changed.opacity && !isturf(changed))
		return
	// Hide only owned tree content while a mutation is unsettled; never shutter
	// the viewport, inventory, weather or HUD.
	for(var/image/I in owned_images)
		if(isturf(changed) && !possible_opacity && !changed.opacity && I.loc && I.loc.loc != changed)
			continue
		published_frames -= I.loc
		I.icon = null
		I.overlays = null
		I.underlays = null
		I.maptext = ""
		I.mouse_opacity = 0

/datum/root_tree_presenter/proc/refresh(datum/los_snapshot/S)
	if(retired || !owner || owner.root_tree_presenter != src || owner.los_context != context)
		return FALSE
	if(!S)
		S = context.capture()
	if(!S)
		invalidate()
		return FALSE
	// Materialize the neighborhood once; the audit and root pass share it.
	var/list/scene = length(owner.images) > 2048 ? list() : range(max(S.radius_x, S.radius_y) + 6, context.body)
	var/reason = composition_conflict(S, scene)
	if(reason)
		release_owned_scene()
		if(fallback_reason != reason)
			fallback_count = min(fallback_count + 1, 1000000)
		fallback_reason = reason
		return TRUE
	var/list/roots = scene_roots(scene)
	if(!roots.len)
		release_owned_scene()
		fallback_reason = "no root trees"
		return TRUE
	if(!setup_scene())
		fallback_reason = "scene lease unavailable"
		return TRUE
	fallback_reason = null
	var/list/current = list()
	var/settled = TRUE
	// Existing flora sheets are at most 160px with <=32px offsets. Six cells
	// cover that overhang; geometry still judges the root.
	for(var/obj/structure/wild/T in roots)
		current += T
		var/image/I = images[T]
		if(!I)
			I = image(null, T)
			I.override = TRUE
			images[T] = I
			owned_images += I
			owner.images += I
		if(context.decision_snapshot(T, S, "visual") == LOS_DENY)
			published_frames -= T
			I.icon = null
			I.mouse_opacity = 0
			continue
		var/rgb = cached_light(T)
		if(!rgb)
			published_frames -= T
			I.icon = null
			I.mouse_opacity = 0
			settled = FALSE
			continue
		var/frame_key = "[T.icon]|[T.icon_state]|[T.dir]|[json_encode(T.color)]|[rgb]"
		var/icon/frame = frames[T]
		if(!frame || frame_keys[T] != frame_key)
			// Omit frame=1: preserve every animation frame and native timing.
			frame = icon(T.icon, T.icon_state, T.dir)
			if(islist(T.color))
				var/list/tint = T.color
				frame.MapColors(arglist(tint))
			else if(T.color)
				frame.Blend(T.color, ICON_MULTIPLY)
			frame.Blend(rgb, ICON_MULTIPLY)
			frames[T] = frame
			frame_keys[T] = frame_key
		if(frame_needs_publication(T, frame))
			root_tree_set_frame(I, T, frame)
			published_frames[T] = frame
			source_appearances[T] = T.appearance
	for(var/atom/old in images.Copy())
		if(old in current)
			continue
		var/image/I = images[old]
		owner.images -= I
		owned_images -= I
		images -= old
		frames -= old
		published_frames -= old
		frame_keys -= old
		source_appearances -= old
		light_keys -= old
		light_values -= old
	if(S.policy != context.policy_key() || S.revision != context.revision)
		invalidate()
		return FALSE
	if(!settled)
		owner.los_dirty = TRUE
	return settled

// Image.icon is an engine appearance getter, not our publication identity.
// Track the exact cached frame we submitted instead of comparing that getter
// against a mutable /icon datum on every audit. Invalidation clears this lease.
/datum/root_tree_presenter/proc/frame_needs_publication(atom/T, icon/frame)
	return published_frames[T] != frame || source_appearances[T] != T.appearance

/datum/root_tree_presenter/proc/cached_light(obj/structure/wild/T)
	var/turf/root = T.loc
	if(context.body.see_invisible >= INVISIBILITY_LEVEL_TWO || (!root.lighting_overlay && root.needs_fullbright_coverage()))
		return "#ffffff"
	var/list/sample = root_light_mask_snapshot(root)
	if(!sample)
		return null
	var/atom/movable/lighting_overlay/L = root.lighting_overlay
	var/key = "\ref[root]|[L.icon]|[L.icon_state]|[L.dir]|[json_encode(sample)]"
	if(light_keys[T] == key)
		return light_values[T]
	var/rgb = root_light_rgb(root, context.body)
	if(rgb)
		light_keys[T] = key
		light_values[T] = rgb
	return rgb

/proc/root_tree_set_frame(image/I, obj/structure/wild/T, icon/frame)
	I.appearance = T.appearance
	I.loc = T
	I.pixel_x = 0
	I.pixel_y = 0
	I.icon = frame
	I.icon_state = ""
	I.color = null
	I.plane = ROOT_TREE_PLANE
	I.appearance_flags |= TILE_BOUND | RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM
	I.override = TRUE
	I.mouse_opacity = T.mouse_opacity

// A separate root pass cannot preserve arbitrary interleaving GAME layers.
// Keep the complete native scene whenever uncertain; never borrow/remove an
// additive client image owned by roof, vehicle, or another gameplay system.
/proc/root_tree_foreground_appearance(A, inherited_plane, inherited_layer, depth = 0, list/budget)
	if(!A)
		return FALSE
	if(!budget)
		budget = list(4096)
	if(budget[1] <= 0)
		return TRUE
	budget[1]--
	if(depth >= 8)
		return TRUE
	var/p = A:plane == FLOAT_PLANE ? inherited_plane : A:plane
	var/l = A:layer < 0 ? inherited_layer : A:layer
	if(p == GAME_PLANE && l >= 5.11 && (A:icon || A:maptext || A:render_source))
		return TRUE
	for(var/O in A:overlays)
		if(root_tree_foreground_appearance(O, p, l, depth + 1, budget))
			return TRUE
	for(var/U in A:underlays)
		if(root_tree_foreground_appearance(U, p, l, depth + 1, budget))
			return TRUE
	return FALSE

/datum/root_tree_presenter/proc/scene_roots(list/scene)
	var/list/roots = list()
	for(var/obj/structure/wild/T in scene)
		if(context.root_tree_admitted(T))
			roots += T
	return roots

/datum/root_tree_presenter/proc/composition_conflict(datum/los_snapshot/S, list/scene)
	if(length(owner.images) > 2048)
		return "client image audit budget exceeded"
	var/list/budget = list(4096)
	var/visits = 0
	var/radius = max(S.radius_x, S.radius_y) + 6
	if(isnull(scene))
		scene = range(radius, context.body)
	for(var/atom/A in scene)
		if(++visits > 4096)
			return "scene atom audit budget exceeded"
		if(context.root_tree_admitted(A))
			continue
		if(root_tree_foreground_appearance(A, A.plane, A.layer, 0, budget))
			return budget[1] <= 0 ? "appearance audit budget exceeded" : "native foreground or mixed-layer appearance"
		// Dynamic render/vis grouping cannot be assigned a reliable footprint.
		if(A.plane == GAME_PLANE && ((ismovable(A) && length(A:vis_contents)) || A.render_source || A.render_target || length(A.filters)))
			return "unbounded game appearance"
	for(var/image/I in owner.images)
		if(I in owned_images)
			continue
		if(owner.los_presenter && (I in owner.los_presenter.owned_images))
			continue
		var/atom/anchor = I.loc
		var/turf/T = get_turf(anchor)
		if(T && (T.z != context.body.z || get_dist(T, context.body) > radius))
			continue
		var/p = anchor ? anchor.plane : GAME_PLANE
		var/l = anchor ? anchor.layer : 0
		if(root_tree_foreground_appearance(I, p, l, 0, budget))
			return budget[1] <= 0 ? "appearance audit budget exceeded" : "client-owned foreground image"
	return null

/datum/root_tree_presenter/proc/owns_tree(atom/A)
	return scene_active && !retired && !!images[A]

/datum/root_tree_presenter/proc/release_owned_scene()
	if(owner)
		owner.images -= owned_images
		owner.screen -= screens
	for(var/obj/screen/P in leased_planes)
		if(P.render_target == lease_targets[P])
			P.render_target = null
	if(game_plane && !length(game_plane.filters))
		game_plane.filters = original_filters
	for(var/obj/screen/P in screens)
		qdel(P)
	images.Cut()
	owned_images.Cut()
	frames.Cut()
	published_frames.Cut()
	frame_keys.Cut()
	source_appearances.Cut()
	light_keys.Cut()
	light_values.Cut()
	screens.Cut()
	leased_planes.Cut()
	lease_targets.Cut()
	game_plane = null
	scene_plane = null
	original_filters = null
	scene_active = FALSE

/datum/root_tree_presenter/proc/retire()
	if(retired)
		return
	release_owned_scene()
	retired = TRUE
	if(owner && owner.root_tree_presenter == src)
		owner.root_tree_presenter = null
	if(root_tree_presenters)
		root_tree_presenters -= src
	owner = null
	context = null

/datum/root_tree_presenter/Destroy()
	retire()
	return ..()

/proc/root_tree_invalidate(atom/changed)
	los_invalidate(changed)
