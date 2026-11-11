// Powered tanning drum: industrial leather production. It takes hides at any
// stage (pelts, raw hides, scraped, wet or dry hides) and bark, by hand or from
// factory arms, and water and tannin by hand or from a pumped pipe network.
// While powered it turns one hide into one leather sheet every two seconds,
// paying the same liquids a person would: 5 water to wash a hide that has not
// been washed and 5 tannin to tan it. When tannin runs low it soaks one piece
// of bark in 10 water for 10 tannin, as a person does by hand. Leather is left
// on the drum's tile, where an arm can take it. Sprite: tools/sprites/build_tanning_drum.py.

#define TANNING_DRUM_HIDES 30 // hide pieces the hopper holds
#define TANNING_DRUM_BARK 20 // pieces of bark the hopper holds
#define TANNING_DRUM_VOLUME 200
#define TANNING_DRUM_LIQUID 100 // units of water, and of tannin, the drum keeps
#define TANNING_DRUM_STEPS 2 // powered seconds per hide
#define TANNING_DRUM_COST 5 // units of water to wash, and of tannin to tan, one hide
#define TANNING_DRUM_BARK_YIELD 10 // tannin from one piece of bark, for as much water
#define TANNING_DRUM_OUTPUT_LIMIT 12 // loose items on the tile before the drum waits

var/global/list/factory_active_tanning_drums = list()

// Hide stages that still need washing before they are tanned.
/proc/tanning_drum_needs_wash(path)
	return ispath(path, /obj/item/stack/material/pelt) || ispath(path, /obj/item/stack/material/rawhide) || ispath(path, /obj/item/stack/material/hairlesshide)

/proc/tanning_drum_hide_type(path)
	return tanning_drum_needs_wash(path) || ispath(path, /obj/item/stack/material/wethide) || ispath(path, /obj/item/stack/material/dryhide)

/obj/structure/tanning_drum
	name = "tanning drum"
	desc = "A powered wooden drum on a steel frame that tans hides into leather. Load hides at any stage and bark, fill it with water and tannin by hand or by pipe, and connect it to power. Each hide costs 5 tannin, plus 5 water if it has not been washed."
	icon = 'icons/obj/tanning_drum.dmi'
	icon_state = "tanning_drum"
	anchored = TRUE
	density = TRUE
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = FALSE
	flags = NOREACT
	powerneeded = 3
	// Hide pieces by stack type, as "[type]" = count, so ejection returns them as loaded.
	var/list/hides = list()
	var/bark = 0
	var/tmp/work_steps = 0
	var/tmp/working = FALSE
	var/tmp/wait_reason = null

/obj/structure/tanning_drum/New()
	..()
	create_reagents(TANNING_DRUM_VOLUME)
	fluid_mark_dirty()

/obj/structure/tanning_drum/persistence_runtime_var(key)
	return (key in list("work_steps", "working", "wait_reason", "powered")) || ..()

/obj/structure/tanning_drum/after_load()
	. = ..()
	var/list/clean = list()
	var/total = 0
	for (var/key in hides)
		var/path = text2path("[key]")
		var/count = round(text2num("[hides[key]]"))
		if (!tanning_drum_hide_type(path) || count < 1)
			continue
		count = min(count, TANNING_DRUM_HIDES - total)
		if (count < 1)
			break
		clean["[path]"] = (clean["[path]"] || 0) + count
		total += count
	hides = clean
	bark = clamp(round(bark), 0, TANNING_DRUM_BARK)
	work_steps = 0
	working = FALSE
	powered = FALSE
	fluid_mark_dirty()
	drum_wake()
	update_icon()

/obj/structure/tanning_drum/Destroy()
	factory_active_tanning_drums -= src
	drum_release_power()
	drum_eject()
	fluid_mark_dirty()
	return ..()

/obj/structure/tanning_drum/proc/hide_count()
	var/total = 0
	for (var/key in hides)
		total += hides[key]
	return total

/obj/structure/tanning_drum/proc/drum_wake()
	if (hide_count() > 0)
		factory_active_tanning_drums |= src

/obj/structure/tanning_drum/proc/drum_release_power()
	if (powersource)
		powersource.update_power(-powerneeded, 1, src)
	powered = FALSE

// Return every loaded hide and piece of bark to the drum's tile. Liquids stay.
/obj/structure/tanning_drum/proc/drum_eject()
	var/turf/T = get_turf(src)
	if (T)
		for (var/key in hides)
			var/path = text2path("[key]")
			if (tanning_drum_hide_type(path) && hides[key] > 0)
				new path(T, hides[key], FALSE)
		if (bark > 0)
			new /obj/item/stack/bark(T, bark)
	hides = list()
	bark = 0
	work_steps = 0
	working = FALSE
	update_icon()

/obj/structure/tanning_drum/update_icon()
	if (working)
		icon_state = "tanning_drum_on"
	else if (hide_count() > 0)
		icon_state = "tanning_drum_off"
	else
		icon_state = "tanning_drum"

// Units of a hide or bark stack the drum would take now.
/obj/structure/tanning_drum/proc/drum_room_for(obj/item/I)
	if (!anchored || !isturf(loc) || !istype(I, /obj/item/stack))
		return 0
	var/obj/item/stack/S = I
	if (tanning_drum_hide_type(S.type))
		return max(0, min(S.amount, TANNING_DRUM_HIDES - hide_count()))
	if (istype(S, /obj/item/stack/bark))
		return max(0, min(S.amount, TANNING_DRUM_BARK - bark))
	return 0

// Take amount units of a hide or bark stack into the hopper. Returns units taken.
/obj/structure/tanning_drum/proc/drum_load(obj/item/stack/S, amount)
	amount = min(amount, drum_room_for(S))
	if (amount <= 0)
		return 0
	var/path = S.type
	var/is_bark = istype(S, /obj/item/stack/bark)
	amount = factory_consume_units(S, amount)
	if (is_bark)
		bark += amount
	else
		hides["[path]"] = (hides["[path]"] || 0) + amount
	drum_wake()
	update_icon()
	return amount

// Liquids: water and tannin only, each kept up to TANNING_DRUM_LIQUID.
/obj/structure/tanning_drum/proc/liquid_room(id)
	if (id != "water" && id != "tannin")
		return 0
	return max(0, min(TANNING_DRUM_LIQUID - reagents.get_reagent_amount(id), reagents.get_free_space()))

/obj/structure/tanning_drum/fluid_demand_tier()
	return anchored && isturf(loc) ? FLUID_TIER_SINK : 0

/obj/structure/tanning_drum/fluid_demand(id)
	return anchored ? liquid_room(id) : 0

/obj/structure/tanning_drum/fluid_receive(id, amount, data)
	amount = min(amount, fluid_demand(id))
	if (amount <= 0)
		return 0
	. = fluid_add_to(reagents, id, amount, data)
	drum_wake()

// Pour the water and tannin from a container. Anything else stays in it.
/obj/structure/tanning_drum/proc/drum_pour(obj/item/weapon/reagent_containers/C, mob/user)
	if (!C.reagents || !C.is_open_container())
		to_chat(user, SPAN_WARNING("Open \the [C] first."))
		return 0
	var/moved = 0
	for (var/id in list("water", "tannin"))
		var/amount = min(C.reagents.get_reagent_amount(id), liquid_room(id))
		if (amount <= 0)
			continue
		var/data = C.reagents.get_data(id)
		C.reagents.remove_reagent(id, amount)
		moved += fluid_add_to(reagents, id, amount, data)
	if (moved > 0)
		to_chat(user, SPAN_NOTICE("You pour [round(moved)] units into \the [src]."))
		playsound(loc, 'sound/effects/slosh.ogg', 25, TRUE)
		drum_wake()
	else
		to_chat(user, SPAN_WARNING("\The [src] takes only water and tannin, and has no room for what \the [C] holds."))
	return moved

/obj/structure/tanning_drum/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/stack/cable_coil))
		connect_cable(user, W)
		return TRUE
	if (istype(W, /obj/item/weapon/reagent_containers))
		if (!user.Adjacent(src))
			return TRUE
		drum_pour(W, user)
		return TRUE
	if (istype(W, /obj/item/stack) && (tanning_drum_hide_type(W.type) || istype(W, /obj/item/stack/bark)))
		if (!crafting_node_allowed(user, "resource_processing"))
			to_chat(user, SPAN_WARNING("You don't know how to tan hides."))
			return TRUE
		if (!anchored || !isturf(loc))
			to_chat(user, SPAN_WARNING("\The [src] needs to be fastened in place first."))
			return TRUE
		var/obj/item/stack/S = W
		var/taken = drum_load(S, S.amount)
		if (taken > 0)
			to_chat(user, SPAN_NOTICE("You load [taken] [istype(W, /obj/item/stack/bark) ? "bark" : "hides"] into \the [src]."))
		else
			to_chat(user, SPAN_WARNING("\The [src]'s hopper is full."))
		return TRUE
	return ..()

/obj/structure/tanning_drum/attack_hand(mob/living/user)
	if (!istype(user) || user.incapacitated() || !user.Adjacent(src))
		return
	if (!hide_count() && !bark)
		to_chat(user, SPAN_NOTICE("\The [src] is empty."))
		return
	drum_eject()
	user.visible_message(SPAN_NOTICE("[user] empties the hopper of \the [src]."), SPAN_NOTICE("You empty the hopper of \the [src]."))

/obj/structure/tanning_drum/examine(mob/user, distance)
	..(user, distance)
	to_chat(user, SPAN_NOTICE("Its hopper holds [hide_count()] of [TANNING_DRUM_HIDES] hides and [bark] of [TANNING_DRUM_BARK] pieces of bark."))
	to_chat(user, SPAN_NOTICE("Its tank holds [round(reagents.get_reagent_amount("water"))] water and [round(reagents.get_reagent_amount("tannin"))] tannin."))
	if (working)
		to_chat(user, SPAN_NOTICE("It is turning."))
	else if (wait_reason)
		to_chat(user, SPAN_WARNING("It waits: [wait_reason]."))

/obj/structure/tanning_drum/proc/drum_wait(reason)
	wait_reason = reason
	if (working)
		working = FALSE
		update_icon()
	return FALSE

// The next hide stage to tan: washed hides first, as they need only tannin.
/obj/structure/tanning_drum/proc/next_hide()
	var/fallback = null
	for (var/key in hides)
		if (hides[key] < 1)
			continue
		if (!tanning_drum_needs_wash(text2path("[key]")))
			return key
		if (!fallback)
			fallback = key
	return fallback

// Soak bark for tannin whenever there is not enough to tan the next hide.
/obj/structure/tanning_drum/proc/drum_brew()
	if (bark < 1 || reagents.get_reagent_amount("tannin") >= TANNING_DRUM_COST || reagents.get_reagent_amount("water") < TANNING_DRUM_BARK_YIELD)
		return FALSE
	bark--
	reagents.remove_reagent("water", TANNING_DRUM_BARK_YIELD)
	reagents.add_reagent("tannin", TANNING_DRUM_BARK_YIELD)
	return TRUE

// One process step (a second). Returns TRUE when a leather sheet was made.
/obj/structure/tanning_drum/proc/drum_step()
	if (QDELETED(src) || !isturf(loc))
		factory_active_tanning_drums -= src
		return FALSE
	var/key = next_hide()
	if (!key)
		factory_active_tanning_drums -= src
		drum_release_power()
		wait_reason = null
		work_steps = 0
		if (working)
			working = FALSE
		update_icon()
		return FALSE
	if (!anchored)
		drum_release_power()
		return drum_wait("it is not fastened in place")
	if (!draw_cable_power())
		powered = FALSE
		return drum_wait("it has no power")
	powered = TRUE
	drum_brew()
	var/wash = tanning_drum_needs_wash(text2path("[key]"))
	if (wash && reagents.get_reagent_amount("water") < TANNING_DRUM_COST)
		return drum_wait("it needs water")
	if (reagents.get_reagent_amount("tannin") < TANNING_DRUM_COST)
		return drum_wait(bark ? "it needs water to soak its bark" : "it needs tannin or bark")
	var/turf/T = loc
	var/obj/item/stack/material/leather/target = null
	for (var/obj/item/stack/material/leather/L in T)
		if (L.type == /obj/item/stack/material/leather && L.amount < L.max_amount)
			target = L
			break
	if (!target && factory_loose_items(T) >= TANNING_DRUM_OUTPUT_LIMIT)
		return drum_wait("its tile is full")
	wait_reason = null
	if (!working)
		working = TRUE
		update_icon()
	if (++work_steps < TANNING_DRUM_STEPS)
		return FALSE
	work_steps = 0
	if (wash)
		reagents.remove_reagent("water", TANNING_DRUM_COST)
	reagents.remove_reagent("tannin", TANNING_DRUM_COST)
	hides[key]--
	if (hides[key] < 1)
		hides -= key
	if (target)
		target.amount++
		target.update_icon()
	else
		new /obj/item/stack/material/leather(T, 1, FALSE)
	if (!hide_count())
		working = FALSE
		update_icon()
	return TRUE

/proc/factory_tanning_drums_step()
	for (var/obj/structure/tanning_drum/D in factory_active_tanning_drums.Copy())
		if (QDELETED(D))
			factory_active_tanning_drums -= D
			continue
		D.drum_step()

// Factory ports: hides and bark in, leather out.
/obj/structure/tanning_drum/factory_accepts(obj/item/I, from_dir = 0)
	if (!factory_movable_item(I))
		return 0
	return drum_room_for(I)

/obj/structure/tanning_drum/factory_insert(obj/item/I, from_dir = 0)
	var/amount = factory_accepts(I, from_dir)
	if (amount <= 0)
		return 0
	return drum_load(I, amount)

/obj/structure/tanning_drum/factory_offer(to_dir = 0, filter_type = null)
	if (!anchored)
		return null
	return factory_offer_tile_output(src, list(/obj/item/stack/material/leather), filter_type)

/obj/structure/tanning_drum/factory_take(obj/item/I, atom/destination)
	return factory_take_tile_output(src, I, destination)

#undef TANNING_DRUM_HIDES
#undef TANNING_DRUM_BARK
#undef TANNING_DRUM_VOLUME
#undef TANNING_DRUM_LIQUID
#undef TANNING_DRUM_STEPS
#undef TANNING_DRUM_COST
#undef TANNING_DRUM_BARK_YIELD
#undef TANNING_DRUM_OUTPUT_LIMIT
