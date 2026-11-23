// Scheduled maintenance asks only about aircraft with an operator who can
// still get them out of danger. This is not an emergency-save veto.

#define FLIGHT_HELM_ACTIVITY (45 SECONDS)

/proc/flight_save_fit_operator(mob/living/human/H)
	return istype(H) && !QDELETED(H) && H.client && H.client.mob == H && !H.incapacitated(INCAPACITATION_DISABLED|INCAPACITATION_RESTRAINED)

/proc/any_flight_at_disconnect_risk()
	for (var/obj/structure/vehicleparts/axis/aircraft/A in airborne_aircraft)
		if (!QDELETED(A) && A.scheduled_save_flight_risk())
			return TRUE
	for (var/datum/craft/air/C in air_hull_crafts)
		if (!QDELETED(C) && C.scheduled_save_flight_risk())
			return TRUE
	return FALSE

/obj/structure/vehicleparts/axis/aircraft/proc/scheduled_save_flight_risk()
	if (!airborne() || air_crossing_asking || air_crossing_hold > world.time)
		return FALSE
	var/mob/living/human/H = driver
	var/obj/structure/bed/chair/drivers/seat = wheel?.drivingchair
	if (!flight_save_fit_operator(H) || QDELETED(seat) || seat.axis != src || seat.buckled_mob != H || H.buckled != seat || wheel.loc != H)
		return FALSE
	// Match the restore path. It puts the plane down gently only if its
	// existing footprint fits straight below; an offset is a hard landing.
	if (!aloft_over_open_air())
		return FALSE
	var/down = ground_z()
	return !down || !!clear_at_level(down)

/datum/craft/air
	var/tmp/mob/living/human/last_helm_operator
	var/tmp/last_helm_operator_until = 0

/datum/craft/air/proc/note_flight_helm(mob/living/human/H)
	last_helm_operator = H
	last_helm_operator_until = world.time + FLIGHT_HELM_ACTIVITY

/datum/craft/air/proc/scheduled_save_flight_risk()
	var/mob/living/human/H = last_helm_operator
	if (!changing_level || world.time >= last_helm_operator_until || !flight_save_fit_operator(H))
		return FALSE
	var/datum/craft_body/built/air/B = body
	if (!istype(B) || !B.placed() || B.landed())
		return FALSE
	var/turf/helm = B.origin()
	var/turf/seat = get_turf(H)
	if (!helm || !seat || helm.z != seat.z || get_dist(seat, helm) > 1 || !B.contains(seat))
		return FALSE
	// Manual descent and ordinary flight need no hold: restore anchors
	// the airship. A live crew can still patch or lighten a sinking hull
	// that retains at least half its required lift.
	var/have = B.lift()
	var/need = B.load()
	return have < need && have * 2 >= need

#undef FLIGHT_HELM_ACTIVITY
