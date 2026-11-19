// Iron and steel works (docs/steelmaking.md): the plant that turns pig iron
// into wrought iron and steel, and coal into coke. Every works is loaded
// with one charge metal and its fuel, then fired: by hand, with a flame, or
// once loaded from automation. The firing runs on an addtimer loop with its
// time left saved, so a save and restart resumes it.
//
//   coke bank           coal burnt down to coke                 Blast Furnaces & Coke
//   finery forge        2 pig iron to 1 wrought iron            Blast Furnaces & Coke
//   cementation furnace wrought iron to blister steel in bulk   Blast Furnaces & Coke
//   puddling furnace    pig iron to wrought iron, stirred       Blast Furnaces & Coke
//   Bessemer converter  pig iron to steel, tipped on time       Steelmaking
//   open hearth         pig iron and scrap steel to fine steel  Open Hearth Steel
//   electric arc furnace scrap iron and steel to fine steel     Alloys

#define STEEL_WORKS_FEED_LIMIT 50 // fuel units automation loads

/obj/structure/steel_works
	icon = 'icons/obj/metallurgy.dmi'
	density = TRUE
	anchored = TRUE
	not_movable = TRUE
	not_disassemblable = FALSE
	var/base_state = "bloomery"
	var/charge = 0 // units of charge metal loaded
	var/list/loaded = list() // charge type path text => units, to give back on Empty
	var/list/additions = list() // alloy ore key => units (alloy_steels.dm)
	var/fuel = 0
	var/burning = FALSE
	var/burn_left = 0 // deciseconds of firing left; saved, so a load resumes it
	var/worker_skill = 1 // Crafting coefficient of whoever fired it
	var/tmp/burn_epoch = 0
	// What it takes and makes.
	var/charge_type = /obj/item/stack/ore/iron_pig
	var/charge_name = "pig iron"
	var/charge_limit = 20
	var/charge_min = 1
	var/fuel_base = 2 // fuel to bring it to heat
	var/fuel_per_charge = 1
	var/burn_time = 1200
	var/burn_tick = 100
	var/output_type = /obj/item/stack/material/iron
	var/output_ratio = 1

/obj/structure/steel_works/persistence_runtime_var(key)
	return key == "burn_epoch" || ..()

/obj/structure/steel_works/New()
	..()
	update_icon()

/obj/structure/steel_works/update_icon()
	icon_state = burning ? "[base_state]_on" : base_state
	set_light(burning ? 3 : 0)

// Fuel kinds it burns, in fuel units (a charcoal is 2).
/obj/structure/steel_works/proc/fuel_rates()
	return list("charcoal" = 2, "coke" = 3)

/obj/structure/steel_works/proc/fuel_needed()
	return fuel_base + charge * fuel_per_charge

/obj/structure/steel_works/proc/accepts_charge(obj/item/I)
	return istype(I, charge_type)

// Units of charge one item adds (stacks count their amount).
/obj/structure/steel_works/proc/charge_units(obj/item/I)
	var/obj/item/stack/S = I
	return istype(S) ? S.amount : 1

/obj/structure/steel_works/proc/fuel_names()
	var/list/names = list()
	for (var/kind in fuel_rates())
		names += kind
	return english_list(names, and_text = " or ")

/obj/structure/steel_works/examine(mob/user, distance)
	..(user, distance)
	if (burning)
		to_chat(user, SPAN_NOTICE("It is at work. About [max(1, round(burn_left / 600))] minute\s left."))
	else
		to_chat(user, SPAN_NOTICE("It holds [charge] of [charge_limit] [charge_name] and [round(fuel, 0.1)] fuel ([fuel_names()]). Firing it takes [fuel_needed()] fuel."))
	var/added = additions_text()
	if (added)
		to_chat(user, SPAN_NOTICE("Alloy additions: [added]."))

/obj/structure/steel_works/attackby(obj/item/I, mob/living/human/H)
	if (!I || !I.loc || !istype(H))
		return
	if (is_tool(I, TOOL_WRENCH))
		if (burning)
			to_chat(H, SPAN_WARNING("Not while it is at work."))
			return
		timed_toggle_anchor(H)
		return
	if (isflamesource(I) && !istype(I, /obj/item/stack))
		start_firing(H)
		return
	if (burning)
		to_chat(H, SPAN_WARNING("\The [src] is at work. Wait for it to finish."))
		return
	if (accepts_charge(I))
		load_charge(I, H)
		return
	if (addition_key(I))
		load_addition(I, H)
		return
	if (istype(I, /obj/item/stack))
		var/value = solid_fuel_value(I, fuel_rates())
		if (value > 0)
			fuel += value
			record_wood_fuel(I, value)
			H.remove_from_mob(I)
			qdel(I)
			visible_message(SPAN_NOTICE("[H] fuels \the [src]."))
			return
		if (istype(I, /obj/item/stack/ore/coal))
			to_chat(H, SPAN_WARNING("Raw coal's sulphur would ruin the metal here. Burn [fuel_names()]."))
			return
	return ..()

/obj/structure/steel_works/proc/load_charge(obj/item/I, mob/living/human/H)
	var/units = charge_units(I)
	var/room = charge_limit - charge
	if (room <= 0)
		to_chat(H, SPAN_WARNING("\The [src] is full."))
		return
	var/obj/item/stack/S = I
	if (istype(S) && units > room)
		S.use(room)
		units = room
	else
		H.remove_from_mob(I)
		qdel(I)
	note_loaded(I.type, units)
	visible_message(SPAN_NOTICE("[H] loads [units] [charge_name] into \the [src]."))

/obj/structure/steel_works/proc/note_loaded(path, units)
	charge += units
	loaded["[path]"] = (loaded["[path]"] || 0) + units

// Units of the charge that are steel of any grade.
/obj/structure/steel_works/proc/loaded_steel()
	. = 0
	for (var/key in loaded)
		var/path = text2path(key)
		if (ispath(path, /obj/item/stack/material/steel))
			. += loaded[key]

/obj/structure/steel_works/attack_hand(mob/living/human/H)
	if (!istype(H))
		return
	if (burning)
		work_firing(H)
		return
	start_firing(H)

// Something to do while it is at work (stirring, tipping). Default: nothing.
/obj/structure/steel_works/proc/work_firing(mob/living/human/H)
	to_chat(H, SPAN_NOTICE("\The [src] is at work."))

// Why it can't start now, or null.
/obj/structure/steel_works/proc/start_problem()
	if (!anchored)
		return "Fasten \the [src] down first."
	if (charge < charge_min)
		return "Load at least [charge_min] [charge_name] first."
	if (fuel < fuel_needed())
		return "It needs [fuel_needed()] fuel ([fuel_names()]) and holds [round(fuel, 0.1)]."
	return null

/obj/structure/steel_works/proc/start_firing(mob/living/human/H)
	if (burning)
		return FALSE
	var/problem = start_problem()
	if (problem)
		if (H)
			to_chat(H, SPAN_WARNING(problem))
		return FALSE
	fuel -= fuel_needed()
	worker_skill = H ? H.getStatCoeff("crafting") : 1
	burning = TRUE
	burn_left = burn_time
	firing_started(H)
	update_icon()
	visible_message(SPAN_NOTICE("\The [src] roars into life."))
	start_burn_loop()
	return TRUE

/obj/structure/steel_works/proc/firing_started(mob/living/human/H)
	return

/obj/structure/steel_works/proc/start_burn_loop()
	addtimer(CALLBACK(src, PROC_REF(burn_step), ++burn_epoch), burn_tick)

// Whether the firing may advance this tick (power, blast).
/obj/structure/steel_works/proc/can_advance()
	return TRUE

/obj/structure/steel_works/proc/burn_step(epoch)
	if (QDELETED(src) || !burning || epoch != burn_epoch)
		return
	if (can_advance())
		burn_left -= burn_tick
		firing_ticked()
	if (!burning)
		return
	if (burn_left <= 0)
		finish_firing()
		return
	addtimer(CALLBACK(src, PROC_REF(burn_step), epoch), burn_tick)

/obj/structure/steel_works/proc/firing_ticked()
	return

/obj/structure/steel_works/proc/finish_firing()
	burning = FALSE
	burn_left = 0
	burn_epoch++
	var/turf/T = get_turf(src)
	produce(T)
	charge = 0
	loaded = list()
	update_icon()

// Puts out what one firing made. Default: output_ratio per unit of charge.
/obj/structure/steel_works/proc/produce(turf/T)
	var/made = round(charge * output_ratio)
	var/alloyed = alloy_output(T, made) // alloy_steels.dm
	if (made - alloyed > 0)
		spawn_stack(output_type, T, made - alloyed)
	visible_message(SPAN_NOTICE("\The [src] finishes its work: [made] [made == 1 ? "piece" : "pieces"] out[alloyed ? ", [alloyed] of it alloy" : ""]."))
	return made

/obj/structure/steel_works/after_load()
	..()
	burn_epoch = 0
	if (burning)
		if (burn_left <= 0)
			burn_left = burn_tick
		start_burn_loop()
	update_icon()

/obj/structure/steel_works/verb/empty_works()
	set category = null
	set name = "Empty"
	set src in range(1)
	if (burning || !istype(usr, /mob/living/human))
		return
	if (charge > 0 || additions_total() > 0)
		return_charge(get_turf(src))
		return_additions(get_turf(src))
		charge = 0
		loaded = list()
		visible_message(SPAN_NOTICE("[usr] empties \the [src]."))

/obj/structure/steel_works/proc/return_charge(turf/T)
	for (var/key in loaded)
		var/path = text2path(key)
		if (ispath(path, /obj/item/stack) && loaded[key] > 0)
			spawn_stack(path, T, loaded[key])

// Automation: charge and fuel in, output out; it fires once it has both.
/obj/structure/steel_works/factory_accepts(obj/item/I, from_dir = 0)
	if (!anchored || burning || !factory_movable_item(I) || !istype(I, /obj/item/stack))
		return 0
	var/obj/item/stack/S = I
	if (accepts_charge(S))
		return max(0, min(S.amount, charge_limit - charge))
	if (addition_key(S))
		return min(S.amount, addition_room())
	var/value = solid_fuel_unit_value(S, fuel_rates())
	if (value <= 0)
		return 0
	return max(0, min(S.amount, round((STEEL_WORKS_FEED_LIMIT - fuel) / value)))

/obj/structure/steel_works/factory_insert(obj/item/I, from_dir = 0)
	var/amount = factory_accepts(I, from_dir)
	if (amount <= 0)
		return 0
	var/obj/item/stack/S = I
	if (accepts_charge(S))
		note_loaded(S.type, factory_consume_units(S, amount))
	else if (addition_key(S))
		note_addition(addition_key(S), factory_consume_units(S, amount))
	else
		var/value = solid_fuel_unit_value(S, fuel_rates())
		record_wood_fuel(S, amount * value)
		fuel += factory_consume_units(S, amount) * value
	if (!burning && charge >= charge_limit && !start_problem())
		start_firing(null)
	return amount

/obj/structure/steel_works/factory_offer(to_dir = 0, filter_type = null)
	if (!anchored)
		return null
	return factory_offer_tile_output(src, list(output_type) + alloy_output_types(), filter_type)

/obj/structure/steel_works/factory_take(obj/item/I, atom/destination)
	return factory_take_tile_output(src, I, destination)

//////////////////////////////////////////////////////////////////////////////
// Coke

/obj/item/stack/ore/coke
	name = "coke"
	desc = "Mineral coal baked in a closed heap until the tar and sulphur are driven off. Light, grey and porous, it burns hot and clean enough to smelt iron."
	icon_state = "ore_charcoal"
	color = "#9a9fa6"
	singular_name = "lump"

/obj/structure/steel_works/coke_bank
	name = "coke bank"
	desc = "A low brick oven for baking mineral coal into coke. Load it with coal and light it: five minutes later, every five coal come out as three coke."
	icon_state = "clay_kiln"
	base_state = "clay_kiln"
	charge_type = /obj/item/stack/ore/coal
	charge_name = "coal"
	charge_limit = 20
	charge_min = 5
	fuel_base = 0
	fuel_per_charge = 0
	burn_time = 3000
	output_type = /obj/item/stack/ore/coke
	output_ratio = 0.6

// A coke bank burns part of its own coal; it needs no other fuel.
/obj/structure/steel_works/coke_bank/fuel_rates()
	return list()

/obj/structure/steel_works/coke_bank/examine(mob/user, distance)
	..(user, distance)
	if (!burning)
		to_chat(user, SPAN_NOTICE("It burns part of its own coal, so it needs no other fuel. Light it with a flame or by hand."))

//////////////////////////////////////////////////////////////////////////////
// Finery forge: pig iron melted under a charcoal blast loses its carbon and
// is gathered into a loop of wrought iron.

/obj/structure/steel_works/finery
	name = "finery forge"
	desc = "An open hearth with a hooded blast. Pig iron melted in it loses its carbon and comes out as wrought iron: two pig iron make one bar."
	icon_state = "stone_kiln"
	base_state = "stone_kiln"
	charge_name = "pig iron"
	charge_limit = 20
	charge_min = 2
	fuel_per_charge = 1
	burn_time = 900
	output_type = /obj/item/stack/material/iron
	output_ratio = 0.5

//////////////////////////////////////////////////////////////////////////////
// Cementation furnace: the carburizing pot on a works scale.

#define CEMENTATION_UNEVEN 15 // percent of bars that take too little carbon, for an ordinary smith

/obj/structure/steel_works/cementation
	name = "cementation furnace"
	desc = "A conical brick furnace with two long clay chests inside. Wrought iron bars packed in charcoal there come out as blister steel after a long firing. Fuel it with charcoal: it packs the chests as well as heating them."
	icon_state = "sandstone_kiln"
	base_state = "sandstone_kiln"
	charge_type = /obj/item/stack/material/iron
	charge_name = "wrought iron bars"
	charge_limit = 30
	charge_min = 5
	fuel_base = 6
	fuel_per_charge = 2
	burn_time = 9000
	output_type = /obj/item/stack/material/steel/blister

/obj/structure/steel_works/cementation/accepts_charge(obj/item/I)
	var/obj/item/stack/material/iron/S = I
	return istype(S) && S.type == /obj/item/stack/material/iron

/obj/structure/steel_works/cementation/fuel_rates()
	return list("charcoal" = 2)

/obj/structure/steel_works/cementation/produce(turf/T)
	var/chance = clamp(round(CEMENTATION_UNEVEN - (worker_skill - 1) * 30), 5, 30)
	var/uneven = 0
	for (var/i in 1 to charge)
		if (prob(chance))
			uneven++
	if (charge - uneven > 0)
		spawn_stack(/obj/item/stack/material/steel/blister, T, charge - uneven)
	if (uneven > 0)
		spawn_stack(/obj/item/stack/material/iron, T, uneven)
	visible_message(SPAN_NOTICE("\The [src] is opened: [charge - uneven] bar\s of blister steel[uneven ? " and [uneven] that took too little carbon" : ""]."))
	return charge - uneven

#undef CEMENTATION_UNEVEN

//////////////////////////////////////////////////////////////////////////////
// Puddling furnace: a reverberatory furnace. The fire is kept apart from
// the iron, so coal will do; the puddler must stir the boiling bath.

#define PUDDLING_STIR_TIME 50

/obj/structure/steel_works/puddling
	name = "puddling furnace"
	desc = "A long, low brick furnace whose flame plays over a hearth of pig iron. While it boils, someone must stir it with an empty hand, or much of the iron is lost. Ten pig iron make eight wrought iron."
	icon_state = "blast_furnace"
	base_state = "blast_furnace"
	charge_name = "pig iron"
	charge_limit = 10
	charge_min = 2
	fuel_per_charge = 1
	burn_time = 1800
	output_type = /obj/item/stack/material/iron
	output_ratio = 0.8
	var/stirred = FALSE

/obj/structure/steel_works/puddling/fuel_rates()
	return list("coal" = 3, "coke" = 3, "charcoal" = 2)

/obj/structure/steel_works/puddling/firing_started(mob/living/human/H)
	stirred = FALSE
	visible_message(SPAN_NOTICE("The pig iron in \the [src] starts to boil. Stir it!"))

/obj/structure/steel_works/puddling/work_firing(mob/living/human/H)
	if (stirred)
		to_chat(H, SPAN_NOTICE("The bath has come to nature already. Let it finish."))
		return
	visible_message(SPAN_NOTICE("[H] works the boiling iron with a rabble."))
	if (!do_after(H, PUDDLING_STIR_TIME, src) || !burning)
		return
	var/chance = clamp(round(60 + (H.getStatCoeff("crafting") - 1) * 80), 30, 95)
	if (prob(chance))
		stirred = TRUE
		visible_message(SPAN_NOTICE("The bath thickens into pasty balls of iron. [H] has brought it to nature."))
	else
		to_chat(H, SPAN_WARNING("The bath splashes and sets unevenly. Stir it again."))

/obj/structure/steel_works/puddling/produce(turf/T)
	var/ratio = stirred ? output_ratio : output_ratio / 2
	var/made = round(charge * ratio)
	if (made > 0)
		spawn_stack(/obj/item/stack/material/iron, T, made)
	visible_message(stirred ? SPAN_NOTICE("The puddler's balls are shingled into [made] bar\s of wrought iron.") : SPAN_WARNING("Nobody stirred the bath: only [made] bar\s of wrought iron came out of the slag."))
	stirred = FALSE
	return made

#undef PUDDLING_STIR_TIME

//////////////////////////////////////////////////////////////////////////////
// Bessemer converter: air blown through molten pig iron burns its carbon
// out. When the flame at the mouth drops, the carbon is gone: tip it then.
// Too early leaves pig iron; too late burns the steel to soft iron.

#define BESSEMER_BLOW 1200 // deciseconds, two minutes
#define BESSEMER_DROP_MIN 750 // earliest the flame drops
#define BESSEMER_DROP_MAX 1050 // latest
#define BESSEMER_WINDOW 100 // deciseconds an ordinary smith has to tip it

/obj/structure/steel_works/bessemer
	name = "Bessemer converter"
	desc = "A pear-shaped iron vessel on trunnions. Load it with pig iron and coke and light it: air roars up through the melt. When the flame at the mouth drops, tip it with an empty hand. Ten pig iron make nine steel."
	icon_state = "blast_furnace"
	base_state = "blast_furnace"
	charge_name = "pig iron"
	charge_limit = 15
	charge_min = 5
	fuel_base = 3
	fuel_per_charge = 0.5
	burn_time = BESSEMER_BLOW
	burn_tick = 10
	output_type = /obj/item/stack/material/steel
	output_ratio = 0.9
	var/drop_at = 0 // deciseconds into the blow when the flame drops; saved
	var/dropped = FALSE

/obj/structure/steel_works/bessemer/fuel_rates()
	return list("coke" = 3)

/obj/structure/steel_works/bessemer/proc/blown()
	return burn_time - burn_left

/obj/structure/steel_works/bessemer/proc/tip_window()
	return round(BESSEMER_WINDOW * clamp(worker_skill, 0.5, 2))

/obj/structure/steel_works/bessemer/firing_started(mob/living/human/H)
	drop_at = rand(BESSEMER_DROP_MIN, BESSEMER_DROP_MAX)
	dropped = FALSE
	visible_message(SPAN_NOTICE("Air roars through \the [src]. Sparks and a long flame pour out of its mouth. Watch for the flame to drop."))

/obj/structure/steel_works/bessemer/firing_ticked()
	if (!dropped && blown() >= drop_at)
		dropped = TRUE
		visible_message(SPAN_NOTICE("The flame at \the [src]'s mouth suddenly drops! Tip it now."))

/obj/structure/steel_works/bessemer/work_firing(mob/living/human/H)
	var/when = blown()
	var/turf/T = get_turf(src)
	burning = FALSE
	burn_left = 0
	burn_epoch++
	var/made = 0
	if (when < drop_at)
		made = round(charge * output_ratio)
		if (made > 0)
			spawn_stack(/obj/item/stack/ore/iron_pig, T, made)
		visible_message(SPAN_WARNING("[H] tips \the [src] too early. The carbon is still in it: [made] pig iron pours out."))
	else if (when <= drop_at + tip_window())
		made = round(charge * output_ratio)
		if (made > 0)
			spawn_stack(/obj/item/stack/material/steel, T, made)
		visible_message(SPAN_NOTICE("[H] tips \the [src] just as the flame drops. [made] steel pours out."))
	else
		overblown(T)
	charge = 0
	loaded = list()
	update_icon()

/obj/structure/steel_works/bessemer/proc/overblown(turf/T)
	var/made = round(charge * 0.8)
	if (made > 0)
		spawn_stack(/obj/item/stack/material/iron, T, made)
	visible_message(SPAN_WARNING("\The [src] blew too long and burnt its steel soft: [made] wrought iron pours out."))
	return made

// Nobody tipped it: the blow runs on and burns the steel soft.
/obj/structure/steel_works/bessemer/produce(turf/T)
	return overblown(T)

#undef BESSEMER_BLOW
#undef BESSEMER_DROP_MIN
#undef BESSEMER_DROP_MAX
#undef BESSEMER_WINDOW

//////////////////////////////////////////////////////////////////////////////
// Open hearth: a slow regenerative furnace. Pig iron and scrap steel melt
// down together; the melter samples it until the carbon is right.

/obj/structure/steel_works/open_hearth
	name = "open hearth furnace"
	desc = "A big regenerative furnace with arched charging doors. It melts pig iron and scrap steel together over a slow firing into fine steel. It burns coal, coke or charcoal."
	icon_state = "blast_furnace"
	base_state = "blast_furnace"
	charge_name = "pig iron or steel"
	charge_limit = 40
	charge_min = 5
	fuel_base = 6
	fuel_per_charge = 1
	burn_time = 6000
	output_type = /obj/item/stack/material/steel/fine
	output_ratio = 0.9

/obj/structure/steel_works/open_hearth/fuel_rates()
	return list("coal" = 3, "coke" = 3, "charcoal" = 2)

/obj/structure/steel_works/open_hearth/accepts_charge(obj/item/I)
	return istype(I, /obj/item/stack/ore/iron_pig) || istype(I, /obj/item/stack/material/steel)

/obj/structure/steel_works/open_hearth/produce(turf/T)
	// Scrap steel melts back whole; pig iron loses some to the slag.
	var/scrap = loaded_steel()
	var/made = round(max(0, charge - scrap) * output_ratio) + scrap
	var/alloyed = alloy_output(T, made) // alloy_steels.dm
	if (made - alloyed > 0)
		spawn_stack(/obj/item/stack/material/steel/fine, T, made - alloyed)
	visible_message(SPAN_NOTICE("\The [src] is tapped: [made] steel runs out[alloyed ? ", [alloyed] of it alloy steel" : ""]."))
	return made

//////////////////////////////////////////////////////////////////////////////
// Electric arc furnace: scrap iron and steel melted by an arc from carbon
// electrodes. Cable it to a powered grid; it burns no fuel and stops while
// the power is off.

/obj/structure/steel_works/arc_furnace
	name = "electric arc furnace"
	desc = "A round steel shell with three carbon electrodes through its lid. Cabled to a powered grid, it melts scrap iron and steel into fine steel. It burns no fuel, but draws heavily and pauses while the power is off."
	icon_state = "blast_furnace"
	base_state = "blast_furnace"
	charge_name = "scrap iron or steel"
	charge_limit = 40
	charge_min = 5
	fuel_base = 0
	fuel_per_charge = 0
	burn_time = 2400
	output_type = /obj/item/stack/material/steel/fine
	output_ratio = 0.95
	powerneeded = 200
	var/tmp/warned_unpowered = FALSE

/obj/structure/steel_works/arc_furnace/fuel_rates()
	return list()

/obj/structure/steel_works/arc_furnace/accepts_charge(obj/item/I)
	return istype(I, /obj/item/stack/material/steel) || istype(I, /obj/item/stack/ore/iron_pig) || (istype(I, /obj/item/stack/material/iron) && I.type == /obj/item/stack/material/iron)

/obj/structure/steel_works/arc_furnace/attackby(obj/item/I, mob/living/human/H)
	if (istype(I, /obj/item/stack/cable_coil))
		connect_cable(H, I)
		return
	return ..()

/obj/structure/steel_works/arc_furnace/start_problem()
	. = ..()
	if (!. && !draw_cable_power())
		return "It has no power. Cable it to a running grid."

/obj/structure/steel_works/arc_furnace/can_advance()
	if (draw_cable_power())
		warned_unpowered = FALSE
		return TRUE
	if (!warned_unpowered)
		warned_unpowered = TRUE
		visible_message(SPAN_WARNING("The arc in \the [src] gutters out: no power."))
	return FALSE

/obj/structure/steel_works/arc_furnace/finish_firing()
	..()
	if (powersource)
		powersource.update_power(-powerneeded, 1, src)

#undef STEEL_WORKS_FEED_LIMIT
