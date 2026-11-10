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

/proc/node_scholar_requirement(node_id)
	var/datum/research_node/N = get_research_node(node_id)
	return N ? min(SCHOLAR_MAX_LEVEL, max(0, N.era_tier) * SCHOLAR_LEVEL_PER_TIER) : 0

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
	return 1 + clamp(margin / 50, 0, 1)

// Adds skill for work on node_id. Work well below the character's level
// teaches less, so the way up is the next tier, not old chapters.
/mob/living/human/proc/gain_scholarship(node_id, amount)
	if (amount <= 0 || !valid_recipe_node_id(node_id))
		return
	var/discipline = node_discipline(node_id)
	var/req = node_scholar_requirement(node_id)
	if (!islist(scholarship))
		scholarship = list()
	var/level = scholar_level(discipline)
	var/factor = clamp(1 - (level - req) / (SCHOLAR_LEVEL_PER_TIER * 2), 0.1, 1)
	scholarship[discipline] = min(SCHOLAR_MAX_LEVEL, round(level + amount * factor, 0.01))
	if (discipline != "mathematics")
		var/math = scholar_level("mathematics")
		var/math_factor = clamp(1 - (math - req / 2) / (SCHOLAR_LEVEL_PER_TIER * 2), 0.1, 1)
		scholarship["mathematics"] = min(SCHOLAR_MAX_LEVEL, round(math + amount * math_factor / 2, 0.01))

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
	if (stat == DEAD)
		scholarship = list()

/mob/living/human/forget_recipe_knowledge()
	..()
	scholarship = list()

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
