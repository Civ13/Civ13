// Hand pump fire engine: a water tub on wheels with a pump and a short leather
// hose. Pull it to the fire, fill the tub by bucket, take the nozzle and click
// where the water should land. One jet puts out the tile it lands on, anyone
// burning there, and often the fires on the tiles around it.
//
// The nozzle never leaves its engine: let go of it or walk past the end of
// the hose and it is back on the engine.

#define FIRE_PUMP_MAX_WATER 400
#define FIRE_PUMP_SHOT_WATER 20 // water one jet uses
#define FIRE_PUMP_RANGE 5 // how far from the nozzle a jet lands
#define FIRE_PUMP_HOSE 3 // how far from the engine the nozzle reaches
#define FIRE_PUMP_COOLDOWN 10
#define FIRE_PUMP_SPLASH_CHANCE 50

/obj/structure/fire_pump
	name = "hand pump fire engine"
	desc = "A water tub on wheels with a hand pump and a leather hose. Fill it by bucket, pull it to the fire, then take the nozzle and aim."
	icon = 'icons/obj/firefighting.dmi'
	icon_state = "fire_pump"
	density = TRUE
	anchored = FALSE
	flammable = TRUE
	var/water = 0
	var/max_water = FIRE_PUMP_MAX_WATER
	var/hose_length = FIRE_PUMP_HOSE // how far from here the nozzle reaches
	var/nozzle_type = /obj/item/weapon/fire_nozzle
	var/tmp/obj/item/weapon/fire_nozzle/nozzle

/obj/structure/fire_pump/persistence_runtime_var(key)
	return key == "nozzle" || ..()

/obj/structure/fire_pump/Destroy()
	if (nozzle)
		var/obj/item/weapon/fire_nozzle/N = nozzle
		nozzle = null
		N.pump = null
		if (!QDELETED(N))
			qdel(N)
	return ..()

/obj/structure/fire_pump/examine(mob/user, distance = -1)
	. = ..()
	examine_water(user)
	if (nozzle_out())
		to_chat(user, SPAN_NOTICE("Its hose is run out."))

/obj/structure/fire_pump/proc/examine_water(mob/user)
	if (water <= 0)
		to_chat(user, SPAN_WARNING("The tub is empty. Pour water in with a bucket."))
	else
		to_chat(user, SPAN_NOTICE("The tub holds [water] of [max_water] units of water, enough for [round(water / FIRE_PUMP_SHOT_WATER)] jet\s."))

// Water on hand for jets, and taking some of it. draw_water returns TRUE when
// the whole amount was there to take.
/obj/structure/fire_pump/proc/water_left()
	return water

/obj/structure/fire_pump/proc/draw_water(amount)
	if (water < amount)
		return FALSE
	water -= amount
	return TRUE

/obj/structure/fire_pump/proc/dry_message()
	return "\The [src] is out of water. Pour more in with a bucket."

/obj/structure/fire_pump/proc/nozzle_out()
	return nozzle && !QDELETED(nozzle) && nozzle.loc != src

// The engine's one nozzle, made the first time it is needed.
/obj/structure/fire_pump/proc/get_nozzle()
	if (!nozzle || QDELETED(nozzle))
		nozzle = new nozzle_type(src)
		nozzle.pump = src
	return nozzle

/obj/structure/fire_pump/proc/stow_nozzle()
	if (!nozzle || QDELETED(nozzle) || nozzle.loc == src)
		return FALSE
	var/mob/holder = ismob(nozzle.loc) ? nozzle.loc : null
	if (holder)
		holder.remove_from_mob(nozzle)
	nozzle.forceMove(src)
	update_icon()
	return TRUE

// Returns the units of water that went in.
/obj/structure/fire_pump/proc/add_water(amount)
	var/taken = max(0, min(amount, max_water - water))
	water += taken
	return taken

// Pouring an open container's water into the tub. Returns TRUE when handled.
/obj/structure/fire_pump/proc/fill_from(obj/item/weapon/reagent_containers/RC, mob/user)
	if (!istype(RC) || !RC.reagents || !RC.is_open_container())
		return FALSE
	var/have = RC.reagents.get_reagent_amount("water")
	if (have <= 0)
		if (user)
			to_chat(user, SPAN_WARNING("\The [RC] has no water in it."))
		return TRUE
	var/taken = add_water(have)
	if (taken <= 0)
		if (user)
			to_chat(user, SPAN_NOTICE("The tub of \the [src] is full."))
		return TRUE
	RC.reagents.remove_reagent("water", taken)
	playsound(get_turf(src), 'sound/effects/watersplash.ogg', 60, TRUE)
	if (user)
		user.visible_message("[user] pours water into \the [src].", SPAN_NOTICE("You pour [taken] units of water into \the [src]. It now holds [water] of [max_water]."))
	return TRUE

/obj/structure/fire_pump/attackby(obj/item/O, mob/user, icon_x, icon_y)
	if (istype(O, /obj/item/weapon/fire_nozzle))
		if (O == nozzle && stow_nozzle() && user)
			to_chat(user, SPAN_NOTICE("You hang the nozzle back on \the [src]."))
		return TRUE
	if (fill_from(O, user))
		return TRUE
	return ..()

/obj/structure/fire_pump/attack_hand(mob/M, icon_x, icon_y)
	if (!isliving(M) || M.stat || M.restrained())
		return ..()
	if (nozzle_out())
		to_chat(M, SPAN_WARNING("Someone already has the nozzle of \the [src]."))
		return TRUE
	var/obj/item/weapon/fire_nozzle/N = get_nozzle()
	if (!M.put_in_hands(N))
		N.forceMove(src)
		to_chat(M, SPAN_WARNING("You need a free hand for the nozzle."))
		return TRUE
	to_chat(M, SPAN_NOTICE("You take the nozzle of \the [src]. Click where the water should land, up to [FIRE_PUMP_RANGE] tiles away. Stay within [hose_length] tiles of \the [src]."))
	update_icon()
	return TRUE

// Pulled or pushed away from whoever holds the nozzle: the hose comes back.
/obj/structure/fire_pump/Move()
	. = ..()
	if (. && nozzle_out() && get_dist(get_turf(nozzle), src) > hose_length)
		var/mob/holder = ismob(nozzle.loc) ? nozzle.loc : null
		if (stow_nozzle() && holder)
			to_chat(holder, SPAN_WARNING("The hose pulls taut and the nozzle is dragged out of your hands."))

/obj/item/weapon/fire_nozzle
	name = "fire engine nozzle"
	desc = "A brass fire nozzle on the end of its hose. Click where the water should land."
	icon = 'icons/obj/firefighting.dmi'
	icon_state = "fire_nozzle"
	item_state = "fire_nozzle"
	item_icons = list(
		slot_l_hand_str = 'icons/obj/firefighting.dmi',
		slot_r_hand_str = 'icons/obj/firefighting.dmi',
		)
	item_state_slots = list(
		slot_l_hand_str = "fire_nozzle_l",
		slot_r_hand_str = "fire_nozzle_r",
		)
	force = WEAPON_FORCE_HARMLESS
	throwforce = WEAPON_FORCE_HARMLESS
	w_class = ITEM_SIZE_LARGE
	should_save = FALSE // the engine makes a fresh one when it is next needed
	var/tmp/obj/structure/fire_pump/pump
	var/tmp/next_spray = 0

/obj/item/weapon/fire_nozzle/persistence_runtime_var(key)
	return key == "next_spray" || key == "pump" || ..()

/obj/item/weapon/fire_nozzle/Destroy()
	if (pump && pump.nozzle == src)
		pump.nozzle = null
	pump = null
	return ..()

// A nozzle with no engine is nothing; one out of anyone's hands goes home.
/obj/item/weapon/fire_nozzle/proc/check_tether()
	if (QDELETED(src))
		return
	if (!pump || QDELETED(pump))
		qdel(src)
		return
	if (!ismob(loc))
		pump.stow_nozzle()

/obj/item/weapon/fire_nozzle/dropped(mob/user)
	..()
	addtimer(CALLBACK(src, PROC_REF(check_tether)), 1)

// A wall stops water: a dense turf, or a solid wall built on the tile.
/proc/fire_jet_blocked(turf/T)
	if (!T || T.density)
		return TRUE
	for (var/obj/covers/C in T)
		if (C.density && C.opacity)
			return TRUE
	return FALSE

// Where a jet aimed at the target comes down: the target's tile, or the last
// open tile before a wall or the end of the jet's reach.
/proc/fire_jet_landing(atom/from, atom/target, reach = FIRE_PUMP_RANGE)
	var/turf/start = get_turf(from)
	var/turf/aim = get_turf(target)
	if (!start || !aim || start.z != aim.z)
		return null
	var/turf/landing = start
	var/steps = 0
	for (var/turf/T in getline2(start, aim, FALSE))
		if (steps >= reach)
			break
		if (fire_jet_blocked(T))
			break
		landing = T
		steps++
	return landing

// What a jet does where it lands. Returns the number of fires put out.
/proc/fire_jet_hit(turf/T)
	if (!T)
		return 0
	var/out = 0
	for (var/obj/effect/fire/F in T)
		qdel(F)
		out++
	for (var/mob/living/L in T)
		if (L.on_fire)
			L.ExtinguishMob()
	for (var/obj/effect/fire/near in range(1, T))
		if (near.loc != T && prob(FIRE_PUMP_SPLASH_CHANCE))
			qdel(near)
			out++
	return out

// Returns TRUE when a jet was thrown.
/obj/item/weapon/fire_nozzle/proc/spray(atom/target, mob/user)
	if (!pump || QDELETED(pump))
		qdel(src)
		return FALSE
	if (!user || world.time < next_spray)
		return FALSE
	if (get_dist(user, pump) > pump.hose_length || user.z != pump.z)
		pump.stow_nozzle()
		to_chat(user, SPAN_WARNING("The hose pulls taut and the nozzle is dragged out of your hands."))
		return FALSE
	if (pump.water_left() < FIRE_PUMP_SHOT_WATER)
		to_chat(user, SPAN_WARNING(pump.dry_message()))
		return FALSE
	var/turf/landing = fire_jet_landing(user, target)
	if (!landing)
		return FALSE
	next_spray = world.time + FIRE_PUMP_COOLDOWN
	user.setClickCooldown(FIRE_PUMP_COOLDOWN)
	pump.draw_water(FIRE_PUMP_SHOT_WATER)
	playsound(get_turf(user), 'sound/effects/extinguish.ogg', 70, TRUE)
	new /obj/effect/fire_jet(landing)
	var/out = fire_jet_hit(landing)
	if (out)
		playsound(landing, 'sound/items/cig_snuff.ogg', 50, TRUE)
	if (pump.water_left() < FIRE_PUMP_SHOT_WATER)
		to_chat(user, SPAN_WARNING("That was the last of the water for \the [pump]."))
	return TRUE

/obj/item/weapon/fire_nozzle/resolve_attackby(atom/A, mob/user, icon_x, icon_y)
	if (istype(A, /obj/structure/fire_pump))
		return ..()
	spray(A, user)
	return TRUE

/obj/item/weapon/fire_nozzle/afterattack(atom/target, mob/user, proximity_flag, params)
	if (!proximity_flag)
		spray(target, user)

// The splash where a jet lands, gone in a moment.
/obj/effect/fire_jet
	name = "water"
	icon = 'icons/effects/effects.dmi'
	icon_state = "extinguish"
	mouse_opacity = FALSE
	anchored = TRUE
	should_save = FALSE

/obj/effect/fire_jet/New()
	..()
	QDEL_IN(src, 6)

// Fire hose reel: a canvas hose on a drum, plumbed to a sink or well beside
// it. It has no tub of its own: every jet draws on that water, so it keeps
// going for as long as the supply does, and the long hose covers a building.

#define FIRE_REEL_HOSE 7
#define FIRE_REEL_SUPPLY_RANGE 1

/obj/structure/fire_pump/reel
	name = "fire hose reel"
	desc = "A canvas fire hose wound on a drum. It draws its water from a sink or well beside it."
	icon_state = "fire_hose_reel"
	density = FALSE
	anchored = TRUE
	flammable = FALSE
	max_water = 0
	hose_length = FIRE_REEL_HOSE

/obj/structure/fire_pump/reel/update_icon()
	..()
	icon_state = nozzle_out() ? "fire_hose_reel_out" : "fire_hose_reel"

/obj/structure/fire_pump/reel/after_load()
	. = ..()
	update_icon()

// The sinks and wells this reel is plumbed to. Puddles do not count.
/obj/structure/fire_pump/reel/proc/supplies()
	var/list/found = list()
	for (var/obj/structure/sink/S in range(FIRE_REEL_SUPPLY_RANGE, src))
		if (istype(S, /obj/structure/sink/puddle) || S.dry || S.volume <= 0)
			continue
		found += S
	return found

/obj/structure/fire_pump/reel/water_left()
	var/total = 0
	for (var/obj/structure/sink/S in supplies())
		total += S.volume
	return total

/obj/structure/fire_pump/reel/draw_water(amount)
	if (water_left() < amount)
		return FALSE
	for (var/obj/structure/sink/S in supplies())
		var/taken = min(amount, S.volume)
		S.volume -= taken
		amount -= taken
		if (amount <= 0)
			break
	return TRUE

/obj/structure/fire_pump/reel/fill_from(obj/item/weapon/reagent_containers/RC, mob/user)
	return FALSE

/obj/structure/fire_pump/reel/dry_message()
	return "No water comes: \the [src] needs a sink or well with water in it right beside it."

/obj/structure/fire_pump/reel/examine_water(mob/user)
	var/left = water_left()
	if (left < FIRE_PUMP_SHOT_WATER)
		to_chat(user, SPAN_WARNING("It has no water supply. It must stand right beside a sink or well with water in it."))
	else
		to_chat(user, SPAN_NOTICE("Its supply holds enough water for [round(left / FIRE_PUMP_SHOT_WATER)] jet\s."))

#undef FIRE_REEL_HOSE
#undef FIRE_REEL_SUPPLY_RANGE
#undef FIRE_PUMP_MAX_WATER
#undef FIRE_PUMP_SHOT_WATER
#undef FIRE_PUMP_RANGE
#undef FIRE_PUMP_HOSE
#undef FIRE_PUMP_COOLDOWN
#undef FIRE_PUMP_SPLASH_CHANCE
