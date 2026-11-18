// ============================================================
// A faction's claimed land across the sea (docs/ship-voyage.md, "Claimed lands")
// ------------------------------------------------------------
// Val (2026-11-18): a faction's claimed island can never be stolen unless it
// abandons it, so it can always keep a recruitment station there; an island
// left empty counts as abandoned.
// - The claim on the world chart is the colony's title. Destroying the charter
//   no longer ends the colony: arrivals still join it, it still counts for
//   the hall bonus and land stages, and its own leader can plant the charter
//   again. Nobody else can claim the land while the claim stands.
// - A claim lapses when the land has had fewer than ISLAND_CLAIM_RESIDENTS
//   residents for ISLAND_CLAIM_LAPSE_DAYS days in a row: members of the colony
//   still on its roster (played within the roster's idle days) with a fastened
//   bed of their own on the land. The land drops back to settled, open to
//   any faction's claim, the charter comes down, and the colony's members
//   are told along the way.
// Stations on these lands always work: such lands have no provinces.
// State: map.faction_recruitment["island_claim"] = list(parent, short since).
// Nothing here sleeps of its own; a lapse asks the world directory (op unclaim).
// ============================================================

#define ISLAND_CLAIM_RESIDENTS 3
#define ISLAND_CLAIM_LAPSE_DAYS 14

// The faction id (civ:<land>:<name>) whose claim this land carries, or null.
/proc/island_claim_parent()
	var/key = expedition_land_key()
	if (!key)
		return null
	var/list/tile = expedition_land_tile()
	if (!islist(tile) || tile["state"] != "CLAIMED")
		return null
	var/list/claims = islist(world_chart["claims"]) ? world_chart["claims"] : list()
	for (var/claimant in claims)
		if (claims[claimant] == key && colony_parent_valid(claimant))
			return claimant
	return null

// TRUE when parent's colony here stands on its claim, charter or not.
/proc/island_claim_holds(parent)
	return parent && parent == island_claim_parent()

// The colony's parent when user leads the colony holding this land's claim.
/proc/island_claim_leader_parent(mob/living/human/user)
	var/parent = island_claim_parent()
	if (!parent || !map || !user.civilization || user.civilization == "none")
		return null
	var/list/row = map.faction_colonies()[user.civilization]
	if (!islist(row) || row[1] != parent || !map.is_faction_leader(user, user.civilization))
		return null
	return parent

// Residents of the colony holding the claim: roster accounts with a bed here.
/proc/island_claim_residents(name)
	var/count = 0
	var/list/roster = map.faction_roster(name)
	var/list/seen = list()
	for (var/obj/structure/bed/B in all_beds)
		var/account = B.persistence_bed_owner_ckey
		if (!account || seen[account] || QDELETED(B) || !B.anchored || !isturf(B.loc) || !islist(roster[account]))
			continue
		seen[account] = TRUE
		count++
	return count

/proc/island_claim_tell(name, message)
	for (var/mob/living/human/H in human_mob_list)
		if (H.client && H.stat != DEAD && H.civilization == name)
			to_chat(H, SPAN_WARNING(message))

// Runs with the land's chart refresh (land_stage.dm).
/proc/island_claim_check()
	var/parent = island_claim_parent()
	if (!parent || !map)
		return
	var/list/S = map.recruitment_state()
	var/list/state = S["island_claim"]
	if (!islist(state) || state.len != 2 || state[1] != parent)
		state = list(parent, 0)
		S["island_claim"] = state
	var/name = map.colony_named_for(parent)
	var/residents = name ? island_claim_residents(name) : 0
	if (residents >= ISLAND_CLAIM_RESIDENTS)
		if (state[2] && name)
			island_claim_tell(name, "[name]'s claim on this land is safe again.")
		state[2] = 0
		return
	if (!state[2])
		state[2] = world.realtime
		if (name)
			island_claim_tell(name, "Fewer than [ISLAND_CLAIM_RESIDENTS] of [name]'s members live here. If nobody settles in within [ISLAND_CLAIM_LAPSE_DAYS] days, the land counts as abandoned and the claim lapses.")
		return
	if (world.realtime - state[2] < ISLAND_CLAIM_LAPSE_DAYS * 864000)
		return
	if (!expedition_land_ask("unclaim", null, parent))
		return
	S -= "island_claim"
	// As when a leader gives the claim up (land_choices.dm), the charter comes down.
	var/obj/structure/colony_charter/C = name ? map.colony_charter_of(name) : null
	if (C)
		C.faction = null
		C.update_icon()
	if (name)
		map.recruitment_audit(name, "The claim on this land lapsed: fewer than [ISLAND_CLAIM_RESIDENTS] members lived here for [ISLAND_CLAIM_LAPSE_DAYS] days.", "")
	log_game("Colony: [parent]'s claim on this land lapsed after [ISLAND_CLAIM_LAPSE_DAYS] days with fewer than [ISLAND_CLAIM_RESIDENTS] residents.")
	to_chat(world, "<big><b>[html_encode(name || party_train_party_name(parent))]</b> left this land empty too long. Its claim has lapsed.</big>")

/proc/island_claim_text(parent)
	if (!island_claim_holds(parent) || !map)
		return null
	var/list/state = map.recruitment_state()["island_claim"]
	if (islist(state) && state.len == 2 && state[1] == parent && state[2])
		var/days = max(0, round((ISLAND_CLAIM_LAPSE_DAYS * 864000 - (world.realtime - state[2])) / 864000, 0.1))
		return "The claim lapses in [days] days unless [ISLAND_CLAIM_RESIDENTS] members live here."
	return "The land is claimed for good while [ISLAND_CLAIM_RESIDENTS] members live here."

#undef ISLAND_CLAIM_RESIDENTS
#undef ISLAND_CLAIM_LAPSE_DAYS
