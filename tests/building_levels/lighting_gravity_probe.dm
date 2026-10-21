/world
	maxx = 8
	maxy = 8
	maxz = 2
	turf = /turf/floor/plating
	area = /area/caribbean
	hub = ""
	hub_password = ""

/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

/obj/map_metadata/lighting_gravity_tester/New()
	return

// Keep unrelated constructor work out; neither payload overrides forceMove/Entered.
/obj/item/lighting_gravity_payload
	anchored = TRUE
/obj/item/lighting_gravity_payload/New()
	return
/mob/lighting_gravity_payload/New()
	return

/proc/lighting_gravity_assert(condition, message)
	if (!condition)
		throw EXCEPTION(message)

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.stat_set_event = new
		GLOB.name_set_event = new
		map = new /obj/map_metadata/lighting_gravity_tester
		// Production startup builds actual shared corners and actual renderer atoms.
		create_lighting("Midday")
		lighting_gravity_assert(created_lighting_corners_and_overlays, "production lighting startup completed")
		var/turf/upper = locate(3,3,2)
		var/turf/below = locate(3,3,1)
		var/atom/movable/lighting_overlay/renderer = upper.lighting_overlay
		lighting_gravity_assert(renderer && renderer.loc == upper, "production renderer starts on upper level")
		// Real turf.New carries contents and schedules Entered; do not adapt that loop.
		upper = new /turf/sky/building(upper)
		sleep(1)
		var/replacement_moved_renderer = renderer.loc != upper
		text2file(json_encode(list("phase"="replacement", "renderer_fell"=replacement_moved_renderer, "renderer_z"=renderer.z, "upper_pointer_matches"=(upper.lighting_overlay == renderer))), "fixture.jsonl")
		// Independently exercise actual forceMove -> sky.Entered. This is an explicit
		// handler challenge, separate from the natural replacement observation above.
		renderer.forceMove(locate(4,3,2))
		renderer.forceMove(upper)
		var/renderer_stayed = renderer.loc == upper
		var/obj/item/lighting_gravity_payload/item = new(locate(4,3,2))
		item.forceMove(upper)
		var/mob/lighting_gravity_payload/M = new(locate(4,3,2))
		M.forceMove(upper)
		text2file(json_encode(list("phase"="entry", "renderer_stayed"=renderer_stayed, "item_fell"=(item.loc == below), "item_anchored"=item.anchored, "mob_fell"=(M.loc == below))), "fixture.jsonl")
		lighting_gravity_assert(item.loc == below, "ordinary anchored item still falls")
		lighting_gravity_assert(M.loc == below, "ordinary mob still falls")
		lighting_gravity_assert(renderer_stayed, "lighting renderer stays on upper level")
		lighting_gravity_assert(!replacement_moved_renderer, "replacement does not drop lighting renderer")
		text2file("PASS: lighting gravity", "result.txt")
	catch (var/exception/E)
		world.log << "LIGHTING GRAVITY exception: [E] at [E.file]:[E.line]"
		text2file("FAIL: [E.name]", "result.txt")
	shutdown()
