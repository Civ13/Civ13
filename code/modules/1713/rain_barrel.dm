// Open barrels left outside catch rain, and dew on clear nights.
// Collection uses the existing object scheduler. No offline or lag catch-up.
/obj/item/weapon/reagent_containers/glass/barrel
	var/collects_rain = TRUE
	var/tmp/collection_seconds = 0
	var/tmp/collection_mode = 0
	var/tmp/last_collection_tick = 0

/obj/item/weapon/reagent_containers/glass/barrel/jerrycan
	collects_rain = FALSE

/obj/item/weapon/reagent_containers/glass/barrel/fueltank
	collects_rain = FALSE

/obj/item/weapon/reagent_containers/glass/barrel/New()
	..()
	start_rain_collection()

/obj/item/weapon/reagent_containers/glass/barrel/persistence_runtime_var(key)
	return (key in list("collection_seconds", "collection_mode", "last_collection_tick")) || ..()

// Registration is cheap and idempotent; the first tick drops closed barrels.
/obj/item/weapon/reagent_containers/glass/barrel/proc/start_rain_collection()
	reset_rain_collection()
	if (collects_rain && !QDELETED(src))
		processing_objects |= src

/obj/item/weapon/reagent_containers/glass/barrel/proc/reset_rain_collection()
	collection_seconds = 0
	collection_mode = 0
	last_collection_tick = world.time

/obj/item/weapon/reagent_containers/glass/barrel/attack_self(mob/user)
	. = ..()
	if (is_open_container())
		start_rain_collection()
	else
		reset_rain_collection()

// Values are game balance, using the existing area/time/temperature model.
// A wet enum alone also covers snow: use the visible rain/monsoon state.
/obj/item/weapon/reagent_containers/glass/barrel/proc/collection_rate()
	if (!collects_rain || QDELETED(src) || !is_open_container() || !isturf(loc) || radiation > 0)
		return 0
	var/turf/T = loc
	var/area/A = get_area(T)
	if (!A || A.location != AREA_OUTSIDE || A.is_void_area || T.radiation > 0 || (locate(/obj/roof) in T))
		return 0
	var/temp = get_temp(src)
	if (temp <= 0 || (map && (map.heat_wave || map.sandstorm || map.blizzard)))
		return 0
	if (findtext(A.icon_state, "rain") || findtext(A.icon_state, "monsoon"))
		return 10
	if (A.weather == WEATHER_NONE && (time_of_day in list("Night", "Dark Night", "Early Morning")) && temp <= 30)
		return 2
	return 0

/obj/item/weapon/reagent_containers/glass/barrel/process_interval(configured_seconds = 2)
	if (!collects_rain || QDELETED(src) || !is_open_container())
		reset_rain_collection()
		return PROCESS_KILL
	// Credit at most one normal object interval, and never twice in one tick.
	var/elapsed = min(2, max(0, configured_seconds), max(0, (world.time - last_collection_tick) / 10))
	last_collection_tick = world.time
	var/rate = collection_rate()
	if (!rate || !reagents || reagents.total_volume >= reagents.maximum_volume)
		collection_seconds = 0
		collection_mode = 0
		return
	if (rate != collection_mode)
		collection_seconds = 0
		collection_mode = rate
	collection_seconds += elapsed
	if (collection_seconds >= 60)
		collection_seconds = 0
		reagents.add_reagent("water", min(rate, reagents.maximum_volume - reagents.total_volume))

/obj/item/weapon/reagent_containers/glass/barrel/examine(mob/user)
	..()
	if (collects_rain && is_open_container())
		to_chat(user, SPAN_NOTICE("With the lid off and nothing overhead, it catches rain outdoors, and dew on clear nights."))

// Legacy dew collectors from older saves and maps turn into open (or closed)
// wood barrels with their water on the first object tick, outside any load.
/obj/structure/reagent_dispensers/dew_collector
	name = "dew collector"
	desc = "An old collecting barrel."
	icon = 'icons/obj/barrel.dmi'
	icon_state = "barrel_wood"
	anchored = TRUE
	not_movable = TRUE
	max_capacity = 200
	var/collecting = TRUE

/obj/structure/reagent_dispensers/dew_collector/New()
	..()
	verbs -= /obj/structure/reagent_dispensers/verb/switch_mode
	processing_objects |= src

/obj/structure/reagent_dispensers/dew_collector/process_interval(configured_seconds = 2)
	if (QDELETED(src) || !isturf(loc))
		return PROCESS_KILL
	convert_to_barrel()
	return PROCESS_KILL

/obj/structure/reagent_dispensers/dew_collector/proc/convert_to_barrel()
	var/obj/item/weapon/reagent_containers/glass/barrel/B = new /obj/item/weapon/reagent_containers/glass/barrel(loc)
	if (reagents && B.reagents)
		reagents.trans_to_holder(B.reagents, reagents.total_volume)
	if (!collecting)
		B.flags &= ~OPENCONTAINER
	B.dir = dir
	B.update_icon()
	B.start_rain_collection()
	qdel(src)
	return B
