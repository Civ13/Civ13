// ============================================================
// Research Tree - scholarship skills (Persistence redesign, Val 2026-11-10)
// ------------------------------------------------------------
// With book research on, progressing research needs a researcher skilled
// enough in the node's discipline, plus Basic Mathematics at half that.
// These skills are separate from body stats. They grow by scholarly work in
// the discipline (researching, studying), with less for work far below the
// character's level, and belong to the character: a new body starts at 0.
// Studying and copying need no skill; only discovery is gated.
// ============================================================

var/global/list/scholar_disciplines = list(
	"mathematics" = "Basic Mathematics",
	"engineering" = "Engineering",
	"natural_science" = "Natural Science",
	"medicine" = "Medicine",
	"agriculture" = "Agriculture",
	"military" = "Military Science")

// Nodes whose discipline differs from their category's default.
var/global/list/scholar_node_disciplines = list(
	"early_economy" = "mathematics",
	"papermaking" = "mathematics",
	"printing_currency" = "mathematics",
	"digital_computing" = "mathematics",
	"digital_networks" = "mathematics",
	"planetary_survey" = "mathematics",
	"orbital_flight" = "mathematics",
	"alloys" = "natural_science",
	"steelmaking" = "natural_science",
	"early_cells" = "natural_science",
	"galvanic_cells" = "natural_science",
	"glassworking" = "natural_science",
	"optics_instruments" = "natural_science",
	"electricity" = "natural_science",
	"combustion" = "natural_science",
	"nuclear_power" = "natural_science",
	"hydraulic_fracturing" = "natural_science",
	"gunpowder" = "natural_science",
	"rocketry" = "natural_science",
	"life_support" = "natural_science",
	"synthetics" = "natural_science",
	"basic_agriculture" = "agriculture",
	"weaving" = "agriculture",
	"furriery" = "agriculture")

// Subjects that also teach a related discipline. Player suggestion relayed by
// Val 2026-11-23: Natural Science had too few subjects of its own to grow
// from ("stone masonry, it's about stone, that's natural science"). Work on
// these (research, study, finds, active work) also teaches
// SCHOLAR_RELATED_SHARE of the gain in the related discipline, never its
// Basic Mathematics share again. Nothing is gated by it: a subject still
// needs only its own discipline, and the tree order is unchanged.
var/global/list/scholar_node_related = list(
	"pottery_storage" = "natural_science",
	"herbalism" = "natural_science",
	"stone_masonry" = "natural_science",
	"resource_processing" = "natural_science",
	"bronze_working" = "natural_science",
	"brickmaking" = "natural_science",
	"ore_dressing" = "natural_science",
	"iron_smithing" = "natural_science",
	"crucible_steel" = "natural_science",
	"tatara_smelting" = "natural_science",
	"apothecary" = "natural_science",
	"irrigation" = "natural_science",
	"amalgamation" = "natural_science",
	"blast_furnaces" = "natural_science",
	"pharmacology" = "natural_science",
	"germ_theory" = "natural_science",
	"open_hearth" = "natural_science",
	"aluminium_refining" = "natural_science",
	"soil_science" = "natural_science",
	"crop_breeding" = "natural_science",
	"planetary_survey" = "natural_science",
	"off_world_mining" = "natural_science",
	"local_resources" = "natural_science")

// The related discipline node_id also teaches, or null.
/proc/node_related_discipline(node_id)
	var/related = scholar_node_related[node_id]
	return (related && related != node_discipline(node_id)) ? related : null

// TRUE when work on node_id counts toward discipline, as its own or related one.
/proc/node_teaches_discipline(node_id, discipline)
	return node_discipline(node_id) == discipline || node_related_discipline(node_id) == discipline

/proc/node_discipline(node_id)
	if (node_id in scholar_node_disciplines)
		return scholar_node_disciplines[node_id]
	var/datum/research_node/N = get_research_node(node_id)
	if (!N)
		return "mathematics"
	switch (N.category)
		if ("Health")
			return "medicine"
		if ("Agriculture", "Textiles")
			return "agriculture"
		if ("Military", "Armour")
			return "military"
	return "engineering"

// The earliest era tier holding a node of each discipline. A discipline's
// first nodes need no skill, so every discipline can be started from scratch
// (Natural Science begins at era 1, not era 0).
var/global/list/scholar_entry_tiers = null

/proc/scholar_entry_tier(discipline)
	if (!scholar_entry_tiers)
		var/list/tiers = list()
		for (var/node_id in research_nodes)
			var/datum/research_node/N = research_nodes[node_id]
			var/d = node_discipline(node_id)
			var/t = max(0, N.era_tier)
			if (isnull(tiers[d]) || t < tiers[d])
				tiers[d] = t
		if (!tiers.len)
			return 0
		scholar_entry_tiers = tiers
	var/tier = scholar_entry_tiers[discipline]
	return isnum(tier) ? tier : 0

/proc/node_scholar_requirement(node_id, discipline = null)
	var/datum/research_node/N = get_research_node(node_id)
	if (!N)
		return 0
	var/steps = max(0, N.era_tier - scholar_entry_tier(discipline ? discipline : node_discipline(node_id)))
	return min(SCHOLAR_MAX_LEVEL, steps * SCHOLAR_LEVEL_PER_TIER)

/mob/living/human
	var/list/scholarship = null // discipline => level (0-100)

/mob/living/human/proc/scholar_level(discipline)
	if (!islist(scholarship))
		return 0
	var/level = scholarship[discipline]
	return isnum(level) ? clamp(level, 0, SCHOLAR_MAX_LEVEL) : 0

/mob/living/human/proc/meets_scholar_requirement(node_id)
	var/req = node_scholar_requirement(node_id)
	return scholar_level(node_discipline(node_id)) >= req && scholar_level("mathematics") >= req / 2

// Research speed multiplier: 1 at the requirement, up to 2 well above it.
/mob/living/human/proc/scholar_research_rate(node_id)
	var/margin = scholar_level(node_discipline(node_id)) - node_scholar_requirement(node_id)
	return (1 + clamp(margin / 50, 0, 1)) * recluse_rate() * study_field_research_mult(node_discipline(node_id)) * adhd_bench_mult()

// Adds skill for work on node_id. Work well below the character's level
// teaches less, so the way up is the next tier, not old chapters.
/mob/living/human/proc/gain_scholarship(node_id, amount)
	if (amount <= 0 || !valid_recipe_node_id(node_id))
		return
	var/discipline = node_discipline(node_id)
	var/req = node_scholar_requirement(node_id)
	var/base_amount = amount
	amount *= trait_scholarship_gain_mult(discipline)
	if (!islist(scholarship))
		scholarship = list()
	var/level = scholar_level(discipline)
	var/factor = clamp(1 - (level - req) / (SCHOLAR_LEVEL_PER_TIER * 2), 0.1, 1)
	// A field of study (study_fields.dm) changes the discipline's own gain,
	// never its Basic Mathematics share.
	scholarship[discipline] = min(SCHOLAR_MAX_LEVEL, round(level + amount * study_field_gain_mult(discipline) * factor, 0.01))
	if (discipline != "mathematics")
		var/math = scholar_level("mathematics")
		var/math_factor = clamp(1 - (math - req / 2) / (SCHOLAR_LEVEL_PER_TIER * 2), 0.1, 1)
		scholarship["mathematics"] = min(SCHOLAR_MAX_LEVEL, round(math + amount * math_factor / 2, 0.01))
	// A related discipline learns a share, judged against the subject's era
	// in that discipline so old work teaches it less too.
	var/related = node_related_discipline(node_id)
	if (related)
		var/related_level = scholar_level(related)
		var/related_req = node_scholar_requirement(node_id, related)
		var/related_factor = clamp(1 - (related_level - related_req) / (SCHOLAR_LEVEL_PER_TIER * 2), 0.1, 1)
		var/related_amount = base_amount * SCHOLAR_RELATED_SHARE * trait_scholarship_gain_mult(related) * study_field_gain_mult(related)
		scholarship[related] = min(SCHOLAR_MAX_LEVEL, round(related_level + related_amount * related_factor, 0.01))

/proc/clean_scholarship(value)
	var/list/result = list()
	if (islist(value))
		for (var/discipline in scholar_disciplines)
			var/level = value[discipline]
			if (isnum(level) && level > 0)
				result[discipline] = min(SCHOLAR_MAX_LEVEL, level)
	return result

/mob/living/human/persistence_import_fields(list/saved_fields)
	. = ..()
	scholarship = clean_scholarship(scholarship)
	if (!istext(scholar_master) || length(scholar_master) > 200)
		scholar_master = null
	if (stat == DEAD)
		scholarship = list()
		scholar_master = null

/mob/living/human/forget_recipe_knowledge()
	..()
	scholarship = list()
	scholar_master = null

/mob/living/human/proc/scholar_requirement_text(node_id)
	var/req = node_scholar_requirement(node_id)
	if (!req)
		return "No scholarship needed"
	return "Needs [scholar_disciplines[node_discipline(node_id)]] [req] and Basic Mathematics [round(req / 2)]"

/mob/living/human/verb/check_scholarship()
	set name = "Check scholarship"
	set category = "IC"
	if (!map || !map.book_research_enabled())
		to_chat(src, SPAN_WARNING("Scholarship isn't used here."))
		return
	var/list/lines = list("<b>Your scholarship</b>")
	for (var/discipline in scholar_disciplines)
		lines += "[scholar_disciplines[discipline]]: [round(scholar_level(discipline))]"
	to_chat(src, jointext(lines, "<br>"))

// ------------------------------------------------------------
// Scholarship tab
// ------------------------------------------------------------

// The latest era a character can research in discipline, mirroring
// node_scholar_requirement(): each tier past the discipline's first needs
// SCHOLAR_LEVEL_PER_TIER more levels (capped at the maximum), plus Basic
// Mathematics at half that.
/mob/living/human/proc/scholar_research_reach(discipline)
	var/entry = scholar_entry_tier(discipline)
	var/level = scholar_level(discipline)
	var/math = scholar_level("mathematics")
	var/reach = entry
	for (var/tier = entry + 1, tier <= 9, tier++)
		var/req = min(SCHOLAR_MAX_LEVEL, (tier - entry) * SCHOLAR_LEVEL_PER_TIER)
		if (level < req || math < req / 2)
			break
		reach = tier
	return reach

// Rows for the Scholarship tab: list(label, value) pairs.
/mob/living/human/proc/scholarship_panel_rows()
	var/list/rows = list()
	rows[++rows.len] = list("<h3>Scholarship</h3>", "")
	for (var/discipline in scholar_disciplines)
		rows[++rows.len] = list("<b>[scholar_disciplines[discipline]]:</b>", "[round(scholar_level(discipline))] / [SCHOLAR_MAX_LEVEL], research up to the [ordinal_age_name(scholar_research_reach(discipline))]")
	rows += study_field_panel_rows()
	var/title = scholar_title()
	rows[++rows.len] = list("<b>Title:</b>", title ? title : "None yet (reach [SCHOLAR_TITLE_APPRENTICE] in a discipline)")
	if (istext(scholar_master))
		var/split = findtext(scholar_master, ":")
		rows[++rows.len] = list("<b>Master:</b>", split ? copytext(scholar_master, split + 1) : scholar_master)
	var/apprentices = scholar_apprentice_count()
	if (apprentices)
		rows[++rows.len] = list("<b>Apprentices:</b>", "[apprentices] / [SCHOLAR_MAX_APPRENTICES]")
	rows[++rows.len] = list("<b>How to raise them:</b>", "IC tab, Skills Guide")
	return rows

/mob/living/human/Stat()
	. = ..()
	if (. && client && client.status_tabs && map && map.book_research_enabled() && client.add_stat_tab("Scholarship"))
		for (var/list/row in scholarship_panel_rows())
			client.add_stat(row[1], row[2])
