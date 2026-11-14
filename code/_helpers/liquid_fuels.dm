// Liquid fuel properties in one table, like the solid fuel rates.
//
// Each fuel lists only what it does; a missing key means "not at all".
// - slick: oil slick units per unit spilled when a container is splashed.
// - explode: units that make a shot container burst into flames.
// A new fuel is one row here. The burn-anything engine list is in
// code/__defines/liquid_fuels.dm so type var defaults can use it.
// ("ethanol" here counts every alcohol, as reagents.get_reagent_amount() does.)

var/global/list/liquid_fuel_table = list(
	"petroleum" = list("slick" = 1, "explode" = 40),
	"gasoline" = list("slick" = 1, "explode" = 10),
	"diesel" = list("slick" = 1/2, "explode" = 30),
	"biodiesel" = list("slick" = 1/2, "explode" = 30),
	"ethanol" = list("explode" = 10),
	"olive_oil" = list("slick" = 1/3),
	"fat_oil" = list("slick" = 1/3),
)

// The fuel's value for key, or null when it has none.
/proc/liquid_fuel_value(id, key)
	var/list/row = liquid_fuel_table[id]
	return row ? row[key] : null

// Oil slick units from spilling spill_amount of R (before rounding).
/proc/liquid_fuel_slick_units(datum/reagents/R, spill_amount)
	if (!R || !R.total_volume)
		return 0
	var/units = 0
	for (var/id in liquid_fuel_table)
		var/slick = liquid_fuel_value(id, "slick")
		if (slick)
			units += R.get_reagent_amount(id) * spill_amount / R.total_volume * slick
	return units

// TRUE when R holds enough of any fuel to burst into flames when shot.
/proc/liquid_fuel_can_explode(datum/reagents/R)
	if (!R)
		return FALSE
	for (var/id in liquid_fuel_table)
		var/needed = liquid_fuel_value(id, "explode")
		if (needed && R.has_reagent(id, needed))
			return TRUE
	return FALSE
