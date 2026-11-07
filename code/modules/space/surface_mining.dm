// ============================================================
// Surface mining and local fabrication (space settlement phase 5)
// ------------------------------------------------------------
// Barren ground has its own ore table: any industrial drill on regolith
// brings up iron, sand, water ice and a little copper and sulphur instead of
// the mainland mix. Off-world Mining adds a lighter regolith drill rig that
// only works on barren ground, and an ice melter that turns water ice into
// water for drinking, farming and the electrolyser. The electrolyser also
// takes ice directly. With local iron and sand, the 3D printer prints the
// spares and module kits listed in config/crafting/factory_recipes.txt, so
// a settlement stops depending on mainland cargo.
// Reuses existing sprites; no new art.
// ============================================================

#define SURFACE_ICE_WATER 20 // units of water per piece of ice
#define SURFACE_MELTER_CAPACITY 400

/obj/item/stack/ore/ice
	name = "water ice"
	desc = "Dirty, rock-hard ice cut from under the regolith. Melt it for water."
	icon_state = "ore_glass"
	color = "#d8ecff"

// The ore a drill brings up on this ground, or null for the drill's own.
/turf/proc/drill_ore_table()
	return null

/turf/floor/dirt/dust/regolith/drill_ore_table()
	return list(
		/obj/item/stack/ore/iron = 6,
		/obj/item/stack/ore/ice = 5,
		/obj/item/stack/ore/glass = 3,
		/obj/item/stack/material/stone = 3,
		/obj/item/stack/ore/copper = 2,
		/obj/item/stack/ore/sulphur = 1,
	)

/obj/structure/drill/proc/drill_ore()
	var/turf/T = get_turf(src)
	var/list/table = T ? T.drill_ore_table() : null
	return table ? pickweight(table) : pick(ore_types)

/obj/structure/drill/regolith_rig
	name = "regolith drill rig"
	desc = "A light drill rig built for barren ground. Requires 60 cable power and open regolith. Produces 2 pieces of ore, sand or ice every two minutes. Clear the output tile before it reaches 12 stacks."
	color = "#d9b38c"
	powerneeded = 60

/obj/structure/drill/regolith_rig/valid_drill_site()
	var/turf/T = loc
	return anchored && istype(T) && T.barren_open_ground() && !(locate(/obj/covers) in T)

// ---------------------------------------------------------------- melting

/obj/structure/reagent_dispensers/ice_melter
	name = "ice melter"
	desc = "A heated tank that melts water ice. Load ice, cable it, and draw water with an open container."
	icon = 'icons/obj/modern_structures.dmi'
	icon_state = "smes2"
	anchored = TRUE
	not_movable = FALSE
	max_capacity = SURFACE_MELTER_CAPACITY
	powerneeded = 5

/obj/structure/reagent_dispensers/ice_melter/examine(mob/user)
	..()
	to_chat(user, SPAN_NOTICE("Water: [round(reagents ? reagents.total_volume : 0)]/[max_capacity] units. [powersource ? "It is cabled." : "Run a cable to it to power it."]"))

/obj/structure/reagent_dispensers/ice_melter/proc/has_power()
	return draw_cable_power()

// Melts as much of the ice stack as fits; returns how many pieces it took.
/obj/structure/reagent_dispensers/ice_melter/proc/melt_ice(obj/item/stack/ore/ice/I)
	if (!istype(I) || !reagents || !has_power())
		return 0
	var/room = max_capacity - reagents.total_volume
	var/pieces = min(I.amount, round(room / SURFACE_ICE_WATER))
	if (pieces <= 0)
		return 0
	reagents.add_reagent("water", pieces * SURFACE_ICE_WATER)
	I.use(pieces)
	return pieces

/obj/structure/reagent_dispensers/ice_melter/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/stack/ore/ice))
		if (!has_power())
			to_chat(user, SPAN_WARNING("\The [src] has no power to melt anything."))
			return
		var/pieces = melt_ice(W)
		if (pieces <= 0)
			to_chat(user, SPAN_WARNING("\The [src] is full."))
			return
		to_chat(user, SPAN_NOTICE("You melt [pieces] piece\s of ice in \the [src]."))
		return
	if (istype(W, /obj/item/stack/cable_coil))
		if (powersource)
			to_chat(user, SPAN_WARNING("It is already cabled."))
			return
		connect_cable(user, W)
		return
	return ..()

// The electrolyser melts ice for itself, at the same rate.
/obj/structure/life_support/electrolyser/proc/melt_ice(obj/item/stack/ore/ice/I)
	if (!istype(I))
		return 0
	var/pieces = min(I.amount, round((water_max - water) / SURFACE_ICE_WATER))
	if (pieces <= 0)
		return 0
	water += pieces * SURFACE_ICE_WATER
	I.use(pieces)
	return pieces

/obj/structure/life_support/electrolyser/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/stack/ore/ice))
		var/pieces = melt_ice(W)
		if (pieces <= 0)
			to_chat(user, SPAN_WARNING("\The [src] is full."))
			return
		to_chat(user, SPAN_NOTICE("You load [pieces] piece\s of ice into \the [src] ([round(water)]/[water_max])."))
		return
	return ..()
