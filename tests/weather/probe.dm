// Production thermal procs are inherited; only startup and damage storage are adapted.
/world
	hub = ""
	hub_password = ""
var/weather_runtime_error = FALSE
/world/Error(exception/error)
	weather_runtime_error = TRUE
	text2file("WEATHER FAIL runtime: [error]", "weather-result.txt")
	world.log << "WEATHER FAIL runtime: [error]"
/obj/map_metadata/weather_probe/New()
	return
/mob/living/human/weather_probe
	var/probe_damage = 0
/mob/living/human/weather_probe/find_trait(trait)
	return FALSE
/mob/living/human/weather_probe/adjustBurnLoss(amount)
	probe_damage += amount
/mob/living/human/weather_probe/adjustBurnLossByPart(amount, organ_name, obj/damage_source = null)
	probe_damage += amount
/proc/weather_assert(condition, message)
	if(!condition)
		throw EXCEPTION(message)
/proc/weather_case(label, seconds, uniform = FALSE, coat = FALSE, covered = FALSE)
	var/mob/living/human/weather_probe/H = new(locate(1,1,1))
	if(uniform)
		H.w_uniform = new /obj/item/clothing/under
		H.w_uniform.cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
		H.w_uniform.min_cold_protection_temperature = 200
	if(coat)
		H.wear_suit = new /obj/item/clothing/suit/storage/coat/fur
	if(covered)
		H.head = new /obj/item/clothing/head
		H.head.cold_protection = HEAD
		H.head.min_cold_protection_temperature = 160
		H.shoes = new /obj/item/clothing/shoes
		H.shoes.cold_protection = FEET
		H.shoes.min_cold_protection_temperature = 160
		H.gloves = new /obj/item/clothing/gloves
		H.gloves.cold_protection = HANDS
		H.gloves.min_cold_protection_temperature = 160
	var/first_damage = 0
	for(var/second in 1 to seconds)
		H.handle_environment()
		H.stabilize_body_temperature()
		if(!first_damage && H.probe_damage > 0)
			first_damage = second
	text2file("[label],[seconds],[first_damage],[H.bodytemperature],[H.probe_damage]", "weather.csv")
	return H
/world/New()
	world.OpenPort(0)
	text2file("started", "weather-start.txt")
	text2file("commit=[world.params["tested_commit"]] BYOND=[world.byond_version].[world.byond_build] nominal_step_seconds=1", "metadata.txt")
	world.log << "WEATHER START"
	try
		weather_assert(world.byond_version == 516 && world.byond_build == 1681, "Pinned runtime required")
		map = new /obj/map_metadata/weather_probe
		map.civilizations = TRUE
		season = "WINTER"
		time_of_day = "Evening"
		var/area/A = get_area(locate(1,1,1))
		A.climate = "temperate"
		A.location = AREA_OUTSIDE
		A.weather = WEATHER_NONE
		text2file("case,seconds,first_damage,body_kelvin,damage", "weather.csv")
		var/mob/living/human/weather_probe/naked = weather_case("naked", 600)
		var/mob/living/human/weather_probe/uniform = weather_case("uniform", 600, TRUE)
		var/mob/living/human/weather_probe/coat = weather_case("coat", 600, FALSE, TRUE)
		var/mob/living/human/weather_probe/layers = weather_case("layers", 600, TRUE, TRUE)
		var/mob/living/human/weather_probe/full = weather_case("full", 3600, TRUE, TRUE, TRUE)
#ifdef WEATHER_BASELINE
		weather_assert(naked.probe_damage > 0, "Baseline cold damage missing")
		weather_assert(uniform.probe_damage >= 0 && full.probe_damage >= 0, "Baseline measurements available")
		weather_assert(abs(layers.bodytemperature - coat.bodytemperature) < 0.01, "Baseline layering changed")
#else
		weather_assert(naked.probe_damage < 500, "Ten-minute cold harm must leave a response window")
		weather_assert(naked.probe_damage > layers.probe_damage, "Layers must reduce harm")
		weather_assert(layers.bodytemperature > coat.bodytemperature && layers.bodytemperature > uniform.bodytemperature, "Overlapping layers must help")
		weather_assert(full.probe_damage > 0, "Complete clothing must not give indefinite immunity")
		A.weather = WEATHER_WET
		A.icon_state = "rain2"
		var/mob/living/human/weather_probe/wet = weather_case("wet_full", 1200, TRUE, TRUE, TRUE)
		weather_assert(wet.cold_wetness > 0.9 && wet.probe_damage > 0, "Rain must impair insulated survival")
		A.weather = WEATHER_NONE
		A.icon_state = ""
		var/mob/living/human/weather_probe/ordinary = new(locate(1,1,1))
		ordinary.w_uniform = new /obj/item/clothing/under
		weather_assert(ordinary.get_cold_protection(244.15) > 0, "Unmodified ordinary clothing must insulate")
		weather_assert(ordinary.get_cold_protection(213.15) == 0, "Ordinary clothing has a finite temperature rating")
		ordinary.cold_protection_disabled_timer = 10
		weather_assert(ordinary.get_cold_protection(244.15) == 0, "Disabled protection must remain disabled")
		A.climate = "tundra"
		var/mob/living/human/weather_probe/arctic = weather_case("tundra_full", 2400, TRUE, TRUE, TRUE)
		weather_assert(arctic.probe_damage > 0, "Arctic clothing protection must remain finite")
		A.weather = WEATHER_EXTREME
		A.icon_state = "snow_storm"
		var/mob/living/human/weather_probe/blizzard = weather_case("blizzard_full", 600, TRUE, TRUE, TRUE)
		weather_assert(blizzard.bodytemperature < full.bodytemperature && blizzard.probe_damage > 0, "Blizzard must overwhelm mild clothing")
		A.location = AREA_INSIDE
		var/mob/living/human/weather_probe/storm_shelter = weather_case("storm_shelter", 600, TRUE, TRUE)
		weather_assert(storm_shelter.probe_damage < blizzard.probe_damage, "Shelter must mitigate the same blizzard")
		A.location = AREA_OUTSIDE
		A.climate = "temperate"
		A.weather = WEATHER_NONE
		A.icon_state = ""
#endif
		A.location = AREA_INSIDE
		var/mob/living/human/weather_probe/sheltered = weather_case("sheltered", 600, TRUE, TRUE)
		weather_assert(sheltered.bodytemperature > layers.bodytemperature, "Shelter must improve cold survival")
		var/obj/structure/brazier/B = new(locate(1,1,1))
		B.on = TRUE
		var/mob/living/human/weather_probe/heated = weather_case("heated", 600)
		weather_assert(heated.probe_damage == 0, "Heating must prevent cold harm")
#ifndef WEATHER_BASELINE
		wet.bodytemperature = 250
		for(var/step in 1 to 1200)
			wet.handle_environment()
			wet.stabilize_body_temperature()
		weather_assert(wet.cold_wetness == 0 && wet.bodytemperature >= 307, "Heat must dry and recover a hypothermic patient")
		var/turf/water = new /turf/floor/beach/water(locate(10,10,1))
		wet.loc = water
		wet.handle_environment()
		weather_assert(wet.cold_wetness == 1, "Immersion must saturate wetness without exceeding its bound")
#endif
		weather_assert(!weather_runtime_error, "Runtime error invalidates observations")
		text2file("WEATHER PASS", "weather-result.txt")
		world.log << "WEATHER PASS"
	catch(var/exception/error)
		text2file("WEATHER FAIL: [error]", "weather-result.txt")
		world.log << "WEATHER FAIL: [error]"
	del(world)
