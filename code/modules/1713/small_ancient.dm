// Small things for the early ages (docs/small-ancient.md): clay tablets and a
// reed stylus, board games, the ice house and ice blocks cut from frozen water.

#define BOARD_GAME_TIME 200
#define ICE_HOUSE_SNOW 60 // minutes of cold per snow pile
#define ICE_HOUSE_ICE 180 // minutes of cold per block of cut ice
#define ICE_HOUSE_CAP 1200
// Below ground the earth stays cool: an ice house there melts a minute of
// cold every four minutes instead of every minute.
#define ICE_HOUSE_MELT_SECONDS 60
#define ICE_HOUSE_MELT_SECONDS_UNDERGROUND 240
#define ICE_BLOCK_WARM_MINUTES 40 // minutes above freezing before a loose block melts

// ---- clay tablets ----------------------------------------------------------------

// Written like paper while wet; fired in a kiln or oven it bakes hard: it can't
// burn and can't be written on any more.
/obj/item/weapon/paper/clay_tablet
	name = "clay tablet"
	desc = "A slab of wet clay to press writing into with a stylus. Fire it in a kiln to keep it for good."
	icon = 'icons/obj/small_ancient.dmi'
	icon_state = "clay_tablet"
	base_icon = "clay_tablet"
	flammable = FALSE
	var/fired = FALSE

/obj/item/weapon/paper/clay_tablet/update_icon()
	paper_stamp_refresh_overlays(src)
	icon_state = "[fired ? "clay_tablet_fired" : "clay_tablet"][has_document_writing() ? "_words" : ""]"

/obj/item/weapon/paper/clay_tablet/attackby(obj/item/P, mob/user)
	if (fired && istype(P, /obj/item/weapon/pen))
		to_chat(user, SPAN_WARNING("\The [src] is baked hard; nothing more can be pressed into it."))
		return
	return ..()

/obj/item/weapon/paper/clay_tablet/proc/fire_tablet()
	if (fired)
		return FALSE
	fired = TRUE
	name = "fired clay tablet"
	desc = "A tablet of baked clay. Whatever is written on it will outlast the one who wrote it."
	update_icon()
	return TRUE

/obj/item/weapon/pen/stylus
	name = "reed stylus"
	desc = "A cut reed with a wedge-shaped tip, for pressing writing into clay. It writes on paper too, after a fashion."
	icon = 'icons/obj/small_ancient.dmi'
	icon_state = "stylus"
	item_state = "pen"

// ---- board games -----------------------------------------------------------------

/obj/item/game_board
	name = "game board"
	desc = "A board and its pieces. Use it with someone beside you to play a game."
	icon = 'icons/obj/small_ancient.dmi'
	w_class = ITEM_SIZE_NORMAL
	var/game = "a game"
	var/tmp/busy = FALSE

/obj/item/game_board/persistence_runtime_var(key)
	return key == "busy" || ..()

/obj/item/game_board/senet
	name = "senet board"
	desc = "Thirty squares in three rows, with spools and cones for pieces and throwing sticks to move them. Use it with someone beside you to play."
	icon_state = "senet"
	game = "senet"

/obj/item/game_board/chess
	name = "chess set"
	desc = "A chequered board and carved pieces for the game of kings. Use it with someone beside you to play."
	icon_state = "chess"
	game = "chess"

/obj/item/game_board/proc/opponent(mob/living/human/user)
	for (var/mob/living/human/H in range(1, get_turf(src)))
		if (H != user && H.stat == CONSCIOUS && !H.lying && H.client)
			return H
	return null

/obj/item/game_board/attack_self(mob/living/human/user)
	play(user)

/obj/item/game_board/attack_hand(mob/living/human/user)
	if (isturf(loc))
		play(user)
		return
	return ..()

/obj/item/game_board/proc/play(mob/living/human/user, mob/living/human/other = null)
	if (!istype(user) || busy)
		return FALSE
	if (!other)
		other = opponent(user)
	if (!other)
		to_chat(user, SPAN_WARNING("You need someone beside you to play [game] with."))
		return FALSE
	busy = TRUE
	user.visible_message(SPAN_NOTICE("[user] and [other] settle down to a game of [game]."))
	var/done = do_after(user, BOARD_GAME_TIME, src)
	busy = FALSE
	if (!done || other.stat != CONSCIOUS || get_dist(other, get_turf(src)) > 1)
		return FALSE
	var/mob/living/human/winner = prob(50) ? user : other
	visible_message(SPAN_NOTICE("[winner] wins the game of [game]."))
	user.adjust_mood(5, "a game of [game]")
	other.adjust_mood(5, "a game of [game]")
	return winner

// ---- ice house -------------------------------------------------------------------

// Packed with snow, it keeps food as a freezer does. The snow melts a minute's
// worth at a time unless it is freezing out.
/obj/structure/closet/ice_house
	name = "ice house"
	desc = "A thick-walled box packed with straw. Pack snow or blocks of cut ice into it and food kept inside stays fresh far longer, until it melts. Built underground, where the earth stays cool, it melts far more slowly."
	icon = 'icons/obj/small_ancient.dmi'
	icon_state = "ice_house"
	icon_closed = "ice_house"
	icon_opened = "ice_house_open"
	anchored = TRUE
	var/cold = 0 // minutes
	var/tmp/melt_seconds = 0
	var/tmp/last_tick = 0

/obj/structure/closet/ice_house/persistence_runtime_var(key)
	return key == "melt_seconds" || key == "last_tick" || ..()

/obj/structure/closet/ice_house/on_runtime_spawn()
	..()
	if (cold > 0)
		start_melting()

/obj/structure/closet/ice_house/Destroy()
	processing_objects -= src
	return ..()

/obj/structure/closet/ice_house/proc/start_melting()
	last_tick = world.time
	processing_objects |= src

/obj/structure/closet/ice_house/proc/is_cold()
	return cold > 0

/obj/structure/closet/ice_house/attackby(obj/item/W, mob/user)
	var/added = 0
	if (istype(W, /obj/item/weapon/snowwall))
		added = ICE_HOUSE_SNOW
	else if (istype(W, /obj/item/weapon/ice_block))
		added = ICE_HOUSE_ICE
	if (added)
		if (cold + added > ICE_HOUSE_CAP)
			to_chat(user, SPAN_NOTICE("\The [src] is packed full."))
			return
		user.drop_from_inventory(W)
		qdel(W)
		cold += added
		start_melting()
		to_chat(user, SPAN_NOTICE("You pack \the [W] into \the [src]."))
		return
	return ..()

// Underground, on the cave level or in the caves, the earth keeps it cool.
/obj/structure/closet/ice_house/proc/underground()
	var/turf/T = get_turf(src)
	if (!T)
		return FALSE
	if (istype(get_area(T), /area/caribbean/void/caves))
		return TRUE
	return underground_depth_of(T.z) > 0

// Where the snow and ice last four times as long: underground, or in the
// insulated body of an ice car (train_stock.dm).
/obj/structure/closet/ice_house/proc/slow_melt()
	return underground()

/obj/structure/closet/ice_house/proc/slow_melt_text()
	return "Down here in the cool earth it melts slowly."

// What a close look tells about the cold left in it.
/obj/structure/closet/ice_house/proc/cold_text(mob/user)
	var/slow = slow_melt()
	to_chat(user, cold > 0 ? SPAN_NOTICE("It holds enough cold for about [slow ? cold * (ICE_HOUSE_MELT_SECONDS_UNDERGROUND / ICE_HOUSE_MELT_SECONDS) : cold] minutes of warm weather.") : SPAN_WARNING("The snow and ice in it have all melted."))
	if (slow)
		to_chat(user, SPAN_NOTICE(slow_melt_text()))

/obj/structure/closet/ice_house/examine(mob/user)
	..()
	if (get_dist(user, src) <= 1)
		cold_text(user)

/obj/structure/closet/ice_house/process_interval(configured_seconds = 2)
	if (QDELETED(src) || cold <= 0)
		processing_objects -= src
		return PROCESS_KILL
	melt_seconds += min(2, max(0, configured_seconds), max(0, (world.time - last_tick) / 10))
	last_tick = world.time
	if (melt_seconds < ICE_HOUSE_MELT_SECONDS)
		return
	var/melt_after = slow_melt() ? ICE_HOUSE_MELT_SECONDS_UNDERGROUND : ICE_HOUSE_MELT_SECONDS
	if (melt_seconds < melt_after)
		return
	melt_seconds -= melt_after
	if (get_temp(src) <= 0)
		return
	cold = max(0, cold - 1)

// ---- cut ice -----------------------------------------------------------------------

// Cut from the edge of an ice hole with a pick, hatchet or chisel (ice_fishing.dm).
// Packed into an ice house it holds three snow piles' worth of cold. Left out
// above freezing it melts away.
/obj/item/weapon/ice_block
	name = "block of ice"
	desc = "A heavy block of lake ice. Pack it into an ice house before it melts."
	icon = 'icons/obj/small_ancient.dmi'
	icon_state = "ice_block"
	w_class = ITEM_SIZE_LARGE
	flammable = FALSE
	value = 1
	var/warm_minutes = ICE_BLOCK_WARM_MINUTES
	var/tmp/melt_epoch = 0

/obj/item/weapon/ice_block/persistence_runtime_var(key)
	return key == "melt_epoch" || ..()

/obj/item/weapon/ice_block/New()
	..()
	schedule_melt()

/obj/item/weapon/ice_block/after_load()
	..()
	schedule_melt()

/obj/item/weapon/ice_block/proc/schedule_melt()
	melt_epoch++
	addtimer(CALLBACK(src, PROC_REF(melt_check), melt_epoch), 1 MINUTE)

/obj/item/weapon/ice_block/proc/melt_check(epoch)
	if (QDELETED(src) || epoch != melt_epoch)
		return FALSE
	if (get_temp(src) > 0)
		warm_minutes--
		if (warm_minutes <= 0)
			var/turf/T = get_turf(src)
			if (T)
				T.visible_message(SPAN_NOTICE("\The [src] melts away."))
			qdel(src)
			return TRUE
	schedule_melt()
	return TRUE

/obj/item/weapon/ice_block/examine(mob/user)
	..()
	if (warm_minutes < ICE_BLOCK_WARM_MINUTES / 2)
		to_chat(user, SPAN_WARNING("It is dripping and half melted."))

#undef BOARD_GAME_TIME
#undef ICE_HOUSE_SNOW
#undef ICE_HOUSE_ICE
#undef ICE_HOUSE_CAP
#undef ICE_HOUSE_MELT_SECONDS
#undef ICE_HOUSE_MELT_SECONDS_UNDERGROUND
#undef ICE_BLOCK_WARM_MINUTES
