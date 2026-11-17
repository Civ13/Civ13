// Attachment strip: a row of HUD tiles, one per accessory attached to a worn
// garment or belt. Clicking worn clothes that carry more than one attachment
// opens the strip; clicking a tile uses that one attachment, with the held
// item or with an empty hand, as clicking the clothes did when it carried
// only that attachment. The tiles belong to the client and are never saved.

/client/var/list/attachment_strip
/client/var/obj/item/clothing/attachment_strip_host
// The how-to line is shown the first time a strip opens for this client.
/client/var/attachment_strip_hint_shown = FALSE

/obj/screen/attachment
	name = "attachment"
	icon = 'icons/mob/screen/1713Style.dmi'
	icon_state = "block"
	layer = 19
	var/obj/item/clothing/accessory/attachment
	var/obj/item/clothing/host

/obj/screen/attachment/Destroy()
	attachment = null
	host = null
	return ..()

// The hover tooltip names the accessory this tile draws, only while the tile
// is in its viewer's open strip and the accessory still hangs from that strip's
// worn clothes.
/obj/screen/attachment/hover_item(mob/viewer)
	if (!viewer || !viewer.client)
		return null
	var/client/C = viewer.client
	if (C.attachment_strip_host != host || !(src in C.attachment_strip) || !(src in C.screen))
		return null
	if (!attachment_strip_valid(attachment, host, viewer))
		return null
	return attachment

// Screen positions for a strip of count tiles: one row, a row above where
// storage windows open (tile_x, tile_y), moved by the same whole-tile shift.
/proc/attachment_strip_locs(count, tile_x, tile_y, shift_x = 0, shift_y = 0)
	var/list/locs = list()
	for (var/i = 0, i < count, i++)
		locs += "[tile_x + shift_x + i]:16,[tile_y + shift_y + 1]:16"
	return locs

// TRUE while the attachment still hangs from clothing the mob wears or holds.
/proc/attachment_strip_valid(obj/item/clothing/accessory/A, obj/item/clothing/C, mob/M)
	return A && C && M && C.loc == M && (A in C.accessories)

/client/proc/hide_attachment_strip()
	if (!attachment_strip)
		return
	screen -= attachment_strip
	for (var/obj/screen/attachment/T in attachment_strip)
		qdel(T)
	attachment_strip = null
	attachment_strip_host = null

/mob/living/human/proc/hide_attachment_strip()
	if (client)
		client.hide_attachment_strip()

/mob/living/human/proc/show_attachment_strip(obj/item/clothing/C)
	hide_attachment_strip()
	if (!client || !istype(C) || C.loc != src || !C.accessories.len)
		return
	var/tile_x = 5
	var/tile_y = 2
	var/datum/hud/HUDdatum = global.HUDdatums[defaultHUD]
	if (HUDdatum)
		tile_x = HUDdatum.ConteinerData["Xslot"]
		tile_y = HUDdatum.ConteinerData["Yslot"]
	var/list/shift = hud_storage_shift((tile_x - 1) * 32 + 16, tile_y * 32 + 16, C.accessories.len * 32, 32)
	var/list/locs = attachment_strip_locs(C.accessories.len, tile_x, tile_y, shift[1], shift[2])
	var/list/tiles = list()
	var/i = 0
	for (var/obj/item/clothing/accessory/A in C.accessories)
		i++
		var/obj/screen/attachment/T = new()
		T.icon = client.prefs.UI_file
		T.name = A.name
		T.attachment = A
		T.host = C
		T.screen_loc = locs[i]
		var/image/picture = image(A.icon, icon_state = A.icon_state)
		picture.color = A.color
		T.overlays += picture
		tiles += T
	client.attachment_strip = tiles
	client.attachment_strip_host = C
	client.screen += tiles
	if (!client.attachment_strip_hint_shown)
		client.attachment_strip_hint_shown = TRUE
		to_chat(src, SPAN_NOTICE("Shift-click an attachment to examine it. Drag it to a hand or the floor, or right-click it and choose Take Off, to take it off."))

// Opens the strip for C, or closes it when it already shows C.
/mob/living/human/proc/toggle_attachment_strip(obj/item/clothing/C)
	if (client && client.attachment_strip_host == C)
		hide_attachment_strip()
		return
	show_attachment_strip(C)

// Redraws an open strip after C gained or lost an attachment.
/mob/living/human/proc/refresh_attachment_strip(obj/item/clothing/C)
	if (!client || client.attachment_strip_host != C)
		return
	if (C.loc == src && C.accessories.len > 1)
		show_attachment_strip(C)
	else
		hide_attachment_strip()

// The tile's attachment when this mob may act on it now, else null. A strip
// left behind by a body change or by clothes coming off is closed.
/obj/screen/attachment/proc/usable_attachment(mob/user)
	var/mob/living/human/H = user
	if (!istype(H))
		// The strip outlived the body it was opened on.
		if (user && user.client)
			user.client.hide_attachment_strip()
		return null
	if (!H.client || !(src in H.client.screen))
		return null
	if (H.stat || H.paralysis || H.stunned || H.weakened || H.restrained())
		return null
	if (!attachment_strip_valid(attachment, host, H))
		H.hide_attachment_strip()
		return null
	return attachment

/obj/screen/attachment/Click(location, control, params)
	var/mob/living/human/H = usr
	if (istype(H) && !H.canClick())
		return TRUE
	var/obj/item/clothing/accessory/A = usable_attachment(usr)
	if (!A)
		return TRUE
	var/obj/item/clothing/C = host
	// Shift-click examines, as it does any other carried item.
	var/list/modifiers = params2list(params)
	if (modifiers["shift"])
		attachment_strip_examine(H, A)
		return TRUE
	attachment_strip_use(H, A, C)
	H.refresh_attachment_strip(C)
	return TRUE

// Dragging a tile onto a hand takes the attachment into that hand; onto the
// floor next to the wearer, it is taken off and set down there.
/obj/screen/attachment/MouseDrop(over_object, src_location, over_location, src_control, over_control, params)
	var/obj/item/clothing/accessory/A = usable_attachment(usr)
	if (!A || over_object == src)
		return
	var/mob/living/human/H = usr
	var/obj/item/clothing/C = host
	if (istype(over_object, /obj/screen/inventory/hand))
		var/obj/screen/inventory/hand/hand_tile = over_object
		attachment_strip_take_off(H, A, C, hand_tile.slot_id)
	else
		var/turf/T = get_turf(over_object)
		if (T && !istype(over_object, /obj/screen))
			attachment_strip_set_down(H, A, C, T)

// Right-click menu entries for a strip tile.
/obj/screen/attachment/verb/examine_attachment()
	set name = "Examine Attachment"
	set category = null
	set src in usr.client.screen
	var/obj/item/clothing/accessory/A = usable_attachment(usr)
	if (A)
		attachment_strip_examine(usr, A)

/obj/screen/attachment/verb/take_off_attachment()
	set name = "Take Off"
	set category = null
	set src in usr.client.screen
	var/obj/item/clothing/accessory/A = usable_attachment(usr)
	if (A)
		attachment_strip_take_off(usr, A, host)

// Examines an attachment on the viewer's own worn clothes. It hangs off the
// wearer rather than on a turf, so the world sight read does not apply.
/proc/attachment_strip_examine(mob/living/human/H, obj/item/clothing/accessory/A)
	if (is_blind(H))
		to_chat(H, SPAN_NOTICE("You feel \a [A] hanging there."))
		return
	A.examine(H)
	if (A && !QDELETED(A))
		crafting_atlas_reference.examine_link(H, A)

// Takes an attachment off into a hand: hand_slot (slot_l_hand or slot_r_hand)
// when given, else the active hand, then the other one. With both hands full
// it lands at the wearer's feet, as any item put in full hands does.
/proc/attachment_strip_take_off(mob/living/human/H, obj/item/clothing/accessory/A, obj/item/clothing/C, hand_slot = null)
	if (!attachment_strip_valid(A, C, H))
		return FALSE
	if (hand_slot == slot_l_hand || hand_slot == slot_r_hand)
		if (H.get_equipped_item(hand_slot))
			to_chat(H, SPAN_WARNING("That hand is full."))
			return FALSE
		// The removal puts the item in the active hand; aim it at the chosen one.
		var/was_left = H.hand
		H.hand = (hand_slot == slot_l_hand)
		C.remove_accessory(H, A)
		H.hand = was_left
	else
		C.remove_accessory(H, A)
	return !(A in C.accessories)

// Takes an attachment off and sets it down on T, the wearer's tile or one
// next to it.
/proc/attachment_strip_set_down(mob/living/human/H, obj/item/clothing/accessory/A, obj/item/clothing/C, turf/T)
	if (!T || !attachment_strip_valid(A, C, H))
		return FALSE
	var/turf/here = get_turf(H)
	if (T != here && !H.Adjacent(T))
		return FALSE
	if (!attachment_strip_take_off(H, A, C))
		return FALSE
	if (A.loc == H)
		H.drop_from_inventory(A, T)
	else if (get_turf(A) != T)
		A.forceMove(T)
	return TRUE

// One click on a strip tile: the held item goes to the attachment; an empty
// hand opens an attachment that has its own use (a pouch, sheath or holster)
// and takes any other one (a necklace, a badge) off into the hand, which
// attached accessories otherwise refuse.
/proc/attachment_strip_use(mob/living/human/H, obj/item/clothing/accessory/A, obj/item/clothing/C)
	var/obj/item/I = H.get_active_hand()
	if (I)
		A.attackby(I, H)
	else if (A.strip_click_removes)
		C.remove_accessory(H, A)
	else
		A.attack_hand(H)

/obj/item/clothing/dropped(mob/user)
	. = ..()
	if (ishuman(user))
		var/mob/living/human/H = user
		if (H.client && H.client.attachment_strip_host == src)
			H.hide_attachment_strip()
