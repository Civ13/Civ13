// Production thermal procs are inherited; only startup and damage storage are adapted.
/obj/map_metadata/weather_probe/New()
/mob/living/human/weather_probe
	var/probe_damage = 0
/mob/living/human/weather_probe/New()
	species = new /datum/species
	bodytemperature = species.body_temperature
	nutrition = 400
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
		weather_assert(naked.probe_damage > layers.probe_damage, "Layers must reduce harm")
		weather_assert(layers.bodytemperature > coat.bodytemperature && layers.bodytemperature > uniform.bodytemperature, "Overlapping layers must help")
		weather_assert(full.probe_damage > 0, "Complete clothing must not give indefinite immunity")
#endif
		A.location = AREA_INSIDE
		var/mob/living/human/weather_probe/sheltered = weather_case("sheltered", 600, TRUE, TRUE)
		weather_assert(sheltered.bodytemperature > layers.bodytemperature, "Shelter must improve cold survival")
		var/obj/structure/brazier/B = new(locate(1,1,1))
		B.on = TRUE
		var/mob/living/human/weather_probe/heated = weather_case("heated", 600)
		weather_assert(heated.probe_damage == 0, "Heating must prevent cold harm")
		world.log << "WEATHER PASS"
	catch(var/exception/error)
		world.log << "WEATHER FAIL: [error]"
	del(world)
