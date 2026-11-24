// Native probe: open air on an upper level shows the level below through
// vis_contents, open air under open air shows the level under that, floors stop
// the view, and replacing the cell drops it.
/world
	hub = ""
	visibility = 0
	maxx = 12
	maxy = 12
	maxz = 3
	fps = 20
	turf = /turf/floor/grass
	area = /area

/world/OpenPort(port)
	if (port == "none")
		return ..("none")
	return FALSE

/world/Topic()
	return null

/client/New()
	del(src)

/obj/map_metadata/open_air_view_native/New()
	map = src

var/list/open_air_probe_log = list()

/mob/living/human/open_air_probe_actor/human_subtile_authority(client/owner)
	return TRUE

/proc/open_air_probe_view(turf/sky/building/T)
	return istype(T) ? T.open_air_view : null

// TRUE when A is shown on the open-air cell above it by its proxy.
/proc/open_air_probe_shown(atom/movable/A, turf/cell)
	var/obj/effect/open_air_proxy/P = A ? A.open_air_proxy : null
	return P && P.loc == cell && (A in P.vis_contents) && P.shows == A

/proc/open_air_probe_turf_shown(atom/A, depth = 0)
	if (depth > 8)
		return FALSE
	for (var/thing in A:vis_contents)
		if (isturf(thing) || open_air_probe_turf_shown(thing, depth + 1))
			return TRUE
	return FALSE

// Artificial fixed/proxy work lets the real process hit a deterministic
// one-item scheduler budget without opening a port or making BYOND clients.
var/list/open_air_probe_work_log = list()

/obj/effect/open_air_view/open_air_work_probe
	var/probe_label
	var/pause_after = FALSE

/obj/effect/open_air_view/open_air_work_probe/open_air_view_sync()
	open_air_probe_work_log += probe_label
	if (pause_after)
		persistence_save_in_progress = TRUE

/obj/effect/open_air_proxy/open_air_work_probe
	var/probe_label

/obj/effect/open_air_proxy/open_air_work_probe/open_air_proxy_check()
	open_air_probe_work_log += probe_label

/proc/open_air_probe_work_budget()
	var/process/open_air_view/P = new
	P.setup()
	var/obj/effect/open_air_view/open_air_work_probe/first = new
	var/obj/effect/open_air_view/open_air_work_probe/second = new
	var/obj/effect/open_air_proxy/open_air_work_probe/stale = new
	var/obj/effect/open_air_proxy/open_air_work_probe/last = new
	first.probe_label = "first"
	second.probe_label = "second"
	stale.probe_label = "stale"
	last.probe_label = "last"
	open_air_views_fixed += list(first, second)
	open_air_proxies += list(stale, last)
	P.reset_current_list()
	P.run_time_tick_usage = -100
	P.run_time_tick_usage_allowance = 1
	open_air_probe_check(P.fire() == PROCESS_TICK_CHECK_RETURNED_EARLY && open_air_probe_work_log.Join(",") == "first", "bounded_scan_yields_after_one_item")
	open_air_probe_check(P.current_list && isnull(P.current_list[1]), "consumed_scan_slot_releases_entry")

	// A removed proxy in the snapshot is never called. Starting a save in
	// the next fixed view pauses before even looking at that stale slot.
	open_air_proxies -= stale
	qdel(stale)
	second.pause_after = TRUE
	P.priority = PROCESS_PRIORITY_VERY_HIGH
	P.fire()
	open_air_probe_check(open_air_probe_work_log.Join(",") == "first,second" && !P.current_list && P.paused_work, "busy_on_resume_pauses_without_consuming_suffix")
	P.reset_current_list()
	open_air_probe_check(!P.current_list && P.paused_work, "busy_pass_does_not_rebuild_snapshot")

	var/obj/effect/open_air_proxy/open_air_work_probe/newcomer = new
	newcomer.probe_label = "new"
	open_air_proxies += newcomer
	persistence_save_in_progress = FALSE
	P.reset_current_list()
	P.fire()
	open_air_probe_check(open_air_probe_work_log.Join(",") == "first,second,last" && !P.current_list && !P.paused_work, "resume_skips_removed_slot_and_finishes_snapshot_once")
	second.pause_after = FALSE
	P.reset_current_list()
	P.fire()
	open_air_probe_check(open_air_probe_work_log.Join(",") == "first,second,last,first,second,last,new", "fresh_pass_adds_new_entries_once")
	open_air_views_fixed -= list(first, second)
	open_air_proxies -= list(last, newcomer)
	qdel(first)
	qdel(second)
	qdel(last)
	qdel(newcomer)
	qdel(P)

/proc/open_air_probe_run()
	config = new
	config.webhook_can_fire = FALSE
	makeDatumRefLists()
	GLOB.all_observable_events = list()
	GLOB.moved_event = new
	GLOB.dir_set_event = new
	GLOB.destroyed_event = new
	GLOB.stat_set_event = new
	GLOB.name_set_event = new
	map = new /obj/map_metadata/open_air_view_native
	open_air_probe_work_budget()
	for (var/tz in 2 to 3)
		for (var/tx in 1 to 12)
			for (var/ty in 1 to 12)
				new /turf/sky/building(locate(tx, ty, tz))
	// A floor on the middle level at (8,8) and one on the top level at (9,9).
	new /obj/covers/wood(locate(8, 8, 2))
	new /obj/covers/wood(locate(9, 9, 3))

	open_air_probe_check(!open_air_view_busy(), "not_busy")
	open_air_view_link_around(3, 6, 6, 3, 3)
	var/turf/top = locate(5, 5, 3)
	var/turf/middle = locate(5, 5, 2)
	var/turf/ground = locate(5, 5, 1)
	var/obj/effect/open_air_view/V = open_air_probe_view(top)
	var/obj/effect/open_air_view/W = open_air_probe_view(middle)
	open_air_probe_check(V && (V in top.vis_contents) && V.shows == middle && (W in V.vis_contents), "top_shows_middle")
	open_air_probe_check(W && (W in middle.vis_contents) && W.shows == ground && (W.ground in W.vis_contents), "middle_shows_ground")
	// No turf is ever shown through vis_contents: the client is sent such a
	// turf again and again (about 2.7 Mbps one level up in a real client).
	open_air_probe_check(!open_air_probe_turf_shown(V) && !open_air_probe_turf_shown(W), "no_turf_in_views")
	open_air_probe_check(W.ground.icon == ground.icon && W.ground.icon_state == ground.icon_state && W.ground.layer == 1.95, "ground_copies_the_turf")
	// Who walks below shows at once, and leaves the old tile's view at once.
	var/obj/structure/walker = new /obj/structure(locate(5, 4, 1))
	open_air_view_link_around(3, 6, 6, 3, 3)
	var/obj/effect/open_air_view/S = open_air_probe_view(locate(5, 4, 2))
	open_air_probe_check(S && open_air_probe_shown(walker, locate(5, 4, 2)) && !(walker in S.vis_contents), "walker_shown")
	var/obj/effect/open_air_proxy/WP = walker.open_air_proxy
	walker.glide_size = 4
	walker.forceMove(ground)
	open_air_probe_check(walker.open_air_proxy == WP && WP.loc == middle && WP.glide_size == 4 && !(walker in W.vis_contents), "walker_follows_moves")
	// A step within the tile moves the proxy by the same offset.
	walker.step_x = 6
	walker.Move(ground, 0, 6, 0)
	open_air_probe_check(WP.loc == middle && WP.step_x == walker.step_x, "proxy_follows_steps")
	walker.step_x = 0
	open_air_probe_check(WP.color && WP.layer > 1.959 && WP.layer < 1.99 && (WP.appearance_flags & KEEP_TOGETHER), "proxy_shaded_under_floors")
	// Something overlapping two tiles (a body between steps) is in both turfs'
	// contents but is shown once, by the view of its loc.
	var/obj/structure/straddler = new /obj/structure(locate(5, 4, 1))
	straddler.step_y = 20
	open_air_view_link_around(3, 6, 6, 3, 3)
	open_air_probe_check((straddler in locate(5, 5, 1)) && open_air_probe_shown(straddler, locate(5, 4, 2)), "straddler_shown_once")
	qdel(straddler)
	// Something put down without Move() shows at the next resync; something
	// deleted goes at once.
	var/obj/item/rods = new /obj/item(ground)
	open_air_probe_check(!rods.open_air_proxy, "new_item_waits_for_sync")
	open_air_view_link_around(3, 6, 6, 3, 3)
	open_air_probe_check(open_air_probe_shown(rods, middle), "new_item_after_sync")
	var/obj/effect/open_air_proxy/RP = rods.open_air_proxy
	qdel(rods)
	open_air_probe_check(!rods.open_air_proxy && (QDELETED(RP) || !RP.loc), "deleted_item_goes")
	// A changed turf look is copied at the next resync.
	ground.icon_state = "dirt"
	open_air_view_link_around(3, 6, 6, 3, 3)
	open_air_probe_check(W.ground.icon_state == "dirt", "turf_look_resynced")
	// Open air under a floor on the middle level: floors over open air show.
	var/obj/covers/C = locate() in locate(8, 8, 2)
	var/obj/effect/open_air_view/OF = open_air_probe_view(locate(8, 8, 3))
	open_air_probe_check(OF && open_air_probe_shown(C, locate(8, 8, 3)), "floor_below_shown")
	// Clicks on a proxy act on the open-air cell; Examine reads the real thing.
	open_air_probe_check(C.open_air_proxy.name == C.name && C.open_air_proxy.mouse_opacity && !C.open_air_proxy.should_save, "proxy_named_and_unsaved")
	qdel(walker)
	open_air_probe_check(QDELETED(WP) || !WP.loc, "proxy_goes_with_its_thing")
	open_air_probe_check(!length(ground.vis_contents), "ground_holds_nothing")
	open_air_probe_check(V.color && W.color && V.mouse_opacity == 0 && (V.appearance_flags & KEEP_TOGETHER), "views_are_shaded")
	open_air_probe_check(!V.loc && !W.loc, "views_are_not_map_atoms")
	// The sky sprite comes off while a cell shows the level below, and the view
	// sits under floors built over open air (layer 1.99).
	open_air_probe_check(!top.icon && !middle.icon && V.layer < 1.99 && W.layer < 1.99, "sky_off_view_under_floors")
	// Southern cells draw over northern ones.
	var/obj/effect/open_air_view/N = open_air_probe_view(locate(5, 6, 3))
	open_air_probe_check(N && N.layer < V.layer, "south_draws_over_north")
	// Only the box around the centre is linked.
	open_air_probe_check(!open_air_probe_view(locate(1, 1, 3)) && !open_air_probe_view(locate(10, 10, 3)), "only_the_box")
	// A floor stops the view; the cell under a floor on the middle level shows
	// nothing from the top level, and a covered top cell holds no view.
	open_air_probe_check(!open_air_probe_view(locate(9, 9, 3)), "floor_on_top_blocks")
	var/turf/sky/building/over_floor = locate(8, 8, 3)
	var/obj/effect/open_air_view/O = open_air_probe_view(over_floor)
	open_air_probe_check(O && !open_air_probe_view(locate(8, 8, 2)), "middle_floor_ends_the_chain")
	// Building a floor later drops the view on the next refresh.
	new /obj/covers/wood(top)
	open_air_view_link_around(3, 6, 6, 3, 3)
	open_air_probe_check(!open_air_probe_view(top) && !(V in top.vis_contents), "new_floor_drops_view")
	open_air_probe_check(top.icon == initial(top.icon), "sky_back_when_view_drops")
	open_air_probe_check(open_air_probe_view(middle) == W, "chain_below_kept")
	// A floor with gaps between its boards keeps the view, so the level below
	// shows through the gaps instead of the sky; a solid floor laid over it
	// drops the view.
	var/turf/sky/building/gapped = locate(6, 4, 3)
	var/obj/covers/repairedfloor/planks = new(gapped)
	planks.name = "upper floor"
	var/turf/sky/building/grated = locate(7, 4, 3)
	new /obj/covers/catwalk(grated)
	open_air_view_link_around(3, 6, 6, 3, 3)
	var/obj/effect/open_air_view/G = open_air_probe_view(gapped)
	var/turf/sky/building/under_gapped = locate(6, 4, 2)
	open_air_probe_check(G && (G in gapped.vis_contents) && G.shows == under_gapped && (under_gapped.open_air_view in G.vis_contents) && !gapped.icon, "gapped_floor_shows_below")
	open_air_probe_check(G && G.layer < planks.layer, "view_under_gapped_floor")
	open_air_probe_check(open_air_probe_view(grated) && !grated.icon, "catwalk_shows_below")
	new /obj/covers/wood(gapped)
	open_air_view_link_around(3, 6, 6, 3, 3)
	open_air_probe_check(!open_air_probe_view(gapped) && gapped.icon == initial(gapped.icon), "solid_floor_over_gaps_blocks")
	// Replacing a cell drops its view.
	var/turf/sky/building/replaced = locate(4, 4, 3)
	var/obj/effect/open_air_view/R = open_air_probe_view(replaced)
	open_air_probe_check(R, "replace_had_view")
	replaced.ChangeTurf(/turf/floor/grass)
	var/turf/now = locate(4, 4, 3)
	open_air_probe_check(!(R in now.vis_contents) && (R.gcDestroyed || R.gc_destroyed || !R.vis_contents.len), "replace_drops_view")
	// Ground replaced under a view is resynced.
	var/turf/regrown = locate(5, 5, 1)
	regrown.ChangeTurf(/turf/floor/dirt)
	// A floor now covers the top cell, so a viewer on the middle level resyncs it.
	open_air_view_link_around(2, 6, 6, 3, 3)
	regrown = locate(5, 5, 1)
	open_air_probe_check((W in regrown.open_air_shown_by) && W.ground.icon_state == regrown.icon_state, "changed_turf_below_resynced")
	// Refreshing again does not stack views.
	open_air_view_link_around(3, 6, 6, 3, 3)
	var/count = 0
	for (var/obj/effect/open_air_view/X in middle.vis_contents)
		count++
	open_air_probe_check(count == 1, "no_stacking")
	// A view whose cell got the sky sprite back, or lost its vis_contents,
	// repairs itself on the next scan instead of showing the sky.
	var/turf/sky/building/healed = locate(5, 6, 3)
	var/obj/effect/open_air_view/HV = open_air_probe_view(healed)
	healed.icon = initial(healed.icon)
	healed.vis_contents.Cut()
	open_air_view_link_around(3, 6, 6, 3, 3)
	open_air_probe_check(HV && open_air_probe_view(healed) == HV && !healed.icon && (HV in healed.vis_contents), "view_repairs_itself")
	// A level being added elsewhere does not stop the scan here; one being
	// added under this level does.
	var/turf/sky/building/fresh = locate(11, 2, 3)
	open_air_probe_check(!open_air_probe_view(fresh), "fresh_cell_unlinked")
	building_allocating_z = 2
	open_air_probe_check(!open_air_view_busy(), "allocation_not_global")
	open_air_probe_check(!open_air_view_link_around(3, 11, 2, 0, 0) && !open_air_probe_view(fresh), "allocating_below_skips")
	building_allocating_z = 5
	open_air_view_link_around(3, 11, 2, 0, 0)
	open_air_probe_check(open_air_probe_view(fresh), "other_allocation_links")
	building_allocating_z = 0
	// A viewer moving east is linked further east than one standing still.
	var/turf/sky/building/ahead = locate(11, 11, 3)
	open_air_view_link_around(3, 6, 11, 3, 0)
	open_air_probe_check(!open_air_probe_view(ahead), "lead_not_without_movement")
	open_air_view_link_around(3, 6, 11, 3, 0, 2, 0)
	open_air_probe_check(open_air_probe_view(ahead) && !open_air_probe_view(locate(1, 11, 3)), "lead_links_ahead_only")
	// Lighting is never shown second-hand; everything else counts as the cell.
	var/atom/movable/lighting_overlay/L = /atom/movable/lighting_overlay
	open_air_probe_check(initial(L.vis_flags) == VIS_HIDE, "lighting_hidden")
	var/mob/M = /mob
	open_air_probe_check((initial(M.vis_flags) & VIS_INHERIT_ID) && (initial(M.vis_flags) & VIS_INHERIT_PLANE), "mobs_inherit")
	open_air_probe_check((ground.vis_flags & VIS_INHERIT_ID) && (ground.vis_flags & VIS_INHERIT_PLANE) && (ground.vis_flags & VIS_INHERIT_LAYER), "turfs_inherit")
	// The ground level has nothing below it.
	open_air_view_link_around(1, 6, 6, 3, 3)
	open_air_probe_check(!length(ground.vis_contents), "ground_level_untouched")

	// Looking up: open air overhead can be looked into, a floor or the top of
	// the world cannot, and each refusal says why.
	movementMachine = new
	var/list/why = list()
	var/mob/living/human/open_air_probe_actor/A = new(locate(2, 2, 1))
	open_air_probe_check(A.look_up_target(why) == locate(2, 2, 2), "look_up_into_open_air")
	A.loc = locate(8, 8, 1)
	open_air_probe_check(!A.look_up_target(why) && findtext(why[1], "floor above"), "floor_blocks_look_up")
	A.loc = locate(2, 2, 3)
	open_air_probe_check(!A.look_up_target(why) && findtext(why[1], "only sky"), "nothing_above_top_level")
	// Without a client nothing starts, and stopping when not looking is harmless.
	A.loc = locate(2, 2, 1)
	open_air_probe_check(!A.start_looking_up() && !A.looking_up_at, "no_client_no_look")
	A.stop_looking_up(TRUE)
	open_air_probe_check(!A.looking_up_at && !A.look_up_label, "stop_is_safe")

/proc/open_air_probe_check(ok, label)
	open_air_probe_log += label
	if (!ok)
		throw EXCEPTION(label)

/world/New()
	OpenPort("none")
	var/error = null
	try
		open_air_probe_run()
	catch (var/exception/probe_error)
		error = "[probe_error.name] [probe_error.file]:[probe_error.line]"
	text2file(error ? "FAIL [error]" : "PASS", "result.txt")
	text2file(json_encode(list("log" = open_air_probe_log, "error" = error)), "receipt.json")
	del(world)
