// Airframe damage and fire from the ground.
//
// An aircraft in the air sits a level above the ground, so nothing on the
// ground can bump into it. What can reach it is fire aimed at its shadow:
// a projectile crossing a ground turf under an airborne frame may hit that
// frame instead of flying on. In low flight any weapon has a chance; at
// cruise only heavy weapons (heavy machine guns, cannon) reach, so a rifle
// cannot bring down a plane at height. Hits wear the airframe down and a
// hit on the nose can kill the engine; enough damage breaks the plane up
// in the air, which crash_land turns into a forced landing or a wreck.

#define AIRCRAFT_HIT_CHANCE_LOW 40
#define AIRCRAFT_HIT_CHANCE_CRUISE 20
#define AIRCRAFT_AA_DAMAGE 100         // projectile damage needed to reach cruise height: heavy machine guns and cannon
#define AIRCRAFT_HULL_FAILURE 150      // accumulated hit damage that breaks the airframe
#define AIRCRAFT_ENGINE_HIT_CHANCE 30  // a nose hit's chance of stopping the engine
#define AIRCRAFT_WELD_REPAIR 50
// Airframe damage a rough landing on open ground adds; a plane already shaken
// to half its hull strength lands rough on a broken landing gear instead.
#define AIRCRAFT_ROUGH_LANDING_DAMAGE 25

/obj/structure/vehicleparts/axis/aircraft
	var/airframe_damage = 0

// The airborne frame whose shadow falls on T, if any.
/obj/structure/vehicleparts/axis/aircraft/proc/frame_over(turf/T)
	if (!shadows || !T)
		return null
	for (var/obj/structure/vehicleparts/frame/F in shadows)
		if (shadow_turfs[shadows[F]] == T)
			return F
	return null

// Whether P can reach this aircraft at its current height.
/obj/structure/vehicleparts/axis/aircraft/proc/reachable_by(obj/item/projectile/P)
	if (!airborne() || !P)
		return FALSE
	if (flight_state == AIRCRAFT_CRUISE)
		return P.damage >= AIRCRAFT_AA_DAMAGE
	return TRUE

/obj/structure/vehicleparts/axis/aircraft/proc/hit_chance()
	return flight_state == AIRCRAFT_CRUISE ? AIRCRAFT_HIT_CHANCE_CRUISE : AIRCRAFT_HIT_CHANCE_LOW

// Called by the projectile code for every ground turf a projectile crosses
// while something is airborne. TRUE when the projectile hit an aircraft.
/proc/aircraft_overhead_fire(obj/item/projectile/P, turf/T)
	if (!airborne_aircraft.len || !P || !T)
		return FALSE
	for (var/obj/structure/vehicleparts/axis/aircraft/A in airborne_aircraft)
		if (QDELETED(A))
			continue
		var/obj/structure/vehicleparts/frame/F = A.frame_over(T)
		if (!F)
			continue
		if (!A.reachable_by(P))
			continue
		if (!prob(A.hit_chance()))
			continue
		A.airframe_hit(F, P)
		return TRUE
	return FALSE

// A projectile strikes frame F.
/obj/structure/vehicleparts/axis/aircraft/proc/airframe_hit(obj/structure/vehicleparts/frame/F, obj/item/projectile/P)
	if (!F || !P)
		return FALSE
	airframe_damage += max(1, P.damage)
	F.visible_message(SPAN_DANGER("\The [P] tears into \the [F]!"))
	var/turf/here = get_turf(F)
	if (here)
		playsound(here, 'sound/effects/bang.ogg', 50, TRUE)
	// Wheels and wall plating take their ordinary hit.
	F.bullet_act(P, null)
	if (istype(F, /obj/structure/vehicleparts/frame/car/aircraft/nose) && engine && engine.on && prob(AIRCRAFT_ENGINE_HIT_CHANCE))
		engine.on = FALSE
		engine.update_icon()
		F.visible_message(SPAN_DANGER("\The [engine] coughs and dies!"))
		pilot_message(SPAN_DANGER("The engine has stopped! Restart it or you will stall."))
	if (airframe_damage >= AIRCRAFT_HULL_FAILURE)
		for (var/mob/living/L in crew())
			to_chat(L, SPAN_DANGER("The airframe gives way!"))
		if (airborne())
			crash_land("airframe failure")
		return TRUE
	if (airframe_damage >= AIRCRAFT_HULL_FAILURE / 2)
		pilot_message(SPAN_WARNING("The airframe is shaking apart. Land soon."))
	return TRUE

/obj/structure/vehicleparts/axis/aircraft/proc/landing_gear_broken()
	for (var/obj/structure/vehicleparts/movement/W in wheels)
		if (W.broken)
			return TRUE
	return FALSE

// The landing gear is one part: mending it fixes every wheel at once.
/obj/structure/vehicleparts/axis/aircraft/proc/mend_landing_gear()
	for (var/obj/structure/vehicleparts/movement/W in wheels)
		W.broken = FALSE
		W.update_icon()

// Welding an airframe section on the ground mends the airframe, then the
// landing gear a crash broke.
/obj/structure/vehicleparts/frame/car/aircraft/attackby(obj/item/W, mob/living/human/user)
	var/obj/structure/vehicleparts/axis/aircraft/A = axis
	if (istype(W, /obj/item/weapon/weldingtool) && istype(A) && (A.airframe_damage > 0 || A.landing_gear_broken()))
		if (A.airborne())
			to_chat(user, SPAN_WARNING("You can't mend the airframe in flight."))
			return
		var/gear = !A.airframe_damage
		to_chat(user, SPAN_NOTICE(gear ? "You start welding the bent landing gear..." : "You start welding the torn airframe..."))
		if (do_after(user, 60, src) && istype(A) && !A.airborne())
			if (gear)
				A.mend_landing_gear()
				to_chat(user, SPAN_NOTICE("The landing gear is fixed. The plane can roll again."))
			else
				A.airframe_damage = max(0, A.airframe_damage - AIRCRAFT_WELD_REPAIR)
				to_chat(user, SPAN_NOTICE(A.airframe_damage ? "The airframe is sounder, but still torn." : (A.landing_gear_broken() ? "The airframe is whole again. Weld it once more to fix the landing gear." : "The airframe is whole again.")))
		return
	return ..()

/obj/structure/vehicleparts/axis/aircraft/examine(mob/user, distance)
	. = ..()
	if (airframe_damage >= AIRCRAFT_HULL_FAILURE / 2)
		to_chat(user, SPAN_DANGER("The airframe is badly torn."))
	else if (airframe_damage > 0)
		to_chat(user, SPAN_WARNING("The airframe is holed in places."))
	if (landing_gear_broken())
		to_chat(user, SPAN_WARNING("The landing gear is broken. Weld any part of the airframe to fix it."))

// Down on open ground without a runway: the plane lands, but the rough ground
// strains the airframe and drags it to a stop. One already badly shaken lands
// on a broken landing gear, which a weld mends.
/obj/structure/vehicleparts/axis/aircraft/proc/rough_landing(down)
	if (!aircraft_shift(down))
		return FALSE
	set_flight_state(AIRCRAFT_GROUND)
	var/worn = airframe_damage >= AIRCRAFT_HULL_FAILURE / 2
	airframe_damage = min(airframe_damage + AIRCRAFT_ROUGH_LANDING_DAMAGE, AIRCRAFT_HULL_FAILURE - 1)
	currentspeed = 0
	moving = FALSE
	if (worn)
		for (var/obj/structure/vehicleparts/movement/W in wheels)
			W.broken = TRUE
			W.update_icon()
		visible_message(SPAN_DANGER("\The [src] slams down on the rough ground and its landing gear buckles!"))
		pilot_message(SPAN_WARNING("The landing gear is broken. Weld any part of the airframe to fix it."))
	else
		visible_message(SPAN_WARNING("\The [src] bounces down on the rough ground and lurches to a stop."))
		pilot_message(SPAN_WARNING("A rough landing: the airframe took a beating. Weld it to repair it."))
	return TRUE

#undef AIRCRAFT_HIT_CHANCE_LOW
#undef AIRCRAFT_HIT_CHANCE_CRUISE
#undef AIRCRAFT_AA_DAMAGE
#undef AIRCRAFT_HULL_FAILURE
#undef AIRCRAFT_ENGINE_HIT_CHANCE
#undef AIRCRAFT_WELD_REPAIR
#undef AIRCRAFT_ROUGH_LANDING_DAMAGE
