// Pointer feedback belongs to the disposable HUD, never to saved characters.
/obj/screen/hover_name
	name = "hover name"
	icon = null
	screen_loc = "WEST:2,NORTH:-2"
	maptext_width = 384
	maptext_height = 32
	mouse_opacity = FALSE
	process_flag = TRUE
	should_save = FALSE
	var/tmp/datum/weakref/hover_target
	var/tmp/datum/weakref/hover_origin
	var/tmp/hover_inventory = FALSE
	var/tmp/hover_screen_loc

/obj/screen/hover_name/persistence_runtime_var(key)
	return (key in list("hover_target", "hover_origin", "hover_inventory", "hover_screen_loc", "parentmob", "maptext")) || ..()

/obj/screen/hover_name/proc/clear_target()
	hover_target = null
	hover_origin = null
	hover_inventory = FALSE
	hover_screen_loc = null
	maptext = ""

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
	if(C.mob != parentmob || I.loc != parentmob || !I.screen_loc || !(I in C.screen))
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
	return (isturf(target) || isturf(target.loc)) && (target in view(C.view, C.eye))

/obj/screen/hover_name/proc/set_target(atom/origin)
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
	maptext = "<span style='vertical-align:top;text-align:left;font-size:12px;color:white;background-color:black'>[html_encode(copytext(label, 1, 129))]</span>"

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
