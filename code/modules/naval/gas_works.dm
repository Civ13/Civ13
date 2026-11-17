// ============================================================
// Gas works: lifting gas for airships, and oxygen (docs/craft-core.md)
// ------------------------------------------------------------
// Airship gas cells hang empty and are filled with hydrogen or helium
// (air_hull.dm). The gases are the ordinary hydrogen, helium and oxygen
// reagents, so they also travel through factory pipes (factory_pipes.dm).
//
// Making it: a hydrogen generator (acid on iron or zinc in a cask), a powered
// electrolysis tank (water into hydrogen and oxygen), a water-gas retort (coal
// or charcoal and water) and a powered helium separator beside a working oil
// well. Keeping it: gasbags carried by hand, steel gas cylinders that only a
// powered gas compressor fills, and a gas holder that stores a great deal of
// one gas and fills cells nearby through a gas hose. Oxygen from a bag or a
// cylinder eases someone short of breath. Nothing here is sold to anyone.
// ============================================================

#define GAS_BAG_VOLUME 60
#define GAS_CYLINDER_VOLUME 240
#define GAS_HOLDER_VOLUME 3000
// What a gas works holds before it must be emptied.
#define GAS_WORKS_STORE 240
// How far a gas hose reaches from its gas holder, in tiles.
#define GAS_HOSE_REACH 6
#define GAS_FILL_TIME 20
#define GAS_COMPRESSOR_RATE 10
#define GAS_OXYGEN_DOSE 10

var/global/list/gas_works = list()
var/global/list/stored_gases = list("hydrogen", "helium", "oxygen")
var/global/list/lifting_gases = list("hydrogen", "helium")

/proc/gas_name(id)
	var/datum/reagent/R = chemical_reagents_list[id]
	return R ? lowertext(R.name) : id

// The one gas a holder holds, or null when it is empty.
/proc/gas_held(datum/reagents/R)
	if (!R)
		return null
	for (var/id in stored_gases)
		if (R.get_reagent_amount(id) > 0)
			return id
	return null

// Moves up to amount units of gas id from one holder to another.
/proc/gas_move(datum/reagents/giver, datum/reagents/taker, id, amount)
	if (!giver || !taker || !id)
		return 0
	amount = min(amount, giver.get_reagent_amount(id), taker.get_free_space())
	if (amount <= 0)
		return 0
	giver.remove_reagent(id, amount)
	taker.add_reagent(id, amount)
	return amount

// Called every pipe network step (factory_pipes.dm).
/proc/gas_works_step()
	for (var/obj/structure/gas_works/W in gas_works.Copy())
		if (QDELETED(W))
			gas_works -= W
			continue
		var/was = W.working
		W.working = W.anchored && isturf(W.loc) ? W.work() : FALSE
		if (was != W.working)
			W.update_icon()

// ---- Carried gas: gasbags and cylinders ----

/obj/item/weapon/reagent_containers/gas_vessel
	name = "gasbag"
	desc = "A stitched leather bag, sealed with pitch, for carrying gas. Use it on a gas works or a gas holder to fill it, and on an airship gas cell, a gas holder or a gas compressor to empty it. A bag of oxygen eases someone short of breath."
	icon = 'icons/obj/gas_works.dmi'
	icon_state = "gasbag"
	w_class = ITEM_SIZE_NORMAL
	volume = GAS_BAG_VOLUME
	flags = NOREACT
	possible_transfer_amounts = null
	amount_per_transfer_from_this = 0
	var/empty_state = "gasbag"
	// A cylinder is only filled by a gas compressor.
	var/pressurised = FALSE

/obj/item/weapon/reagent_containers/gas_vessel/New()
	..()
	if (!reagents)
		create_reagents(volume)
	update_icon()

/obj/item/weapon/reagent_containers/gas_vessel/on_reagent_change()
	update_icon()

/obj/item/weapon/reagent_containers/gas_vessel/update_icon()
	var/id = gas_held(reagents)
	icon_state = id ? "gasbag_full" : "gasbag"

/obj/item/weapon/reagent_containers/gas_vessel/examine(mob/user, distance)
	..(user, distance)
	var/id = gas_held(reagents)
	to_chat(user, SPAN_NOTICE(id ? "It holds [round(reagents.get_reagent_amount(id))] of [volume] units of [gas_name(id)]." : "It is empty."))

// Oxygen for someone short of breath.
/obj/item/weapon/reagent_containers/gas_vessel/attack(mob/living/M, mob/living/user, target_zone)
	if (!istype(M) || user.a_intent == I_HARM)
		return ..()
	if (reagents.get_reagent_amount("oxygen") < GAS_OXYGEN_DOSE)
		to_chat(user, SPAN_WARNING("\The [src] has no oxygen to give."))
		return TRUE
	user.visible_message(SPAN_NOTICE("[user] holds \the [src] to [M == user ? "their own" : "[M]'s"] face and lets the oxygen out."))
	if (!do_after(user, 20, M) || reagents.get_reagent_amount("oxygen") < GAS_OXYGEN_DOSE)
		return TRUE
	reagents.remove_reagent("oxygen", GAS_OXYGEN_DOSE)
	M.adjustOxyLoss(-25)
	to_chat(M, SPAN_NOTICE("You breathe in the oxygen and your head clears."))
	return TRUE

/obj/item/weapon/reagent_containers/gas_vessel/cylinder
	name = "gas cylinder"
	desc = "A heavy steel bottle for gas under pressure. Only a powered gas compressor fills it. Use it on an airship gas cell, a gas holder or a gas compressor to empty it. A cylinder of oxygen eases someone short of breath."
	icon_state = "cylinder_empty"
	w_class = ITEM_SIZE_LARGE
	weight = 15
	volume = GAS_CYLINDER_VOLUME
	empty_state = "cylinder_empty"
	pressurised = TRUE

/obj/item/weapon/reagent_containers/gas_vessel/cylinder/update_icon()
	var/id = gas_held(reagents)
	icon_state = id ? "cylinder_[id]" : "cylinder_empty"

// Fills vessel V from the gases in R, asking which when there are several.
/proc/gas_fill_vessel(mob/user, obj/item/weapon/reagent_containers/gas_vessel/V, datum/reagents/R, atom/source)
	var/id = gas_held(V.reagents)
	if (!id)
		var/list/choices = list()
		for (var/g in stored_gases)
			if (R.get_reagent_amount(g) >= 1)
				choices[capitalize(gas_name(g))] = g
		if (!choices.len)
			to_chat(user, SPAN_WARNING("\The [source] has no gas to give."))
			return FALSE
		if (choices.len == 1)
			id = choices[choices[1]]
		else
			var/pick = WWinput(user, "Which gas?", source.name, choices[1], choices)
			id = choices[pick]
			if (!id || get_dist(user, source) > 1)
				return FALSE
	var/moved = gas_move(R, V.reagents, id, V.reagents.get_free_space())
	if (moved <= 0)
		to_chat(user, SPAN_WARNING(V.reagents.get_free_space() <= 0 ? "\The [V] is full." : "\The [source] has no [gas_name(id)] to give."))
		return FALSE
	to_chat(user, SPAN_NOTICE("You fill \the [V] with [round(moved)] units of [gas_name(id)]."))
	return TRUE

// ---- Gas works ----

/obj/structure/gas_works
	name = "gas works"
	icon = 'icons/obj/gas_works.dmi'
	anchored = TRUE
	density = TRUE
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = FALSE
	flags = NOREACT
	var/base_state = ""
	// Whether it has an "_on" sprite for while it works.
	var/shows_work = TRUE
	var/tmp/working = FALSE

/obj/structure/gas_works/New()
	..()
	if (!reagents)
		create_reagents(GAS_WORKS_STORE)
	reagents.maximum_volume = GAS_WORKS_STORE
	flags |= NOREACT
	gas_works |= src
	fluid_mark_dirty()
	update_icon()

/obj/structure/gas_works/after_load()
	. = ..()
	gas_works |= src
	fluid_mark_dirty()

/obj/structure/gas_works/Destroy()
	gas_works -= src
	if (powersource)
		powersource.update_power(-powerneeded, 1, src)
	fluid_mark_dirty()
	return ..()

/obj/structure/gas_works/update_icon()
	icon_state = working && shows_work ? "[base_state]_on" : base_state

// One step of work; TRUE while it is making gas.
/obj/structure/gas_works/proc/work()
	return FALSE

// Whether its cable brings it the power it needs now.
/obj/structure/gas_works/proc/powered_now()
	return draw_cable_power() ? TRUE : FALSE

/obj/structure/gas_works/proc/make(id, amount)
	return reagents.add_reagent(id, min(amount, reagents.get_free_space()))

/obj/structure/gas_works/examine(mob/user, distance)
	..(user, distance)
	var/list/held = list()
	for (var/id in stored_gases)
		var/n = reagents.get_reagent_amount(id)
		if (n >= 1)
			held += "[round(n)] units of [gas_name(id)]"
	to_chat(user, SPAN_NOTICE(held.len ? "It holds [english_list(held)]. Fill a gasbag or pipe it away." : "It holds no gas yet."))

/obj/structure/gas_works/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/weapon/reagent_containers/gas_vessel))
		var/obj/item/weapon/reagent_containers/gas_vessel/V = W
		if (V.pressurised)
			to_chat(user, SPAN_WARNING("Only a gas compressor can fill \the [V]. Pipe the gas to one, or carry it there in a gasbag."))
			return TRUE
		gas_fill_vessel(user, V, reagents, src)
		return TRUE
	if (istype(W, /obj/item/stack/cable_coil) && powerneeded)
		connect_cable(user, W)
		return TRUE
	return ..()

// Pipes carry its gas away (factory_pipes.dm).
/obj/structure/gas_works/fluid_supply_tier()
	return anchored ? FLUID_TIER_SOURCE : 0

/obj/structure/gas_works/fluid_supplies(id)
	return id in stored_gases

/obj/structure/gas_works/fluid_supply_holder()
	return reagents

// A cask where acid eats iron or zinc and gives off hydrogen.
/obj/structure/gas_works/hydrogen_generator
	name = "hydrogen generator"
	desc = "A sealed cask with a gas pipe. Pour in sulphuric or hydrochloric acid and drop in iron or zinc, and it gives off hydrogen until one runs out."
	base_state = "hydrogen_generator"
	icon_state = "hydrogen_generator"
	flammable = TRUE
	var/acid = 0
	var/metal = 0

/obj/structure/gas_works/hydrogen_generator/work()
	if (acid < 1 || metal < 1 || reagents.get_free_space() < 3)
		return FALSE
	acid--
	metal--
	make("hydrogen", 3)
	return TRUE

/obj/structure/gas_works/hydrogen_generator/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/stack/material/iron) || istype(W, /obj/item/stack/material/zinc))
		var/obj/item/stack/S = W
		if (metal >= 100)
			to_chat(user, SPAN_WARNING("\The [src] has metal enough in it."))
			return TRUE
		if (S.use(1))
			metal += 20
			to_chat(user, SPAN_NOTICE("You drop \the [S.singular_name ? S.singular_name : S] into \the [src]."))
		return TRUE
	if (istype(W, /obj/item/weapon/reagent_containers) && !istype(W, /obj/item/weapon/reagent_containers/gas_vessel) && W.reagents)
		var/took = 0
		for (var/id in list("sacid", "hclacid"))
			var/n = min(W.reagents.get_reagent_amount(id), 120 - acid)
			if (n > 0)
				W.reagents.remove_reagent(id, n)
				acid += n
				took += n
		if (took)
			to_chat(user, SPAN_NOTICE("You pour [round(took)] units of acid into \the [src]."))
			return TRUE
	return ..()

/obj/structure/gas_works/hydrogen_generator/examine(mob/user, distance)
	..(user, distance)
	to_chat(user, SPAN_NOTICE("Acid: [round(acid)] of 120 units. Metal: enough for [round(metal)] more puffs of gas."))

// Water split by electric current into hydrogen and oxygen.
/obj/structure/gas_works/electrolysis_tank
	name = "electrolysis tank"
	desc = "A tank of water with two electrodes. Cabled to power and given water, poured in, piped in or from running water beside it, it splits the water into hydrogen and oxygen, twice as much hydrogen as oxygen."
	base_state = "electrolysis_tank"
	icon_state = "electrolysis_tank"
	powerneeded = 4
	water_capacity = 120

/obj/structure/gas_works/electrolysis_tank/work()
	if (reagents.get_free_space() < 3 || !station_has_water(2) || !powered_now())
		return FALSE
	station_take_water(null, 2)
	make("hydrogen", 2)
	make("oxygen", 1)
	return TRUE

/obj/structure/gas_works/electrolysis_tank/attackby(obj/item/W, mob/user)
	if (station_water_pour(W, user))
		return TRUE
	return ..()

/obj/structure/gas_works/electrolysis_tank/examine(mob/user, distance)
	..(user, distance)
	station_water_examine(user)

// Water-gas: steam over glowing coal or charcoal.
/obj/structure/gas_works/water_gas_retort
	name = "water-gas retort"
	desc = "A firebrick retort. Fed coal or charcoal and given water, poured in, piped in or from running water beside it, it drives steam over the glowing fuel and gives off hydrogen."
	base_state = "water_gas_retort"
	icon_state = "water_gas_retort"
	water_capacity = 120
	var/fuel = 0

/obj/structure/gas_works/water_gas_retort/work()
	if (fuel < 1 || reagents.get_free_space() < 2 || !station_has_water(1))
		return FALSE
	station_take_water(null, 1)
	fuel--
	make("hydrogen", 2)
	return TRUE

/obj/structure/gas_works/water_gas_retort/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/stack/ore/coal) || istype(W, /obj/item/stack/ore/charcoal))
		var/obj/item/stack/S = W
		if (fuel >= 150)
			to_chat(user, SPAN_WARNING("\The [src] is stoked full."))
			return TRUE
		if (S.use(1))
			fuel += 15
			to_chat(user, SPAN_NOTICE("You stoke \the [src]."))
		return TRUE
	if (station_water_pour(W, user))
		return TRUE
	return ..()

/obj/structure/gas_works/water_gas_retort/examine(mob/user, distance)
	..(user, distance)
	station_water_examine(user)
	to_chat(user, SPAN_NOTICE(fuel ? "Its fire will last [round(fuel)] more puffs of gas." : "Its fire is out. Stoke it with coal or charcoal."))

// Helium drawn from the natural gas of an oil well.
/obj/structure/gas_works/helium_separator
	name = "helium separator"
	desc = "A tall cold column. Set beside a working oil well and cabled to power, it draws off the well's natural gas and freezes out everything but a trickle of helium."
	base_state = "helium_separator"
	icon_state = "helium_separator"
	shows_work = FALSE
	powerneeded = 6

/obj/structure/gas_works/helium_separator/proc/well()
	for (var/obj/structure/oilwell/W in range(1, src))
		if (W.has_source())
			return W
	return null

/obj/structure/gas_works/helium_separator/work()
	if (reagents.get_free_space() < 1 || !well() || !powered_now())
		return FALSE
	make("helium", 1)
	return TRUE

/obj/structure/gas_works/helium_separator/examine(mob/user, distance)
	..(user, distance)
	if (!well())
		to_chat(user, SPAN_WARNING("No working oil well stands beside it."))

// ---- The gas holder ----

/obj/structure/gas_holder
	name = "gas holder"
	desc = "A great iron bell floating in a water tank, rising as it fills. It holds a lot of one gas. Empty gasbags or cylinders into it, pipe gas in, or use an empty gasbag on it to fill it. Use a gas hose on it to fill airship gas cells nearby."
	icon = 'icons/obj/gas_holder.dmi'
	icon_state = "gas_holder_low"
	pixel_x = -16
	anchored = TRUE
	density = TRUE
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = FALSE
	flags = NOREACT

/obj/structure/gas_holder/New()
	..()
	if (!reagents)
		create_reagents(GAS_HOLDER_VOLUME)
	reagents.maximum_volume = GAS_HOLDER_VOLUME
	flags |= NOREACT
	fluid_mark_dirty()
	update_icon()

/obj/structure/gas_holder/Destroy()
	fluid_mark_dirty()
	return ..()

/obj/structure/gas_holder/on_reagent_change()
	update_icon()

/obj/structure/gas_holder/update_icon()
	var/share = reagents ? reagents.total_volume / GAS_HOLDER_VOLUME : 0
	icon_state = share > 0.66 ? "gas_holder_high" : (share > 0.2 ? "gas_holder" : "gas_holder_low")

/obj/structure/gas_holder/examine(mob/user, distance)
	..(user, distance)
	var/id = gas_held(reagents)
	to_chat(user, SPAN_NOTICE(id ? "It holds [round(reagents.get_reagent_amount(id))] of [GAS_HOLDER_VOLUME] units of [gas_name(id)]." : "It is empty."))

// Takes amount of gas id, if it holds no other gas.
/obj/structure/gas_holder/proc/take_in(datum/reagents/from, id, amount)
	var/held = gas_held(reagents)
	if (held && held != id)
		return 0
	return gas_move(from, reagents, id, amount)

/obj/structure/gas_holder/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/weapon/reagent_containers/gas_vessel))
		var/obj/item/weapon/reagent_containers/gas_vessel/V = W
		var/id = gas_held(V.reagents)
		if (id)
			var/held = gas_held(reagents)
			if (held && held != id)
				to_chat(user, SPAN_WARNING("\The [src] holds [gas_name(held)]; it takes no other gas."))
				return TRUE
			var/moved = take_in(V.reagents, id, V.reagents.get_reagent_amount(id))
			to_chat(user, SPAN_NOTICE(moved ? "You empty [round(moved)] units of [gas_name(id)] into \the [src]." : "\The [src] is full."))
			return TRUE
		if (V.pressurised)
			to_chat(user, SPAN_WARNING("Only a gas compressor can fill \the [V]. Set one beside \the [src]."))
			return TRUE
		gas_fill_vessel(user, V, reagents, src)
		return TRUE
	if (istype(W, /obj/item/gas_hose))
		var/obj/item/gas_hose/H = W
		H.holder = src
		to_chat(user, SPAN_NOTICE("You couple \the [H] to \the [src]. Use it on an airship gas cell within [GAS_HOSE_REACH] tiles."))
		return TRUE
	return ..()

/obj/structure/gas_holder/fluid_supply_tier()
	return anchored ? FLUID_TIER_BUFFER : 0

/obj/structure/gas_holder/fluid_demand_tier()
	return anchored ? FLUID_TIER_BUFFER : 0

/obj/structure/gas_holder/fluid_supplies(id)
	return id in stored_gases

/obj/structure/gas_holder/fluid_supply_holder()
	return reagents

/obj/structure/gas_holder/fluid_demand(id)
	if (!(id in stored_gases))
		return 0
	var/held = gas_held(reagents)
	if (held && held != id)
		return 0
	return reagents.get_free_space()

/obj/structure/gas_holder/fluid_receive(id, amount, data)
	if (fluid_demand(id) <= 0)
		return 0
	return fluid_add_to(reagents, id, amount, data)

// A hose from a gas holder to the cells of an airship close by.
/obj/item/gas_hose
	name = "gas hose"
	desc = "A long rubberised hose with brass couplings. Use it on a gas holder to couple it, then on an airship gas cell within six tiles, even one level up, to fill the cell from the holder."
	icon = 'icons/obj/gas_works.dmi'
	icon_state = "gas_hose"
	w_class = ITEM_SIZE_NORMAL
	var/tmp/obj/structure/gas_holder/holder = null

/obj/item/gas_hose/proc/reaches(atom/A)
	if (!holder || QDELETED(holder) || !A)
		return FALSE
	var/turf/H = get_turf(holder)
	var/turf/T = get_turf(A)
	return H && T && abs(H.z - T.z) <= 1 && max(abs(H.x - T.x), abs(H.y - T.y)) <= GAS_HOSE_REACH

// ---- Filling airship gas cells ----

/obj/structure/airship_gas_cell/attackby(obj/item/W, mob/user)
	var/datum/reagents/from = null
	if (istype(W, /obj/item/weapon/reagent_containers/gas_vessel))
		from = W.reagents
	else if (istype(W, /obj/item/gas_hose))
		var/obj/item/gas_hose/H = W
		if (!H.reaches(src))
			to_chat(user, SPAN_WARNING("Couple \the [H] to a gas holder within [GAS_HOSE_REACH] tiles first."))
			return
		from = H.holder.reagents
	if (!from)
		return ..()
	if (burnt)
		to_chat(user, SPAN_WARNING("\The [src] is burnt out."))
		return
	var/id = gas_held(from)
	if (!(id in lifting_gases))
		to_chat(user, SPAN_WARNING(id ? "[capitalize(gas_name(id))] lifts nothing. Fill it with hydrogen or helium." : "There is no gas in \the [W]."))
		return
	if (gas && gas_amount > 0 && gas != id)
		to_chat(user, SPAN_WARNING("\The [src] holds [gas_name(gas)]. Take it down with a wrench to let it out before filling it with [gas_name(id)]."))
		return
	if (gas_amount >= AIR_HULL_CELL_GAS)
		to_chat(user, SPAN_NOTICE("\The [src] is full."))
		return
	to_chat(user, SPAN_NOTICE("You start filling \the [src] with [gas_name(id)]..."))
	if (!do_after(user, GAS_FILL_TIME, src) || QDELETED(src) || burnt || QDELETED(W))
		return
	if (istype(W, /obj/item/gas_hose))
		var/obj/item/gas_hose/H2 = W
		if (!H2.reaches(src))
			return
	if (gas && gas_amount > 0 && gas != id)
		return
	var/n = min(AIR_HULL_CELL_GAS - gas_amount, from.get_reagent_amount(id))
	if (n <= 0)
		return
	from.remove_reagent(id, n)
	gas = id
	gas_amount += n
	update_icon()
	to_chat(user, SPAN_NOTICE(gas_amount >= AIR_HULL_CELL_GAS ? "\The [src] swells taut with [gas_name(id)]." : "You put [round(n)] units of [gas_name(id)] into \the [src]; it takes [round(AIR_HULL_CELL_GAS - gas_amount)] more."))
	var/datum/craft/air/C = craft_at(get_turf(src))
	var/datum/craft_body/built/air/B = istype(C) ? C.body : null
	if (istype(B))
		to_chat(user, SPAN_NOTICE("Her gas cells now hold up [B.lift()] of her [B.load()]."))

// ---- The compressor ----

/obj/structure/gas_compressor
	name = "gas compressor"
	desc = "An electric pump that packs gas into a steel cylinder. Put a cylinder in, cable it to power, and it fills the cylinder from a gas holder beside it, from gasbags emptied into it, or from gas piped to it. Use it with an empty hand to take the cylinder out."
	icon = 'icons/obj/gas_works.dmi'
	icon_state = "gas_compressor"
	anchored = TRUE
	density = TRUE
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = FALSE
	powerneeded = 3

/obj/structure/gas_compressor/New()
	..()
	gas_works_compressors |= src
	fluid_mark_dirty()

/obj/structure/gas_compressor/after_load()
	. = ..()
	gas_works_compressors |= src
	fluid_mark_dirty()

/obj/structure/gas_compressor/Destroy()
	gas_works_compressors -= src
	if (powersource)
		powersource.update_power(-powerneeded, 1, src)
	for (var/obj/item/I in contents)
		I.forceMove(get_turf(src))
	fluid_mark_dirty()
	return ..()

var/global/list/gas_works_compressors = list()

/obj/structure/gas_compressor/proc/cylinder()
	return locate(/obj/item/weapon/reagent_containers/gas_vessel/cylinder) in contents

/obj/structure/gas_compressor/proc/powered_now()
	return draw_cable_power() ? TRUE : FALSE

// The gas the cylinder takes now: what it holds, else what id offers.
/obj/structure/gas_compressor/proc/accepts(id)
	var/obj/item/weapon/reagent_containers/gas_vessel/cylinder/C = cylinder()
	if (!C || !(id in stored_gases))
		return FALSE
	var/held = gas_held(C.reagents)
	return !held || held == id

/obj/structure/gas_compressor/proc/compress()
	var/obj/item/weapon/reagent_containers/gas_vessel/cylinder/C = cylinder()
	if (!C || !anchored || C.reagents.get_free_space() <= 0)
		return FALSE
	for (var/obj/structure/gas_holder/H in orange(1, src))
		var/id = gas_held(H.reagents)
		if (id && accepts(id))
			if (!powered)
				return FALSE
			return gas_move(H.reagents, C.reagents, id, GAS_COMPRESSOR_RATE) > 0
	return FALSE

/obj/structure/gas_compressor/examine(mob/user, distance)
	..(user, distance)
	var/obj/item/weapon/reagent_containers/gas_vessel/cylinder/C = cylinder()
	if (!C)
		to_chat(user, SPAN_NOTICE("It has no cylinder in it."))
		return
	var/id = gas_held(C.reagents)
	to_chat(user, SPAN_NOTICE(id ? "Its cylinder holds [round(C.reagents.get_reagent_amount(id))] of [C.volume] units of [gas_name(id)]." : "Its cylinder is empty."))

/obj/structure/gas_compressor/attack_hand(mob/user)
	var/obj/item/C = cylinder()
	if (!C)
		return ..()
	C.forceMove(get_turf(src))
	user.put_in_hands(C)
	to_chat(user, SPAN_NOTICE("You take \the [C] out of \the [src]."))
	fluid_mark_dirty()

/obj/structure/gas_compressor/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/stack/cable_coil))
		connect_cable(user, W)
		return TRUE
	if (istype(W, /obj/item/weapon/reagent_containers/gas_vessel/cylinder))
		if (cylinder())
			to_chat(user, SPAN_WARNING("\The [src] already has a cylinder in it."))
			return TRUE
		user.drop_from_inventory(W)
		W.forceMove(src)
		to_chat(user, SPAN_NOTICE("You fit \the [W] to \the [src]."))
		fluid_mark_dirty()
		return TRUE
	if (istype(W, /obj/item/weapon/reagent_containers/gas_vessel))
		var/obj/item/weapon/reagent_containers/gas_vessel/V = W
		var/id = gas_held(V.reagents)
		var/obj/item/weapon/reagent_containers/gas_vessel/cylinder/C = cylinder()
		if (!id || !C)
			to_chat(user, SPAN_WARNING(C ? "\The [V] is empty." : "Put a cylinder in \the [src] first."))
			return TRUE
		if (!accepts(id))
			to_chat(user, SPAN_WARNING("Its cylinder holds another gas."))
			return TRUE
		if (!powered_now())
			to_chat(user, SPAN_WARNING("\The [src] has no power."))
			return TRUE
		var/moved = gas_move(V.reagents, C.reagents, id, V.reagents.get_reagent_amount(id))
		to_chat(user, SPAN_NOTICE(moved ? "\The [src] packs [round(moved)] units of [gas_name(id)] into the cylinder." : "The cylinder is full."))
		return TRUE
	return ..()

/obj/structure/gas_compressor/fluid_demand_tier()
	return anchored && cylinder() ? FLUID_TIER_SINK : 0

/obj/structure/gas_compressor/fluid_demand(id)
	var/obj/item/weapon/reagent_containers/gas_vessel/cylinder/C = cylinder()
	if (!C || !accepts(id) || !powered)
		return 0
	return min(GAS_COMPRESSOR_RATE, C.reagents.get_free_space())

/obj/structure/gas_compressor/fluid_receive(id, amount, data)
	var/obj/item/weapon/reagent_containers/gas_vessel/cylinder/C = cylinder()
	if (fluid_demand(id) <= 0)
		return 0
	return fluid_add_to(C.reagents, id, min(amount, fluid_demand(id)), data)

/obj/structure/gas_compressor/proc/compressor_step()
	var/was = powered
	powered = cylinder() && powered_now()
	if (powered != was)
		fluid_mark_dirty()
	compress()

/proc/gas_compressors_step()
	for (var/obj/structure/gas_compressor/C in gas_works_compressors.Copy())
		if (QDELETED(C))
			gas_works_compressors -= C
			continue
		C.compressor_step()

#undef GAS_HOSE_REACH
#undef GAS_FILL_TIME
#undef GAS_BAG_VOLUME
#undef GAS_CYLINDER_VOLUME
#undef GAS_HOLDER_VOLUME
#undef GAS_WORKS_STORE
#undef GAS_COMPRESSOR_RATE
#undef GAS_OXYGEN_DOSE
