// Tenders, water towers and water cranes (docs/trains.md).
//
// A tender carries a steam engine's fuel and water. The fireman shovels the
// fuel across by hand; the water runs to the engine's tank by itself. Two
// kinds exist: the old one-tile tender wagon, whose fuel is the items in its
// storage, and the 3x4 walkable tender, a platform car of kind "tender"
// whose front section holds the bunker and the tank as two numbers.
//
// Water towers hold water beside the track and fill the engines and tenders
// standing within reach; a water crane does the same from a tower nearby.

#define TENDER_FUEL_MAX 1500 // a hundred pieces of coal
#define TENDER_WATER_MAX 2400
#define TENDER_WAGON_WATER_MAX 600
#define TENDER_SHOVEL_FUEL 30 // fuel moved by one stroke of the shovel
#define WATER_TOWER_MAX 6000
#define WATER_TOWER_PUMP 300 // one spell at the tower's hand pump
#define WATER_CRANE_PIPE 12 // tiles from a crane to the tower that feeds it

/obj/structure/trains
	var/tender_water = 0

/obj/structure/trains/platform
	var/tender_fuel = 0

// What a piece is worth in a steam engine's firebox; 0 when it does not burn there.
/proc/steam_fuel_value(obj/item/I)
	if (istype(I, /obj/item/stack/ore/coal))
		return 15
	if (istype(I, /obj/item/stack/material/wood) || istype(I, /obj/item/weapon/branch))
		return 3
	return 0

// The section that holds this tender's fuel and water, or null when the car
// is no tender.
/obj/structure/trains/proc/tender_store()
	return null

/obj/structure/trains/storage/tender/tender_store()
	return src

/obj/structure/trains/platform/tender_store()
	if (car_kind != "tender")
		return null
	if (seg_index == 1)
		return src
	for (var/obj/structure/trains/platform/P in car_segments())
		if (P.seg_index == 1)
			return P
	return null

/obj/structure/trains/proc/tender_water_max()
	return 0

/obj/structure/trains/storage/tender/tender_water_max()
	return TENDER_WAGON_WATER_MAX

/obj/structure/trains/platform/tender_water_max()
	return (car_kind == "tender") ? TENDER_WATER_MAX : 0

// Fuel left, in firebox units.
/obj/structure/trains/proc/tender_fuel_left()
	return 0

/obj/structure/trains/storage/tender/tender_fuel_left()
	. = 0
	if (!storage)
		return
	for (var/obj/item/I in storage.contents)
		var/units = 1
		if (istype(I, /obj/item/stack))
			var/obj/item/stack/S = I
			units = S.amount
		. += steam_fuel_value(I) * units

/obj/structure/trains/platform/tender_fuel_left()
	return tender_fuel

// Takes up to `want` units of fuel out of the tender. Returns what came out.
/obj/structure/trains/proc/tender_take_fuel(want)
	return 0

/obj/structure/trains/platform/tender_take_fuel(want)
	var/got = min(want, tender_fuel)
	if (got <= 0)
		return 0
	tender_fuel -= got
	return got

/obj/structure/trains/storage/tender/tender_take_fuel(want)
	. = 0
	if (!storage)
		return
	for (var/obj/item/I in storage.contents)
		var/value = steam_fuel_value(I)
		if (!value)
			continue
		while (. + value <= want && !QDELETED(I))
			. += value
			if (istype(I, /obj/item/stack))
				var/obj/item/stack/S = I
				S.use(1)
			else
				storage.remove_from_storage(I, null)
				qdel(I)
		if (. + 3 > want)
			break
	if (.)
		update_icon()

// Pours water in. Returns what the tank took.
/obj/structure/trains/proc/tender_add_water(amount)
	var/taken = clamp(amount, 0, tender_water_max() - tender_water)
	tender_water += taken
	return taken

/obj/structure/trains/proc/tender_text()
	var/top = tender_water_max()
	if (!top)
		return null
	return "Its tank holds [round(100 * tender_water / top)]% water."

/obj/structure/trains/platform/tender_text()
	if (car_kind != "tender")
		return null
	var/obj/structure/trains/platform/S = tender_store()
	if (!S)
		return null
	return "The bunker is [round(100 * S.tender_fuel / TENDER_FUEL_MAX)]% full of fuel and the tank holds [round(100 * S.tender_water / TENDER_WATER_MAX)]% water. Load it with coal or wood and pour water in; a fireman shovels the fuel into the engine next to it."

/proc/train_water_vessel(obj/item/W)
	return istype(W, /obj/item/weapon/reagent_containers) && W.reagents && W.is_open_container() && W.reagents.has_reagent("water")

// Fuel and water loaded into a tender by hand. TRUE when W was meant for it.
/obj/structure/trains/proc/tender_load(obj/item/W, mob/user)
	var/obj/structure/trains/S = tender_store()
	if (!S)
		return FALSE
	if (train_water_vessel(W))
		var/poured = S.tender_add_water(W.reagents.get_reagent_amount("water"))
		if (poured <= 0)
			to_chat(user, "<span class = 'notice'>The tender's tank is full.</span>")
			return TRUE
		W.reagents.remove_reagent("water", poured)
		playsound(loc, 'sound/effects/watersplash.ogg', 60, TRUE)
		to_chat(user, "You pour water into the tender. [S.tender_text()]")
		return TRUE
	return FALSE

/obj/structure/trains/platform/tender_load(obj/item/W, mob/user)
	if (..())
		return TRUE
	var/obj/structure/trains/platform/S = tender_store()
	var/value = steam_fuel_value(W)
	if (!S || !value)
		return FALSE
	var/room = round((TENDER_FUEL_MAX - S.tender_fuel) / value)
	if (room < 1)
		to_chat(user, "<span class = 'notice'>The bunker is full.</span>")
		return TRUE
	if (istype(W, /obj/item/stack))
		var/obj/item/stack/stack = W
		var/units = min(stack.amount, room)
		S.tender_fuel += units * value
		stack.use(units)
	else
		S.tender_fuel += value
		user.drop_from_inventory(W)
		qdel(W)
	to_chat(user, "You load the bunker. [S.tender_text()]")
	return TRUE

/obj/structure/trains/storage/tender/attackby(obj/item/W as obj, mob/user as mob)
	if (tender_load(W, user))
		return
	return ..()

/obj/structure/trains/storage/tender/examine(mob/user)
	..()
	to_chat(user, "Hitched next to a steam locomotive, a fireman with a shovel feeds the firebox from here. [tender_text()] Pour water in from a bucket.")

/////////////////////////////////////////////////////////////////////////////
// The engine's side

// The tenders coupled directly to this engine, front or rear.
/obj/structure/trains/locomotive/proc/engine_tenders()
	var/list/cars = train_consist_list(train_head())
	var/first = 0
	var/last = 0
	for (var/i in 1 to cars.len)
		var/obj/structure/trains/car = cars[i]
		if (car == src || (car_id && car.car_id == car_id))
			if (!first)
				first = i
			last = i
	var/list/found = list()
	if (!first)
		return found
	for (var/i in list(first - 1, last + 1))
		if (i < 1 || i > cars.len)
			continue
		var/obj/structure/trains/car = cars[i]
		var/obj/structure/trains/store = car.tender_store()
		if (store && !(store in found))
			found += store
	return found

/obj/structure/trains/locomotive/proc/tender_top_up()
	return

// The tender's water runs to the engine's own tank.
/obj/structure/trains/locomotive/coal/tender_top_up()
	var/need = max_water - water
	if (need < 1)
		return
	for (var/obj/structure/trains/store in engine_tenders())
		var/take = min(need, store.tender_water)
		if (take <= 0)
			continue
		store.tender_water -= take
		water += take
		need -= take
		if (need < 1)
			return

// One stroke of the shovel from the tender into the firebox. It works on a
// moving train: the fireman's whole job is this, between looks at the glass.
/obj/structure/trains/locomotive/coal/proc/shovel_coal(mob/user)
	var/room = max_fuel - fuel
	if (room < 3)
		to_chat(user, "<span class = 'notice'>The firebox is full.</span>")
		return FALSE
	var/list/tenders = engine_tenders()
	if (!tenders.len)
		to_chat(user, "There is no tender coupled next to \the [src]. Put fuel in by hand.")
		return FALSE
	for (var/obj/structure/trains/store in tenders)
		var/got = store.tender_take_fuel(min(room, TENDER_SHOVEL_FUEL))
		if (got <= 0)
			continue
		fuel += got
		if (user)
			user.setClickCooldown(10)
			to_chat(user, "You shovel fuel from the tender into the firebox. It is [round(100 * fuel / max_fuel)]% full.")
		playsound(loc, 'sound/effects/shovelling.ogg', 60, TRUE)
		return TRUE
	to_chat(user, "<span class = 'warning'>The tender is out of fuel.</span>")
	return FALSE

/////////////////////////////////////////////////////////////////////////////
// Water tower and water crane

/obj/structure/rail_water
	name = "water crane"
	desc = "A standpipe beside the track. It fills the steam locomotives and tenders standing next to it from a water tower nearby."
	icon = 'icons/obj/vehicles/rail_water.dmi'
	icon_state = "water_crane"
	pixel_x = -16
	pixel_y = -16
	anchored = TRUE
	density = TRUE
	opacity = FALSE
	flammable = FALSE
	not_movable = TRUE
	layer = 3.4
	var/reach = 2 // tiles to the rail tile of what it fills
	var/tmp/busy = FALSE

// The tower this draws from.
/obj/structure/rail_water/proc/source()
	var/obj/structure/rail_water/tower/best = null
	for (var/obj/structure/rail_water/tower/T in range(WATER_CRANE_PIPE, src))
		if (!best || T.water > best.water)
			best = T
	return best

// Everything within reach that takes water: steam engines, tenders and tank cars.
/obj/structure/rail_water/proc/takers()
	var/list/found = list()
	for (var/obj/structure/trains/TR in range(reach, src))
		var/obj/structure/trains/taker = null
		if (istype(TR, /obj/structure/trains/locomotive/coal))
			taker = TR
		else
			taker = TR.tender_store()
			if (!taker)
				var/obj/structure/trains/locomotive/coal/E = TR.unit_engine()
				if (istype(E))
					taker = E
				else if (istype(TR, /obj/structure/trains/platform))
					// a tank car that is empty or carries water (train_tank.dm)
					var/obj/structure/trains/platform/P = TR
					if (P.tank_takes("water"))
						taker = P.tank_store()
		if (taker && !(taker in found))
			found += taker
	return found

// Fills what stands within reach. Returns the water that went out.
/obj/structure/rail_water/proc/fill_takers()
	var/obj/structure/rail_water/tower/T = source()
	if (!T || T.water <= 0)
		return 0
	. = 0
	for (var/obj/structure/trains/taker in takers())
		var/gave = 0
		if (istype(taker, /obj/structure/trains/locomotive/coal))
			var/obj/structure/trains/locomotive/coal/E = taker
			E.boiler_tick()
			gave = E.add_water(T.water)
		else if (!taker.tender_store())
			var/obj/structure/trains/platform/P = taker
			gave = P.tank_fill("water", T.water)
		else
			gave = taker.tender_add_water(T.water)
		T.water -= gave
		. += gave
		if (T.water <= 0)
			break

/obj/structure/rail_water/examine(mob/user)
	..()
	var/obj/structure/rail_water/tower/T = source()
	if (!T)
		to_chat(user, "No water tower stands within [WATER_CRANE_PIPE] tiles to feed it.")
	else if (T != src)
		to_chat(user, "It draws from a water tower holding [round(T.water)] units.")
	to_chat(user, "Stop a steam locomotive, tender or tank car beside it and use it with an empty hand to fill up. A wrench turns it.")

/obj/structure/rail_water/attack_hand(mob/living/user as mob)
	if (!istype(user) || busy)
		return
	var/obj/structure/rail_water/tower/T = source()
	if (!T)
		to_chat(user, "<span class = 'warning'>No water tower stands within [WATER_CRANE_PIPE] tiles to feed \the [src].</span>")
		return
	if (!takers().len)
		return nothing_to_fill(user)
	if (T.water <= 0)
		to_chat(user, "<span class = 'warning'>The water tower is empty.</span>")
		return
	user.visible_message("[user] swings \the [src]'s spout over and opens the valve...", "You swing the spout over and open the valve...")
	busy = TRUE
	var/done = do_after(user, 40, src)
	busy = FALSE
	if (!done)
		return
	var/gave = fill_takers()
	if (gave > 0)
		playsound(loc, 'sound/effects/watersplash.ogg', 80, TRUE)
		user.visible_message("[user] fills up from \the [src].", "You run [round(gave)] units of water in. The tower holds [round(T.water)] more.")
	else
		to_chat(user, "Everything here is full.")

/obj/structure/rail_water/proc/nothing_to_fill(mob/living/user)
	to_chat(user, "No steam locomotive, tender or tank car that takes water stands within reach of \the [src].")

/obj/structure/rail_water/attackby(obj/item/W as obj, mob/user as mob)
	if (is_tool(W, TOOL_WRENCH))
		set_dir(turn(dir, -90))
		playsound(loc, 'sound/items/Ratchet.ogg', 50, TRUE)
		to_chat(user, "You turn \the [src].")
		return
	return ..()

/obj/structure/rail_water/tower
	name = "water tower"
	desc = "A stave tank on a trestle beside the track. It fills the steam locomotives and tenders that stop under its spout, and feeds the water cranes around it."
	icon_state = "water_tower"
	reach = 3
	layer = 4.2
	var/water = 0

/obj/structure/rail_water/tower/source()
	return src

/obj/structure/rail_water/tower/proc/add_tower_water(amount)
	var/taken = clamp(amount, 0, WATER_TOWER_MAX - water)
	water += taken
	return taken

// Fresh water close enough for the tower's own hand pump.
/obj/structure/rail_water/tower/proc/pump_water()
	for (var/turf/T in range(2, src))
		if (aqueduct_fresh_water(T))
			return T
	return null

/obj/structure/rail_water/tower/examine(mob/user)
	..()
	to_chat(user, "It holds [round(water)] of [WATER_TOWER_MAX] units of water. [pump_water() ? "Its hand pump draws from the water beside it: use the tower with nothing to fill." : "Fill it from buckets, or build it within two tiles of fresh water to use its hand pump."]")

/obj/structure/rail_water/tower/nothing_to_fill(mob/living/user)
	if (water >= WATER_TOWER_MAX)
		to_chat(user, "\The [src] is full.")
		return
	if (!pump_water())
		to_chat(user, "There is nothing to fill here, and no fresh water within two tiles for the pump. Fill \the [src] from buckets.")
		return
	user.visible_message("[user] starts working \the [src]'s pump...", "You start working the pump...")
	busy = TRUE
	var/done = do_after(user, 50, src)
	busy = FALSE
	if (!done || !pump_water())
		return
	add_tower_water(WATER_TOWER_PUMP)
	playsound(loc, 'sound/effects/watersplash.ogg', 60, TRUE)
	to_chat(user, "You pump water up into the tank. It holds [round(water)] of [WATER_TOWER_MAX] units.")

/obj/structure/rail_water/tower/attackby(obj/item/W as obj, mob/user as mob)
	if (train_water_vessel(W))
		var/poured = add_tower_water(W.reagents.get_reagent_amount("water"))
		if (poured <= 0)
			to_chat(user, "<span class = 'notice'>\The [src] is full.</span>")
			return
		W.reagents.remove_reagent("water", poured)
		playsound(loc, 'sound/effects/watersplash.ogg', 60, TRUE)
		to_chat(user, "You pour water into \the [src]. It holds [round(water)] of [WATER_TOWER_MAX] units.")
		return
	return ..()

#undef TENDER_FUEL_MAX
#undef TENDER_WATER_MAX
#undef TENDER_WAGON_WATER_MAX
#undef TENDER_SHOVEL_FUEL
#undef WATER_TOWER_MAX
#undef WATER_TOWER_PUMP
#undef WATER_CRANE_PIPE
