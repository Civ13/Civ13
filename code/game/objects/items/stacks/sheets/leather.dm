// Pocket Stronghold-inspired stages, implemented with Civ13 stacks/chemistry.
// Every piece is one eventual leather sheet: split/merge needs no hidden yield.
/obj/item/stack/material
	var/tmp/preparing_hide = FALSE

/obj/item/stack/material/persistence_runtime_var(key)
	return key == "preparing_hide" || ..()

/mob/proc/hide_worker_connected()
	return client != null

/mob/proc/hide_preparation_wait(atom/target)
	return do_after(src, 50, target)

/proc/hide_worker_can_reach(mob/living/user, obj/item/source)
	return istype(user) && !QDELETED(user) && user.hide_worker_connected() && user.stat == CONSCIOUS && !QDELETED(source) && (source.loc == user || isturf(source.loc)) && user.Adjacent(source)

/obj/item/stack/material/proc/hide_preparation_valid(mob/living/user, obj/item/tool, atom/source_loc, turf/site)
	return hide_worker_can_reach(user, src) && loc == source_loc && get_turf(src) == site && amount >= 1 && !QDELETED(tool) && tool.loc == user && user.item_is_in_hands(tool) && tool.sharp && !istype(tool, /obj/item/weapon/reagent_containers) && !istype(tool, /obj/item/weapon/macuahuitl)

/obj/item/stack/material/proc/prepare_hide(mob/living/user, obj/item/tool)
	if (!istype(src, /obj/item/stack/material/pelt) && !istype(src, /obj/item/stack/material/rawhide))
		return FALSE
	var/atom/source_loc = loc
	var/turf/site = get_turf(src)
	if (preparing_hide || !hide_preparation_valid(user, tool, source_loc, site))
		return FALSE
	preparing_hide = TRUE
	user.visible_message(SPAN_NOTICE("[user] starts scraping [src]."))
	var/completed = user.hide_preparation_wait(src)
	if (QDELETED(src))
		return FALSE
	preparing_hide = FALSE
	if (!completed || !hide_preparation_valid(user, tool, source_loc, site))
		return FALSE
	// Pay once, then construct with the final count. New() may merge the output.
	if (!use(1))
		return FALSE
	new /obj/item/stack/material/hairlesshide(site, 1)
	to_chat(user, SPAN_NOTICE("You scrape a hide clean. Wash it with water next."))
	return TRUE

/obj/item/stack/material/pelt/attackby(obj/item/W, mob/user)
	if (W.sharp)
		prepare_hide(user, W)
		return TRUE
	return ..()

/obj/item/stack/material/rawhide
	name = "raw hide"
	icon_state = "sheet-hide"
	default_type = "rawhide"
	flammable = TRUE
	value = 0

/obj/item/stack/material/rawhide/update_strings()
	..()
	desc = "Untanned animal skin. Scrape one piece with a held sharp tool, wash it, dry it on a tanning rack, then apply tannin."

/obj/item/stack/material/rawhide/attackby(obj/item/W, mob/user)
	if (W.sharp)
		prepare_hide(user, W)
		return TRUE
	return ..()

// Retain this legacy type/material identity for already saved prepared hides.
/obj/item/stack/material/hairlesshide
	name = "hairless hide"
	icon_state = "sheet-hairlesshide"
	default_type = "hairlesshide"
	flammable = TRUE
	value = 0

/obj/item/stack/material/hairlesshide/update_strings()
	..()
	desc = "A scraped hide. Apply an open vessel containing at least 5 units of water to wash one piece."

/obj/item/stack/material/wethide
	name = "wet hide"
	icon_state = "sheet-hairlesshide"
	color = "#89796D"
	default_type = "wethide"
	flammable = TRUE
	value = 0

/obj/item/stack/material/wethide/update_strings()
	..()
	desc = "A washed wet hide. Put it on a tanning rack to dry; each piece will yield one leather sheet after tanning."

/obj/item/stack/material/dryhide
	name = "dry hide"
	icon_state = "sheet-hairlesshide"
	color = "#C9AA84"
	default_type = "dryhide"
	flammable = TRUE
	value = 0

/obj/item/stack/material/dryhide/update_strings()
	..()
	desc = "A dried hide. Apply an open vessel containing at least 5 units of bark tannin to tan one piece into leather."

/proc/hide_liquid_valid(mob/living/user, obj/item/source, obj/item/weapon/reagent_containers/glass/vessel, reagent_id, cost)
	return hide_worker_can_reach(user, source) && !QDELETED(vessel) && vessel.loc == user && user.item_is_in_hands(vessel) && vessel.is_open_container() && vessel.reagents && vessel.reagents.has_reagent(reagent_id, cost)

/obj/item/stack/material/proc/apply_hide_liquid(mob/living/user, obj/item/weapon/reagent_containers/glass/vessel, reagent_id, output_type)
	// Explicit paid interactions avoid touch_obj's whole-holder-volume semantics.
	if (!istype(vessel) || amount < 1 || !hide_liquid_valid(user, src, vessel, reagent_id, 5))
		return FALSE
	var/turf/site = get_turf(src)
	if (!use(1))
		return FALSE
	vessel.reagents.remove_reagent(reagent_id, 5)
	new output_type(site, 1)
	return TRUE

/obj/item/stack/material/hairlesshide/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/weapon/reagent_containers/glass))
		if (!apply_hide_liquid(user, W, "water", /obj/item/stack/material/wethide))
			to_chat(user, SPAN_WARNING("Hold an open vessel with at least 5 units of water."))
		return TRUE
	return ..()

/obj/item/stack/material/dryhide/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/weapon/reagent_containers/glass))
		if (!apply_hide_liquid(user, W, "tannin", /obj/item/stack/material/leather))
			to_chat(user, SPAN_WARNING("Hold an open vessel with at least 5 units of tannin."))
		return TRUE
	return ..()

/obj/item/stack/bark
	name = "tree bark"
	desc = "Bark from cutting logs into planks. Apply an open vessel with 10 units of water to extract 10 units of tanning solution from one piece."
	icon = 'icons/obj/bark.dmi'
	icon_state = "bark"
	singular_name = "piece of bark"
	max_amount = 50
	can_stack = TRUE
	w_class = ITEM_SIZE_SMALL
	flammable = TRUE

/obj/item/stack/bark/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/weapon/reagent_containers/glass))
		var/obj/item/weapon/reagent_containers/glass/vessel = W
		if (amount < 1 || !hide_liquid_valid(user, src, vessel, "water", 10))
			to_chat(user, SPAN_WARNING("Hold an open vessel with at least 10 units of water."))
			return TRUE
		if (!use(1))
			return TRUE
		// Equal liquid volumes fit even when the vessel started full.
		vessel.reagents.remove_reagent("water", 10)
		vessel.reagents.add_reagent("tannin", 10)
		to_chat(user, SPAN_NOTICE("You soak the bark to extract tannin."))
		return TRUE
	return ..()

/datum/reagent/tannin
	name = "Tannin"
	id = "tannin"
	description = "A bark-derived tanning solution used to turn dried hides into leather."
	reagent_state = LIQUID
	color = "#571D06"
	taste_description = "astringent bark"
