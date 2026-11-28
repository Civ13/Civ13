// Amalgamation and river bed mercury (docs/amalgam.md).
//
// Quicksilver grabs fine gold and silver out of crushed ore as amalgam. Three
// ways to make it: the stone crusher charged with quicksilver and water works
// as an arrastra; a patio heap of crushed silver ore, quicksilver, salt and
// copper ore is turned in the open; later the drum line (industrial milling).
// Wet amalgam goes through the press, which squeezes free quicksilver back,
// then the retort, which drives the rest off and leaves sponge metal.
//
// Every step loses a little quicksilver. What is lost beside a river settles
// in the river bed of that reach and the next two downstream, where it lasts
// for days: people who drink there, fish caught there and wells dug near it
// take it up (burden, mercury.dm). Elsewhere it fouls the ground.

#define AMALGAM_WET_MERCURY 2 // units of quicksilver in a lump of wet amalgam
#define AMALGAM_HARD_MERCURY 0.8 // left in a pressed lump
#define AMALGAM_RETORT_RETURN 0.9
#define ARRASTRA_RECOVERY 0.55
#define ARRASTRA_LOSS 0.15 // units lost per load
#define ARRASTRA_TIME 60
#define ARRASTRA_WATER 2
#define PATIO_LOADS 20
#define PATIO_MERCURY 20
#define PATIO_SALT 10
#define PATIO_TURNS 6
#define PATIO_TURN_TIME 100
#define PATIO_RECOVERY 0.7
#define PRESS_TIME 20
// River bed mercury.
#define RIVER_MERCURY_THRESHOLD 1 // units in a reach's bed before it shows
#define RIVER_MERCURY_MINUTE_KEEP 0.999833 // 0.99 an hour
#define RIVER_MERCURY_DRINK 0.5 // burden per drink from a contaminated reach
#define RIVER_MERCURY_FISH_BITE 0.3 // burden per bite of a fish from one
#define RIVER_MERCURY_WATER_UNITS 1 // quicksilver in a container filled there

//////////////////////////////////////////////////////////////////////////////
// Items

/obj/item/stack/ore/amalgam
	name = "gold amalgam"
	singular_name = "lump"
	desc = "Soft, heavy grey amalgam of quicksilver and gold. Press the free quicksilver out of it in an amalgam press, then drive the rest off in a mercury retort to get the gold. Handle it outdoors: it gives off fumes when heated."
	icon = 'icons/obj/amalgam.dmi'
	icon_state = "amalgam_gold"
	flammable = FALSE
	max_amount = 20
	var/sponge_type = /obj/item/stack/ore/gold/sponge
	var/mercury_units = AMALGAM_WET_MERCURY
	var/pressed_type = /obj/item/stack/ore/amalgam/gold_pressed

/obj/item/stack/ore/amalgam/gold

/obj/item/stack/ore/amalgam/gold_pressed
	name = "pressed gold amalgam"
	desc = "Gold amalgam squeezed hard in a press. Most of the free quicksilver is out of it; drive the rest off in a mercury retort to get the gold."
	mercury_units = AMALGAM_HARD_MERCURY
	pressed_type = null

/obj/item/stack/ore/amalgam/silver
	name = "silver amalgam"
	desc = "Soft, heavy grey amalgam of quicksilver and silver. Press the free quicksilver out of it in an amalgam press, then drive the rest off in a mercury retort to get the silver. Handle it outdoors: it gives off fumes when heated."
	icon_state = "amalgam_silver"
	sponge_type = /obj/item/stack/ore/silver/sponge
	pressed_type = /obj/item/stack/ore/amalgam/silver_pressed

/obj/item/stack/ore/amalgam/silver_pressed
	name = "pressed silver amalgam"
	desc = "Silver amalgam squeezed hard in a press. Most of the free quicksilver is out of it; drive the rest off in a mercury retort to get the silver."
	icon_state = "amalgam_silver"
	sponge_type = /obj/item/stack/ore/silver/sponge
	mercury_units = AMALGAM_HARD_MERCURY
	pressed_type = null

/obj/item/stack/ore/gold/sponge
	name = "sponge gold"
	desc = "Porous gold left in the retort when the quicksilver has been driven off. It smelts like gold ore."
	icon = 'icons/obj/amalgam.dmi'
	icon_state = "sponge_gold"

/obj/item/stack/ore/silver/sponge
	name = "sponge silver"
	desc = "Porous silver left in the retort when the quicksilver has been driven off. It smelts like silver ore."
	icon = 'icons/obj/amalgam.dmi'
	icon_state = "sponge_silver"

/obj/item/stack/ore/tailings/amalgam
	name = "amalgam tailings"
	desc = "Grey slime washed out of amalgamation, with beads of quicksilver still in it. Tipped into a river it fouls the bed for days; leave it heaped well away from water."
	icon = 'icons/obj/amalgam.dmi'
	icon_state = "amalgam_tailings"

// The wet amalgam crushed ore of this metal makes.
/proc/amalgam_type_for(metal_type)
	return metal_type == /obj/item/stack/ore/silver ? /obj/item/stack/ore/amalgam/silver : /obj/item/stack/ore/amalgam/gold

// Tipping amalgam tailings into fresh water: the river bed takes it up.
/obj/item/stack/ore/tailings/amalgam/afterattack(atom/target, mob/user, proximity)
	var/turf/floor/beach/water/W = target
	if (!proximity || !istype(W) || W.salty || !ishuman(user))
		return ..()
	var/amount = src.amount
	river_mercury_spill(W, amount * 0.05)
	user.visible_message(SPAN_WARNING("[user] tips [amount] load\s of amalgam tailings into the water."), SPAN_WARNING("You tip the amalgam tailings into the water. Quicksilver beads sink into the bed."))
	qdel(src)

//////////////////////////////////////////////////////////////////////////////
// River bed mercury

/datum/river_flood/var/list/bed_mercury = list()

/datum/river_flood/proc/bed_mercury_ready()
	if (!islist(bed_mercury) || bed_mercury.len != count)
		bed_mercury = new /list(count)
		for (var/i in 1 to count)
			bed_mercury[i] = 0

// Settles amount in reach r: most in r, the rest in the next two downstream.
/datum/river_flood/proc/deposit_mercury(r, amount)
	bed_mercury_ready()
	var/left = amount
	for (var/share in list(0.6, 0.25, 0.15))
		bed_mercury[r] += amount * share
		left -= amount * share
		if (!down[r])
			break
		r = down[r]
	// A reach with nothing below it keeps what would have gone further.
	if (left > 0.0001)
		bed_mercury[r] += left

// One minute: the bed slowly buries or carries off what it holds.
/datum/river_flood/proc/step_bed_mercury()
	bed_mercury_ready()
	for (var/i in 1 to count)
		if (bed_mercury[i])
			bed_mercury[i] *= RIVER_MERCURY_MINUTE_KEEP
			if (bed_mercury[i] < 0.01)
				bed_mercury[i] = 0

/datum/river_flood/proc/bed_mercury_at(x, y)
	if (x < 1 || x > maxx || y < 1 || y > maxy)
		return 0
	var/r = reach_at(x, y)
	if (!r)
		return 0
	bed_mercury_ready()
	return bed_mercury[r]

// Quicksilver lying in the bed of the reach at T (0 off a charted river).
/proc/river_mercury_at(turf/T)
	if (!T || !map)
		return 0
	var/datum/river_flood/F = map.river_flood()
	if (!F || T.z != F.z_level)
		return 0
	return F.bed_mercury_at(T.x, T.y)

/proc/river_mercury_tainted(turf/T)
	return river_mercury_at(T) >= RIVER_MERCURY_THRESHOLD

// Quicksilver lost at T: into the river bed if fresh river water is next to
// it, otherwise into the ground. Returns TRUE when the river took it.
/proc/river_mercury_spill(turf/T, amount)
	T = get_turf(T)
	if (!T || amount <= 0)
		return FALSE
	var/datum/river_flood/F = map ? map.river_flood() : null
	if (F && T.z == F.z_level)
		for (var/turf/floor/beach/water/W in range(1, T))
			if (W.salty || W.x < 1 || W.x > F.maxx || W.y < 1 || W.y > F.maxy)
				continue
			var/r = F.reach_at(W.x, W.y)
			if (r)
				F.deposit_mercury(r, amount)
				return TRUE
	pollution_add(T, amount * 3)
	return FALSE

// TRUE when a contaminated reach lies within radius tiles of T.
/proc/river_mercury_near(turf/T, radius)
	if (!T || !map)
		return FALSE
	var/datum/river_flood/F = map.river_flood()
	if (!F || T.z != F.z_level)
		return FALSE
	for (var/turf/floor/beach/water/W in range(radius, T))
		if (!W.salty && F.bed_mercury_at(W.x, W.y) >= RIVER_MERCURY_THRESHOLD)
			return TRUE
	return FALSE

// Drinking straight from a contaminated reach.
/proc/river_mercury_drink(mob/living/human/H, turf/T)
	if (istype(H) && river_mercury_tainted(T))
		H.add_mercury_burden(RIVER_MERCURY_DRINK, "river water fouled with quicksilver")

// A container filled from a contaminated reach, or a well near one.
/proc/river_mercury_fill(obj/item/weapon/reagent_containers/RG, turf/T, radius = 0)
	if (!RG || !RG.reagents)
		return
	if (radius ? river_mercury_near(T, radius) : river_mercury_tainted(T))
		RG.reagents.add_reagent("mercury", RIVER_MERCURY_WATER_UNITS)
		RG.note_food_toxin("water drawn near a river bed fouled with quicksilver at ([T.x],[T.y],[T.z])")

// A fish caught in a contaminated reach carries it in its flesh.
/obj/item/weapon/reagent_containers/food/snacks/var/mercury_taint = FALSE

/proc/river_mercury_taint_catch(obj/item/I, turf/T)
	var/obj/item/weapon/reagent_containers/food/snacks/F = I
	if (istype(F) && river_mercury_tainted(T))
		F.mercury_taint = TRUE

/obj/item/weapon/reagent_containers/food/snacks/On_Consume(mob/M)
	if (mercury_taint && ishuman(M))
		var/mob/living/human/H = M
		H.add_mercury_burden(RIVER_MERCURY_FISH_BITE, "fish from a river fouled with quicksilver")
	return ..()

// What a pan shows in a contaminated reach.
/proc/river_mercury_pan_message(mob/user, turf/water)
	if (river_mercury_tainted(water))
		to_chat(user, SPAN_WARNING("Beads of quicksilver gather in the bottom of the pan. This river bed is fouled with it."))

//////////////////////////////////////////////////////////////////////////////
// The stone crusher as an arrastra

/obj/structure/stone_crusher
	water_capacity = 20
	water_per_use = ARRASTRA_WATER
	var/tmp/arrastra_busy = FALSE

/obj/structure/stone_crusher/get_saved_vars()
	. = ..()
	. -= "arrastra_busy"

/obj/structure/stone_crusher/New()
	..()
	if (!reagents)
		create_reagents(20)
	arrastra_update_overlay()

/obj/structure/stone_crusher/proc/arrastra_mercury()
	return reagents ? reagents.get_reagent_amount("mercury") : 0

/obj/structure/stone_crusher/proc/arrastra_update_overlay()
	overlays.Cut()
	if (arrastra_mercury() >= 1)
		overlays += image('icons/obj/amalgam.dmi', "arrastra_overlay")

/obj/structure/stone_crusher/examine(mob/user, distance)
	..(user, distance)
	if (distance > 2)
		return
	if (arrastra_mercury() >= 1)
		to_chat(user, SPAN_NOTICE("Quicksilver lies in its trough ([round(arrastra_mercury(), 0.1)] units): it is charged as an arrastra. Work crushed ore in it to make amalgam."))
	else
		to_chat(user, SPAN_NOTICE("Pour quicksilver and water into its trough to work crushed ore into amalgam, as an arrastra."))
	station_water_examine(user)

/obj/structure/stone_crusher/attackby(obj/item/W, mob/living/human/H)
	if (!istype(H))
		return ..()
	var/obj/item/weapon/reagent_containers/C = W
	if (istype(C) && C.is_open_container() && C.reagents && C.reagents.get_reagent_amount("mercury") > 0)
		if (!crafting_node_allowed_or_warn(H, "amalgamation"))
			return
		var/amount = min(reagents.get_free_space(), C.reagents.get_reagent_amount("mercury"))
		if (amount <= 0)
			to_chat(H, SPAN_NOTICE("The trough holds all the quicksilver it can."))
			return
		C.reagents.remove_reagent("mercury", amount)
		reagents.add_reagent("mercury", amount)
		arrastra_update_overlay()
		to_chat(H, SPAN_NOTICE("You pour [amount] units of quicksilver into the trough of \the [src]."))
		return
	if (station_water_pour(W, H))
		return
	if (istype(W, /obj/item/stack/ore/crushed_ore))
		if (arrastra_mercury() < AMALGAM_WET_MERCURY)
			to_chat(H, SPAN_WARNING("Crushed ore is already crushed. Charge the trough with quicksilver and water to work it into amalgam."))
			return
		work_arrastra(W, H)
		return
	return ..()

/obj/structure/stone_crusher/proc/arrastra_time()
	return max(5, round(ARRASTRA_TIME * mechanical_drive_factor(src)))

/obj/structure/stone_crusher/proc/work_arrastra(obj/item/stack/ore/crushed_ore/C, mob/living/human/H)
	if (!anchored)
		to_chat(H, SPAN_WARNING("Anchor \the [src] before working it."))
		return 0
	if (arrastra_busy)
		to_chat(H, SPAN_WARNING("Someone is working \the [src]."))
		return 0
	if (!crafting_node_allowed_or_warn(H, "amalgamation"))
		return 0
	arrastra_busy = TRUE
	visible_message(SPAN_NOTICE("[H] starts working crushed ore through the quicksilver in \the [src]."))
	var/loads = 0
	var/made = 0
	var/turf/T = get_turf(src)
	while (!QDELETED(C) && C.amount > 0 && C.loc == H && get_dist(H, src) <= 1 && anchored)
		if (arrastra_mercury() < AMALGAM_WET_MERCURY)
			to_chat(H, SPAN_WARNING("The quicksilver in the trough is spent."))
			break
		if (!station_has_water(user = H))
			break
		if (!do_after(H, arrastra_time(), src) || QDELETED(C) || C.amount < 1 || QDELETED(src))
			break
		if (!station_take_water(H))
			break
		var/metal = C.metal_type
		C.use(1)
		loads++
		reagents.remove_reagent("mercury", ARRASTRA_LOSS)
		river_mercury_spill(T, ARRASTRA_LOSS)
		if (prob(LODE_METAL * ARRASTRA_RECOVERY * 100) && arrastra_mercury() >= AMALGAM_WET_MERCURY)
			reagents.remove_reagent("mercury", AMALGAM_WET_MERCURY)
			spawn_stack(amalgam_type_for(metal), T, 1)
			made++
		spawn_stack(/obj/item/stack/ore/tailings/amalgam, T, 1)
	arrastra_busy = FALSE
	if (!QDELETED(src))
		arrastra_update_overlay()
	if (loads)
		to_chat(H, SPAN_NOTICE("You work [loads] load\s of crushed ore and make [made] lump\s of amalgam."))
	return loads

//////////////////////////////////////////////////////////////////////////////
// Amalgam press

/obj/structure/workshop_machine/amalgam_press
	name = "amalgam press"
	desc = "A cast-iron pot with a heavy screw over it, standing in a catch tray. Use wet amalgam on it to squeeze the free quicksilver out into the tray, then draw it off with a flask or any open vessel. Pressed amalgam needs less firing in the retort."
	icon = 'icons/obj/amalgam.dmi'
	icon_state = "amalgam_press"
	density = FALSE

/obj/structure/workshop_machine/amalgam_press/New()
	..()
	if (!reagents)
		create_reagents(40)

/obj/structure/workshop_machine/amalgam_press/examine(mob/user, distance)
	..(user, distance)
	if (distance <= 2)
		to_chat(user, SPAN_NOTICE("Its tray holds [reagents ? round(reagents.total_volume, 0.1) : 0] units of quicksilver."))

/obj/structure/workshop_machine/amalgam_press/attackby(obj/item/I, mob/living/human/H)
	if (!istype(H))
		return
	if (handle_machine_tool(I, H))
		return
	if (busy)
		to_chat(H, SPAN_WARNING("Someone is working \the [src]."))
		return
	var/obj/item/stack/ore/amalgam/A = I
	if (istype(A))
		press_amalgam(A, H)
		return
	if (istype(I, /obj/item/weapon/reagent_containers) && I.is_open_container())
		var/obj/item/weapon/reagent_containers/C = I
		if (!reagents || reagents.total_volume <= 0)
			to_chat(H, SPAN_NOTICE("The tray is empty."))
			return
		var/moved = reagents.trans_to_obj(C, C.amount_per_transfer_from_this)
		if (moved > 0)
			to_chat(H, SPAN_NOTICE("You draw [moved] units of quicksilver into \the [C]."))
		else
			to_chat(H, SPAN_WARNING("\The [C] is full."))
		return
	return ..()

/obj/structure/workshop_machine/amalgam_press/proc/press_amalgam(obj/item/stack/ore/amalgam/A, mob/living/human/H)
	if (!A.pressed_type)
		to_chat(H, SPAN_NOTICE("That amalgam is already pressed. Fire it in a mercury retort."))
		return
	if (!anchored)
		to_chat(H, SPAN_WARNING("Fasten \the [src] down with a wrench first."))
		return
	if (!crafting_node_allowed_or_warn(H, "amalgamation"))
		return
	var/squeezed = A.mercury_units - AMALGAM_HARD_MERCURY
	var/lumps = min(A.amount, round(reagents.get_free_space() / squeezed))
	if (lumps <= 0)
		to_chat(H, SPAN_WARNING("The tray is full: draw off the quicksilver first."))
		return
	busy = TRUE
	var/done = do_after(H, PRESS_TIME * lumps, src) && worker_ready(H, A)
	busy = FALSE
	if (!done)
		return
	lumps = min(lumps, A.amount)
	var/pressed = A.pressed_type
	A.use(lumps)
	spawn_stack(pressed, get_turf(src), lumps)
	reagents.add_reagent("mercury", squeezed * lumps)
	to_chat(H, SPAN_NOTICE("You screw down the press: [squeezed * lumps] units of quicksilver run into the tray."))

//////////////////////////////////////////////////////////////////////////////
// The retort takes amalgam too

/obj/structure/workshop_machine/mercury_retort/var/list/amalgam_load = null
/obj/structure/workshop_machine/mercury_retort/var/amalgam_mercury = 0

/obj/structure/workshop_machine/mercury_retort/proc/amalgam_lumps()
	. = 0
	for (var/path in amalgam_load)
		. += amalgam_load[path]

/obj/structure/workshop_machine/mercury_retort/retort_contents()
	. = ..()
	var/lumps = amalgam_lumps()
	if (lumps)
		. += " and [lumps] lump\s of amalgam"

/obj/structure/workshop_machine/mercury_retort/retort_charge()
	return ..() + amalgam_lumps()

/obj/structure/workshop_machine/mercury_retort/retort_empty(mob/living/human/H)
	. = ..()
	. += round(amalgam_mercury * AMALGAM_RETORT_RETURN, 0.1)
	for (var/path in amalgam_load)
		spawn_stack(path, get_turf(src), amalgam_load[path])
	if (amalgam_load && amalgam_load.len)
		to_chat(H, SPAN_NOTICE("Sponge metal is left in the pot."))
	amalgam_load = null
	amalgam_mercury = 0

/obj/structure/workshop_machine/mercury_retort/attackby(obj/item/I, mob/living/human/H)
	var/obj/item/stack/ore/amalgam/A = I
	if (istype(A) && istype(H) && !busy)
		load_amalgam(A, H)
		return
	return ..()

/obj/structure/workshop_machine/mercury_retort/proc/load_amalgam(obj/item/stack/ore/amalgam/A, mob/living/human/H)
	var/room = min(RETORT_CAPACITY - retort_charge(), round((reagents.get_free_space() - amalgam_mercury - cinnabar * MERCURY_RETORT_UNITS) / A.mercury_units))
	if (room <= 0)
		to_chat(H, SPAN_WARNING("\The [src] is full, or its receiver is: draw off the quicksilver first."))
		return
	var/moved = min(room, A.amount)
	var/sponge = A.sponge_type
	var/units = A.mercury_units
	A.use(moved)
	if (!amalgam_load)
		amalgam_load = list()
	amalgam_load[sponge] = (amalgam_load[sponge] || 0) + moved
	amalgam_mercury += units * moved
	to_chat(H, SPAN_NOTICE("You charge \the [src] with [moved] lump\s of amalgam ([retort_charge()]/[RETORT_CAPACITY])."))

//////////////////////////////////////////////////////////////////////////////
// Patio heap: crushed silver ore, quicksilver, salt and copper ore, turned
// in the open sun until the silver is amalgam (Medina's patio, 1554).

/obj/structure/patio_heap
	name = "patio"
	desc = "A flagstoned yard under the open sky for the patio process. Spread 20 loads of crushed silver ore on it, pour on 20 units of quicksilver and 10 units of salt, add one copper ore, then turn the heap six times. Most of the silver comes out as amalgam; a good deal of quicksilver is lost to the ground, and to the river if there is one beside it."
	icon = 'icons/obj/amalgam.dmi'
	icon_state = "patio_heap_1"
	anchored = TRUE
	density = FALSE
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = FALSE
	layer = 2.1
	var/loads = 0
	var/copper = 0
	var/turns = 0
	var/tmp/turning = FALSE

/obj/structure/patio_heap/persistence_runtime_var(key)
	return key == "turning" || ..()

/obj/structure/patio_heap/New()
	..()
	if (!reagents)
		create_reagents(PATIO_MERCURY + PATIO_SALT)
	update_icon()

/obj/structure/patio_heap/update_icon()
	icon_state = turns >= 5 ? "patio_heap_3" : (turns >= 2 ? "patio_heap_2" : "patio_heap_1")

/obj/structure/patio_heap/proc/charged()
	return loads >= PATIO_LOADS && copper >= 1 && reagents.get_reagent_amount("mercury") >= PATIO_MERCURY && reagents.get_reagent_amount("sodiumchloride") >= PATIO_SALT

/obj/structure/patio_heap/examine(mob/user, distance)
	..(user, distance)
	if (distance > 2)
		return
	to_chat(user, SPAN_NOTICE("It holds [loads]/[PATIO_LOADS] loads of crushed silver ore, [round(reagents.get_reagent_amount("mercury"), 0.1)]/[PATIO_MERCURY] units of quicksilver, [round(reagents.get_reagent_amount("sodiumchloride"), 0.1)]/[PATIO_SALT] units of salt and [copper]/1 copper ore. It has been turned [turns]/[PATIO_TURNS] times."))

/obj/structure/patio_heap/attackby(obj/item/I, mob/living/human/H)
	if (!istype(H))
		return ..()
	if (is_tool(I, TOOL_HAMMER) && H.a_intent == I_HARM)
		return ..()
	if (turning)
		to_chat(H, SPAN_WARNING("Someone is turning the heap."))
		return
	if (turns > 0 && !is_tool(I, TOOL_SHOVEL))
		to_chat(H, SPAN_NOTICE("The heap is being worked. Turn it with a shovel or your hands until it is done."))
		return
	if (istype(I, /obj/item/stack/ore/crushed_ore/silver))
		var/obj/item/stack/S = I
		var/moved = min(PATIO_LOADS - loads, S.amount)
		if (moved <= 0)
			to_chat(H, SPAN_NOTICE("The patio holds all the ore it can."))
			return
		S.use(moved)
		loads += moved
		to_chat(H, SPAN_NOTICE("You spread [moved] load\s of crushed silver ore on the patio ([loads]/[PATIO_LOADS])."))
		return
	if (istype(I, /obj/item/stack/ore/copper))
		if (copper >= 1)
			to_chat(H, SPAN_NOTICE("The heap already has its copper."))
			return
		var/obj/item/stack/S = I
		S.use(1)
		copper = 1
		to_chat(H, SPAN_NOTICE("You crumble a copper ore into the heap."))
		return
	var/obj/item/weapon/reagent_containers/C = I
	if (istype(C) && C.is_open_container() && C.reagents)
		var/poured = 0
		for (var/id in list("mercury", "sodiumchloride"))
			var/want = (id == "mercury" ? PATIO_MERCURY : PATIO_SALT) - reagents.get_reagent_amount(id)
			var/amount = min(want, C.reagents.get_reagent_amount(id))
			if (amount > 0)
				C.reagents.remove_reagent(id, amount)
				reagents.add_reagent(id, amount)
				poured += amount
		if (poured)
			to_chat(H, SPAN_NOTICE("You pour [poured] units into the heap."))
		else
			to_chat(H, SPAN_NOTICE("The heap needs no more of what is in \the [C]."))
		return
	if (is_tool(I, TOOL_SHOVEL))
		turn_heap(H)
		return
	return ..()

/obj/structure/patio_heap/attack_hand(mob/living/human/H)
	if (istype(H) && charged())
		turn_heap(H)
		return
	return ..()

// A horse, ox or mule beside the heap treads it in half the time.
/obj/structure/patio_heap/proc/turn_time()
	for (var/mob/living/simple_animal/A in range(1, src))
		if (A.stat != DEAD && (findtext("[A.type]", "horse") || findtext("[A.type]", "cow") || findtext("[A.type]", "ox") || findtext("[A.type]", "mule")))
			return PATIO_TURN_TIME / 2
	return PATIO_TURN_TIME

/obj/structure/patio_heap/proc/turn_heap(mob/living/human/H)
	if (turning)
		to_chat(H, SPAN_WARNING("Someone is turning the heap."))
		return
	if (!charged())
		to_chat(H, SPAN_WARNING("The heap is not charged yet. Examine it to see what it still needs."))
		return
	if (!signal_fire_open_sky(src))
		to_chat(H, SPAN_WARNING("The patio process needs the open sun. This yard is under a roof."))
		return
	if (!crafting_node_allowed_or_warn(H, "amalgamation"))
		return
	turning = TRUE
	H.visible_message(SPAN_NOTICE("[H] starts turning the patio heap."), SPAN_NOTICE("You start turning the heap."))
	var/done = do_after(H, turn_time(), src) && !QDELETED(src) && charged()
	turning = FALSE
	if (!done)
		return
	turns++
	update_icon()
	if (turns < PATIO_TURNS)
		to_chat(H, SPAN_NOTICE("You turn the heap ([turns]/[PATIO_TURNS]). It is darkening as the quicksilver takes up the silver."))
		return
	finish(H)

/obj/structure/patio_heap/proc/finish(mob/living/human/H)
	var/turf/T = get_turf(src)
	var/made = round(loads * LODE_METAL * PATIO_RECOVERY)
	var/mercury = reagents.get_reagent_amount("mercury")
	var/lost = max(0, mercury - made * AMALGAM_WET_MERCURY)
	if (made)
		spawn_stack(/obj/item/stack/ore/amalgam/silver, T, made)
	spawn_stack(/obj/item/stack/ore/tailings/amalgam, T, loads)
	river_mercury_spill(T, lost)
	reagents.clear_reagents()
	loads = 0
	copper = 0
	turns = 0
	update_icon()
	to_chat(H, SPAN_NOTICE("The heap is worked out: you wash out [made] lump\s of silver amalgam. [round(lost, 0.1)] units of quicksilver are lost into the yard."))

#undef ARRASTRA_TIME
#undef ARRASTRA_WATER
#undef PATIO_TURN_TIME
#undef PRESS_TIME
