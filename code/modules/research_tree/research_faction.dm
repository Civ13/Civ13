// ============================================================
// Research Tree - per-faction progress state
// ------------------------------------------------------------
// Node definitions are shared; a faction's progress toward each
// node lives here on the map metadata. Completing a node unlocks
// its recipes faction-wide (the locked design decision).
//
// Storage shape:
//   faction_research[faction] = list(node_id => list(status_hint, ticks))
// Only nodes a faction has touched get an entry; untouched nodes
// are treated as LOCKED/AVAILABLE computed on the fly.
//
// Persistence: bench objects persist their own vars automatically
// via the map object saver. This faction-level table is round-scoped
// for now, matching how custom_civs research already behaves; a
// dedicated save/load pass is deferred to a later phase.
// ============================================================

/obj/map_metadata
	var/list/faction_research = list()
	var/list/faction_bench_cap_bonus = list() // faction => permanent bonus slots from the forge
	var/list/faction_forge_progress = list()  // faction => value fed toward the next bonus slot
	var/list/faction_research_director = list() // faction => the Research Director mob
	var/list/faction_director_title = list()    // faction => the (leader-chosen) director title
	// faction => ordinal_age at the moment the faction was founded. The
	// main-tree era-baseline grant (is_node_done) is measured against THIS,
	// not the live/current ordinal_age -- otherwise an established faction
	// would instantly get every main-tree node up to a new era marked done
	// the moment ANY other faction (or the legacy age-up system) advances
	// the era, even though they never researched or unlocked any of it.
	var/list/faction_baseline_era = list()

// A faction "still exists" for reclaim purposes if at least one of its members
// is currently alive. living_mob_list excludes the dead and new_players.
/proc/faction_is_extant(faction)
	if (!faction || faction == "none")
		return FALSE
	for (var/mob/living/human/H in living_mob_list)
		if (H.civilization == faction)
			return TRUE
	return FALSE

// Authoritative leader check: the faction's stored leader record (custom_civs
// index 4) is the source of truth; fall back to the mob's own leader flag only
// if the map keeps no such record.
/obj/map_metadata/proc/is_faction_leader(mob/living/human/H, faction)
	if (!H || !faction || faction == "none")
		return FALSE
	if (H.civilization != faction)
		return FALSE
	var/list/civ_data = custom_civs[faction]
	if (civ_data && civ_data.len >= 4)
		return civ_data[4] == H
	return H.leader

/obj/map_metadata/proc/is_research_director(mob/living/human/H, faction)
	return H && faction && faction_research_director[faction] == H

// Who may change what a faction's benches research: the Leader, the Research
// Director, or an appointed Researcher -- and only within their own faction.
/obj/map_metadata/proc/can_manage_faction_research(mob/living/human/H, faction)
	if (!H || !faction || faction == "none")
		return FALSE
	if (H.civilization != faction)
		return FALSE
	if (is_faction_leader(H, faction))
		return TRUE
	if (is_research_director(H, faction))
		return TRUE
	if (H.research_role == "researcher")
		return TRUE
	return FALSE

/obj/map_metadata/proc/get_director_title(faction)
	var/t = faction_director_title[faction]
	return t ? t : "Research Director"

// Returns the stored list(status, ticks) for a node, creating none.
/obj/map_metadata/proc/get_node_entry(faction, node_id)
	if (!faction || !node_id)
		return null
	var/list/fac = faction_research[faction]
	if (!fac)
		return null
	return fac[node_id]

// Ensures a faction has a progress table and a live entry for node_id.
/obj/map_metadata/proc/ensure_node_entry(faction, node_id)
	if (!faction || !node_id)
		return null
	var/list/fac = faction_research[faction]
	if (!fac)
		fac = list()
		faction_research[faction] = fac
	var/list/entry = fac[node_id]
	if (!entry)
		entry = list(RNODE_AVAILABLE, 0, 0) // status, ticks, prototype-submitted
		fac[node_id] = entry
	return entry

// Whether the prototype for a PROTOTYPE-mode node has been fed to a bench yet.
/obj/map_metadata/proc/node_prototype_submitted(faction, node_id)
	var/list/entry = get_node_entry(faction, node_id)
	return entry && entry.len >= RNODE_ENTRY_PROTOTYPE && entry[RNODE_ENTRY_PROTOTYPE]

// Records that the prototype has been submitted (older 2-element entries are
// grown to fit the flag first).
/obj/map_metadata/proc/set_prototype_submitted(faction, node_id)
	var/list/entry = ensure_node_entry(faction, node_id)
	while (entry.len < RNODE_ENTRY_PROTOTYPE)
		entry += 0
	entry[RNODE_ENTRY_PROTOTYPE] = 1

/obj/map_metadata/proc/is_node_done(faction, node_id)
	var/datum/research_node/N = get_research_node(node_id)
	// The era-baseline free grant is a MAIN-TREE-ONLY mechanic. Specialist
	// trees (Agriculture, Tailoring, ...) must never auto-complete by era --
	// a faction's edge there is meant to be durable and actually earned, and
	// new factions/factionless start at genuine zero in them, with no
	// era-based catch-up at all (locked design decision).
	if (N && N.tree == "Main")
		if (!faction || faction == "none")
			// Factionless: no persistent identity to freeze a snapshot
			// against, and no "someone else's achievement" unfairness to
			// worry about -- always caught up to the current era.
			if (N.era_tier <= ordinal_age)
				return TRUE
		else
			// A real faction's baseline is frozen at whatever era existed
			// when they were founded (set in found_faction(), see
			// faction_creation.dm). It must
			// NOT keep growing later just because the era advances due to
			// OTHER factions' achievements or the legacy age-up system --
			// past that snapshot, they have to actually research it.
			var/snapshot_era = faction_baseline_era[faction]
			if (isnull(snapshot_era))
				// Faction predates snapshot tracking (or was created outside
				// the creation UI, e.g. a map's fixed civs) -- grandfather
				// it in at whatever era it is right now, freezing from here on.
				snapshot_era = ordinal_age
				faction_baseline_era[faction] = snapshot_era
			if (N.era_tier <= snapshot_era)
				return TRUE
	var/list/entry = get_node_entry(faction, node_id)
	return entry && entry[RNODE_ENTRY_STATUS] == RNODE_DONE

// All prereqs of node_id must be DONE for this faction.
/obj/map_metadata/proc/node_prereqs_met(faction, node_id)
	var/datum/research_node/N = get_research_node(node_id)
	if (!N)
		return FALSE
	for (var/req in N.prereqs)
		if (!is_node_done(faction, req))
			return FALSE
	return TRUE

// Computed status for display/UI.
/obj/map_metadata/proc/node_status(faction, node_id)
	if (is_node_done(faction, node_id))
		return RNODE_DONE
	if (!node_prereqs_met(faction, node_id))
		return RNODE_LOCKED
	var/list/entry = get_node_entry(faction, node_id)
	if (entry && entry[RNODE_ENTRY_TICKS] > 0)
		return RNODE_IN_PROGRESS
	return RNODE_AVAILABLE

// Adds analysis ticks toward a node; completes it when cost is met.
// Returns TRUE if the node became DONE on this call.
/obj/map_metadata/proc/add_research_ticks(faction, node_id, amount)
	var/datum/research_node/N = get_research_node(node_id)
	if (!N || amount <= 0)
		return FALSE
	if (is_node_done(faction, node_id))
		return FALSE
	if (!node_prereqs_met(faction, node_id))
		return FALSE
	var/list/entry = ensure_node_entry(faction, node_id)
	entry[RNODE_ENTRY_TICKS] += amount
	entry[RNODE_ENTRY_STATUS] = RNODE_IN_PROGRESS
	if (entry[RNODE_ENTRY_TICKS] >= N.cost_ticks)
		// A PROTOTYPE node needs BOTH the full study AND the prototype submitted.
		// If study is done but the prototype hasn't been fed in yet, hold the
		// ticks at the cap and wait -- completion happens when the prototype is
		// submitted (see the bench's attackby).
		if (N.mode == RESEARCH_MODE_PROTOTYPE && !node_prototype_submitted(faction, node_id))
			entry[RNODE_ENTRY_TICKS] = N.cost_ticks
			return FALSE
		return complete_node(faction, node_id)
	return FALSE

// Human-readable name of an ordinal age (0-8), for era-change announcements.
/proc/ordinal_age_name(age)
	var/static/list/age_names = list("Stone Age", "Classical Age", "Medieval Age", "Imperial Age", "Industrial Age", "WW1", "WW2", "Cold War", "Modern Age")
	var/i = age + 1
	if (i >= 1 && i <= age_names.len)
		return age_names[i]
	return "new age"

// TRUE if at least one research-authorised member of faction (Leader, Research
// Director or Researcher) is currently connected. Benches only tick while this
// holds, so a faction can't research while nobody who could direct it is around.
/obj/map_metadata/proc/faction_has_active_researcher(faction)
	if (!faction || faction == "none")
		return FALSE
	for (var/mob/living/human/H in human_mob_list)
		if (!H.client || H.civilization != faction)
			continue
		if (is_faction_leader(H, faction) || is_research_director(H, faction) || H.research_role == "researcher")
			return TRUE
	return FALSE

// Marks a node DONE faction-wide. Returns TRUE.
/obj/map_metadata/proc/complete_node(faction, node_id)
	var/datum/research_node/N = get_research_node(node_id)
	if (!N)
		return FALSE
	var/list/entry = ensure_node_entry(faction, node_id)
	entry[RNODE_ENTRY_STATUS] = RNODE_DONE
	entry[RNODE_ENTRY_TICKS] = N.cost_ticks
	// Era-changing nodes (the PROTOTYPE-mode capstones) advance the WHOLE WORLD
	// into their era the first time anyone completes one -- a global event,
	// announced server-wide. Every other completion is a quiet faction notice
	// (world-wide shouts for every node x faction would be pure noise).
	if (N.mode == RESEARCH_MODE_PROTOTYPE && N.era_tier > ordinal_age)
		ordinal_age = N.era_tier
		to_chat(world, "<big><font color='#c98a1d'>The discovery of <b>[N.name]</b> by the [faction] sends the world into the <b>[ordinal_age_name(N.era_tier)]</b>!</font></big>")
	else
		for (var/mob/living/human/M in human_mob_list)
			if (M.client && M.civilization == faction)
				to_chat(M, "<big>Your faction has researched <b>[N.name]</b>!</big>")
	return TRUE

// ------------------------------------------------------------
// Bench cap + resource forge (Phase 3)
// ------------------------------------------------------------

// How many benches faction is allowed to own right now.
/obj/map_metadata/proc/get_bench_cap(faction)
	var/bonus = faction_bench_cap_bonus[faction]
	return BASE_BENCH_CAP(ordinal_age) + (bonus ? bonus : 0)

// Counts benches already claimed by faction from the registered global list
// (research_benches) -- no world scan.
/obj/map_metadata/proc/count_faction_benches(faction)
	var/count = 0
	for (var/obj/structure/research_bench/B in research_benches)
		if (istype(B, /obj/structure/research_bench/adminbench))
			continue // debug-only bench; must not eat into a real faction's cap
		if (B.faction == faction)
			count++
	return count

// Read-side accessors so callers never poke the assoc lists directly
// (mirrors get_bench_cap; keeps the faction-state representation private).
/obj/map_metadata/proc/get_forge_progress(faction)
	var/progress = faction_forge_progress[faction]
	return progress ? progress : 0

/obj/map_metadata/proc/get_forge_next_cost(faction)
	var/bonus = faction_bench_cap_bonus[faction]
	return FORGE_CAP_UPGRADE_COST(bonus ? bonus : 0)

// Feeds silver coins into a faction's forge progress; grants a permanent
// +1 bench cap slot each time the escalating threshold is crossed. Progress
// accumulates across calls and overshoot rolls into the next slot. Returns
// TRUE if a new slot was granted on this call.
/obj/map_metadata/proc/add_forge_value(faction, value)
	if (!faction || value <= 0)
		return FALSE
	var/bonus = faction_bench_cap_bonus[faction]
	if (!bonus)
		bonus = 0
	var/progress = faction_forge_progress[faction]
	if (!progress)
		progress = 0
	progress += value
	var/granted = FALSE
	while (progress >= FORGE_CAP_UPGRADE_COST(bonus))
		progress -= FORGE_CAP_UPGRADE_COST(bonus)
		bonus++
		granted = TRUE
	faction_bench_cap_bonus[faction] = bonus
	faction_forge_progress[faction] = progress
	return granted
