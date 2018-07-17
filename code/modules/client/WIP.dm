// magic hotkeys

/client/var/list/hotkeys = list(
	"NORTH" = "startMovingNorth")

/client/var/list/pressing = list()

/client/proc/get_hotkeys_text()
	. = ""
	for (var/key in hotkeys)
		. += "[key] = [hotkeys[key]]"
		if (key != hotkeys[hotkeys.len])
			. += "\n"

/client/verb/set_hotkeys()
	set category = "OOC"
	set name = "Set Hotkeys"
	hotkeys = splittext(input(src, "", "Hotkeys", get_hotkeys_text()) as message, "\n")

/client/proc/onKeyPressed(var/key)
	if (hotkeys[key])
		call(hotkeys[key])()
	pressing[key] = TRUE

/client/proc/onKeyReleased(var/key)
	pressing[key] = FALSE