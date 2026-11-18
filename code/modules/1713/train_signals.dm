// Signals and single-line working (docs/trains.md#signals). Two jobs off the
// train, and the means to keep two trains apart by skill.
//
// - A semaphore signal stands beside the line and speaks to trains running
//   one way. Its arm is worked by hand at the post, or by wire from a lever
//   frame. The cab crew are told what it shows as they come up to it, and a
//   train that passes it at danger is seen to do so.
// - A lever frame in a signal box works signals and switch levers up to
//   forty tiles away, joined to it with signal wire. It is interlocked: two
//   signals that face each other along a line never clear together, and a
//   switch does not move under a clear signal.
// - A single line is worked by token. Two token instruments are wired as a
//   pair and give out one token between them. A section board at each end
//   of the single line names the token a train has to carry to pass it.

#define SIGNAL_SIGHT 10 // tiles ahead at which a cab reads a signal
#define FRAME_REACH 40 // tiles of signal wire and point rodding
#define FRAME_LEVERS 8
#define TOKEN_REACH 150 // tiles of telegraph wire between two instruments
#define POINT_LOCK 10 // a clear signal this near a switch locks it

var/global/list/train_lineside = list() // signals and section boards
var/global/list/train_tokens = list()
var/global/list/train_instruments = list()

/obj/structure/trains/locomotive
	var/tmp/list/lineside_seen = null // what the cab has read and not yet passed

/obj/structure/train_lever
	var/worked_by = null // id of the lever frame that works it

/////////////////////////////////////////////////////////////////////////////
// What stands beside the line

/obj/structure/train_lineside
	name = "lineside post"
	icon = 'icons/obj/vehicles/train_platforms.dmi'
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	not_movable = TRUE
	not_disassemblable = FALSE
	flammable = FALSE
	layer = 4.1
	var/passed = 0 // times a train ran past it when it should have stopped

/obj/structure/train_lineside/New()
	..()
	train_lineside += src

/obj/structure/train_lineside/Destroy()
	train_lineside -= src
	return ..()

// How far ahead of `from` this post stands for a train heading `heading`
// (0 abreast, negative behind), or null when it is not beside that line.
/obj/structure/train_lineside/proc/ahead_of(atom/from, heading)
	if (!from || z != from.z)
		return null
	var/along
	var/aside
	switch (heading)
		if (NORTH)
			along = y - from.y
			aside = x - from.x
		if (SOUTH)
			along = from.y - y
			aside = x - from.x
		if (EAST)
			along = x - from.x
			aside = y - from.y
		if (WEST)
			along = from.x - x
			aside = y - from.y
		else
			return null
	if (abs(aside) > 2)
		return null
	return along

// TRUE when it speaks to trains running this way.
/obj/structure/train_lineside/proc/speaks_to(heading)
	return dir == heading

// What the cab crew of an engine coming up to it are told.
/obj/structure/train_lineside/proc/sighting(obj/structure/trains/locomotive/L)
	return null

// A train driven by L has run past it.
/obj/structure/train_lineside/proc/passed_by(obj/structure/trains/locomotive/L)
	return

/obj/structure/train_lineside/attackby(obj/item/W as obj, mob/user as mob)
	if (is_tool(W, TOOL_WRENCH))
		set_dir(turn(dir, -90))
		playsound(loc, 'sound/effects/lever.ogg', 40, TRUE)
		to_chat(user, "You turn \the [src]: it now speaks to trains running [dir2text(dir)].")
		return
	if (istype(W, /obj/item/train_signal_wire))
		var/obj/item/train_signal_wire/wire = W
		wire.use_on(src, user)
		return
	return ..()

/////////////////////////////////////////////////////////////////////////////
// The semaphore signal

/obj/structure/train_lineside/signal
	name = "semaphore signal"
	desc = "A signal post with a red arm. Arm level: danger, stop. Arm lowered: clear."
	icon_state = "signal_danger"
	var/clear = FALSE
	var/worked_by = null // id of the lever frame that works it

/obj/structure/train_lineside/signal/update_icon()
	icon_state = clear ? "signal_clear" : "signal_danger"

// Puts the arm to clear or to danger. TRUE when it moved.
/obj/structure/train_lineside/signal/proc/set_clear(state)
	if (!!clear == !!state)
		return FALSE
	clear = !!state
	update_icon()
	if (isturf(loc))
		playsound(loc, 'sound/effects/lever.ogg', 60, TRUE)
	return TRUE

/obj/structure/train_lineside/signal/attack_hand(mob/living/user as mob)
	if (!istype(user) || user.incapacitated())
		return
	if (worked_by && train_frame_by_id(worked_by, src))
		to_chat(user, "\The [src] is worked by wire from a signal box; its arm does not move by hand.")
		return
	set_clear(!clear)
	user.visible_message("[user] puts \the [src] to [clear ? "clear" : "danger"].", "You put \the [src] to [clear ? "clear" : "danger"].")

/obj/structure/train_lineside/signal/sighting(obj/structure/trains/locomotive/L)
	return clear ? "The signal ahead shows clear." : SPAN_WARNING("The signal ahead is at danger.")

/obj/structure/train_lineside/signal/passed_by(obj/structure/trains/locomotive/L)
	if (clear)
		return
	passed++
	if (L && isturf(L.loc))
		L.visible_message(SPAN_DANGER("\The [L] runs past \the [src] at danger!"))
	var/obj/structure/train_lever_frame/F = worked_by ? train_frame_by_id(worked_by, src) : null
	if (F && isturf(F.loc))
		F.visible_message(SPAN_WARNING("A bell rings at \the [F]: a train has passed a signal at danger."))
		playsound(F.loc, 'sound/effects/lever.ogg', 60, TRUE)

/obj/structure/train_lineside/signal/examine(mob/user)
	..()
	to_chat(user, "It speaks to trains running [dir2text(dir)] and shows [clear ? "clear" : "danger"]. A wrench turns it.")
	if (worked_by && train_frame_by_id(worked_by, src))
		to_chat(user, "It is worked by wire from a signal box.")
	if (passed)
		to_chat(user, "It has been passed at danger [passed] time\s.")

/////////////////////////////////////////////////////////////////////////////
// The lever frame

// The lever frame with this id within reach of O, or null.
/proc/train_frame_by_id(id, atom/O)
	if (!id || !O)
		return null
	for (var/obj/structure/train_lever_frame/F in range(FRAME_REACH, O))
		if (F.frame_id == id)
			return F
	return null

/obj/structure/train_lever_frame
	name = "lever frame"
	desc = "A row of long levers in an iron frame. Each works a signal or a switch at a distance, by wire or by rodding."
	icon = 'icons/obj/vehicles/train_platforms.dmi'
	icon_state = "lever_frame"
	anchored = TRUE
	density = TRUE
	opacity = FALSE
	not_movable = TRUE
	not_disassemblable = FALSE
	flammable = FALSE
	var/frame_id = null
	var/tmp/list/levers = null // the signals and switch levers it works

/obj/structure/train_lever_frame/proc/id()
	if (!frame_id)
		frame_id = "[rand(1, 9999999)]"
	return frame_id

// The signals and switch levers wired to this frame: signals first.
/obj/structure/train_lever_frame/proc/worked()
	if (levers)
		for (var/atom/A in levers)
			if (QDELETED(A) || get_dist(A, src) > FRAME_REACH)
				levers = null
				break
	if (!levers)
		levers = list()
		if (frame_id)
			for (var/obj/structure/train_lineside/signal/S in train_lineside)
				if (S.worked_by == frame_id && S.z == z && get_dist(S, src) <= FRAME_REACH)
					levers += S
			for (var/obj/structure/train_lever/V in range(FRAME_REACH, src))
				if (V.worked_by == frame_id)
					levers += V
	return levers

// Wires a signal or a switch lever to the frame, or takes it off again.
// Returns a line for whoever did it.
/obj/structure/train_lever_frame/proc/wire(atom/A)
	if (!istype(A, /obj/structure/train_lineside/signal) && !istype(A, /obj/structure/train_lever))
		return null
	var/obj/structure/train_lineside/signal/S = istype(A, /obj/structure/train_lineside/signal) ? A : null
	var/obj/structure/train_lever/V = S ? null : A
	var/theirs = S ? S.worked_by : V.worked_by
	if (theirs == id())
		if (S)
			S.worked_by = null
		else
			V.worked_by = null
		levers = null
		return "You take \the [A] off \the [src]. It is worked by hand again."
	if (A.z != z || get_dist(A, src) > FRAME_REACH)
		return "\The [A] is too far from \the [src]: the wire reaches [FRAME_REACH] tiles."
	var/list/now = worked()
	if (now.len >= FRAME_LEVERS)
		return "\The [src] has no lever to spare: it works [FRAME_LEVERS]."
	if (S)
		S.worked_by = frame_id
	else
		V.worked_by = frame_id
	levers = null
	return "You wire \the [A] to \the [src]. It is worked from the frame now."

// What a lever is called at the frame.
/obj/structure/train_lever_frame/proc/lever_label(atom/A)
	var/where = (A.loc == loc) ? "here" : "[get_dist(A, src)] tile\s [dir2text(get_dir(src, A))]"
	if (istype(A, /obj/structure/train_lineside/signal))
		var/obj/structure/train_lineside/signal/S = A
		return "signal [where], for trains running [dir2text(S.dir)]: [S.clear ? "clear" : "danger"]"
	var/obj/structure/train_lever/V = A
	return "switch [where]: [V.switched == "forward" ? "straight on" : "set for the branch"]"

// Two signals that face each other along one line: a train that passes the
// first meets the back of nothing, and the face of the second's train.
/proc/train_signals_oppose(obj/structure/train_lineside/signal/A, obj/structure/train_lineside/signal/B)
	if (!A || !B || A == B || B.dir != OPPOSITE_DIR(A.dir))
		return FALSE
	var/ahead = B.ahead_of(A, A.dir)
	return !isnull(ahead) && ahead > 0

// Why the interlocking holds a lever, or null when it is free to move.
/obj/structure/train_lever_frame/proc/locked_by(atom/A)
	var/list/now = worked()
	if (istype(A, /obj/structure/train_lineside/signal))
		var/obj/structure/train_lineside/signal/S = A
		if (S.clear)
			return null // a signal always goes back to danger
		for (var/obj/structure/train_lineside/signal/other in now)
			if (other.clear && train_signals_oppose(S, other))
				return "the signal for trains running [dir2text(other.dir)] on the same line is clear"
		return null
	for (var/obj/structure/train_lineside/signal/S in now)
		if (S.clear && get_dist(S, A) <= POINT_LOCK)
			return "the signal [get_dist(S, src)] tile\s [dir2text(get_dir(src, S))] is clear over it"
	return null

// Pulls or restores one lever. TRUE when it moved.
/obj/structure/train_lever_frame/proc/pull(atom/A, mob/user)
	if (!A || QDELETED(A) || !(A in worked()))
		return FALSE
	var/why = locked_by(A)
	if (why)
		if (user)
			to_chat(user, SPAN_WARNING("The lever is locked: [why]."))
		return FALSE
	if (istype(A, /obj/structure/train_lineside/signal))
		var/obj/structure/train_lineside/signal/S = A
		S.set_clear(!S.clear)
	else
		var/obj/structure/train_lever/V = A
		V.throw_switch(V.switched == "forward" ? "split" : "forward")
	if (isturf(loc))
		playsound(loc, 'sound/effects/lever.ogg', 80, TRUE)
	if (user)
		user.visible_message("[user] pulls a lever of \the [src].", "You pull the lever: [lever_label(A)].")
	return TRUE

/obj/structure/train_lever_frame/attack_hand(mob/living/user as mob)
	if (!istype(user) || user.incapacitated())
		return
	var/list/now = worked()
	if (!now.len)
		to_chat(user, "No signal or switch is wired to \the [src]. Use signal wire on the frame, then on each signal and switch lever it is to work.")
		return
	var/list/choices = list()
	var/n = 0
	for (var/atom/A in now)
		n++
		choices["[n]. [lever_label(A)]"] = A
	var/choice = player_input(user, "Which lever?", "[name]", null, "anything", choices, TRUE)
	if (!choice || QDELETED(src) || user.incapacitated() || get_dist(user, src) > 1)
		return
	pull(choices[choice], user)

/obj/structure/train_lever_frame/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/train_signal_wire))
		var/obj/item/train_signal_wire/wire = W
		wire.use_on(src, user)
		return
	return ..()

/obj/structure/train_lever_frame/examine(mob/user)
	..()
	var/list/now = worked()
	if (!now.len)
		to_chat(user, "Nothing is wired to it yet. It works up to [FRAME_LEVERS] signals and switches within [FRAME_REACH] tiles.")
		return
	var/n = 0
	for (var/atom/A in now)
		n++
		to_chat(user, "[n]. [lever_label(A)]")
		if (istype(A, /obj/structure/train_lineside/signal))
			var/obj/structure/train_lineside/signal/S = A
			if (S.passed)
				to_chat(user, SPAN_WARNING("   It has been passed at danger [S.passed] time\s."))

/////////////////////////////////////////////////////////////////////////////
// Signal wire

/obj/item/train_signal_wire
	name = "coil of signal wire"
	desc = "Iron wire for a signal box. Use it on a lever frame, then on each signal and switch lever the frame is to work. Use it on a token instrument, then on its partner and on the section boards of their single line."
	icon = 'icons/obj/vehicles/train_platforms.dmi'
	icon_state = "signal_wire"
	w_class = 2
	force = 2
	throwforce = 2
	var/tmp/atom/run_from = null // the frame or instrument the wire is run from

// Runs the wire to O. Returns the line for whoever holds it, or null when O
// takes no wire.
/obj/item/train_signal_wire/proc/run_to(atom/O)
	if (run_from && QDELETED(run_from))
		run_from = null
	if (istype(O, /obj/structure/train_lever_frame))
		run_from = O
		return "You make the wire fast to \the [O]. Now use it on a signal or a switch lever."
	if (istype(O, /obj/structure/train_token_instrument))
		var/obj/structure/train_token_instrument/I = O
		var/obj/structure/train_token_instrument/other = run_from
		if (istype(other) && other != I)
			run_from = I
			return other.pair_with(I)
		run_from = I
		return "You make the wire fast to \the [I]. Now use it on the instrument at the other end of the single line, or on a section board."
	if (istype(O, /obj/structure/train_lineside/board))
		var/obj/structure/train_lineside/board/B = O
		var/obj/structure/train_token_instrument/I = run_from
		if (!istype(I) || !I.section)
			return "Run the wire from a paired token instrument first."
		B.section = I.section
		B.update_board()
		return "You mark \the [B] for [train_section_name(I.section)]."
	if (istype(O, /obj/structure/train_lineside/signal) || istype(O, /obj/structure/train_lever))
		var/obj/structure/train_lever_frame/F = run_from
		if (!istype(F))
			return "Run the wire from a lever frame first."
		return F.wire(O)
	return null

// TRUE when the wire had something to do with O.
/obj/item/train_signal_wire/proc/use_on(atom/O, mob/user)
	var/line = run_to(O)
	if (!line)
		return FALSE
	if (user)
		playsound(user.loc, 'sound/effects/lever.ogg', 30, TRUE)
		to_chat(user, line)
	return TRUE

/////////////////////////////////////////////////////////////////////////////
// Single-line tokens

/proc/train_section_name(section)
	return section ? "single line [section]" : "no single line"

// The token of a section that is out of its instruments, or null.
/proc/train_token_out(section)
	if (!section)
		return null
	for (var/obj/item/train_token/T in train_tokens)
		if (!QDELETED(T) && T.section == section)
			return T
	return null

/obj/item/train_token
	name = "single-line token"
	desc = "A brass token from a token instrument. The engine that carries it has the single line to itself."
	icon = 'icons/obj/vehicles/train_platforms.dmi'
	icon_state = "train_token"
	w_class = 1
	force = 1
	throwforce = 1
	var/section = null

/obj/item/train_token/New()
	..()
	train_tokens += src

/obj/item/train_token/Destroy()
	train_tokens -= src
	return ..()

/obj/item/train_token/proc/update_token()
	name = "token for [train_section_name(section)]"

/obj/item/train_token/examine(mob/user)
	..()
	to_chat(user, "It is engraved: [train_section_name(section)]. Give it up at the token instrument at either end.")

/obj/structure/train_token_instrument
	name = "token instrument"
	desc = "A cast iron cabinet with a needle, a bell and a slot for brass tokens. It is wired to the instrument at the other end of a single line, and the two give out one token between them."
	icon = 'icons/obj/vehicles/train_platforms.dmi'
	icon_state = "token_instrument"
	anchored = TRUE
	density = TRUE
	opacity = FALSE
	not_movable = TRUE
	not_disassemblable = FALSE
	flammable = FALSE
	var/section = null // the single line it belongs to, shared with its partner

/obj/structure/train_token_instrument/New()
	..()
	train_instruments += src

/obj/structure/train_token_instrument/Destroy()
	train_instruments -= src
	return ..()

// The instrument at the other end of the single line, or null.
/obj/structure/train_token_instrument/proc/partner()
	if (!section)
		return null
	for (var/obj/structure/train_token_instrument/I in train_instruments)
		if (I != src && !QDELETED(I) && I.section == section && I.z == z)
			return I
	return null

// Wires this instrument and I as the two ends of one single line.
/obj/structure/train_token_instrument/proc/pair_with(obj/structure/train_token_instrument/I)
	if (!I || I == src)
		return null
	if (I.z != z || get_dist(I, src) > TOKEN_REACH)
		return "\The [I] is too far away: the wire reaches [TOKEN_REACH] tiles."
	if (train_token_out(section) || train_token_out(I.section))
		return "A token is out. Put it back in its instrument before the wires are changed."
	if (section && section == I.section)
		return "The two are wired as a pair already, for [train_section_name(section)]."
	if (partner() || I.partner())
		return "One of the two is wired to another instrument already. Build new ones for a new single line."
	if (!section)
		section = I.section ? I.section : "[rand(100, 9999)]"
	I.section = section
	return "You wire the two instruments as a pair. They hold the token for [train_section_name(section)]."

// Draws the token. Returns it, or null when the instruments hold none.
/obj/structure/train_token_instrument/proc/draw_token(mob/user)
	if (!section || !partner())
		if (user)
			to_chat(user, "\The [src] is not wired to an instrument at the other end of the line. Use signal wire on one, then on the other.")
		return null
	if (train_token_out(section))
		if (user)
			to_chat(user, SPAN_WARNING("The needle of \the [src] shows a train in the section: the token is out, and no second one comes."))
		return null
	var/obj/item/train_token/T = new(loc)
	T.section = section
	T.update_token()
	ring("The token for [train_section_name(section)] is drawn")
	if (user)
		user.put_in_hands(T)
		to_chat(user, "You draw the token for [train_section_name(section)].")
	return T

// Takes the token back. TRUE when the section is clear again.
/obj/structure/train_token_instrument/proc/restore_token(obj/item/train_token/T, mob/user)
	if (!istype(T))
		return FALSE
	if (!section || T.section != section)
		if (user)
			to_chat(user, "\The [T] does not fit \the [src]: it belongs to [train_section_name(T.section)].")
		return FALSE
	if (user)
		user.drop_from_inventory(T)
		to_chat(user, "You put the token back in \the [src]. The single line is clear.")
	qdel(T)
	ring("The token for [train_section_name(section)] is back in")
	return TRUE

// The bell of this instrument and of its partner.
/obj/structure/train_token_instrument/proc/ring(what)
	for (var/obj/structure/train_token_instrument/I in list(src, partner()))
		if (!isturf(I.loc))
			continue
		playsound(I.loc, 'sound/effects/lever.ogg', 60, TRUE)
		I.visible_message("The bell of \the [I] rings. [what].")

/obj/structure/train_token_instrument/attack_hand(mob/living/user as mob)
	if (!istype(user) || user.incapacitated())
		return
	draw_token(user)

/obj/structure/train_token_instrument/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/train_token))
		restore_token(W, user)
		return
	if (istype(W, /obj/item/train_signal_wire))
		var/obj/item/train_signal_wire/wire = W
		wire.use_on(src, user)
		return
	return ..()

/obj/structure/train_token_instrument/examine(mob/user)
	..()
	if (!section || !partner())
		to_chat(user, "It is not wired to an instrument at the other end of a single line.")
		return
	to_chat(user, "It works [train_section_name(section)]. [train_token_out(section) ? "The needle shows a train in the section: the token is out." : "The needle shows the line clear: the token is in."]")

// A section board: the start of a single line, for trains running its way.
/obj/structure/train_lineside/board
	name = "section board"
	desc = "A board beside the line where a single line begins. No train passes it without the token of the section."
	icon_state = "section_board"
	var/section = null

/obj/structure/train_lineside/board/proc/update_board()
	name = section ? "section board ([train_section_name(section)])" : "section board"

/obj/structure/train_lineside/board/sighting(obj/structure/trains/locomotive/L)
	if (!section)
		return null
	if (L && L.carries_token(section))
		return "The board ahead begins [train_section_name(section)]. Its token is on the engine."
	return SPAN_WARNING("The board ahead begins [train_section_name(section)], and its token is not on the engine.")

/obj/structure/train_lineside/board/passed_by(obj/structure/trains/locomotive/L)
	if (!section || !L || L.carries_token(section))
		return
	passed++
	if (isturf(L.loc))
		L.visible_message(SPAN_DANGER("\The [L] enters [train_section_name(section)] without its token!"))

/obj/structure/train_lineside/board/examine(mob/user)
	..()
	to_chat(user, "It speaks to trains running [dir2text(dir)]. [section ? "It begins [train_section_name(section)]." : "It is blank: use signal wire on a paired token instrument, then on the board."] A wrench turns it.")
	if (passed)
		to_chat(user, "It has been passed without the token [passed] time\s.")

/////////////////////////////////////////////////////////////////////////////
// From the engine

// The tiles of every section of this engine.
/obj/structure/trains/locomotive/proc/engine_tiles()
	. = list()
	if (!isturf(loc))
		return
	. |= train_platform_tiles(loc, dir)
	if (!car_id)
		return
	for (var/obj/structure/trains/TR in range(body_length(), src))
		if (TR.car_id == car_id && isturf(TR.loc))
			. |= train_platform_tiles(TR.loc, TR.dir)

// The people standing in the cabs of the engines of this train.
/obj/structure/trains/locomotive/proc/cab_crew()
	. = list()
	for (var/obj/structure/trains/locomotive/L in train_consist_list(train_head()))
		for (var/obj/structure/trains/S in list(L.control_spot(), L.rear_cab()))
			if (!isturf(S.loc))
				continue
			for (var/turf/T in train_platform_tiles(S.loc, S.dir))
				for (var/mob/living/human/H in T)
					. |= H

// TRUE when the token of a section is on an engine of this train: in a
// pocket, in a hand or lying on its footplate.
/obj/structure/trains/locomotive/proc/carries_token(section)
	var/list/tiles = null
	for (var/obj/item/train_token/T in train_tokens)
		if (QDELETED(T) || T.section != section)
			continue
		var/turf/where = get_turf(T)
		if (!where || where.z != z)
			continue
		if (!tiles)
			tiles = list()
			for (var/obj/structure/trains/locomotive/L in train_consist_list(train_head()))
				tiles |= L.engine_tiles()
		if (where in tiles)
			return TRUE
	return FALSE

// Looked at from the drive loop (trains.dm) when the train starts and each
// time it is counted: reads the signals and boards coming up, and marks the
// ones just passed. Returns how many were passed.
/obj/structure/trains/locomotive/proc/lineside_watch()
	. = 0
	if (!train_lineside.len)
		lineside_seen = null
		return
	var/way = train_way()
	var/obj/structure/trains/lead = (way > 0) ? drive_head : drive_tail
	if (!lead || QDELETED(lead) || !isturf(lead.loc))
		lead = src
	var/heading = (way > 0) ? lead.train_heading() : OPPOSITE_DIR(lead.train_heading())
	var/list/now = list()
	var/list/crew = null
	for (var/obj/structure/train_lineside/S in train_lineside)
		if (!S.speaks_to(heading) || !isturf(S.loc))
			continue
		var/ahead = S.ahead_of(lead, heading)
		if (isnull(ahead))
			continue
		if (ahead > 0 && ahead <= SIGNAL_SIGHT)
			now += S
			if (!lineside_seen || !(S in lineside_seen))
				var/line = S.sighting(src)
				if (line)
					if (!crew)
						crew = cab_crew()
					for (var/mob/M in crew)
						to_chat(M, line)
		else if (ahead <= 0 && lineside_seen && (S in lineside_seen))
			S.passed_by(src)
			.++
	lineside_seen = now.len ? now : null

#undef SIGNAL_SIGHT
#undef FRAME_REACH
#undef FRAME_LEVERS
#undef TOKEN_REACH
#undef POINT_LOCK
