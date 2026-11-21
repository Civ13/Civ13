// Faction rosters, member limits and member starts (docs/land-stages.md,
// "Faction members"). Val's rules (2026-11-14):
// - A faction has a member limit. It grows with the faction's hall and
//   colonies (faction_hall.dm), up to the server's FACTION_MEMBER_LIMIT.
// - Joining a faction in character puts the player's account on its roster.
//   From then on that account's new characters may start with the faction.
// - Nobody may start with a faction before joining it in play.
//
// The roster counts accounts, alive or waiting to start again, so a limit
// holds through deaths. Leaving the faction takes the account off; an account
// that has not played a member for FACTION_ROSTER_IDLE_DAYS drops off, so
// inactive accounts do not fill a faction. Rosters and leader-set limits live
// in map.faction_recruitment (durable, keyed by faction name, renamed with it).
//
// Member starts, stations and the leader verb are in faction_start.dm.
// Nothing here sleeps.

/proc/faction_member_limit_default()
	return config && isnum(config.faction_member_limit) ? config.faction_member_limit : 50

/proc/faction_roster_idle_time()
	var/days = config && isnum(config.faction_roster_idle_days) ? config.faction_roster_idle_days : 14
	return days * 24 * 60 * 60 * 10

// The account a character's membership belongs to, or null (guests have none).
/proc/faction_roster_account(mob/living/human/H)
	if (!istype(H))
		return null
	if (H.persistence_owner_ckey)
		return H.persistence_owner_ckey
	if (H.client && !IsGuestKey(H.client.key))
		return H.client.owner_key()
	return null

// faction -> list(account -> list(joined, seen)); created on first use.
/obj/map_metadata/proc/faction_rosters()
	var/list/S = recruitment_state()
	if (!islist(S["rosters"]))
		S["rosters"] = list()
	return S["rosters"]

/obj/map_metadata/proc/faction_limits()
	var/list/S = recruitment_state()
	if (!islist(S["limits"]))
		S["limits"] = list()
	return S["limits"]

// Drops malformed roster rows and limits (a damaged save is never trusted).
/obj/map_metadata/proc/faction_roster_normalize()
	var/list/rosters = faction_rosters()
	for (var/faction in rosters.Copy())
		var/list/roster = rosters[faction]
		if (!istext(faction) || !islist(roster))
			rosters -= faction
			continue
		for (var/account in roster.Copy())
			var/list/row = roster[account]
			if (!istext(account) || ckey(account) != account || !islist(row) || row.len != 2 || !isnum(row[1]) || !isnum(row[2]))
				roster -= account
	var/list/limits = faction_limits()
	for (var/faction in limits.Copy())
		if (!istext(faction) || !isnum(limits[faction]) || limits[faction] < 1 || limits[faction] != round(limits[faction]))
			limits -= faction
	colony_normalize()
	faction_seal_normalize()
	treasury_normalize()
	land_normalize()
	office_normalize()
	justice_normalize()
	bill_normalize()
	papers_normalize()
	treaty_normalize()

// The faction's roster with idle accounts removed.
/obj/map_metadata/proc/faction_roster(faction)
	var/list/rosters = faction_rosters()
	var/list/roster = rosters[faction]
	if (!islist(roster))
		return list()
	var/cutoff = world.realtime - faction_roster_idle_time()
	for (var/account in roster.Copy())
		var/list/row = roster[account]
		if (!islist(row) || row.len != 2 || !isnum(row[2]) || row[2] < cutoff)
			roster -= account
	return roster

// The server ceiling, what the faction's hall and colonies support
// (faction_hall.dm), and any lower limit its leader set.
/obj/map_metadata/proc/faction_member_cap(faction)
	return min(faction_member_limit_default(), faction_infrastructure_limit(faction))

/obj/map_metadata/proc/faction_member_limit(faction)
	var/limit = faction_member_cap(faction)
	var/list/limits = faction_limits()
	if (isnum(limits[faction]))
		limit = min(limit, limits[faction])
	return limit

/obj/map_metadata/proc/faction_on_roster(faction, account)
	if (!account)
		return FALSE
	var/list/roster = faction_roster(faction)
	return islist(roster[account])

// TRUE when account may not take a new place in faction: the roster is at
// its limit and the account is not already on it.
/obj/map_metadata/proc/faction_full_for(faction, account)
	if (faction_on_roster(faction, account))
		return FALSE
	var/list/roster = faction_roster(faction)
	return roster.len >= faction_member_limit(faction)

/obj/map_metadata/proc/faction_roster_add(faction, account)
	if (!istext(faction) || faction == "none" || !account)
		return FALSE
	var/list/rosters = faction_rosters()
	var/list/roster = rosters[faction]
	if (!islist(roster))
		roster = list()
		rosters[faction] = roster
	var/list/row = roster[account]
	if (islist(row) && row.len == 2)
		row[2] = world.realtime
	else
		roster[account] = list(world.realtime, world.realtime)
	return TRUE

/obj/map_metadata/proc/faction_roster_remove(faction, account)
	var/list/rosters = faction_rosters()
	var/list/roster = rosters[faction]
	if (islist(roster) && account)
		roster -= account

// A member played: keep the account from going idle. A character that was
// already a member before rosters existed (or before it went idle) is put back:
// it is in the faction in play, which is what earns the place.
/obj/map_metadata/proc/faction_roster_touch(mob/living/human/H)
	if (!istype(H) || H.stat == DEAD || !H.civilization || H.civilization == "none" || !(H.civilization in custom_civs))
		return
	faction_roster_add(H.civilization, faction_roster_account(H))

/obj/map_metadata/proc/faction_roster_rename(old_name, new_name)
	faction_rename_assoc_key(faction_rosters(), old_name, new_name)
	faction_rename_assoc_key(faction_limits(), old_name, new_name)
	colony_rename(old_name, new_name)
	faction_seal_rename(old_name, new_name)
	coin_issuer_rename(old_name, new_name)
	treasury_rename(old_name, new_name)
	land_rename(old_name, new_name)
	office_rename(old_name, new_name)
	justice_rename(old_name, new_name)
	bill_rename(old_name, new_name)
	papers_rename(old_name, new_name)
	treaty_rename(old_name, new_name)
