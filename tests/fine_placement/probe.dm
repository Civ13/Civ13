// Native probe: Nudge Object keeps an offset within 8 pixels of the object's
// own 32 pixel snap point and only works on loose things and furnishings.
// Run: python3 tests/ecology_spawning/run_linux.py . tests/fine_placement/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 5
	maxy = 5
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/structure/bed/chair/fp_chair/New()
	return
/obj/structure/sign/custom/fp_sign/New()
	return
/obj/structure/fp_wall
	density = TRUE
/obj/structure/fp_wall/New()
	return

var/fp_failures = 0
var/fp_runtime_error = FALSE
/proc/fp_check(condition, label)
	if (!condition)
		fp_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	fp_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		fp_checks()
	catch(var/exception/e)
		fp_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = fp_failures, "runtime_error" = fp_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/fp_checks()
	fp_check(nudge_base(0) == 0 && nudge_base(6) == 0 && nudge_base(-6) == 0, "a small offset snaps to the tile centre")
	fp_check(nudge_base(32) == 32 && nudge_base(28) == 32 && nudge_base(-30) == -32, "a wall picture keeps its step onto the wall")
	fp_check(nudge_offset(0, 2) == 2 && nudge_offset(6, 2) == 8 && nudge_offset(8, 2) == 8, "nudging stops 8 pixels from the centre")
	fp_check(nudge_offset(-8, -2) == -8 && nudge_offset(32, 2) == 34 && nudge_offset(40, 2) == 40, "and 8 pixels from a wall step")
	var/turf/T = locate(2, 2, 1)
	var/obj/structure/bed/chair/fp_chair/C = new(T)
	var/obj/structure/sign/custom/fp_sign/S = new(T)
	var/obj/structure/fp_wall/W = new(T)
	var/obj/item/I = new(T)
	fp_check(nudge_allowed(C) && nudge_allowed(S) && nudge_allowed(I), "furniture, signs and loose things can be nudged")
	fp_check(!nudge_allowed(W), "other structures cannot")
	I.loc = C
	fp_check(!nudge_allowed(I), "nor a thing that is not on the floor")
