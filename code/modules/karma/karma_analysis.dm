// Staff karma analysis view: every live rating from the coordinator's karma
// files (shared-records/karma/), grouped, filtered and measured in the staff
// member's own window (code/js/karma_analysis.js). R_ADMIN only.
//
// Ratings made here and not yet synced appear once the coordinator's next
// pass rewrites the files (about a minute). A server outside a shard group has
// no coordinator, so this view is empty there; the per-player Karma window
// still works from the local journal.

// Every live rating as a flat row, ready for the analysis view.
/proc/karma_analysis_rows()
	. = list()
	var/folder = "[shared_records.root()]karma/"
	for (var/name in flist(folder))
		if (copytext(name, -5) != ".json")
			continue
		var/text = shared_records.read_json("[folder][name]")
		if (!istext(text))
			continue
		var/list/file = null
		try
			file = json_decode(text)
		catch
			file = null
		if (!islist(file) || !istext(file["ckey"]) || !islist(file["ratings"]))
			continue
		var/list/standing = file["standing"]
		var/target_standing = islist(standing) ? standing["value"] : null
		for (var/list/row in file["ratings"])
			if (!islist(row) || !istext(row["giver"]))
				continue
			. += list(list("target" = file["ckey"], "target_hours" = file["hours"], "target_standing" = target_standing,
				"giver" = row["giver"], "kind" = row["kind"], "factors" = row["factors"],
				"giver_standing" = row["giver_standing"], "giver_hours" = row["giver_hours"], "giver_notes" = row["giver_notes"] ? TRUE : FALSE,
				"flags" = islist(row["flags"]) ? row["flags"] : list(), "faction" = row["faction"], "region" = row["region"],
				"at" = row["at"], "note" = row["note"]))

/datum/karma_admin_window/proc/show_analysis(client/C, focus = "")
	if (!C || !C.holder || !(C.holder.rights & R_ADMIN))
		return
	focus = ckey(focus)
	var/data = replacetext(json_encode(karma_analysis_rows()), "</", "<\\/")
	C << browse_rsc('code/js/karma_analysis.js', "karma_analysis.js")
	var/html = {"<html>[common_browser_style]<head><title>Karma analysis</title>
<style>td,th{padding:2px 6px;border:1px solid #888} table{border-collapse:collapse} #k_controls label{margin-right:10px;white-space:nowrap}</style>
<script src='karma_analysis.js'></script></head><body>
<h3>Karma analysis</h3><p><i>Hidden from players. Synced from every region about once a minute.</i></p>
<div id='k_controls'>
<p><label>Ranking <select id='k_preset'><option value=''>(choose your own)</option>
<option value='poorly_from_good'>Most poorly from good-standing givers</option>
<option value='swing_7d'>Biggest swing in the last 7 days</option>
<option value='most_flagged'>Most flagged ratings received</option>
<option value='mostly_poorly'>Givers who mostly give poorly</option>
<option value='disagree'>Givers who disagree with staff standings</option></select></label></p>
<p><label>Group by <select id='k_group'><option value='target'>rated player</option><option value='giver'>giver</option>
<option value='kind'>kindly or poorly</option><option value='giver_standing'>giver standing</option>
<option value='playtime_band'>giver playtime band</option><option value='faction'>giver faction</option>
<option value='region'>region</option><option value='notes'>giver admin notes</option><option value='flag'>warning flag</option>
<option value='week'>week given</option></select></label>
<label>Kind <select id='k_kind'><option value=''>both</option><option value='kindly'>kindly</option><option value='poorly'>poorly</option></select></label>
<label>Giver standing <select id='k_standing'><option value=''>any</option><option value='good_up'>good or trusted</option>
<option value='poor_down'>poor or bad</option><option value='trusted'>trusted</option><option value='good'>good</option>
<option value='neutral'>neutral</option><option value='poor'>poor</option><option value='bad'>bad</option><option value='unknown'>unknown</option></select></label>
<label>Min group size <input id='k_min' size='3'></label></p>
<p><label>From <input id='k_from' size='10' placeholder='YYYY-MM-DD'></label><label>To <input id='k_to' size='10' placeholder='YYYY-MM-DD'></label>
<label>Min giver hours <input id='k_minhours' size='4'></label>
<label><input type='checkbox' id='k_notes'> givers with notes</label><label><input type='checkbox' id='k_flagged'> flagged only</label>
<label><input type='checkbox' id='k_disagree'> against staff standing</label></p>
<p><label>Rated <input id='k_target' size='12'></label><label>Giver <input id='k_giver' size='12'></label>
<label>Faction <input id='k_faction' size='10'></label><label>Region <input id='k_region' size='10'></label></p>
<p>Weight factors: <label><input type='checkbox' id='k_f_standing' checked> standing</label>
<label><input type='checkbox' id='k_f_playtime' checked> playtime</label><label><input type='checkbox' id='k_f_age' checked> age</label>
<label><input type='checkbox' id='k_f_banned' checked> drop banned givers</label>
<label><input type='checkbox' id='k_showrows'> show each rating</label></p>
</div>
<p id='k_count'></p><table id='k_table'></table><br><table id='k_rows'></table>
<p>CSV of the ratings in this view (copy it out):<br><textarea id='k_csv' rows='6' cols='110' readonly></textarea></p>
<script>karmaInit([data], "[focus]");</script></body></html>"}
	show_browse(C, html, "window=karma_analysis;size=1100x750")
