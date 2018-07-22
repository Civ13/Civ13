
/hook/roundstart/proc/mainstuff()
	world << "<b><big>The round has started!</big></b>"

	for (var/C in clients)
		winset(C, null, "mainwindow.flash=1")

	// announce after some other stuff, like system setups, are announced
	spawn (3)

		// this may have already happened, do it again w/o announce
		setup_autobalance(0)

		// let new players see the join link
		for (var/np in new_player_mob_list)
			if (np:client)
				np:new_player_panel_proc()


	return TRUE