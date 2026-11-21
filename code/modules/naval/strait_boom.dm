// Strait booms (docs/ocean-regions.md, "Straits"). A winch on a shore and
// a chain of iron floats laid across the water to the far shore. Raised, the
// boom stops every hull; a ship's master pays the toll at the winch and it
// drops for STRAIT_BOOM_OPEN. A ship at full speed can ram it: the segment
// she hits breaks and her bow is holed. A crew can also cut a segment from a
// boat with a hatchet or knife, which takes minutes.
//
// No references are kept: a winch finds its boom by walking from its own
// tile in its own direction while the tiles hold its segments, so a save and
// restore need nothing special. Lowered boom times run on world.time, and a
// boom loaded lowered is raised again.
//
// On lands with provinces, a boom may only be laid where no other side holds
// the province (province_holding.dm): a strait belongs to whoever holds its
// shore.

#define STRAIT_BOOM_MAX 60 // tiles of water one winch can span
#define STRAIT_BOOM_OPEN 600 // a paid toll drops the boom for a minute
#define STRAIT_BOOM_CUT 1800 // three minutes to cut a segment
#define STRAIT_BOOM_LAY 20 // per segment laid
#define STRAIT_NOTICE_RADIUS 14

/obj/structure/strait_boom
	name = "strait boom"
	desc = "Iron-bound logs chained end to end across the water. Raised, nothing gets past. Pay the toll at its winch, ram it at full speed, or cut it from a boat."
	icon = 'icons/obj/strait_booms.dmi'
	icon_state = "boom"
	anchored = TRUE
	density = TRUE
	not_movable = TRUE
	not_disassemblable = TRUE
	layer = 2.9
	var/broken = FALSE
	var/lowered = FALSE
	var/tmp/cutting = FALSE

// A hull passing over a lowered boom leaves it where it lies.
/obj/structure/strait_boom/craft_left_behind()
	return TRUE

/obj/structure/strait_boom/New(loc, ndir)
	..()
	if (ndir)
		set_dir(ndir)
	update_state()

/obj/structure/strait_boom/after_load()
	..()
	// A timer does not outlive a save: a lowered boom comes back raised.
	if (lowered && !broken)
		lowered = FALSE
	update_state()

/obj/structure/strait_boom/proc/update_state()
	density = !broken && !lowered
	icon_state = broken ? "boom_broken" : (lowered ? "boom_lowered" : "boom")
	layer = density ? 2.9 : 2.05

/obj/structure/strait_boom/proc/raised()
	return !broken && !lowered

/obj/structure/strait_boom/proc/break_segment()
	if (broken)
		return
	broken = TRUE
	lowered = FALSE
	update_state()
	visible_message(SPAN_DANGER("The chain of \the [src] parts with a crack!"))

/obj/structure/strait_boom/examine(mob/user)
	..()
	if (broken)
		to_chat(user, SPAN_WARNING("This segment is broken. Its winch's owner can mend it with iron."))
	else if (lowered)
		to_chat(user, SPAN_NOTICE("It is lowered: ships can pass over it."))

// Cut a segment from a boat (or a shore): a hatchet or a knife, and time.
/obj/structure/strait_boom/attackby(obj/item/W, mob/user)
	if (!ishuman(user) || broken || !(is_tool(W, TOOL_HATCHET) || is_tool(W, TOOL_KNIFE)))
		return ..()
	if (cutting)
		to_chat(user, SPAN_WARNING("Someone is already cutting \the [src]."))
		return
	cutting = TRUE
	user.visible_message(SPAN_WARNING("[user] starts hacking at the chain of \the [src]."), SPAN_NOTICE("You start cutting through \the [src]. It will take a few minutes."))
	var/ok = do_after(user, STRAIT_BOOM_CUT, src)
	cutting = FALSE
	if (!ok || QDELETED(src) || broken)
		return
	break_segment()

// ---- The winch ----

/obj/structure/strait_winch
	name = "boom winch"
	desc = "A capstan and chain drum set on a shore, for a boom across the water in front of it. Use iron on it to lay or mend the boom, money to pay its toll."
	icon = 'icons/obj/strait_booms.dmi'
	icon_state = "winch"
	anchored = TRUE
	density = TRUE
	not_movable = TRUE
	not_disassemblable = FALSE
	var/owner_ckey = null
	var/owner_civ = null
	var/toll = 0 // in money value; 0 lets anyone lower it
	var/tmp/busy = FALSE
	var/tmp/raise_timer = 0

/obj/structure/strait_winch/New(loc)
	..()
	// A winch is built facing the water from where its builder stood.
	if (ishuman(usr) && !owner_ckey)
		var/mob/living/human/H = usr
		owner_ckey = H.ckey
		owner_civ = H.civilization
		if (!H.Adjacent(src) || get_dir(H, src) == 0)
			set_dir(H.dir)
		else
			set_dir(get_dir(H, src))

/obj/structure/strait_winch/Destroy()
	for (var/obj/structure/strait_boom/B in segments())
		qdel(B)
	return ..()

/obj/structure/strait_winch/examine(mob/user)
	..()
	var/list/S = segments()
	if (!S.len)
		to_chat(user, SPAN_NOTICE("No boom is laid from it yet. Use iron on it: one sheet for every tile of water to the far shore."))
		return
	var/up = boom_raised()
	to_chat(user, SPAN_NOTICE("Its boom runs [S.len] tiles and is [up ? "raised" : "lowered"]. [toll > 0 ? "The toll is [toll]." : "There is no toll: anyone may lower it."]"))
	if (strait_boom_broken_count(S))
		to_chat(user, SPAN_WARNING("[strait_boom_broken_count(S)] of its segments are broken."))

/proc/strait_boom_broken_count(list/S)
	. = 0
	for (var/obj/structure/strait_boom/B in S)
		if (B.broken)
			.++

// Its segments, from the winch outwards.
/obj/structure/strait_winch/proc/segments()
	. = list()
	var/turf/T = get_turf(src)
	for (var/i = 1 to STRAIT_BOOM_MAX)
		T = T ? get_step(T, dir) : null
		if (!T)
			break
		var/obj/structure/strait_boom/B = locate() in T
		if (!B)
			break
		. += B

/obj/structure/strait_winch/proc/boom_raised()
	for (var/obj/structure/strait_boom/B in segments())
		if (B.raised())
			return TRUE
	return FALSE

// The water a boom from here would span: a list of turfs, or a reason.
/obj/structure/strait_winch/proc/span()
	. = list()
	var/turf/T = get_turf(src)
	for (var/i = 1 to STRAIT_BOOM_MAX + 1)
		T = T ? get_step(T, dir) : null
		if (!T)
			return "the water runs off the edge of the world"
		if (!istype(T, /turf/floor/beach/water))
			return length(.) ? . : "there is no water in front of it"
		. += T
	return "the far shore is more than [STRAIT_BOOM_MAX] tiles away"

// Why H may not lay or mend a boom from here, or null.
/obj/structure/strait_winch/proc/lay_refusal(mob/living/human/H)
	if (owner_ckey && H.ckey != owner_ckey && (!owner_civ || owner_civ == "none" || H.civilization != owner_civ))
		return "it is not your winch"
	return strait_province_refusal(H, get_turf(src))

// On a land with provinces, a boom goes only where no other side holds the shore.
/proc/strait_province_refusal(mob/living/human/H, turf/T)
	if (!map || !T)
		return null
	var/datum/province_map/P = map.province_map()
	if (!P)
		return null
	var/c = P.char_at(T.x, T.y)
	var/holder = c ? province_holder_of(c) : null
	if (!holder)
		return null
	if (!H.civilization || H.civilization == "none" || province_group_of(H.civilization) != holder)
		return "[province_group_name(holder)] holds the [P.names[c]]; only its holder may boom its waters"
	return null

/obj/structure/strait_winch/attackby(obj/item/W, mob/user)
	if (!ishuman(user) || !Adjacent(user))
		return ..()
	var/mob/living/human/H = user
	if (istype(W, /obj/item/stack/material/iron))
		lay(H, W)
		return
	if (istype(W, /obj/item/stack/money))
		pay(H, W)
		return
	return ..()

// The tiles that need a segment laid or mended, or why none can be.
/obj/structure/strait_winch/proc/lay_todo()
	var/list/water = span()
	if (!islist(water))
		return water
	. = list()
	for (var/turf/T in water)
		var/obj/structure/strait_boom/B = locate() in T
		if (!B || B.broken)
			. += T

/obj/structure/strait_winch/proc/lay_segments(list/todo)
	for (var/turf/T in todo)
		var/obj/structure/strait_boom/B = locate() in T
		if (B)
			B.broken = FALSE
			B.lowered = FALSE
			B.update_state()
		else
			new /obj/structure/strait_boom(T, dir)

// Lays the boom across to the far shore, or mends its broken segments. One
// iron for each segment laid or mended.
/obj/structure/strait_winch/proc/lay(mob/living/human/H, obj/item/stack/material/iron/W)
	if (busy)
		return
	var/refusal = lay_refusal(H)
	if (refusal)
		to_chat(H, SPAN_WARNING("You cannot lay a boom here: [refusal]."))
		return
	var/list/todo = lay_todo()
	if (!islist(todo))
		to_chat(H, SPAN_WARNING("You cannot lay a boom here: [todo]."))
		return
	if (!todo.len)
		to_chat(H, SPAN_NOTICE("The boom is whole."))
		return
	if (W.amount < todo.len)
		to_chat(H, SPAN_WARNING("You need [todo.len] iron for that, one for every tile; you have [W.amount]."))
		return
	busy = TRUE
	H.visible_message(SPAN_NOTICE("[H] starts paying out a boom from \the [src]."), SPAN_NOTICE("You start laying [todo.len] segments of boom."))
	var/ok = do_after(H, STRAIT_BOOM_LAY * todo.len, src)
	busy = FALSE
	if (!ok || QDELETED(src) || QDELETED(W) || W.amount < todo.len)
		return
	W.use(todo.len)
	lay_segments(todo)
	if (!owner_ckey)
		owner_ckey = H.ckey
		owner_civ = H.civilization
	to_chat(H, SPAN_NOTICE("The boom is laid across the water and raised."))

/obj/structure/strait_winch/attack_hand(mob/living/user)
	if (!ishuman(user) || !Adjacent(user))
		return ..()
	var/mob/living/human/H = user
	if (busy)
		return
	var/list/S = segments()
	if (!S.len)
		to_chat(H, SPAN_NOTICE("No boom is laid yet. Use iron on \the [src], one sheet for every tile of water to the far shore."))
		return
	var/mine = owns(H)
	var/list/choices = list()
	if (mine || toll <= 0)
		choices += boom_raised() ? "Lower the boom" : "Raise the boom"
	else
		to_chat(H, SPAN_NOTICE("The toll is [toll]. Use money on \the [src] to pay it and lower the boom for a minute."))
		return
	if (mine)
		choices += "Set the toll"
		if (locate(/obj/item/stack/money) in contents)
			choices += "Take the tolls"
	var/choice = WWinput(H, "The boom is [boom_raised() ? "raised" : "lowered"]. The toll is [toll].", "Boom winch", choices[1], choices + "Cancel")
	if (!choice || choice == "Cancel" || !Adjacent(H) || QDELETED(src))
		return
	switch (choice)
		if ("Lower the boom")
			lower(H, mine ? 0 : STRAIT_BOOM_OPEN)
		if ("Raise the boom")
			raise()
			H.visible_message(SPAN_NOTICE("[H] winds up the boom."))
		if ("Set the toll")
			var/n = player_input(H, "Toll in money value. 0 lets anyone lower the boom.", "Boom toll", toll, "num", null, TRUE)
			if (isnum(n) && Adjacent(H) && owns(H))
				toll = clamp(round(n), 0, 100000)
				to_chat(H, SPAN_NOTICE("The toll is now [toll]."))
		if ("Take the tolls")
			for (var/obj/item/stack/money/M in contents)
				M.forceMove(get_turf(H))
				H.put_in_hands(M)
			to_chat(H, SPAN_NOTICE("You take the tolls out of the strongbox."))

/obj/structure/strait_winch/proc/owns(mob/living/human/H)
	return H.ckey == owner_ckey || (owner_civ && owner_civ != "none" && H.civilization == owner_civ)

// Pays the toll from a stack of money: the coins go into the winch's strongbox.
/obj/structure/strait_winch/proc/pay(mob/living/human/H, obj/item/stack/money/M)
	if (toll <= 0 || owns(H))
		to_chat(H, SPAN_NOTICE("There is no toll for you here; work the winch by hand."))
		return
	if (!boom_raised())
		to_chat(H, SPAN_NOTICE("The boom is already down."))
		return
	var/coins = M.value > 0 ? CEILING(toll / M.value, 1) : 0
	if (coins <= 0 || M.amount < coins)
		to_chat(H, SPAN_WARNING("The toll is [toll]; that is not enough."))
		return
	var/obj/item/stack/money/paid = coins == M.amount ? M : M.split(coins)
	if (!paid)
		return
	if (paid == M)
		H.drop_from_inventory(M)
	paid.forceMove(src)
	H.visible_message(SPAN_NOTICE("[H] pays the toll at \the [src]."), SPAN_NOTICE("You pay the toll of [toll]."))
	lower(H, STRAIT_BOOM_OPEN)

// Drops every whole segment; raised again after `open` deciseconds (0: stays down).
/obj/structure/strait_winch/proc/lower(mob/living/human/H, open = STRAIT_BOOM_OPEN)
	for (var/obj/structure/strait_boom/B in segments())
		if (!B.broken)
			B.lowered = TRUE
			B.update_state()
	if (raise_timer)
		deltimer(raise_timer)
		raise_timer = 0
	if (open > 0)
		raise_timer = addtimer(CALLBACK(src, PROC_REF(raise)), open, TIMER_STOPPABLE)
	if (H)
		H.visible_message(SPAN_NOTICE("[H] lets out \the [src]; the boom sinks under the water."))

/obj/structure/strait_winch/proc/raise()
	raise_timer = 0
	if (QDELETED(src))
		return
	for (var/obj/structure/strait_boom/B in segments())
		if (!B.broken)
			// A hull lying over it keeps it down until she is clear.
			if (craft_at(get_turf(B)) || vessel_at(get_turf(B)))
				raise_timer = addtimer(CALLBACK(src, PROC_REF(raise)), 50, TIMER_STOPPABLE)
				continue
			B.lowered = FALSE
			B.update_state()

// ---- Ramming (called from sail_hop in under_way.dm) ----

// The raised boom segments just ahead of her bow, as list(segment -> her tile behind it).
/datum/craft/proc/booms_ahead()
	. = list()
	if (!body)
		return
	var/heading = body.heading()
	for (var/turf/T in body.cells())
		var/turf/N = get_step(T, heading)
		if (!N)
			continue
		for (var/obj/structure/strait_boom/B in N)
			if (B.raised() && !.[B])
				.[B] = T

// A refused hop against a raised boom: at full speed she breaks through
// and her bow is holed; slower, she simply stops. TRUE when she rammed.
/datum/craft/proc/boom_ram()
	if (speed < VESSEL_SPEED_FULL)
		return FALSE
	var/list/hit = booms_ahead()
	if (!hit.len)
		return FALSE
	for (var/obj/structure/strait_boom/B in hit)
		B.break_segment()
		var/turf/T = hit[B]
		for (var/obj/covers/C in T)
			if (C.loc == T && !C.wall)
				qdel(C) // the ledger counts the hole (hull_ledger.dm)
				break
	for (var/mob/M in body.aboard())
		shake_camera(M, 4, 3)
	crew_message(SPAN_DANGER("<b>She rams the boom!</b> The chain parts, but her bow is stove in."))
	speed = VESSEL_SPEED_SLOW
	show_drives()
	return TRUE

// ---- Named straits ----

// Region id -> list(name, x, y). The centre of each narrows, on water.
var/global/list/named_straits = list(
	"mediterranean" = list(
		list("Strait of Gibraltar", 92, 131),
		list("Dardanelles", 752, 243),
		list("Bosporus", 807, 267),
		list("Strait of Sicily", 445, 164)),
	"europe" = list(
		list("Strait of Dover", 157, 110),
		list("Danish Straits", 288, 209)),
	"africa" = list(
		list("Bab-el-Mandeb", 859, 703)),
	"asia" = list(
		list("Strait of Hormuz", 35, 290),
		list("Strait of Malacca", 372, 33)))

/datum/craft
	var/tmp/in_strait = null

/proc/strait_region()
	return shard_group ? shard_group.region : null

// The named strait a turf lies in, or null.
/proc/strait_named_at(turf/T, region = strait_region())
	if (!T || T.z != 1)
		return null
	var/list/S = named_straits[region]
	if (!islist(S))
		return null
	for (var/list/N in S)
		if (abs(T.x - N[2]) <= STRAIT_NOTICE_RADIUS && abs(T.y - N[3]) <= STRAIT_NOTICE_RADIUS)
			return N[1]
	return null

// Called after every hop: tells the crew when she enters a named strait.
/datum/craft/proc/strait_notice()
	var/name = body ? strait_named_at(body.origin()) : null
	if (name == in_strait)
		return
	in_strait = name
	if (name)
		crew_message(SPAN_NOTICE("<b>She enters the [name].</b>"))

#undef STRAIT_BOOM_MAX
#undef STRAIT_BOOM_OPEN
#undef STRAIT_BOOM_CUT
#undef STRAIT_BOOM_LAY
#undef STRAIT_NOTICE_RADIUS
