/datum/admins/proc/loadstation()
	set category = "Server"
	set desc="SAAAVE!"
	set name="Load Station (EXPERIMENTAL!)"

	if(!check_rights(R_SERVER))
		return

	if(!ticker)
		alert("Unable to load the world as it is not set up.")
		return
	ticker.loadstation()
    
	/datum/admins/proc/savestation()
	set category = "Server"
	set desc="SAAAVE!"
	set name="Save Station (EXPERIMENTAL!)"

	if(!check_rights(R_SERVER))
		return

	if(!ticker)
		alert("Unable to start the game as it is not set up.")
		return
	spawn(0)
		ticker.savestation()
		