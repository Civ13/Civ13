var/diary
var/game_id = "synthetic-fixture"
var/list/admin_log = list()
var/datum/configuration/config = new
/datum/configuration
	var/log_admin = FALSE
var/checks = 0
var/failures = 0
var/list/failed_labels = list()
var/write_mode = "success"
var/write_calls = 0
var/warning_calls = 0
var/ordinary_calls = 0
var/max_batch = 0
var/archive_before_cut = TRUE
var/list/archived_entries = list()
var/list/metrics = list()
var/shown_html
var/show_calls = 0
var/view_allowed = TRUE

/proc/time_stamp()
	return "synthetic-time"
/proc/game_log(category, text)
	ordinary_calls++
	diary << "ordinary [category]: [text]"
/proc/history_probe_warning()
	warning_calls++
/proc/history_probe_write(payload, logfile)
	write_calls++
	if (write_mode == "zero")
		return FALSE
	if (write_mode == "throw")
		throw new /exception("Synthetic archive failure")
	var/list/packet = json_decode(payload)
	var/list/rows = packet["entries"]
	max_batch = max(max_batch, rows.len)
	archive_before_cut = archive_before_cut && admin_log.len >= rows.len
	for (var/i = 1 to rows.len)
		archive_before_cut = archive_before_cut && admin_log[i] == rows[i]
	var/result = text2file("\n[payload]", logfile)
	if (result)
		archived_entries += rows
	return result
/datum/admin_secret_item
	var/name
/datum/admin_secret_item/admin_secret/proc/execute(mob/user)
	return view_allowed
/proc/history_probe_show(mob/user, html)
	show_calls++
	shown_html = html
/proc/check(ok, label)
	checks++
	if (!ok)
		failures++
		failed_labels += label
		world.log << "FAIL [label]"
/proc/same_rows(list/first, list/second)
	if (first.len != second.len)
		return FALSE
	for (var/i = 1 to first.len)
		if (first[i] != second[i])
			return FALSE
	return TRUE
/proc/combined_rows()
	var/list/combined = archived_entries.Copy()
	combined += admin_log
	return combined
/proc/reset_history()
	admin_log = list()
	admin_history_archive_retry_at = 0
	admin_history_archive_warning_at = 0
	config.log_admin = FALSE
	write_mode = "success"
	write_calls = 0
	warning_calls = 0
	ordinary_calls = 0
	max_batch = 0
	archive_before_cut = TRUE
	archived_entries = list()
	fdel("archived-history.jsonl")
	diary = file("archived-history.jsonl")

world
	maxx = 1
	maxy = 1
	maxz = 1
	view = 1
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
world/New()
	OpenPort("none")
	spawn(0)
		run_tests()
/proc/run_tests()
	check(!world.port && !world.OpenPort(12345), "fixture refuses listening ports")
	reset_history()
	var/datum/admin_secret_item/admin_secret/admin_logs/viewer = new
	viewer.execute(null)
	check(findtext(shown_html, "No-one has done anything this round!") && findtext(shown_html, "private server log"), "empty production view explains archival")
	view_allowed = FALSE
	var/prior_shows = show_calls
	viewer.execute(null)
	check(show_calls == prior_shows, "production view preserves parent permission rejection")
	view_allowed = TRUE

	var/list/expected = list()
	var/list/shared = admin_log
	for (var/i = 1 to ADMIN_HISTORY_RECENT_LIMIT)
		var/entry = i <= 2 ? "duplicate <b>synthetic</b>\nsecond line" : "synthetic [i]"
		expected += entry
		log_admin(entry)
	check(!write_calls && admin_log.len == ADMIN_HISTORY_RECENT_LIMIT, "limit entries remain in memory without archival")
	expected += "overflow"
	log_admin("overflow")
	check(admin_log.len == ADMIN_HISTORY_RECENT_LIMIT + 1 - ADMIN_HISTORY_ARCHIVE_BATCH, "overflow retires one batch")
	check(admin_log == shared, "retirement preserves the original list")
	check(same_rows(expected, combined_rows()), "exact original row order duplicates and newlines are conserved")
	check(archive_before_cut && write_calls == 1 && max_batch == ADMIN_HISTORY_ARCHIVE_BATCH, "archive occurs before cutting a bounded batch")
	check(!ordinary_calls, "optional ordinary logging remains disabled")
	var/list/packet = json_decode(file2text(diary))
	check(packet["category"] == "ARCHIVED_ADMIN_HISTORY" && packet["game_id"] == game_id && same_rows(packet["entries"], expected.Copy(1, 65)), "real temporary file round trip preserves exact archived entries")
	viewer.execute(null)
	var/expected_html = ""
	for (var/entry in admin_log)
		expected_html += "<li>[entry]</li>"
	check(findtext(shown_html, expected_html) && !findtext(shown_html, "duplicate <b>synthetic</b>"), "production view renders all recent rows in order")
	config.log_admin = TRUE
	for (var/i = 1 to 64)
		log_admin("ordinary row [i]")
	check(ordinary_calls == 64 && write_calls == 2, "ordinary enabled logging and archival share the private diary")
	check(findtext(file2text(diary), "ordinary ADMIN: ordinary row 1") && findtext(file2text(diary), "ARCHIVED_ADMIN_HISTORY"), "ordinary and archive records both reach native storage")

	reset_history()
	expected = list()
	shared = admin_log
	for (var/i = 1 to ADMIN_HISTORY_RECENT_LIMIT)
		var/entry = "failure seed [i]"
		expected += entry
		log_admin(entry)
	write_mode = "zero"
	expected += "zero write"
	log_admin("zero write")
	check(same_rows(expected, admin_log) && admin_log == shared, "zero write retains every row")
	for (var/i = 1 to 10)
		var/entry = "cooldown row [i]"
		expected += entry
		log_admin(entry)
	check(write_calls == 1 && warning_calls == 1 && same_rows(expected, admin_log), "failed storage bounds retries and warnings without losing new rows")
	write_mode = "throw"
	admin_history_archive_retry_at = world.time - 1
	expected += "throw write"
	log_admin("throw write")
	check(same_rows(expected, admin_log) && write_calls == 2 && warning_calls == 1, "thrown write retains every row and warning cooldown")
	diary = null
	admin_history_archive_retry_at = world.time - 1
	expected += "missing file"
	log_admin("missing file")
	check(same_rows(expected, admin_log) && write_calls == 2, "missing logfile retains every row without a write")
	diary = file("archived-history.jsonl")
	write_mode = "success"
	admin_history_archive_retry_at = world.time - 1
	expected += "recovered"
	log_admin("recovered")
	check(same_rows(expected, combined_rows()) && admin_log == shared, "recovered storage retains failed rows and list identity")
	check(archived_entries.len == 64, "recovered storage drains just one batch")
	while (admin_log.len < ADMIN_HISTORY_RECENT_LIMIT)
		log_admin("cooldown filler [admin_log.len]")
	write_mode = "zero"
	admin_history_archive_retry_at = world.time - 1
	admin_history_archive_warning_at = world.time - 1
	log_admin("later failure")
	check(warning_calls == 2, "warning can recur after cooldown")

	reset_history()
	expected = list()
	for (var/i = 1 to 5000)
		var/entry = "backlog [i]"
		admin_log += entry
		expected += entry
	check(admin_log.len == 5000 && !write_calls, "idle backlog is retained without background work")
	var/appends = 0
	var/max_calls_per_append = 0
	while (admin_log.len > ADMIN_HISTORY_RECENT_LIMIT && appends < 100)
		appends++
		var/entry = "new backlog [appends]"
		expected += entry
		var/prior_calls = write_calls
		log_admin(entry)
		max_calls_per_append = max(max_calls_per_append, write_calls - prior_calls)
	check(appends == 64 && admin_log.len <= ADMIN_HISTORY_RECENT_LIMIT, "backlog converges gradually on later appends")
	check(max_calls_per_append == 1 && max_batch <= ADMIN_HISTORY_ARCHIVE_BATCH, "backlog recovery uses one bounded batch per append")
	check(same_rows(expected, combined_rows()), "backlog recovery conserves all old and newly appended rows")

	reset_history()
	var/list/baseline = list()
	var/baseline_chars = 0
	for (var/i = 1 to 20000)
		var/entry = "benchmark synthetic [i]"
		baseline += entry
		baseline_chars += length(entry)
		log_admin(entry)
	var/recent_chars = 0
	for (var/entry in admin_log)
		recent_chars += length(entry)
	check(baseline.len == 20000 && admin_log.len <= ADMIN_HISTORY_RECENT_LIMIT, "matched workload bounds the candidate while baseline grows")
	check(same_rows(baseline, combined_rows()), "matched workload conserves all 20000 audit rows")
	check(archive_before_cut && max_batch <= 64, "matched workload respects archive-before-cut and batch budget")
	metrics = list("appends" = 20000, "baseline_history_rows" = baseline.len, "candidate_history_rows" = admin_log.len, "baseline_history_characters" = baseline_chars, "candidate_history_characters" = recent_chars, "archived_rows" = archived_entries.len, "archive_writes" = write_calls)
	text2file(json_encode(list("checks" = checks, "failures" = failures, "failed_labels" = failed_labels, "metrics" = metrics)), "result.json")
	world.log << "COMPLETE admin history fixture"
	del(world)
