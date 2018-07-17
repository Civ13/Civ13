//#define WINTER_TESTING
#define TANK_LOWPOP_THRESHOLD 12
#define ARTILLERY_LOWPOP_THRESHOLD 15

/hook/startup/proc/seasons()
//	#ifdef WINTER_TESTING
//	season = "WINTER"
//	#else
//	if (config && config.allowed_seasons && config.allowed_seasons.len)
//		switch (config.allowed_seasons[1])
//			if (1) // all seasons
//				season = pick("SPRING", "SUMMER", "FALL", "WINTER")
//			if (0) // no seasons = spring
//				season = "SPRING"
//			else
//				season = pick(config.allowed_seasons)
//	else
//		season = pick("SPRING", "SUMMER", "FALL", "WINTER")
//	#endif
	season = pick("SPRING", "SUMMER", "FALL", "WINTER")
// code is horribly broken, lets leave it like this

/hook/roundstart/proc/mainstuff()
	world << "<b><big>The round has started!</big></b>"

	for (var/C in clients)
		winset(C, null, "mainwindow.flash=1")

	processes.supply.codes[GERMAN] = rand(1000,9999)
	processes.supply.codes[SOVIET] = rand(1000,9999)
	processes.supply.codes[USA] = rand(1000,9999)
	processes.supply.codes[JAPAN] = rand(1000,9999)
	// announce after some other stuff, like system setups, are announced
	spawn (3)

		// this may have already happened, do it again w/o announce
		setup_autobalance(0)

		// let new players see the join link
		for (var/np in new_player_mob_list)
			if (np:client)
				np:new_player_panel_proc()

		if (!map || !map.meme)

			// no tanks on lowpop
			if (clients.len <= TANK_LOWPOP_THRESHOLD)
				if (locate(/obj/tank) in world)
					for (var/obj/tank/T in world)
						if ((!T.admin) || (!T.truck))
							qdel(T)
					world << "<i>Due to lowpop, there are no tanks.</i>"

			if (clients.len <= ARTILLERY_LOWPOP_THRESHOLD)
				for (var/A in artillery_list)
					qdel(A)
				for (var/obj/structure/closet/crate/artillery/C in crate_list)
					qdel(C)
				for (var/obj/structure/closet/crate/artillery_gas/C in crate_list)
					qdel(C)
				if (map)
					processes.supply.german_crate_types -= "7,5 cm FK 18 Artillery Piece"
					processes.supply.german_crate_types -= "Artillery Ballistic Shells Crate"
					processes.supply.german_crate_types -= "Artillery Gas Shells Crate"
					map.katyushas = FALSE
				for (var/M in mortar_piece_list)
					qdel(M)
				for (var/S in mortar_spade_list)
					qdel(S)
				for (var/obj/structure/closet/crate/mortar_shells/C in crate_list)
					qdel(C)
				if (map)
					processes.supply.german_crate_types -= "Mortar Shells"
					processes.supply.soviet_crate_types -= "Mortar Shells"
					processes.supply.soviet_crate_types -= "37mm Spade Mortar"
				world << "<i>Due to lowpop, there is no artillery or mortars.</i>"

			if (clients.len <= 12)
				for (var/obj/structure/simple_door/key_door/soviet/QM/D in door_list)
					D.Open()
				for (var/obj/structure/simple_door/key_door/soviet/medic/D in door_list)
					D.Open()
				for (var/obj/structure/simple_door/key_door/soviet/engineer/D in door_list)
					D.Open()
				for (var/obj/structure/simple_door/key_door/german/QM/D in door_list)
					D.Open()
				for (var/obj/structure/simple_door/key_door/german/medic/D in door_list)
					D.Open()
				for (var/obj/structure/simple_door/key_door/german/engineer/D in door_list)
					D.Open()
				world << "<i>Due to lowpop, some doors have started open.</i>"
	return TRUE