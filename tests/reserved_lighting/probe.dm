// Full production callbacks, isolated startup and temporary native storage.
// Prepared only: compile/runtime and signatures are not yet accepted evidence.
/world
	hub = ""
	hub_password = ""
	maxx = 16
	maxy = 16
	maxz = 1
	turf = /turf/reserved_lighting_probe
	area = /area/reserved_lighting_probe
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/world/Topic(T, addr, master, key)
	return null
/client/New(TopicData)
	del(src)
	return
/turf/reserved_lighting_probe/New()
	return
/turf/reserved_lighting_probe/replaced
/turf/reserved_lighting_probe/reserved_subtype
	lighting_reserved = TRUE
/turf/floor/beach/water/ice/reserved_lighting_probe/New()
	return
/area/reserved_lighting_probe
	dynamic_lighting = TRUE
/area/reserved_lighting_probe/New()
	return
/obj/reserved_lighting_probe/New()
	return
var/reserved_startup_mode = null
var/reserved_startup_triggered = FALSE
var/reserved_startup_waiting_turf = null
/proc/environment_sweep_pause(work)
	if (reserved_startup_mode && lighting_startup_in_progress && !reserved_startup_triggered)
		reserved_startup_triggered = TRUE
		var/turf/omitted = locate(11,6,1)
		if (omitted.omit_reserved_lighting_overlay())
			reserved_assert(omitted.get_lumcount() == 0.5, "in-progress startup lumcount fallback")
		var/turf/site = reserved_startup_waiting_turf
		var/started = world.time
		site.activate_reserved_lighting()
		reserved_assert(world.time == started, "bulk owner activation must not block")
		sleep(1)
		if (reserved_startup_mode == "failure")
			throw EXCEPTION("reserved fixture startup interruption")
	return reserved_original_environment_sweep_pause(work)
/proc/reserved_assert(ok, message)
	if (!ok)
		throw EXCEPTION("assertion: [message]")
/proc/reserved_drain()
	var/process/lighting_sources/S = new
	var/process/lighting_overlays/O = new
	var/passes = 0
	while (lighting_update_lights.len || lighting_update_overlays.len || O.current_list)
		reserved_assert(++passes < 1000, "queue did not settle")
		S.run_time_tick_usage = world.tick_usage
		S.run_time_tick_usage_allowance = 100
		S.fire()
		O.run_time_tick_usage = world.tick_usage
		O.run_time_tick_usage_allowance = 100
		O.fire()
		sleep(1)
/proc/reserved_source_signature(datum/light_source/L)
	return list("owner" = "[L.source_atom.type]", "source" = list(L.source_turf.x,L.source_turf.y,L.source_turf.z))
/proc/reserved_snapshot(label)
	// Fixed expected interior union of the center/refusal/startup/replacement/
	// import sites and their halos. Identical coordinates in both paired runs;
	// never derive membership from the candidate's observed overlays.
	var/static/list/activated_cells = list("6,6", "6,7", "6,8", "6,9", "6,10", "6,11", "7,6", "7,7", "7,8", "7,9", "7,10", "7,11", "8,6", "8,7", "8,8", "8,9", "8,10", "8,11", "9,7", "9,8", "9,9", "9,10", "9,11", "10,8", "10,9", "10,10", "10,11", "11,9", "11,10", "11,11")
	// These six coordinates remain omitted even after the activation sequence.
	// Membership is fixed independently of observed candidate overlays.
	var/static/list/still_omitted = list("9,6", "10,6", "10,7", "11,6", "11,7", "11,8")
	var/list/rows = list()
	var/list/lumcounts = list()
	var/activated_rows = 0
	var/omitted_rows = 0
	for (var/turf/T in world)
		if ("[T.x],[T.y]" in still_omitted)
			omitted_rows++
			if (world.params["reserved"] == "1")
				reserved_assert(T.omit_reserved_lighting_overlay() && !T.lighting_overlay, "fixed six remain omitted")
			// Exercise dirty coefficients in both runs. The ordinary overlay
			// refreshes its cache; the omitted turf must do so in get_lumcount.
			T.window_coeff = 0.125
			T.window_coeff_dirty = TRUE
			if (T.lighting_overlay)
				T.lighting_overlay.update_overlay()
		lumcounts += list(list(T.x,T.y,T.get_lumcount(),T.get_lumcount(0.2,0.8)))
		// Only the six still-unactivated interior coordinates remain omitted
		// from the final snapshot. Earlier snapshots compare normal/halo cells.
		if (T.x >= 6 && T.x <= 11 && T.y >= 6 && T.y <= 11)
			if (label != "activated" || !("[T.x],[T.y]" in activated_cells))
				continue
			activated_rows++
		reserved_assert(T.lighting_overlay, "snapshot requires expected overlay [T.x],[T.y]")
		var/list/lums = list()
		for (var/datum/lighting_corner/C in T.corners)
			var/list/masters = list()
			for (var/turf/master in C.masters)
				masters += list(list(master.x,master.y,master.z,C.masters[master]))
			var/list/sources = list()
			for (var/datum/light_source/L in C.affecting)
				sources += list(reserved_source_signature(L))
			lums += list(list(C.x,C.y,C.lum_r,C.lum_g,C.lum_b,C.active,masters,sources))
		reserved_assert(lums.len == 4, "snapshot requires four production corners")
		var/list/turf_sources = list()
		for (var/datum/light_source/L in T.affecting_lights)
			turf_sources += list(reserved_source_signature(L))
		rows += list(list(T.x,T.y,T.lighting_overlay.color,T.lighting_overlay.luminosity,T.lighting_overlay.TOD,T.lighting_overlay.invisibility,lums,turf_sources))
	reserved_assert(activated_rows == (label == "activated" ? 30 : 0), "fixed activated snapshot coverage")
	reserved_assert(rows.len == (label == "activated" ? 250 : 220), "fixed total snapshot coverage")
	reserved_assert(lumcounts.len == 256 && omitted_rows == 6, "all-cell lumcount coverage including fixed six")
	text2file(json_encode(list("label"=label,"rows"=rows,"lumcounts"=lumcounts)), "states.jsonl")
/world/New()
	OpenPort("none")
	try
		reserved_assert(!world.port && !OpenPort(0), "PORT_OPEN")
		text2file("closed", "port-closed.txt")
		config = new
		map = null
		var/candidate = world.params["reserved"] == "1"
		for (var/turf/T in world)
			turfs |= T
			if (candidate && T.x >= 5 && T.x <= 12 && T.y >= 5 && T.y <= 12)
				T.lighting_reserved = TRUE
		// The tiny scene has no appearances before startup. First prove that
		// markers alone cannot suppress an overlay, then explicitly enable its
		// fixture-only declared-inert area. No production map enables the gate.
		var/turf/gate_site = locate(8,8,1)
		reserved_assert(!gate_site.omit_reserved_lighting_overlay(), "default-off clearance gate")
		var/area/fixture_area = get_area(gate_site)
		fixture_area.lighting_reserved_clearance_enabled = "unknown"
		reserved_assert(!gate_site.omit_reserved_lighting_overlay(), "unknown clearance gate remains active")
		fixture_area.lighting_reserved_clearance_enabled = TRUE
		reserved_assert(gate_site.get_lumcount() == 0.5, "pre-startup lumcount fallback")
		create_lighting("Midday")
		var/overlays = 0
		var/list/unique_corners = list()
		for (var/turf/T in world)
			if (T.lighting_overlay)
				overlays++
			for (var/datum/lighting_corner/C in T.corners)
				unique_corners |= C
		reserved_assert(overlays == (candidate ? 220 : 256), "overlay allocation count")
		reserved_assert(unique_corners.len == 289, "unchanged full corner grid")
		// Real corners do not opt an ordinary mask-free turf into reservation.
		var/turf/ordinary_site = locate(2,2,1)
		var/atom/movable/lighting_overlay/ordinary_owner = ordinary_site.lighting_overlay
		ordinary_site.lighting_overlay = null
		reserved_assert(ordinary_site.get_lumcount() == 0.5 && ordinary_site.get_lumcount(0.2,0.8) == 0.5, "ordinary no-overlay fallback")
		ordinary_site.lighting_overlay = ordinary_owner
		if (candidate)
			var/turf/semantic_site = locate(11,6,1)
			var/list/saved_corners = semantic_site.corners
			semantic_site.corners = null
			reserved_assert(semantic_site.get_lumcount() == 0.5, "missing omitted corner list fallback")
			semantic_site.corners = list(saved_corners[1],saved_corners[2],saved_corners[3])
			reserved_assert(semantic_site.get_lumcount() == 0.5, "short omitted corner list fallback")
			semantic_site.corners = saved_corners
			var/datum/lighting_corner/saved_corner = semantic_site.corners[1]
			semantic_site.corners[1] = null
			reserved_assert(semantic_site.get_lumcount() == 0.5, "incomplete omitted corner fallback")
			semantic_site.corners[1] = saved_corner
			fixture_area.lighting_reserved_clearance_enabled = FALSE
			reserved_assert(semantic_site.get_lumcount() == 0.5, "disabled omission lumcount fallback")
			fixture_area.lighting_reserved_clearance_enabled = TRUE
			var/turf/refusal_site = locate(9,9,1)
			var/atom/movable/lighting_overlay/refused = new(refusal_site)
			reserved_assert(!refused.loc, "refused constructor detached before deferred deletion")
			// qdel runs Destroy synchronously and immediately returns eligible
			// overlays to the pool. Never invoke Destroy on an old reference after
			// activation: it may now identify a newly constructed live owner.
			reserved_assert(refused in GlobalPool[/atom/movable/lighting_overlay], "refusal retired to pool")
			var/atom/movable/lighting_overlay/reused = PoolOrNew(/atom/movable/lighting_overlay, refusal_site)
			reserved_assert(reused == refused && !reused.loc, "pooled constructor refusal detaches")
			refusal_site.activate_reserved_lighting()
			var/atom/movable/lighting_overlay/owner = refusal_site.lighting_overlay
			reserved_assert(owner && owner.loc == refusal_site && !QDELETED(owner), "post-refusal activation owner")
			// Distinct superseded owner, not a recycled alias of the live object.
			var/atom/movable/lighting_overlay/superseded = new(refusal_site, TRUE)
			reserved_assert(superseded != owner, "distinct cleanup identity")
			refusal_site.lighting_overlay = owner
			var/old_luminosity = refusal_site.luminosity
			qdel(superseded)
			reserved_assert(refusal_site.lighting_overlay == owner && refusal_site.luminosity == old_luminosity, "superseded cleanup preserves owner")
		// Actual production startup success and exception release, using a
		// wrapper around its real yielding sweep (no fake readiness toggles).
		reserved_startup_mode = "failure"
		reserved_startup_triggered = FALSE
		reserved_startup_waiting_turf = locate(6,6,1)
		var/interrupted = FALSE
		try
			create_lighting("Midday")
		catch (var/exception/E)
			reserved_assert(E.name == "reserved fixture startup interruption", "only intentional startup exception")
			interrupted = TRUE
		reserved_assert(interrupted && !lighting_startup_in_progress && !created_lighting_corners_and_overlays, "startup failure releases barrier")
		sleep(2)
		if (candidate)
			var/turf/failure_site = reserved_startup_waiting_turf
			reserved_assert(!failure_site.lighting_overlay, "failed startup must not refresh overlay")
			var/turf/failed_semantic_site = locate(11,6,1)
			reserved_assert(failed_semantic_site.get_lumcount() == 0.5, "failed startup lumcount fallback")
		reserved_startup_mode = "success"
		reserved_startup_triggered = FALSE
		reserved_startup_waiting_turf = locate(6,10,1)
		create_lighting("Midday")
		reserved_assert(reserved_startup_triggered && created_lighting_corners_and_overlays && !lighting_startup_in_progress, "real startup succeeds")
		reserved_startup_mode = null
		sleep(2)
		var/turf/success_site = reserved_startup_waiting_turf
		reserved_assert(success_site.lighting_overlay, "successful startup activation refreshed")
		var/obj/reserved_lighting_probe/torch = new(locate(3,8,1))
		torch.light_range = 14
		torch.light_power = 0.7
		torch.light_color = "#cc8844"
		torch.light = new /datum/light_source(torch,torch)
		reserved_drain()
		reserved_snapshot("torch")
		var/process/time_of_day_change/P = new
		processes.time_of_day_change = P
		time_of_day = "Night"
		P.apply_daylight("Night", P.lighting_revision)
		reserved_snapshot("night")
		// Production top-atom ownership for a carried source, without actor AI.
		var/obj/reserved_lighting_probe/carrier = new(locate(4,9,1))
		torch.loc = carrier
		torch.light.update(carrier)
		reserved_drain()
		reserved_assert(torch.light.top_atom == carrier && (torch.light in carrier.light_sources), "carried source ownership")
		reserved_assert(torch.light.source_turf == get_turf(carrier), "carried source position")
		reserved_snapshot("carried")
		torch.loc = locate(13,8,1)
		torch.light.update(torch)
		torch.light.force_update()
		reserved_drain()
		reserved_assert(!(torch.light in carrier.light_sources), "released carrier membership")
		reserved_snapshot("moved")
		var/turf/occluder = locate(4,8,1)
		occluder.opacity = TRUE
		occluder.recalc_atom_opacity()
		occluder.reconsider_lights()
		reserved_drain()
		reserved_snapshot("opacity")
		occluder.opacity = FALSE
		occluder.recalc_atom_opacity()
		occluder.reconsider_lights()
		reserved_drain()
		var/turf/center = locate(8,8,1)
		center.activate_reserved_lighting()
		reserved_drain()
		if (candidate)
			for (var/turf/T in range(1,center))
				reserved_assert(T.lighting_overlay, "activation reconstructs halo overlay")
				reserved_assert(T.lighting_overlay.TOD == time_of_day, "activation current TOD")
		// Native replacement must fail open and preserve shared corner identities.
		var/turf/target = locate(10,10,1)
		target.ChangeTurf(/turf/reserved_lighting_probe/replaced)
		reserved_assert(!target.lighting_reserved && target.lighting_overlay, "replacement activates")
		target = target.ChangeTurf(/turf/floor/beach/water/ice/reserved_lighting_probe)
		var/atom/movable/lighting_overlay/ice_owner = target.lighting_overlay
		// Drop only the cached pointer; preserve the actual owner in contents.
		target.lighting_overlay = null
		target.adjust_lighting_overlay_to_daylight()
		reserved_assert(target.lighting_overlay == ice_owner, "ice repair restores actual owner")
		for (var/i = 1 to 4)
			reserved_assert(target.corners[i], "ice repair retains every corner")
		// Actual production entry save/import, no live or existing saves.
		var/map_storage/storage = new
		var/savefile/F = new("reserved-roundtrip.sav")
		F["/format_version"] << 2
		storage.saving_z = 1
		var/index = storage.BuildVarDirectory(F,center)
		// Historical/malformed runtime fields cannot restore a reservation.
		F.cd = storage.entry_path(F,index)
		F["lighting_reserved"] << TRUE
		storage.clear_bookkeeping()
		var/turf/destination = locate(7,7,1)
		storage.Load_Entry(F,index,destination)
		reserved_assert(!destination.lighting_reserved && destination.lighting_overlay, "import activates")
		F.cd = storage.entry_path(F,index)
		F["type"] << /turf/reserved_lighting_probe/reserved_subtype
		storage.clear_bookkeeping()
		var/turf/subtype_destination = locate(7,10,1)
		storage.Load_Entry(F,index,subtype_destination)
		reserved_assert(!subtype_destination.lighting_reserved && subtype_destination.lighting_overlay, "reserved replacement subtype imports active")
		reserved_drain()
		reserved_snapshot("activated")
		text2file("PASS", "result.txt")
	catch (var/exception/E)
		text2file("FAIL: [E.name]", "result.txt")
	shutdown()
