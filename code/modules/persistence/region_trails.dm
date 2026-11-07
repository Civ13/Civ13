// Player-built trails (tools/transfer_storage/README.md, "Player-built trails").
// Anyone can build a trail marker from wood. It starts closed: the first player
// to use it picks the land it should lead to, which asks the admins, and it
// opens only once an admin approves it (and may change where it leads). Admins
// see waiting markers under OOC > Regions and in the admin log. Ferries and
// other player-made routes can reuse the same approval later.

#define REGION_TRAIL_REQUEST_COOLDOWN 6000 // deciseconds between one player's requests
#define REGION_TRAIL_PENDING_MAX 3 // unanswered requests one player may have

// ckey = world.time of that player's next allowed request. Runtime only.
var/global/list/region_trail_next_request = list()

/obj/structure/region_gate/trail_marker
	name = "trail marker"
	desc = "A post marking out a new trail toward distant lands."
	icon = 'icons/obj/structures.dmi'
	icon_state = "propstall1"
	map_storage_saved_vars = "icon_state;dir;name;pixel_x;pixel_y;destination;approved;requested_destination;requester_ckey;approved_by"
	// Opens only after an admin approves it.
	var/approved = FALSE
	var/requested_destination = null
	var/requester_ckey = null
	var/approved_by = null

/obj/structure/region_gate/trail_marker/proc/peer_choices()
	var/list/choices = list()
	if(!shard_group.enabled) return choices
	for(var/id in shard_group.peers)
		var/list/peer = shard_group.peers[id]
		// The rail yard is reached only by a party's own train (party_train.dm).
		if(peer["kind"] == "RAILYARD") continue
		// Orbit is reached only by rocket.
		if(peer["kind"] == "ORBIT") continue
		choices["[peer["name"]] ([id])"] = id
	return choices

/obj/structure/region_gate/trail_marker/closed_reason()
	if(!approved)
		if(requested_destination)
			return "The trail toward [region_trail_name(requested_destination)] is marked out, but nobody has cleared it yet. An admin must approve it."
		return "The trail is only marked out. Use it to choose where it should lead; an admin must approve it before anyone can travel."
	return ..()

// An unapproved marker anyone built must not catch arriving travellers.
/obj/structure/region_gate/trail_marker/accepts_arrivals()
	return approved

/obj/structure/region_gate/trail_marker/attack_hand(mob/living/human/user)
	if(!istype(user) || !user.client) return
	if(approved)
		return ..()
	request(user)

// A player asks for this marker to lead somewhere; admins decide.
/obj/structure/region_gate/trail_marker/proc/request(mob/living/human/user)
	if(!shard_group.enabled)
		to_chat(user, SPAN_WARNING("No other lands are known from here."))
		return
	if(IsGuestKey(user.client.key))
		to_chat(user, SPAN_WARNING("Only players with a BYOND account can mark out a trail."))
		return
	var/reason = request_refusal(user.client.ckey)
	if(reason)
		to_chat(user, SPAN_NOTICE(reason))
		return
	var/list/choices = peer_choices()
	if(!length(choices))
		to_chat(user, SPAN_WARNING("No other lands are known from here."))
		return
	var/choice = input(user, "Which land should this trail lead to? An admin must approve it before it opens.", "Trail marker") as null|anything in choices
	if(!choice || QDELETED(src) || !user.client || !Adjacent(user)) return
	// The prompt slept: someone else may have asked meanwhile.
	reason = request_refusal(user.client.ckey)
	if(reason)
		to_chat(user, SPAN_NOTICE(reason))
		return
	requested_destination = choices[choice]
	requester_ckey = user.client.ckey
	region_trail_next_request[requester_ckey] = world.time + REGION_TRAIL_REQUEST_COOLDOWN
	to_chat(user, SPAN_NOTICE("You mark out a trail toward [region_trail_name(requested_destination)]. It opens once an admin approves it."))
	log_game("Region trail: [requester_ckey] asked for a trail at [x],[y],[z] to [requested_destination].")
	message_admins("[key_name_admin(user)] asks for a trail at [x],[y],[z] to [html_encode(region_trail_name(requested_destination))]. [admin_links()]")

// Null when ckey may ask for this marker now, otherwise why not. Only the
// player who asked may change an unanswered request; each player waits between
// requests and has only a few unanswered at once.
/obj/structure/region_gate/trail_marker/proc/request_refusal(ckey)
	if(approved) return "This trail is already open."
	if(requested_destination && requester_ckey != ckey)
		return closed_reason()
	if(world.time < region_trail_next_request[ckey])
		return "You marked out a trail recently. Wait a while before asking again."
	var/pending = 0
	for(var/obj/structure/region_gate/trail_marker/T in region_gates)
		if(T != src && !T.approved && T.requested_destination && T.requester_ckey == ckey && !QDELETED(T))
			pending++
	if(pending >= REGION_TRAIL_PENDING_MAX)
		return "You already have [pending] trails waiting for an admin."
	return null

/obj/structure/region_gate/trail_marker/proc/admin_links()
	var/at = "trail_at=[x],[y],[z]"
	return "<a href='?src=\ref[src];trail=approve;[at]'>Approve</a> | <a href='?src=\ref[src];trail=reject;[at]'>Reject</a> | <a href='?_src_=holder;adminplayerobservecoodjump=1;X=[x];Y=[y];Z=[z]'>Jump</a>"

/obj/structure/region_gate/trail_marker/Topic(href, href_list)
	if(!href_list["trail"]) return ..()
	if(!check_rights(R_ADMIN)) return
	// A link outlives its marker; a reused reference must not act elsewhere.
	if(href_list["trail_at"] != "[x],[y],[z]")
		to_chat(usr, SPAN_WARNING("That trail marker is gone."))
		return
	switch(href_list["trail"])
		if("approve")
			admin_approve(usr)
		if("reject")
			admin_reject(usr)

// The admin confirms (or changes) where the trail leads, then it opens.
/obj/structure/region_gate/trail_marker/proc/admin_approve(mob/admin)
	if(QDELETED(src)) return
	var/list/choices = peer_choices()
	if(!length(choices))
		to_chat(admin, SPAN_WARNING("This server is not in a region group, so the trail cannot lead anywhere."))
		return
	var/current = null
	for(var/label in choices)
		if(choices[label] == requested_destination)
			current = label
	var/choice = input(admin, "Where should this trail lead?", "Approve trail", current) as null|anything in choices
	if(!choice || QDELETED(src) || !check_rights(R_ADMIN, TRUE, admin)) return
	if(approve(choices[choice], admin.ckey))
		message_admins("[key_name_admin(admin)] approved the trail at [x],[y],[z] to [html_encode(destination_name())].")

// Opens the trail toward a known peer. Returns TRUE when it did.
/obj/structure/region_gate/trail_marker/proc/approve(id, by)
	if(!shard_group.enabled || !istext(id) || !(id in shard_group.peers)) return FALSE
	destination = id
	requested_destination = id
	approved = TRUE
	approved_by = by
	log_admin("[by] approved the trail at [x],[y],[z] to [id] (asked by [requester_ckey || "nobody"]).")
	visible_message(SPAN_NOTICE("The trail toward [destination_name()] is cleared and ready to travel."))
	return TRUE

// Clears a request, or closes an approved trail again.
/obj/structure/region_gate/trail_marker/proc/admin_reject(mob/admin)
	if(QDELETED(src) || !requested_destination && !approved) return
	log_admin("[key_name(admin)] rejected the trail at [x],[y],[z] to [requested_destination || "nowhere"] (asked by [requester_ckey || "nobody"]).")
	message_admins("[key_name_admin(admin)] rejected the trail at [x],[y],[z].")
	approved = FALSE
	destination = null
	requested_destination = null
	requester_ckey = null
	visible_message(SPAN_WARNING("The marked trail fades; nobody will clear it."))

/proc/region_trail_name(id)
	var/list/peer = shard_group.enabled ? shard_group.peers[id] : null
	return peer ? peer["name"] : "[id]"

// Admin rows for the Regions panel: markers waiting for approval.
/proc/region_trail_pending_html()
	var/list/rows = list()
	for(var/obj/structure/region_gate/trail_marker/T in region_gates)
		if(T.approved || !T.requested_destination || QDELETED(T)) continue
		rows += "<li>[T.x],[T.y],[T.z] to [html_encode(region_trail_name(T.requested_destination))] (asked by [html_encode(T.requester_ckey)]): [T.admin_links()]</li>"
	if(!length(rows)) return "<p>No trails are waiting for approval.</p>"
	return "<p>Trails waiting for approval:</p><ul>[jointext(rows, "")]</ul>"

#undef REGION_TRAIL_REQUEST_COOLDOWN
#undef REGION_TRAIL_PENDING_MAX
