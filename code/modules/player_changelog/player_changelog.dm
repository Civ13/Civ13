// What's New: the player-facing Changelog: lines of merged pull requests, shown
// from the lobby, the Game Menu (Esc) and the OOC tab's Changelog verb.
//
// The host (scripts/gaia-host/gaia_host.py start, shard_group.py handover)
// writes config/player-changelog.json with scripts/gaia-host/player_changelog.py:
// only pull requests merged into the revision this server runs, newest first.
// A server started by hand can run that script itself. The file is re-read at
// most once a minute, since the host writes it after the world is already up.

#define PLAYER_CHANGELOG_FILE "config/player-changelog.json"
#define PLAYER_CHANGELOG_REFRESH 600
#define PLAYER_CHANGELOG_MAX 60

var/global/list/player_changelog_entries = null
var/global/player_changelog_checked = null

/proc/player_changelog_read()
	var/list/rows = list()
	if(!fexists(PLAYER_CHANGELOG_FILE))
		return rows
	try
		var/list/record = json_decode(file2text(PLAYER_CHANGELOG_FILE))
		if(islist(record) && record["schema"] == 1 && islist(record["entries"]))
			for(var/list/entry in record["entries"])
				if(rows.len >= PLAYER_CHANGELOG_MAX) break
				var/text = entry["text"]
				var/date = entry["date"]
				var/pr = entry["pr"]
				if(!istext(text) || !length(text) || !istext(date) || length(date) != 10) continue
				rows += list(list("text" = copytext(text, 1, 1501), "date" = date, "pr" = (isnum(pr) && pr > 0 && pr == round(pr)) ? pr : null))
	catch
		rows = list()
	return rows

/proc/player_changelog()
	if(isnull(player_changelog_checked) || world.time - player_changelog_checked >= PLAYER_CHANGELOG_REFRESH)
		player_changelog_checked = world.time
		player_changelog_entries = player_changelog_read()
	return player_changelog_entries

/proc/player_changelog_month(date)
	var/list/names = list("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
	var/month = text2num(copytext(date, 6, 8))
	var/day = text2num(copytext(date, 9, 11))
	if(!isnum(month) || month < 1 || month > 12 || !isnum(day))
		return html_encode(date)
	return "[day] [names[month]] [copytext(date, 1, 5)]"

/proc/player_changelog_html()
	var/list/entries = player_changelog()
	var/list/body = list()
	if(!entries.len)
		body += "<p class='clNote'>No recent changes are recorded for this server yet.</p>"
	else
		var/current = null
		for(var/list/entry in entries)
			if(entry["date"] != current)
				if(current) body += "</ul>"
				current = entry["date"]
				body += "<h3>[player_changelog_month(current)]</h3><ul>"
			var/link = entry["pr"] ? " <a class='clPr' href='https://github.com/Civ13/Civ13/pull/[entry["pr"]]'>#[entry["pr"]]</a>" : ""
			body += "<li>[html_encode(entry["text"])][link]</li>"
		body += "</ul>"
	return {"<html><head><title>What's New</title><meta charset='utf-8'>[common_browser_style]
<style>
body {padding: 10px 14px;}
h2 {margin: 0 0 2px;}
h3 {margin: 14px 0 4px; border-bottom: 1px solid #6b5230;}
ul {margin: 0; padding-left: 18px;}
li {margin: 4px 0; line-height: 140%;}
.clNote {color: #b8ab92; font-size: 12px; margin: 0;}
a.clPr, a.clPr:link, a.clPr:visited {background: none; border: none; padding: 0; margin: 0; color: #a89470; font-size: 11px; display: inline;}
</style></head><body><h2>What's New</h2><p class='clNote'>Player-facing changes in the version this server runs, newest first.</p>[jointext(body, "")]</body></html>"}

/client/proc/show_player_changelog()
	show_browse(src, player_changelog_html(), "window=player_changelog;size=560x620")

/client/verb/player_changelog_verb()
	set name = "Changelog"
	set category = "OOC"
	set desc = "See what changed in the version this server runs."
	show_player_changelog()

#undef PLAYER_CHANGELOG_FILE
#undef PLAYER_CHANGELOG_REFRESH
#undef PLAYER_CHANGELOG_MAX
