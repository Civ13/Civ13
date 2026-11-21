// Timekeeping before the pocket watch, and lighthouses (docs/timekeeping.md).
//
// A sundial tells the hour when the sun is out. A water clock tells it to the
// half hour day or night while it holds water, and runs dry in two hours. An
// hourglass times one minute. A tower clock, wound by hand, keeps the time for
// the clock faces near it and tolls the hour on any bell beside it, heard far
// across the land. A bell can also be rung by hand as an alarm.
//
// A lit lighthouse beacon shines over the sea at night: everyone on the water
// within its range is told now and then which way the light lies.

#define WATER_CLOCK_CAPACITY 120 // minutes of water
#define HOURGLASS_TIME 600
#define TOWER_CLOCK_WIND 120 // minutes a winding lasts
#define BELL_RANGE 60
#define BELL_COOLDOWN 100
#define CLOCK_FACE_RANGE 7
#define BEACON_RANGE 120
#define BEACON_REFLECTOR_RANGE 200
#define BEACON_BURN 1 // fuel per minute
#define BEACON_FUEL_CAP 120
#define BEACON_TELL_GAP 3000

// "about 3 o'clock in the afternoon", from the current game time rounded to
// step minutes (60 or 30).
/proc/rough_clock(step = 60)
	var/exact = clock_time()
	var/hr = text2num(copytext(exact, 1, 3))
	var/mn = text2num(copytext(exact, 4, 6))
	var/pm = copytext(exact, 7) == "PM"
	var/h24 = (hr % 12) + (pm ? 12 : 0)
	var/total = round((h24 * 60 + mn) / step + 0.5) * step
	total %= 1440
	h24 = round(total / 60)
	mn = total - h24 * 60
	var/h12 = h24 % 12
	if (!h12)
		h12 = 12
	var/part = "at night"
	if (h24 >= 5 && h24 < 12)
		part = "in the morning"
	else if (h24 >= 12 && h24 < 18)
		part = "in the afternoon"
	else if (h24 >= 18 && h24 < 22)
		part = "in the evening"
	if (h24 == 12 && !mn)
		return "about noon"
	if (!h24 && !mn)
		return "about midnight"
	return "about [mn ? "half past [h12]" : "[h12] o'clock"] [part]"

// ---- sundial ---------------------------------------------------------------------

/obj/structure/sundial
	name = "sundial"
	desc = "A dial plate with an upright blade. In sunshine its shadow falls on the hour."
	icon = 'icons/obj/timekeeping.dmi'
	icon_state = "sundial"
	density = TRUE
	anchored = TRUE
	not_disassemblable = FALSE

/obj/structure/sundial/proc/reading()
	if (!signal_fire_open_sky(src))
		return "No sun reaches it under a roof."
	if (!(time_of_day in list("Morning", "Midday", "Afternoon")))
		return "There is no shadow on it now."
	if (weather_at(src) != WEATHER_NONE)
		return "Clouds hide the sun; there is no shadow to read."
	return "The shadow falls at [rough_clock(60)]."

/obj/structure/sundial/examine(mob/user)
	..()
	if (get_dist(user, src) <= 1)
		to_chat(user, SPAN_NOTICE(reading()))

/obj/structure/sundial/attack_hand(mob/user)
	to_chat(user, SPAN_NOTICE(reading()))

// ---- water clock -----------------------------------------------------------------

/obj/structure/water_clock
	name = "water clock"
	desc = "A marked vessel that empties drop by drop through a spout. Fill it with water and read the hour, day or night, from the line the water has sunk to."
	icon = 'icons/obj/timekeeping.dmi'
	icon_state = "water_clock_empty"
	density = TRUE
	anchored = TRUE
	not_disassemblable = FALSE
	var/water = 0 // minutes left
	var/links = "" // cords to a lever-worked thing (mechanisms.dm)
	var/alarm_hour = -1 // -1 off, or the hour 0 to 23 its float striker pulls the cords
	var/tmp/drip_seconds = 0
	var/tmp/last_tick = 0
	var/tmp/last_hour = null

/obj/structure/water_clock/persistence_runtime_var(key)
	return key == "drip_seconds" || key == "last_tick" || key == "last_hour" || ..()

/obj/structure/water_clock/New()
	..()
	update_icon()

/obj/structure/water_clock/on_runtime_spawn()
	..()
	if (water > 0)
		start_dripping()

/obj/structure/water_clock/Destroy()
	processing_objects -= src
	return ..()

/obj/structure/water_clock/update_icon()
	icon_state = water > 0 ? "water_clock" : "water_clock_empty"

/obj/structure/water_clock/proc/start_dripping()
	last_tick = world.time
	processing_objects |= src

/obj/structure/water_clock/attackby(obj/item/O, mob/user)
	if (istype(O, /obj/item/stack/material/rope) && ishuman(user))
		mechanism_rope_on_trigger(src, O, user)
		return
	if (istype(O, /obj/item/weapon/reagent_containers))
		var/obj/item/weapon/reagent_containers/RG = O
		if (!RG.reagents || !RG.reagents.has_reagent("water", 1))
			to_chat(user, SPAN_WARNING("It needs clean water."))
			return
		var/room = WATER_CLOCK_CAPACITY - water
		if (room <= 0)
			to_chat(user, SPAN_NOTICE("\The [src] is full."))
			return
		var/used = min(room, RG.reagents.get_reagent_amount("water"))
		RG.reagents.remove_reagent("water", used)
		water += used
		start_dripping()
		update_icon()
		user.visible_message(SPAN_NOTICE("[user] fills \the [src]."), SPAN_NOTICE("You fill \the [src]; it starts to drip."))
		return
	return ..()

/obj/structure/water_clock/process_interval(configured_seconds = 2)
	if (QDELETED(src) || water <= 0)
		processing_objects -= src
		return PROCESS_KILL
	drip_seconds += min(2, max(0, configured_seconds), max(0, (world.time - last_tick) / 10))
	last_tick = world.time
	if (alarm_hour >= 0)
		var/h24 = mechanism_hour24()
		if (!isnull(last_hour) && h24 != last_hour)
			mechanism_clock_alarm(src, alarm_hour, links, h24)
		last_hour = h24
	if (drip_seconds < 60)
		return
	drip_seconds -= 60
	water = max(0, water - 1)
	if (!water)
		update_icon()
		visible_message(SPAN_NOTICE("\The [src] has run dry."))

/obj/structure/water_clock/proc/reading()
	if (water <= 0)
		return "It is dry. Fill it with water to set it running."
	return "The water stands at [rough_clock(30)]."

/obj/structure/water_clock/examine(mob/user)
	..()
	if (get_dist(user, src) <= 1)
		to_chat(user, SPAN_NOTICE(reading()))
		to_chat(user, SPAN_NOTICE("Its float striker pulls its cords [mechanism_alarm_name(alarm_hour)]."))
		mechanism_links_examine(src, user)

/obj/structure/water_clock/attack_hand(mob/user)
	to_chat(user, SPAN_NOTICE(reading()))

// ---- hourglass -------------------------------------------------------------------

/obj/item/hourglass
	name = "hourglass"
	desc = "Sand running between two glass bulbs. Turn it over to time a minute."
	icon = 'icons/obj/timekeeping.dmi'
	icon_state = "hourglass"
	w_class = ITEM_SIZE_SMALL
	var/tmp/running_until = 0
	var/tmp/turns = 0

/obj/item/hourglass/persistence_runtime_var(key)
	return key == "running_until" || key == "turns" || ..()

/obj/item/hourglass/attack_self(mob/user)
	turns++
	var/my_turn = turns
	running_until = world.time + HOURGLASS_TIME
	icon_state = "hourglass_running"
	user.visible_message(SPAN_NOTICE("[user] turns over \the [src]."), SPAN_NOTICE("You turn over \the [src]."))
	addtimer(CALLBACK(src, PROC_REF(run_out), my_turn), HOURGLASS_TIME)

/obj/item/hourglass/proc/run_out(my_turn)
	if (QDELETED(src) || turns != my_turn)
		return
	running_until = 0
	icon_state = "hourglass"
	var/mob/M = loc
	if (istype(M))
		to_chat(M, SPAN_NOTICE("The sand in \the [src] has run out."))
	else
		visible_message(SPAN_NOTICE("The sand in \the [src] has run out."))

// ---- tower clock, clock faces and bells ------------------------------------------

/obj/structure/tower_clock
	name = "tower clock"
	desc = "A frame of iron wheels driven by a falling weight. Wound by hand, it keeps the time for the clock faces near it and strikes the hour on a bell beside it."
	icon = 'icons/obj/timekeeping.dmi'
	icon_state = "tower_clock"
	density = TRUE
	anchored = TRUE
	not_disassemblable = FALSE
	var/wound = 0 // minutes left
	var/links = "" // cords to a lever-worked thing (mechanisms.dm)
	var/alarm_hour = -1 // -1 off, 24 every hour, or the hour 0 to 23 it pulls the cords
	var/tmp/tick_seconds = 0
	var/tmp/last_tick = 0
	var/tmp/last_hour = null

/obj/structure/tower_clock/persistence_runtime_var(key)
	return (key in list("tick_seconds", "last_tick", "last_hour")) || ..()

/obj/structure/tower_clock/on_runtime_spawn()
	..()
	if (wound > 0)
		start_running()

/obj/structure/tower_clock/Destroy()
	processing_objects -= src
	return ..()

/obj/structure/tower_clock/proc/start_running()
	last_tick = world.time
	last_hour = clock_hour()
	processing_objects |= src

/obj/structure/tower_clock/proc/running()
	return wound > 0

/obj/structure/tower_clock/attack_hand(mob/user)
	user.visible_message(SPAN_NOTICE("[user] starts winding \the [src]."), SPAN_NOTICE("You wind the weight up on its rope."))
	if (!do_after(user, 50, src))
		return
	wound = TOWER_CLOCK_WIND
	start_running()
	to_chat(user, SPAN_NOTICE("\The [src] is wound. It reads [rough_clock(30)]."))

/obj/structure/tower_clock/examine(mob/user)
	..()
	if (get_dist(user, src) <= 1)
		to_chat(user, running() ? SPAN_NOTICE("It is running.") : SPAN_WARNING("It has run down. Wind it by hand."))
		to_chat(user, SPAN_NOTICE("Its striking train pulls its cords [mechanism_alarm_name(alarm_hour)]."))
		mechanism_links_examine(src, user)

/obj/structure/tower_clock/attackby(obj/item/O, mob/user)
	if (istype(O, /obj/item/stack/material/rope) && ishuman(user))
		mechanism_rope_on_trigger(src, O, user)
		return
	return ..()

// The hour on a twelve-hour dial.
/proc/clock_hour()
	var/hr = text2num(copytext(clock_time(), 1, 3)) % 12
	return hr ? hr : 12

/obj/structure/tower_clock/process_interval(configured_seconds = 2)
	if (QDELETED(src) || wound <= 0)
		processing_objects -= src
		return PROCESS_KILL
	tick_seconds += min(2, max(0, configured_seconds), max(0, (world.time - last_tick) / 10))
	last_tick = world.time
	if (tick_seconds >= 60)
		tick_seconds -= 60
		wound--
		if (!wound)
			visible_message(SPAN_NOTICE("\The [src] runs down and stops."))
			return
	var/hour = clock_hour()
	if (hour != last_hour)
		last_hour = hour
		strike(hour)
		mechanism_clock_alarm(src, alarm_hour, links, mechanism_hour24())

/obj/structure/tower_clock/proc/strike(hour)
	for (var/obj/structure/bell/B in range(2, src))
		B.toll(hour)
		return TRUE
	return FALSE

/obj/structure/clock_face
	name = "clock face"
	desc = "A painted dial with a single hand. It shows the time kept by a tower clock nearby."
	icon = 'icons/obj/timekeeping.dmi'
	icon_state = "clock_face"
	density = FALSE
	anchored = TRUE
	layer = 3.3
	not_disassemblable = FALSE

// Hung like a sign: it stands on the floor tile and shows on the wall behind.
/obj/structure/clock_face/New()
	..()
	clock_face_offset()

/obj/structure/clock_face/set_dir(ndir)
	. = ..()
	clock_face_offset()

/obj/structure/clock_face/proc/clock_face_offset()
	pixel_x = 0
	pixel_y = 0
	switch (dir)
		if (SOUTH)
			pixel_y = 32
		if (NORTH)
			pixel_y = -32
		if (EAST)
			pixel_x = -32
		if (WEST)
			pixel_x = 32

/obj/structure/clock_face/proc/reading()
	for (var/obj/structure/tower_clock/C in range(CLOCK_FACE_RANGE, src))
		if (C.running())
			return "The hand stands at [rough_clock(30)]."
	return "The hand has stopped. The clock that drives it needs winding."

/obj/structure/clock_face/examine(mob/user)
	..()
	to_chat(user, SPAN_NOTICE(reading()))

/obj/structure/bell
	name = "bell"
	desc = "A great bronze bell on a timber yoke. Ring it by hand to raise an alarm, or hang it beside a tower clock to strike the hours."
	icon = 'icons/obj/timekeeping.dmi'
	icon_state = "bell"
	density = TRUE
	anchored = TRUE
	not_disassemblable = FALSE
	var/tmp/next_ring = 0

/obj/structure/bell/persistence_runtime_var(key)
	return key == "next_ring" || ..()

/obj/structure/bell/attack_hand(mob/user)
	if (world.time < next_ring)
		to_chat(user, SPAN_WARNING("The bell is still swinging."))
		return
	user.visible_message(SPAN_WARNING("[user] rings \the [src]!"), SPAN_NOTICE("You haul on the rope and ring \the [src]."))
	ring(0)

/obj/structure/bell/proc/toll(hour)
	ring(hour)

// Rings once as an alarm (strokes 0), or strikes the hour.
/obj/structure/bell/proc/ring(strokes)
	next_ring = world.time + BELL_COOLDOWN
	flick("bell_ring", src)
	playsound(get_turf(src), 'sound/effects/bell_stand.ogg', 100, TRUE, BELL_RANGE / 3)
	var/turf/T = get_turf(src)
	if (!T)
		return 0
	var/heard = 0
	var/what = strokes ? "A bell tolls [strokes] time\s" : "A bell rings out in alarm"
	for (var/mob/living/human/H in human_mob_list)
		if (H.stat == DEAD || H.sleeping > 0 || get_dist(H, T) > BELL_RANGE || H.ear_deaf)
			continue
		if (!(H.z in timekeeping_z_column(T)))
			continue
		if (get_dist(H, T) > 7)
			to_chat(H, SPAN_NOTICE("[what], [signal_fire_bearing(get_turf(H), T)]."))
		heard++
	return heard

// The z levels stacked with T's, so sound and light carry up and down a tower.
/proc/timekeeping_z_column(turf/T)
	. = list(T.z)
	var/turf/U = T
	while ((U = GetAbove(U)))
		. += U.z
	U = T
	while ((U = GetBelow(U)))
		. += U.z

// ---- lighthouse beacon -----------------------------------------------------------

/obj/structure/lighthouse_beacon
	name = "lighthouse beacon"
	desc = "An iron fire basket for the top of a tower. Feed it wood, coal or charcoal and light it: at night, ships at sea see where it lies."
	icon = 'icons/obj/lighthouse.dmi'
	icon_state = "beacon"
	density = TRUE
	anchored = TRUE
	not_disassemblable = FALSE
	var/fuel = 0 // minutes
	var/lit = FALSE
	var/light_reach = BEACON_RANGE
	var/lit_state = "beacon_lit"
	var/tmp/burn_seconds = 0
	var/tmp/last_tick = 0
	var/tmp/list/told = null // viewer = world.time told

/obj/structure/lighthouse_beacon/persistence_runtime_var(key)
	return (key in list("burn_seconds", "last_tick", "told")) || ..()

/obj/structure/lighthouse_beacon/reflector
	name = "reflector lighthouse lamp"
	desc = "A fire basket with a polished bronze mirror behind it, throwing the light much farther out to sea."
	icon_state = "beacon"
	light_reach = BEACON_REFLECTOR_RANGE
	lit_state = "beacon_reflector"

/obj/structure/lighthouse_lantern
	name = "lantern room glazing"
	desc = "Iron-framed glass panes to keep the wind off a lighthouse fire."
	icon = 'icons/obj/lighthouse.dmi'
	icon_state = "lighthouse_lantern"
	density = TRUE
	anchored = TRUE
	opacity = FALSE
	not_disassemblable = FALSE

/obj/structure/lighthouse_beacon/is_open_flame()
	return lit

/obj/structure/lighthouse_beacon/on_runtime_spawn()
	..()
	if (lit)
		light_up()

/obj/structure/lighthouse_beacon/Destroy()
	processing_objects -= src
	return ..()

/obj/structure/lighthouse_beacon/proc/beacon_fuel_value(obj/item/I)
	if (istype(I, /obj/item/stack/material/wood))
		return 10
	if (istype(I, /obj/item/stack/ore/coal) || istype(I, /obj/item/stack/ore/charcoal))
		return 20
	return 0

/obj/structure/lighthouse_beacon/attackby(obj/item/O, mob/user)
	var/value = beacon_fuel_value(O)
	if (value)
		if (fuel + value > BEACON_FUEL_CAP)
			to_chat(user, SPAN_NOTICE("The basket is full."))
			return
		var/obj/item/stack/S = O
		S.use(1)
		fuel += value
		to_chat(user, SPAN_NOTICE("You feed \the [src]."))
		return
	if (!lit && fuel > 0 && isflamesource(O))
		user.visible_message(SPAN_NOTICE("[user] lights \the [src]."))
		light_up()
		return
	return ..()

/obj/structure/lighthouse_beacon/attack_hand(mob/user)
	if (lit)
		user.visible_message(SPAN_NOTICE("[user] smothers \the [src]."))
		go_out()
		return
	return ..()

/obj/structure/lighthouse_beacon/proc/light_up()
	lit = TRUE
	icon_state = lit_state
	set_light(8, 4, "#ffc56b")
	last_tick = world.time
	processing_objects |= src

/obj/structure/lighthouse_beacon/proc/go_out()
	lit = FALSE
	icon_state = "beacon"
	set_light(0)
	processing_objects -= src

/obj/structure/lighthouse_beacon/examine(mob/user)
	..()
	if (get_dist(user, src) <= 1)
		to_chat(user, SPAN_NOTICE("It holds fuel for about [fuel] minutes."))

/obj/structure/lighthouse_beacon/process_interval(configured_seconds = 2)
	if (QDELETED(src) || !lit)
		return PROCESS_KILL
	burn_seconds += min(2, max(0, configured_seconds), max(0, (world.time - last_tick) / 10))
	last_tick = world.time
	if (burn_seconds < 60)
		return
	burn_seconds -= 60
	fuel = max(0, fuel - BEACON_BURN)
	if (!fuel)
		visible_message(SPAN_NOTICE("\The [src] burns out."))
		go_out()
		return PROCESS_KILL
	shine()

/proc/beacon_dark_out()
	return time_of_day in list("Evening", "Night", "Dark Night", "Early Morning")

/proc/beacon_on_water(mob/living/human/H)
	return istype(get_turf(H), /turf/floor/beach/water)

// Tells sailors in range where the light is, at most every five minutes each.
/obj/structure/lighthouse_beacon/proc/shine()
	var/turf/T = get_turf(src)
	if (!T || !beacon_dark_out() || !signal_fire_open_sky(T))
		return 0
	if (!islist(told))
		told = list()
	var/list/column = timekeeping_z_column(T)
	var/count = 0
	for (var/mob/living/human/H in human_mob_list)
		if (!(H.z in column) || get_dist(H, T) > light_reach || !signal_fire_can_see(H) || !beacon_on_water(H))
			continue
		var/last = told[H]
		if (isnum(last) && world.time - last < BEACON_TELL_GAP)
			continue
		told[H] = world.time
		to_chat(H, SPAN_NOTICE("You see the light of a lighthouse [signal_fire_bearing(get_turf(H), T)]."))
		count++
	return count

#undef WATER_CLOCK_CAPACITY
#undef HOURGLASS_TIME
#undef TOWER_CLOCK_WIND
#undef BELL_RANGE
#undef BELL_COOLDOWN
#undef CLOCK_FACE_RANGE
#undef BEACON_RANGE
#undef BEACON_REFLECTOR_RANGE
#undef BEACON_BURN
#undef BEACON_FUEL_CAP
#undef BEACON_TELL_GAP
