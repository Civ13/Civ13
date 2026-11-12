// ------------------------------------------------------------
// Research Tree - admin view of who knows which research (Val, 2026-11-12)
// ------------------------------------------------------------
// Under book research a character knows only the chapters and manuals they
// have studied. These tools let admins see that knowledge without View
// Variables: per character (right-click Show Research Knowledge), for everyone
// at once with the reverse "who knows this" view (Special > Check Research
// Knowledge), and on the agent `players` read. Offline characters are the
// sleeping bodies left in the world, found by their saved owner. Everything
// here only reads.

// Read-only knowledge summary: known node ids in tree order, partial studies
// as node id => percent read, and whether the character is exempt (an agent
// character, who crafts as if it knew everything).
/mob/living/human/proc/research_knowledge_summary()
	var/list/known = list()
	var/list/studying = list()
	for (var/node_id in research_nodes)
		if (islist(known_recipe_nodes) && (node_id in known_recipe_nodes))
			known += node_id
		else if (islist(study_progress))
			var/fraction = study_progress[node_id]
			if (isnum(fraction) && fraction > 0 && fraction < 1)
				studying[node_id] = round(fraction * 100)
	return list("known" = known, "studying" = studying, "exempt" = recipe_knowledge_exempt() ? TRUE : FALSE)

// The account behind a character, connected or not.
/mob/living/human/proc/research_knowledge_account()
	if (ckey)
		return ckey
	if (persistence_owner_ckey)
		return persistence_owner_ckey
	return null

/mob/living/human/proc/research_knowledge_status()
	if (stat == DEAD)
		return "dead"
	if (client)
		return "online"
	if (ckey)
		return "disconnected"
	if (persistence_owner_ckey)
		return "offline"
	return "no player"

/proc/research_node_label(node_id)
	var/datum/research_node/N = get_research_node(node_id)
	return N ? N.name : "[node_id]"

/proc/research_knowledge_studying_text(list/studying)
	var/list/parts = list()
	for (var/node_id in studying)
		parts += "[html_encode(research_node_label(node_id))] ([studying[node_id]]%)"
	return parts.len ? jointext(parts, ", ") : "-"

/proc/research_knowledge_known_text(list/known)
	var/list/parts = list()
	for (var/node_id in known)
		parts += html_encode(research_node_label(node_id))
	return parts.len ? jointext(parts, ", ") : "-"

/proc/research_knowledge_page(title, body)
	var/html = "<html><head><meta charset='utf-8'><title>[title]</title><style>body{font-family:Verdana,sans-serif;font-size:12px}table{border-collapse:collapse;width:100%}th,td{border:1px solid #888;padding:3px;vertical-align:top}th{background:#ddd;text-align:left}h3{margin:12px 0 4px}</style>"
	html += "<script>function rkFilter(v){v=v.toLowerCase();var rows=document.getElementsByTagName('tr');for(var i=0;i<rows.length;i++){var r=rows\[i\];if(r.className!='rk')continue;r.style.display=(r.innerText||r.textContent).toLowerCase().indexOf(v)>=0?'':'none';}}</script>"
	html += "</head><body>[body]</body></html>"
	return html

/proc/research_knowledge_mode_note()
	if (!map || !map.recipe_knowledge_enabled())
		return "<i>Personal research knowledge is off on this map, so crafting does not check it here.</i><br>"
	if (map.book_research_enabled())
		return "<small>Book research is on: a character knows only what they have studied from a chapter or manual.</small><br>"
	return "<small>Personal recipe knowledge is on: characters learn from manuals of their faction's research.</small><br>"

// Everyone at once: one row per character with a player or any knowledge,
// then the reverse view, one row per research node that anybody knows or is
// part-way through.
/client/proc/cmd_admin_check_research()
	set category = "Special"
	set name = "Check Research Knowledge"
	set desc = "List what research each character knows or is studying, and who knows each research."
	if (!check_rights(R_ADMIN))
		return
	var/list/rows = list()
	var/list/knowers = list()   // node id => list of names
	var/list/readers = list()   // node id => list of "name (n%)"
	var/characters = 0
	for (var/mob/living/human/H in human_mob_list)
		if (QDELETED(H))
			continue
		var/list/info = H.research_knowledge_summary()
		var/list/known = info["known"]
		var/list/studying = info["studying"]
		var/account = H.research_knowledge_account()
		if (!account && !known.len && !studying.len)
			continue
		characters++
		var/status = H.research_knowledge_status()
		var/order = status == "online" ? 0 : (status == "dead" ? 3 : (account ? 1 : 2))
		var/who = "[html_encode(H.real_name)][account ? " ([html_encode(account)])" : ""]"
		var/known_cell = info["exempt"] ? "<i>agent character, crafts without books</i>" : research_knowledge_known_text(known)
		rows += list(list(order, "<tr class='rk'><td>[html_encode(H.real_name)]</td><td>[account ? html_encode(account) : "-"]</td><td>[status]</td><td>[known.len]</td><td>[known_cell]</td><td>[research_knowledge_studying_text(studying)]</td></tr>"))
		for (var/node_id in known)
			if (!knowers[node_id])
				knowers[node_id] = list()
			knowers[node_id] += who
		for (var/node_id in studying)
			if (!readers[node_id])
				readers[node_id] = list()
			readers[node_id] += "[who] [studying[node_id]]%"
	var/body = "<h2>Research knowledge</h2>"
	body += research_knowledge_mode_note()
	body += "<small>Characters in this world only, including sleeping offline ones. Characters away in another region are listed there.</small><br>"
	if (!characters)
		body += "<br>Nobody here knows or is studying any research."
		src << browse(research_knowledge_page("Research Knowledge", body), "window=check_research;size=900x600")
		return
	body += "<br>Filter: <input type='text' onkeyup='rkFilter(this.value)' style='width:240px'>"
	body += "<h3>By character ([characters])</h3>"
	body += "<table><tr><th>Name</th><th>Player</th><th>Status</th><th>Known</th><th>Knows</th><th>Studying</th></tr>"
	for (var/order in 0 to 3)
		for (var/list/row in rows)
			if (row[1] == order)
				body += row[2]
	body += "</table>"
	body += "<h3>By research</h3>"
	body += "<table><tr><th>Research</th><th>Era</th><th>Tree</th><th>Known by</th><th>Being studied by</th></tr>"
	var/listed = 0
	for (var/node_id in research_nodes)
		var/list/k = knowers[node_id]
		var/list/r = readers[node_id]
		if (!k && !r)
			continue
		listed++
		var/datum/research_node/N = research_nodes[node_id]
		body += "<tr class='rk'><td>[html_encode(N.name)]</td><td>[N.era_tier]</td><td>[html_encode(N.tree)]</td><td>[k ? "[k.len]: [jointext(k, ", ")]" : "-"]</td><td>[r ? jointext(r, ", ") : "-"]</td></tr>"
	body += "</table><small>[listed] of [research_nodes.len] research nodes are known or being studied by someone here.</small>"
	src << browse(research_knowledge_page("Research Knowledge", body), "window=check_research;size=900x600")

// One character, from the right-click menu or the verb list.
/client/proc/cmd_admin_show_research(mob/living/human/H as mob in human_mob_list)
	set category = "Admin"
	set name = "Show Research Knowledge"
	set desc = "Show which research this character knows and how far they are through what they are studying."
	if (!check_rights(R_ADMIN))
		return
	if (!istype(H) || QDELETED(H))
		return
	var/list/info = H.research_knowledge_summary()
	var/list/known = info["known"]
	var/list/studying = info["studying"]
	var/account = H.research_knowledge_account()
	var/body = "<h2>[html_encode(H.real_name)]</h2>"
	body += "Player: [account ? html_encode(account) : "none"] ([H.research_knowledge_status()])<br>"
	body += research_knowledge_mode_note()
	if (info["exempt"])
		body += "<b>Agent character:</b> crafts without needing books, whatever is listed below.<br>"
	body += "<h3>Knows [known.len] of [research_nodes.len]</h3>"
	if (known.len)
		body += "<table><tr><th>Research</th><th>Era</th><th>Tree</th><th>Category</th></tr>"
		for (var/node_id in known)
			var/datum/research_node/N = research_nodes[node_id]
			body += "<tr><td>[html_encode(N.name)]</td><td>[N.era_tier]</td><td>[html_encode(N.tree)]</td><td>[html_encode(N.category)]</td></tr>"
		body += "</table>"
	else
		body += "Nothing yet.<br>"
	body += "<h3>Part-way through</h3>"
	if (studying.len)
		body += "<table><tr><th>Research</th><th>Era</th><th>Read</th></tr>"
		for (var/node_id in studying)
			var/datum/research_node/N = research_nodes[node_id]
			body += "<tr><td>[html_encode(N.name)]</td><td>[N.era_tier]</td><td>[studying[node_id]]%</td></tr>"
		body += "</table>"
	else
		body += "Nothing.<br>"
	src << browse(research_knowledge_page("Research: [html_encode(H.real_name)]", body), "window=show_research;size=560x600")
