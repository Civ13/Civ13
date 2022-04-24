/process/epochswap
	// epoch = required players

	var/list/epochs = list(
		//"Stone Age (?-3000 B.C.)" = 0,
		"Chad Mode" = 0,
		"Pre-Firearms (3000 B.C-1650 A.D.)" = 0,
		//"Bronze Age (3000 B.C.-400 A.D.)" = 0,
		//"Dark Ages (400-700)" = 0,
		//"Middle Ages (700-1450)" = 0,
		//"Renaissance (1450-1650)" = 0,
		//"Imperial Age (1650-1780)" = 0,
		//"Industrial Age (1850-1895)" = 0,
		//"Early Modern Era (1896-1930)" = 0,
		"Early Fire Arms (1650-1930)" = 0,
		"World War II (1931-1948)" = 0,
		//"Cold War Era (1949-1984)" = 0,
		//"Modern Era (1985-2020)" = 0,
		"Modern Fire Arms (1949-2021)" = 0,
		"HRP TDM (Gulag, Voyage, Occupation, etc)" = 10,
		"Civilization 13 (Nomads)" = 0,
		"Civilization 13 (Colony & Pioneers)" = 0,
		//"Civilization 13 (Prison Camps)" = 15,
		"Civilization 13 (Others)" = 0,
		"Battle Royale" = 0,
	)
	var/ready = TRUE
	var/admin_triggered = FALSE
	var/finished_at = -1

/process/epochswap/setup()
	name = "epochswap"
	schedule_interval = 5 SECONDS
	start_delay = 5 SECONDS
	fires_at_gamestates = list(GAME_STATE_PLAYING, GAME_STATE_FINISHED)
	priority = PROCESS_PRIORITY_IRRELEVANT
	processes.epochswap = src

/process/epochswap/fire()
	// no SCHECK here
	if (is_ready())
		spawn(20)
			map.save_awards()
		if(map.ID == MAP_VOYAGE)
			var/obj/map_metadata/voyage/nmap = map
			nmap.show_stats()
		if (config.allowedgamemodes == "TDM")
			epochs = list(
				"Pre-Firearms (3000 B.C-1650 A.D.)" = 0,
				"Early Fire Arms (1650-1930)" = 0,
				"World War II (1931-1948)" = 0,
				"Modern Fire Arms (1949-2021)" = 0,
				"HRP TDM (Gulag, Voyage, Occupation, etc)" = 10,
//				"Chad Mode" = 0,
				"Battle Royale" = 6,
			)
		else if (config.allowedgamemodes == "RP")
			epochs = list(
				//"The Art of the Deal" = 10,
				"Civilization 13 (Nomads)" = 0,
				"Civilization 13 (Colony & Pioneers)" = 0,
				//"Civilization 13 (Prison Camps)" = 15,
				"Civilization 13 (Others)" = 0,)
		else if (config.allowedgamemodes == "PERSISTENCE")
			epochs = list(
				"Civilization 13 (Nomads)" = 0,)
		else if (config.allowedgamemodes == "BR")
			epochs = list(
				"Battle Royale" = 6,)
		ready = FALSE
		vote.initiate_vote("epoch", "EpochSwap Process", TRUE, list(src, "swap"))

/process/epochswap/proc/is_ready()
	. = FALSE
	if (config.allowedgamemodes == "BR")
		. = FALSE
	else if (ready)
		if (admin_triggered)
			. = TRUE
		// round will end soon (tm)
		else if (map && map.admins_triggered_roundend)
			. = TRUE
		else if (ticker.finished)
			. = TRUE
	return .

/process/epochswap/proc/swap(var/winner = "Imperial Age (1650-1780)")
	vote.voted_epoch = winner


/process/mapswap
	// map = required players
	var/list/maps = list(MAP_CURSED_ISLAND = 0,)
	var/epoch = "Imperial Age (1650-1780)"
	var/ready = TRUE
	var/admin_triggered = FALSE
	var/finished_at = -1
	var/next_map_title = "TBD"
	var/done = FALSE

/process/mapswap/setup()
	name = "mapswap"
	schedule_interval = 5 SECONDS
	start_delay = 5 SECONDS
	fires_at_gamestates = list(GAME_STATE_PLAYING, GAME_STATE_FINISHED)
	priority = PROCESS_PRIORITY_IRRELEVANT
	processes.mapswap = src

/process/mapswap/fire()
	// no SCHECK here
	done = FALSE
	if (is_ready())
		ready = FALSE
		epoch = vote.voted_epoch
		if (epoch == "Modern Fire Arms (1949-2021)")
	// 2013 - TDM
			maps = list(
				MAP_CAPITOL_HILL = 6,
				MAP_HOSTAGES = 0,
				MAP_ARAB_TOWN = 0,
				MAP_ARAB_TOWN_2 = 0,
				MAP_YELTSIN = 6,
				MAP_ALLEYWAY = 0,
				MAP_COMPOUND = 6,
				MAP_ROAD_TO_DAK_TO = 0,
				MAP_HUE = 15,
				MAP_RETREAT = 6,
				MAP_GROZNY = 6,
				//MAP_FACTORY = 15,
				MAP_AFRICAN_WARLORDS = 10,
			)
		else if (epoch == "World War II (1931-1948)")
	// 1943 - TDM
			maps = list(
				MAP_REICHSTAG = 0,
				MAP_MICROMAHA = 0,
				MAP_NANKOU = 0,
				MAP_SMALLINGRAD = 0,
				MAP_REICHFLAKTURM = 0,
				MAP_PAVLOV_HOUSE = 0,
				MAP_HOTEL = 0,
				MAP_KHALKHYN_GOL = 8,
				MAP_SMALLSIEGEMOSCOW = 8,
				MAP_RIZAL_STADIUM = 10,
				MAP_KURSK = 10,
				MAP_STALINGRAD = 10,
				MAP_OMAHA = 20,
//				MAP_IWO_JIMA = 70,
				MAP_FOREST = 20,
//				MAP_KARELINA = 14,
				MAP_INTRAMUROS = 14,
				MAP_WAKE_ISLAND = 14,
				MAP_BERLIN = 20,
				MAP_NANJING = 14,
			)

		else if (epoch == "Early Fire Arms (1650-1930)")
	// 1903 - TDM
			maps = list(
				MAP_HILL_203 = 0,
				MAP_YPRES = 0,
				MAP_SIBERSYN = 6,
				MAP_TSARITSYN = 6,
				MAP_PORT_ARTHUR = 10,
				MAP_SANTO_TOMAS = 8,
				MAP_CALOOCAN = 0,
				MAP_LITTLE_CREEK_TDM = 0,
				MAP_MISSIONARY_RIDGE = 10,
				MAP_NAVAL = 0,
		//		MAP_SKULLISLAND = 0,
				MAP_CURSED_ISLAND = 0,
				MAP_SUPPLY_RAID = 0,
				MAP_BRIDGE = 0,
				MAP_RECIFE = 10,
				MAP_FIELDS = 10,
				MAP_ROBUSTA = 15,
				MAP_SEKIGAHARA = 6,
			)
		else if (epoch == "Stone Age (?-3000 B.C.)")
			maps = list(
				MAP_FOUR_KINGDOMS = 0,
				MAP_TRIBES = 0,
			)
		else if (epoch == "Chad Mode")
	// chad mode group for TDM
			maps = list(
				MAP_JUNGLE_OF_THE_CHADS = 0,
			)
		else if (epoch == "Pre-Firearms (3000 B.C-1650 A.D.)")
	//	1013 - TDM
			maps = list(
				MAP_KARAK = 0,
				MAP_CAMP = 0,
				MAP_SAMMIRHAYEED = 10,
				MAP_WHITERUN = 10,
				MAP_HERACLEA = 0,
				MAP_SIEGE = 0,
				MAP_GLADIATORS = 0,
				MAP_TEUTOBURG = 8,
				MAP_HERACLEA = 8,
			)
		else if (epoch == "HRP TDM (Gulag, Voyage, Occupation, etc)")
			maps = list(
//				MAP_FOOTBALL = 8,
				MAP_GULAG13 = 0,
				MAP_HUNT = 0,
				MAP_ABASHIRI = 6,
				MAP_VOYAGE = 6,
//				MAP_RIVER_KWAI = 0,
				MAP_LITTLE_CREEK = 10,
				MAP_OCCUPATION = 10,
				MAP_THE_ART_OF_THE_DEAL = 20,

			)
		else if (epoch == "Civilization 13 (Nomads)")
			maps = list(
//				MAP_CIVILIZATIONS = 0,
				MAP_NOMADS = 0,
				MAP_NOMADS_DESERT = 0,
				MAP_NOMADS_ICE_AGE = 0,
				MAP_NOMADS_JUNGLE = 0,
				MAP_NOMADS_DIVIDE = 10,
				MAP_NOMADS_CONTINENTAL = 10,
				MAP_NOMADS_PANGEA = 10,
				MAP_NOMADS_WASTELAND = 0,
				MAP_NOMADS_WASTELAND_2 = 0,
				MAP_NOMADS_NEW_WORLD = 5,
				MAP_NOMADS_MEDITERRANEAN = 0,
//				MAP_NOMADS_ISLAND = 0,
				MAP_NOMADS_KARAFUTO = 0,
				MAP_NOMADS_EUROPE = 10,
			)
		else if (epoch == "Civilization 13 (Colony & Pioneers)")
			maps = list(
				MAP_COLONY = 0,
				MAP_JUNGLE_COLONY = 4,
				MAP_PIONEERS = 5,
				MAP_PIONEERS_WASTELAND_2 = 0,
				MAP_BOHEMIA = 10,
				MAP_FOUR_COLONIES = 20,
			)
		else if (epoch == "Civilization 13 (Others)")
			maps = list(
				MAP_TRIBES = 12,
				MAP_HUNT = 0,
				MAP_LITTLE_CREEK = 10,
				MAP_THE_ART_OF_THE_DEAL = 10,
				MAP_FOUR_KINGDOMS = 0,
				MAP_GULAG13 = 0,
//				MAP_ABASHIRI = 6,
//				MAP_RIVER_KWAI = 0,
				MAP_OCCUPATION = 10,
			)
		else if (epoch == "Battle Royale")
			maps = list(
				MAP_BATTLEROYALE_MEDIEVAL = 0,
				MAP_BATTLEROYALE_IMPERIAL = 0,
				MAP_BATTLEROYALE_WILDWEST = 0,
				MAP_BATTLEROYALE_MODERN = 0,)
		spawn(10)
			vote.initiate_vote("map", "MapSwap Process", TRUE, list(src, "swap"))
			return

/process/mapswap/proc/is_ready()
	. = FALSE
	if (config.allowedgamemodes == "BR")
		. = FALSE
	else if (ready)
		if (admin_triggered)
			. = TRUE
		// round will end soon (tm)
		else if (map && map.admins_triggered_roundend)
			. = TRUE
		else if (ticker.finished)
			. = TRUE
	return .

/process/mapswap/proc/swap(var/winner = "Naval")
	next_map_title = winner
	winner = uppertext(winner)
	if (!maps.Find(winner))
		winner = maps[1]
	// there used to be messages here about success and failure but they lie so they're gone - Kachnov
	if (!done)
		processes.python.execute("mapswap.py", list(winner))
		done = TRUE

/process/gamemode
	var/ready = TRUE
	var/admin_triggered = FALSE
	var/finished_at = -1

/process/gamemode/setup()
	name = "gamemode"
	schedule_interval = 5 SECONDS
	start_delay = 5 SECONDS
	fires_at_gamestates = list()
	priority = PROCESS_PRIORITY_IRRELEVANT
	processes.gamemode = src
/process/gamemode/fire()
	// no SCHECK here
	if (is_ready())
		ready = FALSE
		vote.initiate_vote("gamemode", "Gamemode Process", TRUE, list(src, "swap"))

/process/gamemode/proc/is_ready()
	. = FALSE

	if (ready)
		if (admin_triggered)
			. = TRUE
		// round will end soon (tm)
		else if (map && map.admins_triggered_roundend)
			. = TRUE
		else if (ticker.finished)
			. = FALSE
	return .

/process/gamemode/proc/swap(var/winner = "Classic (Stone Age Start)")
	vote.voted_gamemode = winner
	round_progressing = TRUE
	ticker.delay_end = FALSE
	ticker.pregame_timeleft = 10
	if (vote.voted_gamemode == "Random")
		vote.voted_gamemode = pick("Classic (Stone Age Start)", "Auto-Research Mode", "Resource-Based Research", "Bronze Age (No Research)","Medieval (No Research)","Imperial Age (No Research)", "Industrial Age (No Research)", "Early Modern Age (No Research)", "WW2 Age (No Research)", "Modern Age (No Research)")

	map.gamemode = vote.voted_gamemode
	if (vote.voted_gamemode == "Classic (Stone Age Start)")
		world << "<big>Starting <b>Classic</b> mode. Starting epoch is the Stone Age, research active.</big>"
		map.ordinal_age = 0
		return

	if (vote.voted_gamemode == "Chad Mode")
		world << "<font color=#CECE00><big>Starting <b>Chad Mode</b>. Game epoch is the Stone Age, research inactive. Reduced starting items and more hostile conditions.</big></font>"
		map.ordinal_age = 0
		map.research_active = FALSE
		map.chad_mode = TRUE
		for (var/obj/effect/spawner/mobspawner/MS)
			MS.buff()
		for (var/obj/structure/wild/tree/T)
			T.amount *= 0.5
			T.amount = round(T.amount)
		for (var/obj/structure/wild/jungle/J)
			J.amount *= 0.5
			J.amount = round(J.amount)
		for (var/obj/structure/wild/palm/P)
			P.amount *= 0.5
			P.amount = round(P.amount)
		for (var/obj/structure/wild/junglebush/V)
			if (prob(75) && !istype(V,/obj/structure/wild/junglebush/chinchona))
				qdel(V)
		spawn(10)
			if (map.ID == MAP_NOMADS_ICE_AGE)
				for (var/turf/floor/dirt/winter/W)
					if (prob(40))
						W.ChangeTurf(/turf/floor/winter)
				for (var/turf/floor/winter/grass/WW)
					if (prob(40))
						WW.ChangeTurf(/turf/floor/winter)
			else if (map.ID == MAP_NOMADS_JUNGLE)
				for (var/turf/floor/dirt/winter/W)
					if (prob(40))
						W.ChangeTurf(/turf/floor/winter)
				for (var/turf/floor/winter/grass/WW)
					if (prob(40))
						WW.ChangeTurf(/turf/floor/winter)
		return

	if (vote.voted_gamemode == "Chad Mode +")
		world << "<font color=#CECE00><big>Starting <b>Chad Mode +</b>. Starting epoch is the Stone Age, research is done by sacrificing players. Reduced starting items and more hostile conditions.</big></font>"
		map.ordinal_age = 0
		map.research_active = TRUE
		map.chad_mode = TRUE
		map.chad_mode_plus = TRUE
		for (var/obj/effect/spawner/mobspawner/MS)
			MS.buff()
		for (var/obj/structure/wild/tree/T)
			T.amount *= 0.5
			T.amount = round(T.amount)
		for (var/obj/structure/wild/jungle/J)
			J.amount *= 0.5
			J.amount = round(J.amount)
		for (var/obj/structure/wild/palm/P)
			P.amount *= 0.5
			P.amount = round(P.amount)
		for (var/obj/structure/wild/junglebush/V)
			if (prob(75) && !istype(V,/obj/structure/wild/junglebush/chinchona))
				qdel(V)
		spawn(10)
			if (map.ID == MAP_NOMADS_ICE_AGE)
				for (var/turf/floor/dirt/winter/W)
					if (prob(40))
						W.ChangeTurf(/turf/floor/winter)
				for (var/turf/floor/winter/grass/WW)
					if (prob(40))
						WW.ChangeTurf(/turf/floor/winter)
			else if (map.ID == MAP_NOMADS_JUNGLE)
				for (var/turf/floor/dirt/winter/W)
					if (prob(40))
						W.ChangeTurf(/turf/floor/winter)
				for (var/turf/floor/winter/grass/WW)
					if (prob(40))
						WW.ChangeTurf(/turf/floor/winter)
		return

	else if (vote.voted_gamemode == "Bronze Age (No Research)")
		world << "<big>Starting <b>Bronze Age</b> mode. Game epoch is the Bronze Age, research inactive.</big>"
		map.ordinal_age = 1
		map.age = "313 B.C."
		map.age1_done = TRUE
		map.research_active = FALSE
		var/customresearch = 35
		map.default_research = customresearch
		map.civa_research = list(customresearch,customresearch,customresearch,null)
		map.civb_research = list(customresearch,customresearch,customresearch,null)
		map.civc_research = list(customresearch,customresearch,customresearch,null)
		map.civd_research = list(customresearch,customresearch,customresearch,null)
		map.cive_research = list(customresearch,customresearch,customresearch,null)
		map.civf_research = list(customresearch,customresearch,customresearch,null)
		return

	else if (vote.voted_gamemode == "Auto-Research Mode")
		world << "<big>Starting <b>Auto-Research mode</b>. Starting epoch is the Stone Age, research active but automatic.</big>"
		map.research_active = FALSE //well, it is, but we dont get research kits.
		map.autoresearch = TRUE
		map.ordinal_age = 0
		spawn(100)
			map.autoresearch_proc()
		return

	else if (vote.voted_gamemode == "Resource-Based Research")
		world << "<big>Starting <b>Resource-Based Research</b>. Starting epoch is the Stone Age, research active and requires the sale of items through <b>Research Desks</b>.</big>"
		map.research_active = FALSE //well, it is, but we dont get research kits.
		map.resourceresearch = TRUE
		map.ordinal_age = 0
		return

	else if (vote.voted_gamemode == "Bronze Age Start")
		world << "<big>Starting Classic mode with <b>Bronze Age</b> start. Starting epoch is the Bronze Age, research active.</big>"
		map.ordinal_age = 1
		map.age = "313 B.C."
		map.age1_done = TRUE
		map.research_active = TRUE
		var/customresearch = 35
		map.default_research = customresearch
		map.civa_research = list(customresearch,customresearch,customresearch,null)
		map.civb_research = list(customresearch,customresearch,customresearch,null)
		map.civc_research = list(customresearch,customresearch,customresearch,null)
		map.civd_research = list(customresearch,customresearch,customresearch,null)
		map.cive_research = list(customresearch,customresearch,customresearch,null)
		map.civf_research = list(customresearch,customresearch,customresearch,null)
		return
	else if (vote.voted_gamemode == "Medieval (No Research)")
		world << "<big>Starting <b>Medieval Age</b> mode. Game Epoch is the Medieval Age, research inactive.</big>"
		map.ordinal_age = 2
		map.age = "1013"
		map.age1_done = TRUE
		map.age2_done = TRUE
		map.research_active = FALSE
		var/customresearch = 50
		map.default_research = customresearch
		map.civa_research = list(customresearch,customresearch,customresearch,null)
		map.civb_research = list(customresearch,customresearch,customresearch,null)
		map.civc_research = list(customresearch,customresearch,customresearch,null)
		map.civd_research = list(customresearch,customresearch,customresearch,null)
		map.cive_research = list(customresearch,customresearch,customresearch,null)
		map.civf_research = list(customresearch,customresearch,customresearch,null)
		return
	else if (vote.voted_gamemode == "Imperial Age (No Research)")
		world << "<big>Starting <b>Imperial Age</b> mode. Game Epoch is the Imperial Age, research inactive.</big>"
		map.ordinal_age = 3
		map.age = "1713"
		map.age1_done = TRUE
		map.age2_done = TRUE
		map.age3_done = TRUE
		map.research_active = FALSE
		var/customresearch = 90
		map.default_research = customresearch
		map.civa_research = list(customresearch,customresearch,customresearch,null)
		map.civb_research = list(customresearch,customresearch,customresearch,null)
		map.civc_research = list(customresearch,customresearch,customresearch,null)
		map.civd_research = list(customresearch,customresearch,customresearch,null)
		map.cive_research = list(customresearch,customresearch,customresearch,null)
		map.civf_research = list(customresearch,customresearch,customresearch,null)
		return
	else if (vote.voted_gamemode == "Industrial Age (No Research)")
		world << "<big>Starting <b>Industrial Age</b> mode. Game Epoch is the Industrial Age, research inactive.</big>"
		map.ordinal_age = 4
		map.age = "1873"
		map.age1_done = TRUE
		map.age2_done = TRUE
		map.age3_done = TRUE
		map.age4_done = TRUE
		map.research_active = FALSE
		var/customresearch = 105
		map.default_research = customresearch
		map.civa_research = list(customresearch,customresearch,customresearch,null)
		map.civb_research = list(customresearch,customresearch,customresearch,null)
		map.civc_research = list(customresearch,customresearch,customresearch,null)
		map.civd_research = list(customresearch,customresearch,customresearch,null)
		map.cive_research = list(customresearch,customresearch,customresearch,null)
		map.civf_research = list(customresearch,customresearch,customresearch,null)
		return

	else if (vote.voted_gamemode == "Early Modern Age (No Research)")
		world << "<big>Starting <b>Early Modern Age</b> mode. Game Epoch is the EarLy Modern Age, research inactive.</big>"
		map.ordinal_age = 5
		map.age = "1903"
		map.age1_done = TRUE
		map.age2_done = TRUE
		map.age3_done = TRUE
		map.age4_done = TRUE
		map.age5_done = TRUE
		map.research_active = FALSE
		var/customresearch = 135
		map.default_research = customresearch
		map.civa_research = list(customresearch,customresearch,customresearch,null)
		map.civb_research = list(customresearch,customresearch,customresearch,null)
		map.civc_research = list(customresearch,customresearch,customresearch,null)
		map.civd_research = list(customresearch,customresearch,customresearch,null)
		map.cive_research = list(customresearch,customresearch,customresearch,null)
		map.civf_research = list(customresearch,customresearch,customresearch,null)
		return

	else if (vote.voted_gamemode == "WW2 Age (No Research)")
		world << "<big>Starting <b>WW2 Age</b> mode. Game Epoch is the WW2 Age, research inactive.</big>"
		map.ordinal_age = 6
		map.age = "1943"
		map.age1_done = TRUE
		map.age2_done = TRUE
		map.age3_done = TRUE
		map.age4_done = TRUE
		map.age5_done = TRUE
		map.age6_done = TRUE
		map.research_active = FALSE
		var/customresearch = 152
		map.default_research = customresearch
		map.civa_research = list(customresearch,customresearch,customresearch,null)
		map.civb_research = list(customresearch,customresearch,customresearch,null)
		map.civc_research = list(customresearch,customresearch,customresearch,null)
		map.civd_research = list(customresearch,customresearch,customresearch,null)
		map.cive_research = list(customresearch,customresearch,customresearch,null)
		map.civf_research = list(customresearch,customresearch,customresearch,null)
		return

	else if (vote.voted_gamemode == "Modern Age (No Research)")
		world << "<big>Starting <b>Modern Age</b> mode. Game Epoch is the Modern Age, research inactive.</big>"
		map.ordinal_age = 8
		map.age = "2013"
		map.age1_done = TRUE
		map.age2_done = TRUE
		map.age3_done = TRUE
		map.age4_done = TRUE
		map.age5_done = TRUE
		map.age6_done = TRUE
		map.age7_done = TRUE
		map.age8_done = TRUE
		map.research_active = FALSE
		var/customresearch = 230
		map.default_research = customresearch
		map.civa_research = list(customresearch,customresearch,customresearch,null)
		map.civb_research = list(customresearch,customresearch,customresearch,null)
		map.civc_research = list(customresearch,customresearch,customresearch,null)
		map.civd_research = list(customresearch,customresearch,customresearch,null)
		map.cive_research = list(customresearch,customresearch,customresearch,null)
		map.civf_research = list(customresearch,customresearch,customresearch,null)
		return
	/// TDM MODES ///
	else if (vote.voted_gamemode == "Normal")
		world << "<font color='green'><big>Normal Mode</big><br>No respawn delays.</big></font>"
		config.disable_fov = TRUE
		config.no_respawn_delays = TRUE
		map.gamemode = "Normal"
		global_damage_modifier = 1
		return
	else if (vote.voted_gamemode == "Competitive")
		world << "<font color='yellow'><big>Competitive Mode</big><br>Respawn delay enabled, increased damage.</big></font>"
		config.disable_fov = TRUE
		config.no_respawn_delays = FALSE
		map.gamemode = "Competitive"
		global_damage_modifier = 1.15
		return
	else if (vote.voted_gamemode == "Hardcore")
		world << "<font color='red'><big>HARDCORE Mode</big><br>No respawns, increased damage. Field of View enabled. Awards active.</big></font>"
		config.disable_fov = FALSE
		config.no_respawn_delays = FALSE
		map.gamemode = "Hardcore"
		global_damage_modifier = 1.30
		return
	/// CAPITOL MODES //
	else if (vote.voted_gamemode == "Siege")
		if (map && map.ID == MAP_CAPITOL_HILL)
			world << "<font color='yellow'><big>Siege</big><br>The <b>National Guard</b> must defend the Chambers of the <b>Congress</b> and the <b>Senate</b></big> for <b>40 minutes</b>!</font>"
		else if (map && map.ID == MAP_YELTSIN)
			world << "<font color='yellow'><big>Siege</big><br>The <b>Militia</b> must defend the <b>Parliamental Hall</b></big> until <b>40 minutes</b>!<br><font size=4>All factions have <b>10 minutes</b> to prepare before the battle.</font>"
		config.disable_fov = TRUE
		config.no_respawn_delays = TRUE
		map.gamemode = "Siege"
		for (var/turf/T in get_area_turfs(/area/caribbean/no_mans_land/capturable/one))
			new /area/caribbean/british/land/inside/objective(T)
		for (var/turf/T in get_area_turfs(/area/caribbean/no_mans_land/capturable/two))
			new /area/caribbean/british/land/inside/objective(T)
		return
	else if (vote.voted_gamemode == "Protect the VIP")
		if (map && map.ID == MAP_CAPITOL_HILL)
			world << "<font color='yellow'><big>Protect the VIP</big><br>The <b>HVT</b> is being guarded by the <b>FBI</b> inside the National Guard-controlled Capitol. Protestors must find him!<br>They have <b>25 minutes to do it!</b></big></font>"
		else if (map && map.ID == MAP_YELTSIN)
			world << "<font color='yellow'><big>Protect the VIP</big><br>The <b>HVT</b> is being guarded by the <b>KGB</b> inside the Militia-controlled Capitol. The Soviet Army must find them!<br>They have <b>40 minutes to do it!</b></big></font>"
		config.disable_fov = TRUE
		config.no_respawn_delays = TRUE
		map.gamemode = "Protect the VIP"
		return
	else if (vote.voted_gamemode == "Area Capture")
		world << "<font color='yellow'><big>Area Capture</big><br>Capture the <b>Congress</b> and the <b>Senate</b> to gain points. First team to <b>40 points</b> wins!</big></font>"
		config.disable_fov = TRUE
		config.no_respawn_delays = TRUE
		map.gamemode = "Area Capture"
		var/obj/map_metadata/capitol_hill/CP = map
		CP.points_check()
		return
	else if (vote.voted_gamemode == "Kills")
		if (map && map.ID == MAP_CAPITOL_HILL)
			world << "<font color='yellow'><big>Kills</big><br>The <b>American Militia</b> storms the  <b>National Guard</b>-controlled Capitol!</b></big></font>"
			var/obj/map_metadata/capitol_hill/CP = map
			CP.points_check()
		else if (map && map.ID == MAP_YELTSIN)
			world << "<font color='yellow'><big>Kills</big><br>The <b>Soviet Army</b> storms the <b>Militia</b>-controlled Capitol!</b></big></font>"
			var/obj/map_metadata/yeltsin/CP = map
			CP.points_check()
		config.disable_fov = TRUE
		config.no_respawn_delays = TRUE
		map.gamemode = "Kills"
		return