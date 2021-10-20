
/obj/map_metadata/voyage
	ID = MAP_VOYAGE
	title = "Voyage"
	no_winner ="The ship is on the way."
	lobby_icon_state = "imperial"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 0


	faction_organization = list(
		PIRATES)

	roundend_condition_sides = list(
		list(PIRATES) = /area/caribbean/no_mans_land,
		)
	age = "1713"
	ordinal_age = 3
	faction_distribution_coeffs = list(PIRATES = 1)
	battle_name = "Pirate life"
	mission_start_message = "<font size=4>Your crew of pirates assembles for the first voyage. Will you get rich, or perish like the others?</font>"
	is_singlefaction = TRUE
	is_RP = TRUE
	has_hunger = TRUE
	respawn_delay = 1800 //3 minutes

	var/longitude = 71 //71 to 77 W
	var/latitude = 21 //21 to 27 N
	var/list/mapgen = list()
	var/list/islands = list()
	var/list/forts = list()
	var/list/sea = list()
	var/list/ships = list()
	var/navmoving = FALSE //if the ship is moving
	var/navdirection = "North"
	var/navprogress = 0 //how far along on moving to a neighbouring tile the ship is
	var/navspeed = 0
	var/inzone = FALSE //if the ship is currently in an event zone
	var/ship_anchored = TRUE

	var/roundend_msg = "The round has ended!"

/obj/map_metadata/voyage/proc/get_sink()
	var/t_level = 0
	for(var/obj/effect/flooding/F in get_area_all_atoms(/area/caribbean/pirates/ship/voyage/lower))
		t_level += F.flood_level*3
	for(var/obj/effect/flooding/F in get_area_all_atoms(/area/caribbean/pirates/ship/voyage/lower/storage/kitchen))
		t_level += F.flood_level*3
	for(var/obj/effect/flooding/F in get_area_all_atoms(/area/caribbean/pirates/ship/voyage/lower/storage))
		t_level += F.flood_level*3
	for(var/obj/effect/flooding/F in get_area_all_atoms(/area/caribbean/pirates/ship/voyage/lower/storage/magazine))
		t_level += F.flood_level*3
	return t_level

/obj/map_metadata/voyage/proc/check_roundend_conditions()
	//sinking
	if (get_sink() >= 100)
		roundend_msg = "The ship has sank due to flooding in the lower decks!<br><font color='red'>You have lost!</font>"
		map.next_win = world.time - 100
		return
	//everyone dead
	if(processes.ticker.playtime_elapsed >= 6000) //10 mins
		var/found = FALSE
		for(var/mob/living/human/H in world)
			if (H.stat != DEAD)
				found = TRUE
		if (!found)
			roundend_msg = "The whole crew has succumbed!<br><font color='red'>You have lost!</font>"
			map.next_win = world.time - 100
			return

/obj/map_metadata/voyage/proc/nav()
	check_roundend_conditions()
	if (navmoving && !ship_anchored)
		if (!inzone)
			navspeed = calc_speed()
			navprogress += navspeed
			if (navprogress >= 100)
				navprogress = 0
				if (navdirection == "island" || findtext(navdirection,"ship" || navdirection == "island fort"))
					enter_event()
				else
					switch(navdirection)
						if ("North")
							if(latitude < 27)
								latitude++
								check_ships()
							else
								for(var/obj/structure/voyage/anchor_capstan/AC in world)
									AC.lower_anchor()

						if ("South")
							if(latitude > 21)
								latitude--
								check_ships()
							else
								for(var/obj/structure/voyage/anchor_capstan/AC in world)
									AC.lower_anchor()
						if ("East")
							if(longitude < 77)
								longitude++
								check_ships()
							else
								for(var/obj/structure/voyage/anchor_capstan/AC in world)
									AC.lower_anchor()
						if ("West")
							if(longitude > 71)
								longitude--
								check_ships()
							else
								for(var/obj/structure/voyage/anchor_capstan/AC in world)
									AC.lower_anchor()
	spawn(600)
		nav()
//checks for ships when the player ship arrives in new coordinate
/obj/map_metadata/voyage/proc/check_ships()
	for(var/list/L in ships)
		if (L[3] == latitude && L[4] == longitude)
			world << "<font size=4 color='yellow'>A ship approaches!</font>"
			navmoving = FALSE
			for(var/obj/effect/sailing_effect/S in world)
				S.icon_state = "sailing_effect_stopped"
				S.update_icon()
			inzone = TRUE
			ship_anchored = TRUE
			load_map(mapgen["[latitude],[longitude]"][3])
			return


//0 means random for numerical values
/obj/map_metadata/voyage/proc/gen_ship(sfaction = "random", ssize = 0, slat = 0, slon = 0)
	if (sfaction == "random" || !(sfaction in list("pirates","merchant","spanish","british","undead")))
		sfaction = pick("pirates","merchant","spanish","british","undead")
	if (ssize <= 0 || ssize > 5)
		ssize = pick(1,2,3,4,5)
	else
		ssize = round(ssize)

	var/csloc = pick(src.sea)
	if (slat == 0 || !(slat in list(21,22,23,24,25,26,27)))
		slat = csloc[2]
	if (slon == 0 || !(slon in list(71,72,73,74,75,76,77)))
		slon = csloc[3]

	if(mapgen["[slat],[slon]"])
		mapgen["[slat],[slon]"][3] = "ship[ssize]_[sfaction]"
	ships += list(list(ssize,sfaction,slat,slon))
/obj/map_metadata/voyage/proc/calc_speed()
	var/spd = 0
	var/snum = 0
	for(var/obj/structure/barricade/ship/mast/large/S in world)
		if (S.owner == "ship")
			if (S.mast_is_upgraded == TRUE)
				spd += (S.sailstat+S.sailhealth+S.rigginghealth)/150
				snum++
			else
				spd += (S.sailstat+S.sailhealth+S.rigginghealth)/300
				snum++
	if (spd != 0 && snum != 0)
		spd/=snum //divide by number of masts
	spd*=33 //how much % of progress per minute for each spd unit, ex: 2 masts in full condition = 1*33 = 33, 3 mins to change tiles
	return spd+1

/obj/map_metadata/voyage/proc/enter_event()
	navmoving = FALSE
	for(var/obj/effect/sailing_effect/S in world)
		S.icon_state = "sailing_effect_stopped"
		S.update_icon()
	inzone = TRUE
	ship_anchored = TRUE
	world << "<font size=4 color='yellow'>The ship arrives at the destination.</font>"
	if (navdirection == "island")
		if (prob(50))
			load_map(pick("island1","island2","piratetown","cursedisland"),"north")
		else
			load_map(pick("island1","island2","piratetown"),"south")
		return
	else if (navdirection == "island fort")
		load_map(pick("island_fortress1","island_fortress2"),"south")
	else
		load_map(mapgen["[latitude],[longitude]"][3])
	return

/obj/map_metadata/voyage/proc/abandon_event()
	navmoving = TRUE
	for(var/obj/effect/sailing_effect/S in world)
		S.icon_state = "sailing_effect"
		S.update_icon()
	inzone = FALSE
	ship_anchored = FALSE
	world << "<font size=4 color='yellow'>The ship returns to the high seas.</font>"
	for(var/obj/structure/grapplehook/G in world)
		G.undeploy()
	clear_map()
	//convert looted autofire cannons to normal cannons and looted grappling hooks to normal hooks
	for(var/obj/structure/cannon/modern/tank/voyage/autofire/C in world)
		new/obj/structure/cannon/modern/tank/voyage(C.loc)
		qdel(C)
	for(var/obj/structure/grapplehook/auto/D in world)
		new/obj/structure/grapplehook(D.loc)
		qdel(D)

	for(var/list/L in ships)
		if (L[3] == latitude && L[4] == longitude)
			ships -= L
	for(var/list/L1 in islands)
		if (L1[2] == latitude && L1[3] == longitude)
			L1[4] = world.time + 18000
	for(var/list/L2 in forts)
		if (L2[2] == latitude && L2[3] == longitude)
			L2[4] = world.time + 18000
	return

/obj/map_metadata/voyage/proc/clear_map()
	//North
	for(var/turf/T in get_area_turfs(/area/caribbean/sea/top))
		for (var/mob/living/M in T)
			qdel(M)
		for (var/obj/O in T)
			qdel(O)
		if (T.type != /turf/floor/beach/water/deep/saltwater)
			T.ChangeTurf(/turf/floor/beach/water/deep/saltwater)
	for(var/turf/T1 in get_area_turfs(/area/caribbean/sea/top/roofed))
		for (var/mob/living/M in T1)
			qdel(M)
		for (var/obj/O in T1)
			qdel(O)
		if (T1.type != /turf/floor/beach/water/deep/saltwater)
			T1.ChangeTurf(/turf/floor/beach/water/deep/saltwater)
		new/area/caribbean/sea/top(T1)
		for (var/atom/movable/lighting_overlay/LO in T1)
			LO.update_overlay()
	//South
	for(var/turf/T2 in get_area_turfs(/area/caribbean/sea/bottom))
		for (var/mob/living/M in T2)
			qdel(M)
		for (var/obj/O in T2)
			qdel(O)
		if (T2.type != /turf/floor/beach/water/deep/saltwater)
			T2.ChangeTurf(/turf/floor/beach/water/deep/saltwater)
	for(var/turf/T3 in get_area_turfs(/area/caribbean/sea/bottom/roofed))
		for (var/mob/living/M in T3)
			qdel(M)
		for (var/obj/O in T3)
			qdel(O)
		if (T3.type != /turf/floor/beach/water/deep/saltwater)
			T3.ChangeTurf(/turf/floor/beach/water/deep/saltwater)
		new/area/caribbean/sea/bottom(T3)
		for (var/atom/movable/lighting_overlay/LO in T3)
			LO.update_overlay()

/obj/map_metadata/voyage/update_win_condition()
	if (world.time >= next_win && next_win != -1)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		world << "<font size=4>[roundend_msg]</font>"
		win_condition_spam_check = TRUE
		return FALSE

////////////////////////////////////////////////////////////////
//////////////////LOADING AND SAVING PARTIAL MAPS//////////////
/obj/map_metadata/voyage/proc/load_map(mapname = "ship1", location = "random")
	if (location == "random")
		location = pick("south","north")
	var/y_offset = 0 //for north maps
	if (location == "north")
		y_offset = 51
	var/dmm_file = "maps/zones/[location]/[mapname].dmm"
	if(!isfile(file(dmm_file)))
		var/newName_p1 = splittext(mapname,"_")
		var/newName = newName_p1[1]
		dmm_file = "maps/zones/[location]/[newName].dmm"
	var/dmm_text = file2text(dmm_file)
	var/dmm_suite/suite = new()
	suite.read_map(dmm_text, 1, y_offset, 1)
	/*
	world.log << "Importing [partpath]..."
	var/F = file("[partpath]/turfs.txt")
	if (fexists(F))
		world.log << "Importing turfs..."
		var/tmpturfs = file2text(F)
		var/list/impturfs = splittext(tmpturfs, "\n")
		for (var/i in impturfs)
			var/list/impturfs2 = splittext(i, ";")
			if (impturfs2.len && impturfs2[1] == "TURF")
				var/resultp = text2path(impturfs2[5])
				var/turf/T = locate(text2num(impturfs2[2]),text2num(impturfs2[3])+y_offset,text2num(impturfs2[4]))
				if (T)
					T.ChangeTurf(resultp)
	var/F1 = file("[partpath]/areas.txt")
	if (fexists(F1))
		world.log << "Importing areas..."
		var/tmpareas = file2text(F1)
		var/list/impareas = splittext(tmpareas, "\n")
		for (var/i in impareas)
			var/list/impareas2 = splittext(i, ";")
			if (impareas2.len && impareas2[1] == "AREA")
				var/resultp = text2path(impareas2[5])
				if(resultp)
					new resultp(locate(text2num(impareas2[2]),text2num(impareas2[3])+y_offset,text2num(impareas2[4])))

	var/F2 = file("[partpath]/mobs.txt")
	if (fexists(F2))
		world.log << "Importing mobs..."
		var/tmpmobs = file2text(F2)
		var/list/impmobs = splittext(tmpmobs, "\n")
		for (var/i in impmobs)
			var/list/impmobs2 = splittext(i, ";")
			if (impmobs2.len >= 5 && impmobs2[1] == "MOB" && impmobs2[5] != "/mob/new_player" && impmobs2[5] != "/mob/observer")
				var/resultp = text2path(impmobs2[5])
				var/mob/newmob = new resultp(locate(text2num(impmobs2[2]),text2num(impmobs2[3])+y_offset,text2num(impmobs2[4])))
				newmob.stat = text2num(impmobs2[6])
	var/F3 = file("[partpath]/objs.txt")
	if (fexists(F3))
		world.log << "Importing objects..."
		var/tmpobjs = file2text(F3)
		var/list/impobjs = splittext(tmpobjs, "\n")
		for (var/i in impobjs)
			var/list/impobjs2 = splittext(i, ";")
			if (impobjs2.len >= 5)
				var/resultp = text2path(impobjs2[5])
				var/obj/tmpobj = new resultp(locate(text2num(impobjs2[2]),text2num(impobjs2[3])+y_offset,text2num(impobjs2[4])))
				if (impobjs2[1] == "OBJECT")
					for (var/j=6, j<=impobjs2.len, j++)
						var/list/tempvars = splittext(impobjs2[j], "===")
						if (tempvars.len == 2)
							if (tempvars[1] == "name")
								tmpobj.name = tempvars[2]
							else if (tempvars[1] == "desc")
								tmpobj.desc = tempvars[2]
							else if (tempvars[1] == "dir")
								tmpobj.dir = text2num(tempvars[2])
							else if (tempvars[1] == "icon_state")
								tmpobj.icon_state = tempvars[2]
							else
								if (tmpobj.vars[tempvars[1]] && tempvars[1] != "loc" && tempvars[1] != "locs" && tempvars[1] != "verbs")
									if (isnum(tmpobj.vars[tempvars[1]]))
										tmpobj.vars[tempvars[1]] = text2num(tempvars[2])
									else
										tmpobj.vars[tempvars[1]] = tempvars[2]
	world.log << "Imported all objects."
	world.log << "Finished all imports."
	*/
///////////////////////////////////////////////////////////////////
/obj/map_metadata/voyage/proc/list2text_assoc(var/atom/A, nx = -1, ny = -1, nz = -1)
	. = list()
	if (istype(A, /obj/structure/wild) || (!istype(A, /obj/item) && !istype(A, /obj/structure) && !istype(A, /obj/map_metadata) && !istype(A, /obj/covers)))
		return "SIMPLE_OBJ;[A.x];[A.y];[A.z];[A.type]"
	else
		var/keylist = list("name","desc","icon_state","dir")
		if (istype(A, /obj/item/stack))
			keylist += "amount"
		for (var/key in keylist)
			if (A.vars[key] && A.vars[key] != initial(A.vars[key]))
				if (islist(A.vars[key]))
					if (isemptylist(A.vars[key]))
						. += "[key]===EMPTYLIST"
					else
						. += "[key]==={{"
						for(var/i in A.vars[key])
							. += "[i]|"
						. += "}}"
				else
					. += "[key]===[A.vars[key]]"
		if (nx == -1)
			nx = A.x
		if (ny == -1)
			ny = A.y
		if (nz == -1)
			nz = A.z
		return "OBJECT;[nx];[ny];[nz];[A.type];[list2text(.)]"

/obj/map_metadata/voyage/proc/do_export(saveloc = "maps/test")
	world << "<i><b>Saving the game... Might lag for a few seconds.</b></i>"
	world.log << "Started saving at [time2text(world.realtime,"YYYY-MM-DD-(hh-mm-ss)")]."
	var/F = file("[saveloc]/mobs.txt")
	if (fexists(F))
		fdel(F)
	var/F1 = file("[saveloc]/turfs.txt")
	if (fexists(F1))
		fdel(F1)
	var/F2 = file("[saveloc]/objs.txt")
	if (fexists(F2))
		fdel(F2)
	var/F3 = file("[saveloc]/areas.txt")
	if (fexists(F3))
		fdel(F3)
	spawn(10)
		for (var/turf/T in world)
			if (!istype(T, /turf/floor/beach/water/deep/saltwater))
				text2file("TURF;[T.x];[T.y];[T.z];[T.type]",F1)
			var/area/AR = get_area(T)
			if (istype(AR,/area/caribbean/sea/bottom/roofed) || istype(AR,/area/caribbean/sea/top/roofed))
				text2file("AREA;[T.x];[T.y];[T.z];[AR.type]",F3)
			for (var/mob/living/A in T)
				if (A.loc == T)
					text2file("MOB;[A.x];[A.y];[A.z];[A.type];[A.stat]",F)
			for (var/obj/O in T)
				if (O.loc == T)
					if (!istype(O,/obj/screen) && !istype(O,/atom/movable/lighting_overlay) && !istype(O,/obj/map_metadata) && !istype(O,/obj/effect))
						if(istype(O, /obj/structure/closet) && (istype(O, /obj/structure/closet/crate/empty) || !istype(O, /obj/structure/closet/crate)))
							for(var/obj/CT in O)
								text2file(list2text_assoc(CT, O.x, O.y, O.z),F2)
						text2file(list2text_assoc(O),F2)
	sleep(1)
	world.log << "Finished saving at [time2text(world.realtime,"YYYY-MM-DD-(hh-mm-ss)")]."
	world << "<i><b>Finished saving.</b></i>"
	return saveloc

/////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////
/obj/map_metadata/voyage/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 1 || admin_ended_all_grace_periods)

/obj/map_metadata/voyage/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 1 || admin_ended_all_grace_periods)

/obj/map_metadata/voyage/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_RP == TRUE)
		. = FALSE
	else if (J.is_army == TRUE)
		. = FALSE
	else if (J.is_prison == TRUE)
		. = FALSE
	else if (J.is_ww1 == TRUE)
		. = FALSE
	else if (J.is_coldwar == TRUE)
		. = FALSE
	else if (J.is_medieval == TRUE)
		. = FALSE
	else if (J.is_marooned == TRUE)
		. = FALSE
	else if (istype(J, /datum/job/pirates/battleroyale))
		. = FALSE
	else if (istype(J, /datum/job/pirates/cook) || istype(J, /datum/job/pirates/carpenter) || istype(J, /datum/job/pirates/midshipman))
		. = FALSE
	else
		. = TRUE

/obj/map_metadata/voyage/New()
	..()
	nav()
	for(var/lon = 71, lon <= 77, lon++)
		for(var/lat = 21, lat <= 27, lat++)
			mapgen["[lat],[lon]"] = list(lat, lon, "sea")
			if (prob(25))
				if (prob(15))
					mapgen["[lat],[lon]"][3] = "fort"
					forts += list(list(pick("island_fortress1","island_fortress2"),lat, lon, 0))
				else
					mapgen["[lat],[lon]"][3] = "island"
					islands += list(list(pick("island1","island2","island3","island4","island5"),lat, lon, 0))
			else
				sea += list(list("sea",lat,lon))
	gen_ship(sfaction = "pirates", ssize = 1, slat = 0, slon = 0)
	gen_ship(sfaction = "spanish", ssize = 1, slat = 0, slon = 0)
	gen_ship(sfaction = "pirates", ssize = 1, slat = 0, slon = 0)
	gen_ship(sfaction = "spanish", ssize = 2, slat = 0, slon = 0)
	gen_ship(sfaction = "pirates", ssize = 2, slat = 0, slon = 0)
	gen_ship(sfaction = "pirates", ssize = 2, slat = 0, slon = 0)
	gen_ship(sfaction = "spanish", ssize = 3, slat = 0, slon = 0)
	gen_ship(sfaction = "spanish", ssize = 5, slat = 0, slon = 0)
	gen_ship(sfaction = "spanish", ssize = 6, slat = 0, slon = 0)
	spawn(100)
		load_new_recipes()
/obj/map_metadata/voyage/cross_message()
	return ""
/obj/map_metadata/voyage/reverse_cross_message()
	return ""


/obj/map_metadata/voyage/load_new_recipes()
	var/F3 = file("config/crafting/material_recipes_voyage.txt")
	if (fexists(F3))
		var/list/craftlist_temp = file2list(F3,"\n")
		craftlist_lists["global"] = list()
		for (var/i in craftlist_temp)
			if (findtext(i, ","))
				var/tmpi = replacetext(i, "RECIPE: ", "")
				var/list/current = splittext(tmpi, ",")
				craftlist_lists["global"] += list(current)
				if (current.len != 13)
					world.log << "Error! Recipe [current[2]] has a length of [current.len] (should be 13)."

///////////////Specific objects////////////////////
/obj/structure/voyage/bullet_act(var/obj/item/projectile/P, def_zone)
	P.on_hit(src, FALSE, def_zone)
	return
/obj/structure/voyage/attackby(obj/P, mob/user)
	return
/obj/structure/voyage/shipwheel
	name = "ship wheel"
	desc = "Used to steer the ship."
	icon = 'icons/obj/vehicles/vehicleparts_boats.dmi'
	icon_state = "ship_wheel"
	layer = 2.99
	density = TRUE
	anchored = TRUE
	attack_hand(mob/living/human/H)
		var/obj/map_metadata/voyage/nmap = map
		if (nmap)
			if (nmap.ship_anchored)
				WWalert(H, "The ship is anchored! Raise the anchor first","Ship Anchored")
				return
			var/optlist = list("North","South","East","West")
			var/def_dir = nmap.navdirection
			var/currtile = nmap.mapgen["[nmap.latitude],[nmap.longitude]"][3]
			if (currtile != "sea")
				var/parsed_currtile = currtile
				if (findtext(parsed_currtile,"ship"))
					parsed_currtile = "ship"
				optlist = list("Approach [parsed_currtile]","North","South","East","West")
				def_dir = "Approach [parsed_currtile]"
			var/newdir = WWinput(H, "The Ship is currently heading to the [nmap.navdirection]. Which direction to you want to head to?","Ship Wheel",def_dir,optlist)
			if (findtext(newdir,"Approach "))
				for(var/list/L in nmap.islands)
					if (L[2] == nmap.latitude && L[3] == nmap.longitude && world.time <= L[4])
						WWalert(H, "You've visited this island too recently!", "Island")
						return
				for(var/list/L2 in nmap.forts)
					if (L2[2] == nmap.latitude && L2[3] == nmap.longitude && world.time <= L2[4])
						WWalert(H, "You've visited this island fort too recently!", "Fort")
						return
			if (newdir != nmap.navdirection)
				if (do_after(H, 50, src))
					nmap.navdirection = newdir
					if (findtext(nmap.navdirection,"Approach "))
						nmap.navdirection = replacetext(nmap.navdirection,"Approach ","")
					visible_message("<font size=3 color='yellow'>The ship heads to the <b>[nmap.navdirection]</b>.</font>")
					return
/obj/structure/voyage/tablemap
	name = "map"
	desc = "A map of the regeion. Used by the captain to plan the next moves."
	icon = 'icons/obj/items.dmi'
	icon_state = "table_map"
	layer = 3.2
	var/mob/living/user = null
	anchored = TRUE
	var/image/img
	var/icon/img_flattened
	New()
		..()
		spawn(30)
			img = image(icon = 'icons/minimaps.dmi', icon_state = "voyage")
			get_updated_img()
	proc/get_updated_img()
		img.overlays.Cut()
		if(map.ID == MAP_VOYAGE)
			var/obj/map_metadata/voyage/nmap = map
			for(var/list/L in nmap.islands)
				var/image/newisland = image(icon='icons/minimap_effects.dmi', icon_state=L[1],layer=src.layer+1)
				newisland.pixel_x = 49+((L[3]-71)*69)
				newisland.pixel_y = 81+((L[2]-21)*68)
				img.overlays+=newisland
			for(var/list/L in nmap.forts)
				var/image/newfort = image(icon='icons/minimap_effects.dmi', icon_state=L[1],layer=src.layer+1)
				newfort.pixel_x = 49+((L[3]-71)*69)
				newfort.pixel_y = 81+((L[2]-21)*68)
				img.overlays+=newfort
			for(var/list/L in nmap.ships)
				var/image/newship = image(icon='icons/minimap_effects.dmi', icon_state="ship[L[1]]",layer=src.layer+1.1)
				newship.pixel_x = 49+((L[4]-71)*69)
				newship.pixel_y = 81+((L[3]-21)*68)
				var/image/newship_s = image(icon='icons/minimap_effects.dmi', icon_state="size[L[1]]",layer=src.layer+1.11)
				newship_s.pixel_x = 49+((L[4]-71)*69)
				newship_s.pixel_y = 81+((L[3]-21)*68)
				var/image/newship_f = image(icon='icons/minimap_effects.dmi', icon_state=L[2],layer=src.layer+1.12)
				newship_f.pixel_x = 49+((L[4]-71)*69)
				newship_f.pixel_y = 81+((L[3]-21)*68)
				img.overlays+=newship
				img.overlays+=newship_s
				img.overlays+=newship_f

	examine(mob/user)
		update_icon()
		user << browse(getFlatIcon(img),"window=popup;size=630x630")

	attack_hand(mob/user)
		update_icon()
		examine(user)

/obj/structure/voyage/boatswain_book
	name = "crew log"
	desc = "A book listing all the ship's crew and their assigned jobs."
	icon = 'icons/obj/library.dmi'
	icon_state = "book_bs"
	layer = 3.2
	anchored = TRUE
	attack_hand(mob/living/human/H)
		if (H.original_job_title == "Pirate Boatswain")
			var/dat = "<h1>CREW LOG</h1>"
			dat += tally_crew()
			H << browse(dat, "window=Crew Log")
	proc/tally_crew()
		var/t_text = "<style>table, th, td {border: 1px solid black;}</style><table><tr><th>Name</th><th>Job</th></tr>"
		for(var/mob/living/human/HM in world)
			if (HM.stat != DEAD)
				var/t_title = HM.original_job_title
				if (t_title == "Pirate")
					t_title = "Sailor"
				else
					t_title = replacetext(HM.original_job_title,"Pirate ","")
				t_text += "<tr><td>[HM.name]</td><td>[t_title]</td></tr>"
		t_text += "</table>"
		return t_text

/obj/structure/voyage/quartermaster_book
	name = "ship inventory"
	desc = "A diary tracking the current inventory in the ship."
	icon = 'icons/obj/library.dmi'
	icon_state = "book_qm"
	layer = 3.2
	anchored = TRUE

	attack_hand(mob/living/human/H)
		if (H.original_job_title == "Pirate Quartermaster")
			var/tres = tally_treasure()
			var/mats = tally_materials()
			var/mats_wood = mats["wood"]
			var/mats_cloth = mats["cloth"]
			var/mats_rope = mats["rope"]
			var/food = tally_food()
			var/mats_food = food["food"]
			var/mats_water = food["water"]
			var/wep = tally_weapons()
			var/mats_cannon = wep["cannonballs"]
			var/mats_musket = wep["musket"]
			var/mats_pistol = wep["pistol"]

			var/dat = "<h1>SHIP STOCKS</h1>"
			dat += "<b>Treasury:</b> [tres] reales<br>"
			dat += "<b>Wood:</b> [mats_wood] logs<br>"
			dat += "<b>Cloth:</b> [mats_cloth] sheets<br>"
			dat += "<b>Rope:</b> [mats_rope] coils<br>"
			dat += "<b>Food:</b> [mats_food] doses<br>"
			dat += "<b>Water:</b> [mats_water] units<br>"
			dat += "<b>Cannon Ammo:</b> [mats_cannon] balls<br>"
			dat += "<b>Musket Ammo:</b> [mats_musket] projectiles<br>"
			dat += "<b>Pistol Ammo:</b> [mats_pistol] projectiles<br>"
			H << browse(dat, "window=Ship Stocks")
	proc/tally_treasure()
		var/tally = 0
		var/list/t_turfs = get_area_turfs(/area/caribbean/pirates/ship/voyage/upper/inside/treasury)
		for(var/turf/sel_turf in t_turfs)
			for(var/obj/structure/closet/crate/chest/treasury/ship/S in sel_turf)
				for(var/obj/item/stack/money/M in S)
					tally += M.value*M.amount
				for(var/obj/item/stack/money/M1 in S.loc)
					tally += M1.value*M1.amount
		return tally

	proc/tally_materials()
		var/list/tally = list("cloth" = 0, "wood" = 0, "rope" = 0)
		var/list/t_turfs = get_area_turfs(/area/caribbean/pirates/ship/voyage/lower/storage)
		for(var/turf/sel_turf in t_turfs)
			for(var/obj/structure/closet/crate/S in sel_turf)
				for(var/obj/item/stack/material/cloth/M in S)
					tally["cloth"] += M.amount
				for(var/obj/item/stack/material/rope/M1 in S)
					tally["rope"] += M1.amount
				for(var/obj/item/stack/material/wood/M2 in S)
					tally["wood"] += M2.amount
			for(var/obj/item/stack/material/cloth/M in sel_turf)
				tally["cloth"] += M.amount
			for(var/obj/item/stack/material/rope/M1 in sel_turf)
				tally["rope"] += M1.amount
			for(var/obj/item/stack/material/wood/M2 in sel_turf)
				tally["wood"] += M2.amount
		return tally

	proc/tally_food()
		var/list/tally = list("food" = 0, "water" = 0)
		var/list/t_turfs = get_area_turfs(/area/caribbean/pirates/ship/voyage/lower/storage/kitchen)
		for(var/turf/sel_turf in t_turfs)
			for(var/obj/structure/closet/crate/S in sel_turf)
				for(var/obj/item/weapon/reagent_containers/food/F in S)
					tally["food"]++
			for(var/obj/item/weapon/reagent_containers/food/F in sel_turf)
				tally["food"]++
			for(var/obj/item/weapon/reagent_containers/glass/barrel/B in sel_turf)
				for (var/datum/reagent/R in B.reagents.reagent_list)
					if (istype(R, /datum/reagent/water))
						tally["water"] += R.volume
			for(var/obj/structure/reagent_dispensers/largebarrel/L in sel_turf)
				for (var/datum/reagent/R in L.reagents.reagent_list)
					if (istype(L, /datum/reagent/water))
						tally["water"] += R.volume
		return tally

	proc/tally_weapons()
		var/list/tally = list("musket" = 0, "pistol" = 0, "cannonballs" = 0)
		var/list/t_turfs = get_area_turfs(/area/caribbean/pirates/ship/voyage/lower/storage/magazine)
		for(var/turf/sel_turf in t_turfs)
			for(var/obj/structure/closet/crate/S in sel_turf)
				for(var/obj/item/ammo_casing/musketball/MB in S)
					tally["musket"]++
				for(var/obj/item/ammo_casing/musketball_pistol/MBP in S)
					tally["pistol"]++
				for(var/obj/item/cannon_ball/CB in S)
					tally["cannonballs"]++
			for(var/obj/item/ammo_casing/musketball/MB in sel_turf)
				tally["musket"]++
			for(var/obj/item/ammo_casing/musketball_pistol/MBP in sel_turf)
				tally["pistol"]++
			for(var/obj/item/cannon_ball/CB in sel_turf)
				tally["cannonballs"]++
		return tally

/obj/structure/voyage/sextant
	name = "sextant"
	desc = "Used to determine the current latitude and longitude using the sun and stars."
	icon = 'icons/obj/items.dmi'
	icon_state = "sextant_tool"
	layer = 3.2
	anchored = TRUE

	attack_hand(mob/living/human/H)
		examine(H)

	examine(mob/H)
		..()
		var/obj/map_metadata/voyage/nmap = map
		if (nmap)
			H << "The ship is currently at <b>[nmap.latitude]</b>°N, <b>[nmap.longitude]</b>°W."
			H << "The ship is heading to the <b>[nmap.navdirection]</b>, progress: <b>[nmap.navprogress]%</b>"
			H << "Sinking progress: <b>[nmap.get_sink()]%</b>"
			if(nmap.ship_anchored)
				H << "The ship is <font color='red'><b>anchored</b></font>."

/obj/structure/voyage/shipbell
	name = "ship's bell"
	desc = "Used to relay signals to the crew."
	icon = 'icons/obj/structures.dmi'
	icon_state = "bell_stand"
	layer = 4
	anchored = TRUE
	density = TRUE
	opacity = FALSE
	var/cooldown_bell_stand = 0

	attack_hand(mob/living/human/user)
		if(!ishuman(user))
			return
		play()

	proc/play()
		if (world.time >= cooldown_bell_stand)
			for (var/mob/M in player_list)
				M.client << sound('sound/effects/bell_stand.ogg', repeat = FALSE, wait = TRUE, channel = 777)
			world << "<font size=4 color='yellow'>You hear the ship's bell!</font>"
			cooldown_bell_stand = world.time+50
			icon_state = "bell_stand_ringing"
			spawn(15)
				icon_state = "bell_stand"


/obj/structure/voyage/ropeladder
	name = "rope ladder"
	desc = "A strong rope ladder leading up the mast."
	icon = 'icons/turf/64x64.dmi'
	icon_state = "ropeladder"
	layer = 5
	density = FALSE
	anchored = TRUE

/obj/structure/voyage/anchor
	name = "anchor"
	desc = "A large iron anchor."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "anchor"
	layer = 5
	density = FALSE
	anchored = TRUE

/obj/structure/voyage/anchor_capstan
	name = "anchor capstan"
	desc = "A vertical-axled rotating machine used to raise and lower the ship's anchor."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "capstan"
	layer = 4
	density = TRUE
	anchored = TRUE
	var/image/anchor

	New()
		..()
		anchor = image(icon = 'icons/obj/vehicles/vehicleparts.dmi', icon_state = "anchor", layer = 5, pixel_y = -32)

	update_icon()
		..()
		overlays.Cut()
		if(anchored)
			overlays += anchor

	proc/raise_anchor()
		if(map.ID == MAP_VOYAGE)
			var/obj/map_metadata/voyage/nmap = map
			world << "<font size=3 color='yellow'>The ship starts moving.</font>"
			nmap.ship_anchored = FALSE
			nmap.navmoving = TRUE
			for(var/obj/effect/sailing_effect/S in world)
				S.icon_state = "sailing_effect"
				S.update_icon()
			update_icon()
	proc/lower_anchor()
		if(map.ID == MAP_VOYAGE)
			var/obj/map_metadata/voyage/nmap = map
			nmap.ship_anchored = TRUE
			nmap.navmoving = FALSE
			for(var/obj/effect/sailing_effect/S in world)
				S.icon_state = "sailing_effect_stopped"
				S.update_icon()
			update_icon()
	attack_hand(mob/user)
		if(map.ID == MAP_VOYAGE && ishuman(user))
			var/obj/map_metadata/voyage/nmap = map
			if (nmap.inzone == 1)
				if (nmap.ship_anchored)
					var/resp = WWinput(user, "You are currently in an event, are you sure you want to raise the anchor and leave? It will take two minutes.","Anchor","No",list("Yes","No"))
					if (resp == "No")
						return
					else
						world << "<font size=4 color='yellow'>The ship is getting ready to leave, ALL crew outside must return within <b>2</b> minutes or be left behind!</font>"
						spawn(600)
							world << "<font size=4 color='yellow'>The ship is leaving, ALL crew outside must return within <b>1</b> minute or be left behind!</font>"
						spawn(1200)
							raise_anchor()
							nmap.abandon_event()
				else
					user << "You start [nmap.ship_anchored ? "raising" : "lowering"] the anchor..."
					if (do_after(user, 60, src))
						user << "You lower the anchor."
						lower_anchor()
			else
				user << "You start [nmap.ship_anchored ? "raising" : "lowering"] the anchor..."
				if (do_after(user, 60, src))
					if (nmap.ship_anchored)
						user << "You raise the anchor."
						raise_anchor()
					else
						user << "You lower the anchor."
						lower_anchor()

/obj/structure/voyage/ropeladder/thin
	icon_state = "ropeladder_thin"

/obj/structure/closet/crate/chest/treasury/ship
	name = "ship's treasury"
	desc = "Where the ship's treasury is stored."
	faction = "ship"
	anchored = TRUE

/obj/structure/voyage/grid
	name = "loading gate"
	desc = "A large gridded gate, used to load the ship."
	icon = 'icons/turf/64x64.dmi'
	icon_state = "grid"
	layer = 2.99
	density = FALSE
	anchored = TRUE

/obj/structure/voyage/grid/partial
	icon_state = "grid_partial"

/obj/effect/sailing_effect
	name = "waves"
	desc = "Waves caused by the ship's movement."
	icon = 'icons/obj/vehicles/vehicleparts_boats.dmi'
	icon_state = "sailing_effect_stopped"
	layer = 4
	density = FALSE
	anchored = TRUE

/obj/effect/flooding
	name = "flooded floor"
	desc = "The water seems to be about 50cm deep."
	icon = 'icons/misc/beach.dmi'
	icon_state = "flood_overlay1"
	layer = 2
	density = FALSE
	anchored = TRUE
	var/flood_level = 1

	New()
		..()
		spawn(30)
			var/found = FALSE
			for(var/obj/covers/CV in loc)
				found = TRUE
				break
			if (found)
				for(var/obj/effect/flooding/FLD in loc)
					if (src != FLD)
						flood_level = min(3,flood_level+FLD.flood_level)
						qdel(FLD)
						update_icon()
			else
				qdel(src)

	update_icon()
		icon_state = "flood_overlay[flood_level]"
		desc = "The water seems to be about [flood_level*50]cm deep."

	attackby(obj/item/I, mob/living/human/user)
		if(istype(I, /obj/item/weapon/reagent_containers/glass))
			if (I.reagents.get_free_space() >= 50)
				user << "You start filling \the [I]..."
				if (do_after(user,40,src))
					if (I.reagents.get_free_space() >= 50)
						I.reagents.add_reagent("sodiumchloride", 8)
						I.reagents.add_reagent("water", 42)
						user << "You fill \the [I]."
						playsound(loc, 'sound/effects/watersplash.ogg', 100, TRUE)
						flood_level--
						if (flood_level <= 0)
							qdel(src)
			else
				user << "<span class='warning'>There is not enough free capacity in \the [I] to fill it.</span>"
