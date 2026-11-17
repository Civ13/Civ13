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
