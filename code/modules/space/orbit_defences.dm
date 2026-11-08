// ============================================================
// Station defences (orbital stations, stage E)
// ------------------------------------------------------------
// - Hull armour plate (1969): fitted to a habitat module's core, each plate
//   (up to three) soaks one debris or meteorite strike that would have holed
//   the hull. The module's plates are a plain saved number.
// - Point-defence turret (2013): cabled to power, it shoots down most debris
//   and meteorites heading for a module within seven tiles, and fires on
//   boarding ferries: each ready turret near a port adds 15 seconds to a
//   forced docking there (two at most count).
//
// Nothing here is a world.time stamp; turrets do nothing between strikes.
// ============================================================

#define ORBIT_ARMOUR_MAX 3
#define ORBIT_DEFENCE_RANGE 7
#define ORBIT_DEFENCE_BOARDING_DELAY 150
#define ORBIT_DEFENCE_BOARDING_TURRETS 2

var/global/list/orbit_point_defences = list()

// ---------------------------------------------------------------- armour

/obj/structure/habitat_core
	// Hull armour plates fitted; each soaks one strike.
	var/armour = 0

/obj/item/hull_plate
	name = "hull armour plate"
	desc = "A curved plate of layered steel and padding. Fit it to a habitat module's core to stop one strike of debris or a meteorite. A module takes three."
	icon = 'icons/obj/materials.dmi'
	icon_state = "sheet-plasteel"
	w_class = ITEM_SIZE_LARGE
	flammable = FALSE

/obj/structure/habitat_core/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/hull_plate))
		if (armour >= ORBIT_ARMOUR_MAX)
			to_chat(user, SPAN_WARNING("\The [src]'s module already carries [ORBIT_ARMOUR_MAX] armour plates."))
			return
		if (!user.drop_from_inventory(W))
			return
		qdel(W)
		armour++
		user.visible_message(SPAN_NOTICE("[user] bolts an armour plate over \the [src]'s module."), SPAN_NOTICE("You bolt an armour plate over the module ([armour]/[ORBIT_ARMOUR_MAX])."))
		return
	return ..()

/obj/structure/habitat_core/examine(mob/user)
	..()
	if (armour)
		to_chat(user, SPAN_NOTICE("Its module carries [armour] armour plate\s."))

// ---------------------------------------------------------------- turret

/obj/structure/point_defence
	name = "point-defence turret"
	desc = "A radar-laid rapid-fire gun on a swivel. Cabled to power, it shoots down debris and meteorites heading for modules within seven tiles, and fires on ferries forcing a docking nearby."
	icon = 'icons/obj/cannon.dmi'
	icon_state = "modern_cannon"
	anchored = TRUE
	density = TRUE
	flammable = FALSE
	powerneeded = 30
	// Percent of strikes it stops.
	var/intercept_chance = 75

/obj/structure/point_defence/New()
	..()
	orbit_point_defences |= src

/obj/structure/point_defence/Destroy()
	orbit_point_defences -= src
	return ..()

/obj/structure/point_defence/examine(mob/user)
	..()
	if (!map || map.ordinal_age < 8)
		to_chat(user, SPAN_WARNING("Its fire control needs 2013 electronics."))
	else if (!powersource)
		to_chat(user, SPAN_WARNING("Run a cable to it to power it."))

/obj/structure/point_defence/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/stack/cable_coil))
		if (powersource)
			to_chat(user, SPAN_WARNING("It is already cabled."))
			return
		connect_cable(user, W)
		return
	return ..()

// TRUE when the turret can fire now.
/obj/structure/point_defence/proc/ready()
	if (!isturf(loc) || !map || map.ordinal_age < 8)
		return FALSE
	return powersource && draw_cable_power()

// Ready turrets within range of T.
/proc/orbit_point_defences_near(turf/T)
	var/list/found = list()
	if (!T)
		return found
	for (var/obj/structure/point_defence/D in orbit_point_defences)
		if (!QDELETED(D) && D.z == T.z && get_dist(D, T) <= ORBIT_DEFENCE_RANGE && D.ready())
			found += D
	return found

// Extra time a forced docking at port P takes under its turrets' fire.
/proc/orbit_point_defence_delay(obj/structure/docking_port/P)
	if (!P)
		return 0
	return min(length(orbit_point_defences_near(get_turf(P))), ORBIT_DEFENCE_BOARDING_TURRETS) * ORBIT_DEFENCE_BOARDING_DELAY

// ---------------------------------------------------------------- strikes

// Called before a strike holes module C (surface_hazards.dm). TRUE when a
// turret shot it down or armour soaked it.
/proc/habitat_strike_blocked(obj/structure/habitat_core/C)
	if (!C)
		return FALSE
	var/what = orbit_world() ? "debris" : "a meteorite"
	for (var/obj/structure/point_defence/D in orbit_point_defences_near(get_turf(C)))
		if (prob(D.intercept_chance))
			D.visible_message(SPAN_NOTICE("\The [D] swings round and shreds [what] before it reaches the hull."))
			return TRUE
	if (C.armour > 0)
		C.armour--
		C.visible_message(SPAN_WARNING("Something slams into the hull and an armour plate takes the blow ([C.armour] left)."))
		return TRUE
	return FALSE

#undef ORBIT_ARMOUR_MAX
#undef ORBIT_DEFENCE_RANGE
#undef ORBIT_DEFENCE_BOARDING_DELAY
#undef ORBIT_DEFENCE_BOARDING_TURRETS
