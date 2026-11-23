// Powered cranes: the same hoist as the shear legs (lifting_machines.dm) with
// its own engine. A powered crane hauls only while it has fuel, burns one
// haul's worth a haul and works in a fraction of the hand time. Fuel is
// counted in hauls, so nothing ticks and nothing is stored but one number.
//
// The steam crane burns solid fuel. The tower crane burns motor fuel poured
// from a container, reaches further and lifts or lowers up to three levels.

#define POWER_CRANE_FACTOR 0.35
#define POWER_CRANE_MIN_TIME 10
#define TOWER_CRANE_FUEL_UNITS 5 // units of motor fuel a haul

// Hauls one unit of each solid fuel pays for.
var/global/list/steam_crane_fuel_rates = list(
	"coal" = 4, "charcoal" = 3, "wood" = 1, "plank" = 1, "bamboo" = 1)
var/global/list/tower_crane_fuels = list("diesel", "biodiesel", "gasoline")

/obj/structure/workshop_machine/shear_legs/crane/steam
	name = "steam crane"
	desc = "An iron crane with a boiler, a winding engine and a long jib. It hoists like shear legs, but reaches four tiles and needs steam: load coal, charcoal or wood, and each haul burns a little. Drag an unfastened object next to it onto the crane to raise or lower it one level through open air, or click it with an empty hand to haul up something lying below."
	icon = 'icons/obj/power_cranes.dmi'
	icon_state = "steam_crane"
	base_state = "steam_crane"
	reach = 4
	var/fuel = 0 // hauls it can still make
	var/fuel_limit = 40
	var/no_fuel_text = "has no steam. Load coal, charcoal or wood first."

/obj/structure/workshop_machine/shear_legs/crane/steam/examine(mob/user, distance)
	..(user, distance)
	to_chat(user, SPAN_NOTICE("It has fuel for [round(fuel)] of [fuel_limit] hauls. Click with an empty hand to recover an unfastened waterlogged engine from directly below open sea within reach."))

// TRUE, with the reason told, when the crane cannot haul for want of fuel.
/obj/structure/workshop_machine/shear_legs/crane/steam/proc/out_of_fuel(mob/user)
	if (fuel >= 1)
		return FALSE
	to_chat(user, SPAN_WARNING("\The [src] [no_fuel_text]"))
	return TRUE

// Hauls this item would add, taking what it pays for from it. 0 when it is no fuel.
/obj/structure/workshop_machine/shear_legs/crane/steam/proc/take_fuel(obj/item/I, mob/living/human/H)
	var/obj/item/stack/S = I
	var/each = istype(S) ? solid_fuel_unit_value(S, steam_crane_fuel_rates) : 0
	if (!each)
		return 0
	var/moved = min(S.amount, round((fuel_limit - fuel) / each))
	if (moved <= 0)
		to_chat(H, SPAN_WARNING("\The [src]'s bunker is full."))
		return -1
	record_wood_fuel(S, moved * each)
	S.use(moved)
	visible_message(SPAN_NOTICE("[H] stokes \the [src]."))
	return moved * each

/obj/structure/workshop_machine/shear_legs/crane/steam/attackby(obj/item/I, mob/living/human/H)
	if (!istype(H))
		return
	var/added = take_fuel(I, H)
	if (!added)
		return ..()
	if (added > 0)
		fuel += added

/obj/structure/workshop_machine/shear_legs/crane/steam/MouseDrop_T(atom/movable/dropping, mob/living/human/user)
	if (!istype(user) || !istype(dropping) || ismob(dropping) || user.incapacitated() || get_dist(src, user) > 1)
		return
	if (out_of_fuel(user))
		return
	return ..()

/obj/structure/workshop_machine/shear_legs/crane/steam/attack_hand(mob/living/human/H)
	if (!istype(H) || out_of_fuel(H))
		return
	return ..()

// A powered crane can lift a detached waterlogged engine through one open
// column of seawater. Normal loads still require the original open-air route.
/obj/structure/workshop_machine/shear_legs/crane/steam/haul_below_column(turf/source)
	if (!sea_layer_cell(source))
		return ..()
	var/turf/surface = locate(source.x, source.y, z)
	return sea_layer_open_surface(surface) && !surface.iscovered() && !(locate(/obj/roof) in surface)

/obj/structure/workshop_machine/shear_legs/crane/steam/haul_below_load(obj/load, turf/source)
	if (!sea_layer_cell(source))
		return ..()
	var/obj/structure/engine/E = load
	return istype(E) && E.waterlogged && !E.anchored && !E.fueltank && !length(E.connections) && !(locate(/obj/roof) in source)

// The engine winds: one haul of fuel, a fraction of the hand time.
/obj/structure/workshop_machine/shear_legs/crane/steam/driven_time(base_time)
	if (fuel < 1)
		return ..()
	fuel = max(0, fuel - 1)
	return max(POWER_CRANE_MIN_TIME, round(base_time * POWER_CRANE_FACTOR))

//////////////////////////////////////////////////////////////////////////////
// Tower crane

/obj/structure/workshop_machine/shear_legs/crane/steam/tower
	name = "tower crane"
	desc = "A steel lattice mast with a long counterweighted jib and a motor winch. It reaches six tiles and raises or lowers a load up to three levels at once through open air. Pour diesel, biodiesel or gasoline into its tank; each haul burns a little. Drag an unfastened object next to it onto the crane, or click it with an empty hand to haul up something lying on the level below."
	icon_state = "tower_crane"
	base_state = "tower_crane"
	reach = 6
	fuel_limit = 60
	no_fuel_text = "has an empty tank. Pour in diesel, biodiesel or gasoline first."
	var/lift_levels = 3

/obj/structure/workshop_machine/shear_legs/crane/steam/tower/take_fuel(obj/item/I, mob/living/human/H)
	var/obj/item/weapon/reagent_containers/C = I
	if (!istype(C) || !C.reagents)
		return 0
	var/room = round(fuel_limit - fuel)
	var/added = 0
	var/any = FALSE
	for (var/id in tower_crane_fuels)
		var/hauls = min(room - added, round(C.reagents.get_reagent_amount(id) / TOWER_CRANE_FUEL_UNITS))
		if (C.reagents.get_reagent_amount(id) >= TOWER_CRANE_FUEL_UNITS)
			any = TRUE
		if (hauls <= 0)
			continue
		C.reagents.remove_reagent(id, hauls * TOWER_CRANE_FUEL_UNITS)
		added += hauls
	if (!any)
		return 0
	if (!added)
		to_chat(H, SPAN_WARNING("\The [src]'s tank is full."))
		return -1
	visible_message(SPAN_NOTICE("[H] fills \the [src]'s tank."))
	return added

// Up to lift_levels up through open air above the load, and down any column
// of open air within reach to the first clear ground on each level.
/obj/structure/workshop_machine/shear_legs/crane/steam/tower/haul_choices(atom/movable/load)
	var/list/choices = list()
	var/level = z
	for (var/i = 1 to lift_levels)
		level = multiz_level_above(level)
		if (!level || !edge_open_air(locate(load.x, load.y, level)))
			break
		var/turf/top = landing_on(level)
		if (top)
			choices[i == 1 ? "Raise it 1 level" : "Raise it [i] levels"] = top
	var/list/columns = list()
	for (var/turf/T in range(reach, get_turf(src)))
		if (edge_open_air(T))
			columns += T
	level = z
	for (var/i = 1 to lift_levels)
		level = multiz_level_below(level)
		if (!level || !length(columns))
			break
		var/turf/best = null
		var/best_dist = 0
		var/list/deeper = list()
		for (var/turf/T in columns)
			var/turf/under = locate(T.x, T.y, level)
			if (edge_open_air(under))
				deeper += T
			if (!ledge_landing_clear(under))
				continue
			var/d = get_dist(T, src)
			if (!best || d < best_dist)
				best = under
				best_dist = d
		if (best)
			choices[i == 1 ? "Lower it 1 level" : "Lower it [i] levels"] = best
		columns = deeper
	return choices

#undef POWER_CRANE_FACTOR
#undef POWER_CRANE_MIN_TIME
#undef TOWER_CRANE_FUEL_UNITS
