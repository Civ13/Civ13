// Admin player panel pages.
//
// Two staff windows share one look (admin_panel_css):
// - the player list (verb "Player Panel"): everyone with a key, with a search
//   box, state filters and sortable columns;
// - one player's panel ("Show Player Panel" and every PP link): who they are,
//   their records from every region, hidden karma, then the actions grouped by
//   what they are for.
// In-game actions still go through the existing rights checks in
// code/modules/admin/topic.dm. Text from players is
// html_encode()d here, and the list script reads text and data attributes only.

// The shared look of the staff pages: dark green, the same palette as the
// admin map. Raw string: no DM interpolation inside.
/proc/admin_panel_css()
	return @{"<style>
body{background:#1d2420;color:#d8e2d0;font-family:Verdana,Geneva,sans-serif;font-size:12px;line-height:1.45;margin:0;padding:10px}
a{color:#a6d890;text-decoration:none}
a:hover{color:#fff}
h1{font-size:18px;margin:0;font-weight:bold}
.dim{color:#9aa893;font-size:11px}
.mono{font-family:Consolas,monospace;font-size:11px}
.card{background:#232c26;border:1px solid #3b4a3a;border-radius:4px;padding:8px 10px;margin:0 0 8px}
.card h2{font-size:10px;letter-spacing:1px;text-transform:uppercase;color:#9aa893;margin:0 0 6px;font-weight:normal}
.card h2 span{text-transform:none;letter-spacing:0}
.head{display:flex;justify-content:space-between;gap:10px;align-items:flex-start}
.btns a{display:inline-block;background:#33402f;color:#d8e2d0;border:1px solid #5d7358;border-radius:3px;padding:3px 9px;margin:2px 2px 2px 0;white-space:nowrap}
.btns a:hover{background:#465a41;color:#fff}
.btns a.danger{border-color:#a8573f;color:#f3c0ac}
.btns a.danger:hover{background:#7a2f28;color:#fff}
.btns a.on{background:#7a2f28;border-color:#c0584a;color:#fff}
.btns a.has{background:#2f5a34;border-color:#5fae62;color:#fff}
.btns .lbl{display:inline-block;min-width:74px;color:#9aa893}
.pill{display:inline-block;border-radius:9px;padding:1px 8px;font-size:11px;border:1px solid #5d7358;background:#2b352a;margin:0 3px 2px 0;white-space:nowrap}
.pill.red{background:#5c2520;border-color:#c0584a;color:#ffd0c8}
.pill.amber{background:#57451a;border-color:#c79a36;color:#f6dfa0}
.pill.green{background:#254a2a;border-color:#5fae62;color:#c8f0c0}
.pill.blue{background:#1f3a57;border-color:#5a94cf;color:#c4dcf6}
.pill.grey{background:#30352f;border-color:#6b7468;color:#c2c8be}
.dot{display:inline-block;width:10px;height:10px;border-radius:6px;border:1px solid #000;vertical-align:middle}
.alive{background:#6fcf6f}
.down{background:#e0b040}
.dead{background:#d0554c}
.ghost{background:#e8eee4}
.lobby{background:#6aa9e8}
.other{background:#8a8a8a}
.tiles{display:flex;gap:6px;flex-wrap:wrap;margin-bottom:6px}
.tile{flex:1;min-width:72px;background:#1d2420;border:1px solid #3b4a3a;border-radius:3px;padding:5px 8px;color:#9aa893;font-size:11px}
.tile b{display:block;font-size:17px;color:#d8e2d0}
.tile.bad{border-color:#c0584a}
.tile.bad b{color:#f08a7c}
.tile.note b{color:#e8c060}
.tile.good b{color:#8fdc8a}
.bar{display:flex;gap:8px;align-items:center;flex-wrap:wrap;margin:8px 0}
input.q{background:#141a16;color:#d8e2d0;border:1px solid #5d7358;border-radius:3px;padding:4px 7px;width:230px;font-size:12px}
.chip{background:#2b352a;color:#d8e2d0;border:1px solid #5d7358;border-radius:11px;padding:2px 9px;font-size:11px;cursor:pointer;font-family:inherit}
.chip.on{background:#4f6a48;border-color:#9fd08a;color:#fff}
table.pl{width:100%;border-collapse:collapse}
table.pl th{text-align:left;font-size:10px;letter-spacing:1px;text-transform:uppercase;color:#9aa893;font-weight:normal;padding:4px 6px;cursor:pointer;border-bottom:1px solid #4c5f4a;white-space:nowrap}
table.pl th:hover{color:#fff}
table.pl td{padding:5px 6px;border-top:1px solid #2f3a2e;vertical-align:top}
table.pl tr:hover td{background:#283228}
table.pl a.nm{font-weight:bold;color:#e6efe0}
table.pl td.act a{margin-right:7px}
table.pl td.nw,table.pl td.act{white-space:nowrap}
details{margin:0}
summary{cursor:pointer;color:#d8e2d0}
details .btns{margin-top:6px}
</style>"}

// The state staff pages show for a mob, as list(key, label). Keys: alive,
// down, dead, ghost, lobby, other.
/proc/admin_player_state(mob/M)
	if (isnewplayer(M))
		return list("lobby", "In the lobby")
	if (isghost(M))
		return list("ghost", "Ghost")
	if (isliving(M))
		var/mob/living/L = M
		if (L.stat == DEAD)
			return list("dead", "Dead")
		if (L.stat != CONSCIOUS)
			return list("down", "Unconscious")
		return list("alive", "Alive")
	return list("other", "Other")

// What the mob is: the job for humans, else the kind of mob.
/proc/admin_player_role(mob/M)
	if (ishuman(M))
		var/mob/living/human/H = M
		return H.original_job ? "[H.original_job.title]" : "No job"
	if (isnewplayer(M))
		return "New player"
	if (isghost(M))
		return "Ghost"
	if (isanimal(M))
		return "Animal"
	if (isliving(M))
		return "Living"
	return "[M.type]"

// The mob's faction or civilization, or "".
/proc/admin_player_side(mob/M)
	var/side = tactical_map_side(M)
	if (!side)
		return ""
	return copytext(side, findtext(side, ":") + 1)

/proc/admin_player_where(mob/M)
	var/turf/T = get_turf(M)
	if (!T)
		return isnewplayer(M) ? "Lobby" : "Nowhere"
	var/area/A = get_area(T)
	return "[A ? A.name : "Unknown area"] ([T.x], [T.y], [T.z])"

// Minutes since the client last did anything, or 0 when under five.
/proc/admin_player_idle_minutes(mob/M)
	if (!M || !M.client)
		return 0
	var/minutes = round(M.client.inactivity / 600)
	return minutes >= 5 ? minutes : 0

// Hidden karma of one account as tiles. Callers show it to R_ADMIN only, like
// the Karma window it links to (code/modules/karma/karma_admin.dm).
/proc/player_karma_tiles_html(ckey)
	ckey = ckey(ckey)
	if (!length(ckey))
		return ""
	var/list/dossier = karma_dossier(ckey)
	var/list/summary = dossier["summary"]
	var/list/standing = dossier["standing"]
	var/net = summary["kindly_weighted"] - summary["poorly_weighted"]
	var/html = "<div class='tiles'>"
	html += "<div class='tile'><b>[standing ? capitalize(karma_standing_name(standing["value"])) : "Not set"]</b>admin standing</div>"
	html += "<div class='tile[summary["kindly"] ? " good" : ""]'><b>[summary["kindly"]]</b>kindly ([summary["kindly_weighted"]] weighted)</div>"
	html += "<div class='tile[summary["poorly"] ? " bad" : ""]'><b>[summary["poorly"]]</b>poorly ([summary["poorly_weighted"]] weighted)</div>"
	html += "<div class='tile[net > 0 ? " good" : (net < 0 ? " bad" : "")]'><b>[net > 0 ? "+" : ""][round(net, 0.01)]</b>net weighted</div>"
	html += "</div><div class='btns'>"
	html += "<a href='?src=\ref[karma_admin_window];karma_ckey=[ckey];karma_act=refresh'>Open karma</a>"
	if (dossier["barred"])
		html += "<span class='pill red'>barred from giving</span>"
	html += "</div>"
	return html

// --- The player list ---------------------------------------------------------

/datum/admins/proc/player_panel_new()
	if (!usr || !usr.client || !usr.client.holder)
		return
	usr << browse(player_list_html(usr), "window=players;size=980x640")

// Mentors see who is on and can message them; addresses, records and variables
// are for moderators and admins.
/datum/admins/proc/player_list_html(mob/user)
	var/staff = rights & (R_ADMIN|R_MOD)
	var/list/order = list("alive" = 1, "down" = 2, "dead" = 3, "ghost" = 4, "lobby" = 5, "other" = 6)
	var/list/counts = list("alive" = 0, "down" = 0, "dead" = 0, "ghost" = 0, "lobby" = 0, "other" = 0, "dc" = 0, "flag" = 0)
	var/list/rows = list()
	var/total = 0
	for (var/mob/M in sortmobs())
		if (!M.ckey)
			continue
		total++
		var/list/state = admin_player_state(M)
		counts[state[1]]++
		var/list/tags = list(state[1])
		var/list/badges = list()
		if (!M.client)
			tags += "dc"
			counts["dc"]++
			badges += "<span class='pill grey'>disconnected</span>"
		else
			var/idle = admin_player_idle_minutes(M)
			if (idle)
				badges += "<span class='pill grey'>idle [idle] min</span>"
			if (M.client.prefs && M.client.prefs.muted)
				badges += "<span class='pill amber'>muted</span>"
		if (is_special_character(M))
			badges += "<span class='pill blue'>special role</span>"
		var/hours = ""
		if (staff)
			var/list/sum = shared_records.summary(M.ckey)
			var/bans = length(shared_records.active_bans(M.ckey, "any"))
			if (sum["watch"])
				badges += "<span class='pill red'>watchlist</span>"
			if (bans)
				badges += "<span class='pill red'>[bans] active [bans == 1 ? "ban" : "bans"]</span>"
			if (sum["warnings"])
				badges += "<span class='pill amber'>[sum["warnings"]] [sum["warnings"] == 1 ? "warning" : "warnings"]</span>"
			if (sum["notes"])
				badges += "<span class='pill amber'>[sum["notes"]] [sum["notes"] == 1 ? "note" : "notes"]</span>"
			if (sum["watch"] || bans || sum["warnings"] || sum["notes"])
				tags += "flag"
				counts["flag"]++
			hours = "[sum["hours"]] h played"
		var/name = html_encode("[M.name]")
		var/real_name = (M.real_name && M.real_name != M.name) ? html_encode("[M.real_name]") : ""
		var/key = html_encode("[M.key]")
		var/role = html_encode(admin_player_role(M))
		var/side = html_encode(admin_player_side(M))
		var/rank = (M.client && M.client.holder) ? "<span class='pill green'>[html_encode("[M.client.holder.rank]")]</span>" : ""
		var/search = html_encode(lowertext("[M.name] [M.real_name] [M.key] [M.ckey] [admin_player_role(M)] [admin_player_side(M)]"))

		var/row = "<tr data-s='[jointext(tags, " ")]' data-q='[search]'>"
		row += "<td data-v='[order[state[1]]]'><span class='dot [state[1]]' title='[state[2]]'></span></td>"
		row += "<td><a class='nm' href='?src=\ref[src];adminplayeropts=\ref[M]'>[name]</a>[real_name ? "<div class='dim'>[real_name]</div>" : ""]</td>"
		row += "<td class='nw'>[key] [rank][(staff && M.lastKnownIP) ? "<div class='dim mono'>[html_encode("[M.lastKnownIP]")]</div>" : ""]</td>"
		row += "<td class='nw'>[role][side ? "<div class='dim'>[side]</div>" : ""]</td>"
		row += "<td class='nw'>[html_encode(admin_player_where(M))]</td>"
		row += "<td>[jointext(badges, "")][hours ? "<div class='dim'>[hours]</div>" : ""]</td>"
		row += "<td class='act'><a href='?src=\ref[src];adminplayeropts=\ref[M]' title='Player panel'>PP</a>"
		row += "<a href='?src=\ref[user];priv_msg=\ref[M]' title='Private message'>PM</a>"
		row += "<a href='?src=\ref[src];adminplayerobservejump=\ref[M]' title='Jump to them as a ghost'>JMP</a>"
		if (staff)
			row += "<a href='?src=\ref[src];notes=show;mob=\ref[M]' title='Notes from every region'>N</a>"
			row += "<a href='?_src_=vars;Vars=\ref[M]' title='View variables'>VV</a>"
			row += "<a href='?src=\ref[src];subtlemessage=\ref[M]' title='Subtle message'>SM</a>"
		row += "</td></tr>"
		rows += row

	var/list/html = list("<html><head><meta charset='utf-8'><title>Player panel</title>[admin_panel_css()]</head><body>")
	html += "<div class='head'><div><h1>Players</h1><div class='dim'>[total] with a key - <span id='n'></span></div></div>"
	html += "<div class='btns'><a href='?src=\ref[src];player_list=1'>Refresh</a>"
	if (staff)
		html += "<a href='?src=\ref[src];notes=list;index=1'>All player notes</a>"
	html += "</div></div>"
	html += "<div class='bar'><input class='q' id='q' type='text' placeholder='Search name, key, job or side'><span id='chips'>"
	html += "<button class='chip on' data-f='all' onclick=\"chip('all')\">All [total]</button>"
	var/list/chips = list("alive" = "Alive", "down" = "Unconscious", "dead" = "Dead", "ghost" = "Ghosts", "lobby" = "Lobby", "dc" = "Disconnected")
	if (staff)
		chips["flag"] = "Has records"
	for (var/chip in chips)
		html += " <button class='chip' data-f='[chip]' onclick=\"chip('[chip]')\">[chips[chip]] [counts[chip]]</button>"
	html += "</span></div>"
	html += "<table class='pl'><thead><tr>"
	var/column = 0
	for (var/title in list("State", "Character", "Key", "Role", "Where", "Status", ""))
		html += length(title) ? "<th onclick='sortBy([column])'>[title]</th>" : "<th></th>"
		column++
	html += "</tr></thead><tbody id='rows'>[jointext(rows, "")]</tbody></table>"
	if (!rows.len)
		html += "<p class='dim'>Nobody is connected.</p>"
	html += "<script>[admin_player_list_script()]</script></body></html>"
	return jointext(html, "")

// Search, filters and sorting for the list. Raw string: no DM interpolation
// inside. It reads attributes and text only and never writes HTML.
/proc/admin_player_list_script()
	return @{"
var F='all',SC=-1,SD=1;
function rows(){return document.getElementById('rows').children;}
function apply(){var q=document.getElementById('q').value.toLowerCase(),r=rows(),n=0;
for(var i=0;i<r.length;i++){var s=' '+r[i].getAttribute('data-s')+' ',ok=(F=='all'||s.indexOf(' '+F+' ')>=0)&&(!q||r[i].getAttribute('data-q').indexOf(q)>=0);
r[i].style.display=ok?'':'none';if(ok)n++;}
document.getElementById('n').textContent=n+' shown';}
function chip(f){F=f;var c=document.getElementById('chips').children;
for(var i=0;i<c.length;i++)c[i].className=c[i].getAttribute('data-f')==f?'chip on':'chip';apply();}
function key(r,c){var d=r.children[c],v=d.getAttribute('data-v');return v?parseFloat(v):(d.textContent||'').toLowerCase();}
function sortBy(c){SD=SC==c?-SD:1;SC=c;var b=document.getElementById('rows'),a=[],i;
for(i=0;i<b.children.length;i++)a.push(b.children[i]);
a.sort(function(x,y){var p=key(x,c),q=key(y,c);return p<q?-SD:p>q?SD:0;});
for(i=0;i<a.length;i++)b.appendChild(a[i]);}
document.getElementById('q').onkeyup=apply;document.getElementById('q').focus();apply();
"}

// --- One player's panel --------------------------------------------------------

/datum/admins/proc/show_player_panel(var/mob/M in mob_list)
	set category = null
	set name = "Show Player Panel"
	set desc = "Edit player (respawn, ban, heal, etc)"

	if (!M)
		to_chat(usr, "You seem to be selecting a mob that doesn't exist anymore.")
		return

	if (!istype(src,/datum/admins))
		src = usr.client.holder
	if (!istype(src,/datum/admins))
		to_chat(usr, "Error: you are not an admin!")
		return

	usr << browse(player_options_html(M, usr), "window=adminplayeropts;size=640x760")

// A member profile takes the raw BYOND key, not its normalized ckey.
/proc/admin_byond_profile_url(account_key)
	if (!istext(account_key) || !ckey(account_key) || copytext(account_key, 1, 2) == "@")
		return null
	if (findtext(account_key, regex(@"^Guest-W?[0-9]+$", "i")))
		return null
	var/path_key = replacetext(url_encode(account_key), "+", "%20")
	return "https://www.byond.com/members/[path_key]?format=text"

/datum/admins/proc/player_options_html(mob/M, mob/user)
	var/list/state = admin_player_state(M)
	var/list/body = list("<html><head><meta charset='utf-8'><title>Options for [html_encode("[M.key]")]</title>[admin_panel_css()]</head><body>")

	// Who they are.
	body += "<div class='card'><div class='head'><div>"
	body += "<h1>[html_encode("[M.name]")]</h1>"
	if (M.real_name && M.real_name != M.name)
		body += "<div class='dim'>Real name [html_encode("[M.real_name]")]</div>"
	if (M.key)
		body += "<div>played by <b>[html_encode("[M.key]")]</b> "
		if (M.client)
			body += "<a class='pill green' href='?src=\ref[src];editrights=show' title='Edit staff rights'>[M.client.holder ? html_encode("[M.client.holder.rank]") : "Player"]</a>"
		body += "</div>"
	else
		body += "<div class='dim'>No player</div>"
	var/side = admin_player_side(M)
	body += "<div>[html_encode(admin_player_role(M))][side ? " - [html_encode(side)]" : ""]</div>"
	body += "<div class='dim'>[html_encode(admin_player_where(M))]</div><div class='dim mono'>[M.type]</div>"
	body += "</div><div style='text-align:right'>"
	body += "<span class='pill [state[1] == "alive" ? "green" : (state[1] == "dead" ? "red" : (state[1] == "down" ? "amber" : "blue"))]'>[state[2]]</span>"
	if (isliving(M) && state[1] != "dead")
		var/mob/living/L = M
		if (L.maxHealth > 0)
			body += "<span class='pill grey'>[round(L.health / L.maxHealth * 100)]% health</span>"
	if (M.key && !M.client)
		body += "<span class='pill grey'>disconnected</span>"
	var/idle = admin_player_idle_minutes(M)
	if (idle)
		body += "<span class='pill grey'>idle [idle] min</span>"
	if (M.client && M.client.prefs && M.client.prefs.muted)
		body += "<span class='pill amber'>muted</span>"
	body += "</div></div>"
	body += "<div class='btns' style='margin-top:6px'>"
	body += "<a href='?src=\ref[user];priv_msg=\ref[M]'>Private message</a>"
	body += "<a href='?src=\ref[src];subtlemessage=\ref[M]'>Subtle message</a>"
	body += "[admin_jump_link(M, src)]"
	body += "<a href='?_src_=vars;Vars=\ref[M]'>View variables</a>"
	var/profile = admin_byond_profile_url(M.key)
	if (profile)
		body += "<a href='[html_encode(profile)]' target='_blank' rel='noopener noreferrer'>BYOND Profile</a>"
	if (!isnewplayer(M))
		body += "<a href='?src=\ref[src];revive=\ref[M]'>Heal</a>"
	body += "</div></div>"

	// What every region knows about the account.
	if (M.ckey)
		body += "<div class='card'><h2>Records <span>- every region</span></h2>[player_records_tiles_html(M.ckey, src)]</div>"
	var/karma_key = karma_mob_ckey(M)
	if (karma_key && (rights & R_ADMIN))
		body += "<div class='card'><h2>Karma <span>- hidden from players</span></h2>[player_karma_tiles_html(karma_key)]</div>"
	var/names = M.name_history_admin_html()
	if (length(names))
		body += "<div class='card'><h2>Names</h2>[names]</div>"

	// Moderation.
	body += "<div class='card'><h2>Moderation</h2><div class='btns'>"
	if (rights & (R_MOD | R_ADMIN))
		body += "<a class='danger' href='?src=\ref[src];boot2=\ref[M]'>Kick</a>"
	body += "<a href='?_src_=holder;warn=[M.ckey]'>Warn</a>"
	body += "<a href='?src=\ref[src];notes=show;mob=\ref[M]'>Notes</a>"
	body += "</div>"
	if (M.client)
		var/muted = M.client.prefs.muted
		body += "<div class='btns'><span class='lbl'>Mute</span>"
		var/list/mutes = list("IC" = MUTE_IC, "OOC" = MUTE_OOC, "Pray" = MUTE_PRAY, "Adminhelp" = MUTE_ADMINHELP, "Deadchat" = MUTE_DEADCHAT)
		for (var/label in mutes)
			body += "<a[(muted & mutes[label]) ? " class='on'" : ""] href='?src=\ref[src];mute=\ref[M];mute_type=[mutes[label]]' title='[(muted & mutes[label]) ? "Muted: click to unmute" : "Click to mute"]'>[label]</a>"
		body += "<a href='?src=\ref[src];mute=\ref[M];mute_type=[MUTE_ALL]'>Toggle all</a></div>"
	body += "</div>"

	// Moving and speaking.
	body += "<div class='card'><h2>Move and speak</h2>"
	body += "<div class='btns'><span class='lbl'>Move</span>"
	body += "<a href='?src=\ref[src];jumpto=\ref[M]'>Jump to</a>"
	body += "<a href='?src=\ref[src];getmob=\ref[M]'>Get</a>"
	body += "<a href='?src=\ref[src];sendmob=\ref[M]'>Send to</a>"
	if (get_turf(M) && (rights & (R_ADMIN|R_MOD)))
		body += "<a href='?src=\ref[admin_maps];am=show;m=\ref[M]'>Show on map</a>"
	body += "</div>"
	body += "<div class='btns'><span class='lbl'>Speak</span>"
	body += "<a href='?src=\ref[src];narrateto=\ref[M]'>Narrate to</a>"
	body += "<a href='?src=\ref[src];subtlemessage=\ref[M]'>Subtle message</a>"
	body += "<a href='?src=\ref[src];forcespeech=\ref[M]'>Force say</a></div>"
	body += "</div>"

	// Languages: green ones are known, click to toggle.
	var/list/known = list()
	var/list/unknown = list()
	for (var/k in all_languages)
		var/datum/language/L = all_languages[k]
		if (L.flags & INNATE)
			continue
		var/link = "<a[(L in M.languages) ? " class='has'" : ""] href='?src=\ref[src];toglang=\ref[M];lang=[html_encode(k)]'>[html_encode(k)]</a>"
		if (L in M.languages)
			known += link
		else
			unknown += link
	body += "<div class='card'><h2>Languages <span>- [known.len] known, click one to add or remove it</span></h2>"
	body += "<div class='btns'>[known.len ? jointext(known, "") : "<span class='dim'>None</span>"]</div>"
	body += "<details><summary class='dim'>Other languages ([unknown.len])</summary><div class='btns'>[jointext(unknown, "")]</div></details></div>"

	// Transformations, folded away: they replace the body.
	if (M.client && !isnewplayer(M))
		body += "<div class='card'><details><summary>Transform</summary>"
		body += "<div class='dim' style='margin-top:6px'>Makes a new mob of that kind and copies the player over. Nothing else is carried across.</div><div class='btns'>"
		var/list/kinds = list("Observer" = "observer", "Human" = "human", "Monkey" = "monkey", "Cat" = "cat", "Parrot" = "parrot",
			"Chicken" = "chicken", "Turkey" = "turkey", "Cow" = "cow", "Bull" = "bull", "Mouse" = "nouse", "Bear" = "bear", "Velociraptor" = "velociraptor")
		for (var/label in kinds)
			body += "<a href='?src=\ref[src];simplemake=[kinds[label]];mob=\ref[M]'>[label]</a>"
		body += "</div><div class='dim' style='margin-top:6px'>Body types keep them human and change the body.</div><div class='btns'>"
		var/list/bodies = list("Default" = "default", "Gorilla" = "gorilla", "Werewolf" = "wolfman", "Ant" = "ant", "Orc" = "orc", "Droid" = "droid")
		for (var/label in bodies)
			body += "<a href='?src=\ref[src];simplemake=[bodies[label]];mob=\ref[M]'>[label]</a>"
		if ((rights & R_ADMIN) && (rights & R_SPAWN) && ishuman(M))
			var/mob/living/human/H = M
			if (!H.heteromorph_id && !H.heteromorph_grant_problem(heteromorph_kind("dragonoid")))
				body += "<a href='?src=\ref[src];grant_staff_form=1;mob=\ref[M]'>Dragonoid</a>"
		body += "</div></details></div>"

	body += "</body></html>"
	return jointext(body, "")
