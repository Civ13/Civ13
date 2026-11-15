// Which commit the server runs and when it was last updated, for the Server
// Revision verb (OOC tab) and the admins' Status tab line.
//
// The host (scripts/gaia-host/gaia_host.py start, shard_group.py handover)
// writes config/server-build.json: the revision, its commit time and subject,
// when the .dmb was compiled and when this revision went live (a restart onto
// the same revision keeps that time). A server started by hand has no such
// file: the revision then comes from config/lifecycle-revision.txt or the
// checkout's .git HEAD, without times. The file is re-read at most once a
// minute, so a handover that writes it after the new world boots shows up.

#define SERVER_BUILD_REFRESH 600

var/global/list/server_build_info = null
var/global/server_build_checked = null
var/global/server_build_boot_realtime = world.realtime

/proc/server_build_hex(text)
	if(!istext(text) || length(text) != 40) return FALSE
	for(var/i in 1 to 40)
		var/c = text2ascii(text, i)
		if(!((c >= 48 && c <= 57) || (c >= 97 && c <= 102))) return FALSE
	return TRUE

// The checkout's HEAD commit: .git may be a folder or, in a worktree, a
// "gitdir: <path>" file. A branch HEAD is resolved through its ref file or packed-refs.
/proc/server_build_git_head(root = "")
	var/gitdir = "[root].git/"
	if(!fexists("[gitdir]HEAD"))
		if(!fexists("[root].git")) return null
		var/pointer = trim(file2text("[root].git"))
		if(copytext(pointer, 1, 9) != "gitdir: ") return null
		gitdir = replacetext(trim(copytext(pointer, 9)), "\\", "/")
		if(copytext(gitdir, -1) != "/") gitdir += "/"
		if(!fexists("[gitdir]HEAD")) return null
	var/head = trim(file2text("[gitdir]HEAD"))
	if(server_build_hex(head)) return head
	if(copytext(head, 1, 6) != "ref: ") return null
	var/ref = trim(copytext(head, 6))
	if(findtext(ref, "..")) return null
	var/list/dirs = list(gitdir)
	// A worktree keeps its branch refs in the main repository (commondir).
	if(fexists("[gitdir]commondir"))
		var/common = replacetext(trim(file2text("[gitdir]commondir")), "\\", "/")
		if(copytext(common, -1) != "/") common += "/"
		if(!findtext(common, ":") && copytext(common, 1, 2) != "/") common = "[gitdir][common]"
		dirs += common
	for(var/dir in dirs)
		if(fexists("[dir][ref]"))
			var/value = trim(file2text("[dir][ref]"))
			if(server_build_hex(value)) return value
		if(fexists("[dir]packed-refs"))
			for(var/line in splittext(file2text("[dir]packed-refs"), "\n"))
				var/list/parts = splittext(trim(line), " ")
				if(parts.len == 2 && parts[2] == ref && server_build_hex(parts[1])) return parts[1]
	return null

/proc/server_build_read()
	var/list/info = list("source" = null, "revision" = null)
	if(fexists("config/server-build.json"))
		try
			var/list/record = json_decode(file2text("config/server-build.json"))
			if(islist(record) && server_build_hex(record["revision"]))
				info["source"] = "host"
				info["revision"] = record["revision"]
				if(istext(record["subject"])) info["subject"] = copytext(record["subject"], 1, 201)
				for(var/key in list("committed", "compiled", "deployed"))
					// Whole minutes since 2000-01-01 UTC: exact in a BYOND number, unlike unix seconds.
					var/minute = record["[key]_minute"]
					if(isnum(minute) && minute >= 0 && minute == round(minute) && istext(record["[key]_utc"]))
						info[key] = minute
						info["[key]_utc"] = copytext(record["[key]_utc"], 1, 32)
		catch
			info = list("source" = null, "revision" = null)
	if(!info["revision"] && fexists("config/lifecycle-revision.txt"))
		var/revision = trim(file2text("config/lifecycle-revision.txt"))
		if(server_build_hex(revision))
			info["source"] = "lifecycle"
			info["revision"] = revision
	if(!info["revision"])
		var/head = server_build_git_head()
		if(head)
			info["source"] = "checkout"
			info["revision"] = head
	return info

/proc/server_build_current()
	if(!server_build_info || isnull(server_build_checked) || world.time >= server_build_checked + SERVER_BUILD_REFRESH)
		server_build_checked = world.time
		server_build_info = server_build_read()
	return server_build_info

// Deciseconds since a minute stamp, for "3 hours ago" (world.realtime is good to a couple of minutes).
/proc/server_build_elapsed(minute, now_realtime = world.realtime)
	return max(0, now_realtime - minute * 600)

/proc/server_build_when(list/info, key, now_realtime = world.realtime)
	if(!isnum(info[key])) return null
	return "[info["[key]_utc"]] UTC ([persistence_last_save_ago(server_build_elapsed(info[key], now_realtime))])"

// One line for the Status tab: "abc1234, updated 2026-11-13 01:00 UTC (2 hours ago)".
/proc/server_build_summary(list/info = server_build_current(), now_realtime = world.realtime)
	if(!info || !info["revision"]) return "unknown"
	var/text = copytext(info["revision"], 1, 8)
	var/updated = server_build_when(info, "deployed", now_realtime)
	if(updated) text += ", updated [updated]"
	return text

/proc/server_build_html(list/info = server_build_current(), now_realtime = world.realtime)
	var/list/lines = list("<b>Server revision</b>")
	if(!info || !info["revision"])
		lines += "The commit this server runs is not known."
	else
		var/revision = info["revision"]
		lines += "Commit: <a href='https://github.com/Civ13/Civ13/commit/[revision]'>[copytext(revision, 1, 8)]</a> ([revision])"
		if(info["subject"]) lines += "Change: [html_encode(info["subject"])]"
		var/committed = server_build_when(info, "committed", now_realtime)
		if(committed) lines += "Committed: [committed]"
		var/compiled = server_build_when(info, "compiled", now_realtime)
		if(compiled) lines += "Compiled: [compiled]"
		var/deployed = server_build_when(info, "deployed", now_realtime)
		if(deployed) lines += "Updated on this server: [deployed]"
		if(info["source"] == "checkout") lines += "<i>Read from the checkout; the running build may be older.</i>"
	lines += "Running since: [time2text(server_build_boot_realtime, "YYYY-MM-DD hh:mm", 0)] UTC ([persistence_last_save_ago(max(0, now_realtime - server_build_boot_realtime))])"
	return jointext(lines, "<br>")

/client/verb/server_revision()
	set name = "Server Revision"
	set category = "OOC"
	set desc = "Show which commit this server runs and when it was last updated."
	to_chat(src, "<span class='notice'>[server_build_html()]</span>")

#undef SERVER_BUILD_REFRESH
