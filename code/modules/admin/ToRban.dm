//By Carnwennan
//fetches an external list and processes it into a list of ip addresses.
//It then stores the processed list into a savefile for later use
#define TOR_UPDATE_INTERVAL 216000	//~6 hours

/proc/get_tor_file_dir()
	return "data/ToR_ban.bdb"

/proc/ToRban_isbanned(var/ip_address)
	var/savefile/F = new(get_tor_file_dir())
	if (F)
		if ( ip_address in F.dir )
			return TRUE
	return FALSE

/proc/ToRban_autoupdate()
	var/savefile/F = new(get_tor_file_dir())
	if (F)
		var/last_update
		F["last_update"] >> last_update
		if ((last_update + TOR_UPDATE_INTERVAL) < world.realtime)	//we haven't updated for a while
			ToRban_update()
	return

/proc/ToRban_update()
	spawn(0)
		log_misc("Downloading updated ToR data...")
		var/http[] = world.Export("https://check.torproject.org/exit-addresses")

		var/list/rawlist = file2list(http["CONTENT"])
		if (rawlist.len)
			fdel(get_tor_file_dir())
			var/savefile/F = new(get_tor_file_dir())
			for ( var/line in rawlist )
				if (!line)	continue
				if ( copytext(line,1,12) == "ExitAddress" )
					var/cleaned = copytext(line,13,length(line)-19)
					if (!cleaned)	continue
					F[cleaned] << 1
			F["last_update"] << world.realtime
			log_misc("ToR data updated!")
			if (usr)	to_chat(usr, "ToRban updated.")
		log_misc("ToR data update aborted: no data.")



#undef TOR_UPDATE_INTERVAL
