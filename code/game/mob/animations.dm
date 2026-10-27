/*
adds a dizziness amount to a mob
use this rather than directly changing var/dizziness
since this ensures that the dizzy_process proc is started
currently only humans get dizzy

value of dizziness ranges from FALSE to 1000
below 100 is not dizzy
*/

/mob/var/dizziness = FALSE//Carbon
/mob/var/is_dizzy = FALSE

/mob/proc/make_dizzy(var/amount)
	if (!istype(src, /mob/living/human)) // for the moment, only humans get dizzy
		return

	dizziness = min(1000, dizziness + amount)	// store what will be new value
													// clamped to max 1000
	if (dizziness > 100 && !is_dizzy)
		spawn(0)
			if (isliving(src))
				var/mob/living/L = src
				L.dizzy_process()


/*
dizzy process - wiggles the client's pixel offset over time
spawned from make_dizzy(), will terminate automatically when dizziness gets <100
note dizziness decrements automatically in the mob's Life() proc.
*/
/mob/living/proc/dizzy_process()
	is_dizzy = TRUE
	while (dizziness > 100)
		if (client && !dizzycheck)
			var/amplitude = dizziness*(sin(dizziness * 0.044 * world.time) + 1) / 70
			client.pixel_x = amplitude * sin(0.008 * dizziness * world.time)
			client.pixel_y = amplitude * cos(0.008 * dizziness * world.time)
		sleep(1)
	//endwhile - reset the pixel offsets to zero
	is_dizzy = FALSE
	if (client)
		client.pixel_x = 0
		client.pixel_y = 0

// jitteriness - copy+paste of dizziness
/mob/var/is_jittery = FALSE
/mob/var/jitteriness = FALSE//Carbon
/mob/proc/make_jittery(var/amount)
	if (!istype(src, /mob/living/human)) // for the moment, only humans get dizzy
		return

	jitteriness = min(1000, jitteriness + amount)	// store what will be new value
													// clamped to max 1000
	if (jitteriness > 100 && !is_jittery)
		spawn(0)
			jittery_process()


// Typo from the oriignal coder here, below lies the jitteriness process. So make of his code what you will, the previous comment here was just a copypaste of the above.
/mob/proc/jittery_process()
	//var/old_x = pixel_x
	//var/old_y = pixel_y
	is_jittery = TRUE
	while (jitteriness > 100)
//		var/amplitude = jitteriness*(sin(jitteriness * 0.044 * world.time) + 1) / 70
//		pixel_x = amplitude * sin(0.008 * jitteriness * world.time)
//		pixel_y = amplitude * cos(0.008 * jitteriness * world.time)

		var/amplitude = min(4, jitteriness / 100)
		pixel_x = old_x + rand(-amplitude, amplitude)
		pixel_y = old_y + rand(-amplitude/3, amplitude/3)

		sleep(1)
	//endwhile - reset the pixel offsets to zero
	is_jittery = FALSE
	pixel_x = old_x
	pixel_y = old_y


//handles up-down floaty effect in space and zero-gravity
/mob/var/is_floating = FALSE
/mob/var/floatiness = FALSE

/mob/proc/update_floating(var/dense_object=0)

	if (anchored||buckled)
		make_floating(0)
		return


	if (dense_object && Check_Shoegrip())
		make_floating(0)
		return

	make_floating(1)
	return

/mob/proc/make_floating(var/n)
	if (buckled)
		if (is_floating)
			stop_floating()
		return
	floatiness = n

	if (floatiness && !is_floating)
		start_floating()
	else if (!floatiness && is_floating)
		stop_floating()

/mob/proc/start_floating()

	is_floating = TRUE

	var/amplitude = 2 //maximum displacement from original position
	var/period = 36 //time taken for the mob to go up >> down >> original position, in deciseconds. Should be multiple of 4

	var/top = old_y + amplitude
	var/bottom = old_y - amplitude
	var/half_period = period / 2
	var/quarter_period = period / 4

	animate(src, pixel_y = top, time = quarter_period, easing = SINE_EASING | EASE_OUT, loop = -1)		//up
	animate(pixel_y = bottom, time = half_period, easing = SINE_EASING, loop = -1)						//down
	animate(pixel_y = old_y, time = quarter_period, easing = SINE_EASING | EASE_IN, loop = -1)			//back

/mob/proc/stop_floating()
	animate(src, pixel_y = old_y, time = 5, easing = SINE_EASING | EASE_IN) //halt animation
	//reset the pixel offsets to zero
	is_floating = FALSE

/atom/movable/proc/do_attack_animation(atom/A)

	var/pixel_x_diff = FALSE
	var/pixel_y_diff = FALSE
	var/direction = get_dir(src, A)
	switch(direction)
		if (0)
			pixel_y_diff = pick(0, -8, 8)
			pixel_x_diff = pick(0, -8, 8)
		if (NORTH)
			pixel_y_diff = 8
		if (SOUTH)
			pixel_y_diff = -8
		if (EAST)
			pixel_x_diff = 8
		if (WEST)
			pixel_x_diff = -8
		if (NORTHEAST)
			pixel_x_diff = 8
			pixel_y_diff = 8
		if (NORTHWEST)
			pixel_x_diff = -8
			pixel_y_diff = 8
		if (SOUTHEAST)
			pixel_x_diff = 8
			pixel_y_diff = -8
		if (SOUTHWEST)
			pixel_x_diff = -8
			pixel_y_diff = -8
	animate(src, pixel_x = pixel_x + pixel_x_diff, pixel_y = pixel_y + pixel_y_diff, time = 2)
	animate(pixel_x = initial(pixel_x), pixel_y = initial(pixel_y), time = 2)

/mob/do_attack_animation(atom/A)
	..()
	is_floating = FALSE // If we were without gravity, the bouncing animation got stopped, so we make sure we restart the bouncing after the next movement.

	// What icon do we use for the attack?
	var/image/I
	if (hand && l_hand) // Attacked with item in left hand.
		I = image(l_hand.icon, A, l_hand.icon_state, A.layer + 1)
	else if (!hand && r_hand) // Attacked with item in right hand.
		I = image(r_hand.icon, A, r_hand.icon_state, A.layer + 1)
	else // Attacked with a fist?
		return

	// Who can see the attack?
	var/list/viewing = list()
	for (var/mob/M in viewers(A))
		if (M.client)
			viewing |= M.client
	flick_overlay(I, viewing, 5) // 5 ticks/half a second

	// Scale the icon.
	I.transform *= 0.75
	// Set the direction of the icon animation.
	var/direction = get_dir(src, A)
	if (direction & NORTH)
		I.pixel_y = -16
	else if (direction & SOUTH)
		I.pixel_y = 16

	if (direction & EAST)
		I.pixel_x = -16
	else if (direction & WEST)
		I.pixel_x = 16

	if (!direction) // Attacked self?!
		I.pixel_z = 16

	// And animate the attack!
	animate(I, alpha = 175, pixel_x = FALSE, pixel_y = FALSE, pixel_z = FALSE, time = 3)

/mob/proc/spin(spintime, speed)
	spawn()
		var/D = dir
		while (spintime >= speed)
			sleep(speed)
			switch(D)
				if (NORTH)
					D = EAST
				if (SOUTH)
					D = WEST
				if (EAST)
					D = SOUTH
				if (WEST)
					D = NORTH
			set_dir(D)
			spintime -= speed
	return
