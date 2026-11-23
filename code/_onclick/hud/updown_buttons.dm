// Up and down buttons: two HUD tiles that take the player one level up or
// down. On foot they use whatever way between floors is at hand (a ladder,
// stairs, a wall or hole rim, an open edge, a tree or a vehicle top; see
// multiz/floor_buttons.dm). Anything else that should drive the same buttons,
// such as a lift, a crane or an aircraft's altitude, sets itself as the mob's
// updown_control and answers updown_offer() and updown_press() below. The
// buttons are greyed out while pressing them would do nothing.
//
// The buttons are also two rebindable actions, "floor_up" and "floor_down"
// (OOC > Keybindings), unbound by default.

#define UPDOWN_RECHECK 30 // deciseconds between re-checks while standing still

// What pressing direction (UP or DOWN) would do for user: a short phrase for
// the button's name, such as "Climb up the ladder", or null when nothing.
/datum/proc/updown_offer(mob/living/human/user, direction)
	return null

// Does what updown_offer() offered, or explains why not. TRUE when it acted.
/datum/proc/updown_press(mob/living/human/user, direction)
	return FALSE

/mob/living/human/var/tmp/datum/updown_control = null

/mob/living/human/persistence_runtime_var(key)
	return key == "updown_control" || ..()

// Who answers the buttons: the control that took them over, else the body.
/mob/living/human/proc/updown_handler()
	if (updown_control && QDELETED(updown_control))
		updown_control = null
	return updown_control ? updown_control : src

// Hands the buttons to D (null gives them back) and redraws them at once.
/mob/living/human/proc/set_updown_control(datum/D)
	updown_control = D
	refresh_updown_buttons()

/mob/living/human/proc/refresh_updown_buttons()
	for (var/key in list("go up", "go down"))
		var/obj/screen/updown/B = HUDneed[key]
		if (istype(B))
			B.refresh(TRUE)

// Shared by the HUD buttons and the keybindings.
/mob/living/human/proc/press_updown(direction)
	if (!canClick())
		return FALSE
	var/datum/D = updown_handler()
	. = D.updown_press(src, direction)
	setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
	refresh_updown_buttons()

/mob/living/human/verb/go_up_key()
	set name = "go-up"
	set hidden = TRUE
	press_updown(UP)

/mob/living/human/verb/go_down_key()
	set name = "go-down"
	set hidden = TRUE
	press_updown(DOWN)

/obj/screen/updown
	name = "go up"
	icon_state = "arrow_up"
	process_flag = TRUE
	var/direction = UP
	var/base_state = "arrow_up"
	var/shown_for = null // what the current look was worked out for
	var/next_check = 0

/obj/screen/updown/down
	name = "go down"
	icon_state = "arrow_down"
	direction = DOWN
	base_state = "arrow_down"

/obj/screen/updown/process()
	refresh()

// Lights the button when pressing it would do something, else greys it out.
// Re-checks when the body moves, turns or changes control, and every few
// seconds while it stands still (a ladder may have been built meanwhile).
// The first check runs on the first Life tick.
/obj/screen/updown/proc/refresh(force = FALSE)
	var/mob/living/human/H = parentmob
	if (!istype(H))
		return
	var/datum/D = H.updown_handler()
	var/key = "[H.x],[H.y],[H.z],[H.dir],\ref[D],[H.vehicle_deck ? 1 : 0],[H.climbed_tree ? 1 : 0]"
	if (!force && key == shown_for && world.time < next_check)
		return
	shown_for = key
	next_check = world.time + UPDOWN_RECHECK
	var/offer = D.updown_offer(H, direction)
	var/state = offer ? base_state : "[base_state]_off"
	if (icon_state != state)
		icon_state = state
	name = offer ? offer : (direction == UP ? "Go up (no way up here)" : "Go down (no way down here)")

/obj/screen/updown/Click(location, control, params)
	var/mob/living/human/H = usr
	if (!istype(H) || H != parentmob)
		return TRUE
	// Alt+click the up arrow: look up at the level above (multiz/look_up.dm).
	if (direction == UP && params && params2list(params)["alt"])
		H.toggle_look_up()
		return TRUE
	H.press_updown(direction)
	return TRUE

#undef UPDOWN_RECHECK
