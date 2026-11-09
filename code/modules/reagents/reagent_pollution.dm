// Spilled fuel, oil and harsh chemicals soil the ground where they land
// (code/modules/ecology/pollution.dm). Included after Chemistry-Reagents.dm so
// this extends the base touch_turf.
/datum/reagent/var/pollutant = 0 // pollution per unit spilled on the ground

/datum/reagent/petroleum
	pollutant = 1
/datum/reagent/gasoline
	pollutant = 1
/datum/reagent/diesel
	pollutant = 1
/datum/reagent/biodiesel
	pollutant = 0.5
/datum/reagent/mercury
	pollutant = 3
/datum/reagent/acid
	pollutant = 1

/datum/reagent/touch_turf(turf/T, amount)
	. = ..()
	if (pollutant && isnum(amount) && amount > 0)
		pollution_spread(T, amount * pollutant, 1)
