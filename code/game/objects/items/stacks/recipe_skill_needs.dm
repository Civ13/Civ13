// The one table of recipes that need a level of skill. stack.dm asks it at
// each of its checks, the Crafting window marks a recipe the viewer cannot
// make yet, and both name the skill, the level needed and the viewer's own.
// Levels are getStatCoeff() values: 1 is the starting skill of 100.
//
// Each entry: list(skill, level, matches, parts that rule it out, TRUE when
// the Voyage map skips it). A match is a part of the recipe's title, a list
// of parts that must all be in it, or the result type. Where several entries
// match, the highest applies.
var/global/list/recipe_skill_table = list(
	list("crafting", 1.7, list("carriage")),
	list("crafting", 1, list(list("faction", "door"))),
	list("crafting", 1, list(list("locked", "door")), list("unlocked")),
	list("philosophy", 1.35, list(/obj/item/weapon/book/language_book)),
	list("crafting", 1.35, list("motorcycle frame", "boat frame")),
	list("crafting", 1.9, list("locomotive")),
	list("crafting", 1.35, list("fuel pump")),
	list("crafting", 1.1, list("wall", /obj/structure/sink/well), list("wallet"), TRUE),
	list("crafting", 1.1, list("locked large stone double doors", "locked large sandstone double doors", "locked large lead double doors", "locked large copper double doors", "locked large bronze double doors", "locked large silver double doors", "locked large gold double doors", "locked large bone double doors")),
	list("crafting", 1.1, list("locked wooden privacy door")),
	list("crafting", 1.1, list("unlocked iron door", "unlocked large iron double doors")),
	list("crafting", 1.55, list("arquebus", "matchlock musket")),
	list("crafting", 1.55, list("monumental stone pillar", "monumental ominous statue of the deep-one", "monumental ominous statue of the evil-one", "monumental ominous statue of the outsider", "monumental stone buddha", "monumental saint statue")),
	list("crafting", 1.55, list("locked reinforced large steel double doors")),
	list("crafting", 1.25, list("fire lance")),
	list("crafting", 1.25, list("moai", "long moai", "monumental sandstone obelisk", "monumental stone megalith")),
	list("crafting", 1.35, list("handcannon", "dragoon helmet")),
	list("crafting", 1.35, list("monumental crucero cross", "stone statue", "sandstone statue")),
	list("crafting", 1.35, list("grandfather clock", "standing clock")),
	list("crafting", 1.35, list("locked iron door", "locked large iron double doors"), list("unlocked")),
	list("crafting", 1.35, list("reinforced large steel double doors")),
	list("crafting", 2.2, list(/obj/item/stack/material/electronics)),
	list("crafting", 2.2, list(/obj/structure/sawmill/powered)),
	list("crafting", 1.8, list("cannon", "catapult", "spadroon", "arming sword", "small sword"), list("catapult projectile")),
	list("crafting", 2, list("stormy sea", "city street", "sea sunset", "valley", "still life", "bird and blossom", "pine on the shore", "temple by the river", "desert camp", "barque at sea")),
	list("crafting", 2, list("monumental marble statue of venus", "monumental bronze statue of karl marx")))

/proc/recipe_skill_entry_matches(list/entry, datum/stack_recipe/R)
	return recipe_skill_entry_matches_named(entry, R.title, R.result_type)

// The same match for a recipe known only by its title and result type (the Atlas).
/proc/recipe_skill_entry_matches_named(list/entry, title, result_type)
	if (entry.len >= 5 && entry[5] && map && map.ID == MAP_VOYAGE)
		return FALSE
	if (entry.len >= 4 && islist(entry[4]))
		for (var/part in entry[4])
			if (findtext(title, part))
				return FALSE
	for (var/match in entry[3])
		if (ispath(match))
			// Wells come in several linings; everything else is one exact type.
			if (result_type == match || (match == /obj/structure/sink/well && ispath(result_type, match)))
				return TRUE
		else if (islist(match))
			var/all = TRUE
			for (var/part in match)
				if (!findtext(title, part))
					all = FALSE
					break
			if (all)
				return TRUE
		else if (findtext(title, match))
			return TRUE
	return FALSE

// What skill a recipe needs: list(skill, level), or null when it needs none.
/proc/recipe_skill_need(datum/stack_recipe/R)
	return R ? recipe_skill_need_named(R.title, R.result_type) : null

// The Atlas lists recipes by title and result path rather than by datum.
/proc/recipe_skill_need_named(title, result_type)
	if (!istext(title))
		return null
	if (istext(result_type)) // the Atlas names its results as text
		result_type = text2path(result_type)
	var/list/need = null
	for (var/list/entry in recipe_skill_table)
		if ((!need || entry[2] > need[2]) && recipe_skill_entry_matches_named(entry, title, result_type))
			need = list(entry[1], entry[2])
	return need

// "Needs Crafting 170. Yours is 112.", or null when H has the skill for R.
/proc/recipe_skill_refusal(mob/living/human/H, datum/stack_recipe/R)
	var/list/need = recipe_skill_need(R)
	if (!need || !istype(H))
		return null
	var/have = H.getStatCoeff(need[1])
	if (have >= need[2])
		return null
	return "Needs [capitalize(need[1])] [round(need[2] * 100)]. Yours is [round(have * 100)]."

// The check stack.dm makes before building: tells H and returns TRUE when
// their skill falls short.
/proc/recipe_skill_short(mob/living/human/H, datum/stack_recipe/R)
	var/refusal = recipe_skill_refusal(H, R)
	if (!refusal)
		return FALSE
	to_chat(H, SPAN_DANGER("[refusal] Skills grow with use: keep making simpler things."))
	return TRUE
