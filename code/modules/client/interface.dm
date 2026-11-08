/client/verb/icons_dmf()
	set name = "Change Size"
	set category = "OOC"
	set desc = "Changes screen size."
//	set hidden = TRUE

	var/choice = WWinput(usr, "What screen size?", "Size", "Auto", list("Auto","128x128","96x96","64x64","48x48","32x32"))
	var/list/sizes = list("Auto" = 0, "128x128" = 128, "96x96" = 96, "64x64" = 64, "48x48" = 48, "32x32" = 32)
	set_map_icon_size(sizes[choice] || 0)
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