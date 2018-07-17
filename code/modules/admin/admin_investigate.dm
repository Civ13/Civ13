//By Carnwennan

//This system was made as an alternative to all the in-game lists and variables used to log stuff in-game.
//lists and variables are great. However, they have several major flaws:
//Firstly, they use memory. TGstation has one of the highest memory usage of all the ss13 branches.
//Secondly, they are usually stored in an object. This means that they aren't centralised. It also means that
//the data is lost when the object is deleted! This is especially annoying for things like the singulo engine!
/proc/get_investigate_file_dir()
	if (serverswap && serverswap.Find("master_data_dir"))
		return "[serverswap["master_data_dir"]]investigate/"
	return "data/investigate/"


//SYSTEM
/proc/investigate_subject2file(var/subject)
	return file("[get_investigate_file_dir()][subject].html")

/hook/startup/proc/resetInvestigate()
	investigate_reset()
	return TRUE

/proc/investigate_reset()
	if (fdel(get_investigate_file_dir()))	return TRUE
	return FALSE

/atom/proc/investigate_log(var/message, var/subject)
	if (!message)	return
	var/F = investigate_subject2file(subject)
	if (!F)	return
	F << "<small>[time2text(world.timeofday,"hh:mm")] \ref[src] ([x],[y],[z])</small> || [src] [message]<br>"

//ADMINVERBS
/client/proc/investigate_show( subject in list("hrefs","notes","singulo","telesci") )
	set name = "Investigate"
	set category = "Admin"
	if (!holder)	return
	switch(subject)
		if ("singulo", "telesci")			//general one-round-only stuff
			var/F = investigate_subject2file(subject)
			if (!F)
				src << "<font color='red'>Error: admin_investigate: [get_investigate_file_dir()][subject] is an invalid path or cannot be accessed.</font>"
				return
			src << browse(F,"window=investigate[subject];size=800x300")

		if ("hrefs")				//persistant logs and stuff
			if (config && config.log_hrefs)
				if (href_logfile)
					src << browse(href_logfile,"window=investigate[subject];size=800x300")
				else
					src << "<font color='red'>Error: admin_investigate: No href logfile found.</font>"
					return
			else
				src << "<font color='red'>Error: admin_investigate: Href Logging is not on.</font>"
				return
