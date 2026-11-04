// Container ports for chemistry (phase 0 of docs/chemistry-automation-design.md).
// Barrels already ride factory belts and arms as ordinary items; these ports
// let the oil well, the refineries and internal combustion engines take and
// return them without a person, a barrel station fills or drains barrels
// against its own tank, and a reagent gate sorts barrels by what they hold.
// Hand use of every machine is unchanged.

#define FACTORY_STATION_VOLUME 1000 // units a barrel station's tank holds

// A barrel automation may hand to a reagent machine: real, loose and open.
/proc/factory_reagent_barrel(obj/item/I)
	if (!istype(I, /obj/item/weapon/reagent_containers/glass/barrel) || !factory_movable_item(I))
		return FALSE
	return I.reagents && I.is_open_container()

// A drained barrel waits on its machine's tile until an arm takes it. Only one
// waits at a time, so dense barrels never pile up.
/proc/factory_waiting_barrel(atom/A, obj/item/except = null)
	var/turf/T = get_turf(A)
	if (!T)
		return null
	for (var/obj/item/weapon/reagent_containers/glass/barrel/B in T)
		if (B != except && factory_movable_item(B))
			return B
	return null

//////////////////////////////////////////////////////////////////////////////
// Oil well: takes an empty or part-filled barrel when it has none, and offers
// its barrel back once the barrel is full.

/obj/structure/oilwell/factory_accepts(obj/item/I, from_dir = 0)
	if (work_barrel || !base || !isturf(loc) || !istype(I, /obj/item/weapon/reagent_containers/glass/barrel) || !factory_movable_item(I))
		return 0
	return I.reagents && I.reagents.get_free_space() > 0 ? 1 : 0

/obj/structure/oilwell/factory_insert(obj/item/I, from_dir = 0)
	if (factory_accepts(I, from_dir) <= 0)
		return 0
	I.forceMove(src)
	load_barrel(FALSE)
	return work_barrel == I ? 1 : 0

/obj/structure/oilwell/factory_offer(to_dir = 0, filter_type = null)
	if (!work_barrel || work_barrel.loc != src || !work_barrel.reagents || work_barrel.reagents.get_free_space() > 0)
		return null
	if (filter_type && !istype(work_barrel, filter_type))
		return null
	return work_barrel

/obj/structure/oilwell/factory_take(obj/item/I, atom/destination)
	if (!destination || I != work_barrel || I.loc != src)
		return FALSE
	stop_extraction()
	work_barrel = null
	I.forceMove(destination)
	return I.loc == destination

//////////////////////////////////////////////////////////////////////////////
// Refineries. A barrel holding feedstock is drained into the refinery and left
// on its tile; a barrel with no feedstock becomes the output barrel when there
// is none. A full output barrel is offered, and the refinery starts itself
// whenever it has feedstock, an output barrel with room and cable power.

// Feedstock units this barrel holds that the refinery could take.
/obj/structure/refinery/proc/factory_feed_amount(datum/reagents/R)
	return R.get_reagent_amount("petroleum")

/obj/structure/refinery/proc/factory_feed_room()
	return max(0, maxvolume - volume)

/obj/structure/refinery/proc/factory_has_feed()
	return volume >= 1

// Drain feedstock from R into the refinery's counters. Returns units taken.
/obj/structure/refinery/proc/factory_drain_feed(datum/reagents/R)
	var/amount = min(R.get_reagent_amount("petroleum"), factory_feed_room())
	if (amount <= 0)
		return 0
	R.remove_reagent("petroleum", amount)
	volume = min(maxvolume, volume + amount)
	return amount

/obj/structure/refinery/biofuel/factory_feed_amount(datum/reagents/R)
	return R.get_reagent_amount("olive_oil") + R.get_reagent_amount("fat_oil") + R.get_reagent_amount("ethanol")

/obj/structure/refinery/biofuel/factory_feed_room()
	return max(0, maxvolume - (volume_et + volume_di))

/obj/structure/refinery/biofuel/factory_has_feed()
	return (product == "ethanol" ? volume_et : volume_di) > 0

// Oils go to the biodiesel counter. Ethanol counts at its purity, as when a
// person pours it in.
/obj/structure/refinery/biofuel/factory_drain_feed(datum/reagents/R)
	var/taken = 0
	for (var/id in list("olive_oil", "fat_oil"))
		var/amount = min(R.get_reagent_amount(id), factory_feed_room())
		if (amount <= 0)
			continue
		R.remove_reagent(id, amount)
		volume_di += amount
		taken += amount
	var/ethanol = min(R.get_reagent_amount("ethanol"), factory_feed_room())
	if (ethanol > 0)
		var/strength = 0
		var/total = 0
		for (var/datum/reagent/ethanol/E in R.reagent_list)
			total += E.volume
			strength += E.volume * E.strength
		if (total > 0)
			strength = 1 - ((strength / total) / 100)
			R.remove_reagent("ethanol", ethanol)
			volume_et += ethanol * strength
			taken += ethanol
	return taken

/obj/structure/refinery/proc/factory_output_barrel()
	if (!length(barrel))
		return null
	var/obj/item/weapon/reagent_containers/glass/barrel/B = barrel[1]
	if (!B || QDELETED(B) || B.loc != src)
		barrel.Cut()
		return null
	return B

/obj/structure/refinery/factory_accepts(obj/item/I, from_dir = 0)
	if (!isturf(loc) || !factory_reagent_barrel(I))
		return 0
	var/datum/reagents/R = I.reagents
	if (factory_feed_amount(R) > 0)
		// Drained barrels wait on the tile; take more feed only with room for both.
		return factory_feed_room() > 0 && !factory_waiting_barrel(src) ? 1 : 0
	if (!factory_output_barrel() && R.get_free_space() > 0)
		return 1
	return 0

/obj/structure/refinery/factory_insert(obj/item/I, from_dir = 0)
	if (factory_accepts(I, from_dir) <= 0)
		return 0
	var/datum/reagents/R = I.reagents
	if (factory_feed_amount(R) > 0)
		factory_drain_feed(R)
		if (!factory_output_barrel() && !R.total_volume)
			barrel += I
			I.forceMove(src)
		else
			I.forceMove(get_turf(src))
	else
		barrel += I
		I.forceMove(src)
	factory_try_start()
	return 1

// Start as a person would by hand, but only when nothing is already scheduled.
/obj/structure/refinery/proc/factory_try_start()
	if (refine_scheduled || !isturf(loc))
		return FALSE
	var/obj/item/weapon/reagent_containers/glass/barrel/B = factory_output_barrel()
	if (!B || B.reagents.get_free_space() <= 0 || !factory_has_feed() || !powersource || !powersource.powered)
		return FALSE
	if (!draw_cable_power())
		return FALSE
	active = TRUE
	powered = TRUE
	power_on()
	return TRUE

/obj/structure/refinery/factory_offer(to_dir = 0, filter_type = null)
	var/obj/item/waiting = factory_waiting_barrel(src)
	if (waiting && (!filter_type || istype(waiting, filter_type)))
		return waiting
	var/obj/item/weapon/reagent_containers/glass/barrel/B = factory_output_barrel()
	if (B && B.reagents.get_free_space() <= 0 && (!filter_type || istype(B, filter_type)))
		return B
	return null

/obj/structure/refinery/factory_take(obj/item/I, atom/destination)
	if (!destination || !factory_movable_item(I))
		return FALSE
	if (I.loc == get_turf(src))
		I.forceMove(destination)
		return I.loc == destination
	if (I != factory_output_barrel() || I.reagents.get_free_space() > 0)
		return FALSE
	// A full barrel has already stopped the refine loop; release its power.
	barrel -= I
	active = FALSE
	powered = FALSE
	if (powersource)
		powersource.update_power(-powerneeded, 1, src)
	update_icon()
	I.forceMove(destination)
	return I.loc == destination

// The barrel list mirrors the barrel held inside; a refine loop never
// survives a save, so a refinery that was running loads stopped.
/obj/structure/refinery/persistence_runtime_var(key)
	if (key == "barrel" || key == "refine_scheduled")
		return TRUE
	return ..()

/obj/structure/refinery/after_load()
	. = ..()
	barrel = list()
	for (var/obj/item/weapon/reagent_containers/glass/barrel/B in contents)
		barrel += B
		break
	refine_scheduled = FALSE
	active = FALSE
	powered = FALSE
	update_icon()

/obj/structure/refinery/Destroy()
	for (var/obj/item/weapon/reagent_containers/glass/barrel/B in contents)
		B.forceMove(get_turf(src))
	barrel = list()
	return ..()

//////////////////////////////////////////////////////////////////////////////
// Internal combustion engines: a barrel of a fuel the engine burns tops up the
// engine's connected fuel tank and is left on the engine's tile to be taken
// away. Engines without a connected tank, or not secured, have no port.

/obj/structure/engine/internal/proc/factory_fuel_in(datum/reagents/R)
	var/total = 0
	for (var/F in fuels)
		total += R.get_reagent_amount(F)
	return total

/obj/structure/engine/internal/factory_accepts(obj/item/I, from_dir = 0)
	if (!anchored || !isturf(loc) || broken || !fueltank || I == fueltank || !factory_reagent_barrel(I))
		return 0
	if (!fueltank.reagents || fueltank.reagents.get_free_space() <= 0 || factory_waiting_barrel(src, fueltank))
		return 0
	return factory_fuel_in(I.reagents) > 0 ? 1 : 0

/obj/structure/engine/internal/factory_insert(obj/item/I, from_dir = 0)
	if (factory_accepts(I, from_dir) <= 0)
		return 0
	for (var/F in fuels)
		var/space = fueltank.reagents.get_free_space()
		if (space <= 0)
			break
		var/amount = min(space, I.reagents.get_reagent_amount(F))
		if (amount <= 0)
			continue
		var/data = I.reagents.get_data(F)
		I.reagents.remove_reagent(F, amount)
		fueltank.reagents.add_reagent(F, amount, data)
	I.forceMove(get_turf(src))
	return 1

/obj/structure/engine/internal/factory_offer(to_dir = 0, filter_type = null)
	if (!anchored)
		return null
	var/obj/item/waiting = factory_waiting_barrel(src, fueltank)
	if (waiting && (!filter_type || istype(waiting, filter_type)))
		return waiting
	return null

/obj/structure/engine/internal/factory_take(obj/item/I, atom/destination)
	if (!destination || I == fueltank || I.loc != get_turf(src) || !factory_movable_item(I))
		return FALSE
	I.forceMove(destination)
	return I.loc == destination

//////////////////////////////////////////////////////////////////////////////
// Barrel station: a fixed tank that fills barrels from automation or drains
// them into itself, one barrel at a time, then offers the barrel back. Its
// tank is held inert so mixed deliveries do not react while stored. People
// still use it like any large barrel.

/obj/structure/reagent_dispensers/largebarrel/factory_station
	name = "barrel station"
	desc = "A fixed steel tank with a barrel cradle. Secured with a wrench, it drains barrels that automation brings into its tank, or fills them from it, then hands each barrel back out. Use the Switch Station Mode verb to choose. Its tank is held inert."
	icon_state = "welding_tank"
	max_capacity = FACTORY_STATION_VOLUME
	anchored = FALSE
	not_disassemblable = FALSE
	var/station_fill = FALSE // FALSE drains barrels into the tank, TRUE fills them from it

/obj/structure/reagent_dispensers/largebarrel/factory_station/New()
	..()
	flags |= NOREACT

/obj/structure/reagent_dispensers/largebarrel/factory_station/proc/held_barrel()
	for (var/obj/item/weapon/reagent_containers/glass/barrel/B in contents)
		return B
	return null

/obj/structure/reagent_dispensers/largebarrel/factory_station/factory_accepts(obj/item/I, from_dir = 0)
	if (!anchored || locked || !isturf(loc) || held_barrel() || !factory_reagent_barrel(I))
		return 0
	if (station_fill)
		return reagents.total_volume > 0 && I.reagents.get_free_space() > 0 ? 1 : 0
	return I.reagents.total_volume > 0 && reagents.get_free_space() > 0 ? 1 : 0

/obj/structure/reagent_dispensers/largebarrel/factory_station/factory_insert(obj/item/I, from_dir = 0)
	if (factory_accepts(I, from_dir) <= 0)
		return 0
	I.forceMove(src)
	if (station_fill)
		reagents.trans_to_holder(I.reagents, I.reagents.get_free_space())
	else
		I.reagents.trans_to_holder(reagents, reagents.get_free_space())
	return 1

/obj/structure/reagent_dispensers/largebarrel/factory_station/factory_offer(to_dir = 0, filter_type = null)
	if (locked)
		return null
	var/obj/item/B = held_barrel()
	if (B && (!filter_type || istype(B, filter_type)))
		return B
	return null

/obj/structure/reagent_dispensers/largebarrel/factory_station/factory_take(obj/item/I, atom/destination)
	if (locked || !destination || I != held_barrel())
		return FALSE
	I.forceMove(destination)
	return I.loc == destination

/obj/structure/reagent_dispensers/largebarrel/factory_station/attack_hand(mob/user)
	var/obj/item/B = held_barrel()
	if (B && !locked)
		B.forceMove(get_turf(src))
		to_chat(user, SPAN_NOTICE("You take \the [B] out of \the [src]'s cradle."))
		return
	return ..()

/obj/structure/reagent_dispensers/largebarrel/factory_station/examine(mob/user, distance)
	..(user, distance)
	to_chat(user, SPAN_NOTICE("It is set to [station_fill ? "fill barrels from its tank" : "drain barrels into its tank"]."))

/obj/structure/reagent_dispensers/largebarrel/factory_station/verb/switch_station_mode()
	set name = "Switch Station Mode"
	set category = null
	set src in range(1)
	if (!isliving(usr) || locked)
		return
	station_fill = !station_fill
	to_chat(usr, SPAN_NOTICE("\The [src] will now [station_fill ? "fill barrels from its tank" : "drain barrels into its tank"]."))

/obj/structure/reagent_dispensers/largebarrel/factory_station/Destroy()
	for (var/obj/item/I in contents)
		I.forceMove(get_turf(src))
	return ..()

//////////////////////////////////////////////////////////////////////////////
// Reagent gate: a sorting gate that sends containers by what they hold. Its
// filter is the main reagent of the container held when it is set, or "empty"
// for an empty one. Items without reagents always go straight on.

/obj/structure/factory_belt/routing/gate/reagent
	name = "reagent gate"
	desc = "A sorting gate with a sampling probe. Containers whose main reagent matches its filter leave by the side, everything else goes straight on. Use the Set Gate Filter verb holding a container to choose the filter (an empty one sorts out empties), and a screwdriver to swap the side."
	assembly_type = /obj/item/factory_belt_assembly/gate/reagent
	var/filter_reagent = null

/obj/structure/factory_belt/routing/gate/reagent/proc/reagent_matches(obj/item/I)
	if (!filter_reagent || !I || !I.reagents)
		return FALSE
	if (filter_reagent == "empty")
		return I.reagents.total_volume <= 0
	return I.reagents.get_master_reagent_id() == filter_reagent

/obj/structure/factory_belt/routing/gate/reagent/export_dirs(obj/item/I)
	if (reagent_matches(I))
		return list(side_dir())
	return list(dir)

/obj/structure/factory_belt/routing/gate/reagent/proc/reagent_filter_name()
	if (filter_reagent == "empty")
		return "empty containers"
	var/datum/reagent/R = chemical_reagents_list[filter_reagent]
	return "containers mostly of [R ? R.name : filter_reagent]"

/obj/structure/factory_belt/routing/gate/reagent/examine(mob/user, distance)
	..(user, distance)
	if (filter_reagent)
		to_chat(user, SPAN_NOTICE("Its probe is set to [reagent_filter_name()]."))

/obj/structure/factory_belt/routing/gate/reagent/set_gate_filter()
	set name = "Set Gate Filter"
	set category = null
	set src in oview(1)
	var/mob/living/L = usr
	if (!istype(L) || L.incapacitated())
		return
	var/obj/item/held = L.get_active_hand()
	if (!held || !held.reagents)
		to_chat(L, SPAN_WARNING("Hold a container with the reagent the gate should sort out, or an empty one."))
		return
	filter_reagent = held.reagents.total_volume > 0 ? held.reagents.get_master_reagent_id() : "empty"
	to_chat(L, SPAN_NOTICE("\The [src] will now send [reagent_filter_name()] to the side."))

/obj/structure/factory_belt/routing/gate/reagent/clear_gate_filter()
	set name = "Clear Gate Filter"
	set category = null
	set src in oview(1)
	filter_type = null
	filter_reagent = null
	to_chat(usr, SPAN_NOTICE("You clear \the [src]'s filter."))

/obj/item/factory_belt_assembly/gate/reagent
	name = "reagent gate assembly"
	desc = "A folded reagent gate. Use it on an adjacent floor tile to lay it running away from you."
	belt_type = /obj/structure/factory_belt/routing/gate/reagent
	color = "#8ad0a0"

#undef FACTORY_STATION_VOLUME
