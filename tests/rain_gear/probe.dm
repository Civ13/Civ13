// Native probe: rain gear, capes over clothing, grease finishes, wringing,
// wet slowdown and ballistic plate weight.
// Run: python3 tests/ecology_spawning/run_linux.py . tests/rain_gear/probe.dm
/world
	hub = ""
	hub_password = ""
	visibility = 0
	maxx = 8
	maxy = 4
	maxz = 1
	turf = /turf/floor/plating

/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

/client/New()
	del(src)
	return

/obj/map_metadata/rg_probe/New()
	return

// Skip the human constructor; these checks only read worn slots and vars.
/mob/living/human/rg_probe/New()
	return
/mob/living/human/rg_probe/update_inv_l_hand()
	return
/mob/living/human/rg_probe/update_inv_r_hand()
	return
/mob/living/human/rg_probe/update_inv_w_uniform()
	return
/mob/living/human/rg_probe/update_inv_wear_suit()
	return

var/rg_failures = 0
var/rg_runtime_error = FALSE
/proc/rg_check(condition, label)
	if (!condition)
		rg_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"

/world/Error(exception/e)
	rg_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new /decl/observ/moved
		GLOB.dir_set_event = new /decl/observ/dir_set
		GLOB.name_set_event = new /decl/observ/name_set
		GLOB.stat_set_event = new /decl/observ/stat_set
		map = new /obj/map_metadata/rg_probe
		map.civilizations = TRUE
		rg_checks()
	catch(var/exception/e)
		rg_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = rg_failures, "runtime_error" = rg_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/rg_close(a, b)
	return abs(a - b) < 0.0001

/proc/rg_checks()
	var/turf/T = locate(2, 2, 1)
	var/area/A = get_area(T)
	A.location = AREA_OUTSIDE
	A.weather = WEATHER_WET
	A.icon_state = "rain2"
	var/mob/living/human/rg_probe/H = new
	H.loc = T

	// Rain reads.
	rg_check(H.rain_on_mob() == 2, "steady rain falls on a mob outside")
	A.icon_state = "monsoon"
	rg_check(H.rain_on_mob() == 3 && rain_gear_wind_at(T) == 3, "a monsoon is heavy rain with a gale")
	A.icon_state = "rain2"
	var/obj/structure/lean_to/L = new(T)
	rg_check(H.rain_on_mob() == 0 && under_canopy(T), "a lean-to keeps the rain off like a canopy")
	qdel(L)

	// Nothing worn: soak at the base rate.
	rg_check(H.get_rain_protection() == 0, "no gear gives no protection")
	H.cold_wetness = 0
	H.rain_soak_step(2)
	rg_check(rg_close(H.cold_wetness, 0.01), "bare skin soaks at the base rate in steady rain")

	// Worn pieces stack as independent layers.
	var/obj/item/clothing/suit/storage/coat/ww2/japcoat_rain/coat = new(H)
	var/obj/item/clothing/head/strawhat/hat = new(H)
	H.wear_suit = coat
	H.head = hat
	rg_check(rg_close(H.get_rain_protection(), 1 - 0.2 * 0.7), "raincoat and straw hat stack")
	H.cold_wetness = 0
	H.rain_soak_step(2)
	rg_check(rg_close(H.cold_wetness, 0.01 * 0.2 * 0.7), "gear slows soaking by its protection")

	// Umbrellas only shelter when open and right side out, capped at 95%.
	var/obj/item/weapon/umbrella/U = new(H)
	H.r_hand = U
	rg_check(rg_close(H.get_rain_protection(), 1 - 0.2 * 0.7), "a closed umbrella does nothing")
	U.open = TRUE
	rg_check(rg_close(H.get_rain_protection(), 0.95), "an open umbrella over a raincoat hits the cap")
	U.wind_flip_chance = 100
	U.wind_step(null, 2)
	rg_check(!U.inside_out, "a stiff breeze does not flip an umbrella")
	U.wind_step(null, 3)
	rg_check(U.inside_out && !U.shelters(), "a gale turns an umbrella inside out")
	H.r_hand = null

	// Grease finish: replaces a weaker rating and wears off only in rain.
	var/obj/item/clothing/suit/cape/cape = new(T)
	rg_check(cape.get_rain_resist() == 35, "a plain cape sheds some rain")
	cape.apply_waterproofing(60, 2)
	rg_check(cape.get_rain_resist() == 60, "lard grease raises a cape's rating")
	cape.weather_waterproofing()
	cape.weather_waterproofing()
	rg_check(cape.get_rain_resist() == 35 && cape.waterproof_left == 0, "the grease washes out after its rain ticks")

	// Capes fasten over a coat and come back intact.
	cape.apply_waterproofing(60, 5)
	rg_check(coat.try_fasten_cape(cape, null), "a cape fastens over a coat")
	var/list/capes = H.worn_capes()
	rg_check(capes.len == 1 && !(cape in T) && cape.loc != T, "the worn cape rides on the coat")
	var/obj/item/clothing/accessory/worn_cape/W = capes[1]
	rg_check(W.get_cape() == cape && W.get_rain_resist() == 60, "the worn cape keeps the cape's grease")
	rg_check(rg_close(H.get_rain_protection(), 1 - 0.2 * 0.7 * 0.4), "a cape adds a rain layer over the coat")
	H.rain_soak_step(2)
	rg_check(cape.waterproof_left == 4, "rain wears the grease on a worn cape")
	var/obj/item/clothing/suit/cape/blue/second = new(T)
	rg_check(coat.try_fasten_cape(second, null) && second.loc == T, "only one cape fits over a coat")
	coat.remove_accessory(null, W)
	rg_check(cape.loc == T && !(W in coat.accessories) && !H.worn_capes().len, "unfastening gives back the same cape")
	var/obj/item/clothing/under/shirt = new(H)
	H.w_uniform = shirt
	rg_check(shirt.try_fasten_cape(second, null) && H.worn_capes().len == 1, "a cape can be fastened over a uniform")
	var/obj/item/clothing/head/strawhat/not_cape = new(T)
	rg_check(!coat.try_fasten_cape(not_cape, null), "only cape-wearable suits fasten as capes")

	var/obj/item/clothing/suit/straw_rain_cape/straw = new(T)
	rg_check(coat.try_fasten_cape(straw, null), "a straw rain cape fastens over a coat")
	var/obj/item/clothing/accessory/worn_cape/SW = coat.accessories[1]
	rg_check(SW.icon_override == 'icons/mob/rain_gear.dmi' && SW.overlay_state == "straw_rain_cape", "the worn straw cape draws its own sprite")
	rg_check(coat.get_cold_coverage() & UPPER_TORSO, "a fastened cape adds its cold coverage")

	// Wet clothes slow movement on settlement maps.
	H.cold_wetness = 1
	rg_check(rg_close(H.wet_clothes_slowdown(), 0.6), "soaked clothes add movement delay")
	H.cold_wetness = 0.3
	rg_check(rg_close(H.wet_clothes_slowdown(), 0.18), "wrung-out clothes drag less")
	map.civilizations = FALSE
	rg_check(H.wet_clothes_slowdown() == 0, "battle maps have no wet slowdown")
	map.civilizations = TRUE

	// Drying: by the fire beats warm air beats cold air.
	H.cold_wetness = 1
	rg_check(H.drying_rate(5) == 0.002 && H.drying_rate(20) == 0.01, "air dries slowly in the cold")
	var/obj/structure/brazier/B = new(locate(4, 2, 1))
	B.on = TRUE
	rg_check(H.drying_rate(5) == 0.03, "a lit fire two tiles away dries fast")
	B.on = FALSE

	// Umbrella shade in hot sun.
	U.inside_out = FALSE
	U.open = TRUE
	H.l_hand = U
	rg_check(H.umbrella_shade_temperature(40) == 34 && H.umbrella_shade_temperature(28) == 25 && H.umbrella_shade_temperature(20) == 20, "an open umbrella shades hot sun only")
	H.l_hand = null

	// Ballistic plates add weight inside a carrier.
	var/obj/item/clothing/accessory/armor/coldwar/plates/platecarrier/PC = new(T)
	PC.hold.contents += new /obj/item/weapon/armorplates
	PC.hold.contents += new /obj/item/weapon/armorplates
	shirt.accessories += PC
	rg_check(rg_close(H.armor_plate_slowdown(), 0.2), "two inserted plates add weight")
