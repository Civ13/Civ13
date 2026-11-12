// ============================================================
// Research Tree - losing an era (Val, 2026-11-12)
// ------------------------------------------------------------
// With book research an era lives in writing: the capstone chapter that
// moved the world into it. When no book, recipe manual, compendium or torn
// chapter anywhere in this world (carried, stored in a container, on a bench,
// on an offline character) still holds the capstone of the current era or a
// later one, the world falls back one era.
//
// - The check runs every ERA_LOSS_CHECK_INTERVAL; the records must be missing
//   on ERA_LOSS_MISSED_CHECKS checks in a row, so a book only briefly out of
//   the world never costs an era.
// - One era is lost at a time. If the era below has lost its records too, it
//   goes on a later check.
// - Characters keep what they studied. Anyone who still knows the capstone
//   can write it down again, which brings the era straight back.
// - A region never falls below its mainland's era (follow_mainland_epoch
//   keeps regions up with it), and holds while the mainland can't be reached.
// ============================================================

#define ERA_LOSS_CHECK_INTERVAL (5 MINUTES)
#define ERA_LOSS_MISSED_CHECKS 2

// Every book and torn chapter, so the check never scans the world.
var/global/list/era_record_items = list()

// Runtime only: world.time restarts at boot, and a reboot starts the count again.
var/global/era_loss_next_check = 0
var/global/era_loss_missed = 0

/obj/item/weapon/book/New()
	..()
	era_record_items += src

/obj/item/weapon/book/Destroy()
	era_record_items -= src
	return ..()

/obj/item/weapon/paper/research_page/New()
	..()
	era_record_items += src

/obj/item/weapon/paper/research_page/Destroy()
	era_record_items -= src
	return ..()

// The research node ids an item records in writing.
/obj/item/proc/era_record_node_ids()
	return null

/obj/item/weapon/book/era_record_node_ids()
	return research_chapter_list()

/obj/item/weapon/book/node_book/era_record_node_ids()
	return valid_recipe_node_id(node_id) ? list(node_id) : null

/obj/item/weapon/book/node_compendium/era_record_node_ids()
	return clean_recipe_node_ids(node_ids)

/obj/item/weapon/paper/research_page/era_record_node_ids()
	return valid_recipe_node_id(node_id) ? list(node_id) : null

// Capstone node id => the era it opens.
/proc/era_capstone_tiers()
	var/list/tiers = list()
	for (var/node_id in research_nodes)
		var/datum/research_node/N = research_nodes[node_id]
		if (N.mode == RESEARCH_MODE_PROTOTYPE && N.era_tier > 0)
			tiers[node_id] = N.era_tier
	return tiers

/proc/era_capstone_node(era)
	for (var/node_id in research_nodes)
		var/datum/research_node/N = research_nodes[node_id]
		if (N.mode == RESEARCH_MODE_PROTOTYPE && N.era_tier == era)
			return N
	return null

// The highest era whose capstone is still written down somewhere in this
// world (0 when none is). Deleted items and items outside the map don't count.
/proc/surviving_era_record_tier(list/items = era_record_items)
	var/list/tiers = era_capstone_tiers()
	. = 0
	for (var/obj/item/I in items)
		if (QDELETED(I) || !get_turf(I))
			continue
		for (var/node_id in I.era_record_node_ids())
			var/tier = tiers[node_id]
			if (tier > .)
				. = tier

// The lowest era this world may fall to: 0, or the mainland's era for a
// region of a group. null while the mainland's era is unknown.
/obj/map_metadata/proc/era_loss_floor()
	if (!shard_group || !shard_group.enabled || !shard_group.mainland || shard_group.region == shard_group.mainland)
		return 0
	var/list/peer = shard_group.peers[shard_group.mainland]
	if (!peer || peer["state"] != "UP" || !isnum(peer["ordinal_age"]))
		return null
	return peer["ordinal_age"]

/obj/map_metadata/proc/era_loss_tick()
	if (world.time < era_loss_next_check)
		return FALSE
	era_loss_next_check = world.time + ERA_LOSS_CHECK_INTERVAL
	return check_era_records()

// Returns TRUE when this check cost the world an era.
/obj/map_metadata/proc/check_era_records(list/items = era_record_items)
	if (!persistence || !book_research_enabled() || ordinal_age <= 0 || persistence_save_in_progress || !persistence_player_restore_ready)
		era_loss_missed = 0
		return FALSE
	var/floor = era_loss_floor()
	if (isnull(floor) || floor >= ordinal_age || surviving_era_record_tier(items) >= ordinal_age)
		era_loss_missed = 0
		return FALSE
	era_loss_missed++
	if (era_loss_missed < ERA_LOSS_MISSED_CHECKS)
		return FALSE
	era_loss_missed = 0
	return lose_era()

/obj/map_metadata/proc/lose_era()
	if (ordinal_age <= 0)
		return FALSE
	var/lost = ordinal_age
	var/datum/research_node/cap = era_capstone_node(lost)
	ordinal_age = lost - 1
	var/year = ordinal_age_year(ordinal_age)
	if (year)
		age = year
	for (var/i = ordinal_age + 1, i <= 9, i++)
		if ("age[i]_done" in vars)
			vars["age[i]_done"] = FALSE
	log_game("Book research: no written record of era [lost] is left; the world falls back to era [ordinal_age].")
	to_chat(world, "<big><font color='#8a4b2d'>The last written record of <b>[cap ? cap.name : ordinal_age_name(lost)]</b> is gone. The world falls back into the <b>[ordinal_age_name(ordinal_age)]</b>.</font></big>")
	return TRUE
