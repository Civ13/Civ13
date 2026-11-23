#define NOTICEBOARD_MAX_POSTS 5

/obj/structure/noticeboard
	name = "notice board"
	desc = "A board for pinning important notices upon."
	icon = 'icons/obj/structures.dmi'
	icon_state = "nboard00"
	density = FALSE
	anchored = TRUE
	not_movable = FALSE
	not_disassemblable = TRUE
	var/board_mount_dir = 0
	var/board_glass = FALSE
	var/board_glass_closed = FALSE
	var/datum/lock/board_lock

/obj/structure/noticeboard/persistence_runtime_var(key)
	return key == "overlays" || ..()

/obj/structure/noticeboard/initialize()
	..()
	// Preserve map-authored same-tile papers. Restores own their exact children;
	// after_load only refreshes appearance and never calls this mapper path.
	if (!restoring && isturf(loc))
		// A mapped wall offset is a mount, so a wrench takes it down cleanly
		// instead of unanchoring a board that still floats on the wall.
		if (!board_mount_dir)
			if (pixel_y == 32 && !pixel_x)
				board_mount_dir = NORTH
			else if (pixel_y == -32)
				board_mount_dir = SOUTH
			else if (pixel_x == 32 && !pixel_y)
				board_mount_dir = EAST
			else if (pixel_x == -32 && !pixel_y)
				board_mount_dir = WEST
		var/count = noticeboard_post_count()
		for (var/obj/item/weapon/paper/P in loc)
			if (count >= NOTICEBOARD_MAX_POSTS)
				break
			if (P.forceMove(src) && P.loc == src)
				count++
	update_icon()

/obj/structure/noticeboard/after_load()
	..()
	update_icon()

/obj/structure/noticeboard/proc/noticeboard_accepts(obj/item/I)
	return !QDELETED(I) && (istype(I, /obj/item/weapon/paper) || istype(I, /obj/item/weapon/photo) || istype(I, /obj/item/weapon/cartography_map) || istype(I, /obj/item/weapon/map) || istype(I, /obj/item/weapon/map_tdm))

/obj/structure/noticeboard/proc/noticeboard_post_count()
	var/count = 0
	for (var/obj/item/I in contents)
		if (I.loc == src && noticeboard_accepts(I))
			count++
	return count

/obj/structure/noticeboard/proc/noticeboard_can_read(mob/user)
	return !QDELETED(src) && isliving(user) && !QDELETED(user) && user.Adjacent(src)

/obj/structure/noticeboard/proc/noticeboard_can_handle(mob/user)
	return noticeboard_can_read(user) && !user.stat && !user.restrained()

/obj/structure/noticeboard/proc/noticeboard_blocks_changes()
	return board_glass && board_glass_closed

/obj/structure/noticeboard/proc/noticeboard_refresh()
	update_icon()
	GLOB.nanomanager.update_uis(src)

/obj/structure/noticeboard/update_icon()
	..()
	icon_state = "nboard0[min(NOTICEBOARD_MAX_POSTS, noticeboard_post_count())]"
	overlays.Cut()
	if (noticeboard_blocks_changes())
		var/image/pane = image('icons/obj/windows.dmi', icon_state = "window_clear")
		pane.alpha = 105
		overlays += pane

// Like wall-mounted paintings, the object stays on the accessible floor tile.
/obj/structure/noticeboard/proc/noticeboard_mount(mob/user)
	var/turf/T = loc
	var/facing = user.dir
	if (!isturf(T) || T.density || !(facing in cardinal) || !painting_is_wall_turf(get_step(T, facing)))
		to_chat(user, SPAN_WARNING("Face a solid wall beside the board to hang it."))
		return
	for (var/obj/structure/noticeboard/B in T)
		if (B != src && B.board_mount_dir == facing)
			to_chat(user, SPAN_WARNING("A noticeboard already hangs there."))
			return
	for (var/obj/structure/banner/B in T)
		if (B.banner_mount_dir == facing)
			to_chat(user, SPAN_WARNING("A banner already hangs there."))
			return
	if (painting_frame_occupies(T, facing))
		to_chat(user, SPAN_WARNING("A frame already hangs there."))
		return
	board_mount_dir = facing
	anchored = TRUE
	pixel_x = facing == EAST ? 32 : (facing == WEST ? -32 : 0)
	pixel_y = facing == NORTH ? 32 : (facing == SOUTH ? -32 : 0)
	add_fingerprint(user)
	noticeboard_refresh()
	to_chat(user, SPAN_NOTICE("You hang \the [src] on the wall."))

/obj/structure/noticeboard/proc/noticeboard_shatter(mob/user)
	if (!board_glass)
		return
	// The lock stays on the frame. No item is moved, copied or destroyed.
	board_glass = FALSE
	board_glass_closed = FALSE
	add_fingerprint(user)
	playsound(src, 'sound/effects/hit_on_shattered_glass.ogg', 70, TRUE)
	user.visible_message(SPAN_WARNING("[user] smashes the glass on \the [src]!"), SPAN_NOTICE("You smash the glass. The notices stay pinned."))
	noticeboard_refresh()

/obj/structure/noticeboard/attackby(obj/item/W, mob/user)
	var/mob/living/H = user
	if (!istype(H) || !noticeboard_can_handle(H) || QDELETED(W) || W.loc != H || !H.item_is_in_hands(W))
		return
	if (board_glass && H.a_intent == I_HARM && is_tool(W, TOOL_HAMMER))
		noticeboard_shatter(H)
		return
	if (board_glass && board_lock && (istype(W, /obj/item/weapon/key) || istype(W, /obj/item/weapon/storage/belt/keychain)))
		if (!board_lock.matching_key(W))
			to_chat(H, SPAN_WARNING("That key does not fit the noticeboard."))
			return
		board_glass_closed = !board_glass_closed
		add_fingerprint(H)
		noticeboard_refresh()
		to_chat(H, SPAN_NOTICE(board_glass_closed ? "You lock the glass cover." : "You unlock and open the glass cover."))
		return
	if (noticeboard_blocks_changes())
		to_chat(H, SPAN_WARNING("Open the glass cover before changing the notices."))
		return
	if (noticeboard_accepts(W))
		if (noticeboard_post_count() >= NOTICEBOARD_MAX_POSTS)
			to_chat(H, SPAN_NOTICE("There is no room for another notice."))
			return
		if (!H.transfer_held_item_to(W, src) || QDELETED(W) || W.loc != src)
			return
		W.add_fingerprint(H)
		add_fingerprint(H)
		noticeboard_refresh()
		to_chat(H, SPAN_NOTICE("You pin \the [W] to \the [src]."))
		return
	if (istype(W, /obj/item/stack/material/glass))
		if (board_glass)
			to_chat(H, SPAN_NOTICE("The board already has a glass cover."))
			return
		var/obj/item/stack/material/glass/G = W
		if (!G.use(1))
			return
		board_glass = TRUE
		board_glass_closed = FALSE
		add_fingerprint(H)
		noticeboard_refresh()
		to_chat(H, SPAN_NOTICE("You fit an open glass cover. Fit a keyed lock to secure it."))
		return
	if (istype(W, /obj/item/fitted_lock))
		var/obj/item/fitted_lock/F = W
		if (!board_glass || board_lock)
			to_chat(H, SPAN_NOTICE(board_lock ? "The board already has a lock." : "Fit a glass cover first."))
			return
		if (!F.family || !F.key_taken || !F.code)
			to_chat(H, SPAN_WARNING("Use a keyed lock and take its key out first."))
			return
		if (!H.transfer_held_item_to(F, src) || QDELETED(F) || F.loc != src)
			return
		board_lock = F.make_lock(H)
		qdel(F)
		add_fingerprint(H)
		noticeboard_refresh()
		to_chat(H, SPAN_NOTICE("You fit the lock. Use its key to close and lock the glass."))
		return
	if (is_tool(W, TOOL_HAMMER) && H.a_intent != I_HARM)
		noticeboard_mount(H)
		return
	if (is_tool(W, TOOL_WRENCH))
		if (powersource)
			to_chat(H, SPAN_NOTICE("Remove the cables first."))
			return
		if (!do_ship_fixture_after(H, 15, src) || !noticeboard_can_handle(H) || noticeboard_blocks_changes() || QDELETED(W) || W.loc != H || !H.item_is_in_hands(W))
			return
		if (!board_mount_dir)
			toggle_anchor(H)
			return
		board_mount_dir = 0
		pixel_x = initial(pixel_x)
		pixel_y = initial(pixel_y)
		add_fingerprint(H)
		noticeboard_refresh()
		to_chat(H, SPAN_NOTICE("You take \the [src] down from the wall."))
		return
	return ..()

/obj/structure/noticeboard/attack_hand(mob/user)
	examine(user)

/obj/structure/noticeboard/examine(mob/user)
	if (!user)
		user = usr
	if (noticeboard_can_read(user))
		ui_interact(user)
	else
		..()

/obj/structure/noticeboard/ui_actions(ui_key)
	return list("read", "remove", "cover")

/obj/structure/noticeboard/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open = TRUE)
	if (!noticeboard_can_read(user))
		return
	var/can_handle = noticeboard_can_handle(user)
	var/closed = noticeboard_blocks_changes()
	var/list/items = list()
	for (var/obj/item/I in contents)
		if (I.loc != src || !noticeboard_accepts(I))
			continue
		var/list/buttons = list(panel_button("Read", "read", "\ref[I]"))
		if (can_handle && !closed)
			buttons += list(panel_button("Remove", "remove", "\ref[I]"))
		items += list(panel_item(I.name, null, buttons))
	var/list/cover_buttons
	if (can_handle && board_glass && !board_lock)
		cover_buttons = list(panel_button(closed ? "Open Glass" : "Close Glass", "cover"))
	var/cover_text = !board_glass ? "Open board: anyone nearby can pin or remove notices." : (closed ? "Glass closed: you can still read the notices." : "Glass open: notices can be pinned or removed.")
	if (board_glass && board_lock)
		cover_text += " Use its key to [closed ? "open" : "close"] the glass."
	open_panel(user, "Notices", 420, 400, list(panel_section("Noticeboard", notes = list(cover_text), items = items, buttons = cover_buttons, empty = "Nothing is pinned here.")), ui = ui, force_open = force_open)

/obj/structure/noticeboard/Topic(href, href_list)
	if (..())
		return
	var/mob/user = usr
	if (!noticeboard_can_read(user))
		return
	user.set_using_object(src)
	if (href_list["cover"])
		if (noticeboard_can_handle(user) && board_glass && !board_lock)
			board_glass_closed = !board_glass_closed
			add_fingerprint(user)
			noticeboard_refresh()
		return
	if (href_list["remove"])
		// A stale panel is not permission to take a notice through closed glass.
		if (!noticeboard_can_handle(user) || noticeboard_blocks_changes())
			return
		var/obj/item/P = locate(href_list["remove"]) in src
		var/turf/T = get_turf(src)
		if (!noticeboard_accepts(P) || P.loc != src || !T || !P.forceMove(T) || QDELETED(P) || P.loc != T)
			return
		P.add_fingerprint(user)
		add_fingerprint(user)
		noticeboard_refresh()
		return
	if (href_list["read"])
		var/obj/item/I = locate(href_list["read"]) in src
		if (noticeboard_accepts(I) && I.loc == src)
			noticeboard_read_post(user, I)

/obj/structure/noticeboard/proc/noticeboard_read_post(mob/user, obj/item/I)
	// Only read-only per-type viewers; a chart's attack_self would redraw it.
	if (istype(I, /obj/item/weapon/paper))
		var/obj/item/weapon/paper/P = I
		P.show_document(user, FALSE, "noticeboard", src)
	else if (istype(I, /obj/item/weapon/photo))
		var/obj/item/weapon/photo/P = I
		if (P.img)
			P.show(user)
	else if (istype(I, /obj/item/weapon/cartography_map))
		var/obj/item/weapon/cartography_map/M = I
		M.read_map(user)
	else if (istype(I, /obj/item/weapon/map))
		var/obj/item/weapon/map/M = I
		M.examine(user)
	else if (istype(I, /obj/item/weapon/map_tdm))
		var/obj/item/weapon/map_tdm/M = I
		M.examine(user)

#undef NOTICEBOARD_MAX_POSTS

////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////MAIL//SYSTEM/////////////////////////////////
/obj/structure/mailbox
	name = "mail bag"
	desc = "A bag of mail, to be distributed to other colonial administrations."
	icon = 'icons/obj/storage.dmi'
	icon_state = "mailbag"
	density = FALSE
	anchored = TRUE
	var/faction = FALSE
	var/receive_only = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE
/obj/structure/mailbox/processor
	invisibility = 101

/obj/structure/mailbox/received
	name = "received mail bag"
	desc = "A bag of mail, with received objects from other colonies."
	icon = 'icons/obj/storage.dmi'
	icon_state = "mailbag"
	density = FALSE
	anchored = TRUE
	receive_only = TRUE

/obj/structure/mailbox/spanish
	name = "Spanish mail bag"
	desc = "A bag of mail, to be delivered to the Spanish colonial administration."
	faction = "spanish"

/obj/structure/mailbox/dutch
	name = "Dutch mail bag"
	desc = "A bag of mail, to be delivered to the Dutch colonial administration."
	faction = "dutch"

/obj/structure/mailbox/portuguese
	name = "Portuguese mail bag"
	desc = "A bag of mail, to be delivered to the Dutch colonial administration."
	faction = "portuguese"

/obj/structure/mailbox/french
	name = "French mail bag"
	desc = "A bag of mail, to be delivered to the French colonial administration."
	faction = "french"

/obj/structure/mailbox/british
	name = "British mail bag"
	desc = "A bag of mail, to be delivered to the British colonial administration."
	faction = "british"

/obj/structure/mailbox/attackby(var/obj/item/weapon/paper/W as obj, var/mob/living/human/H as mob)
	if (receive_only == TRUE)
		to_chat(H, "This is only for received letters! It won't be delivered if you put it here!")
		return
	if (!istype(W, /obj/item/weapon/paper))
		to_chat(H, "You cannot send this by mail. Only paper is accepted.")
		return
	if (copy_paper_delivery(W, H))
		to_chat(H, "Your message has been sent and will be delivered soon.")
	else
		to_chat(H, "Your letter could not be sent.")
	return
