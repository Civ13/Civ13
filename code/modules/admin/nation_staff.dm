// Nations (Admin tab): staff tools for nation governments
// (tools/transfer_storage/nation_staff.py, docs/nation-government.md).
// See any nation's government, motions, revolt and staff log; freeze or thaw
// it, void a motion or a revolt petition, or set its government by hand.
// Every act needs a reason and is logged here and by the coordinator.

/datum/admins/proc/nation_staff_panel()
	set category = "Admin"
	set name = "Nations"
	set desc = "See every nation's government, freeze it, void a motion or revolt, or set its government by hand."
	if(!check_rights(R_ADMIN)) return
	var/mob/requester = usr
	if(!requester || !requester.client) return
	if(!nations_enabled())
		to_chat(requester, SPAN_WARNING("Nations are not enabled on this server."))
		return
	nations_refresh()
	var/list/names = list()
	for(var/nid in nation_registry)
		names["[nation_registry[nid]["name"]] ([nid])"] = nid
	if(!names.len)
		to_chat(requester, "No nations have been founded yet.")
		return
	var/nid = names[WWinput(requester, "Which nation?", "Nations", "Cancel", names + "Cancel")]
	if(!nid || !islist(nation_registry[nid]))
		return
	to_chat(requester, nation_staff_report(nid))
	var/list/N = nation_registry[nid]
	var/list/acts = list(N["frozen"] ? "Thaw" : "Freeze")
	if(length(N["motions"]))
		acts += "Void a motion"
	if(nation_revolt_of(nid))
		acts += "Void the revolt petition"
	acts += list("Set the government", "Cancel")
	var/pick = WWinput(requester, "What should staff do with [N["name"]]?", "Nations", "Cancel", acts)
	if(!pick || pick == "Cancel" || !check_rights(R_ADMIN))
		return
	var/list/body = list("op" = "staff", "actor" = requester.ckey, "faction" = N["members"][1])
	switch(pick)
		if("Freeze")
			body["act"] = "freeze"
		if("Thaw")
			body["act"] = "thaw"
		if("Void the revolt petition")
			body["act"] = "void_revolt"
		if("Void a motion")
			var/list/motions = list()
			for(var/list/M in N["motions"])
				motions["[M["id"]]: [nation_motion_label(M)]"] = M["id"]
			var/id = motions[WWinput(requester, "Which motion?", "Nations", "Cancel", motions + "Cancel")]
			if(!isnum(id))
				return
			body["act"] = "void_motion"
			body["motion"] = id
		if("Set the government")
			if(!nation_staff_pick_government(requester, nid, body))
				return
	var/reason = input(requester, "Why? This goes in the nation's staff log.", "Nations") as text|null
	reason = trim(copytext(replacetext(replacetext(reason || "", "\n", " "), "\t", " "), 1, 201))
	for(var/bad in list("<", ">", "&", "\"", "|", ascii2text(13)))
		reason = replacetext(reason, bad, "")
	if(!length(reason) || !check_rights(R_ADMIN))
		return
	body["reason"] = reason
	if(!nation_send(body))
		to_chat(requester, SPAN_WARNING("The coordinator cannot be reached right now. Try again later."))
		return
	log_admin("[key_name(requester)] asked the nations to [body["act"]] [N["name"]] ([nid]): [reason]")
	message_admins("[key_name_admin(requester)] asked the nations to [body["act"]] [html_encode(N["name"])]: [html_encode(reason)]")
	to_chat(requester, SPAN_NOTICE("Sent. You will hear the answer when the lands next confer, within a few minutes."))

// Fills body with a government and its head, from citizens online here.
/proc/nation_staff_pick_government(mob/requester, nid, list/body)
	var/list/kinds = list()
	for(var/kind in nation_government_info)
		kinds[nation_government_info[kind][1]] = kind
	var/kind = kinds[WWinput(requester, "Which government? It takes effect at once, past the era and notice.", "Nations", "Cancel", kinds + "Cancel")]
	if(!kind)
		return FALSE
	body["act"] = "set"
	body["type"] = kind
	if(kind == "confederation")
		return TRUE
	var/list/candidates = list()
	for(var/mob/living/human/H in player_list)
		if(!H.client || !H.civilization || H.civilization == "none" || nation_of_id(nation_faction_id(H.civilization)) != nid)
			continue
		if(!account_verified(H.nation_account()))
			continue
		if(kind == "theocracy" && (!istext(H.religion) || H.religion == "none"))
			continue
		candidates["[H.real_name] of [H.civilization] ([H.nation_account()])"] = H
	if(!candidates.len)
		to_chat(requester, SPAN_WARNING("No citizen of that nation with a verified account[kind == "theocracy" ? " and a faith" : ""] is playing here to head it."))
		return FALSE
	var/mob/living/human/H = candidates[WWinput(requester, "Who heads it?", "Nations", "Cancel", candidates + "Cancel")]
	if(!H || !H.client)
		return FALSE
	body["person"] = H.nation_account()
	body["pname"] = copytext(H.real_name, 1, 65)
	body["pfaction"] = nation_faction_id(H.civilization)
	if(kind == "theocracy")
		body["religion"] = copytext(H.religion, 1, 41)
	return TRUE

/proc/nation_staff_report(nid)
	var/list/N = nation_registry[nid]
	var/list/lines = list("<b>[html_encode(N["name"])]</b> ([nid])", nation_government_line(nid))
	var/list/G = nation_government_of(nid)
	if(istext(G["head_account"]))
		lines += "Head's account: [html_encode(G["head_account"])]."
	if(N["frozen"])
		lines += "<b>Frozen by staff</b>: no changes of government, votes, successors, claims or revolts; the head's absence does not count."
	for(var/list/M in N["motions"])
		lines += "Motion [M["id"]]: [html_encode(nation_motion_label(M))]."
	var/revolt = nation_revolt_line(nid)
	if(revolt)
		var/list/R = nation_revolt_of(nid)
		var/list/signers = list()
		for(var/list/S in R["signers"])
			signers += html_encode("[S["name"]] ([S["account"]])")
		lines += "[revolt] Signers: [jointext(signers, ", ")]."
	for(var/list/E in N["staff_log"])
		lines += "Staff log: [html_encode(E["actor"])] [html_encode(E["act"])], [html_encode(E["detail"])] ([max(0, round((nation_unix_now() - E["at"]) / 3600))] hours ago)."
	return jointext(lines, "<br>")
