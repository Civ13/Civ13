// Syrups (Val, 2026-11-22).
//
// Tree sap: in late winter and spring, in temperate or taiga lands, a living
// broadleaf tree runs sweet sap. Use an open container on it while holding a
// knife in the other hand to cut a tap: the container catches SAP_TAP_AMOUNT
// units of sap, and the tree runs again after SAP_TAP_WAIT (runtime only,
// world_time_stamps.dm). Broadleaf trees in the silk lands give lacquer
// instead (lacquer.dm runs first).
//
// Boiling (a small pot that finishes boiling on a campfire, stove or oven,
// oven.dm):
// - SAP_PER_SYRUP units of sap boil down to 1 unit of maple syrup.
// - sugar boiled with an equal amount of water becomes simple syrup.
// - a pot holding syrup and no water, sap or sugar is boiled down again:
//   maple syrup sets into maple sugar, and simple syrup crystallises into
//   clean sugar and leaves molasses behind.
//
// Uses (chemistry files, so the Crafting Atlas lists them): simple syrup and
// fruit juice make fruit syrup, simple syrup sweetens lemonade, maple syrup
// sets jam (preserves.dm) and molasses ferments into rum. Every syrup is
// sweet food that lifts the mood a little.
//
// Nothing here sleeps outside the do_after wait.

#define SAP_TAP_AMOUNT 10
#define SAP_TAP_WAIT 12000 // twenty minutes of world.time
#define SAP_TAP_TIME 60
#define SAP_PER_SYRUP 8
#define MAPLE_SUGAR_SHARE 0.5 // sugar from each unit of maple syrup boiled down
#define SIMPLE_SUGAR_SHARE 0.4 // clean sugar from each unit of simple syrup
#define SIMPLE_MOLASSES_SHARE 0.1 // molasses from each unit of simple syrup

/proc/sap_climates()
	return list("temperate", "taiga")

// The sap runs from the end of winter into spring.
/proc/sap_season_active()
	return season == SEASON_WINTER || season == SEASON_SPRING

/obj/structure/wild/tree/live_tree/var/tmp/sap_tapped_at = null // world.time of the last tap

// Plain broadleaf trees only: not pines, willows or dead trees.
/obj/structure/wild/tree/live_tree/proc/sap_tree()
	return (type == /obj/structure/wild/tree/live_tree || type == /obj/structure/wild/tree/live_tree/snow) && health > 0 && radiation < 15

/obj/structure/wild/tree/live_tree/proc/sap_climate_ok()
	var/turf/T = get_turf(src)
	return T && (ecology_outdoor_climate(T) in sap_climates())

/obj/structure/wild/tree/live_tree/proc/sap_bled_out()
	return !isnull(sap_tapped_at) && world.time < sap_tapped_at + SAP_TAP_WAIT

// The wait, as a proc so a test fixture can stand in for do_after.
/obj/structure/wild/tree/live_tree/proc/sap_tap_wait(mob/living/human/H)
	return do_after(H, SAP_TAP_TIME, src)

// An open container used on a tree (wild.dm). TRUE when it was handled.
/proc/sap_tap_attackby(obj/structure/wild/tree/T, obj/item/W, mob/living/human/H)
	if (!istype(T, /obj/structure/wild/tree/live_tree) || !istype(W, /obj/item/weapon/reagent_containers) || !ishuman(H) || H.a_intent == I_HARM)
		return FALSE
	var/obj/structure/wild/tree/live_tree/L = T
	if (!L.sap_tree() || !is_tool(H.get_inactive_hand(), TOOL_KNIFE))
		return FALSE
	var/obj/item/weapon/reagent_containers/RG = W
	if (!L.sap_climate_ok())
		to_chat(H, SPAN_NOTICE("Trees here do not run sweet sap. Look for broadleaf trees in temperate or northern forests."))
		return TRUE
	if (!sap_season_active())
		to_chat(H, SPAN_NOTICE("The sap only runs at the end of winter and in spring."))
		return TRUE
	if (!RG.is_open_container() || !RG.reagents)
		to_chat(H, SPAN_WARNING("Open \the [RG] first."))
		return TRUE
	if (RG.reagents.get_free_space() < SAP_TAP_AMOUNT)
		to_chat(H, SPAN_WARNING("\The [RG] needs room for [SAP_TAP_AMOUNT] units of sap."))
		return TRUE
	if (L.sap_bled_out())
		to_chat(H, SPAN_NOTICE("The tap on \the [L] has stopped dripping for now. Try another tree, or come back later."))
		return TRUE
	H.visible_message(SPAN_NOTICE("[H] cuts a tap into \the [L] and holds \the [RG] under it."), SPAN_NOTICE("You cut a tap into \the [L] and hold \the [RG] under it."))
	if (!L.sap_tap_wait(H) || QDELETED(L) || !L.sap_tree() || RG.loc != H || !RG.reagents || !RG.is_open_container())
		return TRUE
	if (!is_tool(H.get_inactive_hand(), TOOL_KNIFE) || RG.reagents.get_free_space() < SAP_TAP_AMOUNT || L.sap_bled_out() || !sap_season_active())
		return TRUE
	L.sap_tapped_at = world.time
	RG.reagents.add_reagent("tree_sap", SAP_TAP_AMOUNT)
	to_chat(H, SPAN_NOTICE("Clear, sweet sap drips from the tap into \the [RG]."))
	return TRUE

// Boil the syrups in this holder. Returns a list of what happened, for the notice.
/datum/reagents/proc/boil_syrups()
	var/list/done = list()
	var/sap = get_reagent_amount("tree_sap")
	var/sugar = get_reagent_amount("sugar")
	var/water = get_reagent_amount("water")
	if (sap <= 0 && water <= 0 && sugar <= 0)
		// Nothing left to thin it: the syrup boils down again.
		var/maple = get_reagent_amount("maple_syrup")
		if (maple > 0)
			remove_reagent("maple_syrup", maple)
			add_reagent("sugar", maple * MAPLE_SUGAR_SHARE)
			done += "maple_sugar"
		var/simple = get_reagent_amount("sugar_syrup")
		if (simple > 0)
			remove_reagent("sugar_syrup", simple)
			add_reagent("sugar", simple * SIMPLE_SUGAR_SHARE)
			add_reagent("molasses", simple * SIMPLE_MOLASSES_SHARE)
			done += "molasses"
		return done
	if (sap > 0)
		remove_reagent("tree_sap", sap)
		add_reagent("maple_syrup", sap / SAP_PER_SYRUP)
		done += "maple_syrup"
	var/paired = min(sugar, water)
	if (paired > 0)
		remove_reagent("sugar", paired)
		remove_reagent("water", paired)
		add_reagent("sugar_syrup", paired * 2)
		done += "sugar_syrup"
	return done

/proc/syrup_boil_notice(datum/reagents/holder, atom/where, list/done)
	if (!holder || !where || !length(done))
		return
	var/pot = holder.my_atom
	if ("maple_syrup" in done)
		where.visible_message(SPAN_NOTICE("The sap in \the [pot] boils down to a thick amber maple syrup."))
	if ("sugar_syrup" in done)
		where.visible_message(SPAN_NOTICE("The sugar in \the [pot] melts into a clear simple syrup."))
	if ("maple_sugar" in done)
		where.visible_message(SPAN_NOTICE("The maple syrup in \the [pot] boils down and sets into maple sugar."))
	if ("molasses" in done)
		where.visible_message(SPAN_NOTICE("Clean sugar crystallises out of the syrup in \the [pot], leaving dark molasses behind."))

#undef SAP_TAP_AMOUNT
#undef SAP_TAP_WAIT
#undef SAP_TAP_TIME
#undef SAP_PER_SYRUP
#undef MAPLE_SUGAR_SHARE
#undef SIMPLE_SUGAR_SHARE
#undef SIMPLE_MOLASSES_SHARE
