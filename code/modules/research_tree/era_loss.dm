// ============================================================
// Research Tree - each land's era follows its books (Val, 2026-11-12, 2026-11-23)
// ------------------------------------------------------------
// With book research an era lives in writing: the capstone chapter that
// moved a land into it. Every land (each region world, and a world on its
// own) keeps the era whose capstone is written down in that land: in a book,
// recipe manual, compendium or torn chapter that is carried, stored in a
// container, on a bench or on an offline character there. A capstone written
// in one land does nothing for another until a copy is taken there.
//
// - The records are checked every ERA_RECORD_CHECK_INTERVAL.
// - When no copy of the current era's capstone (or a later one) is left in a
//   land, because the last one was carried to another land or destroyed, the
//   land keeps its era for ERA_RECORD_RETURN_WINDOW. A copy brought back (or
//   written again) in that time costs nothing. After it the land falls back
//   one era, and one more every ERA_RECORD_STEP while the records are missing.
// - When a land holds a later capstone than its era, carried in from another
//   land, the land rises one era once that copy has stayed ERA_RECORD_SETTLE_TIME,
//   and one more every ERA_RECORD_STEP until it reaches the book's era
//   (gain_era in book_research.dm). So a
//   book that leaves its land for good slowly moves its era with it, and one
//   brought home in time moves nothing.
// - Writing a capstone (or writing a lost one again from memory) moves the
//   land straight into its era, as before.
// - Characters keep what they studied. The Stone Age is never lost.
// - The clocks are real time and saved with the world (era_records_state), so
//   a restart or a sleeping land does not reset them.
// ============================================================

// Every book and torn chapter, so the check never scans the world.
var/global/list/era_record_items = list()

// Runtime only: world.time restarts at boot.
var/global/era_loss_next_check = 0

// Saved (durable map field version 7): when this land's records first went
// missing ("missing_since"), when a later capstone first arrived
// ("above_since") and when the era last moved by this file ("last_step"),
// each as world.realtime written as text, which JSON keeps exactly.
/obj/map_metadata/var/list/era_records_state = list()

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
// land (0 when none is). Deleted items and items outside the map don't count.
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

// A saved clock, or null when unset or unreadable.
/obj/map_metadata/proc/era_record_clock(key)
	if (!islist(era_records_state))
		era_records_state = list()
	var/value = era_records_state[key]
	if (istext(value))
		value = text2num(value)
	return isnum(value) ? value : null

/obj/map_metadata/proc/set_era_record_clock(key, value)
	if (!islist(era_records_state))
		era_records_state = list()
	if (isnull(value))
		era_records_state -= key
	else
		era_records_state[key] = num2text(value, 20)

// Time since a clock started, starting it now when unset. A clock that reads
// later than now (the host's clock went back) starts again.
/obj/map_metadata/proc/era_record_elapsed(key, now)
	var/since = era_record_clock(key)
	if (isnull(since) || since > now)
		set_era_record_clock(key, now)
		return 0
	return now - since

/obj/map_metadata/proc/era_record_step_ready(now)
	var/last = era_record_clock("last_step")
	return isnull(last) || last > now || now - last >= ERA_RECORD_STEP

// The land's era now matches its records (a capstone was just written).
/obj/map_metadata/proc/era_records_settled()
	set_era_record_clock("missing_since", null)
	set_era_record_clock("above_since", null)

/obj/map_metadata/proc/era_loss_tick()
	if (world.time < era_loss_next_check)
		return FALSE
	era_loss_next_check = world.time + ERA_RECORD_CHECK_INTERVAL
	return check_era_records()

// Returns TRUE when this check moved the land's era, down or up.
/obj/map_metadata/proc/check_era_records(list/items = era_record_items, now = world.realtime)
	// The clocks wait through a save or a load rather than starting over.
	if (!persistence || !book_research_enabled() || persistence_save_in_progress || !persistence_player_restore_ready)
		return FALSE
	var/held = surviving_era_record_tier(items)
	if (held < ordinal_age)
		set_era_record_clock("above_since", null)
		if (era_record_elapsed("missing_since", now) < ERA_RECORD_RETURN_WINDOW || !era_record_step_ready(now))
			return FALSE
		if (!lose_era())
			return FALSE
		set_era_record_clock("last_step", now)
		// The era below may be missing too; it goes a step later.
		if (held >= ordinal_age)
			set_era_record_clock("missing_since", null)
		return TRUE
	set_era_record_clock("missing_since", null)
	if (held == ordinal_age)
		set_era_record_clock("above_since", null)
		return FALSE
	if (era_record_elapsed("above_since", now) < ERA_RECORD_SETTLE_TIME || !era_record_step_ready(now))
		return FALSE
	if (!gain_era())
		return FALSE
	set_era_record_clock("last_step", now)
	if (held <= ordinal_age)
		set_era_record_clock("above_since", null)
	return TRUE

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
	log_game("Book research: no written record of era [lost] has been in this land for too long; it falls back to era [ordinal_age].")
	to_chat(world, "<big><font color='#8a4b2d'>No written record of <b>[cap ? cap.name : ordinal_age_name(lost)]</b> has been in these lands for too long. They fall back into the <b>[ordinal_age_name(ordinal_age)]</b>.</font></big>")
	return TRUE
