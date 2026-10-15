// Collection uses the existing object scheduler. No offline or lag catch-up.
/obj/structure/reagent_dispensers/dew_collector
	name = "dew collector"
	desc = "A covered collecting barrel. Open its cover outdoors for clear-night dew or rain. Use an open container to draw water."
	icon = 'icons/obj/barrel.dmi'
	icon_state = "barrel_wood"
	anchored = TRUE
	not_movable = TRUE
	max_capacity = 200
	var/collecting = TRUE
	var/tmp/collection_seconds = 0
	var/tmp/collection_mode = 0
	var/tmp/last_collection_tick = 0
	var/tmp/drawing = FALSE
	var/tmp/retired_collector = FALSE

/obj/structure/reagent_dispensers/dew_collector/New()
	..()
	verbs -= /obj/structure/reagent_dispensers/verb/switch_mode
	last_collection_tick = world.time
	processing_objects |= src

/obj/structure/reagent_dispensers/dew_collector/proc/retire_collection()
	retired_collector = TRUE
	collection_seconds = 0
	collection_mode = 0
	processing_objects -= src

/obj/structure/reagent_dispensers/dew_collector/Destroy()
	retire_collection()
	return ..()

/obj/structure/reagent_dispensers/dew_collector/Del()
	retire_collection()
	..()

/obj/structure/reagent_dispensers/dew_collector/persistence_runtime_var(key)
	return (key in list("collection_seconds", "collection_mode", "last_collection_tick", "drawing", "retired_collector")) || ..()

// Values are game balance, using the existing area/time/temperature model.
// A wet enum alone also covers snow: use the visible rain/monsoon state.
/obj/structure/reagent_dispensers/dew_collector/proc/collection_rate()
	if (retired_collector || gcDestroyed || gc_destroyed || !collecting || !isturf(loc) || !anchored || radiation > 0)
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

/obj/structure/reagent_dispensers/dew_collector/process_interval(configured_seconds = 2)
	if (retired_collector || gcDestroyed || gc_destroyed || !isturf(loc))
		retire_collection()
		return PROCESS_KILL
	// Credit at most one normal object interval, and never twice in one tick.
	var/elapsed = min(2, max(0, configured_seconds), max(0, (world.time - last_collection_tick) / 10))
	last_collection_tick = world.time
	var/rate = collection_rate()
	if (!rate || !reagents || reagents.total_volume >= max_capacity)
		collection_seconds = 0
		collection_mode = 0
		return
	if (rate != collection_mode)
		collection_seconds = 0
		collection_mode = rate
	collection_seconds += elapsed
	if (collection_seconds >= 60)
		collection_seconds = 0
		reagents.add_reagent("water", min(rate, max_capacity - reagents.total_volume))

/obj/structure/reagent_dispensers/dew_collector/attack_hand(mob/user)
	if (!can_draw(user))
		return
	collecting = !collecting
	collection_seconds = 0
	collection_mode = 0
	last_collection_tick = world.time
	to_chat(user, SPAN_NOTICE("You [collecting ? "open" : "close"] the collecting cover."))

/obj/structure/reagent_dispensers/dew_collector/examine(mob/user)
	..()
	to_chat(user, SPAN_NOTICE("The collecting cover is [collecting ? "open" : "closed"]. Capacity: 200 units. Clear nonfreezing nights yield 2 units per exposed minute; rain yields 10. Covered, frozen or irradiated collectors do not collect."))

/obj/structure/reagent_dispensers/dew_collector/proc/can_draw(mob/user)
	return user && user.stat == CONSCIOUS && !retired_collector && !gcDestroyed && !gc_destroyed && isturf(loc) && user.Adjacent(src)

/mob/proc/dew_drawing_wait(atom/target)
	return do_after(src, 15, target)

/obj/structure/reagent_dispensers/dew_collector/attackby(obj/item/O, mob/user)
	if (istype(O, /obj/item/weapon/reagent_containers))
		draw_water(O, user)
		return
	// Collection is one-way; other barrel refill/lock modes are not applicable.
	return

/obj/structure/reagent_dispensers/dew_collector/proc/draw_water(obj/item/weapon/reagent_containers/C, mob/user)
	if (drawing || !can_draw(user) || !C || C.loc != user || !C.is_open_container() || !C.reagents || !reagents || reagents.total_volume <= 0)
		return FALSE
	drawing = TRUE
	var/completed = user.dew_drawing_wait(src)
	drawing = FALSE
	if (!completed || !can_draw(user) || !C || C.loc != user || !C.is_open_container() || !C.reagents || !reagents)
		return FALSE
	var/amount = min(amount_per_transfer_from_this, C.reagents.maximum_volume - C.reagents.total_volume, reagents.get_reagent_amount("water"))
	if (amount <= 0)
		return FALSE
	// Use the existing reagent transfer path, preserving finite contents.
	return reagents.trans_id_to(C, "water", amount) > 0
