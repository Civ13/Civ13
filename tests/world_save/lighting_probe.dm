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
		var/datum/lighting_corner/corner = new(locate(3,3,1), NORTHEAST, TRUE)
		var/atom/movable/lighting_overlay/overlay = new(locate(3,3,1), TRUE)
		carrier.indirect_source = original_source
		carrier.indirect_corner = corner
		carrier.indirect_overlay = overlay
		durable_world_check(!original_source.should_save && !corner.should_save, "derived lighting datums are exportable")
		durable_world_check(!overlay.should_save, "derived overlay is exportable")
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
		var/process/lighting_sources/light_process = new
		light_process.run_time_tick_usage_allowance = 10
		for(var/attempt = 1, attempt <= 20 && lighting_update_lights.len, attempt++)
			light_process.run_time_tick_usage = world.tick_usage
			light_process.fire()
			sleep(1)
		durable_world_check(lamp.light.applied && default_lamp.light.applied && !lamp.light.needs_update && !default_lamp.light.needs_update, "restored lights failed native application")
		durable_world_check(dview_mob == runtime_view && !dview_mob.loc && !dview_mob.gcDestroyed && !dview_mob.gc_destroyed, "native light application retired runtime view helper")
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
