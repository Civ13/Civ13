// Servicing (docs/trains.md#servicing). A train wears as it runs, slowly,
// and is kept running by a little regular work.
//
// - Axle boxes: every car and engine runs on the oil in its axle boxes
//   (`axle_oil`, in tiles). Run dry, a box runs hot: it smokes and drags.
//   Run hot for long enough, the axle seizes and holds the car like a brake
//   until the bearing is changed.
// - The fire: a steam engine's fire fills with clinker as it burns. A dirty
//   fire steams poorly until it is cleaned with a fire rake over an ash pit.
//
// Wear is counted where the train is already added up: refresh_consist()
// for a driven train and roll_refresh() for one that rolls free, every few
// tiles. Nothing here ticks by itself.

#define TRAIN_OIL_FULL 600 // tiles one oiling lasts
#define TRAIN_OIL_LOW 100 // tiles left when the boxes are said to run dry
#define TRAIN_OIL_UNITS 5 // units of oil a car takes
#define TRAIN_HOT_SEIZE 150 // tiles run hot before the axle seizes
#define TRAIN_HOT_WARN 30 // a hot box shows itself this often, in tiles
#define TRAIN_OIL_TIME 30
#define TRAIN_BEARING_TIME 150
#define TRAIN_CLINKER_FIRES 4 // fireboxes of fuel that fill the fire with clinker
#define TRAIN_CLINKER_CLEAN 40 // percent of clinker a fire carries without harm
#define TRAIN_CLINKER_TIME 80
#define TRAIN_ASH_PIT_MAX 10 // fires an ash pit takes before it is dug out

/obj/structure/trains
	var/axle_oil = TRAIN_OIL_FULL
	var/axle_seized = FALSE

/obj/structure/trains/locomotive
	var/tmp/consist_hot = 0 // weight of the cars with a hot box

/obj/structure/trains/locomotive/coal
	var/clinker = 0 // percent

// Oils that will do for an axle box.
var/global/list/train_axle_oils = list("fat_oil", "olive_oil", "cornoil", "lard", "petroleum", "lube")

// The sections that are serviced as one: the whole of a car or engine.
/obj/structure/trains/proc/service_sections()
	return list(src)

/obj/structure/trains/platform/service_sections()
	var/obj/structure/trains/locomotive/E = car_engine()
	if (E)
		return E.service_sections()
	return car_segments()

/obj/structure/trains/locomotive/service_sections()
	var/list/sections = list(src)
	if (body_kind && car_id)
		for (var/obj/structure/trains/platform/P in range(body_length(), src))
			if (P.car_id == car_id)
				sections += P
	return sections

// The section that speaks for its car, so a long car is not heard eight times.
/obj/structure/trains/proc/axle_speaker()
	return TRUE

/obj/structure/trains/platform/axle_speaker()
	return seg_index == 1

// "seized", "hot", "dry" or "oiled".
/obj/structure/trains/proc/axle_state()
	if (axle_seized)
		return "seized"
	if (axle_oil <= 0)
		return "hot"
	if (axle_oil < TRAIN_OIL_LOW)
		return "dry"
	return "oiled"

// The car has run this many tiles.
/obj/structure/trains/proc/wear_axles(tiles)
	if (tiles <= 0 || axle_seized)
		return
	var/before = axle_oil
	axle_oil -= tiles
	if (axle_oil > 0)
		return
	if (axle_oil <= -TRAIN_HOT_SEIZE)
		axle_seized = TRUE
		if (axle_speaker() && isturf(loc))
			visible_message(SPAN_DANGER("With a shriek of metal an axle of \the [src] seizes!"))
			playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
		return
	if (axle_speaker() && isturf(loc) && (before > 0 || round(-axle_oil / TRAIN_HOT_WARN) != round(-before / TRAIN_HOT_WARN)))
		visible_message(SPAN_WARNING("Smoke curls from a hot axle box on \the [src]."))

/obj/structure/trains/proc/axle_text()
	switch (axle_state())
		if ("seized")
			return "An axle has seized. The bearing has to be changed with a wrench before the car will roll freely."
		if ("hot")
			return "An axle box is running hot. It needs oil."
		if ("dry")
			return "Its axle boxes are running dry."
	return null

/obj/structure/trains/examine(mob/user)
	..()
	var/text = axle_text()
	if (text)
		to_chat(user, SPAN_WARNING(text))

/obj/structure/trains/proc/oil_axles()
	for (var/obj/structure/trains/S in service_sections())
		S.axle_oil = TRAIN_OIL_FULL

/obj/structure/trains/proc/change_bearing()
	for (var/obj/structure/trains/S in service_sections())
		S.axle_seized = FALSE
		S.axle_oil = 0
	train_weights_changed()

// The engine that drives the train, and a train that rolls free, add the
// train up again at once.
/obj/structure/trains/proc/train_weights_changed()
	var/obj/structure/trains/head = train_head()
	head.roll_steps = 0
	for (var/obj/structure/trains/locomotive/L in train_consist_list(head))
		if (L.driving)
			L.refresh_consist()

// The oil in an open vessel that will do, or null.
/proc/train_oil_in(obj/item/W)
	var/obj/item/weapon/reagent_containers/C = W
	if (!istype(C) || !C.reagents || !C.is_open_container())
		return null
	for (var/id in train_axle_oils)
		if (C.reagents.get_reagent_amount(id) >= TRAIN_OIL_UNITS)
			return id
	return null

// Servicing by hand: oil for the axle boxes, a wrench for a seized axle.
// TRUE when W was used for it.
/obj/structure/trains/proc/service_use(obj/item/W, mob/living/user)
	if (!istype(user) || !W || !isturf(loc))
		return FALSE
	var/oil = train_oil_in(W)
	if (oil)
		if (train_rolling())
			to_chat(user, SPAN_WARNING("The train is moving."))
			return TRUE
		if (axle_seized)
			to_chat(user, SPAN_WARNING(axle_text()))
			return TRUE
		if (axle_oil >= TRAIN_OIL_FULL - 10)
			to_chat(user, "The axle boxes of \the [src] are full of oil.")
			return TRUE
		user.visible_message("[user] starts oiling the axle boxes of \the [src]...", "You start going round the axle boxes of \the [src] with the oil...")
		if (!do_after(user, TRAIN_OIL_TIME, src) || user.get_active_hand() != W || train_rolling() || axle_seized || train_oil_in(W) != oil)
			return TRUE
		W.reagents.remove_reagent(oil, TRAIN_OIL_UNITS)
		oil_axles()
		user.visible_message("[user] oils the axle boxes of \the [src].", "You oil the axle boxes of \the [src]. They are good for a long run.")
		return TRUE
	if (axle_seized && is_tool(W, TOOL_WRENCH))
		if (train_rolling())
			to_chat(user, SPAN_WARNING("The train is moving."))
			return TRUE
		user.visible_message("[user] starts changing a seized bearing on \the [src]...", "You jack up the axle box and start changing the burnt bearing...")
		if (!do_after(user, TRAIN_BEARING_TIME, src) || !axle_seized || train_rolling())
			return TRUE
		change_bearing()
		playsound(loc, 'sound/effects/lever.ogg', 100, TRUE)
		user.visible_message("[user] changes a bearing on \the [src].", "You fit the new bearing. Oil the axle boxes before the car runs.")
		return TRUE
	return FALSE

/obj/structure/trains/platform/service_use(obj/item/W, mob/living/user)
	var/obj/structure/trains/locomotive/E = car_engine()
	if (E)
		return E.service_use(W, user)
	return ..()

/obj/structure/trains/attackby(obj/item/W as obj, mob/user as mob)
	if (service_use(W, user))
		return TRUE
	return ..()

/////////////////////////////////////////////////////////////////////////////
// The fire

// How well a dirty fire burns: all of it up to TRAIN_CLINKER_CLEAN, half
// when it is choked.
/obj/structure/trains/locomotive/coal/proc/clinker_factor()
	if (clinker <= TRAIN_CLINKER_CLEAN)
		return 1
	return 1 - 0.5 * (min(100, clinker) - TRAIN_CLINKER_CLEAN) / (100 - TRAIN_CLINKER_CLEAN)

// Every tile of work leaves its clinker on the bars (steam_use()).
/obj/structure/trains/locomotive/coal/proc/make_clinker(notch, weight, tiles)
	if (on && max_fuel && tiles > 0)
		clinker = min(100, clinker + fuel_per_tile(notch, weight) * tiles * 100 / (TRAIN_CLINKER_FIRES * max_fuel))

/obj/structure/trains/locomotive/coal/proc/clinker_text()
	if (clinker >= 80)
		return " The fire is choked with clinker."
	if (clinker > TRAIN_CLINKER_CLEAN)
		return " The fire is dirty with clinker."
	return ""

// The ash pit the engine stands over, if any.
/obj/structure/trains/locomotive/coal/proc/ash_pit()
	for (var/obj/structure/trains/S in service_sections())
		var/obj/structure/rail_ash_pit/pit = locate() in S.loc
		if (pit)
			return pit
	return null

// Cleaning the fire: the clinker is broken up with the rake and dropped
// through the bars into the pit. TRUE when it was done.
/obj/structure/trains/locomotive/coal/proc/clean_fire(mob/living/user)
	if (!at_firebox(user))
		to_chat(user, "Stand at the firebox door in the middle of the cab to clean the fire.")
		return FALSE
	if (train_rolling())
		to_chat(user, SPAN_WARNING("Stop the train first."))
		return FALSE
	if (clinker < 5)
		to_chat(user, "The fire is clean.")
		return FALSE
	var/obj/structure/rail_ash_pit/pit = ash_pit()
	if (!pit)
		to_chat(user, SPAN_WARNING("The clinker has to go somewhere. Stand the engine over an ash pit."))
		return FALSE
	if (pit.ash >= TRAIN_ASH_PIT_MAX)
		to_chat(user, SPAN_WARNING("\The [pit] is full. Dig it out with a shovel."))
		return FALSE
	user.visible_message("[user] starts raking out \the [src]'s fire...", "You break up the clinker and start raking it down through the bars...")
	if (!do_after(user, TRAIN_CLINKER_TIME, src) || train_rolling() || QDELETED(pit) || ash_pit() != pit || pit.ash >= TRAIN_ASH_PIT_MAX)
		return FALSE
	clean_fire_into(pit)
	user.visible_message("[user] cleans \the [src]'s fire.", "You clean the fire. Glowing clinker drops into \the [pit].")
	return TRUE

/obj/structure/trains/locomotive/coal/proc/clean_fire_into(obj/structure/rail_ash_pit/pit)
	boiler_tick()
	clinker = 0
	// Some of the fire goes down with it.
	fuel = round(fuel * 0.8)
	if (pit)
		pit.ash = min(TRAIN_ASH_PIT_MAX, pit.ash + 1)
		pit.update_icon()

/obj/structure/trains/locomotive/coal/service_use(obj/item/W, mob/living/user)
	if (istype(W, /obj/item/train_fire_rake))
		clean_fire(user)
		return TRUE
	return ..()

/obj/item/train_fire_rake
	name = "fire rake"
	desc = "A long iron rake for breaking up clinker and cleaning a locomotive's fire. Use it at the firebox door while the engine stands over an ash pit."
	icon = 'icons/obj/vehicles/train_platforms.dmi'
	icon_state = "fire_rake"
	w_class = 4
	force = 10
	throwforce = 6

// A pit between the rails for an engine's ashes.
/obj/structure/rail_ash_pit
	name = "ash pit"
	desc = "A brick-lined pit between the rails. An engine stands over it to have its fire cleaned."
	icon = 'icons/obj/vehicles/train_platforms.dmi'
	icon_state = "ash_pit"
	anchored = TRUE
	density = FALSE
	flammable = FALSE
	layer = 2.6
	var/ash = 0 // fires cleaned into it

/obj/structure/rail_ash_pit/on_runtime_spawn()
	..()
	update_icon()

/obj/structure/rail_ash_pit/after_load()
	..()
	update_icon()

// It lies along the track it is dug under.
/obj/structure/rail_ash_pit/update_icon()
	if (isturf(loc))
		for (var/obj/structure/rails/R in loc)
			if (R.dir in cardinal)
				dir = R.dir
			break
	icon_state = ash >= TRAIN_ASH_PIT_MAX ? "ash_pit_full" : (ash > 0 ? "ash_pit_ash" : "ash_pit")

/obj/structure/rail_ash_pit/examine(mob/user)
	..()
	if (ash >= TRAIN_ASH_PIT_MAX)
		to_chat(user, SPAN_WARNING("It is full of ash and clinker. Dig it out with a shovel."))
	else if (ash > 0)
		to_chat(user, "There is ash in it. A shovel digs it out.")

// Digs the pit out. Returns the ash that came out of it.
/obj/structure/rail_ash_pit/proc/dig_out(turf/where)
	if (ash <= 0)
		return 0
	var/out = min(3, ash)
	for (var/i in 1 to out)
		new /obj/item/wood_ash(where || get_turf(src))
	ash = 0
	update_icon()
	return out

/obj/structure/rail_ash_pit/attackby(obj/item/W as obj, mob/user as mob)
	if (is_tool(W, TOOL_SHOVEL))
		if (ash <= 0)
			to_chat(user, "\The [src] is empty.")
			return
		for (var/obj/structure/trains/T in loc)
			to_chat(user, SPAN_WARNING("\The [T] stands over it."))
			return
		user.visible_message("[user] starts digging out \the [src]...", "You start digging the ash out of \the [src]...")
		if (!do_after(user, 50, src) || ash <= 0)
			return
		dig_out(get_turf(user))
		to_chat(user, "You dig out \the [src].")
		return
	return ..()

#undef TRAIN_OIL_FULL
#undef TRAIN_OIL_LOW
#undef TRAIN_OIL_UNITS
#undef TRAIN_HOT_SEIZE
#undef TRAIN_HOT_WARN
#undef TRAIN_OIL_TIME
#undef TRAIN_BEARING_TIME
#undef TRAIN_CLINKER_FIRES
#undef TRAIN_CLINKER_CLEAN
#undef TRAIN_CLINKER_TIME
#undef TRAIN_ASH_PIT_MAX
