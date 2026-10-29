// Explicit test admission only. No map, login, input or timer constructs this.
/client/var/tmp/datum/root_tree_presenter/root_tree_presenter
var/global/list/root_tree_presenters

// Native appearance getters can return a non-null identity matrix. Test its
// values rather than its presence; even a small real transform is unsupported.
/proc/root_tree_identity_transform(matrix/M)
	if(isnull(M))
		return TRUE
	if(!istype(M, /matrix))
		return FALSE
	return M.a == 1 && M.b == 0 && M.c == 0 && M.d == 0 && M.e == 1 && M.f == 0

/datum/los_context/proc/root_tree_admitted(obj/structure/wild/tree/live_tree/A)
	if(!CIV13_ROOT_TREE_PRESENTATION || !A || A.type != /obj/structure/wild/tree/live_tree || !(A in root_trees))
		return FALSE
	if(A.gcDestroyed || A.gc_destroyed || !isturf(A.loc) || A.loc.type != /turf/floor/plating || !A.anchored || !A.opacity)
		return FALSE
	if(A.plane != GAME_PLANE || A.layer != 5.11 || A.pixel_w || A.pixel_z || (A.appearance_flags & PLANE_MASTER))
		return FALSE
	if(A.step_x || A.step_y || abs(A.pixel_x) > 32 || abs(A.pixel_y) > 32 || A.bound_x || A.bound_y || A.bound_width != 32 || A.bound_height != 32 || !root_tree_identity_transform(A.transform) || length(A.filters) || length(A.overlays) || length(A.underlays) || length(A.vis_contents) || A.render_source || A.render_target || A.maptext)
		return FALSE
	return A.icon in list('icons/obj/flora/bigtrees.dmi', 'icons/obj/flora/bigtrees_winter.dmi', 'icons/obj/flora/deadtrees.dmi', 'icons/obj/flora/deadtrees_winter.dmi')

/datum/los_context/proc/admit_root_tree(obj/structure/wild/tree/live_tree/T)
	if(!CIV13_ROOT_TREE_PRESENTATION || !policy_key() || !T || root_trees.len >= 8 || (T in root_trees))
		return FALSE
	var/datum/los_mutation/M = begin_change()
	if(!M)
		return FALSE
	root_trees += T
	if(!root_tree_admitted(T))
		root_trees -= T
		finish_change(M)
		return FALSE
	return finish_change(M)

/obj/screen/root_tree_shutter
	icon = 'icons/turf/areas.dmi'
	icon_state = "black"
	screen_loc = "WEST,SOUTH to EAST,NORTH"
	plane = ROOT_WEATHER_PLANE
	layer = 100
	mouse_opacity = 0
	should_save = FALSE

/obj/screen/root_tree_weather
	screen_loc = "CENTER"
	plane = ROOT_WEATHER_PLANE
	mouse_opacity = 0
	appearance_flags = NO_CLIENT_COLOR
	should_save = FALSE

/datum/root_tree_presenter
	should_save = FALSE
	var/client/owner
	var/datum/los_context/context
	var/list/images = list()
	var/list/owned_images = list()
	var/obj/screen/plane_master/weather_plane
	var/obj/screen/root_tree_weather/weather_copy
	var/obj/screen/root_tree_shutter/shutter
	var/weather_target
	var/retired = FALSE
	var/driver_generation = 0

/datum/root_tree_presenter/New(client/C, datum/los_context/V)
	..()
	if(!CIV13_ROOT_TREE_PRESENTATION || !CIV13_GEOMETRIC_LOS_CORE || !LIGHTING_COMPOSITION_V2 || !C || !V || V.owner != C || C.los_context != V || !V.policy_key() || !C.mob.hud_used)
		retired = TRUE
		return
	var/obj/screen/plane_master/P = C.mob.hud_used.plane_masters["[LIGHTING_PLANE]"]
	var/obj/screen/plane_master/G = C.mob.hud_used.plane_masters["[GAME_PLANE]"]
	// Cross-plane scene filters cannot be copied per tree without changing
	// their grouping. Refuse them until that composition has its own proof.
	if(!G || length(G.filters) || G.color || !root_tree_identity_transform(G.transform) || G.alpha != 255)
		retired = TRUE
		return
	if(!P || !(P in C.screen) || P.blend_mode != BLEND_OVERLAY || P.render_target || C.root_tree_presenter)
		retired = TRUE
		return
	owner = C
	context = V
	weather_plane = P
	weather_target = "*root-weather-\ref[src]"
	weather_plane.render_target = weather_target
	weather_copy = new
	weather_copy.render_source = weather_target
	shutter = new
	owner.screen += weather_copy
	owner.screen += shutter
	owner.root_tree_presenter = src
	if(!root_tree_presenters)
		root_tree_presenters = list()
	root_tree_presenters += src
	var/generation = ++driver_generation
	spawn(1)
		drive(generation)

/datum/root_tree_presenter/proc/drive(generation)
	while(!retired && owner && owner.root_tree_presenter == src && driver_generation == generation)
		refresh()
		sleep(1)

// Blank overrides retain native target identity while preventing the original
// overhanging sprite from reappearing on a failed or hidden-root decision.
/datum/root_tree_presenter/proc/invalidate()
	if(retired || !owner)
		return
	owner.screen |= shutter
	for(var/image/I in owned_images)
		I.icon = null
		I.mouse_opacity = 0

/datum/root_tree_presenter/proc/planes_admitted()
	if(!owner || !owner.mob || !owner.mob.hud_used || !weather_plane || !weather_copy)
		return FALSE
	var/obj/screen/plane_master/P = owner.mob.hud_used.plane_masters["[LIGHTING_PLANE]"]
	var/obj/screen/plane_master/G = owner.mob.hud_used.plane_masters["[GAME_PLANE]"]
	return P == weather_plane && (P in owner.screen) && P.blend_mode == BLEND_OVERLAY && P.render_target == weather_target && weather_copy.render_source == weather_target && G && (G in owner.screen) && !length(G.filters) && !G.color && root_tree_identity_transform(G.transform) && G.alpha == 255

/datum/root_tree_presenter/proc/refresh()
	if(!CIV13_ROOT_TREE_PRESENTATION || retired || !owner)
		return FALSE
	invalidate()
	if(owner.root_tree_presenter != src || owner.los_context != context || !context || context.owner != owner || !context.policy_key() || !planes_admitted())
		return FALSE
	if(!context.capture())
		return FALSE
	var/key = context.policy_key()
	for(var/image/old in owned_images.Copy())
		if(!old.loc)
			owner.images -= old
			owned_images -= old
	var/list/retained = list()
	for(var/obj/structure/wild/tree/live_tree/T in context.root_trees)
		if(images[T])
			retained[T] = images[T]
	images = retained
	for(var/obj/structure/wild/tree/live_tree/T in context.root_trees)
		var/image/I = images[T]
		if(!I)
			I = image(null, T)
			I.override = TRUE
			I.mouse_opacity = 0
			images[T] = I
			owned_images += I
			owner.images += I
		if(!context.root_tree_admitted(T) || context.decision(context.body, T, "hover") == LOS_DENY || !(T.loc in view(owner.view, owner.eye)))
			continue
		var/turf/root = T.loc
		var/rgb = root_light_rgb(root, context.body)
		if(!rgb)
			continue
		var/icon/frame = icon(T.icon, T.icon_state, T.dir, 1)
		if(frame.Width() != 64 || frame.Height() != 64)
			continue
		if(islist(T.color))
			var/list/tint = T.color
			frame.MapColors(arglist(tint))
		else if(T.color)
			frame.Blend(T.color, ICON_MULTIPLY)
		frame.Blend(rgb, ICON_MULTIPLY)
		I.appearance = T.appearance
		I.loc = T
		I.icon = frame
		I.icon_state = ""
		I.color = null
		I.plane = ROOT_TREE_PLANE
		I.appearance_flags |= TILE_BOUND
		I.override = TRUE
		I.mouse_opacity = T.mouse_opacity
	if(key != context.policy_key())
		invalidate()
		return FALSE
	owner.screen -= shutter
	return TRUE

/datum/root_tree_presenter/proc/retire()
	if(retired)
		return
	retired = TRUE
	driver_generation++
	if(owner)
		owner.images -= owned_images
		owner.screen -= weather_copy
		owner.screen -= shutter
		if(owner.root_tree_presenter == src)
			owner.root_tree_presenter = null
	if(weather_plane && weather_plane.render_target == weather_target)
		weather_plane.render_target = null
	if(root_tree_presenters)
		root_tree_presenters -= src
		if(!root_tree_presenters.len)
			root_tree_presenters = null
	images.Cut()
	owned_images.Cut()
	qdel(weather_copy)
	qdel(shutter)
	owner = null
	context = null
	weather_plane = null

/datum/root_tree_presenter/Destroy()
	retire()
	return ..()

/proc/root_tree_invalidate(atom/changed)
	if(!CIV13_ROOT_TREE_PRESENTATION || !root_tree_presenters)
		return
	for(var/datum/root_tree_presenter/P in root_tree_presenters)
		P.invalidate()
