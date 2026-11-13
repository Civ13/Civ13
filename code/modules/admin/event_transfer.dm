// Event Transfer (Admin tab): the admin side of event regions
// (code/modules/persistence/region_event.dm, docs/event-regions.md). In a home
// land it sends players to an event region, lists who is away and can bring
// their characters back; in the event region it sends players home.

/datum/admins/proc/event_transfer()
	set category = "Admin"
	set name = "Event Transfer"
	set desc = "Send everyone or chosen players to an event region and back. Their characters here are kept safe and unchanged while they are away."
	if(!check_rights(R_ADMIN)) return
	var/mob/requester = usr
	if(!requester || !requester.client) return
	if(!shard_group.enabled)
		to_chat(requester, SPAN_WARNING("This server is not part of a region group."))
		return
	if(region_event_world())
		region_event_send_home_panel(requester)
		return
	var/list/away = event_stashes()
	var/list/choices = list()
	if(region_event_peers().len) choices += "Send players to an event"
	if(away.len)
		choices += "List players away ([away.len])"
		choices += "Bring characters back now"
	choices += "Close"
	if(choices.len == 1)
		to_chat(requester, SPAN_WARNING("This group has no event region, and nobody from here is away at one. Add a region of kind EVENT to the group (docs/event-regions.md)."))
		return
	var/choice = WWinput(requester, "Event transfers: players sent to an event region keep their character here, saved and out of play, until they come back.", "Event Transfer", "Close", choices)
	if(!choice || choice == "Close" || !check_rights(R_ADMIN)) return
	if(choice == "Send players to an event")
		region_event_send_panel(requester)
	else if(findtext(choice, "List players away") == 1)
		var/list/lines = list("<b>Away at an event:</b>")
		for(var/obj/structure/event_stash/S in away)
			var/mob/living/human/H = S.body()
			lines += "[html_encode(S.owner_ckey)]: [H ? html_encode(H.real_name) : "(no character)"] at [html_encode(region_event_name(S.event_region))], returns [S.return_mode == "bed" ? "to their bed" : "where they stood"]"
		to_chat(requester, jointext(lines, "<br>"))
	else if(choice == "Bring characters back now")
		region_event_release_panel(requester, away)

/proc/region_event_mode_choice(mob/requester)
	var/answer = WWinput(requester, "When they come back, where should their characters return?", "Return to", "Where they stood", list("Where they stood", "Their bed"))
	if(!answer) return null
	return answer == "Their bed" ? "bed" : "spot"

// Picks clients: everyone, or one at a time until Done.
/proc/region_event_pick_clients(mob/requester, list/pool, title)
	var/everyone = WWinput(requester, "Who?", title, "Everyone", list("Everyone", "Choose players", "Cancel"))
	if(!everyone || everyone == "Cancel") return null
	if(everyone == "Everyone") return pool.Copy()
	var/list/picked = list()
	while(TRUE)
		var/list/options = list()
		for(var/client/C in pool)
			if(!(C in picked)) options["[C.key][C.mob && C.mob.real_name ? " ([C.mob.real_name])" : ""]"] = C
		if(!options.len) break
		var/pick = input(requester, "Add a player ([picked.len] chosen). Cancel when done.", title) as null|anything in options
		if(!pick) break
		picked += options[pick]
	return picked.len ? picked : null

/proc/region_event_send_panel(mob/requester)
	var/list/events = region_event_peers()
	var/event_id
	if(events.len == 1)
		event_id = events[1]
	else
		var/list/names = list()
		for(var/id in events) names[events[id]] = id
		var/pick = input(requester, "Which event region?", "Event Transfer") as null|anything in names
		if(!pick) return
		event_id = names[pick]
	var/list/pool = list()
	for(var/client/C in clients) pool += C
	var/list/picked = region_event_pick_clients(requester, pool, "Send to [region_event_name(event_id)]")
	if(!picked) return
	var/mode = region_event_mode_choice(requester)
	if(!mode) return
	if(WWinput(requester, "Send [picked.len] player\s to [region_event_name(event_id)]? Their characters here leave play, saved as they are, and come back [mode == "bed" ? "beside their bed (where they stood if they have none)" : "where they stood"] unless the send-back says otherwise.", "Event Transfer", "No", list("Send", "No")) != "Send") return
	if(!check_rights(R_ADMIN)) return
	region_event_send(requester, picked, event_id, mode)

/proc/region_event_release_panel(mob/requester, list/away)
	var/list/options = list("Everyone away")
	for(var/obj/structure/event_stash/S in away) options += S.owner_ckey
	var/pick = input(requester, "Bring whose character back into play now? Use this when a player will not come back from the event (for example it closed). A player who rejoins later takes their character from where it returned.", "Bring back") as null|anything in options
	if(!pick || !check_rights(R_ADMIN)) return
	var/mode = region_event_mode_choice(requester)
	if(!mode) return
	var/count = 0
	for(var/obj/structure/event_stash/S in event_stashes())
		if(pick != "Everyone away" && S.owner_ckey != pick) continue
		if(S.release(mode)) count++
	log_admin("[key_name(requester)] brought [count] event character\s back into play here ([mode]).")
	message_admins("[key_name_admin(requester)] brought [count] event character\s back into play.")

/proc/region_event_send_home_panel(mob/requester)
	var/list/pool = list()
	for(var/client/C in clients) pool += C
	var/list/picked = region_event_pick_clients(requester, pool, "Send players home")
	if(!picked) return
	var/mode = region_event_mode_choice(requester)
	if(!mode) return
	if(WWinput(requester, "Send [picked.len] player\s home, [mode == "bed" ? "beside their bed (where they stood if they have none)" : "where they stood"]?", "Event Transfer", "No", list("Send home", "No")) != "Send home") return
	if(!check_rights(R_ADMIN)) return
	region_event_send_home(requester, picked, mode)
