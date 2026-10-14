#define TRUE 1
#define FALSE 0
#define USE_CUSTOM_ERROR_HANDLER
#define GLOBAL_DATUM_INIT(key, path, value)
#define GLOBAL_VAR_INIT(key, value)
#define LAZYLEN(value) length(value)
var/datum/test_globals/GLOB = new
var/datum/config
var/list/debug_messages = list()
var/list/dd_messages = list()
var/checks = 0
var/failures = 0
var/last_html = ""
/datum/test_globals
	var/datum/error_viewer/error_cache/error_cache
	var/total_runtimes = 0
	var/total_runtimes_skipped = 0
/datum/browser
/datum/browser/New(mob/user, id, title, width, height)
	return
/datum/browser/proc/set_content(html)
	last_html = html
/datum/browser/proc/add_head_content(html)
	return
/datum/browser/proc/open()
	return
/proc/to_chat(user, text)
	return
/proc/time_stamp()
	return "fixture"
/proc/rhtml_encode(text)
	return html_encode(text)
/proc/get_turf(atom/A)
	while (A && !isturf(A))
		A = A.loc
	return A
/proc/log_debug(text)
	debug_messages += text
/proc/log_to_dd(text)
	dd_messages += text
/proc/log_info_line(atom/A)
	return A ? "fixture atom" : null
/proc/check(ok, label)
	checks++
	if (!ok)
		failures++
		world.log << "FAIL [label]"
/proc/test_exception(line)
	var/exception/E = new("fixture runtime")
	E.file = "fixture.dm"
	E.line = line
	E.desc = "fixture\n  detail one\n  detail two"
	return E
/world
	maxx = 2
	maxy = 2
	maxz = 1
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/world/New()
	OpenPort("none")
	spawn(0)
		run_tests()
/proc/run_tests()
	check(!world.port && !world.OpenPort(12345), "fixture refuses listening ports")
	var/datum/error_viewer/error_cache/C = new
	GLOB.error_cache = C
	var/exception/E = test_exception(1)
	var/mob/actor = new(locate(1, 1, 1))
	usr = actor
	C.log_error(E, list("first detail"))
	usr = null
	var/datum/error_viewer/error_entry/held = C.errors[1]
	var/held_ref = "\ref[held]"
	check(held.usr_loc == actor.loc && held.usr_ref == "\ref[actor]", "production captures actual usr location")
	var/datum/error_viewer/error_source/S = held.error_source
	for (var/i = 2 to 250)
		C.log_error(E, list("detail [i]"), i % 2 ? 3 : 0)
	check(C.errors.len == ERROR_SOURCE_HISTORY_LIMIT && S.errors.len == ERROR_SOURCE_HISTORY_LIMIT, "per-source history bounded")
	check(held.retired && !held.error_source && !held.usr_loc && !held.usr_ref, "retired external holder releases source and usr location")
	check(!held.desc && !held.info && !held.info_name, "retired external holder releases detail text")
	check(!(held in C.errors) && !(held in S.errors), "retired external holder absent from both roots")
	check(C.errors[1] == S.errors[1] && C.errors[C.errors.len] == S.errors[S.errors.len], "source FIFO matches global history")
	var/datum/error_viewer/error_entry/second = C.errors[2]
	var/datum/error_viewer/error_entry/last = C.errors[C.errors.len]
	check(findtext(second.desc, "detail 152") && findtext(last.desc, "detail 250"), "source FIFO keeps newest details chronologically")
#ifndef HISTORICAL_ERROR_HISTORY
	check(S.total_logged == 126 && S.total_skipped == 372 && S.total_retired == 150, "source lifetime counters include retired skip summaries")
#endif
	held.show_to(null)
	check(findtext(last_html, "expired from the recent history") && findtext(last_html, "Refresh"), "expired holder shows safe refresh navigation")
	held = null
	sleep(1)
	check(!locate(held_ref), "retired unheld entry autocollects natively")
	// Distinct fixed source lines exercise the global cap independently.
	for (var/i = 2 to 16)
		E = test_exception(i)
		for (var/j = 1 to 100)
			C.log_error(E, list("source [i] detail [j]"))
	check(C.errors.len == ERROR_HISTORY_LIMIT, "global history bounded across sources")
	var/datum/error_viewer/error_entry/first = C.errors[1]
	check(first.error_source == C.error_sources["fixture.dm,7"], "global FIFO retains newest sources in order")
	var/memberships = 0
	var/backrefs = 0
	for (var/key in C.error_sources)
		var/datum/error_viewer/error_source/source = C.error_sources[key]
		memberships += source.errors.len
		for (var/datum/error_viewer/error_entry/entry in source.errors)
			if (entry.error_source == source && (entry in C.errors))
				backrefs++
	check(memberships == ERROR_HISTORY_LIMIT && backrefs == ERROR_HISTORY_LIMIT, "native memberships and source backrefs bounded and consistent")
	check(!S.errors.len, "old source metadata retains no retired entries")
	last = C.errors[C.errors.len]
	C.show_to(null, null, TRUE)
	check(findtext(last_html, "linear<hr>") && findtext(last_html, "Recent history:"), "linear viewer states recent history policy")
	check(findtext(last_html, first.make_link(null, C, TRUE)) < findtext(last_html, last.make_link(null, C, TRUE)), "linear viewer preserves entry ordering")
	S.show_to(null)
#ifndef HISTORICAL_ERROR_HISTORY
	check(findtext(last_html, "126 logged runtimes, 372 skipped; 0 recent entries, 250 retired"), "source viewer preserves totals after global retirement")
#endif
	// Notification cooldown belongs to source metadata, survives detail eviction.
	config = new
	S.next_message_at = world.time + ERROR_MSG_DELAY
	C.log_error(test_exception(1), list("cooldown"))
	check(!debug_messages.len, "retirement preserves notification cooldown")
	S.next_message_at = 0
	C.log_error(test_exception(1), list("notify"))
	C.log_error(test_exception(1), list("throttled"))
	C.log_error(test_exception(1), skip_count = 2)
	check(debug_messages.len == 1 && S.next_message_at > world.time, "notifications throttled and skip summaries silent")
	var/datum/error_viewer/error_entry/summary = C.errors[C.errors.len]
	check(summary.is_skip_count && !findtext(summary.make_link(), "<a "), "skip summary remains plain text")
	// Real production world/Error keeps total and skipped counts and disk logs.
	E = test_exception(99)
	for (var/i = 1 to 12)
		world.Error(E)
	sleep(4)
	check(GLOB.total_runtimes == 12 && GLOB.total_runtimes_skipped == 2, "world Error totals and silence cooldown preserved")
	var/datum/error_viewer/error_source/world_source = C.error_sources["fixture.dm,99"]
	check(world_source && world_source.errors.len == 11, "world Error appends skipped summary through production cache")
	check(dd_messages.len > 10 && findtext(dd_messages[dd_messages.len], "Skipped 2 runtimes"), "world Error disk log and skip notification preserved")
	text2file(json_encode(list("checks" = checks, "failures" = failures, "memberships" = memberships, "backrefs" = backrefs)), "result.json")
	shutdown()
