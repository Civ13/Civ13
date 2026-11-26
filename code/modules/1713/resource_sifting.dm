// Renewable trace gathering leaves finite terrain deposits untouched.
/mob/living/human/var/tmp/sifting_resources = FALSE
/mob/living/human/var/tmp/sifting_action = FALSE
/turf/var/tmp/datum/sifting_identity

/mob/living/human/get_saved_vars()
	var/list/saved = ..()
	saved -= list("sifting_resources", "sifting_action")
	return saved

/turf/proc/can_sift_resources()
	return (istype(src, /turf/floor/dirt) || istype(src, /turf/floor/beach/sand)) && !is_mineable && !(locate(/obj/covers) in src)

/mob/living/human/proc/sifting_choices(turf/T = null)
	var/list/choices = list("Stone" = /obj/item/stack/material/stone, "Sand" = /obj/item/stack/ore/glass, "Copper ore" = /obj/item/stack/ore/copper, "Tin ore" = /obj/item/stack/ore/tin)
	if (map && map.ordinal_age >= 1)
		choices["Iron ore"] = /obj/item/stack/ore/iron
		choices["Calamine (zinc ore)"] = /obj/item/stack/ore/zinc
		// Black iron sand settles out of beach sand (tatara.dm).
		if (istype(T, /turf/floor/beach/sand))
			choices["Iron sand"] = /obj/item/stack/ore/iron_sand
	if (map && map.ordinal_age >= 2)
		choices["Coal"] = /obj/item/stack/ore/coal
		choices["Saltpeter"] = /obj/item/stack/ore/saltpeter
		choices["Sulphur"] = /obj/item/stack/ore/sulphur
		choices["Lead ore"] = /obj/item/stack/ore/lead
	return choices

// River panning: heavy metals, and black iron sand from the Classical age.
/mob/living/human/proc/panning_choices()
	var/list/choices = list("Copper ore" = /obj/item/stack/ore/copper, "Tin ore" = /obj/item/stack/ore/tin, "Silver ore" = /obj/item/stack/ore/silver, "Gold ore" = /obj/item/stack/ore/gold)
	if (map && map.ordinal_age >= 1)
		choices["Iron sand"] = /obj/item/stack/ore/iron_sand
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
	var/list/choices = panning ? panning_choices() : sifting_choices(T)
	var/choice
	if (!client && agent_character_for(src))
		// An agent-controlled character has no client for input(); it names its pick with the step's choose answer.
		choice = WWinput(src, "Trace gathering", "Trace gathering", null, choices)
	else
		choice = player_input(src, "Trace gathering yields one unit: three uninterrupted minutes by hand, two minutes with a sieve or river pan. Iron sand comes out in larger batches. Mining finite deposits produces much larger batches.", "Trace gathering", null, "anything", choices, TRUE)
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

// One dispatch point so every feed works regardless of .dme include order.
/obj/item/kitchen/wood_bowl/attackby(obj/item/I, mob/living/human/H)
	if (istype(H))
		if (istype(I, /obj/item/stack/ore/pay_dirt))
			return pan_pay_dirt(I, H)
		if (istype(I, /obj/item/stack/ore/crushed_ore))
			return pan_crushed_ore(I, H)
		if (istype(I, /obj/item/stack/ore/glass))
			return pan_sand(I, H)
	return ..()

// A pan must stay in the user's hands or on the same reachable ground.
/obj/item/kitchen/wood_bowl/proc/panning_tool_available(mob/living/human/H, atom/original_location)
	return !QDELETED(src) && !QDELETED(H) && loc == original_location && (loc == H ? H.item_is_in_hands(src) : isturf(loc) && Adjacent(H))

/turf/proc/panning_water()
	for (var/turf/floor/beach/water/W in range(1, src))
		if (!W.salty && W.water_level <= 30 && W.watertile && is_liquid_water(W))
			return W
	return null

/mob/living/human/proc/valid_sifting_tool(obj/item/tool, panning)
	if (!tool)
		return !panning
	if (get_active_hand() != tool)
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
	var/list/choices = panning ? panning_choices() : sifting_choices(T)
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
	to_chat(src, SPAN_NOTICE("You begin slowly gathering trace resources[tool ? " with [tool]" : " by hand"]."))
	if (!sifting_wait(T, tool) || stat || loc != T || !T.can_sift_resources() || T.sifting_identity != identity || !valid_sifting_tool(tool, panning))
		return FALSE
	if (panning && (!water || T.panning_water() != water || water.sifting_identity != water_identity))
		return FALSE
	var/units = ispath(resource_type, /obj/item/stack/ore/iron_sand) ? iron_sand_yield(panning) : 1
	if (!T.deposit_small_resource(resource_type, units))
		to_chat(src, SPAN_WARNING("Clear the output tile before sifting more resources."))
		return FALSE
	to_chat(src, SPAN_NOTICE(units > 1 ? "You wash out [units] units of black iron sand without destroying the terrain." : "You recover one unit without destroying the terrain."))
	if (water)
		river_mercury_pan_message(src, water) // amalgam.dm
	return TRUE

/mob/living/human/proc/choices_values(list/choices)
	var/list/values = list()
	for (var/key in choices)
		values += choices[key]
	return values
