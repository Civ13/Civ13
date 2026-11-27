// Isolated end-to-end Examine delivery through the real human renderer.
// python3 tests/ecology_spawning/run_linux.py . tests/tgui/flavor_preview_probe.dm 180
/world
	hub = ""
	hub_password = ""
	maxx = 5
	maxy = 5
	maxz = 1
	visibility = 0

/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

/mob/living/human/flavor_preview_fixture/New()
	// Only initialize dependencies examined by the real proc, not live mob startup.
	gender = MALE
	species = new /datum/species/human
	species.has_limbs = list()
	icon = 'icons/mob/animal.dmi'
	icon_state = "cow"

/obj/map_metadata/flavor_preview_fixture/New()
	map = src

/mob/agent_proxy/flavor_preview_fixture/New()
	return

/mob/agent_proxy/flavor_preview_fixture/capture(message)
	agent_output += message

/obj/item/clothing/head/flavor_preview_fixture
	body_parts_covered = FACE
	icon = 'icons/mob/animal.dmi'
	icon_state = "cow"

/proc/flavor_preview_check(condition, label)
	if (!condition)
		throw EXCEPTION(label)
	world.log << "PASS: [label]"

/proc/flavor_preview_examine(mob/living/human/subject, mob/agent_proxy/viewer, text)
	viewer.agent_output.Cut()
	subject.flavor_text = html_encode(text)
	usr = viewer
	subject.examine(viewer)
	usr = null
	return jointext(viewer.agent_output, "\n")

var/flavor_preview_runtime_error = FALSE
/world/Error(exception/e)
	flavor_preview_runtime_error = TRUE
	world.log << "runtime error: [e] [e.file]:[e.line]"

/world/New()
	OpenPort("none")
	var/failures = 0
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		var/obj/map_metadata/flavor_preview_fixture/setup = new(null)
		gender_datums[MALE] = new /datum/gender/male
		var/mob/living/human/flavor_preview_fixture/H = new(locate(3, 3, 1))
		var/mob/agent_proxy/P = new /mob/agent_proxy/flavor_preview_fixture
		var/short = "Soot & ash. Has a scar & a stiff limp."
		var/msg = flavor_preview_examine(H, P, short)
		flavor_preview_check(findtext(msg, html_encode(short)) && !findtext(msg, "flavor_more=1"), "short ampersand description is complete in Examine")
		var/unicode = ""
		for (var/i in 1 to 40)
			unicode += "é"
		msg = flavor_preview_examine(H, P, unicode)
		flavor_preview_check(findtext(msg, unicode) && !findtext(msg, "flavor_more=1"), "40 multibyte characters fit without a reader link")
		msg = flavor_preview_examine(H, P, "[unicode]&")
		flavor_preview_check(findtext(msg, "[copytext_char(unicode, 1, 37)]...") && findtext(msg, "flavor_more=1"), "41 characters use a complete 36-character excerpt and More link")
		var/literal = "<b>Not markup</b> & &lt;"
		msg = flavor_preview_examine(H, P, literal)
		flavor_preview_check(findtext(msg, html_encode(literal)) && !findtext(msg, "<b>Not markup</b>"), "markup and entity-looking input remain escaped")
		H.head = new /obj/item/clothing/head/flavor_preview_fixture(H)
		msg = flavor_preview_examine(H, P, short)
		flavor_preview_check(!findtext(msg, html_encode(short)) && !findtext(msg, "flavor_more=1"), "Examine still hides flavor when the face is covered")
		qdel(setup)
	catch(var/exception/e)
		failures++
		world.log << "FAIL: [e] [e.file]:[e.line]"
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = failures, "runtime_error" = flavor_preview_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
