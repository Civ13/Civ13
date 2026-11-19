// Solid fuels: one table says which items burn as which fuel kind, and each
// heat device lists what one unit of each kind is worth to it. A new fuel is
// one line in solid_fuel_kinds plus the devices' rates; a new device is a
// rates table. Subtypes burn as their listed parent.

var/global/list/solid_fuel_kinds = list(
	/obj/item/stack/material/wood = "wood",
	/obj/item/stack/material/woodplank = "plank",
	/obj/item/stack/material/bamboo = "bamboo",
	/obj/item/weapon/branch = "branch",
	/obj/item/stack/material/leaf = "leaf",
	/obj/item/stack/dung = "dung",
	/obj/item/stack/ore/charcoal = "charcoal",
	/obj/item/stack/ore/coal = "coal",
	/obj/item/stack/ore/coke = "coke",
)

// Rates are fuel per unit of the item's amount, or list(per unit, flat bonus).
// Ovens and campfires count in logs; the bonus keeps their old branch, leaf and
// dung values.
var/global/list/hearth_fuel_rates = list(
	"wood" = 1, "bamboo" = 1, "branch" = list(1, 0.5), "leaf" = list(1, 0.5),
	"dung" = list(1, 1), "charcoal" = 2.5, "coal" = 3)
// Bloomeries and blast furnaces also burn planks.
var/global/list/furnace_fuel_rates = list(
	"wood" = 1, "bamboo" = 1, "plank" = 1, "branch" = list(1, 0.5), "leaf" = list(1, 0.5),
	"dung" = list(1, 1), "charcoal" = 2.5, "coal" = 3, "coke" = 3)
// Bloomeries and blast furnaces count in charcoal halves (steel_grades.dm):
// a charcoal is 2, a log 1. Raw coal, leaves and dung can't smelt iron.
var/global/list/bloomery_fuel_rates = list(
	"charcoal" = 2, "coke" = 3, "wood" = 1, "bamboo" = 1, "plank" = 1, "branch" = 0.5)
// Factory furnaces take only stackable logs, planks and coal from automation.
var/global/list/factory_fuel_rates = list(
	"wood" = 1, "bamboo" = 1, "plank" = 1, "charcoal" = 2.5, "coal" = 3, "coke" = 3)
// Braziers count in burn ticks.
var/global/list/brazier_fuel_rates = list(
	"coal" = 220, "charcoal" = 180, "wood" = 80, "plank" = 80, "bamboo" = 80,
	"dung" = 90, "branch" = 60, "leaf" = 60)
// Engine heat sources count in seconds of burn.
var/global/list/heat_source_fuel_rates = list(
	"coal" = 240, "charcoal" = 80, "wood" = 60, "plank" = 60, "branch" = 60,
	"bamboo" = 60, "dung" = 60, "leaf" = 30)

/proc/solid_fuel_kind(obj/item/I)
	if (!istype(I))
		return null
	for (var/path in solid_fuel_kinds)
		if (istype(I, path))
			return solid_fuel_kinds[path]
	return null

// Fuel this item gives a device with these rates, or 0 if the device can't burn it.
/proc/solid_fuel_value(obj/item/I, list/rates)
	var/kind = solid_fuel_kind(I)
	if (!kind || !(kind in rates))
		return 0
	var/rate = rates[kind]
	if (islist(rate))
		return I.amount * rate[1] + rate[2]
	return I.amount * rate

// Fuel one unit of this item gives a device with these rates, ignoring any flat bonus.
/proc/solid_fuel_unit_value(obj/item/I, list/rates)
	var/kind = solid_fuel_kind(I)
	if (!kind || !(kind in rates))
		return 0
	var/rate = rates[kind]
	return islist(rate) ? rate[1] : rate
