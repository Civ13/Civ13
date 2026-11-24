// Colony charters (docs/land-stages.md, "Colonies"). Factions live in one
// land. A traveller now carries their faction's id (civ:<land>:<name>, the
// land it was founded in) across a trail. A leader who carries it into another
// land can plant a colony charter there: it founds the faction in that land
// under the same name, and from then on members arriving from any land rejoin
// it. A colony counts only while a charter bound to it stands, so it can be
// raided away. Each world reports its standing colonies to the coordinator
// with its population sample (land_stage.dm); a colony that has stood for 3
// days with 3 living members suggests the land for the COLONY stage.
//
// Colonies live in map.faction_recruitment["colonies"]: local faction name ->
// list(parent faction id, founded world.realtime). Nothing here sleeps except
// the planting prompt, which rechecks everything after it.

var/global/list/colony_charters = list() // every colony charter, bound or not

// Saved with the body: the faction this character travelled as, and whether
// they led it when they left. Set on arrival from another land.
/mob/living/human/var/colony_origin = null
/mob/living/human/var/colony_origin_leader = FALSE

/proc/colony_parent_valid(id)
	return istext(id) && findtext(id, "civ:") == 1 && party_train_valid_party(id)

// The id a character travels as: a colony's members travel as its parent
// faction, so the identity always names the land the faction was founded in.
/proc/colony_faction_id(mob/living/human/H)
	if (!istype(H) || !H.civilization || H.civilization == "none" || !map || !shard_group.enabled)
		return null
	var/list/colonies = map.faction_colonies()
	var/list/row = colonies[H.civilization]
	if (islist(row) && colony_parent_valid(row[1]))
		return row[1]
	return party_train_faction_party(H.civilization)

/proc/colony_colour_valid(value)
	if (!istext(value) || length(value) != 7 || copytext(value, 1, 2) != "#")
		return FALSE
	for (var/i = 2, i <= 7, i++)
		if (!findtext("0123456789abcdefABCDEF", copytext(value, i, i + 1)))
			return FALSE
	return TRUE

// --- Map state -------------------------------------------------------------

/obj/map_metadata/proc/faction_colonies()
	var/list/S = recruitment_state()
	if (!islist(S["colonies"]))
		S["colonies"] = list()
	return S["colonies"]

/obj/map_metadata/proc/colony_normalize()
	var/list/colonies = faction_colonies()
	for (var/name in colonies.Copy())
		var/list/row = colonies[name]
		if (!istext(name) || !islist(row) || row.len != 2 || !colony_parent_valid(row[1]) || !isnum(row[2]))
			colonies -= name

/obj/map_metadata/proc/colony_rename(old_name, new_name)
	faction_rename_assoc_key(faction_colonies(), old_name, new_name)

// The local faction planted for parent, or null.
/obj/map_metadata/proc/colony_named_for(parent)
	var/list/colonies = faction_colonies()
	for (var/name in colonies)
		var/list/row = colonies[name]
		if (islist(row) && row[1] == parent && (name in custom_civs))
			return name
	return null

/obj/map_metadata/proc/colony_charter_of(name)
	for (var/obj/structure/colony_charter/C in colony_charters)
		if (!QDELETED(C) && C.faction == name && isturf(C.loc))
			return C
	return null

// The faction a member of parent joins on arrival here: the parent itself
// when it was founded in this land, else its standing colony.
/obj/map_metadata/proc/colony_home_faction(parent)
	if (!colony_parent_valid(parent))
		return null
	var/prefix = "civ:[shard_group.region]:"
	if (findtext(parent, prefix) == 1)
		var/name = copytext(parent, length(prefix) + 1)
		return (name in custom_civs) ? name : null
	var/name = colony_named_for(parent)
	// A colony on its claimed land stands without its charter (island_claim.dm).
	return name && (colony_charter_of(name) || island_claim_holds(parent)) ? name : null

// Standing colonies for the land sample: parent, local name, age in whole
// hours and living members (characters that belong to an account).
/obj/map_metadata/proc/colony_report()
	var/list/report = list()
	var/list/colonies = faction_colonies()
	for (var/name in colonies)
		var/list/row = colonies[name]
		if (!islist(row) || !(name in custom_civs) || !(colony_charter_of(name) || island_claim_holds(row[1])) || report.len >= 50)
			continue
		var/members = 0
		for (var/mob/living/human/H in human_mob_list)
			if (H.civilization == name && H.persistence_owner_ckey && H.stat != DEAD && !QDELETED(H))
				members++
		report += list(list("parent" = row[1], "name" = name, "age_hours" = max(0, round((world.realtime - row[2]) / 36000)), "members" = members))
	return report

// --- Arrival ----------------------------------------------------------------

// A traveller keeps the faction they left as, and rejoins it here when it
// lives in this land (home, or a standing colony). Called by region travel
// after a party train has restored its own party.
/proc/colony_arrival(mob/living/human/H, list/P)
	if (!istype(H) || !map || !islist(P) || !colony_parent_valid(P["faction"]))
		return FALSE
	H.colony_origin = P["faction"]
	H.colony_origin_leader = P["faction_leader"] == 1
	if (!map.allows_custom_factions() || (H.civilization && H.civilization != "none"))
		return FALSE
	var/name = map.colony_home_faction(H.colony_origin)
	if (!name || !H.enroll_in_faction(name))
		return FALSE
	to_chat(H, SPAN_NOTICE("You rejoin [name] here."))
	return TRUE

// --- The charter ------------------------------------------------------------

/obj/structure/colony_charter
	name = "colony charter"
	desc = "A post to hang a faction's charter on. Planted in another land by a faction's leader, it founds a colony there."
	icon = 'icons/obj/flags.dmi'
	icon_state = "flagpole_blank"
	density = FALSE
	anchored = TRUE
	flammable = TRUE
	layer = MOB_LAYER + 0.01
	// The colony this charter stands for, by name. faction_rename.dm rewrites
	// vars called "faction", so a rename keeps the binding.
	var/faction = null

/obj/structure/colony_charter/New()
	..()
	colony_charters |= src
	update_icon()

/obj/structure/colony_charter/Destroy()
	colony_charters -= src
	return ..()

/obj/structure/colony_charter/update_icon()
	name = faction ? "[faction] colony charter" : initial(name)

/obj/structure/colony_charter/examine(mob/user)
	..()
	if (!faction)
		to_chat(user, "No charter hangs on it yet. A faction's leader who has travelled here from their own land can plant one.[expedition_land_key() ? " Planted on a land across the sea, it claims the island as the faction's own: only those the faction lets land can sail here (Faction > Faction Island)." : ""]")
		return
	var/list/row = map ? map.faction_colonies()[faction] : null
	if (islist(row))
		to_chat(user, "It holds the charter of [faction], a colony from [copytext(row[1], 5, findtext(row[1], ":", 5))].")
	else
		to_chat(user, "It holds the charter of [faction].")
	var/claim = islist(row) ? island_claim_text(row[1]) : null
	if (claim)
		to_chat(user, claim)
		// The claimed island's border (island_access.dm).
		to_chat(user, island_access_status_text(row[1]))

// A founder must be playing their own signed-in BYOND character beside the
// charter. Overseas visitors keep their home faction in colony_origin until
// there is a local branch to join; a current local faction takes precedence.
// Use the same ten-minute active-client window as province stake.
/obj/structure/colony_charter/proc/continent_founder_account(mob/living/human/H, origin)
	if (!istype(H) || QDELETED(H) || H.stat || H.sleeping)
		return null
	var/client/C = H.client
	if (!C || C.mob != H || !C.ckey || IsGuestKey(C.key) || C.inactivity >= 10 MINUTES)
		return null
	if (H.persistence_owner_ckey != C.owner_key() || !isturf(H.loc) || H.z != z || get_dist(H, src) > 1)
		return null
	if (H.civilization && H.civilization != "none")
		if (colony_faction_id(H) != origin)
			return null
	else if (H.colony_origin != origin)
		return null
	return C.ckey

/obj/structure/colony_charter/proc/continent_founders_ready(mob/living/human/user, origin)
	var/account = continent_founder_account(user, origin)
	if (!account)
		return FALSE
	for (var/client/C in clients)
		if (C == user.client)
			continue
		var/other = continent_founder_account(C.mob, origin)
		if (other && other != account)
			return TRUE
	return FALSE

// Why user cannot plant a charter here now, or null.
/obj/structure/colony_charter/proc/plant_block(mob/living/human/user)
	if (!map || !shard_group.enabled || !map.allows_custom_factions())
		return "Colonies can only be planted in a land of the wider world."
	if (faction)
		return "A charter already hangs here."
	if (!isturf(loc) || user.stat || get_dist(user, src) > 1)
		return "You must stand beside the charter post."
	// The leader of the colony holding this land's claim plants its charter again (island_claim.dm).
	var/claimed = island_claim_leader_parent(user)
	if (claimed)
		var/own = map.colony_named_for(claimed)
		return own && map.colony_charter_of(own) ? "[own]'s charter already stands in this land." : null
	var/origin = user.colony_origin
	if (!colony_parent_valid(origin) || !user.colony_origin_leader)
		return "Only a faction's leader who travelled here from their faction's land can plant a colony."
	if (findtext(origin, "civ:[shard_group.region]:") == 1)
		return "This is your faction's own land."
	if (user.civilization && user.civilization != "none")
		return "You must not belong to a faction here."
	var/name = party_train_party_name(origin)
	// A land across the sea takes one faction's claim, and a faction claims one such land (land_choices.dm).
	if (expedition_land_key())
		var/list/tile = expedition_land_tile()
		var/list/claims = islist(world_chart["claims"]) ? world_chart["claims"] : list()
		if (claims[origin] && claims[origin] != expedition_land_key())
			return "[name] already claims another land across the sea. A faction claims only one."
		if (islist(tile) && tile["state"] == "CLAIMED" && claims[origin] != expedition_land_key())
			return "This land is already claimed."
	var/existing = map.colony_named_for(origin)
	if (existing && map.colony_charter_of(existing))
		return "[existing] already has a colony in this land. Members who arrive join it."
	if (!existing && map.faction_name_taken(name))
		return "A faction called [name] already lives in this land."
	if (!existing && !expedition_land_key() && continent_home() && !continent_founders_ready(user, origin))
		return "To found a colony on this continent, you and another active member of your faction must stand beside the charter on separate signed-in BYOND accounts."
	return null

/obj/structure/colony_charter/attack_hand(mob/living/human/user)
	if (!ishuman(user))
		return ..()
	if (faction)
		examine(user)
		if (unclaim_parent(user))
			unclaim_menu(user) // land_choices.dm
		return
	var/block = plant_block(user)
	if (block)
		to_chat(user, SPAN_WARNING(block))
		return
	var/name = party_train_party_name(island_claim_leader_parent(user) || user.colony_origin)
	var/answer = WWinput(user, "Plant the charter of [name] here, founding a colony of your faction in this land? Members of [name] who arrive here will join it.", "Colony Charter", "Cancel", list("Plant the charter", "Cancel"))
	if (answer != "Plant the charter")
		return
	plant(user)

/obj/structure/colony_charter/proc/plant(mob/living/human/user)
	// Recheck after the prompt, immediately before changing charter or faction.
	var/block = plant_block(user)
	if (block)
		to_chat(user, SPAN_WARNING(block))
		return FALSE
	var/origin = island_claim_leader_parent(user) || user.colony_origin
	var/name = map.colony_named_for(origin)
	if (name)
		// The colony lost its charter; a leader of the parent, or its own, sets it up again.
		if (user.civilization != name)
			user.enroll_in_faction(name)
	else
		name = party_train_party_name(origin)
		map.colony_found(user, name, origin)
	faction = name
	update_icon()
	map.recruitment_audit(name, "[user.real_name] planted the colony charter at [x],[y].", faction_roster_account(user) || "")
	// On a land across the sea the charter is the faction's claim to it.
	if (expedition_land_key() && !island_claim_holds(origin))
		expedition_land_ask("claim", user.ckey, origin)
	log_game("Colony: [key_name(user)] planted the charter of [name] ([origin]) at [x],[y],[z].")
	to_chat(user, "<big>The charter of <b>[name]</b> now stands in this land.</big>")
	return TRUE

// A new local faction named for the parent, led by the leader who planted it.
// It starts with this land's research, like any new faction: knowledge lives
// in books, which travellers can carry over.
/obj/map_metadata/proc/colony_found(mob/living/human/founder, name, parent)
	founder.civilization = name
	faction_roster_add(name, faction_roster_account(founder))
	founder.leader = TRUE
	founder.faction_perms = list(1,1,1,1)
	custom_faction_nr += name
	custom_civs += list("[name]" = list(default_research, default_research, default_research, founder, 0, "star", "#000000", "#FFFFFF", 10, 10))
	faction_baseline_era[name] = ordinal_age
	faction_symbol_grid[name] = faction_symbol_new_grid()
	faction_colonies()[name] = list(parent, world.realtime)
	founder.make_commander()
	founder.make_title_changer()
	founder.grant_faction_symbol_editor()
	return TRUE
