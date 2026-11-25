// Extra characters bought with lifetime points (docs/character-slots.md).
//
// Every account plays slot 1, saved under the account itself. Lifetime points
// (accolades.dm) unlock slots 2 to 4, which own their bodies under the owner
// key "@<slot><account>" (player_reclaim.dm). Only a Discord-verified account
// may unlock or play an extra slot (the verified soft whitelist); one that
// loses verification goes back to slot 1 and its other characters stay asleep.
//
// One character is in play at a time: a client plays one slot. A switch puts
// the current character to rest where it is (asleep in its own bed, or left
// idle in the lobby for half an hour) and loads the chosen one. A slot left is
// not played again for an hour, and nobody switches out of trouble.
//
// The account's characters are kin, and anyone who examines one sees the
// others' names. Splitting one group into several factions, or using kin, to
// get around claim limits is structuring; admins step in to break it up.
//
// Records (shared_player_records.dm), all under the account's ckey:
//   character_slot  - list(slot, points): the slot was bought; id md5(kind|ckey|slot)
//   character_switch - list(slot, from): the account now plays slot
//   character_named - list(slot, name): a character's name, for kin lines
#define CHARACTER_SLOT_RETURN_WAIT 3600 // seconds before a slot left can be played again
#define CHARACTER_SLOT_HURT_WAIT 6000 // deciseconds after being hurt before switching
#define CHARACTER_SLOT_IDLE_MINUTES 30 // a body left in the lobby this long may be switched from
#define CHARACTER_SLOT_JAIL_RANGE 4

// The points each slot costs, in the order they are bought.
/proc/character_slot_cost(slot)
	switch(slot)
		if(2) return 100
		if(3) return 200
		if(4) return 300
	return 0

// The verified soft whitelist: a Discord-linked account. Fails closed.
/proc/character_slots_verified(client/C)
	if(!C || !C.ckey || IsGuestKey(C.key))
		return FALSE
	return account_verified(C.ckey) || is_discord_id(C.discord_id)

/proc/character_slot_record_id(kind, ckey, key)
	return md5("[kind]|[ckey]|[key]")

var/global/list/character_slot_cache = list() // ckey -> list(world.time, state)

/proc/character_slot_forget(ckey)
	character_slot_cache -= ckey

// What one account has: unlocked slots, points spent, the slot it plays, when
// each slot was last left (unix seconds) and each slot's latest name.
/proc/character_slot_state(ckey, fresh = FALSE)
	ckey = ckey(ckey)
	var/list/cached = character_slot_cache[ckey]
	if(!fresh && islist(cached) && world.time - cached[1] < 50)
		return cached[2]
	var/list/unlocked = list()
	var/list/locked = list()
	var/list/left = list()
	var/list/names = list()
	var/spent = 0
	var/active = 1
	var/active_at = "0" // record times are unix digit strings (shared_player_records.dm)
	if(length(ckey))
		for(var/list/record in shared_records.records_for(ckey))
			var/list/body = record["body"]
			if(!islist(body))
				continue
			var/slot = body["slot"]
			if(!isnum(slot) || slot < 1 || slot > character_slots_max || slot != round(slot))
				continue
			var/at = shared_records.unix_value(record["at"])
			switch(record["kind"])
				if("character_slot")
					if(slot < 2)
						continue
					// Points once spent stay spent, even on a slot staff locked.
					spent += isnum(body["points"]) ? max(0, round(body["points"])) : 0
					if(record["revoked"])
						locked["[slot]"] = record
					else
						unlocked["[slot]"] = record
				if("character_switch")
					if(record["revoked"] || shared_records.unix_after(active_at, at))
						continue
					active = slot
					active_at = at
					var/from = body["from"]
					if(isnum(from) && from >= 1 && from <= character_slots_max)
						if(!left["[from]"] || shared_records.unix_after(at, left["[from]"]))
							left["[from]"] = at
				if("character_named")
					if(!record["revoked"] && istext(body["name"]) && (!names["[slot]"] || !shared_records.unix_after(names["[slot]"][2], at)))
						names["[slot]"] = list(copytext(body["name"], 1, MAX_NAME_LEN + 1), at)
	for(var/key in locked)
		unlocked -= key
	var/list/state = list("unlocked" = unlocked, "locked" = locked, "spent" = spent, "active" = active, "left" = left, "names" = names)
	character_slot_cache[ckey] = list(world.time, state)
	return state

/proc/character_slot_open(list/state, slot)
	if(slot == 1)
		return TRUE
	var/list/unlocked = state["unlocked"]
	return !!unlocked["[slot]"]

/proc/character_slot_count(list/state)
	var/list/unlocked = state["unlocked"]
	return 1 + length(unlocked)

/proc/character_slot_balance(ckey)
	var/list/state = character_slot_state(ckey)
	return max(0, accolade_points(ckey) - state["spent"])

// The next slot to buy, or 0 when every slot is bought or staff locked one.
/proc/character_slot_next(list/state)
	var/list/locked = state["locked"]
	for(var/slot = 2 to character_slots_max)
		if(locked["[slot]"])
			return 0
		if(!character_slot_open(state, slot))
			return slot
	return 0

// -- unlocking -------------------------------------------------------------------

// Buys the next slot with lifetime points. Returns the record, or why not.
/proc/character_slot_unlock(client/C)
	var/ckey = accolade_client_ckey(C)
	if(!ckey)
		return "Extra characters belong to a signed-in BYOND account."
	if(!character_slots_verified(C))
		return "Only a Discord-verified account can unlock extra characters. Use Verify Discord first."
	return character_slot_buy(ckey)

// Buys the next slot for a verified account's ckey (callers check verification).
/proc/character_slot_buy(ckey)
	var/list/state = character_slot_state(ckey)
	var/slot = character_slot_next(state)
	if(!slot)
		return "There is no character slot left to unlock."
	var/cost = character_slot_cost(slot)
	var/balance = character_slot_balance(ckey)
	if(balance < cost)
		return "Slot [slot] costs [cost] lifetime points. You have [balance]."
	var/list/record = shared_records.add(ckey, "character_slot", list("slot" = slot, "points" = cost), ckey, "", character_slot_record_id("character_slot", ckey, slot))
	character_slot_forget(ckey)
	if(!record)
		return "The slot could not be recorded. Try again in a minute."
	log_game("Character slots: [ckey] unlocked slot [slot] for [cost] points.")
	return record

// -- switching -------------------------------------------------------------------

/mob/living/human/var/tmp/character_slot_admitted_name // set at fresh durable Join, consumed by EquipRank
/mob/living/human/var/tmp/character_idle_minutes = 0 // minutes this owned body has had no player

// Why this body cannot be switched away from now, or null.
/mob/living/human/proc/character_slot_body_refusal()
	if(stat == DEAD || QDELETED(src))
		return null
	if(handcuffed || legcuffed)
		return "is restrained"
	if(length(justice_examine_lines(src)))
		return "is wanted or outlawed"
	for(var/obj/structure/simple_door/D in range(CHARACTER_SLOT_JAIL_RANGE, src))
		if(D.cell_sentence_left > 0)
			return "is serving a jail sentence"
	if(round_fact_hit_time >= 0 && world.time - round_fact_hit_time < CHARACTER_SLOT_HURT_WAIT)
		return "was hurt in the last ten minutes"
	return null

// The assigned bed must still be valid when used to leave a durable body.
/mob/living/human/proc/character_lobby_assigned_bed(owner)
	if(!owner || stat == DEAD || !inducedSSD || sleeping <= 0 || !isturf(loc))
		return null
	for(var/obj/structure/bed/B in loc)
		if(B.persistence_bed_owner_ckey == owner && (!buckled || buckled == B) && B.valid_sleep_bed(src))
			return B
	return null

// TRUE when this body rests asleep in its own bed (Sleep in a bed).
/mob/living/human/proc/character_slot_resting(owner)
	if(persistence_bed_return_enabled())
		return !!character_lobby_assigned_bed(owner)
	if(!inducedSSD || !isturf(loc))
		return FALSE
	for(var/obj/structure/bed/B in loc)
		if(B.persistence_bed_owner_ckey == owner)
			return TRUE
	return FALSE

// Why the client cannot leave the character it plays now, or null.
/proc/character_slot_leave_refusal(client/C)
	var/owner = C.owner_key()
	var/mob/living/human/H = C.mob
	if(istype(H))
		if(H.persistence_owner_ckey != owner || H.stat == DEAD)
			return null
		if(!H.character_slot_resting(owner))
			return "Your character must be asleep in their own bed first: use Sleep in your bed, then switch."
		var/why = H.character_slot_body_refusal()
		return why ? "You cannot switch while your character [why]." : null
	for(var/mob/living/human/B in human_mob_list)
		if(B.persistence_owner_ckey != owner || B.stat == DEAD || QDELETED(B))
			continue
		if(!B.character_slot_resting(owner) && B.character_idle_minutes < CHARACTER_SLOT_IDLE_MINUTES)
			return "[B.real_name] was left awake [B.character_idle_minutes] minute\s ago. Switch after [CHARACTER_SLOT_IDLE_MINUTES] minutes, or play them and Sleep in their bed."
		var/why = B.character_slot_body_refusal()
		if(why)
			return "You cannot switch while [B.real_name] [why]."
	return null

// Seconds until a slot left can be played again (0 when it can).
/proc/character_slot_return_wait(list/state, slot)
	var/list/left = state["left"]
	var/left_at = left["[slot]"]
	if(!istext(left_at))
		return 0
	var/until = shared_records.unix_add(left_at, CHARACTER_SLOT_RETURN_WAIT)
	var/now = shared_records.now_unix()
	if(!shared_records.unix_after(until, now))
		return 0
	// Under an hour apart, so the last seven digits tell the difference.
	var/a = text2num(copytext("0000000[until]", -7))
	var/b = text2num(copytext("0000000[now]", -7))
	return a >= b ? a - b : a + 10000000 - b

// Why the client cannot play slot now, or null.
/proc/character_slot_switch_refusal(client/C, slot)
	if(region_gateway_here())
		return "Use the gateway character lobby. A switch must be admitted in your character's land."
	if(!region_gateway_expected_slot_ok(C))
		return "Your selected character changed. Reconnect through the gateway before switching."
	var/ckey = accolade_client_ckey(C)
	if(!ckey)
		return "Extra characters belong to a signed-in BYOND account."
	if(!isnum(slot) || slot < 1 || slot > character_slots_max || slot != round(slot))
		return "There is no such character slot."
	if(slot == C.character_slot)
		return "You are already playing that character."
	var/list/state = character_slot_state(ckey)
	if(!character_slot_open(state, slot))
		return "That character slot is not unlocked."
	if(slot > 1 && !character_slots_verified(C))
		return "Only a Discord-verified account can play extra characters."
	var/wait = character_slot_return_wait(state, slot)
	if(wait > 0)
		return "You left that character less than an hour ago. Wait [round(wait / 60, 1) || 1] more minute\s."
	if(persistence_save_active())
		return "Wait for the world save to finish."
	return character_slot_leave_refusal(C)

// Puts the current character to rest and loads the one in slot. Returns
// null on success, else why not.
/proc/character_slot_switch(client/C, slot)
	var/why = character_slot_switch_refusal(C, slot)
	if(why)
		return why
	var/ckey = accolade_client_ckey(C)
	var/from = C.character_slot
	if(!shared_records.add(ckey, "character_switch", list("slot" = slot, "from" = from), ckey))
		return "The switch could not be recorded. Try again in a minute."
	character_slot_forget(ckey)
	log_game("Character slots: [ckey] switched from slot [from] to slot [slot].")
	C.character_slot = slot
	var/mob/new_player/lobby = C.mob
	if(!istype(lobby))
		// The character stays asleep in its bed; the player goes to the lobby.
		lobby = new /mob/new_player()
		lobby.key = C.key
		return null // the lobby's Login takes the new slot's body back
	if(region_home_reclaim_ok(lobby))
		map_storage.reclaim_saved_player(lobby)
	return null

// At every lobby login: play the slot the account last chose, unless it is
// no longer open to this client. Fails closed to slot 1.
/client/proc/character_slot_restore()
	var/ckey = accolade_client_ckey(src)
	if(!ckey)
		character_slot = 1
		return
	var/list/state = character_slot_state(ckey)
	var/slot = state["active"]
	if(slot > 1 && (!character_slot_open(state, slot) || !character_slots_verified(src)))
		if(character_slot != 1 || slot > 1)
			to_chat(src, SPAN_WARNING("Your account is not verified (or that slot was locked), so you play your first character. Your other characters stay asleep until you verify again."))
		slot = 1
	character_slot = slot

// -- kin -------------------------------------------------------------------------

// The other characters of the account behind this body, by name.
/mob/living/human/proc/character_kin_names()
	. = list()
	var/owner = persistence_owner_ckey
	var/slot = owner_key_slot(owner)
	var/ckey = accolade_account_ckey(owner)
	if(!slot || !ckey)
		return
	var/list/state = character_slot_state(ckey)
	if(character_slot_count(state) < 2)
		return
	var/list/names = state["names"]
	for(var/other = 1 to character_slots_max)
		if(other != slot && character_slot_open(state, other) && islist(names["[other]"]))
			. += names["[other]"][1]

// Compare names, not ckeys: punctuation that distinguishes two character
// names should remain significant, but capitalization and spacing should not.
/proc/character_slot_name_key(name)
	if(!istext(name))
		return null
	var/static/regex/whitespace = regex(@"\s+", "g")
	return lowertext(trim(whitespace.Replace(name, " ")))

// Returns the other existing slot using this name, or 0. Staff locking a
// purchased slot preserves its body. A living body here takes priority over
// its last recorded name; other lands use this account's shared records.
/proc/character_slot_name_conflict(account, slot, name)
	var/name_key = character_slot_name_key(name)
	if(!account || !slot || !name_key)
		return 0
	var/list/state = character_slot_state(account, TRUE)
	var/list/names = state["names"]
	var/list/locked = state["locked"]
	for(var/other = 1 to character_slots_max)
		if(other == slot || (!character_slot_open(state, other) && !locked["[other]"]))
			continue
		var/mob/living/human/H = region_home_living_body(owner_key_for(account, other))
		var/list/entry = names["[other]"]
		var/other_name = H ? H.real_name : (islist(entry) ? entry[1] : null)
		if(character_slot_name_key(other_name) == name_key)
			return other
	return 0

// Remember the current name, including slot 1 before it has any siblings.
// A slot that later returns to an older name needs a new latest record.
/mob/living/human/proc/character_slot_note_name()
	var/owner = persistence_owner_ckey
	var/slot = owner_key_slot(owner)
	var/ckey = accolade_account_ckey(owner)
	if(!slot || !ckey || !real_name)
		return
	var/list/state = character_slot_state(ckey)
	if(!persistence_bed_return_enabled() && character_slot_count(state) < 2)
		return
	var/list/names = state["names"]
	if(islist(names["[slot]"]) && names["[slot]"][1] == real_name)
		return
	if(shared_records.add(ckey, "character_named", list("slot" = slot, "name" = real_name)))
		character_slot_forget(ckey)

/mob/living/human/examine(mob/user)
	. = ..()
	if(user && user != src)
		var/list/kin = character_kin_names()
		if(length(kin))
			to_chat(user, SPAN_NOTICE("[real_name] is kin to [english_list(kin)]: one player plays them all."))

// Called every minute from the accolades process.
/proc/character_slots_tick()
	for(var/mob/living/human/H in human_mob_list)
		if(QDELETED(H) || !H.persistence_owner_ckey)
			continue
		if(H.client)
			H.character_idle_minutes = 0
			H.character_slot_note_name()
		else
			H.character_idle_minutes++

// -- the local sleep picker ------------------------------------------------------

// This is narrower than the legacy switch/idle admission. Only a living,
// actually sleeping body on its own valid assigned bed can enter this picker.
/proc/character_lobby_sleep_body(client/C)
	if(!accolade_client_ckey(C) || !persistence_bed_return_enabled())
		return null
	var/mob/living/human/H = C.mob
	var/owner = C.owner_key()
	if(!istype(H) || QDELETED(H) || H.gcDestroyed || H.client != C || H.persistence_owner_ckey != owner)
		return null
	return H.character_lobby_assigned_bed(owner) ? H : null

/proc/character_lobby_departure_refusal(client/C)
	var/mob/living/human/H = character_lobby_sleep_body(C)
	if(!H)
		return "Your character must still be asleep in their own assigned bed."
	if(H.character_picker_waking)
		return "You are already waking this character."
	if(persistence_sleep_transfer_blocked() || map_storage.character_recovery_unready())
		return "Wait for the world save or recovery to finish."
	var/reason = H.character_slot_body_refusal()
	return reason ? "You cannot leave while your character [reason]." : null

// Text only, placed in the private window after exact slot ownership and
// unique local body checks. Never publishes location or condition to a peer.
/proc/character_local_body_summary(mob/living/human/H)
	if(H.stat == DEAD)
		return "Dead in this land."
	if(H.inducedSSD && H.sleeping > 0)
		return "Asleep in this land."
	return "Awake in this land."

// The base skills the picker lists, in its order.
/proc/character_local_body_skills()
	return list("strength", "dexterity", "stamina", "crafting", "medical", "philosophy", "farming")

/client/proc/open_character_sleep_picker()
	var/mob/living/human/H = character_lobby_sleep_body(src)
	if(!H)
		return FALSE
	if(!character_sleep_picker || character_sleep_picker.owner != src)
		character_sleep_picker = new /datum/character_slot_window(src)
	character_sleep_picker.sleep_picker_body = H
	character_sleep_picker.ui_interact(H)
	return TRUE

// -- the window ------------------------------------------------------------------

/client/var/datum/character_slot_window/character_slot_window = null
/client/var/datum/character_slot_window/character_sleep_picker = null

/client/verb/characters_window()
	set name = "Characters"
	set category = "OOC"
	set desc = "Your characters, and extra character slots bought with lifetime points."
	if(!accolade_client_ckey(src))
		to_chat(src, SPAN_WARNING("Characters belong to a signed-in BYOND account."))
		return
	if(!character_slot_window || character_slot_window.owner != src)
		character_slot_window = new /datum/character_slot_window(src)
	character_slot_window.ui_interact(mob)

/datum/character_slot_window
	var/client/owner = null
	var/mob/living/human/sleep_picker_body = null

/datum/character_slot_window/New(client/C)
	..()
	owner = C

/datum/character_slot_window/Destroy()
	GLOB.nanomanager.close_uis(src)
	if(owner && owner.character_slot_window == src)
		owner.character_slot_window = null
	if(owner && owner.character_sleep_picker == src)
		owner.character_sleep_picker = null
	sleep_picker_body = null
	owner = null
	return ..()

/datum/topic_state/character_slots/can_use_topic(var/src_object, var/mob/user)
	var/datum/character_slot_window/W = src_object
	if(!istype(W) || !W.owner || !user || user.client != W.owner)
		return STATUS_CLOSE
	if(W.sleep_picker_body && (W.sleep_picker_body != user || character_lobby_sleep_body(W.owner) != user))
		return STATUS_CLOSE
	return STATUS_INTERACTIVE

/datum/character_slot_window/ui_actions(ui_key)
	if(sleep_picker_body)
		return list("wake_local", "gateway_roster")
	return list("unlock", "switch")

/datum/character_slot_window/ui_interact(mob/user, ui_key = "main", datum/nanoui/ui = null, force_open = TRUE)
	if(!owner || !user || user.client != owner)
		return
	if(sleep_picker_body && (sleep_picker_body != user || character_lobby_sleep_body(owner) != user))
		return
	var/list/sections = sleep_picker_body ? sleep_picker_sections() : window_sections()
	open_panel(user, sleep_picker_body ? "Sleeping Characters" : "Characters", sleep_picker_body ? 560 : 640, 700, sections, ui_key = ui_key, ui = ui, force_open = force_open, state = /datum/topic_state/character_slots)

// The panel (designed by Fable): the balance and who is played now, then one
// line per slot with its state, its button and why a disabled button is
// disabled, then the rules.
/datum/character_slot_window/proc/window_sections()
	var/ckey = accolade_client_ckey(owner)
	var/list/state = character_slot_state(ckey)
	var/list/names = state["names"]
	var/list/locked = state["locked"]
	var/verified = character_slots_verified(owner)
	var/balance = character_slot_balance(ckey)
	var/next_slot = character_slot_next(state)
	var/current = owner.character_slot
	// The name of the character in play: the body itself knows it best.
	var/current_name = islist(names["[current]"]) ? names["[current]"][1] : null
	var/mob/living/human/body = owner.mob
	if(istype(body) && body.real_name && body.persistence_owner_ckey == owner.owner_key())
		current_name = body.real_name
	// Why each sleeping character cannot be played now. One reason shared by
	// all of them is shown once, above the list.
	var/list/whys = list()
	var/candidates = 0
	var/shared_why = null
	var/all_same = TRUE
	for(var/slot = 1 to character_slots_max)
		if(slot == current || !character_slot_open(state, slot) || (slot > 1 && !verified))
			continue
		candidates++
		var/why = character_slot_switch_refusal(owner, slot)
		if(!why)
			continue
		whys["[slot]"] = why
		if(!shared_why)
			shared_why = why
		else if(shared_why != why)
			all_same = FALSE
	if(candidates < 2 || length(whys) != candidates || !all_same)
		shared_why = null
	var/list/items = list()
	for(var/slot = 1 to character_slots_max)
		var/list/buttons = list()
		var/detail
		var/name = islist(names["[slot]"]) ? names["[slot]"][1] : null
		if(slot == current)
			name = current_name
			detail = "Playing now."
		else if(locked["[slot]"])
			detail = "Locked by staff."
		else if(character_slot_open(state, slot))
			if(slot > 1 && !verified)
				detail = "Asleep until you verify your Discord account."
				buttons += list(panel_button("Play", "switch", slot, TRUE))
			else
				var/why = whys["[slot]"]
				detail = (name || slot == 1) ? "Asleep." : "Not played yet."
				if(why && !shared_why)
					detail += " [why]"
				buttons += list(panel_button("Play", "switch", slot, !!why))
		else
			var/cost = character_slot_cost(slot)
			if(next_slot == slot)
				if(!verified)
					detail = "Not unlocked. Costs [cost] lifetime point\s. Verify your Discord account to unlock it."
				else if(balance < cost)
					detail = "Not unlocked. Costs [cost] lifetime point\s - you need [cost - balance] more."
				else
					detail = "Not unlocked. Costs [cost] lifetime point\s."
				buttons += list(panel_button("Unlock for [cost] point\s", "unlock", slot, !verified || balance < cost))
			else if(!next_slot)
				detail = "Not unlocked. No slot can be unlocked while one is locked by staff."
			else
				detail = "Not unlocked. Costs [cost] lifetime point\s. Unlock character [slot - 1] first."
		items += list(panel_item("Character [slot][name ? " - [name]" : ""]", detail, buttons))
	var/list/summary_notes = list()
	if(!verified)
		summary_notes += "Only Discord-verified accounts can unlock or play extra characters. Use the Verify Discord verb to link yours."
	summary_notes += "Extra characters are unlocked with lifetime points, which you earn and claim in the Accolades window."
	var/list/rows = list()
	if(!verified)
		rows += list(panel_row("Account", "Not Discord-verified", "warn"))
	rows += list(
		panel_row("Points to spend", "[balance] point\s", balance ? "good" : "muted"),
		panel_row("Characters", "[character_slot_count(state)] of [character_slots_max] unlocked"),
		panel_row("Playing now", "Character [current][current_name ? " - [current_name]" : ""]", "info"))
	var/list/slot_notes = null
	if(shared_why)
		slot_notes = list("You cannot switch right now. [shared_why]")
	var/list/rules = list(
		"You play one character at a time. You can switch only when your current character is asleep in their own bed, or after they have been left in the lobby for 30 minutes.",
		"A character you leave cannot be played again for an hour. You cannot switch while your character is restrained, jailed, wanted or recently hurt.",
		"Your characters are kin, and this is public: anyone who examines one of them sees the names of the others.",
		"Splitting one group into several factions, or using kin, to get around claim limits is structuring. It is not allowed, and admins will step in to break it up.")
	return list(
		panel_section("Your characters", notes = summary_notes, rows = rows),
		panel_section("Character slots", notes = slot_notes, items = items),
		panel_section("Rules", notes = rules))

/datum/character_slot_window/proc/sleep_picker_sections()
	var/client/C = owner
	var/list/state = character_slot_state(accolade_client_ckey(C))
	var/list/names = state["names"]
	var/list/bodies = list()
	var/list/ambiguous = list()
	// Only this client's exact durable owner keys can enter the local roster.
	for(var/mob/living/human/H in human_mob_list)
		if(QDELETED(H) || H.gcDestroyed || !H.loc)
			continue
		var/slot = owner_key_slot(H.persistence_owner_ckey)
		if(slot < 1 || H.persistence_owner_ckey != owner_key_for(C.ckey, slot))
			continue
		if((H.client && H.client != C) || bodies["[slot]"])
			ambiguous["[slot]"] = TRUE
		else
			bodies["[slot]"] = H
	// The picker (designed by Fable): who can be played from this bed and the
	// one button that does it, then the local bodies' skills side by side.
	var/list/items = list()
	var/list/columns = list("Skill")
	var/list/shown = list()
	for(var/slot = 1 to character_slots_max)
		if(!character_slot_open(state, slot) || (slot > 1 && !character_slots_verified(C)))
			continue
		var/mob/living/human/H = ambiguous["[slot]"] ? null : bodies["[slot]"]
		var/name = H ? H.real_name : (islist(names["[slot]"]) ? names["[slot]"][1] : null)
		var/detail = H ? character_local_body_summary(H) : "Not found in this land. The character lobby can take you to them."
		var/list/buttons
		if(slot == C.character_slot)
			if(sleep_picker_body.character_picker_waking)
				detail = "Waking up. This takes 30 seconds."
			buttons = list(panel_button("Wake up", "wake_local", disabled = sleep_picker_body.character_picker_waking))
		items += list(panel_item("Slot [slot][name ? " - [name]" : ""]", detail, buttons))
		if(H && islist(H.stats))
			columns += "[name ? name : "Slot [slot]"]"
			shown += H
	var/refusal = character_lobby_departure_refusal(C)
	var/list/notes = list("Your character stays asleep in their bed. Wake up here, or open the character lobby to continue as someone else.")
	if(refusal)
		notes += refusal
	var/list/sections = list(panel_section("While you sleep", notes = notes, items = items,
		buttons = list(panel_button("Open the character lobby", "gateway_roster", disabled = !!refusal))))
	if(shown.len)
		var/list/rows = list()
		for(var/stat_name in character_local_body_skills())
			var/list/row = list(capitalize(stat_name))
			for(var/mob/living/human/H in shown)
				var/list/stat_data = H.stats[stat_name]
				row += (islist(stat_data) && length(stat_data) && isnum(stat_data[1])) ? "[round(stat_data[1], 0.1)]" : "-"
			rows += list(row)
		sections += list(panel_section("Skills", table = panel_table(columns, rows)))
	return sections

/datum/character_slot_window/ui_act(action, list/params, mob/user, datum/nanoui/ui)
	if(!owner || !user || user.client != owner)
		return TRUE
	var/client/C = owner
	if(sleep_picker_body)
		if(sleep_picker_body != user || character_lobby_sleep_body(C) != user)
			return TRUE
		switch(action)
			if("wake_local")
				sleep_picker_body.request_character_picker_wake(C)
			if("gateway_roster")
				var/why = character_lobby_departure_refusal(C)
				if(why)
					to_chat(C, SPAN_WARNING(why))
				else if(!region_gateway_open_roster(C))
					to_chat(C, SPAN_WARNING("The gateway lobby is not available right now. Your character is still asleep here."))
		return TRUE
	switch(action)
		if("unlock")
			var/result = character_slot_unlock(C)
			if(istext(result))
				to_chat(C, SPAN_WARNING(result))
			else
				to_chat(C, SPAN_NOTICE("You unlocked character slot [result["body"]["slot"]]. Choose Play on it when you are ready."))
			return TRUE
		if("switch")
			var/slot = text2num(params["value"])
			var/why = character_slot_switch(C, slot)
			if(why)
				to_chat(C, SPAN_WARNING(why))
			else
				to_chat(C, SPAN_NOTICE("You now play character [slot]. Your other character rests where you left them."))
			return TRUE
	return FALSE

#undef CHARACTER_SLOT_RETURN_WAIT
#undef CHARACTER_SLOT_HURT_WAIT
#undef CHARACTER_SLOT_IDLE_MINUTES
#undef CHARACTER_SLOT_JAIL_RANGE
