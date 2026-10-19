// Generated from scripts/gameplay_bridge/catalog.py; do not edit by hand.
/proc/gameplay_action_fields(list/A)
	if (!islist(A))
		return FALSE
	var/list/keys
	switch(A["type"])
		if ("consume")
			keys = list("type", "target")
			if (!istext(A["target"]) || !length(A["target"]) || length(A["target"]) > 64)
				return FALSE
		if ("craft")
			keys = list("type", "target", "recipe")
			if (!istext(A["target"]) || !length(A["target"]) || length(A["target"]) > 64)
				return FALSE
			if (!istext(A["recipe"]) || !(A["recipe"] in list("bind_flint_axe", "deploy_canopy", "grass_twine", "leather_canopy", "sharpen_stick")))
				return FALSE
		if ("drink")
			keys = list("type", "target")
			if (!istext(A["target"]) || !length(A["target"]) || length(A["target"]) > 64)
				return FALSE
		if ("drop")
			keys = list("type", "target")
			if (!istext(A["target"]) || !length(A["target"]) || length(A["target"]) > 64)
				return FALSE
		if ("equip")
			keys = list("type", "target", "slot")
			if (!istext(A["target"]) || !length(A["target"]) || length(A["target"]) > 64)
				return FALSE
			if (!istext(A["slot"]) || !(A["slot"] in list("belt")))
				return FALSE
		if ("examine")
			keys = list("type", "target")
			if (!istext(A["target"]) || !length(A["target"]) || length(A["target"]) > 64)
				return FALSE
		if ("gather")
			keys = list("type", "target")
			if (!istext(A["target"]) || !length(A["target"]) || length(A["target"]) > 64)
				return FALSE
		if ("intent")
			keys = list("type", "intent")
			if (!istext(A["intent"]) || !(A["intent"] in list("help", "grab", "walk")))
				return FALSE
		if ("move")
			keys = list("type", "direction")
			if (!istext(A["direction"]) || !(A["direction"] in list("north", "south", "east", "west")))
				return FALSE
		if ("pickup")
			keys = list("type", "target")
			if (!istext(A["target"]) || !length(A["target"]) || length(A["target"]) > 64)
				return FALSE
		if ("refill")
			keys = list("type", "target")
			if (!istext(A["target"]) || !length(A["target"]) || length(A["target"]) > 64)
				return FALSE
		if ("say")
			keys = list("type", "text")
			if (!istext(A["text"]) || !length(A["text"]) || length(A["text"]) > 160)
				return FALSE
		if ("swap_hands")
			keys = list("type")
		if ("use")
			keys = list("type", "target")
			if (!istext(A["target"]) || !length(A["target"]) || length(A["target"]) > 64)
				return FALSE
	if (!keys || A.len != keys.len)
		return FALSE
	for (var/key in A)
		if (!(key in keys))
			return FALSE
	return TRUE
