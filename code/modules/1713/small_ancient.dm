// Small things for the early ages (docs/small-ancient.md): clay tablets and a
// reed stylus, board games and the ice house.

#define BOARD_GAME_TIME 200
#define ICE_HOUSE_SNOW 60 // minutes of cold per snow pile
#define ICE_HOUSE_CAP 600

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
	desc = "A thick-walled box packed with straw. Pack snow into it and food kept inside stays fresh far longer, until the snow melts."
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
	if (istype(W, /obj/item/weapon/snowwall))
		if (cold + ICE_HOUSE_SNOW > ICE_HOUSE_CAP)
			to_chat(user, SPAN_NOTICE("\The [src] is packed full of snow."))
			return
		user.drop_from_inventory(W)
		qdel(W)
		cold += ICE_HOUSE_SNOW
		start_melting()
		to_chat(user, SPAN_NOTICE("You pack the snow into \the [src]."))
		return
	return ..()

/obj/structure/closet/ice_house/examine(mob/user)
	..()
	if (get_dist(user, src) <= 1)
		to_chat(user, cold > 0 ? SPAN_NOTICE("It holds snow for about [cold] minutes.") : SPAN_WARNING("The snow in it has all melted."))

/obj/structure/closet/ice_house/process_interval(configured_seconds = 2)
	if (QDELETED(src) || cold <= 0)
		processing_objects -= src
		return PROCESS_KILL
	melt_seconds += min(2, max(0, configured_seconds), max(0, (world.time - last_tick) / 10))
	last_tick = world.time
	if (melt_seconds < 60)
		return
	melt_seconds -= 60
	if (get_temp(src) <= 0)
		return
	cold = max(0, cold - 1)

#undef BOARD_GAME_TIME
#undef ICE_HOUSE_SNOW
#undef ICE_HOUSE_CAP
