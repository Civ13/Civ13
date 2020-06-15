/datum/gas_mixture
	//Associative list of gas moles.
	//Gases with FALSE moles are not tracked and are pruned by update_values()
	var/list/gas = list()
	//Temperature in Kelvin of this gas mix.
	var/temperature = FALSE

	//Sum of all the gas moles in this mix.  Updated by update_values()
	var/total_moles = FALSE

	//Size of the group this gas_mixture is representing.  TRUE for singletons.
	var/group_multiplier = TRUE

	//List of active tile overlays for this gas_mixture.  Updated by check_tile_graphic()
	var/list/graphic = list()

	var/volume = 2500

//Takes a gas string and the amount of moles to adjust by.  Calls update_values() if update isn't 0.
/datum/gas_mixture/proc/adjust_gas(gasid, moles, update = TRUE)
	if (moles == FALSE)
		return

	if (group_multiplier != TRUE)
		gas[gasid] += moles/group_multiplier
	else
		gas[gasid] += moles

	if (update)
		update_values()


//Same as adjust_gas(), but takes a temperature which is mixed in with the gas.
/datum/gas_mixture/proc/adjust_gas_temp(gasid, moles, temp, update = TRUE)
	if (moles == FALSE)
		return

	if (moles > 0 && abs(temperature - temp) > MINIMUM_TEMPERATURE_DELTA_TO_CONSIDER)
		var/self_heat_capacity = heat_capacity()
		var/giver_heat_capacity = gas_data.specific_heat[gasid] * moles
		var/combined_heat_capacity = giver_heat_capacity + self_heat_capacity
		if (combined_heat_capacity != FALSE)
			temperature = (temp * giver_heat_capacity + temperature * self_heat_capacity) / combined_heat_capacity

	if (group_multiplier != TRUE)
		gas[gasid] += moles/group_multiplier
	else
		gas[gasid] += moles

	if (update)
		update_values()


//Variadic version of adjust_gas().  Takes any number of gas and mole pairs and applies them.
/datum/gas_mixture/proc/adjust_multi()
	ASSERT(!(args.len % 2))

	for (var/i = TRUE; i < args.len; i += 2)
		adjust_gas(args[i], args[i+1], update = FALSE)

	update_values()


//Variadic version of adjust_gas_temp().  Takes any number of gas, mole and temperature associations and applies them.
/datum/gas_mixture/proc/adjust_multi_temp()
	ASSERT(!(args.len % 3))

	for (var/i = TRUE; i < args.len; i += 3)
		adjust_gas_temp(args[i], args[i + 1], args[i + 2], update = FALSE)

	update_values()


//Merges all the gas from another mixture into this one.  Respects group_multipliers and adjusts temperature correctly.
//Does not modify giver in any way.
/datum/gas_mixture/proc/merge(const/datum/gas_mixture/giver)
	if (!giver)
		return

	if (abs(temperature-giver.temperature)>MINIMUM_TEMPERATURE_DELTA_TO_CONSIDER)
		var/self_heat_capacity = heat_capacity()
		var/giver_heat_capacity = giver.heat_capacity()
		var/combined_heat_capacity = giver_heat_capacity + self_heat_capacity
		if (combined_heat_capacity != FALSE)
			temperature = (giver.temperature*giver_heat_capacity + temperature*self_heat_capacity)/combined_heat_capacity

	if ((group_multiplier != TRUE)||(giver.group_multiplier != TRUE))
		for (var/g in giver.gas)
			gas[g] += giver.gas[g] * giver.group_multiplier / group_multiplier
	else
		for (var/g in giver.gas)
			gas[g] += giver.gas[g]

	update_values()


/datum/gas_mixture/proc/equalize(datum/gas_mixture/sharer)
	var/our_heatcap = heat_capacity()
	var/share_heatcap = sharer.heat_capacity()

	for (var/g in gas|sharer.gas)
		var/comb = gas[g] + sharer.gas[g]
		comb /= volume + sharer.volume
		gas[g] = comb * volume
		sharer.gas[g] = comb * sharer.volume

	if (our_heatcap + share_heatcap)
		temperature = ((temperature * our_heatcap) + (sharer.temperature * share_heatcap)) / (our_heatcap + share_heatcap)
	sharer.temperature = temperature

	return TRUE


//Returns the heat capacity of the gas mix based on the specific heat of the gases.
/datum/gas_mixture/proc/heat_capacity()
	. = FALSE
	for (var/g in gas)
		. += gas_data.specific_heat[g] * gas[g]
	. *= group_multiplier


//Adds or removes thermal energy. Returns the actual thermal energy change, as in the case of removing energy we can't go below TCMB.
/datum/gas_mixture/proc/add_thermal_energy(var/thermal_energy)
	if (total_moles == FALSE)
		return FALSE

	var/heat_capacity = heat_capacity()
	if (thermal_energy < 0)
		if (temperature < TCMB)
			return FALSE
		var/thermal_energy_limit = -(temperature - TCMB)*heat_capacity	//ensure temperature does not go below TCMB
		thermal_energy = max( thermal_energy, thermal_energy_limit )	//thermal_energy and thermal_energy_limit are negative here.
	temperature += thermal_energy/heat_capacity
	return thermal_energy

//Returns the thermal energy change required to get to a new temperature
/datum/gas_mixture/proc/get_thermal_energy_change(var/new_temperature)
	return heat_capacity()*(max(new_temperature, FALSE) - temperature)


//Technically vacuum doesn't have a specific entropy. Just use a really big number (infinity would be ideal) here so that it's easy to add gas to vacuum and hard to take gas out.
#define SPECIFIC_ENTROPY_VACUUM		150000


//Returns the ideal gas specific entropy of the whole mix. This is the entropy per mole of /mixed/ gas.
/datum/gas_mixture/proc/specific_entropy()
	if (!gas.len || total_moles == FALSE)
		return SPECIFIC_ENTROPY_VACUUM

	. = FALSE
	for (var/g in gas)
		. += gas[g] * specific_entropy_gas(g)
	. /= total_moles


/*
	It's arguable whether this should even be called entropy anymore. It's more "based on" entropy than actually entropy now.

	Returns the ideal gas specific entropy of a specific gas in the mix. This is the entropy due to that gas per mole of /that/ gas in the mixture, not the entropy due to that gas per mole of gas mixture.

	For the purposes of SS13, the specific entropy is just a number that tells you how hard it is to move gas. You can replace this with whatever you want.
	Just remember that returning a SMALL number == adding gas to this gas mix is HARD, taking gas away is EASY, and that returning a LARGE number means the opposite (so a vacuum should approach infinity).

	So returning a constant/(partial pressure) would probably do what most players expect. Although the version I have implemented below is a bit more nuanced than simply TRUE/P in that it scales in a way
	which is bit more realistic (natural log), and returns a fairly accurate entropy around room temperatures and pressures.
*/
/datum/gas_mixture/proc/specific_entropy_gas(var/gasid)
	if (!(gasid in gas) || gas[gasid] == FALSE)
		return SPECIFIC_ENTROPY_VACUUM	//that gas isn't here

	//group_multiplier gets divided out in volume/gas[gasid] - also, V/(m*T) = R/(partial pressure)
	var/molar_mass = gas_data.molar_mass[gasid]
	var/specific_heat = gas_data.specific_heat[gasid]
	return R_IDEAL_GAS_EQUATION * ( log( (IDEAL_GAS_ENTROPY_CONSTANT*volume/(gas[gasid] * temperature)) * (molar_mass*specific_heat*temperature)**(2/3) + 1 ) +  15 )

	//alternative, simpler equation
	//var/partial_pressure = gas[gasid] * R_IDEAL_GAS_EQUATION * temperature / volume
	//return R_IDEAL_GAS_EQUATION * ( log (1 + IDEAL_GAS_ENTROPY_CONSTANT/partial_pressure) + 20 )


//Updates the total_moles count and trims any empty gases.
/datum/gas_mixture/proc/update_values()
	total_moles = FALSE
	for (var/g in gas)
		if (gas[g] <= 0)
			gas -= g
		else
			total_moles += gas[g]


//Returns the pressure of the gas mix.  Only accurate if there have been no gas modifications since update_values() has been called.
/datum/gas_mixture/proc/return_pressure()
	if (volume)
		return total_moles * R_IDEAL_GAS_EQUATION * temperature / volume
	return FALSE


//Removes moles from the gas mixture and returns a gas_mixture containing the removed air.
/datum/gas_mixture/proc/remove(amount)
	amount = min(amount, total_moles * group_multiplier) //Can not take more air than the gas mixture has!
	if (amount <= 0)
		return null

	var/datum/gas_mixture/removed = new

	for (var/g in gas)
		removed.gas[g] = QUANTIZE((gas[g] / total_moles) * amount)
		gas[g] -= removed.gas[g] / group_multiplier

	removed.temperature = temperature
	update_values()
	removed.update_values()

	return removed


//Removes a ratio of gas from the mixture and returns a gas_mixture containing the removed air.
/datum/gas_mixture/proc/remove_ratio(ratio, out_group_multiplier = TRUE)
	if (ratio <= 0)
		return null
	out_group_multiplier = between(1, out_group_multiplier, group_multiplier)

	ratio = min(ratio, TRUE)

	var/datum/gas_mixture/removed = new
	removed.group_multiplier = out_group_multiplier

	for (var/g in gas)
		removed.gas[g] = (gas[g] * ratio * group_multiplier / out_group_multiplier)
		gas[g] = gas[g] * (1 - ratio)

	removed.temperature = temperature
	removed.volume = volume * group_multiplier / out_group_multiplier
	update_values()
	removed.update_values()

	return removed

//Removes a volume of gas from the mixture and returns a gas_mixture containing the removed air with the given volume
/datum/gas_mixture/proc/remove_volume(removed_volume)
	var/datum/gas_mixture/removed = remove_ratio(removed_volume/(volume*group_multiplier), TRUE)
	removed.volume = removed_volume
	return removed

//Removes moles from the gas mixture, limited by a given flag.  Returns a gax_mixture containing the removed air.
/datum/gas_mixture/proc/remove_by_flag(flag, amount)
	if (!flag || amount <= 0)
		return

	var/sum = FALSE
	for (var/g in gas)
		if (gas_data.flags[g] & flag)
			sum += gas[g]

	var/datum/gas_mixture/removed = new

	for (var/g in gas)
		if (gas_data.flags[g] & flag)
			removed.gas[g] = QUANTIZE((gas[g] / sum) * amount)
			gas[g] -= removed.gas[g] / group_multiplier

	removed.temperature = temperature
	update_values()
	removed.update_values()

	return removed


//Copies gas and temperature from another gas_mixture.
/datum/gas_mixture/proc/copy_from(const/datum/gas_mixture/sample)
	gas = sample.gas.Copy()
	temperature = sample.temperature

	update_values()

	return TRUE

/datum/gas_mixture/proc/react()
//	zburn(null, force_burn=0, no_check=0) //could probably just call zburn() here with no args but I like being explicit.


//Rechecks the gas_mixture and adjusts the graphic list if needed.
//Two lists can be passed by reference if you need know specifically which graphics were added and removed.
/datum/gas_mixture/proc/check_tile_graphic(list/graphic_add = null, list/graphic_remove = null)
	for (var/g in gas_data.overlay_limit)
		if (graphic.Find(gas_data.tile_overlay[g]))
			//Overlay is already applied for this gas, check if it's still valid.
			if (gas[g] <= gas_data.overlay_limit[g])
				if (!graphic_remove)
					graphic_remove = list()
				graphic_remove += gas_data.tile_overlay[g]
		else
			//Overlay isn't applied for this gas, check if it's valid and needs to be added.
			if (gas[g] > gas_data.overlay_limit[g])
				if (!graphic_add)
					graphic_add = list()
				graphic_add += gas_data.tile_overlay[g]

	. = FALSE
	//Apply changes
	if (graphic_add && graphic_add.len)
		graphic += graphic_add
		. = TRUE
	if (graphic_remove && graphic_remove.len)
		graphic -= graphic_remove
		. = TRUE


//Simpler version of merge(), adjusts gas amounts directly and doesn't account for temperature or group_multiplier.
/datum/gas_mixture/proc/add(datum/gas_mixture/right_side)
	for (var/g in right_side.gas)
		gas[g] += right_side.gas[g]

	update_values()
	return TRUE


//Simpler version of remove(), adjusts gas amounts directly and doesn't account for group_multiplier.
/datum/gas_mixture/proc/subtract(datum/gas_mixture/right_side)
	for (var/g in right_side.gas)
		gas[g] -= right_side.gas[g]

	update_values()
	return TRUE


//Multiply all gas amounts by a factor.
/datum/gas_mixture/proc/multiply(factor)
	for (var/g in gas)
		gas[g] *= factor

	update_values()
	return TRUE


//Divide all gas amounts by a factor.
/datum/gas_mixture/proc/divide(factor)
	for (var/g in gas)
		gas[g] /= factor

	update_values()
	return TRUE

//Equalizes a list of gas mixtures.  Used for pipe networks.
/proc/equalize_gases(datum/gas_mixture/list/gases)
	//Calculate totals from individual components
	var/total_volume = FALSE
	var/total_thermal_energy = FALSE
	var/total_heat_capacity = FALSE

	var/list/total_gas = list()
	for (var/datum/gas_mixture/gasmix in gases)
		total_volume += gasmix.volume
		var/temp_heatcap = gasmix.heat_capacity()
		total_thermal_energy += gasmix.temperature * temp_heatcap
		total_heat_capacity += temp_heatcap
		for (var/g in gasmix.gas)
			total_gas[g] += gasmix.gas[g]

	if (total_volume > 0)
		var/datum/gas_mixture/combined = new(total_volume)
		combined.gas = total_gas

		//Calculate temperature
		if (total_heat_capacity > 0)
			combined.temperature = total_thermal_energy / total_heat_capacity
		combined.update_values()

		//Allow for reactions
		combined.react()

		//Average out the gases
		for (var/g in combined.gas)
			combined.gas[g] /= total_volume

		//Update individual gas_mixtures
		for (var/datum/gas_mixture/gasmix in gases)
			gasmix.gas = combined.gas.Copy()
			gasmix.temperature = combined.temperature
			gasmix.multiply(gasmix.volume)

	return TRUE
