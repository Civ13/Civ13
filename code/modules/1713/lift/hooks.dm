/proc/handle_lifts()

	var/display_message = FALSE

	spawn (1)
		if (display_message)
			world << "<span class = 'notice'>Setting up the lift system.</span>"

	// assign lift IDs

	var/list/top_lifts = list()
	var/list/bottom_lifts = list()

	for (var/obj/lift_controller/master in lift_list)
		if (master.istop)
			++top_lifts[master.area_id]
			master.lift_id = "ww2-l-[master.area_id]-[top_lifts[master.area_id]]"
		else
			++bottom_lifts[master.area_id]
			master.lift_id = "ww2-l-[master.area_id]-[bottom_lifts[master.area_id]]"
		display_message = TRUE

	// assign lift targets and corresponding areas
	for (var/obj/lift_controller/master in lift_list)
		master.target = master.find_target()
		master.corresponding_area = get_area(master.target)

	// create lift pseudoturfs
	for (var/obj/lift_controller/down/master in lift_list)
		if (istype(master))
			var/area/master_area = get_area(master)
			for (var/turf/t in master_area.get_turfs())
				var/obj/lift_pseudoturf/lpt = new/obj/lift_pseudoturf(t, null, master)
				lpt.master = master

	// link linked levers

	for (var/obj/lift_lever/linked/linked_lever in lever_list)
		for (var/obj/lift_lever/counterpart in lever_list)
			if (linked_lever != counterpart && linked_lever.type != counterpart.type)
				if (linked_lever.lever_id == counterpart.lever_id)
					linked_lever.counterpart = counterpart
					break

	return TRUE

// helpers

/obj/lift_controller/proc/find_target()
	for (var/obj/lift_controller/master in lift_list)
		if (lift_id == master.lift_id && master != src)
			return master