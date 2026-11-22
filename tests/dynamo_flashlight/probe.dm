// Native probe: the dynamo flashlight intensity cycle keeps its light in step (#6756).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/dynamo_flashlight/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 12
	maxy = 12
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/df_probe/New()
	return

var/df_failures = 0
var/df_runtime_error = FALSE
/proc/df_check(condition, label)
	if (!condition)
		df_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	df_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.name_set_event = new /decl/observ/name_set
		GLOB.stat_set_event = new /decl/observ/stat_set
		makeDatumRefLists()
		movementMachine = new
		map = new /obj/map_metadata/df_probe
		df_checks()
	catch(var/exception/e)
		df_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = df_failures, "runtime_error" = df_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/df_checks()
	var/mob/living/human/user = new(locate(5, 5, 1))
	var/obj/item/flashlight/japflashlight/F = new(locate(6, 5, 1))
	F.on = FALSE
	F.update_icon()
	F.secondary_attack_self(user)
	df_check(F.intensity == 1 && !F.light_range && !F.light, "changing intensity while off emits no light ([F.light_range])")
	F.update_light()
	df_check(!F.light, "an unlit flashlight stays dark after a later light update")
	F.on = TRUE
	F.update_icon()
	df_check(F.light_range == 3 && F.light && F.light.light_range == 3, "switching on uses the chosen low intensity ([F.light_range])")
	// Settle the queued creation as the lighting process would, then cycle.
	F.light.needs_update = FALSE
	lighting_update_lights -= F.light
	F.secondary_attack_self(user)
	df_check(F.light_range == 2 && F.light && F.light.needs_update, "changing intensity while lit queues the light at once")
	F.light.check()
	df_check(F.light.light_range == 2, "the queued light takes the new range ([F.light.light_range])")
	F.light.needs_update = FALSE
	lighting_update_lights -= F.light
	F.secondary_attack_self(user)
	df_check(F.light_range == 5 && F.light.needs_update, "cycling back to normal queues full range")
