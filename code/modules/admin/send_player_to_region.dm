// Send Player to Region (Admin tab): the admin side of
// code/modules/persistence/region_admin_send.dm (docs/region-admin-send.md).
// Choose players or the ship one is aboard, a region and a landing; the dry
// run is shown in chat before anything is sent.

/datum/admins/proc/send_player_to_region()
	set category = "Admin"
	set name = "Send Player to Region"
	set desc = "Send players, or the ship they are aboard, to another region of this group with everything they carry. Shows a dry run first."
	if(!check_rights(R_ADMIN)) return
	var/mob/requester = usr
	if(!requester || !requester.client) return
	if(!shard_group.enabled)
		to_chat(requester, SPAN_WARNING("This server is not part of a region group."))
		return
	var/what = WWinput(requester, "Who goes? Players keep everything they wear and carry, their skills, research and languages, exactly as on a trail.", "Send Player to Region", "Cancel", list("Online players", "A character by account", "The ship a player is aboard", "Recent transfers", "Cancel"))
	if(!what || what == "Cancel") return
	if(what == "Recent transfers")
		var/list/lines = list("<b>Recent region transfers here:</b>")
		for(var/list/note in region_admin_send_recent)
			lines += html_encode(note["text"])
		if(lines.len == 1) lines += "None since this world started."
		to_chat(requester, jointext(lines, "<br>"))
		return
	var/ship = what == "The ship a player is aboard"
	var/list/bodies = what == "A character by account" ? region_admin_send_pick_account(requester) : region_admin_send_pick_online(requester, ship)
	if(!length(bodies)) return
	var/list/places = region_admin_send_destinations()
	if(!places.len)
		to_chat(requester, SPAN_WARNING("This group has no other region to send anyone to."))
		return
	var/place = input(requester, "Send them to which region?", "Send Player to Region") as null|anything in places
	if(!place) return
	var/id = places[place]
	var/list/landing = list("landing" = "arrival", "by" = requester.ckey)
	if(!ship)
		var/how = WWinput(requester, "Where should they land in [place]?", "Landing", "Nearest dry shore", list("Nearest dry shore", "Exact coordinates", "Normal arrival point", "Cancel"))
		if(!how || how == "Cancel") return
		var/at_text = null
		if(how == "Exact coordinates")
			var/turf/here = get_turf(requester)
			at_text = input(requester, "Coordinates in [place], as x,y,z. Unsafe tiles move to the nearest safe floor close by.", "Landing", here ? "[here.x],[here.y],[here.z]" : "") as null|text
			if(!at_text) return
		var/mode = how == "Nearest dry shore" ? "shore" : (how == "Exact coordinates" ? "coords" : "arrival")
		landing = region_admin_send_landing(mode, at_text, requester.ckey)
		if(istext(landing))
			to_chat(requester, SPAN_WARNING(landing))
			return
	var/list/rows = region_admin_send_preflight(bodies, id, landing, ship)
	to_chat(requester, region_admin_send_report_html(rows, id, landing, ship))
	var/list/ready = list()
	for(var/i = 1 to rows.len)
		var/list/row = rows[i]
		if(row["ok"]) ready += bodies[i]
	if(!ready.len)
		to_chat(requester, SPAN_WARNING("Nobody can be sent now. See the dry run above."))
		return
	if(WWinput(requester, "Send [ready.len] of [bodies.len] to [place] now? The dry run is in your chat.", "Send Player to Region", "No", list("Send", "No")) != "Send") return
	if(!check_rights(R_ADMIN)) return
	if(region_admin_send_running)
		to_chat(requester, SPAN_WARNING("Another region transfer is still running here. Try again when it finishes."))
		return
	// Hold them still, then check again: the prompt waited on the admin.
	var/list/checked = region_admin_send_hold_and_check(ready, id, landing, ship)
	ready = checked["ready"]
	for(var/list/row in checked["rows"])
		if(!row["ok"])
			to_chat(requester, SPAN_WARNING("No longer ready: [html_encode(row["ckey"])] ([html_encode(row["name"])]): [html_encode(row["reason"])]"))
	if(!ready.len)
		to_chat(requester, SPAN_WARNING("Nobody can be sent now: everyone changed since the dry run."))
		return
	log_admin("[key_name(requester)] started a region transfer of [ready.len] character\s to [id].")
	region_admin_send_run(ready, id, landing, ship, requester.ckey, requester)

/proc/region_admin_send_pick_online(mob/requester, ship)
	var/list/picked = list()
	while(TRUE)
		var/list/options = list()
		for(var/client/C in clients)
			var/mob/living/human/H = C.mob
			if(istype(H) && !(H in picked)) options["[C.key] ([H.real_name])"] = H
		if(!options.len) break
		var/pick = input(requester, ship ? "Whose ship? Pick a player aboard her." : "Add a player ([picked.len] chosen). Cancel when done.", "Send Player to Region") as null|anything in options
		if(!pick) break
		picked += options[pick]
		if(ship) break
	return picked

/proc/region_admin_send_pick_account(mob/requester)
	var/account = ckey(input(requester, "Account (ckey) whose character goes. Offline characters wait at the destination for their player.", "Send Player to Region") as null|text)
	if(!account) return null
	for(var/mob/living/human/H in human_mob_list)
		if(QDELETED(H) || H.stat == DEAD) continue
		if((H.client && H.client.ckey == account) || (!H.client && H.persistence_owner_ckey == account))
			return list(H)
	to_chat(requester, SPAN_WARNING("No living character of [account] is in this land."))
	return null
