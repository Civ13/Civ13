// Native probe: living conditions move where mood settles.
// Run: python3 tests/ecology_spawning/run_linux.py . tests/mood_living/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 20
	maxy = 20
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/ml_probe/New()
	return
/mob/living/human/ml_probe
	var/rested_test_time
// A November 2026 midnight, with BYOND's native float rounding for realtime.
/mob/living/human/ml_probe/rested_learning_realtime()
	return isnull(rested_test_time) ? ..() : 8490528000 + rested_test_time
/mob/living/human/ml_probe/rested_learning_timeofday()
	return isnull(rested_test_time) ? ..() : rested_test_time - round(rested_test_time / 864000) * 864000
/mob/living/human/ml_probe/New()
	return
/mob/living/human/ml_probe/update_icons()
	return
/obj/item/weapon/book/ml_book/New()
	return
/obj/structure/bed/ml_bed/New()
	return
/obj/structure/bed/bedroll/ml_roll/New()
	return
/obj/structure/bed/chair/ml_chair/New()
	return
/obj/item/weapon/bedsheet/ml_sheet/New()
	return
/obj/item/clothing/under/ml_clothes/New()
	return
/obj/item/clothing/suit/storage/coat/ml_coat/New()
	return
/obj/item/clothing/head/ml_hat/New()
	return
/obj/item/clothing/shoes/ml_shoes/New()
	return
/obj/structure/brazier/ml_fire/New()
	return
/mob/living/simple_animal/cattle/ml_cow/New()
	return
/mob/living/simple_animal/complex_animal/dog/ml_dog/New()
	return
/obj/structure/painting_frame/ml_painting/New()
	return
/obj/structure/rock_art/ml_rock_art/New()
	return
/obj/structure/religious/gravestone/ml_grave/New()
	return
/obj/structure/religious/monument/obelisk/ml_obelisk/New()
	return
/obj/structure/table/ml_table/New()
	return
/obj/item/weapon/reagent_containers/food/snacks/ml_meal/New()
	return

var/ml_failures = 0
var/ml_runtime_error = FALSE
/proc/ml_check(condition, label)
	if (!condition)
		ml_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	ml_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		map = new /obj/map_metadata/ml_probe
		map.nomads = TRUE
		map.civilizations = TRUE
		ml_rested_research_checks()
		ml_checks()
	catch(var/exception/e)
		ml_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = ml_failures, "runtime_error" = ml_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

// A bare survivor: a bit dirty, cold, never slept in a bed, poorly fed.
/proc/ml_human(x, y)
	var/mob/living/human/ml_probe/H = new(locate(x, y, 1))
	H.stat = CONSCIOUS
	H.has_hunger_and_thirst = TRUE
	H.species = new /datum/species/human
	H.hygiene = 150
	H.bodytemperature = 290
	H.nutrition = H.max_nutrition
	H.water = H.max_water
	H.diet_reserves = list()
	for (var/group in diet_groups)
		H.diet_reserves[group] = 0
	return H

/proc/ml_rest(mob/living/human/H)
	H.refresh_mood_rest()
	return H.mood_rest

/proc/ml_checks()
	var/mob/living/human/H = ml_human(5, 5)
	ml_check(ml_rest(H) == 50 && !H.mood_rest_parts.len, "a bare survivor rests at neutral ([H.mood_rest] [json_encode(H.mood_rest_parts)])")

	// Each condition on its own.
	H.hygiene = 200
	ml_check(ml_rest(H) == 54 && H.mood_rest_parts["being clean"] == 4, "being clean lifts the resting level")
	H.hygiene = 74
	ml_check(ml_rest(H) == 42 && H.mood_rest_parts["being filthy"] == -8, "being filthy lowers it")
	H.hygiene = 150
	H.has_fleas = TRUE
	ml_check(ml_rest(H) == 45 && H.mood_rest_parts["fleas"] == -5, "fleas lower it")
	H.has_fleas = FALSE
	for (var/i = 1, i <= 2, i++)
		H.diet_reserves[diet_groups[i]] = 100
	ml_check(ml_rest(H) == 50, "two food groups are not a varied diet")
	H.diet_reserves[diet_groups[3]] = 40
	ml_check(ml_rest(H) == 55 && H.mood_rest_parts["a varied diet"] == 5, "three adequate food groups are")
	for (var/group in diet_groups)
		H.diet_reserves[group] = 0
	H.bodytemperature = H.species.body_temperature
	ml_check(ml_rest(H) == 53 && H.mood_rest_parts["being warm and dry"] == 3, "warm and dry lifts it")
	H.cold_wetness = 0.5
	ml_check(ml_rest(H) == 50, "wet clothes are not comfortable")
	H.cold_wetness = 0
	H.bodytemperature = H.species.heat_level_1
	ml_check(ml_rest(H) == 50, "overheating is not comfortable")
	H.bodytemperature = 290
	H.nutrition = H.max_nutrition * 0.25
	ml_check(ml_rest(H) == 42 && H.mood_rest_parts["going hungry"] == -8, "hunger lowers it")
	H.water = H.max_water * 0.2
	ml_check(ml_rest(H) == 34 && H.mood_rest_parts["going thirsty"] == -8, "thirst adds to hunger")
	H.nutrition = H.max_nutrition
	H.water = H.max_water
	H.traumatic_shock = 50
	ml_check(ml_rest(H) == 45 && H.mood_rest_parts["being in pain"] == -5, "lasting pain lowers it")
	H.traumatic_shock = 49
	ml_check(ml_rest(H) == 50, "a passing ache does not")
	H.disease = TRUE
	H.disease_type = "flu"
	ml_check(ml_rest(H) == 42 && H.mood_rest_parts["being sick"] == -8, "illness lowers it")
	H.disease_type = "cholera"
	H.disease_progression = 179
	ml_check(ml_rest(H) == 42, "an early serious illness counts as being sick")
	H.disease_progression = 180
	ml_check(ml_rest(H) == 38 && H.mood_rest_parts["being seriously ill"] == -12 && !("being sick" in H.mood_rest_parts), "a serious illness weighs more")
	H.disease = FALSE
	H.disease_type = "none"
	H.disease_progression = 0

	// Sleep: the bed is noted while asleep and counts after waking.
	var/turf/T = get_turf(H)
	ml_check(ml_rest(H) == 50, "recovered, the survivor rests at neutral again")
	H.inducedSSD = TRUE
	H.sleeping = 66
	var/obj/structure/bed/chair/ml_chair/chair = new(T)
	ml_rest(H)
	ml_check(H.sleep_comfort == 0, "a chair is no bed")
	chair.loc = null
	var/obj/structure/bed/bedroll/ml_roll/roll = new(T)
	ml_rest(H)
	ml_check(H.sleep_comfort == 2, "a bedroll is a simple place to sleep ([H.sleep_comfort])")
	var/obj/item/weapon/bedsheet/ml_sheet/sheet = new(T)
	ml_rest(H)
	ml_check(H.sleep_comfort == 4, "a blanket makes the bedroll comfortable")
	roll.loc = null
	ml_rest(H)
	ml_check(H.sleep_comfort == 0, "a sheet on the bare ground is no bed")
	var/obj/structure/bed/ml_bed/bed = new(T)
	sheet.loc = null
	ml_rest(H)
	ml_check(H.sleep_comfort == 4, "a proper bed is comfortable")
	bed.padding_material = new /material/cloth()
	ml_rest(H)
	ml_check(H.sleep_comfort == 6, "padding makes the bed finer ([H.sleep_comfort])")
	roll.loc = T
	roll.padding_material = bed.padding_material
	bed.loc = null
	ml_rest(H)
	ml_check(H.sleep_comfort == 2, "padding does nothing for a bedroll ([H.sleep_comfort])")
	roll.loc = null
	roll.padding_material = null
	bed.loc = T
	sheet.loc = T
	ml_rest(H)
	ml_check(H.sleep_comfort == 8 && H.sleep_comfort_name() == "a padded bed with sheets to sleep in", "padding and sheets together are the best bed ([H.sleep_comfort])")
	bed.padding_material = null
	ml_check(ml_rest(H) == 50 && H.sleep_comfort == 6, "a sleeper's resting level waits until they wake")
	H.inducedSSD = FALSE
	H.sleeping = 0
	ml_check(ml_rest(H) == 56 && H.mood_rest_parts["a fine bed to sleep in"] == 6, "a fine bed counts after waking ([H.mood_rest])")
	H.loc = locate(10, 10, 1)
	ml_check(ml_rest(H) == 56, "and keeps counting away from the bed")

	// Dressed for the weather: clothes that suit the season and climate, worn for a while.
	var/area/weather_area = get_area(H)
	var/old_climate = weather_area.climate
	var/old_season = season
	var/obj/item/clothing/under/ml_clothes/clothes = new
	var/obj/item/clothing/suit/storage/coat/ml_coat/coat = new
	coat.cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
	coat.min_cold_protection_temperature = COAT_MIN_COLD_PROTECTION_TEMPERATURE
	var/obj/item/clothing/head/ml_hat/hat = new
	hat.cold_protection = HEAD
	hat.min_cold_protection_temperature = HELMET_MIN_COLD_PROTECTION_TEMPERATURE
	var/obj/item/clothing/shoes/ml_shoes/boots = new
	H.cold_wetness = 0
	weather_area.climate = "sea"
	season = "FALL"
	ml_check(get_temp(H) >= 10 && get_temp(H) <= 18 && !H.mood_dressed_for_weather(), "nobody is dressed for the weather with no clothes on")
	H.w_uniform = clothes
	ml_check(H.mood_dressed_for_weather() && ml_rest(H) == 56, "mild weather suits plain clothes, but not at once ([H.mood_rest])")
	H.mood_dressed_since = world.time - 5990
	ml_check(ml_rest(H) == 56, "nor just short of ten minutes")
	H.mood_dressed_since = world.time - 6000
	ml_check(ml_rest(H) == 59 && H.mood_rest_parts["being dressed for the weather"] == 3, "after ten minutes they lift the resting level ([H.mood_rest])")
	H.w_uniform = null
	ml_check(ml_rest(H) == 56 && !H.mood_dressed_since, "undressing ends it and restarts the wait")
	H.w_uniform = clothes
	season = "WINTER"
	weather_area.climate = "temperate"
	ml_check(get_temp(H) < 10 && !H.mood_dressed_for_weather(), "plain clothes are not enough in a temperate winter ([get_temp(H)] [H.get_cold_protection(get_temp(H) + 273.15)])")
	H.wear_suit = coat
	ml_check(H.mood_dressed_for_weather(), "a coat over them is")
	H.cold_wetness = 1
	ml_check(!H.mood_dressed_for_weather(), "soaked layers do not count as warm")
	H.cold_wetness = 0
	// Ordinary layers stop helping below -33 C: a tundra blizzard is that cold.
	weather_area.climate = "tundra"
	var/ml_old_weather = weather_area.weather
	var/ml_old_look = weather_area.icon_state
	weather_area.weather = WEATHER_EXTREME
	weather_area.icon_state = "snow_storm"
	ml_check(get_temp(H) < -33 && !H.mood_dressed_for_weather(), "a tundra blizzard takes more than a coat ([get_temp(H)])")
	H.head = hat
	ml_check(H.mood_dressed_for_weather(), "a coat and a warm hat suit the tundra")
	weather_area.weather = ml_old_weather
	weather_area.icon_state = ml_old_look
	weather_area.climate = "desert"
	season = "SUMMER"
	var/ml_old_time = time_of_day
	time_of_day = "Afternoon"
	ml_check(get_temp(H) >= 27 && !H.mood_dressed_for_weather(), "a coat does not suit the desert")
	H.wear_suit = null
	ml_check(!H.mood_dressed_for_weather(), "hot ground wants something on your feet")
	H.shoes = boots
	ml_check(H.mood_dressed_for_weather(), "light clothes and shoes suit the heat")
	time_of_day = ml_old_time
	H.w_uniform = null
	H.head = null
	H.shoes = null
	weather_area.climate = old_climate
	season = old_season
	ml_check(ml_rest(H) == 56, "and it all ends with the clothes off")

	// Shelter: a roof, or a lit fire at night.
	var/area/here = get_area(H)
	var/outside = here.location
	here.location = AREA_INSIDE
	ml_check(ml_rest(H) == 59 && H.mood_rest_parts["a roof over your head"] == 3, "a roof lifts the resting level ([H.mood_rest])")
	here.location = AREA_OUTSIDE
	var/obj/structure/brazier/ml_fire/fire = new(locate(11, 10, 1))
	fire.on = TRUE
	time_of_day = "Midday"
	ml_check(ml_rest(H) == 56, "a fire by day is no shelter")
	time_of_day = "Night"
	ml_check(ml_rest(H) == 59 && H.mood_rest_parts["a fire to sit by at night"] == 3, "a lit fire at night is")
	fire.on = FALSE
	ml_check(ml_rest(H) == 56, "a cold brazier is not")
	fire.loc = null
	here.location = outside

	// Animal company: tame and alive, close by.
	var/mob/living/simple_animal/cattle/ml_cow/cow = new(locate(12, 10, 1))
	cow.stat = CONSCIOUS
	ml_check(ml_rest(H) == 59 && H.mood_rest_parts["animal company"] == 3, "a tame cow nearby is company ([H.mood_rest])")
	cow.wild = TRUE
	ml_check(ml_rest(H) == 56, "a wild one is not")
	cow.wild = FALSE
	cow.stat = DEAD
	ml_check(ml_rest(H) == 56, "nor is a dead one")
	cow.stat = CONSCIOUS
	cow.loc = locate(14, 10, 1)
	ml_check(ml_rest(H) == 56, "nor one four tiles away")
	cow.loc = null
	var/mob/living/simple_animal/complex_animal/dog/ml_dog/dog = new(locate(10, 11, 1))
	dog.stat = CONSCIOUS
	dog.tamed = FALSE
	ml_check(ml_rest(H) == 56, "an untamed dog is no comfort")
	dog.tamed = TRUE
	ml_check(ml_rest(H) == 59, "a tamed dog is")
	dog.loc = null

	// Art in sight: two points a piece, three pieces at most.
	new /obj/structure/religious/gravestone/ml_grave(locate(10, 12, 1))
	ml_check(ml_rest(H) == 56, "a gravestone is not art")
	var/list/works = list(new /obj/structure/painting_frame/ml_painting(locate(11, 11, 1)))
	ml_check(ml_rest(H) == 58 && H.mood_rest_parts["art around you"] == 2, "one painting lifts it a little")
	works += new /obj/structure/rock_art/ml_rock_art(locate(9, 10, 1))
	works += new /obj/structure/religious/monument/obelisk/ml_obelisk(locate(10, 13, 1))
	ml_check(ml_rest(H) == 62 && H.mood_rest_parts["art around you"] == 6, "three works lift it more ([H.mood_rest])")
	works += new /obj/structure/painting_frame/ml_painting(locate(12, 12, 1))
	ml_check(ml_rest(H) == 62, "a fourth adds nothing")
	H.loc = locate(1, 1, 1)
	ml_check(ml_rest(H) == 56, "art out of sight does nothing")
	H.loc = locate(10, 10, 1)

	// With everything, the resting level stops at the cap: good, never excellent.
	here.location = AREA_INSIDE
	dog.loc = locate(10, 11, 1)
	H.hygiene = 250
	H.bodytemperature = H.species.body_temperature
	for (var/group in diet_groups)
		H.diet_reserves[group] = 100
	ml_check(ml_rest(H) == 75 && mood_tier(H.mood_rest) == MOOD_TIER_GOOD, "the finest home rests at the cap of 75 ([H.mood_rest])")
	H.hygiene = 150
	H.bodytemperature = 290
	for (var/group in diet_groups)
		H.diet_reserves[group] = 0
	here.location = outside
	dog.loc = null
	for (var/obj/structure/work in works)
		work.loc = null

	// Small pleasures lift mood once per gap.
	H.mood = 50
	ml_check(H.mood_leisure("a good read", 5, 12000) && H.mood == 55, "a good read lifts mood")
	ml_check(!H.mood_leisure("a good read", 5, 12000) && H.mood == 55, "but not twice in a row")
	ml_check(H.mood_leisure("a meal at a table", 3, 6000) && H.mood == 58, "another pleasure has its own gap")
	H.mood_leisure_next = null
	H.mood = 50
	var/obj/item/weapon/reagent_containers/food/snacks/ml_meal/meal = new(H)
	meal.satisfaction = 5
	meal.On_Consume(H)
	ml_check(H.mood == 50, "a meal on the move is just a meal ([H.mood])")
	var/obj/structure/table/ml_table/table = new(locate(11, 10, 1))
	meal.On_Consume(H)
	ml_check(H.mood == 53, "a meal at a table is a pleasure ([H.mood])")
	meal.On_Consume(H)
	ml_check(H.mood == 53, "once per sitting")
	H.mood_leisure_next = null
	meal.satisfaction = -5
	meal.On_Consume(H)
	ml_check(H.mood == 53, "food you dislike is no pleasure at any table")
	table.loc = null
	H.mood_drift()

	// Everything good at once stays under the cap; everything bad stays above the floor.
	H.hygiene = 250
	H.bodytemperature = H.species.body_temperature
	for (var/group in diet_groups)
		H.diet_reserves[group] = 100
	ml_check(ml_rest(H) == 68, "bed, diet, washing and warmth together rest at 68 ([H.mood_rest])")
	ml_check(mood_tier(H.mood_rest) == MOOD_TIER_GOOD, "which is a good mood")
	H.mood = 68
	H.mood_drift()
	ml_check(H.mood == 68, "a comfortable character stays there")
	H.sleep_comfort = 0
	H.hygiene = 0
	H.has_fleas = TRUE
	H.nutrition = 0
	H.water = 0
	H.traumatic_shock = 100
	H.disease = TRUE
	H.disease_type = "plague"
	H.disease_progression = 500
	for (var/group in diet_groups)
		H.diet_reserves[group] = 0
	ml_check(ml_rest(H) == 30, "misery is limited to 30 ([H.mood_rest])")

	// Maps without survival needs keep the neutral resting level.
	H.disease = FALSE
	H.has_fleas = FALSE
	H.traumatic_shock = 0
	H.hygiene = 250
	H.sleep_comfort = 6
	map.nomads = FALSE
	map.civilizations = FALSE
	ml_check(ml_rest(H) == 50, "a battle map ignores living conditions ([H.mood_rest] [json_encode(H.mood_rest_parts)])")

// Exercise actual skill gains rather than checking the modifier or save-field names.
/proc/ml_skill_progress(mob/living/human/H, statname, amount)
	H.stats[statname] = list(100, 100)
	H.adaptStat(statname, amount)
	return H.getMaxStat(statname)

// Use real entry and exit procs without a connected client. The character picker
// delegates to finish_wake_up() after its own confirmation and wait.
/proc/ml_bed_transition(mob/living/human/ml_probe/H, sleep, now)
	H.rested_test_time = now
	var/succeeded = sleep ? H.enter_bed_sleep() : H.finish_wake_up()
	if (!succeeded)
		CRASH("Rested learning probe could not [sleep ? "enter bed sleep" : "wake up"]")

/proc/ml_rested_research_checks()
	map.persistence = TRUE
	build_research_tree()
	var/mob/living/human/ml_probe/H = ml_human(12, 12)
	var/mob/living/human/ml_probe/other = ml_human(13, 12)
	var/turf/T = get_turf(H)
	var/obj/structure/bed/bedroll/ml_roll/R = new(T)
	var/obj/item/weapon/book/ml_book/B = new(T)
	var/normal = ml_skill_progress(H, "medical", 20)
	ml_bed_transition(H, TRUE, -20 MINUTES)
	ml_bed_transition(H, FALSE, -8 MINUTES)
	B.add_research_work("basic_tools", 2, FALSE, H)
	ml_check(B.research_ticks("basic_tools") == 2, "a bedroll does not bank research points")
	R.loc = null
	var/obj/structure/bed/ml_bed/bed = new(T)

	ml_bed_transition(H, TRUE, -5 MINUTES)
	ml_bed_transition(H, FALSE, 5 MINUTES - 1)
	B.add_research_work("basic_tools", 2, FALSE, H)
	ml_check(B.research_ticks("basic_tools") == 4, "one decisecond short of ten minutes across midnight does not qualify")

	ml_bed_transition(H, TRUE, -5 MINUTES)
	H.rested_test_time = 0
	H.sleep_update() // Also called on reconnect; it must preserve the start.
	ml_bed_transition(H, FALSE, 5 MINUTES)
	ml_check(ml_skill_progress(H, "medical", 20) == normal, "bed rest no longer changes ordinary skill gains")
	// A full prototype study waiting for its installation, anonymous work, and
	// a second researcher's points must not spend H's rested bonus.
	var/datum/research_node/prototype = get_research_node("bronze_working")
	B.add_research_work("bronze_working", prototype.cost_ticks, FALSE, H)
	B.add_research_work("bronze_working", 0, FALSE, H)
	B.add_research_work("basic_tools", 1)
	B.add_research_work("basic_tools", 2, FALSE, other)
	ml_check(B.research_ticks("basic_tools") == 7, "unattributed and other researchers' work gets no bonus")
	H.rested_test_time = 5 MINUTES + 864000
	B.add_research_work("basic_tools", 2, FALSE, H)
	ml_check(B.research_ticks("basic_tools") == 19, "a full rest adds ten points after an offline day, even after zero-point and capped work")
	B.add_research_work("basic_tools", 2, FALSE, H)
	ml_check(B.research_ticks("basic_tools") == 21, "the bonus does not apply to a second contribution")

	ml_bed_transition(H, TRUE, 6 MINUTES + 864000)
	ml_bed_transition(H, FALSE, 16 MINUTES + 864000)
	ml_bed_transition(H, TRUE, 17 MINUTES + 864000)
	ml_bed_transition(H, FALSE, 27 MINUTES + 864000)
	var/points = B.record_field_work("soil_science_harvests", H)
	ml_check(points > 0 && B.research_ticks("soil_science") == points + 10, "field work uses one banked bonus and sleeping twice does not stack it")
	B.add_research_work("basic_tools", 2, FALSE, H)
	ml_check(B.research_ticks("basic_tools") == 23, "crediting field work spends the same one-use bonus")

	ml_bed_transition(H, TRUE, 28 MINUTES + 864000)
	ml_bed_transition(H, FALSE, 38 MINUTES + 864000)
	var/obj/item/weapon/book/ml_book/near_cap = new(T)
	near_cap.add_research_work("bronze_working", prototype.cost_ticks - 4)
	near_cap.add_research_work("bronze_working", 1, FALSE, H)
	ml_check(near_cap.research_ticks("bronze_working") == prototype.cost_ticks && !near_cap.has_research_chapter("bronze_working"), "the bonus respects the chapter cap and does not replace a required prototype")
	B.add_research_work("basic_tools", 2, FALSE, H)
	ml_check(B.research_ticks("basic_tools") == 25, "using part of the bonus near a cap does not carry leftovers to another chapter")
	bed.loc = null
	map.persistence = FALSE
