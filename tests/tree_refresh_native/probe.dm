// New full-source native fixture. No frozen probe or production default changes.
/world
	name = "Civ13 bounded tree refresh native fixture"
	hub = ""
	hub_password = ""
	visibility = 0
	view = "15x15"
	maxx = 64
	maxy = 64
	maxz = 1
	fps = 20
	mob = /mob/living/human/tree_native
	turf = /turf/floor/plating/tree_native
	area = /area

var/global/list/tree_native_clients = list()
var/global/list/tree_native_roots = list()
var/global/list/tree_native_hidden = list()
var/global/list/tree_native_foregrounds = list()
var/global/list/tree_native_totals = list()
var/global/list/tree_native_event_leases = list()
var/global/tree_native_holding = FALSE
var/global/list/tree_native_active_row
var/global/list/tree_native_row
var/global/tree_native_events = 0
var/global/tree_native_case = 0
var/global/tree_native_mode
var/global/tree_native_binding
var/global/tree_native_error
var/global/tree_native_ready = FALSE
var/global/tree_native_finishing = FALSE
var/global/processScheduler/tree_native_scheduler
var/global/process/visibility/tree_native_process
var/global/obj/tree_native_opaque/tree_native_mover

/obj/map_metadata/subtile_fixture/New()
	map = src

/turf/floor/plating/tree_native
	icon = 'icons/turf/floors.dmi'
	icon_state = "white"
	luminosity = 1

/datum/hud/tree_native/New(mob/owner)
	// Fixture HUD ownership only. Actual production plane types/renderer remain.
	mymob = owner
	for(var/path in list(/obj/screen/plane_master/game_world, /obj/screen/plane_master/lighting, /obj/screen/plane_master/light_mask))
		var/obj/screen/plane_master/P = new path
		P.invisibility = 0
		P.backdrop(owner)
		plane_masters["[P.plane]"] = P
		owner.client.screen += P

/obj/tree_native_opaque
	opacity = TRUE
	density = FALSE
	icon = 'icons/turf/floors.dmi'
	icon_state = "white"
	color = "#202020"

/obj/tree_native_hidden
	name = "hidden witness"
	icon = 'icons/turf/floors.dmi'
	icon_state = "white"
	color = "#ff00ff"

/obj/tree_native_fallback
	icon = 'icons/turf/floors.dmi'
	icon_state = "white"
	plane = GAME_PLANE
	layer = 6
	alpha = 1
	mouse_opacity = 0

/client/New()
	if(!tree_native_ready || address != "127.0.0.1" || copytext(key, 1, 6) != "Guest" || tree_native_clients.len >= 2)
		return null
	if(byond_version != 516 || byond_build != 1688)
		return null
	tree_native_clients += src
	clients |= src
	return ..()

/client/Topic()
	return null

/client/Del()
	if(los_context)
		los_context.retire()
	clients -= src
	if(!tree_native_finishing)
		tree_native_error = "unexpected_client_disconnect"
	return ..()

/mob/living/human/tree_native/Login()
	// Never call game Login/preferences/admin/authentication/world startup.
	loc = locate(tree_native_clients.Find(client) == 1 ? 16 : 48, tree_native_clients.Find(client) == 1 ? 16 : 48, 1)
	client.eye = src
	client.view = "15x15"
	client.pixel_x = 0
	client.pixel_y = 0
	client.adminobs = FALSE
	see_invisible = 25
	stat = CONSCIOUS
	canmove = TRUE
	lastarea = get_area(src)
	m_intent = "walk"
	hud_used = new /datum/hud/tree_native(src)
	HUDtech["fov"] = new /obj/screen/fov
	tree_native_require(set_human_subtile(TRUE), "actual_smooth_optin")

/mob/living/human/tree_native/Logout()
	if(client && client.los_context)
		client.los_context.retire()
	return

/world/Topic()
	return null

/world/Export()
	return null

/world/Import()
	return null

/world/Reboot()
	return

/proc/tree_native_require(ok, reason)
	if(!ok)
		throw EXCEPTION(reason)

/proc/tree_native_client(datum/D)
	if(istype(D, /client))
		return D
	if(istype(D, /datum/los_context))
		var/datum/los_context/V = D
		return V.owner
	if(istype(D, /datum/root_tree_presenter))
		var/datum/root_tree_presenter/P = D
		return P.owner
	if(istype(D, /datum/los_presenter))
		var/datum/los_presenter/P = D
		return P.owner
	return null

/proc/tree_native_count(name, datum/D)
	var/client/C = tree_native_client(D)
	var/key = "[tree_native_clients.Find(C)]|[name]"
	tree_native_totals[key] = (isnum(tree_native_totals[key]) ? tree_native_totals[key] : 0) + 1
	if(tree_native_row)
		var/list/counts = tree_native_row["counters"]
		counts[key] = (isnum(counts[key]) ? counts[key] : 0) + 1

/proc/tree_native_image_delta(datum/D, before)
	var/client/C = tree_native_client(D)
	if(!C || !tree_native_row)
		return
	var/delta = length(C.images) - before
	var/list/counts = tree_native_row["counters"]
	var/key = "[tree_native_clients.Find(C)]|[delta >= 0 ? "image_additions" : "image_removals"]"
	counts[key] = (isnum(counts[key]) ? counts[key] : 0) + abs(delta)

/proc/tree_native_affected(phase, list/contexts)
	if(!tree_native_row)
		return
	var/list/refs = list()
	for(var/datum/los_context/V in contexts)
		refs += "\ref[V]"
	var/list/sets = tree_native_row["affected"]
	tree_native_require(sets.len < 32, "affected_context_sample_bound")
	sets += list(list("phase"=phase,"contexts"=refs))

/proc/tree_native_begin(name, datum/D)
	if(name == "capture")
		tree_native_count("captures", D)
	if(!tree_native_row)
		return null
	return list("name"=name, "client"=tree_native_clients.Find(tree_native_client(D)), "start_tick"=world.time, "start_usage"=TICK_USAGE, "tick_lag"=world.tick_lag)

/proc/tree_native_end(list/clock)
	if(!clock || !tree_native_row)
		return
	clock["end_tick"] = world.time
	clock["end_usage"] = TICK_USAGE
	if(tree_native_active_row)
		tree_native_active_row["last_clock"] = clock
	if(clock["start_tick"] == clock["end_tick"] && clock["end_usage"] - clock["start_usage"] >= 100)
		throw EXCEPTION("whole_tick_native_callback")
	if(clock["name"] == "light_notify")
		var/list/notifications = tree_native_row["light_notifications"]
		if(!islist(notifications))
			notifications = list("calls"=0,"resolved"=0,"unresolved"=0,"sum_ms"=0,"max_ms"=0)
			tree_native_row["light_notifications"] = notifications
		notifications["calls"]++
		// One explicit notification and at most one committed overlay callback
		// per root: 2 * 64. Aggregate these, never consume ordinary span slots.
		tree_native_require(notifications["calls"] <= 128, "notification_call_limit")
		if(!notifications["first"])
			notifications["first"] = clock
		notifications["last"] = clock
		var/delta = clock["end_usage"] - clock["start_usage"]
		if(clock["start_tick"] == clock["end_tick"] && delta >= 0)
			var/ms = TICK_DELTA_TO_MS(delta)
			notifications["resolved"]++
			notifications["sum_ms"] += ms
			notifications["max_ms"] = max(notifications["max_ms"], ms)
		else
			notifications["unresolved"]++
		return
	var/list/timings = tree_native_row["timings"]
	tree_native_require(timings.len < 64, "timing_row_limit")
	timings += list(clock)

/proc/tree_native_snapshot()
	var/list/result = list()
	for(var/client/C in tree_native_clients)
		var/datum/root_tree_presenter/P = C.root_tree_presenter
		var/datum/los_presenter/L = C.los_presenter
		var/list/identities = list()
		var/list/roots = tree_native_roots[C]
		for(var/i = 1, i <= min(2, length(roots)), i++)
			var/atom/T = roots[i]
			var/image/I = P && P.scene_active ? P.images[T] : (L ? L.tree_images[T] : null)
			var/icon/F = P ? P.published_frames[T] : null
			if(tree_native_holding)
				if(I)
					tree_native_event_leases |= I
				if(F)
					tree_native_event_leases |= F
				tree_native_require(tree_native_event_leases.len <= 64, "identity_lease_limit")
			identities += list(list("root"="\ref[T]", "image"=I ? "\ref[I]" : null, "published_frame"=F ? "\ref[F]" : null, "native_icon_present"=I && !isnull(I.icon), "in_client_images"=I && (I in C.images), "override"=I ? I.override : null, "plane"=I ? I.plane : null, "mouse_opacity"=I ? I.mouse_opacity : null))
		var/discovered = 0
		if(C.los_context)
			for(var/obj/structure/wild/T in range(13, C.mob))
				if(C.los_context.root_tree_admitted(T))
					discovered++
		result += list(list("client"=tree_native_clients.Find(C), "client_ref"="\ref[C]", "context_ref"="\ref[C.los_context]", "body_ref"="\ref[C.mob]", "body_position"=list(C.mob.x,C.mob.y,C.mob.z,C.mob.step_x,C.mob.step_y), "view"=C.view, "pan"=list(C.pixel_x,C.pixel_y), "client_engine"=list(C.byond_version,C.byond_build), "scene_active"=(P && P.scene_active) ? TRUE : FALSE, "fallback_reason"=P ? P.fallback_reason : "no_presenter", "discovered"=discovered, "root_owned"=P ? P.images.len : 0, "root_published"=P ? P.published_frames.len : 0, "fallback_allowed"=L ? L.tree_images.len : 0, "client_images"=length(C.images), "identities"=identities))
	return result

/proc/tree_native_engine_return(atom/movable/A, result)
	if(!tree_native_row || !istype(A, /mob/living/human/tree_native))
		return
	var/list/rows = tree_native_row["native_returns"]
	tree_native_require(rows.len < 32, "native_pulse_bound")
	rows += list(list("result"=result, "at"=world.time, "x"=A.x, "y"=A.y, "sx"=A.step_x, "sy"=A.step_y, "phase_count"=length(tree_native_row["phases"]), "first_pulse_clients"=rows.len ? null : tree_native_snapshot()))

/proc/tree_native_checkpoint(phase, atom/movable/A)
	if(!tree_native_row || !(A == tree_native_mover || istype(A, /mob/living/human/tree_native)))
		return
	if(phase == "postmove" && ismob(A))
		var/mob/M = A
		if(M.client && M.client.los_context && M.client.los_context.movement_turf == M.loc)
			return
	var/list/phases = tree_native_row["phases"]
	tree_native_require(phases.len < 16, "callback_phase_limit")
	phases += list(list("phase"=phase, "mover"="\ref[A]", "loc"="\ref[A.loc]", "x"=A.x, "y"=A.y, "sx"=A.step_x, "sy"=A.step_y, "clients"=tree_native_snapshot()))

/proc/tree_native_light(turf/T, level)
	if(!T.lighting_overlay)
		new /atom/movable/lighting_overlay(T, TRUE)
	if(!length(T.corners))
		for(var/d in list(NORTHEAST, SOUTHEAST, SOUTHWEST, NORTHWEST))
			var/datum/lighting_corner/C = new
			C.masters[T] = d
			T.corners += C
	for(var/datum/lighting_corner/C in T.corners)
		C.lum_r = level
		C.lum_g = level
		C.lum_b = level
	T.lighting_overlay.update_overlay()

/proc/tree_native_clear_scene()
	for(var/client/C in tree_native_clients)
		if(C.los_context)
			C.los_context.retire()
		var/obj/F = tree_native_foregrounds[C]
		if(F)
			qdel(F)
		var/list/roots = tree_native_roots[C]
		for(var/obj/structure/wild/T in roots)
			qdel(T)
		var/obj/witness = tree_native_hidden[C]
		if(witness)
			qdel(witness)
	tree_native_roots = list()
	tree_native_hidden = list()
	tree_native_foregrounds = list()
	if(tree_native_mover)
		qdel(tree_native_mover)
		tree_native_mover = null

/proc/tree_native_scene(viewers, count, mode)
	tree_native_clear_scene()
	for(var/client/C in tree_native_clients)
		var/mob/living/human/H = C.mob
		var/offset = tree_native_clients.Find(C) == 1 ? 16 : 48
		H.forceMove(locate(offset, offset, 1))
		H.step_x = 0
		H.step_y = 0
		var/list/roots = list()
		// First root is a visible occluder with a witness immediately behind it.
		var/obj/structure/wild/tree/live_tree/front = new(locate(offset, offset+2, 1))
		roots += front
		for(var/dx = -12, dx <= 12 && roots.len < count, dx++)
			for(var/dy = -12, dy <= 12 && roots.len < count, dy++)
				if(abs(dy) <= 1 || (dx == 0 && (dy == 2 || dy == 3)))
					continue
				roots += new /obj/structure/wild/tree/live_tree(locate(offset+dx, offset+dy, 1))
		for(var/obj/structure/wild/T in roots)
			T.icon = 'icons/obj/flora/bigtrees.dmi'
			T.icon_state = "tree_1"
			T.pixel_x = -16
			T.pixel_y = 0
			T.density = FALSE
			T.opacity = TRUE
			tree_native_light(T.loc, 0.7)
		tree_native_roots[C] = roots
		tree_native_hidden[C] = new /obj/tree_native_hidden(locate(offset, offset+3, 1))
		if(mode == "fallback")
			tree_native_foregrounds[C] = new /obj/tree_native_fallback(C.mob.loc)
		C.los_dirty = TRUE
		tree_native_require(C.reconcile_geometric_los(), "initial_reconcile")
	tree_native_mover = new(locate(20,16,1))

/proc/tree_native_event(kind, iteration, viewers, count, mode)
	tree_native_require(!tree_native_error, tree_native_error)
	tree_native_require(++tree_native_events <= 800, "event_limit")
	var/client/A = tree_native_clients[1]
	var/client/B = viewers == 2 ? tree_native_clients[2] : null
	var/other_before = (isnum(tree_native_totals["2|captures"]) ? tree_native_totals["2|captures"] : 0)
	tree_native_event_leases.Cut()
	tree_native_holding = TRUE
	var/list/row = list("case"=tree_native_case, "class"=kind, "iteration"=iteration, "recorded"=(iteration > 5), "viewers"=viewers, "roots"=count, "mode"=mode, "phases"=list(), "timings"=list(), "counters"=list(), "native_returns"=list(), "affected"=list())
	tree_native_active_row = row
	tree_native_row = row
	row["before"] = tree_native_snapshot()
	var/list/clock = tree_native_begin("event", null)
	if(kind == "audit")
		A.los_next_audit = world.time
		A.reconcile_geometric_los()
	if(kind == "viewer_move")
		var/mob/living/human/H = A.mob
		A.canmove = TRUE
		A.moving = TRUE
		H.SelfMove(locate(H.x == 16 ? 17 : 16,16,1), H.x == 16 ? EAST : WEST, world.time + 2)
		A.moving = FALSE
	if(kind == "opaque_move")
		if(B)
			B.los_dirty = TRUE
		tree_native_mover.Move(locate(tree_native_mover.x == 20 ? 21 : 20,16,1), tree_native_mover.x == 20 ? EAST : WEST)
	if(kind == "queued_light")
		var/list/roots = tree_native_roots[A]
		for(var/i = 1, i <= min(64, roots.len), i++)
			var/obj/structure/wild/T = roots[i]
			var/turf/root = T.loc
			root.lighting_overlay.needs_update = TRUE
			root_tree_light_changed(T.loc)
		row["pending_committed"] = tree_native_snapshot()
		for(var/i = 1, i <= min(64, roots.len), i++)
			var/obj/structure/wild/T = roots[i]
			tree_native_light(T.loc, iteration % 2 ? 0.6 : 0.7)
		A.reconcile_geometric_los()
	clock["end_tick"] = world.time
	clock["end_usage"] = TICK_USAGE
	row["event_timer"] = clock
	row["other_sync_captures"] = ((isnum(tree_native_totals["2|captures"]) ? tree_native_totals["2|captures"] : 0)) - other_before
	row["after"] = tree_native_snapshot()
	tree_native_row = null
	var/scene_valid = TRUE
	var/safe = TRUE
	for(var/client/C in tree_native_clients)
		var/datum/root_tree_presenter/P = C.root_tree_presenter
		var/datum/los_presenter/L = C.los_presenter
		if(!P || (mode == "root" ? !P.scene_active : (P.scene_active || P.fallback_reason != "native foreground or mixed-layer appearance")))
			scene_valid = FALSE
		var/obj/witness = tree_native_hidden[C]
		if(los_read_allowed(C.mob, witness, "hover") || los_read_allowed(C.mob, witness, "examine"))
			safe = FALSE
		var/image/denial = L ? L.images[witness] : null
		if(!denial || !denial.override || denial.mouse_opacity || !(denial in C.images))
			safe = FALSE
	if(kind == "viewer_move" && iteration == 1)
		// Real production mutation ownership creates an unavailable capture.
		var/datum/los_mutation/ticket = A.los_context.begin_change()
		tree_native_require(ticket && !A.reconcile_geometric_los(), "capture_failure_control")
		row["capture_failed"] = tree_native_snapshot()
		tree_native_require(A.los_context.finish_change(ticket), "capture_failure_release")
		tree_native_require(A.reconcile_geometric_los(), "capture_failure_recovery")
	row["scene_valid"] = scene_valid
	row["safe"] = safe
	row["allowance_usage"] = tree_native_process.run_time_tick_usage_allowance
	row["allowance_ms"] = TICK_DELTA_TO_MS(tree_native_process.run_time_tick_usage_allowance)
	// Separate actual scheduled pass; never count it as synchronous opaque refresh.
	var/list/scheduled = list("counters"=list(),"timings"=list(),"phases"=list(),"affected"=list(),"native_returns"=list())
	var/scheduled_other_before = isnum(tree_native_totals["2|captures"]) ? tree_native_totals["2|captures"] : 0
	row["scheduled"] = scheduled
	tree_native_row = scheduled
	tree_native_process.reset_current_list()
	tree_native_process.run_time_tick_usage = TICK_USAGE
	tree_native_scheduler.recordStart(tree_native_process)
	tree_native_process.process()
	tree_native_row = null
	row["scheduled"] = scheduled
	row["other_scheduled_captures"] = (isnum(tree_native_totals["2|captures"]) ? tree_native_totals["2|captures"] : 0) - scheduled_other_before
	row["scheduled_remaining_clients"] = length(tree_native_process.current_list)
	row["scheduler"] = list("last"=tree_native_scheduler.last_run_time[tree_native_process], "highest"=tree_native_scheduler.highest_run_time[tree_native_process], "last_twenty"=tree_native_scheduler.last_twenty_run_times[tree_native_process])
	text2file(json_encode(row), "events.jsonl")
	tree_native_holding = FALSE
	tree_native_event_leases.Cut()
	tree_native_require(scene_valid && safe, "event_visibility_or_admission")
	if(kind == "opaque_move" && viewers == 2)
		tree_native_require(row["other_sync_captures"] == 0, "unrelated_sync_refresh")
	tree_native_active_row = null

/world/New()
	var/list/binding = json_decode(file2text("binding.json"))
	if(!islist(binding) || binding["head"] != TREE_NATIVE_HEAD || !istext(binding["binding"]))
		tree_native_finish("run_binding")
		return
	tree_native_binding = binding["binding"]
	try
		tree_native_require(world.byond_version == 516 && world.byond_build == 1688, "pinned_engine")
		rand_seed(13013)
		human_subtile_fixture_initialize()
		config.disable_fov = TRUE
		time_of_day2luminosity["tree_native"] = 0
		time_of_day = "tree_native"
		created_lighting_corners_and_overlays = TRUE
		lighting_startup_in_progress = FALSE
		tree_native_scheduler = new
		tree_native_process = new(tree_native_scheduler)
		tree_native_scheduler.addProcess(tree_native_process)
		tree_native_process.run_time_tick_usage_allowance = tree_native_scheduler.calculate_run_time_allowance(tree_native_process.priority)
		tree_native_ready = TRUE
		text2file(json_encode(list("head"=TREE_NATIVE_HEAD,"binding"=tree_native_binding,"port"=world.port)), "ready.json")
		spawn(1)
			tree_native_execute()
	catch(var/exception/tree_native_start_error)
		tree_native_finish(tree_native_start_error.name)

/proc/tree_native_execute()
	try
		for(var/viewers in list(1,2))
			if(viewers == 2)
				text2file("2", "need-second-client")
			while(tree_native_clients.len < viewers)
				sleep(1)
			for(var/count in list(64,256))
				for(var/mode in list("root","fallback"))
					tree_native_case++
					tree_native_mode = mode
					tree_native_scene(viewers,count,mode)
					for(var/kind in list("audit","viewer_move","opaque_move","queued_light"))
						for(var/i = 1, i <= 25, i++)
							tree_native_event(kind,i,viewers,count,mode)
							sleep(1)
		tree_native_finish(null)
	catch(var/exception/tree_native_run_error)
		tree_native_finish(tree_native_run_error.name)

/proc/tree_native_save_failure(error)
	if(fexists("failed-event.json"))
		return
	var/list/failed = tree_native_active_row
	if(!islist(failed))
		failed = list("case"=tree_native_case,"events"=tree_native_events,"active_row_missing"=TRUE)
	failed["failure_reason"] = copytext("[error]", 1, 1025)
	failed["identity_lease_count"] = tree_native_event_leases.len
	var/encoded = json_encode(failed)
	if(length(encoded) > 131072)
		var/list/timings = failed["timings"]
		var/list/phases = failed["phases"]
		failed = list("failure_reason"=copytext("[error]",1,1025),"case"=tree_native_case,"events"=tree_native_events,"truncated"=TRUE,"original_characters"=length(encoded),"original_md5"=md5(encoded),"timing_count"=length(timings),"phase_count"=length(phases),"identity_lease_count"=tree_native_event_leases.len)
		encoded = json_encode(failed)
	tree_native_require(length(encoded) <= 131072 && text2file(encoded,"failed-event.json"), "failed_row_retention")

/proc/tree_native_finish(error)
	tree_native_finishing = TRUE
	var/retention_error = null
	if(error)
		try
			tree_native_save_failure(error)
		catch(var/exception/tree_native_retention_exception)
			retention_error = tree_native_retention_exception.name
	var/cleaned = FALSE
	try
		tree_native_row = null
		tree_native_active_row = null
		tree_native_holding = FALSE
		tree_native_event_leases.Cut()
		tree_native_clear_scene()
		OpenPort("none")
		cleaned = !port && !length(root_tree_presenters) && !length(los_active_contexts)
	catch(var/exception/tree_native_cleanup_error)
		if(!error)
			error = tree_native_cleanup_error.name
	text2file(json_encode(list("head"=TREE_NATIVE_HEAD,"binding"=tree_native_binding,"engine"=list(world.byond_version,world.byond_build),"world"=list("map"=list(world.maxx,world.maxy,world.maxz),"view"=world.view,"fps"=world.fps,"tick_lag"=world.tick_lag,"icon_size"=world.icon_size,"seed"=13013),"error"=error,"failure_retention_error"=retention_error,"cleanup"=cleaned,"events"=tree_native_events,"pixels_verified"=FALSE)), "receipt.json")
	del(world)
	return
