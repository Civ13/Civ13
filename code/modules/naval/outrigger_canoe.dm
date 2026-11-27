// ============================================================
// Outrigger canoes (docs/outrigger-canoe.md)
// ------------------------------------------------------------
// An outrigger is a dugout canoe with two booms lashed across her and a
// float lashed to their ends. She is built on a finished dugout, ashore or in
// the shallows: wood for the booms and float, then rope to lash them. The
// float steadies her, so she may cross the open sea and ride out a wind that
// keeps a bare dugout on the beach.
//
// She is paddled like a dugout. Two fittings are added to a working canoe and
// come off again:
// - a small sail, which steps a short mast with a crab claw sail. Set, the
//   wind drives her whenever that is quicker than the paddle.
// - an outboard: an engine dropped on her, then its fuel tank. Running, it
//   drives her and burns fuel for every tile.
// A canoe carries one or the other.
//
// A hammer takes a canoe apart when nobody and nothing is aboard.
//
// The dugout calls canoe_work() from its attackby and dress_hull() from its
// update_icon (code/modules/1713/dugout_canoe.dm).
// ============================================================

#define OUTRIGGER_FIT_TIME 60
#define OUTRIGGER_LASH_TIME 80
#define OUTRIGGER_RIG_TIME 60
#define OUTRIGGER_APART_TIME 50

/obj/structure/vehicle/raft/dugout/outrigger
	name = "outrigger canoe"
	desc = "A dugout canoe with a float lashed out on two booms. She is steady enough for the open sea. Holding a paddle makes her faster."
	icon = OUTRIGGER_ICON
	icon_state = "outrigger"
	pixel_w = -32
	pixel_z = -32
	health = 100
	vehicle_m_delay = 13
	paddle_delay = 7
	open_sea = TRUE
	rough_wind = 4
	seat_spacing = 8
	seat_lift = 0
	var/mast = FALSE              // A mast is stepped and a sail bent on.
	var/sail_set = FALSE
	var/sail_torn = FALSE         // A torn sail drives nothing (naval/small_boat_upkeep.dm).
	var/sail_path = null          // Text path of the sail that was fitted, to give back.
	var/tmp/motor_on = FALSE
	var/tmp/under_power = FALSE       // The engine set the pace of the move in hand.
	var/tmp/image/sail_image = null
	var/tmp/sail_look = null

// ---- Looks ----

/obj/structure/vehicle/raft/dugout/outrigger/dress_hull()
	icon_state = engine ? "outrigger_motor" : "outrigger"
	var/sail_state = !sail_set ? "mast_furled" : (sail_torn ? "mast_torn" : "mast_set")
	var/look = mast ? "[sail_state][dir]" : null
	if (look == sail_look)
		return
	if (sail_image)
		overlays -= sail_image
		sail_image = null
	sail_look = look
	if (look)
		sail_image = image(icon, sail_state, dir = dir)
		sail_image.layer = MOB_LAYER + 2.11
		overlays += sail_image

/obj/structure/vehicle/raft/dugout/outrigger/examine(mob/user, distance = -1)
	. = ..()
	if (mast)
		to_chat(user, "A mast is stepped and the sail is [sail_set ? "set" : "furled"]. From her steering seat, Set or Furl Sail works it; Strike Mast takes it down.")
	else if (engine)
		if (fueltank)
			to_chat(user, "An outboard engine is clamped on her stern, with [round(fueltank.reagents.total_volume)] of [fueltank.reagents.maximum_volume] units of fuel. From her steering seat, Start or Stop Engine works it. A wrench takes it off.")
		else
			to_chat(user, "An engine is clamped on her stern. It needs a fuel tank of up to [OUTRIGGER_MAX_TANK] units.")
	else
		to_chat(user, "A small sail used on her steps a mast. An engine of [OUTRIGGER_MIN_ENGINE] to [OUTRIGGER_MAX_ENGINE]cc dragged onto her makes her a motor boat.")

/obj/structure/vehicle/raft/dugout/examine(mob/user, distance = -1)
	. = ..()
	if (booms_fitted)
		to_chat(user, "Two booms and a float are laid on her. [OUTRIGGER_LASH_ROPE] rope will lash them and make her an outrigger. A hammer knocks them off again.")
	else if (type == /obj/structure/vehicle/raft/dugout)
		to_chat(user, "[OUTRIGGER_BOOM_WOOD] wood used on her fits the booms and float of an outrigger.")

// ---- Work on a canoe ----

// Why nobody can work on her here, or null. Boat work is done ashore or
// standing in the shallows, with her empty.
/obj/structure/vehicle/raft/dugout/proc/canoe_work_refusal()
	if (istype(loc, /turf/floor/beach/water/deep))
		return "she has to be ashore or in the shallows"
	if (length(ontop) || length(ontop_o))
		return "she has to be empty"
	return null

/obj/structure/vehicle/raft/dugout/proc/canoe_refuse(mob/user, what)
	var/why = canoe_work_refusal()
	if (why)
		to_chat(user, SPAN_WARNING("You cannot [what] \the [src]: [why]."))
		return TRUE
	return FALSE

// What taking her apart gives back: about half the wood, and all the rope.
/obj/structure/vehicle/raft/dugout/proc/canoe_salvage(turf/T)
	var/obj/item/stack/material/wood/W = new(T)
	W.amount = 6
	if (booms_fitted)
		W.amount += OUTRIGGER_BOOM_WOOD
	W.update_icon()

/obj/structure/vehicle/raft/dugout/outrigger/canoe_salvage(turf/T)
	..()
	var/obj/item/stack/material/wood/W = locate() in T
	if (W)
		W.amount += OUTRIGGER_BOOM_WOOD / 2
		W.update_icon()
	var/obj/item/stack/material/rope/R = new(T)
	R.amount = OUTRIGGER_LASH_ROPE
	R.update_icon()
	drop_sail(T)
	drop_outboard(T)

// TRUE when the click was boat work and is done with.
/obj/structure/vehicle/raft/dugout/proc/canoe_work(obj/item/O, mob/user)
	if (!ishuman(user) || !O)
		return FALSE
	if (is_tool(O, TOOL_HAMMER))
		if (canoe_refuse(user, booms_fitted ? "knock the booms off" : "take apart"))
			return TRUE
		playsound(loc, 'sound/items/Screwdriver.ogg', 75, TRUE)
		if (booms_fitted)
			to_chat(user, SPAN_NOTICE("You start knocking the booms and float off \the [src]."))
			if (do_after(user, OUTRIGGER_APART_TIME, src) && booms_fitted && !canoe_work_refusal())
				booms_fitted = FALSE
				var/obj/item/stack/material/wood/W = new(get_turf(src))
				W.amount = OUTRIGGER_BOOM_WOOD
				W.update_icon()
				update_icon()
				to_chat(user, SPAN_NOTICE("\The [src] is a plain canoe again."))
			return TRUE
		to_chat(user, SPAN_NOTICE("You start taking \the [src] apart."))
		if (do_after(user, OUTRIGGER_APART_TIME, src) && !QDELETED(src) && !canoe_work_refusal())
			to_chat(user, SPAN_NOTICE("You take \the [src] apart. Some of the wood is past using."))
			canoe_salvage(get_turf(src))
			qdel(src)
		return TRUE
	return canoe_fitting(O, user)

// A plain dugout takes the booms and float, then the lashings.
/obj/structure/vehicle/raft/dugout/proc/canoe_fitting(obj/item/O, mob/user)
	if (!booms_fitted && (istype(O, /obj/item/stack/material/wood) || istype(O, /obj/item/stack/material/woodplank)))
		if (health < initial(health))
			return FALSE // Wood mends a damaged canoe first (small_craft_leaks.dm).
		var/obj/item/stack/S = O
		if (S.amount < OUTRIGGER_BOOM_WOOD)
			to_chat(user, SPAN_WARNING("The booms and float of an outrigger take [OUTRIGGER_BOOM_WOOD] wood."))
			return TRUE
		if (canoe_refuse(user, "fit booms to"))
			return TRUE
		user.visible_message(SPAN_NOTICE("[user] starts shaping booms and a float for \the [src]."), SPAN_NOTICE("You start shaping two booms and a float for \the [src]."))
		if (do_after(user, OUTRIGGER_FIT_TIME, src) && !booms_fitted && !canoe_work_refusal() && !QDELETED(S) && S.use(OUTRIGGER_BOOM_WOOD))
			booms_fitted = TRUE
			update_icon()
			to_chat(user, SPAN_NOTICE("The booms lie across \the [src] with the float at their ends. Lash them with [OUTRIGGER_LASH_ROPE] rope."))
		return TRUE
	if (booms_fitted && istype(O, /obj/item/stack/material/rope))
		var/obj/item/stack/S = O
		if (S.amount < OUTRIGGER_LASH_ROPE)
			to_chat(user, SPAN_WARNING("Lashing the booms and float takes [OUTRIGGER_LASH_ROPE] rope."))
			return TRUE
		if (canoe_refuse(user, "lash"))
			return TRUE
		user.visible_message(SPAN_NOTICE("[user] starts lashing the booms and float to \the [src]."), SPAN_NOTICE("You start lashing the booms to the hull and the float to the booms."))
		if (do_after(user, OUTRIGGER_LASH_TIME, src) && booms_fitted && !canoe_work_refusal() && !QDELETED(S) && S.use(OUTRIGGER_LASH_ROPE))
			become_outrigger(user)
		return TRUE
	return FALSE

/obj/structure/vehicle/raft/dugout/proc/become_outrigger(mob/user)
	var/obj/structure/vehicle/raft/dugout/outrigger/C = new(get_turf(src))
	C.dir = dir
	C.bilge = bilge
	C.soak = soak
	C.dressing = dressing
	C.on_rollers = on_rollers
	C.update_icon()
	C.dress_rollers()
	user.visible_message(SPAN_NOTICE("[user] finishes \a [C]."), SPAN_NOTICE("The lashings are tight: you have made \a [C]."))
	note_craft_practice(user, "/obj/structure/dugout_log")
	qdel(src)

// An outrigger takes a sail, or the tank and fuel of her outboard.
/obj/structure/vehicle/raft/dugout/outrigger/canoe_fitting(obj/item/O, mob/user)
	if (istype(O, /obj/item/sail))
		if (mast)
			to_chat(user, SPAN_WARNING("\The [src] has a sail already."))
			return TRUE
		if (engine)
			to_chat(user, SPAN_WARNING("The outboard is in the way of a mast. Take it off with a wrench first."))
			return TRUE
		if (canoe_refuse(user, "step a mast on"))
			return TRUE
		user.visible_message(SPAN_NOTICE("[user] starts stepping a mast on \the [src]."), SPAN_NOTICE("You start stepping the mast and bending on \the [O]."))
		if (do_after(user, trade_time(user, OUTRIGGER_RIG_TIME, "mechanic"), src) && !mast && !engine && !canoe_work_refusal() && !QDELETED(O))
			sail_path = "[O.type]"
			user.drop_from_inventory(O)
			qdel(O)
			mast = TRUE
			sail_set = FALSE
			update_icon()
			to_chat(user, SPAN_NOTICE("\The [src] carries a sail. Set it from her steering seat."))
		return TRUE
	if (istype(O, /obj/item/weapon/reagent_containers/glass/barrel/fueltank))
		if (!engine || fueltank)
			to_chat(user, SPAN_WARNING(engine ? "\The [src] has a fuel tank already." : "Drag an engine onto \the [src] first."))
			return TRUE
		var/obj/item/weapon/reagent_containers/glass/barrel/fueltank/T = O
		if (T.reagents.maximum_volume > OUTRIGGER_MAX_TANK)
			to_chat(user, SPAN_WARNING("That tank is too big for a canoe. She takes one of up to [OUTRIGGER_MAX_TANK] units."))
			return TRUE
		if (do_after(user, trade_time(user, OUTRIGGER_RIG_TIME, "mechanic"), src) && engine && !fueltank && !QDELETED(T))
			user.drop_from_inventory(T)
			T.forceMove(src)
			fueltank = T
			update_icon()
			to_chat(user, SPAN_NOTICE("You stow \the [T] and couple it to the engine."))
		return TRUE
	if (is_tool(O, TOOL_WRENCH) && engine)
		if (canoe_refuse(user, "take the outboard off"))
			return TRUE
		if (do_after(user, trade_time(user, OUTRIGGER_RIG_TIME, "mechanic"), src) && engine && !canoe_work_refusal())
			drop_outboard(get_turf(user))
			update_icon()
			to_chat(user, SPAN_NOTICE("You unclamp the outboard from \the [src]."))
		return TRUE
	if (fueltank && engine && istype(O, /obj/item/weapon/reagent_containers/glass))
		var/obj/item/weapon/reagent_containers/glass/G = O
		for (var/fuel in engine.fuels)
			if (!G.reagents || !G.reagents.has_reagent(fuel))
				continue
			var/room = fueltank.reagents.maximum_volume - fueltank.reagents.total_volume
			if (room <= 0)
				to_chat(user, SPAN_WARNING("The fuel tank is full."))
				return TRUE
			var/pour = min(room, G.reagents.get_reagent_amount(fuel))
			fueltank.reagents.add_reagent(fuel, pour)
			G.reagents.remove_reagent(fuel, pour)
			to_chat(user, SPAN_NOTICE("You pour [round(pour)] units of fuel into the tank."))
			return TRUE
	return FALSE

/obj/structure/vehicle/raft/dugout/outrigger/proc/drop_sail(turf/T)
	if (!mast)
		return
	var/path = text2path(sail_path) || /obj/item/sail
	new path(T)
	mast = FALSE
	sail_set = FALSE
	sail_torn = FALSE
	sail_path = null

/obj/structure/vehicle/raft/dugout/outrigger/proc/drop_outboard(turf/T)
	motor_on = FALSE
	if (fueltank)
		fueltank.forceMove(T)
		fueltank = null
	if (engine)
		engine.on = FALSE
		engine.forceMove(T)
		engine = null

// An engine is dragged onto her; anything else is cargo, as on a dugout.
/obj/structure/vehicle/raft/dugout/outrigger/MouseDrop_T(atom/A, mob/living/human/user)
	if (!istype(A, /obj/structure/engine/internal))
		return ..()
	var/obj/structure/engine/internal/E = A
	if (!ishuman(user) || get_dist(user, src) > 1 || get_dist(E, src) > 1)
		return
	if (engine)
		to_chat(user, SPAN_WARNING("\The [src] has an engine already."))
		return
	if (mast)
		to_chat(user, SPAN_WARNING("The mast is in the way of an outboard. Strike the mast first."))
		return
	if (E.enginesize > OUTRIGGER_MAX_ENGINE || E.enginesize < OUTRIGGER_MIN_ENGINE)
		to_chat(user, SPAN_WARNING("A canoe takes an engine of [OUTRIGGER_MIN_ENGINE] to [OUTRIGGER_MAX_ENGINE]cc."))
		return
	if (E.on || E.fueltank)
		to_chat(user, SPAN_WARNING("Turn \the [E] off and uncouple its tank first."))
		return
	if (canoe_refuse(user, "fit an engine to"))
		return
	user.visible_message(SPAN_NOTICE("[user] starts clamping \the [E] onto \the [src]."), SPAN_NOTICE("You start clamping \the [E] over her stern."))
	if (do_after(user, trade_time(user, 130, "mechanic"), src) && !engine && !mast && !canoe_work_refusal() && !QDELETED(E) && get_dist(E, src) <= 1)
		E.forceMove(src)
		engine = E
		update_icon()
		to_chat(user, SPAN_NOTICE("The engine is on. She needs a fuel tank of up to [OUTRIGGER_MAX_TANK] units."))

// ---- Sail and engine at work ----

/obj/structure/vehicle/raft/dugout/outrigger/verb/work_sail()
	set name = "Set or Furl Sail"
	set category = "Object"
	set src in view(1)
	var/mob/living/human/H = usr
	if (!istype(H) || H.stat || H != driver)
		to_chat(usr, SPAN_WARNING("The sail is worked from her steering seat."))
		return
	if (!mast)
		to_chat(H, SPAN_WARNING("\The [src] carries no sail."))
		return
	sail_set = !sail_set
	update_icon()
	if (sail_set)
		to_chat(H, SPAN_NOTICE("You set the sail. You are [point_of_sail_name(dir, weather_wind_dir_at(src))]; hold a direction to steer."))
	else
		to_chat(H, SPAN_NOTICE("You furl the sail."))

/obj/structure/vehicle/raft/dugout/outrigger/verb/strike_mast()
	set name = "Strike Mast"
	set category = "Object"
	set src in view(1)
	var/mob/living/human/H = usr
	if (!istype(H) || H.stat || H.restrained() || get_dist(H, src) > 1)
		return
	if (!mast)
		to_chat(H, SPAN_WARNING("\The [src] carries no mast."))
		return
	if (sail_torn)
		to_chat(H, SPAN_WARNING("The sail is torn. Mend it with cloth before you roll it up."))
		return
	if (canoe_refuse(H, "strike the mast of"))
		return
	if (do_after(H, OUTRIGGER_RIG_TIME, src) && mast && !canoe_work_refusal())
		drop_sail(get_turf(H))
		update_icon()
		to_chat(H, SPAN_NOTICE("You take down the mast and roll up the sail."))

/obj/structure/vehicle/raft/dugout/outrigger/verb/work_engine()
	set name = "Start or Stop Engine"
	set category = "Object"
	set src in view(1)
	var/mob/living/human/H = usr
	if (!istype(H) || H.stat || H != driver)
		to_chat(usr, SPAN_WARNING("The engine is worked from her steering seat."))
		return
	if (!engine || !fueltank)
		to_chat(H, SPAN_WARNING(engine ? "The engine has no fuel tank." : "\The [src] has no engine."))
		return
	if (motor_on)
		stop_motor()
		to_chat(H, SPAN_NOTICE("You stop the engine."))
		return
	if (!motor_fuel())
		to_chat(H, SPAN_WARNING("There is no fuel the engine burns in the tank."))
		return
	motor_on = TRUE
	playsound(loc, engine.starting_snd, 35, FALSE, 2)
	to_chat(H, SPAN_NOTICE("The engine catches. Hold a direction to drive her."))

/obj/structure/vehicle/raft/dugout/outrigger/proc/stop_motor()
	if (motor_on && engine)
		playsound(loc, engine.ending_snd, 65, FALSE, 2)
	motor_on = FALSE

// Units of fuel one tile under power burns.
/obj/structure/vehicle/raft/dugout/outrigger/proc/motor_burn()
	return engine ? engine.enginesize / 1000 : 0

// The fuel in the tank the engine can burn a tile's worth of, or null.
/obj/structure/vehicle/raft/dugout/outrigger/proc/motor_fuel()
	if (!engine || !fueltank || !fueltank.reagents)
		return null
	for (var/fuel in engine.fuels)
		if (fueltank.reagents.has_reagent(fuel, motor_burn()))
			return fuel
	return null

// Tenths of a second a tile takes under power: 7 for the smallest engine, 3 for the biggest.
/obj/structure/vehicle/raft/dugout/outrigger/proc/motor_delay()
	return max(3, round(8 - engine.enginesize / 80))

// The quickest of paddle, sail and engine sets her pace.
/obj/structure/vehicle/raft/dugout/outrigger/step_delay(m_dir)
	. = ..()
	if (mast && sail_set && !sail_torn && m_dir)
		. = min(., sail_step_time(src, m_dir))
	under_power = FALSE
	if (!motor_on)
		return
	if (motor_fuel())
		. = min(., motor_delay())
		under_power = TRUE
	else
		stop_motor()
		if (driver)
			to_chat(driver, SPAN_WARNING("The engine coughs and dies: the tank is dry."))

// A tile made under power burns its fuel.
/obj/structure/vehicle/raft/dugout/outrigger/do_move(m_dir = null, interval = null)
	var/turf/was = loc
	. = ..()
	if (under_power && loc != was)
		var/fuel = motor_fuel()
		if (fuel)
			fueltank.reagents.remove_reagent(fuel, motor_burn())

#undef OUTRIGGER_FIT_TIME
#undef OUTRIGGER_LASH_TIME
#undef OUTRIGGER_RIG_TIME
#undef OUTRIGGER_APART_TIME
