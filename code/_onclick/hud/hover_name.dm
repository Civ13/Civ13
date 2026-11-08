// Pointer feedback belongs to the disposable HUD, never to saved characters.
// The label is a tooltip that follows the pointer: cream text with a dark
// outline on a dark wood-brown panel with a one pixel light border, in the
// 1713 HUD palette. The panel is two solid rectangles (border behind fill)
// drawn as underlays, and the maptext box is exactly the fill rectangle with
// the text centred both ways, so the text always sits in the middle of the
// panel. The client measures each label once (MeasureText) to size the panel;
// until that answer arrives a rough estimate is used, still centred.
// Only screen_loc changes while the pointer moves over one target.
/obj/screen/hover_name
	name = "hover name"
	icon = null
	screen_loc = "WEST:2,NORTH:-2"
	layer = 30 // above SCREEN_LAYER and every HUD control; HUD art never covers it
	maptext_width = 384
	maptext_height = 32
	mouse_opacity = FALSE
	process_flag = TRUE
	should_save = FALSE
	var/tmp/datum/weakref/hover_target
	var/tmp/datum/weakref/hover_origin
	var/tmp/datum/weakref/hover_storage
	var/tmp/hover_inventory = FALSE
	var/tmp/hover_screen_loc
	// The encoded label currently drawn, with its panel size in pixels
	// including the one pixel border.
	var/tmp/hover_text
	var/tmp/hover_text_width = 0
	var/tmp/hover_text_height = 0
	// Font size in pixels; follows the player's Hover Text Size (11px at 100%).
	var/tmp/hover_font_px = 11
	// Client text measurements, "[px]|[text]" -> list(width, height).
	var/tmp/list/hover_measured
	var/tmp/hover_measuring
	// world.time of the last full visibility check of the current target.
	var/tmp/hover_checked_at = -1

#define HOVER_NAME_MAX_WIDTH 384
// A pointer moving over one target only moves the panel between full checks
// this many deciseconds apart. MouseMove arrives far faster than ticks while
// aiming, and every full check captures the viewer's whole line-of-sight scene.
#define HOVER_NAME_RECHECK 2
#define HOVER_NAME_MEASURE_CACHE 256

// The styled label text, centred in its maptext box. px is the font size.
/proc/hover_name_span(text, px = 11)
	return "<span style='text-align:center;vertical-align:middle;font-family:Verdana,sans-serif;font-size:[px]px;-dm-text-outline:1px #1c110a;color:#f3e9d6'>[text]</span>"

/proc/hover_name_measure_key(text, px)
	return "[px]|[text]"

// Rough Verdana width of an encoded label, erring wide: about 7px per
// character at 11px.
/proc/hover_name_estimate_width(text, px)
	return round(7 * px / 11 * length(text))

// Padding between the text and the panel edge for a font size.
/proc/hover_name_pad_x(px)
	return max(3, round(px / 2))

/proc/hover_name_pad_y(px)
	return max(1, round(px / 5))

// One solid panel rectangle w x h pixels with its lower left corner at x,y
// relative to the label, from a white 32x32 state scaled about its centre.
/proc/hover_name_rect(w, h, x, y, colour, rect_layer)
	var/image/rect = image('icons/effects/effects.dmi', icon_state = "white", layer = rect_layer)
	rect.color = colour
	rect.appearance_flags = PIXEL_SCALE | RESET_COLOR
	rect.transform = matrix(w / 32, 0, x + w / 2 - 16, 0, h / 32, y + h / 2 - 16)
	return rect

/obj/screen/hover_name/persistence_runtime_var(key)
	return (key in list("hover_target", "hover_origin", "hover_storage", "hover_inventory", "hover_screen_loc", "hover_text", "hover_text_width", "hover_text_height", "hover_font_px", "hover_measured", "hover_measuring", "hover_checked_at", "maptext_width", "maptext_height", "parentmob", "maptext")) || ..()

/obj/screen/hover_name/proc/clear_target()
	hover_target = null
	hover_origin = null
	hover_storage = null
	hover_inventory = FALSE
	hover_screen_loc = null
	hover_text = null
	hover_text_width = 0
	hover_text_height = 0
	hover_checked_at = -1
	maptext = ""
	update_backdrop()

// Rebuild the panel underlays for hover_text, or remove them when it is empty:
// the border rectangle one pixel larger on every side, behind the fill, which
// covers exactly the maptext box.
/obj/screen/hover_name/proc/update_backdrop()
	if (length(underlays))
		underlays.Cut()
	if (!hover_text)
		return
	underlays += hover_name_rect(maptext_width + 2, maptext_height + 2, -1, -1, "#9a8468", FLOAT_LAYER - 1)
	underlays += hover_name_rect(maptext_width, maptext_height, 0, 0, "#3b2c1e", FLOAT_LAYER)

// The label's font size: 11px at 100% Hover Text Size, scaled with it.
// This is its own setting so the text can stay small with a large HUD.
/obj/screen/hover_name/proc/hover_label_px()
	if (!parentmob || !parentmob.client)
		return 11
	var/client/C = parentmob.client
	var/g = C.prefs?.hover_text_scale
	if (!isnum(g))
		return 11
	return clamp(round(11 * g), 6, 22)

// Size the panel around text_w x text_h pixels of text; even sizes keep the
// scaled rectangles on whole pixels.
/obj/screen/hover_name/proc/set_panel_size(text_w, text_h)
	var/px = hover_font_px
	var/w = min(HOVER_NAME_MAX_WIDTH, text_w + 2 * hover_name_pad_x(px))
	var/h = text_h + 2 * hover_name_pad_y(px)
	w += w % 2
	h += h % 2
	maptext_width = w
	maptext_height = h
	hover_text_width = w + 2
	hover_text_height = h + 2
	update_backdrop()

// Ask the client how large it draws a label, once per text and size. The
// answer arrives after a round trip; a label that changed meanwhile only
// caches it.
/obj/screen/hover_name/proc/measure_label(text, px)
	set waitfor = FALSE
	var/key = hover_name_measure_key(text, px)
	if (hover_measuring == key || !parentmob || !parentmob.client)
		return
	hover_measuring = key
	var/client/C = parentmob.client
	// No width: given one, the client answers with that box width instead of
	// the text's own width, which drew a panel as wide as the screen.
	var/result = C.MeasureText(hover_name_span(text, px))
	if (hover_measuring == key)
		hover_measuring = null
	if (QDELETED(src) || !istext(result))
		return
	var/split = findtext(result, "x")
	var/w = split ? text2num(copytext(result, 1, split)) : null
	var/h = split ? text2num(copytext(result, split + 1)) : null
	if (!isnum(w) || !isnum(h) || w <= 0 || h <= 0)
		return
	// The estimate errs wide, so a much wider answer is not the text's width;
	// keep the estimate then rather than draw an oversized panel.
	var/estimate = hover_name_estimate_width(text, px)
	if (w > estimate * 1.5 + 8)
		w = estimate
	// A name wider than the panel limit wraps at that width.
	var/max_text = HOVER_NAME_MAX_WIDTH - 2 * hover_name_pad_x(px)
	if (w > max_text)
		h *= -round(-w / max_text)
		w = max_text
	if (!hover_measured)
		hover_measured = list()
	else if (length(hover_measured) >= HOVER_NAME_MEASURE_CACHE)
		hover_measured.Cut()
	hover_measured[key] = list(w, h)
	if (hover_text == text && hover_font_px == px)
		set_panel_size(w, h)
		follow_pointer()

// Draw an encoded label; an unchanged label resends nothing.
/obj/screen/hover_name/proc/show_label(text)
	var/px = hover_label_px()
	if (text == hover_text && px == hover_font_px && maptext)
		return
	hover_text = text
	hover_font_px = px
	maptext = hover_name_span(text, px)
	var/list/size = null
	if (hover_measured)
		size = hover_measured[hover_name_measure_key(text, px)]
	if (size)
		set_panel_size(size[1], size[2])
		return
	// Rough Verdana metrics, erring wide, until the client answers: about 7px
	// per character at 11px, wrapping at the maximum width, 14px per line.
	var/max_text = HOVER_NAME_MAX_WIDTH - 2 * hover_name_pad_x(px)
	var/estimate = hover_name_estimate_width(text, px)
	var/lines = max(1, -round(-estimate / max_text))
	set_panel_size(min(max_text, estimate), round(14 * px / 11) * lines)
	measure_label(text, px)

// Place the panel just below and right of the pointer, clamped to the right
// edge and flipped above the pointer near the bottom, using the pixel position
// the mouse callbacks parsed and the client's current view size.
/obj/screen/hover_name/proc/follow_pointer()
	if (!parentmob || !parentmob.client)
		return
	var/client/C = parentmob.client
	var/list/size = getviewsize(C.view)
	var/view_w = size[1] * 32
	var/view_h = size[2] * 32
	var/mx = (C.mouse_screen_x - 1) * 32 + C.mouse_screen_pixel_x
	var/my = (C.mouse_screen_y - 1) * 32 + C.mouse_screen_pixel_y
	var/x = max(1, min(mx + 10, view_w - hover_text_width + 1))
	// The panel hangs below the pointer; near the bottom edge it flips above.
	var/top = my - 20
	if (top < hover_text_height)
		top = min(view_h, my + 8 + hover_text_height)
	var/y = max(1, top - hover_text_height + 1)
	var/tx = round(x / 32)
	var/ty = round(y / 32)
	var/pointer_loc = "[tx + 1]:[x - tx * 32],[ty + 1]:[y - ty * 32]"
	if (pointer_loc != screen_loc)
		screen_loc = pointer_loc

/obj/screen/hover_name/Destroy()
	clear_target()
	parentmob = null
	return ..()

/obj/screen/hover_name/proc/inventory_slot_visible(atom/target)
	if(!istype(target, /obj/screen/inventory) || !parentmob || !parentmob.client)
		return FALSE
	var/client/C = parentmob.client
	var/obj/screen/inventory/slot = target
	return C.mob == parentmob && slot.parentmob == parentmob && (slot in parentmob.HUDinventory) && (slot in C.screen) && slot.screen_loc && slot.mouse_opacity && slot.alpha && slot.invisibility <= parentmob.see_invisible

/obj/screen/hover_name/proc/inventory_item_visible(atom/target)
	if(!istype(target, /obj/item) || !parentmob || !parentmob.client)
		return FALSE
	var/client/C = parentmob.client
	var/obj/item/I = target
	if(C.mob != parentmob || !I.screen_loc || !(I in C.screen))
		return FALSE
	if(los_storage_hover_visible(parentmob, I))
		return TRUE
	if(I.loc != parentmob)
		return FALSE
	// A stale displayed item can outlive its hidden slot (for example a pouch).
	// Apply this to direct item hits as well as slot art and stationary refresh.
	for(var/obj/screen/inventory/slot in parentmob.HUDinventory)
		if(inventory_slot_visible(slot) && parentmob.get_equipped_item(slot.slot_id) == I && I.screen_loc == slot.screen_loc)
			return TRUE
	return FALSE

/obj/screen/hover_name/proc/inventory_target_current(atom/target)
	if(!inventory_item_visible(target))
		return FALSE
	var/obj/item/I = target
	if (hover_storage)
		if (hover_storage.resolve() != I.loc)
			return FALSE
	else if (I.loc != parentmob)
		return FALSE
	return I.screen_loc == hover_screen_loc

// Slot art can receive the mouse hit around a transparent item sprite. Resolve
// only this body's current, visible slot and its actual displayed owned item.
// Never use screen.master, a container search, or another body's equipment.
/obj/screen/hover_name/proc/pointer_target(atom/origin)
	if(!istype(origin, /obj/screen/inventory))
		return origin
	if(!inventory_slot_visible(origin))
		return null
	var/obj/screen/inventory/slot = origin
	var/obj/item/I = parentmob.get_equipped_item(slot.slot_id)
	if(!inventory_item_visible(I) || I.screen_loc != slot.screen_loc)
		return null
	return I

/obj/screen/hover_name/proc/target_visible(atom/target)
	if (!los_read_allowed(parentmob, target, "hover"))
		return FALSE
	if (!target || !parentmob || !parentmob.client || !target.mouse_opacity || !target.alpha || istype(target, /obj/screen))
		return FALSE
	var/client/C = parentmob.client
	if(C.mob != parentmob || parentmob.HUDneed["hover name"] != src || !(src in C.screen))
		return FALSE
	if (target.invisibility > parentmob.see_invisible)
		return FALSE
	// Inventory items use the client's existing screen membership. Never inspect
	// closed containers or use a target's underlying type/real identity as a name.
	if (ismovable(target))
		var/atom/movable/movable_target = target
		if (movable_target.screen_loc && (target in C.screen))
			return inventory_item_visible(target)
	// BYOND's view() hides a tree standing behind another opaque tree, but the
	// tree presenter still draws its exposed canopy. The LOS read above already
	// applied that presenter rule, so only require the tree to be on screen.
	if (los_tree_canopy_readable(target))
		return target in range(C.view, C.eye)
	return (isturf(target) || isturf(target.loc)) && (target in view(C.view, C.eye))

/obj/screen/hover_name/proc/set_target(atom/origin)
	// A move across the current pointer target only refreshes: process() still
	// revalidates with fresh visibility, but keeps the drawn label and underlays.
	// Within HOVER_NAME_RECHECK of the last check it only moves the panel.
	var/atom/current = hover_target?.resolve()
	if (origin && current && hover_origin?.resolve() == origin && pointer_target(origin) == current)
		if (!hover_inventory || inventory_target_current(current))
			if (hover_checked_at >= 0 && world.time >= hover_checked_at && world.time < hover_checked_at + HOVER_NAME_RECHECK)
				follow_pointer()
			else
				process()
			return
	clear_target()
	var/atom/target = pointer_target(origin)
	if (!target)
		return
	hover_target = WEAKREF(target)
	hover_origin = WEAKREF(origin)
	hover_inventory = inventory_item_visible(target)
	if(hover_inventory)
		var/obj/item/I = target
		hover_screen_loc = I.screen_loc
		if (I.loc != parentmob)
			hover_storage = WEAKREF(I.loc)
	// Complete pointer setup synchronously, then validate in process once before
	// reading a label. Later process calls still obtain their own fresh visibility.
	process()

/obj/screen/hover_name/process()
	var/atom/target = hover_target?.resolve()
	var/atom/origin = hover_origin?.resolve()
	if (!origin || pointer_target(origin) != target || (hover_inventory && !inventory_target_current(target)) || !target_visible(target))
		clear_target()
		return
	var/label = target.name
	if (ishuman(target))
		var/mob/living/human/H = target
		label = H.get_visible_name()
	if (!length(label))
		clear_target()
		return
	show_label(html_encode(copytext(label, 1, 129)))
	hover_checked_at = world.time
	follow_pointer()

/client/proc/hover_name_widget()
	if (mob)
		return mob.HUDneed["hover name"]

/client/proc/update_hover_name(atom/target)
	var/obj/screen/hover_name/label = hover_name_widget()
	label?.set_target(target)

/client/proc/clear_hover_name()
	var/obj/screen/hover_name/label = hover_name_widget()
	label?.clear_target()

/client/MouseExited(atom/object, location, control, params)
	var/obj/screen/hover_name/label = hover_name_widget()
	// A late exit from the previous object must not erase a newer enter.
	if (label && label.hover_origin?.resolve() == object)
		label.clear_target()
	..()
