/*/client/proc/air_report()
	set category = "Debug"
	set name = "Show Air Report"

	if (!master_controller || !air_master)
		alert(usr,"Master_controller or air_master not found.","Air Report")
		return

	var/active_groups = air_master.active_zones
	var/inactive_groups = air_master.zones.len - active_groups

	var/hotspots = FALSE
	for (var/obj/fire/hotspot in world)
		hotspots++

	var/active_on_main_station = FALSE
	var/inactive_on_main_station = FALSE
	for (var/zone/zone in air_master.zones)
		var/turf/simulated/turf = locate() in zone.contents
		if (turf && turf.z in config.station_levels)
			if (zone.needs_update)
				active_on_main_station++
			else
				inactive_on_main_station++

	var/output = {"<b>AIR SYSTEMS REPORT</b><HR>
<b>General Processing Data</b><BR>
	Cycle: [air_master.current_cycle]<br>
	Groups: [air_master.zones.len]<BR>
---- <I>Active:</I> [active_groups]<BR>
---- <I>Inactive:</I> [inactive_groups]<BR><br>
---- <I>Active on station:</i> [active_on_main_station]<br>
---- <i>Inactive on station:</i> [inactive_on_main_station]<br>
<BR>
<b>Special Processing Data</b><BR>
	Hotspot Processing: [hotspots]<BR>
<br>
<b>Geometry Processing Data</b><BR>
	Tile Update: [air_master.tiles_to_update.len]<BR>
"}

	usr << browse(output,"window=airreport")
*/
/*
/client/proc/fix_next_move()
	set category = "Debug"
	set name = "Unfreeze Everyone"
	var/largest_move_time = FALSE
	var/largest_click_time = FALSE
	var/mob/largest_move_mob = null
	var/mob/largest_click_mob = null
	for (var/mob/M in world)
		if (!M.client)
			continue
		if (M.next_move >= largest_move_time)
			largest_move_mob = M
			if (M.next_move > world.time)
				largest_move_time = M.next_move - world.time
			else
				largest_move_time = TRUE
		if (M.next_click >= largest_click_time)
			largest_click_mob = M
			if (M.next_click > world.time)
				largest_click_time = M.next_click - world.time
			else
				largest_click_time = FALSE
		log_admin("DEBUG: [key_name(M)]  next_move = [M.next_move]  next_click = [M.next_click]  world.time = [world.time]")
		M.next_move = TRUE
		M.next_click = FALSE
	message_admins("[key_name_admin(largest_move_mob)] had the largest move delay with [largest_move_time] frames / [largest_move_time/10] seconds!", TRUE)
	message_admins("[key_name_admin(largest_click_mob)] had the largest click delay with [largest_click_time] frames / [largest_click_time/10] seconds!", TRUE)
	message_admins("world.time = [world.time]", TRUE)

	return*/

/*
/client/proc/radio_report()
	set category = "Debug"
	set name = "Radio report"
	return FALSE
*/



/*
/client/proc/reload_mentors()
	set name = "Reload Mentors"
	set category = "Debug"

	if (!check_rights(R_SERVER)) return

	message_admins("[key_name(usr)] manually reloaded Mentors")
	world.load_mods()*/


//todo:
/client/proc/jump_to_dead_group()
	set name = "Jump to dead group"
	set category = "Debug"
		/*
	if (!holder)
		src << "Only administrators may use this command."
		return

	if (!air_master)
		usr << "Cannot find air_system"
		return
	var/datum/air_group/dead_groups = list()
	for (var/datum/air_group/group in air_master.air_groups)
		if (!group.group_processing)
			dead_groups += group
	var/datum/air_group/dest_group = pick(dead_groups)
	usr.loc = pick(dest_group.members)

	return
	*/
/*
/client/proc/kill_airgroup()
	set name = "Kill Local Airgroup"
	set desc = "Use this to allow manual manupliation of atmospherics."
	set category = "Debug"*/
	/*
	if (!holder)
		src << "Only administrators may use this command."
		return

	if (!air_master)
		usr << "Cannot find air_system"
		return

	var/turf/T = get_turf(usr)
	if (istype(T, /turf/simulated))
		var/datum/air_group/AG = T:parent
		AG.next_check = 30
		AG.group_processing = FALSE
	else
		usr << "Local airgroup is unsimulated!"

	*/
/*
/client/proc/print_jobban_old()
	set name = "Print Jobban Log"
	set desc = "This spams all the active jobban entries for the current round to standard output."
	set category = "Debug"

	usr << "<b>Jobbans active in this round.</b>"
	for (var/t in jobban_keylist)
		usr << "[t]"

/client/proc/print_jobban_old_filter()
	set name = "Search Jobban Log"
	set desc = "This searches all the active jobban entries for the current round and outputs the results to standard output."
	set category = "Debug"

	var/filter = input("Contains what?","Filter") as text|null
	if (!filter)
		return

	usr << "<b>Jobbans active in this round.</b>"
	for (var/t in jobban_keylist)
		if (findtext(t, filter))
			usr << "[t]"
*/