// Balanced diet (issue #3313). See docs/balanced-diet.md for the design and numbers.
// Actual metabolized nutrition feeds four bounded, slowly decaying nutrient reserves.
// Balanced reserves and enjoyed foods raise the stamina ceiling, the energy that
// running and physical work already spend. Hunger, thirst and digestion are unchanged.

#define DIET_RESERVE_CAP 150
#define DIET_RESERVE_START 80
#define DIET_ADEQUATE 40
#define DIET_PLENTY 100
#define DIET_DECAY 0.0004 // fraction of each reserve lost per Life tick, about an hour half-life
#define DIET_GROUP_BONUS 0.05
#define DIET_ENJOY_CAP 100
#define DIET_ENJOY_RATE 0.5
#define DIET_ENJOY_BONUS 0.1
#define DIET_BONUS_CAP 0.25
#define DIET_TASTE_SHARE 0.25 // minimum flavour share that counts for tastes
#define DIET_TASTE_EXPOSURE 1 // units of a flavour eaten before its taste is learned
#define DIET_WARN_TICKS 450 // about 15 minutes of sustained imbalance
#define DIET_FATIGUE_TICKS 1350 // about 45 minutes
#define DIET_FATIGUE_FACTOR 0.75
#define DIET_DISH_BONUS 0.25
#define DIET_DISH_POINTS 30 // nutrition per unit of nutriment

// Penalties stay off until availability across supported maps and seasons is shown.
var/global/diet_penalties_enabled = FALSE

var/global/list/diet_groups = list("carbohydrate", "protein", "fat", "vitamins")

var/global/list/diet_group_sources = list(
	"carbohydrate" = "bread, grain, potatoes, corn or honey",
	"protein" = "meat, eggs, beans or mushrooms",
	"fat" = "meat, eggs, cheese, coconut or cooking oil",
	"vitamins" = "vegetables, fruit, berries, turnips or mushrooms")

// Flavour descriptors carried in nutriment data (ingredient lineage) to nutrient shares.
var/global/list/diet_descriptor_profiles = list(
	"bread" = list("carbohydrate" = 1), "toasted bread" = list("carbohydrate" = 1),
	"bun" = list("carbohydrate" = 1), "dough" = list("carbohydrate" = 1),
	"wheat" = list("carbohydrate" = 1), "oats" = list("carbohydrate" = 1),
	"barley" = list("carbohydrate" = 1), "rice" = list("carbohydrate" = 1),
	"corn" = list("carbohydrate" = 1), "potato" = list("carbohydrate" = 0.8, "vitamins" = 0.2),
	"potatoes" = list("carbohydrate" = 0.8, "vitamins" = 0.2), "noodles" = list("carbohydrate" = 1),
	"biscuits" = list("carbohydrate" = 1), "sugar" = list("carbohydrate" = 1),
	"sweetness" = list("carbohydrate" = 0.5, "vitamins" = 0.5),
	"carrot" = list("vitamins" = 0.8, "carbohydrate" = 0.2), "cabbage" = list("vitamins" = 1),
	"tomato" = list("vitamins" = 1), "turnip" = list("vitamins" = 0.7, "carbohydrate" = 0.3),
	"vegetables" = list("vitamins" = 1), "canned vegetables" = list("vitamins" = 1),
	"fruit" = list("vitamins" = 0.7, "carbohydrate" = 0.3), "apple" = list("vitamins" = 0.7, "carbohydrate" = 0.3),
	"beans" = list("protein" = 0.5, "carbohydrate" = 0.5),
	"mushroom" = list("vitamins" = 0.5, "protein" = 0.5), "mushrooms" = list("vitamins" = 0.5, "protein" = 0.5),
	"meat" = list("protein" = 0.7, "fat" = 0.3), "canned meat" = list("protein" = 0.7, "fat" = 0.3),
	"fish" = list("protein" = 0.8, "fat" = 0.2), "salmon" = list("protein" = 0.7, "fat" = 0.3),
	"egg" = list("protein" = 0.6, "fat" = 0.4), "tofu" = list("protein" = 0.8, "fat" = 0.2),
	"cheese" = list("fat" = 0.5, "protein" = 0.5), "cream" = list("fat" = 1),
	"olive oil" = list("fat" = 1), "olives" = list("fat" = 0.7, "vitamins" = 0.3),
	"seafood" = list("protein" = 0.8, "fat" = 0.2))

// Texture and seasoning words in flavour data are not ingredients. They are left out
// of the nutrient profile, so jerky ("meat", "jaw tension") is not mostly carbohydrate.
var/global/list/diet_neutral_descriptors = list("jaw tension", "spices", "salt", "vinegar", "sourness")

// Reagents whose own identity fixes the profile, regardless of carried flavour.
var/global/list/diet_reagent_profiles = list(
	"protein" = list("protein" = 0.7, "fat" = 0.3), "egg" = list("protein" = 0.6, "fat" = 0.4),
	"cornoil" = list("fat" = 1), "honey" = list("carbohydrate" = 1),
	"flour" = list("carbohydrate" = 1), "barleyflour" = list("carbohydrate" = 1),
	"oatflour" = list("carbohydrate" = 1), "rice" = list("carbohydrate" = 1),
	"glucose" = list("carbohydrate" = 1), "tomato" = list("vitamins" = 1),
	"coconutmilk" = list("fat" = 0.6, "carbohydrate" = 0.4), "apricotjuice" = list("vitamins" = 0.7, "carbohydrate" = 0.3))

// Taste identity for reagents that carry no flavour data of their own.
var/global/list/diet_reagent_descriptors = list("protein" = "meat", "egg" = "egg", "honey" = "honey")

// Taste categories are separate from nutrients. Every listed flavour is carried by a
// reachable food; tests/balanced_diet checks this against the food sources.
var/global/list/diet_taste_categories = list(
	"grain" = list("wheat", "oats", "barley", "rice", "corn"),
	"vegetable" = list("potato", "carrot", "cabbage", "tomato", "turnip", "beans", "mushroom"),
	"animal" = list("meat", "egg"),
	"fruit and sweet" = list("fruit", "honey", "sweetness"))

var/global/list/diet_validated_category_cache

// A category needs two distinct flavours not claimed by an earlier category, or it
// is left out (and logged) rather than generating overlapping preferences.
/proc/diet_validate_categories(list/categories)
	var/list/valid = list()
	var/list/claimed = list()
	for (var/category in categories)
		var/list/options = list()
		for (var/descriptor in categories[category])
			if (istext(descriptor) && length(descriptor) && !(descriptor in claimed) && !(descriptor in options))
				options += descriptor
		if (options.len < 2)
			log_debug("Diet taste category [category] has fewer than two distinct reachable flavours and is skipped.")
			continue
		claimed += options
		valid[category] = options
	return valid

/proc/diet_taste_categories_valid()
	if (!islist(diet_validated_category_cache))
		diet_validated_category_cache = diet_validate_categories(diet_taste_categories)
	return diet_validated_category_cache

// descriptor => share (0..1) of a reagent's carried flavour lineage.
/proc/diet_flavor_shares(datum/reagent/R)
	var/list/shares = list()
	if (!R)
		return shares
	var/total = 0
	if (islist(R.data))
		var/list/flavours = R.data
		for (var/descriptor in flavours)
			if (!istext(descriptor))
				continue
			var/weight = flavours[descriptor]
			if (isnum(weight) && weight > 0)
				shares[descriptor] = weight
				total += weight
	if (total <= 0)
		shares = list()
		var/fallback = diet_reagent_descriptors[R.id]
		if (fallback)
			shares[fallback] = 1
		return shares
	for (var/descriptor in shares)
		shares[descriptor] = shares[descriptor] / total
	return shares

// group => share, summing to 1. Unknown flavours count as generic carbohydrate.
/proc/diet_profile_for(datum/reagent/R)
	var/list/profile = list()
	if (!R)
		return profile
	var/list/fixed = diet_reagent_profiles[R.id]
	if (islist(fixed))
		return fixed.Copy()
	var/list/flavours = diet_flavor_shares(R)
	if (!flavours.len)
		profile["carbohydrate"] = 1
		return profile
	var/counted = 0
	for (var/descriptor in flavours)
		if (descriptor in diet_neutral_descriptors)
			continue
		counted += flavours[descriptor]
		var/list/known = diet_descriptor_profiles[descriptor]
		if (!islist(known))
			known = list("carbohydrate" = 1)
		for (var/group in known)
			profile[group] = (profile[group] || 0) + known[group] * flavours[descriptor]
	if (counted <= 0)
		return list("carbohydrate" = 1)
	for (var/group in profile)
		profile[group] = profile[group] / counted
	return profile

// descriptor => share of a whole container's food lineage, weighted by the nutrition
// each reagent carries. Meat and eggs are their own reagents rather than nutriment
// flavours, so a dish's lineage must read every nutritious reagent, not just nutriment.
/proc/diet_lineage_shares(datum/reagents/holder)
	var/list/lineage = list()
	if (!holder)
		return lineage
	var/total = 0
	for (var/datum/reagent/ingredient in holder.reagent_list)
		var/points = diet_reagent_points(ingredient, ingredient.volume)
		if (points <= 0)
			continue
		total += points
		var/list/shares = diet_flavor_shares(ingredient)
		for (var/descriptor in shares)
			lineage[descriptor] = (lineage[descriptor] || 0) + shares[descriptor] * points
	if (total <= 0)
		return list()
	for (var/descriptor in lineage)
		lineage[descriptor] = lineage[descriptor] / total
	return lineage

/proc/diet_find_reagent(datum/reagents/holder, id)
	if (!holder)
		return null
	for (var/datum/reagent/R in holder.reagent_list)
		if (R.id == id)
			return R
	return null

/proc/diet_reagent_points(datum/reagent/R, amount)
	if (istype(R, /datum/reagent/nutriment))
		var/datum/reagent/nutriment/N = R
		return max(0, N.nutriment_factor * amount)
	if (istype(R, /datum/reagent/drink))
		var/datum/reagent/drink/D = R
		return max(0, D.nutrition * amount)
	return 0

/* Character tastes: hidden, per character life (mind), learned only by eating. */

/datum/mind
	var/list/diet_tastes // descriptor => 1 (liked) or -1 (disliked); never shown
	var/diet_taste_token // identifies this character's taste generation in notes
	var/list/diet_taste_exposure
	var/list/diet_tastes_known // only the facts this character has learned

/datum/mind/proc/diet_ensure_tastes()
	if (islist(diet_tastes) && istext(diet_taste_token) && length(diet_taste_token))
		return
	diet_tastes = list()
	diet_taste_exposure = list()
	diet_tastes_known = list()
	diet_taste_token = md5("[world.realtime]-[world.time]-[rand(1, 999999999)]-[key]")
	var/list/categories = diet_taste_categories_valid()
	for (var/category in categories)
		var/list/options = categories[category]
		options = options.Copy()
		var/liked = pick_n_take(options)
		var/disliked = pick(options)
		diet_tastes[liked] = 1
		diet_tastes[disliked] = -1

/datum/mind/proc/diet_expose(descriptor, units)
	if (!istext(descriptor) || units <= 0 || !islist(diet_tastes))
		return FALSE
	var/preference = diet_tastes[descriptor]
	if (!preference)
		return FALSE
	if (!islist(diet_taste_exposure))
		diet_taste_exposure = list()
	if (!islist(diet_tastes_known))
		diet_tastes_known = list()
	if (diet_tastes_known[descriptor])
		return FALSE
	diet_taste_exposure[descriptor] = min(DIET_TASTE_EXPOSURE, (diet_taste_exposure[descriptor] || 0) + units)
	if (diet_taste_exposure[descriptor] < DIET_TASTE_EXPOSURE)
		return FALSE
	diet_tastes_known[descriptor] = preference
	var/observation = preference > 0 ? "You enjoy the taste of [descriptor]." : "You dislike the taste of [descriptor]."
	learn_discovery("food_taste", descriptor, diet_taste_token, "Taste: [descriptor]", observation)
	if (current)
		to_chat(current, "<span class='notice'>[observation] You make a note of it (IC > Notes).</span>")
	return TRUE

/* Nutrient reserves and energy capacity, kept on the body. */

/mob/living/human
	var/list/diet_reserves // null until first use so legacy and new bodies start once
	var/diet_enjoyment = 0
	var/diet_imbalance_ticks = 0
	var/tmp/list/diet_last_check

// The trend snapshot belongs to the live status display, not the saved body.
/mob/living/human/persistence_runtime_var(key)
	return key == "diet_last_check" || ..()

/mob/living/human/proc/diet_ensure()
	if (!islist(diet_reserves))
		diet_reserves = list()
	for (var/group in diet_groups)
		var/value = diet_reserves[group]
		if (!isnum(value))
			diet_reserves[group] = DIET_RESERVE_START
		else
			diet_reserves[group] = clamp(value, 0, DIET_RESERVE_CAP)
	if (!isnum(diet_enjoyment))
		diet_enjoyment = 0
	diet_enjoyment = clamp(diet_enjoyment, 0, DIET_ENJOY_CAP)

/mob/living/human/proc/diet_reserve(group)
	if (!islist(diet_reserves) || !isnum(diet_reserves[group]))
		return DIET_RESERVE_START
	return clamp(diet_reserves[group], 0, DIET_RESERVE_CAP)

/mob/living/human/proc/diet_adequate_groups()
	. = 0
	for (var/group in diet_groups)
		if (diet_reserve(group) >= DIET_ADEQUATE)
			.++

/mob/living/human/proc/diet_capacity_bonus()
	var/enjoyment = isnum(diet_enjoyment) ? clamp(diet_enjoyment, 0, DIET_ENJOY_CAP) : 0
	return min(DIET_BONUS_CAP, diet_adequate_groups() * DIET_GROUP_BONUS + enjoyment / DIET_ENJOY_CAP * DIET_ENJOY_BONUS)

/mob/living/human/proc/diet_stamina_cap()
	var/base = stats["stamina"][2]
	return base + round(base * diet_capacity_bonus())

// Mild fatigue only after prolonged imbalance, only when enabled, never on top of starvation.
/mob/living/human/proc/diet_recovery_factor()
	if (diet_penalties_enabled && diet_imbalance_ticks >= DIET_FATIGUE_TICKS && nutrition > 0)
		return DIET_FATIGUE_FACTOR
	return 1

/mob/living/human/proc/diet_recover_stamina()
	stats["stamina"][1] = min(stats["stamina"][1] + round(stats["stamina"][2] * 0.02 * diet_recovery_factor()), diet_stamina_cap())

// Called from metabolism with the amount actually removed this tick, so splitting,
// sharing or diluting food cannot add nutrients that were not eaten.
/mob/living/human/proc/diet_intake(datum/reagent/R, removed)
	if (!R || removed <= 0 || stat == DEAD)
		return
	var/points = diet_reagent_points(R, removed)
	if (points <= 0)
		return
	diet_ensure()
	var/list/profile = diet_profile_for(R)
	for (var/group in profile)
		if (group in diet_groups)
			diet_reserves[group] = min(DIET_RESERVE_CAP, diet_reserves[group] + points * profile[group])
	if (!mind || mind.current != src)
		return
	mind.diet_ensure_tastes()
	var/list/flavours = diet_flavor_shares(R)
	var/liked = 0
	var/disliked = 0
	for (var/descriptor in flavours)
		var/share = flavours[descriptor]
		if (share < DIET_TASTE_SHARE)
			continue
		var/preference = mind.diet_tastes[descriptor]
		if (!preference)
			continue
		if (preference > 0)
			liked += share
		else
			disliked += share
		mind.diet_expose(descriptor, removed * share)
	if (liked || disliked)
		diet_enjoyment = clamp(diet_enjoyment + points * (liked - disliked) * DIET_ENJOY_RATE, 0, DIET_ENJOY_CAP)

// Net liked share of a flavour lineage for this character (trace flavours ignored).
/mob/living/human/proc/diet_liked_share(list/flavours)
	if (!islist(flavours) || !mind || mind.current != src)
		return 0
	mind.diet_ensure_tastes()
	. = 0
	for (var/descriptor in flavours)
		if (flavours[descriptor] >= DIET_TASTE_SHARE)
			. += flavours[descriptor] * (mind.diet_tastes[descriptor] || 0)

// A prepared dish made from liked ingredients is better than the ingredients alone.
// The flavours are the bowl's actual lineage before the bite. Credit is limited to
// the bowl's finite paid food, so refills or dilution cannot renew it.
/mob/living/human/proc/diet_credit_dish(quality, food, list/flavours)
	quality = clamp(round(quality), 0, 3)
	if (!quality || food <= 0 || stat == DEAD)
		return
	var/net = diet_liked_share(flavours)
	if (net <= 0)
		return
	diet_ensure()
	diet_enjoyment = clamp(diet_enjoyment + food * DIET_DISH_POINTS * net * DIET_ENJOY_RATE * DIET_DISH_BONUS * quality, 0, DIET_ENJOY_CAP)

// Diet messages go through one proc so the native probe can observe them.
/mob/living/human/proc/diet_notify(message)
	to_chat(src, message)

/mob/living/human/proc/handle_diet()
	if (stat == DEAD)
		return
	diet_ensure()
	for (var/group in diet_groups)
		diet_reserves[group] = max(0, diet_reserves[group] - diet_reserves[group] * DIET_DECAY)
	diet_enjoyment = max(0, diet_enjoyment - diet_enjoyment * DIET_DECAY)
	if (diet_adequate_groups() <= 2)
		diet_imbalance_ticks = min(DIET_FATIGUE_TICKS * 2, diet_imbalance_ticks + 1)
		if (diet_imbalance_ticks == DIET_WARN_TICKS)
			diet_notify("<span class='warning'>Your meals have been narrow lately. A more varied diet would restore your energy; use Check Diet in the IC tab.</span>")
		else if (diet_imbalance_ticks == DIET_FATIGUE_TICKS && diet_penalties_enabled)
			diet_notify("<span class='warning'>Your narrow diet leaves you tired; your stamina recovers more slowly until you eat more varied food.</span>")
	else if (diet_imbalance_ticks)
		// Announce recovery only when the narrow-diet warning was actually in effect,
		// so a brief dip below adequate never produces an unexplained message.
		var/was_warned = diet_imbalance_ticks >= DIET_WARN_TICKS
		diet_imbalance_ticks = max(0, diet_imbalance_ticks - 3)
		if (was_warned && diet_imbalance_ticks < DIET_WARN_TICKS)
			diet_notify("<span class='notice'>Your varied meals have restored your usual energy.</span>")

/proc/diet_level_word(value)
	if (value >= DIET_PLENTY)
		return "plenty"
	if (value >= DIET_ADEQUATE)
		return "adequate"
	if (value >= DIET_ADEQUATE / 3)
		return "low"
	return "depleted"

/mob/living/human/proc/diet_status_text()
	diet_ensure()
	var/list/lines = list("<b>Diet</b>")
	var/list/low = list()
	for (var/group in diet_groups)
		var/value = diet_reserves[group]
		var/trend = ""
		if (islist(diet_last_check) && isnum(diet_last_check[group]))
			var/delta = value - diet_last_check[group]
			trend = delta > 1 ? ", rising" : (delta < -1 ? ", falling" : ", steady")
		lines += "[capitalize(group)]: [diet_level_word(value)][trend]"
		if (value < DIET_ADEQUATE)
			low += group
	diet_last_check = diet_reserves.Copy()
	var/base = stats["stamina"][2]
	var/bonus = diet_capacity_bonus()
	lines += "Energy capacity: [diet_stamina_cap()] (base [base], diet +[round(bonus * 100)]%). Available: [round(stats["stamina"][1])]."
	if (diet_enjoyment >= DIET_ENJOY_CAP / 3)
		lines += "You have been enjoying your food, which adds to your energy."
	if (diet_imbalance_ticks >= DIET_FATIGUE_TICKS && diet_penalties_enabled && nutrition > 0)
		lines += "<span class='warning'>Your narrow diet is slowing your stamina recovery.</span>"
	else if (diet_imbalance_ticks >= DIET_WARN_TICKS)
		lines += "<span class='warning'>Your diet has been narrow for a while[diet_penalties_enabled ? "; if it continues your stamina will recover more slowly" : ""].</span>"
	for (var/group in low)
		lines += "For more [group], eat [diet_group_sources[group]]."
	if (!low.len)
		lines += "Your diet is balanced. Variety keeps it that way; one missed meal will not undo it."
	return jointext(lines, "<br>")

/mob/living/human/verb/check_diet()
	set name = "Check Diet"
	set category = "IC"
	if (stat == DEAD)
		return
	to_chat(src, diet_status_text())

// Nutrient contributions of a food's actual contents, plus tastes this character has learned.
/mob/living/human/proc/diet_food_summary(obj/item/weapon/reagent_containers/food/F)
	if (!F || !F.reagents || !F.reagents.reagent_list.len)
		return ""
	var/list/totals = list()
	var/total = 0
	var/list/known = list()
	for (var/datum/reagent/R in F.reagents.reagent_list)
		var/points = diet_reagent_points(R, R.volume)
		if (points <= 0)
			continue
		var/list/profile = diet_profile_for(R)
		for (var/group in profile)
			totals[group] = (totals[group] || 0) + points * profile[group]
			total += points * profile[group]
		if (mind && islist(mind.diet_tastes_known))
			var/list/flavours = diet_flavor_shares(R)
			for (var/descriptor in flavours)
				if (flavours[descriptor] >= DIET_TASTE_SHARE && mind.diet_tastes_known[descriptor])
					known[descriptor] = mind.diet_tastes_known[descriptor]
	if (total <= 0)
		return ""
	var/list/parts = list()
	for (var/group in diet_groups)
		var/share = (totals[group] || 0) / total
		if (share >= 0.5)
			parts += "mostly [group]"
		else if (share >= 0.2)
			parts += "some [group]"
		else if (share > 0.02)
			parts += "a little [group]"
	. = "Nutrients: [jointext(parts, ", ")]."
	for (var/descriptor in known)
		. += " You know you [known[descriptor] > 0 ? "enjoy" : "dislike"] the taste of [descriptor]."
