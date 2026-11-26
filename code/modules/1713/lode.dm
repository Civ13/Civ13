// Lode ore and ore dressing (docs/lode.md).
//
// Gold-bearing quartz and silver-bearing ore turn up in mined rock far more
// often than free gold or silver ore, but the metal is locked in the rock.
// It has to be crushed (stone crusher, water stamp mill or electric stamp
// mill) and the crushed ore washed (pan or buddle) or, later, amalgamated.
// One load of crushed ore holds half a lump of metal; each method recovers a
// share of that, and the rest goes out with the tailings.

#define LODE_GOLD_CHANCE 4 // percent per mined rock, from the Classical age
#define LODE_SILVER_CHANCE 3
#define LODE_LUMPS 4
// Lode metal per load: code/__defines/ore_processing.dm
#define LODE_PAN_RECOVERY 0.2
#define LODE_BUDDLE_RECOVERY 0.35
#define PAN_CRUSHED_TIME 150
#define BUDDLE_WASH_TIME 50

/obj/item/stack/ore/gold_quartz
	name = "gold-bearing quartz"
	singular_name = "lump"
	desc = "Milky white vein quartz stained rusty brown, with a few specks of gold. The gold is locked inside: crush it in a stone crusher or stamp mill, then wash the crushed ore."
	icon = 'icons/obj/lode.dmi'
	icon_state = "gold_quartz"
	flammable = FALSE

/obj/item/stack/ore/silver_lode
	name = "silver-bearing ore"
	singular_name = "lump"
	desc = "Heavy dark lead ore with bright steel-grey glints, carrying a little silver. Crush it in a stone crusher or stamp mill, then wash the crushed ore."
	icon = 'icons/obj/lode.dmi'
	icon_state = "silver_lode"
	flammable = FALSE

/obj/item/stack/ore/crushed_ore
	name = "crushed ore"
	singular_name = "load"
	icon = 'icons/obj/lode.dmi'
	flammable = FALSE
	max_amount = 20
	var/metal_type = /obj/item/stack/ore/gold

/obj/item/stack/ore/crushed_ore/gold
	name = "crushed quartz"
	desc = "Gold-bearing quartz stamped to grit. Wash it in a pan or a buddle to get the gold out; most of it still goes out with the tailings."
	icon_state = "crushed_gold"
	metal_type = /obj/item/stack/ore/gold

/obj/item/stack/ore/crushed_ore/silver
	name = "crushed silver ore"
	desc = "Silver-bearing ore stamped to grit. Wash it in a pan or a buddle to get the silver out; most of it still goes out with the tailings."
	icon_state = "crushed_silver"
	metal_type = /obj/item/stack/ore/silver

/obj/item/stack/ore/tailings
	name = "tailings"
	singular_name = "load"
	desc = "Washed-out grit and slime from ore dressing. Some metal is still in it, but no washing will get it out."
	icon = 'icons/obj/lode.dmi'
	icon_state = "tailings"
	flammable = FALSE
	max_amount = 50

// The crushed ore a lump of lode ore becomes, or null for anything else.
/proc/lode_crushed_type(obj/item/I)
	if (!I)
		return null
	if (I.type == /obj/item/stack/ore/gold_quartz)
		return /obj/item/stack/ore/crushed_ore/gold
	if (I.type == /obj/item/stack/ore/silver_lode)
		return /obj/item/stack/ore/crushed_ore/silver
	return null

// Mined rock: lode ore is rolled on its own, like cinnabar.
/turf/proc/mining_lode(mob/living/human/H)
	if (!map || map.ordinal_age < 1)
		return 0
	var/lode_type = null
	if (prob(LODE_GOLD_CHANCE * continent_ore_factor("gold", src))) // continent_resources.dm
		lode_type = /obj/item/stack/ore/gold_quartz
	else if (prob(LODE_SILVER_CHANCE * continent_ore_factor("silver", src)))
		lode_type = /obj/item/stack/ore/silver_lode
	if (!lode_type)
		return 0
	var/obj/item/stack/ore/L = new lode_type(src)
	L.amount = LODE_LUMPS
	if (istype(get_area(src), /area/caribbean/void/caves/special))
		L.amount *= 2
	L.update_icon()
	if (H)
		to_chat(H, SPAN_GREEN_BOLD("You found some <b>[L.name]</b>!"))
	return L.amount

// One load of crushed ore washed at a recovery share: the metal ore found,
// if any, and always one load of tailings.
/proc/crushed_ore_wash(metal_type, recovery, roll = null)
	. = list()
	if (isnull(roll))
		roll = rand(1, 1000) / 10
	if (roll <= LODE_METAL * recovery * 100)
		.[metal_type] = 1
	.[/obj/item/stack/ore/tailings] = 1

// Panning crushed ore in a wooden bowl beside water: slow and wasteful.
/obj/item/kitchen/wood_bowl/proc/pan_crushed_ore(obj/item/stack/ore/crushed_ore/C, mob/living/human/H)
	var/turf/T = get_turf(H)
	var/turf/water = T?.panning_water()
	if (!water)
		to_chat(H, SPAN_WARNING("Stand beside shallow fresh water to pan crushed ore."))
		return
	var/atom/bowl_location = loc
	if (!panning_tool_available(H, bowl_location))
		return
	to_chat(H, SPAN_NOTICE("You swirl a load of [C.name] in \the [src]."))
	if (!do_after(H, PAN_CRUSHED_TIME, T) || QDELETED(C) || C.amount < 1 || !panning_tool_available(H, bowl_location))
		return
	if (get_turf(H) != T || !water || T.panning_water() != water)
		return
	var/metal = C.metal_type
	C.use(1)
	var/list/names = pay_dirt_output(crushed_ore_wash(metal, LODE_PAN_RECOVERY), T)
	river_mercury_pan_message(H, water)
	to_chat(H, SPAN_NOTICE("You keep: [english_list(names)]. A buddle would save more of it."))

//////////////////////////////////////////////////////////////////////////////
// Buddle: a round pit with a sweep, where crushed ore settles by weight.

/obj/structure/placer_washer/buddle
	name = "buddle"
	desc = "A round shallow pit with a cone in the middle and a sweep turning over it, the way ore dressers have washed crushed ore since Agricola's day. Pour water into it, then wash crushed ore in it: the heavy metal settles, the light grit runs off as tailings."
	icon = 'icons/obj/lode.dmi'
	icon_state = "buddle"
	idle_state = "buddle"
	busy_state = "buddle_working"
	method = "buddle"
	wash_time = BUDDLE_WASH_TIME
	water_capacity = 40
	wood_back = 4
	node = "ore_dressing"

/obj/structure/placer_washer/buddle/accepts_feed(obj/item/I)
	return istype(I, /obj/item/stack/ore/crushed_ore)

/obj/structure/placer_washer/buddle/wash_load(obj/item/stack/P)
	var/obj/item/stack/ore/crushed_ore/C = P
	var/metal = C.metal_type
	P.use(1)
	return crushed_ore_wash(metal, LODE_BUDDLE_RECOVERY)

//////////////////////////////////////////////////////////////////////////////
// Water stamp mill: the stamp mill driven by a mill wheel, treadwheel, horse
// gin or windmill next to it instead of cable power.

/obj/structure/drill/stamp_mill/water
	name = "water stamp mill"
	desc = "A timber frame of iron-shod stamps lifted by a cam shaft. Set it next to a turning mill wheel, treadwheel, horse gin or windmill, anchor it and load up to fifty stone blocks or lumps of gold-bearing quartz or silver-bearing ore. It crushes one every six seconds while it is driven; clear its output before twelve stacks accumulate."
	icon = 'icons/obj/lode.dmi'
	icon_state = "water_stamp_mill"
	powerneeded = 0
	crush_interval = 3
	var/idle_state = "water_stamp_mill"
	var/active_state = "water_stamp_mill_on"

/obj/structure/drill/stamp_mill/water/check_power()
	powered = mechanical_drive_factor(src) < 1
	return powered

/obj/structure/drill/stamp_mill/water/update_icon()
	icon_state = active ? active_state : idle_state
	update_plates_overlay() // milling.dm

/obj/structure/drill/stamp_mill/water/process_machine()
	if (active && !process_pending && anchored && isturf(loc) && loaded_stone() && !check_power())
		stop_drilling()
		visible_message(SPAN_WARNING("\The [src] stops: nothing is turning its cam shaft."))
		return
	return ..()

#undef PAN_CRUSHED_TIME
#undef BUDDLE_WASH_TIME
