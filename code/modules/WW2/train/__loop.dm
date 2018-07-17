var/train_loop_interval = -1
var/next_supplytrain_message = -1
var/next_german_supplytrain_master_process = -1

/proc/setup_trains()
	spawn (1)
		world << "<span class = 'notice'>Setting up the train system.</span>"
	german_train_master = new/datum/train_controller/german_train_controller()
	german_supplytrain_master = new/datum/train_controller/german_supplytrain_controller()
	processes.train.schedule_interval = round(8/german_train_master.velocity)

/proc/train_loop()
	spawn while (1)
		if (processes.train && processes.train.supplytrain_may_process)
			processes.train.supplytrain_may_process = FALSE
			supplytrain_processes()
		sleep (50)

/proc/normal_train_processes()

	// main train
	if (german_train_master)
		german_train_master.Process()

		if (german_train_master.moving)
			german_train_master.sound_loop()

	// supply train
	if (german_supplytrain_master)
		if (world.realtime > next_german_supplytrain_master_process)
			german_supplytrain_master.Process()
			if (prob(1) && prob(2) && !german_supplytrain_master.here)
				radio2germans("The Supply Train has broken down. It will not be functional for five minutes.", "Supply Train Announcements")
				next_german_supplytrain_master_process = world.realtime + 2700

		if (german_supplytrain_master.moving)
			german_supplytrain_master.sound_loop()

/proc/supplytrain_processes()

	if (next_german_supplytrain_master_process > world.realtime)
		return

	// make us visible if we're docking at the armory
	// make us invisible if we're leaving

	if (!german_supplytrain_master.moving)

		var/stopthetrain = FALSE

		for (var/a in german_supplytrain_master.train_car_centers)
			var/obj/train_car_center/tcc = a
			for (var/b in tcc.forwards_pseudoturfs)
				var/obj/train_pseudoturf/tpt = b
				if (locate(/obj/structure/closet/crate) in get_turf(tpt))
					if (german_supplytrain_master.direction == "FORWARDS")
						stopthetrain = TRUE
						break

		for (var/next in living_mob_list)
			var/mob/living/L = next
			if (L && L.stat != DEAD)
				if (!istype(L.loc, /obj/structure/largecrate)) // puppers
					if (istype(get_area(L), /area/prishtina/german/armory/train))
						stopthetrain = TRUE
						break

		if (stopthetrain)
			if (world.time >= next_supplytrain_message)
				radio2germans("The Supply Train is either occupied by a person, has a person standing in its way, or has not had its crates unloaded. Its departure has been delayed until this condition is solved.", "Supply Train Announcements")
				next_supplytrain_message = world.time + 600
				processes.train.supplytrain_special_check = TRUE
			goto skipmovement

		processes.train.supplytrain_special_check = FALSE

		switch (german_supplytrain_master.direction)
			if ("FORWARDS")
				german_supplytrain_master.direction = "BACKWARDS"
				radio2germans("The Supply Train is departing from the armory. It will arrive again in 2 minutes.", "Supply Train Announcements")
				if (!german_supplytrain_master.invisible)
					german_supplytrain_master.update_invisibility(1)
				german_supplytrain_master.here = FALSE
				for (var/a in german_supplytrain_master.train_car_centers)
					if (a)
						var/obj/train_car_center/tcc = a
						for (var/b in tcc.forwards_pseudoturfs)
							if (b)
								var/obj/train_pseudoturf/tpt = b
								if (tpt.loc)
									for (var/obj/item/weapon/paper/supply_train_requisitions_sheet/paper in tpt.loc.contents)
										paper.memo = ""
										break
			if ("BACKWARDS")
				german_supplytrain_master.direction = "FORWARDS"
				radio2germans("The Supply Train is arriving at the armory. It will depart in 2 minutes.", "Supply Train Announcements")
				if (german_supplytrain_master.invisible)
					german_supplytrain_master.update_invisibility(0)
				german_supplytrain_master.here = TRUE

		german_supplytrain_master.moving = TRUE

	skipmovement