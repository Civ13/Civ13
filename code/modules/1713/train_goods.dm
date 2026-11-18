// Freight handling (train scale-up, step 16). The goods yard: what a yard
// crew works so that loading a train is a job and not a chore.
//
// - Loading stage: a raised stage with a chute. The crew heaps ore, coal or
//   sand on it between trains; one pull of the chute fills the open wagons
//   and hoppers standing beside it. (A hopper empties into a drop pit under
//   the track, train_freight.dm.)
// - Goods crane: a hand crane beside the track that swings crates and
//   machines between the ground and a car's deck.
// - Livestock ramp: animals penned behind it are driven aboard the car at
//   its head, or driven off it.
// - Destination card: every car has a holder. A pen writes the card, and
//   the guard's journal lists what each car is carded for.
//
// Nothing here buys or sells: every load is put on and taken off by players.

#define LOADING_STAGE_MAX 3000 // units of one kind of bulk
#define LOADING_STAGE_TIME 40
#define LOADING_STAGE_SHOVEL_TIME 20
#define LIVESTOCK_RAMP_REACH 3 // tiles behind the ramp its pen may reach
#define LIVESTOCK_RAMP_TIME 40
#define TRAIN_CARD_LENGTH 40

/////////////////////////////////////////////////////////////////////////////
// Loading stage

/obj/structure/rail_depot/loading_stage
	name = "loading stage"
	desc = "A raised timber stage beside the track with a chute over the rails. Ore, coal or sand heaped on it runs down the chute into the open wagons and hoppers standing next to it."
	icon_state = "loading_stage_empty"
	var/bulk_path = null // the type of stack heaped on it, as text
	var/bulk_amount = 0

/obj/structure/rail_depot/loading_stage/update_icon()
	icon_state = bulk_amount > 0 ? "loading_stage_[train_bulk_tone(bulk_path)]" : "loading_stage_empty"

/obj/structure/rail_depot/loading_stage/examine(mob/user)
	..()
	if (bulk_amount > 0)
		to_chat(user, "It holds [bulk_amount] of [LOADING_STAGE_MAX] units of [train_bulk_name(bulk_path)]. Stop open wagons or hoppers beside it and use it with an empty hand to run the heap down the chute. A shovel takes it back off.")
	else
		to_chat(user, "It is empty and takes [LOADING_STAGE_MAX] units of one kind: tip ore, coal or sand onto it.")

// Heaps a stack on the stage. Returns the units taken.
/obj/structure/rail_depot/loading_stage/proc/load_bulk(obj/item/stack/ore/W)
	if (!train_bulk_item(W))
		return 0
	if (bulk_amount > 0 && bulk_path != "[W.type]")
		return 0
	var/take = min(W.amount, LOADING_STAGE_MAX - bulk_amount)
	if (take <= 0)
		return 0
	bulk_path = "[W.type]"
	bulk_amount += take
	W.use(take)
	update_icon()
	return take

// The cars within reach that carry bulk, each once, by its load section.
/obj/structure/rail_depot/loading_stage/proc/takers()
	var/list/found = list()
	for (var/obj/structure/trains/platform/P in range(reach, src))
		var/obj/structure/trains/platform/S = P.bulk_store()
		if (S)
			found |= S
	return found

// Runs the heap down the chute. Returns the units that went into cars.
/obj/structure/rail_depot/loading_stage/proc/fill_takers()
	. = 0
	for (var/obj/structure/trains/platform/S in takers())
		if (bulk_amount <= 0)
			break
		if (S.bulk_amount > 0 && S.bulk_path != bulk_path)
			continue
		var/gave = min(bulk_amount, S.bulk_max() - S.bulk_amount)
		if (gave <= 0)
			continue
		S.bulk_path = bulk_path
		S.bulk_amount += gave
		S.update_bulk()
		bulk_amount -= gave
		. += gave
	if (bulk_amount <= 0)
		bulk_amount = 0
		bulk_path = null
	if (.)
		update_icon()

// Shovels up to `want` units back off onto where. Returns what came off.
/obj/structure/rail_depot/loading_stage/proc/take_off(want, turf/where)
	if (bulk_amount <= 0 || want <= 0 || !where)
		return 0
	var/path = bulk_path
	var/out = min(want, bulk_amount)
	bulk_amount -= out
	if (bulk_amount <= 0)
		bulk_path = null
	update_icon()
	return train_bulk_spill(path, out, list(where))

/obj/structure/rail_depot/loading_stage/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/stack/ore))
		if (!train_bulk_item(W))
			to_chat(user, SPAN_WARNING("That does not travel in bulk."))
			return
		if (bulk_amount > 0 && bulk_path != "[W.type]")
			to_chat(user, SPAN_WARNING("\The [src] is heaped with [train_bulk_name(bulk_path)]. It holds one kind at a time."))
			return
		var/took = load_bulk(W)
		if (!took)
			to_chat(user, "<span class = 'notice'>\The [src] is full.</span>")
			return
		playsound(loc, 'sound/effects/shovelling.ogg', 60, TRUE)
		to_chat(user, "You tip [took] onto \the [src]. It holds [bulk_amount] of [LOADING_STAGE_MAX] units of [train_bulk_name(bulk_path)].")
		return
	if (is_tool(W, TOOL_SHOVEL))
		if (bulk_amount <= 0)
			to_chat(user, "\The [src] is empty.")
			return
		if (busy)
			return
		user.visible_message("[user] starts shovelling off \the [src]...", "You start shovelling off \the [src]...")
		busy = TRUE
		var/done = do_after(user, LOADING_STAGE_SHOVEL_TIME, src)
		busy = FALSE
		if (!done || bulk_amount <= 0)
			return
		var/out = take_off(50, get_turf(user))
		playsound(loc, 'sound/effects/shovelling.ogg', 60, TRUE)
		to_chat(user, "You shovel [out] off \the [src]. [bulk_amount] left.")
		return
	return ..()

/obj/structure/rail_depot/loading_stage/attack_hand(mob/living/user as mob)
	if (!istype(user) || busy)
		return
	if (bulk_amount <= 0)
		to_chat(user, "<span class = 'warning'>\The [src] is empty. Tip ore, coal or sand onto it.</span>")
		return
	if (!takers().len)
		to_chat(user, "No open wagon or hopper stands within reach of \the [src].")
		return
	user.visible_message("[user] opens \the [src]'s chute...", "You open the chute and the heap starts to run...")
	busy = TRUE
	var/done = do_after(user, LOADING_STAGE_TIME, src)
	busy = FALSE
	if (!done)
		return
	var/gave = fill_takers()
	if (gave > 0)
		playsound(loc, 'sound/effects/shovelling.ogg', 100, TRUE)
		user.visible_message("[user] loads the wagons from \the [src].", "[gave] units rumble down the chute. [bulk_amount ? "[bulk_amount] stay on the stage." : "The stage is bare."]")
	else
		to_chat(user, "The wagons here are full, or loaded with something else.")

/////////////////////////////////////////////////////////////////////////////
// Goods crane

/obj/structure/workshop_machine/shear_legs/crane/goods
	name = "goods crane"
	desc = "A hand crane on an iron post, for a goods yard. Fasten it down beside the track, then drag an unfastened object within three tiles onto it: it swings the load onto the deck of a car, sets it down beside the track, or raises or lowers it one level through open air."
	icon = 'icons/obj/vehicles/train_platforms.dmi'
	icon_state = "goods_crane"
	base_state = "goods_crane"
	reach = 3

/obj/structure/workshop_machine/shear_legs/crane/goods/sling_reach()
	return reach

/obj/structure/workshop_machine/shear_legs/crane/goods/haul_choices(atom/movable/load)
	return train_crane_swings(src, load, ..(), null)

// On top of what a hoist does anyway: the nearest clear deck of a car, and
// the nearest clear ground off the track, both within the crane's reach. A
// rail crane never swings a load onto its own car (own_car).
/proc/train_crane_swings(obj/structure/workshop_machine/shear_legs/crane, atom/movable/load, list/choices, own_car)
	var/turf/here = get_turf(crane)
	var/turf/from = get_turf(load)
	if (!here || !from)
		return choices
	var/turf/deck = null
	var/turf/ground = null
	var/deck_dist = 0
	var/ground_dist = 0
	var/deck_name = null
	var/obj/structure/trains/platform/on = train_deck_at(from)
	for (var/turf/T in range(crane.reach, here))
		if (T == from || !ledge_landing_clear(T))
			continue
		var/d = get_dist(T, from)
		var/obj/structure/trains/platform/P = train_deck_at(T)
		if (P)
			if ((own_car && P.car_id == own_car) || P.density || (on && on.car_id == P.car_id))
				continue
			if (!deck || d < deck_dist)
				deck = T
				deck_dist = d
				deck_name = P.name
		else if (!(locate(/obj/structure/rails) in T) && (!ground || d < ground_dist))
			ground = T
			ground_dist = d
	if (deck)
		choices["Swing it onto the [deck_name]"] = deck
	if (ground)
		choices["Set it down beside the track"] = ground
	return choices

/////////////////////////////////////////////////////////////////////////////
// Livestock ramp

/obj/structure/train_livestock_ramp
	name = "livestock ramp"
	desc = "A cleated timber ramp with rails either side. It stands at the door of a stock car: animals penned behind it are driven up into the car, or down out of it."
	icon = 'icons/obj/vehicles/train_platforms.dmi'
	icon_state = "livestock_ramp"
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	not_movable = TRUE
	flammable = FALSE
	layer = 2.55
	var/tmp/busy = FALSE

/obj/structure/train_livestock_ramp/persistence_runtime_var(key)
	return key == "busy" || ..(key)

/obj/structure/train_livestock_ramp/after_load()
	..()
	busy = FALSE

// The deck tile at the head of the ramp, and the car it belongs to.
/obj/structure/train_livestock_ramp/proc/head_tile()
	return get_step(src, dir)

/obj/structure/train_livestock_ramp/proc/car()
	return train_deck_at(head_tile())

// What a ramp moves: farm and wild beasts, not people, and nothing that is
// dead, ridden or out for blood.
/proc/train_livestock(mob/living/simple_animal/A)
	if (!istype(A) || A.stat == DEAD || A.rider)
		return FALSE
	if (istype(A, /mob/living/simple_animal/hostile) || istype(A, /mob/living/simple_animal/civilian) || istype(A, /mob/living/simple_animal/hostage) || istype(A, /mob/living/simple_animal/npc_vendor))
		return FALSE
	return TRUE

// A tile an animal can be put on: open, with no animal and nothing solid but
// the car itself and its sides.
/proc/train_livestock_room(turf/T)
	if (!T || T.density)
		return FALSE
	for (var/atom/movable/AM in T)
		if (isliving(AM) || (AM.density && !istype(AM, /obj/structure/train_part) && !istype(AM, /obj/structure/trains)))
			return FALSE
	return TRUE

// The deck tiles of the whole car, nearest the ramp first.
/obj/structure/train_livestock_ramp/proc/deck_tiles()
	var/list/tiles = list()
	var/obj/structure/trains/platform/P = car()
	if (!P)
		return tiles
	var/turf/head = head_tile()
	var/list/found = list()
	for (var/obj/structure/trains/platform/S in P.car_segments())
		for (var/turf/T in train_platform_tiles(S.loc, S.dir))
			found |= T
	while (found.len)
		var/turf/best = null
		for (var/turf/T in found)
			if (!best || get_dist(T, head) < get_dist(best, head))
				best = T
		found -= best
		tiles += best
	return tiles

// The pen: ground behind and beside the ramp, off the track and off any car.
/obj/structure/train_livestock_ramp/proc/pen_tiles()
	var/list/tiles = list()
	var/turf/here = get_turf(src)
	var/turf/front = head_tile()
	if (!here || !front)
		return tiles
	for (var/dist in 0 to LIVESTOCK_RAMP_REACH)
		for (var/turf/T in range(dist, here))
			if ((T in tiles) || get_dist(T, here) != dist)
				continue
			// Nothing on the track side of the ramp.
			var/ahead = (T.x - here.x) * (front.x - here.x) + (T.y - here.y) * (front.y - here.y)
			if (ahead > 0 || train_deck_at(T) || (locate(/obj/structure/rails) in T))
				continue
			tiles += T
	return tiles

/obj/structure/train_livestock_ramp/proc/ramp_problem()
	var/obj/structure/trains/platform/P = car()
	if (!P)
		return "No car stands at the head of \the [src]. It faces [dir2text(dir)]: stop a car so that its deck is on the next tile that way."
	if (P.train_rolling())
		return "The train is moving."
	for (var/atom/movable/AM in head_tile())
		if (AM.density && !isliving(AM) && !istype(AM, /obj/structure/train_part/deck))
			return "\The [AM] is in the way at the head of the ramp. Open the car's door there."
	return null

// Drives the penned animals aboard. Returns how many went up.
/obj/structure/train_livestock_ramp/proc/drive_aboard()
	. = 0
	if (ramp_problem())
		return
	var/list/room = list()
	for (var/turf/T in deck_tiles())
		if (train_livestock_room(T))
			room += T
	for (var/turf/T in pen_tiles())
		for (var/mob/living/simple_animal/A in T)
			if (!room.len)
				return
			if (!train_livestock(A))
				continue
			var/turf/dest = room[1]
			room.Cut(1, 2)
			if (A.pulledby)
				A.pulledby.stop_pulling()
			A.train_shift(dest, FALSE)
			.++

// Drives the animals on the car down into the pen. Returns how many came off.
/obj/structure/train_livestock_ramp/proc/drive_off()
	. = 0
	if (ramp_problem())
		return
	var/list/room = list()
	for (var/turf/T in pen_tiles())
		if (T != get_turf(src) && train_livestock_room(T))
			room += T
	for (var/turf/T in deck_tiles())
		for (var/mob/living/simple_animal/A in T)
			if (!room.len)
				return
			if (!train_livestock(A))
				continue
			var/turf/dest = room[1]
			room.Cut(1, 2)
			if (A.pulledby)
				A.pulledby.stop_pulling()
			A.train_shift(dest, FALSE)
			.++

/obj/structure/train_livestock_ramp/proc/work(mob/living/user, aboard)
	if (busy || !istype(user) || user.incapacitated())
		return 0
	var/problem = ramp_problem()
	if (problem)
		to_chat(user, SPAN_WARNING(problem))
		return 0
	user.visible_message("[user] starts driving the animals [aboard ? "up" : "down"] \the [src].", "You start driving the animals [aboard ? "up the ramp into the car" : "down the ramp out of the car"].")
	busy = TRUE
	var/done = do_after(user, LIVESTOCK_RAMP_TIME, src)
	busy = FALSE
	if (!done || QDELETED(src))
		return 0
	problem = ramp_problem()
	if (problem)
		to_chat(user, SPAN_WARNING(problem))
		return 0
	var/moved = aboard ? drive_aboard() : drive_off()
	if (moved)
		user.visible_message("[user] drives [moved] animal\s [aboard ? "aboard" : "off the car"].", "You drive [moved] animal\s [aboard ? "aboard. Shut the car's door behind them." : "down into the pen."]")
	else
		to_chat(user, aboard ? "There are no animals in the pen behind the ramp, or no room for them in the car." : "There are no animals on the car, or no room for them behind the ramp.")
	return moved

/obj/structure/train_livestock_ramp/attack_hand(mob/living/user as mob)
	if (!istype(user) || user.incapacitated() || busy)
		return
	var/problem = ramp_problem()
	if (problem)
		to_chat(user, SPAN_WARNING(problem))
		return
	var/list/options = list("Drive the animals aboard" = TRUE, "Drive the animals off the car" = FALSE)
	var/choice = WWinput(user, "Animals within [LIVESTOCK_RAMP_REACH] tiles behind the ramp go aboard; animals on the car come down.", name, "Cancel", options + "Cancel")
	if (!(choice in options) || QDELETED(src) || get_dist(user, src) > 1)
		return
	work(user, options[choice])

/obj/structure/train_livestock_ramp/attackby(obj/item/W as obj, mob/user as mob)
	if (is_tool(W, TOOL_WRENCH))
		set_dir(turn(dir, -90))
		playsound(loc, 'sound/items/Ratchet.ogg', 50, TRUE)
		to_chat(user, "You turn \the [src]: its head is now to the [dir2text(dir)].")
		return
	return ..()

/obj/structure/train_livestock_ramp/examine(mob/user)
	..()
	to_chat(user, "Its head is to the [dir2text(dir)]: stand it two tiles from the rails so that a car's deck comes next to it, and open the car's door there. Pen the animals within [LIVESTOCK_RAMP_REACH] tiles behind it. A wrench turns it.")

/////////////////////////////////////////////////////////////////////////////
// Destination cards

/obj/structure/trains
	var/destination_card = null // what is written on the card in its holder

// The section that carries the card of this car or engine.
/obj/structure/trains/proc/card_holder()
	return src

/obj/structure/trains/platform/card_holder()
	var/obj/structure/trains/locomotive/E = unit_engine()
	if (E)
		return E
	if (seg_index != 1)
		for (var/obj/structure/trains/platform/P in car_segments())
			if (P.seg_index == 1)
				return P
	return src

/obj/structure/trains/proc/card_text()
	var/obj/structure/trains/holder = card_holder()
	return holder ? holder.destination_card : null

// Writes the card, or wipes it with an empty text. TRUE when it changed.
/obj/structure/trains/proc/set_card(text)
	var/obj/structure/trains/holder = card_holder()
	if (!holder)
		return FALSE
	text = text ? sanitize(text, TRAIN_CARD_LENGTH) : null
	if (!text)
		text = null
	if (holder.destination_card == text)
		return FALSE
	holder.destination_card = text
	return TRUE

// The line examine() shows (train_couplings.dm).
/obj/structure/trains/proc/card_line()
	var/text = card_text()
	return text ? "The card in its holder reads: [text]. A pen writes a new one." : "Its card holder is empty. A pen writes a destination card."

// A pen on the car (train_servicing.dm asks first). TRUE when W was used.
/obj/structure/trains/proc/card_use(obj/item/W, mob/living/user)
	if (!istype(W, /obj/item/weapon/pen) || !istype(user))
		return FALSE
	var/text = player_input(user, "Where is \the [src] bound, or what is it carrying? Leave it blank to take the card out.", "Destination card", card_text(), "text", null, TRUE)
	if (isnull(text) || QDELETED(src) || user.incapacitated() || get_dist(user, src) > 1)
		return TRUE
	if (set_card(text))
		var/now = card_text()
		user.visible_message("[user] [now ? "writes a card and slips it into the holder of" : "takes the card out of the holder of"] \the [src].", now ? "You card \the [src]: [now]." : "You take the card out of \the [src]'s holder.")
	return TRUE

#undef LOADING_STAGE_MAX
#undef LOADING_STAGE_TIME
#undef LOADING_STAGE_SHOVEL_TIME
#undef LIVESTOCK_RAMP_REACH
#undef LIVESTOCK_RAMP_TIME
#undef TRAIN_CARD_LENGTH
