// Staff side of hidden karma (karma_ledger.dm): one player's dossier, the
// admin standing, voiding a rating and barring an account from giving.
// R_ADMIN only. Every change is logged and shared with the other regions
// through the shared player records store.

var/global/datum/karma_admin_window/karma_admin_window = new

/client/proc/cmd_admin_karma()
	set category = "Admin"
	set name = "Karma"
	set desc = "A player's hidden karma: who remembers them kindly or poorly, and how those givers stand."
	if (!check_rights(R_ADMIN))
		return
	var/list/choices = list("(analysis view: every player)" = "")
	for (var/client/C in clients)
		choices["[C.ckey]"] = C.ckey
	var/pick = player_input(src.mob, "Whose karma? Pick an online player or the analysis view, or Cancel to type a ckey.", "Karma", null, "anything", sortList(choices), TRUE)
	if (pick == "(analysis view: every player)")
		karma_admin_window.show_analysis(src)
		return
	if (!pick)
		pick = player_input(src.mob, "Type a ckey.", "Karma", null, "text", null, TRUE)
	pick = ckey(pick)
	if (!length(pick))
		return
	karma_admin_window.show(src, pick)

// The ckey karma belongs to for a mob: a persistent body's owner, else its player.
/proc/karma_mob_ckey(mob/M)
	if (ishuman(M))
		return karma_character_ckey(M)
	return ismob(M) && M.ckey ? M.ckey : null

// One line for the Player Panel and prayer lines: standing and weighted counts.
/proc/karma_brief(ckey)
	var/list/dossier = karma_dossier(ckey)
	var/list/summary = dossier["summary"]
	var/list/standing = dossier["standing"]
	return "[standing ? "Standing [karma_standing_name(standing["value"])]" : "No standing"], kindly [summary["kindly"]] ([summary["kindly_weighted"]]), poorly [summary["poorly"]] ([summary["poorly_weighted"]])"

/datum/karma_admin_window/proc/show(client/C, ckey)
	if (!C || !C.holder || !(C.holder.rights & R_ADMIN))
		return
	ckey = ckey(ckey)
	var/list/dossier = karma_dossier(ckey)
	var/list/summary = dossier["summary"]
	var/list/standing = dossier["standing"]
	var/link = "?src=\ref[src];karma_ckey=[ckey]"
	var/html = "<html>[common_browser_style]<head><title>Karma: [ckey]</title></head><body>"
	html += "<h3>Karma: [ckey]</h3><p><i>Hidden from players. Weights = giver standing x playtime share x age.</i></p>"
	if (standing)
		html += "<p><b>Admin standing:</b> [karma_standing_name(standing["value"])] ([standing["value"]]) by [html_encode("[standing["author"]]")] on [shared_records.time_text(standing["at"], "YYYY-MM-DD")]: [html_encode("[standing["reason"]]")]</p>"
	else
		html += "<p><b>Admin standing:</b> not set</p>"
	html += "<p><a href='[link];karma_act=standing'>Set standing</a> | "
	html += dossier["barred"] ? "<b>Barred from giving</b> (<a href='[link];karma_act=unbar'>lift</a>)" : "<a href='[link];karma_act=bar'>Bar from giving</a>"
	html += " | <a href='[link];karma_act=analysis'>Analyse their ratings</a> | <a href='[link];karma_act=refresh'>Refresh</a></p>"
	html += "<p><b>Playtime</b> (alive, awake, connected): [dossier["hours"]] h. "
	html += "<b>Kindly</b> [summary["kindly"]] (weighted [summary["kindly_weighted"]]), <b>poorly</b> [summary["poorly"]] (weighted [summary["poorly_weighted"]]), net per 10 h played: [summary["per10h"]].</p>"
	for (var/kind in list("kindly", "poorly"))
		var/list/rows = list()
		for (var/list/row in dossier["ratings"])
			if (row["kind"] == kind)
				rows += list(row)
		html += "<h4>Remembered [kind] by ([length(rows)])</h4>"
		if (!length(rows))
			html += "<p><i>nobody</i></p>"
			continue
		html += "<table width='100%' border='1' cellspacing='0' cellpadding='2'><tr><th>Giver</th><th>Standing</th><th>Hours</th><th>Notes</th><th>Weight</th><th>Flags</th><th>When</th><th>Their note</th><th></th></tr>"
		for (var/list/row in sortTim(rows, /proc/cmp_karma_weight_dsc))
			var/list/flags = row["flags"]
			var/list/factors = row["factors"]
			var/list/record = row["record"]
			html += "<tr><td><a href='?src=\ref[src];karma_ckey=[row["giver"]];karma_act=refresh'>[row["giver"]]</a></td>"
			html += "<td>[row["giver_standing"]]</td><td>[row["giver_hours"]]</td><td>[row["giver_notes"] ? "<b>yes</b>" : "no"]</td>"
			html += "<td title='standing [factors["standing"]] x playtime [factors["playtime"]] x age [factors["age"]]'>[row["weight"]]</td>"
			html += "<td>[length(flags) ? replacetext(jointext(flags, ", "), "_", " ") : ""]</td>"
			html += "<td>[shared_records.time_text(row["at"], "YYYY-MM-DD")]</td><td>[length(row["note"]) ? row["note"] : ""]</td>"
			html += "<td><a href='[link];karma_act=void;karma_record=[record["id"]]'>Void</a></td></tr>"
		html += "</table>"
	html += "</body></html>"
	show_browse(C, html, "window=karma_[ckey];size=900x600")

/proc/cmp_karma_weight_dsc(list/a, list/b)
	return b["weight"] - a["weight"]

/datum/karma_admin_window/Topic(href, list/href_list)
	var/client/C = usr ? usr.client : null
	if (!C || !check_rights(R_ADMIN))
		return
	var/ckey = ckey(href_list["karma_ckey"])
	if (!length(ckey))
		return
	var/rank = C.holder.rank
	switch (href_list["karma_act"])
		if ("analysis")
			show_analysis(C, ckey)
			return
		if ("standing")
			var/choice = player_input(C.mob, "Hidden admin standing for [ckey]:", "Karma", null, "anything", list("Trusted (+2)", "Good (+1)", "Neutral (0)", "Poor (-1)", "Bad (-2)"), TRUE)
			if (!choice)
				return
			var/reason = player_input(C.mob, "Why? (required, kept in the log)", "Karma", null, "text", null, TRUE)
			if (!reason)
				return
			var/list/values = list("Trusted (+2)" = 2, "Good (+1)" = 1, "Neutral (0)" = 0, "Poor (-1)" = -1, "Bad (-2)" = -2)
			var/value = values[choice]
			if (karma_set_standing(ckey, value, sanitize(reason), C.ckey, rank))
				karma_staff_log(C, "set [ckey]'s karma standing to [value]: [reason]")
		if ("bar", "unbar")
			var/reason = player_input(C.mob, href_list["karma_act"] == "bar" ? "Why bar [ckey] from giving karma?" : "Why lift the bar?", "Karma", null, "text", null, TRUE)
			if (!reason)
				return
			if (karma_set_bar(ckey, href_list["karma_act"] == "bar", sanitize(reason), C.ckey, rank))
				karma_staff_log(C, "[href_list["karma_act"] == "bar" ? "barred" : "unbarred"] [ckey] from giving karma: [reason]")
		if ("void")
			var/list/target = null
			for (var/list/record in shared_records.records_for(ckey))
				if (record["id"] == href_list["karma_record"] && record["kind"] == "karma_rating")
					target = record
			if (!target || target["revoked"])
				return
			var/reason = player_input(C.mob, "Why void this rating? It stays in the log.", "Karma", null, "text", null, TRUE)
			if (!reason)
				return
			var/list/body = target["body"]
			if (shared_records.revoke(target, C.ckey, rank, sanitize(reason)))
				karma_staff_log(C, "voided [body["giver"]]'s [body["rating"]] rating of [ckey]: [reason]")
	show(C, ckey)

/proc/karma_staff_log(client/C, text)
	log_admin("[key_name(C)] [text]")
	message_admins("[key_name_admin(C)] [html_encode(text)]")
