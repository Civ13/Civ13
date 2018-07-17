/client/verb/update_ping(time as num)
	set hidden = TRUE
	set instant = TRUE
	set name = ".update_ping"
	var/ping = pingfromtime(time)
	last_ping = max(ping, 0)

/client/proc/pingfromtime(time)
	return ((world.time+world.tick_lag*world.tick_usage/100)-time)*100

/client/verb/display_ping(time as num)
	set hidden = TRUE
	set instant = TRUE
	set name = ".display_ping"
	src << "<span class='notice'>Round trip ping took [round(pingfromtime(time),1)]ms</span>"

/client/verb/ping()
	set name = "Ping"
	set category = "OOC"
	winset(src, null, "command=.display_ping+[world.time+world.tick_lag*world.tick_usage/100]")