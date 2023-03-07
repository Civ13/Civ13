/datum/admins/proc/loadmap()
	set category = "Server"
	set desc = "SAAAVE!"
	set name = "Load Map (EXPERIMENTAL!)"
	var/mapfile = file("map_saves/map.txt")
	if (!fexists(mapfile))
		usr << "The savefile does not exist or is corrupted!"
		return
	var/loaded_metadata = file2text(mapfile)
	var/list/parsed_metadata = splittext(loaded_metadata, "\n")
	if (map.ID != parsed_metadata[1])
		usr << "Different maps! The current map is <b>[map.ID]</b> and the saved map is <b>[parsed_metadata[1]]</b>."
		usr << "Start a round in the right map first, then load."
		return
	var/inp = WWinput(usr, "Are you sure you want to load the saved map?", "Load Map", "No", list("Yes","No"))
	if (inp == "No")
		return
	if(!check_rights(R_SERVER))
		return

	if(!ticker)
		alert("Unable to load the world as it is not set up.")
		return
	ticker.loadmap()
    
/datum/admins/proc/savemap()
	set category = "Server"
	set desc = "SAAAVE!"
	set name = "Save Map (EXPERIMENTAL!)"
	var/inp = WWinput(usr, "Are you sure you want to save the map?", "Load Map", "No", list("Yes","No"))
	if (inp == "No")
		return
	if(!check_rights(R_SERVER))
		return

	if(!ticker)
		alert("Unable to start the game as it is not set up.")
		return
	spawn(0)
		ticker.savemap()
		