/obj/train_lever // I would make this machinery, but right now trains don't need power subsystems etc
	var/faction = GERMAN
	anchored = 1.0
	density = TRUE
	icon = 'icons/WW2/train_lever.dmi'
	icon_state = "lever_none"
	var/none_state = "lever_none"
	var/pushed_state = "lever_pushed"
	var/pulled_state = "lever_pulled"
	var/direction = "NONE"
	name = "train lever"
	var/real = FALSE

/obj/train_lever/New()
	..()
	lever_list += src

/obj/train_lever/Destroy()
	lever_list -= src
	..()

/obj/train_lever/attack_hand(var/mob/user as mob)
	if (!processes.train || !processes.train.fires_at_gamestates.Find(ticker.current_state))
		user << "<span class = 'warning'>You can't send the train right now.</span>"
		return
	if (user && istype(user, /mob/living/carbon/human))
		if (processes.ticker.playtime_elapsed < 9000)
			user << "<span class = 'danger'>15 or more minutes must elapse before you can leave!</span>"
			return
		function(user)

/obj/train_lever/proc/automatic_function(var/direction, var/client/abuser)
	var/datum/train_controller/train_controller = null

	switch (faction)
		if (GERMAN)
			if (german_train_master)
				train_controller = german_train_master
		if (SOVIET)
			return

	if (!train_controller)
		abuser << "<span class = 'danger'>Couldn't find a train datum!</span>" // bug

	if (train_controller.halting)
		abuser << "<span class = 'danger'>The train is not done halting yet.</span>"
		return

	switch (direction)
		if ("Forwards", "Backwards")
			train_controller.start_moving(uppertext(direction))
		if ("Stop")
			train_controller.stop_moving_slow()


/obj/train_lever/proc/function(var/mob/user as mob)

	var/datum/train_controller/train_controller = null

	switch (faction)
		if (GERMAN)
			if (german_train_master)
				train_controller = german_train_master
		if (SOVIET)
			return

	if (!train_controller)
		return // bug

	if (train_controller.halting)
		user << "<span class = 'danger'>The train is not done halting yet.</span>"
		return

	var/what = null

	switch (direction)
		if ("NONE")
			what = input(user, "Do what with the lever?") in list("Push Forward (Start Train)", "Pull Back (Start Train)")
		if ("FORWARDS")
			what = input(user, "Do what with the lever?") in list("Pull Back (Stop Train)")
		if ("BACKWARDS")
			what = input(user, "Do what with the lever?") in list("Push Forwards (Stop Train)")

	if (locate(src) in get_step(user, user.dir)) // note: making sure locs are the same
		// does not work if the train is moving, so we do this instead of the extra do_after arg
		if (findtext(what, "Start Train"))
			what = replacetext(what, " (Start Train)", "")
			switch (what)
				if ("Push Forward")
					train_controller.start_moving("FORWARDS")
					visible_message("<span class = 'danger'>[user] pushes the train lever forward, starting the train!</span>")
				if ("Pull Back")
					train_controller.start_moving("BACKWARDS")
					visible_message("<span class = 'danger'>[user] pulls back the train lever, starting the train!</span>")

		else if (findtext(what, "Stop Train"))
			what = replacetext(what, " (Stop Train)", "")
			switch (what)
				if ("Pull Back")
					train_controller.stop_moving_slow()
					visible_message("<span class = 'danger'>[user] pulls back the train lever, stopping the train.</span>")
				if ("Push Forwards")
					train_controller.stop_moving_slow()
					visible_message("<span class = 'danger'>[user] pushes the train lever forward, stopping the train.</span>")
		playsound(get_turf(src), 'sound/effects/lever.ogg', 100, TRUE)

/obj/train_lever/german
	faction = GERMAN

/obj/train_lever/russian
	faction = GERMAN