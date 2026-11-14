// Member starts (faction_roster.dm holds the rosters and limits). A member
// start places the new character beside one of the faction's recruitment
// stations; only an account on the roster is offered one, so nobody starts
// with a faction before joining it in play (Val, 2026-11-14).

#define FACTION_START_WILDS "In the wilds, as a nomad"

var/global/list/recruitment_stations = list() // every recruitment station, for member starts

// The faction this lobby chose to start with, set by faction_start_prompt.
/mob/new_player/var/faction_start_choice = null

/mob/living/human/Login()
	..()
	if (map && map.allows_custom_factions())
		map.faction_roster_touch(src)

// --- Member starts ---------------------------------------------------------

// A turf beside one of the faction's stations where a new character can stand.
/obj/map_metadata/proc/faction_start_turf(faction)
	for (var/obj/structure/recruitment_station/S in recruitment_stations)
		if (QDELETED(S) || S.faction != faction || !isturf(S.loc))
			continue
		for (var/turf/T in orange(1, S))
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

// Factions this account may start with now: on the roster and with a station
// that has room beside it.
/obj/map_metadata/proc/faction_start_choices(account)
	var/list/choices = list()
	if (!account || !allows_custom_factions())
		return choices
	var/list/rosters = faction_rosters()
	for (var/faction in rosters)
		if ((faction in custom_civs) && faction_on_roster(faction, account) && faction_start_turf(faction))
			choices += faction
	return choices

// Asks a member where to start. Returns FALSE when the player cancelled or
// left, TRUE otherwise (faction_start_choice says which faction, if any).
/mob/new_player/proc/faction_start_prompt()
	faction_start_choice = null
	if (!client || IsGuestKey(client.key) || !map)
		return TRUE
	var/list/choices = map.faction_start_choices(client.ckey)
	if (!choices.len)
		return TRUE
	var/list/options = list(FACTION_START_WILDS)
	for (var/faction in choices)
		options += "With [faction]"
	var/answer = WWinput(src, "You are a member of [english_list(choices)]. Where should your new character start?", "Starting place", FACTION_START_WILDS, options)
	if (!client || client.mob != src)
		return FALSE
	if (!istext(answer) || answer == FACTION_START_WILDS)
		return TRUE
	var/faction = copytext(answer, length("With ") + 1)
	if (faction in choices)
		faction_start_choice = faction
	return TRUE

// The start turf for this lobby's chosen faction, or null when it is gone
// (the station destroyed, the roster changed): the player starts as usual.
/mob/new_player/proc/faction_start_destination()
	if (!faction_start_choice || !client || !map)
		return null
	if (!map.faction_on_roster(faction_start_choice, client.ckey) || !(faction_start_choice in map.custom_civs))
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
	faction_start_choice = null
	if (!client || !map.faction_on_roster(faction, client.ckey))
		return FALSE
	H.clear_faction_privileges()
	H.civilization = faction
	map.faction_roster_add(faction, client.ckey)
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
	var/cap = faction_member_limit_default()
	var/value = player_input(src, "[faction] has [roster.len] of [map.faction_member_limit(faction)] members. Set a limit from 1 to [cap] (the server's limit).", "Member Limit", map.faction_member_limit(faction), "num", null, TRUE)
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
