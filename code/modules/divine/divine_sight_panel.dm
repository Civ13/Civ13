// ============================================================
// Divine Sight: the panel page. Hidden mechanic, as divine_sight.dm: keep it
// out of changelog lines, the wiki and the public Crafting Atlas.
// ------------------------------------------------------------
// divine_sight_panel_html() turns the data gathered by divine_panel_data()
// (divine_sight.dm) into one page: a toolbar, the prayers that wait for an
// answer, the god's followers and the spirits still bound to bodies. Plain
// HTML and inline CSS only, no script: the page is rebuilt on every action.
// Every text value passes through divine_panel_text(); hrefs are built by the
// caller from refs and are placed as they come.
// ============================================================

#define DIVINE_PANEL_EMPTY(text) "<div class='none'>" + text + "</div>"

// A value as page text. Null shows as nothing.
/proc/divine_panel_text(value)
	return html_encode("[value]")

/proc/divine_panel_button(href, label, kind = "")
	if (!href)
		return ""
	return "<a class='b[kind ? " [kind]" : ""]' href='[href]'>[label]</a>"

// A section heading with its count. Lit when something waits there.
/proc/divine_panel_heading(title, count, lit = FALSE)
	return "<h2[lit && count ? " class='lit'" : ""]>[title]<span class='n'>[count]</span></h2>"

/proc/divine_panel_css()
	return @{"<style>
html,body{margin:0;padding:0}
body{background:#17151d;color:#e9e3d2;font-family:Verdana,Geneva,sans-serif;font-size:12px;line-height:1.4;padding:0 0 10px}
a{color:#e8cf8a;text-decoration:none}
a:hover{color:#fff}
.top{background:#211d2b;border-bottom:1px solid #6d5a2c;padding:10px 12px 8px}
.rule{height:2px;background:#c9a548;font-size:0;line-height:0}
h1{font-family:Georgia,'Times New Roman',serif;font-size:21px;font-weight:normal;color:#f4dc9a;margin:0;letter-spacing:1px}
h1 span{color:#c9a548;font-size:15px;margin-right:7px}
.sub{color:#b0a78f;font-size:11px;margin-top:2px}
.sub b{color:#e9e3d2;font-weight:normal}
.bar{padding:7px 12px 6px;background:#1c1924;border-bottom:1px solid #35303f}
.b{display:inline-block;background:#2d2838;color:#e9e3d2;border:1px solid #5b5270;border-radius:3px;padding:3px 9px;margin:1px 3px 1px 0;white-space:nowrap;font-size:12px}
.b:hover{background:#40395a;border-color:#8a7fb0;color:#fff}
.b.yes{background:#2c5230;border-color:#63b368;color:#e2f8dc;font-weight:bold}
.b.yes:hover{background:#3c7442;color:#fff}
.b.no{background:#4a2422;border-color:#b8584c;color:#ffd6cd}
.b.no:hover{background:#7a2f28;color:#fff}
.b.sm{padding:2px 7px;font-size:11px}
.sec{margin:10px 12px 0}
h2{font-size:11px;letter-spacing:1px;text-transform:uppercase;color:#b0a78f;font-weight:normal;margin:0 0 4px;padding:0 0 3px;border-bottom:1px solid #35303f}
h2.lit{color:#f4dc9a;border-bottom-color:#6d5a2c}
.n{display:inline-block;min-width:10px;text-align:center;margin-left:7px;padding:0 6px;border-radius:9px;border:1px solid #4a4458;background:#24202d;color:#b0a78f;font-size:11px;letter-spacing:0}
h2.lit .n{background:#c9a548;border-color:#f4dc9a;color:#1c1608;font-weight:bold}
table{width:100%;border-collapse:collapse}
td{padding:4px 6px;vertical-align:middle;border-bottom:1px solid #2a2633}
tr:hover td{background:#1f1c28}
td.act{text-align:right;white-space:nowrap;width:1%}
td.mark{width:1%;padding-right:0;color:#c9a548;white-space:nowrap}
.pray td{background:#221f17;border-bottom-color:#3d3520}
.pray:hover td{background:#2b2719}
.who{color:#fff;font-weight:bold}
.dim{color:#a39b86;font-size:11px}
.what{color:#f4dc9a}
.pill{display:inline-block;border-radius:9px;padding:0 8px;font-size:11px;border:1px solid #6b6578;background:#2a2633;color:#c9c3d2;white-space:nowrap}
.pill.awake{background:#254a2a;border-color:#5fae62;color:#c8f0c0}
.pill.away{background:#57451a;border-color:#c79a36;color:#f6dfa0}
.pill.dead{background:#3a2a2a;border-color:#96645c;color:#e0bcb4}
.none{color:#a39b86;font-style:italic;padding:5px 6px}
.note{margin:10px 12px 0;padding:7px 10px;background:#221f17;border:1px solid #6d5a2c;border-left:3px solid #c9a548;border-radius:3px;color:#e3d6ad}
</style>"}

/proc/divine_sight_panel_html(mob/observer/ghost/G, list/data)
	if (!islist(data))
		data = list()
	var/label = divine_panel_text(data["label"])
	var/claim = data["claim"]
	var/list/html = list("<!DOCTYPE html><html><head><meta charset='utf-8'><meta http-equiv='X-UA-Compatible' content='IE=edge'><title>Divine Sight</title>")
	html += divine_panel_css()
	html += "</head><body>"

	// Who is looking, and for which god they answer.
	html += "<div class='rule'></div><div class='top'><h1><span>&#10022;</span>[label]</h1>"
	if (claim)
		html += "<div class='sub'>Divine Sight - you speak as <b>[divine_panel_text(claim)]</b></div>"
	else
		html += "<div class='sub'>Divine Sight - you speak for no god yet</div>"
	html += "</div>"

	html += "<div class='bar'>"
	for (var/list/action in data["actions"])
		html += divine_panel_button(action["href"], divine_panel_text(action["label"]))
	html += "</div>"

	if (!claim)
		html += "<div class='note'>Beseech requests and your followers appear here once you choose <b>Speak as a god</b> in Divine Patron. Prayers over the dead and bound spirits are shown to every god.</div>"

	// Prayers awaiting an answer: Beseech requests first, then prayers over the dead.
	var/list/requests = data["requests"]
	var/list/revivals = data["revivals"]
	var/waiting = 0
	var/list/rows = list()
	for (var/list/R in requests)
		var/open = R["grant"] || R["refuse"]
		if (open)
			waiting++
		var/detail = divine_panel_text(R["detail"])
		rows += "<tr class='pray'><td class='mark'>&#10022;</td><td><span class='who'>[divine_panel_text(R["who"])]</span><br>"
		rows += "<span class='dim'>beseeches</span> <span class='what'>[divine_panel_text(R["what"])]</span>[detail ? " <span class='dim'>[detail]</span>" : ""]</td><td class='act'>"
		if (open)
			rows += divine_panel_button(R["grant"], "Grant", "yes")
			rows += divine_panel_button(R["refuse"], "Refuse", "no")
		else
			rows += "<span class='pill'>[divine_panel_text(R["state"])]</span> "
		rows += divine_panel_button(R["go"], "Go", "sm")
		rows += "</td></tr>"
	for (var/list/P in revivals)
		waiting++
		rows += "<tr class='pray'><td class='mark'>&#10013;</td><td><span class='who'>[divine_panel_text(P["who"])]</span><br>"
		rows += "<span class='dim'>prays for the return of</span> <span class='what'>[divine_panel_text(P["for"])]</span></td><td class='act'>"
		rows += divine_panel_button(P["grant"], "Grant", "yes")
		rows += divine_panel_button(P["refuse"], "Refuse", "no")
		rows += divine_panel_button(P["go"], "Go", "sm")
		rows += "</td></tr>"
	html += "<div class='sec'>[divine_panel_heading("Prayers awaiting you", waiting, TRUE)]"
	if (rows.len)
		html += "<table>[jointext(rows, "")]</table>"
	else
		html += DIVINE_PANEL_EMPTY("No prayer waits for your answer.")
	html += "</div>"

	// Followers of the god they speak as.
	var/list/followers = data["followers"]
	html += "<div class='sec'>[divine_panel_heading("Followers", length(followers))]"
	if (length(followers))
		html += "<table>"
		for (var/list/F in followers)
			var/status = divine_panel_text(F["status"])
			html += "<tr><td><span class='who'>[divine_panel_text(F["name"])]</span> <span class='pill [status]'>[status]</span><br>"
			html += "<span class='dim'>[divine_panel_text(F["place"])]</span></td><td class='act'>"
			html += divine_panel_button(F["go"], "Go", "sm")
			html += divine_panel_button(F["haunt"], "Haunt", "sm")
			html += "</td></tr>"
		html += "</table>"
	else
		html += DIVINE_PANEL_EMPTY(claim ? "Nobody follows you yet." : "Followers appear once you speak as a god.")
	html += "</div>"

	// Spirits of the dead still held to their bodies.
	var/list/spirits = data["spirits"]
	html += "<div class='sec'>[divine_panel_heading("Bound spirits", length(spirits))]"
	if (length(spirits))
		html += "<table>"
		for (var/list/S in spirits)
			html += "<tr><td><span class='who'>[divine_panel_text(S["name"])]</span> <span class='dim'>([divine_panel_text(S["ckey"])])</span><br>"
			html += "<span class='dim'>[divine_panel_text(S["left"])]</span></td><td class='act'>"
			html += divine_panel_button(S["go"], "Go", "sm")
			html += divine_panel_button(S["release"], "Release", "sm no")
			html += "</td></tr>"
		html += "</table>"
	else
		html += DIVINE_PANEL_EMPTY("No spirit lingers by its body.")
	html += "</div>"

	html += "</body></html>"
	return jointext(html, "")

#undef DIVINE_PANEL_EMPTY
