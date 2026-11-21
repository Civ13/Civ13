// Pine resin (Val, 2026-11-21; plan "Resin materials plan", PR 1).
//
// Any living pine on any land bleeds resin. Use an open container on a pine
// while holding a knife in the other hand to score the bark: the container
// catches 10 units of resin, and the tree bleeds again after RESIN_TAP_WAIT.
//
// Cook it down: in help intent, use a container holding 10 resin on a lit
// brazier, hearth or stove for a lump of resin (rosin). The steam leaves 2
// units of turpentine behind in the container. A lump melts back into 10 units
// of liquid resin when a hot open container (heated over a fire in grab intent,
// castle_pour.dm) is used on it.
//
// Resin lumps are the plain resin that later trades (resin-cloth armour,
// laminates, lacquer) ask for. Liquid resin and turpentine also refuel torches
// and lamps (lantern.dm).
//
// The tapping wait is runtime only (world.time, never saved: world_time_stamps.dm).
// In harm intent a container hits the tree as before. Nothing here sleeps
// outside the do_after waits.

#define RESIN_TAP_AMOUNT 10
#define RESIN_TAP_WAIT 12000 // twenty minutes of world.time
#define RESIN_TAP_TIME 60
#define RESIN_LUMP_UNITS 10
#define RESIN_TURPENTINE_UNITS 2
#define RESIN_COOK_TIME 50

/datum/reagent/resin
	name = "Resin"
	id = "resin"
	description = "Sticky golden sap from a pine. Cooked down, it sets into lumps of rosin."
	taste_description = "pine and bitterness"
	reagent_state = LIQUID
	color = "#C8892E"

/datum/reagent/turpentine
	name = "Turpentine"
	id = "turpentine"
	description = "A thin, sharp-smelling spirit cooked out of pine resin. It burns in lamps and thins paint and varnish."
	taste_description = "burning pine"
	reagent_state = LIQUID
	color = "#E8E2C8"

/material/resin
	name = "resin"
	display_name = "resin"
	icon_colour = "#B8782A"
	hardness = 10
	weight = 5
	sheet_singular_name = "lump"
	sheet_plural_name = "lumps"
	stack_type = /obj/item/stack/material/resin
	integrity = 15
	resilience = 0.2
	density = 11
	firmness = 10
	toughness = 10
	wear = 50
	heat_limit = 80
	corrosion = 0
	spring = 5
	shaping = SHAPE_MOULDED

// Lumps of hardened resin. They reuse the clay lump sprite, tinted amber,
// until they have their own art.
/obj/item/stack/material/resin
	name = "resin"
	desc = "Hard amber lumps of cooked pine resin. Warm one in a hot pot and it runs again."
	icon_state = "claylump"
	default_type = "resin"
	apply_colour = TRUE
	value = 2

/obj/item/stack/material/resin/New()
	update_icon()
	return ..()

/obj/item/stack/material/resin/update_icon()
	icon_state = "claylump[pile_suffix(amount, list(13, 26, 39))]"

// A hot open container used on resin melts one lump into it.
/obj/item/stack/material/resin/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/weapon/reagent_containers))
		resin_melt(W, user)
		return
	return ..()

/obj/item/stack/material/resin/proc/resin_melt(obj/item/weapon/reagent_containers/RG, mob/user)
	if (!RG.is_open_container() || !RG.reagents)
		to_chat(user, SPAN_WARNING("Open \the [RG] first."))
		return FALSE
	if (!RG.is_hot())
		to_chat(user, SPAN_WARNING("\The [RG] needs to be hot to melt resin. Heat it over a fire in grab intent first."))
		return FALSE
	if (RG.reagents.get_free_space() < RESIN_LUMP_UNITS)
		to_chat(user, SPAN_WARNING("\The [RG] needs room for [RESIN_LUMP_UNITS] units of resin."))
		return FALSE
	if (!use(1))
		return FALSE
	RG.reagents.add_reagent("resin", RESIN_LUMP_UNITS)
	to_chat(user, SPAN_NOTICE("A lump of resin softens and runs into \the [RG]."))
	return TRUE

/obj/structure/wild/tree/live_tree/pine/var/tmp/resin_tapped_at = null // world.time of the last tap

/obj/structure/wild/tree/live_tree/pine/proc/resin_bled_out()
	return !isnull(resin_tapped_at) && world.time < resin_tapped_at + RESIN_TAP_WAIT

/obj/structure/wild/tree/live_tree/pine/proc/resin_tree()
	return health > 0 && radiation < 15

// The waits, as procs so a test fixture can stand in for do_after.
/obj/structure/wild/tree/live_tree/pine/proc/resin_tap_wait(mob/living/human/H)
	return do_after(H, RESIN_TAP_TIME, src)

/obj/item/weapon/reagent_containers/proc/resin_cook_wait(mob/living/human/H, atom/source)
	return do_after(H, RESIN_COOK_TIME, source)

// An open container used on a tree (wild.dm). TRUE when it was handled.
/proc/resin_tap_attackby(obj/structure/wild/tree/T, obj/item/W, mob/living/human/H)
	if (!istype(T, /obj/structure/wild/tree/live_tree/pine) || !istype(W, /obj/item/weapon/reagent_containers) || !ishuman(H) || H.a_intent == I_HARM)
		return FALSE
	var/obj/structure/wild/tree/live_tree/pine/P = T
	var/obj/item/weapon/reagent_containers/RG = W
	if (!P.resin_tree())
		to_chat(H, SPAN_NOTICE("No resin runs from a dead tree."))
		return TRUE
	if (!RG.is_open_container() || !RG.reagents)
		to_chat(H, SPAN_WARNING("Open \the [RG] first."))
		return TRUE
	if (!is_tool(H.get_inactive_hand(), TOOL_KNIFE))
		to_chat(H, SPAN_WARNING("Hold a knife in your other hand to score the bark."))
		return TRUE
	if (RG.reagents.get_free_space() < RESIN_TAP_AMOUNT)
		to_chat(H, SPAN_WARNING("\The [RG] needs room for [RESIN_TAP_AMOUNT] units of resin."))
		return TRUE
	if (P.resin_bled_out())
		to_chat(H, SPAN_NOTICE("The cuts on \the [P] have stopped weeping for now. Try another pine, or come back later."))
		return TRUE
	H.visible_message(SPAN_NOTICE("[H] scores the bark of \the [P] and holds \the [RG] under the cut."), SPAN_NOTICE("You score the bark of \the [P] and hold \the [RG] under the cut."))
	if (!P.resin_tap_wait(H) || QDELETED(P) || !P.resin_tree() || RG.loc != H || !RG.reagents || !RG.is_open_container())
		return TRUE
	if (!is_tool(H.get_inactive_hand(), TOOL_KNIFE) || RG.reagents.get_free_space() < RESIN_TAP_AMOUNT || P.resin_bled_out())
		return TRUE
	P.resin_tapped_at = world.time
	RG.reagents.add_reagent("resin", RESIN_TAP_AMOUNT)
	to_chat(H, SPAN_NOTICE("Golden resin oozes down the cut into \the [RG]."))
	return TRUE

// A container of resin used on a lit brazier or stove in help intent cooks it
// down into a lump (castle_pour.dm calls this). TRUE when it was handled.
/proc/resin_cook_attackby(atom/source, obj/item/W, mob/living/human/H)
	if (!istype(W, /obj/item/weapon/reagent_containers) || !W.reagents || !W.reagents.has_reagent("resin") || !ishuman(H) || H.a_intent != I_HELP)
		return FALSE
	var/obj/item/weapon/reagent_containers/RG = W
	if (!pour_heat_source_lit(source))
		to_chat(H, SPAN_WARNING("\The [source] isn't lit."))
		return TRUE
	if (!RG.reagents.has_reagent("resin", RESIN_LUMP_UNITS))
		to_chat(H, SPAN_WARNING("You need [RESIN_LUMP_UNITS] units of resin to cook down a lump."))
		return TRUE
	H.visible_message(SPAN_NOTICE("[H] cooks resin over \the [source]."), SPAN_NOTICE("You cook the resin over \the [source] until it thickens."))
	if (!RG.resin_cook_wait(H, source) || persistence_save_in_progress || QDELETED(RG) || RG.loc != H || !pour_heat_source_lit(source) || !RG.reagents || !RG.reagents.has_reagent("resin", RESIN_LUMP_UNITS))
		return TRUE
	RG.reagents.remove_reagent("resin", RESIN_LUMP_UNITS)
	RG.reagents.add_reagent("turpentine", RESIN_TURPENTINE_UNITS)
	var/obj/item/stack/material/resin/R = new(get_turf(H), 1)
	H.put_in_hands(R)
	to_chat(H, SPAN_NOTICE("The resin sets into a hard amber lump. A little turpentine is left in \the [RG]."))
	return TRUE

#undef RESIN_TAP_AMOUNT
#undef RESIN_TAP_WAIT
#undef RESIN_TAP_TIME
#undef RESIN_LUMP_UNITS
#undef RESIN_TURPENTINE_UNITS
#undef RESIN_COOK_TIME
