//By Carnwennan
//fetches an external list and processes it into a list of ip addresses.
//It then stores the processed list into a savefile for later use
#define TOR_UPDATE_INTERVAL 216000	//~6 hours
#define TOR_EXIT_LIST_URL "https://check.torproject.org/exit-addresses"

/proc/get_tor_file_dir()
	return "data/ToR_ban.bdb"

/proc/ToRban_autoupdate()
	var/savefile/F = new(get_tor_file_dir())
	if (F)
		var/last_update
		F["last_update"] >> last_update
		if ((last_update + TOR_UPDATE_INTERVAL) < world.realtime)	//we haven't updated for a while
			ToRban_update()
	return

/proc/ToRban_update()
	set waitfor = FALSE
	log_misc("Downloading updated ToR data...")
	// Fetched off the game loop (2026-11-07): world.Export froze the server
	// for the whole download. rust_g's asynchronous HTTP is checked once a tick
	// for up to a minute; only if rust_g cannot fetch it does the old blocking
	// Export run, once every six hours.
	var/body = null
	var/datum/http_request/R = new
	R.prepare(RUSTG_HTTP_METHOD_GET, TOR_EXIT_LIST_URL, "", list())
	var/async_ok = TRUE
	try
		R.begin_async()
	catch
		async_ok = FALSE
	if (async_ok)
		for (var/i in 1 to 600)
			if (R.is_complete())
				break
			sleep(1)
		if (R.is_complete())
			var/datum/http_response/response = R.into_response()
			if (!response.error && istext(response.body))
				body = response.body
			else
				log_misc("ToR data: rust_g could not fetch the list ([response.error ? response.error : "no body"]); trying world.Export.")
		else
			log_misc("ToR data update aborted: no answer within a minute.")
			return
	if (!istext(body))
		var/http[] = world.Export(TOR_EXIT_LIST_URL)
		if (islist(http) && http["CONTENT"])
			body = file2text(http["CONTENT"])
	if (!istext(body) || !length(body))
		log_misc("ToR data update aborted: no data.")
		return
	var/list/rawlist = splittext(body, "\n")
	var/count = 0
	fdel(get_tor_file_dir())
	var/savefile/F = new(get_tor_file_dir())
	for ( var/line in rawlist )
		if (!line)	continue
		if ( copytext(line,1,12) == "ExitAddress" )
			var/cleaned = copytext(line,13,length(line)-19)
			if (!cleaned)	continue
			F[cleaned] << 1
			count++
	F["last_update"] << world.realtime
	log_misc("ToR data updated: [count] exit addresses.")

#undef TOR_UPDATE_INTERVAL
#undef TOR_EXIT_LIST_URL
