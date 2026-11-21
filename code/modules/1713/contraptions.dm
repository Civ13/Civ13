// Contraptions that store, sequence or raise drive (mechanical_power.dm):
//
// - Counterweight drum: a wound-up stone weight that turns machines while it
//   falls, and that a lever's cord can brake and release.
// - Cam drum: a driven barrel of pegs that pulls its cords one after another.
// - Stationary steam engine: a mover that runs on coal, charcoal or wood.
//
// None of them ticks for the drive: the drum and the engine work out how far
// the weight has fallen or how much fuel has burned when they are asked. Only
// the cam drum joins the object loop, while it is set running.

#define COUNTERWEIGHT_WIND_TIME 100 // deciseconds of cranking for one winding
#define COUNTERWEIGHT_WIND_FALL 3000 // deciseconds of fall one winding stores
#define COUNTERWEIGHT_MAX_FALL 9000
#define CAM_DRUM_STEP 200 // deciseconds between pulls at a drive share of 1
#define CAM_DRUM_IDLE_RECHECK 100
#define STEAM_ENGINE_FUEL_LIMIT 60 // minutes of running

//////////////////////////////////////////////////////////////////////////////
// Counterweight drum

/obj/structure/workshop_machine/mover/counterweight
	name = "counterweight drum"
	desc = "A rope drum on a timber frame with a squared stone hanging from it. Crank the weight up, and as it falls it drives the fastened machines next to it, or along a line shaft, for a few minutes. A lever's cord can hold its brake and let it go."
	icon = 'icons/obj/contraptions.dmi'
	icon_state = "counterweight"
	base_state = "counterweight"
	drive_factor = 0.6
	drive_capacity = 1
	var/stored = 0 // deciseconds of fall left, counted from released_at while released
	var/released = TRUE // FALSE while the brake holds the weight
	var/tmp/released_at = 0
	var/tmp/winding = FALSE

/obj/structure/workshop_machine/mover/counterweight/persistence_runtime_var(key)
	return key == "released_at" || key == "winding" || ..()

// Deciseconds of fall the weight still has.
/obj/structure/workshop_machine/mover/counterweight/proc/fall_left()
	if (!released)
		return stored
	if (!released_at) // just loaded: the fall starts again from here
		released_at = world.time
	return max(0, stored - (world.time - released_at))

/obj/structure/workshop_machine/mover/counterweight/proc/set_released(want)
	if (want == released)
		return FALSE
	stored = fall_left()
	released = want
	released_at = want ? world.time : 0
	update_icon()
	playsound(src, 'sound/items/Ratchet.ogg', 40, TRUE)
	return TRUE

/obj/structure/workshop_machine/mover/counterweight/idle_reason()
	if (fall_left() <= 0)
		return "The weight is down. Crank it up again with an empty hand."
	if (!released)
		return "Its brake is on. Release it by hand or with a lever's cord."
	return null

/obj/structure/workshop_machine/mover/counterweight/examine(mob/user, distance)
	..(user, distance)
	var/left = fall_left()
	if (left > 0)
		to_chat(user, SPAN_NOTICE("The weight has about [max(1, round(left / 600))] minute\s of fall left[released ? "" : ", held by the brake"]."))

/obj/structure/workshop_machine/mover/counterweight/attack_hand(mob/living/human/H)
	if (!istype(H))
		return
	if (H.a_intent == I_HELP)
		wind(H)
		return
	set_released(!released)
	H.visible_message(SPAN_NOTICE("[H] [released ? "lets off" : "sets"] the brake of \the [src]."), SPAN_NOTICE("You [released ? "let off" : "set"] the brake."))

/obj/structure/workshop_machine/mover/counterweight/proc/wind(mob/living/human/H)
	if (winding || !anchored)
		examine(H, 1)
		return
	if (fall_left() + COUNTERWEIGHT_WIND_FALL > COUNTERWEIGHT_MAX_FALL)
		to_chat(H, SPAN_NOTICE("The weight is already cranked up to the top."))
		return
	winding = TRUE
	H.visible_message(SPAN_NOTICE("[H] starts cranking up the weight of \the [src]."), SPAN_NOTICE("You start cranking up the weight. (Use another intent to set or let off the brake.)"))
	var/done = do_after(H, COUNTERWEIGHT_WIND_TIME, src)
	winding = FALSE
	if (!done || QDELETED(src))
		return
	add_fall(COUNTERWEIGHT_WIND_FALL)
	to_chat(H, SPAN_NOTICE("You crank the weight up."))

/obj/structure/workshop_machine/mover/counterweight/proc/add_fall(amount)
	stored = min(COUNTERWEIGHT_MAX_FALL, fall_left() + amount)
	if (released)
		released_at = world.time
	update_icon()

//////////////////////////////////////////////////////////////////////////////
// Stationary steam engine

/obj/structure/workshop_machine/mover/steam_engine
	name = "stationary steam engine"
	desc = "A boiler, a cylinder and a heavy flywheel on a brick bed. Stoke it with coal, charcoal or wood and it drives the fastened machines next to it, or along a line shaft, harder than any wheel or animal, for as long as the fire lasts."
	icon = 'icons/obj/contraptions.dmi'
	icon_state = "steam_engine"
	base_state = "steam_engine"
	drive_factor = 0.35
	drive_capacity = 6
	flammable = FALSE
	var/fuel = 0 // minutes of running left
	var/tmp/last_burn = 0

/obj/structure/workshop_machine/mover/steam_engine/persistence_runtime_var(key)
	return key == "last_burn" || ..()

// Burns the fuel used since it was last asked.
/obj/structure/workshop_machine/mover/steam_engine/proc/burn()
	var/minutes = last_burn ? (world.time - last_burn) / 600 : 0
	last_burn = world.time
	if (minutes > 0 && fuel > 0)
		fuel = max(0, fuel - minutes)

/obj/structure/workshop_machine/mover/steam_engine/idle_reason()
	burn()
	if (fuel <= 0)
		return "Its firebox is cold. Stoke it with coal, charcoal or wood."
	return null

/obj/structure/workshop_machine/mover/steam_engine/examine(mob/user, distance)
	..(user, distance)
	burn()
	to_chat(user, SPAN_NOTICE("Its firebox holds fuel for about [round(fuel)] of [STEAM_ENGINE_FUEL_LIMIT] minutes."))

/obj/structure/workshop_machine/mover/steam_engine/attackby(obj/item/I, mob/living/human/H)
	if (!istype(H))
		return
	var/obj/item/stack/S = I
	var/each = istype(S) ? solid_fuel_unit_value(S, steam_hammer_fuel_rates) : 0
	if (!each)
		return ..()
	burn()
	var/moved = min(S.amount, round((STEAM_ENGINE_FUEL_LIMIT - fuel) / each))
	if (moved <= 0)
		to_chat(H, SPAN_WARNING("\The [src]'s firebox is full."))
		return
	fuel += moved * each
	S.use(moved)
	update_icon()
	visible_message(SPAN_NOTICE("[H] stokes \the [src]."))

//////////////////////////////////////////////////////////////////////////////
// Cam drum: pulls its cords in turn while driven.

/obj/structure/mechanism/cam_drum
	name = "cam drum"
	desc = "A pegged barrel turned by a mill wheel, windmill, horse gin, treadwheel or line shaft. Tie cords to it and set it running: it pulls them one after another, over and over, for as long as it is driven."
	icon = 'icons/obj/contraptions.dmi'
	icon_state = "cam_drum"
	base_state = "cam_drum"
	drive_draw = 1
	var/running = FALSE
	var/cam_index = 0
	var/tmp/next_cam = 0
	var/tmp/turning = FALSE

/obj/structure/mechanism/cam_drum/persistence_runtime_var(key)
	return key == "next_cam" || key == "turning" || ..()

/obj/structure/mechanism/cam_drum/after_load()
	..()
	if (running)
		processing_objects |= src

/obj/structure/mechanism/cam_drum/on_runtime_spawn()
	..()
	if (running)
		processing_objects |= src

/obj/structure/mechanism/cam_drum/Destroy()
	processing_objects -= src
	return ..()

/obj/structure/mechanism/cam_drum/update_icon()
	icon_state = turning ? "[base_state]_on" : base_state

/obj/structure/mechanism/cam_drum/examine(mob/user, distance)
	..(user, distance)
	if (!running)
		to_chat(user, SPAN_NOTICE("It is stopped. Click it with an empty hand to set it running."))
	else if (mechanical_drive_factor(src) >= 1)
		to_chat(user, SPAN_WARNING("It is set running, but nothing turns it."))
	else
		to_chat(user, SPAN_NOTICE("It is turning, pulling its cords in turn."))

/obj/structure/mechanism/cam_drum/attack_hand(mob/living/human/user)
	if (!istype(user))
		return ..()
	set_running(!running)
	user.visible_message(SPAN_NOTICE("[user] [running ? "sets \the [src] running" : "stops \the [src]"]."), SPAN_NOTICE("You [running ? "set \the [src] running" : "stop \the [src]"]."))

/obj/structure/mechanism/cam_drum/proc/set_running(want)
	running = want
	if (running)
		next_cam = world.time
		processing_objects |= src
	else
		processing_objects -= src
		turning = FALSE
		update_icon()

// Pulls the next cord if the drum is driven; TRUE when it pulled one.
/obj/structure/mechanism/cam_drum/proc/cam_step()
	var/list/entries = mechanism_link_offsets(links)
	var/factor = (anchored && isturf(loc)) ? mechanical_drive_factor(src) : 1
	if (factor >= 1 || !entries.len)
		next_cam = world.time + CAM_DRUM_IDLE_RECHECK
		if (turning)
			turning = FALSE
			update_icon()
		return FALSE
	cam_index = (cam_index % entries.len) + 1
	mechanism_pull_links(src, entries[cam_index], null)
	next_cam = world.time + round(CAM_DRUM_STEP * factor)
	if (!turning)
		turning = TRUE
		update_icon()
	return TRUE

/obj/structure/mechanism/cam_drum/process_interval(configured_seconds = 2)
	if (QDELETED(src) || !running)
		processing_objects -= src
		return PROCESS_KILL
	if (world.time >= next_cam)
		cam_step()

//////////////////////////////////////////////////////////////////////////////
// Relay: a cord-worked switch for the electric device on its tile.

// TRUE when an open relay on T cuts the cable power of the devices there.
/proc/mechanism_relay_open_on(atom/T)
	if (!isturf(T))
		return FALSE
	for (var/obj/structure/mechanism_relay/R in T)
		if (!R.closed)
			return TRUE
	return FALSE

/obj/structure/mechanism_relay
	name = "relay"
	desc = "A copper knife switch in a wooden case, with a cord pawl to throw it. Set it on the same tile as a lamp, outlet or other electric device: open, it cuts that device off from the cable; closed, the device draws power again. Throw it by hand or tie a lever's or plate's cord to it."
	icon = 'icons/obj/contraptions.dmi'
	icon_state = "relay_closed"
	anchored = TRUE
	density = FALSE
	not_movable = FALSE
	not_disassemblable = FALSE
	layer = 2.9
	var/closed = TRUE

/obj/structure/mechanism_relay/after_load()
	..()
	update_icon()

/obj/structure/mechanism_relay/update_icon()
	icon_state = closed ? "relay_closed" : "relay_open"

/obj/structure/mechanism_relay/examine(mob/user, distance)
	..(user, distance)
	to_chat(user, SPAN_NOTICE("It is [closed ? "closed: the device here can draw power" : "open: the device here has no power"]."))

/obj/structure/mechanism_relay/proc/set_closed(want)
	if (want == closed)
		return FALSE
	closed = want
	update_icon()
	playsound(src, 'sound/machines/click.ogg', 40, TRUE)
	return TRUE

/obj/structure/mechanism_relay/attack_hand(mob/living/human/user)
	if (!istype(user))
		return ..()
	set_closed(!closed)
	user.visible_message(SPAN_NOTICE("[user] [closed ? "closes" : "opens"] \the [src]."), SPAN_NOTICE("You [closed ? "close" : "open"] \the [src]."))

#undef COUNTERWEIGHT_WIND_TIME
#undef COUNTERWEIGHT_WIND_FALL
#undef COUNTERWEIGHT_MAX_FALL
#undef CAM_DRUM_STEP
#undef CAM_DRUM_IDLE_RECHECK
#undef STEAM_ENGINE_FUEL_LIMIT
