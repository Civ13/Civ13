// Player HUD layout: a scale for the whole HUD, plus per-tile position, size
// and lock, saved per HUD style in the player's preferences.
//
// A position is kept per axis as an anchor (WEST/CENTER/EAST, SOUTH/CENTER/NORTH)
// and the pixel offset of the tile's lower-left corner from that anchor point
// (the left edge, the centre, or the right edge of the view). BYOND resolves
// the anchor keywords itself, so tiles stay on their edge when the view resizes.
// Stored offsets are unscaled, so changing the HUD scale keeps a custom layout.

#define HUD_LAYOUT_MIN_SIZE 0.5
#define HUD_LAYOUT_MAX_SIZE 3
#define HUD_LAYOUT_SIZE_STEP 0.25

var/global/list/hud_scale_choices = list("50%" = 0.5, "75%" = 0.75, "100%" = 1, "125%" = 1.25, "150%" = 1.5, "175%" = 1.75, "200%" = 2)

/datum/preferences
	var/hud_scale = 1
	// Size of the hover name text under the mouse, separate from hud_scale.
	var/hover_text_scale = 1
	// FALSE hides the hover name panel under the mouse (OOC > Toggle Hover Text).
	var/hover_text_enabled = TRUE
	// Entries "style~key~ax~ox~ay~oy~size~locked"; ax is "D" when the tile
	// keeps its default position.
	var/list/hud_layout = list()

/client
	var/hud_edit_mode = FALSE
	// Stands in for the open storage window while editing; never on screen.
	var/obj/screen/hud_storage_handle = null
	var/hud_grab_x = 0
	var/hud_grab_y = 0

/obj/screen
	var/hud_layout_key = null
	var/hud_default_loc = null
	var/hud_size = 1
	var/hud_ax = null
	var/hud_ox = 0
	var/hud_ay = null
	var/hud_oy = 0
	// Action buttons move as one bar; this is a button's offset from the first.
	var/hud_rel_x = 0
	var/hud_rel_y = 0

////////////////////////// screen_loc helpers //////////////////////////

// One axis of a screen_loc, e.g. "EAST-1:28", "7:5" or "CENTER".
// Returns list(anchor, pixel offset of the tile's lower-left from the anchor point).
/proc/hud_parse_axis(text, horizontal)
	var/px = 0
	var/colon = findtext(text, ":")
	if (colon)
		px = text2num(copytext(text, colon + 1))
		if (!isnum(px))
			px = 0
		text = copytext(text, 1, colon)
	text = trim(uppertext(text))
	var/low = horizontal ? "WEST" : "SOUTH"
	var/high = horizontal ? "EAST" : "NORTH"
	var/anchor = low
	var/base = 0
	var/shift_text = null
	if (findtext(text, low) == 1)
		shift_text = copytext(text, length(low) + 1)
	else if (findtext(text, high) == 1)
		anchor = high
		base = -32
		shift_text = copytext(text, length(high) + 1)
	else if (findtext(text, "CENTER") == 1)
		anchor = "CENTER"
		base = -16
		shift_text = copytext(text, 7)
	else
		var/tile = text2num(text)
		if (!isnum(tile))
			return null
		base = (tile - 1) * 32
	if (shift_text)
		var/shift = text2num(replacetext(shift_text, "+", ""))
		if (isnum(shift))
			base += shift * 32
	return list(anchor, base + px)

// Returns list(ax, ox, ay, oy) for a single-position screen_loc, or null.
/proc/hud_parse_screen_loc(loc)
	if (!istext(loc) || findtext(loc, " to ") || findtext(loc, ".map"))
		return null
	var/list/parts = splittext(loc, ",")
	if (parts.len != 2)
		return null
	var/list/X = hud_parse_axis(parts[1], TRUE)
	var/list/Y = hud_parse_axis(parts[2], FALSE)
	if (!X || !Y)
		return null
	return list(X[1], X[2], Y[1], Y[2])

/proc/hud_axis_text(anchor, offset)
	offset = round(offset)
	switch (anchor)
		if ("EAST", "NORTH")
			offset += 32
		if ("CENTER")
			offset += 16
	return "[anchor]:[offset]"

// Scales a w x h pixel icon (32x32 unless given) by k about its lower-left
// corner. BYOND scales about the icon's centre, so a taller icon such as the
// body part selector needs its own height here or it drifts up or down.
/proc/hud_scale_matrix(k, w = 32, h = 32)
	if (k == 1)
		return null
	return matrix(k, 0, w / 2 * (k - 1), 0, k, h / 2 * (k - 1))

// True for identity and for matrices made by hud_scale_matrix(), so the HUD
// never overwrites an item's own rotation or flip.
/proc/is_hud_scale_matrix(matrix/M)
	if (!M)
		return TRUE
	if (M.b != 0 || M.d != 0 || M.a != M.e)
		return FALSE
	return abs(M.c - 16 * (M.a - 1)) < 0.01 && abs(M.f - 16 * (M.a - 1)) < 0.01

/proc/hud_scale_item(obj/item/I, obj/screen/slot)
	if (!I || !is_hud_scale_matrix(I.transform))
		return
	I.transform = slot ? slot.transform : null

/proc/hud_unscale_item(obj/item/I)
	if (I && I.transform && is_hud_scale_matrix(I.transform))
		I.transform = null

// Pixel position of a screen-loc mouse parameter ("[map:]x:px,y:py"),
// counted from the view's lower-left. Returns list(x, y) or null.
/proc/hud_mouse_pixels(params)
	var/list/P = params2list(params)
	var/loc = P ? P["screen-loc"] : null
	if (!loc)
		return null
	var/list/parts = splittext(loc, ",")
	if (parts.len != 2)
		return null
	var/list/out = list()
	for (var/i = 1 to 2)
		var/list/bits = splittext(parts[i], ":")
		if (bits.len < 2)
			return null
		var/tile = text2num(bits[bits.len - 1])
		var/px = text2num(bits[bits.len])
		if (!isnum(tile) || !isnum(px))
			return null
		out += (tile - 1) * 32 + px
	return out

/proc/hud_anchor_origin(anchor, size_px)
	switch (anchor)
		if ("EAST", "NORTH")
			return size_px
		if ("CENTER")
			return size_px / 2
	return 0

////////////////////////// layout storage //////////////////////////

/datum/preferences/proc/hud_layout_entry(style, key)
	var/prefix = "[style]~[key]~"
	for (var/entry in hud_layout)
		if (istext(entry) && findtext(entry, prefix) == 1)
			var/list/F = splittext(entry, "~")
			if (F.len != 8)
				continue
			return F
	return null

/datum/preferences/proc/set_hud_layout_entry(style, key, list/F)
	var/prefix = "[style]~[key]~"
	for (var/entry in hud_layout.Copy())
		if (istext(entry) && findtext(entry, prefix) == 1)
			hud_layout -= entry
	if (F)
		hud_layout += jointext(F, "~")

/datum/preferences/proc/sanitize_hud_scale()
	if (!isnum(hud_scale) || hud_scale < 0.5 || hud_scale > 3)
		hud_scale = 1

////////////////////////// reflow at large scales //////////////////////////

// A default tile scales toward the screen edge or centre it sits nearest.
/proc/hud_infer_anchor(list/D, view_w, view_h)
	var/x = hud_anchor_origin(D[1], view_w) + D[2]
	var/y = hud_anchor_origin(D[3], view_h) + D[4]
	var/cx = x + 16
	var/cy = y + 16
	var/ax = cx < view_w / 3 ? "WEST" : (cx > view_w * 2 / 3 ? "EAST" : "CENTER")
	var/ay = cy < view_h / 3 ? "SOUTH" : (cy > view_h * 2 / 3 ? "NORTH" : "CENTER")
	return list(ax, x - hud_anchor_origin(ax, view_w), ay, y - hud_anchor_origin(ay, view_h))

// Splits list(tile, x, y, w, h) entries into runs that overlap along one axis
// (2 = x, 3 = y) at 100%, so tiles that share a spot or a column move together.
// w and h are the tile's footprint in pixels at 100% (32 when left out).
/proc/hud_flow_groups(list/entries, axis)
	var/list/sorted = list()
	for (var/list/T in entries)
		var/i = 1
		while (i <= sorted.len)
			var/list/O = sorted[i]
			if (O[axis] > T[axis])
				break
			i++
		sorted.Insert(i, list(T))
	. = list()
	var/list/current = null
	var/current_end = 0
	for (var/list/T in sorted)
		if (current && T[axis] < current_end)
			current += list(T)
		else
			current = list(T)
			. += list(current)
		current_end = max(current_end, T[axis] + hud_flow_extent(T, axis))

/proc/hud_flow_extent(list/T, axis)
	return T.len >= axis + 2 ? T[axis + 2] : 32

/proc/hud_flow_place(obj/screen/S, x, y, g, view_w, view_h, w = 32, h = 32)
	x = clamp(x, 0, max(0, view_w - w * g))
	y = clamp(y, 0, max(0, view_h - h * g))
	S.hud_ax = (x + w * g / 2 > view_w / 2) ? "EAST" : "WEST"
	S.hud_ox = x - hud_anchor_origin(S.hud_ax, view_w)
	S.hud_ay = "SOUTH"
	S.hud_oy = y
	S.screen_loc = "[hud_axis_text(S.hud_ax, S.hud_ox)],[hud_axis_text(S.hud_ay, S.hud_oy)]"

// Above 100% the default HUD no longer fits a standard view. The right-hand
// status column stacks up the right edge, wrapping leftward when too tall;
// every other column of tiles drops into the lowest free spot from the left,
// so the bar wraps into extra rows instead of overlapping.
/proc/hud_reflow(list/flow, g, view_w, view_h)
	var/s = 32 * g
	var/list/east = list()
	var/list/rest = list()
	for (var/list/T in flow)
		if (T[2] + 16 > view_w - 32)
			east += list(T)
		else
			rest += list(T)
	var/east_w = 0
	if (east.len)
		east_w = s
		var/col_x = view_w - s
		var/y = 0
		for (var/list/G in hud_flow_groups(east, 3))
			var/y0 = G[1][3]
			var/y1 = y0
			for (var/list/T in G)
				y0 = min(y0, T[3])
				y1 = max(y1, T[3] + hud_flow_extent(T, 3))
			var/gh = (y1 - y0) * g
			if (y > 0 && y + gh > view_h)
				col_x -= s
				east_w += s
				y = 0
			for (var/list/T in G)
				hud_flow_place(T[1], col_x, y + (T[3] - y0) * g, g, view_w, view_h, hud_flow_extent(T, 2), hud_flow_extent(T, 3))
			y += gh
	var/limit = round(view_w - east_w)
	var/step = 4
	var/list/sky = new /list(round(limit / step) + 1)
	for (var/i = 1 to sky.len)
		sky[i] = 0
	for (var/list/G in hud_flow_groups(rest, 2))
		var/x0 = G[1][2]
		var/x1 = x0
		var/y0 = G[1][3]
		var/y1 = y0
		for (var/list/T in G)
			x0 = min(x0, T[2])
			x1 = max(x1, T[2] + hud_flow_extent(T, 2))
			y0 = min(y0, T[3])
			y1 = max(y1, T[3] + hud_flow_extent(T, 3))
		var/gw = (x1 - x0) * g
		var/gh = (y1 - y0) * g
		var/cells = max(1, round(-(-gw / step)))
		var/best_cell = 1
		var/best_top = null
		for (var/c = 1, c + cells - 1 <= sky.len, c++)
			var/top = 0
			for (var/j = c, j < c + cells, j++)
				top = max(top, sky[j])
			if (isnull(best_top) || top < best_top - 0.01)
				best_top = top
				best_cell = c
		if (isnull(best_top))
			best_top = 0
		for (var/j = best_cell, j < min(sky.len + 1, best_cell + cells), j++)
			sky[j] = best_top + gh
		var/gx = (best_cell - 1) * step
		for (var/list/T in G)
			hud_flow_place(T[1], gx + (T[2] - x0) * g, best_top + (T[3] - y0) * g, g, view_w, view_h, hud_flow_extent(T, 2), hud_flow_extent(T, 3))

// Where a storage window goes, in whole tiles from its usual place.
// x0/y0: the window's usual lower-left pixel; w/h: its size in pixels.
// custom: list(x, y) the player dragged it to, or null. rects: list(x, y, size)
// or list(x, y, w, h) of the HUD tiles on screen. Above 100% a window in its usual place moves up
// clear of the tiles below it. The window always stays on screen.
/proc/hud_storage_shift_for(x0, y0, w, h, g, view_w, view_h, list/custom, list/rects)
	var/dx = 0
	var/dy = 0
	if (custom)
		dx = round((custom[1] - x0) / 32, 1)
		dy = round((custom[2] - y0) / 32, 1)
	else if (g > 1)
		var/top = y0
		for (var/list/R in rects)
			var/rh = R.len >= 4 ? R[4] : R[3]
			if (R[1] < x0 + w && R[1] + R[3] > x0 && R[2] < view_h / 2)
				top = max(top, R[2] + rh)
		dy = -round(-(top - y0) / 32)
	var/min_dx = -round(x0 / 32)
	var/min_dy = -round(y0 / 32)
	dx = max(min_dx, min(dx, round((view_w - w - x0) / 32)))
	dy = max(min_dy, min(dy, round((view_h - h - y0) / 32)))
	return list(dx, dy)

////////////////////////// applying the layout //////////////////////////

var/global/list/hud_icon_px_cache = list()

// The tile's icon size in pixels, which the scale matrix needs.
/obj/screen/proc/hud_icon_px()
	if (!icon)
		return list(32, 32)
	var/key = "[icon]"
	var/list/px = hud_icon_px_cache[key]
	if (!px)
		var/icon/I = icon(icon)
		px = list(I.Width() || 32, I.Height() || 32)
		hud_icon_px_cache[key] = px
	return px

// Enlarged tiles keep sharp pixels. Shrunk tiles stay smoothed: dropping
// whole pixel rows below 100% garbles the lettering on buttons.
/proc/hud_pixel_scale(atom/A, k)
	if (k > 1)
		A.appearance_flags |= PIXEL_SCALE
	else
		A.appearance_flags &= ~PIXEL_SCALE

// The space the tile takes on screen at 100%, including offset overlays.
/obj/screen/proc/hud_footprint()
	return hud_icon_px()

// Called after the tile's scale changes; k is its total scale.
/obj/screen/proc/hud_rescaled(k)
	return

// The swap button is two 32px halves: the left icon and a right overlay one
// tile over. Overlay offsets are not scaled by the transform, so the right
// half's offset follows the scale or the button splits apart (below 100%) or
// overlaps itself (above).
/obj/screen/swap/hud_footprint()
	return list(64, 32)

/obj/screen/swap/hud_rescaled(k)
	overlays.Cut()
	var/image/right = image(icon = icon, icon_state = "swap-r", pixel_x = 32 * k)
	hud_pixel_scale(right, k)
	overlays += right

/mob/living/human/proc/hud_layout_elements()
	. = list()
	for (var/name in HUDneed)
		if (name == "hover name")
			continue
		var/obj/screen/S = HUDneed[name]
		if (istype(S))
			if (!S.hud_layout_key)
				S.hud_layout_key = "need:[name]"
			. += S
	for (var/obj/screen/inventory/S in HUDinventory)
		if (!S.hud_layout_key)
			S.hud_layout_key = "inv:[S.slot_id]"
		. += S
	if (hud_used)
		for (var/obj/screen/S in hud_used.vehicle_hud)
			if (!S.hud_layout_key)
				S.hud_layout_key = "veh:[S.type]"
			. += S

// Action buttons in bar order, skipping any an older drag pinned in place.
/mob/living/human/proc/hud_action_buttons()
	. = list()
	for (var/datum/action/A in actions)
		var/obj/screen/movable/action_button/B = A.button
		. += B
	for (var/obj/screen/movable/action_button/B in .)
		if (B.moved)
			. -= B

/mob/living/human/update_action_buttons()
	..()
	apply_action_bar_layout()

// The action bar keeps its default spacing; its first button is the bar's
// position, and HUD scale and the bar's size scale the whole bar.
/mob/living/human/proc/apply_action_bar_layout()
	if (!client || !client.prefs || !hud_used)
		return
	var/datum/preferences/P = client.prefs
	P.sanitize_hud_scale()
	var/g = P.hud_scale
	var/size = 1
	var/list/D1 = hud_parse_screen_loc(hud_used.ButtonNumberToScreenCoords(1))
	if (!D1)
		return
	var/list/bar = D1
	var/list/F = P.hud_layout_entry(defaultHUD, "actions")
	if (F)
		var/stored_size = text2num(F[7])
		if (isnum(stored_size))
			size = clamp(stored_size, HUD_LAYOUT_MIN_SIZE, HUD_LAYOUT_MAX_SIZE)
		if (F[3] != "D")
			var/ox = text2num(F[4])
			var/oy = text2num(F[6])
			if (isnum(ox) && isnum(oy) && (F[3] in list("WEST", "CENTER", "EAST")) && (F[5] in list("SOUTH", "CENTER", "NORTH")))
				bar = list(F[3], ox, F[5], oy)
	var/k = g * size
	var/list/V = getviewsize(client.view)
	var/view_w = V[1] * 32
	var/view_h = V[2] * 32
	var/x0 = hud_anchor_origin(bar[1], view_w)
	var/y0 = hud_anchor_origin(bar[3], view_h)
	var/n = 0
	for (var/datum/action/A in actions)
		n++
		var/obj/screen/movable/action_button/B = A.button
		if (!B || B.moved)
			continue
		var/list/Dn = hud_parse_screen_loc(hud_used.ButtonNumberToScreenCoords(n))
		if (!Dn)
			continue
		B.hud_layout_key = "actions"
		B.hud_size = size
		B.hud_rel_x = (Dn[2] - D1[2]) * k
		B.hud_rel_y = (Dn[4] - D1[4]) * k
		B.hud_ax = bar[1]
		B.hud_ay = bar[3]
		B.hud_ox = clamp(x0 + bar[2] * g + B.hud_rel_x, 0, max(0, view_w - 32 * k)) - x0
		B.hud_oy = clamp(y0 + bar[4] * g + B.hud_rel_y, 0, max(0, view_h - 32 * k)) - y0
		B.screen_loc = "[hud_axis_text(B.hud_ax, B.hud_ox)],[hud_axis_text(B.hud_ay, B.hud_oy)]"
		B.transform = hud_scale_matrix(k)
		hud_pixel_scale(B, k)
		if (client.hud_edit_mode)
			B.color = hud_tile_locked(B) ? "#ff8a8a" : "#9cff9c"

/mob/living/human/proc/apply_hud_layout()
	if (!client || !client.prefs)
		return
	var/datum/preferences/P = client.prefs
	P.sanitize_hud_scale()
	var/g = P.hud_scale
	var/list/V = getviewsize(client.view)
	var/view_w = V[1] * 32
	var/view_h = V[2] * 32
	// Default inventory and control tiles above 100% are reflowed together so
	// they never cover each other; entries are list(tile, x, y, w, h) at 100%.
	var/list/flow = list()
	for (var/obj/screen/S in hud_layout_elements())
		if (!S.hud_default_loc)
			S.hud_default_loc = S.screen_loc
		var/list/D = hud_parse_screen_loc(S.hud_default_loc)
		if (!D)
			continue
		var/list/foot = S.hud_footprint()
		var/list/px = S.hud_icon_px()
		var/size = 1
		var/custom = FALSE
		var/list/F = P.hud_layout_entry(defaultHUD, S.hud_layout_key)
		if (F)
			var/stored_size = text2num(F[7])
			if (isnum(stored_size))
				size = clamp(stored_size, HUD_LAYOUT_MIN_SIZE, HUD_LAYOUT_MAX_SIZE)
			if (F[3] != "D")
				var/ox = text2num(F[4])
				var/oy = text2num(F[6])
				if (isnum(ox) && isnum(oy) && (F[3] in list("WEST", "CENTER", "EAST")) && (F[5] in list("SOUTH", "CENTER", "NORTH")))
					D = list(F[3], ox, F[5], oy)
					custom = TRUE
		if (!custom)
			D = hud_infer_anchor(D, view_w, view_h)
			if (g > 1 && size == 1 && (findtext(S.hud_layout_key, "need:") == 1 || findtext(S.hud_layout_key, "inv:") == 1))
				flow += list(list(S, hud_anchor_origin(D[1], view_w) + D[2], hud_anchor_origin(D[3], view_h) + D[4], foot[1], foot[2]))
		S.hud_size = size
		S.hud_ax = D[1]
		S.hud_ay = D[3]
		// Keep every tile fully on screen; a large scale on a narrow view
		// would otherwise push edge tiles past the far edge.
		var/edge_w = foot[1] * g * size
		var/edge_h = foot[2] * g * size
		var/x0 = hud_anchor_origin(S.hud_ax, view_w)
		var/y0 = hud_anchor_origin(S.hud_ay, view_h)
		S.hud_ox = clamp(x0 + D[2] * g, 0, max(0, view_w - edge_w)) - x0
		S.hud_oy = clamp(y0 + D[4] * g, 0, max(0, view_h - edge_h)) - y0
		S.screen_loc = "[hud_axis_text(S.hud_ax, S.hud_ox)],[hud_axis_text(S.hud_ay, S.hud_oy)]"
		S.transform = hud_scale_matrix(g * size, px[1], px[2])
		hud_pixel_scale(S, g * size)
		S.hud_rescaled(g * size)
	if (flow.len)
		hud_reflow(flow, g, view_w, view_h)
	sync_inventory_screen_locs()
	apply_action_bar_layout()
	if (istype(s_active, /obj/item/weapon/storage))
		var/obj/item/weapon/storage/open_storage = s_active
		open_storage.orient2hud(src)
	if (client.hud_edit_mode)
		hud_edit_tint()

/mob/proc/hud_storage_shift(x0, y0, w, h)
	return list(0, 0)

/mob/living/human/hud_storage_shift(x0, y0, w, h)
	if (!client || !client.prefs)
		return list(0, 0)
	var/list/V = getviewsize(client.view)
	var/view_w = V[1] * 32
	var/view_h = V[2] * 32
	var/g = client.prefs.hud_scale
	var/list/custom = null
	var/list/F = client.prefs.hud_layout_entry(defaultHUD, "storage")
	if (F && F[3] != "D")
		var/ox = text2num(F[4])
		var/oy = text2num(F[6])
		if (isnum(ox) && isnum(oy))
			custom = list(hud_anchor_origin(F[3], view_w) + ox * g, hud_anchor_origin(F[5], view_h) + oy * g)
	var/list/rects = list()
	if (!custom && g > 1)
		for (var/obj/screen/S in hud_layout_elements())
			if (S.hud_ax && (S in client.screen))
				var/list/foot = S.hud_footprint()
				rects += list(list(hud_anchor_origin(S.hud_ax, view_w) + S.hud_ox, hud_anchor_origin(S.hud_ay, view_h) + S.hud_oy, foot[1] * g * S.hud_size, foot[2] * g * S.hud_size))
	. = hud_storage_shift_for(x0, y0, w, h, g, view_w, view_h, custom, rects)
	var/obj/screen/handle = hud_storage_tile()
	handle.hud_ax = "WEST"
	handle.hud_ox = x0 + .[1] * 32
	handle.hud_ay = "SOUTH"
	handle.hud_oy = y0 + .[2] * 32

/mob/living/human/proc/hud_storage_tile()
	if (!client.hud_storage_handle)
		var/obj/screen/S = new
		S.name = "storage window"
		S.hud_layout_key = "storage"
		client.hud_storage_handle = S
	return client.hud_storage_handle

/mob/living/human/proc/hud_tile_locked(obj/screen/S)
	var/list/F = client.prefs.hud_layout_entry(defaultHUD, S.hud_layout_key)
	return F && F[8] == "1"

/mob/living/human/proc/hud_edit_tint()
	for (var/obj/screen/S in hud_layout_elements() + hud_action_buttons())
		S.color = hud_tile_locked(S) ? "#ff8a8a" : "#9cff9c"

// The editable tile under the mouse: the tile itself or an item worn in its slot.
/mob/living/human/proc/hud_layout_target(object)
	if (!istype(object, /atom))
		return null
	var/list/elements = hud_layout_elements()
	if (object in elements)
		return object
	if (istype(object, /obj/screen/movable/action_button) && (object in hud_action_buttons()))
		return object
	if (istype(s_active, /obj/item/weapon/storage))
		var/obj/item/weapon/storage/T = s_active
		if ((object in list(T.boxes, T.storage_start, T.storage_continue, T.storage_end, T.closer)) || (istype(object, /obj/item) && object:loc == T))
			return hud_storage_tile()
	if (istype(object, /obj/item))
		for (var/obj/screen/inventory/S in HUDinventory)
			if (S.slot_id && get_equipped_item(S.slot_id) == object && (S in elements))
				return S
	return null

/proc/hud_tile_name(obj/screen/S)
	if (S.hud_layout_key == "actions")
		return "The action bar"
	if (S.hud_layout_key == "storage")
		return "The storage window"
	return capitalize(S.name)

/mob/living/human/proc/hud_tile_entry(obj/screen/S)
	var/list/F = client.prefs.hud_layout_entry(defaultHUD, S.hud_layout_key)
	if (!F)
		F = list(defaultHUD, S.hud_layout_key, "D", "0", "D", "0", "1", "0")
	return F

/mob/living/human/proc/hud_move_tile(obj/screen/S, list/mouse)
	var/list/V = getviewsize(client.view)
	var/w = V[1] * 32
	var/h = V[2] * 32
	var/g = client.prefs.hud_scale
	var/k = g * S.hud_size
	var/list/foot = S.hud_footprint()
	var/x = clamp(mouse[1] - client.hud_grab_x - S.hud_rel_x, 0, max(0, w - foot[1] * k))
	var/y = clamp(mouse[2] - client.hud_grab_y - S.hud_rel_y, 0, max(0, h - foot[2] * k))
	var/cx = x + foot[1] / 2 * k
	var/cy = y + foot[2] / 2 * k
	var/ax = cx < w / 3 ? "WEST" : (cx > w * 2 / 3 ? "EAST" : "CENTER")
	var/ay = cy < h / 3 ? "SOUTH" : (cy > h * 2 / 3 ? "NORTH" : "CENTER")
	var/list/F = hud_tile_entry(S)
	F[3] = ax
	F[4] = "[round((x - hud_anchor_origin(ax, w)) / g, 0.01)]"
	F[5] = ay
	F[6] = "[round((y - hud_anchor_origin(ay, h)) / g, 0.01)]"
	client.prefs.set_hud_layout_entry(defaultHUD, S.hud_layout_key, F)
	apply_hud_layout()

/mob/living/human/proc/hud_resize_tile(obj/screen/S, step)
	var/list/F = hud_tile_entry(S)
	var/size = text2num(F[7])
	if (!isnum(size))
		size = 1
	size = clamp(size + step, HUD_LAYOUT_MIN_SIZE, HUD_LAYOUT_MAX_SIZE)
	F[7] = "[size]"
	client.prefs.set_hud_layout_entry(defaultHUD, S.hud_layout_key, F)
	apply_hud_layout()
	to_chat(src, SPAN_NOTICE("[hud_tile_name(S)] is now [round(size * 100)]% size."))

/mob/living/human/proc/hud_toggle_lock(obj/screen/S)
	var/list/F = hud_tile_entry(S)
	F[8] = (F[8] == "1") ? "0" : "1"
	if (F[3] == "D" && F[7] == "1" && F[8] == "0")
		F = null
	client.prefs.set_hud_layout_entry(defaultHUD, S.hud_layout_key, F)
	hud_edit_tint()
	to_chat(src, SPAN_NOTICE("[hud_tile_name(S)] is now [(F && F[8] == "1") ? "locked" : "unlocked"]."))

/mob/living/human/proc/end_hud_edit()
	if (!client)
		return
	client.hud_edit_mode = FALSE
	recolor_HUD(client.prefs.UI_style_color, client.prefs.UI_style_alpha)
	if (hud_used)
		for (var/obj/screen/S in hud_used.vehicle_hud)
			S.color = null
	// Restores each action button's availability colour.
	update_action_buttons()

////////////////////////// mouse hooks //////////////////////////

/client/proc/hud_edit_human()
	if (!hud_edit_mode)
		return null
	if (!ishuman(mob) || !mob.client)
		hud_edit_mode = FALSE
		return null
	return mob

/client/MouseDown(object, location, control, params)
	var/mob/living/human/H = hud_edit_human()
	if (H)
		var/obj/screen/S = H.hud_layout_target(object)
		if (S)
			var/list/mouse = hud_mouse_pixels(params)
			var/list/V = getviewsize(view)
			if (mouse && S.hud_ax)
				hud_grab_x = mouse[1] - (hud_anchor_origin(S.hud_ax, V[1] * 32) + S.hud_ox)
				hud_grab_y = mouse[2] - (hud_anchor_origin(S.hud_ay, V[2] * 32) + S.hud_oy)
			else
				hud_grab_x = 16
				hud_grab_y = 16
			return
	return ..()

/client/MouseDrop(src_object, over_object, src_location, over_location, src_control, over_control, params)
	var/mob/living/human/H = hud_edit_human()
	if (H)
		var/obj/screen/S = H.hud_layout_target(src_object)
		if (S)
			if (H.hud_tile_locked(S))
				to_chat(H, SPAN_WARNING("[hud_tile_name(S)] is locked. Click it to unlock it."))
				return
			var/list/mouse = hud_mouse_pixels(params)
			if (mouse)
				H.hud_move_tile(S, mouse)
			return
	return ..()

/client/Click(object, location, control, params)
	var/mob/living/human/H = hud_edit_human()
	if (H)
		var/obj/screen/S = H.hud_layout_target(object)
		if (S)
			H.hud_toggle_lock(S)
			return
	return ..()

/client/MouseWheel(object, delta_x, delta_y, location, control, params)
	var/mob/living/human/H = hud_edit_human()
	if (H)
		var/obj/screen/S = H.hud_layout_target(object)
		if (S)
			if (H.hud_tile_locked(S))
				to_chat(H, SPAN_WARNING("[hud_tile_name(S)] is locked. Click it to unlock it."))
				return
			if (S.hud_layout_key == "storage")
				to_chat(H, SPAN_WARNING("The storage window can't be resized; drag it to move it."))
				return
			if (delta_y)
				H.hud_resize_tile(S, delta_y > 0 ? HUD_LAYOUT_SIZE_STEP : -HUD_LAYOUT_SIZE_STEP)
			return
	return ..()

////////////////////////// verbs //////////////////////////

/client/verb/edit_hud_layout()
	set name = "Edit HUD Layout"
	set category = "OOC"
	set desc = "Move, resize and lock your HUD tiles."

	if (!ishuman(mob) || !mob:hud_used)
		to_chat(src, SPAN_WARNING("You need a body with a HUD to edit it."))
		return
	var/mob/living/human/H = mob
	if (hud_edit_mode)
		H.end_hud_edit()
		prefs.save_preferences()
		to_chat(src, SPAN_NOTICE("HUD layout saved."))
		return
	hud_edit_mode = TRUE
	H.hud_edit_tint()
	to_chat(src, SPAN_NOTICE("<b>Editing your HUD.</b> Drag a tile to move it. Scroll the mouse wheel over a tile to resize it. Click a tile to lock or unlock it; locked tiles are red and stay put. Action buttons move and resize together as one bar. Open a bag first to drag its storage window. Use <b>Edit HUD Layout</b> again to save and finish."))

/client/verb/set_hud_scale()
	set name = "HUD Scale"
	set category = "OOC"
	set desc = "Make your whole HUD larger or smaller."

	var/current = "100%"
	for (var/label in hud_scale_choices)
		if (hud_scale_choices[label] == prefs.hud_scale)
			current = label
	var/choice = player_input(src, "Choose a HUD scale. Your current scale is [current].", "HUD Scale", current, "anything", hud_scale_choices, TRUE)
	if (!choice)
		return
	prefs.hud_scale = hud_scale_choices[choice]
	prefs.save_preferences()
	if (ishuman(mob))
		var/mob/living/human/H = mob
		H.apply_hud_layout()
	to_chat(src, SPAN_NOTICE("HUD scale set to [choice]."))

/client/verb/set_hover_text_size()
	set name = "Hover Text Size"
	set category = "OOC"
	set desc = "Make the name under your mouse larger or smaller."

	var/current = "100%"
	for (var/label in hud_scale_choices)
		if (hud_scale_choices[label] == prefs.hover_text_scale)
			current = label
	var/choice = player_input(src, "Choose a size for the name shown under your mouse. Your current size is [current].", "Hover Text Size", current, "anything", hud_scale_choices, TRUE)
	if (!choice)
		return
	prefs.hover_text_scale = hud_scale_choices[choice]
	prefs.save_preferences()
	to_chat(src, SPAN_NOTICE("Hover text size set to [choice]."))

/client/verb/toggle_hover_text()
	set name = "Toggle Hover Text"
	set category = "OOC"
	set desc = "Show or hide the name under your mouse."

	prefs.hover_text_enabled = !prefs.hover_text_enabled
	prefs.save_preferences()
	if (!prefs.hover_text_enabled)
		clear_hover_name()
	to_chat(src, SPAN_NOTICE("Hover text [prefs.hover_text_enabled ? "shown" : "hidden"]. Use <b>Toggle Hover Text</b> again to [prefs.hover_text_enabled ? "hide" : "show"] it."))

/client/verb/reset_hud_layout()
	set name = "Reset HUD Layout"
	set category = "OOC"
	set desc = "Put HUD tiles back in their default places."

	var/style = ishuman(mob) ? mob:defaultHUD : prefs.UI_style
	var/choice = player_input(src, "Reset which tiles of the [style] HUD?", "Reset HUD Layout", null, "anything", list("Unlocked tiles", "All tiles and the HUD scale"), TRUE)
	if (!choice)
		return
	var/prefix = "[style]~"
	for (var/entry in prefs.hud_layout.Copy())
		if (!istext(entry) || findtext(entry, prefix) != 1)
			continue
		var/list/F = splittext(entry, "~")
		if (choice == "Unlocked tiles" && F.len == 8 && F[8] == "1")
			continue
		prefs.hud_layout -= entry
	if (choice != "Unlocked tiles")
		prefs.hud_scale = 1
	prefs.save_preferences()
	if (ishuman(mob))
		var/mob/living/human/H = mob
		H.apply_hud_layout()
	to_chat(src, SPAN_NOTICE("HUD layout reset."))

#undef HUD_LAYOUT_MIN_SIZE
#undef HUD_LAYOUT_MAX_SIZE
#undef HUD_LAYOUT_SIZE_STEP
