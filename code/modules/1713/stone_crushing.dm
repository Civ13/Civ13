// Stone crushing: surplus stone blocks become a small, chance-based yield of
// sand, ores and minerals. One stone is consumed per roll; most rolls leave
// only rubble, so mined deposits stay the main source of ore.

// Weights are per 10,000 rolls (100 = 1%). The era gates match trace
// sifting: iron and calamine (zinc) from the Bronze Age, coal/lead/saltpeter/sulphur from the
// Medieval age. Anything not unlocked in the current age stays rubble.
/proc/stone_crushing_table(age = 0, powered = FALSE)
	var/list/table = list(
		/obj/item/stack/ore/glass = 2000,
		/obj/item/stack/ore/copper = 300,
		/obj/item/stack/ore/tin = 250,
		/obj/item/stack/ore/silver = 60,
		/obj/item/stack/ore/gold = 30,
		/obj/item/stack/ore/diamond = 10,
	)
	if (age >= 1)
		table[/obj/item/stack/ore/iron] = 300
		table[/obj/item/stack/ore/zinc] = 150
	if (age >= 2)
		table[/obj/item/stack/ore/coal] = 200
		table[/obj/item/stack/ore/lead] = 150
		table[/obj/item/stack/ore/saltpeter] = 100
		table[/obj/item/stack/ore/sulphur] = 100
	// Mechanised stamping and washing recovers half again as much of every
	// ore and mineral; sand recovery rises from 20% to 25%.
	if (powered)
		for (var/ore_type in table)
			table[ore_type] = ore_type == /obj/item/stack/ore/glass ? 2500 : round(table[ore_type] * 1.5)
	return table

// Returns an output type, or null when the stone only crumbles to rubble.
/proc/roll_stone_crushing(list/table, roll = null)
	if (isnull(roll))
		roll = rand(1, 10000)
	for (var/ore_type in table)
		roll -= table[ore_type]
		if (roll <= 0)
			return ore_type
	return null

/proc/stone_crushing_age()
	return map ? map.ordinal_age : 0

/proc/is_crushable_stone(obj/item/I)
	return I && I.type == /obj/item/stack/material/stone

// Hand-worked edge-runner mill. Several people may work it at once.
/obj/structure/stone_crusher
	name = "stone crusher"
	desc = "A heavy stone wheel rolled around a trough. Use stone blocks on it to crush them one at a time; most crumble to rubble, but some yield sand, ore or a rare mineral. Output collects under the crusher."
	icon = 'icons/obj/structures.dmi'
	icon_state = "grindstone"
	anchored = TRUE
	density = TRUE
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = FALSE
	var/output_stack_limit = 12
	var/tmp/list/crushing_workers = list()

/obj/structure/stone_crusher/get_saved_vars()
	var/list/saved = ..()
	saved -= list("crushing_workers")
	return saved

/obj/structure/stone_crusher/examine(mob/user, distance)
	..(user, distance)
	to_chat(user, SPAN_NOTICE("Roughly one stone in five gives sand and, from the Medieval age, about one in seven gives ore; the rest is rubble. Clear the output before twelve stacks pile up."))

/obj/structure/stone_crusher/proc/crushing_wait(mob/living/human/H)
	return do_after(H, max(20, round(50 / H.getStatCoeff("strength"))), src)

/obj/structure/stone_crusher/proc/crushing_output_turf()
	return get_turf(src)

/obj/structure/stone_crusher/attackby(obj/item/W, mob/living/human/H)
	if (!is_crushable_stone(W) || !istype(H))
		return ..()
	crush_stones(H, W)

/obj/structure/stone_crusher/proc/crush_stones(mob/living/human/H, obj/item/stack/material/stone/S)
	if (!anchored)
		to_chat(H, SPAN_WARNING("Anchor \the [src] before working it."))
		return 0
	if (H in crushing_workers)
		return 0
	crushing_workers += H
	visible_message(SPAN_NOTICE("[H] starts crushing stones in \the [src]."), SPAN_NOTICE("You start crushing stones in \the [src]."))
	var/crushed = 0
	while (TRUE)
		if (H.stat || !anchored || QDELETED(S) || S.loc != H || S.amount < 1 || get_dist(H, src) > 1)
			break
		playsound(loc, 'sound/effects/pickaxe.ogg', 60, TRUE)
		if (!crushing_wait(H))
			break
		// Revalidate the same stack and actor after the wait, before paying.
		if (H.stat || !anchored || QDELETED(S) || S.loc != H || S.amount < 1 || get_dist(H, src) > 1)
			break
		if (!crush_one_stone(H, S))
			break
		crushed++
	crushing_workers -= H
	if (crushed)
		to_chat(H, SPAN_NOTICE("You stop after crushing [crushed] stone[crushed == 1 ? "" : "s"]."))
	return crushed

// Output space is checked before the stone is spent; a full tile refunds nothing because nothing was taken.
/obj/structure/stone_crusher/proc/crush_one_stone(mob/living/human/H, obj/item/stack/material/stone/S, roll = null)
	var/turf/T = crushing_output_turf()
	if (!T)
		return FALSE
	var/result = roll_stone_crushing(stone_crushing_table(stone_crushing_age(), FALSE), roll)
	if (result && !T.deposit_small_resource(result, 1, output_stack_limit))
		to_chat(H, SPAN_WARNING("Clear the output under \the [src] before crushing more stone."))
		return FALSE
	S.use(1)
	if (result)
		var/obj/item/stack/sample = result
		to_chat(H, SPAN_NOTICE("The stone breaks open: you find some [initial(sample.name)]."))
	return TRUE

// Powered stamp mill: load up to fifty stones and it crushes one every four
// seconds with better recovery, until the hopper is empty or output is full.
/obj/structure/drill/stamp_mill
	name = "powered stamp mill"
	desc = "Electric stamps pound loaded stone blocks and wash out sand, ore and minerals. Anchor it, connect 150 cable power and load up to fifty stone blocks. It crushes one stone every four seconds with better recovery than a hand crusher; clear its output before twelve stacks accumulate."
	ore_types = list()
	var/hopper_limit = 50
	var/crush_interval = 2 // process ticks of two seconds each

/obj/structure/drill/stamp_mill/proc/loaded_stone()
	for (var/obj/item/stack/material/stone/S in contents)
		if (S.type == /obj/item/stack/material/stone && S.amount > 0)
			return S
	return null

/obj/structure/drill/stamp_mill/proc/loaded_stone_amount()
	var/total = 0
	for (var/obj/item/stack/material/stone/S in contents)
		total += S.amount
	return total

/obj/structure/drill/stamp_mill/examine(mob/user, distance)
	..(user, distance)
	to_chat(user, SPAN_NOTICE("Its hopper holds [loaded_stone_amount()] of [hopper_limit] stone blocks."))

/obj/structure/drill/stamp_mill/attackby(obj/item/W, mob/living/human/H)
	if (is_crushable_stone(W))
		load_stone(H, W)
		return
	return ..()

/obj/structure/drill/stamp_mill/proc/load_stone(mob/living/human/H, obj/item/stack/material/stone/S)
	if (!istype(H) || S.loc != H || get_dist(src, H) > 1)
		return 0
	if (hopper_space() <= 0)
		to_chat(H, SPAN_WARNING("\The [src]'s hopper is full."))
		return 0
	var/moved = fill_hopper(S, S.amount, H)
	if (moved)
		to_chat(H, SPAN_NOTICE("You load [moved] stone block[moved == 1 ? "" : "s"] into \the [src]."))
	return moved

/obj/structure/drill/stamp_mill/proc/hopper_space()
	return max(0, hopper_limit - loaded_stone_amount())

// Move up to amount stone into the hopper. H is only passed for hand loading,
// which keeps the existing stack-use rules for a worker.
/obj/structure/drill/stamp_mill/proc/fill_hopper(obj/item/stack/material/stone/S, amount, mob/living/human/H = null)
	var/moved = min(hopper_space(), amount, S.amount)
	if (moved <= 0)
		return 0
	var/obj/item/stack/material/stone/hopper = loaded_stone()
	if (H)
		if (!S.use(moved))
			return 0
	else
		S.amount -= moved
		if (S.amount <= 0)
			qdel(S)
		else
			S.update_icon()
	if (hopper)
		hopper.amount += moved
	else
		new /obj/item/stack/material/stone(src, moved, FALSE)
	return moved

// Factory port: plain stone blocks fill the hopper. Nothing is offered;
// crushed output still lands on the mill's tile.
/obj/structure/drill/stamp_mill/factory_accepts(obj/item/I, from_dir = 0)
	if (!is_crushable_stone(I) || !factory_movable_item(I))
		return 0
	var/obj/item/stack/material/stone/S = I
	return min(S.amount, hopper_space())

/obj/structure/drill/stamp_mill/factory_insert(obj/item/I, from_dir = 0)
	var/amount = factory_accepts(I, from_dir)
	if (amount <= 0)
		return 0
	return fill_hopper(I, amount)

/obj/structure/drill/stamp_mill/verb/unload_stone()
	set name = "Unload Stamp Mill"
	set category = null
	set src in oview(1)
	stop_drilling()
	for (var/obj/item/I in contents)
		I.loc = loc

/obj/structure/drill/stamp_mill/attack_hand(mob/living/human/H)
	if (active)
		return ..()
	if (!anchored)
		to_chat(H, SPAN_NOTICE("Fix \the [src] in place with a wrench first."))
		return
	if (!loaded_stone())
		to_chat(H, SPAN_WARNING("Load stone blocks into \the [src] first."))
		return
	active = TRUE
	next_spawn = crush_interval
	production_due = 0
	if (!process_pending)
		process_machine()
	if (active)
		to_chat(H, "You power up \the [src].")

/obj/structure/drill/stamp_mill/proc/stamp_one_stone(roll = null)
	var/obj/item/stack/material/stone/S = loaded_stone()
	var/turf/T = get_turf(src)
	if (!S || !T)
		return FALSE
	var/result = roll_stone_crushing(stone_crushing_table(stone_crushing_age(), TRUE), roll)
	if (result && !T.deposit_small_resource(result, 1, output_stack_limit))
		return FALSE
	S.amount--
	if (S.amount <= 0)
		qdel(S)
	return TRUE

/obj/structure/drill/stamp_mill/process_machine()
	if (!active || process_pending)
		return
	if (!anchored || !isturf(loc))
		stop_drilling()
		return
	if (!loaded_stone())
		stop_drilling()
		visible_message(SPAN_NOTICE("\The [src] stops: its hopper is empty."))
		return
	if (!check_power())
		stop_drilling()
		visible_message(SPAN_WARNING("\The [src] stops: insufficient cable power."))
		return
	if (next_spawn <= 0)
		if (!stamp_one_stone())
			stop_drilling()
			visible_message(SPAN_WARNING("\The [src] stops: clear its output tile and restart it."))
			return
		next_spawn = crush_interval
	playsound(loc, 'sound/effects/pickaxe.ogg', 50, FALSE)
	update_icon()
	process_pending = TRUE
	spawn (2 SECONDS)
		process_pending = FALSE
		if (active)
			next_spawn--
			process_machine()

/obj/structure/drill/stamp_mill/Destroy()
	for (var/obj/item/I in contents)
		I.loc = loc
	return ..()
