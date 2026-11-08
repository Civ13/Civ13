client/New()
	..()
	// Leave the splitter where the skin saved it: forcing it here threw the
	// saved layout away on every connect, then the refits moved it again.
	winset(src, "mainwindow", "can-resize=true;titlebar=true;menu=menu")
	fit_viewport_soon()

client/verb/updateFullscreen()
	set name = "updateFullscreen"
	set hidden = TRUE
	if (!fullscreen)
		winset(src, "mainwindow", "is-maximized=false;can-resize=false;titlebar=false;menu=")
		winset(src, "mainwindow.mainvsplit", "splitter=78")
		winset(src, "mainwindow", "is-maximized=true")
		fullscreen = TRUE
		if(is_preference_enabled(/datum/client_preference/fit_viewport))
			fit_viewport()
		return
	else
		winset(src, "mainwindow", "can-resize=true;titlebar=true;menu=menu")
		winset(src, "mainwindow.mainvsplit", "splitter=75")
		fullscreen = FALSE
		if(is_preference_enabled(/datum/client_preference/fit_viewport))
			fit_viewport()
		return

client/verb/fixFullscreen()
	set name = "fixFullscreen"
	set hidden = TRUE
	winset(src, "mainwindow", "can-resize=true;titlebar=true;menu=menu")
