// Accolades: lifetime points for an account (docs/accolades.md).
//
// Each accolade can be claimed once per account, ever. Meeting one marks it
// ready; the player presses Claim in the Accolades window and the points are
// theirs for good. Points will unlock extra character slots; nothing else
// spends them, and they never trade.
//
// Everything lives in the shared player records store
// (code/modules/admin/shared_player_records.dm), so it is the same on every
// region of a shard group and survives deaths and characters:
//
//   accolade_met   about a ckey; body accolade. The accolade was met and waits to be claimed.
//   accolade       about a ckey; body accolade, points (and grant = 1 when staff gave it).
//   accolade_land  about a ckey; body land. A land one of the account's characters has lived in.
//
// A met, claim or land record gets an id made from the ckey and the accolade
// (or land), so two regions writing the same record store it once, and a claim
// staff revoked can never be claimed again. Staff grants get fresh ids.
//
// Accolades are earned only in persistent lands: never in the TDM barracks or
// battle worlds, event lands or the tutorial region (except First Steps, which
// is finished there). Guests and host agents never earn.
//
// Entry points for other features:
//   accolade_meet(ckey, id)            -> TRUE when the accolade is newly met
//   accolade_meet_mob(mob, id)         -> the same for a character's account
//   accolade_points(ckey)              -> points claimed, minus anything spent (later: slots)
//   accolade_state(ckey)               -> list("met", "claimed", "removed", "lands", "points")
//   accolade_claim(ckey, id)           -> the claim record, or a refusal text
#define ACCOLADE_CACHE_TIME 50 // deciseconds a ckey's state is reused
#define ACCOLADE_SURVIVOR_MINUTES 600
#define ACCOLADE_OLD_HAND_MINUTES 3000
#define ACCOLADE_CITIZEN_MINUTES 600
#define ACCOLADE_APPRENTICE_SUBJECTS 10
#define ACCOLADE_SCHOLAR_SUBJECTS 50
#define ACCOLADE_WANDERER_LANDS 3

// id -> list(name, points, group, condition). Order is the window's order.
/proc/accolade_catalog()
	var/static/list/catalog = list(
		"first_steps" = list("First Steps", 5, "Start", "Finish the tutorial."),
		"settled" = list("Settled", 5, "Start", "Sleep in a bed that is assigned to you."),
		"survivor" = list("Survivor", 15, "Survival", "Keep one character alive for 10 hours of play."),
		"old_hand" = list("Old Hand", 40, "Survival", "Keep one character alive for 50 hours of play."),
		"four_seasons" = list("Four Seasons", 20, "Survival", "Live through every season of the year with one character."),
		"apprentice" = list("Apprentice", 10, "Knowledge", "Know 10 research subjects with one character."),
		"scholar" = list("Scholar", 30, "Knowledge", "Know 50 research subjects with one character."),
		"pioneer" = list("Pioneer", 30, "Knowledge", "Be in the faction whose research moves your land into a new era."),
		"sailor" = list("Sailor", 10, "Travel", "Set out on a voyage from a boat's tiller."),
		"wanderer" = list("Wanderer", 15, "Travel", "Live in 3 different lands."),
		"world_traveller" = list("World Traveller", 40, "Travel", "Live in every land of the world."),
		"citizen" = list("Citizen", 10, "Community", "Spend 10 hours of play in one faction."))
	return catalog

/proc/accolade_name(id)
	var/list/entry = accolade_catalog()[id]
	return islist(entry) ? entry[1] : null

/proc/accolade_value(id)
	var/list/entry = accolade_catalog()[id]
	return islist(entry) ? entry[2] : 0

// -- who and where -------------------------------------------------------------

// The ckey an account earns under: a BYOND ckey, or the ckey verified for a
// Discord account key. Guests and host agents never earn.
/proc/accolade_account_ckey(account)
	if(!istext(account) || !length(account) || is_agent_account(account))
		return null
	if(is_account_key(account))
		return shared_records.account_ckey(account)
	if(persistence_guest_account(account) || ckey(account) != account)
		return null
	return account

/proc/accolade_client_ckey(client/C)
	if(!C || !C.ckey || IsGuestKey(C.key))
		return null
	return C.ckey

/proc/accolade_mob_ckey(mob/M)
	if(!M)
		return null
	if(M.client)
		return accolade_client_ckey(M.client)
	if(ishuman(M))
		var/mob/living/human/H = M
		return accolade_account_ckey(H.persistence_owner_ckey)
	return null

// Persistent lands only. A world outside a shard group earns when it keeps
// its characters (the same test as bed return).
/proc/accolades_earned_here()
	if(shard_group && shard_group.enabled && (shard_group.kind in list("BARRACKS", "BATTLE", "EVENT", "TUTORIAL", "RAID")))
		return FALSE
	return persistence_bed_return_enabled()

// The land name accolades record: the region id, or "local" outside a group.
/proc/accolade_land_here()
	if(shard_group && shard_group.enabled && istext(shard_group.region))
		return shard_group.region
	return "local"

// Every land World Traveller asks for: the group's surface regions.
/proc/accolade_world_lands()
	. = list()
	if(!shard_group || !shard_group.enabled)
		return
	if(shard_group.kind == "SURFACE")
		. += shard_group.region
	for(var/id in shard_group.peers)
		var/list/peer = shard_group.peers[id]
		if(islist(peer) && peer["kind"] == "SURFACE")
			. += id

// -- reading -------------------------------------------------------------------

var/global/list/accolade_cache = list() // ckey -> list(world.time, state)

/proc/accolade_forget(ckey)
	accolade_cache -= ckey

// What one account has: met accolades waiting to be claimed, claims (and
// staff grants), claims staff took away, lands lived in, and the balance.
/proc/accolade_state(ckey)
	ckey = ckey(ckey)
	var/list/cached = accolade_cache[ckey]
	if(islist(cached) && world.time - cached[1] < ACCOLADE_CACHE_TIME)
		return cached[2]
	var/list/met = list()
	var/list/claimed = list()
	var/list/removed = list()
	var/list/lands = list()
	var/points = 0
	if(length(ckey))
		for(var/list/record in shared_records.records_for(ckey))
			var/list/body = record["body"]
			if(!islist(body))
				continue
			switch(record["kind"])
				if("accolade_met")
					if(!record["revoked"] && istext(body["accolade"]))
						met[body["accolade"]] = record
				if("accolade")
					var/id = body["accolade"]
					if(!istext(id))
						continue
					if(record["revoked"])
						if(record["id"] == accolade_record_id("accolade", ckey, id))
							removed[id] = record
						continue
					if(claimed[id])
						continue // a staff grant and a claim pay once
					claimed[id] = record
					points += isnum(body["points"]) ? max(0, round(body["points"])) : 0
				if("accolade_land")
					if(!record["revoked"] && istext(body["land"]))
						lands |= body["land"]
	var/list/state = list("met" = met, "claimed" = claimed, "removed" = removed, "lands" = lands, "points" = points)
	accolade_cache[ckey] = list(world.time, state)
	return state

/proc/accolade_points(ckey)
	var/list/state = accolade_state(ckey)
	return state["points"]

// "claimed", "removed", "ready" or "open".
/proc/accolade_status(list/state, id)
	var/list/claimed = state["claimed"]
	var/list/removed = state["removed"]
	var/list/met = state["met"]
	if(claimed[id])
		return "claimed"
	if(removed[id])
		return "removed"
	if(met[id])
		return "ready"
	return "open"

/proc/accolade_record_id(kind, ckey, key)
	return md5("[kind]|[ckey]|[key]")

// -- writing -------------------------------------------------------------------

// Marks an accolade met for an account. TRUE when it is newly met here.
/proc/accolade_meet(ckey, id)
	ckey = ckey(ckey)
	if(!length(ckey) || !accolade_catalog()[id])
		return FALSE
	if(id != "first_steps" && !accolades_earned_here())
		return FALSE
	var/list/state = accolade_state(ckey)
	if(accolade_status(state, id) != "open")
		return FALSE
	if(!shared_records.add(ckey, "accolade_met", list("accolade" = id, "land" = accolade_land_here()), id = accolade_record_id("accolade_met", ckey, id)))
		return FALSE
	accolade_forget(ckey)
	var/client/C = directory[ckey]
	if(C)
		to_chat(C, SPAN_NOTICE("<b>Accolade earned: [accolade_name(id)].</b> Open <b>Accolades</b> in the OOC tab to claim [accolade_value(id)] lifetime point\s."))
		C.refresh_accolade_window()
	log_game("Accolades: [ckey] met [id].")
	return TRUE

/proc/accolade_meet_mob(mob/M, id)
	return accolade_meet(accolade_mob_ckey(M), id)

// Claims a met accolade. Returns the claim record, or a refusal text.
/proc/accolade_claim(ckey, id)
	ckey = ckey(ckey)
	if(!length(ckey) || !accolade_catalog()[id])
		return "There is no such accolade."
	accolade_forget(ckey)
	var/list/state = accolade_state(ckey)
	switch(accolade_status(state, id))
		if("claimed")
			return "You have already claimed [accolade_name(id)]."
		if("removed")
			return "Staff removed [accolade_name(id)] from your account; it cannot be claimed again."
		if("open")
			return "You have not earned [accolade_name(id)] yet."
	var/list/record = shared_records.add(ckey, "accolade", list("accolade" = id, "points" = accolade_value(id)), id = accolade_record_id("accolade", ckey, id))
	accolade_forget(ckey)
	if(!record)
		return "The claim could not be recorded. Try again in a minute."
	log_game("Accolades: [ckey] claimed [id] for [accolade_value(id)] point\s.")
	return record

// Records a land the account lives in, and checks the travel accolades.
/proc/accolade_note_land(ckey, land = null)
	ckey = ckey(ckey)
	if(!length(ckey) || !accolades_earned_here())
		return
	if(!istext(land))
		land = accolade_land_here()
	var/list/state = accolade_state(ckey)
	var/list/lands = state["lands"]
	if(!(land in lands))
		if(!shared_records.add(ckey, "accolade_land", list("land" = land), id = accolade_record_id("accolade_land", ckey, land)))
			return
		accolade_forget(ckey)
		state = accolade_state(ckey)
		lands = state["lands"]
	if(length(lands) >= ACCOLADE_WANDERER_LANDS)
		accolade_meet(ckey, "wanderer")
	var/list/world_lands = accolade_world_lands()
	if(length(world_lands) >= 2 && !length(world_lands - lands))
		accolade_meet(ckey, "world_traveller")

// -- character progress -----------------------------------------------------------

// Per-character counters, saved with the body and carried on trips:
// "minutes" alive and awake while played, "seasons" lived through,
// "faction" and "faction_minutes" in it.
/mob/living/human/var/list/accolade_progress = null

/proc/accolade_progress_clean(list/progress)
	. = list()
	if(!islist(progress))
		return
	if(isnum(progress["minutes"]))
		.["minutes"] = clamp(round(progress["minutes"], 1), 0, 1000000)
	if(islist(progress["seasons"]))
		var/list/seasons = list()
		for(var/name in progress["seasons"])
			if(name in list(SEASON_SPRING, SEASON_SUMMER, SEASON_FALL, SEASON_WINTER, SEASON_WET, SEASON_DRY))
				seasons |= name
		if(seasons.len)
			.["seasons"] = seasons
	if(istext(progress["faction"]) && length(progress["faction"]) <= 64)
		.["faction"] = progress["faction"]
		.["faction_minutes"] = isnum(progress["faction_minutes"]) ? clamp(round(progress["faction_minutes"], 1), 0, 1000000) : 0

// Every season of a year: the four temperate ones, or wet and dry.
/proc/accolade_full_year(list/seasons)
	if(!islist(seasons))
		return FALSE
	if(!length(list(SEASON_SPRING, SEASON_SUMMER, SEASON_FALL, SEASON_WINTER) - seasons))
		return TRUE
	return !length(list(SEASON_WET, SEASON_DRY) - seasons)

// One minute of play for a character: alive, awake and played.
/mob/living/human/proc/accolade_minute()
	if(!client || stat != CONSCIOUS || inducedSSD || sleeping)
		return
	var/account = accolade_client_ckey(client)
	if(!account || !accolades_earned_here())
		return
	var/list/progress = accolade_progress_clean(accolade_progress)
	progress["minutes"] = (progress["minutes"] || 0) + 1
	var/list/seasons = progress["seasons"] || list()
	if(istext(season))
		seasons |= season
	progress["seasons"] = seasons
	var/faction = civilization && civilization != "none" ? "[civilization]" : null
	if(faction != progress["faction"])
		progress -= "faction"
		progress -= "faction_minutes"
		if(faction)
			progress["faction"] = faction
			progress["faction_minutes"] = 0
	if(faction)
		progress["faction_minutes"] = progress["faction_minutes"] + 1
	accolade_progress = progress
	if(progress["minutes"] >= ACCOLADE_SURVIVOR_MINUTES)
		accolade_meet(account, "survivor")
	if(progress["minutes"] >= ACCOLADE_OLD_HAND_MINUTES)
		accolade_meet(account, "old_hand")
	if(accolade_full_year(seasons))
		accolade_meet(account, "four_seasons")
	if(faction && progress["faction_minutes"] >= ACCOLADE_CITIZEN_MINUTES)
		accolade_meet(account, "citizen")
	accolade_check_knowledge(account)
	accolade_note_land(account)

/mob/living/human/proc/accolade_check_knowledge(account = null)
	if(!account)
		account = accolade_mob_ckey(src)
	if(!account)
		return
	var/known = length(clean_recipe_node_ids(known_recipe_nodes))
	if(known >= ACCOLADE_APPRENTICE_SUBJECTS)
		accolade_meet(account, "apprentice")
	if(known >= ACCOLADE_SCHOLAR_SUBJECTS)
		accolade_meet(account, "scholar")

// A faction's research moved the world into a new era: every played member
// of that faction here shares Pioneer.
/proc/accolade_era_research(faction)
	if(!istext(faction) || faction == "none")
		return
	for(var/mob/living/human/H in human_mob_list)
		if(H.client && H.stat != DEAD && H.civilization == faction)
			accolade_meet_mob(H, "pioneer")

/proc/accolades_tick()
	for(var/mob/living/human/H in human_mob_list)
		if(H.client && !QDELETED(H))
			H.accolade_minute()

// -- the window ------------------------------------------------------------------

/client/var/datum/accolade_window/accolade_window = null

/client/proc/refresh_accolade_window()
	if(accolade_window)
		GLOB.nanomanager.update_uis(accolade_window)

/client/verb/accolades_window()
	set name = "Accolades"
	set category = "OOC"
	set desc = "Your lifetime accolades and points."
	if(!accolade_client_ckey(src))
		to_chat(src, SPAN_WARNING("Accolades belong to a signed-in BYOND account. Guests cannot earn them."))
		return
	if(!accolade_window || accolade_window.owner != src)
		accolade_window = new /datum/accolade_window(src)
	accolade_window.ui_interact(mob)

/datum/accolade_window
	var/client/owner = null

/datum/accolade_window/New(client/C)
	..()
	owner = C

/datum/accolade_window/Destroy()
	GLOB.nanomanager.close_uis(src)
	if(owner && owner.accolade_window == src)
		owner.accolade_window = null
	owner = null
	return ..()

/datum/topic_state/accolades/can_use_topic(var/src_object, var/mob/user)
	var/datum/accolade_window/W = src_object
	if(!istype(W) || !W.owner || !user || user.client != W.owner)
		return STATUS_CLOSE
	return STATUS_INTERACTIVE

/datum/accolade_window/ui_actions(ui_key)
	return list("claim")

/datum/accolade_window/ui_interact(mob/user, ui_key = "main", datum/nanoui/ui = null, force_open = TRUE)
	if(!owner || !user || user.client != owner)
		return
	open_panel(user, "Accolades", 640, 700, window_sections(), ui_key = ui_key, ui = ui, force_open = force_open, state = /datum/topic_state/accolades)

// The panel: the balance, then what can be claimed now, then every accolade
// in catalog order with its state as a toned label.
/datum/accolade_window/proc/window_sections()
	var/ckey = accolade_client_ckey(owner)
	var/list/state = accolade_state(ckey)
	var/list/catalog = accolade_catalog()
	var/claimed_count = 0
	var/ready_count = 0
	var/ready_points = 0
	var/list/ready_items = list()
	var/list/lines = list()
	for(var/id in catalog)
		var/list/entry = catalog[id]
		var/list/status_cell
		switch(accolade_status(state, id))
			if("claimed")
				claimed_count++
				status_cell = panel_cell("Claimed", "good")
			if("ready")
				ready_count++
				ready_points += entry[2]
				ready_items += list(panel_item(entry[1], entry[4], list(panel_button("Claim [entry[2]] point\s", "claim", id))))
				status_cell = panel_cell("Ready", "ready")
			if("removed")
				status_cell = panel_cell("Removed by staff", "warn")
			else
				status_cell = panel_cell("Not yet", "muted")
		lines += list(list(entry[1], entry[4], entry[2], status_cell))
	var/list/notes = list("Each accolade can be claimed once per account, ever. Claimed points are kept for good and will unlock extra character slots.")
	if(!accolades_earned_here())
		notes += "Accolades are not earned in this land. Anything you have already earned can still be claimed."
	var/list/rows = list(
		panel_row("Balance", "[state["points"]] point\s", state["points"] ? "good" : "muted"),
		panel_row("Accolades", "[claimed_count] of [length(catalog)] claimed"))
	if(ready_count)
		rows += list(panel_row("Ready to claim", "[ready_count] accolade\s - [ready_points] point\s", "ready"))
	return list(
		panel_section("Lifetime points", notes = notes, rows = rows),
		ready_count ? panel_section("Ready to claim", items = ready_items) : panel_section("Ready to claim", notes = list("Nothing to claim right now. An accolade appears here as soon as you earn it.")),
		panel_section("All accolades", table = panel_table(list("Accolade", "How it is earned", "Points", "Status"), lines)))

/datum/accolade_window/ui_act(action, list/params, mob/user, datum/nanoui/ui)
	if(!owner || !user || user.client != owner)
		return TRUE
	if(action != "claim")
		return FALSE
	var/id = params["value"]
	if(!istext(id) || !accolade_catalog()[id])
		return TRUE
	var/ckey = accolade_client_ckey(owner)
	var/result = accolade_claim(ckey, id)
	if(istext(result))
		to_chat(owner, SPAN_WARNING(result))
	else
		to_chat(owner, SPAN_NOTICE("You claimed <b>[accolade_name(id)]</b> for [accolade_value(id)] lifetime point\s. You now have [accolade_points(ckey)]."))
	return TRUE

#undef ACCOLADE_CACHE_TIME
#undef ACCOLADE_SURVIVOR_MINUTES
#undef ACCOLADE_OLD_HAND_MINUTES
#undef ACCOLADE_CITIZEN_MINUTES
#undef ACCOLADE_APPRENTICE_SUBJECTS
#undef ACCOLADE_SCHOLAR_SUBJECTS
#undef ACCOLADE_WANDERER_LANDS
