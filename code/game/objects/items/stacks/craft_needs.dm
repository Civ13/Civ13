// Tools and second materials a stack recipe needs, declared as data.
//
// config/craft_needs.json maps a product's type path to
// - "tools": tool qualities (names in craft_tool_qualities) the builder must
//   have. A tool is reused, never consumed.
// - "inputs": item type path = amount per product, paid when the build
//   completes: units of a stack, or whole items of any other type. Nothing is
//   taken if the build is cancelled.
// - "water" (optional): units of water per product, from an open container
//   held or at the builder's feet, or free beside running water
//   (station_water.dm).
// Tools and inputs count when held, worn in a real equipment slot or lying at
// the builder's feet; containers are never searched. The same file feeds the
// Crafting Atlas, and the guard below reports each line to the Crafting window.
// A new product that needs a hammer or a second material adds a JSON entry
// instead of another block in produce_recipe().

var/global/list/craft_need_specs
var/global/list/craft_tool_qualities = list(
	"wrench" = TOOL_WRENCH,
	"hammer" = TOOL_HAMMER,
	"crowbar" = TOOL_CROWBAR,
	"wirecutter" = TOOL_WIRECUTTER,
	"screwdriver" = TOOL_SCREWDRIVER,
	"welder" = TOOL_WELDER,
	"knife" = TOOL_KNIFE,
	"hatchet" = TOOL_HATCHET,
	"shovel" = TOOL_SHOVEL,
	"pickaxe" = TOOL_PICKAXE,
	"chisel" = TOOL_CHISEL,
)

// Other stacks that pay for a declared stack input, and the name the
// requirement line shows. Logs (/stack/material/wood, once called "wooden
// plank") and sawn planks are both wood for a handle, so either one counts.
var/global/list/craft_need_alternates = list(
	/obj/item/stack/material/wood = list(/obj/item/stack/material/woodplank),
	/obj/item/stack/hay = list(/obj/item/stack/material/straw),
	/obj/item/stack/material/cloth = list(/obj/item/stack/material/woolcloth, /obj/item/stack/material/leather),
)
var/global/list/craft_need_input_names = list(
	/obj/item/stack/material/wood = "wood (a log or a plank)",
	/obj/item/stack/hay = "hay or straw",
	/obj/item/stack/material/cloth = "cloth, wool cloth or leather",
)

/proc/craft_needs_for(result_type)
	if (!craft_need_specs)
		var/text = file2text("config/craft_needs.json")
		craft_need_specs = text ? json_decode(text) : null
		if (!islist(craft_need_specs))
			craft_need_specs = list()
	return craft_need_specs["[result_type]"]

// Held, worn or at the builder's feet, and not worn out.
/proc/craft_need_reachable(mob/living/human/H, obj/item/I)
	if (QDELETED(H) || QDELETED(I))
		return FALSE
	if (I.loc == H)
		return H.get_inventory_slot(I) ? TRUE : FALSE
	return isturf(I.loc) && I.loc == get_turf(H)

// Every item the builder could use: hands first, then equipment, then at most
// 32 things at their feet.
/proc/craft_need_candidates(mob/living/human/H)
	var/list/found = list()
	if (QDELETED(H))
		return found
	for (var/slot in (list(slot_l_hand, slot_r_hand) + slot_equipment_priority))
		var/obj/item/I = H.get_equipped_item(slot)
		if (istype(I) && craft_need_reachable(H, I))
			found |= I
	var/turf/site = get_turf(H)
	var/visited = 0
	if (site)
		for (var/atom/movable/A in site)
			if (++visited > 32)
				break
			if (isitem(A))
				found |= A
	return found

/proc/craft_need_tool(mob/living/human/H, quality_name, list/candidates)
	var/quality = craft_tool_qualities[quality_name]
	if (!quality)
		return null
	for (var/obj/item/I in candidates)
		if (is_tool(I, quality) && (isnull(I.health) || I.health > 0))
			return I
	return null

/proc/craft_need_stack(stack_type, amount, list/candidates, obj/item/stack/paying)
	var/list/accepted = list(stack_type)
	if (craft_need_alternates[stack_type])
		accepted += craft_need_alternates[stack_type]
	for (var/obj/item/stack/S in candidates)
		if (S == paying || !S.can_use(amount))
			continue
		for (var/accepted_type in accepted)
			if (istype(S, accepted_type))
				return S
	return null

// The loose items that pay for an input which is not a stack, or null when
// there are too few.
/proc/craft_need_items(item_type, amount, list/candidates)
	var/list/found = list()
	for (var/obj/item/I in candidates)
		if (istype(I, item_type))
			found += I
			if (found.len >= amount)
				return found
	return null

// One list("kind", "label", "met", "item", "amount") per requirement, in file
// order, or null when the product needs nothing extra.
/proc/craft_need_lines(mob/living/human/H, datum/stack_recipe/R, quantity = 1, obj/item/stack/paying = null)
	if (!R)
		return null
	var/list/spec = craft_needs_for(R.result_type)
	if (!spec)
		return null
	var/list/lines = list()
	var/list/candidates = craft_need_candidates(H)
	for (var/quality_name in spec["tools"])
		var/obj/item/tool = craft_need_tool(H, quality_name, candidates)
		lines[++lines.len] = list("kind" = "tool", "label" = "a [quality_name] (held, worn or at your feet)", "met" = tool ? TRUE : FALSE, "item" = tool, "amount" = 0)
	var/list/inputs = spec["inputs"]
	for (var/type_text in inputs)
		var/input_type = text2path(type_text)
		var/amount = inputs[type_text] * max(1, quantity)
		var/obj/item/input_name = input_type
		var/shown_name = craft_need_input_names[input_type]
		if (!shown_name)
			shown_name = input_type ? lowertext(initial(input_name.name)) : type_text
		// A stack pays from one pile; anything else pays whole items.
		var/found = null
		if (ispath(input_type, /obj/item/stack))
			found = craft_need_stack(input_type, amount, candidates, paying)
		else if (input_type)
			found = craft_need_items(input_type, amount, candidates)
		lines[++lines.len] = list("kind" = "input", "label" = "[amount] [shown_name] (held or at your feet)", "met" = found ? TRUE : FALSE, "item" = found, "amount" = amount)
	if (spec["water"])
		var/water = spec["water"] * max(1, quantity)
		var/source = craft_need_water(H, water, candidates)
		lines[++lines.len] = list("kind" = "water", "label" = "[water] units of water (an open container held or at your feet, or running water beside you)", "met" = source ? TRUE : FALSE, "item" = source, "amount" = water)
	return lines

// The message for the first thing missing, or null when everything is there.
/proc/craft_needs_refusal(mob/living/human/H, datum/stack_recipe/R, quantity = 1, obj/item/stack/paying = null)
	for (var/list/line in craft_need_lines(H, R, quantity, paying))
		if (!line["met"])
			return "<span class = 'warning'>You need [line["label"]] to make this.</span>"
	return null

// Take the second materials. Call only right after craft_needs_refusal()
// returned null, with no wait in between.
/proc/craft_needs_pay(mob/living/human/H, datum/stack_recipe/R, quantity = 1, obj/item/stack/paying = null)
	for (var/list/line in craft_need_lines(H, R, quantity, paying))
		if (line["kind"] == "water")
			var/obj/item/weapon/reagent_containers/C = line["item"]
			if (istype(C))
				C.reagents.remove_reagent("water", line["amount"])
			continue
		if (line["kind"] != "input")
			continue
		var/obj/item/stack/S = line["item"]
		if (istype(S))
			S.use(line["amount"])
		else if (islist(line["item"]))
			for (var/obj/item/I in line["item"])
				if (I.loc == H)
					H.drop_from_inventory(I)
				qdel(I)

// Hides the recipe from "makeable only" lists and refuses at the start.
// produce_recipe() rechecks with the real batch size before it pays.
/datum/craft_guard/needs
	order = 95
	hides_recipe = TRUE

/datum/craft_guard/needs/refusal(mob/living/human/H, datum/stack_recipe/R, phase)
	return craft_needs_refusal(H, R)

/datum/craft_guard/needs/describe_lines(mob/living/human/H, datum/stack_recipe/R)
	var/list/found = list()
	for (var/list/line in craft_need_lines(H, R))
		found[++found.len] = list("kind" = "[type]", "label" = capitalize(line["label"]), "met" = line["met"])
	return found
