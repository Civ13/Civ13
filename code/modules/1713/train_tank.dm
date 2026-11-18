// The tank car (docs/trains.md#tank-car). One riveted tank on a bogie frame:
// water for a dry water stop, oil, fuel, milk or drink by the trainload.
//
// - The liquid is a kind and a number on the car's first section
//   (`tank_reagent`, `tank_amount`), not a reagent holder: a tank carries one
//   liquid at a time, the way a tender carries its water.
// - Open vessels pour in at the tank and draw off again, at the shell or at
//   the valve on the end platform.
// - The valve runs water into a water tower beside the track and fuel into a
//   heavy diesel locomotive; a water tower or crane fills a tank car the way
//   it fills a tender.

#define TANK_PER_WEIGHT 600 // units of liquid that weigh as much as one section of a car
#define TANK_VALVE_TIME 40
#define TANK_VALVE_REACH 3

/obj/structure/trains/platform
	var/tank_reagent = null // the id of the liquid in the tank
	var/tank_amount = 0 // units, on the car's first section

// Units of liquid this kind of car carries; 0 for a car with no tank.
/obj/structure/trains/platform/proc/tank_max()
	var/list/L = layout()
	return (L && L["tank"]) ? L["tank"] : 0

// The section that holds the car's liquid, or null when it has no tank.
/obj/structure/trains/platform/proc/tank_store()
	if (!tank_max())
		return null
	if (seg_index == 1)
		return src
	for (var/obj/structure/trains/platform/P in car_segments())
		if (P.seg_index == 1)
			return P
	return null

// The liquid's weight, counted once for the car.
/obj/structure/trains/platform/proc/tank_weight()
	return (seg_index == 1 && tank_amount > 0) ? tank_amount / TANK_PER_WEIGHT : 0

/proc/train_tank_name(id)
	var/datum/reagent/R = id ? chemical_reagents_list[id] : null
	return R ? lowertext(R.name) : "liquid"

// The one liquid an open vessel holds, as a reagent id; null for an empty or
// closed vessel, a mixture, or anything that does not pour.
/proc/train_tank_liquid(obj/item/W)
	if (!istype(W, /obj/item/weapon/reagent_containers) || !W.reagents || !W.is_open_container())
		return null
	if (W.reagents.reagent_list.len != 1)
		return null
	var/datum/reagent/R = W.reagents.reagent_list[1]
	if (!istype(R) || R.reagent_state != LIQUID || R.volume <= 0)
		return null
	return R.id

// TRUE when the tank can take more of this liquid.
/obj/structure/trains/platform/proc/tank_takes(id)
	var/obj/structure/trains/platform/S = tank_store()
	if (!S || !id)
		return FALSE
	if (S.tank_amount > 0 && S.tank_reagent != id)
		return FALSE
	return S.tank_amount < tank_max()

// Runs liquid in. Returns the units the tank took.
/obj/structure/trains/platform/proc/tank_fill(id, amount)
	var/obj/structure/trains/platform/S = tank_store()
	if (!S || !tank_takes(id) || amount <= 0)
		return 0
	. = min(amount, tank_max() - S.tank_amount)
	S.tank_reagent = id
	S.tank_amount += .
	train_weights_changed()

// Draws up to `want` units off. Returns what came out.
/obj/structure/trains/platform/proc/tank_draw(want)
	var/obj/structure/trains/platform/S = tank_store()
	if (!S || S.tank_amount <= 0 || want <= 0)
		return 0
	. = min(want, S.tank_amount)
	S.tank_amount -= .
	if (S.tank_amount <= 0)
		S.tank_amount = 0
		S.tank_reagent = null
	train_weights_changed()

/obj/structure/trains/platform/proc/tank_text()
	var/obj/structure/trains/platform/S = tank_store()
	if (!S)
		return null
	var/how = "Pour an open vessel of one liquid in at the tank, or hold an empty one to it to draw off. The valve on its end platform runs water into a water tower and fuel into a heavy diesel locomotive."
	if (S.tank_amount <= 0)
		return "Its tank holds up to [tank_max()] units of one liquid and is empty. [how]"
	return "Its tank holds [round(S.tank_amount)] of [tank_max()] units of [train_tank_name(S.tank_reagent)]. [how]"

// TRUE on the sections the tank itself stands on.
/obj/structure/trains/platform/proc/tank_shell()
	if (!tank_max())
		return FALSE
	var/list/seg = segment_layout()
	return seg && seg["tank"]

// The tank a section shows (update_car_overlays()).
/obj/structure/trains/platform/proc/tank_overlay()
	var/list/L = layout()
	if (!L || !L["tank"])
		return null
	var/list/seg = segment_layout()
	if (!seg || !seg["tank"])
		return null
	var/image/shell = image('icons/obj/vehicles/train_loads.dmi', "tank_[seg["tank"]]", layer = layer + 0.3)
	shell.pixel_x = -world.icon_size
	shell.pixel_y = -world.icon_size
	return shell

// An open vessel at the tank or its valve: one with liquid in pours it in, an
// empty one is filled. TRUE when W was used.
/obj/structure/trains/platform/proc/tank_vessel(obj/item/W, mob/living/user)
	var/obj/structure/trains/platform/S = tank_store()
	if (!S || !istype(user) || !istype(W, /obj/item/weapon/reagent_containers) || !W.reagents || !W.is_open_container())
		return FALSE
	if (W.reagents.total_volume <= 0)
		if (S.tank_amount <= 0)
			to_chat(user, "\The [src]'s tank is empty.")
			return TRUE
		var/id = S.tank_reagent
		var/out = tank_draw(W.reagents.maximum_volume)
		W.reagents.add_reagent(id, out)
		playsound(loc, 'sound/effects/watersplash.ogg', 60, TRUE)
		to_chat(user, "You draw [round(out)] units of [train_tank_name(id)] off. [round(S.tank_amount)] left in the tank.")
		return TRUE
	var/id = train_tank_liquid(W)
	if (!id)
		to_chat(user, SPAN_WARNING("A tank car takes one plain liquid. That is a mixture, or it does not pour."))
		return TRUE
	if (S.tank_amount > 0 && S.tank_reagent != id)
		to_chat(user, SPAN_WARNING("The tank holds [train_tank_name(S.tank_reagent)]. Drain it before loading something else."))
		return TRUE
	var/took = tank_fill(id, W.reagents.get_reagent_amount(id))
	if (took <= 0)
		to_chat(user, "<span class = 'notice'>The tank is full.</span>")
		return TRUE
	W.reagents.remove_reagent(id, took)
	playsound(loc, 'sound/effects/watersplash.ogg', 60, TRUE)
	to_chat(user, "You pour [round(took)] units of [train_tank_name(id)] into the tank. It holds [round(S.tank_amount)] of [tank_max()].")
	return TRUE

// By hand at the tank shell (attackby()). The end platforms are plain deck.
/obj/structure/trains/platform/proc/tank_use(obj/item/W, mob/living/user)
	if (!tank_shell())
		return FALSE
	return tank_vessel(W, user)

/////////////////////////////////////////////////////////////////////////////
// The valve

// Fuel this engine takes straight from a tank car's valve.
/obj/structure/trains/locomotive/proc/tank_fuel_ids()
	return null

/obj/structure/trains/locomotive/heavy_diesel/tank_fuel_ids()
	return list("diesel", "biodiesel")

// Runs the tank out through the valve into what stands beside it: water into
// a water tower, fuel into a heavy diesel locomotive. Returns the units that
// ran out.
/obj/structure/trains/platform/proc/tank_run_out(atom/from)
	var/obj/structure/trains/platform/S = tank_store()
	if (!S || S.tank_amount <= 0 || !from)
		return 0
	. = 0
	if (S.tank_reagent == "water")
		for (var/obj/structure/rail_water/tower/T in range(TANK_VALVE_REACH, from))
			. += tank_draw(T.add_tower_water(S.tank_amount))
			if (S.tank_amount <= 0)
				return
		return
	var/list/done = list()
	for (var/obj/structure/trains/TR in range(TANK_VALVE_REACH, from))
		var/obj/structure/trains/locomotive/E = istype(TR, /obj/structure/trains/locomotive) ? TR : TR.unit_engine()
		if (!E || (E in done))
			continue
		done += E
		var/list/ids = E.tank_fuel_ids()
		if (!ids || !(S.tank_reagent in ids))
			continue
		var/gave = tank_draw(max(0, E.max_fuel - E.fuel))
		E.fuel += gave
		. += gave
		if (S.tank_amount <= 0)
			return

/obj/structure/trains/platform/proc/tank_run_out_by(mob/living/user, atom/from)
	var/obj/structure/trains/platform/S = tank_store()
	if (!S || !istype(user))
		return FALSE
	if (S.tank_amount <= 0)
		to_chat(user, "\The [src]'s tank is empty.")
		return FALSE
	if (train_rolling())
		to_chat(user, SPAN_WARNING("The train is moving."))
		return FALSE
	user.visible_message("[user] couples a hose to \the [src]'s valve and opens it...", "You couple the hose and open the valve...")
	if (!do_after(user, TANK_VALVE_TIME, src) || train_rolling())
		return FALSE
	var/kind = train_tank_name(S.tank_reagent)
	var/out = tank_run_out(from)
	if (out <= 0)
		to_chat(user, "Nothing within reach takes [kind]. Water runs into a water tower within [TANK_VALVE_REACH] tiles, fuel into a heavy diesel locomotive. Hold an open vessel to the valve to draw off by hand.")
		return FALSE
	playsound(loc, 'sound/effects/watersplash.ogg', 80, TRUE)
	user.visible_message("[user] runs [kind] out of \the [src].", "[round(out)] units of [kind] run out. [S.tank_amount > 0 ? "[round(S.tank_amount)] stay in the tank." : "The tank is empty."]")
	return TRUE

// The valve and hose on a tank car's end platform. A tank car is built with one.
/obj/structure/train_tank_valve
	name = "tank valve"
	desc = "A hand wheel on the outlet pipe of a tank car, with a length of hose. Use it to run the tank out into a water tower or a diesel locomotive beside the car, or hold an open vessel to it."
	icon = 'icons/obj/vehicles/train_platforms.dmi'
	icon_state = "tank_valve"
	anchored = TRUE
	density = FALSE
	flammable = FALSE
	layer = 3.1

// The tank car this valve is bolted to, if any.
/obj/structure/train_tank_valve/proc/tank()
	if (!anchored || !isturf(loc))
		return null
	for (var/obj/structure/trains/platform/P in range(1, src))
		if (P.tank_max() && (loc in train_platform_tiles(P.loc, P.dir)))
			return P
	return null

/obj/structure/train_tank_valve/attack_hand(mob/living/user)
	if (!istype(user, /mob/living/human) || user.incapacitated() || get_dist(user, src) > 1)
		return
	var/obj/structure/trains/platform/P = tank()
	if (!P)
		to_chat(user, "\The [src] has to stand on a tank car to work.")
		return
	P.tank_run_out_by(user, src)

/obj/structure/train_tank_valve/attackby(obj/item/W as obj, mob/user as mob)
	if (is_tool(W, TOOL_WRENCH))
		timed_toggle_anchor(user, 30)
		return
	var/obj/structure/trains/platform/P = tank()
	if (P && P.tank_vessel(W, user))
		return
	return ..()

/obj/structure/train_tank_valve/examine(mob/user)
	..()
	if (!anchored)
		to_chat(user, "It is unbolted. Stand it on the deck of a tank car and use a wrench.")
	var/obj/structure/trains/platform/P = tank()
	var/text = P ? P.tank_text() : null
	if (text)
		to_chat(user, text)

/obj/structure/train_car_kit/tank_car
	name = "tank car kit"
	car_kind = "tank_car"

#undef TANK_PER_WEIGHT
#undef TANK_VALVE_TIME
#undef TANK_VALVE_REACH
