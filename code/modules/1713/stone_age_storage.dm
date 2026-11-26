// Stone Age storage: places to keep things from 5000 BC, before Cooperage
// brings the wood crate and chest. Each one opens a real storage window (the
// same one a backpack opens) instead of sweeping up its tile like a crate.
//   woven basket (Weaving)              light, normal-sized things
//   clay storage jar (Pottery)          small things only, keeps food longest
//   hewn log chest (Basic Furniture)    takes large tools and weapons
//   storage pit (Primitive Construction) biggest, fixed in the ground, cool
//   zeer pot (Pottery)                  kept wet, cools food by evaporation
// Every one has Dump Out, which tips its contents onto the floor.
// Sprites: icons/obj/stone_age_storage.dmi, drawn by
// tests/sprites/create_stone_age_storage.py. See docs/stone-age-storage.md.

#define STONE_STORAGE_ICON 'icons/obj/stone_age_storage.dmi'

/obj/structure/storage_container
	name = "storage container"
	desc = "Something to keep things in."
	icon = STONE_STORAGE_ICON
	icon_state = "basket"
	density = TRUE
	anchored = FALSE
	opacity = FALSE
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = FALSE
	var/base_state = "basket"
	var/slots = 7
	var/max_item_size = ITEM_SIZE_NORMAL
	var/max_space = 14
	// Added to stored food's decay clock each minute: 300 is any container,
	// 600 is the floor, lower keeps food longer (reagent_containers/food.dm).
	var/food_decay_step = 300
	var/dump_time = 10 // deciseconds to tip everything out
	var/list/hold_only = null // item types it takes, null for anything that fits
	var/tmp/obj/item/weapon/storage/internal/storage

// The one lock hook: the shared lock system (door locks thread) fills this in.
// Opening the window, putting in and Dump Out all ask it first.
/obj/structure/storage_container/proc/storage_access_allowed(mob/user)
	return lock_hand_access(src, user)

/obj/structure/storage_container/persistence_runtime_var(key)
	return key == "storage" || ..()

/obj/structure/storage_container/New()
	..()
	ensure_storage()
	if (mapped_lock)
		host_apply_mapped_lock(src)
	update_icon()

/obj/structure/storage_container/after_load()
	..()
	ensure_storage()
	update_icon()

// A load replaces the constructor's holder with the saved one: bind whichever
// holder the container now holds, or build an empty one.
/obj/structure/storage_container/proc/ensure_storage()
	if (!storage || QDELETED(storage) || storage.loc != src)
		storage = null
		for (var/obj/item/weapon/storage/internal/candidate in contents)
			if (!QDELETED(candidate))
				storage = candidate
				break
		if (!storage)
			storage = new/obj/item/weapon/storage/internal(src)
	storage.master_item = src
	storage.name = name
	storage.w_class = ITEM_SIZE_GARGANTUAN // so bags and boxes up to the size limit fit
	storage.storage_slots = slots
	storage.max_w_class = max_item_size
	storage.max_storage_space = max(max_space, storage_used_space())
	storage.can_hold = hold_only ? hold_only.Copy() : list()
	return storage

/obj/structure/storage_container/proc/storage_used_space()
	. = 0
	if (!storage)
		return
	for (var/obj/item/I in storage.contents)
		. += I.get_storage_cost()

/obj/structure/storage_container/proc/stored_items()
	ensure_storage()
	return storage.contents.Copy()

/obj/structure/storage_container/update_icon()
	icon_state = (storage && storage.contents.len) ? "[base_state]_full" : base_state

/obj/structure/storage_container/examine(mob/user, distance = -1)
	..()
	lock_examine(src, user)
	to_chat(user, SPAN_NOTICE(rodent_access_text(rodent_access_level())))
	if (!storage)
		return
	var/count = storage.contents.len
	if (!count)
		to_chat(user, SPAN_NOTICE("It is empty."))
	else
		to_chat(user, SPAN_NOTICE("It holds [count] of [slots] things."))

/obj/structure/storage_container/attack_hand(mob/user)
	if (!ishuman(user) || !user.Adjacent(src))
		return
	if (!storage_access_allowed(user))
		return
	ensure_storage()
	storage.open(user)

/obj/structure/storage_container/MouseDrop(obj/over_object)
	ensure_storage()
	if (storage.handle_mousedrop(usr, over_object))
		..(over_object)

/obj/structure/storage_container/attackby(obj/item/W, mob/user)
	if (lock_attackby(src, W, user))
		return
	if (is_tool(W, TOOL_HAMMER) || is_tool(W, TOOL_CROWBAR))
		return ..() // dismantling goes through the usual structure rules
	if (!storage_access_allowed(user))
		return
	ensure_storage()
	storage.attackby(W, user)
	update_icon()

/obj/structure/storage_container/internal_storage_accepts(obj/item/W, stop_messages = FALSE)
	if (W.w_class > max_item_size)
		if (!stop_messages)
			to_chat(usr, SPAN_WARNING("\The [W] is too big for \the [src]."))
		return FALSE
	return TRUE

/obj/structure/storage_container/verb/dump_out()
	set name = "Dump Out"
	set category = null
	set src in view(1)
	var/mob/living/human/H = usr
	if (!istype(H) || H.incapacitated() || !H.Adjacent(src))
		return
	dump_contents_by(H)

/obj/structure/storage_container/AltClick(mob/user)
	if (ishuman(user) && user.Adjacent(src))
		dump_contents_by(user)
		return
	return ..()

/obj/structure/storage_container/proc/dump_contents_by(mob/living/human/H)
	if (!storage_access_allowed(H))
		return FALSE
	ensure_storage()
	if (!storage.contents.len)
		to_chat(H, SPAN_NOTICE("\The [src] is already empty."))
		return FALSE
	H.visible_message(SPAN_NOTICE("[H] starts tipping out \the [src]."), SPAN_NOTICE("You start tipping out \the [src]."))
	if (!do_after(H, dump_time, src))
		return FALSE
	. = empty_out(get_turf(H) == get_turf(src) ? get_turf(src) : get_turf(H))
	H.visible_message(SPAN_NOTICE("[H] tips out \the [src]."), SPAN_NOTICE("You tip out \the [src]."))

// Everything inside onto a turf. Returns how many things came out.
/obj/structure/storage_container/proc/empty_out(turf/T)
	. = 0
	if (!storage || !T)
		return
	storage.close_all()
	for (var/obj/item/I in storage.contents.Copy())
		storage.remove_from_storage(I, T)
		.++
	update_icon()

/obj/structure/storage_container/Destroy()
	if (storage)
		empty_out(get_turf(src))
		qdel(storage)
		storage = null
	return ..()

// Stored food reads its keeping speed from the container that owns its holder.
/proc/storage_food_decay_step(obj/item/weapon/storage/internal/holder)
	var/obj/structure/storage_container/C = holder.master_item
	if (istype(C))
		return C.food_keeping_step()
	return 300

// The keeping speed right now; a container whose keeping changes overrides it.
/obj/structure/storage_container/proc/food_keeping_step()
	return food_decay_step

// The holder's window changes never call back into the owner, so refresh it.
/obj/item/weapon/storage/internal/update_icon()
	..()
	if (istype(master_item, /obj/structure/storage_container))
		var/obj/structure/storage_container/C = master_item
		C.update_icon()

/////////////////////////////////////////////////////////////// woven basket

/obj/structure/storage_container/basket
	name = "woven basket"
	desc = "A wide basket coiled from grass, splints or cord. It is light enough to drag about and holds a good armful of everyday things."
	icon_state = "basket"
	base_state = "basket"
	slots = 7
	max_item_size = ITEM_SIZE_NORMAL
	max_space = 14
	dump_time = 10
	density = FALSE

/////////////////////////////////////////////////////////// clay storage jar

/obj/item/weapon/clay/storage_jar
	name = "unfired clay storage jar"
	desc = "A tall, wide-shouldered jar of wet clay. Fire it in a kiln or oven to make a storage jar."
	icon = STONE_STORAGE_ICON
	icon_state = "storage_jar_unfired"
	w_class = ITEM_SIZE_LARGE
	result = /obj/structure/storage_container/storage_jar

// A jar comes out of the fire too big to sit in the oven: it is set down on
// the first open tile beside it. Returns the placed jar, or null when there is
// nowhere to set it down (the caller then keeps the unfired jar).
/obj/item/weapon/clay/storage_jar/fired_result(atom/where)
	var/turf/origin = get_turf(where)
	if (!origin)
		return null
	var/turf/spot = origin
	for (var/d in cardinal)
		var/turf/T = get_step(origin, d)
		if (storage_jar_spot_ok(T))
			spot = T
			break
	return new result(spot)

/proc/storage_jar_spot_ok(turf/T)
	if (!T || T.density)
		return FALSE
	for (var/atom/movable/A in T)
		if (A.density)
			return FALSE
	return TRUE

/obj/structure/storage_container/storage_jar
	name = "clay storage jar"
	desc = "A tall fired jar with a stopper of wood and hide. It only takes small things like grain, seeds, food and beads, but sealed food keeps twice as long in it, and fire can't touch it."
	icon_state = "storage_jar"
	base_state = "storage_jar"
	slots = 6
	max_item_size = ITEM_SIZE_SMALL
	max_space = 12
	food_decay_step = 150
	dump_time = 15
	flammable = FALSE
	dismantle_wood_fallback = FALSE // fired clay, not wood

/////////////////////////////////////////////////////////////////// zeer pot

// A pot-in-pot cooler: wet sand between two fired pots draws heat out of the
// inner one as the water evaporates. Pour water into it and it keeps food far
// longer until the sand dries out; it works best in dry heat, where the water
// evaporates fastest. Dry, it keeps food like the jar it still is.
#define ZEER_SAMPLE_INTERVAL 100 // deciseconds between ambient samples while wet
#define ZEER_WATER_MAX 60 // units of water the sand holds
#define ZEER_STEP_WET 100 // decay step while the sand is wet
#define ZEER_STEP_ARID 75 // ...in dry climates
#define ZEER_STEP_HUMID 125 // ...in wet climates, where little evaporates

/obj/item/weapon/clay/storage_jar/zeer_pot
	name = "unfired zeer pot"
	desc = "A wide pot of wet clay nested inside a bigger one. Fire it in a kiln or oven to make a zeer pot, a cooler kept wet with sand and water."
	icon_state = "zeer_pot_unfired"
	result = /obj/structure/storage_container/storage_jar/zeer_pot

/obj/structure/storage_container/storage_jar/zeer_pot
	name = "zeer pot"
	desc = "One fired pot nested in another with sand packed between them and a cloth over the top. Pour water into the sand: as it evaporates it keeps the inner pot cool, and food in it lasts far longer than in a plain jar. It works best where the air is hot and dry."
	icon_state = "zeer_pot"
	base_state = "zeer_pot"
	slots = 5
	max_space = 10
	var/water = 0 // units in the sand
	var/tmp/water_tick = null // world.time the water was last brought up to date
	var/tmp/water_sample_rate = 0 // rate that applies until the next sample

/obj/structure/storage_container/storage_jar/zeer_pot/persistence_runtime_var(key)
	return key == "water_tick" || key == "water_sample_rate" || ..()

/obj/structure/storage_container/storage_jar/zeer_pot/after_load()
	..()
	water_tick = null
	water_sample_rate = 0
	if (water > 0)
		processing_objects |= src
	else
		processing_objects -= src

/obj/structure/storage_container/storage_jar/zeer_pot/process_interval(configured_seconds = 2)
	if (QDELETED(src) || water <= 0)
		processing_objects -= src
		return PROCESS_KILL
	if (isnull(water_tick) || world.time - water_tick >= ZEER_SAMPLE_INTERVAL)
		settle_water()
	if (water <= 0)
		return PROCESS_KILL

/obj/structure/storage_container/storage_jar/zeer_pot/update_icon()
	var/full = storage && storage.contents.len
	icon_state = "[base_state][water > 0 ? "_wet" : ""][full ? "_full" : ""]"

// Water lost per minute: none when freezing, fastest in dry heat.
/obj/structure/storage_container/storage_jar/zeer_pot/proc/evaporation_rate()
	var/temp = get_temp(src)
	if (temp <= 0)
		return 0
	var/rate = temp >= 25 ? 0.5 : 0.33
	if (zeer_arid_climate(src))
		rate *= 1.25
	return rate

// Charge elapsed time at the last observed rate, then sample the present
// surroundings. A newly hot or cold tile cannot rewrite the prior interval.
/obj/structure/storage_container/storage_jar/zeer_pot/proc/settle_water()
	if (water <= 0)
		return water
	var/now = world.time
	if (!isnull(water_tick) && water_tick <= now)
		var/minutes = (now - water_tick) / 600
		water = max(0, water - minutes * water_sample_rate)
	if (water <= 0)
		water_tick = null
		water_sample_rate = 0
		processing_objects -= src
		update_icon()
	else
		water_tick = now
		water_sample_rate = evaporation_rate()
	return water

/obj/structure/storage_container/storage_jar/zeer_pot/food_keeping_step()
	if (settle_water() <= 0)
		return food_decay_step
	if (zeer_arid_climate(src))
		return ZEER_STEP_ARID
	if (zeer_humid_climate(src))
		return ZEER_STEP_HUMID
	return ZEER_STEP_WET

/proc/zeer_arid_climate(atom/A)
	var/area/AR = get_area(A)
	return AR && (AR.climate in list("desert", "semiarid", "savanna"))

/proc/zeer_humid_climate(atom/A)
	var/area/AR = get_area(A)
	return AR && (AR.climate in list("jungle", "sea"))

/obj/structure/storage_container/storage_jar/zeer_pot/attackby(obj/item/W, mob/user)
	var/obj/item/weapon/reagent_containers/RC = W
	if (istype(RC) && RC.reagents && RC.is_open_container() && RC.reagents.has_reagent("water"))
		if (pour_water(RC, user))
			return
	return ..()

/obj/structure/storage_container/storage_jar/zeer_pot/proc/pour_water(obj/item/weapon/reagent_containers/RC, mob/user)
	settle_water()
	var/room = ZEER_WATER_MAX - water
	if (room < 1)
		return FALSE // soaked through: a full vessel goes in like anything else
	var/amount = min(room, RC.reagents.get_reagent_amount("water"))
	if (amount <= 0)
		return FALSE
	RC.reagents.remove_reagent("water", amount)
	water = min(ZEER_WATER_MAX, water + amount)
	water_tick = world.time
	water_sample_rate = evaporation_rate()
	processing_objects |= src
	update_icon()
	user.visible_message(SPAN_NOTICE("[user] pours water into the sand of \the [src]."), SPAN_NOTICE("You soak the sand of \the [src] with [amount] units of water."))
	return TRUE

/obj/structure/storage_container/storage_jar/zeer_pot/examine(mob/user, distance = -1)
	..()
	settle_water()
	if (water <= 0)
		to_chat(user, SPAN_WARNING("The sand is dry. Pour water into it to cool the pot."))
		return
	var/rate = evaporation_rate()
	if (rate <= 0)
		to_chat(user, SPAN_NOTICE("The sand is damp, and nothing evaporates in this cold."))
		return
	to_chat(user, SPAN_NOTICE("The sand is wet and will stay damp for about [round(water / rate)] more minutes."))

#undef ZEER_SAMPLE_INTERVAL
#undef ZEER_WATER_MAX
#undef ZEER_STEP_WET
#undef ZEER_STEP_ARID
#undef ZEER_STEP_HUMID

///////////////////////////////////////////////////////////// hewn log chest

/obj/structure/storage_container/log_chest
	name = "hewn log chest"
	desc = "A log split and hollowed out with stone tools, with a hide lid tied over the top. It is heavy, but it takes tools, weapons and bundles too long for a basket."
	icon_state = "log_chest"
	base_state = "log_chest"
	slots = 10
	max_item_size = ITEM_SIZE_LARGE
	max_space = 24
	dump_time = 20

///////////////////////////////////////////////////////////////// storage pit

#define STORAGE_PIT_DIG_TIME_SHOVEL 80
#define STORAGE_PIT_DIG_TIME_STICK 160

/obj/item/weapon/storage_pit_lining
	name = "pit lining"
	desc = "A bundle of dry grass or hide to line a storage pit. Hold a shovel or digging stick in your other hand and use this on the ground next to you to dig and line the pit."
	icon = STONE_STORAGE_ICON
	icon_state = "pit_lining"
	w_class = ITEM_SIZE_NORMAL
	flammable = TRUE
	value = 1

/proc/storage_pit_ground_ok(turf/T)
	if (!istype(T, /turf/floor) || T.density)
		return FALSE
	return istype(T, /turf/floor/grass) || istype(T, /turf/floor/dirt) || istype(T, /turf/floor/beach/sand) || istype(T, /turf/floor/winter)

/proc/storage_pit_dig_time(obj/item/I)
	if (istype(I, /obj/item/weapon/plough/digging_stick))
		return STORAGE_PIT_DIG_TIME_STICK
	if (is_tool(I, TOOL_SHOVEL))
		return STORAGE_PIT_DIG_TIME_SHOVEL
	return 0

/obj/item/weapon/storage_pit_lining/afterattack(atom/target, mob/user, proximity_flag, params)
	if (!proximity_flag || !ishuman(user))
		return ..()
	var/turf/T = get_turf(target)
	if (!T || !user.Adjacent(T) || T == get_turf(user))
		return ..()
	if (!storage_pit_ground_ok(T))
		to_chat(user, SPAN_WARNING("A storage pit has to be dug in bare ground: grass, dirt, sand or snow."))
		return TRUE
	if (locate(/obj/structure/storage_container/storage_pit) in T)
		to_chat(user, SPAN_WARNING("There is already a storage pit there."))
		return TRUE
	var/obj/item/tool = user.get_inactive_hand()
	var/delay = storage_pit_dig_time(tool)
	if (delay)
		delay = work_delay(user, STORAGE_PIT_DIG_TIME_SHOVEL, WORK_DIG, tool)
	if (!delay)
		to_chat(user, SPAN_WARNING("Hold a shovel or a digging stick in your other hand to dig the pit."))
		return TRUE
	user.visible_message(SPAN_NOTICE("[user] starts digging a storage pit."), SPAN_NOTICE("You start digging a storage pit with \the [tool]."))
	if (!do_after(user, delay, T) || QDELETED(src) || loc != user || user.get_inactive_hand() != tool || !storage_pit_ground_ok(T) || (locate(/obj/structure/storage_container/storage_pit) in T))
		return TRUE
	new /obj/structure/storage_container/storage_pit(T)
	user.visible_message(SPAN_NOTICE("[user] digs and lines a storage pit."), SPAN_NOTICE("You dig the pit and line it."))
	qdel(src)
	return TRUE

/obj/structure/storage_container/storage_pit
	name = "storage pit"
	desc = "A lined pit dug into the ground and covered over. It holds the most of any early store, and the cool earth keeps food a little longer, but it can't be moved."
	icon_state = "storage_pit"
	base_state = "storage_pit"
	slots = 14
	max_item_size = ITEM_SIZE_NORMAL
	max_space = 28
	food_decay_step = 200
	dump_time = 20
	density = FALSE
	anchored = TRUE
	not_movable = TRUE
	layer = TURF_LAYER + 0.1

// Filling the pit back in with a shovel removes it; what was inside comes out.
/obj/structure/storage_container/storage_pit/attackby(obj/item/W, mob/user)
	if (is_tool(W, TOOL_SHOVEL))
		user.visible_message(SPAN_NOTICE("[user] starts filling in \the [src]."), SPAN_NOTICE("You start filling in \the [src]."))
		if (do_after(user, STORAGE_PIT_DIG_TIME_SHOVEL / 2, src) && !QDELETED(src))
			qdel(src)
		return
	return ..()

#undef STORAGE_PIT_DIG_TIME_SHOVEL
#undef STORAGE_PIT_DIG_TIME_STICK

#undef STONE_STORAGE_ICON
