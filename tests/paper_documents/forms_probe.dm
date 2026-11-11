// Native form-field probe: python3 tests/ecology_spawning/run_linux.py . tests/paper_documents/forms_probe.dm
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
var/forms_probe_failures = 0
var/forms_probe_runtime = FALSE
/proc/forms_probe_check(condition, label)
	if (!condition)
		forms_probe_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	forms_probe_runtime = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		forms_probe_record_checks()
	catch(var/exception/e)
		forms_probe_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("failures" = forms_probe_failures, "runtime_error" = forms_probe_runtime, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/forms_probe_section(id, kind, text, target = null)
	var/list/section = list("id" = id, "lineage" = md5(id), "version" = 1, "kind" = kind, "language_id" = "civ13:english:v1", "text" = text, "ink" = "black", "tool" = "pen")
	if (kind == "field_answer")
		section["target"] = target
	return section

/proc/forms_probe_record(list/sections)
	return list("schema_version" = 1, "revision" = 1, "document_id" = md5("doc"), "legacy_policy" = "legacy_unclassified", "legacy" = list("name" = "paper", "info" = null, "stamps" = null, "fields" = 0, "free_space" = 3000, "stamped" = list(), "ico" = list(), "offset_x" = list(), "offset_y" = list()), "sections" = sections, "next_section" = sections.len + 1)

/proc/forms_probe_record_checks()
	// Startup fills the language registry; the probe world skips startup.
	for (var/T in typesof(/datum/language) - /datum/language)
		var/datum/language/L = new T
		all_languages[L.name] = L
	var/list/good = forms_probe_record(list(forms_probe_section("section-1", "field_label", "Name"), forms_probe_section("section-2", "field_label", "Rank"), forms_probe_section("section-3", "field_answer", "Ada", "section-1")))
	for (var/list/S in good["sections"])
		forms_probe_check(paper_document_section_valid(S), "section [S["id"]] valid")
	forms_probe_check(paper_written_language("civ13:english:v1"), "english registered")
	forms_probe_check(paper_document_record_valid(forms_probe_record(list(forms_probe_section("section-1", "body", "x")))), "plain record valid")
	forms_probe_check(paper_document_record_valid(good), "label with an answer is valid")
	forms_probe_check(!paper_document_field_open(good, "section-1"), "answered blank is closed")
	forms_probe_check(paper_document_field_open(good, "section-2"), "unanswered blank is open")
	forms_probe_check(!paper_document_field_open(good, "section-3"), "an answer is not a blank")
	var/list/twice = forms_probe_record(list(forms_probe_section("section-1", "field_label", "Name"), forms_probe_section("section-2", "field_answer", "A", "section-1"), forms_probe_section("section-3", "field_answer", "B", "section-1")))
	forms_probe_check(!paper_document_record_valid(twice), "a blank cannot be answered twice")
	var/list/dangling = forms_probe_record(list(forms_probe_section("section-1", "field_answer", "A", "section-9")))
	forms_probe_check(!paper_document_record_valid(dangling), "answer needs an existing blank")
	var/list/no_target = forms_probe_record(list(forms_probe_section("section-1", "field_label", "Name"), list("id" = "section-2", "lineage" = md5("x"), "version" = 1, "kind" = "field_answer", "language_id" = "civ13:english:v1", "text" = "A", "ink" = "black", "tool" = "pen")))
	forms_probe_check(!paper_document_record_valid(no_target), "answer without a target is invalid")
	var/obj/item/weapon/paper/P = new(locate(2, 2, 1))
	var/list/view = list("legacy_body_html" = "", "sections" = list(list("id" = "section-1", "kind" = "field_label", "language_id" = "civ13:english:v1", "text" = "Name", "ink" = "black", "tool" = "pen"), list("id" = "section-2", "kind" = "field_label", "language_id" = "civ13:english:v1", "text" = "Rank", "ink" = "black", "tool" = "pen"), list("id" = "section-3", "kind" = "field_answer", "language_id" = "civ13:english:v1", "text" = "Ada", "ink" = "blue", "tool" = "pen", "target" = "section-1")))
	var/html = paper_document_view_body(view, P)
	world.log << html
	forms_probe_check(findtext(html, "Name</font>: <u><font face=\"Verdana\" color=\"blue\">Ada</font></u>"), "answer drawn on its blank line")
	forms_probe_check(findtext(html, "Rank</font>: <u>&nbsp;"), "empty blank drawn as a line")
