// Actual production lighting constructors, saver and loader. No scheduler/client.
/obj/map_metadata/persistence_lighting_probe/New()
	map = src
/obj/map_metadata/persistence_lighting_probe
	ID = "LIGHTING_FIXTURE"
/obj/item/persistence_light_container
	var/list/legacy_runtime_refs
	var/datum/light_source/indirect_source
	var/datum/lighting_corner/indirect_corner
	var/atom/movable/lighting_overlay/indirect_overlay
/obj/item/persistence_custom_light
/obj/item/persistence_clear_fixture
/obj/item/persistence_opaque_fixture
	opacity = TRUE
/obj/item/persistence_default_light
	light_range = 2
	light_power = 1
	light_color = "#112233"

// Exercise the actual propagation procedures on the unused second level.
// No replacement for recalc_corner, native view(), or corner luminosity updates.
/proc/lighting_corner_snapshot(list/corners)
	var/list/result = list()
	for(var/datum/lighting_corner/C in corners)
		result += C.lum_r
		result += C.lum_g
		result += C.lum_b
	return result

/proc/lighting_corner_parity(list/before, list/after)
	durable_world_check(before.len == after.len, "corner snapshot dimensions differ")
	for(var/i = 1, i <= before.len, i++)
		durable_world_check(abs(before[i] - after[i]) < 0.000001, "corner propagation RGB differs")

/proc/lighting_probe_drain()
	var/process/lighting_sources/P = new
	P.run_time_tick_usage_allowance = 10
	for(var/attempt = 1, attempt <= 20 && lighting_update_lights.len, attempt++)
		P.run_time_tick_usage = world.tick_usage
		P.fire()
		sleep(1)
	durable_world_check(!lighting_update_lights.len, "lighting queue failed to drain")

/proc/lighting_graph_snapshot(datum/light_source/custom, datum/light_source/default_source)
	var/list/result = list()
	for(var/turf/T in block(locate(1,1,1), locate(8,8,1)))
		for(var/datum/lighting_corner/C in T.corners)
			if(!C) continue
			var/key = "[C.x],[C.y],1"
			// Owners are the custom and default fixture lights, independent of refs.
			result[key] = list(C.lum_r, C.lum_g, C.lum_b, C.affecting ? C.affecting.len : 0, (custom in C.affecting), (default_source in C.affecting), isnull(custom.effect_str[C]) ? 0 : custom.effect_str[C], isnull(default_source.effect_str[C]) ? 0 : default_source.effect_str[C])
	return result

/proc/lighting_graph_parity(list/before, list/after)
	durable_world_check(before.len > 2 && before.len == after.len, "reconstructed corner graph dimensions differ")
	for(var/key in before)
		durable_world_check(islist(after[key]), "reconstructed corner coordinates differ")
		lighting_corner_parity(before[key], after[key])

/proc/lighting_corner_allocation_probe()
	var/list/corners = list()
	for(var/turf/T in block(locate(1,1,2), locate(8,8,2)))
		for(var/i = 1, i <= 4, i++)
			if(!T.corners[i])
				T.corners[i] = new /datum/lighting_corner(T, LIGHTING_CORNER_DIAGONAL[i], TRUE)
			var/datum/lighting_corner/C = T.corners[i]
			C.active = FALSE
			corners |= C
	var/initial_lists = 0
	for(var/datum/lighting_corner/C in corners)
		if(islist(C.affecting)) initial_lists++
	text2file(json_encode(list("corners" = corners.len, "initial_lists" = initial_lists)), "lighting-allocation-initial.json")
	durable_world_check(corners.len > 2 && initial_lists == 0, "untouched corners allocated affecting lists")
	var/obj/item/persistence_custom_light/first = new(locate(2,2,2))
	var/obj/item/persistence_custom_light/second = new(locate(6,6,2))
	first.set_light(2, 1, "#ff0000")
	second.set_light(2, 1, "#0000ff")
	var/datum/light_source/A = first.light
	var/datum/light_source/B = second.light
	A.check()
	B.check()
	// Start B normally while corners are inactive, then let visibility activate it.
	B.apply_lum()
	for(var/datum/lighting_corner/C in corners)
		C.active = TRUE
	A.apply_lum()
	B.smart_vis_update()
	durable_world_check(A.effect_str.len && B.effect_str.len, "both corner insertion paths were not exercised")
	var/datum/lighting_corner/one = A.effect_str[1]
	var/datum/lighting_corner/two = B.effect_str[1]
	durable_world_check(one != two && islist(one.affecting) && islist(two.affecting) && one.affecting != two.affecting, "corners share mutable affecting list")
	for(var/datum/lighting_corner/C in A.effect_str)
		durable_world_check((A in C.affecting) && !(B in C.affecting), "apply registration leaked across corners")
	for(var/datum/lighting_corner/C in B.effect_str)
		durable_world_check((B in C.affecting) && !(A in C.affecting), "smart registration leaked across corners")
	var/list/retained = one.affecting
	var/list/before = lighting_corner_snapshot(corners)
	var/list/original_position = before.Copy()
	A.remove_lum()
	durable_world_check(one.affecting == retained && !retained.len, "remove discarded affecting list identity")
	A.smart_vis_update()
	durable_world_check(one.affecting == retained && (A in retained), "re-add replaced affecting list identity")
	lighting_corner_parity(before, lighting_corner_snapshot(corners))
	// Visibility removal through native range, then actual movement and reapplication.
	A.source_turf = locate(8,8,1)
	A.smart_vis_update()
	durable_world_check(!A.effect_str.len && one.affecting == retained && !retained.len, "smart removal retained source or replaced list")
	durable_world_check(first.forceMove(locate(4,2,2)), "allocation light movement refused")
	first.light_range = 3
	A.check()
	durable_world_check(A.source_turf == locate(4,2,2), "moved source turf did not follow owner")
	A.apply_lum()
	before = lighting_corner_snapshot(corners)
	durable_world_check(json_encode(before) != json_encode(original_position), "movement did not change corner illumination")
	A.remove_lum()
	A.smart_vis_update()
	lighting_corner_parity(before, lighting_corner_snapshot(corners))
	// Compare smart occlusion updates with complete remove/apply on the same scene.
	var/obj/item/persistence_opaque_fixture/blocker = new(locate(5,2,2))
	blocker.set_opacity(TRUE)
	A.smart_vis_update()
	durable_world_check(json_encode(before) != json_encode(lighting_corner_snapshot(corners)), "opaque blocker did not change corner illumination")
	before = lighting_corner_snapshot(corners)
	A.remove_lum()
	A.apply_lum()
	lighting_corner_parity(before, lighting_corner_snapshot(corners))
	blocker.set_opacity(FALSE)
	A.smart_vis_update()
	durable_world_check(json_encode(before) != json_encode(lighting_corner_snapshot(corners)), "cleared blocker did not change corner illumination")
	before = lighting_corner_snapshot(corners)
	A.remove_lum()
	A.apply_lum()
	lighting_corner_parity(before, lighting_corner_snapshot(corners))
	A.remove_lum()
	B.remove_lum()
	first.set_light(0)
	second.set_light(0)
	qdel(first)
	qdel(second)
	qdel(blocker)
	var/list/identities = list()
	var/allocated = 0
	for(var/datum/lighting_corner/C in corners)
		if(islist(C.affecting))
			allocated++
			identities["\ref[C.affecting]"] = TRUE
			durable_world_check(!C.affecting.len, "removed light retained corner membership")
	durable_world_check(allocated > 1 && identities.len == allocated, "allocated corners do not own independent lists")
	text2file(json_encode(list("corners" = corners.len, "initial_lists" = initial_lists, "allocated_lists" = allocated, "distinct_lists" = identities.len)), "lighting-allocation.json")

/proc/lighting_saved_ref(savefile/F, wanted_type)
	F.cd = "/entries"
	var/list/shards = F.dir.Copy()
	for(var/shard in shards)
		F.cd = "/entries/[shard]"
		var/list/entries = F.dir.Copy()
		for(var/ref in entries)
			if(F["[map_storage.entry_path(F, ref)]/type"] == wanted_type)
				return ref
	return null

/world/OpenPort(port)
	if(port != "none") return FALSE
	return ..()
/world/IsBanned(key, address, computer_id, type)
	return list("reason" = "Offline lighting fixture")
/world/New()
	text2file("lighting world-New entered", "probe-progress.log")
	world.OpenPort("none")
	try
		durable_world_check(!world.port && !world.OpenPort(0) && !world.OpenPort(18465) && !world.port, "lighting fixture opened a listener")
		text2file(json_encode(list("port" = world.port)), "lighting-port-ready.json")
		sleep(20)
		config = new
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
		ticker = new
		ticker.current_state = GAME_STATE_PREGAME
		game_id = "lighting-disk-round"
		// Startup is isolated; initialize the real observation hooks used by forceMove.
		if(!GLOB) GLOB = new /datum/controller/global_vars
		GLOB.gvars_datum_init_order = list()
		GLOB.InitGlobalall_observable_events()
		GLOB.InitGlobalmoved_event()
		GLOB.InitGlobaldir_set_event()
		text2file("lighting fixture globals ready", "probe-progress.log")
		map = new /obj/map_metadata/persistence_lighting_probe(locate(1,1,1))
		lighting_corner_allocation_probe()
		for(var/turf/T in block(locate(1,1,1), locate(8,8,1)))
			for(var/i = 1, i <= 4, i++)
				if(!T.corners[i])
					T.corners[i] = new /datum/lighting_corner(T, LIGHTING_CORNER_DIAGONAL[i], TRUE)
			if(!T.lighting_overlay) new /atom/movable/lighting_overlay(T, TRUE)
			for(var/datum/lighting_corner/C in T.corners)
				C.active = TRUE
		var/obj/item/persistence_light_container/carrier = new(locate(3,3,1))
		var/obj/item/persistence_custom_light/lamp = new(carrier)
		lamp.set_light(5, 2, "#224466")
		var/obj/item/persistence_default_light/default_lamp = new(locate(4,3,1))
		var/obj/item/persistence_clear_fixture/opaque_item = new(locate(3,4,1))
		opaque_item.set_opacity(TRUE)
		var/obj/item/persistence_opaque_fixture/clear_item = new(locate(4,4,1))
		clear_item.set_opacity(FALSE)
		var/datum/light_source/original_source = lamp.light
		durable_world_check(original_source && original_source.source_atom == lamp && original_source.top_atom == carrier, "real custom light constructor binding failed")
		durable_world_check(default_lamp.light && default_lamp.light.source_atom == default_lamp, "real default light constructor failed")
		durable_world_check(carrier.light_sources.len == 1 && lamp.light_sources.len == 1, "initial source registered more than once")
		var/turf/graph_turf = locate(3,3,1)
		var/datum/lighting_corner/corner = graph_turf.corners[1]
		var/atom/movable/lighting_overlay/overlay = graph_turf.lighting_overlay
		carrier.indirect_source = original_source
		carrier.indirect_corner = corner
		carrier.indirect_overlay = overlay
		durable_world_check(!original_source.should_save && !corner.should_save, "derived lighting datums are exportable")
		durable_world_check(!overlay.should_save, "derived overlay is exportable")
		lighting_probe_drain()
		var/list/saved_graph = lighting_graph_snapshot(lamp.light, default_lamp.light)
		text2file(json_encode(saved_graph), "lighting-graph-before.json")
		durable_world_check(map_storage.Save_World(), "lighting world save failed")
		var/savefile/F = new("map_saves/1.sav")
		var/lamp_ref = lighting_saved_ref(F, /obj/item/persistence_custom_light)
		var/carrier_ref = lighting_saved_ref(F, /obj/item/persistence_light_container)
		var/opaque_ref = lighting_saved_ref(F, /obj/item/persistence_clear_fixture)
		var/clear_ref = lighting_saved_ref(F, /obj/item/persistence_opaque_fixture)
		var/list/opaque_saved = F["[map_storage.entry_path(F, opaque_ref)]/opacity"]
		var/list/clear_saved = F["[map_storage.entry_path(F, clear_ref)]/opacity"]
		durable_world_check(islist(opaque_saved) && islist(clear_saved) && opaque_saved["value"] && !clear_saved["value"], "obstruction fixture values not exported")
		durable_world_check(lamp_ref && carrier_ref, "saved light or container missing")
		F.cd = map_storage.entry_path(F, lamp_ref)
		durable_world_check(!("light" in F.dir) && !("light_sources" in F.dir), "runtime atom lighting fields exported")
		F.cd = map_storage.entry_path(F, carrier_ref)
		durable_world_check(!("light_sources" in F.dir), "container source registry exported")
		durable_world_check(!lighting_saved_ref(F, /datum/light_source) && !lighting_saved_ref(F, /datum/lighting_corner) && !lighting_saved_ref(F, /atom/movable/lighting_overlay), "indirect lighting graph exported")
		// Preserve the shape of historical runtime graphs, including indirect refs.
		var/list/runtime_types = list(/datum/light_source, /datum/lighting_corner, /atom/movable/lighting_overlay)
		for(var/i = 1, i <= runtime_types.len, i++)
			var/ref = "[900 + i]"
			F["[map_storage.entry_path(F, ref)]/type"] << runtime_types[i]
			F["/lists/900/[i]/key"] << list("kind" = "entry", "ref" = ref)
			F["/lists/900/[i]/value"] << list("kind" = "value", "value" = null)
		F["/lists/900/length"] << 3
		F["[map_storage.entry_path(F, carrier_ref)]/legacy_runtime_refs"] << list("kind" = "list", "ref" = "900")
		F["[map_storage.entry_path(F, lamp_ref)]/light"] << list("kind" = "entry", "ref" = "901")
		F["[map_storage.entry_path(F, lamp_ref)]/light_sources"] << list("kind" = "list", "ref" = "900")
		durable_world_check(map_storage.validate_world_save(), "legacy lighting save preflight rejected")
		var/mob/dview/runtime_view = dview_mob
		var/mob/ordinary_mob = new(locate(6,6,1))
		map_storage.ClearMap()
		durable_world_check(dview_mob == runtime_view && dview_mob && !dview_mob.gcDestroyed && !dview_mob.gc_destroyed, "map clearing retired runtime view helper")
		durable_world_check(!ordinary_mob || ordinary_mob.gcDestroyed || ordinary_mob.gc_destroyed, "map clearing retained ordinary mob")
		durable_world_check(map_storage.Load_World(), "legacy lighting graph prevented import")
		// Locate spatially: ClearMap queues old objects for deferred disposal.
		carrier = locate(/obj/item/persistence_light_container) in locate(3,3,1)
		lamp = locate(/obj/item/persistence_custom_light) in carrier
		default_lamp = locate(/obj/item/persistence_default_light) in locate(4,3,1)
		opaque_item = locate(/obj/item/persistence_clear_fixture) in locate(3,4,1)
		clear_item = locate(/obj/item/persistence_opaque_fixture) in locate(4,4,1)
		var/turf/opaque_turf = locate(3,4,1)
		var/turf/clear_turf = locate(4,4,1)
		text2file(json_encode(list("opaque_ref" = "\ref[opaque_item]", "clear_ref" = "\ref[clear_item]", "opaque_value" = opaque_item.opacity, "clear_value" = clear_item.opacity, "opaque_cache" = opaque_turf.has_opaque_atom, "clear_cache" = clear_turf.has_opaque_atom)), "lighting-restored.json")
		durable_world_check(opaque_item.opacity && !clear_item.opacity, "saved obstruction properties changed")
		durable_world_check(opaque_turf.has_opaque_atom && !clear_turf.has_opaque_atom, "restored obstruction caches stale")
		durable_world_check(carrier && lamp && lamp.loc == carrier, "nested light placement lost")
		durable_world_check(lamp.light, "restored custom light not rebuilt")
		durable_world_check(lamp.light != original_source && lamp.light.source_atom == lamp && lamp.light.top_atom == carrier, "restored source owner/top binding differs")
		durable_world_check(lamp.light_power == 2 && lamp.light_range == 5 && lamp.light_color == "#224466", "durable light properties changed")
		durable_world_check(default_lamp.light && default_lamp.light.source_atom == default_lamp, "default source lost during import")
		durable_world_check(lamp.light_sources.len == 1 && carrier.light_sources.len == 1 && default_lamp.light_sources.len == 1, "restored source registration duplicated")
		durable_world_check(islist(carrier.legacy_runtime_refs) && carrier.legacy_runtime_refs.len == 3, "legacy reference list shape changed")
		for(var/i = 1, i <= carrier.legacy_runtime_refs.len, i++)
			durable_world_check(isnull(carrier.legacy_runtime_refs[i]), "legacy runtime reference constructed")
		durable_world_check(!carrier.indirect_source && !carrier.indirect_corner && !carrier.indirect_overlay, "indirect source graph restored")
		// Run the production light queue through native view(), not only bindings.
		lighting_probe_drain()
		durable_world_check(lamp.light.applied && default_lamp.light.applied && !lamp.light.needs_update && !default_lamp.light.needs_update, "restored lights failed native application")
		durable_world_check(dview_mob == runtime_view && !dview_mob.loc && !dview_mob.gcDestroyed && !dview_mob.gc_destroyed, "native light application retired runtime view helper")
		var/list/restored_graph = lighting_graph_snapshot(lamp.light, default_lamp.light)
		text2file(json_encode(restored_graph), "lighting-graph-after.json")
		lighting_graph_parity(saved_graph, restored_graph)
		var/obj/item/persistence_light_container/new_carrier = new(locate(5,3,1))
		// Use the production movement API, which dispatches Entered/Exited hooks.
		durable_world_check(lamp.forceMove(new_carrier), "restored light movement refused")
		durable_world_check(lamp.light.top_atom == new_carrier && !carrier.light_sources.len && new_carrier.light_sources.len == 1, "restored light movement left stale top registration")
		lamp.set_light(0)
		durable_world_check(!lamp.light && !new_carrier.light_sources.len && !lamp.light_sources.len, "restored light switch-off retained registrations")
		if(durable_probe_failed) throw EXCEPTION("native runtime error occurred")
		text2file(json_encode(list("done" = TRUE, "checks" = durable_probe_checks)), "metadata-result.json")
	catch(var/exception/E)
		world.log << "FAIL: [E] at [E.file]:[E.line]"
		text2file(json_encode(list("done" = FALSE, "checks" = durable_probe_checks, "error" = "[E]", "import_error" = map_storage.last_error)), "metadata-result.json")
	del(world)
