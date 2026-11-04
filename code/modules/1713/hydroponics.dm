// Hydroponic trays (docs/hydroponics-design.md, accepted choices H1-H6).
// A tray owns its crop as plain state: crop id, stage and a saved partial
// cycle. It never creates an /obj/structure/farming/plant, so it never starts
// the outdoor crop's recursive growth chain or touches soil rules.
//
// Each productive cycle needs 60 seconds of active-server time while the tray
// draws 5 PU of cable power and holds at least 1 N nutrient and 2 U water.
// Payment is taken once, when a cycle completes; supplies only fall at that
// point, so a tray that could pay when the cycle started can still pay at the
// end. Without power or supplies the cycle pauses and keeps its progress.
// Offline time and time spent while unpowered earn nothing.

#define HYDROPONICS_RESERVOIR 60
#define HYDROPONICS_CYCLE_TIME 600 // deciseconds of productive time per stage
#define HYDROPONICS_CYCLE_WATER 2
#define HYDROPONICS_CYCLE_NUTRIENT 1
#define HYDROPONICS_READY_STAGE 7 // planted at 1, six cycles to ready
#define HYDROPONICS_DEAD_STAGE 8
#define HYDROPONICS_POWER 5
#define HYDROPONICS_COMPOST_NUTRIENT 3
#define HYDROPONICS_FRAGILE_DRY_TIME 6000 // ten productive-clock minutes without water

/proc/hydroponics_crops()
	return list("potato", "carrot", "cabbage", "tomato", "beans", "wheat")

// Fragile crops die after a long water shortage; every other crop only pauses.
/proc/hydroponics_fragile_crops()
	return list("tomato", "beans")

/obj/structure/hydroponics_tray
	name = "hydroponics tray"
	desc = "A powered steel growing tray with a glass cover rail and a combined 60-unit reservoir. Plant potato, carrot, cabbage, tomato, bean or wheat seeds, pour in water, dissolve compost for nutrients and connect a cable. Each of six growth cycles takes a minute of power, 2 units of water and 1 unit of nutrient."
	icon = 'icons/obj/structures.dmi'
	icon_state = "kevlar_trough_empty"
	anchored = TRUE
	density = TRUE
	opacity = FALSE
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = FALSE
	powerneeded = HYDROPONICS_POWER
	var/crop = null // plant id from hydroponics_crops(), null when empty
	var/stage = 0
	var/water_units = 0
	var/nutrient_units = 0
	var/cycle_progress = 0 // saved productive deciseconds in the current cycle
	var/dry_time = 0 // fragile crops only: productive-clock deciseconds without water
	var/tmp/last_tick = 0
	var/tmp/registered = FALSE

/obj/structure/hydroponics_tray/New()
	..()
	last_tick = world.time
	update_icon()

/obj/structure/hydroponics_tray/persistence_runtime_var(key)
	return (key in list("last_tick", "registered", "powersource", "powered")) || ..(key)

/obj/structure/hydroponics_tray/after_load()
	..()
	// Restored state never earns offline progress or keeps a stale power lease.
	last_tick = world.time
	registered = FALSE
	powersource = null
	powered = FALSE
	water_units = clamp(water_units, 0, HYDROPONICS_RESERVOIR)
	nutrient_units = clamp(nutrient_units, 0, HYDROPONICS_RESERVOIR - water_units)
	cycle_progress = clamp(cycle_progress, 0, HYDROPONICS_CYCLE_TIME - 1)
	if (crop && !(crop in hydroponics_crops()))
		clear_crop()
	// The cable laid on the tray's own tile is still there; rejoin it.
	if (anchored && isturf(loc))
		for (var/obj/structure/cable/C in loc)
			powersource = C
			C.connections |= src
			break
	start_processing()
	update_icon()

/obj/structure/hydroponics_tray/Destroy()
	stop_processing()
	release_power()
	return ..()

/obj/structure/hydroponics_tray/proc/reservoir_free()
	return max(0, HYDROPONICS_RESERVOIR - water_units - nutrient_units)

/obj/structure/hydroponics_tray/proc/growing()
	return crop && stage >= 1 && stage < HYDROPONICS_READY_STAGE

/obj/structure/hydroponics_tray/proc/ready()
	return crop && stage == HYDROPONICS_READY_STAGE

/obj/structure/hydroponics_tray/proc/dead()
	return crop && stage >= HYDROPONICS_DEAD_STAGE

/obj/structure/hydroponics_tray/proc/can_pay_cycle()
	return water_units >= HYDROPONICS_CYCLE_WATER && nutrient_units >= HYDROPONICS_CYCLE_NUTRIENT

/obj/structure/hydroponics_tray/proc/start_processing()
	if (crop && !dead() && !registered)
		last_tick = world.time
		processing_objects |= src
		registered = TRUE

/obj/structure/hydroponics_tray/proc/stop_processing()
	processing_objects -= src
	registered = FALSE

/obj/structure/hydroponics_tray/proc/release_power()
	if (powersource)
		powersource.update_power(-powerneeded, 1, src)
	powered = FALSE

/obj/structure/hydroponics_tray/proc/clear_crop()
	crop = null
	stage = 0
	cycle_progress = 0
	dry_time = 0
	stop_processing()
	release_power()
	update_icon()

/obj/structure/hydroponics_tray/proc/kill_crop(reason = "dead")
	if (!crop)
		return
	stage = HYDROPONICS_DEAD_STAGE
	cycle_progress = 0
	stop_processing()
	release_power()
	visible_message(SPAN_WARNING("The [crop] in \the [src] is [reason]."))
	update_icon()

// Same outdoor weather that kills field crops; a roof or indoor area shelters the tray.
/obj/structure/hydroponics_tray/proc/weather_exposure()
	var/turf/T = get_turf(src)
	var/area/A = get_area(T)
	if (!T || !A || A.location != AREA_OUTSIDE || (locate(/obj/roof) in T))
		return null
	if (findtext(A.icon_state, "snow_storm"))
		return "frozen"
	if (findtext(A.icon_state, "sandstorm"))
		return "destroyed"
	return null

/obj/structure/hydroponics_tray/process_interval(configured_seconds = 2)
	var/elapsed = min(max(0, configured_seconds * 10), max(0, world.time - last_tick))
	last_tick = world.time
	if (persistence_active_operation)
		return
	if (gc_destroyed || gcDestroyed || !crop || dead())
		registered = FALSE
		return PROCESS_KILL
	return advance(elapsed)

// One bounded step; no catch-up loop. Returns PROCESS_KILL once nothing can change.
/obj/structure/hydroponics_tray/proc/advance(elapsed)
	var/exposure = weather_exposure()
	if (exposure)
		kill_crop(exposure)
		return PROCESS_KILL
	if (ready())
		// Ready crops stop growing and stop drawing power, but stay exposed to weather.
		if (powered)
			release_power()
		return
	if (!anchored || !isturf(loc))
		if (powered)
			release_power()
		return
	if (water_units < HYDROPONICS_CYCLE_WATER && (crop in hydroponics_fragile_crops()))
		dry_time += elapsed
		if (dry_time >= HYDROPONICS_FRAGILE_DRY_TIME)
			kill_crop("dry")
			return PROCESS_KILL
	else
		dry_time = 0
	if (!can_pay_cycle())
		if (powered)
			release_power()
		update_icon()
		return
	powered = draw_cable_power()
	if (!powered)
		update_icon()
		return
	cycle_progress += elapsed
	if (cycle_progress < HYDROPONICS_CYCLE_TIME)
		return
	// Completion-time payment: one stage per paid cycle, never more per call.
	water_units -= HYDROPONICS_CYCLE_WATER
	nutrient_units -= HYDROPONICS_CYCLE_NUTRIENT
	cycle_progress = 0
	stage++
	if (ready())
		release_power()
		visible_message(SPAN_NOTICE("The [crop] in \the [src] is ready to harvest."))
	update_icon()

/obj/structure/hydroponics_tray/update_icon()
	overlays.Cut()
	if (!crop)
		return
	var/plant_path = text2path("/obj/structure/farming/plant/[crop]")
	if (!plant_path)
		return
	var/obj/structure/farming/plant/P = plant_path
	var/state
	if (dead())
		state = "[crop]-dead"
	else if (ready())
		state = "[crop]-harvest"
	else
		state = "[crop]-grow[clamp(stage, 1, 6)]"
	var/image/I = image(initial(P.icon), state)
	I.pixel_y = 6
	overlays += I

/obj/structure/hydroponics_tray/examine(mob/user, distance)
	..(user, distance)
	to_chat(user, SPAN_NOTICE("Reservoir: [round(water_units, 0.1)] water and [round(nutrient_units, 0.1)] nutrient of [HYDROPONICS_RESERVOIR] units."))
	if (!crop)
		to_chat(user, SPAN_NOTICE("Nothing is planted. It accepts potato, carrot, cabbage, tomato, bean or wheat seeds."))
		return
	if (dead())
		to_chat(user, SPAN_WARNING("The [crop] is dead. Clear it with a knife, hatchet or scythe."))
	else if (ready())
		to_chat(user, SPAN_NOTICE("The [crop] is ready to harvest."))
	else
		to_chat(user, SPAN_NOTICE("The [crop] has completed [stage - 1] of 6 growth cycles ([round(cycle_progress / 10)] of 60 seconds into the next)."))
		if (!powersource)
			to_chat(user, SPAN_WARNING("Growth is paused: connect a cable carrying [HYDROPONICS_POWER] PU."))
		else if (!can_pay_cycle())
			to_chat(user, SPAN_WARNING("Growth is paused: each cycle needs [HYDROPONICS_CYCLE_WATER] water and [HYDROPONICS_CYCLE_NUTRIENT] nutrient."))
		else if (!powered)
			to_chat(user, SPAN_WARNING("Growth is paused until the cable can supply [HYDROPONICS_POWER] PU."))
		if ((crop in hydroponics_fragile_crops()) && water_units < HYDROPONICS_CYCLE_WATER)
			to_chat(user, SPAN_WARNING("The [crop] is wilting and will die if it stays without water."))

/obj/structure/hydroponics_tray/attack_hand(mob/living/human/H)
	if (ready())
		harvest(H)
		return
	examine(H)

/obj/structure/hydroponics_tray/proc/is_harvest_tool(obj/item/W)
	return istype(W, /obj/item/weapon/material/hatchet) || istype(W, /obj/item/weapon/attachment/bayonet) || istype(W, /obj/item/weapon/material/kitchen/utensil/knife) || istype(W, /obj/item/weapon/material/scythe)

// Harvest authority is retired before any output is created, so a repeated
// request emits nothing. Accepted yield: two seeds and one to three produce.
/obj/structure/hydroponics_tray/proc/harvest(mob/user, produce_count = null)
	if (!ready())
		return FALSE
	var/turf/T = get_turf(src)
	if (!T)
		return FALSE
	var/harvested = crop
	clear_crop()
	var/seed_path = text2path("/obj/item/stack/farming/seeds/[harvested]")
	var/produce_path = text2path("/obj/item/weapon/reagent_containers/food/snacks/grown/[harvested]")
	if (seed_path)
		new seed_path(T, 2)
	if (isnull(produce_count))
		produce_count = rand(1, 3)
	if (produce_path)
		for (var/i = 1, i <= produce_count, i++)
			new produce_path(T)
	if (user)
		to_chat(user, SPAN_NOTICE("You harvest the [harvested] from \the [src]."))
	return TRUE

/obj/structure/hydroponics_tray/proc/plant_seed(mob/user, obj/item/stack/farming/seeds/S)
	if (crop)
		to_chat(user, SPAN_WARNING("\The [src] already has a crop. Harvest or clear it first."))
		return FALSE
	if (!(S.plant in hydroponics_crops()))
		to_chat(user, SPAN_WARNING("\The [src] only grows potato, carrot, cabbage, tomato, bean or wheat seeds."))
		return FALSE
	if (!anchored)
		to_chat(user, SPAN_WARNING("Fasten \the [src] with a wrench first."))
		return FALSE
	var/planted = S.plant
	if (!S.use(1))
		return FALSE
	crop = planted
	stage = 1
	cycle_progress = 0
	dry_time = 0
	start_processing()
	update_icon()
	to_chat(user, SPAN_NOTICE("You plant [planted] in \the [src]."))
	return TRUE

// Only water is taken from the donor; anything else stays in it.
/obj/structure/hydroponics_tray/proc/fill_water(mob/user, obj/item/weapon/reagent_containers/C)
	var/available = C.reagents ? C.reagents.get_reagent_amount("water") : 0
	if (available <= 0)
		to_chat(user, SPAN_WARNING("\The [C] has no water in it."))
		return 0
	var/space = reservoir_free()
	if (space <= 0)
		to_chat(user, SPAN_WARNING("\The [src]'s reservoir is full."))
		return 0
	C.reagents.remove_reagent("water", min(available, space))
	// Credit only what actually left the donor.
	var/accepted = max(0, min(space, available - C.reagents.get_reagent_amount("water")))
	water_units += accepted
	C.update_icon()
	to_chat(user, SPAN_NOTICE("You pour [round(accepted, 0.1)] units of water into \the [src]."))
	return accepted

/obj/structure/hydroponics_tray/proc/add_compost(mob/user, obj/item/I)
	if (reservoir_free() < HYDROPONICS_COMPOST_NUTRIENT)
		to_chat(user, SPAN_WARNING("\The [src]'s reservoir has no room for more nutrient."))
		return FALSE
	nutrient_units += HYDROPONICS_COMPOST_NUTRIENT
	if (user)
		user.drop_from_inventory(I)
	qdel(I)
	to_chat(user, SPAN_NOTICE("You dissolve the compost into \the [src]'s reservoir, adding [HYDROPONICS_COMPOST_NUTRIENT] units of nutrient."))
	return TRUE

/obj/structure/hydroponics_tray/attackby(obj/item/W, mob/living/human/H)
	if (istype(W, /obj/item/stack/farming/seeds))
		plant_seed(H, W)
		return TRUE
	if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/poo/fertilizer))
		add_compost(H, W)
		return TRUE
	if (istype(W, /obj/item/weapon/reagent_containers) && !istype(W, /obj/item/weapon/reagent_containers/food/snacks) && W.is_open_container())
		fill_water(H, W)
		return TRUE
	if (is_harvest_tool(W) && crop)
		if (ready())
			harvest(H)
		else
			to_chat(H, SPAN_WARNING("You clear the [dead() ? "dead " : ""][crop] from \the [src]."))
			clear_crop()
		return TRUE
	if (istype(W, /obj/item/stack/cable_coil))
		if (!anchored)
			to_chat(H, SPAN_WARNING("Fasten \the [src] with a wrench first."))
			return TRUE
		connect_cable(H, W)
		start_processing()
		return TRUE
	if (istype(W, /obj/item/weapon/wrench))
		release_power()
		wrench_action(H)
		return TRUE
	if (istype(W, /obj/item/weapon/hammer))
		if (crop)
			to_chat(H, SPAN_WARNING("Clear the crop before dismantling \the [src]."))
			return TRUE
		if (powersource)
			to_chat(H, SPAN_WARNING("Remove the cables first."))
			return TRUE
		// Half refund: two of four steel sheets and one of two glass sheets. The reservoir drains.
		hammer_action(H, W, 200, list(/obj/item/stack/material/steel, /obj/item/stack/material/glass), list(2, 1))
		return TRUE
	return ..()

// Crafted from four steel sheets; two glass sheets and one length of cable complete it.
/obj/structure/hydroponics_frame
	name = "hydroponics tray frame"
	desc = "The steel frame of a hydroponics tray. Fit two glass sheets, then one length of cable, to finish it."
	icon = 'icons/obj/structures.dmi'
	icon_state = "kevlar_trough_empty"
	alpha = 170
	anchored = TRUE
	density = TRUE
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = FALSE
	var/glazed = FALSE

/obj/structure/hydroponics_frame/examine(mob/user, distance)
	..(user, distance)
	to_chat(user, SPAN_NOTICE(glazed ? "It needs one length of cable." : "It needs two glass sheets."))

/obj/structure/hydroponics_frame/attackby(obj/item/W, mob/living/human/H)
	if (!glazed && istype(W, /obj/item/stack/material/glass) && W.type == /obj/item/stack/material/glass)
		var/obj/item/stack/material/glass/G = W
		if (!G.can_use(2) || !G.use(2))
			to_chat(H, SPAN_WARNING("You need two glass sheets."))
			return TRUE
		glazed = TRUE
		to_chat(H, SPAN_NOTICE("You fit the glass panels to \the [src]."))
		return TRUE
	if (glazed && istype(W, /obj/item/stack/cable_coil))
		var/obj/item/stack/cable_coil/C = W
		if (!C.can_use(1) || !C.use(1))
			return TRUE
		var/obj/structure/hydroponics_tray/T = new(loc)
		T.anchored = anchored
		T.dir = dir
		to_chat(H, SPAN_NOTICE("You wire the pump and lights, finishing \the [T]."))
		qdel(src)
		return TRUE
	if (istype(W, /obj/item/weapon/wrench))
		wrench_action(H)
		return TRUE
	if (istype(W, /obj/item/weapon/hammer))
		hammer_action(H, W, 100, glazed ? list(/obj/item/stack/material/steel, /obj/item/stack/material/glass) : list(/obj/item/stack/material/steel), glazed ? list(2, 1) : list(2))
		return TRUE
	return ..()

#undef HYDROPONICS_RESERVOIR
#undef HYDROPONICS_CYCLE_TIME
#undef HYDROPONICS_CYCLE_WATER
#undef HYDROPONICS_CYCLE_NUTRIENT
#undef HYDROPONICS_READY_STAGE
#undef HYDROPONICS_DEAD_STAGE
#undef HYDROPONICS_POWER
#undef HYDROPONICS_COMPOST_NUTRIENT
#undef HYDROPONICS_FRAGILE_DRY_TIME
