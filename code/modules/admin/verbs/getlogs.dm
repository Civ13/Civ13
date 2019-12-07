/*
	HOW DO I LOG RUNTIMES?
	Firstly, start dreamdeamon if it isn't already running. Then select "world>Log Session" (or press the F3 key)
	navigate the popup window to the data/logs/runtime/ folder from where your tgstation .dmb is located.
	(you may have to make this folder yourself)

	OPTIONAL: 	you can select the little checkbox down the bottom to make dreamdeamon save the log everytime you
				start a world. Just remember to repeat these steps with a new name when you update to a new revision!

	Save it with the name of the revision your server uses (e.g. r3459.txt).
	Game Masters will now be able to grant access any runtime logs you have archived this way!
	This will allow us to gather information on bugs across multiple servers and make maintaining the TG
	codebase for the entire /TG/station commuity a TONNE easier :3 Thanks for your help!
*/

//This proc allows download of runtime logs saved within the data/logs/ folder by dreamdeamon.
//It works similarly to show-server-log.
/client/proc/getruntimelog()
	set name = ".getruntimelog"
	set desc = "Retrieve any session logfiles saved by dreamdeamon."
	set category = null

	if (!holder)
		src << "<font color='red'>Only Admins may use this command.</font>"
		return
	var/path = "civ13.log"
	message_admins("[key_name_admin(src)] accessed file: [path]")
	src << run( file(path) )
	src << "Attempting to send file, this may take a fair few minutes if the file is very large."
	return


//This proc allows download of past server logs saved within the data/logs/ folder.
//It works similarly to show-server-log.
/client/proc/getserverlog()
	set name = ".getserverlog"
	set desc = "Fetch logfiles from data/logs"
	set category = null

	var/path = browse_files("data/logs/")
	if (!path)
		return

	if (file_spam_check())
		return

	message_admins("[key_name_admin(src)] accessed file: [path]")
	src << run( file(path) )
	src << "Attempting to send file, this may take a fair few minutes if the file is very large."
	return


//Other log stuff put here for the sake of organisation

//Shows today's server log
/datum/admins/proc/view_txt_log()
	set category = "Admin"
	set name = "Show Server Logs"
	set desc = "Shows the server logs."
	if (!usr || !usr.client)
		return
	var/choice = WWinput(usr, "Check Error Logs or Server Logs?", "Server Logs", "Cancel", list("Cancel", "Error Logs", "Server Logs"))
	switch(choice)
		if ("Cancel")
			return
		if ("Error Logs")
			usr.client.getruntimelog()
			return
		if ("Server Logs")
			usr.client.getserverlog()
			return

	return