// Fighting a pedal airship from the ground (pedal_airship.dm).
//
// An airship aloft floats on the open-air level, out of reach of anything on
// the ground but fire aimed under it, the way ground fire reaches low planes
// (aircraft_damage.dm). Its gas bag is a big, slow target: a bullet or arrow
// crossing the tile under it may strike it, whatever fired it. Most hits hole
// the bag; some strike the gondola and whoever rides in it. Every hole costs
// lift, and with too many it cannot stay up and sinks to the ground. Fire
// arrows and incendiary rounds set the gas alight: the airship falls and its
// rider is burnt and bruised. On the ground, cloth patches the holes.

#define PEDAL_AIRSHIP_HIT_CHANCE 50
// Share of hits that strike the gondola and its rider instead of the bag.
#define PEDAL_AIRSHIP_RIDER_HIT_CHANCE 25
// Share of lift each hole costs.
#define PEDAL_AIRSHIP_HOLE_LIFT 0.2
// Holes at which it can no longer stay up.
#define PEDAL_AIRSHIP_SINK_HOLES 4
// A burnt bag counts as this many holes to patch.
#define PEDAL_AIRSHIP_BURNT_HOLES 6
#define PEDAL_AIRSHIP_PATCH_TIME 40

/obj/structure/vehicle/bicycle/airship
	var/bag_holes = 0

// Share of its full lift the holed bag still gives.
/obj/structure/vehicle/bicycle/airship/proc/bag_lift()
	return max(0, 1 - bag_holes * PEDAL_AIRSHIP_HOLE_LIFT)

/obj/structure/vehicle/bicycle/airship/proc/bag_too_holed()
	return bag_holes >= PEDAL_AIRSHIP_SINK_HOLES

// Whether the holed bag can still hold H and what H carries up.
/obj/structure/vehicle/bicycle/airship/proc/bag_holds(mob/living/human/H)
	if (bag_too_holed())
		return FALSE
	if (!H)
		return TRUE
	return pedal_airship_can_lift(bicycle_load_ratio(bicycle_carried_weight(H), H.getStatCoeff("strength")) / max(0.01, bag_lift()))

// Projectiles that set the gas alight.
/proc/projectile_ignites_gas(obj/item/projectile/P)
	return istype(P, /obj/item/projectile/arrow/arrow/fire) || istype(P, /obj/item/projectile/arrow/bolt/fire) || istype(P, /obj/item/projectile/bullet/shotgun/incendiary)

// Called by the projectile code for every ground turf a projectile crosses
// while something flies overhead. Returns what it struck (the turf under an
// aircraft or airship, or an airship's rider), else null.
/proc/airborne_overhead_hit(obj/item/projectile/P, turf/T)
	if (airborne_aircraft.len && aircraft_overhead_fire(P, T))
		return T
	if (aloft_pedal_airships.len)
		. = pedal_airship_overhead_fire(P, T)
		if (.)
			return
	if (air_hull_crafts.len)
		return air_hull_overhead_fire(P, T)
	return null

/proc/pedal_airship_overhead_fire(obj/item/projectile/P, turf/T)
	if (!P || !T || P.is_shrapnel)
		return null
	for (var/obj/structure/vehicle/bicycle/airship/S in aloft_pedal_airships)
		if (QDELETED(S) || !S.aloft || S.ground_turf() != T)
			continue
		// Its own rider's shots go down, not up into the bag.
		if (P.firer && (P.firer in S.ontop))
			continue
		if (!prob(PEDAL_AIRSHIP_HIT_CHANCE))
			continue
		return S.struck_by(P, T)
	return null

// P strikes the airship from below. Returns what it hit: the rider, or the
// ground turf T under the bag.
/obj/structure/vehicle/bicycle/airship/proc/struck_by(obj/item/projectile/P, turf/T)
	var/mob/living/rider = driver
	if (rider && (rider in ontop) && prob(PEDAL_AIRSHIP_RIDER_HIT_CHANCE))
		visible_message(SPAN_DANGER("\The [P] punches up through the gondola of \the [src]!"))
		P.def_zone = pickweight(list("l_leg" = 3, "r_leg" = 3, "groin" = 2, "chest" = 1))
		P.attack_mob(rider, 1)
		return rider
	if (projectile_ignites_gas(P))
		ignite_bag()
		return T
	hole_bag(P)
	return T

/obj/structure/vehicle/bicycle/airship/proc/hole_bag(obj/item/projectile/P)
	bag_holes++
	visible_message(SPAN_DANGER("\The [P] rips through the gas bag of \the [src]!"))
	playsound(get_turf(src), 'sound/effects/bang.ogg', 30, TRUE)
	var/mob/living/human/H = driver
	if (aloft && !bag_holds(istype(H) && (H in ontop) ? H : null))
		if (driver)
			to_chat(driver, SPAN_DANGER("Gas hisses out of the holes and the airship sinks!"))
		visible_message(SPAN_WARNING("\The [src] loses its gas and sinks."))
		set_down()
	else if (driver && bag_holes)
		to_chat(driver, SPAN_WARNING("The gas bag is holed in [bag_holes] place\s. It lifts less, and [PEDAL_AIRSHIP_SINK_HOLES] holes will bring it down."))
	return TRUE

// The gas catches: the airship falls and the rider is hurt in the fire and the fall.
/obj/structure/vehicle/bicycle/airship/proc/ignite_bag()
	bag_holes = max(bag_holes, PEDAL_AIRSHIP_BURNT_HOLES)
	visible_message(SPAN_DANGER("The gas bag of \the [src] bursts into flame!"))
	playsound(get_turf(src), 'sound/effects/bang.ogg', 60, TRUE)
	var/list/riders = list()
	for (var/mob/living/L in ontop)
		riders += L
	if (aloft)
		set_down()
		visible_message(SPAN_DANGER("\The [src] crashes down in a burning heap!"))
	for (var/mob/living/L in riders)
		to_chat(L, SPAN_DANGER("The gas bag burns over your head and you fall!"))
		L.adjustBruteLoss(rand(15, 30))
		L.adjustBurnLoss(rand(10, 20))
		L.fire_stacks = max(L.fire_stacks, 2)
		L.IgniteMob()
	return TRUE

// Cloth over a hole, one at a time, on the ground.
/obj/structure/vehicle/bicycle/airship/proc/patch_bag(obj/item/stack/material/cloth/C, mob/living/human/user)
	if (!istype(C) || !bag_holes)
		return FALSE
	if (aloft)
		to_chat(user, SPAN_WARNING("You cannot reach the gas bag's holes up here."))
		return TRUE
	to_chat(user, SPAN_NOTICE("You start stitching a patch over a hole in the gas bag..."))
	if (!do_after(user, PEDAL_AIRSHIP_PATCH_TIME, src) || aloft || !bag_holes || QDELETED(C) || !C.use(1))
		return TRUE
	bag_holes--
	to_chat(user, SPAN_NOTICE(bag_holes ? "You patch a hole. [bag_holes] more to go." : "You patch the last hole. The gas bag is whole again."))
	return TRUE

/obj/structure/vehicle/bicycle/airship/examine(mob/user, distance)
	. = ..()
	if (bag_holes >= PEDAL_AIRSHIP_BURNT_HOLES)
		to_chat(user, SPAN_DANGER("Its gas bag is burnt and torn. Patch it with cloth before it can fly again."))
	else if (bag_too_holed())
		to_chat(user, SPAN_DANGER("Its gas bag is holed in [bag_holes] places and cannot lift. Patch it with cloth."))
	else if (bag_holes)
		to_chat(user, SPAN_WARNING("Its gas bag is holed in [bag_holes] place\s, so it lifts less. Patch it with cloth."))

// ---- Fighting from the gondola ----
//
// The rider sees the ground below through the airship's ground view and can
// shoot or throw at it: the shot or throw starts on the ground under the
// gondola, above the hills, and goes on from there as on the ground. Things
// dropped over the side fall onto whoever is below (building_levels.dm);
// glass bottles burst where they land, so a lit firebomb sets the ground alight.

// The airship user rides aloft, or null.
/proc/aloft_airship_ridden_by(mob/user)
	if (!user)
		return null
	var/obj/structure/vehicle/bicycle/airship/S = user.buckled
	if (!istype(S) || !S.aloft || !(user in S.ontop))
		return null
	return S

// The ground turf under user when user rides an airship aloft or stands on
// a crewed airship's deck (air_hull.dm), else null.
/proc/airborne_ground_under(mob/user)
	var/obj/structure/vehicle/bicycle/airship/S = aloft_airship_ridden_by(user)
	if (S)
		return S.ground_turf()
	// An airship's deck: the first solid level under it, however high she flies.
	return air_hull_under(user) ? air_hull_solid_below(get_turf(user)) : null

// Open air clicked from a gondola or deck means what is seen through it: the
// first solid turf under it. Anything else is aimed at as it is.
/proc/airborne_aim_turf(mob/user, turf/T)
	var/turf/here = get_turf(user)
	if (!T || !here || T.z != here.z || !air_hull_open_air(T) || !airborne_ground_under(user))
		return T
	var/turf/G = air_hull_solid_below(T)
	return G ? G : T

// Where a shot or throw by user at target starts: the ground under the
// gondola or deck when target is on that ground.
/proc/airborne_launch_turf(mob/user, atom/target)
	var/turf/T = get_turf(target)
	if (!T)
		return null
	var/turf/G = airborne_ground_under(user)
	if (!G || T.z != G.z)
		return null
	return G

// TRUE when firer shoots from a gondola or deck over start.
/proc/pedal_airship_rider_shot(mob/firer, turf/start)
	var/turf/G = airborne_ground_under(firer)
	return G && G == start

// A bottle that falls a storey or more bursts; a lit firebomb sets the ground alight.
/obj/item/weapon/reagent_containers/food/drinks/bottle/landed_from_fall(turf/T)
	if (!isGlass || !T)
		return
	var/power = calculate_alcohol_power()
	var/atom/against = T
	for (var/mob/living/L in T)
		if (!L.lying)
			against = L
			break
	if (reagents && reagents.total_volume > 0)
		against.visible_message(SPAN_WARNING("\The [src] bursts and splashes its contents over \the [against]!"))
		reagents.splash(against, reagents.total_volume)
	else
		against.visible_message(SPAN_WARNING("\The [src] smashes on \the [T]!"))
	shatter(T, against, power)

/obj/item/proc/landed_from_fall(turf/T)
	return

#undef PEDAL_AIRSHIP_HIT_CHANCE
#undef PEDAL_AIRSHIP_RIDER_HIT_CHANCE
#undef PEDAL_AIRSHIP_HOLE_LIFT
#undef PEDAL_AIRSHIP_SINK_HOLES
#undef PEDAL_AIRSHIP_BURNT_HOLES
#undef PEDAL_AIRSHIP_PATCH_TIME
