/*
	Turf manipulation
*/

//Transports a turf from a source turf to a target turf, moving all of the turf's contents and making the target a copy of the source.
/proc/transport_turf_contents(turf/source, turf/target)

	var/turf/new_turf = target.ChangeTurf(source.type, 1, 1)
	new_turf.transport_properties_from(source)

	for(var/obj/O in source)
		if(O.simulated)
			O.forceMove(new_turf)
		else if(istype(O,/obj/effect))
			var/obj/effect/E = O
			E.forceMove(new_turf)

	for(var/mob/M in source)
		if(isEye(M)) continue // If we need to check for more mobs, I'll add a variable
		M.forceMove(new_turf)

	return new_turf
