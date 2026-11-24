// Regional player houses. The map owns charters; neither a display name nor a
// BYOND account/slot can authorize someone to act for a charter.
#define PLAYER_HOUSE_LIMIT 256
#define PLAYER_HOUSE_ROSTER_LIMIT 32
#define PLAYER_HOUSE_INVITE_RANGE 2

/obj/map_metadata/var/list/player_houses_state = list()
/mob/living/human/var/player_house_life_id = null
/mob/living/human/var/tmp/player_house_offer_pending = FALSE
/mob/living/human/var/tmp/player_house_life_generation = 0
/mob/living/human/var/tmp/player_house_offer_next = 0

/proc/player_house_runtime_var(key)
	return key == "player_house_offer_pending" || key == "player_house_offer_next" || key == "player_house_life_generation"

/proc/player_house_feature()
	return map && map.persistence && (map.nomads || map.civilizations) && map.uses_durable_metadata()

/proc/player_house_actor(mob/living/human/H)
	return istype(H) && !QDELETED(H) && H.stat == CONSCIOUS && !H.restrained() && H.client && H.client.mob == H && !IsGuestKey(H.client.key) && H.persistence_owner_ckey == H.client.owner_key()

// Role lookup is keyed by a life token written only on enrollment, not a
// reusable character slot. The house stays in the ledger even without stewards.
/obj/map_metadata/proc/player_house_of(mob/living/human/H)
	if(!istype(H) || QDELETED(H) || H.stat == DEAD || !H.player_house_life_id)
		return null
	for(var/id in player_houses_state)
		var/list/house = player_houses_state[id]
		if(!islist(house))
			continue
		var/list/roster = house["roster"]
		if(islist(roster) && (roster[H.player_house_life_id] in list("steward", "member")))
			return id
	return null

/obj/map_metadata/proc/player_house_role(mob/living/human/H, id)
	if(!istype(H) || QDELETED(H) || H.stat == DEAD || !H.player_house_life_id || !id)
		return null
	var/list/house = player_houses_state[id]
	if(!islist(house))
		return null
	var/list/roster = house["roster"]
	if(!islist(roster))
		return null
	var/role = roster[H.player_house_life_id]
	return (role in list("steward", "member")) ? role : null

/mob/living/human/proc/ensure_player_house_life()
	if(!player_house_life_id)
		player_house_life_id = md5("[world.realtime]|[REF(src)]|[rand(100000, 999999)]|[rand(100000, 999999)]")
	return player_house_life_id

// Called before death can yield. No shared map write is required while saves
// are active. A revived body does not recover its old governing privileges.
/mob/living/human/proc/lose_player_house_authority()
	player_house_life_id = null
	player_house_life_generation++

/obj/map_metadata/proc/player_house_found(mob/living/human/H, house_name)
	if(src != map || !player_house_feature() || !player_house_actor(H) || persistence_admission_blocked() || player_house_of(H) || length(player_houses_state) >= PLAYER_HOUSE_LIMIT)
		return FALSE
	house_name = trim(sanitize(house_name, 41, FALSE))
	if(!length(house_name))
		return FALSE
	for(var/id in player_houses_state)
		var/list/house = player_houses_state[id]
		if(islist(house) && lowertext(house["name"]) == lowertext(house_name))
			return FALSE
	var/life = H.ensure_player_house_life()
	var/house_id = md5("[life]|[world.realtime]|[house_name]")
	if(house_id in player_houses_state)
		return FALSE
	player_houses_state[house_id] = list("name" = house_name, "roster" = list("[life]" = "steward"))
	return TRUE

// An offer's mode must remain the same through consent: a promotion can
// update a full roster, but it must never silently enroll a former member.
/proc/player_house_offer_mode(mob/living/human/H, mob/living/human/target, id, offer_role)
	if(!player_house_feature() || persistence_admission_blocked() || !player_house_actor(H) || !player_house_actor(target) || H == target || H.z != target.z || get_dist(H, target) > PLAYER_HOUSE_INVITE_RANGE || map.player_house_role(H, id) != "steward")
		return null
	var/list/house = map.player_houses_state[id]
	var/list/roster = house["roster"]
	if(!islist(roster))
		return null
	var/target_house = map.player_house_of(target)
	if(target_house)
		if(offer_role == "steward" && target_house == id && map.player_house_role(target, id) == "member")
			return "promote"
		return null
	if(roster.len < PLAYER_HOUSE_ROSTER_LIMIT)
		return "enroll"
	return null

/mob/living/human/proc/player_houses_menu()
	set name = "Player Houses"
	set category = "Faction"
	if(!player_house_feature() || !player_house_actor(src))
		return
	var/obj/map_metadata/land = map
	var/datum/save_identity = persistence_admission_identity
	var/life_generation = player_house_life_generation
	var/id = land.player_house_of(src)
	if(!id)
		var/house_name = player_input(src, "Name your house:", "Found House", null, "text", null, TRUE)
		if(!house_name || land != map || life_generation != player_house_life_generation || persistence_admission_changed(save_identity))
			return
		if(land.player_house_found(src, house_name))
			to_chat(src, SPAN_NOTICE("Your house charter has been registered. Appoint another steward for succession."))
		else
			to_chat(src, SPAN_WARNING("That house could not be registered. Try a different name when the land is not saving."))
		return
	var/list/house = land.player_houses_state[id]
	var/role = land.player_house_role(src, id)
	var/list/options = list("Leave House", "Cancel")
	if(role == "steward")
		options.Insert(1, "Invite Member", "Appoint Co-steward")
	var/choice = WWinput(src, "House [house["name"]]: [role]", "Player Houses", "Cancel", options)
	if(land != map || persistence_admission_changed(save_identity) || !player_house_actor(src) || land.player_house_role(src, id) != role)
		return
	var/list/roster = house["roster"]
	if(choice == "Leave House")
		roster -= player_house_life_id
		to_chat(src, SPAN_NOTICE("You leave the house. Its charter remains in force."))
		return
	if(role != "steward" || !(choice in list("Invite Member", "Appoint Co-steward")))
		return
	var/offer_role = choice == "Appoint Co-steward" ? "steward" : "member"
	var/list/candidates = list()
	var/list/candidate_modes = list()
	for(var/mob/living/human/target in oview(PLAYER_HOUSE_INVITE_RANGE, src))
		var/candidate_mode = player_house_offer_mode(src, target, id, offer_role)
		if(candidate_mode && !target.player_house_offer_pending)
			candidates += target
			candidate_modes[target] = candidate_mode
	if(!candidates.len)
		return
	var/mob/living/human/target = WWinput(src, "Choose a nearby character:", "Player Houses", null, candidates)
	if(land != map || persistence_admission_changed(save_identity) || !target || !(target in candidates))
		return
	var/offer_mode = candidate_modes[target]
	if(player_house_offer_mode(src, target, id, offer_role) != offer_mode || target.player_house_offer_pending || world.time < player_house_offer_next)
		return
	var/inviter_life = player_house_life_id
	var/invitee_life = target.player_house_life_id
	var/client/invitee = target.client
	var/invitee_life_generation = target.player_house_life_generation
	player_house_offer_next = world.time + 100
	target.player_house_offer_pending = TRUE
	var/offer_text = offer_mode == "promote" ? "Become a co-steward of House [house["name"]]?" : "Join House [house["name"]] as a [offer_role]?"
	var/answer = WWinput(target, offer_text, "House Invitation", "No", list("Yes", "No"))
	if(!target || QDELETED(target))
		return
	target.player_house_offer_pending = FALSE
	if(answer != "Yes" || land != map || persistence_admission_changed(save_identity) || inviter_life != player_house_life_id || invitee != target.client || invitee_life_generation != target.player_house_life_generation)
		return
	if(land.player_houses_state[id] != house || house["roster"] != roster || invitee_life != target.player_house_life_id || player_house_offer_mode(src, target, id, offer_role) != offer_mode)
		return
	if(offer_mode == "promote")
		roster[invitee_life] = "steward"
		to_chat(target, SPAN_NOTICE("You are now a co-steward of the house."))
		to_chat(src, SPAN_NOTICE("[target] is now a co-steward of the house."))
		return
	var/life = target.ensure_player_house_life()
	roster[life] = offer_role
	to_chat(target, SPAN_NOTICE("You join the house as a [offer_role]."))
	to_chat(src, SPAN_NOTICE("[target] joined the house as a [offer_role]."))

/obj/map_metadata/proc/player_house_has_active_steward(id)
	for(var/mob/living/human/H in player_list)
		if(player_house_actor(H) && player_house_role(H, id) == "steward")
			return TRUE
	return FALSE

// Explicit, audited local recovery if no steward can act. This changes one
// charter's steward roster only; it cannot assign or edit company stock.
/client/proc/recover_player_house()
	set name = "Recover Player House"
	set category = "Admin"
	if(!check_rights(R_ADMIN) || !mob || !player_house_feature())
		return
	var/mob/requester = mob
	var/obj/map_metadata/land = map
	var/datum/save_identity = persistence_admission_identity
	var/list/options = list()
	for(var/id in land.player_houses_state)
		var/list/house = land.player_houses_state[id]
		if(islist(house))
			options[house["name"]] = id
	if(!options.len)
		return
	var/label = WWinput(requester, "Choose an existing charter:", "Recover Player House", null, options)
	if(!istext(label) || !(label in options))
		return
	var/id = options[label]
	var/list/house = land.player_houses_state[id]
	if(!id || !islist(house) || !check_rights(R_ADMIN) || mob != requester)
		return
	if(land.player_house_has_active_steward(id))
		to_chat(requester, SPAN_WARNING("An active steward can handle succession."))
		return
	var/list/candidates = list()
	for(var/mob/living/human/H in player_list)
		var/membership = land.player_house_of(H)
		if(player_house_actor(H) && (!membership || membership == id) && land.player_house_role(H, id) != "steward")
			candidates += H
	if(!candidates.len)
		return
	var/mob/living/human/recipient = WWinput(requester, "Who will steward House [label]?", "Recover Player House", null, candidates)
	if(!player_house_actor(recipient) || !check_rights(R_ADMIN) || mob != requester)
		return
	var/client/receiver = recipient.client
	var/life_generation = recipient.player_house_life_generation
	var/reason = player_input(requester, "Why is manual succession necessary? This reason is recorded.", "Recover Player House", null, "text", null, TRUE)
	reason = istext(reason) ? trim(sanitize(reason, 240, FALSE)) : null
	if(!reason || !player_house_actor(recipient) || receiver != recipient.client || life_generation != recipient.player_house_life_generation || !check_rights(R_ADMIN) || mob != requester)
		return
	if(WWinput(recipient, "Staff are offering you stewardship of House [label]. Accept?", "House Succession", "No", list("Yes", "No")) != "Yes")
		return
	if(!check_rights(R_ADMIN) || mob != requester || land != map || !player_house_feature() || persistence_admission_changed(save_identity))
		return
	if(!player_house_actor(recipient) || receiver != recipient.client || life_generation != recipient.player_house_life_generation || land.player_houses_state[id] != house)
		return
	var/membership = land.player_house_of(recipient)
	var/list/roster = house["roster"]
	if(land.player_house_has_active_steward(id) || !islist(roster) || (membership && membership != id) || land.player_house_role(recipient, id) == "steward")
		return
	// A staff-authorized recovery can extend a full historical roster. Cap
	// player invitations independently so absent or dead lives can't be reused.
	var/life = recipient.ensure_player_house_life()
	roster[life] = "steward"
	log_admin("[key_name(src)] recovered House [label] ([id]) to [key_name(recipient)]. Reason: [reason]")
	message_admins("[key_name_admin(src)] recovered House [label] to [key_name_admin(recipient)]. Reason: [html_encode(reason)]")
	to_chat(recipient, SPAN_NOTICE("You are now a steward of House [label]."))

#undef PLAYER_HOUSE_LIMIT
#undef PLAYER_HOUSE_ROSTER_LIMIT
#undef PLAYER_HOUSE_INVITE_RANGE
