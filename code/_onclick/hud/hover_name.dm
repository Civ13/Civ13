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

/obj/screen/hover_name/persistence_runtime_var(key)
	return (key in list("hover_target", "parentmob", "maptext")) || ..()

/obj/screen/hover_name/proc/clear_target()
	hover_target = null
	maptext = ""

/obj/screen/hover_name/Destroy()
	clear_target()
	parentmob = null
	return ..()

/obj/screen/hover_name/proc/target_visible(atom/target)
	if (!los_read_allowed(parentmob, target, "hover"))
		return FALSE
	if (!target || !parentmob || !parentmob.client || !target.mouse_opacity || !target.alpha || istype(target, /obj/screen))
		return FALSE
	var/client/C = parentmob.client
	if (target.invisibility > parentmob.see_invisible)
		return FALSE
	// Inventory items use the client's existing screen membership. Never inspect
	// closed containers or use a target's underlying type/real identity as a name.
	if (ismovable(target))
		var/atom/movable/movable_target = target
		if (movable_target.screen_loc && (target in C.screen))
			return TRUE
	return (isturf(target) || isturf(target.loc)) && (target in view(C.view, C.eye))

/obj/screen/hover_name/proc/set_target(atom/target)
	clear_target()
	if (!target_visible(target))
		return
	hover_target = WEAKREF(target)
	process()

/obj/screen/hover_name/process()
	var/atom/target = hover_target?.resolve()
	if (!target_visible(target))
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
	if (label && label.hover_target?.resolve() == object)
		label.clear_target()
	..()
