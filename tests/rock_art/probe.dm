// Native rock art probe, included by tests/ecology_spawning/run_linux.py, never by
// the game DME. It drives code/modules/1713/rock_art.dm.
/world
	hub = ""
	hub_password = ""
	maxx = 30
	maxy = 30
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/rock_probe/New()
	map = src
/mob/living/human/rock_probe/New()
	icon_update = FALSE
	return
var/rock_failures = 0
var/rock_runtime_error = FALSE
/proc/rock_check(condition, label)
	if (!condition)
		rock_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	rock_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"


/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/rock_probe
		for (var/turf/T in block(locate(1, 1, 1), locate(30, 30, 1)))
			T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
		locate(10, 11, 1):ChangeTurf(/turf/wall/rockwall, FALSE, FALSE)
		rock_checks()
	catch(var/exception/e)
		rock_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = rock_failures, "runtime_error" = rock_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/rock_checks()
	var/turf/wall = locate(10, 11, 1)
	var/turf/stand = locate(10, 10, 1)
	rock_check(rock_art_surface(wall) && !rock_art_surface(stand), "only natural rock takes rock art")
	var/mob/living/human/rock_probe/H = new(stand)
	var/obj/item/pigment/ochre_red/P = new(stand)
	P.afterattack(wall, H, TRUE)
	var/obj/structure/rock_art/R = rock_art_on(stand, NORTH)
	rock_check(R && R.pixel_y == 32, "a pigment on the rock starts rock art on that face")
	var/obj/item/canvas/rock/C = R ? R.held_canvas() : null
	rock_check(C && !C.needs_easel && C.base_colour == ROCK_ART_BASE, "it holds a rock canvas")
	rock_check(C && painting_can_reach(H, C), "the painter on the tile can reach it")
	var/mob/living/human/rock_probe/far = new(locate(12, 10, 1))
	rock_check(C && !painting_can_reach(far, C), "someone off the tile can't")
	P.afterattack(wall, H, TRUE)
	var/count = 0
	for (var/obj/structure/rock_art/X in stand)
		count++
	rock_check(count == 1, "a second use reopens the same rock art")
	var/small = ""
	for (var/i = 1 to 32 * 32)
		small += (i == 1 ? "a42" : "876")
	C.small = small
	var/icon/I = C.rock_icon()
	rock_check(I && I.GetPixel(1, 32) == "#aa4422", "paint shows")
	rock_check(I && !I.GetPixel(2, 32), "bare rock stays clear")
	C.finished = TRUE
	C.title = "Hunt"
	R.update_icon()
	rock_check(R.name == "\"Hunt\"" && R.overlays.len == 1, "finished rock art shows its title and paint")
	rock_check(C.format_weight == 0.5, "rock art counts half a painting")
	qdel(R)
	rock_check(QDELETED(C), "removing the rock art removes its canvas")
