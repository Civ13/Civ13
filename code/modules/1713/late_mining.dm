// Late mining (docs/late_mining.md): the hydraulic monitor, which blasts a
// river bank into pay dirt and leaves it dead gravel for good, and the cyanide
// vat, which leaches the last gold out of old tailings. Both foul the river.

#define MONITOR_PAY_DIRT 6 // loads from one stripped bank tile
#define MONITOR_TIME 60
#define MONITOR_SILT 2 // river foul load from one stripped tile
#define CYANIDE_AGE 5 // Early Modern (1903)
#define VAT_CYANIDE_PER_LOAD 1
#define VAT_ZINC_LOADS 10 // loads one zinc sheet precipitates
#define VAT_RECOVERY 15 // percent chance a tailings load gives a gold ore
#define VAT_WASH_TIME 50

// A pulse of foul load into the river reach next to T, or ground pollution
// where there is none.
/proc/river_foul_dump(turf/T, amount)
	T = get_turf(T)
	if (!T || amount <= 0)
		return FALSE
	var/datum/river_flood/F = map ? map.river_flood() : null
	if (F && T.z == F.z_level)
		for (var/turf/floor/beach/water/W in range(1, T))
			if (W.salty || W.x < 1 || W.x > F.maxx || W.y < 1 || W.y > F.maxy)
				continue
			var/r = F.reach_at(W.x, W.y)
			if (r)
				F.foul_ready()
				F.foul[r] += amount
				return TRUE
	pollution_add(T, amount * 3)
	return FALSE

//////////////////////////////////////////////////////////////////////////////
// Stripped bank: what a monitor leaves behind.

/turf/floor/gravel/stripped
	name = "stripped bank"
	desc = "Bare cobbles and washed sand where a hydraulic jet has torn the bank away. Nothing will grow here, and no gold is left in it."
	icon = 'icons/obj/late_mining.dmi'
	icon_state = "stripped_bank"

//////////////////////////////////////////////////////////////////////////////
// Hydraulic monitor

/obj/structure/hydraulic_monitor
	name = "hydraulic monitor"
	desc = "A huge cast-iron nozzle on a swivel, fed from the river by a mover-driven pump. Set it on a river bank beside fresh water and a turning mill wheel, treadwheel, horse gin or windmill, aim it at a dirt or sand bank and work it: the jet tears the whole bank into pay dirt at once. The ground it strips is ruined for good, and the silt fouls the river."
	icon = 'icons/obj/late_mining.dmi'
	icon_state = "hydraulic_monitor"
	anchored = FALSE
	density = TRUE
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = FALSE
	var/tmp/jetting = FALSE

/obj/structure/hydraulic_monitor/persistence_runtime_var(key)
	return key == "jetting" || ..()

/obj/structure/hydraulic_monitor/verb/turn_nozzle()
	set name = "Turn Nozzle"
	set category = null
	set src in oview(1)
	if (!isliving(usr) || usr.incapacitated() || jetting)
		return
	set_dir(turn(dir, -90))
	to_chat(usr, SPAN_NOTICE("You swing \the [src] to face [dir2text(dir)]."))

// Fresh water beside the monitor to feed it.
/obj/structure/hydraulic_monitor/proc/water_feed()
	var/turf/T = get_turf(src)
	if (!T)
		return null
	for (var/turf/floor/beach/water/W in range(1, T))
		if (!W.salty && W.watertile)
			return W
	return null

// Why the monitor cannot strip its target now, or null.
/obj/structure/hydraulic_monitor/proc/monitor_refusal()
	if (!anchored)
		return "Fasten \the [src] down with a wrench first."
	if (!water_feed())
		return "\The [src] needs fresh river water right beside it."
	if (mechanical_drive_factor(src) >= 1)
		return "Nothing is turning the pump: set a mill wheel, treadwheel, horse gin or windmill beside \the [src]."
	var/turf/T = get_step(src, dir)
	if (!T || !T.can_sift_resources())
		return "\The [src] must be aimed at an uncovered dirt or sand bank."
	for (var/atom/movable/A in T)
		if (A.density)
			return "Something is in the way of the jet."
	return null

/obj/structure/hydraulic_monitor/attackby(obj/item/I, mob/living/human/H)
	if (is_tool(I, TOOL_WRENCH) && !jetting)
		toggle_anchor(H)
		return
	return ..()

/obj/structure/hydraulic_monitor/attack_hand(mob/living/human/H)
	if (!istype(H) || jetting)
		return ..()
	if (!crafting_node_allowed_or_warn(H, "industrial_milling"))
		return
	var/why = monitor_refusal()
	if (why)
		to_chat(H, SPAN_WARNING(why))
		return
	var/turf/T = get_step(src, dir)
	jetting = TRUE
	icon_state = "hydraulic_monitor_jetting"
	H.visible_message(SPAN_NOTICE("[H] opens \the [src]. A roaring jet of water slams into the bank."), SPAN_NOTICE("You open \the [src] and play the jet over the bank."))
	var/done = do_after(H, MONITOR_TIME, src)
	jetting = FALSE
	if (QDELETED(src))
		return
	icon_state = "hydraulic_monitor"
	if (!done || get_step(src, dir) != T || monitor_refusal())
		return
	strip_bank(T)
	to_chat(H, SPAN_NOTICE("The bank collapses into a heap of wet gravel. Muddy water pours into the river."))

// Tears T down into pay dirt and leaves stripped gravel.
/obj/structure/hydraulic_monitor/proc/strip_bank(turf/T)
	var/grade = pay_dirt_grade(T.x, T.y)
	pay_dirt_stock -= "[T.x],[T.y],[T.z]"
	var/turf/G = T.ChangeTurf(/turf/floor/gravel/stripped)
	spawn_stack(pay_dirt_type(grade), G || T, MONITOR_PAY_DIRT)
	river_foul_dump(src, MONITOR_SILT)
	return G

//////////////////////////////////////////////////////////////////////////////
// Cyanide vat with a zinc box

/obj/structure/placer_washer/cyanide_vat
	name = "cyanide vat"
	desc = "A big hooped leaching vat with a zinc box under its tap. Fill it with water and cyanide, charge the box with zinc and run old tailings through it: the solution dissolves the last fine gold, and the zinc drops it out as black slime. Cyanide kills; drained solution fouls the river."
	icon = 'icons/obj/late_mining.dmi'
	icon_state = "cyanide_vat"
	idle_state = "cyanide_vat"
	busy_state = "cyanide_vat_leaching"
	density = TRUE
	method = "cyanide"
	wash_time = VAT_WASH_TIME
	water_capacity = 60
	water_per_use = 5
	wood_back = 4
	node = "industrial_milling"
	var/zinc_loads = 0

/obj/structure/placer_washer/cyanide_vat/New()
	..()
	if (!reagents)
		create_reagents(30)

/obj/structure/placer_washer/cyanide_vat/examine(mob/user, distance)
	..(user, distance)
	to_chat(user, SPAN_NOTICE("Cyanide: [round(reagents ? reagents.get_reagent_amount("cyanide") : 0, 0.1)] units. The zinc box has enough zinc for [zinc_loads] load\s."))

/obj/structure/placer_washer/cyanide_vat/accepts_feed(obj/item/I)
	return istype(I, /obj/item/stack/ore/tailings)

/obj/structure/placer_washer/cyanide_vat/can_wash_load(mob/living/human/H)
	if (!map || map.ordinal_age < CYANIDE_AGE)
		to_chat(H, SPAN_WARNING("Nobody yet knows how to leach gold with cyanide. That comes with the Early Modern age."))
		return FALSE
	if (!reagents || reagents.get_reagent_amount("cyanide") < VAT_CYANIDE_PER_LOAD)
		to_chat(H, SPAN_WARNING("\The [src] needs cyanide in it."))
		return FALSE
	if (zinc_loads < 1)
		to_chat(H, SPAN_WARNING("The zinc box is spent. Put a zinc sheet in it."))
		return FALSE
	return TRUE

/obj/structure/placer_washer/cyanide_vat/wash_load(obj/item/stack/P)
	P.use(1)
	return cyanide_leach_load()

/obj/structure/placer_washer/cyanide_vat/proc/cyanide_leach_load(roll = null)
	. = list()
	reagents.remove_reagent("cyanide", VAT_CYANIDE_PER_LOAD)
	zinc_loads--
	if (isnull(roll))
		roll = rand(1, 100)
	if (roll <= VAT_RECOVERY)
		.[/obj/item/stack/ore/gold] = 1

/obj/structure/placer_washer/cyanide_vat/attackby(obj/item/I, mob/living/human/H)
	if (!istype(H) || washing)
		return ..()
	if (istype(I, /obj/item/stack/material/zinc))
		var/obj/item/stack/material/zinc/Z = I
		if (zinc_loads >= VAT_ZINC_LOADS)
			to_chat(H, SPAN_NOTICE("The zinc box is full."))
			return
		if (!Z.use(1))
			return
		zinc_loads = VAT_ZINC_LOADS
		to_chat(H, SPAN_NOTICE("You cut the zinc into shavings and pack the box."))
		return
	var/obj/item/weapon/reagent_containers/C = I
	if (istype(C) && C.is_open_container() && C.reagents && C.reagents.get_reagent_amount("cyanide") > 0)
		var/amount = min(reagents.get_free_space(), C.reagents.get_reagent_amount("cyanide"))
		if (amount <= 0)
			to_chat(H, SPAN_NOTICE("\The [src] holds all the cyanide it can."))
			return
		C.reagents.remove_reagent("cyanide", amount)
		reagents.add_reagent("cyanide", amount)
		to_chat(H, SPAN_NOTICE("You pour [amount] units of cyanide into \the [src]."))
		return
	return ..()

/obj/structure/placer_washer/cyanide_vat/verb/drain_vat()
	set name = "Drain Vat"
	set category = null
	set src in oview(1)
	if (!isliving(usr) || usr.incapacitated() || washing)
		return
	drain(usr)

// Empties the solution onto the ground: into the river beside water.
/obj/structure/placer_washer/cyanide_vat/proc/drain(mob/user)
	var/cyanide = reagents ? reagents.get_reagent_amount("cyanide") : 0
	if (cyanide <= 0 && water_store <= 0)
		if (user)
			to_chat(user, SPAN_NOTICE("\The [src] is empty."))
		return FALSE
	reagents.clear_reagents()
	water_store = 0
	if (cyanide > 0)
		river_foul_dump(src, cyanide)
	if (user)
		user.visible_message(SPAN_WARNING("[user] knocks out the bung of \the [src]. The solution floods out."))
	return TRUE

/obj/structure/placer_washer/cyanide_vat/Destroy()
	if (reagents && reagents.get_reagent_amount("cyanide") > 0)
		river_foul_dump(src, reagents.get_reagent_amount("cyanide"))
	return ..()

#undef MONITOR_PAY_DIRT
#undef MONITOR_TIME
#undef MONITOR_SILT
#undef CYANIDE_AGE
#undef VAT_CYANIDE_PER_LOAD
#undef VAT_ZINC_LOADS
#undef VAT_RECOVERY
#undef VAT_WASH_TIME
