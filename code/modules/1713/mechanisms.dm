// Mechanisms (docs/mechanisms.md): triggers tied by cord to things that move.
//
// A trigger - a lever, a pull cord, a pressure plate or a tripwire - is tied
// with rope to up to four actuators on the same level within seven tiles: a
// door, window, shutter or trapdoor, a castle drop trapdoor, a gate winch, a
// bell or a rock drop. Working the trigger pulls every cord tied to it.
//
// A lever holds its position: thrown, it opens what it is tied to (drops a
// trapdoor, raises a gate), and thrown back it shuts them. A pull cord, plate
// or tripwire gives a single pull, which turns each door or gate the other way.
// A bell rings and a rock drop lets go on any pull but a lever thrown back.
//
// A pulley block beside a trigger carries its cords one level up or down. A
// water clock or tower clock is a trigger too: set its alarm and it pulls its
// cords at that hour, or every hour.
//
// Nothing ticks and nothing polls. A plate fires from Crossed(), a clock from
// its own minute. A cord is saved on its trigger as an offset to the tile it
// is tied to ("dx,dy", or "dx,dy,dz" through a pulley), and the thing on that
// tile is found again each pull, so a cord tied to something that has since
// gone simply does nothing.

#define MECHANISM_LINK_RANGE 7
#define MECHANISM_MAX_LINKS 4
#define MECHANISM_TIE_TIME 20
#define MECHANISM_PULL_GAP 20 // ds before a plate or cord pulls again
#define ROCK_DROP_DAMAGE 15
#define ROCK_DROP_RESET_TIME 40
#define MECHANISM_ALARM_HOURLY 24

// ---- what a cord can be tied to ------------------------------------------------------

// TRUE when a cord pull can work A.
/proc/mechanism_actuatable(atom/A)
	if (istype(A, /obj/structure/simple_door))
		// Doors with keypads, key slots or faction locks keep their own rules.
		return !istype(A, /obj/structure/simple_door/key_door) || istype(A, /obj/structure/simple_door/key_door/anyone)
	return istype(A, /obj/structure/castle_trapdoor) || istype(A, /obj/structure/castle_winch) || istype(A, /obj/structure/bell) || istype(A, /obj/structure/rock_drop) || istype(A, /obj/structure/workshop_machine/transmission/line_shaft/clutch) || istype(A, /obj/structure/workshop_machine/mover/counterweight) || istype(A, /obj/structure/mechanism_relay) || istype(A, /obj/item/circuit_shell/mechanism_port) || istype(A, /obj/structure/workshop_machine/hopper) || istype(A, /obj/structure/sluice_gate)

// The first thing on T a cord can work, or null.
/proc/mechanism_actuator_on(turf/T)
	if (!T)
		return null
	for (var/atom/movable/A in T)
		if (!QDELETED(A) && mechanism_actuatable(A))
			return A
	return null

// "3 north, 2 east" from origin to T.
/proc/mechanism_offset_words(atom/origin, turf/T)
	var/list/parts = list()
	var/dy = T.y - origin.y
	var/dx = T.x - origin.x
	if (dy)
		parts += "[abs(dy)] [dy > 0 ? "north" : "south"]"
	if (dx)
		parts += "[abs(dx)] [dx > 0 ? "east" : "west"]"
	if (T.z != origin.z)
		parts += mechanism_level_dz(origin, T) > 0 ? "one level up" : "one level down"
	return parts.len ? jointext(parts, ", ") : "here"

// A pulley block within a tile of A carries its cords up and down a level.
/proc/mechanism_pulley_near(atom/A)
	var/turf/T = get_turf(A)
	if (!T)
		return FALSE
	for (var/obj/structure/mechanism_pulley/P in range(1, T))
		if (P.anchored)
			return TRUE
	return FALSE

// 1 when T is on the level above origin, -1 below, 0 on its level.
/proc/mechanism_level_dz(atom/origin, turf/T)
	var/turf/here = get_turf(origin)
	if (!here || !T || T.z == here.z)
		return 0
	if (T.z == multiz_level_above(here.z))
		return 1
	if (T.z == multiz_level_below(here.z))
		return -1
	return 0

// The saved link entry for a cord from origin to T.
/proc/mechanism_link_entry(atom/origin, turf/T)
	var/turf/here = get_turf(origin)
	var/dz = mechanism_level_dz(origin, T)
	return dz ? "[T.x - here.x],[T.y - here.y],[dz]" : "[T.x - here.x],[T.y - here.y]"

// The "dx,dy" offsets in a saved link text.
/proc/mechanism_link_offsets(links)
	. = list()
	if (!links)
		return
	for (var/entry in splittext(links, ";"))
		if (entry)
			. += entry

// The tiles a link text reaches from origin, in order.
/proc/mechanism_link_turfs(atom/origin, links)
	. = list()
	var/turf/here = get_turf(origin)
	if (!here)
		return
	var/pulley = null // looked up once, only if a cord needs it
	for (var/entry in mechanism_link_offsets(links))
		var/list/xy = splittext(entry, ",")
		if (xy.len != 2 && xy.len != 3)
			continue
		var/z = here.z
		if (xy.len == 3)
			// A cord between levels runs over a pulley; without one it hangs slack.
			if (isnull(pulley))
				pulley = mechanism_pulley_near(origin)
			if (!pulley)
				continue
			z = text2num(xy[3]) > 0 ? multiz_level_above(here.z) : multiz_level_below(here.z)
			if (!z)
				continue
		var/turf/T = locate(here.x + text2num(xy[1]), here.y + text2num(xy[2]), z)
		if (T)
			. += T

// Pulls every cord in links. state: TRUE thrown, FALSE thrown back, null a
// single pull. Returns how many things moved or rang.
/proc/mechanism_pull_links(atom/origin, links, state)
	. = 0
	for (var/turf/T in mechanism_link_turfs(origin, links))
		var/atom/A = mechanism_actuator_on(T)
		if (A && mechanism_actuate(A, state))
			.++

// One cord pulls A. TRUE when it moved or rang.
/proc/mechanism_actuate(atom/A, state)
	if (istype(A, /obj/structure/simple_door))
		var/obj/structure/simple_door/D = A
		if (D.isSwitchingStates)
			return FALSE
		var/want_open = isnull(state) ? !D.state : state
		if (want_open == D.state)
			return FALSE
		// Someone holding or bracing it keeps it where it is.
		if (D.door_braced_against(null))
			return FALSE
		// A bar or a locked lock holds the door against the cord.
		if (want_open && (D.locked || D.door_barred() || (D.door_lock && D.door_lock.blocks())))
			playsound(get_turf(D), 'sound/machines/door_locked.ogg', 50, TRUE)
			return FALSE
		// A trapdoor never opens under someone (trapdoors.dm); the castle drop
		// trapdoor is the one made to.
		if (want_open && D.is_trapdoor() && (locate(/mob/living) in D.loc))
			return FALSE
		if (want_open)
			D.Open()
		else
			D.Close()
		return TRUE
	if (istype(A, /obj/structure/castle_trapdoor))
		var/obj/structure/castle_trapdoor/C = A
		var/want_drop = isnull(state) ? !C.open : state
		if (want_drop == C.open)
			return FALSE
		if (want_drop)
			C.drop()
		else
			C.shut()
		return TRUE
	if (istype(A, /obj/structure/castle_winch))
		var/obj/structure/castle_winch/W = A
		var/list/gates = W.gates()
		if (!gates.len || W.busy)
			return FALSE
		var/raise = state
		if (isnull(raise))
			var/obj/structure/castle_gate/first = gates[1]
			raise = istype(first) ? !first.open : TRUE
		W.work(raise)
		return TRUE
	if (istype(A, /obj/structure/workshop_machine/transmission/line_shaft/clutch))
		// Thrown over, a lever throws the clutch in; thrown back, out.
		var/obj/structure/workshop_machine/transmission/line_shaft/clutch/C = A
		if (!C.anchored)
			return FALSE
		return C.set_engaged(isnull(state) ? !C.engaged : state)
	if (istype(A, /obj/structure/workshop_machine/mover/counterweight))
		// Thrown over, a lever lets the weight fall; thrown back, it brakes.
		var/obj/structure/workshop_machine/mover/counterweight/W = A
		return W.set_released(isnull(state) ? !W.released : state)
	if (istype(A, /obj/structure/mechanism_relay))
		// Thrown over, a lever closes the relay; thrown back, it opens it.
		var/obj/structure/mechanism_relay/R = A
		return R.set_closed(isnull(state) ? !R.closed : state)
	if (istype(A, /obj/item/circuit_shell/mechanism_port))
		var/obj/item/circuit_shell/mechanism_port/P = A
		return P.cord_pulled(state)
	if (istype(A, /obj/structure/workshop_machine/hopper))
		// Thrown over, a lever opens the hopper gate; thrown back, it shuts it.
		var/obj/structure/workshop_machine/hopper/H = A
		return H.set_gate(isnull(state) ? !H.gate_shut : !state)
	if (istype(A, /obj/structure/sluice_gate))
		// Thrown over, a lever draws the boards up; thrown back, it lowers them.
		var/obj/structure/sluice_gate/G = A
		return G.set_open(isnull(state) ? !G.open : state)
	if (state == FALSE)
		return FALSE // a lever thrown back neither rings nor drops
	if (istype(A, /obj/structure/bell))
		var/obj/structure/bell/B = A
		if (world.time < B.next_ring)
			return FALSE
		B.ring(0)
		return TRUE
	if (istype(A, /obj/structure/rock_drop))
		var/obj/structure/rock_drop/R = A
		return R.release()
	return FALSE

// ---- tying and cutting cords -----------------------------------------------------

// Rope used on a trigger: tie a cord to something in reach, or cut one.
// The trigger keeps its own link text in its links var. TRUE when handled.
/proc/mechanism_rope_on_trigger(atom/trigger, obj/item/stack/material/rope/R, mob/living/human/user)
	if (!istype(R) || !istype(user))
		return FALSE
	var/list/tied = mechanism_link_turfs(trigger, trigger.vars["links"])
	var/list/choices = list()
	var/list/cuts = list()
	for (var/turf/T in tied)
		var/atom/A = mechanism_actuator_on(T)
		var/label = "Cut the cord to [A ? A.name : "nothing"] ([mechanism_offset_words(trigger, T)])"
		choices[label] = T
		cuts += label
	if (tied.len < MECHANISM_MAX_LINKS)
		for (var/atom/movable/A in mechanism_reachable_actuators(trigger))
			var/turf/T = get_turf(A)
			if (!T || (T in tied) || !tutorial_workshop_pair(user, trigger, T))
				continue
			choices["Tie a cord to [A.name] ([mechanism_offset_words(trigger, T)])"] = T
	if (!choices.len)
		to_chat(user, SPAN_WARNING("There is nothing within [MECHANISM_LINK_RANGE] tiles of \the [trigger] that a cord could work: a door, trapdoor, gate winch, bell, rock drop, shaft clutch, counterweight drum, relay, mechanism port, hopper gate or sluice gate."))
		return TRUE
	var/choice = player_input(user, "Tie or cut which cord on \the [trigger]?", "Cords", null, "anything", choices, TRUE)
	var/turf/target = choice ? choices[choice] : null
	if (!target || QDELETED(trigger) || QDELETED(R) || user.get_active_hand() != R || get_dist(user, trigger) > 1 || !tutorial_workshop_pair(user, trigger, target))
		return TRUE
	var/entry = mechanism_link_entry(trigger, target)
	var/list/offsets = mechanism_link_offsets(trigger.vars["links"])
	if (choice in cuts)
		offsets -= entry
		trigger.vars["links"] = jointext(offsets, ";")
		new /obj/item/stack/material/rope(get_turf(user), 1)
		user.visible_message(SPAN_NOTICE("[user] cuts a cord from \the [trigger]."), SPAN_NOTICE("You cut the cord and coil it up."))
		return TRUE
	if (offsets.len >= MECHANISM_MAX_LINKS)
		to_chat(user, SPAN_WARNING("\The [trigger] already has [MECHANISM_MAX_LINKS] cords tied to it."))
		return TRUE
	user.visible_message(SPAN_NOTICE("[user] starts running a cord from \the [trigger]."), SPAN_NOTICE("You start running a cord from \the [trigger]."))
	if (!do_after(user, MECHANISM_TIE_TIME, trigger) || QDELETED(trigger) || QDELETED(R) || !tutorial_workshop_pair(user, trigger, target) || !R.use(1))
		return TRUE
	offsets = mechanism_link_offsets(trigger.vars["links"])
	if (!(entry in offsets) && offsets.len < MECHANISM_MAX_LINKS)
		offsets += entry
		trigger.vars["links"] = jointext(offsets, ";")
	var/atom/A = mechanism_actuator_on(target)
	to_chat(user, SPAN_NOTICE("You tie the cord from \the [trigger] to \the [A ? A.name : "spot"] ([mechanism_offset_words(trigger, target)])."))
	return TRUE

// Everything a new cord from trigger could be tied to: on its own level, and
// one level up and down when a pulley block stands beside it.
/proc/mechanism_reachable_actuators(atom/trigger)
	. = list()
	var/turf/here = get_turf(trigger)
	if (!here)
		return
	var/list/levels = list(here.z)
	if (mechanism_pulley_near(trigger))
		for (var/z in list(multiz_level_above(here.z), multiz_level_below(here.z)))
			if (z)
				levels += z
	for (var/z in levels)
		var/turf/low = locate(max(1, here.x - MECHANISM_LINK_RANGE), max(1, here.y - MECHANISM_LINK_RANGE), z)
		var/turf/high = locate(min(world.maxx, here.x + MECHANISM_LINK_RANGE), min(world.maxy, here.y + MECHANISM_LINK_RANGE), z)
		if (!low || !high)
			continue
		for (var/turf/T in block(low, high))
			var/atom/A = mechanism_actuator_on(T)
			if (A && A != trigger)
				. += A

// What a trigger's cords are tied to, for examine.
/proc/mechanism_links_examine(atom/trigger, mob/user)
	var/list/names = list()
	for (var/turf/T in mechanism_link_turfs(trigger, trigger.vars["links"]))
		var/atom/A = mechanism_actuator_on(T)
		names += "[A ? A.name : "nothing"] ([mechanism_offset_words(trigger, T)])"
	if (names.len)
		to_chat(user, SPAN_NOTICE("Cords run from it to: [english_list(names)]."))
	else
		to_chat(user, SPAN_NOTICE("No cords are tied to it. Use rope on it to tie one to a door, trapdoor, gate winch, bell, rock drop, shaft clutch, counterweight drum, relay or mechanism port within [MECHANISM_LINK_RANGE] tiles."))

// ---- triggers -----------------------------------------------------------------------

/obj/structure/mechanism
	name = "mechanism"
	icon = 'icons/obj/mechanisms.dmi'
	anchored = TRUE
	density = FALSE
	not_movable = TRUE
	not_disassemblable = FALSE
	flammable = TRUE
	var/links = "" // "dx,dy;dx,dy": tiles its cords are tied to, on this level
	var/base_state = ""
	var/tmp/next_pull = 0

/obj/structure/mechanism/persistence_runtime_var(key)
	return key == "next_pull" || ..()

/obj/structure/mechanism/examine(mob/user, distance)
	..(user, distance)
	mechanism_links_examine(src, user)

/obj/structure/mechanism/attackby(obj/item/I, mob/living/human/user)
	if (istype(I, /obj/item/stack/material/rope) && istype(user))
		mechanism_rope_on_trigger(src, I, user)
		return
	return ..()

// Pull every cord. state as mechanism_pull_links.
/obj/structure/mechanism/proc/pull(state)
	next_pull = world.time + MECHANISM_PULL_GAP
	playsound(get_turf(src), 'sound/effects/rollermove.ogg', 30, TRUE)
	return mechanism_pull_links(src, links, state)

// Lever: holds its position.
/obj/structure/mechanism/lever
	name = "lever"
	desc = "A wooden lever in a stone socket. Tie cords from it with rope; throw it to open, drop or raise what they are tied to, and throw it back to shut them."
	icon_state = "lever"
	base_state = "lever"
	var/thrown = FALSE

/obj/structure/mechanism/lever/after_load()
	..()
	update_icon()

/obj/structure/mechanism/lever/update_icon()
	icon_state = thrown ? "[base_state]_pulled" : base_state

/obj/structure/mechanism/lever/attack_hand(mob/living/human/user)
	if (!istype(user) || !Adjacent(user))
		return ..()
	if (world.time < next_pull)
		return
	thrown = !thrown
	update_icon()
	user.visible_message(SPAN_NOTICE("[user] throws \the [src] [thrown ? "over" : "back"]."), SPAN_NOTICE("You throw \the [src] [thrown ? "over" : "back"]."))
	pull(thrown)

// Pull cord: one pull each time.
/obj/structure/mechanism/pull_cord
	name = "pull cord"
	desc = "A rope on a wooden bracket with a toggle at the end. Tie cords from it with rope; each pull opens what is shut and shuts what is open, rings a bell or lets a rock drop go."
	icon_state = "pull_cord"
	base_state = "pull_cord"

/obj/structure/mechanism/pull_cord/attack_hand(mob/living/human/user)
	if (!istype(user) || !Adjacent(user))
		return ..()
	if (world.time < next_pull)
		to_chat(user, SPAN_WARNING("The cord is still swinging back."))
		return
	flick("[base_state]_pulled", src)
	user.visible_message(SPAN_NOTICE("[user] pulls \the [src]."), SPAN_NOTICE("You pull \the [src]."))
	pull(null)

// Pressure plate: a stranger, or a large animal, stepping on it pulls once.
/obj/structure/mechanism/pressure_plate
	name = "pressure plate"
	desc = "A flat stone set flush into the ground on a pivot. Tie cords from it with rope; anyone outside the setter's people, or a large animal, stepping on it gives every cord one pull."
	icon_state = "pressure_plate"
	base_state = "pressure_plate"
	layer = 2.1
	flammable = FALSE
	var/owner_name = null
	var/owner_civilization = null
	var/owner_faction = null

/obj/structure/mechanism/pressure_plate/proc/set_owner(mob/living/human/H)
	owner_name = H.real_name
	owner_civilization = H.civilization
	owner_faction = H.faction_text

// The setter and their people (civilization, or side on a team map) step on it safely.
/obj/structure/mechanism/pressure_plate/proc/is_friend(mob/living/human/H)
	if (owner_name && H.real_name == owner_name)
		return TRUE
	if (owner_civilization && owner_civilization != "none" && H.civilization == owner_civilization)
		return TRUE
	if (map && !map.civilizations && owner_faction && H.faction_text == owner_faction)
		return TRUE
	return FALSE

/obj/structure/mechanism/pressure_plate/proc/presses(atom/movable/AM)
	if (ishuman(AM))
		var/mob/living/human/H = AM
		return H.stat != DEAD && !is_friend(H)
	if (istype(AM, /mob/living/simple_animal))
		var/mob/living/simple_animal/S = AM
		return S.stat != DEAD && S.mob_size >= MOB_MEDIUM
	return FALSE

/obj/structure/mechanism/pressure_plate/Crossed(atom/movable/AM)
	..()
	if (world.time < next_pull || !presses(AM))
		return
	flick("[base_state]_pressed", src)
	pull(null)

/obj/structure/mechanism/pressure_plate/attack_hand(mob/living/human/user)
	if (!istype(user) || !Adjacent(user))
		return ..()
	user.visible_message(SPAN_NOTICE("[user] starts prising up \the [src]."))
	if (!do_after(user, 30, src) || QDELETED(src))
		return
	for (var/turf/T in mechanism_link_turfs(src, links))
		new /obj/item/stack/material/rope(get_turf(src), 1)
	new /obj/item/mechanism_kit/pressure_plate(get_turf(src))
	qdel(src)

// Set from the hand so it knows whose people may cross it.
/obj/item/mechanism_kit/pressure_plate
	name = "pressure plate"
	desc = "A flat stone slab and pivot. Use it in hand to set it into the ground where you stand; your own people can then step on it safely."
	icon = 'icons/obj/mechanisms.dmi'
	icon_state = "pressure_plate"
	w_class = ITEM_SIZE_NORMAL

/obj/item/mechanism_kit/pressure_plate/attack_self(mob/living/human/user)
	var/turf/T = get_turf(user)
	if (!istype(user) || !T)
		return
	if (locate(/obj/structure/mechanism) in T)
		to_chat(user, SPAN_WARNING("There is already a mechanism here."))
		return
	if (!do_after(user, 40, T) || QDELETED(src))
		return
	var/obj/structure/mechanism/pressure_plate/P = new(T)
	P.set_owner(user)
	user.visible_message(SPAN_NOTICE("[user] sets a stone slab into the ground."), SPAN_NOTICE("You set the pressure plate. Your own people can step on it safely; tie cords from it with rope."))
	qdel(src)

// Tripwire alarms also pull any cords tied to them (cmss13_gear.dm).
/obj/structure/tripwire_alarm
	var/links = ""

/obj/structure/tripwire_alarm/examine(mob/user, distance)
	..(user, distance)
	mechanism_links_examine(src, user)

/obj/structure/tripwire_alarm/attackby(obj/item/I, mob/living/human/user)
	if (istype(I, /obj/item/stack/material/rope) && istype(user))
		mechanism_rope_on_trigger(src, I, user)
		return
	return ..()

// ---- pulley block ----------------------------------------------------------------------

// Beside a trigger, it carries the trigger's cords one level up or down.
/obj/structure/mechanism_pulley
	name = "pulley block"
	desc = "A wooden sheave in a block on a post. Set it beside a lever, pull cord, plate, tripwire or clock, and cords from that trigger can run one level up or down through it."
	icon = 'icons/obj/mechanisms.dmi'
	icon_state = "pulley"
	anchored = TRUE
	density = FALSE
	not_movable = TRUE
	not_disassemblable = FALSE
	flammable = TRUE

// ---- clock alarms ------------------------------------------------------------------------

// The hour of the day, 0 to 23, from the game clock.
/proc/mechanism_hour24()
	var/exact = clock_time()
	var/hr = text2num(copytext(exact, 1, 3)) % 12
	return hr + (copytext(exact, 7) == "PM" ? 12 : 0)

// "6 AM", "12 PM" for an hour 0 to 23.
/proc/mechanism_hour_name(h24)
	var/h12 = h24 % 12
	return "[h12 ? h12 : 12] [h24 >= 12 ? "PM" : "AM"]"

// alarm: -1 off, MECHANISM_ALARM_HOURLY every hour, or the hour 0 to 23.
/proc/mechanism_alarm_name(alarm)
	if (alarm == MECHANISM_ALARM_HOURLY)
		return "every hour"
	if (alarm < 0)
		return "off"
	return "at [mechanism_hour_name(alarm)]"

// Pull the clock's cords when the hour that just struck is its alarm hour.
/proc/mechanism_clock_alarm(atom/clock, alarm, links, h24)
	if (alarm < 0 || !links)
		return 0
	if (alarm != MECHANISM_ALARM_HOURLY && alarm != h24)
		return 0
	if (alarm != MECHANISM_ALARM_HOURLY)
		clock.visible_message(SPAN_NOTICE("A striker in \the [clock] trips and its cords jerk."))
	return mechanism_pull_links(clock, links, null)

// Ask for an alarm setting; returns the new setting or null when cancelled.
/proc/mechanism_choose_alarm(mob/user, atom/clock, hourly_allowed)
	var/list/choices = list("Off" = -1)
	if (hourly_allowed)
		choices["Every hour"] = MECHANISM_ALARM_HOURLY
	for (var/h in 0 to 23)
		choices[mechanism_hour_name(h)] = h
	var/choice = player_input(user, "Pull the cords on \the [clock] when?", "Alarm", null, "anything", choices, TRUE)
	if (!choice || !(choice in choices) || QDELETED(clock) || get_dist(user, clock) > 1)
		return null
	return choices[choice]

/obj/structure/water_clock/verb/set_alarm()
	set name = "Set Alarm"
	set category = null
	set src in view(1)
	var/mob/living/human/H = usr
	if (!istype(H) || H.stat || H.restrained())
		return
	var/picked = mechanism_choose_alarm(H, src, FALSE)
	if (isnull(picked))
		return
	alarm_hour = picked
	to_chat(H, SPAN_NOTICE("You set the float striker on \the [src]: its cords pull [mechanism_alarm_name(alarm_hour)]."))

/obj/structure/tower_clock/verb/set_alarm()
	set name = "Set Alarm"
	set category = null
	set src in view(1)
	var/mob/living/human/H = usr
	if (!istype(H) || H.stat || H.restrained())
		return
	var/picked = mechanism_choose_alarm(H, src, TRUE)
	if (isnull(picked))
		return
	alarm_hour = picked
	to_chat(H, SPAN_NOTICE("You set the striking train on \the [src]: its cords pull [mechanism_alarm_name(alarm_hour)]."))

// ---- rock drop -------------------------------------------------------------------------

// A net of stones hung over a tile. A cord pull lets it go on whoever stands
// under it; it is hung up again by hand.
/obj/structure/rock_drop
	name = "rock drop"
	desc = "A rope net of stones hung from a timber frame. A cord pull from a lever, pull cord, pressure plate or tripwire lets it fall on whoever stands under it. Hang it up again with an empty hand."
	icon = 'icons/obj/mechanisms.dmi'
	icon_state = "rock_drop"
	anchored = TRUE
	density = FALSE
	not_movable = TRUE
	not_disassemblable = FALSE
	layer = 4.1
	var/loaded = TRUE

/obj/structure/rock_drop/after_load()
	..()
	update_icon()

/obj/structure/rock_drop/update_icon()
	icon_state = loaded ? "rock_drop" : "rock_drop_empty"

// Let the stones go. TRUE when it was loaded.
/obj/structure/rock_drop/proc/release()
	if (!loaded)
		return FALSE
	loaded = FALSE
	update_icon()
	playsound(get_turf(src), 'sound/effects/thud.ogg', 70, TRUE)
	visible_message(SPAN_DANGER("Stones crash down from \the [src]!"))
	for (var/mob/living/L in get_turf(src))
		if (L.stat == DEAD || isobserver(L))
			continue
		if (ishuman(L))
			var/mob/living/human/H = L
			var/zone = pick("head", "chest", "l_arm", "r_arm")
			var/blocked = H.run_armor_check(zone, "melee")
			H.apply_damage(ROCK_DROP_DAMAGE, BRUTE, zone, blocked, used_weapon = "falling stones")
			H.Weaken(2)
		else
			L.adjustBruteLoss(ROCK_DROP_DAMAGE)
		to_chat(L, SPAN_DANGER("Stones crash down on you!"))
	return TRUE

/obj/structure/rock_drop/attack_hand(mob/living/human/user)
	if (!istype(user) || !Adjacent(user))
		return ..()
	if (loaded)
		to_chat(user, SPAN_NOTICE("\The [src] is hung and ready."))
		return
	user.visible_message(SPAN_NOTICE("[user] starts hauling the stones back up into \the [src]."))
	if (!do_after(user, ROCK_DROP_RESET_TIME, src) || QDELETED(src) || loaded)
		return
	loaded = TRUE
	update_icon()
	to_chat(user, SPAN_NOTICE("You hang the stones up again."))

#undef MECHANISM_LINK_RANGE
#undef MECHANISM_MAX_LINKS
#undef MECHANISM_TIE_TIME
#undef MECHANISM_PULL_GAP
#undef ROCK_DROP_DAMAGE
#undef ROCK_DROP_RESET_TIME
#undef MECHANISM_ALARM_HOURLY
