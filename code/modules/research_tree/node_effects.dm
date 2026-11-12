// ============================================================
// Research Tree - standing effects of late nodes (Val, 2026-11-12)
// ------------------------------------------------------------
// Some late nodes unlock few or no recipes. On book-research worlds a
// character who has studied one of them also gains a standing benefit, so
// every late chapter is worth reading. Knowledge is personal: the benefit
// follows the character who knows the node, not their faction.
// ============================================================

// Metal tools and weapons forged by someone who knows Alloys last longer.
#define NODE_EFFECT_ALLOY_DURABILITY 1.3
// Extra harvest fraction for a farmer who knows Advanced Agriculture.
#define NODE_EFFECT_FARM_YIELD 0.25
// Surgery step success multiplier for a surgeon who knows Anesthetic Surgery.
#define NODE_EFFECT_SURGERY_QUALITY 1.15
// Surgery step time multiplier for a surgeon who knows Modern Medicine.
#define NODE_EFFECT_SURGERY_TIME 0.75
// Chance multiplier of catching an illness for someone who knows Public Health.
#define NODE_EFFECT_DISEASE_CHANCE 0.5
// Flight fuel multiplier for a pilot who knows Aviation & Rocketry.
#define NODE_EFFECT_FLIGHT_FUEL 0.75

// node id => what knowing it does, shown in the research windows.
var/global/list/research_node_effects = list(
	"alloys" = "Metal tools and weapons you forge last 30% longer.",
	"advanced_agriculture" = "Your harvests give 25% more crop and seed.",
	"anesthetic_surgery" = "Your patients lie still: each surgery step is 15% more likely to succeed.",
	"modern_medicine" = "You finish each surgery step a quarter faster.",
	"public_health" = "You are half as likely to catch an illness from people nearby or from poor hygiene.",
	"aviation_rocketry" = "Aircraft you pilot burn a quarter less fuel in the air.")

// The effect line for the research windows, or null off book-research worlds.
/proc/research_node_effect_text(node_id)
	if (!map || !map.book_research_enabled())
		return null
	return research_node_effects[node_id]

// Whether this character holds a node's standing effect. Agent characters are
// exempt from personal knowledge, so they have studied nothing and gain none.
/mob/living/human/proc/has_node_effect(node_id)
	if (!map || !map.book_research_enabled() || !(node_id in research_node_effects))
		return FALSE
	return !recipe_knowledge_exempt() && knows_recipe_node(node_id)

/proc/mob_has_node_effect(mob/user, node_id)
	var/mob/living/human/H = user
	return istype(H) && H.has_node_effect(node_id)

// Alloys: called for every crafted item; only metal material tools gain.
/proc/apply_crafting_node_effects(mob/user, atom/crafted)
	var/obj/item/weapon/material/M = crafted
	if (!istype(M) || !M.material || M.unbreakable || M.maxhealth <= 0)
		return FALSE
	if (!istype(M.material, /material/steel) && !istype(M.material, /material/iron) && !istype(M.material, /material/bronze))
		return FALSE
	if (!mob_has_node_effect(user, "alloys"))
		return FALSE
	M.maxhealth = round(M.maxhealth * NODE_EFFECT_ALLOY_DURABILITY)
	M.health = M.maxhealth
	return TRUE

// Advanced Agriculture: added to the farming skill's harvest bonus.
/proc/farming_node_bonus(mob/user)
	return mob_has_node_effect(user, "advanced_agriculture") ? NODE_EFFECT_FARM_YIELD : 0

// Anesthetic Surgery / Modern Medicine: surgeon-side scales.
/proc/surgery_node_quality(mob/user)
	return mob_has_node_effect(user, "anesthetic_surgery") ? NODE_EFFECT_SURGERY_QUALITY : 1

/proc/surgery_node_time(mob/user)
	return mob_has_node_effect(user, "modern_medicine") ? NODE_EFFECT_SURGERY_TIME : 1

// Public Health: scales the chance of catching a contagious illness.
/mob/living/human/proc/disease_node_scale()
	return has_node_effect("public_health") ? NODE_EFFECT_DISEASE_CHANCE : 1

// Aviation & Rocketry: scales fuel burnt in the air.
/proc/flight_fuel_node_scale(mob/pilot)
	return mob_has_node_effect(pilot, "aviation_rocketry") ? NODE_EFFECT_FLIGHT_FUEL : 1

#undef NODE_EFFECT_ALLOY_DURABILITY
#undef NODE_EFFECT_FARM_YIELD
#undef NODE_EFFECT_SURGERY_QUALITY
#undef NODE_EFFECT_SURGERY_TIME
#undef NODE_EFFECT_DISEASE_CHANCE
#undef NODE_EFFECT_FLIGHT_FUEL
