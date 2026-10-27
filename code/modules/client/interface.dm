/client/verb/icons_dmf()
	set name = "Change Size"
	set category = "OOC"
	set desc = "Changes screen size."
//	set hidden = TRUE

	var/choice = WWinput(usr, "What screen size?", "Size", "Auto", list("Auto","128x128","96x96","64x64","48x48","32x32"))
	if (choice == "Auto")
		winset(src, "mapwindow.map", "icon-size=0")
	else if (choice == "128x128")
		winset(src, "mapwindow.map", "icon-size=128")
	else if (choice == "96x96")
		winset(src, "mapwindow.map", "icon-size=96")
	else if (choice == "64x64")
		winset(src, "mapwindow.map", "icon-size=64")
	else if (choice == "48x48")
		winset(src, "mapwindow.map", "icon-size=48")
	else if (choice == "32x32")
		winset(src, "mapwindow.map", "icon-size=32")
	else
		winset(src, "mapwindow.map", "icon-size=0")
	return

/client/verb/icons_scale()
	set name = "Change Scale"
	set category = "OOC"
	set desc = "Changes the image compression algorithm."

	var/choice = WWinput(usr, "Which algorithm will you choose??", "Algorithm", "Auto", list("Auto","Nearest neighbor method","Blur"))
	if (choice == "Auto")
		winset(src, "mapwindow.map", "zoom-mode=normal")
	else if (choice == "Nearest neighbor method")
		winset(src, "mapwindow.map", "zoom-mode=distort")
	else if (choice == "Blur")
		winset(src, "mapwindow.map", "zoom-mode=blur")
	return