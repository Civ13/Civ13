/datum/admins/proc/loadmap()
	set category = "Server"
	set desc="SAAAVE!"
	set name="Load Map (EXPERIMENTAL!)"
	var/inp = WWinput(usr, "Are you sure you want to load the saved map?", "Load Map", "No", list("Yes","No"))
	if (inp == "no")
		return
	if(!check_rights(R_SERVER))
		return

	if(!ticker)
		alert("Unable to load the world as it is not set up.")
		return
	ticker.loadmap()
    
/datum/admins/proc/savemap()
	set category = "Server"
	set desc="SAAAVE!"
	set name="Save Map (EXPERIMENTAL!)"
	var/inp = WWinput(usr, "Are you sure you want to save the map?", "Load Map", "No", list("Yes","No"))
	if (inp == "no")
		return
	if(!check_rights(R_SERVER))
		return

	if(!ticker)
		alert("Unable to start the game as it is not set up.")
		return
	spawn(0)
		ticker.savemap()
		