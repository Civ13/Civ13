// Land stages (docs/land-stages.md). Every land of a region group has a
// settlement stage that the group coordinator keeps beside the home ledger:
// CLOSED, FRONTIER (explorers only), COLONY (a faction has settled there) or
// OPEN (new characters may start there). The mainland is always MAINLAND. A
// paused land keeps its stage, but new starts there wait. Admins set stages
// from Admin > Land Status; each world reads the list from its own transfer
// agent. A stage never moves anyone's home or character.

#define LAND_STAGE_REFRESH 600 // deciseconds between reads of the agent's copy

var/global/list/land_stages = list() // region id -> list("stage", "paused", "by", "at")
var/global/list/land_stage_pending = list() // admin changes the coordinator has not decided yet
var/global/land_stages_checked = 0 // world.time of the last good read (0: never)
var/global/land_stages_refreshing = FALSE
var/global/list/land_suggestions_told = list() // region id -> the suggestion admins here were last told about

/proc/land_stage_names()
	return list("CLOSED", "FRONTIER", "COLONY", "OPEN")

// Lands whose stage means something: places people can live. Transit worlds,
// event and practice worlds and battle worlds never get one.
/proc/land_stage_kind_ok(kind)
	return kind in list("SURFACE", "OCEANIC", "UNDERGROUND", "OTHER")

// Reads the stage list from this world's transfer agent. Sleeps; returns FALSE
// and keeps the last list when the agent cannot answer.
/proc/land_stages_refresh()
	if(!shard_group.enabled || !transfer_bridge || !transfer_bridge.enabled() || land_stages_refreshing)
		return FALSE
	land_stages_refreshing = TRUE
	var/list/answer = transfer_bridge.request("/lands", list())
	land_stages_refreshing = FALSE
	if(!answer || !answer["ok"] || !islist(answer["result"]))
		return FALSE
	var/list/result = answer["result"]
	var/list/lands = result["lands"]
	if(!islist(lands))
		return FALSE
	var/list/clean = list()
	for(var/id in lands)
		var/list/entry = lands[id]
		if(!shard_id_valid(id) || !islist(entry) || !((entry["stage"] in land_stage_names()) || entry["stage"] == "MAINLAND"))
			continue
		clean[id] = list("stage" = entry["stage"], "paused" = entry["paused"] ? TRUE : FALSE,
			"by" = istext(entry["by"]) ? ckey(entry["by"]) : null, "at" = isnum(entry["at"]) ? entry["at"] : 0,
			"readiness" = land_readiness_clean(entry["readiness"]))
	var/list/waiting = list()
	if(islist(result["pending"]))
		for(var/list/request in result["pending"])
			if(islist(request) && shard_id_valid(request["region"]) && (request["stage"] in land_stage_names()))
				waiting += list(list("region" = request["region"], "stage" = request["stage"], "paused" = request["paused"] ? TRUE : FALSE))
	land_stages = clean
	land_stage_pending = waiting
	land_stages_checked = world.time
	land_suggestions_tell()
	return TRUE

// The coordinator's population numbers for one land, or null.
/proc/land_readiness_clean(list/ready)
	if(!islist(ready))
		return null
	var/list/clean = list()
	for(var/key in list("homes", "players_peak", "living", "hours"))
		clean[key] = isnum(ready[key]) ? max(0, round(ready[key])) : 0
	clean["players_avg"] = isnum(ready["players_avg"]) ? max(0, ready["players_avg"]) : 0
	clean["suggest"] = (ready["suggest"] in list("OPEN", "PAUSE", "RESUME")) ? ready["suggest"] : null
	return clean

/proc/land_suggestion_text(suggest)
	switch(suggest)
		if("OPEN") return "ready to settle: enough people live there and the mainland can spare them"
		if("PAUSE") return "consider pausing new starts: the mainland is quiet or this land has outgrown it"
		if("RESUME") return "ready to resume new starts"
	return ""

// Tells this world's admins once when a land's suggested change appears or
// changes. Admins decide; nothing changes by itself.
/proc/land_suggestions_tell()
	for(var/id in land_stages)
		var/list/entry = land_stages[id]
		var/list/ready = entry["readiness"]
		var/suggest = ready ? ready["suggest"] : null
		if(land_suggestions_told[id] == suggest)
			continue
		land_suggestions_told[id] = suggest
		if(!suggest)
			continue
		var/name = id == shard_group.region ? shard_group.name : (shard_group.peers[id] ? shard_group.peers[id]["name"] : id)
		message_admins("Land Status: [html_encode(name)] is [land_suggestion_text(suggest)]. See Admin > Land Status.")

// Reports this world's population to its transfer agent for the coordinator's
// weekly numbers: players connected and living characters owned by an account.
/proc/land_sample_post()
	if(!shard_group.enabled || !transfer_bridge || !transfer_bridge.enabled())
		return FALSE
	var/living = 0
	for(var/mob/living/human/H in human_mob_list)
		if(H.persistence_owner_ckey && H.stat != DEAD && !QDELETED(H))
			living++
	var/list/colonies = map ? map.colony_report() : list()
	var/list/answer = transfer_bridge.request("/land/sample", list("players" = length(clients), "living" = living, "colonies" = colonies))
	return answer && answer["ok"]

// A refresh when the copy is older than LAND_STAGE_REFRESH; called by the
// region poll loop (shard_group.start_polling).
/proc/land_stages_refresh_due()
	if(land_stages_checked && world.time - land_stages_checked < LAND_STAGE_REFRESH)
		return FALSE
	return land_stages_refresh()

// The stage of a land: MAINLAND, CLOSED, FRONTIER, COLONY or OPEN.
/proc/land_stage(id)
	if(!shard_group.enabled || !id)
		return null
	if(id == shard_group.mainland)
		return "MAINLAND"
	var/list/entry = land_stages[id]
	return entry ? entry["stage"] : "CLOSED"

/proc/land_stage_paused(id)
	var/list/entry = land_stages[id]
	return entry ? entry["paused"] : FALSE

/proc/land_stage_text(stage, paused = FALSE)
	var/text
	switch(stage)
		if("MAINLAND") text = "mainland"
		if("CLOSED") text = "unexplored"
		if("FRONTIER") text = "frontier"
		if("COLONY") text = "colonised"
		if("OPEN") text = "settled"
		else text = "-"
	if(paused && stage != "MAINLAND")
		text += " (paused)"
	return text

// The Regions panel's column: a stage only for lands people live in.
/proc/land_stage_column(id, kind)
	if(id != shard_group.mainland && !land_stage_kind_ok(kind))
		return ""
	return land_stage_text(land_stage(id), land_stage_paused(id))

// What each stage lets players do, for the admin panel.
/proc/land_stage_help(stage)
	switch(stage)
		if("CLOSED") return "nobody travels there yet"
		if("FRONTIER") return "explorers travel there; a bed there keeps their home"
		if("COLONY") return "a faction has settled there; its members may start there"
		if("OPEN") return "new characters may also start in its wilds"
	return ""

// "Name (id)" = id for every land an admin may give a stage.
/proc/land_stage_choices()
	var/list/choices = list()
	if(!shard_group.enabled)
		return choices
	var/list/ids = list(shard_group.region) + shard_group.order
	for(var/id in ids)
		if(id == shard_group.mainland)
			continue
		var/name = id == shard_group.region ? shard_group.name : shard_group.peers[id]["name"]
		var/kind = id == shard_group.region ? shard_group.kind : shard_group.peers[id]["kind"]
		if(!land_stage_kind_ok(kind))
			continue
		choices["[name] ([id])"] = id
	return choices

/proc/land_stage_admin_html()
	var/list/lines = list("<table class='regions'><tr><th>Land</th><th>Stage</th><th>What it allows</th><th>Homes</th><th>Players (7-day avg / peak)</th><th>Living</th><th>Set by</th></tr>")
	var/list/choices = land_stage_choices()
	lines += "<tr><td>[html_encode(shard_group.mainland == shard_group.region ? shard_group.name : (shard_group.peers[shard_group.mainland] ? shard_group.peers[shard_group.mainland]["name"] : shard_group.mainland))]</td><td>mainland</td><td>every new character starts here</td>[land_readiness_cells(shard_group.mainland)]<td></td></tr>"
	for(var/label in choices)
		var/id = choices[label]
		var/stage = land_stage(id)
		var/list/entry = land_stages[id]
		var/by = entry && entry["by"] ? html_encode(entry["by"]) : ""
		lines += "<tr><td>[html_encode(label)]</td><td>[land_stage_text(stage, land_stage_paused(id))]</td><td>[land_stage_help(stage)]</td>[land_readiness_cells(id)]<td>[by]</td></tr>"
		var/list/ready = entry ? entry["readiness"] : null
		if(ready && ready["suggest"])
			lines += "<tr><td></td><td colspan='6' class='note'>Suggested: [land_suggestion_text(ready["suggest"])].</td></tr>"
	lines += "</table>"
	if(length(land_stage_pending))
		lines += "<p class='note'>Waiting for the world directory: [length(land_stage_pending)] change(s).</p>"
	if(!land_stages_checked)
		lines += "<p class='note'>The stage list has not been read from the world directory yet.</p>"
	return jointext(lines, "")

/proc/land_readiness_cells(id)
	var/list/entry = land_stages[id]
	var/list/ready = entry ? entry["readiness"] : null
	if(!ready)
		return "<td>-</td><td>-</td><td>-</td>"
	var/avg = ready["hours"] ? "[round(ready["players_avg"], 0.1)] / [ready["players_peak"]]" : "no data yet"
	return "<td>[ready["homes"]]</td><td>[avg]</td><td>[ready["living"]]</td>"

/datum/admins/proc/land_status()
	set category = "Admin"
	set name = "Land Status"
	set desc = "See and set each land's settlement stage: unexplored, frontier, colonised or settled."
	if(!check_rights(R_ADMIN)) return
	var/mob/M = usr
	if(!M || !M.client) return
	if(!shard_group.enabled)
		to_chat(M, SPAN_WARNING("This server is not part of a region group, so it has no lands."))
		return
	land_stages_refresh()
	var/datum/browser/popup = new(M, "land_status", "Land Status", 820, 380)
	popup.add_head_content("<style>table.regions{border-collapse:collapse;width:100%}table.regions th,table.regions td{padding:3px 6px;text-align:left;border-bottom:1px solid #444}p.note,td.note{color:#c96}</style>")
	popup.set_content(land_stage_admin_html())
	popup.open(FALSE)
	var/list/choices = land_stage_choices()
	if(!length(choices))
		to_chat(M, SPAN_NOTICE("No land in this group can take a stage."))
		return
	var/choice = WWinput(M, "Which land's stage do you want to change?", "Land Status", "Cancel", choices + "Cancel")
	if(!choice || choice == "Cancel" || !(choice in choices) || !M.client || !check_rights(R_ADMIN)) return
	var/id = choices[choice]
	var/list/stage_choices = list()
	for(var/stage in land_stage_names())
		stage_choices["[land_stage_text(stage)]: [land_stage_help(stage)]"] = stage
	var/stage_choice = WWinput(M, "[choice] is [land_stage_text(land_stage(id), land_stage_paused(id))]. Choose its stage. Nobody's home or character moves.", "Land Status", "Cancel", stage_choices + "Cancel")
	if(!stage_choice || stage_choice == "Cancel" || !(stage_choice in stage_choices) || !M.client || !check_rights(R_ADMIN)) return
	var/stage = stage_choices[stage_choice]
	var/paused = FALSE
	if(stage == "COLONY" || stage == "OPEN")
		paused = WWinput(M, "Pause new starts in [choice]? A paused land keeps its stage.", "Land Status", "Not paused", list("Not paused", "Paused")) == "Paused"
		if(!M.client || !check_rights(R_ADMIN)) return
	var/list/answer = transfer_bridge.request("/land/set", list("region" = id, "stage" = stage, "paused" = paused ? 1 : 0, "admin" = M.ckey))
	if(!answer || !answer["ok"])
		to_chat(M, SPAN_WARNING("The world directory refused or did not answer[answer && istext(answer["error"]) ? ": [html_encode(answer["error"])]" : ""]. Nothing changed."))
		return
	log_admin("[key_name(M)] set the land [id] to [stage][paused ? " (paused)" : ""].")
	message_admins("[key_name_admin(M)] set [html_encode(choice)] to [land_stage_text(stage, paused)]. Every land sees it within a minute.")

#undef LAND_STAGE_REFRESH
