// Deterministic RNG adapters; the mining body itself comes from production.
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
/obj/map_metadata/yield_probe/New()
	return
/mob/living/human/yield_probe/New()
	return
var/yield_failures = 0
var/yield_runtime_error = FALSE
var/list/yield_chances
var/yield_chance_index = 0
var/yield_fuel = 1
var/yield_high = FALSE
/proc/yield_prob(chance)
	yield_chance_index++
	return yield_chance_index <= yield_chances.len ? yield_chances[yield_chance_index] : FALSE
/proc/yield_rand(low, high)
	return yield_high ? high : low
/proc/yield_pick()
	return yield_fuel
/proc/yield_check(condition, label)
	if (!condition)
		yield_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	yield_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/proc/yield_case(era, title, list/chances, expected, minimum, maximum, terrain = /turf/floor/dirt/underground, climate = "temperate", map_id = MAP_NOMADS_PANGEA, special = FALSE)
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
	yield_chances = chances
	yield_chance_index = 0
	T.mining_proc(null)
	T = locate(5,5,1)
	var/amount = 0
	for (var/obj/item/stack/S in T)
		if (S.type == expected)
			amount += S.amount
	yield_check(!T.is_mineable && amount == (yield_high ? maximum : minimum), "era[era] [title] [yield_high ? "max" : "min"] yield[amount] and finite depletion")
	// Compare only overlapping renewable minerals. Fossils are explicitly one.
	if (minimum > 2)
		yield_check(amount > 2, "[title] destructive batch exceeds two-unit automated trace batch")
/world/New()
	OpenPort("none")
	try
		GLOB.moved_event = new /decl/observ/moved
		movementMachine = new
		populate_material_list()
		map = new /obj/map_metadata/yield_probe
		var/mob/living/human/yield_probe/H = new(locate(1,1,1))
		for (var/era in 0 to 8)
			map.ordinal_age = era
			var/list/choices = H.sifting_choices()
			yield_check(!(/obj/item/stack/material/fossil in choices) && choices["Iron ore"] == (era >= 1 ? /obj/item/stack/ore/iron : null) && choices["Coal"] == (era >= 2 ? /obj/item/stack/ore/coal : null), "era[era] real sustainable catalog gates minerals and excludes fossil")
			for (var/high in list(FALSE,TRUE))
				yield_high = high
				yield_case(era,"copper",list(TRUE,TRUE),/obj/item/stack/ore/copper,12,24)
				yield_case(era,"tin",list(TRUE,FALSE),/obj/item/stack/ore/tin,12,24)
				yield_case(era,"iron era gate",list(FALSE,TRUE),era >= 1 ? /obj/item/stack/ore/iron : /obj/item/stack/material/stone,era >= 1 ? 12 : 16,24)
				for (var/fuel in 1 to 4)
					yield_fuel = fuel
					var/list/types = list(/obj/item/stack/ore/coal,/obj/item/stack/ore/saltpeter,/obj/item/stack/ore/sulphur,/obj/item/stack/ore/lead)
					yield_case(era,"fuel[fuel] era gate",list(FALSE,FALSE,TRUE),era >= 2 ? types[fuel] : /obj/item/stack/material/stone,era >= 2 ? (fuel == 1 ? 24 : 8) : 16,era >= 2 ? (fuel == 1 ? 32 : 8) : 24)
				yield_case(era,"silver",list(FALSE,FALSE,FALSE,TRUE),/obj/item/stack/ore/silver,4,4)
				yield_case(era,"gold",list(FALSE,FALSE,FALSE,FALSE,TRUE),/obj/item/stack/ore/gold,4,4)
				yield_case(era,"diamond",list(FALSE,FALSE,FALSE,FALSE,FALSE,TRUE),/obj/item/stack/ore/diamond,4,4)
				yield_case(era,"icy fossil exception",list(FALSE,FALSE,FALSE,FALSE,FALSE,FALSE,TRUE),/obj/item/stack/material/fossil,1,1,/turf/floor/dirt/underground/icy)
				yield_case(era,"sandstone",list(),/obj/item/stack/material/sandstone,16,24,/turf/floor/dirt/underground/sandy)
				yield_case(era,"fallback stone",list(),/obj/item/stack/material/stone,16,24)
				yield_case(era,"marble era gate",list(FALSE,FALSE,FALSE,FALSE,FALSE,FALSE,TRUE),era >= 1 ? /obj/item/stack/material/marble : /obj/item/stack/material/stone,16,24,/turf/floor/dirt/underground,"temperate","yield-fixture")
				yield_case(era,"jungle obsidian era gate",list(FALSE,FALSE,FALSE,FALSE,FALSE,FALSE,FALSE,TRUE),era >= 1 && era <= 3 ? /obj/item/stack/ore/obsidian : /obj/item/stack/material/stone,16,24,/turf/floor/dirt/underground,"jungle")
				yield_case(era,"Antarctica excludes fuel",list(FALSE,FALSE,TRUE),/obj/item/stack/material/stone,16,24,/turf/floor/dirt/underground,"temperate",MAP_ANTARCTICA)
				yield_case(era,"surface desert sandstone",list(),/obj/item/stack/material/sandstone,16,24,/turf/floor/dirt/underground,"desert")
				yield_case(era,"semiarid marble era gate",list(),era >= 1 ? /obj/item/stack/material/marble : /obj/item/stack/material/stone,16,24,/turf/floor/dirt/underground,"semiarid")
				yield_case(era,"special copper multiplier",list(TRUE,TRUE),/obj/item/stack/ore/copper,24,48,/turf/floor/dirt/underground,"temperate",MAP_NOMADS_PANGEA,TRUE)
				yield_case(era,"special fossil exception",list(FALSE,FALSE,FALSE,FALSE,FALSE,FALSE,TRUE),/obj/item/stack/material/fossil,2,2,/turf/floor/dirt/underground/icy,"temperate",MAP_NOMADS_PANGEA,TRUE)
	catch(var/exception/e)
		yield_check(FALSE,"exception [e]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = yield_failures, "runtime_error" = yield_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
