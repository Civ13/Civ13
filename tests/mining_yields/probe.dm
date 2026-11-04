// Deterministic RNG adapters; all mining bodies, gates and outputs are production.
/world
	hub = ""
	hub_password = ""
	maxx = 12
	maxy = 12
	maxz = 2
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/client/New()
	del(src)
/obj/map_metadata/yield_probe/New()
	return
/mob/living/human/yield_probe
	var/strength_awards = 0
/mob/living/human/yield_probe/New()
	return
/mob/living/human/yield_probe/adaptStat(statname, multiplier = 1)
	if (statname == "strength")
		strength_awards += multiplier
var/yield_failures = 0
var/yield_assertions = 0
var/yield_runtime_error = FALSE
var/list/yield_chances
var/list/yield_observed
var/yield_chance_index = 0
var/yield_high = FALSE
/proc/yield_prob(chance)
	yield_observed += chance
	yield_chance_index++
	return yield_chance_index <= yield_chances.len ? yield_chances[yield_chance_index] : FALSE
/proc/yield_rand(low, high)
	return yield_high ? high : low
/proc/yield_check(condition, label)
	yield_assertions++
	if (!condition)
		yield_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	yield_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/proc/yield_mask(index = 0, geology = FALSE, first = FALSE, second = FALSE, third = FALSE)
	var/list/mask = list(FALSE,FALSE,FALSE,FALSE,FALSE,FALSE,FALSE,FALSE,FALSE,FALSE,FALSE,geology,first,second,third)
	if (index)
		mask[index] = TRUE
	return mask
/proc/yield_units(turf/T, expected)
	var/amount = 0
	for (var/obj/item/stack/S in T)
		if (S.type == expected)
			amount += S.amount
	return amount
/proc/yield_case(era, title, list/chances, list/expected, terrain = /turf/floor/dirt/underground, climate = "temperate", map_id = MAP_NOMADS_PANGEA, special = FALSE)
	map.ordinal_age = era
	map.ID = map_id
	var/area/above = get_area(locate(5,5,2))
	above.climate = climate
	for (var/obj/item/stack/S in locate(5,5,1))
		qdel(S)
	var/turf/T = new terrain(locate(5,5,1))
	var/area/normal = get_area(locate(1,1,1))
	normal.contents += T
	if (special)
		var/area/bonus = locate(/area/caribbean/void/caves/special)
		if (!bonus)
			bonus = new /area/caribbean/void/caves/special
		bonus.contents += T
	var/mob/living/human/yield_probe/H = new(locate(1,1,1))
	yield_chances = chances
	yield_observed = list()
	yield_chance_index = 0
	T.mining_proc(H)
	T = locate(5,5,1)
	var/label = "era[era] [title] [yield_high ? "max" : "min"] [special ? "special" : "normal"]"
	var/list/actual = list()
	for (var/obj/item/stack/S in T)
		actual[S.type] += S.amount
	yield_check(actual.len == expected.len, "[label] exact output types")
	for (var/type in expected)
		yield_check(yield_units(T, type) == expected[type], "[label] [type] quantity [expected[type]]")
	yield_check(!T.is_mineable && !istype(T, terrain) && H.strength_awards == 1, "[label] finite conversion and one strength award")
	var/rolls_before = yield_chance_index
	T.mining_proc(H)
	var/unchanged = H.strength_awards == 1 && yield_chance_index == rolls_before
	for (var/type in actual)
		unchanged = unchanged && yield_units(T, type) == actual[type]
	yield_check(unchanged, "[label] no duplicate completion")
	qdel(H)
/proc/yield_rate_case(era, map_id)
	yield_case(era,"all failures",yield_mask(),list(/obj/item/stack/material/stone = yield_high ? 24 : 16),map_id = map_id)
	// Oracle from the historical sequential tree; coal alone is doubled.
	var/legacy_common_miss = era >= 1 ? 0.48 : 0.8
	var/fuel = era >= 2 && map_id != MAP_ANTARCTICA
	if (fuel)
		legacy_common_miss *= 0.75
	var/u = era >= 8 ? legacy_common_miss * 5 : 0
	var/rare_miss = legacy_common_miss - u / 100
	var/list/rates = list(12,8,era >= 1 ? 32 : 0,fuel ? 6 : 0,fuel ? 3 : 0,fuel ? 3 : 0,fuel ? 3 : 0,u,rare_miss * 5,rare_miss * 0.95 * 2,rare_miss * 0.95 * 0.98)
	var/no_ore = 1
	for (var/index in 1 to 11)
		yield_check(abs(yield_observed[index] - rates[index]) < 0.00001, "era[era] [map_id] roll[index] rate [rates[index]]")
		no_ore *= 1 - rates[index] / 100
	var/legacy_geology = rare_miss * 0.95 * 0.98 * 0.99
	yield_check(abs(no_ore * yield_observed[12] / 100 - legacy_geology) < 0.00001, "era[era] [map_id] unchanged unconditional geology budget")
/world/New()
	OpenPort("none")
	try
		GLOB.moved_event = new /decl/observ/moved
		movementMachine = new
		populate_material_list()
		map = new /obj/map_metadata/yield_probe
		yield_check(port == 0 && !OpenPort(0) && port == 0, "closed port and refused reopen")
		// Native built-in, outside the adapted production body: verify fractional
		// probabilities are usable rather than treating sub-1% ores as zero.
		rand_seed(20261103)
		var/native_hits = 0
		for (var/draw in 1 to 1000000)
			if (prob(0.33516))
				native_hits++
		world.log << "NATIVE_PROB: 0.33516 percent, 1000000 draws, [native_hits] hits"
		yield_check(abs(native_hits - 3351.6) < 350, "native fractional probability within six standard deviations")
		var/list/types = list(/obj/item/stack/ore/copper,/obj/item/stack/ore/tin,/obj/item/stack/ore/iron,/obj/item/stack/ore/coal,/obj/item/stack/ore/saltpeter,/obj/item/stack/ore/sulphur,/obj/item/stack/ore/lead,/obj/item/stack/ore/uranium,/obj/item/stack/ore/silver,/obj/item/stack/ore/gold,/obj/item/stack/ore/diamond)
		for (var/era in 0 to 8)
			var/mob/living/human/yield_probe/catalog_actor = new(locate(1,1,1))
			map.ordinal_age = era
			var/list/choices = catalog_actor.sifting_choices()
			yield_check(!(/obj/item/stack/material/fossil in choices) && choices["Iron ore"] == (era >= 1 ? /obj/item/stack/ore/iron : null) && choices["Coal"] == (era >= 2 ? /obj/item/stack/ore/coal : null), "era[era] unchanged sustainable catalog")
			qdel(catalog_actor)
			for (var/high in list(FALSE,TRUE))
				yield_high = high
				for (var/special in list(FALSE,TRUE))
					var/multiplier = special ? 2 : 1
					for (var/map_id in list(MAP_NOMADS_PANGEA,MAP_ANTARCTICA))
						var/list/all = list(TRUE,TRUE,TRUE,TRUE,TRUE,TRUE,TRUE,TRUE,TRUE,TRUE,TRUE)
						var/list/mixed = list(/obj/item/stack/material/stone = high ? 12 : 8)
						for (var/index in 1 to 11)
							var/eligible = !(index == 3 && era < 1) && !(index >= 4 && index <= 7 && (era < 2 || map_id == MAP_ANTARCTICA)) && !(index == 8 && era < 8)
							var/amount = index <= 3 ? (high ? 24 : 12) : index == 4 ? (high ? 32 : 24) : index <= 7 ? 8 : index == 8 ? 1 : 4
							amount *= index == 8 ? 1 : multiplier
							var/list/solo = list()
							if (eligible)
								solo[types[index]] = amount
								mixed[types[index]] = amount
								if (index <= 7)
									solo[/obj/item/stack/material/stone] = high ? 12 : 8
							else
								solo[/obj/item/stack/material/stone] = (high ? 24 : 16) * multiplier
							yield_case(era,"single roll[index]",yield_mask(index),solo,map_id = map_id,special = special)
						yield_case(era,"all ores together",all,mixed,map_id = map_id,special = special)
						// Legacy rocky floors keep other drops but never uranium.
						var/list/legacy = mixed.Copy()
						legacy.Remove(/obj/item/stack/ore/uranium)
						yield_case(era,"legacy rocky floor",all,legacy,/turf/floor/mining,map_id = map_id,special = special)
						if (!special)
							yield_rate_case(era,map_id)
					var/fossil_amount = special ? 2 : 1
					yield_case(era,"icy fossil",yield_mask(0,TRUE,TRUE),list(/obj/item/stack/material/fossil = fossil_amount),/turf/floor/dirt/underground/icy,special = special)
					yield_case(era,"sandstone",yield_mask(0,TRUE),list(/obj/item/stack/material/sandstone = (high ? 24 : 16) * multiplier),/turf/floor/dirt/underground/sandy,special = special)
					yield_case(era,"surface desert",yield_mask(0,TRUE),list(/obj/item/stack/material/sandstone = (high ? 24 : 16) * multiplier),climate = "desert",special = special)
					var/list/geology = list()
					geology[era >= 1 ? /obj/item/stack/material/marble : /obj/item/stack/material/stone] = (high ? 24 : 16) * multiplier
					if (era >= 1)
						geology[/obj/item/stack/material/stone] = high ? 12 : 8
					yield_case(era,"general marble gate",yield_mask(0,TRUE,TRUE),geology,map_id = "yield-fixture",special = special)
					geology = list()
					geology[era >= 1 && era <= 3 ? /obj/item/stack/ore/obsidian : /obj/item/stack/material/stone] = (high ? 24 : 16) * multiplier
					if (era >= 1 && era <= 3)
						geology[/obj/item/stack/material/stone] = high ? 12 : 8
					yield_case(era,"jungle obsidian gate",yield_mask(0,TRUE,FALSE,TRUE),geology,climate = "jungle",special = special)
					geology = list()
					geology[era >= 1 ? /obj/item/stack/material/marble : /obj/item/stack/material/stone] = (high ? 24 : 16) * multiplier
					yield_case(era,"semiarid marble gate",yield_mask(0,TRUE),geology,climate = "semiarid",special = special)
					yield_case(era,"rejected geology",yield_mask(),list(/obj/item/stack/material/stone = (high ? 24 : 16) * multiplier),/turf/floor/dirt/underground/icy,"semiarid",special = special)
	catch(var/exception/e)
		yield_check(FALSE,"exception [e]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "assertions" = yield_assertions, "failures" = yield_failures, "runtime_error" = yield_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
