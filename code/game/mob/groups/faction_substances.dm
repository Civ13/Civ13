// Substance rules (drug_classes.dm has the classes). On its registered land
// (land_registry.dm) a faction may mark each class of drug as allowed (the
// default), licensed or banned. The game only shows the rule: examine says it,
// "Read the laws" lists it and police dogs sniff for what is banned there.
// Arrest, trial, fines and confiscation stay with the faction's justice.
//
// A licensed class needs a substance licence, a faction paper like a trading
// licence (faction_papers.dm). Members of the faction never need one.
//
// The rules live in the faction's papers record (map.faction_recruitment["papers"]):
//   faction -> list(..., "substances" = list(class = "licensed" or "banned"))

var/global/list/faction_substance_classes = list("opioid" = "opiates", "stimulant" = "stimulants", "nicotine" = "tobacco", "cannabis" = "cannabis", "alcohol" = "alcohol")

/obj/map_metadata/proc/substance_rules(faction)
	var/list/R = papers_record(faction)
	var/list/rules = R["substances"]
	if (!islist(rules))
		rules = list()
		R["substances"] = rules
	for (var/class in rules.Copy())
		if (!(class in faction_substance_classes) || !(rules[class] in list("licensed", "banned")))
			rules -= class
	return rules

/obj/map_metadata/proc/substance_rule(faction, class)
	var/list/rules = substance_rules(faction)
	return rules[class] || "allowed"

/obj/map_metadata/proc/substance_set_rule(faction, class, rule)
	if (!(class in faction_substance_classes) || !(rule in list("allowed", "licensed", "banned")))
		return FALSE
	var/list/rules = substance_rules(faction)
	if (rule == "allowed")
		rules -= class
	else
		rules[class] = rule
	return TRUE

/obj/map_metadata/proc/substance_rule_lines(faction)
	. = list()
	var/list/rules = substance_rules(faction)
	for (var/class in faction_substance_classes)
		if (rules[class] == "banned")
			. += "On the land of [faction], [faction_substance_classes[class]] are banned."
		else if (rules[class] == "licensed")
			. += "On the land of [faction], [faction_substance_classes[class]] need a [faction_paper_kinds["substance"]]."

// Raw crops count as their class before they are prepared.
/proc/substance_raw_class(obj/item/I)
	if (istype(I, /obj/item/stack/material/coca))
		return "stimulant"
	if (istype(I, /obj/item/stack/material/poppy))
		return "opioid"
	if (istype(I, /obj/item/stack/material/tobacco))
		return "nicotine"
	if (istype(I, /obj/item/stack/material/cannabis) || istype(I, /obj/item/stack/material/cannabis_fresh))
		return "cannabis"
	return null

// The classes of drug an item carries.
/proc/item_substance_classes(obj/item/I)
	. = list()
	if (!I)
		return
	var/raw = substance_raw_class(I)
	if (raw)
		. |= raw
	if (I.reagents)
		for (var/datum/reagent/R in I.reagents.reagent_list)
			var/class = drug_reagent_class(R)
			if (R.volume > 0 && (class in faction_substance_classes))
				. |= class

// list(faction, rule) for the strictest rule on I at T, or null where it is allowed.
/proc/item_substance_rule(obj/item/I, turf/T)
	if (!map || !I || !T)
		return null
	var/list/at = map.land_plot_at(T)
	if (!at)
		return null
	var/faction = at[1]
	var/found = null
	for (var/class in item_substance_classes(I))
		var/rule = map.substance_rule(faction, class)
		if (rule == "banned")
			return list(faction, "banned")
		if (rule == "licensed")
			found = "licensed"
	return found ? list(faction, found) : null

// Examine (items.dm).
/obj/item/proc/substance_examine(mob/user)
	var/list/rule = item_substance_rule(src, get_turf(src))
	if (!rule)
		return
	if (rule[2] == "banned")
		to_chat(user, SPAN_WARNING("This is banned on the land of [rule[1]]."))
	else
		to_chat(user, SPAN_NOTICE("Outsiders need a [faction_paper_kinds["substance"]] of [rule[1]] to carry this here."))

// Police dogs (dog.dm): what is banned on this land, or the old contraband
// list where no faction has a rule.
/proc/item_sniffable(obj/item/I, turf/T)
	if (!I)
		return FALSE
	var/list/at = map && T ? map.land_plot_at(T) : null
	if (at)
		var/list/rule = item_substance_rule(I, T)
		return rule && rule[2] == "banned"
	return I.is_contraband || (I.reagents && (I.reagents.has_reagent("methamphetamine") || I.reagents.has_reagent("cocaine")))

/mob/living/human/proc/substance_rules_menu(faction)
	var/list/options = list()
	for (var/class in faction_substance_classes)
		options["[capitalize(faction_substance_classes[class])]: [map.substance_rule(faction, class)]"] = class
	var/pick = WWinput(src, "On the registered land of [faction], each kind of drug can be allowed, licensed for outsiders or banned.", "Substance rules", "Cancel", options + "Cancel")
	if (!pick || pick == "Cancel" || !(pick in options) || civilization != faction || !map.is_faction_leader(src, faction))
		return
	var/class = options[pick]
	var/rule = WWinput(src, "[capitalize(faction_substance_classes[class])] on the land of [faction]:", "Substance rules", "Cancel", list("allowed", "licensed", "banned", "Cancel"))
	if (!(rule in list("allowed", "licensed", "banned")) || civilization != faction || !map.is_faction_leader(src, faction))
		return
	map.substance_set_rule(faction, class, rule)
	var/what = faction_substance_classes[class]
	var/text = rule == "allowed" ? "allows [what]" : (rule == "licensed" ? "requires a [faction_paper_kinds["substance"]] for [what]" : "bans [what]")
	map.office_announce(faction, "[faction] now [text] on its registered land.")
	map.justice_log(faction, "[real_name] set the rule on [what]: [rule].")
	log_game("[key_name(src)] set [class] to [rule] on the land of [faction].")
