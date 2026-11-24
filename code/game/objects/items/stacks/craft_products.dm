// Questions a stack recipe asks before it builds, declared as data.
//
// A product that asks the builder for a name, colour or owner declares a
// /datum/craft_product subtype with `prompts` instead of calling player_input()
// inside produce_recipe(). A crafting screen can read the prompts and pass the
// answers in produce_recipe(options); anything not passed is asked as before.
//
// Each prompt is a list with these keys:
// - "field": the answer's key in the options list.
// - "kind": "text", "color" or "company" (a company the builder belongs to).
// - "question", "title": the prompt text. "%title%", "%material%" and
//   "%religion%" become the recipe title, its material and the builder's religion.
// - "default": shown in the prompt. "fallback": used when the answer is empty.
// - "blank_ok": keep an empty text answer instead of the fallback.
// - "required": an empty answer (or Cancel) stops the build.
// - "max_length": longest text answer taken from options, 256 when not set.
//   Text passed in options is sanitized; typed answers are kept as typed.

/datum/craft_product
	var/order = 100
	var/list/prompts = list()

/datum/craft_product/proc/matches(datum/stack_recipe/R)
	return FALSE

// Turn collected answers into the fields produce_recipe() reads.
/datum/craft_product/proc/finish(list/chosen, datum/stack_recipe/R)
	return

var/global/list/craft_products = null

/proc/craft_product_list()
	if (!craft_products)
		var/list/products = list()
		for (var/path in subtypesof(/datum/craft_product))
			var/datum/craft_product/P = new path
			var/at = products.len + 1
			for (var/i = 1, i <= products.len, i++)
				var/datum/craft_product/other = products[i]
				if (P.order < other.order)
					at = i
					break
			products.Insert(at, P)
		craft_products = products
	return craft_products

/proc/craft_product_for(datum/stack_recipe/R)
	if (!R)
		return null
	for (var/datum/craft_product/P in craft_product_list())
		if (P.matches(R))
			return P
	return null

/proc/craft_product_text(text, datum/stack_recipe/R, mob/living/human/H)
	if (!istext(text))
		return text
	text = replacetext(text, "%title%", "[R.title]")
	text = replacetext(text, "%material%", "[R.use_material]")
	if (findtext(text, "%religion%"))
		text = replacetext(text, "%religion%", H ? "[H.religion]" : "")
	return text

/proc/craft_product_companies(mob/living/human/H)
	var/list/found = list()
	if (!H || !map)
		return found
	for (var/i in map.custom_company_nr)
		if (company_may_operate(H, i))
			found += i
	return found

// One answer, from options when given there, otherwise asked. Returns null to stop the build.
/proc/craft_product_answer(mob/user, list/prompt, datum/stack_recipe/R, list/options)
	var/mob/living/human/H = user
	var/field = prompt["field"]
	var/kind = prompt["kind"]
	var/question = craft_product_text(prompt["question"], R, H)
	var/title = craft_product_text(prompt["title"], R, H)
	var/default = craft_product_text(prompt["default"], R, H)
	var/fallback = craft_product_text(prompt["fallback"], R, H)
	var/given = options && (field in options)
	var/answer = given ? options[field] : null
	switch (kind)
		if ("company")
			var/list/companies = craft_product_companies(H)
			if (!companies.len)
				to_chat(user, "You are not part of any companies!")
				return null
			if (!given)
				answer = WWinput(user, question, title, "Cancel", companies + "Cancel")
			if (!(answer in companies))
				return null
			if (!company_may_operate(H, answer))
				return null
			return answer
		if ("color")
			if (!given)
				answer = WWinput(user, question, title, default, "color")
			var/regex/hex = regex("^#\[0-9a-fA-F\]{6}$")
			if (!istext(answer) || !hex.Find(answer))
				answer = null
		else
			if (!given)
				answer = player_input(user, question, title, default, "text", null, prompt["can_cancel"] ? TRUE : FALSE)
			else if (!isnull(answer))
				answer = sanitize(copytext("[answer]", 1, (prompt["max_length"] ? prompt["max_length"] : 256) + 1))
	if (isnull(answer) || (answer == "" && !prompt["blank_ok"]))
		if (prompt["required"])
			return null
		if (isnull(answer) || !isnull(fallback))
			answer = isnull(fallback) ? "" : fallback
	return answer

// Every answer this recipe needs, or null when the builder cancelled. A recipe
// without a declared product returns an empty list.
/proc/craft_product_options(mob/user, datum/stack_recipe/R, list/options = null)
	var/list/chosen = list()
	var/datum/craft_product/P = craft_product_for(R)
	if (!P)
		return chosen
	for (var/list/prompt in P.prompts)
		var/answer = craft_product_answer(user, prompt, R, options)
		if (isnull(answer))
			return null
		chosen[prompt["field"]] = answer
	P.finish(chosen, R)
	return chosen

/datum/craft_product/custom_sign
	order = 10
	prompts = list(
		list("field" = "name", "kind" = "text", "question" = "Choose a name for this sign:", "fallback" = "Sign", "blank_ok" = TRUE, "can_cancel" = TRUE),
		list("field" = "desc", "kind" = "text", "question" = "Choose a description for this sign:", "fallback" = "An empty sign.", "blank_ok" = TRUE, "can_cancel" = TRUE),
	)

/datum/craft_product/custom_sign/matches(datum/stack_recipe/R)
	return findtext(R.title, "custom") && findtext(R.title, "sign")

/datum/craft_product/signpost
	order = 20
	prompts = list(
		list("field" = "west", "kind" = "text", "question" = "Add a West sign? Leave empty to not add one.", "title" = "Signpost", "default" = "", "can_cancel" = TRUE),
		list("field" = "north", "kind" = "text", "question" = "Add a North sign? Leave empty to not add one.", "title" = "Signpost", "default" = "", "can_cancel" = TRUE),
		list("field" = "east", "kind" = "text", "question" = "Add a East sign? Leave empty to not add one.", "title" = "Signpost", "default" = "", "can_cancel" = TRUE),
		list("field" = "south", "kind" = "text", "question" = "Add a South sign? Leave empty to not add one.", "title" = "Signpost", "default" = "", "can_cancel" = TRUE),
	)

/datum/craft_product/signpost/matches(datum/stack_recipe/R)
	return findtext(R.title, "signpost")

/datum/craft_product/signpost/finish(list/chosen, datum/stack_recipe/R)
	var/desc = ""
	var/list/sides = list("west" = "West", "north" = "North", "east" = "East", "south" = "South")
	for (var/field in sides)
		if (chosen[field] != "")
			desc += "[field == "west" ? "" : "<br>"]<b>[sides[field]]:</b> [chosen[field]]"
	chosen["desc"] = desc

/datum/craft_product/locked_door
	order = 30
	prompts = list(
		list("field" = "name", "kind" = "text", "question" = "Choose a name for the door:", "fallback" = "Locked", "blank_ok" = TRUE, "can_cancel" = TRUE),
	)

/datum/craft_product/locked_door/matches(datum/stack_recipe/R)
	return findtext(R.title, "locked") && findtext(R.title, "door") && !findtext(R.title, "unlocked")

/datum/craft_product/tin_can
	order = 40
	prompts = list(
		list("field" = "name", "kind" = "text", "question" = "Choose a brand for this can:", "title" = "Tin Can Brand", "default" = "", "fallback" = ""),
		list("field" = "color1", "kind" = "color", "question" = "Choose a main color:", "title" = "Tin Can Main Color", "default" = "#000000", "fallback" = "#000000"),
		list("field" = "color2", "kind" = "color", "question" = "Choose a secondary color:", "title" = "Tin Can Secondary Color", "default" = "#FFFFFF", "fallback" = "#FFFFFF"),
	)

/datum/craft_product/tin_can/matches(datum/stack_recipe/R)
	return findtext(R.title, "tin can")

/datum/craft_product/cigarette_pack
	order = 50
	prompts = list(
		list("field" = "name", "kind" = "text", "question" = "Choose a name for this pack:", "title" = "Cigarette Pack Name", "default" = "cigarette pack", "fallback" = "cigarette pack"),
		list("field" = "color", "kind" = "color", "question" = "Choose a color:", "title" = "Cigarette Pack Color", "default" = "#000000", "required" = TRUE),
	)

/datum/craft_product/cigarette_pack/matches(datum/stack_recipe/R)
	return findtext(R.title, "cigarette pack")

/datum/craft_product/statue
	order = 60
	prompts = list(
		list("field" = "name", "kind" = "text", "question" = "What name to give to the statue?", "title" = "Statue", "default" = "%material% statue", "blank_ok" = TRUE),
		list("field" = "desc", "kind" = "text", "question" = "What description to add to the statue?", "title" = "Statue", "default" = "A %material% statue.", "blank_ok" = TRUE),
	)

/datum/craft_product/statue/matches(datum/stack_recipe/R)
	return R.result_type == /obj/structure/religious/statue

/datum/craft_product/vehicle_frame
	order = 70
	prompts = list(
		list("field" = "name", "kind" = "text", "question" = "Choose a name for this vehicle:", "title" = "Vehicle Name", "default" = "motorcycle", "fallback" = "motorcycle"),
		list("field" = "color", "kind" = "color", "question" = "Choose a color:", "title" = "Vehicle Color", "default" = "#FFFFFF", "required" = TRUE),
	)

/datum/craft_product/vehicle_frame/matches(datum/stack_recipe/R)
	return findtext(R.title, "motorcycle frame") || findtext(R.title, "boat frame")

/datum/craft_product/fuel_pump
	order = 80
	prompts = list(
		list("field" = "company", "kind" = "company", "question" = "Which company will own this %title%?", "title" = "%title%"),
		list("field" = "name", "kind" = "text", "question" = "Choose a name for this pump:", "title" = "Fuel Pump Name", "default" = "fuel pump", "fallback" = "fuel pump"),
		list("field" = "color", "kind" = "color", "question" = "Fuel Pump - Choose a color:", "title" = "Fuel Pump Color", "default" = "#FFFFFF", "required" = TRUE),
	)

/datum/craft_product/fuel_pump/matches(datum/stack_recipe/R)
	return findtext(R.title, "fuel pump")

/datum/craft_product/holy_book
	order = 90
	prompts = list(
		list("field" = "name", "kind" = "text", "question" = "Choose a title for the holy book:", "title" = "Holy Book Name", "default" = "%religion%'s Holy Book", "blank_ok" = TRUE),
	)

/datum/craft_product/holy_book/matches(datum/stack_recipe/R)
	return findtext(R.title, "holy book")

/datum/craft_product/gravestone
	order = 100
	prompts = list(
		list("field" = "name", "kind" = "text", "question" = "Choose a name to inscribe on this gravestone:", "fallback" = "gravestone", "can_cancel" = TRUE),
		list("field" = "desc", "kind" = "text", "question" = "Choose an epitaph to inscribe on this gravestone:", "fallback" = "A gravestone made with polished stone.", "can_cancel" = TRUE),
	)

/datum/craft_product/gravestone/matches(datum/stack_recipe/R)
	return findtext(R.title, "gravestone")

// Market and supply stalls, and vending machines: a name, then the owning company.
/datum/craft_product/company_stall
	order = 110
	prompts = list(
		list("field" = "name", "kind" = "text", "question" = "Choose a name for this %title%:", "fallback" = "%title%", "can_cancel" = TRUE),
		list("field" = "company", "kind" = "company", "question" = "Which company will own this %title%?", "title" = "%title%"),
	)

/datum/craft_product/company_stall/matches(datum/stack_recipe/R)
	return findtext(R.title, "market stall") || findtext(R.title, "vending machine") || findtext(R.title, "supply stall")
