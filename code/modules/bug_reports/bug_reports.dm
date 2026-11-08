// In-game bug reports (idea from CM-SS13, reimplemented for Civ13).
// A player files a report with Help > Report bug. It waits in a queue until an admin
// approves or rejects it in Admin > Bug Reports. An approved report becomes a GitHub
// issue through the API when the server has BUG_REPORT_GITHUB_TOKEN set; without a
// token the admin gets a prefilled new-issue page to submit with their own account.
// The queue survives restarts in data/bug_reports/queue.json.
//
// The token is never kept in a variable: it is read from config/config.txt only while an
// issue is being filed, so View Variables and saves never see it.

#define BUG_REPORT_COOLDOWN 3000 // deciseconds between one player's reports
#define BUG_REPORT_PENDING_MAX 50 // waiting reports in all
#define BUG_REPORT_PER_PLAYER 3 // waiting reports per player
#define BUG_REPORT_REQUEST_TICKS 300 // ticks a GitHub request may take
#define BUG_REPORT_QUEUE_FILE "data/bug_reports/queue.json"

var/global/datum/bug_report_queue/bug_reports = new

/datum/bug_report
	var/id
	var/ckey
	var/title
	var/what
	var/steps
	var/expected
	var/list/context = list() // ordered label -> value
	var/filed_at // UTC text
	var/state = "pending" // pending, filing, failed
	var/last_error

/datum/bug_report/proc/to_list()
	return list("id" = id, "ckey" = ckey, "title" = title, "what" = what, "steps" = steps, "expected" = expected,
		"context" = context, "filed_at" = filed_at, "state" = state == "filing" ? "pending" : state, "last_error" = last_error)

/datum/bug_report/proc/from_list(list/L)
	if (!islist(L) || !isnum(L["id"]) || !istext(L["ckey"]) || !istext(L["title"]))
		return FALSE
	id = L["id"]
	ckey = ckey(L["ckey"])
	title = bug_report_clean(L["title"], BUG_REPORT_TITLE_MAX, FALSE)
	what = bug_report_clean(L["what"])
	steps = bug_report_clean(L["steps"])
	expected = bug_report_clean(L["expected"])
	context = islist(L["context"]) ? L["context"] : list()
	filed_at = istext(L["filed_at"]) ? L["filed_at"] : ""
	state = L["state"] == "failed" ? "failed" : "pending"
	last_error = istext(L["last_error"]) ? L["last_error"] : null
	return TRUE

/datum/bug_report_queue
	var/list/reports = list() // id (text) -> /datum/bug_report, oldest first
	var/next_id = 1
	var/list/last_report_at = list() // ckey -> world.time
	var/loaded = FALSE
	var/filed = 0
	var/rejected = 0

/datum/bug_report_queue/proc/ensure_loaded()
	if (loaded)
		return
	loaded = TRUE
	if (!fexists(BUG_REPORT_QUEUE_FILE))
		return
	try
		var/list/saved = json_decode(file2text(BUG_REPORT_QUEUE_FILE))
		if (isnum(saved["next_id"]))
			next_id = max(1, round(saved["next_id"]))
		for (var/list/L in saved["reports"])
			var/datum/bug_report/R = new
			if (!R.from_list(L) || reports["[R.id]"])
				continue
			reports["[R.id]"] = R
			next_id = max(next_id, R.id + 1)
	catch(var/exception/e)
		log_admin("Bug reports: [BUG_REPORT_QUEUE_FILE] could not be read ([e]); starting an empty queue.")

/datum/bug_report_queue/proc/save()
	var/list/out = list()
	for (var/id in reports)
		var/datum/bug_report/R = reports[id]
		out += list(R.to_list())
	if (fexists(BUG_REPORT_QUEUE_FILE))
		fdel(BUG_REPORT_QUEUE_FILE)
	text2file(json_encode(list("next_id" = next_id, "reports" = out)), BUG_REPORT_QUEUE_FILE)

/datum/bug_report_queue/proc/pending_for(ckey)
	. = 0
	for (var/id in reports)
		var/datum/bug_report/R = reports[id]
		if (R.ckey == ckey)
			.++

// Why this player cannot file a report now, or null.
/datum/bug_report_queue/proc/refusal(client/C)
	ensure_loaded()
	if (!C)
		return "No client."
	if (C.prefs && (C.prefs.muted & MUTE_ADMINHELP))
		return "You cannot send bug reports while muted from adminhelp."
	if (reports.len >= BUG_REPORT_PENDING_MAX)
		return "The bug report queue is full. Please try again later, or report it on the Discord."
	if (pending_for(C.ckey) >= BUG_REPORT_PER_PLAYER)
		return "You already have [BUG_REPORT_PER_PLAYER] reports waiting for an admin."
	var/last = last_report_at[C.ckey]
	if (isnum(last) && world.time < last + BUG_REPORT_COOLDOWN)
		return "Please wait [round((last + BUG_REPORT_COOLDOWN - world.time) / 10)] seconds before sending another report."
	return null

// Round details that help reproduce a bug. No IP, computer ID or other private data.
/datum/bug_report_queue/proc/context_for(client/C)
	var/list/L = list()
	L["Server"] = config && config.server_name ? config.server_name : world.name
	if (shard_group && shard_group.enabled)
		L["Region"] = shard_group.name ? "[shard_group.name] ([shard_group.region])" : shard_group.region
	if (map)
		L["Map"] = map.title ? map.title : map.ID
	if (game_id)
		L["Round"] = game_id
	var/revision = nomads_lifecycle ? nomads_lifecycle.read_revision() : null
	if (istext(revision) && length(revision) == 40)
		L["Revision"] = revision
	L["BYOND"] = "server [world.byond_version].[world.byond_build], client [C.byond_version].[C.byond_build]"
	var/mob/M = C.mob
	var/turf/T = M ? get_turf(M) : null
	if (T)
		var/area/A = get_area(T)
		L["Location"] = "[A ? A.name : "unknown area"] ([T.x], [T.y], [T.z])"
	if (M)
		L["Character"] = "[M.type][M.stat == DEAD ? ", dead" : ""]"
	L["Round time"] = "[round(world.time / 600)] minutes"
	L["Reported at"] = "[time2text(world.realtime, "YYYY-MM-DD hh:mm")] (server time)"
	return L

/datum/bug_report_queue/proc/add(client/C, title, what, steps, expected)
	ensure_loaded()
	var/datum/bug_report/R = new
	R.id = next_id++
	R.ckey = C.ckey
	R.title = bug_report_clean(title, BUG_REPORT_TITLE_MAX, FALSE)
	R.what = bug_report_clean(what)
	R.steps = bug_report_clean(steps)
	R.expected = bug_report_clean(expected)
	R.context = context_for(C)
	R.filed_at = time2text(world.realtime, "YYYY-MM-DD hh:mm")
	reports["[R.id]"] = R
	last_report_at[C.ckey] = world.time
	save()
	log_admin("BUG REPORT #[R.id] from [key_name(C)]: [R.title]")
	var/notice = "<span class='notice'><b>Bug report #[R.id]</b> from [key_name(C)]: [html_encode(R.title)] (<a href='?src=\ref[src];bugreport=panel'>review</a>)</span>"
	for (var/client/X in admins)
		if (X.holder && (R_ADMIN & X.holder.rights))
			to_chat(X, notice)
	return R

/proc/bug_report_notify(ckey, message)
	var/client/C = directory[ckey]
	if (C)
		to_chat(C, message)

/datum/bug_report_queue/proc/github_repo()
	return config && bug_report_repo_valid(config.bug_report_github_repo) ? config.bug_report_github_repo : null

/datum/bug_report_queue/proc/issue_text(datum/bug_report/R, title, admin_note)
	return list(bug_report_issue_title(title ? title : R.title), bug_report_issue_body(R.ckey, R.what, R.steps, R.expected, R.context, admin_note))

// Read only while filing; see the note at the top of this file.
/datum/bug_report_queue/proc/read_token()
	if (!fexists("config/config.txt"))
		return null
	return bug_report_token_from_lines(file2list("config/config.txt"))

/datum/bug_report_queue/proc/token_configured()
	return !!read_token()

/datum/bug_report_queue/proc/approve(datum/bug_report/R, admin_ckey, title, admin_note)
	set waitfor = FALSE
	if (!R || R.state == "filing")
		return
	var/repo = github_repo()
	if (!repo)
		bug_report_notify(admin_ckey, "<span class='warning'>Bug reports: BUG_REPORT_GITHUB_REPO is not set to owner/name in the server config.</span>")
		return
	var/list/text = issue_text(R, title, admin_note)
	var/list/labels = bug_report_labels(config.bug_report_github_labels)
	var/token = read_token()
	if (!token)
		// No token: the admin submits the prefilled form with their own GitHub account.
		var/url = bug_report_prefill_url(repo, text[1], text[2], jointext(labels, ","))
		var/client/A = directory[admin_ckey]
		if (A && url)
			A << link(url)
		finish(R, admin_ckey, null, "opened as a prefilled GitHub form (the server has no GitHub token)")
		return
	R.state = "filing"
	R.last_error = null
	var/list/result = post_issue(repo, token, text[1], text[2], labels)
	token = null
	if (!result["url"] && result["status"] == 422 && labels.len)
		// A label the token may not create: file it without labels.
		result = post_issue(repo, read_token(), text[1], text[2], list())
	if (result["url"])
		finish(R, admin_ckey, result["url"], "filed as [result["url"]]")
		return
	R.state = "failed"
	R.last_error = result["error"]
	save()
	log_admin("Bug report #[R.id] could not be filed by [admin_ckey]: [R.last_error]")
	bug_report_notify(admin_ckey, "<span class='warning'>Bug report #[R.id] could not be filed: [html_encode(R.last_error)]. It is still in the queue; try again or use the prefilled GitHub form.</span>")

// list("url" = issue page or null, "status" = HTTP status, "error" = text)
/datum/bug_report_queue/proc/post_issue(repo, token, title, body, list/labels)
	var/list/payload = list("title" = title, "body" = body)
	if (labels.len)
		payload["labels"] = labels
	var/datum/http_request/H = new
	H.prepare(RUSTG_HTTP_METHOD_POST, "https://api.github.com/repos/[repo]/issues", json_encode(payload), list(
		"Authorization" = "Bearer [token]",
		"Accept" = "application/vnd.github+json",
		"X-GitHub-Api-Version" = "2022-11-28",
		"User-Agent" = "Civ13-bug-reports",
		"Content-Type" = "application/json"))
	try
		H.begin_async()
	catch
		return list("status" = 0, "error" = "rust_g HTTP is unavailable")
	for (var/i in 1 to BUG_REPORT_REQUEST_TICKS)
		if (H.is_complete())
			break
		sleep(1)
	if (!H.is_complete())
		return list("status" = 0, "error" = "GitHub did not answer in time")
	var/datum/http_response/response = H.into_response()
	if (response.error)
		return list("status" = 0, "error" = "request failed")
	var/list/answer = null
	try
		answer = json_decode(response.body)
	catch
		answer = null
	var/status = response.status_code
	if (status == 201 && islist(answer) && istext(answer["html_url"]) && findtext(answer["html_url"], "https://github.com/") == 1)
		return list("url" = answer["html_url"], "status" = status)
	var/message = islist(answer) && istext(answer["message"]) ? copytext(answer["message"], 1, 200) : "no message"
	return list("status" = status, "error" = "GitHub answered [status]: [message]")

/datum/bug_report_queue/proc/finish(datum/bug_report/R, admin_ckey, url, outcome)
	reports -= "[R.id]"
	filed++
	save()
	log_admin("Bug report #[R.id] ([R.title]) approved by [admin_ckey]: [outcome]")
	message_admins("Bug report #[R.id] approved by [admin_ckey]: [html_encode(outcome)]")
	bug_report_notify(R.ckey, "<span class='notice'>Thank you! An admin approved your bug report \"[html_encode(R.title)]\"[url ? ": <a href='[url]'>[url]</a>" : " and passed it to the developers"].</span>")

/datum/bug_report_queue/proc/reject(datum/bug_report/R, admin_ckey, reason)
	if (!R || R.state == "filing")
		return
	reports -= "[R.id]"
	rejected++
	save()
	reason = bug_report_clean(reason, 300, FALSE)
	log_admin("Bug report #[R.id] ([R.title]) rejected by [admin_ckey][length(reason) ? ": [reason]" : ""]")
	message_admins("Bug report #[R.id] rejected by [admin_ckey].")
	bug_report_notify(R.ckey, "<span class='notice'>An admin closed your bug report \"[html_encode(R.title)]\" without filing it[length(reason) ? ": [html_encode(reason)]" : "."]</span>")

/datum/bug_report_queue/proc/panel_html()
	ensure_loaded()
	var/list/H = list("<html><head><title>Bug Reports</title></head><body>")
	var/repo = github_repo()
	H += "<b>GitHub:</b> [repo ? html_encode(repo) : "<font color='red'>BUG_REPORT_GITHUB_REPO is not set</font>"], "
	H += token_configured() ? "token set, approved reports are filed automatically." : "<font color='orange'>no token, Approve opens a prefilled GitHub form for you to submit</font>."
	H += "<br>Waiting: [reports.len]. Approved this round: [filed]. Rejected: [rejected]. <a href='?src=\ref[src];bugreport=panel'>Refresh</a><hr>"
	if (!reports.len)
		H += "<i>No bug reports are waiting.</i>"
	for (var/id in reports)
		var/datum/bug_report/R = reports[id]
		H += "<h3>#[R.id]: [html_encode(R.title)]</h3>"
		H += "From <b>[html_encode(R.ckey)]</b> at [html_encode(R.filed_at)][R.state == "filing" ? " <i>(filing...)</i>" : ""]"
		if (R.last_error)
			H += "<br><font color='red'>Last attempt failed: [html_encode(R.last_error)]</font>"
		H += "<br><b>What happened:</b><pre>[html_encode(R.what)]</pre>"
		H += "<b>Steps:</b><pre>[html_encode(R.steps)]</pre>"
		H += "<b>Expected:</b><pre>[html_encode(R.expected)]</pre>"
		var/list/details = list()
		for (var/label in R.context)
			details += "[html_encode(label)]: [html_encode("[R.context[label]]")]"
		H += "<small>[jointext(details, " | ")]</small><br>"
		if (R.state != "filing")
			H += "<a href='?src=\ref[src];bugreport=approve;id=[R.id]'>Approve</a> | "
			H += "<a href='?src=\ref[src];bugreport=edit;id=[R.id]'>Edit title and approve</a> | "
			H += "<a href='?src=\ref[src];bugreport=reject;id=[R.id]'>Reject</a>"
		H += "<hr>"
	H += "</body></html>"
	return jointext(H, "")

/datum/bug_report_queue/proc/show_panel(mob/user)
	if (!user || !check_rights(R_ADMIN, TRUE, user))
		return
	user << browse(panel_html(), "window=bugreports;size=720x640")

/datum/bug_report_queue/Topic(href, href_list)
	var/mode = href_list["bugreport"]
	if (!mode || !check_rights(R_ADMIN, TRUE, usr))
		return
	ensure_loaded()
	if (mode == "panel")
		show_panel(usr)
		return
	var/datum/bug_report/R = reports[href_list["id"]]
	if (!R)
		to_chat(usr, "<span class='warning'>That bug report was already handled.</span>")
		show_panel(usr)
		return
	var/admin_ckey = usr.ckey
	switch (mode)
		if ("approve", "edit")
			var/title = R.title
			if (mode == "edit")
				title = input(usr, "Issue title (\[In-game] is added in front).", "Bug report #[R.id]", R.title) as text|null
				if (isnull(title))
					return
			var/note = input(usr, "Optional note for the developers (shown on the issue).", "Bug report #[R.id]") as message|null
			if (isnull(note))
				return
			// The prompts wait; check again that it is still ours to approve.
			if (!check_rights(R_ADMIN, TRUE, usr) || reports["[R.id]"] != R || R.state == "filing")
				return
			if (mode == "edit")
				R.title = bug_report_clean(title, BUG_REPORT_TITLE_MAX, FALSE)
			approve(R, admin_ckey, R.title, note)
		if ("reject")
			var/reason = input(usr, "Reason sent to the player (optional).", "Reject bug report #[R.id]") as text|null
			if (isnull(reason))
				return
			if (!check_rights(R_ADMIN, TRUE, usr) || reports["[R.id]"] != R)
				return
			reject(R, admin_ckey, reason)
	show_panel(usr) // approve() returns at its first wait, so a report being filed shows as filing

/client/verb/report_bug()
	set category = "Help!"
	set name = "Report Bug"
	set desc = "Send a bug report to the admins, who can pass it to the developers on GitHub."
	var/why = bug_reports.refusal(src)
	if (why)
		to_chat(src, "<span class='warning'>[why]</span>")
		return
	var/title = input(src, "Short summary of the bug (one line).", "Report bug") as text|null
	title = bug_report_clean(title, BUG_REPORT_TITLE_MAX, FALSE)
	if (!length(title))
		return
	var/what = input(src, "What happened?", "Report bug: [title]") as message|null
	if (isnull(what))
		return
	var/steps = input(src, "How can it be made to happen again? Leave empty if you do not know.", "Report bug: [title]") as message|null
	if (isnull(steps))
		return
	var/expected = input(src, "What should have happened instead?", "Report bug: [title]") as message|null
	if (isnull(expected))
		return
	if (!length(bug_report_clean(what)))
		to_chat(src, "<span class='warning'>Please describe what happened.</span>")
		return
	why = bug_reports.refusal(src) // the prompts wait
	if (why)
		to_chat(src, "<span class='warning'>[why]</span>")
		return
	var/datum/bug_report/R = bug_reports.add(src, title, what, steps, expected)
	to_chat(src, "<span class='notice'>Bug report #[R.id] sent. An admin will review it; your BYOND key, the map, round and your location are attached. You will hear back here if you are online.</span>")

/client/proc/bug_reports_panel()
	set category = "Admin"
	set name = "Bug Reports"
	set desc = "Review in-game bug reports and file them as GitHub issues."
	bug_reports.show_panel(mob)

#undef BUG_REPORT_COOLDOWN
#undef BUG_REPORT_PENDING_MAX
#undef BUG_REPORT_PER_PLAYER
#undef BUG_REPORT_REQUEST_TICKS
#undef BUG_REPORT_QUEUE_FILE
