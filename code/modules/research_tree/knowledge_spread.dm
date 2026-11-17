// ============================================================
// Research Tree - knowledge spreads with a lag (Val, 2026-11-17)
// ------------------------------------------------------------
// On book-research worlds a subject falls into one of three bands, set only
// by how many eras its own era is behind the world's:
//   Guarded   - the newest eras: research, books and teaching as ever.
//   Spreading - further behind: quicker to learn and to research again.
//   Common    - further still: everyone knows it.
// The two lags are server config (KNOWLEDGE_SPREADING_ERAS and
// KNOWLEDGE_COMMON_ERAS). Nothing is saved: the band follows the era, up or
// down. This file only works the band out and names it; what each band does
// lives beside the thing it changes.
// ============================================================

/proc/knowledge_spreading_lag()
	return config && isnum(config.knowledge_spreading_eras) ? config.knowledge_spreading_eras : 2

/proc/knowledge_common_lag()
	return config && isnum(config.knowledge_common_eras) ? config.knowledge_common_eras : 4

// The band of a subject of era_tier in a world at world_era, for the given
// lags. Common wins when the lags overlap.
/proc/knowledge_band_for(era_tier, world_era, spreading_lag, common_lag)
	if (!isnum(era_tier) || !isnum(world_era))
		return KNOWLEDGE_GUARDED
	var/behind = world_era - era_tier
	if (isnum(common_lag) && behind >= common_lag)
		return KNOWLEDGE_COMMON
	if (isnum(spreading_lag) && behind >= spreading_lag)
		return KNOWLEDGE_SPREADING
	return KNOWLEDGE_GUARDED

// The band of node_id on this world now. Subjects found only in books, and
// every subject off a book-research world, stay guarded.
/proc/knowledge_band(node_id)
	if (!map || !map.book_research_enabled())
		return KNOWLEDGE_GUARDED
	var/datum/research_node/N = get_research_node(node_id)
	if (!N || N.mode == RESEARCH_MODE_BOOK || research_node_dormant(N))
		return KNOWLEDGE_GUARDED
	return knowledge_band_for(N.era_tier, map.ordinal_age, knowledge_spreading_lag(), knowledge_common_lag())

/proc/knowledge_band_name(band)
	switch (band)
		if (KNOWLEDGE_COMMON)
			return "common knowledge"
		if (KNOWLEDGE_SPREADING)
			return "spreading"
	return "guarded"

// A subject's era as the research windows show it: "Stone Age", or
// "Stone Age - common knowledge" once the subject is no longer guarded.
/proc/research_era_label(datum/research_node/N)
	if (!N)
		return ""
	var/band = knowledge_band(N.id)
	var/era = ordinal_age_name(N.era_tier)
	return band == KNOWLEDGE_GUARDED ? era : "[era] - [knowledge_band_name(band)]"

// Every subject in band now.
/proc/knowledge_band_node_ids(band)
	var/list/ids = list()
	for (var/node_id in research_nodes)
		if (knowledge_band(node_id) == band)
			ids += node_id
	return ids

// ------------------------------------------------------------
// Common knowledge: everyone knows it
// ------------------------------------------------------------
// A living character gains every common subject it lacks: when a player
// takes the body (so a new character starts with them) and when the era
// advances. What was gained is kept if the era later falls. It brings no
// scholarship and no skill: only the subjects themselves.

// The latest era that is common knowledge now, or -1 when none is.
/proc/knowledge_common_era()
	if (!map || !map.book_research_enabled())
		return -1
	return min(9, map.ordinal_age - knowledge_common_lag())

// Adds the common subjects src lacks. Returns how many were added.
/mob/living/human/proc/grant_common_knowledge(announce = TRUE)
	if (stat == DEAD || !map || !map.book_research_enabled() || recipe_knowledge_exempt())
		return 0
	var/list/common = knowledge_band_node_ids(KNOWLEDGE_COMMON)
	if (!common.len)
		return 0
	var/list/known = clean_recipe_node_ids(known_recipe_nodes)
	var/had = known.len
	known |= common
	var/gained = known.len - had
	if (!gained)
		return 0
	known_recipe_nodes = known
	recipe_knowledge_initialized = TRUE
	for (var/node_id in common)
		clear_study_progress(node_id)
	refresh_recipe_knowledge_menus()
	if (announce)
		var/through = ordinal_age_name(knowledge_common_era())
		if (had)
			to_chat(src, SPAN_NOTICE("Knowledge up to the <b>[through]</b> is common now: you know [gained] more subject\s without a book. The tech tree shows them."))
		else
			to_chat(src, SPAN_NOTICE("Knowledge up to the <b>[through]</b> is common in this age: you already know [gained] subject\s. The tech tree shows them. Newer subjects are learned from books, from people who know them, or by research."))
	return gained

/mob/living/human/Login()
	..()
	grant_common_knowledge()

// The era moved up: every living character gains what became common.
/proc/knowledge_era_advanced()
	if (!map || !map.book_research_enabled() || knowledge_common_era() < 0)
		return 0
	var/reached = 0
	for (var/mob/living/human/H in human_mob_list)
		if (H.grant_common_knowledge())
			reached++
	return reached

// ------------------------------------------------------------
// Spreading knowledge: quicker to learn
// ------------------------------------------------------------
// Reading a spreading subject's chapter, or hearing it read aloud, takes half
// the time (scholar_study_time), and watching and guided work can teach all
// of it at any era (trade_learning_cap). It still needs a book or a teacher.

/proc/knowledge_study_mult(node_id)
	return knowledge_band(node_id) == KNOWLEDGE_SPREADING ? KNOWLEDGE_SPREADING_STUDY : 1

// Researching a spreading subject again is cheaper: the world already knows
// it can be done. Bench work on it counts KNOWLEDGE_REDISCOVERY_RATE times;
// samples, field work and prototypes keep their usual shares.
/proc/knowledge_rediscovery_rate(node_id)
	return knowledge_band(node_id) == KNOWLEDGE_SPREADING ? KNOWLEDGE_REDISCOVERY_RATE : 1
