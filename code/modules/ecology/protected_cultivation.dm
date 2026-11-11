// Protected cultivation (docs/protected-cultivation.md, issue #3049).
// A crop under a glass roof keeps growing out of season, at half speed, as long
// as its climate suits it. The roof grants nothing else: no water (there is no
// rain under a roof), no soil nutrition and no growth in an unsuitable climate.
// Every roof already shelters crops from storms, because roofs make an indoor
// area; opaque roofs are unchanged. Trees and mushrooms keep their own rules.
//
// This file is included after pollution.dm, so its override runs first and the
// pollution check still applies to greenhouse growth.

/proc/greenhouse_glass_over(turf/T)
	return istype(T) && (locate(/obj/roof/glass) in T)

// TRUE when the glass roof is what lets this crop grow right now.
/obj/structure/farming/plant/proc/greenhouse_extends_season()
	if (vstatic || stage > readyStageMax || istype(src, /obj/structure/farming/plant/tree))
		return FALSE
	var/turf/T = get_turf(src)
	if (!greenhouse_glass_over(T))
		return FALSE
	var/area/A = get_area(T)
	if (!A || !(A.climate in biomes))
		return FALSE
	return !(season in seasons)

/obj/structure/farming/plant/advance_stage_if_allowed(allow_stage)
	if (!allow_stage && greenhouse_extends_season() && prob(50))
		allow_stage = TRUE
	return ..(allow_stage)

/obj/structure/farming/plant/farming_diagnostics(farming_skill)
	. = ..()
	if (greenhouse_extends_season())
		. += "The glass roof keeps \the [src] growing out of season, at half speed. It still needs watering."
