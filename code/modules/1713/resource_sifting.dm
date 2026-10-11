// Renewable trace gathering leaves finite terrain deposits untouched.
/mob/living/human/var/tmp/sifting_resources = FALSE
/mob/living/human/var/tmp/sifting_action = FALSE
/turf/var/tmp/datum/sifting_identity

/turf/proc/can_sift_resources()
	return (istype(src, /turf/floor/dirt) || istype(src, /turf/floor/beach/sand)) && !is_mineable && !(locate(/obj/covers) in src)

/mob/living/human/proc/sifting_choices()
	var/list/choices = list("Stone" = /obj/item/stack/material/stone, "Sand" = /obj/item/stack/ore/glass, "Copper ore" = /obj/item/stack/ore/copper, "Tin ore" = /obj/item/stack/ore/tin)
	if (map && map.ordinal_age >= 1)
		choices["Iron ore"] = /obj/item/stack/ore/iron
	if (map && map.ordinal_age >= 2)
		choices["Coal"] = /obj/item/stack/ore/coal
		choices["Saltpeter"] = /obj/item/stack/ore/saltpeter
		choices["Sulphur"] = /obj/item/stack/ore/sulphur
		choices["Lead ore"] = /obj/item/stack/ore/lead
	return choices

/mob/living/human/verb/sift_resources()
	set name = "Sift soil for resources"
	set category = "Crafting"
	choose_resource_sifting()

/mob/living/human/proc/choose_resource_sifting(obj/item/tool, panning = FALSE)
	if (sifting_resources || sifting_action || stat || !isturf(loc))
		return
	var/turf/T = loc
	if (!T.can_sift_resources())
		to_chat(src, SPAN_WARNING("Stand on uncovered, non-mineable dirt or sand."))
		return
	sifting_resources = TRUE
	var/list/choices = panning ? list("Copper ore" = /obj/item/stack/ore/copper, "Tin ore" = /obj/item/stack/ore/tin, "Silver ore" = /obj/item/stack/ore/silver, "Gold ore" = /obj/item/stack/ore/gold) : sifting_choices()
	var/choice = input(src, "Trace gathering yields one unit: three uninterrupted minutes by hand, two minutes with a sieve or river pan. Mining finite deposits produces much larger batches.", "Trace gathering") as null|anything in choices
	if (choice)
		sift_resource(T, choices[choice], tool, panning)
	sifting_resources = FALSE

// A wooden bowl is a pan; bottled water never substitutes for a river tile.
/obj/item/kitchen/wood_bowl/verb/pan_resources()
	set name = "Pan river sediment"
	set category = "Crafting"
	set src in usr
	if (ishuman(usr))
		var/mob/living/human/H = usr
		H.choose_resource_sifting(src, TRUE)

/obj/item/weapon/resource_sieve
	name = "wooden resource sieve"
	desc = "A simple wooden sieve. Use it while standing on uncovered dirt or sand to gather one trace resource in two minutes."
	icon = 'icons/obj/kitchen.dmi'
	icon_state = "wood_bowl"
	flammable = TRUE
	w_class = ITEM_SIZE_SMALL

/obj/item/weapon/resource_sieve/attack_self(mob/user)
	if (ishuman(user))
		var/mob/living/human/H = user
		H.choose_resource_sifting(src)

/turf/proc/panning_water()
	for (var/turf/floor/beach/water/W in range(1, src))
		if (!W.salty && W.water_level <= 30 && W.watertile)
			return W
	return null

/mob/living/human/proc/valid_sifting_tool(obj/item/tool, panning)
	if (!tool)
		return !panning
	if (l_hand != tool && r_hand != tool)
		return FALSE
	return panning ? istype(tool, /obj/item/kitchen/wood_bowl) : istype(tool, /obj/item/weapon/resource_sieve)
// Split out for production-path tests with a bounded action-delay adapter.
/mob/living/human/proc/sifting_wait(turf/T, obj/item/tool)
	return do_after(src, tool ? 1200 : 1800, T)

/mob/living/human/proc/sift_resource(turf/T, resource_type, obj/item/tool, panning = FALSE)
	if (sifting_action)
		return FALSE
	sifting_action = TRUE
	. = perform_sifting(T, resource_type, tool, panning)
	sifting_action = FALSE

/mob/living/human/proc/perform_sifting(turf/T, resource_type, obj/item/tool, panning)
	var/list/choices = panning ? list("Copper ore" = /obj/item/stack/ore/copper, "Tin ore" = /obj/item/stack/ore/tin, "Silver ore" = /obj/item/stack/ore/silver, "Gold ore" = /obj/item/stack/ore/gold) : sifting_choices()
	if (stat || !T || loc != T || !T.can_sift_resources() || !valid_sifting_tool(tool, panning) || !(resource_type in choices_values(choices)))
		return FALSE
	if (!T.sifting_identity)
		T.sifting_identity = new /datum
	var/datum/identity = T.sifting_identity
	var/turf/water = panning ? T.panning_water() : null
	if (panning && !water)
		to_chat(src, SPAN_WARNING("Panning requires an adjacent shallow freshwater tile, not bottled or salt water."))
		return FALSE
	if (water && !water.sifting_identity)
		water.sifting_identity = new /datum
	var/datum/water_identity = water ? water.sifting_identity : null
	to_chat(src, SPAN_NOTICE("You begin slowly sifting for trace resources by hand."))
	if (!sifting_wait(T, tool) || stat || loc != T || !T.can_sift_resources() || T.sifting_identity != identity || !valid_sifting_tool(tool, panning))
		return FALSE
	if (panning && (!water || T.panning_water() != water || water.sifting_identity != water_identity))
		return FALSE
	if (!T.deposit_small_resource(resource_type, 1))
		to_chat(src, SPAN_WARNING("Clear the output tile before sifting more resources."))
		return FALSE
	to_chat(src, SPAN_NOTICE("You recover one unit without destroying the terrain."))
	return TRUE

/mob/living/human/proc/choices_values(list/choices)
	var/list/values = list()
	for (var/key in choices)
		values += choices[key]
	return values
