// Native fixture for code/modules/reagents/food_toxin_log.dm. The production
// file is included unchanged; only the engine-side helpers it calls are stubbed.
var/list/checks = list()
var/list/failed = list()
var/list/game_lines = list()

/proc/check(label, ok)
	checks += label
	if (!ok)
		failed += label

/proc/game_log(category, text)
	game_lines += "[category]: [text]"

/proc/time_stamp()
	return "12:00:00"

/proc/get_turf(atom/A)
	return locate(A.x, A.y, A.z)

/proc/ishuman(A)
	return istype(A, /mob/living/human)

/proc/key_name(whom)
	var/mob/M = whom
	return "[M.ckey]/([M.name])"

/datum/reagent
	var/id = "reagent"
	var/volume = 0
/datum/reagent/water
	id = "water"
/datum/reagent/toxin
	id = "toxin"
/datum/reagent/toxin/food_poisoning
	id = "food_poisoning"
/datum/reagent/toxin/cyanide
	id = "cyanide"

/datum/reagents
	var/list/reagent_list = list()

/datum/reagents/proc/put(path, amount)
	var/datum/reagent/R = new path
	R.volume = amount
	reagent_list += R

/mob
	var/list/attack_log = list()

/mob/proc/append_attack_log(entry)
	attack_log += entry

/mob/living
	var/datum/reagents/reagents
	var/toxloss = 0

/mob/living/New()
	..()
	reagents = new

/mob/living/proc/getToxLoss()
	return toxloss

/mob/living/human
	var/datum/reagents/ingested

/mob/living/human/New()
	..()
	ingested = new

/obj/item/weapon/reagent_containers/food
	var/rotten = FALSE
	var/raw = FALSE

/obj/item/weapon/reagent_containers/food/fish
	name = "fish fillet"
	food_toxin_origin = "raw fish, may be caught contaminated"

/world
	maxx = 2
	maxy = 2
	maxz = 1

/world/New()
	..()
	var/turf/T = locate(1, 1, 1)

	var/datum/reagents/mix = new
	mix.put(/datum/reagent/water, 10)
	mix.put(/datum/reagent/toxin/food_poisoning, 1.5)
	mix.put(/datum/reagent/toxin/cyanide, 0)
	var/list/amounts = food_toxin_amounts(mix)
	check("only toxins with volume are counted", amounts.len == 1 && amounts["food_poisoning"] == 1.5)
	check("no reagents means no toxins", !food_toxin_amounts(null).len)

	var/obj/item/weapon/reagent_containers/food/plain = new(T)
	plain.name = "stew"
	check("unrecorded origin has a placeholder", findtext(food_toxin_cause(plain), "origin not recorded"))
	check("known_only returns null when nothing is recorded", isnull(food_toxin_cause(plain, TRUE)))
	plain.rotten = TRUE
	plain.raw = TRUE
	check("rotten and raw flags name the cause", food_toxin_cause(plain) == "rotten; raw")
	var/obj/item/weapon/reagent_containers/food/fish/F = new(T)
	F.raw = TRUE
	check("type default origin is used and raw is not repeated", food_toxin_cause(F) == "raw fish, may be caught contaminated")
	check("non-objects have no recorded cause", isnull(food_toxin_cause(T, TRUE)))

	var/obj/O = new(T)
	O.note_food_toxin("puddle water")
	O.note_food_toxin("puddle water")
	O.note_food_toxin("zombie meat")
	check("origin notes are deduplicated and joined", O.food_toxin_origin == "puddle water; zombie meat")
	for (var/i in 1 to 50)
		O.note_food_toxin("cause number [i]")
	check("origin text stays bounded", length(O.food_toxin_origin) < 200)

	var/mob/living/human/H = new(T)
	H.name = "Eater"
	H.ckey = "tester"
	H.toxloss = 15
	H.ingested.put(/datum/reagent/toxin/food_poisoning, 0.5)
	H.reagents.put(/datum/reagent/toxin/food_poisoning, 1)
	log_food_toxin(H, F, list("food_poisoning" = 1), food_toxin_cause(F), "swallowing")
	var/line = food_toxin_log[food_toxin_log.len]
	check("one game log line per swallow", game_lines.len == 1 && findtext(game_lines[1], "FOOD: "))
	check("line names eater, amount, source, route and cause", findtext(line, "tester/(Eater) swallowed food_poisoning 1u from fish fillet (/obj/item/weapon/reagent_containers/food/fish) via swallowing at (1,1,1). Cause: raw fish"))
	check("line reports blood plus stomach toxins and damage", findtext(line, "Now holds food_poisoning 1.5u, toxin damage 15."))
	check("attack log gets the entry", H.attack_log.len == 1 && findtext(H.attack_log[1], "Food toxin: food_poisoning 1u from fish fillet"))

	log_food_toxin(H, F, list(), "nothing", "swallowing")
	log_food_toxin(null, F, list("food_poisoning" = 1), "nobody", "swallowing")
	check("empty swallows and missing eaters are not logged", game_lines.len == 1 && food_toxin_log.len == 1)

	for (var/i in 1 to 250)
		log_food_toxin(H, F, list("food_poisoning" = i), "ring", "swallowing")
	check("ring keeps the newest 200 lines", food_toxin_log.len == 200 && findtext(food_toxin_log[200], "food_poisoning 250u") && findtext(food_toxin_log[1], "food_poisoning 51u"))

	var/out = file("result.json")
	fdel(out)
	out << json_encode(list("checks" = checks.len, "failed_labels" = failed))
	del(src)
