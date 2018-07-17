#define AB_ITEM TRUE
#define AB_SPELL 2
#define AB_INNATE 3
#define AB_GENERIC 4

#define AB_CHECK_RESTRAINED TRUE
#define AB_CHECK_STUNNED 2
#define AB_CHECK_LYING 4
#define AB_CHECK_ALIVE 8
#define AB_CHECK_INSIDE 16

// TODO: COMPLETELY UNFUCK THE HUD - JULY 14, 2017 aka the 'mob/living/living.dm' spaghetti monster
/datum/action
	var/name = "Generic Action"
	var/action_type = AB_ITEM
	var/procname = null
	var/atom/movable/target = null
	var/check_flags = FALSE
	var/processing = FALSE
	var/active = FALSE
	var/obj/screen/movable/action_button/button = null
	var/button_icon = 'icons/mob/actions.dmi'
	var/button_icon_state = "default"
	var/background_icon_state = "bg_default"
	var/mob/living/owner

/datum/action/New(var/Target)
	target = Target
	button = new
	button.name = name

/datum/action/Destroy()
	if (owner)
		Remove(owner)
	if (target)
		target = null
	if (button)
		qdel(button)
	else
		button = null
	return ..()

/datum/action/proc/Grant(mob/living/T)
	if (owner)
		if (owner == T)
			return
		Remove(owner)
	owner = T
	button.owner = src
	T.actions |= src // scope HUDs can somehow be granted twice
	if (T.client)
		T.client.screen |= button // scope HUDs can somehow be granted twice
	T.update_action_buttons()

/datum/action/proc/Remove(mob/living/T)
	if (T)
		if (T.client)
			T.client.screen -= button
		button.moved = FALSE //so the button appears in its normal position when given to another owner.
		T.actions -= src
		T.update_action_buttons()
		owner = null

/datum/action/proc/Trigger()
	if (!IsAvailable())
		return FALSE
	return TRUE

/datum/action/proc/Activate()
	return

/datum/action/proc/Deactivate()
	return

/datum/action/proc/Process()
	return

/datum/action/proc/CheckRemoval(mob/living/user) // TRUE if action is no longer valid for this mob and should be removed
	return FALSE

/datum/action/proc/IsAvailable()
	if (!owner)
		return FALSE
	if (check_flags & AB_CHECK_RESTRAINED)
		if (owner.restrained())
			return FALSE
	if (check_flags & AB_CHECK_STUNNED)
		if (owner.stunned)
			return FALSE
	if (check_flags & AB_CHECK_LYING)
		if (owner.lying)
			return FALSE
	if (check_flags & AB_CHECK_ALIVE)
		if (owner.stat)
			return FALSE
	if (check_flags & AB_CHECK_INSIDE)
		if (!(target in owner))
			return FALSE
	return TRUE

/datum/action/proc/UpdateName()
	return name

/obj/screen/movable/action_button
	var/datum/action/owner
	screen_loc = "WEST,NORTH"

/obj/screen/movable/action_button/Click(location,control,params)
	var/list/modifiers = params2list(params)
	if (modifiers["shift"])
		moved = FALSE
		return TRUE
	if (usr.next_move >= world.time) // Is this needed ?
		return
	owner.Trigger()
	return TRUE

/obj/screen/movable/action_button/proc/UpdateIcon()
	if (!owner)
		return
	icon = owner.button_icon
	icon_state = owner.background_icon_state

	overlays.Cut()
	var/image/img
	if (owner.action_type == AB_ITEM && owner.target)
		var/obj/item/I = owner.target
		img = image(I.icon, src , I.icon_state)
	else if (owner.button_icon && owner.button_icon_state)
		img = image(owner.button_icon,src,owner.button_icon_state)
	img.pixel_x = pixel_x
	img.pixel_y = pixel_y
	overlays += img

	if (!owner.IsAvailable())
		color = rgb(128,0,0,128)
	else
		color = rgb(255,255,255,255)

//Hide/Show Action Buttons ... Button
/obj/screen/movable/action_button/hide_toggle
	name = "Hide Buttons"
	icon = 'icons/mob/actions.dmi'
	icon_state = "bg_default"
	var/hidden = FALSE

/obj/screen/movable/action_button/hide_toggle/Click()
	//usr.hud_used.action_buttons_hidden = !usr.hud_used.action_buttons_hidden

	//hidden = usr.hud_used.action_buttons_hidden
	if (hidden)
		name = "Show Buttons"
	else
		name = "Hide Buttons"
	UpdateIcon()
	usr.update_action_buttons()


/obj/screen/movable/action_button/hide_toggle/proc/InitialiseIcon(var/mob/living/user)
	if (isalien(user))
		icon_state = "bg_alien"
	else
		icon_state = "bg_default"
	UpdateIcon()
	return

/obj/screen/movable/action_button/hide_toggle/UpdateIcon()
	overlays.Cut()
	var/image/img = image(icon,src,hidden?"show":"hide")
	overlays += img
	return

//This is the proc used to update all the action buttons. Properly defined in /mob/living/
/mob/proc/update_action_buttons()
	return

#define AB_WEST_OFFSET 4
#define AB_NORTH_OFFSET 26
#define AB_MAX_COLUMNS 10

/datum/hud/proc/ButtonNumberToScreenCoords(var/number) // TODO : Make this zero-indexed for readabilty
	var/row = round((number-1)/AB_MAX_COLUMNS)
	var/col = ((number - 1)%(AB_MAX_COLUMNS)) + 1
	var/coord_col = "+[col-1]"
	var/coord_col_offset = AB_WEST_OFFSET+2*col
	var/coord_row = "[-1 - row]"
	var/coord_row_offset = AB_NORTH_OFFSET
	return "WEST[coord_col]:[coord_col_offset],NORTH[coord_row]:[coord_row_offset]"

/datum/hud/proc/SetButtonCoords(var/obj/screen/button,var/number)
	var/row = round((number-1)/AB_MAX_COLUMNS)
	var/col = ((number - 1)%(AB_MAX_COLUMNS)) + 1
	var/x_offset = 32*(col-1) + AB_WEST_OFFSET + 2*col
	var/y_offset = -32*(row+1) + AB_NORTH_OFFSET

	var/matrix/M = matrix()
	M.Translate(x_offset,y_offset)
	button.transform = M

//Presets for item actions
/datum/action/item_action
	check_flags = AB_CHECK_RESTRAINED|AB_CHECK_STUNNED|AB_CHECK_LYING|AB_CHECK_ALIVE|AB_CHECK_INSIDE

/datum/action/item_action/CheckRemoval(mob/living/user)
	return !(target in user)

/datum/action/item_action/hands_free
	check_flags = AB_CHECK_ALIVE|AB_CHECK_INSIDE

#undef AB_WEST_OFFSET
#undef AB_NORTH_OFFSET
#undef AB_MAX_COLUMNS
