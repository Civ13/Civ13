// Transfer arms and parts bins (phase 1 of docs/factory-automation-design.md).
//
// An arm takes one item from behind it and puts it in front of it, through the
// factory ports in factory_ports.dm: belts, crates, bins and machines, or loose
// floor items. It needs cable power and does nothing on its own while off.

#define FACTORY_ARM_FLOOR_LIMIT 12 // loose items an arm will pile on a bare floor tile

var/global/list/factory_active_arms = list()

/obj/structure/factory_arm
	name = "feeder arm"
	desc = "A powered swing arm. It lifts one item at a time from the tile behind it and sets it down on the tile in front: onto a belt, into a crate or machine, or onto the floor. Cable it, then switch it on. Turn it with a wrench while it is off."
	icon = 'icons/obj/modern_structures.dmi'
	icon_state = "loader0"
	anchored = TRUE
	density = TRUE
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = FALSE
	powerneeded = 2
	var/on = FALSE
	var/swing_time = 20 // deciseconds per transfer
	var/filter_type = null // only items of this type, when set
	var/can_filter = FALSE
	var/filter_optional = FALSE // a filterable arm that also runs with no filter
	var/batch = 1 // items of one kind lifted per swing
	var/tmp/next_swing = 0

/obj/structure/factory_arm/sorting
	name = "sorting arm"
	desc = "A powered swing arm that only moves one kind of item. Hit it with an item to set its filter; use the Clear Filter verb to reset it. Cable it, then switch it on. Turn it with a wrench while it is off."
	icon_state = "unloader0"
	powerneeded = 3
	can_filter = TRUE

// Lifts up to ten items of one kind each swing: every item of the kind it took
// first, or of its filter when one is set.
/obj/structure/factory_arm/stack
	name = "stack arm"
	desc = "A heavy powered swing arm that moves up to ten items of one kind each swing. Hit it with an item to make it move only that kind; use the Clear Filter verb to let it move anything. Cable it, then switch it on. Turn it with a wrench while it is off."
	icon_state = "unloader0"
	color = "#9fc7ff"
	powerneeded = 5
	can_filter = TRUE
	filter_optional = TRUE
	batch = 10

/obj/structure/factory_arm/New()
	..()
	update_icon()
	if (on)
		arm_wake()

/obj/structure/factory_arm/Destroy()
	arm_sleep()
	if (powersource)
		powersource.update_power(-powerneeded, 1, src)
	for (var/obj/item/I in contents)
		I.forceMove(get_turf(src))
	return ..()

/obj/structure/factory_arm/persistence_runtime_var(key)
	if (key == "next_swing")
		return TRUE
	return ..()

// A saved running arm resumes; saved time never pays out a transfer.
/obj/structure/factory_arm/after_load()
	. = ..()
	next_swing = 0
	powered = FALSE
	if (on)
		arm_wake()
	update_icon()

/obj/structure/factory_arm/update_icon()
	var/base = can_filter ? "unloader" : "loader"
	icon_state = "[base][(on && powered) ? 1 : 0]"
	overlays.Cut()
	overlays += image(icon = 'icons/minimap_effects.dmi', icon_state = "map_arrow", dir = dir)

/obj/structure/factory_arm/set_dir(new_dir)
	. = ..()
	update_icon()

/obj/structure/factory_arm/examine(mob/user, distance)
	..(user, distance)
	to_chat(user, SPAN_NOTICE("It moves items [dir2text(dir)] and is [on ? "on" : "off"][on && !powered ? ", without power" : ""]."))
	if (can_filter)
		to_chat(user, SPAN_NOTICE(filter_type ? "It only moves [factory_filter_name(filter_type)]." : (filter_optional ? "It has no filter set and moves anything." : "It has no filter set and moves nothing.")))
	var/held_count = 0
	for (var/obj/item/I in contents)
		held_count++
	if (held_count)
		to_chat(user, SPAN_NOTICE("It is holding [held_count == 1 ? "\a [held_item()]" : "[held_count] items"]."))

/proc/factory_filter_name(type)
	var/atom/A = type
	return initial(A.name)

/obj/structure/factory_arm/proc/held_item()
	for (var/obj/item/I in contents)
		return I
	return null

/obj/structure/factory_arm/attack_hand(mob/user)
	if (!anchored)
		to_chat(user, SPAN_NOTICE("Fix \the [src] in place with a wrench first."))
		return
	on = !on
	next_swing = 0
	if (on)
		arm_wake()
	else
		arm_stop()
	update_icon()
	to_chat(user, SPAN_NOTICE("You switch \the [src] [on ? "on" : "off"]."))

/obj/structure/factory_arm/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/weapon/wrench))
		if (on)
			to_chat(user, SPAN_WARNING("Switch \the [src] off first."))
			return
		set_dir(turn(dir, -90))
		playsound(src, 'sound/items/Ratchet.ogg', 50, TRUE)
		to_chat(user, SPAN_NOTICE("You turn \the [src] to move items [dir2text(dir)]."))
		return
	if (istype(W, /obj/item/stack/cable_coil))
		connect_cable(user, W)
		return
	if (can_filter && !istype(W, /obj/item/weapon/hammer) && !istype(W, /obj/item/weapon/crowbar))
		filter_type = W.type
		to_chat(user, SPAN_NOTICE("\The [src] will now only move [factory_filter_name(filter_type)]."))
		return
	return ..()

/obj/structure/factory_arm/stack/verb/clear_stack_filter()
	set name = "Clear Filter"
	set category = null
	set src in oview(1)
	filter_type = null
	to_chat(usr, SPAN_NOTICE("You clear \the [src]'s filter."))

/obj/structure/factory_arm/sorting/verb/clear_filter()
	set name = "Clear Filter"
	set category = null
	set src in oview(1)
	filter_type = null
	to_chat(usr, SPAN_NOTICE("You clear \the [src]'s filter."))

/obj/structure/factory_arm/proc/arm_wake()
	if (!QDELETED(src))
		factory_active_arms |= src

/obj/structure/factory_arm/proc/arm_sleep()
	factory_active_arms -= src

/obj/structure/factory_arm/proc/arm_stop()
	arm_sleep()
	if (powersource)
		powersource.update_power(-powerneeded, 1, src)
	powered = FALSE

/obj/structure/factory_arm/proc/source_turf()
	return get_step(src, turn(dir, 180))

/obj/structure/factory_arm/proc/target_turf()
	return get_step(src, dir)

/obj/structure/factory_arm/proc/wanted(obj/item/I, kind = null)
	if (can_filter && !filter_type && !filter_optional)
		return FALSE
	if (kind && I.type != kind)
		return FALSE
	return !filter_type || istype(I, filter_type)

// Where an item would go in front: a port that takes it, else a clear floor.
/obj/structure/factory_arm/proc/find_target(obj/item/I)
	var/turf/T = target_turf()
	if (!T || T.density)
		return null
	for (var/obj/O in T)
		if (istype(O, /obj/item) || O == src)
			continue
		if (O.factory_accepts(I, turn(dir, 180)) > 0)
			return O
	var/loose = 0
	for (var/atom/movable/AM in T)
		if (AM.density)
			return null
		if (istype(AM, /obj/item))
			loose++
	return loose < FACTORY_ARM_FLOOR_LIMIT ? T : null

// Lift an item from behind into the arm. Ports come first, then loose items.
// kind limits it to one exact type, for the later lifts of a batch.
/obj/structure/factory_arm/proc/pick_up(kind = null)
	var/turf/T = source_turf()
	if (!T)
		return FALSE
	for (var/obj/O in T)
		if (istype(O, /obj/item) || istype(O, /obj/structure/factory_arm))
			continue
		var/obj/item/offered = O.factory_offer(dir, kind || filter_type)
		if (offered && wanted(offered, kind) && find_target(offered))
			return O.factory_take(offered, src)
	for (var/obj/item/I in T)
		if (!factory_belt_cargo_item(I) || !wanted(I, kind) || !find_target(I))
			continue
		I.forceMove(src)
		animate(I)
		I.pixel_x = 0
		I.pixel_y = 0
		return I.loc == src
	return FALSE

// Set the held item down in front. A partial insert keeps the rest held.
/obj/structure/factory_arm/proc/put_down(obj/item/I)
	var/atom/target = find_target(I)
	if (!target)
		return FALSE
	if (isturf(target))
		return I.forceMove(target)
	var/obj/O = target
	return O.factory_insert(I, turn(dir, 180)) > 0

/obj/structure/factory_arm/proc/arm_step()
	if (!on || !anchored || !isturf(loc))
		arm_stop()
		update_icon()
		return
	if (world.time < next_swing)
		return
	next_swing = world.time + swing_time
	var/was_powered = powered
	if (!draw_cable_power())
		powered = FALSE
		if (was_powered)
			update_icon()
		return
	powered = TRUE
	if (!was_powered)
		update_icon()
	if (!held_item())
		pick_up()
		var/obj/item/first = held_item()
		for (var/i in 2 to batch)
			if (!first || !pick_up(first.type))
				break
	// Set down everything held, stopping at the first item with nowhere to go.
	for (var/obj/item/held in contents)
		if (!put_down(held) || held.loc == src)
			break

/proc/factory_arms_step()
	for (var/obj/structure/factory_arm/A in factory_active_arms.Copy())
		if (QDELETED(A))
			factory_active_arms -= A
			continue
		A.arm_step()

//////////////////////////////////////////////////////////////////////////////
// Parts bin: a crate that only takes more of what it already holds, so an arm
// or belt feeding several bins sorts by itself.

/obj/structure/closet/crate/factory_bin
	name = "parts bin"
	desc = "A steel crate for a production line. Once it holds something it only accepts more of the same kind."

/obj/structure/closet/crate/factory_bin/factory_accepts(obj/item/I, from_dir = 0)
	for (var/obj/item/stored in contents)
		if (stored.type != I.type)
			return 0
		break
	return ..()

#undef FACTORY_ARM_FLOOR_LIMIT
