// Native stamp probe: python3 tests/ecology_spawning/run_linux.py . tests/paper_documents/stamp_probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 10
	maxy = 10
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
var/stamp_probe_failures = 0
var/stamp_probe_runtime = FALSE
/proc/stamp_probe_check(condition, label)
	if (!condition)
		stamp_probe_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	stamp_probe_runtime = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		stamp_probe_icons()
		stamp_probe_overlays()
	catch(var/exception/e)
		stamp_probe_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("failures" = stamp_probe_failures, "runtime_error" = stamp_probe_runtime, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

// Every stamp a player can hold has a reader image and a sheet impression.
/proc/stamp_probe_icons()
	for (var/path in typesof(/obj/item/weapon/stamp))
		var/obj/item/weapon/stamp/S = new path
		var/state = S.icon_state
		stamp_probe_check(!!paper_stamp_reader_icon(state), "reader image for [path] ([state])")
		stamp_probe_check(!!paper_stamp_sheet_state(state), "sheet impression for [path] ([state])")
		var/marker = paper_stamp_marker(S)
		stamp_probe_check(findtext(marker, "paperstamp_[state].png") && !findtext(marker, "\["), "marker for [path] holds no ref")
		qdel(S)

/proc/stamp_probe_overlays()
	var/turf/T = locate(2, 2, 1)
	var/obj/item/weapon/paper/P = new(T)
	P.stamped = list("stamp-approved", /obj/item/weapon/stamp, "seal-court", "not-a-stamp")
	paper_stamp_refresh_overlays(P)
	stamp_probe_check(P.overlays.len == 2, "two drawable impressions become overlays ([P.overlays.len])")
	paper_stamp_refresh_overlays(P)
	stamp_probe_check(P.overlays.len == 2, "refreshing does not duplicate overlays ([P.overlays.len])")
	var/first_x = 0
	for (var/image/I in P.stamp_overlay_images)
		first_x = I.pixel_x
		break
	paper_stamp_refresh_overlays(P)
	var/again_x = 0
	for (var/image/I in P.stamp_overlay_images)
		again_x = I.pixel_x
		break
	stamp_probe_check(first_x == again_x, "impression offsets are stable")
	P.stamped = list()
	paper_stamp_refresh_overlays(P)
	stamp_probe_check(P.overlays.len == 0, "clearing stamps clears overlays")
	stamp_probe_check(P.persistence_runtime_var("stamp_overlay_images"), "overlay images are runtime-only")
	stamp_probe_check(paper_stamp_join(null, "x") == "<BR>x" && paper_stamp_join("", "x") == "<BR>x", "first impression starts a new line")
	stamp_probe_check(paper_stamp_join("<BR>a", "x") == "<BR>ax", "later impressions follow on the same line")
	var/list/source = list("stamp-deny")
	var/list/next = paper_stamp_list_with(source, "seal-court")
	stamp_probe_check(source.len == 1 && next.len == 2 && next[2] == "seal-court", "stamp list is copied, not changed in place")
