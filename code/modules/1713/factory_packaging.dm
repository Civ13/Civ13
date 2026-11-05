// Chemistry automation phase 3: packaging. The bottler fills containers that
// belts bring it from its pipe network and hands them back full; the
// automatic tablet press takes calcium carbonate and aspirin from its pipes
// and presses the same aspirin tablets as the hand-run press, leaving them on
// its tile for arms. See docs/chemistry-automation-design.md.

#define FLUID_PRESS_BUFFER 40 // eight tablets' worth
#define FLUID_PRESS_OUTPUT_LIMIT 12 // loose items on its tile before it waits

//////////////////////////////////////////////////////////////////////////////
// Bottler: takes one open, empty or partly filled container at a time from
// automation, fills it with its filter reagent from the pipes, then offers it.

/obj/structure/fluid_bottler
	name = "bottler"
	desc = "A pipe-fed filling cradle. Belts and arms bring it open containers; it fills each with its one reagent from the pipe network and hands it back once full. Hold a filled container and use Set Bottler Reagent to choose that reagent."
	icon = 'icons/obj/chemical.dmi'
	icon_state = "dispenser"
	anchored = TRUE
	density = TRUE
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = FALSE
	var/filter_reagent = null

/obj/structure/fluid_bottler/New()
	..()
	fluid_mark_dirty()

/obj/structure/fluid_bottler/Destroy()
	var/obj/item/C = held_container()
	if (C && get_turf(src))
		C.forceMove(get_turf(src))
	fluid_mark_dirty()
	return ..()

/obj/structure/fluid_bottler/proc/held_container()
	for (var/obj/item/weapon/reagent_containers/C in contents)
		return C
	return null

// An open container holding nothing but the bottler's reagent, with room left.
/obj/structure/fluid_bottler/proc/fillable(obj/item/weapon/reagent_containers/C)
	if (!istype(C) || istype(C, /obj/item/weapon/reagent_containers/pill) || !C.reagents || !C.is_open_container())
		return FALSE
	if (C.reagents.get_free_space() <= 0)
		return FALSE
	for (var/datum/reagent/R in C.reagents.reagent_list)
		if (R.id != filter_reagent)
			return FALSE
	return TRUE

/obj/structure/fluid_bottler/proc/is_full(obj/item/weapon/reagent_containers/C)
	return C && C.reagents && C.reagents.get_free_space() <= 0.01

/obj/structure/fluid_bottler/factory_accepts(obj/item/I, from_dir = 0)
	if (!filter_reagent || !isturf(loc) || held_container())
		return 0
	return fillable(I) ? 1 : 0

/obj/structure/fluid_bottler/factory_insert(obj/item/I, from_dir = 0)
	if (factory_accepts(I, from_dir) <= 0)
		return 0
	I.forceMove(src)
	var/datum/fluid_network/N = fluid_network_of(src)
	if (N)
		N.idle_steps = 0
	return 1

// Full, or no longer fillable (its reagent was changed or it was closed), so a
// belt line never stalls on a container the bottler cannot finish.
/obj/structure/fluid_bottler/proc/releasable(obj/item/weapon/reagent_containers/C)
	return C && (is_full(C) || !fillable(C))

/obj/structure/fluid_bottler/factory_offer(to_dir = 0, filter_type = null)
	var/obj/item/weapon/reagent_containers/C = held_container()
	if (releasable(C) && (!filter_type || istype(C, filter_type)))
		return C
	return null

/obj/structure/fluid_bottler/factory_take(obj/item/I, atom/destination)
	if (!destination || I != held_container() || !releasable(I))
		return FALSE
	I.forceMove(destination)
	return I.loc == destination

/obj/structure/fluid_bottler/fluid_demand_tier()
	return anchored ? FLUID_TIER_SINK : 0

/obj/structure/fluid_bottler/fluid_demand(id)
	if (!filter_reagent || id != filter_reagent)
		return 0
	var/obj/item/weapon/reagent_containers/C = held_container()
	if (!C || !fillable(C))
		return 0
	return C.reagents.get_free_space()

/obj/structure/fluid_bottler/fluid_receive(id, amount, data)
	amount = min(amount, fluid_demand(id))
	if (amount <= 0)
		return 0
	var/obj/item/weapon/reagent_containers/C = held_container()
	return fluid_add_to(C.reagents, id, amount, data)

/obj/structure/fluid_bottler/attack_hand(mob/user)
	var/obj/item/C = held_container()
	if (!C)
		to_chat(user, SPAN_NOTICE("\The [src] holds no container."))
		return
	C.forceMove(get_turf(src))
	to_chat(user, SPAN_NOTICE("You take \the [C] out of \the [src]."))

/obj/structure/fluid_bottler/examine(mob/user, distance)
	..(user, distance)
	var/datum/reagent/R = filter_reagent ? chemical_reagents_list[filter_reagent] : null
	to_chat(user, SPAN_NOTICE(filter_reagent ? "It fills containers with [R ? R.name : filter_reagent]." : "No reagent is set."))
	var/obj/item/weapon/reagent_containers/C = held_container()
	if (C)
		to_chat(user, SPAN_NOTICE("It holds \a [C] with [round(C.reagents.total_volume)] of [C.reagents.maximum_volume] units."))

/obj/structure/fluid_bottler/verb/set_bottler_reagent()
	set name = "Set Bottler Reagent"
	set category = null
	set src in oview(1)
	var/mob/living/L = usr
	if (!istype(L) || L.incapacitated())
		return
	var/obj/item/held = L.get_active_hand()
	if (!held || !held.reagents || !held.reagents.total_volume)
		to_chat(L, SPAN_WARNING("Hold a filled container to choose the reagent \the [src] bottles."))
		return
	filter_reagent = held.reagents.get_master_reagent_id()
	var/datum/reagent/R = chemical_reagents_list[filter_reagent]
	to_chat(L, SPAN_NOTICE("\The [src] now fills containers with [R ? R.name : filter_reagent]."))

//////////////////////////////////////////////////////////////////////////////
// Automatic tablet press: pipe-fed and powered, it presses one aspirin tablet
// (one unit of calcium carbonate and four of aspirin) a step.

var/global/list/fluid_presses = list()
var/global/list/fluid_tablet_cost = list("calcium_carbonate" = 1, "aspirin" = 4)

/obj/structure/fluid_tablet_press
	name = "automatic tablet press"
	desc = "A powered press fed by pipes. It draws calcium carbonate and aspirin into an inert buffer and presses one aspirin tablet a step onto its tile for arms to take."
	icon = 'icons/obj/chemical.dmi'
	icon_state = "mixer0b"
	anchored = TRUE
	density = TRUE
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = FALSE
	flags = NOREACT
	powerneeded = 2

/obj/structure/fluid_tablet_press/New()
	..()
	create_reagents(FLUID_PRESS_BUFFER)
	fluid_presses |= src
	fluid_mark_dirty()

/obj/structure/fluid_tablet_press/Destroy()
	fluid_presses -= src
	press_release_power()
	fluid_mark_dirty()
	return ..()

/obj/structure/fluid_tablet_press/persistence_runtime_var(key)
	if (key == "powered")
		return TRUE
	return ..()

/obj/structure/fluid_tablet_press/after_load()
	. = ..()
	powered = FALSE
	fluid_presses |= src
	fluid_mark_dirty()

/obj/structure/fluid_tablet_press/proc/press_release_power()
	if (powersource)
		powersource.update_power(-powerneeded, 1, src)
	powered = FALSE

/obj/structure/fluid_tablet_press/proc/can_press()
	if (!isturf(loc) || !tablet_press_year_allowed())
		return FALSE
	for (var/id in fluid_tablet_cost)
		if (reagents.get_reagent_amount(id) < fluid_tablet_cost[id])
			return FALSE
	return factory_loose_items(loc) < FLUID_PRESS_OUTPUT_LIMIT

// Power is drawn only for a step that presses a tablet.
/obj/structure/fluid_tablet_press/proc/press_step()
	if (!can_press())
		if (powered)
			press_release_power()
		return FALSE
	powered = draw_cable_power() ? TRUE : FALSE
	if (!powered)
		return FALSE
	var/obj/item/weapon/reagent_containers/pill/product = new(loc)
	product.name = "aspirin tablet"
	for (var/id in fluid_tablet_cost)
		var/data = reagents.get_data(id)
		reagents.remove_reagent(id, fluid_tablet_cost[id])
		product.reagents.add_reagent(id, fluid_tablet_cost[id], data)
	return TRUE

/obj/structure/fluid_tablet_press/fluid_demand_tier()
	return anchored ? FLUID_TIER_SINK : 0

// Keep the buffer in the tablet ratio, so neither input can crowd out the other.
/obj/structure/fluid_tablet_press/fluid_demand(id)
	if (!(id in fluid_tablet_cost) || !tablet_press_year_allowed())
		return 0
	var/share = FLUID_PRESS_BUFFER * fluid_tablet_cost[id] / 5
	return max(0, share - reagents.get_reagent_amount(id))

/obj/structure/fluid_tablet_press/fluid_receive(id, amount, data)
	amount = min(amount, fluid_demand(id))
	if (amount <= 0)
		return 0
	return fluid_add_to(reagents, id, amount, data)

/obj/structure/fluid_tablet_press/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/stack/cable_coil))
		connect_cable(user, W)
		return
	return ..()

/obj/structure/fluid_tablet_press/examine(mob/user, distance)
	..(user, distance)
	to_chat(user, SPAN_NOTICE("Its buffer holds [round(reagents.get_reagent_amount("calcium_carbonate"), 0.1)] units of calcium carbonate and [round(reagents.get_reagent_amount("aspirin"), 0.1)] of aspirin."))
	if (!tablet_press_year_allowed())
		to_chat(user, SPAN_WARNING("Tablets cannot be pressed in this era."))

/proc/factory_presses_step()
	for (var/obj/structure/fluid_tablet_press/P in fluid_presses.Copy())
		if (QDELETED(P))
			fluid_presses -= P
			continue
		P.press_step()

#undef FLUID_PRESS_BUFFER
#undef FLUID_PRESS_OUTPUT_LIMIT
