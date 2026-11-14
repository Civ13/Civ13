// Tools and second materials a stack recipe needs, declared as data.
//
// config/craft_needs.json maps a product's type path to
// - "tools": tool qualities (names in craft_tool_qualities) the builder must
//   have. A tool is reused, never consumed.
// - "inputs": stack type path = amount per product, paid when the build
//   completes. Nothing is taken if the build is cancelled.
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
	for (var/obj/item/stack/S in candidates)
		if (S != paying && istype(S, stack_type) && S.can_use(amount))
			return S
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
		var/stack_type = text2path(type_text)
		var/amount = inputs[type_text] * max(1, quantity)
		var/obj/item/stack/stack_name = stack_type
		var/obj/item/stack/S = stack_type ? craft_need_stack(stack_type, amount, candidates, paying) : null
		lines[++lines.len] = list("kind" = "input", "label" = "[amount] [stack_type ? lowertext(initial(stack_name.name)) : type_text] (held or at your feet)", "met" = S ? TRUE : FALSE, "item" = S, "amount" = amount)
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
		var/obj/item/stack/S = line["item"]
		if (line["kind"] == "input" && istype(S))
			S.use(line["amount"])

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
