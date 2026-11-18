// Rubber trees (Val, 2026-11-18): rubber comes only from the jungle.
//
// In the rubber lands (the Jungle, Earth Africa and Earth Asia) a living jungle
// tree is a rubber tree. Use an open container on it while holding a knife in
// the other hand to score the bark: the container catches 10 units of latex,
// and the tree bleeds again after RUBBER_TAP_WAIT. Other continents have no
// rubber trees; lands that are not continents (expedition islands, battle
// maps) keep theirs.
//
// Latex cures with sulphur: use a container holding 10 latex on a sulphur rock
// for a sheet of rubber. Rubber does what plastic sheeting does in older
// trades: it insulates copper into cable, rubberises an airship gas cell and
// makes rubber boots.
//
// The tapping wait is runtime only (world.time, never saved: world_time_stamps.dm). In harm intent a container
// hits the tree as before. Nothing here sleeps.

#define RUBBER_TAP_LATEX 10
#define RUBBER_TAP_WAIT 12000 // twenty minutes of world.time
#define RUBBER_TAP_TIME 60
#define RUBBER_CURE_LATEX 10
#define RUBBER_CURE_TIME 40

/datum/reagent/latex
	name = "Latex"
	id = "latex"
	description = "The milky sap of a rubber tree. Worked with sulphur, it cures into rubber."
	reagent_state = LIQUID
	color = "#F2EFE4"

// A sheet of natural rubber (/material/rubber, materials.dm). It reuses the
// plastic sheet sprite, tinted dark brown.
/obj/item/stack/material/rubber
	name = "rubber"
	icon_state = "sheet-plastic"
	default_type = "rubber"
	apply_colour = TRUE
	value = 3

/obj/item/stack/material/rubber/New()
	update_icon()
	return ..()

/obj/item/stack/material/rubber/update_icon()
	icon_state = "sheet-plastic[pile_suffix(amount, list(13, 26, 39))]"

/obj/structure/wild/jungle/var/tmp/latex_tapped_at = null // world.time of the last tap

/obj/structure/wild/jungle/proc/latex_bled_out()
	return !isnull(latex_tapped_at) && world.time < latex_tapped_at + RUBBER_TAP_WAIT

/proc/rubber_lands()
	var/static/list/lands = list(MAP_NOMADS_JUNGLE, MAP_NOMADS_EARTH_AFRICA, MAP_NOMADS_EARTH_ASIA)
	return lands

/proc/rubber_land_names()
	var/list/names = list()
	for (var/id in rubber_lands())
		switch (id)
			if (MAP_NOMADS_JUNGLE)
				names += "the Jungle"
			if (MAP_NOMADS_EARTH_AFRICA)
				names += "Africa"
			if (MAP_NOMADS_EARTH_ASIA)
				names += "Asia"
	return names

// TRUE when jungle trees here are rubber trees.
/proc/rubber_trees_here()
	if (!continent_home()) // continent_resources.dm
		return TRUE
	return map.ID in rubber_lands()

// The waits, as procs so a test fixture can stand in for do_after.
/obj/structure/wild/jungle/proc/rubber_tap_wait(mob/living/human/H)
	return do_after(H, RUBBER_TAP_TIME, src)

/obj/item/stack/ore/sulphur/proc/rubber_cure_wait(mob/living/human/H)
	return do_after(H, RUBBER_CURE_TIME, src)

/obj/structure/wild/jungle/proc/rubber_tree()
	return type == /obj/structure/wild/jungle && health > 0 && rubber_trees_here()

// An open container used on a jungle tree (wild.dm). TRUE when it was handled.
/proc/rubber_tap_attackby(obj/structure/wild/jungle/J, obj/item/W, mob/living/human/H)
	if (!istype(W, /obj/item/weapon/reagent_containers) || !ishuman(H) || J.type != /obj/structure/wild/jungle || H.a_intent == I_HARM)
		return FALSE
	var/obj/item/weapon/reagent_containers/RG = W
	if (!J.rubber_tree())
		to_chat(H, SPAN_NOTICE("No latex runs from this tree. Rubber trees grow only in the jungles of [english_list(rubber_land_names())]."))
		return TRUE
	if (!RG.is_open_container() || !RG.reagents)
		to_chat(H, SPAN_WARNING("Open \the [RG] first."))
		return TRUE
	if (!is_tool(H.get_inactive_hand(), TOOL_KNIFE))
		to_chat(H, SPAN_WARNING("Hold a knife in your other hand to score the bark."))
		return TRUE
	if (RG.reagents.get_free_space() < RUBBER_TAP_LATEX)
		to_chat(H, SPAN_WARNING("\The [RG] needs room for [RUBBER_TAP_LATEX] units of latex."))
		return TRUE
	if (J.latex_bled_out())
		to_chat(H, SPAN_NOTICE("The cuts on \the [J] have bled out for now. Try another tree, or come back later."))
		return TRUE
	H.visible_message(SPAN_NOTICE("[H] scores the bark of \the [J] and holds \the [RG] under the cut."), SPAN_NOTICE("You score the bark of \the [J] and hold \the [RG] under the cut."))
	if (!J.rubber_tap_wait(H) || QDELETED(J) || !J.rubber_tree() || RG.loc != H || !RG.reagents || !RG.is_open_container())
		return TRUE
	if (!is_tool(H.get_inactive_hand(), TOOL_KNIFE) || RG.reagents.get_free_space() < RUBBER_TAP_LATEX || J.latex_bled_out())
		return TRUE
	J.latex_tapped_at = world.time
	RG.reagents.add_reagent("latex", RUBBER_TAP_LATEX)
	to_chat(H, SPAN_NOTICE("Milky latex runs down the cut into \the [RG]."))
	return TRUE

// A container of latex used on a sulphur rock (ores.dm). TRUE when it was handled.
/proc/rubber_cure_attackby(obj/item/stack/ore/sulphur/S, obj/item/W, mob/living/human/H)
	if (!istype(W, /obj/item/weapon/reagent_containers) || !W.reagents || !W.reagents.has_reagent("latex") || !ishuman(H))
		return FALSE
	if (!W.reagents.has_reagent("latex", RUBBER_CURE_LATEX))
		to_chat(H, SPAN_WARNING("You need [RUBBER_CURE_LATEX] units of latex to cure a sheet of rubber."))
		return TRUE
	H.visible_message(SPAN_NOTICE("[H] works crushed sulphur into the latex."), SPAN_NOTICE("You work crushed sulphur into the latex and let it cure."))
	if (!S.rubber_cure_wait(H) || persistence_save_in_progress || QDELETED(S) || !W.reagents || !W.reagents.has_reagent("latex", RUBBER_CURE_LATEX) || !S.use(1))
		return TRUE
	W.reagents.remove_reagent("latex", RUBBER_CURE_LATEX)
	var/obj/item/stack/material/rubber/R = new(get_turf(H), 1)
	H.put_in_hands(R)
	to_chat(H, SPAN_NOTICE("The latex sets into a sheet of rubber."))
	return TRUE

// Rubber and copper make insulated cable, as plastic and copper do (cables.dm).
/obj/item/stack/material/rubber/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/stack/material/copper))
		var/obj/item/stack/material/copper/conductor = W
		if (!user || user.stat)
			return
		var/turf/site = get_turf(src)
		if (!site || !can_use(1) || !conductor.can_use(1))
			to_chat(user, SPAN_WARNING("You need one rubber sheet and one copper ingot."))
			return
		conductor.use(1)
		use(1)
		new /obj/item/stack/cable_coil(site, 1)
		to_chat(user, SPAN_NOTICE("You make insulated cable from the rubber and copper."))
		return
	..()

/proc/rubber_text()
	if (!continent_home())
		return ""
	if (map.ID in rubber_lands())
		return "Rubber trees grow in its jungle: score a jungle tree with a knife and catch the latex in an open container."
	return "No rubber trees grow here: rubber comes from the jungles of [english_list(rubber_land_names())]."

#undef RUBBER_TAP_LATEX
#undef RUBBER_TAP_WAIT
#undef RUBBER_TAP_TIME
#undef RUBBER_CURE_LATEX
#undef RUBBER_CURE_TIME
