// Line-of-sight cost probe (issue #3582). Manual native tool, never compiled
// by CI (see README.md). Included at the end of a copy of civ13.dme so it can
// wrap game procs. It needs real Dream Seeker clients: it waits for them,
// gives each a human body and scripts standing, walking, camera pans and a
// door, with 1, 2, 4 and 8 of them active.
var/global/datum/los_cost_probe/los_cost_probe = new

/datum/los_cost_probe
	var/list/marks = list()
	var/started_tod = 0
	var/want_clients = 8
	var/phase_seconds = 12
	var/list/players = list()	// clients, in arrival order
	var/list/bodies = list()	// their humans, same order
	var/turf/centre
	var/obj/structure/simple_door/door
	var/measuring = FALSE
	// Per-phase counters, filled by the wrappers below. Times are in ms.
	var/list/count = list()
	var/list/ms = list()
	var/overhead_ms = 0
	var/image_adds = 0
	var/image_removes = 0

/datum/los_cost_probe/New()
	started_tod = world.timeofday
	spawn(10)
		drive()

/datum/los_cost_probe/proc/mark(name, list/data)
	var/list/row = list("phase" = name, "wall_s" = (world.timeofday - started_tod) / 10)
	if(data)
		row += data
	marks += list(row)
	world.log << "LOSPROBE [name]"
	fdel("probe-marks.json")
	text2file(json_encode(marks), "probe-marks.json")

/datum/los_cost_probe/proc/set_phase(label)
	fdel("probe-phase.txt")
	text2file(label, "probe-phase.txt")

/datum/los_cost_probe/proc/add(key, started_usage)
	if(!measuring)
		return
	count[key] = count[key] + 1
	ms[key] = ms[key] + (world.tick_usage - started_usage) * world.tick_lag

/datum/los_cost_probe/proc/open_turf(turf/T)
	if(!istype(T, /turf/floor/grass) || T.density)
		return FALSE
	for(var/atom/movable/A in T)
		if(A.density || A.opacity)
			return FALSE
	return TRUE

// Open grass tiles, sight blockers and trees in the 21x21 square around T.
/datum/los_cost_probe/proc/scene_stats(turf/T)
	var/good = 0
	var/opaque = 0
	var/trees = 0
	for(var/turf/U in range(10, T))
		if(open_turf(U))
			good++
		for(var/atom/movable/A in U)
			if(A.opacity)
				opaque++
			if(root_tree_family(A))
				trees++
	return list(good, opaque, trees)

// A field is mostly open grass with few trees and almost no blockers; a
// forest has at least `trees` trees. Trees do not block sight, but each one
// is another atom to decide and to draw. A map with no such field gets the
// most open spot that can be found.
/datum/los_cost_probe/proc/find_scene(trees = 0, list/avoid)
	for(var/need in (trees ? list(150) : list(330, 250, 150)))
		for(var/tries in 1 to 40000)
			var/turf/T = locate(rand(25, world.maxx - 25), rand(25, world.maxy - 25), rand(1, world.maxz))
			if(!open_turf(T))
				continue
			var/near = FALSE
			for(var/turf/other in avoid)
				if(other.z == T.z && get_dist(other, T) < 70)
					near = TRUE
			if(near)
				continue
			var/list/stats = scene_stats(T)
			if(stats[1] < need || (trees ? stats[3] < trees : (stats[2] > 6 || (need == 330 && stats[3] > 20))))
				continue
			return T
	return null

/datum/los_cost_probe/proc/scene_text(turf/T)
	if(!T)
		return null
	var/list/stats = scene_stats(T)
	return "[T.x],[T.y],[T.z] open=[stats[1]] blockers=[stats[2]] trees=[stats[3]]"

// A 5x5 wooden hut with a door in its south wall, four tiles north of T.
/datum/los_cost_probe/proc/build_hut(turf/T)
	for(var/dx in -2 to 2)
		for(var/dy in 4 to 8)
			if(abs(dx) != 2 && dy != 4 && dy != 8)
				continue
			var/turf/U = locate(T.x + dx, T.y + dy, T.z)
			if(!U)
				continue
			for(var/atom/movable/A in U)
				if(A.density || A.opacity)
					qdel(A)
			if(dx == 0 && dy == 4)
				door = new /obj/structure/simple_door(U, "wood")
			else
				new /obj/covers/wood_wall(U)

/datum/los_cost_probe/proc/place(active, spread = FALSE, list/spots)
	for(var/i in 1 to bodies.len)
		var/mob/living/human/H = bodies[i]
		var/client/C = players[i]
		if(!C || !H)
			continue
		C.stopmovingright()
		C.stopmovingleft()
		if(i > active)
			// Parked: no context, and nothing of the scene on screen.
			C.set_geometric_los(FALSE)
			H.forceMove(locate(3 + i, 3, 1))
			continue
		C.set_geometric_los(TRUE)
		if(spread && spots)
			H.forceMove(spots[i])
		else
			H.forceMove(locate(centre.x - 3 + ((i - 1) % 4) * 2, centre.y - 1 - round((i - 1) / 4) * 2, centre.z))

/datum/los_cost_probe/proc/pan(client/C, on)
	var/target = on ? world.icon_size * 7 : 0
	C.los_prepare_camera_pan(target, 0, 3, C.view)
	animate(C, pixel_x = target, pixel_y = 0, time = 3, easing = SINE_EASING)
	C.pixel_x = target
	C.pixel_y = 0

/datum/los_cost_probe/proc/profile_rows()
	var/list/rows = list()
	var/list/all = json_decode(world.Profile(PROFILE_REFRESH, null, "json"))
	for(var/list/entry in all)
		var/name = entry["name"]
		if(!entry["calls"] || !(findtext(name, "los_") || findtext(name, "root_tree") || findtext(name, "/process/visibility")))
			continue
		rows += list(list("name" = name, "self_s" = entry["self"], "total_s" = entry["total"], "calls" = entry["calls"]))
	return rows

// kind: stand, walk-one, walk-all, pan or door.
/datum/los_cost_probe/proc/run_phase(scene, kind, active)
	var/label = "[scene]/[kind]/[active]"
	sleep(30)	// settle after placement
	set_phase(label)
	count = list()
	ms = list()
	overhead_ms = 0
	image_adds = 0
	image_removes = 0
	world.Profile(PROFILE_CLEAR)
	world.Profile(PROFILE_START)
	measuring = TRUE
	var/cpu = 0
	var/samples = 0
	var/images = 0
	var/masks = 0
	var/dir = EAST
	var/flip = FALSE
	var/list/start_turfs = list()
	for(var/i in 1 to active)
		start_turfs += get_turf(bodies[i])
	var/walkers = kind == "walk-all" ? active : (kind == "walk-one" ? 1 : 0)
	for(var/i in 1 to walkers)
		var/client/C = players[i]
		C.startmovingright()
	var/until = world.time + phase_seconds * 10
	var/next_turn = world.time + 30
	var/next_event = world.time + 10
	var/tiles = 0
	var/list/last_turfs = start_turfs.Copy()
	while(world.time < until)
		sleep(2)
		cpu += world.cpu
		samples++
		var/now_images = 0
		var/now_masks = 0
		for(var/i in 1 to active)
			var/client/C = players[i]
			if(!C)
				continue
			now_images += C.images.len
			if(C.los_presenter)
				now_masks += C.los_presenter.owned_images.len
			var/turf/now = get_turf(bodies[i])
			if(now != last_turfs[i])
				tiles++
				last_turfs[i] = now
		images = max(images, now_images)
		masks = max(masks, now_masks)
		if(walkers && world.time >= next_turn)
			next_turn = world.time + 30
			for(var/i in 1 to walkers)
				var/client/C = players[i]
				if(dir == EAST)
					C.stopmovingright()
					C.startmovingleft()
				else
					C.stopmovingleft()
					C.startmovingright()
			dir = dir == EAST ? WEST : EAST
		if(world.time >= next_event)
			next_event = world.time + 20
			flip = !flip
			if(kind == "pan")
				for(var/i in 1 to active)
					pan(players[i], flip)
			if(kind == "door" && door && !door.isSwitchingStates)
				door.SwitchState()
	measuring = FALSE
	world.Profile(PROFILE_STOP)
	for(var/i in 1 to active)
		var/client/C = players[i]
		if(!C)
			continue
		C.stopmovingright()
		C.stopmovingleft()
		if(kind == "pan")
			pan(C, FALSE)
	var/blockers = 0
	var/client/first = players[1]
	if(first && first.los_context)
		var/datum/los_snapshot/S = first.los_context.capture(TRUE)
		if(S)
			blockers = S.blockers.len
	mark(label, list("scene" = scene, "kind" = kind, "active" = active, "seconds" = phase_seconds, "avg_cpu" = round(cpu / max(1, samples), 0.1), "count" = count, "ms" = ms, "probe_overhead_ms" = overhead_ms, "image_adds" = image_adds, "image_removes" = image_removes, "max_client_images" = images, "max_los_masks" = masks, "tiles_walked" = tiles, "blockers" = blockers, "connected" = clients.len, "profile" = profile_rows()))
	set_phase("idle")

// Non-atom datums are not in world; a bare for() walks every datum.
/datum/los_cost_probe/proc/live_objects()
	var/contexts = 0
	var/presenters = 0
	var/tree_presenters = 0
	var/snapshots = 0
	for(var/datum/los_context/V)
		contexts++
	for(var/datum/los_presenter/P)
		presenters++
	for(var/datum/root_tree_presenter/R)
		tree_presenters++
	for(var/datum/los_snapshot/S)
		snapshots++
	var/held_images = 0
	var/held_lists = 0
	for(var/client/C in clients)
		held_images += C.images.len
		var/datum/los_presenter/P = C.los_presenter
		if(P)
			held_lists += P.images.len + P.owned_images.len + P.visible_targets.len + P.tree_images.len + P.tree_appearances.len
		var/datum/los_context/V = C.los_context
		if(V && V.audit_appearances)
			held_lists += V.audit_appearances.len
	return list("contexts" = contexts, "presenters" = presenters, "tree_presenters" = tree_presenters, "snapshots" = snapshots, "active_contexts" = length(los_active_contexts), "client_images" = held_images, "presenter_list_entries" = held_lists, "connected" = clients.len)

/datum/los_cost_probe/proc/memory_phase(label, seconds = 10)
	sleep(30)
	set_phase(label)
	sleep(seconds * 10)
	mark(label, live_objects())
	set_phase("idle")

/datum/los_cost_probe/proc/drive()
	if(world.params["los_clients"])
		want_clients = max(1, text2num(world.params["los_clients"]))
	if(world.params["los_seconds"])
		phase_seconds = max(4, text2num(world.params["los_seconds"]))
	set_phase("booting")
	while(!(ticker && ticker.current_state == GAME_STATE_PLAYING))
		if(config)
			config.guests_allowed = TRUE
			config.webhook_can_fire = FALSE
		if(ticker && ticker.current_state == GAME_STATE_PREGAME)
			ticker.pregame_timeleft = 1
			ticker.admin_started = TRUE
			round_progressing = TRUE
		sleep(10)
	sleep(100)
	// The same scenes for the on and off builds of one map.
	rand_seed(3582)
	centre = find_scene()
	var/turf/forest = null
	for(var/trees in list(80, 50, 30))
		if(!forest && centre)
			forest = find_scene(trees, list(centre))
	if(!centre)
		mark("no clear field found")
		set_phase("done")
		return
	var/field_text = scene_text(centre)
	build_hut(centre)
	mark("playing", list("map" = "[map ? map.ID : null]", "maxx" = world.maxx, "maxy" = world.maxy, "maxz" = world.maxz, "fps" = world.fps, "geometric_los" = CIV13_GEOMETRIC_LOS_CORE, "field" = field_text, "forest" = scene_text(forest), "want_clients" = want_clients, "byond" = "[world.byond_version].[world.byond_build]"))
	set_phase("waiting for clients")
	var/waited = 0
	var/patience = world.params["los_wait"] ? text2num(world.params["los_wait"]) : 600
	while(clients.len < want_clients && waited < patience)
		sleep(10)
		waited++
	sleep(100)
	for(var/client/C in clients)
		if(players.len >= want_clients)
			break
		var/mob/living/human/H = new /mob/living/human(centre)
		H.ckey = C.ckey
		bodies += H
	sleep(50)
	for(var/mob/living/human/H in bodies)
		players += H.client
	if(!players.len || !players[1])
		mark("no clients")
		set_phase("done")
		return
	var/client/first = players[1]
	mark("clients", list("connected" = players.len, "view" = "[first.view]", "client_fps" = first.fps, "client_byond" = "[first.byond_version].[first.byond_build]"))
	var/list/steps = list()
	for(var/n in list(1, 2, 4, 8, 16))
		if(n <= players.len)
			steps += n
	if(!(players.len in steps))
		steps += players.len
	for(var/active in steps)
		place(active)
		for(var/kind in list("stand", "walk-one", "walk-all", "pan", "door"))
			place(active)
			run_phase("field", kind, active)
	if(forest)
		var/saved = centre
		centre = forest
		for(var/active in steps)
			for(var/kind in list("stand", "walk-all"))
				place(active)
				run_phase("forest", kind, active)
		centre = saved
	// Every viewer alone in its own field: per-viewer cost without neighbours.
	var/list/spots = list(centre)
	while(spots.len < players.len)
		var/turf/T = find_scene(0, spots)
		if(!T)
			break
		spots += T
	if(spots.len >= players.len && players.len > 1)
		place(players.len, TRUE, spots)
		run_phase("apart", "stand", players.len)
		place(players.len, TRUE, spots)
		run_phase("apart", "walk-all", players.len)
	// Memory: everyone in the field with line of sight, then released, twice.
	place(players.len)
	memory_phase("memory/held-1")
	if(CIV13_GEOMETRIC_LOS_CORE)
		for(var/client/C in players)
			if(C)
				C.set_geometric_los(FALSE)
		memory_phase("memory/released-1")
		place(players.len)
		memory_phase("memory/held-2")
		for(var/client/C in players)
			if(C)
				C.set_geometric_los(FALSE)
		memory_phase("memory/released-2")
		place(players.len)
		memory_phase("memory/held-3")
	for(var/client/C in players)
		if(C)
			del(C)
	memory_phase("memory/disconnected")
	set_phase("done")
	mark("done")

/client/reconcile_geometric_los()
	var/t = world.tick_usage
	var/before = los_cost_probe.overhead_ms
	. = ..()
	if(los_cost_probe.measuring)
		los_cost_probe.add("reconcile", t)
		los_cost_probe.ms["reconcile"] -= los_cost_probe.overhead_ms - before

/datum/los_context/capture(presentation = FALSE, atom/focus = null)
	var/t = world.tick_usage
	. = ..()
	los_cost_probe.add(presentation ? "capture" : "capture_read", t)

/datum/los_context/audit_scene_unchanged(datum/los_snapshot/S)
	var/t = world.tick_usage
	. = ..()
	los_cost_probe.add("audit_scan", t)

/datum/los_context/record_audit_scene(datum/los_snapshot/S)
	var/t = world.tick_usage
	. = ..()
	los_cost_probe.add("audit_record", t)

/datum/los_presenter/refresh(datum/los_snapshot/S)
	var/t0 = world.tick_usage
	var/list/before = los_cost_probe.measuring ? owned_images.Copy() : null
	var/t = world.tick_usage
	. = ..()
	los_cost_probe.add("presenter_refresh", t)
	if(before)
		var/t1 = world.tick_usage
		var/kept = 0
		for(var/I in before)
			if(owned_images[I])
				kept++
		los_cost_probe.image_removes += before.len - kept
		los_cost_probe.image_adds += owned_images.len - kept
		los_cost_probe.overhead_ms += ((t - t0) + (world.tick_usage - t1)) * world.tick_lag

/datum/los_presenter/refresh_targets(datum/los_snapshot/S, list/targets)
	var/t = world.tick_usage
	. = ..()
	los_cost_probe.add("presenter_targets", t)

/datum/root_tree_presenter/refresh(datum/los_snapshot/S)
	var/t = world.tick_usage
	. = ..()
	los_cost_probe.add("tree_refresh", t)
