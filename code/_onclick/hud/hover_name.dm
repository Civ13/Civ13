// Pointer feedback belongs to the disposable HUD, never to saved characters.
// The label is a tooltip that follows the pointer: cream text with a dark
// outline on a dark wood-brown panel with a one pixel light border, in the
// 1713 HUD palette. The panel is pure maptext, so it always fits the text the
// client actually draws: the text span carries the fill colour, and four
// underlays repeat the same span in the border colour one pixel out on each
// side. Only screen_loc changes while the pointer moves over one target.
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
	// The encoded label currently drawn, with its estimated panel size in
	// pixels; the estimate only places the panel, the drawn border fits itself.
	var/tmp/hover_text
	var/tmp/hover_text_width = 0
	var/tmp/hover_text_height = 0

// One styled span: the text with a nbsp on each side as horizontal padding.
// border = TRUE draws the same span in the border colour for the underlays.
/proc/hover_name_span(text, border)
	var/ink = border ? "#9a8468" : "#f3e9d6"
	var/fill = border ? "#9a8468" : "#3b2c1e"
	var/outline = border ? "" : "-dm-text-outline:1px #1c110a;"
	return "<span style='vertical-align:top;text-align:left;font-family:Verdana,sans-serif;font-size:11px;[outline]color:[ink];background-color:[fill]'>&nbsp;[text]&nbsp;</span>"

/obj/screen/hover_name/persistence_runtime_var(key)
	return (key in list("hover_target", "hover_origin", "hover_storage", "hover_inventory", "hover_screen_loc", "hover_text", "hover_text_width", "hover_text_height", "parentmob", "maptext")) || ..()

/obj/screen/hover_name/proc/clear_target()
	hover_target = null
	hover_origin = null
	hover_storage = null
	hover_inventory = FALSE
	hover_screen_loc = null
	hover_text = null
	hover_text_width = 0
	hover_text_height = 0
	maptext = ""
	update_backdrop()

// Rebuild the border underlays for hover_text, or remove them when it is empty.
/obj/screen/hover_name/proc/update_backdrop()
	if (length(underlays))
		underlays.Cut()
	if (!hover_text)
		return
	for (var/list/shift in list(list(-1, 0), list(1, 0), list(0, -1), list(0, 1)))
		var/image/edge = image(null)
		edge.maptext = hover_name_span(hover_text, TRUE)
		edge.maptext_width = maptext_width
		edge.maptext_height = maptext_height
		edge.maptext_x = shift[1]
		edge.maptext_y = shift[2]
		underlays += edge

// Draw an encoded label; an unchanged label resends nothing.
/obj/screen/hover_name/proc/show_label(text)
	if (text == hover_text && maptext)
		return
	hover_text = text
	// Rough Verdana 11px metrics, erring wide: about 7px per character plus
	// the padding and border, wrapping at the maptext width, 14px per line.
	var/estimate = 7 * length(text) + 12
	hover_text_width = min(maptext_width, estimate)
	hover_text_height = min(maptext_height, 14 * -round(-estimate / maptext_width) + 2)
	maptext = hover_name_span(text, FALSE)
	update_backdrop()

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
	var/x = max(0, min(mx + 10, view_w - hover_text_width))
	// The text sits at the top of the maptext box; keep the box above the edge.
	var/top = my - 20
	if (top < maptext_height)
		top = min(view_h, my + 8 + hover_text_height)
	var/y = max(0, top - maptext_height)
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
	var/atom/current = hover_target?.resolve()
	if (origin && current && hover_origin?.resolve() == origin && pointer_target(origin) == current)
		if (!hover_inventory || inventory_target_current(current))
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
