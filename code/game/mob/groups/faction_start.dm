// Member starts (faction_roster.dm holds the rosters and limits). A member
// start places the new character beside one of the faction's recruitment
// stations; only an account on the roster is offered one, so nobody starts
// with a faction before joining it in play (Val, 2026-11-14).

#define FACTION_START_WILDS "Here, on your own"

var/global/list/recruitment_stations = list() // every recruitment station, for member starts

// The faction this lobby chose to start with, set by faction_start_prompt.
/mob/new_player/var/faction_start_choice = null
// A colony start the coordinator granted this account here: the colony's
// parent faction id (colony_charter.dm). Set by region_home_admit.
/mob/new_player/var/colony_start_grant = null
// Where a member start places the new body on a land without random starts;
// job relocation takes it (job_controller.dm relocate).
/mob/living/human/var/tmp/faction_start_turf = null

/mob/living/human/Login()
	..()
	if (map && map.allows_custom_factions())
		map.faction_roster_touch(src)
	province_activity_start() // province_stake.dm

// --- Member starts ---------------------------------------------------------

// Open lands (docs/land-stages.md) whose wilds a player may start in from
// here: OPEN and not paused. Players in their first two days always start in
// the land they joined, near the most people. Returns label -> land id.
/mob/new_player/proc/wild_start_choices()
	var/list/choices = list()
	if (!client || IsGuestKey(client.key) || !shard_group.enabled || !region_home_enabled() || new_player_marks.is_new(client))
		return choices
	for (var/land in land_stages)
		var/list/entry = land_stages[land]
		if (land == shard_group.region || !islist(entry) || entry["stage"] != "OPEN" || entry["paused"])
			continue
		var/list/peer = shard_group.peers[land]
		choices["In the wilds of [peer ? peer["name"] : land]"] = land
	return choices

// A turf beside one of the faction's recruitment stations or its colony
// charter where a new character can stand.
/obj/map_metadata/proc/faction_start_turf(faction)
	var/list/anchors = list()
	for (var/obj/structure/recruitment_station/S in recruitment_stations)
		if (!QDELETED(S) && S.faction == faction && isturf(S.loc))
			anchors += S
	var/obj/structure/colony_charter/charter = colony_charter_of(faction)
	if (charter)
		anchors += charter
	for (var/atom/anchor in anchors)
		for (var/turf/T in orange(1, anchor))
			if (T.density || T.water_level || istype(T, /turf/floor/beach/water))
				continue
			var/blocked = FALSE
			for (var/atom/movable/AM in T)
				if (AM.density)
					blocked = TRUE
					break
			if (!blocked)
				return T
	return null

// Factions this account may start with here now: on the roster (or granted
// a start at this colony) and with a station or charter that has room beside it.
/obj/map_metadata/proc/faction_start_choices(account, grant = null)
	var/list/choices = list()
	if (!account || !allows_custom_factions())
		return choices
	var/list/rosters = faction_rosters()
	for (var/faction in rosters)
		if ((faction in custom_civs) && faction_on_roster(faction, account) && faction_start_turf(faction))
			choices += faction
	var/granted = grant ? colony_home_faction(grant) : null
	if (granted && !(granted in choices) && faction_start_turf(granted))
		choices += granted
	return choices

// Colonies in other lands this account may start at: factions founded here
// that it is a member of, with a colony standing in a land that takes colony
// starts (COLONY or OPEN). Returns label -> list(land, faction id).
/obj/map_metadata/proc/faction_colony_choices(account)
	var/list/choices = list()
	if (!account || !allows_custom_factions() || !shard_group.enabled)
		return choices
	var/list/colonies = faction_colonies()
	var/list/rosters = faction_rosters()
	for (var/faction in rosters)
		if (!(faction in custom_civs) || colonies[faction] || !faction_on_roster(faction, account))
			continue
		var/parent = party_train_faction_party(faction)
		for (var/land in land_stages)
			var/list/entry = land_stages[land]
			if (land == shard_group.region || !islist(entry) || !(entry["stage"] in list("COLONY", "OPEN")))
				continue
			for (var/list/colony in entry["colonies"])
				// A colony nobody has lived in for days takes no starts.
				if (islist(colony) && colony["parent"] == parent && !colony["paused"])
					var/list/peer = shard_group.peers[land]
					choices["With [colony["name"]] in [peer ? peer["name"] : land]"] = list(land, parent)
	return choices

// Asks a member where to start. Returns FALSE when the player cancelled or
// left, TRUE otherwise (faction_start_choice says which faction, if any).
/mob/new_player/proc/faction_start_prompt()
	faction_start_choice = null
	if (!client || IsGuestKey(client.key) || !map)
		return TRUE
	var/account = client.ckey
	var/list/choices = map.faction_start_choices(account, colony_start_grant)
	var/list/abroad = map.faction_colony_choices(account)
	var/list/wilds = wild_start_choices()
	// Signal fires whose keepers invited newcomers (immigration_fires.dm).
	var/list/fires = immigration_fire_choices()
	immigration_fire_choice = null
	if (!choices.len && !abroad.len && !wilds.len && !fires.len)
		return TRUE
	var/list/options = list(FACTION_START_WILDS)
	for (var/faction in choices)
		options += "With [faction]"
	options += fires
	options += abroad
	options += wilds
	var/answer = WWinput(src, "Where should your new character start?[death_legacy_preview(choices, FACTION_START_WILDS)]", "Starting place", FACTION_START_WILDS, options)
	if (!client || client.mob != src)
		return FALSE
	if (!istext(answer) || answer == FACTION_START_WILDS)
		return TRUE
	if (answer in fires)
		immigration_fire_choice = fires[answer]
		return TRUE
	if (answer in wilds)
		// The coordinator moves this account's home to that open land.
		var/land = wilds[answer]
		if (!region_home_ask(account, "start", land))
			to_chat(src, SPAN_WARNING("The world directory cannot be reached right now. Try again in a minute."))
		else
			to_chat(src, SPAN_NOTICE("Your next character will start in the wilds there. In a few seconds, join that land:"))
			region_home_tell(src, land)
		return FALSE
	if (answer in abroad)
		// The coordinator moves this account's home to that land and grants
		// the start there; the player joins that land's server to take it.
		var/list/pick = abroad[answer]
		var/list/result = region_home_ask(account, "colony", pick[1], pick[2])
		if (!result)
			to_chat(src, SPAN_WARNING("The world directory cannot be reached right now. Try again in a minute."))
		else
			to_chat(src, SPAN_NOTICE("Your next character will start [lowertext(copytext(answer, 1, 2))][copytext(answer, 2)]. In a few seconds, join that land:"))
			region_home_tell(src, pick[1])
		return FALSE
	var/faction = copytext(answer, length("With ") + 1)
	if (faction in choices)
		faction_start_choice = faction
		// A granted colony start is used once.
		if (colony_start_grant && map.colony_home_faction(colony_start_grant) == faction && !map.faction_on_roster(faction, account))
			region_home_ask(account, "colony_used", null, colony_start_grant)
	return TRUE

// The start turf for this lobby's chosen faction, or null when it is gone
// (the station destroyed, the roster changed): the player starts as usual.
/mob/new_player/proc/faction_start_destination()
	if (!faction_start_choice || !client || !map)
		return null
	var/granted = colony_start_grant && map.colony_home_faction(colony_start_grant) == faction_start_choice
	if ((!granted && !map.faction_on_roster(faction_start_choice, client.ckey)) || !(faction_start_choice in map.custom_civs))
		faction_start_choice = null
		return null
	var/turf/T = map.faction_start_turf(faction_start_choice)
	if (!T)
		faction_start_choice = null
	return T

// The new character joins the faction it starts with. Membership was earned
// in play, so the rejoin cooldown of an earlier life does not apply.
/mob/new_player/proc/faction_start_apply(mob/living/human/H)
	if (!istype(H) || !faction_start_choice || !map)
		return FALSE
	var/faction = faction_start_choice
	var/turf/T = faction_start_destination()
	faction_start_choice = null
	if (!client || !T)
		return FALSE
	var/granted = colony_start_grant && map.colony_home_faction(colony_start_grant) == faction
	colony_start_grant = null
	if (!granted && !map.faction_on_roster(faction, client.ckey))
		return FALSE
	H.clear_faction_privileges()
	H.civilization = faction
	map.faction_roster_add(faction, client.ckey)
	H.faction_start_turf = T
	to_chat(H, SPAN_NOTICE("You start out with [faction]."))
	return TRUE

// --- Leader verb -----------------------------------------------------------

/mob/living/human/proc/set_faction_member_limit()
	set name = "Set Member Limit"
	set category = "Faction"
	if (!map || !civilization || civilization == "none" || !map.is_faction_leader(src, civilization) || stat == DEAD)
		to_chat(src, SPAN_WARNING("Only a faction's leader can set its member limit."))
		return
	var/faction = civilization
	var/list/roster = map.faction_roster(faction)
	var/cap = map.faction_member_cap(faction)
	var/value = player_input(src, "[faction] has [roster.len] of [map.faction_member_limit(faction)] members. Set a limit from 1 to [cap] (what your hall and colonies support; build up your hall to raise it).", "Member Limit", map.faction_member_limit(faction), "num", null, TRUE)
	if (!isnum(value) || civilization != faction || !map.is_faction_leader(src, faction) || stat == DEAD)
		return
	value = clamp(round(value), 1, cap)
	var/list/limits = map.faction_limits()
	if (value >= cap)
		limits -= faction
	else
		limits[faction] = value
	map.recruitment_audit(faction, "[real_name] set the member limit to [value].", faction_roster_account(src) || "")
	to_chat(src, SPAN_NOTICE("[faction]'s member limit is now [value]. Members already on the roster stay."))

#undef FACTION_START_WILDS
