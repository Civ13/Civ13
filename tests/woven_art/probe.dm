// Native probe: woven rugs and tapestries use dyes not pigments, lie on the
// floor or hang on a wall, and count as art and floor cover for a home.
// Run: python3 tests/ecology_spawning/run_linux.py . tests/woven_art/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 8
	maxy = 8
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/mob/living/human/wa_probe/New()
	return
/mob/living/human/wa_probe/update_icons()
	return
/turf/wa_wall
	density = TRUE

var/wa_failures = 0
var/wa_runtime_error = FALSE
/proc/wa_check(condition, label)
	if (!condition)
		wa_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	wa_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		wa_checks()
	catch(var/exception/e)
		wa_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = wa_failures, "runtime_error" = wa_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/wa_weave(obj/item/canvas/woven/C)
	var/plain = ""
	for (var/y = 0, y < C.canvas_h, y++)
		for (var/x = 0, x < C.canvas_w, x++)
			plain += ((x + y) % 4 < 2) ? "1" : "2"
	C.palette = "[C.base_colour],#a8342c,#3e5a86"
	C.paint_data = painting_pack(plain)
	C.finished = TRUE
	C.title = "Test"
	C.refresh_small()

/proc/wa_checks()
	for (var/T in typesof(/obj/item/canvas/woven))
		var/obj/item/canvas/woven/C = new T(null)
		var/icon/W = icon(C.woven_icon)
		wa_check(("blank" in icon_states(C.woven_icon)) && ("edge" in icon_states(C.woven_icon)) && (C.icon_state in icon_states(C.icon)), "[C.format] has its sprites")
		wa_check(C.art_left + C.art_w <= W.Width() && C.art_top + C.art_h <= W.Height() && C.canvas_w == C.art_w && C.canvas_h == C.art_h, "[C.format] weaves at its shown size")

	var/mob/living/human/wa_probe/M = new(locate(1, 1, 1))
	new /obj/item/pigment/charcoal(M)
	var/obj/item/canvas/woven/C = new(M)
	var/list/allowed = painting_allowed_colours(M, C)
	wa_check(allowed.len == 1 && allowed[1] == C.base_colour, "carried pigments do not dye wool ([json_encode(allowed)])")
	var/obj/item/canvas/plain_canvas = new(M)
	wa_check(painting_allowed_colours(M, plain_canvas).len > 1, "they still paint a canvas")

	// A finished small rug is laid and counts.
	wa_weave(C)
	var/list/frame = C.framed_overlays()
	wa_check(frame.len == 2, "a woven rug shows its weave and its edge")
	fcopy(painting_build_icon(C.small, C.art_w, C.art_h, C.art_left, C.art_top, C.woven_icon, "blank"), "woven_rug_small.dmi")
	var/turf/floor = locate(3, 3, 1)
	M.loc = locate(2, 2, 1)
	wa_check(woven_lay_rug(M, C, floor) && C.loc != M, "a rug is laid on the floor")
	var/obj/structure/woven_rug/R = locate() in floor
	wa_check(R && R.held_canvas() == C && R.name == "\"Test\"" && R.icon == C.woven_icon, "the laid rug carries the weave")
	wa_check(mood_is_art(R), "a rug is art")
	wa_check(home_floor_covered(floor) && !home_floor_covered(locate(4, 3, 1)), "a small rug covers its own tile")
	wa_check(!woven_lay_rug(M, new /obj/item/canvas/woven(M), floor), "only one rug to a tile")

	// A large one covers four tiles.
	var/obj/item/canvas/woven/large/L = new(M)
	wa_weave(L)
	M.loc = locate(5, 5, 1)
	wa_check(woven_lay_rug(M, L, locate(5, 5, 1)), "a large rug is laid")
	wa_check(home_floor_covered(locate(6, 6, 1)) && home_floor_covered(locate(6, 5, 1)) && !home_floor_covered(locate(7, 5, 1)), "and covers two tiles by two")
	qdel(R)
	wa_check(C.loc == floor, "a rug taken up leaves its weave")

	// A wide tapestry hangs two tiles wide on a wall to the north.
	for (var/x = 1, x <= 8, x++)
		new /turf/wa_wall(locate(x, 8, 1))
	var/obj/item/canvas/woven/tapestry/wide/TW = new(M)
	wa_weave(TW)
	M.loc = locate(3, 7, 1)
	wa_check(painting_hang(M, TW, locate(3, 8, 1)), "a wide tapestry hangs on the wall")
	var/obj/structure/painting_frame/F = locate() in locate(3, 7, 1)
	wa_check(F && F.held_canvas() == TW && F.pixel_y == 32 && mood_is_art(F), "it hangs like a painting and is art")
	var/obj/item/canvas/woven/tapestry/T2 = new(M)
	wa_weave(T2)
	M.loc = locate(4, 7, 1)
	wa_check(!painting_hang(M, T2, locate(4, 8, 1)), "nothing hangs over the wide tapestry's second tile")
