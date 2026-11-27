// Industrial milling (docs/milling.md): the Industrial-era gold mill.
//
// Each machine is a hopper machine on the water stamp mill's frame: a turning
// mill wheel, treadwheel, horse gin or windmill next to it drives it, it works
// one load every few seconds while it has feed, water and drive, and it stops
// when any of those runs out or its output tile fills.
//
// - Trommel: screens pay dirt into a sluice beside it, so a sluice washes as
//   fast as people can shovel.
// - Amalgamator drum: crushed ore, quicksilver and water to amalgam (80%).
//   It loses quicksilver every load; a mercury separator beside it saves most.
// - Shaking table: crushed ore and water to clean metal ore (65%), no
//   quicksilver at all.
// - Amalgamation plates: fitted to a stamp mill and charged with quicksilver,
//   the mill gives amalgam straight from lode ore (50%).

#define DRUM_RECOVERY 0.8
#define DRUM_LOSS 0.2
#define DRUM_SEPARATED_LOSS 0.03
#define TABLE_RECOVERY 0.65
#define PLATES_RECOVERY 0.5
#define PLATES_LOSS 0.05

// Shared by the milling machines.
/obj/structure/drill/stamp_mill/water/mill
	name = "milling machine"
	icon = 'icons/obj/milling.dmi'
	water_capacity = 60
	water_per_use = 10
	takes_plates = FALSE
	var/node = "industrial_milling"
	var/feed_name = "crushed ore"

/obj/structure/drill/stamp_mill/water/mill/hopper_accepts(obj/item/I)
	return istype(I, /obj/item/stack/ore/crushed_ore)

/obj/structure/drill/stamp_mill/water/mill/examine(mob/user, distance)
	..(user, distance)
	station_water_examine(user)

/obj/structure/drill/stamp_mill/water/mill/attackby(obj/item/W, mob/living/human/H)
	if (istype(H) && station_water_pour(W, H))
		return
	return ..()

/obj/structure/drill/stamp_mill/water/mill/attack_hand(mob/living/human/H)
	if (!active && istype(H) && !crafting_node_allowed_or_warn(H, node))
		return
	return ..()

// Check or take the water for one load, or return FALSE with the reason set.
/obj/structure/drill/stamp_mill/water/mill/proc/mill_water(check_only = FALSE)
	if (check_only ? station_has_water() : station_take_water(null))
		return TRUE
	mill_stop_reason = "it has run out of water"
	return FALSE

// One unit of hopper feed, used up.
/obj/structure/drill/stamp_mill/water/mill/proc/take_feed()
	var/obj/item/stack/S = loaded_stone()
	if (!S)
		return null
	. = S.type
	S.amount--
	if (S.amount <= 0)
		qdel(S)

//////////////////////////////////////////////////////////////////////////////
// Trommel

/obj/structure/drill/stamp_mill/water/mill/trommel
	name = "trommel"
	desc = "A long perforated iron drum turning on a timber frame. Set a sluice box beside it, drive it with a mill wheel, treadwheel, horse gin or windmill, and load up to fifty loads of pay dirt: it screens the gravel into the sluice one load every four seconds, so the sluice washes as fast as you can dig. It uses the sluice's quicksilver if there is any."
	icon_state = "trommel"
	idle_state = "trommel"
	active_state = "trommel_on"
	crush_interval = 2
	feed_name = "pay dirt"

/obj/structure/drill/stamp_mill/water/mill/trommel/hopper_accepts(obj/item/I)
	return istype(I, /obj/item/stack/ore/pay_dirt)

/obj/structure/drill/stamp_mill/water/mill/trommel/proc/fed_sluice()
	for (var/obj/structure/placer_washer/sluice/S in range(1, src))
		if (S != src && !S.washing)
			return S
	return null

/obj/structure/drill/stamp_mill/water/mill/trommel/stamp_one_stone(roll = null)
	var/obj/structure/placer_washer/sluice/S = fed_sluice()
	if (!S)
		mill_stop_reason = "there is no free sluice box beside it"
		return FALSE
	var/turf/T = get_turf(S)
	if (!T)
		return FALSE
	var/stack_count = 0
	for (var/obj/item/stack/stack in T)
		if (++stack_count >= output_stack_limit)
			mill_stop_reason = "clear the sluice output tile and restart it"
			return FALSE
	var/obj/item/stack/ore/pay_dirt/P = loaded_stone()
	if (!P || !mill_water())
		return FALSE
	var/grade = P.grade
	take_feed()
	var/mercury = S.mercury_charged()
	var/list/found = pay_dirt_wash(grade, "sluice", mercury)
	if (mercury)
		S.spend_mercury()
	pay_dirt_output(found, T)
	return TRUE

//////////////////////////////////////////////////////////////////////////////
// Amalgamator drum and mercury separator

/obj/structure/drill/stamp_mill/water/mill/drum
	name = "amalgamator drum"
	desc = "A squat cast-iron pan with mullers turning in it, the Washoe way of working silver and gold ore. Pour in quicksilver and water, load up to fifty loads of crushed ore and drive it: it grinds one load into amalgam every six seconds, far better than an arrastra. It loses some quicksilver with every load; a mercury separator beside it saves most of that."
	icon_state = "amalgamator_drum"
	idle_state = "amalgamator_drum"
	active_state = "amalgamator_drum_on"
	water_per_use = 15

/obj/structure/drill/stamp_mill/water/mill/drum/New()
	..()
	if (!reagents)
		create_reagents(30)

/obj/structure/drill/stamp_mill/water/mill/drum/proc/separated()
	return locate(/obj/structure/mercury_separator) in range(1, src)

/obj/structure/drill/stamp_mill/water/mill/drum/proc/loss()
	return separated() ? DRUM_SEPARATED_LOSS : DRUM_LOSS

/obj/structure/drill/stamp_mill/water/mill/drum/examine(mob/user, distance)
	..(user, distance)
	to_chat(user, SPAN_NOTICE("It holds [round(reagents.get_reagent_amount("mercury"), 0.1)] units of quicksilver.[separated() ? " A mercury separator catches what it would lose." : ""]"))

/obj/structure/drill/stamp_mill/water/mill/drum/attackby(obj/item/W, mob/living/human/H)
	if (istype(H) && pour_mercury_into(src, W, H))
		return
	return ..()

/obj/structure/drill/stamp_mill/water/mill/drum/stamp_one_stone(roll = null)
	var/obj/item/stack/ore/crushed_ore/C = loaded_stone()
	if (!C)
		return FALSE
	var/spend = loss()
	if (reagents.get_reagent_amount("mercury") < AMALGAM_WET_MERCURY + spend)
		mill_stop_reason = "its quicksilver is spent"
		return FALSE
	if (!mill_water(TRUE))
		return FALSE
	var/turf/T = get_turf(src)
	if (!T.deposit_small_resource(/obj/item/stack/ore/tailings/amalgam, 1, output_stack_limit))
		return FALSE
	if (!mill_water())
		return FALSE
	var/metal = C.metal_type
	take_feed()
	finish_amalgam_load(T, metal, spend, DRUM_RECOVERY, roll)
	return TRUE

/obj/structure/mercury_separator
	name = "mercury separator"
	desc = "A wide shallow iron settler with a slow stirring arm. Set beside an amalgamator drum, it lets the quicksilver and amalgam carried off in the slime settle out, so the drum loses far less."
	icon = 'icons/obj/milling.dmi'
	icon_state = "mercury_separator"
	anchored = TRUE
	density = TRUE
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = FALSE

//////////////////////////////////////////////////////////////////////////////
// Shaking table

/obj/structure/drill/stamp_mill/water/mill/table
	name = "shaking table"
	desc = "A riffled deck shaken end to end under a sheet of water, which sorts crushed ore by weight into clean metal and waste. Pour in water, load up to fifty loads of crushed ore and drive it: one load every four seconds, no quicksilver needed."
	icon_state = "shaking_table"
	idle_state = "shaking_table"
	active_state = "shaking_table_on"
	crush_interval = 2

/obj/structure/drill/stamp_mill/water/mill/table/stamp_one_stone(roll = null)
	var/obj/item/stack/ore/crushed_ore/C = loaded_stone()
	if (!C)
		return FALSE
	if (!mill_water(TRUE))
		return FALSE
	var/turf/T = get_turf(src)
	if (!T.deposit_small_resource(/obj/item/stack/ore/tailings, 1, output_stack_limit))
		return FALSE
	if (!mill_water())
		return FALSE
	var/metal = C.metal_type
	take_feed()
	if (isnull(roll))
		roll = rand(1, 1000) / 10
	if (roll <= LODE_METAL * TABLE_RECOVERY * 100)
		spawn_stack(metal, T, 1)
	return TRUE

//////////////////////////////////////////////////////////////////////////////
// Amalgamation plates on a stamp mill

/obj/item/amalgamation_plates
	name = "amalgamation plates"
	desc = "Copper plates silvered with quicksilver. Fit them under a stamp mill's mortar and charge the mill with quicksilver: the gold and silver in the stamped ore stick to them as amalgam."
	icon = 'icons/obj/milling.dmi'
	icon_state = "amalgamation_plates"
	w_class = ITEM_SIZE_NORMAL
	flags = CONDUCT
	value = 15

/obj/structure/drill/stamp_mill/var/plates = FALSE
/obj/structure/drill/stamp_mill/var/takes_plates = TRUE
/obj/structure/drill/stamp_mill/var/plates_overlay = "plates_overlay_electric"
/obj/structure/drill/stamp_mill/water
	plates_overlay = "plates_overlay_water"

/obj/structure/drill/stamp_mill/proc/update_plates_overlay()
	overlays.Cut()
	if (plates)
		overlays += image('icons/obj/milling.dmi', plates_overlay)

/obj/structure/drill/stamp_mill/update_icon()
	..()
	update_plates_overlay()

/obj/structure/drill/stamp_mill/proc/plate_mercury()
	return reagents ? reagents.get_reagent_amount("mercury") : 0

/obj/structure/drill/stamp_mill/examine(mob/user, distance)
	..(user, distance)
	if (plates)
		to_chat(user, SPAN_NOTICE("Amalgamation plates are fitted, charged with [round(plate_mercury(), 0.1)] units of quicksilver."))

/obj/structure/drill/stamp_mill/attackby(obj/item/W, mob/living/human/H)
	if (!istype(H))
		return ..()
	if (istype(W, /obj/item/amalgamation_plates) && takes_plates)
		if (plates)
			to_chat(H, SPAN_NOTICE("\The [src] already has plates fitted."))
			return
		if (!crafting_node_allowed_or_warn(H, "industrial_milling"))
			return
		H.drop_from_inventory(W)
		qdel(W)
		plates = TRUE
		if (!reagents)
			create_reagents(20)
		update_icon()
		to_chat(H, SPAN_NOTICE("You fit the amalgamation plates under the mortar of \the [src]. Charge it with quicksilver."))
		return
	if (plates && pour_mercury_into(src, W, H))
		return
	return ..()

/obj/structure/drill/stamp_mill/stamp_one_stone(roll = null)
	var/obj/item/stack/S = loaded_stone()
	var/crushed = lode_crushed_type(S)
	if (!plates || !crushed || plate_mercury() < AMALGAM_WET_MERCURY + PLATES_LOSS)
		return ..()
	var/turf/T = get_turf(src)
	if (!T.deposit_small_resource(/obj/item/stack/ore/tailings/amalgam, 1, output_stack_limit))
		return FALSE
	var/obj/item/stack/ore/crushed_ore/sample = crushed
	var/metal = initial(sample.metal_type)
	S.amount--
	if (S.amount <= 0)
		qdel(S)
	finish_amalgam_load(T, metal, PLATES_LOSS, PLATES_RECOVERY, roll)
	return TRUE

/obj/structure/drill/stamp_mill/proc/finish_amalgam_load(turf/T, metal, spend, recovery, roll)
	reagents.remove_reagent("mercury", spend)
	river_mercury_spill(T, spend)
	if (isnull(roll))
		roll = rand(1, 1000) / 10
	if (roll <= LODE_METAL * recovery * 100)
		reagents.remove_reagent("mercury", AMALGAM_WET_MERCURY)
		spawn_stack(amalgam_type_for(metal), T, 1)

// Pours quicksilver from an open container into A. TRUE when handled.
/proc/pour_mercury_into(atom/A, obj/item/W, mob/living/human/H)
	var/obj/item/weapon/reagent_containers/C = W
	if (!istype(C) || !C.is_open_container() || !C.reagents || C.reagents.get_reagent_amount("mercury") <= 0 || !A.reagents)
		return FALSE
	var/amount = min(A.reagents.get_free_space(), C.reagents.get_reagent_amount("mercury"))
	if (amount <= 0)
		to_chat(H, SPAN_NOTICE("\The [A] holds all the quicksilver it can."))
		return TRUE
	C.reagents.remove_reagent("mercury", amount)
	A.reagents.add_reagent("mercury", amount)
	to_chat(H, SPAN_NOTICE("You pour [amount] units of quicksilver into \the [A]."))
	return TRUE

#undef DRUM_LOSS
#undef DRUM_SEPARATED_LOSS
#undef PLATES_LOSS
