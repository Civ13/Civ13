// Hopper machines: driven machines that work on their own while they have feed.
//
// Fill the hopper, and while a treadwheel, horse gin, mill wheel or windmill
// drives the machine (directly or through transmission.dm) it works one batch
// a step and leaves the product on its tile. Nobody has to stand at it. A step
// takes a minute at half hand time, sooner on a faster drive and later on a
// slower or overloaded one. It stops when the hopper is empty, when 20 products
// lie on its tile, or when the drive stops; it asks the drive only once a step.
//
// Every hopper has a gate that a lever's cord can shut and open (mechanisms.dm).
// Factory belts and arms can fill the hopper and take its products, and a
// belt that leads away from the machine carries each product off.

#define HOPPER_STEP_TIME 600 // deciseconds a step takes at a drive share of 0.5
#define HOPPER_IDLE_RECHECK 600 // deciseconds before an undriven machine looks again
#define HOPPER_OUTPUT_CAP 20

/obj/structure/workshop_machine/hopper
	name = "hopper machine"
	icon = 'icons/obj/hopper_machines.dmi'
	drive_draw = 2
	var/base_state = ""
	var/capacity = 20 // feed the hopper holds
	var/batch = 1 // feed worked each step
	var/list/hopper = list() // feed kind -> count
	var/gate_shut = FALSE // a cord's gate holds the feed back
	var/tmp/next_step = 0
	var/tmp/working = FALSE

/obj/structure/workshop_machine/hopper/persistence_runtime_var(key)
	return key == "next_step" || key == "working" || ..()

/obj/structure/workshop_machine/hopper/New()
	..()
	update_icon()

/obj/structure/workshop_machine/hopper/after_load()
	..()
	if (hopper_count())
		start_working()

/obj/structure/workshop_machine/hopper/on_runtime_spawn()
	..()
	if (hopper_count())
		start_working()

/obj/structure/workshop_machine/hopper/Destroy()
	processing_objects -= src
	return ..()

/obj/structure/workshop_machine/hopper/update_icon()
	icon_state = working ? "[base_state]_on" : base_state

/obj/structure/workshop_machine/hopper/proc/hopper_count()
	. = 0
	for (var/kind in hopper)
		. += hopper[kind]

/obj/structure/workshop_machine/hopper/proc/start_working()
	if (!next_step || next_step < world.time)
		next_step = world.time + HOPPER_STEP_TIME
	processing_objects |= src

// The kind of feed I is, or null when the hopper does not take it.
/obj/structure/workshop_machine/hopper/proc/feed_kind(obj/item/I)
	return null

// How many of I one item or stack holds as feed.
/obj/structure/workshop_machine/hopper/proc/feed_amount(obj/item/I)
	var/obj/item/stack/S = I
	return istype(S) ? S.amount : 1

// Takes up to want of I into the hopper; returns how many went in.
/obj/structure/workshop_machine/hopper/proc/take_feed(obj/item/I, want)
	var/obj/item/stack/S = I
	if (istype(S))
		var/n = min(want, S.amount)
		S.use(n)
		return n
	qdel(I)
	return 1

// Makes one batch's products from one unit of feed of this kind.
/obj/structure/workshop_machine/hopper/proc/make_product(kind, turf/T)
	return

// Feed of this kind put back as items, when the machine is taken apart.
/obj/structure/workshop_machine/hopper/proc/return_feed(kind, count, turf/T)
	return

// How many products already lie on T.
/obj/structure/workshop_machine/hopper/proc/output_count(turf/T)
	return 0

/obj/structure/workshop_machine/hopper/proc/feed_words()
	return "feed"

// Item types the machine makes, for factory arms that unload it.
/obj/structure/workshop_machine/hopper/proc/product_types()
	return list()

// Shuts or opens the hopper gate; TRUE when it moved.
/obj/structure/workshop_machine/hopper/proc/set_gate(shut)
	if (shut == gate_shut)
		return FALSE
	gate_shut = shut
	playsound(src, 'sound/items/Ratchet.ogg', 30, TRUE)
	if (!gate_shut && hopper_count())
		next_step = world.time + HOPPER_IDLE_RECHECK / 6
		processing_objects |= src
	return TRUE

// A fastened belt beside the machine that carries away from it, if any.
/obj/structure/workshop_machine/hopper/proc/outgoing_belt()
	for (var/d in cardinal)
		var/turf/T = get_step(src, d)
		var/obj/structure/factory_belt/B = T ? locate(/obj/structure/factory_belt) in T : null
		if (B && B.anchored && B.dir == d)
			return B
	return null

// Products just made on T go onto an outgoing belt when there is one.
/obj/structure/workshop_machine/hopper/proc/send_products(turf/T, list/before)
	var/obj/structure/factory_belt/B = outgoing_belt()
	if (!B)
		return
	var/list/types = product_types()
	for (var/obj/item/I in T)
		if ((I in before) || !(I.type in types))
			continue
		factory_place_on_turf(I, get_turf(B))
	B.belt_wake()

/obj/structure/workshop_machine/hopper/factory_accepts(obj/item/I, from_dir = 0)
	if (!anchored || !factory_movable_item(I) || !feed_kind(I))
		return 0
	return min(capacity - hopper_count(), feed_amount(I))

/obj/structure/workshop_machine/hopper/factory_insert(obj/item/I, from_dir = 0)
	var/amount = factory_accepts(I, from_dir)
	if (amount <= 0)
		return 0
	var/kind = feed_kind(I)
	var/n = take_feed(I, amount)
	hopper[kind] = (hopper[kind] || 0) + n
	start_working()
	return n

/obj/structure/workshop_machine/hopper/factory_offer(to_dir = 0, filter_type = null)
	if (!anchored || !isturf(loc))
		return null
	var/list/types = product_types()
	for (var/obj/item/I in loc)
		if ((I.type in types) && (!filter_type || istype(I, filter_type)) && factory_movable_item(I))
			return I
	return null

/obj/structure/workshop_machine/hopper/factory_take(obj/item/I, atom/destination)
	return factory_take_tile_output(src, I, destination)

/obj/structure/workshop_machine/hopper/proc/load_item(obj/item/I, mob/living/human/H)
	var/kind = feed_kind(I)
	if (!kind)
		return 0
	var/room = capacity - hopper_count()
	if (room <= 0)
		to_chat(H, SPAN_WARNING("The hopper of \the [src] is full."))
		return 0
	if (istype(I, /obj/item/stack) || I.loc != H || H.drop_from_inventory(I))
		var/n = take_feed(I, min(room, feed_amount(I)))
		hopper[kind] = (hopper[kind] || 0) + n
		return n
	return 0

/obj/structure/workshop_machine/hopper/attackby(obj/item/I, mob/living/human/H)
	if (!istype(H))
		return
	if (handle_machine_tool(I, H))
		if (!anchored)
			working = FALSE
			update_icon()
		return
	var/loaded = 0
	if (istype(I, /obj/item/weapon/storage))
		for (var/obj/item/C in I)
			if (feed_kind(C) && hopper_count() < capacity)
				var/obj/item/weapon/storage/bag = I
				bag.remove_from_storage(C, src)
				loaded += load_item(C, H)
	else if (feed_kind(I))
		loaded = load_item(I, H)
	else
		return ..()
	if (loaded)
		H.visible_message(SPAN_NOTICE("[H] tips [feed_words()] into the hopper of \the [src]."), SPAN_NOTICE("You tip [loaded] into the hopper; it holds [hopper_count()] of [capacity]."))
		start_working()
	return

/obj/structure/workshop_machine/hopper/attack_hand(mob/living/human/H)
	if (istype(H))
		examine(H, 1)

/obj/structure/workshop_machine/hopper/examine(mob/user, distance)
	..(user, distance)
	to_chat(user, SPAN_NOTICE("Its hopper holds [hopper_count()] of [capacity] [feed_words()]."))
	if (gate_shut)
		to_chat(user, SPAN_NOTICE("Its hopper gate is shut: it works nothing until a lever's cord opens it."))
	if (!anchored)
		to_chat(user, SPAN_WARNING("It is not fastened down."))
	else if (output_count(get_turf(src)) >= HOPPER_OUTPUT_CAP)
		to_chat(user, SPAN_WARNING("Its output is piled up. Clear it away and it works on."))
	else if (hopper_count() && mechanical_drive_factor(src) >= 1)
		to_chat(user, SPAN_WARNING("Nothing drives it. It needs a turning treadwheel, horse gin, mill wheel or windmill, beside it or joined by a line shaft."))

/obj/structure/workshop_machine/hopper/dismantled()
	var/turf/T = get_turf(src)
	for (var/kind in hopper)
		return_feed(kind, hopper[kind], T)
	hopper.Cut()

// TRUE while the machine still has work: then it stays on the object loop.
/obj/structure/workshop_machine/hopper/proc/work_step()
	if (!hopper_count())
		return FALSE
	if (!anchored || !isturf(loc) || persistence_save_in_progress || persistence_active_operation)
		next_step = world.time + HOPPER_IDLE_RECHECK
		return TRUE
	var/turf/T = loc
	var/factor = gate_shut ? 1 : mechanical_drive_factor(src)
	if (factor >= 1 || output_count(T) >= HOPPER_OUTPUT_CAP)
		next_step = world.time + HOPPER_IDLE_RECHECK
		if (working)
			working = FALSE
			update_icon()
		return TRUE
	var/list/before = T.contents.Copy()
	for (var/i = 1 to batch)
		var/kind = null
		for (var/k in hopper)
			if (hopper[k] > 0)
				kind = k
				break
		if (!kind)
			break
		hopper[kind]--
		if (hopper[kind] <= 0)
			hopper -= kind
		make_product(kind, T)
	send_products(T, before)
	working = TRUE
	update_icon()
	next_step = world.time + round(HOPPER_STEP_TIME * factor * 2)
	return hopper_count() > 0

/obj/structure/workshop_machine/hopper/process_interval(configured_seconds = 2)
	if (QDELETED(src))
		return PROCESS_KILL
	if (world.time < next_step)
		return
	if (!work_step())
		processing_objects -= src
		working = FALSE
		update_icon()
		return PROCESS_KILL

//////////////////////////////////////////////////////////////////////////////
// Millstones: grain to flour.

var/global/list/millstone_grains = list(
	"wheat" = list(/obj/item/weapon/reagent_containers/food/snacks/grown/wheat, /obj/item/weapon/reagent_containers/food/condiment/flour),
	"oat" = list(/obj/item/weapon/reagent_containers/food/snacks/grown/oat, /obj/item/weapon/reagent_containers/food/condiment/flour/oatflour),
	"barley" = list(/obj/item/weapon/reagent_containers/food/snacks/grown/barley, /obj/item/weapon/reagent_containers/food/condiment/flour/barleyflour),
	"rice" = list(/obj/item/weapon/reagent_containers/food/snacks/grown/rice, /obj/item/weapon/reagent_containers/food/snacks/rice),
)

/obj/structure/workshop_machine/hopper/millstones
	name = "millstones"
	desc = "A runner stone turning on a bed stone under a grain hopper. Fill the hopper with wheat, oats, barley or rice, by the handful or from a sack, and while a mill wheel, windmill, horse gin or treadwheel drives it, it grinds two a step into flour on its own."
	icon_state = "millstones"
	base_state = "millstones"
	batch = 2

/obj/structure/workshop_machine/hopper/millstones/feed_words()
	return "grain"

/obj/structure/workshop_machine/hopper/millstones/feed_kind(obj/item/I)
	for (var/kind in millstone_grains)
		var/list/pair = millstone_grains[kind]
		if (I.type == pair[1])
			return kind
	return null

/obj/structure/workshop_machine/hopper/millstones/product_types()
	. = list()
	for (var/kind in millstone_grains)
		var/list/pair = millstone_grains[kind]
		. += pair[2]

/obj/structure/workshop_machine/hopper/millstones/make_product(kind, turf/T)
	var/list/pair = millstone_grains[kind]
	if (pair)
		var/path = pair[2]
		new path(T)

/obj/structure/workshop_machine/hopper/millstones/return_feed(kind, count, turf/T)
	var/list/pair = millstone_grains[kind]
	if (!pair)
		return
	var/path = pair[1]
	for (var/i = 1 to count)
		new path(T)

/obj/structure/workshop_machine/hopper/millstones/output_count(turf/T)
	. = 0
	for (var/kind in millstone_grains)
		var/list/pair = millstone_grains[kind]
		var/path = pair[2]
		for (var/obj/item/I in T)
			if (I.type == path)
				.++

//////////////////////////////////////////////////////////////////////////////
// Sash saw: logs to planks.

/obj/structure/workshop_machine/hopper/sash_saw
	name = "sash saw"
	desc = "A frame saw that a crank drives up and down through a log fed along its bed. Load it with logs, and while a mill wheel, windmill, horse gin or treadwheel drives it, it saws one log a step into two planks and a piece of bark on its own."
	icon_state = "sash_saw"
	base_state = "sash_saw"
	batch = 1

/obj/structure/workshop_machine/hopper/sash_saw/feed_words()
	return "logs"

/obj/structure/workshop_machine/hopper/sash_saw/feed_kind(obj/item/I)
	var/obj/item/stack/material/wood/W = I
	if (!istype(W) || W.type != /obj/item/stack/material/wood || W.default_type != "wood" || !W.material || W.material.name != "wood" || W.onfire)
		return null
	return "wood"

/obj/structure/workshop_machine/hopper/sash_saw/product_types()
	return list(/obj/item/stack/material/woodplank, /obj/item/stack/bark)

/obj/structure/workshop_machine/hopper/sash_saw/make_product(kind, turf/T)
	var/obj/item/stack/material/woodplank/P = new(T, 2, FALSE)
	for (var/obj/item/stack/material/woodplank/existing in T)
		if (existing != P && existing.type == P.type && existing.amount < existing.max_amount && !existing.color && !existing.customname)
			P.merge(existing)
			break
	new /obj/item/stack/bark(T, 1)
	playsound(T, 'sound/effects/woodfile.ogg', 60, TRUE)

/obj/structure/workshop_machine/hopper/sash_saw/return_feed(kind, count, turf/T)
	if (count > 0)
		new /obj/item/stack/material/wood(T, count)

/obj/structure/workshop_machine/hopper/sash_saw/output_count(turf/T)
	. = 0
	for (var/obj/item/stack/material/woodplank/P in T)
		. += P.amount
	. = round(. / 2)

//////////////////////////////////////////////////////////////////////////////
// Fulling stocks: wool to wool cloth.

/obj/structure/workshop_machine/hopper/fulling_stocks
	name = "fulling stocks"
	desc = "Two heavy wooden hammers that a cam shaft lifts and drops into a trough of wet wool. Fill it with wool, and while a mill wheel, windmill, horse gin or treadwheel drives it, it beats two a step into felted wool cloth on its own."
	icon_state = "fulling_stocks"
	base_state = "fulling_stocks"
	batch = 2

/obj/structure/workshop_machine/hopper/fulling_stocks/feed_words()
	return "wool"

/obj/structure/workshop_machine/hopper/fulling_stocks/feed_kind(obj/item/I)
	return I.type == /obj/item/stack/material/wool ? "wool" : null

/obj/structure/workshop_machine/hopper/fulling_stocks/product_types()
	return list(/obj/item/stack/material/woolcloth)

/obj/structure/workshop_machine/hopper/fulling_stocks/make_product(kind, turf/T)
	var/obj/item/stack/material/woolcloth/C = new(T, 1, FALSE)
	for (var/obj/item/stack/material/woolcloth/existing in T)
		if (existing != C && existing.type == C.type && existing.amount < existing.max_amount && !existing.color && !existing.customname)
			C.merge(existing)
			break
	playsound(T, 'sound/effects/woodfile.ogg', 40, TRUE)

/obj/structure/workshop_machine/hopper/fulling_stocks/return_feed(kind, count, turf/T)
	if (count > 0)
		new /obj/item/stack/material/wool(T, count)

/obj/structure/workshop_machine/hopper/fulling_stocks/output_count(turf/T)
	. = 0
	for (var/obj/item/stack/material/woolcloth/C in T)
		. += C.amount

//////////////////////////////////////////////////////////////////////////////
// Bark stamps: bark to crushed tanbark, which gives twice the tannin.

/obj/structure/workshop_machine/hopper/bark_stamps
	name = "bark stamps"
	desc = "A row of iron-shod wooden stamps that a cam shaft lifts and drops on a trough of bark. Fill it with bark, and while a mill wheel, windmill, horse gin or treadwheel drives it, it crushes two pieces a step into tanbark, which yields twice the tannin."
	icon_state = "bark_stamps"
	base_state = "bark_stamps"
	batch = 2

/obj/structure/workshop_machine/hopper/bark_stamps/feed_words()
	return "bark"

/obj/structure/workshop_machine/hopper/bark_stamps/feed_kind(obj/item/I)
	return I.type == /obj/item/stack/bark ? "bark" : null

/obj/structure/workshop_machine/hopper/bark_stamps/product_types()
	return list(/obj/item/stack/bark/crushed)

/obj/structure/workshop_machine/hopper/bark_stamps/make_product(kind, turf/T)
	var/obj/item/stack/bark/crushed/C = new(T, 2, FALSE)
	for (var/obj/item/stack/bark/crushed/existing in T)
		if (existing != C && existing.amount < existing.max_amount)
			C.merge(existing)
			break
	playsound(T, 'sound/effects/woodfile.ogg', 40, TRUE)

/obj/structure/workshop_machine/hopper/bark_stamps/return_feed(kind, count, turf/T)
	if (count > 0)
		new /obj/item/stack/bark(T, count)

/obj/structure/workshop_machine/hopper/bark_stamps/output_count(turf/T)
	. = 0
	for (var/obj/item/stack/bark/crushed/C in T)
		. += C.amount
	. = round(. / 2)

#undef HOPPER_STEP_TIME
#undef HOPPER_IDLE_RECHECK
#undef HOPPER_OUTPUT_CAP
