// "Only what I can make" filter for the held-material crafting window.
// Presentation only: produce_recipe() and Topic still own every admission
// check, so a row marked makeable can still be refused at craft time.

/datum/preferences
	var/craft_makeable_only = FALSE

// Can the viewer make one of this recipe from this stack right now? Covers
// knowledge (manuals and research), material on hand, crafting skill gates
// and the tools or extra materials checked by carving, joinery, the tablet
// press and cloth recipes. Where the player stands (river banks, map edges,
// sea decks, workshops) is not judged here: moving can fix those.
/obj/item/stack/proc/recipe_makeable_now(mob/user, datum/stack_recipe/R)
	if (!ishuman(user) || !R || !R.req_amount)
		return FALSE
	var/mob/living/human/H = user
	if (amount < R.req_amount)
		return FALSE
	var/result = "[R.result_type]"
	if (crafting_recipe_manual_hint(H, result) || !crafting_recipe_allowed(H, result))
		return FALSE
	if (!civ_generation_can_build(H, R.result_type) || !exercise_can_build(H, R.result_type) || !civ_telecom_can_build(H, R.result_type))
		return FALSE
	if (stone_mold_type(R.result_type))
		var/datum/stone_mold_carving/carving = new(src, H, R)
		if (!carving.valid())
			return FALSE
	if (findtext(R.title, "joinery: ") == 1)
		var/datum/furniture_joinery_action/joinery = new(src, H, R)
		if (!joinery.valid())
			return FALSE
	if (R.result_type == /obj/structure/chem_master/tablet_press/constructed)
		var/datum/tablet_press_construction/press = new(src, H, R, 1)
		if (!press.valid())
			return FALSE
	if (is_cloth_sheet(src))
		var/datum/cloth_recipe_payment/payment = new(src, H, R, 1)
		if (!payment.valid())
			return FALSE
	return TRUE

/mob/proc/craft_makeable_only()
	return client && client.prefs && client.prefs.craft_makeable_only

// The window's tick box reports here, so the choice follows the player to
// every material and every round. One global, stateless receiver.
var/global/datum/held_crafting_filter/held_crafting_filter = new

/datum/held_crafting_filter/Topic(href, href_list)
	if (!usr || !usr.client || !usr.client.prefs || isnull(href_list["makeable_only"]))
		return
	var/datum/preferences/P = usr.client.prefs
	var/wanted = text2num(href_list["makeable_only"]) ? TRUE : FALSE
	if (P.craft_makeable_only == wanted)
		return
	P.craft_makeable_only = wanted
	P.save_preferences()
