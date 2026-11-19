// Placer mining: pay dirt, the sluice box and the rocker (docs/placer.md).
//
// Pay dirt is gravel shovelled from river banks. What it carries is set by
// the district it comes from (the mountain-seam hash, so nothing is saved):
// about one district in four is gold-bearing, more carry tin, the rest are
// barren sand with a little iron sand. Nobody can choose the metal; panning a
// load tells you what the ground holds. Washing it in a sluice or a rocker is
// faster than a pan. Every bank tile gives a few loads, then rests.

#define PAY_DIRT_DISTRICT 16
#define PAY_DIRT_LOADS 3
#define PAY_DIRT_REGROW 4000 // deciseconds per load coming back
#define PAY_DIRT_DIG_TIME 100
#define PAN_PAY_DIRT_TIME 200
#define SLUICE_WASH_TIME 60
#define ROCKER_WASH_TIME 45
// Mercury in the riffles: a quarter more gold, a little lost every load.
#define SLUICE_MERCURY_BONUS 1.25
#define SLUICE_MERCURY_LOSS 0.05

// "x,y,z" -> /datum/resource_stock for dug bank tiles. Runtime only.
var/global/list/pay_dirt_stock = list()

/obj/item/stack/ore/pay_dirt
	name = "pay dirt"
	desc = "Wet gravel shovelled from a river bank. Whatever metal it holds has to be washed out of it: in a pan, a sluice box or a rocker."
	icon = 'icons/obj/placer.dmi'
	icon_state = "pay_dirt"
	singular_name = "load"
	flammable = FALSE
	max_amount = 20
	var/grade = "barren"

/obj/item/stack/ore/pay_dirt/tin
	grade = "tin"

/obj/item/stack/ore/pay_dirt/rich
	grade = "rich"

// The grade of pay dirt dug at x, y: "rich" (gold), "tin" or "barren".
/proc/pay_dirt_grade(x, y)
	var/bx = round((x - 1) / PAY_DIRT_DISTRICT)
	var/by = round((y - 1) / PAY_DIRT_DISTRICT)
	var/roll = mountain_seam_hash("[bx],[by],[mountain_seam_map_key()],placer") % 100
	if (roll < 25)
		return "rich"
	if (roll < 65)
		return "tin"
	return "barren"

/proc/pay_dirt_type(grade)
	switch (grade)
		if ("rich")
			return /obj/item/stack/ore/pay_dirt/rich
		if ("tin")
			return /obj/item/stack/ore/pay_dirt/tin
	return /obj/item/stack/ore/pay_dirt

/turf/proc/pay_dirt_bank()
	return can_sift_resources() && panning_water()

/turf/proc/pay_dirt_stock()
	var/key = "[x],[y],[z]"
	var/datum/resource_stock/S = pay_dirt_stock[key]
	if (!S)
		S = new /datum/resource_stock(PAY_DIRT_LOADS, PAY_DIRT_REGROW)
		pay_dirt_stock[key] = S
	return S

/mob/living/human/var/tmp/digging_pay_dirt = FALSE

/mob/living/human/persistence_runtime_var(key)
	return key == "digging_pay_dirt" || ..()

/mob/living/human/verb/dig_pay_dirt()
	set name = "Dig pay dirt"
	set category = "Crafting"
	set desc = "Shovel gravel from the river bank you stand on, to wash for metal."
	var/obj/item/weapon/material/shovel/S = get_active_hand()
	if (!istype(S))
		to_chat(src, SPAN_WARNING("Hold a shovel."))
		return
	var/turf/T = loc
	if (!istype(T) || !T.pay_dirt_bank())
		to_chat(src, SPAN_WARNING("Stand on an uncovered river bank, dirt or sand right beside shallow fresh water."))
		return
	if (digging_pay_dirt || stat)
		return
	var/datum/resource_stock/stock = T.pay_dirt_stock()
	if (stock.available() < 1)
		to_chat(src, SPAN_WARNING("This bit of bank is dug out. Try further along the river, or come back later."))
		return
	digging_pay_dirt = TRUE
	visible_message(SPAN_NOTICE("[src] starts shovelling gravel from the bank."))
	var/done = do_after(src, work_delay(src, PAY_DIRT_DIG_TIME, WORK_DIG, get_active_hand()), T)
	digging_pay_dirt = FALSE
	if (!done || get_active_hand() != S || loc != T || !stock.take(1))
		return
	spawn_stack(pay_dirt_type(pay_dirt_grade(T.x, T.y)), T, 1)
	to_chat(src, SPAN_NOTICE("You shovel up a load of pay dirt."))

// One load washed by a method ("pan", "sluice", "rocker"): a list of
// ore type -> amount. Gold is a chance per load, so the long run matches the
// per-hour rates in docs/placer.md.
/proc/pay_dirt_wash(grade, method, mercury = FALSE, roll = null)
	. = list()
	var/scale = method == "rocker" ? 1.2 : (method == "pan" ? 0.55 : 1)
	if (mercury)
		scale *= SLUICE_MERCURY_BONUS
	var/gold = 0
	var/silver = 0
	var/tin = 0
	var/iron_sand = 0
	var/sand = 0
	switch (grade)
		if ("rich")
			gold = 27
			silver = 5
			tin = 20
		if ("tin")
			gold = 9
			tin = 60
		else
			gold = 1
			iron_sand = map && map.ordinal_age >= 1 ? 50 : 0
			sand = 40
	if (prob(gold * scale))
		.[/obj/item/stack/ore/gold] = 1
	if (prob(silver * scale))
		.[/obj/item/stack/ore/silver] = 1
	if (prob(tin))
		.[/obj/item/stack/ore/tin] = 1
	if (prob(iron_sand))
		.[/obj/item/stack/ore/iron_sand] = 1
	if (prob(sand))
		.[/obj/item/stack/ore/glass] = 1

/proc/pay_dirt_output(list/found, turf/T)
	var/list/names = list()
	for (var/ore_type in found)
		spawn_stack(ore_type, T, found[ore_type])
		var/obj/item/stack/O = ore_type
		names += initial(O.name)
	return names

// Panning pay dirt in a wooden bowl beside water: slow, but it tells you what
// the ground carries.
/obj/item/kitchen/wood_bowl/attackby(obj/item/I, mob/living/human/H)
	if (!istype(I, /obj/item/stack/ore/pay_dirt) || !istype(H))
		return ..()
	var/obj/item/stack/ore/pay_dirt/P = I
	var/turf/T = get_turf(H)
	if (!T || !T.panning_water())
		to_chat(H, SPAN_WARNING("Stand beside shallow fresh water to pan pay dirt."))
		return
	to_chat(H, SPAN_NOTICE("You swirl a load of pay dirt in \the [src]."))
	if (!do_after(H, PAN_PAY_DIRT_TIME, T) || QDELETED(P) || P.amount < 1)
		return
	var/grade = P.grade
	P.use(1)
	var/list/names = pay_dirt_output(pay_dirt_wash(grade, "pan"), T)
	river_mercury_pan_message(H, T.panning_water())
	switch (grade)
		if ("rich")
			to_chat(H, SPAN_NOTICE("Yellow flecks glint in the black sand at the bottom of the pan. This ground carries gold."))
		if ("tin")
			to_chat(H, SPAN_NOTICE("Heavy dark tinstone grains settle in the pan. This ground carries tin."))
		else
			to_chat(H, SPAN_NOTICE("Nothing but sand and a little black iron sand. This ground carries no metal worth washing."))
	if (names.len)
		to_chat(H, SPAN_NOTICE("You keep: [english_list(names)]."))

//////////////////////////////////////////////////////////////////////////////
// Sluice box and rocker

/obj/structure/placer_washer
	name = "placer washer"
	icon = 'icons/obj/placer.dmi'
	density = FALSE
	anchored = TRUE
	not_movable = FALSE
	not_disassemblable = FALSE
	water_capacity = 30
	water_per_use = 5
	var/method = "sluice"
	var/wash_time = SLUICE_WASH_TIME
	var/idle_state = "sluice"
	var/busy_state = "sluice_running"
	var/wood_back = 3
	var/node = "bronze_working"
	var/tmp/washing = FALSE

/obj/structure/placer_washer/persistence_runtime_var(key)
	return key == "washing" || ..()

/obj/structure/placer_washer/examine(mob/user, distance)
	..(user, distance)
	station_water_examine(user)

/obj/structure/placer_washer/proc/mercury_charged()
	return FALSE

/obj/structure/placer_washer/proc/spend_mercury()
	return

// What this washer takes: pay dirt here, crushed ore in a buddle (lode.dm).
/obj/structure/placer_washer/proc/accepts_feed(obj/item/I)
	return istype(I, /obj/item/stack/ore/pay_dirt)

// Whether another load can go through now (a cyanide vat needs its charge).
/obj/structure/placer_washer/proc/can_wash_load(mob/living/human/H)
	return TRUE

// Washes one unit of feed P (already checked): ore type -> amount found.
/obj/structure/placer_washer/proc/wash_load(obj/item/stack/P)
	var/obj/item/stack/ore/pay_dirt/D = P
	var/grade = D.grade
	P.use(1)
	var/mercury = mercury_charged()
	. = pay_dirt_wash(grade, method, mercury)
	if (mercury)
		spend_mercury()

/obj/structure/placer_washer/attackby(obj/item/I, mob/living/human/H)
	if (!istype(H))
		return ..()
	if (washing)
		to_chat(H, SPAN_WARNING("Someone is washing in \the [src]."))
		return
	if (is_tool(I, TOOL_HAMMER) && H.a_intent == I_HARM)
		visible_message(SPAN_NOTICE("[H] starts taking \the [src] apart."))
		if (do_after(H, 40, src) && !QDELETED(src) && !washing)
			spawn_stack(/obj/item/stack/material/wood, get_turf(src), wood_back)
			qdel(src)
		return
	if (station_water_pour(I, H))
		return
	if (accepts_feed(I))
		wash(I, H)
		return
	return ..()

// Washes the held pay dirt one load at a time until it runs out, the water
// does, or the worker stops.
/obj/structure/placer_washer/proc/wash(obj/item/stack/P, mob/living/human/H)
	if (!crafting_node_allowed_or_warn(H, node))
		return
	washing = TRUE
	icon_state = busy_state
	var/feed_name = P.name
	visible_message(SPAN_NOTICE("[H] starts washing [feed_name] in \the [src]."))
	var/loads = 0
	var/list/kept = list()
	while (!QDELETED(P) && P.amount > 0 && P.loc == H && get_dist(H, src) <= 1)
		if (!can_wash_load(H))
			break
		if (!station_has_water())
			station_take_water(H)
			break
		if (!do_after(H, wash_time, src) || QDELETED(P) || P.amount < 1 || QDELETED(src))
			break
		if (!station_take_water(H))
			break
		var/list/found = wash_load(P)
		for (var/name in pay_dirt_output(found, get_turf(src)))
			kept[name] = (kept[name] || 0) + 1
		loads++
	washing = FALSE
	if (!QDELETED(src))
		icon_state = idle_state
	if (loads)
		var/list/parts = list()
		for (var/name in kept)
			parts += "[kept[name]] [name]"
		to_chat(H, SPAN_NOTICE("You wash [loads] load\s of [feed_name][parts.len ? " and keep [english_list(parts)]" : ", and find nothing"]."))

/obj/structure/placer_washer/sluice
	name = "sluice box"
	desc = "A long sloped wooden trough with cross riffles and a fleece in the bottom, the way gold has been caught since Roman times. Set it by running water, or pour water into it, then wash pay dirt down it: the heavy grains stay behind the riffles. Pour a little quicksilver into the riffles to catch more fine gold, at the price of some lost to the water every load."
	icon_state = "sluice"
	wood_back = 4

/obj/structure/placer_washer/sluice/New()
	..()
	if (!reagents)
		create_reagents(10)

/obj/structure/placer_washer/sluice/examine(mob/user, distance)
	..(user, distance)
	if (reagents && reagents.get_reagent_amount("mercury") >= 1)
		to_chat(user, SPAN_NOTICE("Quicksilver gleams behind the riffles ([round(reagents.get_reagent_amount("mercury"), 0.1)] units)."))

/obj/structure/placer_washer/sluice/attackby(obj/item/I, mob/living/human/H)
	var/obj/item/weapon/reagent_containers/C = I
	if (istype(C) && C.is_open_container() && C.reagents && C.reagents.get_reagent_amount("mercury") > 0 && !washing)
		var/room = reagents.get_free_space()
		var/amount = min(room, C.reagents.get_reagent_amount("mercury"))
		if (amount <= 0)
			to_chat(H, SPAN_NOTICE("The riffles hold all the quicksilver they can."))
			return
		C.reagents.remove_reagent("mercury", amount)
		reagents.add_reagent("mercury", amount)
		to_chat(H, SPAN_NOTICE("You pour [amount] units of quicksilver into the riffles."))
		return
	return ..()

/obj/structure/placer_washer/sluice/mercury_charged()
	return reagents && reagents.get_reagent_amount("mercury") >= 1

// Mercury washed away settles in the river bed beside it, or fouls the ground.
/obj/structure/placer_washer/sluice/spend_mercury()
	reagents.remove_reagent("mercury", SLUICE_MERCURY_LOSS)
	river_mercury_spill(get_turf(src), SLUICE_MERCURY_LOSS)

/obj/structure/placer_washer/rocker
	name = "rocker"
	desc = "A gold-rush cradle: a wooden box on rockers with a sieve hopper on top. Pour water in with a bucket, tip pay dirt into the hopper and rock it: one person can wash gold anywhere they can carry water to, faster than a sluice."
	icon_state = "rocker"
	idle_state = "rocker"
	busy_state = "rocker_rocking"
	method = "rocker"
	wash_time = ROCKER_WASH_TIME
	water_capacity = 40
	anchored = FALSE
	wood_back = 3
	node = "ore_dressing"
