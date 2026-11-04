// Pipe networks (phase 1 of docs/chemistry-automation-design.md).
//
// Pipes join machines into a network. Pipes hold no reagents: a network is
// only the list of machines next to its pipes. Every two seconds, while a
// powered pump is on the network, machines that want a reagent pull it from
// machines that offer it, one tier down: sources (oil wells, water intakes,
// refinery output, draining barrel stations) feed buffers (holding tanks) and
// sinks (refinery feed, engine fuel tanks, filling barrel stations); buffers
// feed sinks. Tanks never trade with tanks, so nothing sloshes back and forth.
// Transfers move one reagent at a time and keep its data. Storage is inert.

#define FLUID_STEP_INTERVAL 2 // factory process ticks (seconds) per network step
#define FLUID_PUMP_RATE 20 // units each powered pump moves per step on its network
#define FLUID_TANK_VOLUME 1000
#define FLUID_INTAKE_RATE 10 // units of water an intake draws per step
#define FLUID_NETWORK_LIMIT 600 // pipes walked into one network
#define FLUID_IDLE_RECHECK 5 // an idle network looks again every this many steps
#define FLUID_REBUILD_STEPS 30 // networks are rebuilt at least this often

#define FLUID_TIER_SOURCE 1
#define FLUID_TIER_BUFFER 2
#define FLUID_TIER_SINK 3

var/global/list/fluid_pipes = list()
var/global/list/fluid_pumps = list()
var/global/list/fluid_networks = list()
var/global/fluid_networks_dirty = TRUE
var/global/fluid_tick = 0
var/global/fluid_steps_since_rebuild = 0

/proc/fluid_mark_dirty()
	fluid_networks_dirty = TRUE

//////////////////////////////////////////////////////////////////////////////
// Machine roles. A machine offers reagents from fluid_supply_holder() at
// fluid_supply_tier(), and takes them through fluid_demand()/fluid_receive()
// at fluid_demand_tier(). Zero tiers mean no role.

/obj/proc/fluid_supply_tier()
	return 0

/obj/proc/fluid_demand_tier()
	return 0

/obj/proc/fluid_supply_holder()
	return null

// Whether this machine lets reagent id out through pipes.
/obj/proc/fluid_supplies(id)
	return TRUE

// Units of reagent id this machine would take now.
/obj/proc/fluid_demand(id)
	return 0

// Take amount units of reagent id. Returns the units taken.
/obj/proc/fluid_receive(id, amount, data)
	return 0

/proc/fluid_add_to(datum/reagents/R, id, amount, data)
	if (!R || amount <= 0)
		return 0
	amount = min(amount, R.get_free_space())
	if (amount <= 0)
		return 0
	R.add_reagent(id, amount, data)
	return amount

//////////////////////////////////////////////////////////////////////////////
// Networks.

/datum/fluid_network
	var/list/pipes = list()
	var/list/members = list()
	var/idle_steps = 0
	var/rotation = 0
	var/last_moved = 0

/datum/fluid_network/proc/pumped_rate()
	var/rate = 0
	for (var/obj/structure/fluid_pump/P in members)
		if (P.on && P.powered && !QDELETED(P))
			rate += FLUID_PUMP_RATE
	return rate

/datum/fluid_network/proc/member_ok(obj/O)
	return O && !QDELETED(O) && isturf(O.loc)

// Move up to the pumped rate from lower-tier suppliers to higher-tier demanders.
/datum/fluid_network/proc/network_step()
	last_moved = 0
	var/budget = pumped_rate()
	if (budget <= 0)
		return 0
	var/list/suppliers = list()
	var/list/demanders = list()
	for (var/obj/O in members)
		if (!member_ok(O))
			continue
		if (O.fluid_supply_tier() && O.fluid_supply_holder())
			suppliers += O
		if (O.fluid_demand_tier())
			demanders += O
	if (!suppliers.len || !demanders.len)
		return 0
	// Rotate the starting supplier so equal sources share the work.
	rotation = (rotation % suppliers.len) + 1
	var/list/ordered = suppliers.Copy(rotation) + suppliers.Copy(1, rotation)
	for (var/tier in list(FLUID_TIER_SINK, FLUID_TIER_BUFFER))
		for (var/obj/D in demanders)
			if (D.fluid_demand_tier() != tier)
				continue
			for (var/obj/S in ordered)
				if (S == D || S.fluid_supply_tier() >= tier)
					continue
				var/datum/reagents/R = S.fluid_supply_holder()
				if (!R)
					continue
				for (var/datum/reagent/reagent in R.reagent_list.Copy())
					var/id = reagent.id
					if (!S.fluid_supplies(id))
						continue
					var/amount = min(budget, reagent.volume, D.fluid_demand(id))
					if (amount <= 0)
						continue
					var/data = R.get_data(id)
					R.remove_reagent(id, amount)
					var/taken = D.fluid_receive(id, amount, data)
					if (taken < amount)
						// Anything refused goes back where it came from.
						R.add_reagent(id, amount - taken, data)
					budget -= taken
					last_moved += taken
					if (budget <= 0)
						return last_moved
	return last_moved

/proc/fluid_pipe_neighbours(obj/structure/fluid_pipe/P)
	var/list/found = list()
	if (!P.fluid_open())
		return found
	for (var/d in cardinal)
		var/turf/T = get_step(P, d)
		if (!T)
			continue
		for (var/obj/structure/fluid_pipe/N in T)
			if (N.fluid_open() && !QDELETED(N))
				found += N
	return found

/proc/fluid_has_role(obj/O)
	return O.fluid_supply_tier() || O.fluid_demand_tier() || istype(O, /obj/structure/fluid_pump)

/proc/fluid_rebuild_networks()
	fluid_networks = list()
	fluid_networks_dirty = FALSE
	fluid_steps_since_rebuild = 0
	var/list/seen = list()
	for (var/obj/structure/fluid_pipe/P in fluid_pipes.Copy())
		if (QDELETED(P))
			fluid_pipes -= P
			continue
		P.network = null
	for (var/obj/structure/fluid_pipe/start in fluid_pipes)
		if (seen[start] || !isturf(start.loc) || !start.fluid_open())
			continue
		var/datum/fluid_network/N = new
		var/list/queue = list(start)
		seen[start] = TRUE
		while (queue.len && N.pipes.len < FLUID_NETWORK_LIMIT)
			var/obj/structure/fluid_pipe/P = queue[queue.len]
			queue.len--
			N.pipes += P
			P.network = N
			for (var/obj/structure/fluid_pipe/next in fluid_pipe_neighbours(P))
				if (!seen[next])
					seen[next] = TRUE
					queue += next
		for (var/obj/structure/fluid_pipe/P in N.pipes)
			for (var/turf/T in list(P.loc) + P.fluid_adjacent_turfs())
				for (var/obj/O in T)
					if (!istype(O, /obj/structure/fluid_pipe) && !istype(O, /obj/item) && fluid_has_role(O))
						N.members |= O
		fluid_networks += N
	for (var/obj/structure/fluid_pipe/P in fluid_pipes)
		P.update_icon()

/proc/fluid_network_of(obj/O)
	for (var/datum/fluid_network/N in fluid_networks)
		if (O in N.members)
			return N
	return null

// One network step: pumps draw power, then each awake network moves reagents.
/proc/factory_fluids_step()
	if (fluid_networks_dirty || ++fluid_steps_since_rebuild >= FLUID_REBUILD_STEPS)
		fluid_rebuild_networks()
	for (var/obj/structure/fluid_pump/P in fluid_pumps.Copy())
		if (QDELETED(P))
			fluid_pumps -= P
			continue
		P.pump_step()
	for (var/datum/fluid_network/N in fluid_networks)
		if (N.idle_steps && N.idle_steps % FLUID_IDLE_RECHECK)
			N.idle_steps++
			continue
		if (N.network_step() > 0)
			N.idle_steps = 0
		else
			N.idle_steps++

/proc/factory_fluids_tick()
	if (++fluid_tick < FLUID_STEP_INTERVAL)
		return
	fluid_tick = 0
	factory_fluids_step()

//////////////////////////////////////////////////////////////////////////////
// Pipes connect to every adjacent pipe and machine. A closed valve joins
// nothing, splitting the network in two.

/obj/structure/fluid_pipe
	name = "fluid pipe"
	desc = "A steel pipe. It joins with pipes and machines on every side. A network only moves liquids while a powered pump is connected to it."
	icon = 'icons/obj/machines/pipes.dmi'
	icon_state = "intact"
	anchored = TRUE
	density = FALSE
	layer = 2.8
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = FALSE
	var/tmp/datum/fluid_network/network = null

/obj/structure/fluid_pipe/New()
	..()
	fluid_pipes |= src
	fluid_mark_dirty()

/obj/structure/fluid_pipe/Destroy()
	fluid_pipes -= src
	network = null
	fluid_mark_dirty()
	for (var/obj/structure/fluid_pipe/P in orange(1, src))
		P.update_icon()
	return ..()

/obj/structure/fluid_pipe/Move()
	. = ..()
	fluid_mark_dirty()

// Networks are rebuilt after load; a saved reference would pin a stale datum.
/obj/structure/fluid_pipe/persistence_runtime_var(key)
	if (key == "network")
		return TRUE
	return ..()

/obj/structure/fluid_pipe/after_load()
	. = ..()
	fluid_pipes |= src
	fluid_mark_dirty()

/obj/structure/fluid_pipe/proc/fluid_open()
	return TRUE

/obj/structure/fluid_pipe/proc/fluid_adjacent_turfs()
	var/list/turfs = list()
	for (var/d in cardinal)
		var/turf/T = get_step(src, d)
		if (T)
			turfs += T
	return turfs

// The directions this pipe visibly joins: open pipes and machines.
/obj/structure/fluid_pipe/proc/joined_dirs()
	var/list/dirs = list()
	if (!fluid_open())
		return dirs
	for (var/d in cardinal)
		var/turf/T = get_step(src, d)
		if (!T)
			continue
		for (var/obj/O in T)
			if (istype(O, /obj/structure/fluid_pipe))
				var/obj/structure/fluid_pipe/P = O
				if (P.fluid_open())
					dirs |= d
					break
			else if (!istype(O, /obj/item) && fluid_has_role(O))
				dirs |= d
				break
	return dirs

/obj/structure/fluid_pipe/update_icon()
	overlays.Cut()
	var/list/dirs = joined_dirs()
	var/mask = 0
	for (var/d in dirs)
		mask |= d
	switch (dirs.len)
		if (0)
			icon_state = "intact"
			set_dir(NORTH)
		if (1)
			icon_state = "intact"
			set_dir((mask & (NORTH|SOUTH)) ? NORTH : EAST)
		if (2)
			icon_state = "intact"
			if (mask == (NORTH|SOUTH))
				set_dir(NORTH)
			else if (mask == (EAST|WEST))
				set_dir(EAST)
			else
				set_dir(mask)
		if (3)
			icon_state = "manifold"
			set_dir((NORTH|SOUTH|EAST|WEST) & ~mask)
		else
			icon_state = "manifold"
			set_dir(SOUTH)
			overlays += image(icon = icon, icon_state = "intact", dir = NORTH)

/obj/structure/fluid_pipe/examine(mob/user, distance)
	..(user, distance)
	if (network)
		to_chat(user, SPAN_NOTICE("Its network has [network.pipes.len] pipe\s and [network.members.len] connected machine\s[network.pumped_rate() ? ", and is pumping" : ", with no running pump"]."))

/obj/structure/fluid_pipe/valve
	name = "pipe valve"
	desc = "A steel pipe with a hand valve. Closed, it joins nothing and splits the network in two. Click it to open or close it."
	color = "#c08080"
	var/open = TRUE

/obj/structure/fluid_pipe/valve/New()
	..()
	color = open ? "#80c080" : "#c08080"

/obj/structure/fluid_pipe/valve/fluid_open()
	return open

/obj/structure/fluid_pipe/valve/after_load()
	. = ..()
	color = open ? "#80c080" : "#c08080"

/obj/structure/fluid_pipe/valve/attack_hand(mob/user)
	open = !open
	color = open ? "#80c080" : "#c08080"
	fluid_mark_dirty()
	to_chat(user, SPAN_NOTICE("You [open ? "open" : "close"] \the [src]."))

/obj/structure/fluid_pipe/valve/update_icon()
	..()
	if (!open)
		icon_state = "intact"

//////////////////////////////////////////////////////////////////////////////
// Pump: a network moves liquids only while a powered pump is next to one of
// its pipes. Each running pump adds FLUID_PUMP_RATE units a step.

/obj/structure/fluid_pump
	name = "fluid pump"
	desc = "An electric pump. Set next to a pipe and cabled, it moves liquids through that pipe network while switched on."
	icon = 'icons/obj/machines/pipes.dmi'
	icon_state = "compressor"
	anchored = TRUE
	density = TRUE
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = FALSE
	powerneeded = 3
	var/on = FALSE

/obj/structure/fluid_pump/New()
	..()
	fluid_pumps |= src
	fluid_mark_dirty()

/obj/structure/fluid_pump/Destroy()
	fluid_pumps -= src
	if (powersource)
		powersource.update_power(-powerneeded, 1, src)
	fluid_mark_dirty()
	return ..()

/obj/structure/fluid_pump/persistence_runtime_var(key)
	if (key == "powered")
		return TRUE
	return ..()

/obj/structure/fluid_pump/after_load()
	. = ..()
	powered = FALSE
	fluid_pumps |= src
	fluid_mark_dirty()

/obj/structure/fluid_pump/attack_hand(mob/user)
	on = !on
	if (!on)
		pump_stop()
	to_chat(user, SPAN_NOTICE("You switch \the [src] [on ? "on" : "off"]."))

/obj/structure/fluid_pump/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/stack/cable_coil))
		connect_cable(user, W)
		return
	return ..()

/obj/structure/fluid_pump/examine(mob/user, distance)
	..(user, distance)
	to_chat(user, SPAN_NOTICE("It is [on ? "on" : "off"][on && !powered ? ", without power" : ""]."))

/obj/structure/fluid_pump/proc/pump_stop()
	if (powersource)
		powersource.update_power(-powerneeded, 1, src)
	powered = FALSE

/obj/structure/fluid_pump/proc/pump_step()
	if (!on || !isturf(loc))
		if (powered)
			pump_stop()
		return
	var/was = powered
	powered = draw_cable_power() ? TRUE : FALSE
	if (powered && !was)
		// A network that went idle for lack of power wakes now.
		var/datum/fluid_network/N = fluid_network_of(src)
		if (N)
			N.idle_steps = 0

//////////////////////////////////////////////////////////////////////////////
// Holding tank: an inert buffer. With a filter set it holds one reagent only.

/obj/structure/fluid_tank
	name = "holding tank"
	desc = "A fixed steel tank for a pipe network. It fills from sources and feeds machines that want what it holds. Hold a container and use Set Tank Filter to keep it to one reagent. Its contents are held inert."
	icon = 'icons/obj/barrel.dmi'
	icon_state = "air"
	anchored = TRUE
	density = TRUE
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = FALSE
	flags = OPENCONTAINER | NOREACT
	var/filter_reagent = null

/obj/structure/fluid_tank/New()
	..()
	create_reagents(FLUID_TANK_VOLUME)
	fluid_mark_dirty()

/obj/structure/fluid_tank/Destroy()
	fluid_mark_dirty()
	return ..()

/obj/structure/fluid_tank/fluid_supply_tier()
	return FLUID_TIER_BUFFER

/obj/structure/fluid_tank/fluid_demand_tier()
	return FLUID_TIER_BUFFER

/obj/structure/fluid_tank/fluid_supply_holder()
	return reagents

/obj/structure/fluid_tank/fluid_demand(id)
	if (filter_reagent && id != filter_reagent)
		return 0
	return reagents.get_free_space()

/obj/structure/fluid_tank/fluid_receive(id, amount, data)
	if (fluid_demand(id) <= 0)
		return 0
	return fluid_add_to(reagents, id, amount, data)

/obj/structure/fluid_tank/examine(mob/user, distance)
	..(user, distance)
	to_chat(user, SPAN_NOTICE("It holds [round(reagents.total_volume)] of [FLUID_TANK_VOLUME] units[reagents.total_volume ? ", mostly [reagents.get_master_reagent_name()]" : ""]."))
	if (filter_reagent)
		var/datum/reagent/R = chemical_reagents_list[filter_reagent]
		to_chat(user, SPAN_NOTICE("It only takes [R ? R.name : filter_reagent]."))

/obj/structure/fluid_tank/verb/set_tank_filter()
	set name = "Set Tank Filter"
	set category = null
	set src in oview(1)
	var/mob/living/L = usr
	if (!istype(L) || L.incapacitated())
		return
	var/obj/item/held = L.get_active_hand()
	if (!held || !held.reagents || !held.reagents.total_volume)
		filter_reagent = null
		to_chat(L, SPAN_NOTICE("\The [src] now takes anything. Hold a filled container to keep it to one reagent."))
		return
	filter_reagent = held.reagents.get_master_reagent_id()
	var/datum/reagent/R = chemical_reagents_list[filter_reagent]
	to_chat(L, SPAN_NOTICE("\The [src] now only takes [R ? R.name : filter_reagent]."))

//////////////////////////////////////////////////////////////////////////////
// Water intake: set beside open water, it draws water for its network as a
// person filling a container there would get it, sickness, salt and all.

/obj/structure/fluid_intake
	name = "water intake"
	desc = "A screened pipe inlet. Set beside open water, it supplies that water to its pipe network."
	icon = 'icons/obj/machines/pipes.dmi'
	icon_state = "inlet"
	anchored = TRUE
	density = TRUE
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = FALSE

/obj/structure/fluid_intake/New()
	..()
	create_reagents(FLUID_INTAKE_RATE)
	flags |= NOREACT
	fluid_mark_dirty()

/obj/structure/fluid_intake/Destroy()
	fluid_mark_dirty()
	return ..()

/obj/structure/fluid_intake/proc/water_turf()
	for (var/d in cardinal)
		var/turf/floor/beach/water/W = get_step(src, d)
		if (istype(W) && !istype(W, /turf/floor/beach/water/ice))
			return W
	return null

// Draw this step's water: the same mix a person gets filling a container.
/obj/structure/fluid_intake/proc/draw_water()
	var/turf/floor/beach/water/W = water_turf()
	var/amount = reagents.get_free_space()
	if (!W || amount <= 0)
		return
	var/other = 0
	if (W.sickness > 0)
		reagents.add_reagent("cholera", amount * W.sickness * 0.05)
		other += amount * W.sickness * 0.05
	if (W.salty)
		reagents.add_reagent("sodiumchloride", amount * 0.04)
		other += amount * 0.04
	reagents.add_reagent(W.radiation > 0 ? "irradiated_water" : "water", max(0, amount - other))

/obj/structure/fluid_intake/fluid_supply_tier()
	return FLUID_TIER_SOURCE

/obj/structure/fluid_intake/fluid_supply_holder()
	draw_water()
	return reagents

/obj/structure/fluid_intake/examine(mob/user, distance)
	..(user, distance)
	to_chat(user, water_turf() ? SPAN_NOTICE("It sits beside open water.") : SPAN_WARNING("There is no open water beside it."))

//////////////////////////////////////////////////////////////////////////////
// Phase 0 machines on pipes.

// Oil well: its barrel is the wellhead tank, and pipes draw petroleum from it.
/obj/structure/oilwell/fluid_supply_tier()
	return FLUID_TIER_SOURCE

/obj/structure/oilwell/fluid_supply_holder()
	if (!work_barrel || work_barrel.loc != src)
		return null
	return work_barrel.reagents

/obj/structure/oilwell/fluid_supplies(id)
	return id == "petroleum"

// Refineries take feedstock from pipes and offer their output barrel's contents.
/obj/structure/refinery/fluid_supply_tier()
	return FLUID_TIER_SOURCE

/obj/structure/refinery/fluid_demand_tier()
	return FLUID_TIER_SINK

/obj/structure/refinery/fluid_supply_holder()
	var/obj/item/weapon/reagent_containers/glass/barrel/B = factory_output_barrel()
	return B ? B.reagents : null

/obj/structure/refinery/fluid_demand(id)
	return (id in factory_feed_ids()) ? factory_feed_room() : 0

/obj/structure/refinery/fluid_receive(id, amount, data)
	if (fluid_demand(id) <= 0)
		return 0
	var/datum/reagents/feed = new /datum/reagents(amount)
	feed.add_reagent(id, amount, data)
	var/taken = factory_drain_feed(feed)
	qdel(feed)
	factory_try_start()
	return taken

// Engines fill their connected fuel tank with fuels they burn.
/obj/structure/engine/internal/fluid_demand_tier()
	return FLUID_TIER_SINK

/obj/structure/engine/internal/fluid_demand(id)
	if (!anchored || broken || !fueltank || !fueltank.reagents || !(id in fuels))
		return 0
	return fueltank.reagents.get_free_space()

/obj/structure/engine/internal/fluid_receive(id, amount, data)
	if (fluid_demand(id) <= 0)
		return 0
	return fluid_add_to(fueltank.reagents, id, amount, data)

// Barrel stations: draining stations supply their tank; filling stations take.
/obj/structure/reagent_dispensers/largebarrel/factory_station/fluid_supply_tier()
	return station_fill ? 0 : FLUID_TIER_SOURCE

/obj/structure/reagent_dispensers/largebarrel/factory_station/fluid_demand_tier()
	return station_fill ? FLUID_TIER_SINK : 0

/obj/structure/reagent_dispensers/largebarrel/factory_station/fluid_supply_holder()
	return anchored && !locked ? reagents : null

/obj/structure/reagent_dispensers/largebarrel/factory_station/fluid_demand(id)
	if (!anchored || locked || !station_fill)
		return 0
	return reagents.get_free_space()

/obj/structure/reagent_dispensers/largebarrel/factory_station/fluid_receive(id, amount, data)
	if (fluid_demand(id) <= 0)
		return 0
	return fluid_add_to(reagents, id, amount, data)

#undef FLUID_TANK_VOLUME
#undef FLUID_INTAKE_RATE
#undef FLUID_NETWORK_LIMIT
#undef FLUID_REBUILD_STEPS
