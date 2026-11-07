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
	// Only validated resource-work producers may create these per-client FX.
	// Keyed image -> root; bounded independently of the discovered forest.
	var/list/work_images = list()
	var/list/frame_keys = list()
	var/list/frame_appearances = list()
	var/list/frame_lights = list()
	var/list/frame_dirs = list()
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
	// Foreground verdicts depend only on an appearance, which BYOND interns
	// and shares between identical atoms. Keyed by appearance so a step walks
	// only appearances this viewer has not audited yet. Bounded; never holds
	// a budget-exhausted verdict, which is not a property of the appearance.
	var/list/foreground_verdicts = list()

/datum/root_tree_presenter/New(client/C, datum/los_context/V)
	..()
	if(!CIV13_ROOT_TREE_PRESENTATION || !CIV13_GEOMETRIC_LOS_CORE || !LIGHTING_COMPOSITION_V2 || !C || !V || V.owner != C || C.root_tree_presenter || !C.mob || !C.mob.hud_used)
		retired = TRUE
		return
	owner = C
	context = V
	owner.root_tree_presenter = src
	// A fresh presenter has published nothing; the audit may not skip it.
	context.clear_audit_scene()
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
	make_lit_relay(game_target, mask_target, ROOT_SCENE_PLANE, 1, TRUE)
	make_relay(tree_target, ROOT_SCENE_PLANE, 2, TRUE)
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
	// A plane master at 0 disables mouse hits for ALL of its children. Keep
	// visual-only planes inert, but allow the game/tree relay chain to route.
	if(number == ROOT_TREE_PLANE || number == ROOT_SCENE_PLANE)
		P.mouse_opacity = 1
	screens += P
	owner.screen += P
	return P

/datum/root_tree_presenter/proc/make_relay(source, number, order, mouse_passthrough = FALSE)
	var/obj/screen/root_scene_relay/R = new
	R.render_source = source
	R.plane = number
	R.layer = order
	// render_source is otherwise only a visual copy: hits belong to the relay.
	// PASS_MOUSE preserves the real character/tree identity and native priority.
	if(mouse_passthrough)
		R.appearance_flags |= PASS_MOUSE
		R.mouse_opacity = 1
	screens += R
	owner.screen += R
	return R

/datum/root_tree_presenter/proc/make_lit_relay(source, mask_source, number, order, mouse_passthrough = FALSE)
	var/obj/screen/root_scene_relay/R = make_relay(source, number, order, mouse_passthrough)
	// Both inputs are full-viewport plane slates. Apply the mask directly as
	// a composite filter, avoiding child-overlay plane/layer/group ordering.
	// BLEND_MULTIPLY retains destination alpha; applying source alpha again
	// would square translucency on sprite edges and translucent roof pixels.
	R.filters += filter(type="layer", render_source=mask_source, flags=FILTER_OVERLAY, blend_mode=BLEND_MULTIPLY)
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

/datum/root_tree_presenter/proc/invalidate(atom/changed, possible_opacity = FALSE, viewer_refresh = FALSE)
	if(retired || !owner)
		return
	owner.los_dirty = TRUE
	clear_work_images()
	// Only the non-yielding post-move refresh may retain an unchanged lease.
	// Pre-write invalidation, opaque movers and unknown contexts still withdraw.
	if(viewer_refresh && changed == context.body && !possible_opacity && !changed.opacity)
		return
	// Transparent clutter movement cannot occlude any tree. Nonblocking turf
	// changes invalidate only roots actually owned by that turf.
	if(changed && changed != context.body && !possible_opacity && !changed.opacity && !isturf(changed))
		return
	// Hide only owned tree content while a mutation is unsettled; never shutter
	// the viewport, inventory, weather or HUD.
	for(var/image/I in owned_images)
		if(isturf(changed) && !possible_opacity && !changed.opacity && I.loc && I.loc.loc != changed)
			continue
		withdraw_tree(I.loc, I)

/datum/root_tree_presenter/proc/refresh(datum/los_snapshot/S)
	if(retired || !owner || owner.root_tree_presenter != src || owner.los_context != context)
		return FALSE
	if(!S)
		S = context.capture(TRUE)
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
	// Keyed set so the stale-image sweep below is linear, not quadratic.
	var/list/current = list()
	var/settled = TRUE
	context.begin_snapshot_pass(S)
	// Existing flora sheets are at most 160px with <=32px offsets. Six cells
	// cover that overhang; geometry still judges the root.
	for(var/obj/structure/wild/T in roots)
		current[T] = TRUE
		var/image/I = images[T]
		if(!I)
			I = image(null, T)
			I.override = TRUE
			I.mouse_opacity = 0
			images[T] = I
			owned_images += I
			owner.images += I
		if(context.decision_snapshot(T, S, "visual_tree") == LOS_DENY)
			withdraw_tree(T, I)
			continue
		var/rgb = root_tree_quantize_rgb(cached_light(T))
		if(!rgb)
			withdraw_tree(T, I)
			settled = FALSE
			continue
		var/source_appearance = T.appearance
		var/icon/frame = frames[T]
		if(!frame_inputs_unchanged(T, rgb, source_appearance))
			var/frame_key = "[T.icon]|[T.icon_state]|[T.dir]|[json_encode(T.color)]|[rgb]"
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
			// Frame inputs are independent of whether this image is currently
			// published; hidden/withdrawn roots must not borrow stale leases.
			frame_appearances[T] = source_appearance
			frame_lights[T] = rgb
			frame_dirs[T] = T.dir
		if(frame_needs_publication(T, frame, source_appearance))
			clear_work_images(T)
			root_tree_set_frame(I, T, frame)
			published_frames[T] = frame
			source_appearances[T] = source_appearance
	context.end_snapshot_pass()
	for(var/atom/old in images.Copy())
		if(current[old])
			continue
		clear_work_images(old)
		var/image/I = images[old]
		owner.images -= I
		owned_images -= I
		images -= old
		frames -= old
		published_frames -= old
		frame_keys -= old
		frame_appearances -= old
		frame_lights -= old
		frame_dirs -= old
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
/datum/root_tree_presenter/proc/frame_needs_publication(atom/T, icon/frame, source_appearance)
	if(isnull(source_appearance))
		source_appearance = T.appearance
	return published_frames[T] != frame || source_appearances[T] != source_appearance

/datum/root_tree_presenter/proc/frame_inputs_unchanged(atom/T, rgb, source_appearance)
	return frames[T] && frame_appearances[T] == source_appearance && frame_lights[T] == rgb && frame_dirs[T] == T.dir

/datum/root_tree_presenter/proc/withdraw_tree(atom/T, image/I)
	clear_work_images(T)
	if(!I || !published_frames[T])
		return FALSE
	published_frames -= T
	I.icon = null
	I.overlays = null
	I.underlays = null
	I.maptext = ""
	I.mouse_opacity = 0
	return TRUE

/datum/root_tree_presenter/proc/remove_work_image(image/I)
	if(!work_images[I])
		return
	if(owner)
		owner.images -= I
	owned_images -= I
	work_images -= I

/datum/root_tree_presenter/proc/clear_work_images(atom/T)
	for(var/image/I in work_images.Copy())
		if(T && work_images[I] != T)
			continue
		remove_work_image(I)

/datum/root_tree_presenter/proc/cached_light(obj/structure/wild/T)
	var/turf/root = T.loc
	if(context.body.see_invisible >= INVISIBILITY_LEVEL_TWO || (!root.lighting_overlay && root.needs_fullbright_coverage()))
		return "#ffffff"
	// Pending corner work has not replaced the native displayed mask. Read
	// only its still-committed matrix; missing/replaced/partial masks still deny.
	var/list/sample = root_light_mask_snapshot(root, TRUE)
	if(!sample)
		return null
	var/atom/movable/lighting_overlay/L = root.lighting_overlay
	var/key = "\ref[root]|[L.icon]|[L.icon_state]|[L.dir]|[json_encode(sample)]"
	// Daylight on the client lives in the plane master's matrix, not the
	// overlay's (lighting_overlay.dm), so the sample lacks it: add the same
	// term to the sampled colour, and let the key follow the time of day.
	var/client_daylight = daylight_on_client()
	if(client_daylight)
		key += "|[time_of_day]"
	if(light_keys[T] == key)
		return light_values[T]
	var/rgb = root_light_rgb(root, context.body, TRUE)
	if(rgb && client_daylight && rgb != "#ffffff")
		var/list/channels = rgb2num(rgb)
		var/add = round(255 * daylight_lum(root.get_window_coeff()))
		if(islist(channels) && channels.len >= 3 && add > 0)
			rgb = rgb(min(255, channels[1] + add), min(255, channels[2] + add), min(255, channels[3] + add))
	if(rgb)
		light_keys[T] = key
		light_values[T] = rgb
	return rgb

// Each distinct light colour bakes a new tree icon that every viewer must
// download. Rounding channels to steps of 8 (about 3%) is not visible but
// stops gradual day/night changes from minting a new frame on every tick.
/proc/root_tree_quantize_rgb(rgb)
	if(!istext(rgb) || length(rgb) != 7 || rgb == "#ffffff")
		return rgb
	var/list/channels = rgb2num(rgb)
	if(!islist(channels) || channels.len < 3)
		return rgb
	for(var/i = 1, i <= 3, i++)
		channels[i] = min(255, round(channels[i] / 8 + 0.5) * 8)
	return rgb(channels[1], channels[2], channels[3])

/proc/root_tree_set_frame(image/I, obj/structure/wild/T, icon/frame)
	I.appearance = T.appearance
	I.loc = T
	I.pixel_x = 0
	I.pixel_y = 0
	I.icon = frame
	I.icon_state = ""
	I.color = null
	I.plane = ROOT_TREE_PLANE
	// An admitted canopy may overlap visible turf while its root turf is hidden.
	// The geometric surface gate owns admission; retain native pixel visibility.
	if(T.opacity)
		I.appearance_flags &= ~TILE_BOUND
	else
		I.appearance_flags |= TILE_BOUND
	I.appearance_flags |= RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM
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
		var/appearance = A.appearance
		var/verdict = foreground_verdicts[appearance]
		if(isnull(verdict))
			verdict = root_tree_foreground_appearance(A, A.plane, A.layer, 0, budget)
			if(budget[1] > 0)
				if(foreground_verdicts.len >= 2048)
					foreground_verdicts.Cut()
				foreground_verdicts[appearance] = verdict
		if(verdict)
			return budget[1] <= 0 ? "appearance audit budget exceeded" : "native foreground or mixed-layer appearance"
		// Dynamic render/vis grouping cannot be assigned a reliable footprint.
		if(A.plane == GAME_PLANE && ((ismovable(A) && length(A:vis_contents)) || A.render_source || A.render_target || length(A.filters)))
			return "unbounded game appearance"
	// Build the presenter-owned image set once; scanning both owned lists for
	// every client image made this audit quadratic on every refresh.
	var/list/presenter_images = list()
	for(var/owned in owned_images)
		presenter_images[owned] = TRUE
	if(owner.los_presenter)
		for(var/owned in owner.los_presenter.owned_images)
			presenter_images[owned] = TRUE
	for(var/image/I in owner.images)
		if(presenter_images[I])
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
	work_images.Cut()
	frames.Cut()
	published_frames.Cut()
	frame_keys.Cut()
	frame_appearances.Cut()
	frame_lights.Cut()
	frame_dirs.Cut()
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
	foreground_verdicts.Cut()
	// Fallback copies now belong to the mask presenter; refresh before any skip.
	if(context)
		context.clear_audit_scene()
	owner = null
	context = null

/datum/root_tree_presenter/Destroy()
	retire()
	return ..()

/proc/root_tree_invalidate(atom/changed)
	return los_invalidate(changed)


// Photometric work does not change occlusion. Keep each published tree at the
// same committed lighting as the native mask until the next matrix is ready.
// Blocker/appearance/lifetime changes still use synchronous los_invalidate.
/proc/root_tree_light_changed(turf/root)
	if(!root || !root_tree_presenters)
		return
	// Every lighting corner/overlay change calls this, and most turfs hold no
	// tree. Look this turf's own trees up in each presenter's keyed image
	// table instead of scanning every presenter's whole forest per light tick.
	for(var/obj/structure/wild/T in root.contents)
		if(T.loc != root)
			continue
		for(var/datum/root_tree_presenter/P in root_tree_presenters)
			if(P.retired || !P.owner)
				continue
			if(P.images[T])
				P.owner.los_dirty = TRUE
