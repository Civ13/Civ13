/world
	hub = ""
	hub_password = ""
	maxx = 8
	maxy = 8
	maxz = 1
	turf = /turf/floor/plating
	area = /area
	visibility = 0

/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

/mob/living/human/diet_tester/New()
	species = new /datum/species/human
	body_build = new /datum/body_build
	ingested = new /datum/reagents/metabolism(500, src, CHEM_INGEST)
	reagents = new /datum/reagents(100, src)
	stats = list("stamina" = list(100, 100))

/mob/living/human/diet_tester/religion_check()
	return "none"

/obj/map_metadata/diet_tester/New()
	return

/proc/diet_assert(condition, message)
	if (!condition)
		throw EXCEPTION(message)
	world.log << "DIET PASS: [message]"

/proc/diet_close(a, b, epsilon = 0.001)
	return abs(a - b) <= epsilon

/proc/diet_subject(turf/site, start = 0)
	var/mob/living/human/diet_tester/H = new(site)
	H.diet_reserves = list("carbohydrate" = start, "protein" = start, "fat" = start, "vitamins" = start)
	H.nutrition = 0
	var/datum/mind/M = new("diet-[rand(1, 999999)]")
	M.current = H
	H.mind = M
	M.diet_ensure_tastes()
	M.diet_tastes = list() // tests that need tastes set them explicitly
	return H

/proc/diet_eat(mob/living/human/H, id, amount, list/flavour)
	H.ingested.add_reagent(id, amount, flavour ? flavour.Copy() : null)
	for (var/i in 1 to 500)
		if (H.ingested.total_volume <= 0)
			break
		H.ingested.metabolize()

/proc/diet_sum(mob/living/human/H)
	. = 0
	for (var/group in diet_groups)
		. += H.diet_reserves[group]

/world/New()
	OpenPort("none")
	sleep(1)
	try
		text2file(json_encode(list("byond_version" = world.byond_version, "byond_build" = world.byond_build, "network" = "closed", "startup" = "disabled")), "fixture.json")
		var/turf/site = locate(3,3,1)
		map = new /obj/map_metadata/diet_tester

		// Equal intake: one food group versus a balanced spread of the same nutrition.
		var/mob/living/human/narrow = diet_subject(site)
		var/mob/living/human/balanced = diet_subject(site)
		diet_eat(narrow, "nutriment", 8, list("bread" = 1))
		diet_eat(balanced, "nutriment", 2, list("bread" = 1))
		diet_eat(balanced, "nutriment", 2, list("carrot" = 1))
		diet_eat(balanced, "protein", 2)
		diet_eat(balanced, "egg", 2)
		diet_assert(diet_close(narrow.nutrition, 240) && diet_close(balanced.nutrition, 240), "hunger gain unchanged and equal: nutriment_factor times eaten units")
		diet_assert(narrow.diet_reserves["carbohydrate"] == DIET_RESERVE_CAP && diet_close(diet_sum(balanced), 240), "nutrient reserves conserve the eaten nutrition")
		diet_assert(narrow.diet_adequate_groups() == 1 && balanced.diet_adequate_groups() == 4, "balanced spread covers every group")
		diet_assert(balanced.diet_capacity_bonus() > narrow.diet_capacity_bonus(), "balanced diet raises capacity over equal narrow intake")

		// The larger capacity is usable stamina: it refills above base and can be spent.
		narrow.stats["stamina"][1] = 0
		balanced.stats["stamina"][1] = 0
		for (var/i in 1 to 100)
			narrow.diet_recover_stamina()
			balanced.diet_recover_stamina()
		diet_assert(balanced.stats["stamina"][1] == 120 && narrow.stats["stamina"][1] == 105, "recovery fills the diet-raised ceiling")
		balanced.stats["stamina"][1] -= 115
		diet_assert(balanced.stats["stamina"][1] == 5, "extra energy is spent like ordinary stamina")
		var/mob/living/human/ordinary = diet_subject(site, 80)
		ordinary.diet_enjoyment = 0
		ordinary.stats["stamina"][1] = 0
		for (var/i in 1 to 100)
			ordinary.diet_recover_stamina()
		diet_assert(ordinary.stats["stamina"][1] >= ordinary.stats["stamina"][2], "ordinary meals keep at least the base capacity")

		// Splitting and dilution conserve nutrients; tiny bites only add what they contain.
		var/mob/living/human/whole = diet_subject(site)
		var/mob/living/human/split = diet_subject(site)
		var/mob/living/human/diluted = diet_subject(site)
		diet_eat(whole, "nutriment", 4, list("carrot" = 1))
		for (var/i in 1 to 40)
			diet_eat(split, "nutriment", 0.1, list("carrot" = 1))
		diluted.ingested.add_reagent("water", 20)
		diet_eat(diluted, "nutriment", 4, list("carrot" = 1))
		diet_assert(diet_close(diet_sum(whole), 120) && diet_close(diet_sum(split), diet_sum(whole), 0.01) && diet_close(diet_sum(diluted), diet_sum(whole)), "splitting, tiny bites and dilution cannot manufacture nutrients")
		var/mob/living/human/capped = diet_subject(site)
		diet_eat(capped, "nutriment", 100, list("bread" = 1))
		diet_assert(capped.diet_reserves["carbohydrate"] == DIET_RESERVE_CAP && capped.diet_capacity_bonus() <= DIET_BONUS_CAP, "reserves and bonus are bounded")

		// Tastes: liked foods add enjoyment and capacity; mixed preferences offset; traces do not count.
		var/mob/living/human/liker = diet_subject(site)
		var/mob/living/human/neutral = diet_subject(site)
		liker.mind.diet_tastes = list("carrot" = 1, "cabbage" = -1)
		diet_eat(liker, "nutriment", 4, list("carrot" = 1))
		diet_eat(neutral, "nutriment", 4, list("carrot" = 1))
		diet_assert(liker.diet_enjoyment > 0 && neutral.diet_enjoyment == 0 && liker.diet_capacity_bonus() > neutral.diet_capacity_bonus(), "liked food raises capacity over equal neutral intake")
		diet_assert(liker.mind.diet_tastes_known["carrot"] == 1 && !liker.mind.diet_tastes_known["cabbage"], "eating reveals only the tasted preference")
		var/taste_records = 0
		for (var/key in liker.mind.learned_discoveries)
			var/list/record = liker.mind.learned_discoveries[key]
			if (record["category"] == "food_taste")
				taste_records++
				diet_assert(record["identity"] == "carrot" && record["context"] == liker.mind.diet_taste_token, "discovery records the learned taste for this life")
		diet_assert(taste_records == 1, "one discovery note per learned taste")
		var/notes = liker.mind.discoveries_html()
		diet_assert(findtext(notes, "enjoy the taste of carrot") && !findtext(notes, "cabbage"), "notes show learned facts without hidden tastes")
		diet_eat(liker, "nutriment", 4, list("carrot" = 1))
		taste_records = 0
		for (var/key in liker.mind.learned_discoveries)
			var/list/again = liker.mind.learned_discoveries[key]
			if (again["category"] == "food_taste")
				taste_records++
		diet_assert(taste_records == 1, "repeat eating does not duplicate notes")
		var/mob/living/human/mixed = diet_subject(site)
		mixed.mind.diet_tastes = list("carrot" = 1, "cabbage" = -1)
		diet_eat(mixed, "nutriment", 4, list("carrot" = 1, "cabbage" = 1))
		diet_assert(mixed.diet_enjoyment == 0, "liked and disliked ingredients offset")
		var/mob/living/human/trace = diet_subject(site)
		trace.mind.diet_tastes = list("carrot" = 1)
		diet_eat(trace, "nutriment", 4, list("carrot" = 1, "bread" = 9))
		diet_assert(trace.diet_enjoyment == 0 && !trace.mind.diet_tastes_known["carrot"], "trace liked flavour neither rewards nor reveals")
		var/mob/living/human/hater = diet_subject(site)
		hater.mind.diet_tastes = list("cabbage" = -1)
		hater.diet_enjoyment = 50
		diet_eat(hater, "nutriment", 4, list("cabbage" = 1))
		diet_assert(hater.diet_enjoyment < 50 && hater.mind.diet_tastes_known["cabbage"] == -1, "disliked food lowers enjoyment and is learned")

		// Food examine shows nutrients and only learned tastes.
		var/obj/item/weapon/reagent_containers/food/snacks/grown/carrot/C = new(site)
		C.reagents.add_reagent("nutriment", 2, list("cabbage" = 1))
		var/summary = liker.diet_food_summary(C)
		diet_assert(findtext(summary, "Nutrients:") && findtext(summary, "vitamins") && findtext(summary, "enjoy the taste of carrot") && !findtext(summary, "cabbage"), "examine shows nutrients and only learned tastes")

		// Better dishes from liked ingredients: bounded by the bowl's finite paid credit.
		var/mob/living/human/diner = diet_subject(site)
		diner.mind.diet_tastes = list("carrot" = 1)
		var/obj/item/weapon/reagent_containers/food/snacks/prepared_meal/meal = new(site)
		meal.meal_quality = 3
		meal.reagents.add_reagent("nutriment", 4, list("carrot" = 1))
		meal.meal_reward_food = 4
		meal.take_food_bite(diner, 4)
		var/after_dish = diner.diet_enjoyment
		diet_assert(after_dish > 0, "prepared dish from a liked ingredient earns a dish bonus")
		meal.reagents.add_reagent("nutriment", 4, list("carrot" = 1))
		meal.take_food_bite(diner, 4)
		diet_assert(diner.diet_enjoyment == after_dish, "refilled bowl cannot renew the dish bonus")

		// Taste generation: one distinct like and dislike per valid category; bad categories fail validation.
		var/list/categories = diet_taste_categories_valid()
		diet_assert(categories.len == diet_taste_categories.len, "every shipped taste category validates")
		for (var/i in 1 to 40)
			var/datum/mind/fresh = new("fresh-[i]")
			fresh.diet_ensure_tastes()
			for (var/category in categories)
				var/likes = 0
				var/dislikes = 0
				for (var/descriptor in categories[category])
					if (fresh.diet_tastes[descriptor] == 1)
						likes++
					else if (fresh.diet_tastes[descriptor] == -1)
						dislikes++
				diet_assert(likes == 1 && dislikes == 1, "category [category] has one like and one dislike")
			diet_assert(!fresh.diet_tastes_known.len && !fresh.learned_discoveries, "new character starts with no revealed tastes")
		var/list/bad = diet_validate_categories(list("a" = list("x", "y"), "b" = list("x", "z"), "c" = list("w", "w")))
		diet_assert(bad.len == 1 && bad["a"] && !bad["b"] && !bad["c"], "overlapping or insufficient categories are rejected")
		var/datum/mind/stable = new("stable")
		stable.diet_ensure_tastes()
		var/token = stable.diet_taste_token
		var/list/before_tastes = stable.diet_tastes.Copy()
		stable.diet_ensure_tastes()
		diet_assert(stable.diet_taste_token == token && stable.diet_tastes ~= before_tastes, "existing tastes never reroll")

		// Legacy bodies start once at a neutral reserve, never at zero.
		var/mob/living/human/legacy = diet_subject(site)
		legacy.diet_reserves = null
		legacy.diet_ensure()
		diet_assert(legacy.diet_adequate_groups() == 4, "legacy body initialises without a surprise penalty")
		legacy.diet_reserves["fat"] = 7
		legacy.diet_ensure()
		diet_assert(legacy.diet_reserves["fat"] == 7, "initialisation is not repeated")

		// Brief imbalance is tolerated; sustained imbalance warns, then (only if enabled) mildly slows recovery.
		var/mob/living/human/drift = diet_subject(site, 80)
		drift.nutrition = 200
		for (var/i in 1 to 300)
			drift.handle_diet()
		diet_assert(drift.diet_adequate_groups() == 4 && drift.diet_imbalance_ticks == 0, "a missed meal does not cause imbalance")
		drift.diet_reserves = list("carbohydrate" = 120, "protein" = 0, "fat" = 0, "vitamins" = 0)
		for (var/i in 1 to 1400)
			drift.handle_diet()
		diet_assert(drift.diet_imbalance_ticks >= 1350 && drift.diet_recovery_factor() == 1, "penalties stay off by default")
		diet_penalties_enabled = TRUE
		diet_assert(drift.diet_recovery_factor() == 0.75, "enabled fatigue is mild")
		drift.nutrition = -10
		diet_assert(drift.diet_recovery_factor() == 1, "fatigue never stacks with starvation")
		drift.nutrition = 200
		diet_eat(drift, "protein", 4)
		diet_eat(drift, "nutriment", 3, list("carrot" = 1))
		drift.handle_diet()
		diet_assert(drift.diet_adequate_groups() >= 3 && drift.diet_imbalance_ticks > 1300 && drift.diet_recovery_factor() == 0.75, "recovery is gradual, not instant")
		for (var/i in 1 to 30)
			drift.handle_diet()
		diet_assert(drift.diet_recovery_factor() == 1, "balanced meals restore normal recovery")
		diet_penalties_enabled = FALSE
		var/status = drift.diet_status_text()
		diet_assert(findtext(status, "Energy capacity:") && findtext(status, "Carbohydrate:"), "status explains reserves and capacity")

		// Durable state is saved with the body and the character mind.
		diet_assert(("diet_reserves" in liker.get_saved_vars()) && ("diet_enjoyment" in liker.get_saved_vars()), "body diet state is saved")
		diet_assert(!("diet_last_check" in drift.get_saved_vars()), "status snapshot is not saved")
		var/list/mind_vars = liker.mind.get_saved_vars()
		diet_assert(("diet_tastes" in mind_vars) && ("diet_taste_token" in mind_vars) && ("diet_tastes_known" in mind_vars) && ("learned_discoveries" in mind_vars), "character tastes and notes are saved")
		liker.mind.current = null // detached mind graph; full-body reclaim is outside this probe
		map_storage.clear_bookkeeping()
		map_storage.saving_z = 1
		var/savefile/S = new("mind.sav")
		S["/format_version"] << 2
		var/entry = map_storage.BuildVarDirectory(S, liker.mind, 1)
		S.Flush()
		S = null
		S = new("mind.sav")
		map_storage.clear_bookkeeping()
		var/datum/mind/restored = map_storage.Load_Entry(S, entry, starting_loc = site)
		liker.mind.current = liker
		diet_assert(istype(restored) && restored.diet_taste_token == liker.mind.diet_taste_token && restored.diet_tastes ~= liker.mind.diet_tastes && restored.diet_tastes_known["carrot"] == 1, "tastes survive a native save and load")
		restored.diet_ensure_tastes()
		diet_assert(restored.diet_taste_token == liker.mind.diet_taste_token && findtext(restored.discoveries_html(), "enjoy the taste of carrot"), "restored character keeps tastes and readable notes without a reroll")
		text2file("PASS: balanced diet", "result.txt")
	catch (var/exception/E)
		world.log << "DIET exception: [E] at [E.file]:[E.line]"
		text2file("FAIL: [E.name]", "result.txt")
	shutdown()
