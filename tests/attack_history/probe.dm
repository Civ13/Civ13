#define TRUE 1
#define FALSE 0
var/attack_log
var/game_id = "synthetic-fixture"
var/datum/configuration/config = new
/datum/configuration
	var/log_attack = FALSE
var/checks = 0
var/failures = 0
var/list/failed_labels = list()
var/write_mode = "success"
var/write_calls = 0
var/warning_calls = 0
var/max_batch = 0
var/archive_before_cut = TRUE
var/list/archived_entries = list()
var/list/metrics = list()

/proc/time_stamp()
	return "synthetic-time"
/proc/history_probe_warning(message)
	warning_calls++
	world.log << message
/proc/history_probe_write(payload, logfile)
	write_calls++
	if (write_mode == "zero")
		return FALSE
	if (write_mode == "throw")
		throw new /exception("Synthetic archive failure")
	var/list/packet = json_decode(payload)
	var/list/rows = packet["entries"]
	var/mob/subject = locate(packet["subject_ref"])
	max_batch = max(max_batch, rows.len)
	archive_before_cut = archive_before_cut && subject && subject.attack_log.len >= rows.len
	if (subject && subject.attack_log.len >= rows.len)
		for (var/i = 1 to rows.len)
			archive_before_cut = archive_before_cut && subject.attack_log[i] == rows[i]
	var/result = text2file("\n[payload]", logfile)
	if (result)
		archived_entries += rows
	return result
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
/proc/combined_rows(mob/subject)
	var/list/combined = archived_entries.Copy()
	combined += subject.attack_log
	return combined
/proc/reset_archive()
	attack_history_archive_retry_at = 0
	attack_history_archive_warning_at = 0
	write_mode = "success"
	write_calls = 0
	warning_calls = 0
	max_batch = 0
	archive_before_cut = TRUE
	archived_entries = list()
	fdel("archived-history.jsonl")
	attack_log = file("archived-history.jsonl")
/proc/fill_history(mob/subject, count)
	for (var/i = 1 to count)
		subject.append_attack_log("synthetic row [i]")

/world
	maxx = 1
	maxy = 1
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
	reset_archive()
	var/mob/body = new
	var/mob/observer/ghost/ghost = new(body)
	var/list/shared = body.attack_log
	var/mob/other = new
	check(shared == ghost.attack_log && shared != other.attack_log, "ghost shares only its body's list")
	var/list/expected = list()
	for (var/i = 1 to 1100)
		var/entry = i % 11 ? "\[synthetic-time\] <font color='red'>row [i] \"quoted\"\nline</font>" : "duplicate row"
		expected += entry
		if (i % 2)
			body.append_attack_log(entry)
		else
			ghost.append_attack_log(entry)
	check(body.attack_log == shared && ghost.attack_log == shared, "retirement preserves body and ghost list identity")
	check(body.attack_log.len <= ATTACK_HISTORY_RECENT_LIMIT, "normal recent history bounded")
	check(same_rows(expected, combined_rows(body)), "archived plus recent rows preserve exact order text and duplicates")
	check(body.attack_log[body.attack_log.len] == expected[expected.len], "newest row survives retirement")
	check(!other.attack_log.len, "unrelated mob history remains empty")
	check(max_batch <= ATTACK_HISTORY_ARCHIVE_BATCH && max_batch > 0, "archive batches bounded to 64 rows")
	check(archive_before_cut, "archive sees old rows before in-place retirement")
	check(!config.log_attack && archived_entries.len > 0, "optional ordinary logger cannot disable archival")
	var/list/disk_rows = list()
	var/metadata_ok = TRUE
	for (var/line in splittext(file2text(attack_log), "\n"))
		if (!length(line))
			continue
		var/list/packet = json_decode(line)
		metadata_ok = metadata_ok && packet["category"] == "ARCHIVED_MOB_ATTACK_HISTORY" && packet["game_id"] == game_id && length(packet["subject_ref"])
		disk_rows += packet["entries"]
	check(same_rows(disk_rows, archived_entries) && metadata_ok, "actual private file round trip preserves rows and source metadata")

	reset_archive()
	body = new
	ghost = new(body)
	shared = body.attack_log
	fill_history(body, ATTACK_HISTORY_RECENT_LIMIT)
	expected = body.attack_log.Copy()
	write_mode = "zero"
	expected += "failed zero"
	body.append_attack_log("failed zero")
	check(same_rows(expected, body.attack_log) && body.attack_log == shared && ghost.attack_log == shared, "zero return retains the entire shared history")
	check(write_calls == 1 && warning_calls == 1 && !archived_entries.len, "archive failure emits one bounded warning")
	for (var/i = 1 to 60)
		expected += "during cooldown [i]"
		ghost.append_attack_log("during cooldown [i]")
	check(write_calls == 1 && warning_calls == 1 && same_rows(expected, body.attack_log), "cooldown retains new rows without repeated writes or warnings")
	attack_history_archive_retry_at = world.time - 1
	expected += "retry zero"
	body.append_attack_log("retry zero")
	check(write_calls == 2 && warning_calls == 1 && same_rows(expected, body.attack_log), "failed retry keeps rows and warning rate limit")
	write_mode = "throw"
	attack_history_archive_retry_at = world.time - 1
	expected += "failed throw"
	body.append_attack_log("failed throw")
	check(write_calls == 3 && same_rows(expected, body.attack_log), "thrown archive failure retains every row")
	attack_log = null
	attack_history_archive_retry_at = world.time - 1
	expected += "missing logfile"
	body.append_attack_log("missing logfile")
	check(write_calls == 3 && same_rows(expected, body.attack_log), "unavailable private logfile retains every row")
	attack_log = file("archived-history.jsonl")
	write_mode = "success"
	attack_history_archive_retry_at = world.time - 1
	expected += "recovered write"
	body.append_attack_log("recovered write")
	check(archived_entries.len == ATTACK_HISTORY_ARCHIVE_BATCH && same_rows(expected, combined_rows(body)), "recovered archive drains one batch without losing new or failed rows")
	check(body.attack_log == shared && ghost.attack_log == shared, "recovered archive retains shared identity")
	write_mode = "zero"
	attack_history_archive_retry_at = world.time - 1
	attack_history_archive_warning_at = world.time - 1
	body.append_attack_log("later failure")
	check(warning_calls == 2, "warning can recur only after cooldown")

	reset_archive()
	body = new
	expected = list()
	for (var/i = 1 to 5000)
		var/entry = "legacy synthetic [i]"
		body.attack_log += entry
		expected += entry
	check(body.attack_log.len == 5000 && !write_calls, "idle legacy backlog is retained until touched")
	var/appends = 0
	var/max_calls_per_append = 0
	while (body.attack_log.len > ATTACK_HISTORY_RECENT_LIMIT && appends < 100)
		appends++
		var/entry = "new legacy row [appends]"
		expected += entry
		var/calls_before = write_calls
		body.append_attack_log(entry)
		max_calls_per_append = max(max_calls_per_append, write_calls - calls_before)
	check(body.attack_log.len <= ATTACK_HISTORY_RECENT_LIMIT && appends == 64, "legacy backlog converges on later appends")
	check(max_calls_per_append == 1 && max_batch <= ATTACK_HISTORY_ARCHIVE_BATCH, "legacy catchup writes at most one 64-row batch per append")
	check(same_rows(expected, combined_rows(body)), "legacy catchup preserves all old and newly appended rows")
	metrics["legacy_appends_to_converge"] = appends

	reset_archive()
	body = new
	var/list/baseline = list()
	var/baseline_chars = 0
	for (var/i = 1 to 20000)
		var/entry = "benchmark synthetic [i]"
		baseline += entry
		baseline_chars += length(entry)
		body.append_attack_log(entry)
	var/recent_chars = 0
	for (var/entry in body.attack_log)
		recent_chars += length(entry)
	check(baseline.len == 20000 && body.attack_log.len <= ATTACK_HISTORY_RECENT_LIMIT, "matched workload bounds candidate history while baseline grows")
	check(same_rows(baseline, combined_rows(body)), "matched workload conserves all 20000 forensic rows")
	check(archive_before_cut && max_batch <= ATTACK_HISTORY_ARCHIVE_BATCH, "matched workload respects archive-before-cut and batch budget")
	metrics["appends"] = 20000
	metrics["baseline_history_rows"] = baseline.len
	metrics["candidate_history_rows"] = body.attack_log.len
	metrics["baseline_history_characters"] = baseline_chars
	metrics["candidate_history_characters"] = recent_chars
	metrics["archived_rows"] = archived_entries.len
	metrics["archive_writes"] = write_calls
	text2file(json_encode(list("checks" = checks, "failures" = failures, "failed_labels" = failed_labels, "metrics" = metrics)), "result.json")
	world.log << "COMPLETE attack history fixture"
	del(world)
