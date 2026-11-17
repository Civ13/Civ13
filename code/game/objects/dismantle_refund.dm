// Dismantling or smashing a built object must never give back more than it
// cost. This finds what one unit of refund may be for a built type: the
// material its recipes charge, valued against the cheapest recipe in every
// loaded crafting list. Map-placed objects with no recipe return `fallback`.
//
// A log saws into four planks, so wood is valued in planks. A type whose
// recipes charge unrelated materials (for example stone on one map and iron
// on another) gives nothing back, because no single refund is safe on all of
// them. tests/dismantle_refunds mirrors these rules.

var/global/list/crafted_refund_stack_cache = list()

/proc/crafted_refund_stack(path, fallback = null)
	var/key = "[path]"
	if (key in crafted_refund_stack_cache)
		var/cached = crafted_refund_stack_cache[key]
		return cached == "none" ? fallback : cached
	var/found = FALSE
	var/mixed = FALSE
	var/family = null
	var/any_planks = FALSE
	var/cheapest = null
	var/cheapest_stack = null
	for (var/list_name in craftlist_lists)
		for (var/list/row in craftlist_lists[list_name])
			if (row.len < 6 || row[3] != key)
				continue
			var/material_text = row[1]
			if (copytext(material_text, -1) == "/")
				material_text = copytext(material_text, 1, -1)
			var/material_path = text2path(material_text)
			if (!ispath(material_path, /material))
				mixed = TRUE
				continue
			var/material/M = material_path
			var/stack = initial(M.stack_type)
			var/amount = text2num(row[4])
			var/made = max(1, text2num(row[6]))
			if (!stack || !isnum(amount))
				mixed = TRUE
				continue
			found = TRUE
			var/row_family = "[stack]"
			var/value = amount / made
			if (stack == /obj/item/stack/material/wood || stack == /obj/item/stack/material/woodplank)
				row_family = "wood"
				if (stack == /obj/item/stack/material/wood)
					value *= 4
				else
					any_planks = TRUE
			if (family && family != row_family)
				mixed = TRUE
			family = row_family
			if (isnull(cheapest) || value < cheapest)
				cheapest = value
				cheapest_stack = stack
	var/result = "none"
	if (found && !mixed)
		if (family == "wood")
			if (!any_planks && cheapest >= 4)
				result = /obj/item/stack/material/wood
			else if (cheapest >= 1)
				result = /obj/item/stack/material/woodplank
			else
				result = null
		else if (cheapest >= 1)
			result = cheapest_stack
		else
			result = null
	else if (found)
		result = null
	crafted_refund_stack_cache[key] = result
	if (result == "none")
		return fallback
	return result
