// Players remember each other kindly or poorly (hidden karma, karma_ledger.dm).
// Only staff ever see what was given: the rated player is never told, and the
// giver sees only their own list. Giving is for Discord-verified accounts
// (the verified soft whitelist), with no cap on how many players and no
// minimum time; a new giver's ratings simply weigh little.

// The ckey behind a character: the owner of a persistent body, else whoever plays it.
/proc/karma_character_ckey(mob/living/human/H)
	if (!istype(H))
		return null
	var/owner = owner_key_account(H.persistence_owner_ckey)
	if (istext(owner) && length(owner))
		return ckey(owner)
	if (H.ckey)
		return H.ckey
	return null

// Why this client may not give karma now, or null.
/proc/karma_giver_refusal(client/C)
	if (!C)
		return "You cannot do that."
	if (IsGuestKey(C.key))
		return "Sign in to BYOND first."
	if (!verified_discord_id(C.ckey))
		return "Only Discord-verified accounts can do this. Use OOC > Verify Discord first."
	if (karma_barred(C.ckey))
		return "You cannot do that."
	return null

// Why this character may not be remembered by this client, or null.
/proc/karma_target_refusal(client/C, mob/living/human/H)
	var/target = karma_character_ckey(H)
	if (!target || is_agent_account(target))
		return "You can only remember other players."
	if (target == C.ckey)
		return "You cannot remember yourself."
	if (H.stat == DEAD)
		return "You can only remember the living."
	return null

/mob/living/human/verb/karma_remember()
	set name = "Remember"
	set category = null
	set desc = "Privately remember this person kindly or poorly. Only staff ever see it."
	set src in view()
	var/client/C = usr.client
	if (!C || !ismob(usr) || usr == src)
		return
	var/refusal = karma_giver_refusal(C) || karma_target_refusal(C, src)
	if (refusal)
		to_chat(usr, SPAN_WARNING(refusal))
		return
	var/target = karma_character_ckey(src)
	var/list/given = karma_given(C.ckey)
	var/list/before = given[target]
	var/choice = player_input(usr, "How will you remember [name]? Nobody but staff will ever know.[before ? " (Now: [before["kind"]].)" : ""]", "Remember", null, "anything", list("Kindly", "Poorly"), TRUE)
	if (!choice)
		return
	var/note = player_input(usr, "Add a private note for staff if you like (optional, up to 1000 characters).", "Remember", before && istext(before["note"]) ? html_decode(before["note"]) : "", "message", null, TRUE)
	if (isnull(note))
		return
	// Checked again: the prompts can stay open a long time.
	refusal = karma_giver_refusal(C) || (QDELETED(src) ? "They are gone." : karma_target_refusal(C, src))
	if (refusal)
		to_chat(usr, SPAN_WARNING(refusal))
		return
	var/shared_cid = client && C.computer_id && client.computer_id == C.computer_id
	var/faction = ""
	var/mob/living/human/giver = usr
	if (istype(giver))
		faction = istext(giver.civilization) && giver.civilization != "none" ? giver.civilization : ""
	var/result = karma_rate(C.ckey, target, choice == "Kindly" ? "kindly" : "poorly", note, faction, shared_cid)
	if (istext(result))
		to_chat(usr, SPAN_WARNING(result))
		return
	to_chat(usr, SPAN_NOTICE("You will remember [name] [choice == "Kindly" ? "kindly" : "poorly"]."))

// -- the giver's own list -----------------------------------------------------

var/global/datum/karma_notes_window/karma_notes_window = new

/datum/karma_notes_window/proc/show(client/C)
	if (!C)
		return
	var/list/given = karma_given(C.ckey)
	var/html = "<h3>People you remember</h3><p>Only staff ever see these. Change how you remember someone, edit your note, or forget them.</p>"
	if (!length(given))
		html += "<p><i>You have not remembered anyone yet. Right-click a person and choose Remember.</i></p>"
	else
		html += "<table width='100%'><tr><th align='left'>Player</th><th align='left'>How</th><th align='left'>Your note</th><th></th></tr>"
		for (var/target in sortList(given.Copy()))
			var/list/row = given[target]
			html += "<tr><td>[html_encode(target)]</td><td>[html_encode("[row["kind"]]")]</td><td>[length(row["note"]) ? row["note"] : "<i>none</i>"]</td>"
			html += "<td><a href='?src=\ref[src];karma_edit=[url_encode(target)]'>Change</a> <a href='?src=\ref[src];karma_forget=[url_encode(target)]'>Forget</a></td></tr>"
		html += "</table>"
	show_browse(C, html, "window=karma_notes;size=560x420")

/datum/karma_notes_window/Topic(href, list/href_list)
	var/client/C = usr ? usr.client : null
	if (!C)
		return
	var/target = ckey(href_list["karma_edit"] || href_list["karma_forget"])
	if (!length(target) || target == C.ckey)
		return
	var/list/received = karma_received(target)
	var/list/record = received[C.ckey]
	if (!islist(record))
		to_chat(C, SPAN_WARNING("You do not remember [target]."))
		show(C)
		return
	if (href_list["karma_forget"])
		if (player_input(C.mob, "Forget how you remember [target]?", "Remember", "No", "anything", list("Yes", "No"), TRUE) == "Yes" && shared_records.revoke(record, C.ckey, "Player", "forgotten by the giver"))
			to_chat(C, SPAN_NOTICE("You no longer remember [target] either way."))
		show(C)
		return
	var/refusal = karma_giver_refusal(C)
	if (refusal)
		to_chat(C, SPAN_WARNING(refusal))
		return
	var/list/body = record["body"]
	var/choice = player_input(C.mob, "How do you remember [target]?", "Remember", body["rating"] == "kindly" ? "Kindly" : "Poorly", "anything", list("Kindly", "Poorly"), TRUE)
	if (!choice)
		return
	var/note = player_input(C.mob, "Your private note for staff (optional).", "Remember", istext(body["note"]) ? html_decode(body["note"]) : "", "message", null, TRUE)
	if (isnull(note))
		return
	var/result = karma_rate(C.ckey, target, choice == "Kindly" ? "kindly" : "poorly", note, body["faction"], body["shared_cid"])
	if (istext(result))
		to_chat(C, SPAN_WARNING(result))
	show(C)

/client/verb/karma_notes()
	set name = "People I Remember"
	set category = "OOC"
	set desc = "See and change how you remember other players. Only staff ever see it."
	var/refusal = karma_giver_refusal(src)
	if (refusal && !length(karma_given(ckey)))
		to_chat(src, SPAN_WARNING(refusal))
		return
	karma_notes_window.show(src)
