var/capture_hook_calls = 0
var/capture_projection_calls = 0
var/capture_runtime_calls = 0
/datum/capture_input
	var/paid_units = 17
	var/list/shared
	var/list/alias
	var/datum/capture_input/next
/datum/capture_input/get_saved_vars()
	return list("paid_units", "shared", "alias", "next")
/datum/capture_input/yielding/get_saved_vars()
	capture_projection_calls++
	sleep(0)
	return ..()
/datum/capture_input/mutating/get_saved_vars()
	capture_projection_calls++
	paid_units = 0
	return ..()
/datum/capture_input/mutating/persistence_runtime_var(key)
	capture_runtime_calls++
	paid_units = 0
	return FALSE
/datum/capture_input/mutating/unreviewed
/obj/structure/compost
	var/current = 23
/obj/structure/compost/before_save()
	capture_hook_calls++
	current = 0
/datum/immutable_world_capture/test_clock
	max_tick_usage = 100000
/datum/immutable_world_capture/test_clock/clock_now()
	return 100
/datum/immutable_world_capture/test_clock/expired/clock_now()
	return 100 + node_count * 10
/datum/immutable_world_capture/test_clock/cancelled/clock_now()
	if(node_count) active = FALSE
	return 100
/proc/check(condition, message)
	if(!condition) throw EXCEPTION(message)
/proc/new_capture_frame(path = /datum/immutable_world_capture/test_clock)
	var/datum/immutable_world_capture/frame = new path
	// Fixture projections cover only these exact input types. Whole idle-world
	// enumeration is not complete real-game projection/cohort acceptance.
	frame.projection_manifest = list("/datum/capture_input" = list("paid_units", "shared", "alias", "next"), "/datum/capture_input/mutating" = list("paid_units", "shared", "alias", "next"), "/datum/capture_input/yielding" = list("paid_units", "shared", "alias", "next"), "/turf" = list("name", "dir"), "/obj/map_metadata" = list("ID", "age", "ordinal_age", "persistence", "research_active", "resourceresearch", "perschadplus"), "/obj/structure/compost" = list("current"))
	return frame
/world
	maxx = 8
	maxy = 6
	maxz = 2
	visibility = 0
	sleep_offline = FALSE
/world/OpenPort(port)
	return ..("none")
/world/New()
	OpenPort("none")
	..()
	// Native startup tick_usage is not a normal processing-tick budget.
	// Yield before capture begins; captures and their guards remain synchronous.
	sleep(1)
	try
		var/datum/capture_input/A = new
		A.shared = list("paid" = 11)
		A.shared += list(A.shared)
		A.alias = A.shared
		A.next = A
		var/datum/immutable_world_capture/frame = new_capture_frame()
		var/capture_ok = frame.capture(list(A))
		if(!capture_ok) world.log << "Capture rejection detail: [frame.error]"
		check(capture_ok, "detached graph capture failed")
		var/text = frame.captured_text
		A.paid_units = 99
		A.shared["paid"] = 77
		var/list/payload = json_decode(frame.captured_text)
		var/list/node = payload["nodes"][1]
		check(node["fields"]["paid_units"]["value"] == 17, "immutable capture read later live progress")
		check(node["fields"]["next"]["id"] == 1, "datum cycle identity lost")
		check(node["fields"]["shared"]["id"] == node["fields"]["alias"]["id"], "list alias identity lost")
		var/list/list_node = payload["nodes"][node["fields"]["shared"]["id"]]
		check(list_node["rows"][1]["value"]["value"] == 11, "immutable capture read later nested list")
		check(list_node["rows"][2]["key"]["id"] == list_node["id"], "list cycle identity lost")
		check(frame.captured_text == text && isnull(frame.nodes) && isnull(frame.pins) && isnull(frame.identities), "capture retained source graph")
		// Caller may write the detached string after live state has changed.
		check(text2file(text, "detached.json"), "detached fixture write failed")
		check(json_decode(file2text("detached.json"))["nodes"][1]["fields"]["paid_units"]["value"] == 17, "detached async-writer input changed")
		map = new /obj/map_metadata(locate(1,1,1))
		var/datum/immutable_world_capture/world_frame = new_capture_frame()
		check(world_frame.capture_world(), "whole idle world capture failed")
		var/list/world_payload = json_decode(world_frame.captured_text)
		check(world_payload["roots"].len == world.maxx * world.maxy * world.maxz + 1, "whole world root coverage lost")
		check(world_payload["world_dimensions"][3] == 2, "whole world dimensions lost")
		text2file("prior completed generation", "prior-generation.txt")
		var/prior_generation = file2text("prior-generation.txt")
		var/obj/structure/compost/paid = new(locate(1,1,1))
		check(!frame.capture(list(paid)) && isnull(frame.captured_text), "mutating paid hook admitted")
		check(paid.current == 23 && !capture_hook_calls, "rejected capture changed paid state")
		for(var/bound in list("max_nodes", "max_edges", "max_reserved_bytes", "max_variables", "max_depth"))
			frame = new_capture_frame()
			frame.vars[bound] = 0
			check(!frame.capture(list(A)) && isnull(frame.captured_text), "capture bound did not reject: [bound]")
			check(A.paid_units == 99 && A.shared["paid"] == 77, "budget rejection mutated input")
		frame = new_capture_frame(/datum/immutable_world_capture/test_clock/expired)
		check(!frame.capture(list(A)) && isnull(frame.captured_text), "elapsed capture budget admitted")
		frame = new_capture_frame(/datum/immutable_world_capture/test_clock/cancelled)
		check(!frame.capture(list(A)) && isnull(frame.captured_text), "cancelled capture admitted")
		var/datum/capture_input/mutating/mutating = new
		frame = new_capture_frame()
		check(frame.capture(list(mutating)), "pure field projection failed")
		check(!capture_runtime_calls, "capture invoked runtime exclusion callback")
		check(!capture_projection_calls && mutating.paid_units == 17, "capture invoked mutating projection")
		var/datum/capture_input/yielding/yielding = new
		frame = new_capture_frame()
		check(frame.capture(list(yielding)), "callback-free admission rejected")
		check(!capture_projection_calls, "capture invoked same-tick projection callback")
		var/datum/capture_input/mutating/unreviewed/unreviewed = new
		frame = new_capture_frame()
		check(!frame.capture(list(unreviewed)), "unreviewed projection admitted")
		check(!capture_projection_calls && unreviewed.paid_units == 17, "unreviewed projection changed paid state")
		check(file2text("prior-generation.txt") == prior_generation, "failed capture changed prior generation")
		text2file("PASS", "result.txt")
	catch(var/exception/E)
		text2file("FAIL: [E.name]", "result.txt")
	del(world)
