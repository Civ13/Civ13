// Wells that players dig (docs/dug-wells.md).
//
// A shovel digs a waterhole, one spit at a time. It holds water once it is
// deeper than the water table under its tile, which lies a little under low
// ground and deeper under hills, follows the river beside it up and down, and
// lies deeper in dry climates, dry seasons and heat waves. The sides of a bare
// hole stand only 2 spits deep: a timber lining lets it go to 5 and a stone
// lining (the stone, sandstone and marble well recipes) to 8.
//
// A waterhole is a puddle and a lined well is a well, so everything that fouls
// or dries those (waste and sewage nearby, floods, soap) applies unchanged. A
// well or puddle with dug_depth 0 is a spring, as before: it never runs low.
//
// A lined well takes a fitting, built standing on it: a windlass and pail
// brings up a full container at any depth, and a hand pump does it faster.
//
// Nothing here ticks. A dug well works out its water when someone uses it.

#define WELL_TABLE_BASE 1
#define WELL_TABLE_SLOPE 0.5
#define WELL_TABLE_MIN 0.5
#define WELL_DRY_SPELL 1
#define WELL_DEPTH_UNLINED 2
#define WELL_DEPTH_TIMBER 5
#define WELL_DEPTH_STONE 8
#define WELL_VOLUME_PER_LEVEL 150
#define WELL_VOLUME_MAX 750
// Units a minute for each level of standing water, up to 3 levels.
#define WELL_RECHARGE_PER_LEVEL 100
#define WELL_RECHARGE_LEVELS 3
// Water further down than this cannot be drunk from the hands, and takes
// longer to draw.
#define WELL_HAND_REACH 2
#define WELL_HAUL_TIME 5
#define WELL_DRINK_VOLUME 10
#define WELL_DIG_TIME 150
#define WELL_DIG_TIME_PER_SPIT 50
#define WELL_WINDLASS_TIME 20
#define WELL_PUMP_TIME 10
#define WELL_UNFIT_TIME 80
#define WELL_BREAK_TIME 200

/obj/structure/sink
	// Spits dug by players; 0 for a spring.
	var/dug_depth = 0
	var/tmp/dug_settled_at = 0

/obj/structure/sink/persistence_runtime_var(key)
	return key == "dug_settled_at" || ..()

// ---- the water table -----------------------------------------------------------

// Spits down to water under a tile in ordinary weather: 0 under floodwater.
/proc/well_water_table(turf/T)
	if (!T)
		return WELL_TABLE_BASE
	if (flood_depth_at(T) > 0)
		return 0
	. = WELL_TABLE_BASE + max(0, terrain_height_at(T) - river_stage_at(T)) * WELL_TABLE_SLOPE
	var/area/A = get_area(T)
	if (A)
		switch (A.climate)
			if ("desert")
				. += 2
			if ("semiarid")
				. += 1
			if ("savanna")
				. += 0.5
			if ("jungle")
				. -= 0.5
	. = max(WELL_TABLE_MIN, .)

// What a digger can tell about the water from the earth at a given depth.
/proc/well_earth_text(turf/T, depth)
	var/gap = well_water_table(T) - depth
	if (gap < 0)
		return "Water seeps into the bottom."
	if (gap <= 1)
		return "The earth at the bottom is wet: water is no more than a spit further down."
	if (gap <= 2.5)
		return "The earth at the bottom is damp: water is a few spits further down."
	return "The earth at the bottom is dry: water is a long way down here, if there is any."

// The dug waterhole or well on a tile, or null.
/proc/well_dug_at(turf/T)
	for (var/obj/structure/sink/S in T)
		if (S.dug_depth && !QDELETED(S))
			return S
	return null

// Whether a recipe builds a well, which goes over a puddle or a dug waterhole.
// Asked by result type, not by title: "jeweller's post" and "oil well" both
// hold the word "well" without being one.
/proc/craft_recipe_builds_well(datum/stack_recipe/R)
	return R && ispath(R.result_type, /obj/structure/sink/well)

// Whether a well may be built on this tile: over a puddle, or over a dug well
// that takes a new lining.
/proc/well_build_site(turf/T)
	return (locate(/obj/structure/sink/puddle) in T) || well_dug_at(T)

// A lining recipe may replace the dug well already on the tile with another kind.
/proc/well_relining(result_type, turf/T)
	if (!ispath(result_type, /obj/structure/sink/well))
		return FALSE
	var/obj/structure/sink/S = well_dug_at(T)
	return S && S.type != result_type

// Why a well cannot be dug on this tile, or null.
/proc/well_site_problem(turf/floor/T)
	if (!istype(T) || !T.is_diggable || istype(T, /turf/floor/beach/water) || istype(T, /turf/floor/lava) || T.terrain_floor_covered())
		return "You can't dig a well here."
	if (istype(T, /turf/floor/wood) || istype(T, /turf/floor/wood_broken) || istype(T, /turf/floor/ship) || istype(T, /turf/floor/carpet) || istype(T, /turf/floor/broken_floor) || istype(T, /turf/floor/plating))
		return "You can't dig a well here."
	if (locate(/obj/structure/multiz) in T)
		return "There is a tunnel entrance here!"
	if (sewer_piece_at(T) || (locate(/obj/structure/toilet) in T))
		return "A well cannot share its hole with a drain or a latrine."
	if (locate(/obj/structure/sink) in T)
		return "There is water here already. Build a well over it."
	return null

// ---- water in a dug well ---------------------------------------------------------

/obj/structure/sink/proc/dug_max_depth()
	return 0

/obj/structure/sink/puddle/waterhole/dug_max_depth()
	return WELL_DEPTH_UNLINED

/obj/structure/sink/well/dug_max_depth()
	return WELL_DEPTH_STONE

/obj/structure/sink/well/timber/dug_max_depth()
	return WELL_DEPTH_TIMBER

// A bare hole silts up and gives water half as fast.
/obj/structure/sink/proc/dug_recharge_factor()
	return 1

/obj/structure/sink/puddle/waterhole/dug_recharge_factor()
	return 0.5

// Spits from the rim down to the water now: a dry season or a heat wave
// draws it down.
/obj/structure/sink/proc/dug_table()
	. = well_water_table(get_turf(src))
	if (. <= 0)
		return
	if (dry)
		. += WELL_DRY_SPELL
	if (weather_heat_at(src))
		. += WELL_DRY_SPELL

// Levels of water standing in the bottom.
/obj/structure/sink/proc/dug_column()
	return max(0, dug_depth - dug_table())

// Bring the water up to date: what has seeped in since it was last used.
/obj/structure/sink/proc/dug_settle()
	if (!dug_depth)
		return
	var/column = dug_column()
	max_volume = round(min(WELL_VOLUME_MAX, column * WELL_VOLUME_PER_LEVEL))
	var/minutes = dug_settled_at ? max(0, world.time - dug_settled_at) / 600 : 0
	dug_settled_at = world.time
	volume += minutes * min(column, WELL_RECHARGE_LEVELS) * WELL_RECHARGE_PER_LEVEL * dug_recharge_factor()
	volume = clamp(volume, 0, max_volume)

/obj/structure/sink/well/refill()
	if (dug_depth)
		return
	..()

/obj/structure/sink/well/heat_dried()
	if (dug_depth)
		return dug_column() <= 0
	return ..()

/obj/structure/sink/proc/dug_examine(mob/user)
	if (!dug_depth || get_dist(src, user) > 2)
		return
	dug_settle()
	var/table = dug_table()
	var/column = dug_depth - table
	to_chat(user, SPAN_NOTICE("It is dug [dug_depth] spit\s deep and will stand to [dug_max_depth()]."))
	if (column <= 0)
		if (dry || weather_heat_at(src))
			to_chat(user, SPAN_WARNING("The dry weather has drawn the water down below its bottom. Dug deeper, it would hold water through a dry spell."))
		else
			to_chat(user, SPAN_WARNING("It has not reached water. [well_earth_text(get_turf(src), dug_depth)]"))
		return
	var/standing = column >= 2 ? "Deep water stands" : (column >= 1 ? "A good depth of water stands" : "A little water stands")
	to_chat(user, SPAN_NOTICE("[standing] in it, [table <= 0.5 ? "close under the rim" : "about [round(table, 0.5)] spit\s down"]."))
	if (table > WELL_HAND_REACH && !well_fitting())
		to_chat(user, SPAN_NOTICE("That is too far down to drink from your hands: lower a cup or a bucket, or build a windlass over it."))
	if (column < WELL_DRY_SPELL)
		to_chat(user, SPAN_NOTICE("It is shallow enough to fail in a dry season or a heat wave."))

// Drinking and drawing. Returns FALSE when the user cannot reach the water.
/obj/structure/sink/proc/dug_reach(mob/user, obj/item/O)
	if (!dug_depth)
		return TRUE
	dug_settle()
	update_icon()
	if (volume <= 0 || !ishuman(user) || well_fitting())
		return TRUE
	var/table = dug_table()
	if (table <= WELL_HAND_REACH)
		return TRUE
	var/mob/living/human/H = user
	if (!O)
		if (H.a_intent != I_GRAB)
			return TRUE
		to_chat(H, SPAN_WARNING("The water is too far down to drink from your hands. Lower a cup or a bucket."))
		return FALSE
	var/obj/item/weapon/reagent_containers/RG = O
	if (!istype(RG) || !RG.is_open_container())
		return TRUE
	to_chat(H, SPAN_NOTICE("You lower \the [RG] down the well on a line."))
	return do_after(H, round((table - WELL_HAND_REACH) * WELL_HAUL_TIME) + WELL_HAUL_TIME, src, check_for_repeats = FALSE)

// A drink from the hands takes water out of a dug well.
/obj/structure/sink/proc/dug_drink(mob/living/human/H, water_before)
	if (dug_depth && istype(H) && H.water > water_before)
		volume = max(0, volume - WELL_DRINK_VOLUME)
		update_icon()

// ---- digging -------------------------------------------------------------------

/obj/structure/sink/proc/dug_dig_time(mob/user, obj/item/weapon/material/shovel/S, depth)
	return work_delay_per_speed(user, WELL_DIG_TIME + (depth - 1) * WELL_DIG_TIME_PER_SPIT, WORK_DIG, S)

// Why it cannot be dug a spit deeper, or null.
/obj/structure/sink/proc/dug_deepen_problem()
	if (!dug_depth)
		return "\The [src] is fed by a spring: digging will not better it."
	if (dug_depth >= dug_max_depth())
		if (dug_max_depth() < WELL_DEPTH_STONE)
			return "The sides will not stand any deeper. Line it with [dug_max_depth() < WELL_DEPTH_TIMBER ? "timber or stone" : "stone"] first."
		return "It is as deep as a well can be dug by hand."
	return null

// One more spit, with the spoil heaped beside it.
/obj/structure/sink/proc/dug_deepen()
	dug_settle()
	dug_depth++
	dug_settle()
	update_icon()
	excavation_spoil(get_turf(src), 1)

/obj/structure/sink/proc/dug_fill_in()
	qdel(src)

/obj/structure/sink/proc/dug_dig(mob/living/user, obj/item/weapon/material/shovel/S)
	if (!dug_depth || !istype(user))
		return FALSE
	var/choice = WWinput(user, "\The [src] is [dug_depth] spit\s deep.", "Well", "Dig deeper", list("Dig deeper", "Fill it in", "Cancel"))
	if (choice == "Cancel" || QDELETED(src) || !user.Adjacent(src))
		return TRUE
	if (choice == "Fill it in")
		if (dug_lined())
			to_chat(user, SPAN_WARNING("The lining holds the shaft open. Break it up with a hammer first."))
			return TRUE
		user.visible_message(SPAN_WARNING("[user] starts filling in \the [src]."), SPAN_NOTICE("You start filling in \the [src]."))
		playsound(src, 'sound/effects/shovelling.ogg', 100, TRUE)
		if (do_after(user, dug_dig_time(user, S, dug_depth), src) && !QDELETED(src))
			to_chat(user, SPAN_NOTICE("You fill \the [src] in."))
			log_game("[key_name(user)] filled in [src] at [x],[y],[z].")
			dug_fill_in()
		return TRUE
	var/problem = dug_deepen_problem()
	if (problem)
		to_chat(user, SPAN_WARNING(problem))
		return TRUE
	user.visible_message(SPAN_NOTICE("[user] starts digging \the [src] deeper."), SPAN_NOTICE("You start digging \the [src] deeper."), SPAN_NOTICE("You hear the ground being dug nearby."))
	playsound(src, 'sound/effects/shovelling.ogg', 100, TRUE)
	if (!do_after(user, dug_dig_time(user, S, dug_depth + 1), src) || QDELETED(src) || dug_deepen_problem())
		return TRUE
	dug_deepen()
	to_chat(user, SPAN_NOTICE("You dig \the [src] to [dug_depth] spit\s. [well_earth_text(get_turf(src), dug_depth)]"))
	if (ishuman(user))
		var/mob/living/human/H = user
		H.adaptStat("strength", 1)
	return TRUE

/obj/item/weapon/material/shovel/proc/shovel_dig_well(mob/living/user, turf/floor/TB)
	var/obj/structure/sink/dug = well_dug_at(TB)
	if (dug)
		dug.dug_dig(user, src)
		return
	var/problem = well_site_problem(TB)
	if (problem)
		to_chat(user, SPAN_WARNING(problem))
		return
	user.visible_message(SPAN_NOTICE("[user] starts digging a waterhole."), SPAN_NOTICE("You start digging a waterhole."), SPAN_NOTICE("You hear the ground being dug nearby."))
	playsound(src, 'sound/effects/shovelling.ogg', 100, TRUE)
	if (!do_after(user, work_delay_per_speed(user, WELL_DIG_TIME, WORK_DIG, src), src) || well_site_problem(TB))
		return
	var/obj/structure/sink/puddle/waterhole/W = new /obj/structure/sink/puddle/waterhole(TB)
	excavation_spoil(TB, 1)
	to_chat(user, SPAN_NOTICE("You dig a waterhole a spit deep. [well_earth_text(TB, W.dug_depth)] Dig again here to go deeper."))

// ---- the waterhole ---------------------------------------------------------------

/obj/structure/sink/puddle/waterhole
	name = "waterhole"
	desc = "A hole dug down toward the water in the ground. What gathers in a bare hole is muddy: boil it before you drink it. A lining of timber or stone makes a clean well of it, and lets it be dug deeper."
	icon = 'icons/obj/wells.dmi'
	icon_state = "waterhole_dry"
	mosquito_limit = 0
	dug_depth = 1
	volume = 0
	max_volume = 0

/obj/structure/sink/puddle/waterhole/refill()
	return

/obj/structure/sink/puddle/waterhole/heat_dried()
	return dug_column() <= 0

/obj/structure/sink/puddle/waterhole/update_icon()
	icon_state = (heat_dried() || volume <= 0) ? "waterhole_dry" : "waterhole"

/obj/structure/sink/puddle/waterhole/examine(mob/user, distance = -1)
	. = ..()
	if (.)
		dug_examine(user)

// The puddle underneath shows its splash while someone is at the water.
/obj/structure/sink/puddle/waterhole/attack_hand(mob/user)
	if (!dug_reach(user))
		return
	var/mob/living/human/H = user
	var/before = istype(H) ? H.water : 0
	..()
	dug_drink(H, before)
	update_icon()

/obj/structure/sink/puddle/waterhole/attackby(obj/item/O, mob/user)
	if (is_tool(O, TOOL_SHOVEL))
		dug_dig(user, O)
		return
	if (!dug_reach(user, O))
		return
	..()
	update_icon()

// ---- lined wells -----------------------------------------------------------------

/obj/structure/sink/well/timber
	name = "timber-lined well"
	desc = "A well shaft lined with a crib of split timber, with a low curb of logs around its mouth."
	icon = 'icons/obj/wells.dmi'
	icon_state = "timber_well"

/obj/structure/sink/well/timber/update_icon()
	icon_state = (heat_dried() || volume <= 0) ? "timber_well_dry" : "timber_well"

// A lining takes over the hole it is built in: its depth, and its water once
// the mud has settled.
/obj/structure/sink/well/on_runtime_spawn()
	..()
	well_adopt_site()

/obj/structure/sink/well/proc/well_adopt_site()
	for (var/obj/structure/sink/S in loc)
		if (S == src || !S.dug_depth)
			continue
		dug_depth = max(dug_depth, S.dug_depth)
		dry = S.dry
		if (istype(S, /obj/structure/sink/well))
			dirty = dirty || S.dirty
		S.dug_settle()
		volume = S.volume
		qdel(S)
	if (dug_depth)
		dug_settle()
		update_icon()

/obj/structure/sink/well/examine(mob/user, distance = -1)
	. = ..()
	if (.)
		dug_examine(user)
		if (get_dist(src, user) <= 1)
			to_chat(user, SPAN_NOTICE("A hammer would take [well_fitting() ? "its fitting down" : "its lining apart"]."))

/obj/structure/sink/well/attack_hand(mob/user)
	if (!dug_reach(user))
		return
	var/mob/living/human/H = user
	var/before = istype(H) ? H.water : 0
	..()
	dug_drink(H, before)

/obj/structure/sink/well/attackby(obj/item/O, mob/user)
	if (is_tool(O, TOOL_HAMMER))
		well_break(user)
		return
	if (is_tool(O, TOOL_SHOVEL))
		if (dug_depth)
			dug_dig(user, O)
		else
			to_chat(user, SPAN_WARNING("A shovel will not shift the lining. Break it up with a hammer."))
		return
	var/obj/structure/well_fitting/F = well_fitting()
	if (F && F.draw(src, O, user))
		return
	if (!dug_reach(user, O))
		return
	..()

// ---- taking a well apart -----------------------------------------------------------
// A fitting comes off first, then the lining is broken up. A dug shaft is left as
// a bare waterhole a shovel can fill in; a well over a spring leaves its puddle.

/obj/structure/sink/proc/dug_lined()
	return FALSE

/obj/structure/sink/well/dug_lined()
	return TRUE

// What is got back, about half of what went in.
/obj/structure/sink/well/proc/well_salvage()
	return list(/obj/item/stack/material/stone = 3)

/obj/structure/sink/well/sandstone/well_salvage()
	return list(/obj/item/stack/material/sandstone = 3)

/obj/structure/sink/well/marble/well_salvage()
	return list(/obj/item/stack/material/marble = 3)

/obj/structure/sink/well/timber/well_salvage()
	return list(/obj/item/stack/material/wood = 2)

/proc/well_drop_salvage(turf/T, list/salvage)
	for (var/path in salvage)
		new path(T, salvage[path])

// The lining comes out. Unlined sides only stand so deep, so the rest caves in.
/obj/structure/sink/well/proc/well_break_lining(salvage = TRUE)
	var/turf/T = get_turf(src)
	if (!T)
		qdel(src)
		return null
	if (salvage)
		well_drop_salvage(T, well_salvage())
	var/obj/structure/sink/puddle/left
	if (dug_depth)
		dug_settle()
		left = new /obj/structure/sink/puddle/waterhole(T)
		left.dug_depth = min(dug_depth, WELL_DEPTH_UNLINED)
		left.dry = dry
		left.dug_settle()
		left.volume = min(volume, left.volume)
		left.update_icon()
	else
		left = new /obj/structure/sink/puddle(T)
	qdel(src)
	return left

/obj/structure/sink/well/proc/well_break(mob/living/user)
	if (!istype(user))
		return
	var/obj/structure/well_fitting/F = well_fitting()
	if (F)
		user.visible_message(SPAN_WARNING("[user] starts taking \the [F] off \the [src]."), SPAN_NOTICE("You start taking \the [F] off \the [src]."))
		playsound(src, 'sound/effects/woodhit.ogg', 100, TRUE)
		if (!do_after(user, WELL_UNFIT_TIME, src) || QDELETED(src) || QDELETED(F))
			return
		to_chat(user, SPAN_NOTICE("You take \the [F] down."))
		F.unfit()
		return
	if (WWinput(user, "Break up the lining of \the [src]?[dug_depth ? "" : " The spring under it will be left as a puddle."]", "Well", "Cancel", list("Break it up", "Cancel")) != "Break it up")
		return
	if (QDELETED(src) || !user.Adjacent(src) || well_fitting())
		return
	user.visible_message(SPAN_DANGER("[user] starts breaking up the lining of \the [src]!"), SPAN_NOTICE("You start breaking up the lining of \the [src]."), SPAN_NOTICE("You hear hammering nearby."))
	playsound(src, 'sound/effects/woodhit.ogg', 100, TRUE)
	if (!do_after(user, WELL_BREAK_TIME, src) || QDELETED(src) || well_fitting())
		return
	log_game("[key_name(user)] broke up [src] at [x],[y],[z].")
	var/obj/structure/sink/left = well_break_lining()
	to_chat(user, SPAN_NOTICE("You break up the lining. [istype(left, /obj/structure/sink/puddle/waterhole) ? "A bare hole is left: a shovel will fill it in." : "The spring is left as a puddle."]"))

/obj/structure/well_fitting/proc/unfit()
	well_drop_salvage(get_turf(src), salvage)
	qdel(src)

// A blast close by fills the shaft; one further off shakes the lining out.
/obj/structure/sink/well/ex_act(severity)
	if (severity <= 1)
		qdel(src)
	else if (severity <= 2 && prob(50))
		well_break_lining(FALSE)

/obj/structure/sink/puddle/waterhole/ex_act(severity)
	if (severity <= 2)
		qdel(src)

// ---- fittings --------------------------------------------------------------------

// The windlass or pump over this water, or null.
/obj/structure/sink/proc/well_fitting()
	return null

/obj/structure/sink/well/well_fitting()
	return locate(/obj/structure/well_fitting) in loc

/obj/structure/sink/well/Destroy()
	for (var/obj/structure/well_fitting/F in loc)
		qdel(F)
	return ..()

/obj/structure/well_fitting
	icon = 'icons/obj/wells.dmi'
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	layer = 3.05
	not_movable = TRUE
	not_disassemblable = TRUE
	var/draw_time = WELL_WINDLASS_TIME
	var/use_state = null
	var/draw_text = "wind a full pail up"
	var/list/salvage = list(/obj/item/stack/material/wood = 2, /obj/item/stack/material/rope = 1)

/obj/structure/well_fitting/proc/well()
	return locate(/obj/structure/sink/well) in loc

// A newer fitting takes the place of the one on the well.
/obj/structure/well_fitting/on_runtime_spawn()
	..()
	for (var/obj/structure/well_fitting/F in loc)
		if (F != src)
			qdel(F)

/obj/structure/well_fitting/attack_hand(mob/user)
	var/obj/structure/sink/well/W = well()
	if (W)
		return W.attack_hand(user)
	return ..()

/obj/structure/well_fitting/attackby(obj/item/O, mob/user)
	var/obj/structure/sink/well/W = well()
	if (W)
		return W.attackby(O, user)
	return ..()

// Units a container takes in one drawing: all it has room for.
/obj/structure/well_fitting/proc/draw_amount(obj/structure/sink/well/W, obj/item/weapon/reagent_containers/RG)
	return max(0, min(RG.volume - RG.reagents.total_volume, W.volume))

// Fill RG from the well in one go, foul water and all. Returns the units drawn.
/obj/structure/well_fitting/proc/draw_into(obj/structure/sink/well/W, obj/item/weapon/reagent_containers/RG)
	W.dug_settle()
	if (W.heat_dried())
		return 0
	var/amount = draw_amount(W, RG)
	if (amount <= 0)
		return 0
	if (W.has_nearby_fecal_waste())
		W.dirty = TRUE
	W.flood_foul()
	var/watertype = W.radiation > 0 ? "irradiated_water" : "water"
	if (W.dirty)
		RG.reagents.add_reagent("cholera", amount * 0.05)
		RG.note_food_toxin("unboiled water from a dirty [W.name] (fecal waste nearby) at ([W.x],[W.y],[W.z])")
		RG.reagents.add_reagent(watertype, amount * 0.95)
	else
		RG.reagents.add_reagent(watertype, amount)
	W.volume -= amount
	W.update_icon()
	return amount

// Drawing with an open container. Returns TRUE when the fitting dealt with it.
/obj/structure/well_fitting/proc/draw(obj/structure/sink/well/W, obj/item/O, mob/user)
	var/obj/item/weapon/reagent_containers/RG = O
	if (!istype(RG) || !RG.is_open_container() || !RG.reagents)
		return FALSE
	W.dug_settle()
	W.update_icon()
	if (W.heat_dried() || W.volume <= 0)
		to_chat(user, SPAN_WARNING("\The [W] is dry!"))
		return TRUE
	if (RG.reagents.total_volume >= RG.volume)
		to_chat(user, SPAN_WARNING("\The [RG] is full."))
		return TRUE
	if (use_state)
		flick(use_state, src)
	if (!do_after(user, draw_time, W, check_for_repeats = FALSE) || QDELETED(W) || QDELETED(RG))
		return TRUE
	if (draw_into(W, RG))
		user.visible_message(SPAN_NOTICE("[user] fills \the [RG] at \the [W]."), SPAN_NOTICE("You [draw_text] and fill \the [RG]."))
		playsound(W.loc, 'sound/effects/watersplash.ogg', 100, TRUE)
	else
		to_chat(user, SPAN_WARNING("\The [W] is dry!"))
	return TRUE

/obj/structure/well_fitting/windlass
	name = "well windlass"
	desc = "A roller on two posts over the well, with a rope and a pail. Winding it brings up a full pail from any depth."
	icon_state = "fit_windlass"
	use_state = "fit_windlass_use"

/obj/structure/well_fitting/pump
	name = "well pump"
	desc = "A cast iron hand pump bolted to a plank cover over the well. A few strokes of the handle fill a bucket."
	icon_state = "fit_pump"
	use_state = "fit_pump_use"
	draw_time = WELL_PUMP_TIME
	draw_text = "work the handle"
	salvage = list(/obj/item/stack/material/iron = 3)

// Fittings go on a lined well and nowhere else.
/datum/craft_guard/well_fitting
	order = 75
	after_wait = TRUE

/datum/craft_guard/well_fitting/refusal(mob/living/human/H, datum/stack_recipe/R, phase)
	if (!ispath(R.result_type, /obj/structure/well_fitting))
		return null
	if (locate(/obj/structure/sink/well) in get_turf(H))
		return null
	return phase == CRAFT_GUARD_START ? "<span class='warning'>Build this standing on a lined well.</span>" : ""

#undef WELL_TABLE_BASE
#undef WELL_TABLE_SLOPE
#undef WELL_TABLE_MIN
#undef WELL_DRY_SPELL
#undef WELL_DEPTH_UNLINED
#undef WELL_DEPTH_TIMBER
#undef WELL_DEPTH_STONE
#undef WELL_VOLUME_PER_LEVEL
#undef WELL_VOLUME_MAX
#undef WELL_RECHARGE_PER_LEVEL
#undef WELL_RECHARGE_LEVELS
#undef WELL_HAND_REACH
#undef WELL_HAUL_TIME
#undef WELL_DRINK_VOLUME
#undef WELL_DIG_TIME
#undef WELL_DIG_TIME_PER_SPIT
#undef WELL_WINDLASS_TIME
#undef WELL_PUMP_TIME
