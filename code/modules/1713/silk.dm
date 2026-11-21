// Silk (Val, 2026-11-21; plan "Resin materials plan", PR 2).
//
// Mulberries: in the silk lands (Earth Asia; lands that are not continents keep
// theirs) a living broadleaf tree is a mulberry. Pick its leaves in grab intent
// with an empty hand. Now and then the leaves carry a clutch of silkworm eggs.
// Eggs travel and trade like any item, so silk can be raised on any land that
// gets mulberry leaves.
//
// Rearing: a silkworm tray takes one clutch of eggs and SILK_TRAY_LEAVES
// mulberry leaves, then the worms eat and spin for SILK_REAR_TIME. The tray
// gives SILK_TRAY_COCOONS cocoons and keeps the clutch for the next batch.
//
// Reeling: a hot open container holding water, used on cocoons, softens them
// and unwinds up to SILK_REEL_BATCH of them into silk thread, one thread each.
// The loom weaves silk thread into silk cloth (/material/silk, production.dm).
//
// The rearing timer is saved (rear_left), so a reload resumes the batch, as the
// tar kiln does. Nothing here sleeps outside the do_after waits.

#define SILK_PICK_TIME 40
#define SILK_PICK_LEAVES 2
#define SILK_EGG_CHANCE 25
#define SILK_TRAY_LEAVES 6
#define SILK_TRAY_COCOONS 6
#define SILK_REAR_TIME 6000 // ten minutes
#define SILK_REAR_STEP 50
#define SILK_REEL_BATCH 5
#define SILK_REEL_WATER 10
#define SILK_REEL_TIME 30

/proc/silk_lands()
	var/static/list/lands = list(MAP_NOMADS_EARTH_ASIA)
	return lands

// TRUE when broadleaf trees here are mulberries.
/proc/mulberries_here()
	if (!continent_home()) // continent_resources.dm
		return TRUE
	return map.ID in silk_lands()

/obj/structure/wild/tree/live_tree/proc/mulberry_tree()
	return type == /obj/structure/wild/tree/live_tree && health > 0 && radiation < 15 && mulberries_here()

// The waits and the egg roll, as procs so a test fixture can stand in for them.
/obj/structure/wild/tree/live_tree/proc/silk_pick_wait(mob/living/human/H)
	return do_after(H, SILK_PICK_TIME, src)

/obj/structure/wild/tree/live_tree/proc/silk_egg_roll()
	return prob(SILK_EGG_CHANCE)

/obj/item/stack/silk_cocoons/proc/silk_reel_wait(mob/living/human/H)
	return do_after(H, SILK_REEL_TIME, src)

// An empty hand on a tree in grab intent (wild.dm). TRUE when it was handled.
/proc/silk_pick_attack_hand(obj/structure/wild/W, mob/living/human/H)
	if (!istype(W, /obj/structure/wild/tree/live_tree) || W.type != /obj/structure/wild/tree/live_tree || !ishuman(H) || H.a_intent != I_GRAB || H.gorillaman)
		return FALSE
	var/obj/structure/wild/tree/live_tree/T = W
	if (!T.mulberry_tree())
		return FALSE
	if (T.leaves < 1)
		to_chat(H, SPAN_WARNING("This mulberry has been stripped of leaves. They grow back in time; try another tree."))
		return TRUE
	to_chat(H, SPAN_NOTICE("You start picking mulberry leaves..."))
	if (!T.silk_pick_wait(H) || QDELETED(T) || !T.mulberry_tree() || T.leaves < 1)
		return TRUE
	T.leaves--
	var/obj/item/stack/material/leaf/mulberry/L = new(get_turf(H), SILK_PICK_LEAVES)
	H.put_in_hands(L)
	if (T.silk_egg_roll())
		var/obj/item/silkworm_eggs/E = new(get_turf(H))
		H.put_in_hands(E)
		to_chat(H, SPAN_NOTICE("You pick some mulberry leaves. A clutch of tiny silkworm eggs clings to one of them."))
	else
		to_chat(H, SPAN_NOTICE("You pick some mulberry leaves."))
	return TRUE

/obj/item/stack/material/leaf/mulberry
	name = "mulberry leaves"
	desc = "Broad, glossy mulberry leaves. Silkworms eat nothing else."
	singular_name = "mulberry leaf"
	icon = 'icons/obj/silk.dmi'
	icon_state = "mulberry_leaves"

/obj/item/silkworm_eggs
	name = "silkworm eggs"
	desc = "A clutch of tiny grey silkworm eggs on a scrap of leaf. Put them in a silkworm tray with mulberry leaves to raise silkworms."
	icon = 'icons/obj/silk.dmi'
	icon_state = "silkworm_eggs"
	w_class = ITEM_SIZE_TINY
	value = 6

/obj/item/stack/silk_cocoons
	name = "silk cocoons"
	desc = "Pale silk cocoons. Soften them with a hot pot of water to unwind them into silk thread."
	singular_name = "silk cocoon"
	icon = 'icons/obj/silk.dmi'
	icon_state = "silk_cocoons"
	w_class = ITEM_SIZE_SMALL
	max_amount = 50
	value = 2
	flammable = TRUE

/obj/item/stack/silk_cocoons/New()
	..()
	update_icon()

/obj/item/stack/silk_cocoons/update_icon()
	icon_state = "silk_cocoons[pile_suffix(amount, list(13, 26, 39))]"

/obj/item/stack/silk_cocoons/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/weapon/reagent_containers) && ishuman(user))
		silk_reel(W, user)
		return
	return ..()

/obj/item/stack/silk_cocoons/proc/silk_reel(obj/item/weapon/reagent_containers/RG, mob/living/human/H)
	if (!RG.is_open_container() || !RG.reagents)
		to_chat(H, SPAN_WARNING("Open \the [RG] first."))
		return FALSE
	if (!RG.reagents.has_reagent("water", SILK_REEL_WATER))
		to_chat(H, SPAN_WARNING("You need [SILK_REEL_WATER] units of water in \the [RG] to soften the cocoons."))
		return FALSE
	if (!RG.is_hot())
		to_chat(H, SPAN_WARNING("The water needs to be hot. Heat \the [RG] over a fire in grab intent first."))
		return FALSE
	H.visible_message(SPAN_NOTICE("[H] softens cocoons in hot water and unwinds them."), SPAN_NOTICE("You soften the cocoons in the hot water and find the end of each thread."))
	if (!silk_reel_wait(H) || persistence_save_in_progress || QDELETED(src) || QDELETED(RG) || !RG.reagents || !RG.reagents.has_reagent("water", SILK_REEL_WATER))
		return FALSE
	var/reeled = min(amount, SILK_REEL_BATCH)
	if (reeled <= 0)
		return FALSE
	var/turf/site = get_turf(H)
	if (!use(reeled))
		return FALSE
	var/obj/item/stack/silk_thread/T = new(site, reeled)
	H.put_in_hands(T)
	to_chat(H, SPAN_NOTICE("You reel [reeled] cocoon\s into silk thread."))
	return TRUE

/obj/item/stack/silk_thread
	name = "silk thread"
	desc = "Fine, strong silk thread. Weave it at a loom into silk cloth."
	singular_name = "skein"
	icon = 'icons/obj/silk.dmi'
	icon_state = "silk_thread"
	w_class = ITEM_SIZE_SMALL
	max_amount = 50
	value = 3
	flammable = TRUE

/material/silk
	name = "silk"
	display_name = "silk"
	icon_colour = "#F3EBD3"
	hardness = 12
	weight = 3
	sheet_singular_name = "bolt"
	sheet_plural_name = "bolts"
	stack_type = /obj/item/stack/material/silk
	door_icon_base = "wood"
	flags = MATERIAL_PADDING
	resilience = 0.0
	density = 5
	firmness = 5
	toughness = 60
	wear = 25
	heat_limit = 150
	corrosion = 0
	spring = 40
	shaping = SHAPE_SEWN

/obj/item/stack/material/silk
	name = "silk"
	desc = "Smooth, light silk cloth. It is fine for clothing and stronger than it looks."
	icon = 'icons/obj/silk.dmi'
	icon_state = "silk"
	default_type = "silk"
	apply_colour = FALSE
	value = 8
	w_class = ITEM_SIZE_SMALL
	flammable = TRUE

/obj/item/stack/material/silk/New()
	update_icon()
	return ..()

/obj/item/stack/material/silk/update_icon()
	icon_state = "silk[pile_suffix(amount, list(13, 26, 39))]"

// ---- silkworm tray --------------------------------------------------------------

/obj/structure/silkworm_tray
	name = "silkworm tray"
	desc = "A shallow woven tray on a wooden frame for raising silkworms. Add a clutch of silkworm eggs and six mulberry leaves."
	icon = 'icons/obj/silk.dmi'
	icon_state = "silkworm_tray"
	anchored = TRUE
	density = FALSE
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = FALSE
	var/eggs = FALSE
	var/leaves = 0
	var/rear_left = 0 // ds of rearing left; saved, so a reload resumes the batch

/obj/structure/silkworm_tray/update_icon()
	if (rear_left > 0)
		icon_state = "silkworm_tray_active"
	else if (locate(/obj/item/stack/silk_cocoons) in get_turf(src))
		icon_state = "silkworm_tray_cocoons"
	else
		icon_state = "silkworm_tray"

/obj/structure/silkworm_tray/after_load()
	..()
	update_icon()
	if (rear_left > 0)
		addtimer(CALLBACK(src, PROC_REF(rear_tick)), SILK_REAR_STEP)

/obj/structure/silkworm_tray/examine(mob/user)
	..()
	if (rear_left > 0)
		to_chat(user, SPAN_NOTICE("Silkworms are eating and spinning; about [max(1, round(rear_left / 600, 0.5))] minute\s left."))
	else
		to_chat(user, SPAN_NOTICE("It holds [eggs ? "a clutch of silkworm eggs" : "no eggs"] and [leaves] of [SILK_TRAY_LEAVES] mulberry leaves."))

/obj/structure/silkworm_tray/attackby(obj/item/W, mob/user)
	update_icon()
	if (istype(W, /obj/item/silkworm_eggs))
		if (eggs)
			to_chat(user, SPAN_NOTICE("\The [src] already holds a clutch of eggs."))
			return
		user.remove_from_mob(W)
		qdel(W)
		eggs = TRUE
		to_chat(user, SPAN_NOTICE("You lay the silkworm eggs in \the [src]."))
		silk_try_start(user)
		return
	if (istype(W, /obj/item/stack/material/leaf/mulberry))
		var/obj/item/stack/material/leaf/mulberry/L = W
		if (rear_left > 0 || leaves >= SILK_TRAY_LEAVES)
			to_chat(user, SPAN_NOTICE("\The [src] has all the leaves it needs."))
			return
		var/used = min(SILK_TRAY_LEAVES - leaves, L.amount)
		if (used > 0 && L.use(used))
			leaves += used
			to_chat(user, SPAN_NOTICE("You spread [used] mulberry lea[used == 1 ? "f" : "ves"] in \the [src] ([leaves]/[SILK_TRAY_LEAVES])."))
			silk_try_start(user)
		return
	if (istype(W, /obj/item/stack/material/leaf))
		to_chat(user, SPAN_WARNING("Silkworms eat only mulberry leaves."))
		return
	return ..()

/obj/structure/silkworm_tray/attack_hand(mob/user)
	update_icon()
	if (eggs && rear_left <= 0 && ishuman(user))
		eggs = FALSE
		var/obj/item/silkworm_eggs/E = new(get_turf(src))
		user.put_in_hands(E)
		to_chat(user, SPAN_NOTICE("You take the silkworm eggs out of \the [src]."))
		return
	return ..()

/obj/structure/silkworm_tray/proc/silk_try_start(mob/user)
	if (!eggs || leaves < SILK_TRAY_LEAVES || rear_left > 0)
		return FALSE
	leaves = 0
	rear_left = SILK_REAR_TIME
	if (user)
		to_chat(user, SPAN_NOTICE("Tiny silkworms hatch and start on the leaves."))
	update_icon()
	addtimer(CALLBACK(src, PROC_REF(rear_tick)), SILK_REAR_STEP)
	return TRUE

/obj/structure/silkworm_tray/proc/rear_tick()
	if (QDELETED(src) || rear_left <= 0)
		return
	rear_left -= SILK_REAR_STEP
	if (rear_left > 0)
		addtimer(CALLBACK(src, PROC_REF(rear_tick)), SILK_REAR_STEP)
		return
	rear_left = 0
	new /obj/item/stack/silk_cocoons(get_turf(src), SILK_TRAY_COCOONS)
	update_icon()
	visible_message(SPAN_NOTICE("The silkworms in \the [src] have spun their cocoons. A few moths have left eggs for the next batch."))

#undef SILK_PICK_TIME
#undef SILK_PICK_LEAVES
#undef SILK_EGG_CHANCE
#undef SILK_TRAY_LEAVES
#undef SILK_TRAY_COCOONS
#undef SILK_REAR_TIME
#undef SILK_REAR_STEP
#undef SILK_REEL_BATCH
#undef SILK_REEL_WATER
#undef SILK_REEL_TIME
