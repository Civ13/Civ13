// Houses are determined by the authenticated persistence account, not by
// a character's name, faction, slot number, or historical invitation.
#define PLAYER_HOUSE_LIMIT 256

/obj/map_metadata/var/list/player_houses_state = list()
// Keep old character save tokens for evidence only. Never authorize with them.
/mob/living/human/var/player_house_life_id = null

/proc/player_house_feature()
	return map && map.persistence && (map.nomads || map.civilizations) && map.uses_durable_metadata()

/proc/player_house_account(mob/living/human/H)
	if(!istype(H) || QDELETED(H) || H.stat != CONSCIOUS || H.restrained() || !H.client || H.client.mob != H || IsGuestKey(H.client.key))
		return null
	var/client/C = H.client
	var/slot_owner = H.persistence_owner_ckey
	if(!persistence_owner_valid(slot_owner) || slot_owner != C.owner_key())
		return null
	var/account = owner_key_account(slot_owner)
	return account && account == C.ckey ? account : null

/obj/map_metadata/proc/player_house_bound_id(account)
	if(!istext(account) || !length(account) || owner_key_slot(account) != 1 || ckey(account) != account || persistence_guest_account(account))
		return null
	var/found
	for(var/id in player_houses_state)
		var/list/house = player_houses_state[id]
		if(!islist(house) || house["owner_ckey"] != account)
			continue
		if(found)
			return null
		found = id
	return found

/obj/map_metadata/proc/player_house_of(mob/living/human/H)
	if(src != map || !player_house_feature())
		return null
	return player_house_bound_id(player_house_account(H))

/obj/map_metadata/proc/player_house_found(mob/living/human/H, house_name)
	var/account = player_house_account(H)
	if(src != map || !player_house_feature() || !account || persistence_admission_blocked() || length(player_houses_state) >= PLAYER_HOUSE_LIMIT)
		return FALSE
	house_name = trim(sanitize(house_name, 41, FALSE))
	if(!length(house_name))
		return FALSE
	for(var/id in player_houses_state)
		var/list/house = player_houses_state[id]
		if(islist(house) && (house["owner_ckey"] == account || lowertext(house["name"]) == lowertext(house_name)))
			return FALSE
	var/house_id = md5("account-house|[account]|[world.realtime]|[length(player_houses_state)]")
	if(house_id in player_houses_state)
		return FALSE
	player_houses_state[house_id] = list("name" = house_name, "owner_ckey" = account)
	return TRUE

/mob/living/human/proc/player_houses_menu()
	set name = "Player Houses"
	set category = "Faction"
	var/account = player_house_account(src)
	if(!player_house_feature() || !account)
		return
	var/obj/map_metadata/land = map
	var/id = land.player_house_of(src)
	if(id)
		var/list/house = land.player_houses_state[id]
		to_chat(src, SPAN_NOTICE("House [html_encode(house["name"])] belongs to your account. All characters you own share it in this region."))
		return
	var/datum/save_identity = persistence_admission_identity
	var/slot_owner = persistence_owner_ckey
	var/house_name = player_input(src, "Name your account's house in this region. Older houses without a verified account owner cannot be claimed here.", "Register Player House", null, "text", null, TRUE)
	if(!house_name || land != map || persistence_admission_changed(save_identity) || slot_owner != persistence_owner_ckey || player_house_account(src) != account)
		return
	if(land.player_house_found(src, house_name))
		to_chat(src, SPAN_NOTICE("Your account's house has been registered in this region."))
	else
		to_chat(src, SPAN_WARNING("That house could not be registered. Check the name or contact staff if you are affected by an older charter."))

// Operations and company stock are separate. Historical unchartered
// companies keep their shareholder-operated workflow until explicitly bound.
/obj/map_metadata/proc/company_controlling_house(company)
	if (!company || company == "Global")
		return null
	var/found
	for (var/id in player_houses_state)
		var/list/house = player_houses_state[id]
		if (!islist(house))
			continue
		var/list/charters = house["companies"]
		if (islist(charters) && charters[company] == TRUE)
			if (found)
				return "conflicted"
			found = id
	return found

/obj/map_metadata/proc/company_attach_house(company, id, mob/living/human/H)
	if (src != map || !player_house_feature() || !id || player_house_of(H) != id || !company || company == "Global" || company_controlling_house(company) || persistence_admission_blocked())
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
	return id != "conflicted" && map.player_house_of(H) == id

/mob/living/human/proc/charter_existing_company()
	set category = "Faction"
	set name = "Charter Existing Company"
	if (!player_house_feature() || !player_house_account(src) || persistence_admission_blocked())
		return
	var/obj/map_metadata/land = map
	var/datum/save_identity = persistence_admission_identity
	var/house_id = land.player_house_of(src)
	if (!house_id)
		to_chat(src, SPAN_NOTICE("Register your account's house in Player Houses first. Older charters cannot be claimed without verifying their owner."))
		return
	var/list/eligible = list()
	for (var/company in land.custom_company_nr)
		if (!land.company_controlling_house(company) && company_has_stake(company, src, 100))
			eligible += company
	if (!eligible.len)
		to_chat(src, SPAN_NOTICE("No unchartered company in which you hold all the stock is available. If an older charter is already linked, contact staff; share ownership is unchanged."))
		return
	var/company = WWinput(src, "Which company do you want your house to control?", "Company Charter", "Cancel", eligible + "Cancel")
	if (!(company in eligible) || land != map || land.player_house_of(src) != house_id || persistence_admission_changed(save_identity) || !company_has_stake(company, src, 100))
		return
	var/list/house = land.player_houses_state[house_id]
	if (WWinput(src, "Give House [house["name"]] control of [company]'s operations? This does not transfer its stock or any balances.", "Company Charter", "No", list("Yes", "No")) != "Yes")
		return
	if (land != map || persistence_admission_changed(save_identity) || land.player_house_of(src) != house_id || !company_has_stake(company, src, 100) || !(company in land.custom_company_nr))
		return
	if (land.company_attach_house(company, house_id, src))
		to_chat(src, SPAN_NOTICE("Your house now controls [company]'s operations. No shares changed hands."))

#undef PLAYER_HOUSE_LIMIT
