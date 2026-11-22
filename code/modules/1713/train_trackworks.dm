// Track works (docs/trains.md#track-works): what is built at the lineside
// to end a line and to cross it.
//
// - A buffer stop is bolted to the last tile of rails. It is solid to
//   trains: a slow train comes to rest against it, a harder blow it still
//   holds, and a train at speed smashes it and is wrecked (rail_hit() in
//   trains.dm asks hold()).
// - A level crossing is boards laid between the rails where a road crosses,
//   and a gate on the road at each side. The gates of one crossing swing
//   together: shut across the road they are solid, open they leave the road
//   clear. They are worked by hand, or by a lever of a lever frame
//   (train_signals.dm), which interlocks them with its signals. Cab crews
//   are told how the gates ahead stand.

#define TRAIN_BUFFER_HOLD 1.25 // the hardest blow (collision_impact()) a buffer stop takes
#define TRAIN_GATE_TIME 20
#define TRAIN_GATE_REACH 4 // gates this near each other belong to one crossing

/////////////////////////////////////////////////////////////////////////////
// Buffer stop

/obj/structure/train_buffer_stop
	name = "buffer stop"
	desc = "A heavy timber beam on a frame of rail, bolted across the end of a line. A train that comes up to it slowly stops against it."
	icon = 'icons/obj/vehicles/train_platforms.dmi'
	icon_state = "buffer_stop"
	anchored = TRUE
	density = TRUE
	opacity = FALSE
	not_movable = TRUE
	not_disassemblable = FALSE
	flammable = FALSE
	layer = 2.7
	var/hits = 0 // hard blows it has taken

// TRUE when it takes a blow of this impact and stands.
/obj/structure/train_buffer_stop/proc/hold(impact)
	if (impact > TRAIN_BUFFER_HOLD)
		return FALSE
	if (impact >= 0.5)
		hits++
	return TRUE

// Broken up by a train it could not hold: the rails stay, the stop is scrap.
/obj/structure/train_buffer_stop/proc/smash()
	var/turf/T = get_turf(src)
	if (T)
		visible_message(SPAN_DANGER("\The [src] is smashed to pieces!"))
		new /obj/item/stack/material/iron(T)
	qdel(src)

/obj/structure/train_buffer_stop/ex_act(severity)
	if (severity <= 2)
		smash()

/obj/structure/train_buffer_stop/attackby(obj/item/W as obj, mob/user as mob)
	if (is_tool(W, TOOL_WRENCH))
		set_dir(turn(dir, -90))
		playsound(loc, 'sound/items/Ratchet.ogg', 50, TRUE)
		to_chat(user, "You turn \the [src]: its beam now faces trains coming from the [dir2text(OPPOSITE_DIR(dir))].")
		return
	return ..()

/obj/structure/train_buffer_stop/examine(mob/user)
	..()
	to_chat(user, "It ends a line running [dir2text(dir)]. [(isturf(loc) && rail_at(loc)) ? "It is bolted to the rails." : "It stands on bare ground: set it on the last tile of rails."] A wrench turns it.")
	if (hits)
		to_chat(user, "Its beam is scarred by [hits] hard blow\s.")

/////////////////////////////////////////////////////////////////////////////
// Level crossing

/obj/structure/train_crossing_boards
	name = "crossing boards"
	desc = "Thick boards laid between and beside the rails, level with their heads, so that a road can cross the line."
	icon = 'icons/obj/vehicles/train_platforms.dmi'
	icon_state = "crossing_boards"
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	not_movable = TRUE
	not_disassemblable = FALSE
	layer = 2.55

/obj/structure/train_crossing_boards/attackby(obj/item/W as obj, mob/user as mob)
	if (is_tool(W, TOOL_WRENCH))
		set_dir(turn(dir, -90))
		playsound(loc, 'sound/items/Ratchet.ogg', 50, TRUE)
		to_chat(user, "You turn \the [src] to lie along a line running [dir2text(dir)].")
		return
	return ..()

// A gate on the road beside the line. dir is the way from the gate to the
// rails: the road runs that way through its tile.
/obj/structure/train_lineside/gate
	name = "crossing gate"
	desc = "A long white gate with a red disc, hung on a post beside a level crossing."
	icon_state = "crossing_gate_open"
	layer = 3.2
	var/shut = FALSE // across the road
	var/worked_by = null // id of the lever frame that works it
	var/tmp/busy = FALSE

/obj/structure/train_lineside/gate/persistence_runtime_var(key)
	return key == "busy" || ..(key)

/obj/structure/train_lineside/gate/after_load()
	..()
	busy = FALSE
	update_icon()

/obj/structure/train_lineside/gate/update_icon()
	icon_state = shut ? "crossing_gate_shut" : "crossing_gate_open"
	density = !!shut

// It tells trains either way, whichever side of the line it stands.
/obj/structure/train_lineside/gate/speaks_to(heading)
	return heading == turn(dir, 90) || heading == turn(dir, -90)

// The gates of this crossing, itself first.
/obj/structure/train_lineside/gate/proc/crossing_gates()
	var/list/gates = list(src)
	for (var/obj/structure/train_lineside/gate/G in train_lineside)
		if (G != src && !QDELETED(G) && G.z == z && get_dist(G, src) <= TRAIN_GATE_REACH)
			gates += G
	return gates

// The one gate of the crossing that speaks for it: only one line is said to
// a cab, and only one passing is counted.
/obj/structure/train_lineside/gate/proc/speaks_for_crossing()
	for (var/obj/structure/train_lineside/gate/G in crossing_gates())
		if ("\ref[G]" < "\ref[src]")
			return FALSE
	return TRUE

// The lever frame that works this crossing, or null.
/obj/structure/train_lineside/gate/proc/crossing_frame()
	for (var/obj/structure/train_lineside/gate/G in crossing_gates())
		var/obj/structure/train_lever_frame/F = G.worked_by ? train_frame_by_id(G.worked_by, G) : null
		if (F)
			return F
	return null

// Swings every gate of the crossing. TRUE when they moved.
/obj/structure/train_lineside/gate/proc/set_shut(state)
	. = FALSE
	for (var/obj/structure/train_lineside/gate/G in crossing_gates())
		if (!!G.shut == !!state)
			continue
		G.shut = !!state
		G.update_icon()
		. = TRUE
	if (. && isturf(loc))
		playsound(loc, 'sound/effects/lever.ogg', 60, TRUE)

// Why the gates cannot swing across the road now, or null.
/obj/structure/train_lineside/gate/proc/shut_problem()
	for (var/obj/structure/train_lineside/gate/G in crossing_gates())
		for (var/atom/movable/AM in G.loc)
			if (AM != G && AM.density && !istype(AM, /obj/structure/train_lineside))
				return "\The [AM] stands in the way of \the [G]."
			if (isliving(AM))
				return "[AM] stands in the way of \the [G]."
	return null

/obj/structure/train_lineside/gate/attack_hand(mob/living/user as mob)
	if (!istype(user) || user.incapacitated() || busy)
		return
	if (crossing_frame())
		to_chat(user, "\The [src] is worked by rodding from a signal box; it does not swing by hand.")
		return
	var/state = !shut
	var/problem = state ? shut_problem() : null
	if (problem)
		to_chat(user, SPAN_WARNING(problem))
		return
	busy = TRUE
	user.visible_message("[user] starts to swing \the [src] [state ? "across the road" : "clear of the road"].", "You start to swing the crossing gates [state ? "across the road" : "clear of the road"].")
	var/done = do_after(user, TRAIN_GATE_TIME, src)
	busy = FALSE
	if (!done || QDELETED(src) || crossing_frame() || (state && shut_problem()))
		return
	if (set_shut(state))
		user.visible_message("[user] swings the crossing gates [state ? "shut across the road" : "open to the road"].", "You swing the crossing gates [state ? "shut across the road" : "open to the road"].")

/obj/structure/train_lineside/gate/attackby(obj/item/W as obj, mob/user as mob)
	if (is_tool(W, TOOL_WRENCH))
		if (shut)
			to_chat(user, SPAN_WARNING("Open \the [src] to the road before you turn its post."))
			return
		set_dir(turn(dir, -90))
		playsound(loc, 'sound/effects/lever.ogg', 40, TRUE)
		to_chat(user, "You turn \the [src]: the rails are now to its [dir2text(dir)].")
		return
	return ..()

/obj/structure/train_lineside/gate/sighting(obj/structure/trains/locomotive/L)
	if (!speaks_for_crossing())
		return null
	return shut ? "The level crossing ahead is shut to the road." : SPAN_WARNING("The gates of the level crossing ahead stand open to the road.")

/obj/structure/train_lineside/gate/passed_by(obj/structure/trains/locomotive/L)
	if (shut || !speaks_for_crossing())
		return
	passed++
	if (L && isturf(L.loc))
		L.visible_message(SPAN_WARNING("\The [L] runs over the level crossing with its gates open to the road!"))

/obj/structure/train_lineside/gate/examine(mob/user)
	..()
	to_chat(user, "The rails are to its [dir2text(dir)], and it wants a clear tile between it and them for the sides of wide cars. It stands [shut ? "shut across the road" : "open to the road"], with the other gates within [TRAIN_GATE_REACH] tiles of it. A wrench turns its post.")
	if (crossing_frame())
		to_chat(user, "It is worked by rodding from a signal box.")
	if (passed)
		to_chat(user, "A train has run over this crossing with the gates open to the road [passed] time\s.")

#undef TRAIN_BUFFER_HOLD
#undef TRAIN_GATE_TIME
#undef TRAIN_GATE_REACH
