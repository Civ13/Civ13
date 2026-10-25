// Prepared only. Uses the actual serializer/header/loadmap with minimal adapters.
// Area reassignment models the roofing seam; it does not construct a game roof.
/world
	name = "Civ13 isolated elevation fixture"
	maxx = 8
	maxy = 6
	maxz = 2
	turf = /turf/elevation_ground
	visibility = 0
	hub = ""
/turf/elevation_ground
/turf/elevation_replaced
/area/elevation_room
/obj/item/elevation_container
/obj/item/elevation_payload
var/elevation_checks = 0
/proc/elevation_check(condition, message)
	elevation_checks++
	if(!condition) throw EXCEPTION(message)
/world/OpenPort(port)
	return ..("none")
/client/New()
	del(src)
/world/Error(exception/E)
	errors += "[E]"
	world.log << "FAIL: unexpected runtime [E] at [E.file]:[E.line]"
/world/New()
	OpenPort("none")
	try
		elevation_check(world.port == 0, "fixture port not closed")
		map = new /obj/map_metadata(locate(1,1,1))
		ticker = new
		elevation_check(get_elevation(locate(3,3,1)) == 0, "fresh default not flat zero")
		map.elevation_default_metres = 15
		map.elevation_regions = list(list("x1" = 2, "x2" = 4, "y1" = 2, "y2" = 4, "z" = 1, "metres" = 1200), list("x1" = 8, "x2" = 8, "y1" = 6, "y2" = 6, "z" = 2, "metres" = -200))
		map.elevation_profile_cache = null
		var/turf/T = locate(3,3,1)
		var/obj/item/elevation_container/bag = new(T)
		var/obj/item/elevation_payload/payload = new(bag)
		elevation_check(get_elevation(payload) == 1200, "contained physical location lost")
		var/area/elevation_room/room = new
		room.contents += T
		elevation_check(get_elevation(payload) == 1200, "area replacement lost elevation")
		T = new /turf/elevation_replaced(T)
		elevation_check(get_elevation(payload) == 1200, "native turf replacement lost elevation")
		T = T.ChangeTurf(/turf/elevation_ground, FALSE, FALSE)
		elevation_check(get_elevation(T) == 1200, "ChangeTurf lost elevation")
		elevation_check(get_elevation(locate(3,3,2)) == 15, "z inferred height")
		elevation_check(map_storage.Save_World(), "elevation export failed")
		var/header = file2text("map_saves/round.json")
		var/list/state = map_storage.read_round_state()
		var/list/snapshot = state["elevation"]
		var/list/rows = snapshot["regions"]
		var/list/first = rows[1]
		first["x1"] = 0
		fdel("map_saves/round.json")
		text2file(json_encode(state), "map_saves/round.json")
		elevation_check(!map_storage.validate_world_save() && get_elevation(payload) == 1200 && payload.loc == bag, "bad snapshot admitted or mutated live world")
		fdel("map_saves/round.json")
		text2file(header, "map_saves/round.json")
		map.elevation_default_metres = 9000
		map.elevation_regions = null
		map.elevation_profile_cache = null
		elevation_check(ticker.loadmap(), "saved elevation import failed")
		elevation_check(get_elevation(locate(3,3,1)) == 1200 && get_elevation(locate(1,1,2)) == 15, "new defaults replaced saved geography")
		elevation_check(get_elevation(locate(8,6,2)) == -200, "saved edge or second plane lost")
		var/obj/item/elevation_payload/restored = locate() in world
		elevation_check(restored && get_elevation(restored) == 1200, "restored nested payload lost physical elevation")
		state = map_storage.read_round_state()
		state.Remove("elevation")
		fdel("map_saves/round.json")
		text2file(json_encode(state), "map_saves/round.json")
		map.elevation_profile_cache = null
		elevation_check(ticker.loadmap(), "legacy missing elevation rejected")
		elevation_check(get_elevation(locate(3,3,1)) == 0 && get_elevation(locate(8,6,2)) == 0, "legacy did not restore flat zero")
		elevation_check(!errors.len, "native diagnostic occurred")
		text2file(json_encode(list("passed" = TRUE, "checks" = elevation_checks)), "elevation-result.json")
	catch(var/exception/elevation_failure)
		world.log << "FAIL: [elevation_failure] at [elevation_failure.file]:[elevation_failure.line]"
		text2file(json_encode(list("passed" = FALSE, "checks" = elevation_checks, "error" = "[elevation_failure]")), "elevation-result.json")
	del(world)
	return
