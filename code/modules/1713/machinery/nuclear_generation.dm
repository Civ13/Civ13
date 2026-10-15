// Abstract gameplay machinery. No global radiation API or ore inheritance.
// Uranium acquisition and paid processing remain subject to exact-head acceptance.
/obj/item/stack/reactor_fuel
	name = "sealed reactor fuel cartridge"
	desc = "A sealed, finite fuel cartridge produced from one unit of uranium ore."
	icon = 'icons/obj/mining.dmi'
	icon_state = "ore_uranium"
	amount = 1
	max_amount = 10
	var/energy_per_cartridge = 1800 // PU seconds, prepaid in one-second intervals.

/obj/structure/civ_generator/nuclear
	name = "controlled reactor generator"
	desc = "A finite-fuel generator with coolant, controls and maintenance. Heat is local; this machine never changes global radiation."
	icon = 'icons/obj/engines32.dmi'
	icon_state = "reactor_3"
	var/fuel_energy = 0
	var/coolant = 0
	var/heat = 0 // abstract 0-100 gameplay scale, not a physical temperature.
	var/wear = 0
	var/control_setting = 20 // low 20 PU or high 60 PU; off inserts controls.

/obj/structure/civ_generator/nuclear/rated_output()
	if (heat >= 80 || wear >= 120 || coolant < 1)
		return 0
	return min(control_setting == 60 ? 60 : 20, max(0, fuel_energy))

/obj/structure/civ_generator/nuclear/after_load()
	..()
	fuel_energy = clamp(fuel_energy, 0, 18000)
	coolant = clamp(coolant, 0, 100)
	heat = clamp(heat, 0, 100)
	wear = clamp(wear, 0, 120)
	control_setting = control_setting == 60 ? 60 : 20

/obj/structure/civ_generator/nuclear/settle_generation()
	if (retired || output_epoch == round(world.time / 10))
		return
	// No catch-up cooling, fuel consumption or hazard pulses after scheduler lag.
	heat = max(0, min(100, heat) - 1)
	fuel_energy = clamp(fuel_energy, 0, 18000)
	coolant = clamp(coolant, 0, 100)
	wear = clamp(wear, 0, 120)
	..()
	if (output_power > 0)
		fuel_energy -= output_power
		coolant--
		wear++
		heat = min(100, heat + (control_setting == 60 ? 3 : 1))
	if (heat >= 80 || wear >= 120 || coolant < 1 || fuel_energy <= 0)
		stop_generation()
	if (heat >= 80 && isturf(loc))
		var/targets = 0
		for (var/mob/living/human/H in range(1, src))
			if (local_heat_target(H))
				H.take_overall_damage(0, 2)
				if (++targets >= 8)
					break
	if (powersource)
		powersource.rebuild_supply()

/obj/structure/civ_generator/nuclear/proc/local_heat_target(mob/living/human/H)
	return H && isturf(H.loc) && isturf(loc) && H.z == z && get_dist(src, H) <= 1 && get_area(H) == get_area(src)

/obj/structure/civ_generator/nuclear/examine(mob/user)
	..()
	to_chat(user, "Fuel: [fuel_energy]/18000 PU s. Coolant: [coolant]/100. Heat: [heat]/100. Wear: [wear]/120. Setting: [control_setting] PU.")

/obj/structure/civ_generator/nuclear/attackby(obj/item/W, mob/user)
	if (enabled)
		to_chat(user, "Switch the generator off before fuel, coolant or maintenance work.")
		return
	if (istype(W, /obj/item/stack/reactor_fuel))
		var/obj/item/stack/reactor_fuel/F = W
		var/energy = clamp(F.energy_per_cartridge, 0, 1800)
		if (heat >= 40 || energy <= 0 || fuel_energy + energy > 18000 || F.amount < 1)
			return
		fuel_energy += energy
		F.use(1)
		return
	if (W.reagents && W.reagents.get_reagent_amount("water") >= 1 && coolant < 100)
		var/transfer = min(100 - coolant, W.reagents.get_reagent_amount("water"))
		W.reagents.remove_reagent("water", transfer)
		coolant += transfer
		return
	if (istype(W, /obj/item/stack/material/steel) && wear > 0 && heat < 40)
		var/obj/item/stack/material/steel/S = W
		if (S.amount >= 1)
			S.use(1)
			wear = max(0, wear - 30)
		return
	..()

/obj/structure/civ_generator/nuclear/verb/set_output()
	set name = "Set reactor output"
	set src in oview(1)
	if (enabled || heat >= 40)
		return
	control_setting = control_setting == 20 ? 60 : 20
	to_chat(usr, "Reactor output set to [control_setting] PU while off.")

/obj/structure/reactor_fuel_processor
	name = "reactor fuel processor"
	desc = "Seals one paid uranium ore unit into one finite reactor cartridge. Requires Modern Nuclear Power research and crafting 105. Raw inputs remain hazardous until processed."
	icon = 'icons/obj/computers.dmi'
	icon_state = "solar_screen"
	anchored = TRUE
	density = TRUE
	var/tmp/fuel_processing = FALSE
	var/tmp/fuel_retired = FALSE

/obj/structure/reactor_fuel_processor/proc/processing_wait(mob/living/human/H)
	return do_after(H, 100, src)

/obj/structure/reactor_fuel_processor/attackby(obj/item/W, mob/user)
	if (!istype(W, /obj/item/stack/ore/uranium))
		return ..()
	var/obj/item/stack/ore/uranium/U = W
	var/mob/living/human/H = user
	if (fuel_processing || fuel_retired || U.uranium_extracting || U.uranium_retired || U.amount < 1 || !isturf(loc) || !civ_generation_can_build(H, type) || !(U.loc == H || isturf(U.loc)) || get_dist(H, src) > 1 || get_dist(U, src) > 1)
		return
	fuel_processing = TRUE
	U.uranium_extracting = TRUE
	var/atom/input_loc = U.loc
	var/atom/actor_loc = H.loc
	var/atom/machine_loc = loc
	if (processing_wait(H))
		if (!fuel_retired && loc == machine_loc && H.loc == actor_loc && U.loc == input_loc && !U.uranium_retired && U.amount >= 1 && get_dist(H, src) <= 1 && get_dist(U, src) <= 1 && civ_generation_can_build(H, type))
			if (U.use(1))
				new /obj/item/stack/reactor_fuel(get_turf(src))
	if (U)
		U.uranium_extracting = FALSE
	fuel_processing = FALSE

/obj/structure/reactor_fuel_processor/persistence_runtime_var(key)
	return (key in list("fuel_processing", "fuel_retired")) || ..()

/obj/structure/reactor_fuel_processor/Destroy()
	fuel_retired = TRUE
	return ..()

/obj/structure/reactor_fuel_processor/Del()
	fuel_retired = TRUE
	..()
