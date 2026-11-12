// A craft's papers (docs/craft-core.md): its name, the party that owns it,
// its crew and their roles, how it takes new crew, who is barred, and a memo
// for the crew. One type serves every kind of craft.
//
// A party is what party_train_party_of() gives: a player's faction, or the
// player alone. Crew are kept by character name. Every field is plain text,
// so the saved object that owns a register can keep it with register_state().

/datum/craft_register
	var/name = ""
	var/party = null
	var/list/crew = list()        // character name -> role
	var/join_mode = CRAFT_JOIN_CLOSED
	var/list/requests = list()    // character names asking to join
	var/list/barred = list()      // character names
	var/memo = ""

// The roles that may take the helm.
/datum/craft_register/proc/steering_roles()
	return list(CRAFT_ROLE_CAPTAIN, CRAFT_ROLE_HELMSMAN)

/datum/craft_register/proc/role_of(mob/user)
	return user ? crew[user.real_name] : null

/datum/craft_register/proc/is_owner(mob/living/human/H)
	return istype(H) && party && party_train_party_of(H) == party

/datum/craft_register/proc/is_barred(mob/user)
	return user && (user.real_name in barred)

// TRUE when this mob counts as crew: a member of the owning party, or someone
// on the crew list.
/datum/craft_register/proc/is_crew(mob/user)
	if (!user || is_barred(user))
		return FALSE
	return is_owner(user) || !isnull(crew[user.real_name])

// TRUE when this mob may steer. Members of the owning party always may; listed
// crew need a steering role. A register with no party guards nothing.
/datum/craft_register/proc/may_steer(mob/user)
	if (!party)
		return TRUE
	if (!user || is_barred(user))
		return FALSE
	if (is_owner(user))
		return TRUE
	return role_of(user) in steering_roles()

/datum/craft_register/proc/set_role(char_name, role)
	if (!istext(char_name) || !length(char_name))
		return FALSE
	if (isnull(role))
		crew -= char_name
	else
		crew[char_name] = role
	requests -= char_name
	return TRUE

// Someone asks to join. Returns TRUE when they are crew at once (open), or
// their request was noted (ask); FALSE when the craft takes nobody or bars them.
/datum/craft_register/proc/ask_to_join(mob/user)
	if (!user || is_barred(user))
		return FALSE
	if (is_crew(user))
		return TRUE
	switch (join_mode)
		if (CRAFT_JOIN_OPEN)
			return set_role(user.real_name, CRAFT_ROLE_HAND)
		if (CRAFT_JOIN_ASK)
			requests |= user.real_name
			return TRUE
	return FALSE

/datum/craft_register/proc/bar(char_name)
	if (!istext(char_name) || !length(char_name))
		return FALSE
	barred |= char_name
	crew -= char_name
	requests -= char_name
	return TRUE

// TRUE while someone who may speak for the craft is online: the raid rule
// that trains and stations already use.
/datum/craft_register/proc/owners_online()
	return party ? party_members_online(party) : FALSE

// The register as text for a saved field, and back.
/datum/craft_register/proc/register_state()
	return json_encode(list("name" = name, "party" = party, "crew" = crew, "join" = join_mode, "requests" = requests, "barred" = barred, "memo" = memo))

/proc/craft_register_restore(text)
	if (!istext(text) || !length(text))
		return null
	var/list/state = null
	try
		state = json_decode(text)
	catch
		return null
	if (!islist(state))
		return null
	var/datum/craft_register/R = new
	R.name = istext(state["name"]) ? state["name"] : ""
	R.party = istext(state["party"]) ? state["party"] : null
	if (islist(state["crew"]))
		var/list/saved = state["crew"]
		for (var/who in saved)
			if (istext(who) && istext(saved[who]))
				R.crew[who] = saved[who]
	if (state["join"] in list(CRAFT_JOIN_OPEN, CRAFT_JOIN_ASK, CRAFT_JOIN_CLOSED))
		R.join_mode = state["join"]
	for (var/field in list("requests", "barred"))
		if (!islist(state[field]))
			continue
		for (var/who in state[field])
			if (istext(who))
				if (field == "requests")
					R.requests |= who
				else
					R.barred |= who
	R.memo = istext(state["memo"]) ? state["memo"] : ""
	return R
