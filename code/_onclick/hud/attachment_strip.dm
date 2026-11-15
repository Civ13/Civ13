// Attachment strip: a row of HUD tiles, one per accessory attached to a worn
// garment or belt. Clicking worn clothes that carry more than one attachment
// opens the strip; clicking a tile uses that one attachment, with the held
// item or with an empty hand, as clicking the clothes did when it carried
// only that attachment. The tiles belong to the client and are never saved.

/client/var/list/attachment_strip
/client/var/obj/item/clothing/attachment_strip_host

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

/obj/screen/attachment/Click()
	var/mob/living/human/H = usr
	if (!istype(H))
		// The strip outlived the body it was opened on.
		if (usr && usr.client)
			usr.client.hide_attachment_strip()
		return TRUE
	if (!H.canClick())
		return TRUE
	if (H.stat || H.paralysis || H.stunned || H.weakened || H.restrained())
		return TRUE
	if (!attachment_strip_valid(attachment, host, H))
		H.hide_attachment_strip()
		return TRUE
	var/obj/item/clothing/C = host
	var/obj/item/I = H.get_active_hand()
	if (I)
		attachment.attackby(I, H)
	else
		attachment.attack_hand(H)
	H.refresh_attachment_strip(C)
	return TRUE

/obj/item/clothing/dropped(mob/user)
	. = ..()
	if (ishuman(user))
		var/mob/living/human/H = user
		if (H.client && H.client.attachment_strip_host == src)
			H.hide_attachment_strip()
