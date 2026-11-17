// The depot (docs/trains.md#the-depot). Structures beside the track that
// turn an engine round quickly: a coaling stage fills bunkers and fireboxes
// from its heap, a sand bin fills sandboxes. Both are loaded by hand and
// serve what stands within reach, like a water crane (train_water.dm).

#define COAL_STAGE_MAX 6000 // fuel, in firebox units: four hundred pieces of coal
#define COAL_STAGE_TIME 40
#define SAND_BIN_MAX 200
#define SAND_BIN_TIME 20
#define TENDER_BUNKER_MAX 1500 // TENDER_FUEL_MAX (train_water.dm)

/obj/structure/rail_depot
	name = "depot stage"
	icon = 'icons/obj/vehicles/rail_water.dmi'
	pixel_x = -16
	pixel_y = -16
	anchored = TRUE
	density = TRUE
	opacity = FALSE
	flammable = FALSE
	not_movable = TRUE
	layer = 3.4
	var/reach = 2 // tiles to the rail tile of what it serves
	var/tmp/busy = FALSE

/obj/structure/rail_depot/on_runtime_spawn()
	..()
	update_icon()

/obj/structure/rail_depot/after_load()
	..()
	busy = FALSE
	update_icon()

/obj/structure/rail_depot/persistence_runtime_var(key)
	return key == "busy" || ..(key)

/////////////////////////////////////////////////////////////////////////////
// Coaling stage

/obj/structure/rail_depot/coal_stage
	name = "coaling stage"
	desc = "A raised timber stage beside the track, with a heap of fuel and a chute. It fills the tenders and fireboxes of the steam locomotives standing next to it."
	icon_state = "coal_stage_empty"
	var/fuel = 0

/obj/structure/rail_depot/coal_stage/update_icon()
	icon_state = fuel >= COAL_STAGE_MAX / 2 ? "coal_stage_full" : (fuel > 0 ? "coal_stage" : "coal_stage_empty")

/obj/structure/rail_depot/coal_stage/examine(mob/user)
	..()
	to_chat(user, "Its heap is [round(100 * fuel / COAL_STAGE_MAX)]% of what it can hold. Load it with coal or wood. Stop a steam locomotive or tender beside it and use it with an empty hand to fill up.")

// Loads the heap from a pile. Returns the pieces taken.
/obj/structure/rail_depot/coal_stage/proc/load_fuel(obj/item/W)
	var/value = steam_fuel_value(W)
	if (!value)
		return 0
	var/room = round((COAL_STAGE_MAX - fuel) / value)
	if (room < 1)
		return 0
	var/units = 1
	if (istype(W, /obj/item/stack))
		var/obj/item/stack/S = W
		units = min(S.amount, room)
		fuel += units * value
		S.use(units)
	else
		fuel += value
		qdel(W)
	update_icon()
	return units

// The bunkers and fireboxes within reach, tenders first.
/obj/structure/rail_depot/coal_stage/proc/takers()
	var/list/tenders = list()
	var/list/engines = list()
	for (var/obj/structure/trains/TR in range(reach, src))
		var/obj/structure/trains/platform/store = TR.tender_store()
		if (istype(store))
			tenders |= store
			continue
		var/obj/structure/trains/locomotive/coal/E = istype(TR, /obj/structure/trains/locomotive/coal) ? TR : TR.unit_engine()
		if (istype(E))
			engines |= E
	return tenders + engines

// Fills what stands within reach. Returns the fuel that went out.
/obj/structure/rail_depot/coal_stage/proc/fill_takers()
	. = 0
	for (var/obj/structure/trains/taker in takers())
		if (fuel <= 0)
			break
		var/gave = 0
		if (istype(taker, /obj/structure/trains/locomotive/coal))
			var/obj/structure/trains/locomotive/coal/E = taker
			E.boiler_tick()
			gave = min(fuel, max(0, E.max_fuel - E.fuel))
			E.fuel += gave
		else
			var/obj/structure/trains/platform/P = taker
			gave = min(fuel, max(0, TENDER_BUNKER_MAX - P.tender_fuel))
			P.tender_fuel += gave
		fuel -= gave
		. += gave
	if (.)
		update_icon()

/obj/structure/rail_depot/coal_stage/attackby(obj/item/W as obj, mob/user as mob)
	if (steam_fuel_value(W))
		if (!load_fuel(W))
			to_chat(user, "<span class = 'notice'>\The [src] is full.</span>")
			return
		to_chat(user, "You tip the fuel onto \the [src]. Its heap is [round(100 * fuel / COAL_STAGE_MAX)]% of what it can hold.")
		return
	return ..()

/obj/structure/rail_depot/coal_stage/attack_hand(mob/living/user as mob)
	if (!istype(user) || busy)
		return
	if (!takers().len)
		to_chat(user, "No steam locomotive or tender stands within reach of \the [src].")
		return
	if (fuel <= 0)
		to_chat(user, "<span class = 'warning'>\The [src] is empty. Load it with coal or wood.</span>")
		return
	user.visible_message("[user] opens \the [src]'s chute...", "You open the chute and start running fuel down...")
	busy = TRUE
	var/done = do_after(user, COAL_STAGE_TIME, src)
	busy = FALSE
	if (!done)
		return
	var/gave = fill_takers()
	if (gave > 0)
		playsound(loc, 'sound/effects/shovelling.ogg', 80, TRUE)
		user.visible_message("[user] coals up from \the [src].", "Fuel rattles down the chute. The heap is [round(100 * fuel / COAL_STAGE_MAX)]% of what it can hold.")
	else
		to_chat(user, "Everything here is full.")

/////////////////////////////////////////////////////////////////////////////
// Sand bin

/obj/structure/rail_depot/sand_bin
	name = "sand bin"
	desc = "A covered bin of dry sand beside the track. It fills the sandboxes of the locomotives standing next to it."
	icon_state = "sand_bin_empty"
	var/sand = 0

/obj/structure/rail_depot/sand_bin/update_icon()
	icon_state = sand > 0 ? "sand_bin" : "sand_bin_empty"

/obj/structure/rail_depot/sand_bin/examine(mob/user)
	..()
	to_chat(user, "It holds [sand] of [SAND_BIN_MAX] charges of sand. Load it with sand. Stop a locomotive beside it and use it with an empty hand to fill the sandbox.")

/obj/structure/rail_depot/sand_bin/proc/load_sand(obj/item/stack/ore/glass/pile)
	if (!istype(pile))
		return 0
	var/taken = min(SAND_BIN_MAX - sand, pile.amount)
	if (taken <= 0)
		return 0
	sand += taken
	pile.use(taken)
	update_icon()
	return taken

/obj/structure/rail_depot/sand_bin/proc/takers()
	var/list/found = list()
	for (var/obj/structure/trains/TR in range(reach, src))
		var/obj/structure/trains/locomotive/E = istype(TR, /obj/structure/trains/locomotive) ? TR : TR.unit_engine()
		if (istype(E))
			found |= E
	return found

// Fills the sandboxes within reach. Returns the charges that went out.
/obj/structure/rail_depot/sand_bin/proc/fill_takers()
	. = 0
	for (var/obj/structure/trains/locomotive/E in takers())
		var/gave = min(sand, E.sand_room())
		if (gave <= 0)
			continue
		E.sand += gave
		sand -= gave
		. += gave
	if (.)
		update_icon()

/obj/structure/rail_depot/sand_bin/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/stack/ore/glass))
		if (!load_sand(W))
			to_chat(user, "<span class = 'notice'>\The [src] is full.</span>")
			return
		to_chat(user, "You tip the sand into \the [src]. It holds [sand] of [SAND_BIN_MAX] charges.")
		return
	return ..()

/obj/structure/rail_depot/sand_bin/attack_hand(mob/living/user as mob)
	if (!istype(user) || busy)
		return
	if (!takers().len)
		to_chat(user, "No locomotive stands within reach of \the [src].")
		return
	if (sand <= 0)
		to_chat(user, "<span class = 'warning'>\The [src] is empty. Load it with sand.</span>")
		return
	user.visible_message("[user] starts filling a sandbox from \the [src]...", "You start carrying sand across to the sandbox...")
	busy = TRUE
	var/done = do_after(user, SAND_BIN_TIME, src)
	busy = FALSE
	if (!done)
		return
	var/gave = fill_takers()
	if (gave > 0)
		to_chat(user, "You put [gave] charge\s of sand in. \The [src] holds [sand] more.")
	else
		to_chat(user, "Every sandbox here is full.")

#undef COAL_STAGE_MAX
#undef COAL_STAGE_TIME
#undef SAND_BIN_MAX
#undef SAND_BIN_TIME
#undef TENDER_BUNKER_MAX
