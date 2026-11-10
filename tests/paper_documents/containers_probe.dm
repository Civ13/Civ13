// Native container probe: python3 tests/ecology_spawning/run_linux.py . tests/paper_documents/containers_probe.dm
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
var/containers_probe_failures = 0
var/containers_probe_runtime = FALSE
/proc/containers_probe_check(condition, label)
	if (!condition)
		containers_probe_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	containers_probe_runtime = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		containers_probe_checks()
	catch(var/exception/e)
		containers_probe_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("failures" = containers_probe_failures, "runtime_error" = containers_probe_runtime, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/containers_probe_checks()
	var/turf/T = locate(2, 2, 1)
	var/obj/item/weapon/paper/A = new(T)
	var/obj/item/weapon/paper/B = new(T)
	var/obj/item/weapon/storage/envelope/E = new(T)
	containers_probe_check(paper_document_envelope_open(E), "a new envelope starts open")
	E.opened = FALSE
	containers_probe_check(!paper_document_envelope_open(E), "a closed envelope refuses")
	containers_probe_check(!paper_document_envelope_open(A), "a paper is not an envelope")
	var/obj/item/weapon/paper_bundle/bundle = new(T)
	A.loc = bundle
	B.loc = bundle
	bundle.pages = list(A, B)
	bundle.page = 1
	containers_probe_check(paper_document_bundle_page(bundle, A), "open page of a bundle")
	containers_probe_check(!paper_document_bundle_page(bundle, B), "other bundle page refuses")
	bundle.page = 2
	containers_probe_check(paper_document_bundle_page(bundle, B), "turning the page moves access")
	bundle.page = 5
	containers_probe_check(!paper_document_bundle_page(bundle, B), "out of range page refuses")
	var/obj/item/weapon/folder/F = new(T)
	containers_probe_check(paper_document_held_folder(F) && !paper_document_held_folder(bundle), "folder check")
	E.sealed = TRUE
	E.wax_colour = "red"
	E.overlays.Cut()
	E.after_load()
	containers_probe_check(E.overlays.len == 1, "wax seal redrawn after load ([E.overlays.len])")
	var/obj/item/weapon/storage/envelope/E2 = new(T)
	E2.sealed = TRUE
	E2.wax_colour = "<script>"
	E2.after_load()
	containers_probe_check(E2.overlays.len == 0, "unknown wax colour ignored")
	var/obj/structure/filingcabinet/C = new(T)
	var/obj/item/weapon/paper/Z = new(C)
	Z.name = "Zeta"
	var/obj/item/weapon/paper/Y = new(C)
	Y.name = "Alpha"
	var/list/sorted = sortAtom(C.contents.Copy())
	containers_probe_check(sorted.len == 2 && sorted[1] == Y, "cabinet index sorted by name")
