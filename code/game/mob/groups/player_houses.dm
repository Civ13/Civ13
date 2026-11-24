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

/proc/player_house_offer_valid(mob/living/human/H, mob/living/human/target, id)
	return player_house_feature() && !persistence_admission_blocked() && player_house_actor(H) && player_house_actor(target) && H != target && H.z == target.z && get_dist(H, target) <= PLAYER_HOUSE_INVITE_RANGE && map.player_house_role(H, id) == "steward" && !map.player_house_of(target)

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
	if(role != "steward" || !(choice in list("Invite Member", "Appoint Co-steward")) || roster.len >= PLAYER_HOUSE_ROSTER_LIMIT)
		return
	var/list/candidates = list()
	for(var/mob/living/human/target in oview(PLAYER_HOUSE_INVITE_RANGE, src))
		if(player_house_offer_valid(src, target, id) && !target.player_house_offer_pending)
			candidates += target
	if(!candidates.len)
		return
	var/mob/living/human/target = WWinput(src, "Choose a nearby character:", "Player Houses", null, candidates)
	if(land != map || persistence_admission_changed(save_identity) || !player_house_offer_valid(src, target, id) || target.player_house_offer_pending || world.time < player_house_offer_next)
		return
	var/offer_role = choice == "Appoint Co-steward" ? "steward" : "member"
	var/inviter_life = player_house_life_id
	var/client/invitee = target.client
	var/invitee_life_generation = target.player_house_life_generation
	player_house_offer_next = world.time + 100
	target.player_house_offer_pending = TRUE
	var/answer = WWinput(target, "Join House [house["name"]] as a [offer_role]?", "House Invitation", "No", list("Yes", "No"))
	if(!target || QDELETED(target))
		return
	target.player_house_offer_pending = FALSE
	if(answer != "Yes" || land != map || persistence_admission_changed(save_identity) || inviter_life != player_house_life_id || invitee != target.client || invitee_life_generation != target.player_house_life_generation)
		return
	if(!player_house_offer_valid(src, target, id) || roster.len >= PLAYER_HOUSE_ROSTER_LIMIT)
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

// Operations and company stock are separate. Historical unchartered
// companies keep their shareholder-operated workflow until explicitly bound.
/obj/map_metadata/proc/company_controlling_house(company)
	if (!company || company == "Global")
		return null
	for (var/id in player_houses_state)
		var/list/house = player_houses_state[id]
		if (!islist(house))
			continue
		var/list/charters = house["companies"]
		if (islist(charters) && charters[company] == TRUE)
			return id
	return null

/obj/map_metadata/proc/company_attach_house(company, id)
	if (src != map || !player_house_feature() || !company || company == "Global" || company_controlling_house(company) || persistence_admission_blocked())
		return FALSE
	var/list/house = player_houses_state[id]
	if (!islist(house))
		return FALSE
	var/list/charters = house["companies"]
	if (!islist(charters))
		charters = list()
		house["companies"] = charters
	charters[company] = TRUE
	return TRUE

/proc/company_may_operate(mob/living/human/H, company)
	if (!map)
		return FALSE
	var/id = map.company_controlling_house(company)
	if (!id)
		return find_company_member(H, company)
	return player_house_actor(H) && map.player_house_role(H, id) == "steward"

/mob/living/human/proc/charter_existing_company()
	set category = "Faction"
	set name = "Charter Existing Company"
	if (!player_house_feature() || !player_house_actor(src) || persistence_admission_blocked())
		return
	var/obj/map_metadata/land = map
	var/datum/save_identity = persistence_admission_identity
	var/house_id = land.player_house_of(src)
	if (!house_id || land.player_house_role(src, house_id) != "steward")
		return
	var/list/eligible = list()
	for (var/company in land.custom_company_nr)
		if (!land.company_controlling_house(company) && company_has_stake(company, src, 100))
			eligible += company
	if (!eligible.len)
		to_chat(src, SPAN_NOTICE("You have no unchartered companies in which you hold all the stock."))
		return
	var/company = WWinput(src, "Which company do you want your house to control?", "Company Charter", "Cancel", eligible + "Cancel")
	if (!(company in eligible) || land != map || !player_house_actor(src) || land.player_house_role(src, house_id) != "steward" || persistence_admission_changed(save_identity) || !company_has_stake(company, src, 100))
		return
	var/list/house = land.player_houses_state[house_id]
	if (WWinput(src, "Give House [house["name"]] control of [company]'s operations? This does not transfer its stock or any balances.", "Company Charter", "No", list("Yes", "No")) != "Yes")
		return
	if (land != map || persistence_admission_changed(save_identity) || !player_house_actor(src) || land.player_house_role(src, house_id) != "steward" || !company_has_stake(company, src, 100) || !(company in land.custom_company_nr))
		return
	if (land.company_attach_house(company, house_id))
		to_chat(src, SPAN_NOTICE("Your house now controls [company]'s operations. No shares changed hands."))

#undef PLAYER_HOUSE_LIMIT
#undef PLAYER_HOUSE_ROSTER_LIMIT
#undef PLAYER_HOUSE_INVITE_RANGE
