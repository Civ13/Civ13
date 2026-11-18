// Servicing (docs/trains.md#servicing). A train wears as it runs, slowly,
// and is kept running by a little regular work.
//
// - Axle boxes: every car and engine runs on the oil in its axle boxes
//   (`axle_oil`, in tiles). Run dry, a box runs hot: it smokes and drags.
//   Run hot for long enough, the axle seizes and holds the car like a brake
//   until the bearing is changed.
// - The fire: a steam engine's fire fills with clinker as it burns. A dirty
//   fire steams poorly until it is cleaned with a fire rake over an ash pit.
// - Brake shoes (`brake_shoes`, in tiles run with the brake on) wear thin;
//   worn out, the brake barely holds until a new set is fitted.
// - The boiler: the water a steam engine boils leaves scale (`scale`). A
//   scaled boiler steams poorly until it is washed out, cold, beside a water
//   crane or tower.
// - The engine itself (`mileage`): after a long distance it pulls less until
//   it is overhauled in an engine shed, the bay of a rail warehouse.
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
#define TRAIN_SHOES_FULL 300 // tiles a set of brake shoes lasts with the brake on
#define TRAIN_SHOES_THIN 50
#define TRAIN_SHOES_WORN 0.3 // share of its weight a car on worn-out shoes still holds
#define TRAIN_SHOES_TIME 100
#define TRAIN_SCALE_TANKS 12 // tanks of water boiled that scale a boiler up
#define TRAIN_SCALE_CLEAN 40 // percent of scale a boiler carries without harm
#define TRAIN_WASHOUT_WATER 300
#define TRAIN_WASHOUT_PRESSURE 25 // the boiler has to be this cold
#define TRAIN_WASHOUT_TIME 300
#define TRAIN_OVERHAUL_DUE 5000 // tiles an engine works between overhauls
#define TRAIN_OVERHAUL_PARTS 10 // iron or steel for the new parts
#define TRAIN_OVERHAUL_TIME 600

/obj/structure/trains
	var/axle_oil = TRAIN_OIL_FULL
	var/axle_seized = FALSE
	var/brake_shoes = TRAIN_SHOES_FULL

/obj/structure/trains/locomotive
	var/tmp/consist_hot = 0 // weight of the cars with a hot box
	var/mileage = 0 // tiles worked since the last overhaul

/obj/structure/trains/locomotive/coal
	var/clinker = 0 // percent
	var/scale = 0 // percent

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
	for (var/text in list(axle_text(), shoe_text()))
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
	// Rerailing (train_derail.dm).
	if (istype(W, /obj/item/train_jack))
		return jack_use(W, user)
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
	if (istype(W, /obj/item/train_brake_shoes))
		if (train_rolling())
			to_chat(user, SPAN_WARNING("The train is moving."))
			return TRUE
		if (brake_shoes >= TRAIN_SHOES_FULL - 10)
			to_chat(user, "The brake shoes of \the [src] are sound.")
			return TRUE
		if (handbrake)
			to_chat(user, SPAN_WARNING("Let the handbrake off first."))
			return TRUE
		user.visible_message("[user] starts fitting new brake shoes to \the [src]...", "You knock out the cotters and start changing the brake shoes of \the [src]...")
		if (!do_after(user, TRAIN_SHOES_TIME, src) || user.get_active_hand() != W || train_rolling() || handbrake)
			return TRUE
		user.drop_from_inventory(W)
		qdel(W)
		fit_shoes()
		playsound(loc, 'sound/effects/lever.ogg', 100, TRUE)
		user.visible_message("[user] fits new brake shoes to \the [src].", "You fit the new brake shoes.")
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
// Brake shoes

// The car has run this many tiles with its brake on.
/obj/structure/trains/proc/wear_shoes(tiles)
	if (tiles <= 0 || brake_shoes <= 0)
		return
	brake_shoes = max(0, brake_shoes - tiles)
	if (brake_shoes <= 0 && axle_speaker() && isturf(loc))
		visible_message(SPAN_WARNING("The brake of \the [src] grinds metal on metal: its shoes are worn out."))

// The share of its weight this car's brake holds.
/obj/structure/trains/proc/brake_hold()
	return (brake_shoes > 0 || axle_seized) ? 1 : TRAIN_SHOES_WORN

/obj/structure/trains/proc/shoe_text()
	if (brake_shoes <= 0)
		return "Its brake shoes are worn out and the brake barely holds. It needs a new set."
	if (brake_shoes < TRAIN_SHOES_THIN)
		return "Its brake shoes are worn thin."
	return null

/obj/structure/trains/proc/fit_shoes()
	for (var/obj/structure/trains/S in service_sections())
		S.brake_shoes = TRAIN_SHOES_FULL
	train_weights_changed()

/obj/item/train_brake_shoes
	name = "set of brake shoes"
	desc = "Cast iron brake shoes for a railway car or engine. Use them on a standing car whose shoes are worn."
	icon = 'icons/obj/vehicles/train_platforms.dmi'
	icon_state = "brake_shoes"
	w_class = 3
	force = 8
	throwforce = 6

/////////////////////////////////////////////////////////////////////////////
// Overhaul

// The engine has worked this many tiles.
/obj/structure/trains/locomotive/proc/wear_engine(tiles)
	if (tiles <= 0)
		return
	var/before = mileage
	mileage += tiles
	if (before < TRAIN_OVERHAUL_DUE && mileage >= TRAIN_OVERHAUL_DUE && isturf(loc))
		visible_message(SPAN_WARNING("\The [src] knocks and blows at every stroke. It is due for an overhaul."))

// The share of its pull a worn engine still has: all of it until an overhaul
// is due, falling to seven tenths at twice the distance.
/obj/structure/trains/locomotive/proc/wear_factor()
	if (mileage <= TRAIN_OVERHAUL_DUE)
		return 1
	return max(0.7, 1 - 0.3 * (mileage - TRAIN_OVERHAUL_DUE) / TRAIN_OVERHAUL_DUE)

/obj/structure/trains/locomotive/proc/overhaul_text()
	if (mileage >= TRAIN_OVERHAUL_DUE)
		return "It is worn and pulls less than it should. It is due for an overhaul in an engine shed."
	return null

// The rail warehouse whose bay the engine stands in: its shed.
/obj/structure/trains/locomotive/proc/engine_shed()
	var/list/sections = service_sections()
	for (var/obj/structure/rail_warehouse/W in range(14, src))
		var/list/bay = W.bay()
		for (var/obj/structure/trains/S in sections)
			if (S.loc in bay)
				return W
	return null

/proc/train_overhaul_parts(obj/item/stack/material/M)
	return (istype(M, /obj/item/stack/material/iron) || istype(M, /obj/item/stack/material/steel)) && M.amount >= TRAIN_OVERHAUL_PARTS

/obj/structure/trains/locomotive/proc/overhaul()
	mileage = 0
	train_weights_changed()

// A fitter with a wrench, and iron or steel for the parts in the other hand.
/obj/structure/trains/locomotive/proc/overhaul_by(mob/living/user)
	if (train_rolling())
		to_chat(user, SPAN_WARNING("The train is moving."))
		return FALSE
	if (on)
		to_chat(user, SPAN_WARNING("[stop_text] first."))
		return FALSE
	if (!engine_shed())
		to_chat(user, SPAN_WARNING("An overhaul is shed work. Stand \the [src] in the bay of a rail warehouse."))
		return FALSE
	var/obj/item/stack/material/parts = user.get_inactive_hand()
	if (!train_overhaul_parts(parts))
		to_chat(user, SPAN_WARNING("The new parts take [TRAIN_OVERHAUL_PARTS] iron or steel. Hold it in your other hand."))
		return FALSE
	user.visible_message("[user] starts stripping down \the [src] for an overhaul...", "You start on the overhaul: rods off, valves out, bearings and rings to be made new...")
	if (!do_after(user, TRAIN_OVERHAUL_TIME, src) || train_rolling() || on || !engine_shed() || user.get_inactive_hand() != parts || !train_overhaul_parts(parts))
		return FALSE
	parts.use(TRAIN_OVERHAUL_PARTS)
	overhaul()
	playsound(loc, 'sound/effects/lever.ogg', 100, TRUE)
	user.visible_message("[user] finishes the overhaul of \the [src].", "You put \the [src] back together. It runs like new.")
	return TRUE

/obj/structure/trains/locomotive/service_use(obj/item/W, mob/living/user)
	if (istype(user) && !axle_seized && mileage >= TRAIN_OVERHAUL_DUE / 2 && is_tool(W, TOOL_WRENCH))
		overhaul_by(user)
		return TRUE
	return ..()

/////////////////////////////////////////////////////////////////////////////
// The boiler

// How well a scaled boiler takes the fire's heat: all of it up to
// TRAIN_SCALE_CLEAN, six tenths when it is thick with scale.
/obj/structure/trains/locomotive/coal/proc/scale_factor()
	if (scale <= TRAIN_SCALE_CLEAN)
		return 1
	return 1 - 0.4 * (min(100, scale) - TRAIN_SCALE_CLEAN) / (100 - TRAIN_SCALE_CLEAN)

// The water that boils off leaves its scale behind (steam_use()).
/obj/structure/trains/locomotive/coal/proc/make_scale(boiled)
	if (max_water && boiled > 0)
		scale = min(100, scale + boiled * 100 / (TRAIN_SCALE_TANKS * max_water))

/obj/structure/trains/locomotive/coal/proc/scale_text()
	if (scale >= 80)
		return " The boiler is thick with scale."
	if (scale > TRAIN_SCALE_CLEAN)
		return " The boiler is scaling up."
	return ""

// Worth the work from half the scale a boiler carries without harm.
/obj/structure/trains/locomotive/coal/proc/washout_due()
	return scale > TRAIN_SCALE_CLEAN / 2

// The water tower whose hose reaches the engine and holds enough for a
// washout, or null.
/obj/structure/trains/locomotive/coal/proc/washout_water()
	for (var/obj/structure/trains/S in service_sections())
		for (var/obj/structure/rail_water/W in range(3, S))
			if (!(src in W.takers()))
				continue
			var/obj/structure/rail_water/tower/T = W.source()
			if (T && T.water >= TRAIN_WASHOUT_WATER)
				return T
	return null

// The plugs come out, the scale is hosed out and the boiler is filled again.
/obj/structure/trains/locomotive/coal/proc/wash_out(obj/structure/rail_water/tower/T)
	if (T)
		T.water = max(0, T.water - TRAIN_WASHOUT_WATER)
	scale = 0
	pressure = 0
	boiler_water = max_boiler

/obj/structure/trains/locomotive/coal/proc/wash_out_by(mob/living/user)
	boiler_tick()
	if (train_rolling())
		to_chat(user, SPAN_WARNING("Stop the train first."))
		return FALSE
	if (on)
		to_chat(user, SPAN_WARNING("Drop the fire first. A boiler is washed out cold."))
		return FALSE
	if (pressure > TRAIN_WASHOUT_PRESSURE)
		to_chat(user, SPAN_WARNING("The boiler is still too hot at [round(pressure)]% pressure. Let it cool below [TRAIN_WASHOUT_PRESSURE]%."))
		return FALSE
	var/obj/structure/rail_water/tower/T = washout_water()
	if (!T)
		to_chat(user, SPAN_WARNING("A washout takes a hose and [TRAIN_WASHOUT_WATER] units of water. Stand \the [src] beside a water crane or water tower that holds as much."))
		return FALSE
	user.visible_message("[user] starts washing out \the [src]'s boiler...", "You take out the washout plugs and start hosing the scale out of the boiler...")
	if (!do_after(user, TRAIN_WASHOUT_TIME, src) || train_rolling() || on || washout_water() != T)
		return FALSE
	wash_out(T)
	playsound(loc, 'sound/effects/watersplash.ogg', 80, TRUE)
	user.visible_message("[user] washes out \the [src]'s boiler.", "Mud and scale run out on the ground. You put the plugs back and fill the boiler again.")
	return TRUE

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
	var/along = isturf(loc) ? rail_dir_at(loc) : null
	if (along)
		dir = along
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
#undef TRAIN_SHOES_FULL
#undef TRAIN_SHOES_THIN
#undef TRAIN_SHOES_WORN
#undef TRAIN_SHOES_TIME
#undef TRAIN_SCALE_TANKS
#undef TRAIN_SCALE_CLEAN
#undef TRAIN_WASHOUT_WATER
#undef TRAIN_WASHOUT_PRESSURE
#undef TRAIN_WASHOUT_TIME
#undef TRAIN_OVERHAUL_DUE
#undef TRAIN_OVERHAUL_PARTS
#undef TRAIN_OVERHAUL_TIME
