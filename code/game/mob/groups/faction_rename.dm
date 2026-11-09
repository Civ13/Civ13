// ============================================================
// Faction Renaming
// ------------------------------------------------------------
// A player-founded faction's Leader may rename it with the Rename Faction
// verb (a Faction panel button, granted and revoked alongside Modify Faction
// Symbol). A faction name is the key for most faction state, so the rename
// re-keys every map list and world reference in one synchronous pass, with
// no sleep in between: a world save can't capture half a rename.
//
// For the next FACTION_RENAME_NOTICE_SEASONS counted seasons, examining the
// faction (its members, banners, posters, the Faction List) shows the old
// name. The record lives in map.faction_renames, which is in the durable map
// inventory (durable_contract.dm), and the season clock is the durable
// abandonment_season_changes counter, so both survive a world save/load.
// ============================================================

#define FACTION_RENAME_NOTICE_SEASONS 8
#define FACTION_RENAME_COOLDOWN (1 HOURS)

// Object/mob variables that hold a custom faction's name as plain text
// (banners, doors, benches, tamed animals' mob.faction, warrants' tgtcmp...).
// Only exact matches against the old name are rewritten.
var/global/list/faction_rename_text_vars = list("faction", "tgtcmp")

// Record for a faction's current name: list(previous name, value of
// abandonment_season_changes at the rename, world.realtime at the rename).
// Returns null when there is no rename still inside the notice window.
/obj/map_metadata/proc/faction_rename_record(faction)
	if (!istext(faction))
		return null
	var/list/record = faction_renames[faction]
	if (!islist(record) || record.len < 2 || !istext(record[1]) || !isnum(record[2]))
		return null
	if (abandonment_season_changes - record[2] >= FACTION_RENAME_NOTICE_SEASONS)
		return null
	return record

/obj/map_metadata/proc/faction_previous_name(faction)
	var/list/record = faction_rename_record(faction)
	return record ? record[1] : null

// One sentence, or "" when the faction has no recent rename.
/obj/map_metadata/proc/faction_rename_notice(faction)
	var/previous = faction_previous_name(faction)
	if (!previous)
		return ""
	return "[capitalize(previous)] was recently renamed to [faction]."

// Drops records whose notice window has closed.
/obj/map_metadata/proc/prune_faction_renames()
	for (var/faction in faction_renames.Copy())
		if (!faction_rename_record(faction))
			faction_renames -= faction

// Why this faction can't be renamed right now, or null if it can.
/obj/map_metadata/proc/faction_rename_block_reason(faction)
	if (!allows_custom_factions())
		return "Factions can't be renamed on this map."
	if (!istext(faction) || !(faction in custom_faction_nr) || !(faction in custom_civs))
		return "Only factions founded by players can be renamed."
	if (persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required)
		return "The world is being saved. Try again in a moment."
	var/list/record = faction_renames[faction]
	if (islist(record) && record.len >= 3 && isnum(record[3]))
		var/remaining = record[3] + FACTION_RENAME_COOLDOWN - world.realtime
		if (remaining > 0)
			return "Your faction was renamed recently. Try again in [max(1, round(remaining / (1 MINUTES)))] minute\s."
	return null

// Moves an association to a new key, keeping its position in the list.
/proc/faction_rename_assoc_key(list/L, old_key, new_key)
	if (!islist(L))
		return
	var/index = L.Find(old_key)
	if (!index)
		return
	var/value = L[old_key]
	if (new_key in L)
		// A stale entry under the new name (from a faction that no longer
		// exists) must not survive alongside the renamed faction's own.
		L -= new_key
		index = L.Find(old_key)
	L.Cut(index, index + 1)
	L.Insert(index, new_key)
	L[new_key] = value

// Rewrites faction-name variables on one atom. Returns TRUE if any changed.
/proc/faction_rename_atom_vars(atom/A, old_name, new_name)
	var/list/V = A.vars
	var/changed = FALSE
	for (var/key in faction_rename_text_vars)
		if ((key in V) && V[key] == old_name)
			V[key] = new_name
			changed = TRUE
	return changed

// Renames a player-founded faction everywhere its name is used as a key or a
// reference. Callers check permissions; this checks only data consistency.
// Returns TRUE on success.
/obj/map_metadata/proc/rename_faction(old_name, new_name)
	if (!istext(old_name) || !istext(new_name) || !length(new_name) || old_name == new_name || new_name == "none")
		return FALSE
	var/index = custom_faction_nr.Find(old_name)
	if (!index || !(old_name in custom_civs))
		return FALSE
	if (faction_name_taken(new_name, old_name))
		return FALSE

	// Map state keyed by faction name.
	custom_faction_nr[index] = new_name
	for (var/list/L in list(custom_civs, faction_motto, faction_flavour, \
			faction_symbol_grid, faction_symbol_icon, faction_symbol_tool, faction_symbol_color, faction_symbol_undo, \
			faction_research, faction_bench_cap_bonus, faction_forge_progress, faction_research_director, \
			faction_director_title, faction_baseline_era, scores, marketplaceaccounts, assign_precursors, facl))
		faction_rename_assoc_key(L, old_name, new_name)

	// Map state that stores the name as a value.
	for (var/list/R in vehicle_registrations)
		if (R.len >= 2 && R[2] == old_name)
			R[2] = new_name
	for (var/key in globalmarketplace)
		var/list/entry = globalmarketplace[key]
		if (islist(entry) && entry.len >= 1 && entry[1] == old_name)
			entry[1] = new_name

	// The rename notice. A faction renamed twice inside the window shows only
	// its latest previous name.
	prune_faction_renames()
	faction_renames -= old_name
	faction_renames[new_name] = list(old_name, abandonment_season_changes, world.realtime)

	// Members, former members, and tamed animals (mob.faction).
	for (var/mob/M in world)
		if (ishuman(M))
			var/mob/living/human/H = M
			if (H.civilization == old_name)
				H.civilization = new_name
			for (var/list/left in H.left_factions)
				if (left.len >= 1 && left[1] == old_name)
					left[1] = new_name
		faction_rename_atom_vars(M, old_name, new_name)

	// Banners, posters, doors, research benches, official papers, oil
	// deposits, passports and the like. Their names and descriptions were
	// built from the faction name, so those follow too.
	for (var/obj/O in world)
		if (faction_rename_atom_vars(O, old_name, new_name))
			O.name = replacetext(O.name, old_name, new_name)
			if (istext(O.desc))
				O.desc = replacetext(O.desc, old_name, new_name)
	// Party trains (party_train.dm) belong to the faction, not its old name.
	party_train_rename_faction(old_name, new_name)
	// Recruitment policy, applications and audit (faction_recruitment.dm).
	recruitment_rename_faction(old_name, new_name)
	return TRUE

/mob/living/human/proc/rename_own_faction()
	set name = "Rename Faction"
	set category = "Faction"
	set desc = "Choose a new name for your faction."

	if (!map || !civilization || civilization == "none")
		to_chat(src, SPAN_WARNING("You are not part of any faction."))
		return
	var/old_name = civilization
	if (!map.is_faction_leader(src, old_name))
		to_chat(src, SPAN_WARNING("Only the Leader of your faction may rename it."))
		return
	var/reason = map.faction_rename_block_reason(old_name)
	if (reason)
		to_chat(src, SPAN_WARNING(reason))
		return

	var/newname = player_input(src, "Choose a new name for [old_name]. For the next [FACTION_RENAME_NOTICE_SEASONS] seasons, anyone examining your faction will also see its old name.", "Rename Faction", old_name, "text", null, TRUE)
	if (!newname)
		return
	// Same rule as founding (faction_creation.dm): the name becomes an assoc
	// key and raw HTML, so markup is stripped rather than encoded.
	newname = sanitize(newname, FACTION_NAME_MAX_CHARS + 1, FALSE)
	if (!newname || newname == "" || newname == "none")
		to_chat(src, SPAN_WARNING("That name contains nothing usable. Choose another name."))
		return
	if (newname == old_name)
		return
	if (map.faction_name_taken(newname, old_name))
		to_chat(src, SPAN_WARNING("That name is taken by another faction, or was one until recently. Choose another name."))
		return

	var/confirm = WWinput(src, "Rename [old_name] to [newname]? Your faction can't be renamed again for an hour.", "Rename Faction", "Cancel", list("Rename", "Cancel"))
	if (confirm != "Rename")
		return
	// The dialogs above block; re-check everything that could have changed.
	if (stat || !map || civilization != old_name || !map.is_faction_leader(src, old_name))
		return
	reason = map.faction_rename_block_reason(old_name)
	if (reason)
		to_chat(src, SPAN_WARNING(reason))
		return
	if (!map.rename_faction(old_name, newname))
		to_chat(src, SPAN_WARNING("That name is no longer available. Choose another name."))
		return

	log_game("[key_name(src)] renamed the faction [old_name] to [newname].")
	for (var/mob/living/human/H in world)
		if (H.civilization == newname && H.client)
			to_chat(H, "<big>Your faction, <b>[old_name]</b>, has been renamed to <b>[newname]</b> by [src.real_name].</big>")

/mob/living/human/proc/grant_faction_rename()
	verbs += /mob/living/human/proc/rename_own_faction

/mob/living/human/proc/remove_faction_rename()
	verbs -= /mob/living/human/proc/rename_own_faction

// Examining faction property shows the recent-rename notice.
/obj/structure/banner/faction/examine(mob/user, distance = -1)
	. = ..()
	if (map && faction != "none")
		var/notice = map.faction_rename_notice(faction)
		if (notice)
			to_chat(user, "<i>[notice]</i>")

/obj/structure/poster/faction/examine(mob/user, distance = -1)
	. = ..()
	if (map && faction != "none")
		var/notice = map.faction_rename_notice(faction)
		if (notice)
			to_chat(user, "<i>[notice]</i>")
