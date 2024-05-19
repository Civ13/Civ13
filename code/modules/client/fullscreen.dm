client/New()
	..()
	winset(src, "mainwindow", "can-resize=true;titlebar=true;menu=menu")
	winset(src, "mainwindow.mainvsplit", "splitter=75")
	if(is_preference_enabled(/datum/client_preference/fit_viewport))
		fit_viewport()

client/verb/updateFullscreen()
	set name = "updateFullscreen"
	set hidden = TRUE
	if (!fullscreen)
		winset(src, "mainwindow", "is-maximized=false;can-resize=false;titlebar=false;menu=")
		winset(src, "mainwindow.mainvsplit", "splitter=78")
		winset(src, "mainwindow", "is-maximized=true")
		fullscreen = TRUE
		return
	else
		winset(src, "mainwindow", "can-resize=true;titlebar=true;menu=menu")
		winset(src, "mainwindow.mainvsplit", "splitter=75")
		fullscreen = FALSE
		return

client/verb/fixFullscreen()
	set name = "fixFullscreen"
	set hidden = TRUE
	winset(src, "mainwindow", "can-resize=true;titlebar=true;menu=menu")
