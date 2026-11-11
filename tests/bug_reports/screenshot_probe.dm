// Native probe for bug report screenshots (code/modules/bug_reports/bug_report_screenshot.dm).
// By hand, with the pinned BYOND:
//   python3 tests/ecology_spawning/run_linux.py . tests/bug_reports/screenshot_probe.dm
// It draws a mob's view on a small grass map and checks the picture: its size, where a sprite
// lands, that an invisible sprite and turfs behind an opaque wall stay out, that the file is
// saved and the queue keeps and forgets it. The picture is left as evidence (shot.png).
/world
	hub = ""
	hub_password = ""
	maxx = 40
	maxy = 40
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/shot_probe/New()
	return
/mob/living/human/shot_probe/New()
	return
/mob/living/human/shot_probe/update_icons()
	return
/obj/shot_marker
	anchored = TRUE
	layer = 5
var/shot_failures = 0
var/shot_runtime_error = FALSE
/proc/shot_check(condition, label)
	if (!condition)
		shot_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	shot_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/shot_probe
		shot_checks()
	catch(var/exception/e)
		shot_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = shot_failures, "runtime_error" = shot_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/shot_square(colour)
	var/icon/I = icon('icons/effects/96x96.dmi', "")
	I.Scale(32, 32)
	I.DrawBox(colour, 1, 1, 32, 32)
	return I

/proc/shot_checks()
	for (var/turf/T in block(locate(1, 1, 1), locate(40, 40, 1)))
		T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
	var/mob/living/human/shot_probe/M = new(locate(20, 20, 1))
	M.see_invisible = SEE_INVISIBLE_LIVING
	// A red square two tiles east and one north of the viewer.
	var/obj/shot_marker/red = new(locate(22, 21, 1))
	red.icon = shot_square("#ff0000")
	// An invisible blue square must not be drawn.
	var/obj/shot_marker/blue = new(locate(18, 21, 1))
	blue.icon = shot_square("#0000ff")
	blue.invisibility = 101
	// An opaque column at x = 23 hides x = 24 and beyond on row 20.
	for (var/y in 14 to 26)
		var/turf/W = locate(23, y, 1)
		W.opacity = TRUE
	var/obj/shot_marker/hidden = new(locate(25, 20, 1))
	hidden.icon = shot_square("#00ff00")
	// Ordinary scenery, away from the checked tiles, so the evidence picture looks like play.
	for (var/list/place in list(list(/obj/structure/wild/tree/live_tree, 15, 24), list(/obj/structure/wild/tree/live_tree, 16, 15),
		list(/obj/structure/wild/bush, 21, 16), list(/obj/structure/wild/bush, 14, 19), list(/obj/structure/table/wood, 19, 23),
		list(/obj/structure/bed/chair/wood, 18, 23)))
		try
			var/path = place[1]
			new path(locate(place[2], place[3], 1))
		catch(var/exception/e)
			world.log << "scenery [place[1]] skipped: [e]"

	var/list/size = getviewsize(world.view)
	var/icon/shot = bug_report_render_view(M, null)
	shot_check(istype(shot, /icon), "a picture is drawn")
	if (!istype(shot, /icon))
		return
	fcopy(shot, "shot.png")
	shot_check(shot.Width() == size[1] * 32 && shot.Height() == size[2] * 32, "the picture is the view size ([shot.Width()]x[shot.Height()])")
	// The viewer's tile is the centre one; its bottom-left pixel in the picture:
	var/cx = (size[1] - 1) / 2 * 32
	var/cy = (size[2] - 1) / 2 * 32
	shot_check(shot.GetPixel(cx + 2 * 32 + 16, cy + 32 + 16) == "#ff0000", "the red square is two tiles east, one north ([shot.GetPixel(cx + 2 * 32 + 16, cy + 32 + 16)])")
	shot_check(shot.GetPixel(cx - 2 * 32 + 16, cy + 32 + 16) != "#0000ff", "the invisible square is left out")
	shot_check(shot.GetPixel(cx + 5 * 32 + 16, cy + 16) == "#000000", "a turf behind the wall stays black")
	shot_check(shot.GetPixel(cx + 16, cy - 2 * 32 + 16) != "#000000", "a visible floor tile is drawn")

	// The queue keeps the picture with the report and forgets it on reject.
	var/datum/bug_report/R = bug_reports.add_from("probe", "probe", "probe", M, null, "Title", "What", "", "", shot)
	shot_check(R.screenshot == "[R.id].png" && fexists("data/bug_reports/screens/[R.id].png"), "the picture is saved with the report")
	var/datum/bug_report/copy = new
	shot_check(copy.from_list(R.to_list()) && copy.screenshot == R.screenshot, "the picture survives a queue reload")
	bug_reports.reject(R, "admin", "")
	shot_check(!fexists("data/bug_reports/screens/[R.id].png"), "a rejected report's picture is deleted")
	var/datum/bug_report/none = bug_reports.add_from("probe2", "probe2", "probe2", M, null, "Title", "What", "", "", null)
	shot_check(isnull(none.screenshot), "a report without a picture has none")
