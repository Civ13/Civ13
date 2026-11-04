// Machine ports for smelting and wood (phase 2b of
// docs/factory-automation-design.md). Bloomeries and blast furnaces take iron
// ore and fuel from automation and start a smelt once both are loaded; the
// powered saw mill keeps a small log hopper and cuts one log a second while
// powered. Both leave their output on their own tile, where arms can take it.
// Hand use of these machines is unchanged.

#define FACTORY_FURNACE_LIMIT 50 // ore units, and fuel units, a furnace takes from automation
#define FACTORY_MILL_HOPPER 20 // logs a powered saw mill holds for automation
#define FACTORY_MILL_PLANKS 12 // planks per log, as when a person runs the powered mill
#define FACTORY_OUTPUT_LIMIT 12 // loose items a machine leaves on its tile before it waits

var/global/list/factory_active_mills = list()

// Fuel value of one unit of a stack, as the furnaces count it by hand.
/proc/factory_fuel_value(obj/item/I)
	if (istype(I, /obj/item/stack/material/wood) || istype(I, /obj/item/stack/material/bamboo) || istype(I, /obj/item/stack/material/woodplank))
		return 1
	if (istype(I, /obj/item/stack/ore/charcoal))
		return 2.5
	if (istype(I, /obj/item/stack/ore/coal))
		return 3
	return 0

/proc/factory_loose_items(turf/T)
	var/count = 0
	for (var/obj/item/I in T)
		count++
	return count

// Take amount units of a stack for a machine's own counter. Returns the units taken.
/proc/factory_consume_units(obj/item/stack/S, amount)
	amount = min(amount, S.amount)
	if (amount <= 0)
		return 0
	S.amount -= amount
	if (S.amount <= 0)
		qdel(S)
	else
		S.update_icon()
	return amount

// The first stack of one of types lying on the machine's own tile.
/proc/factory_offer_tile_output(atom/A, list/types, filter_type)
	var/turf/T = get_turf(A)
	if (!T)
		return null
	for (var/obj/item/stack/S in T)
		if (filter_type && !istype(S, filter_type))
			continue
		var/wanted = FALSE
		for (var/type in types)
			if (istype(S, type))
				wanted = TRUE
				break
		if (wanted && factory_movable_item(S))
			return S
	return null

/proc/factory_take_tile_output(atom/A, obj/item/I, atom/destination)
	if (!destination || I.loc != get_turf(A) || !factory_movable_item(I))
		return FALSE
	I.forceMove(destination)
	return I.loc == destination

//////////////////////////////////////////////////////////////////////////////
// Bloomery and blast furnace. Clay kilns work with molds and stay manual.

/obj/structure/furnace/proc/factory_port_ready()
	return anchored && !istype(src, /obj/structure/furnace/kiln)

/obj/structure/furnace/proc/factory_output_types()
	if (istype(src, /obj/structure/furnace/blast_furnace))
		return list(/obj/item/stack/ore/iron_pig)
	return list(/obj/item/stack/ore/iron_sponge)

/obj/structure/furnace/factory_accepts(obj/item/I, from_dir = 0)
	if (!factory_port_ready() || !factory_movable_item(I) || !istype(I, /obj/item/stack))
		return 0
	var/obj/item/stack/S = I
	if (istype(S, /obj/item/stack/ore/iron))
		return max(0, min(S.amount, FACTORY_FURNACE_LIMIT - iron))
	var/value = factory_fuel_value(S)
	if (value <= 0)
		return 0
	return max(0, min(S.amount, round((FACTORY_FURNACE_LIMIT - fuel) / value)))

/obj/structure/furnace/factory_insert(obj/item/I, from_dir = 0)
	var/amount = factory_accepts(I, from_dir)
	if (amount <= 0)
		return 0
	var/obj/item/stack/S = I
	if (istype(S, /obj/item/stack/ore/iron))
		iron += factory_consume_units(S, amount)
	else
		var/value = factory_fuel_value(S)
		record_wood_fuel(S, amount * value)
		fuel += factory_consume_units(S, amount) * value
	factory_try_start()
	return amount

// Automation starts a smelt as soon as ore and enough fuel are loaded.
/obj/structure/furnace/proc/factory_try_start()
	if (!on && iron > 0 && fuel > 1)
		start_smelt()

/obj/structure/furnace/factory_offer(to_dir = 0, filter_type = null)
	if (!factory_port_ready())
		return null
	return factory_offer_tile_output(src, factory_output_types(), filter_type)

/obj/structure/furnace/factory_take(obj/item/I, atom/destination)
	return factory_take_tile_output(src, I, destination)

//////////////////////////////////////////////////////////////////////////////
// Powered saw mill.

/obj/structure/sawmill/powered/var/factory_logs = 0

/obj/structure/sawmill/powered/proc/factory_log_ok(obj/item/I)
	if (!istype(I, /obj/item/stack/material/wood) || !factory_movable_item(I))
		return FALSE
	var/obj/item/stack/material/wood/W = I
	return W.default_type == "wood" && W.material && W.material.name == "wood" && !W.onfire

/obj/structure/sawmill/powered/factory_accepts(obj/item/I, from_dir = 0)
	if (!anchored || !factory_log_ok(I))
		return 0
	var/obj/item/stack/S = I
	return max(0, min(S.amount, FACTORY_MILL_HOPPER - factory_logs))

/obj/structure/sawmill/powered/factory_insert(obj/item/I, from_dir = 0)
	var/amount = factory_accepts(I, from_dir)
	if (amount <= 0)
		return 0
	factory_logs += factory_consume_units(I, amount)
	factory_active_mills |= src
	return amount

/obj/structure/sawmill/powered/factory_offer(to_dir = 0, filter_type = null)
	return factory_offer_tile_output(src, list(/obj/item/stack/material/woodplank), filter_type)

/obj/structure/sawmill/powered/factory_take(obj/item/I, atom/destination)
	return factory_take_tile_output(src, I, destination)

/obj/structure/sawmill/powered/examine(mob/user, distance)
	..(user, distance)
	if (factory_logs)
		to_chat(user, SPAN_NOTICE("Its feed hopper holds [factory_logs] log\s."))

/obj/structure/sawmill/powered/after_load()
	. = ..()
	factory_logs = clamp(round(factory_logs), 0, FACTORY_MILL_HOPPER)
	if (factory_logs)
		factory_active_mills |= src

/obj/structure/sawmill/powered/Destroy()
	factory_active_mills -= src
	if (factory_logs > 0 && isturf(loc))
		new /obj/item/stack/material/wood(loc, factory_logs)
	factory_logs = 0
	return ..()

// Cut one log from the hopper while anchored, powered and not cutting by hand.
/obj/structure/sawmill/powered/proc/factory_cut()
	if (factory_logs <= 0 || !isturf(loc))
		factory_active_mills -= src
		return
	if (!anchored || current_work || !check_power())
		return
	var/turf/T = get_turf(src)
	var/obj/item/stack/material/woodplank/target = null
	for (var/obj/item/stack/material/woodplank/P in T)
		if (P.type == /obj/item/stack/material/woodplank && !P.color && P.amount + FACTORY_MILL_PLANKS <= P.max_amount)
			target = P
			break
	if (!target && factory_loose_items(T) >= FACTORY_OUTPUT_LIMIT)
		return
	factory_logs--
	if (target)
		target.amount += FACTORY_MILL_PLANKS
		target.update_icon()
	else
		new /obj/item/stack/material/woodplank(T, FACTORY_MILL_PLANKS, FALSE)
	if (factory_logs <= 0)
		factory_active_mills -= src

/proc/factory_mills_step()
	for (var/obj/structure/sawmill/powered/M in factory_active_mills.Copy())
		if (QDELETED(M))
			factory_active_mills -= M
			continue
		M.factory_cut()

#undef FACTORY_FURNACE_LIMIT
#undef FACTORY_MILL_HOPPER
#undef FACTORY_MILL_PLANKS
#undef FACTORY_OUTPUT_LIMIT
