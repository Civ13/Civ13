/datum/admins/proc/save_update_resume()
	set category = "Server"
	set name = "Save, Update and Resume"
	var/mob/requester = usr
	if(!requester || !requester.client) return
	var/client/requester_client = requester.client
	var/datum/admins/requester_holder = requester_client.holder
	if(requester_holder != src || owner != requester_client || requester_client.mob != requester || !check_rights(R_SERVER, TRUE, requester)) return
	if(WWinput(requester, "Request the configured supervisor to save, shut down, update, compile and restore this world? Players will be disconnected. Serialization is not atomic; stop gameplay before saving. The supervisor must already be enabled.", "Save, Update and Resume", "No", list("Yes", "No")) != "Yes") return
	if(!requester || !requester_client || !requester_holder || usr != requester || requester.client != requester_client || requester_client.mob != requester || requester_client.holder != requester_holder || requester_holder != src || owner != requester_client || !check_rights(R_SERVER, TRUE, requester)) return
	if(!nomads_lifecycle.request_maintenance())
		to_chat(requester, "Maintenance request refused; a request, save or recovery may already be active, or lifecycle control is disabled.")
		return
	to_chat(requester, "Maintenance requested. The supervisor must accept it; check admin messages and supervisor journal for the outcome.")

/datum/admins/proc/save_restart_resume()
	set category = "Server"
	set name = "Save, Restart and Resume"
	if(!check_rights(R_SERVER)) return
	if(WWinput(usr, "Save this world, restart immediately after validation and automatically resume that generation? Actions during serialization may not be preserved. Stop gameplay before confirming. Supported on native Gaia/Europe only.", "Save, Restart and Resume", "No", list("Yes", "No")) != "Yes") return
	if(!check_rights(R_SERVER)) return
	spawn(0)
		persistence_restart.execute()

/datum/admins/proc/resume_pending_recovery()
	set category = "Server"
	set name = "Resume Pending Recovery"
	if(!check_rights(R_SERVER)) return
	if(!persistence_restart.startup_hold)
		to_chat(usr, "No startup recovery hold. [persistence_restart.last_error]")
		return
	if(WWinput(usr, "Retry validation of the retained recovery intent? After an import failure, restart from the original map first. This never discards an intent or starts a fresh round.", "Resume Pending Recovery", "No", list("Yes", "No")) != "Yes") return
	if(!check_rights(R_SERVER)) return
	spawn(0)
		persistence_restart.resume_startup()

/datum/admins/proc/loadmap()
	set category = "Debug"
	set desc = "SAAAVE!"
	set name = "Load Map (EXPERIMENTAL!)"
	var/mapfile = file("map_saves/map.txt")
	if (!fexists(mapfile))
		to_chat(usr, "The savefile does not exist or is corrupted!")
		return
	var/loaded_metadata = file2text(mapfile)
	var/list/parsed_metadata = splittext(loaded_metadata, "\n")
	if (map.ID != parsed_metadata[1])
		to_chat(usr, "Different maps! The current map is <b>[map.ID]</b> and the saved map is <b>[parsed_metadata[1]]</b>.")
		to_chat(usr, "Start a round in the right map first, then load.")
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
	set category = "Debug"
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
	if(ticker.current_state < GAME_STATE_PLAYING)
		alert("The round has not started yet; there is nothing to save.")
		return
	spawn(0)
		ticker.savemap()
