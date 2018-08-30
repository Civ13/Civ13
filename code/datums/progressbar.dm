/datum/progressbar
	var/goal = 1
	var/image/bar
	var/shown = FALSE
	var/mob/user
	var/client/client

/datum/progressbar/New(mob/_user, goal_number, atom/target)
	. = ..()
	if (!target) target = _user
	if (!istype(target))
		EXCEPTION("Invalid target given")
	if (goal_number)
		goal = goal_number
	bar = image('icons/effects/progessbar.dmi', target, "prog_bar_0")
	bar.appearance_flags = APPEARANCE_UI_IGNORE_ALPHA
	bar.pixel_y = 32
	bar.layer = 1000
	bar.plane = HUD_PLANE
	user = _user
	if (user)
		client = user.client

/datum/progressbar/Destroy()
	if (client)
		client.images -= bar
	qdel(bar)
	. = ..()

/datum/progressbar/proc/update(progress)
	//world << "Update [progress] - [goal] - [(progress / goal)] - [((progress / goal) * 100)] - [round(((progress / goal) * 100), 5)]"
	if (!user || !user.client)
		shown = FALSE
		return
	if (user.client != client)
		if (client)
			client.images -= bar
			shown = FALSE
		client = user.client

	progress = Clamp(progress, FALSE, goal)
	bar.icon_state = "prog_bar_[round(((progress / goal) * 100), 5)]"
	if (!shown && user.is_preference_enabled(/datum/client_preference/show_progress_bar))
		user.client.images += bar
		shown = TRUE
